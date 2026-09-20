# Active Session State

*Updated: 2026-09-19*

## Current Task
/design-system pet-definition-data — IN PROGRESS. Skeleton created at design/gdd/pet-definition-data.md (2026-09-19). Sections done: A Overview, B Player Fantasy (anchor: Discovery), C Detailed Rules (palette per species + form override; uniform animation core set, egg exempt; ordered share-threshold form rules + default; care restore/sad thresholds per species; MVP arc egg0/baby3/child4/adult2 ≈9 days; species bloop, forms bloop_playful/bloop_cozy provisional). Current section: D Formulas. Scope decision: PDD owns identity + ALL pet tunables (decay rates, stage thresholds, form rule table, palettes, animations). Review mode: solo. Context/feasibility brief given: Foundation layer, no upstream deps, 6 direct dependents (all undesigned) — highest fan-out GDD in the project; Godot Resource/.tres as data, definitions immutable/shared-by-reference, typed Dictionary (4.4) + duplicate_deep (4.5) flagged MEDIUM knowledge gaps; storage format/schema versioning → ADR.

/design-review design/gdd/time-service.md — DONE 2026-09-19: NEEDS REVISION (6 blocking, 7 recommended; scope S). User accepted as-is; systems-index marked "Approved (as-is)"; log at design/gdd/reviews/time-service-review-log.md. Open blocking items to re-check when Save & Persistence / Life Stage & Growth / Offline Sim are designed: bounded timestamp domain (int64 wrap), anchor-timestamp data contract, false DST claim, AC #2 wall-clock sleep, AC #9 unfalsifiable → CI lint gate, section rename "Detailed Rules".

## Prototype: device-button-feel
- **Hypothesis:** If the player taps the three round device buttons, each press will feel tactile and satisfying — confirmed if a first-time tester presses a button repeatedly/playfully without being asked to, within the first 30 seconds.
- **Riskiest assumption (test first):** haptic + audio + visual sync — do press-down, haptic pulse, and beep read as one unified click?
- **Path:** Engine (Godot 4.7.1, GDScript) — feel is timing-sensitive; browser latency would lie.
- **Scope:** 3 round buttons on plain shell-colored background; on press → offset_transform press-down, vibrate_handheld, synthesized square-wave beep; on release → spring back. Press counter + 30s timer for the measurable signal.
- **Cut:** pet, LCD/menu logic, needs, life stages, shell art, save, offline sim, mini-game.
- **Dir:** prototypes/device-button-feel-concept/ (project.godot, main.tscn, main.gd, README.md)
- **Verified 4.7.1 APIs (via godot --doctool):** Input.vibrate_handheld(duration_ms:int=500, amplitude:float=-1.0); Control.offset_transform_{enabled,position,scale,pivot_ratio,visual_only}
- **Iteration log:**
  - round 0 (2026-09-18): files written; headless + windowed runs clean (no script errors). Awaiting user run/observations.
  - round 1 (2026-09-18): user ran on desktop — runs fine, press visual + beep feel synced. Haptic (riskiest assumption) still untested — needs phone deploy.
  - debrief (2026-09-18): hypothesis CONFIRMED (desktop), worst moment none, verdict PROCEED. Phone test skipped this round. REPORT.md + prototypes/index.md written. CD-PLAYTEST skipped — Solo mode.

## Progress
- [x] /start — stage=Concept, review-mode=solo
- [x] /brainstorm — design/gdd/game-concept.md written (Pocket Pal)
- [x] /setup-engine — Godot 4.7.1 / GDScript; CLAUDE.md, technical-preferences.md, engine-reference docs updated to 4.7
- [x] /prototype device-button-feel — PROCEED (prototypes/device-button-feel-concept/REPORT.md)
- [x] /design-review design/gdd/game-concept.md — NEEDS REVISION, revised 2026-09-18 (log: design/gdd/reviews/game-concept-review-log.md)
- [x] /map-systems — systems-index.md written (16 systems; order: Time Service → Pet Definition Data → Device Frame → Need → Save → Growth → LCD → Care → Offline Sim → Pet Animation → …)
- [ ] /gate-check systems-design (optional director sign-off)
- [ ] /art-bible (Candy Gadget anchor)
- [x] /design-system time-service — COMPLETE (design/gdd/time-service.md, Status: Designed, pending review)
- [x] /design-review design/gdd/time-service.md — NEEDS REVISION, accepted as-is (2026-09-19)
- [~] /design-system pet-definition-data — IN PROGRESS (skeleton created 2026-09-19; next: Section A Overview)

## Key Decisions
- Concept: colorful skeuomorphic Tamagotchi device on phone; 3 round buttons + boxy LCD
- Forgiving real-time, no death (graduation + album), once-a-day 1–3 min sessions
- Life stages egg→baby→child→adult over check-in days (absent days pause growth); adult form selected by care *style* over a rolling window — never cumulative/consistency (Pillar 2)
- Offline sim: UTC epoch, elapsed clamped [0, MAX_OFFLINE], needs-only; growth never advances offline; long absence → warm greeting, never penalty
- Shells earned, never sold; price model (premium vs free-no-IAP) still open before v1.0
- Core hypothesis falsifiable: ≥70% of 8–10 testers reopen next day unprompted; <50% falsifies
- Visual channel must carry the full experience alone (sound/haptics amplify)
- Three buttons = pillar; cycle-then-select = default not pillar; ≤3 presses to any care action
- Systems index: Life Stage & Growth is Core and owns the care-history log; Device Frame owns feedback flags (Settings writes one-way — resolves the only cycle)
- Roadmap layers (post-MVP): device shells, personality quirks, extra species
- Platform: iOS/Android portrait. Engine: Godot 4.7.1 (machine install, Homebrew), GDScript, gdUnit4. Solo, first game, ~7–8 weeks to v1.0

## Files
- design/gdd/time-service.md (Approved as-is 2026-09-19 — 6 review blockers still open, see review log)
- design/gdd/pet-definition-data.md (IN PROGRESS — skeleton only)
- design/gdd/reviews/time-service-review-log.md
- design/registry/entities.yaml (2 formulas registered: elapsed_seconds, is_new_calendar_day)
- design/gdd/game-concept.md (revised 2026-09-18)
- design/gdd/systems-index.md (Time Service marked Designed, 1/10 MVP)
- design/gdd/reviews/game-concept-review-log.md
- production/stage.txt (Concept)
- production/review-mode.txt (solo)
- CLAUDE.md (Technology Stack)
- .claude/docs/technical-preferences.md
- docs/engine-reference/godot/ (VERSION.md, breaking-changes, deprecated-apis, best-practices, modules/*, new modules/mobile-export.md)
- prototypes/device-button-feel-concept/ (throwaway — never import into src/; REPORT.md = verdict)
- prototypes/index.md

## Open Questions
- Haptic sync on device (riskiest assumption from /prototype) — untested; close on Android/iOS before finalising the button-input GDD and any ADR relying on vibrate_handheld amplitude
- Verify for 4.7 before architecture (see docs/engine-reference/godot/modules/mobile-export.md): local-notification plugin, suspend/resume notifications, iOS signing, safe-area API. (vibrate_handheld signature now verified — see Prototype section; amplitude support per-platform still to be tested on device)
- Local-notification plugin still unidentified for 4.7 — gates the Vertical Slice tier (Daily Notification system); spike during architecture → ADR
- LCD rendering approach unvalidated (SubViewport + shader vs DrawableTexture2D) — spike before LCD Screen Renderer GDD Formulas section
- 3-week MVP estimate set top-down — verify via /sprint-plan
