# Architecture

Adapted from the designs of **wow-ai** and **WowGrok**, targeting retail World of Warcraft 12.1 (Interface 120100).

## Core Constraint

WoW addons run in a sandbox. They **cannot**:

- Open sockets or make HTTP requests
- Freely read/write arbitrary files outside SavedVariables
- Inject code or read game memory

Therefore all AI communication goes through an external **bridge** process.

## Communication Channels

### 1. Outbound (Addon → Bridge) — Pixel Strip

The addon encodes messages as a strip of small colored squares (typically 4×4 px cells) in the top-left corner of the game window.

- Encoded with a simple protocol (magic header, length, payload, checksum)
- Bridge captures the screen region several times per second and decodes it
- Requires **windowed or borderless** mode (exclusive fullscreen blocks capture)

### 2. Inbound (Bridge → Addon) — Slot Pool

A pool of load-on-demand addon slots (e.g. 100–200):

- Each slot is a tiny addon with `## LoadOnDemand: 1` and an `Inbox.lua`
- Bridge writes the reply data into the slot files
- Addon loads the appropriate slot via `C_AddOns.LoadAddOn` when a signal arrives
- Readiness is indicated by empty vs. valid `.wav` files (PlaySoundFile trick)

### 3. Signals

- `.wav` files used as cheap presence/readiness flags
- Presence heartbeat so the addon can show bridge status
- ACK signals so the pixel strip can be cleared

## Retail 12.1 Considerations

- Interface version: **120100** (patch 12.1.0)
- Midnight-era restrictions apply: combat log and many secret values are restricted
- Non-combat data (quest log, gear, professions, talents, zone, inventory) remains readable via documented APIs
- Prefer `C_*` namespaces where available
- SavedVariables for persistent state (session token, settings, chat history metadata)

## Character Context

The addon can optionally collect and send:

- Character identity (name, realm, class, level, faction)
- Current zone / subzone / coordinates
- Equipped gear (item links + optional tooltips)
- Quest log / weekly progress
- Professions and skill levels
- Talents / specialization

Context is sent only when it changes, to keep payloads small.

## Grok Integration

Two backends planned:

1. **Grok Build CLI** (default) — `grok login` (browser OAuth) + headless invocation
2. **xAI API** — direct HTTP with `XAI_API_KEY`

The bridge launches or calls the chosen backend, streams the response, and writes it back through the slot pool.

## Fallback Modes

- Pixel + slots (preferred, low latency)
- Reload fallback (`/reload` after each message) if capture fails

## Security & ToS Notes

- Only documented addon APIs
- No memory reading, no input injection, no automation of combat
- Bridge runs locally under user control
- Not affiliated with Blizzard or xAI
