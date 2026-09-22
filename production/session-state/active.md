# Active Session State

*Updated: 2026-09-22*

## Current Task

**PATH DECISION 2026-09-22 — compressed design → code.** User asked how close the project is to implementation; answer was "not close" (stage=Concept, 8 of 10 MVP GDDs not started, no architecture, no tests, no src). User chose the **compressed path** over the full template path and over code-first, and chose **accept-with-notes** over further review cycles.

The compressed plan (≈10–12 sessions to first production code, vs ~30+ on the full path):

1. **DONE 2026-09-22** — close Pet Definition Data and Time Service as *Approved (accepted with notes)*; all open review blockers converted to Open Questions in the GDDs with owners and target resolution points.
2. **NEXT (parallel, not gated on any GDD)** — run `/test-setup` (tests/ scaffold + gdUnit4 runner + CI workflow) and the **LCD rendering spike** (SubViewport+shader vs `DrawableTexture2D`). These two answer the project's biggest technical unknowns and unblock the Time Service AC rewrites.
3. Batch-author the remaining 8 MVP GDDs at **reduced depth** — one authoring pass, one `/design-review` each, accept-with-notes. Detailed Rules / Formulas / Acceptance Criteria are what `/dev-story` consumes and get full attention; Player Fantasy and Tuning Knobs stay thin. Order per systems-index: Device Frame & Button Input (3) → Need System (4) → Save & Persistence (5) → Life Stage & Growth (6) → LCD Screen Renderer (7) → Care Actions (8) → Offline Time Simulation (9) → Pet Animation & Reactions (10).
4. **Minimal architecture** — 3 ADRs only: (a) LCD rendering approach, (b) save format + schema versioning + catalog wiring/immutability (PDD OQ#1/#2), (c) time/event injection. Skip the full traceability matrix and `/architecture-review` for now.
5. `/create-epics` → `/create-stories` → `/dev-story` on the foundation layer.

## Progress
- [x] /start — stage=Concept, review-mode=solo
- [x] /brainstorm — design/gdd/game-concept.md written (Pocket Pal)
- [x] /setup-engine — Godot 4.7.1 / GDScript; CLAUDE.md, technical-preferences.md, engine-reference docs updated to 4.7
- [x] /prototype device-button-feel — PROCEED (prototypes/device-button-feel-concept/REPORT.md)
- [x] /design-review game-concept.md — NEEDS REVISION, revised 2026-09-18
- [x] /map-systems — systems-index.md (16 systems, design order set)
- [x] /design-system time-service + /design-review — **Approved (accepted with notes)**, 6 blockers → Open Questions
- [x] /design-system pet-definition-data + /design-review ×2 — **Approved (accepted with notes)**, 5 blockers + 10 recommended → Open Questions #8–#13
- [ ] /test-setup — tests/unit, tests/integration, gdunit4_runner.gd, .github/workflows/tests.yml
- [ ] LCD rendering spike — SubViewport+shader vs DrawableTexture2D → feeds ADR (a)
- [ ] 8 remaining MVP GDDs (systems 3–10), reduced depth
- [ ] 3 ADRs (LCD rendering, save/catalog, time injection)
- [ ] /create-epics → /create-stories → /dev-story

**Deliberately skipped on the compressed path** (revisit before v1.0, not before first code): `/gate-check`, `/art-bible`, `/review-all-gdds`, full `/create-architecture` + traceability, `/architecture-review`, `/create-control-manifest`, accessibility-requirements.md, interaction-patterns.md, UX specs.

## Prototype: device-button-feel
- **Verdict: PROCEED** (2026-09-18). Hypothesis confirmed on desktop — press visual + beep read as synced.
- **Path**: Engine (Godot 4.7.1, GDScript). Dir: `prototypes/device-button-feel-concept/` — throwaway, never import into src/. REPORT.md = verdict.
- **Verified 4.7.1 APIs** (via `godot --doctool`): `Input.vibrate_handheld(duration_ms:int=500, amplitude:float=-1.0)`; `Control.offset_transform_{enabled,position,scale,pivot_ratio,visual_only}`
- **Still untested**: haptics on a real phone (the riskiest assumption). Desktop cannot test it. Close before the Device Frame GDD is finalised.

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
- Platform: iOS/Android portrait. Engine: Godot 4.7.1 (Homebrew), GDScript, gdUnit4. Solo, first game, ~7–8 weeks to v1.0
- **Process (2026-09-22)**: solo review mode means `/design-review` is advisory. Default disposition is accept-with-notes; blockers become Open Questions resolved at their natural implementation moment. Do not run a GDD through more than one review cycle.

## Files
- design/gdd/time-service.md — **Approved (accepted with notes)**; 6 ex-blockers in its Open Questions subsection
- design/gdd/pet-definition-data.md — **Approved (accepted with notes)**; OQ#8–#13 carry the 5 blockers + 10 recommended
- design/gdd/reviews/{time-service,pet-definition-data,game-concept}-review-log.md — full audit trail incl. 2026-09-22 dispositions
- design/gdd/systems-index.md — PDD → Approved (with notes); 2 docs approved, 2/10 MVP
- design/gdd/game-concept.md (revised 2026-09-18)
- design/registry/entities.yaml — 1 entity (bloop); 4 formulas (elapsed_seconds, is_new_calendar_day, care_action_share, total_arc_days)
- production/stage.txt — `Concept`
- production/review-mode.txt — `solo`
- CLAUDE.md, .claude/docs/technical-preferences.md
- docs/engine-reference/godot/ — VERSION.md, breaking-changes, deprecated-apis, best-practices, modules/*
- prototypes/device-button-feel-concept/, prototypes/index.md

## Open Questions

**Technical unknowns that need code, not documents — highest priority:**
- LCD rendering approach unvalidated (SubViewport + pixel-grid shader vs 4.7's `DrawableTexture2D`). Pillar-1-critical, never prototyped. → spike now, feeds ADR (a) and LCD Screen Renderer's Formulas section
- Haptic sync on a real device (`vibrate_handheld` amplitude support per platform) — untested; blocks finalising the Device Frame GDD
- Local-notification plugin still unidentified for 4.7 — gates the Vertical Slice tier (Daily Notification). Scope fallback: ship the slice without it
- Verify for 4.7 (see docs/engine-reference/godot/modules/mobile-export.md): `NOTIFICATION_APPLICATION_PAUSED/_RESUMED`, iOS signing, safe-area API

**Routed into GDD Open Questions (owners and targets live in the GDDs now):**
- Time Service: bounded timestamp domain, anchor-timestamp contract, DST limitation, AC#2/AC#9 rewrites, section rename
- Pet Definition Data: OQ#1/#2 → the save/catalog ADR (storage format, schema versioning, wiring/injection, Core Rule 3 immutability enforcement); OQ#3–#5 → LCD Renderer / Need System / Life Stage & Growth sessions; OQ#8–#12 → the five accepted blockers; OQ#13 → the 10 recommended items backlog
- ADR inputs from godot-specialist (2026-09-22): nested definitions Resource vs plain data; export inclusion of manifest-driven dynamic resource paths in the mobile PCK (silent-drop risk); `SpriteFrames` as sprite_set type + frame-size validation cost; verify for 4.7: `make_read_only()`, `StringName == String` key equality, `@export var id: StringName`

**Planning:**
- 3-week MVP estimate was set top-down — verify via `/sprint-plan` once epics exist
