# Active Session State

*Updated: 2026-09-23 (epics created; ADRs 0001–0002 Accepted)*

## NOW — SHORTCUT TO CODE (decided 2026-09-23)
User chose to start code on the three approved systems (Time Service, Pet Definition Data, Need System) before the remaining GDDs are done.
Save & Persistence GDD is PAUSED at section D (Formulas) — resume later; ADR-0002 may need a revision once it is approved.

Shortcut plan:
1. **DONE 2026-09-23** — ADR-0001 time & event injection → docs/architecture/adr-0001-time-and-event-injection.md (Proposed). Time Service GDD Core Rule 2 synced (constructor injection); 2 OQs marked resolved.
   - Pre-/dev-story checks owed (local 4.7.1): body-less `@abstract func` compiles; `extends TimeSource` works from tests/helpers/ and from an inner class. A compile probe was denied — run it manually or approve it.
   - On-device checks owed: PAUSED/RESUMED fire + reach a child Node; tz `bias` sign on Android AND iOS (godot#37571); stale Timer on resume.
   - Registry updated 2026-09-23 (2 state, 3 interfaces, 3 forbidden patterns).
2. **DONE 2026-09-23** — ADR-0002 pet catalog loading, injection & immutability → docs/architecture/adr-0002-pet-catalog-loading-and-immutability.md (Proposed). `.tres` Resources + CatalogManifest (ext_resource refs); pure CatalogValidator; injected `strict` build-type flag; PetCatalog lookups return null; setter guards + recursive lock(); CI lint for SpriteFrames mutators / duplicate() / pet-data load(). NeedSystem._init(time, need_profile, care_profile). PDD GDD synced (Rules 3, 13; 2 ACs; OQ#1 half, #2, #9 resolved). Registry updated (+1 state, +1 interface, +1 api, +4 forbidden).
   - Pre-/dev-story checks owed (local 4.7.1): Object.set() hits setters on a locked resource; String arg → StringName-keyed dict lookup; make_read_only rejects append/sort.
   - Export checks owed: manifest species included in the PCK with a filtered preset; **on a real device export, catalog READY with ≥1 species** (godot#98798, typed arrays loading empty on export).
3. **DONE 2026-09-23** — `/create-epics`: production/epics/{time-service,pet-definition-data,need-system}/EPIC.md + index.md. Need System is Core layer (built third). User decisions: **ADR-0001 and ADR-0002 → Accepted** (local compile checks become each epic's first story; ADR fallbacks apply if they fail); **tr-registry.yaml seeded with 33 TR-IDs**, one per GDD Core Rule (+ TR-time-service-005 lifecycle). Time Service epic also owns GameRoot/AppLifecycle/TimeProvider scaffolding. Untraced: TR-need-system-013 (Save accessor shape → ADR-0003).
4. **IN PROGRESS** — `/create-stories`: **time-service DONE 2026-09-23 (5 stories: 001 TimeSource+fakes incl. @abstract compile checks, 002 TimeService + contract-test swap (≈4 lines, not 1), 003 TimeProvider+GameRoot+lint, 004 AppLifecycle+resume slots, 005 on-device V1–V3 — needs export presets)**. **pet-definition-data DONE 2026-09-23 (9 stories: 001 enums+DefinitionResource+ADR-0002 V#1–4 probes, 002 schema+factory+reflection test, 003 validator pt1 — first amends PDD Rule 12 with APPROVED wording (floor<sad_threshold<100, decay≥0.01, OQ#8 retired-form, OQ#11 min_share (0,1]), 004 validator pt2 rules+animations, 005 PetCatalog, 006 formulas, 007 bloop content + placeholder sprites via tools/ script + GameRoot load + shipped fixture, 008 CI lint, 009 export V#5–6)**. **need-system DONE 2026-09-23 (7 stories: 001 anchors+need_value+state (fresh pet = 100 at construction — user-approved, provisional), 002 apply_care+signals, 003 queries (verify enum-typed Array[Need.Id] compiles, else Array[int]), 004 crossing detection, 005 anchor copy semantics (provisional names → ADR-0003), 006 scheduler+GameRoot wiring, 007 on-device ADVISORY)**. **All 21 stories written.** ⚠️ ADR-0001 §5 gap found: literal `rearm()` re-arms a 1 s timer forever when a need is already sad (next_crossing_utc returns now) — Story 006 skips non-CONTENT needs; ADR-0001 §5 should be amended. Next: commit, then `/story-readiness` → `/dev-story` on time-service story 001 (pet-definition-data 001 can run in parallel).
   - Previous step-3 notes still apply:
   - Run `/architecture-review` in a FRESH session at some point (never in the authoring session).
   - ADR renumbering: 0003 = save format/versioning (waits on the Save GDD); 0004 = LCD rendering (SubViewport spike).
   - Need System's asks of PDD are still open: validation `floor < sad_threshold < 100`, `decay_per_hour ≥ 0.01`. CatalogValidator implements PDD Rule 12, so fold these into the PDD before the validator story.

## PAUSED — Save & Persistence GDD (5), `/design-system save-persistence`
- File: design/gdd/save-persistence.md — skeleton created
- Review mode: solo (production/review-mode.txt); reduced depth per compressed path
- Current section: Formulas (D)
- Sections done: Overview, Player Fantasy, Detailed Rules (decisions: backup+split album file; quarantine+new egg on catalog miss; write on background + coalesced events)

## CORRECTION 2026-09-22 — Need System was reviewed and REVISED (supersedes the section below)
`/design-review` → NEEDS REVISION → revised same session → **Approved (revised)**. See
design/gdd/reviews/need-system-review-log.md. **Sleep is now PRESS-RESTORED** via
`apply_care(lights)` — no `dark` flag, no `set_dark`, no `recover_per_hour`;
`all_needs_addressed` = every need CONTENT. Core Rule 14 split into pure
`check_crossings()` / `on_resumed()` + `NeedCrossingScheduler` adapter. The
"Sleep is rate-switched" and "Done for today redefined as addressed" notes below are STALE.
design/registry/entities.yaml Need System entries are also stale — fix in the Save GDD's Phase 5b.

## Current Task

**PATH DECISION 2026-09-22 — compressed design → code.** User asked how close the project is to implementation; answer was "not close" (stage=Concept, 8 of 10 MVP GDDs not started, no architecture, no tests, no src). User chose the **compressed path** over the full template path and over code-first, and chose **accept-with-notes** over further review cycles.

The compressed plan (≈10–12 sessions to first production code, vs ~30+ on the full path):

1. **DONE 2026-09-22** — close Pet Definition Data and Time Service as *Approved (accepted with notes)*; all open review blockers converted to Open Questions in the GDDs with owners and target resolution points.
2. **DONE 2026-09-22** — `/test-setup` (project.godot + gdUnit4 v6.2.1 + runner + CI, 12/12 green) and the **LCD rendering spike** (verdict: SubViewport; `DrawableTexture2D` rejected).
3. Batch-author the remaining 8 MVP GDDs at **reduced depth** — one authoring pass, one `/design-review` each, accept-with-notes. Detailed Rules / Formulas / Acceptance Criteria are what `/dev-story` consumes and get full attention; Player Fantasy and Tuning Knobs stay thin. Order per systems-index: Device Frame & Button Input (3) → Need System (4) → Save & Persistence (5) → Life Stage & Growth (6) → LCD Screen Renderer (7) → Care Actions (8) → Offline Time Simulation (9) → Pet Animation & Reactions (10).
4. **Minimal architecture** — 3 ADRs only: (a) LCD rendering approach, (b) save format + schema versioning + catalog wiring/immutability (PDD OQ#1/#2), (c) time/event injection. Skip the full traceability matrix and `/architecture-review` for now.
5. `/create-epics` → `/create-stories` → `/dev-story` on the foundation layer.


## DONE 2026-09-22 — Need System GDD (4) authored, NOT reviewed

`design/gdd/need-system.md` — all 11 sections, 0 placeholders. 14 Core Rules,
32 acceptance criteria (all BLOCKING, all gdUnit4-automatable), 10 Open
Questions. Status in the index: **Designed** (pending review).
Review mode: **lean** — `systems-designer` consulted for Formulas,
`qa-lead` for Acceptance Criteria. CD-GDD-ALIGN skipped (lean).

### NEXT SESSION — `/design-review design/gdd/need-system.md`, in a FRESH session

### The decisions that shaped it

**Lazy anchor evaluation, no tick.** A need stores only `anchor_value` +
`anchor_utc`; the value is COMPUTED ON READ from elapsed time. Consequences:
online/offline/suspended are arithmetically identical, so Offline Time
Simulation implements no second decay path; `seconds_until_sad()` can solve for
the exact crossing moment, which Daily Notification uses to schedule and Need
System itself uses to arm a one-shot crossing timer (Core Rule 14 — there is
still no tick; the timer observes the formula, never advances it).

**Sleep is rate-switched, not press-restored.** Device Frame owns a `dark` flag
and writes it one-way via `set_dark(bool, at_utc)`; while dark, sleep moves
toward 100 at `recover_per_hour`. This resolves the Device Frame ↔ Need System
cycle with the same pattern already used for Device Frame ↔ Settings. Because a
rate change invalidates an anchor, **both edges of the toggle must re-anchor**.

**"Done for today" redefined as *addressed*, not *content*** —
`all_needs_addressed` = every need CONTENT, OR (sleep AND dark). Putting the pet
to bed IS the resolution for sleep. This was forced by `systems-designer`
finding that rate-switched sleep cannot be cleared inside a 1–3 min session,
which contradicted the already-approved Overview. Overview reworded to
"addressable"; signal renamed from `all_needs_content`.

**0–100 scale is now owned by Need System** — closes Pet Definition Data
Open Question #4.

**MVP balance (bloop):** decay 3.0/hr for hunger/cleanliness/fun, sleep 1.5/hr,
recover 5.0/hr, `sad_threshold` 40, `floor` 0, `restore_amount` 100. Sad at 20h,
value 28 at the 24h check-in, floor only at 33h. Derived safe band for
`decay_per_hour` at threshold 40 is **2.5–4.17** — re-tune against that band,
not by feel. Unplaytested.

**GDScript traps caught at design time** (two ACs are written as trap
detectors): `elapsed_seconds / 3600.0` — integer division silently drops
sub-hour decay; and `ceili()` not `int()` for `seconds_until_sad`, so a
notification never fires early.

### What this GDD owes other documents (10 Open Questions)
- **Pet Definition Data** (4): `recover_per_hour` has no schema home;
  `CareProfile.restore_amount` for `lights` is now dead data; load validation
  permits `floor > sad_threshold`, `floor > 100` and `sad_threshold == 100`,
  each of which silently breaks a need; and the "runtime state owned by Save &
  Persistence" wording conflicts with Need System owning the live anchors.
- **Device Frame** (1): empty urgency ranking is undefined — and that is the
  normal state right after a care session. Third item for its revision list.
- **Offline Time Sim / Save & Persistence** (2): `reanchor_with_cap()` and the
  anchor accessor shape are both unspecified.
- **Playtest** (2): balance numbers, and the "relief not guilt" claim which
  depends on Pet Animation's greeting beat.

Registry updated: 4 new formulas (`need_value`, `apply_care`,
`seconds_until_sad`, `all_needs_addressed`), 1 new constant (`need_scale_max`),
bloop need-profile attributes, `elapsed_seconds` referenced_by.
Systems index: row 4 → Designed, plus 3 previously-missing edges added.

## DONE 2026-09-22 — `/design-review design/gdd/device-frame-button-input.md`

Verdict: **NEEDS REVISION** — 11 blocking, 8 recommended. Scope signal M.
Specialists: game-designer, systems-designer, ux-designer, audio-director,
gameplay-programmer, godot-specialist, qa-lead, creative-director (senior).
Full findings: `design/gdd/reviews/device-frame-button-input-review-log.md`.
Systems index row 3 now reads **In Review**. User chose to revise in a separate
session; the 11 items are still open.

The two that matter most, both "a verified claim that isn't":
1. `ring_distance` assumes Euclidean mod, but GDScript `%` is sign-of-dividend —
   at `from=2,to=0,n=3` it yields -2 and `press_cost=0`, making the BLOCKING
   "press_cost <= 3" AC provably true on paper and silently false in code. Needs
   `posmod()` and an AC enumerating all 9 pairs.
2. `DisplayServer.get_display_safe_area()` is cited as settled fact in two ACs
   while `docs/engine-reference/godot/modules/mobile-export.md:43` lists it as
   OPEN for 4.7. Plus a real coordinate-space gap: it returns physical screen
   pixels, but the project's stretch mode is `canvas_items`/`expand`.

Senior rulings to apply during revision: the **ring stays** (add LCD directional
glyphs rather than changing the scheme); **split the mute AC** into an automatable
BLOCKING one plus an advisory human one; and **the tick fires during ACTING** —
*"acknowledgement is unconditional; action is conditional."*

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
