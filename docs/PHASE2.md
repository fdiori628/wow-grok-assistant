# Phase 2: Grok CLI Integration + Character Context + Chat UI

## What was implemented

### Character context (addon)
- `GetContext()` collects character name/level/class, zone, quest count, and equipped item links.
- Prompts automatically include this context.

### Grok CLI (bridge)
- Calls `grok -p "..." --output-format json` and writes the reply to the slot pool.

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
3. Type a question and press Enter.
4. Expected: Message appears in the window, bridge calls Grok, reply appears in the window.

## Notes / Next steps

- UI is basic (no history persistence, no rich formatting).
- No session resume yet.
- Context can still be enriched (weekly activities, gear scoring, etc.).
- Optional API key backend can be added later.
