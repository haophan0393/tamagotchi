# Story 006: NeedCrossingScheduler and GameRoot wiring

> **Epic**: Need System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (~3–4 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/need-system.md` (Core Rule 14 adapter; Interactions table)
**Requirement**: `TR-need-system-014`, `TR-need-system-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: ADR-0001: Time and Event Injection (primary); ADR-0002: Pet Catalog Loading, Injection and Immutability
**ADR Decision Summary**: `GameRoot` builds `NeedSystem` from the loaded species' profiles and a `NeedCrossingScheduler` node that arms one one-shot Timer for the soonest crossing; the resume handler runs cap → `on_resumed()` → `rearm()`.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: `Timer.start(time_sec)` resets a running timer, so no `stop()` first. `one_shot = true`. A `Timer` measures a *delay* and never reads the clock, so it's lint-compliant. During OS suspension no frames run — the Timer says nothing about elapsed wall time (ADR-0001 Risks). Tests assert `wait_time` / `is_stopped()` and emit `timeout` by hand; they never wait on real time.

**Control Manifest Rules (this layer)**:
- Required: the scheduler arms only — no rules; `GameRoot` is the only place that wires collaborators
- Forbidden: `engine_timer_in_logic` (the Timer lives in the adapter only); `autoload_access_from_logic`
- Guardrail: `wait_time ≥ 1.0` s

---

## Acceptance Criteria

*From ADR-0001 §4–5 and GDD Core Rule 14:*

- [ ] `NeedCrossingScheduler` (`src/gameplay/needs/need_crossing_scheduler.gd`, `extends Node`) with one child one-shot `Timer`; `setup(needs: NeedSystem, time: TimeService)` is called before `add_child`
- [ ] `rearm()` takes the soonest non-`-1` `next_crossing_utc()` across the four needs and starts the Timer with `wait_time = maxf(1.0, float(next_utc - time.get_now_utc()))`; if every need returns `-1` it calls `stop()`
- [ ] On `timeout`: `needs.check_crossings()`, then `rearm()`
- [ ] `GameRoot` constructs `NeedSystem(time_service, species.need_profile, species.care_profile)` from the catalog's bloop species, after the catalog load and before any other logic object that needs it
- [ ] `GameRoot` calls `crossing_scheduler.rearm()` after every `need_changed`
- [ ] `GameRoot._on_app_resumed()` fills slots (2) `needs.on_resumed()` and (3) `crossing_scheduler.rearm()`, in that order after the still-empty slot (1)

---

## Implementation Notes

*Derived from ADR-0001 §2, §4, §5 and ADR-0002 §5:*

- Per-pet consumers receive profiles, not the catalog (ADR-0002 §5). Which species `GameRoot` uses is a **temporary choice**: the first hatchable species (bloop) until Save & Persistence supplies the live pet's species id. Mark it `# TEMP until Save & Persistence`.
- `GameRoot` also holds the scheduler node as a child, created in code or placed in `GameRoot.tscn` — either is fine; document which.
- If a need is already sad, `next_crossing_utc()` returns `now`, giving `wait_time = 1.0` — the timer fires once, `check_crossings()` observes the state, and the next `rearm()` moves on to the next crossing. Make sure that doesn't loop: an already-sad need must not keep re-arming a 1 s timer forever. **Resolve by skipping needs whose `get_state()` is not `CONTENT`** when choosing the soonest crossing — confirm this matches ADR-0001's intent ("next downward crossing") and note it in the completion notes.
- The resume-order test replaces the three collaborators with spies (subclasses or stub objects that record calls into a shared list) and asserts the recorded order.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: the on-device ADVISORY check
- Offline Time Simulation: slot (1)
- Save & Persistence: the live pet's species id and anchor load at boot

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted). The developer implements against these — do not invent new test cases during implementation.*

Setup: `FakeTimeSource` at `t=0`, factory profiles, a `NeedSystem`, a scheduler added to the test tree via `add_child` after `setup()`.

- **AC-1** Arms for the soonest crossing: all needs at 100, hunger decay 3.0 (crosses at 72000), others slower → after `rearm()`, the Timer is running with `wait_time == 72000.0`
- **AC-2** Minimum wait: a need crossing 0.4 s from now (fractional via decay) → `wait_time == 1.0`
- **AC-3** Nothing to arm: every need has `floor > sad_threshold` → after `rearm()`, the Timer `is_stopped()`
- **AC-4** Already-sad needs are skipped: hunger already `SAD`, fun crosses at 30000 → `wait_time == 30000.0` (not 1.0)
  - Edge case: all four already sad → Timer stopped
- **AC-5** Timeout path: advance the fake clock to 72000, emit the Timer's `timeout` → `need_became_sad(HUNGER)` emitted once; the Timer is re-armed for the next crossing
- **AC-6** Re-arm after care: after AC-5, `apply_care(FEED)` through `GameRoot`'s wiring → `rearm()` ran (wait time now points to hunger's new crossing, 72000 s from now)
- **AC-7** Resume order: `GameRoot._on_app_resumed()` with spy collaborators → recorded calls `[on_resumed, rearm]` (slot 1 empty), never reversed
- **AC-8** Boot wiring: `GameRoot.tscn` instantiated → it holds a `NeedSystem` whose `get_value(HUNGER)` is `100.0` and whose decay matches bloop's `need_profile.hunger.decay_per_hour` (3.0)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/need_system/need_wiring_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 002, 003, 004 must be DONE; Time Service Story 004 (resume handler) and Pet Definition Data Story 007 (catalog load in `GameRoot`) must be DONE
- Unlocks: Story 007
