#!/usr/bin/env node
/**
 * Generates LoadOnDemand slot addons for the inbound channel.
 *
 * Usage:
 *   node setup-slots.js --addons "C:\\Program Files\\World of Warcraft\\_retail_\\Interface\\AddOns"
 *   node setup-slots.js --addons ./test-addons --slots 20
 *
 * The generated folders must exist before the WoW client is launched
 * (or you must fully restart the client after copying them).
 */

const fs = require("fs")
const path = require("path")

const args = process.argv.slice(2)
let addonsDir = null
let numSlots = 20

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--addons" && args[i + 1]) {
    addonsDir = args[++i]
  } else if (args[i] === "--slots" && args[i + 1]) {
    numSlots = parseInt(args[++i], 10) || 20
  }
}

if (!addonsDir) {
  console.error("Usage: node setup-slots.js --addons <Interface\\AddOns path> [--slots N]")
  process.exit(1)
}

const TOC = `## Interface: 120100
## Title: WoWGrok Slot
## Notes: LoadOnDemand slot for WoW Grok Assistant replies
## LoadOnDemand: 1
## Author: fdiori628

Inbox.lua
`

const INBOX = `-- Placeholder. The bridge overwrites this file at runtime.
WoWGrok_SlotData = nil
`

console.log(`Generating ${numSlots} slot addons into: ${addonsDir}`)

for (let i = 1; i <= numSlots; i++) {
  const name = `WoWGrok_S${String(i).padStart(3, "0")}`
  const dir = path.join(addonsDir, name)
  fs.mkdirSync(dir, { recursive: true })
  fs.writeFileSync(path.join(dir, `${name}.toc`), TOC)
  fs.writeFileSync(path.join(dir, "Inbox.lua"), INBOX)
}

console.log("Done. Fully restart the WoW client so it discovers the new addons.")
console.log("Leave the slot addons enabled on the AddOns screen.")
