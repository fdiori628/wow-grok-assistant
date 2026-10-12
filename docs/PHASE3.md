# Phase 3: Useful Features

## Implemented

### Weekly Activity Monitor
- Command: `/grok weekly`
- Context includes separate progress for M+ (Activities), Raid, and World vaults.
- When available, reward item names (via `C_WeeklyRewards.GetItemHyperlink`) are included.
- Asks Grok to summarize and suggest priorities.

### Gear Upgrade Suggestions
- Command: `/grok gear`
- Asks Grok for the most impactful upgrades based on current equipped gear and item level.

### Profession Advice
- Command: `/grok profession` (or `/grok prof`)
- Asks Grok for weekly profession priorities based on current skill levels.

### Persistent Per-Character Notes
- Commands:
  - `/grok note add <text>` — add a note
  - `/grok note list` — show notes for the current character
  - `/grok note clear` — clear notes
- Stored in `WoWGrokAssistantDB.notes` (SavedVariables), keyed by character-realm.
- Notes are automatically included in the context sent to Grok.
- Limited to 10 notes per character.

### Basic Map / Route Helper
- Command: `/grok map`
- Uses current zone and asks Grok for practical activity / route suggestions.
- Full pathing is limited by 12.1 API restrictions; this is zone-context only.

## Usage

1. Ensure bridge is running and addon is loaded.
2. Examples:
   ```
   /grok weekly
   /grok gear
   /grok map
   /grok profession
   /grok note add farm M+ 8+ for vault
   /grok note list
   ```

## Notes

- These features reuse the existing Grok pipeline and context collection.
- Optional API key backend is available in the bridge (`XAI_API_KEY` env var).
- Notes and chat history persist across sessions via SavedVariables.
- Chat UI has minor visual polish (backdrop color, title color, size).
