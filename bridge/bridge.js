/**
 * WoW Grok Assistant — Bridge (Phase 1 complete)
 * - Spawns capture.ps1
 * - On decoded message, writes an echo reply into all slot Inbox.lua files
 *
 * Set environment variable WOW_ADDONS to your Interface\\AddOns path,
 * or edit the default below.
 */

const { spawn } = require("child_process")
const fs = require("fs")
const path = require("path")

const captureScript = path.join(__dirname, "capture.ps1")
const ADDONS = process.env.WOW_ADDONS || path.join(__dirname, "..", "test-addons")
const NUM_SLOTS = 20

function writeSlots(reply) {
  const lua = `WoWGrok_SlotData = {
  now = ${Math.floor(Date.now() / 1000)},
  replies = {
    { id = ${reply.id}, status = "done", text = ${JSON.stringify("echo: " + reply.text)} }
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
  console.log(`[slots] wrote echo reply id=${reply.id} to ${written} slot(s)`)
}

console.log("WoW Grok Assistant bridge (Phase 1: full round-trip)")
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
        writeSlots(msg)
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
