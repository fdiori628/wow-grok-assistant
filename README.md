# wow-grok-assistant

In-game Grok AI assistant for World of Warcraft (retail 12.1 / Midnight).

Inspired by the architectures of [wow-ai](https://github.com/chelinho139/wow-ai) and [WowGrok](https://github.com/hydrolive/wow-grok).

## Status

**Early development** — targeting official retail WoW patch 12.1 (Interface: 120100).

## How it works (high level)

WoW addons cannot open network connections. Communication with Grok happens through an external **bridge** process:

1. **Addon → Bridge**: The addon draws a colored pixel strip in the top-left corner of the screen. The bridge captures and decodes it.
2. **Bridge → Addon**: The bridge writes replies into a pool of load-on-demand slot addons. The game loads them on demand. Readiness is signaled via empty vs valid `.wav` files.

This follows the proven design used by wow-ai and WowGrok.

## Goals

- In-game chat window with Grok (via Grok Build CLI or xAI API)
- Character context (gear, quests, weekly activities, talents, professions, zone, etc.)
- Helpers for monitoring weekly tasks, gear upgrades, and other progress
- OAuth-style login via `grok login` or API key

## Requirements (planned)

- World of Warcraft retail 12.1+, windowed or borderless mode
- Node.js 22+
- Grok Build CLI (`grok login`) or `XAI_API_KEY`

## Project structure

```
addon/          # WoW addon (Lua)
bridge/         # Companion process (Node.js)
docs/           # Architecture and design notes
```

## Development

See `docs/ARCHITECTURE.md` for the detailed design adapted for retail 12.1.

This project is not affiliated with Blizzard or xAI.
