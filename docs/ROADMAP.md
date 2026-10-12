# Roadmap

## Phase 0 — Skeleton
- [x] Repository structure
- [x] Basic addon .toc + slash command
- [x] Architecture document

## Phase 1 — Communication
- [x] Pixel strip encoder in the addon
- [x] Pixel-perfect scaling
- [x] Windows screen capture decoder
- [x] Slot pool generation + writer in the bridge
- [x] Basic round-trip: send message → receive echo

## Phase 2 — Grok Integration
- [x] Grok CLI backend (`grok login` + headless)
- [ ] Optional API key backend
- [x] Character context collection (gear, quests, zone)
- [x] In-game chat UI
- [x] Session resume / multi-turn

## Phase 3 — Useful Features
- [x] Weekly activity monitor / reminders (`/grok weekly`)
- [x] Gear upgrade suggestions (`/grok gear`)
- [x] Persistent per-character notes (`/grok note`)
- [ ] Map / route helpers (if feasible under 12.1 restrictions)

## Robustness (post-review)
- [x] Single-slot reply writes (no overwrite races)
- [x] Grok CLI 45s timeout
- [x] Capture process auto-restart
- [x] Pixel sampling ±1 tolerance
- [x] Chat history persistence (last 20)
- [x] `/grok debug` command
- [x] Notes length limit
- [x] Raised MAX_PAYLOAD to 6000

## Notes
- Primary target: retail 12.1 (Interface 120100)
- Windowed / borderless mode required for capture
- Keep the design ToS-friendly (documented APIs only)
