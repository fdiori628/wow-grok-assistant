# Phase 1: Full Round-Trip (Pixel Out + Slot In)

## What was implemented

### Outbound (addon → bridge)
- Pixel strip encoding + pixel-perfect drawing (already done)

### Inbound (bridge → addon)
- `bridge/setup-slots.js` generates LoadOnDemand slot addons (`WoWGrok_S001` …)
- Bridge writes the same echo reply into every slot's `Inbox.lua`
- Addon polls by calling `C_AddOns.LoadAddOn` on unused slots and looks for a matching `id` in `WoWGrok_SlotData.replies`
- On match, prints the reply in chat and hides the strip

## Setup (required once)

1. Generate the slot addons **before** starting the client (or fully restart after copying):
   ```bash
   node bridge/setup-slots.js --addons "C:\\Program Files (x86)\\World of Warcraft\\_retail_\\Interface\\AddOns" --slots 20
   ```
2. Fully quit and relaunch WoW so it discovers the new slot addons.
3. On the AddOns screen, leave the `WoWGrok_S###` entries enabled.
4. Set the environment variable (or edit the default in `bridge.js`):
   ```bash
   set WOW_ADDONS=C:\\Program Files (x86)\\World of Warcraft\\_retail_\\Interface\\AddOns
   ```

## Test the round-trip

1. Start the bridge:
   ```bash
   node bridge/bridge.js
   ```
2. In game (windowed/borderless):
   ```
   /grok hello world
   ```
3. Expected:
   - Bridge prints `[decoded] id=N text="hello world"` then `[slots] wrote echo reply...`
   - Shortly after, the addon prints `Reply id=N: echo: hello world` and hides the strip.

## Notes

- Slot files must exist at client launch (WoW only discovers addon files at startup).
- Each slot can be loaded only once per UI session. The bridge writes to all of them so any unused slot works.
- Signals (WAV) are not yet implemented; polling is used instead. This is sufficient for Phase 1.
- Echo mode only — no real Grok call yet.

Next: Phase 2 (Grok CLI / API integration + character context).
