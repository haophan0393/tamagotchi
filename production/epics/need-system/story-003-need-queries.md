# Story 003: Queries: seconds_until_sad, next_crossing_utc, urgency ranking

> **Epic**: Need System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S–M (~2–3 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/need-system.md`
**Requirement**: `TR-need-system-011`, `TR-need-system-014` (query half)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: ADR-0001: Time and Event Injection
**ADR Decision Summary**: `next_crossing_utc()` is the pure query the `NeedCrossingScheduler` adapter arms its one Timer from; all time comes from the injected `TimeService`.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: Typed return `Array[Need.Id]` — **verify on 4.7.1 that an enum-typed `Array` compiles and that `append`/sort work on it**. If it doesn't, use `Array[int]` and record the choice here and in the GDD's Interactions table on next touch. `ceili()` returns `int`; a truncating `int()` is the trap. 4.7 typed-return rule: early `return`s followed by one unconditional final `return`.

**Control Manifest Rules (this layer)**:
- Required: pure queries — no state change, no signal emission
- Forbidden: `engine_timer_in_logic`
- Guardrail: the sentinel contract (`0` = already sad, `-1` = never) is part of the interface — no null, no error

---

## Acceptance Criteria

*From GDD `design/gdd/need-system.md` Acceptance Criteria, scoped to this story:*

**`seconds_until_sad` and `next_crossing_utc`**
- [ ] `v0 ≤ sad_threshold` → `0`
- [ ] `floor=50`, `sad_threshold=40`, any value → `-1`
- [ ] `floor == sad_threshold == 40`, `v0=100`, `decay=3.0` → `72000`, not `-1`
- [ ] `v0=100`, `threshold=40`, `decay=7.0` (exact `30857.14…`) → `30858` (a truncating `int()` returning `30857` must fail)
- [ ] need anchored at `t=1000`, `anchor=100`, `decay=3.0`, `threshold=40`, clock at `1000` → `next_crossing_utc()` returns `73000`; for `floor > sad_threshold` it returns `-1`

**Urgency ranking**
- [ ] hunger=10 and fun=25 `SAD`, cleanliness `CONTENT`, sleep `AT_FLOOR`(0) → `get_urgency_ranking()` returns `[sleep, hunger, fun]`
- [ ] two sad needs at an identical value → ordered by enum index (hunger < cleanliness < fun < sleep)
- [ ] no need sad → an empty typed array, never null

---

## Implementation Notes

*Derived from the GDD Formulas and Implementation notes:*

- `seconds_until_sad(need: Need.Id) -> int`, written as early returns:
  ```
  v0 = get_value(need); S = float(sad_threshold); F = floor; d = decay_per_hour
  if v0 <= S: return 0
  if F > sad_threshold: return -1
  return ceili((v0 - S) / d * 3600.0)
  ```
  No `d > 0` guard — PDD's validator guarantees `decay_per_hour ≥ 0.01` (amended Rule 12), which also bounds the result to ≤ ~3.6 × 10⁷ s.
- `next_crossing_utc(need: Need.Id) -> int`: `-1` if `seconds_until_sad` is `-1`; else `time.get_now_utc() + seconds_until_sad(need)`. When already sad this returns `now` (GDD Core Rule 14).
- `get_urgency_ranking() -> Array[Need.Id]`: collect needs where `is_sad()`, sort with a custom comparator — by `get_value()` ascending, then by enum index. `sort_custom` with a stable tie-break on the index; don't rely on sort stability.
- Read values once per call (compute into a local list first) so all comparisons use the same `now`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: the scheduler that consumes `next_crossing_utc()`
- Device Frame (in revision): cursor placement from the ranking, including the empty and sleep-first cases
- Daily Notification (Vertical Slice): scheduling from `seconds_until_sad`

---

## QA Test Cases

*From the GDD's Acceptance Criteria (qa-lead consulted at GDD authoring, lean mode). The developer implements against these — do not invent new test cases during implementation.*

Setup: `FakeTimeSource`, `TimeService`, factory profiles overridden per case.

- **AC-1** Already sad: hunger at 40 (threshold 40) → `0`; at 10 → `0`
- **AC-2** Never: `floor=50`, `threshold=40` at values 100 and 50 → `-1` both
- **AC-3** Collapsed band: `floor=40`, `threshold=40`, `v0=100`, `decay=3.0` → `72000`
- **AC-4** Ceiling: `decay=7.0` → `30858`
  - Edge case: an exact result (`decay=3.0` → `72000`) is not rounded up to `72001`
- **AC-5** Absolute crossing: anchored at `t=1000`, clock `1000` → `73000`; `floor > threshold` → `-1`
  - Edge case: already sad at clock `t` → returns `t`
- **AC-6** Ranking: hunger 10, fun 25, cleanliness 90, sleep 0 (`AT_FLOOR`) → `[SLEEP, HUNGER, FUN]`
- **AC-7** Ties: hunger and fun both at exactly 20.0 → `[HUNGER, FUN]`; cleanliness and sleep both at 0 → `[CLEANLINESS, SLEEP]`
- **AC-8** Empty: all `CONTENT` → `[]`, `is_empty()`, not `null`, typed
- **AC-9** Purity: calling all three queries emits no signal and leaves every anchor unchanged

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/need_system/need_queries_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE
- Unlocks: Story 006
