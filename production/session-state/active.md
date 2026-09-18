# Active Session State

*Updated: 2026-09-18*

## Current Task
Concept phase — engine configured (Godot 4.7.1, GDScript). Next: /prototype device-button-feel.

## Progress
- [x] /start — stage=Concept, review-mode=solo
- [x] /brainstorm — design/gdd/game-concept.md written (Pocket Pal)
- [x] /setup-engine — Godot 4.7.1 / GDScript; CLAUDE.md, technical-preferences.md, engine-reference docs updated to 4.7
- [ ] /prototype device-button-feel
- [ ] /art-bible (Candy Gadget anchor)
- [ ] /map-systems

## Key Decisions
- Concept: colorful skeuomorphic Tamagotchi device on phone; 3 round buttons + boxy LCD
- Forgiving real-time, no death (graduation + album), once-a-day 1–3 min sessions
- Life stages egg→baby→child→adult; care quality selects adult form
- Roadmap layers (post-MVP): device shells, personality quirks, extra species
- Platform: iOS/Android portrait. Engine: Godot 4.7.1 (machine install, Homebrew), GDScript, gdUnit4. Solo, first game, ~7–8 weeks to v1.0

## Files
- design/gdd/game-concept.md
- production/stage.txt (Concept)
- production/review-mode.txt (solo)
- CLAUDE.md (Technology Stack)
- .claude/docs/technical-preferences.md
- docs/engine-reference/godot/ (VERSION.md, breaking-changes, deprecated-apis, best-practices, modules/*, new modules/mobile-export.md)

## Open Questions
- Verify for 4.7 before architecture (see docs/engine-reference/godot/modules/mobile-export.md): Input.vibrate_handheld signature, local-notification plugin, suspend/resume notifications, iOS signing, safe-area API
- game-concept.md still references Godot 4.6 in 3 places — update when the concept doc is next revised
