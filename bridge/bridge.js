/**
 * WoW Grok Assistant — Bridge (Phase 2 + session resume)
 * - Spawns capture.ps1
 * - Calls Grok CLI with session resume for multi-turn conversations
 *
 * Requires: `grok` in PATH and logged in (`grok login`)
 * Optional: set WOW_ADDONS to your Interface\\AddOns path
 */

const { spawn } = require("child_process")
const fs = require("fs")
const path = require("path")

const captureScript = path.join(__dirname, "capture.ps1")
const ADDONS = process.env.WOW_ADDONS || path.join(__dirname, "..", "test-addons")
const NUM_SLOTS = 20
const STATE_FILE = path.join(__dirname, "state.json")

let currentSessionId = null

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

function writeSlots(id, text) {
  const lua = `WoWGrok_SlotData = {
  now = ${Math.floor(Date.now() / 1000)},
  replies = {
    { id = ${id}, status = "done", text = ${JSON.stringify(text)} }
  }
}
`
  let written = 0
  for (let i = 1; i <= NUM_SLOTS; i++) {
    const name = `WoWGrok_S${String(i).padStart(3, "0")}`
    const inbox = path.join(ADDONS, name, "Inbox.lua")
    if (fs.existsSync(path.dirname(inbox))) {
      fs.writeFileSync(inbox, lua)
      written++
    }
  }
  console.log(`[slots] wrote reply id=${id} to ${written} slot(s)`)
}

function callGrok(prompt, callback) {
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
  proc.stdout.on("data", (d) => { stdout += d.toString() })
  proc.stderr.on("data", (d) => { stderr += d.toString() })

  proc.on("close", (code) => {
    if (code !== 0) {
      callback(null, `Grok CLI failed (code ${code}): ${stderr.slice(0, 500)}`)
      return
    }
    try {
      const json = JSON.parse(stdout.trim())
      const text = json.text || json.response || stdout.trim() || "(empty reply)"
      if (json.sessionId) {
        currentSessionId = json.sessionId
        saveState()
        console.log(`[grok] sessionId updated to ${currentSessionId}`)
      }
      callback(text, null)
    } catch (e) {
      callback(stdout.trim() || stderr.trim() || "(no output)", null)
    }
  })

  proc.on("error", (err) => {
    callback(null, `Failed to spawn grok: ${err.message}. Is Grok CLI installed and in PATH?`)
  })
}

loadState()

console.log("WoW Grok Assistant bridge (Phase 2 + session resume)")
console.log("AddOns path:", ADDONS)
console.log("Starting capture.ps1 ...")

const ps = spawn("powershell.exe", [
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", captureScript,
  "-ProcessName", "Wow"
], {
  stdio: ["ignore", "pipe", "pipe"]
})

ps.stdout.on("data", (data) => {
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
        console.log(`[decoded] id=${msg.id} text=${JSON.stringify(msg.text)}`)
        const fullPrompt = msg.text
        callGrok(fullPrompt, (reply, err) => {
          if (err) {
            console.error("[grok]", err)
            writeSlots(msg.id, "Error: " + err)
          } else {
            console.log(`[grok] reply length=${(reply || "").length}`)
            writeSlots(msg.id, reply || "(empty)")
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

ps.stderr.on("data", (data) => {
  console.error("[capture stderr]", data.toString().trim())
})

ps.on("close", (code) => {
  console.log(`capture process exited with code ${code}`)
})

process.on("SIGINT", () => {
  ps.kill()
  process.exit(0)
})
