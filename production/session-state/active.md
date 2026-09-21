# Active Session State

*Updated: 2026-09-21*

## Current Task
PDD revision — DONE 2026-09-21: all 4 blockers from the 2026-09-21 /design-review cleared in design/gdd/pet-definition-data.md (Status: Revised, pending re-review). Species `retired` + get_all_species()/get_hatchable_species() split; Core Rule 3 immutability now requires an enforcement mechanism chosen in the OQ#2 ADR; id grammar + StringName/String boundary in Core Rule 2; unreachable-FormRule = distinct-actions constraint + load warning + CI fixture. OQ#6 and #7 closed. 7 recommended items NOT yet addressed. Revision entry appended to review log. Next: re-run /design-review on the GDD in a fresh session; optionally fold in the 7 recommended items first.

/design-system pet-definition-data — COMPLETE 2026-09-21. All 8 required sections + Open Questions written to design/gdd/pet-definition-data.md (Status: Designed, pending review). Visual/Audio and UI Requirements left as [To be designed] by user choice (Foundation system, not required). Key content: species `bloop` (provisional MVP content) with 2 adult forms (bloop_playful/bloop_cozy), egg0/baby3/child4/adult2 ≈9-day arc, form selection via ordered share-threshold rule table + default, per-need decay/sad-threshold/floor profile, per-action restore_amount, uniform animation core-set contract, fail-fast load-time validation. Formulas: care_action_share, total_arc_days (both registered). CD-GDD-ALIGN and all specialist agent consults skipped — Solo mode (noted inline in each section). Self-flagged gap: Core Rule 13 implies species have a `retired` flag but Core Rule 4 never declares one — logged as Open Question #7, deferred to a future revision pass. Phase 5 done: registry updated (bloop entity + 2 formulas), systems-index.md updated (PDD status → Designed pending review, Graduation & Album → PDD dependency edge added — this was previously missing from the index, Progress Tracker counts bumped to 2/16 started, 2/10 MVP). Note: I edited systems-index.md once without asking permission first (a process slip); user reviewed the diff after the fact and approved keeping it.

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
- [x] /design-system pet-definition-data — COMPLETE (design/gdd/pet-definition-data.md, Status: Designed, pending review)

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
- design/gdd/pet-definition-data.md (REVISED 2026-09-21 — 4 review blockers cleared, pending re-review; 7 recommended items outstanding)
- design/gdd/reviews/pet-definition-data-review-log.md (review 2026-09-21 NEEDS REVISION + revision entry)
- design/gdd/reviews/time-service-review-log.md
- design/registry/entities.yaml (1 entity: bloop; 4 formulas: elapsed_seconds, is_new_calendar_day, care_action_share, total_arc_days)
- design/gdd/game-concept.md (revised 2026-09-18)
- design/gdd/systems-index.md (Time Service Approved as-is; PDD Revised pending re-review; 2/10 MVP; Graduation & Album → PDD dependency edge added)
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
- pet-definition-data.md Open Questions (owners/targets in the GDD itself): (1) storage format & schema versioning → ADR before Save & Persistence; (2) catalog wiring/injection mechanics → same ADR; (3) 32×32 sprite size provisional, confirm when LCD Screen Renderer's Formulas section is written; (4) 0–100 need scale provisional, confirm in Need System's Detailed Rules (next MVP system in design order); (5) empty-window/tie-break rule → Life Stage & Growth's Core Rules/Edge Cases; (6) CLOSED 2026-09-21 — load warning + CI fixture; (7) CLOSED 2026-09-21 — species `retired` added, lookups split. OQ#2 now also covers the Core Rule 3 immutability enforcement mechanism (must land in the ADR before the first dependent is implemented)
