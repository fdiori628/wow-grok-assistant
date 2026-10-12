# Phase 2: Grok CLI Integration + Character Context + Chat UI + Session Resume

## What was implemented

### Character context (addon)
- `GetContext()` collects character name/level/class, zone, quest count, and equipped item links.
- Prompts automatically include this context.

### Grok CLI (bridge)
- Calls `grok -p "..." --output-format json` and writes the reply to the slot pool.

### Session Resume
- Bridge parses `sessionId` from Grok's JSON response.
- Persists it to `bridge/state.json`.
- Subsequent messages automatically use `--resume <sessionId>` so the conversation continues with prior context.
- Survives bridge restarts.

### In-game Chat UI
- Movable window with title bar, scrollable message area, and input box.
- `/grok` (no args) toggles the window.
- Type in the input box and press Enter to send.
- User messages and Grok replies appear in the window (and also print to chat).
- `/grok <message>` still works as a direct send.

## Requirements

1. Grok CLI installed and logged in (`grok login` or `XAI_API_KEY`).
2. `grok` in PATH.
3. Slot addons generated (Phase 1).
4. Windowed / borderless mode.

## Test

1. Start bridge: `node bridge/bridge.js`
2. In game: `/grok` to open the window.
3. Send a first message, then a follow-up (e.g. "what did I just ask?").
4. Expected: Second reply shows awareness of the first message (session resumed).

## Notes / Next steps

- UI is basic (no history persistence, no rich formatting).
- Context can still be enriched (weekly activities, gear scoring, etc.).
- Optional API key backend can be added later.
- To start a fresh session, delete `bridge/state.json` and restart the bridge.
