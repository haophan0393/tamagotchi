# Story 002: TimeService production implementation

> **Epic**: Time Service
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (~2 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: 2026-09-23

## Context

**GDD**: `design/gdd/time-service.md`
**Requirement**: `TR-time-service-001`, `TR-time-service-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Time and Event Injection
**ADR Decision Summary**: `TimeService` is a stateless `class_name TimeService extends RefCounted` constructed with a `TimeSource`, exposing the GDD's four operations; `get_local_calendar_date()` applies the **current** bias to any timestamp.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: 4.7 — every method with a typed return must return on every path. `Time.get_datetime_dict_from_unix_time()` is a pure conversion (not a clock read) and is not in the `clock-discipline` pattern.

**Control Manifest Rules (this layer)**:
- Required: constructor injection — `_init(source: TimeSource)`; no Autoload, no `get_tree()`
- Forbidden: `autoload_access_from_logic`; engine clock APIs outside `system_time_source.gd`
- Guardrail: Time Service applies no gameplay policy — no offline cap, no "what a new day means" (Core Rule 3)

---

## Acceptance Criteria

*From GDD `design/gdd/time-service.md` Acceptance Criteria #1–#9, scoped to this story:*

- [ ] AC #1 — `FakeTimeSource` at `1000` → `get_now_utc()` returns `1000`
- [ ] AC #2 — after advancing the fake clock by 1, a second `get_now_utc()` is ≥ the first + 1
- [ ] AC #3 — `since_utc = 1000`, clock `1300` → `get_elapsed_seconds(1000)` returns `300`
- [ ] AC #4 — `since_utc = 1300`, clock `1000` (rolled back) → returns `0`, never negative
- [ ] AC #5 — `since_utc` equal to now → returns `0`
- [ ] AC #6 — two timestamps on the same local date → `is_new_calendar_day` is `false`
- [ ] AC #7 — two timestamps 4 minutes apart across local midnight → `true`
- [ ] AC #8 — two timestamps a full year apart → `true`
- [ ] AC #9 (determinism half) — identical results across three injected timezone offsets, independent of the machine's real clock and timezone
- [ ] `ServiceUnderTest` points at the production script and the reference implementation is deleted from the test file

---

## Implementation Notes

*Derived from ADR-0001 §1 and the existing specification-first test:*

- File: `src/core/time/time_service.gd`, `class_name TimeService extends RefCounted`, `_init(source: TimeSource)`. Hold the source in a private typed field; hold nothing else (stateless).
- The reference implementation in `tests/unit/time_service/time_service_contract_test.gd` (`RefTimeService`) is the contract — port its four method bodies as-is:
  - `get_elapsed_seconds`: `maxi(0, get_now_utc() - since_utc)` — no upper bound (a test pins this)
  - `get_local_calendar_date`: add `bias_minutes * 60` to the timestamp, convert with `Time.get_datetime_dict_from_unix_time()`, return `{"year", "month", "day"}`
  - `is_new_calendar_day`: compare the two local-date dictionaries
- **The test swap is more than one line.** The file's header says "change ONE line", but `RefTimeService` is also used as a type annotation (lines 90 and 106) and `FakeTimeSource` is an inner class. Change `ServiceUnderTest`, both annotations to `TimeService`, delete the `FakeTimeSource` and `RefTimeService` inner classes (the helper from Story 001 replaces the fake), and update the header comment. **Do not change any assertion or fixture constant.**
- DST: the current bias is applied to every timestamp. That DST can't be recovered from an epoch is an accepted limitation (ADR-0001 §1) — don't try to handle it.
- Doc-comment every public method.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `TimeSource` / `FakeTimeSource` (must be DONE first)
- Story 003: AC #10 (`TimeProvider` Autoload)
- Open GDD questions: bounded timestamp domain and input validation (→ Save & Persistence / ADR-0003)

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted). The developer implements against these — do not invent new test cases during implementation.*

These already exist in `tests/unit/time_service/time_service_contract_test.gd` and must pass unchanged against the production class:

- **AC-1**: `test_get_now_utc_returns_injected_time` — Given clock `1000`; When `get_now_utc()`; Then `1000`
- **AC-2**: `test_get_now_utc_advances_with_the_injected_clock` — Given clock `1000`; When read, `advance(1)`, read; Then second ≥ first + 1
- **AC-3**: `test_get_elapsed_seconds_returns_difference` — Given since `1000`, clock `1300`; Then `300`
- **AC-4**: `test_get_elapsed_seconds_clamps_rolled_back_clock_to_zero` — Given since `1300`, clock `1000`; Then `0`
- **AC-5**: `test_get_elapsed_seconds_returns_zero_for_same_instant` — Given since == now; Then `0`
  - Edge case: `test_get_elapsed_seconds_applies_no_upper_bound` — a multi-year gap returns the true value
- **AC-6**: `test_is_new_calendar_day_false_within_one_local_date`
- **AC-7**: `test_is_new_calendar_day_true_across_local_midnight` — fixtures `SEP_18_2358_UTC` → `SEP_19_0002_UTC`
- **AC-8**: `test_is_new_calendar_day_true_across_a_full_year`
  - Edge case: `test_is_new_calendar_day_depends_on_current_timezone` — the same pair of timestamps flips result under a different injected bias
- **AC-9**: `test_results_are_independent_of_real_wall_clock_and_timezone` — UTC, Tokyo (+540), Los Angeles (−480)
  - Fixture guard: `test_fixture_timestamps_land_on_their_documented_local_dates`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/time_service/time_service_contract_test.gd` — must exist and pass (existing file, swapped to production)

**Status**: [x] Passing against production — 12 tests (2026-09-23)

---

## Dependencies

- Depends on: Story 001 must be DONE
- Unlocks: Story 003

---

## Completion Notes
**Completed**: 2026-09-23
**Criteria**: 10/10 passing (all auto-verified; suite 22/22, clock-discipline lint OK)
**Deviations**:
- ADVISORY — `ServiceUnderTest` is `preload("res://src/core/time/time_service.gd")`, not `:= TimeService`: Godot 4.7.1 rejects a global `class_name` as a constant expression (verified by probe). Functionally equivalent.
- ADVISORY — AC #9 test re-derives only elapsed seconds (bias-independent) across the three timezones; the date path is exercised under UTC only. Follow-up: repeat `get_local_calendar_date` under Tokyo/LA.
**Follow-ups from /code-review** (non-blocking): pre-epoch / negative-bias timestamps unpinned by tests (→ ADR-0003 test plan); no null guard on `_init(source)` (low risk — single composition root).
**Test Evidence**: Logic: `tests/unit/time_service/time_service_contract_test.gd`
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (godot-gdscript-specialist + qa-tester)
