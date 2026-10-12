# Phase 1: Pixel Encoding & Screen Capture Decoding

## What was implemented

### Addon side
- `addon/WoWGrokAssistant/Codec.lua`  
  Pure-Lua encoder: magic `0xC7 0x1A`, 16-bit id, 16-bit length, payload, Fletcher-16 checksum.  
  Bytes packed MSB-first into 3-bit cells (R/G/B fully on/off).

- `addon/WoWGrokAssistant/WoWGrokAssistant.lua`  
  On `/grok <text>` it encodes the message and draws a 4	imes4-pixel cell strip in the top-left corner of the UI.  
  `/grok hide` hides the strip.  
  Message ids are persisted in SavedVariables.

### Bridge side
- `bridge/capture.ps1`  
  Windows PowerShell script that finds the `Wow` process, captures the top-left client area, samples cell centers, and emits JSON lines with `{id, text}` (or info/warn).

- `bridge/bridge.js`  
  Spawns `capture.ps1` and pretty-prints decoded messages.

## How to test

1. Copy the `addon/WoWGrokAssistant` folder into your retail `Interface/AddOns/`.
2. Restart WoW (or `/reload` after first install), enable the addon.
3. Set the game to **windowed** or **borderless windowed** (exclusive fullscreen will not work).
4. In a terminal inside the `bridge/` folder:
   ```bash
   node bridge.js
   ```
5. In game type:
   ```
   /grok hello world
   ```
6. The bridge should print something like:
   ```
   [decoded] id=1 text="hello world"
   ```

## Notes / Limitations (Phase 1)

- Windows only for the capture script (Linux/macOS later).
- Scale is approximate; on high-DPI or unusual UI scales the cells may not align perfectly. The original projects use a more precise `768 / physicalHeight` scale.
- No ACK, no slot pool, no Grok call yet — this is only the outbound pixel channel.
- Strip stays visible until you `/grok hide`.

Next phases will add the inbound slot pool and the actual Grok integration.
