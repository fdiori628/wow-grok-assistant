/**
 * WoW Grok Assistant — Bridge (Phase 1)
 * Spawns the Windows pixel strip capture and logs decoded messages.
 *
 * Usage (Windows):
 *   node bridge.js
 *
 * Requires the game in windowed or borderless mode.
 * Process name defaults to "Wow" (retail client).
 */

const { spawn } = require("child_process")
const path = require("path")

const captureScript = path.join(__dirname, "capture.ps1")

console.log("WoW Grok Assistant bridge (Phase 1: pixel capture)")
console.log("Starting capture.ps1 ...")
console.log("Make sure WoW is windowed/borderless and the addon has drawn a strip.")

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
