# Phase 2: Grok CLI Integration + Character Context + Chat UI + Session Resume

## What was implemented

### Character context (addon)
- Character name, level, class, zone / subzone
- Specialization name
- Average / equipped item level (`GetAverageItemLevel`)
- Gold amount
- Active quest count
- Weekly rewards progress (`C_WeeklyRewards.GetActivities`)
- Professions with skill levels (`GetProfessions` + `GetProfessionInfo`)
- Equipped item names

### Grok CLI (bridge)
- Calls `grok -p "..." --output-format json` and writes the reply to the slot pool.

### Session Resume
- Bridge parses `sessionId` from Grok's JSON response and persists it to `bridge/state.json`.
- Subsequent messages automatically use `--resume <sessionId>`.

### In-game Chat UI
- Movable window with title bar, scrollable message area, and input box.
- Timestamps on messages.
- Clear button and `/grok clear`.
- Status indicator (Ready / Waiting / Error).
- `/grok` toggles the window.
- Enter in the input box sends the message.

## Requirements

1. Grok CLI installed and logged in (`grok login` or `XAI_API_KEY`).
2. `grok` in PATH.
3. Slot addons generated (Phase 1).
4. Windowed / borderless mode.

## Test

1. Start bridge: `node bridge/bridge.js`
2. In game: `/grok` to open the window.
3. Send messages; follow-ups should continue the session.
4. Try `/grok context` to see the enriched context.

## Notes / Next steps

- UI still lacks persistent history across reloads.
- Context can be further enriched (detailed weekly vault, currencies beyond gold, etc.).
- Optional API key backend can be added later.
- To start a fresh session, delete `bridge/state.json` and restart the bridge.
