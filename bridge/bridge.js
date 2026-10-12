/**
 * WoW Grok Assistant — Bridge
 * - Spawns capture.ps1 (auto-restart)
 * - Calls Grok CLI (preferred) or XAI API key fallback
 * - Serializes Slot writes + heartbeat
 */

const { spawn } = require("child_process")
const fs = require("fs")
const path = require("path")
const https = require("https")

const captureScript = path.join(__dirname, "capture.ps1")
const ADDONS = process.env.WOW_ADDONS || path.join(__dirname, "..", "test-addons")
const NUM_SLOTS = 20
const STATE_FILE = path.join(__dirname, "state.json")
const GROK_TIMEOUT_MS = 45000
const HEARTBEAT_MS = 30000
const API_KEY = process.env.XAI_API_KEY || null
const USE_API = !!API_KEY

let currentSessionId = null
let nextWriteSlot = 1
let captureProc = null
let writeQueue = []
let writing = false

function loadState() {
  try {
    if (fs.existsSync(STATE_FILE)) {
      const s = JSON.parse(fs.readFileSync(STATE_FILE, "utf8"))
      currentSessionId = s.sessionId || null
      console.log("[state] loaded sessionId:", currentSessionId || "(none)")
    }
  } catch (e) {
    console.warn("[state] failed to load:", e.message)
  }
}

function saveState() {
  try {
    fs.writeFileSync(STATE_FILE, JSON.stringify({ sessionId: currentSessionId }, null, 2))
  } catch (e) {
    console.warn("[state] failed to save:", e.message)
  }
}

function processWriteQueue() {
  if (writing || writeQueue.length === 0) return
  writing = true
  try {
    const { id, text } = writeQueue.shift()
    const ok = writeSingleSlot(id, text)
    if (!ok && id !== 0) {
      console.warn("[slots] write failed for id=" + id + ", queueing error reply")
      writeQueue.unshift({ id, text: "Error: no Slot directories found. Check WOW_ADDONS path." })
    }
  } catch (e) {
    console.error("[slots] write failed:", e.message)
  } finally {
    writing = false
    setImmediate(processWriteQueue)
  }
}

function enqueueWrite(id, text) {
  writeQueue.push({ id, text })
  processWriteQueue()
}

function writeSingleSlot(id, text) {
  const lua = `WoWGrok_SlotData = {
  now = ${Math.floor(Date.now() / 1000)},
  replies = {
    { id = ${id}, status = "done", text = ${JSON.stringify(text)} }
  }
}
`
  for (let attempt = 0; attempt < NUM_SLOTS; attempt++) {
    const name = `WoWGrok_S${String(nextWriteSlot).padStart(3, "0")}`
    const inbox = path.join(ADDONS, name, "Inbox.lua")
    nextWriteSlot = (nextWriteSlot % NUM_SLOTS) + 1
    if (fs.existsSync(path.dirname(inbox))) {
      fs.writeFileSync(inbox, lua)
      console.log(`[slots] wrote id=${id} to ${name}`)
      return true
    }
  }
  console.warn("[slots] no slot directories found — check WOW_ADDONS path")
  return false
}

function writeHeartbeat() {
  const lua = `WoWGrok_SlotData = {
  now = ${Math.floor(Date.now() / 1000)},
  replies = {}
}
`
  for (let attempt = 0; attempt < NUM_SLOTS; attempt++) {
    const name = `WoWGrok_S${String(nextWriteSlot).padStart(3, "0")}`
    const inbox = path.join(ADDONS, name, "Inbox.lua")
    nextWriteSlot = (nextWriteSlot % NUM_SLOTS) + 1
    if (fs.existsSync(path.dirname(inbox))) {
      fs.writeFileSync(inbox, lua)
      return
    }
  }
}

function callGrokAPI(prompt, callback) {
  const body = JSON.stringify({
    model: "grok-4.7",
    messages: [{ role: "user", content: prompt }],
    temperature: 0.7
  })
  const req = https.request({
    hostname: "api.x.ai",
    path: "/v1/chat/completions",
    method: "POST",
    headers: {
      "Authorization": `Bearer ${API_KEY}`,
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(body)
    }
  }, (res) => {
    let data = ""
    res.on("data", (c) => { data += c })
    res.on("end", () => {
      try {
        const json = JSON.parse(data)
        if (res.statusCode !== 200) {
          callback(null, `API ${res.statusCode}: ${(json.error?.message || data).slice(0, 300)}`)
          return
        }
        const text = json.choices?.[0]?.message?.content || "(empty)"
        callback(text, null)
      } catch (e) {
        callback(null, "API parse error: " + data.slice(0, 200))
      }
    })
  })
  req.on("error", (err) => callback(null, "API request failed: " + err.message))
  req.setTimeout(GROK_TIMEOUT_MS, () => {
    req.destroy()
    callback(null, "API timeout")
  })
  req.write(body)
  req.end()
}

function callGrokCLI(prompt, callback) {
  const args = ["-p", prompt, "--output-format", "json", "--no-auto-update"]
  if (currentSessionId) {
    args.push("--resume", currentSessionId)
    console.log(`[grok] resuming session ${currentSessionId}`)
  } else {
    console.log("[grok] starting new session")
  }

  const proc = spawn("grok", args, { stdio: ["ignore", "pipe", "pipe"] })
  let stdout = ""
  let stderr = ""
  let finished = false

  const timer = setTimeout(() => {
    if (!finished) {
      finished = true
      try { proc.kill() } catch {}
      callback(null, "Grok CLI timed out after 45s")
    }
  }, GROK_TIMEOUT_MS)

  proc.stdout.on("data", (d) => { stdout += d.toString() })
  proc.stderr.on("data", (d) => { stderr += d.toString() })

  proc.on("close", (code) => {
    if (finished) return
    finished = true
    clearTimeout(timer)
    if (code !== 0) {
      callback(null, `Grok CLI failed (code ${code}): ${stderr.slice(0, 400)}`)
      return
    }
    try {
      const json = JSON.parse(stdout.trim())
      const text = json.text || json.response || "(empty reply)"
      if (json.sessionId) {
        currentSessionId = json.sessionId
        saveState()
        console.log(`[grok] sessionId updated to ${currentSessionId}`)
      }
      callback(text, null)
    } catch (e) {
      const fallback = stdout.trim() || stderr.trim() || "(no output)"
      callback(fallback, null)
    }
  })

  proc.on("error", (err) => {
    if (finished) return
    finished = true
    clearTimeout(timer)
    callback(null, `Failed to spawn grok: ${err.message}`)
  })
}

function callGrok(prompt, callback) {
  if (USE_API) {
    console.log("[grok] using XAI API key (stateless)")
    const apiPrompt = "[New session - no prior history]\n" + prompt
    callGrokAPI(apiPrompt, callback)
  } else {
    callGrokCLI(prompt, callback)
  }
}

function startCapture() {
  if (captureProc) {
    try { captureProc.kill() } catch {}
  }
  console.log("Starting capture.ps1 ...")
  captureProc = spawn("powershell.exe", [
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", captureScript,
    "-ProcessName", "Wow"
  ], { stdio: ["ignore", "pipe", "pipe"] })

  captureProc.stdout.on("data", (data) => {
    const lines = data.toString().split(/\r?\n/).filter(Boolean)
    for (const line of lines) {
      try {
        const msg = JSON.parse(line)
        if (msg.info) {
          console.log("[capture]", msg.info)
        } else if (msg.warn) {
          console.warn("[capture]", msg.warn)
        } else if (msg.error) {
          console.error("[capture]", msg.error)
        } else if (msg.id !== undefined && msg.text !== undefined) {
          console.log(`[decoded] id=${msg.id} text=${JSON.stringify(msg.text).slice(0, 120)}`)
          callGrok(msg.text, (reply, err) => {
            if (err) {
              console.error("[grok]", err)
              enqueueWrite(msg.id, "Error: " + err)
            } else {
              console.log(`[grok] reply length=${(reply || "").length}`)
              enqueueWrite(msg.id, reply || "(empty)")
            }
          })
        } else {
          console.log("[capture]", line)
        }
      } catch {
        console.log("[capture raw]", line)
      }
    }
  })

  captureProc.stderr.on("data", (data) => {
    console.error("[capture stderr]", data.toString().trim())
  })

  captureProc.on("close", (code) => {
    console.log(`capture process exited with code ${code} — restarting in 3s`)
    setTimeout(startCapture, 3000)
  })
}

loadState()
console.log("WoW Grok Assistant bridge")
console.log("AddOns path:", ADDONS)
console.log("Backend:", USE_API ? "XAI API key" : "Grok CLI")
startCapture()
setInterval(writeHeartbeat, HEARTBEAT_MS)
writeHeartbeat()

process.on("SIGINT", () => {
  if (captureProc) captureProc.kill()
  process.exit(0)
})
