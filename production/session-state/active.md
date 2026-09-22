# Active Session State

*Updated: 2026-09-22 (post /test-setup + LCD spike + Device Frame GDD)*

## Current Task

**PATH DECISION 2026-09-22 — compressed design → code.** User asked how close the project is to implementation; answer was "not close" (stage=Concept, 8 of 10 MVP GDDs not started, no architecture, no tests, no src). User chose the **compressed path** over the full template path and over code-first, and chose **accept-with-notes** over further review cycles.

The compressed plan (≈10–12 sessions to first production code, vs ~30+ on the full path):

1. **DONE 2026-09-22** — close Pet Definition Data and Time Service as *Approved (accepted with notes)*; all open review blockers converted to Open Questions in the GDDs with owners and target resolution points.
2. **DONE 2026-09-22** — `/test-setup` (project.godot + gdUnit4 v6.2.1 + runner + CI, 12/12 green) and the **LCD rendering spike** (verdict: SubViewport; `DrawableTexture2D` rejected).
3. Batch-author the remaining 8 MVP GDDs at **reduced depth** — one authoring pass, one `/design-review` each, accept-with-notes. Detailed Rules / Formulas / Acceptance Criteria are what `/dev-story` consumes and get full attention; Player Fantasy and Tuning Knobs stay thin. Order per systems-index: Device Frame & Button Input (3) → Need System (4) → Save & Persistence (5) → Life Stage & Growth (6) → LCD Screen Renderer (7) → Care Actions (8) → Offline Time Simulation (9) → Pet Animation & Reactions (10).
4. **Minimal architecture** — 3 ADRs only: (a) LCD rendering approach, (b) save format + schema versioning + catalog wiring/immutability (PDD OQ#1/#2), (c) time/event injection. Skip the full traceability matrix and `/architecture-review` for now.
5. `/create-epics` → `/create-stories` → `/dev-story` on the foundation layer.


## NEXT SESSION — `/design-review design/gdd/device-frame-button-input.md`

**Run it in a FRESH session.** The reviewer must not inherit this authoring
context or independent critique is impossible.

After the review, continue step 3 of the compressed plan: the next system in
design order is **Need System (4)**.

## Device Frame & Button Input GDD (DONE 2026-09-22 — authored, NOT reviewed)

`design/gdd/device-frame-button-input.md` — all 11 sections, 0 placeholders.
Status: **Designed** (pending review). Reduced depth per the compressed path:
Detailed Rules / Formulas / Acceptance Criteria at full depth; Player Fantasy
and Tuning Knobs thin.

### The decision that shaped it
The concept's two constraints were **arithmetically incompatible**: 4 care
actions and "any care action reachable in <=3 presses". Under cycle-then-select
item *k* costs `k+1` presses, so only the first two items can ever fit.

**Resolved by making C cycle backwards**, turning the menu into a ring and
halving worst-case distance — which fits <=3 exactly at **3 ring items, not 4**:
- `ring_distance = min((to-from) mod n, (from-to) mod n)`
- `press_cost = ring_distance + 2` → **2 or 3 for n=3; 4 at n=4 (breaks)**
- **`n <= 3` is therefore a CONSTRAINT, not a tuning knob.**

Buttons: **A = next, B = select, C = previous.** `CONFIRM` is the single modal
state where the ring is suspended and C means cancel (for graduation).

### Two consequences other GDDs must accept
1. **Lights on/off is reclassified** from a care action (game-concept.md line 75
   lists it as one of four) to a **contextual device toggle** on B in `IDLE`
   while the pet is sleepy. Either the concept is updated, or **Care Actions must
   accept it**. Do not let this drift.
2. **Care Actions must not add a ring item.** A fourth breaks the press budget.
   Registered in the entity registry against `press_cost` so `/consistency-check`
   will catch it.

### Provisional assumptions (undesigned dependencies)
- Need System exposes an **urgency ranking** — used to place the cursor on open.
- `LCD_W`/`LCD_H` assumed **64x64**; LCD Screen Renderer owns the real value.
- Care Actions' Play mini-game input model is unresolved; anything beyond the
  three buttons collides with Core Rule 1.

### Registry
3 new formulas registered, sourced to this GDD: `ring_distance`, `press_cost`
(constraint-bearing), `lcd_scale`.

### Still the top open risk
**Haptics have never run on a real phone.** Signature verified against 4.7.1,
but per-platform `amplitude` support is unknown and triad sync is unvalidated on
glass. Underpins Pillar 1. Graceful degradation is designed in (Core Rule 10),
so it cannot block MVP — only weaken it. On-device spike before Vertical Slice.

## LCD rendering spike (DONE 2026-09-22) — verdict: Approach A

`prototypes/lcd-rendering-spike/` — REPORT.md carries the full rationale.
**Decision: SubViewport at LCD resolution + pixel-grid shader.** Feeds ADR (a).

- **`DrawableTexture2D` is REJECTED, and the reason is not performance.** It is a
  **blit target, not a canvas**: `blit_rect` / `blit_rect_multi` only, with **no
  `draw_*` API at all**. Everything composited into it must already be a
  `Texture2D` — no `AnimatedSprite2D`, no `Tween`, no `Label`. That is fatal for a
  panel that owns the HUD, menu cursor and pet animation.
- **Our own engine-reference docs were wrong about this** and said Option B worked
  "if all drawing is done via `draw_*` calls" — the exact thing it cannot do.
  Corrected in `modules/rendering.md`, `deprecated-apis.md`, `current-best-practices.md`.
- **Approach C (direct sprites, no intermediate texture) produced NO pixel grid.**
  A `Control`'s material does not apply to its children. General rule: **the grid
  shader requires the LCD contents flattened into one texture first.** Only found
  by looking at the screenshots — frame times were excellent and nothing errored.
- **Performance did not separate A from B** (240-246 vs 240-297 fps, run-to-run
  noise; 11 vs 6 draw calls, both far under the 50 budget). B repainting every
  frame was also unmeasurable. Desktop only — **nothing has run on the Android target.**
- **Gotcha**: `setup()` takes `DrawableTexture2D.DrawableFormat`, not `Image.Format`.
- **Gotcha**: `SubViewportContainer.stretch = true` alone resizes the viewport to
  the container, defeating low-res rendering. `stretch_shrink` is the real knob.

### Constraint this hands to the Device Frame GDD
**The LCD's on-screen rect must be an exact integer multiple of the LCD resolution**
(spike used 64x64 at x6 = 384x384). Non-integer scale makes the grid shimmer.
This collides with safe-area layout on notched phones and 4.7's `expand` stretch
default — the device frame must snap the panel to the largest integer multiple
that fits and absorb the remainder in the shell, not scale to fill.

## Test infrastructure (DONE 2026-09-22, `/test-setup`)

Verified by execution, not scaffolded: **12/12 tests green, exit 0**; deliberately
broken assertion returns **exit 100**, so the CI gate actually gates.

- **`project.godot`** now exists at the repo root — this is the real Pocket Pal
  project (720x1280 portrait, mobile renderer, `canvas_items`/`expand`,
  `handheld/orientation=1`). `.gdignore` files keep Godot out of `docs/`,
  `design/`, `production/`, `prototypes/`, `tmp/` and the template dir.
- **gdUnit4 v6.2.1** vendored at `addons/gdUnit4/` from `godot-gdunit-labs/gdUnit4`.
- **`tests/gdunit4_runner.gd`** — wrapper for the pinned CI command. Three
  non-obvious things it handles, all found by running it rather than reading docs:
  1. gdUnit4 v6 **refuses `--headless`** by default → must pass `--ignoreHeadlessMode`.
  2. The real entry point is `addons/gdUnit4/bin/GdUnitCmdTool.gd`; the skill
     template's `addons/gdunit4/GdUnitRunner.gd` is stale for v6.
  3. gdUnit4's arg parser **discards every token up to one containing
     `GdUnitCmdTool.gd`**, so a synthetic arg vector must start with that sentinel
     or the parser silently prints its help screen instead of running.
- **`.github/workflows/tests.yml`** — triggers on `master` (not `main`), uses
  `godot-gdunit-labs/gdUnit4-action@v1.3.2` pinned to gdUnit4 `v6.2.1` to match
  the vendored copy. **Bump both together.** Second job: `clock-discipline`.
- **Evidence path deviation**: manual evidence goes to `production/qa/evidence/`
  per coding-standards, not the skill template's `tests/evidence/`. Noted in
  `tests/README.md`.

### Time Service blockers closed this session
- **AC #2** rewritten — the real one-second wall-clock sleep is gone; monotonicity
  is proven by advancing the injected clock.
- **AC #9** rewritten — split into a determinism test plus the `clock-discipline`
  CI lint gate, which fails the build on any engine clock API in `src/` outside
  `src/core/time/system_time_source.gd`. **That filename is now part of the contract.**
- **New open question raised**: `TimeSource` must also expose
  `get_timezone_bias_minutes()`, not just `get_unix_time()` — otherwise
  `get_local_calendar_date()` reads the machine's real timezone and every
  calendar-day assertion is non-deterministic across machines. → time/event injection ADR.

### Note for /dev-story on Time Service
`tests/unit/time_service/time_service_contract_test.gd` is **specification-first**:
it runs against a reference implementation declared inside the test file, because
Time Service has no production code yet. When implementing, change **one line** —
the `ServiceUnderTest` constant — to preload the real script. Every assertion
carries over. Do not fork the tests.

## Progress
- [x] /start — stage=Concept, review-mode=solo
- [x] /brainstorm — design/gdd/game-concept.md written (Pocket Pal)
- [x] /setup-engine — Godot 4.7.1 / GDScript; CLAUDE.md, technical-preferences.md, engine-reference docs updated to 4.7
- [x] /prototype device-button-feel — PROCEED (prototypes/device-button-feel-concept/REPORT.md)
- [x] /design-review game-concept.md — NEEDS REVISION, revised 2026-09-18
- [x] /map-systems — systems-index.md (16 systems, design order set)
- [x] /design-system time-service + /design-review — **Approved (accepted with notes)**, 6 blockers → Open Questions
- [x] /design-system pet-definition-data + /design-review ×2 — **Approved (accepted with notes)**, 5 blockers + 10 recommended → Open Questions #8–#13
- [x] /test-setup — project.godot, gdUnit4 v6.2.1, tests/, gdunit4_runner.gd, CI + clock-discipline gate. **12/12 green, exit 0 verified**
- [x] LCD rendering spike — **Approach A (SubViewport) chosen**; DrawableTexture2D rejected (blit-only). Feeds ADR (a)
- [x] Device Frame & Button Input GDD (system 3) — authored, **pending `/design-review`**
- [ ] 7 remaining MVP GDDs (systems 4–10), reduced depth  **<- NEXT** (next: Need System)
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
- design/gdd/time-service.md — **Approved (accepted with notes)**; 6 ex-blockers in its Open Questions subsection, **2 of them closed 2026-09-22** (AC#2, AC#9)
- project.godot, addons/gdUnit4/ (v6.2.1), tests/{README.md,gdunit4_runner.gd,unit/time_service/,integration/,smoke/}, .github/workflows/tests.yml
- design/gdd/pet-definition-data.md — **Approved (accepted with notes)**; OQ#8–#13 carry the 5 blockers + 10 recommended
- design/gdd/reviews/{time-service,pet-definition-data,game-concept}-review-log.md — full audit trail incl. 2026-09-22 dispositions
- design/gdd/systems-index.md — PDD → Approved (with notes); 2 docs approved, 2/10 MVP
- design/gdd/game-concept.md (revised 2026-09-18)
- design/registry/entities.yaml — 1 entity (bloop); 4 formulas (elapsed_seconds, is_new_calendar_day, care_action_share, total_arc_days)
- production/stage.txt — `Concept`
- production/review-mode.txt — `solo`
- CLAUDE.md, .claude/docs/technical-preferences.md
- docs/engine-reference/godot/ — VERSION.md, breaking-changes, deprecated-apis, best-practices, modules/*
- prototypes/device-button-feel-concept/, prototypes/lcd-rendering-spike/, prototypes/index.md
- docs/engine-reference/godot/ — rendering.md, deprecated-apis.md, current-best-practices.md **corrected 2026-09-22** (DrawableTexture2D)

## Open Questions

**Technical unknowns that need code, not documents — highest priority:**
- ~~LCD rendering approach unvalidated~~ **RESOLVED 2026-09-22** — Approach A (SubViewport). Residual: **on-device perf of the render target on a tile-based mobile GPU is untested**; so is whether the flicker reads as "warm LCD" or "broken screen" on a real phone.
- Haptic sync on a real device (`vibrate_handheld` amplitude support per platform) — untested; blocks finalising the Device Frame GDD
- Local-notification plugin still unidentified for 4.7 — gates the Vertical Slice tier (Daily Notification). Scope fallback: ship the slice without it
- Verify for 4.7 (see docs/engine-reference/godot/modules/mobile-export.md): `NOTIFICATION_APPLICATION_PAUSED/_RESUMED`, iOS signing, safe-area API

**Routed into GDD Open Questions (owners and targets live in the GDDs now):**
- Time Service: bounded timestamp domain, anchor-timestamp contract, DST limitation, AC#2/AC#9 rewrites, section rename
- Pet Definition Data: OQ#1/#2 → the save/catalog ADR (storage format, schema versioning, wiring/injection, Core Rule 3 immutability enforcement); OQ#3–#5 → LCD Renderer / Need System / Life Stage & Growth sessions; OQ#8–#12 → the five accepted blockers; OQ#13 → the 10 recommended items backlog
- ADR inputs from godot-specialist (2026-09-22): nested definitions Resource vs plain data; export inclusion of manifest-driven dynamic resource paths in the mobile PCK (silent-drop risk); `SpriteFrames` as sprite_set type + frame-size validation cost; verify for 4.7: `make_read_only()`, `StringName == String` key equality, `@export var id: StringName`

**Planning:**
- 3-week MVP estimate was set top-down — verify via `/sprint-plan` once epics exist
