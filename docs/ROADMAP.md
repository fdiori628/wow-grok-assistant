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
- [ ] Weekly activity monitor / reminders
- [ ] Gear upgrade suggestions
- [ ] Persistent per-character notes
- [ ] Map / route helpers (if feasible under 12.1 restrictions)

## Notes
- Primary target: retail 12.1 (Interface 120100)
- Windowed / borderless mode required for capture
- Keep the design ToS-friendly (documented APIs only)
