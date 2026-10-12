/**
 * WoW Grok Assistant — Bridge (Phase 2)
 * - Spawns capture.ps1
 * - On decoded message, calls Grok CLI headlessly and writes the reply to slots
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
  console.log("[grok] calling CLI...")
  const args = ["-p", prompt, "--output-format", "json", "--no-auto-update"]
  // Optional: --always-approve if you want tools; omitted for pure chat for now
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
      callback(text, null)
    } catch (e) {
      // Fallback if not pure JSON
      callback(stdout.trim() || stderr.trim() || "(no output)", null)
    }
  })

  proc.on("error", (err) => {
    callback(null, `Failed to spawn grok: ${err.message}. Is Grok CLI installed and in PATH?`)
  })
}

console.log("WoW Grok Assistant bridge (Phase 2: Grok CLI)")
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
        // The addon already prefixes context; we just pass the full text as prompt
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
