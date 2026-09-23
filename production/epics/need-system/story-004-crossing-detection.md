# Story 004: Crossing detection: check_crossings and on_resumed

> **Epic**: Need System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (~2 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/need-system.md`
**Requirement**: `TR-need-system-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: ADR-0001: Time and Event Injection
**ADR Decision Summary**: Crossing detection is a pure, idempotent `check_crossings()` in the logic layer; `on_resumed()` is the single resume entry point; only the `NeedCrossingScheduler` adapter (Story 006) touches an engine Timer.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: None beyond Story 001's. No engine timing is involved in this story by design.

**Control Manifest Rules (this layer)**:
- Required: detection is state-based, not event-based — a late or dropped check is caught by the next one
- Forbidden: `engine_timer_in_logic`
- Guardrail: `last_observed_state` is in-memory only — never persisted

---

## Acceptance Criteria

*From GDD `design/gdd/need-system.md` Acceptance Criteria (Crossing detection) and Core Rule 14:*

- [ ] hunger anchored at `t=0`, `anchor=100`, `decay=3.0`, `threshold=40`; `check_crossings()` at `71999`, then `72000`, then `72000` again → `need_became_sad(hunger)` emitted exactly once, on the second call
- [ ] hunger `CONTENT` at its anchor, clock advanced `0 → 100000` with no intervening check (simulated suspension); `on_resumed()` → `need_became_sad(hunger)` exactly once; a second `on_resumed()` at the same time emits nothing
- [ ] a need that crossed while unobserved, re-anchored above `sad_threshold` by care before any check → a later `check_crossings()` emits no `need_became_sad` for it
- [ ] `last_observed_state` is initialised on construction (and on anchor-set load, Story 005) to the state of `anchor_value` itself, and reset on every re-anchor

---

## Implementation Notes

*Derived from GDD Core Rule 14 and ADR-0001 §4–5:*

- Add `signal need_became_sad(need_id: Need.Id)` and a per-need `_last_observed: State`.
- `check_crossings() -> void`: for each need, compute the current state; if `_last_observed == CONTENT` and the current state is `SAD` or `AT_FLOOR`, emit `need_became_sad`; then set `_last_observed` to the current state. A `SAD → AT_FLOOR` move emits nothing (not a new crossing).
- `on_resumed() -> void`: calls `check_crossings()`. Nothing else — Offline Time Simulation's cap runs **before** it, from `GameRoot` (ADR-0001 §4).
- Extend Story 002's `_reanchor()` to set `_last_observed` to the new state.
- Initialisation uses the state *of `anchor_value` itself* (value at elapsed 0), not the state at `now` — otherwise a crossing that happened before construction (a load after a long absence) would be swallowed instead of reported on the first check.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: the scheduler node, its Timer, and `GameRoot` calling `on_resumed()` from the resume handler
- Offline Time Simulation: `reanchor_with_cap()`

---

## QA Test Cases

*From the GDD's Acceptance Criteria (qa-lead consulted at GDD authoring, lean mode). The developer implements against these — do not invent new test cases during implementation.*

Setup: `FakeTimeSource` at `t=0`, `TimeService`, factory profiles, `monitor_signals(needs)`.

- **AC-1** Exactly once: checks at 71999, 72000, 72000 → one `need_became_sad(HUNGER)`, emitted by the 72000 call
- **AC-2** Resume after suspension: advance to 100000, `on_resumed()` → one emission; second `on_resumed()` → none
  - Edge case: at 100000 hunger is `AT_FLOOR` (≈ 33 h); still exactly one emission, and a later check emits nothing more
- **AC-3** Cared before check: advance to 100000, `apply_care(FEED)` (restore 100), then `check_crossings()` → no emission for hunger
- **AC-4** Initialisation from anchor: construct with hunger's anchor at `t=0`, clock already at 100000 → first `check_crossings()` emits `need_became_sad(HUNGER)` once
- **AC-5** Independence: only hunger crosses (others have lower decay) → only hunger is emitted; a later crossing of fun emits only fun

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/need_system/crossing_detection_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001 and 002 must be DONE
- Unlocks: Story 006
