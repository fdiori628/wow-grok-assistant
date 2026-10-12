# Phase 2: Grok CLI Integration + Character Context

## What was implemented

### Character context (addon)
- `GetContext()` collects:
  - Character name, level, class
  - Current zone / subzone
  - Number of active quests (`C_QuestLog.GetNumQuestLogEntries`)
  - Equipped item links for main slots
- On `/grok <message>`, the addon builds a full prompt that includes this context + the player question.
- `/grok context` prints the raw context for debugging.

### Grok CLI (bridge)
- On decoded message, the bridge runs:
  ```bash
  grok -p "<full prompt>" --output-format json --no-auto-update
  ```
- Parses the JSON reply (or falls back to raw stdout).
- Writes the real Grok reply into the slot pool (same as Phase 1).

## Requirements

1. Grok CLI installed and logged in:
   ```bash
   grok login
   # or set XAI_API_KEY
   ```
2. `grok` must be in PATH when the bridge runs.
3. Slot addons already generated (from Phase 1).
4. Game in windowed / borderless mode.

## Test

1. Start bridge: `node bridge/bridge.js`
2. In game: `/grok what should I do this week?`
3. Expected: Bridge calls Grok, then addon prints the reply.

## Notes / Next steps

- Context is still basic (no full weekly checklist, no detailed gear scoring).
- No session resume yet (`--resume`).
- No in-game chat window (still uses chat print + pixel strip).
- Optional API key backend can be added later.
- For longer conversations, we should implement proper session IDs and multi-turn.

This completes the core of Phase 2. UI and richer context can follow.
