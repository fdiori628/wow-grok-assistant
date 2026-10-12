# Phase 3: Useful Features

## Implemented

### Weekly Activity Monitor
- Command: `/grok weekly`
- Builds a focused prompt asking Grok to summarize current weekly progress (from context) and suggest priorities.

### Gear Upgrade Suggestions
- Command: `/grok gear`
- Asks Grok for the most impactful upgrades based on current equipped gear and item level.

### Persistent Per-Character Notes
- Commands:
  - `/grok note add <text>` — add a note
  - `/grok note list` — show notes for the current character
  - `/grok note clear` — clear notes
- Stored in `WoWGrokAssistantDB.notes` (SavedVariables), keyed by character-realm.
- Notes are automatically included in the context sent to Grok.

## Usage

1. Ensure bridge is running and addon is loaded.
2. Examples:
   ```
   /grok weekly
   /grok gear
   /grok note add farm M+ 8+ for vault
   /grok note list
   ```

## Notes

- These features reuse the existing Grok pipeline and context collection.
- Map/route helpers are still pending (may be limited by 12.1 API restrictions).
- Notes persist across sessions via SavedVariables.
