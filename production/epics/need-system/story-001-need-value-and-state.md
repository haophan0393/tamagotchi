# Story 001: Need anchors, need_value and derived state

> **Epic**: Need System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/need-system.md`
**Requirement**: `TR-need-system-002`, `-003`, `-004`, `-006`, `-008`, `-010`, `-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: ADR-0001: Time and Event Injection (primary); ADR-0002: Pet Catalog Loading, Injection and Immutability
**ADR Decision Summary**: `NeedSystem` is a plain `RefCounted` constructed as `_init(time: TimeService, needs: NeedProfile, care: CareProfile)`; it never reads the wall clock, never touches an Autoload or the scene tree, and holds no engine `Timer`.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: 4.7 — every typed-return method must return on every path. `clamp()` with mixed `int`/`float` args widens implicitly but raises unsafe-cast warnings under static typing — cast bounds explicitly (`float(floor)`, `100.0`).

**Control Manifest Rules (this layer)**:
- Required: constructor injection only; time comes from the injected `TimeService`
- Forbidden: `autoload_access_from_logic`; `engine_timer_in_logic` (no Timer, no `_process`, no per-frame decay); engine clock APIs (`clock-discipline` CI)
- Guardrail: value is computed on read — nothing accumulates

---

## Acceptance Criteria

*From GDD `design/gdd/need-system.md` Acceptance Criteria, scoped to this story:*

**Enum and scale**
- [ ] (Enum criterion is proven by Pet Definition Data Story 001 — `Need.Id` is reused, not redefined here)
- [ ] Any valid anchor/elapsed input → `need_value()` returns a `float` with `floor ≤ value ≤ 100`

**`need_value`**
- [ ] `anchor=100`, `decay=3.0`, `elapsed=0`, called twice → both exactly `100.0`
- [ ] `anchor=100`, `decay=3.0`, `elapsed=72000` → `40.0`
- [ ] `anchor=100`, `decay=3.0`, `elapsed=1800` → `98.5` (an `elapsed / 3600` implementation must fail this)
- [ ] sleep: `anchor=100`, `decay=1.5`, `elapsed=86400` → `64.0`
- [ ] `elapsed=157680000` (~5 years) → exactly `float(floor)`
- [ ] `floor=0`, `elapsed=0`, corrupted `anchor=150` → `100.0`; corrupted `anchor=-20` → `0.0`
- [ ] `anchor=70`, `anchor_utc` 3600 s ahead of the fake clock → `70.0`
- [ ] `floor == sad_threshold == 40`, `anchor=100`, `decay=3.0`, sampled at `71999` and `72000` → `CONTENT` then `AT_FLOOR`, no `SAD` observed

**State derivation**
- [ ] `anchor=100`, `decay=3.0`, `threshold=40`, sampled at `71999`, `72000`, `72001` → `CONTENT`, `SAD`, `SAD` (compare with `<=`, not `==`)
- [ ] decay to exactly `floor` (with `floor < sad_threshold`) → `AT_FLOOR`
- [ ] `floor=50`, `sad_threshold=40`, need at floor → `CONTENT`, never `AT_FLOOR`, never both
- [ ] an instance built only from a persisted anchor pair, queried at three fake-clock times → each state matches `need_value` at that time (recomputed, never cached)
- [ ] `is_sad(need)` is true for both `SAD` and `AT_FLOOR`

**Construction (approved 2026-09-23, provisional)**
- [ ] A newly constructed `NeedSystem` anchors every need at `anchor_value = 100.0`, `anchor_utc = time.get_now_utc()`

---

## Implementation Notes

*Derived from ADR-0001 §2, ADR-0002 §5 and the GDD's Implementation notes:*

- File: `src/gameplay/needs/need_system.gd`, `class_name NeedSystem extends RefCounted`. Add `enum State { CONTENT, AT_FLOOR, SAD }` on the class (e.g. `NeedSystem.State`).
- Per-need storage: two fields, `anchor_value: float` and `anchor_utc: int`, for each `Need.Id` — e.g. a small inner class `NeedAnchor` or two typed arrays indexed by `Need.Id`. This is in-memory runtime state, not a definition, so the `DefinitionResource` rules don't apply.
- Formula, written exactly: `clampf(anchor_value - params.decay_per_hour * (float(time.get_elapsed_seconds(anchor_utc)) / 3600.0), float(params.floor), 100.0)`.
- State precedence, first match wins: `value > float(sad_threshold)` → `CONTENT`; `value == float(floor)` → `AT_FLOOR` (safe float equality **only** because `clampf` returns the exact bound); else `SAD`.
- Public read API for this story: `get_value(need: Need.Id) -> float`, `get_state(need: Need.Id) -> State`, `is_sad(need: Need.Id) -> bool`. Keep `need_value` as a private helper taking an anchor and params so the formula is testable at arbitrary inputs.
- Clock rollback needs no defence here — `TimeService.get_elapsed_seconds()` already clamps to 0. Don't add a second guard (GDD Edge Cases).
- The "fresh pet at 100 now" default is **provisional**: Save & Persistence's anchor contract may change it. Keep it in one place in `_init()`.
- Tests construct `NeedSystem` with `FakeTimeSource` → `TimeService`, and profiles from `tests/helpers/pet_data_factory.gd`. No scene tree, no Autoload (ADR-0001 Validation Criteria).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `apply_care`, re-anchoring, signals
- Story 003: `seconds_until_sad`, `next_crossing_utc`, urgency ranking
- Story 004: crossing detection
- Story 005: reading and loading the anchor set

---

## QA Test Cases

*From the GDD's Acceptance Criteria (qa-lead consulted at GDD authoring, lean mode). The developer implements against these — do not invent new test cases during implementation.*

Setup for every case: `FakeTimeSource` at `t=0`, `TimeService` on it, a factory `NeedProfile` overridden per case; the need under test anchored at `t=0` unless stated. "Elapsed = e" means `fake.advance(e)`.

- **AC-1** Range: for anchors `{-20, 0, 40, 100, 150}` × elapsed `{0, 1800, 72000, 157680000}`, every `get_value` is a `float` in `[floor, 100]`
- **AC-2** No drift: `anchor=100`, `decay=3.0`, elapsed 0 → two reads both `== 100.0`
- **AC-3** 20 h: elapsed 72000 → `40.0`
- **AC-4** Sub-hour: elapsed 1800 → `98.5`
- **AC-5** Sleep: `decay=1.5`, elapsed 86400 → `64.0`
- **AC-6** Five years: elapsed 157680000 → `float(floor)`
- **AC-7** Corrupt anchors: `150` → `100.0`; `-20` → `0.0` (elapsed 0, floor 0)
- **AC-8** Rollback: `anchor=70`, `anchor_utc = now + 3600` → `70.0`
- **AC-9** Collapsed band: `floor=40`, `threshold=40` → states at 71999 / 72000 are `CONTENT` / `AT_FLOOR`
- **AC-10** Threshold edge: states at 71999 / 72000 / 72001 are `CONTENT` / `SAD` / `SAD`
- **AC-11** At floor: `floor=0`, `threshold=40`, elapsed ≥ 120000 → `AT_FLOOR`
- **AC-12** Floor above threshold: `floor=50`, `threshold=40`, decayed to 50 → `CONTENT`
- **AC-13** Recomputed state: one instance, read at elapsed 0, 72000, 120000 → `CONTENT`, `SAD`, `AT_FLOOR`
- **AC-14** `is_sad`: true for `SAD` and `AT_FLOOR`, false for `CONTENT`
- **AC-15** Fresh pet: construct at fake `t=5000` → every need `get_value == 100.0` and its anchor time is `5000`

Note: the GDD Edge Case `floor == 100` and `sad_threshold == 100` data are excluded by the amended PDD validator (Pet Definition Data Story 003) and aren't tested here — except the `sad_threshold=100` case, which Story 002 documents.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/need_system/need_value_and_state_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Time Service Story 002 (`TimeService`, `FakeTimeSource`) and Pet Definition Data Story 002 (`NeedProfile`, `CareProfile`, `Need.Id`, factory) must be DONE
- Unlocks: Stories 002, 003, 004, 005
