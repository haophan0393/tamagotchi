# Epic: Time Service

> **Layer**: Foundation
> **GDD**: design/gdd/time-service.md
> **Architecture Module**: `src/core/time/` (clock abstraction and service) + `src/core/app/` (composition root and lifecycle adapter). *No `docs/architecture/architecture.md` exists (compressed path, 2026-09-22) — module boundaries are taken from ADR-0001 §1–4.*
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories time-service`

## Overview

Implements the single injectable source of "now" for the whole game: an abstract
`TimeSource` (UTC epoch seconds plus timezone bias in minutes east of UTC), the
production `SystemTimeSource` (the only file allowed to call engine clock APIs),
the test-only `FakeTimeSource`, and the stateless `TimeService` exposing the four
GDD operations. Because ADR-0001 fixes the wiring for every later system, this
epic also carries the minimal app scaffolding that wiring needs: the `TimeProvider`
Autoload, the `GameRoot` composition root (main scene), and the `AppLifecycle`
adapter with the single ordered resume handler. Later epics add their systems to
`GameRoot`; this epic establishes it.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Time and Event Injection | Constructor injection into `RefCounted` logic classes, wired by one `GameRoot`; typed signals on logic classes; `AppLifecycle` maps PAUSED/RESUMED + FOCUS_* to two edge-detected signals | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-time-service-001 | Four operations; non-negative elapsed clamp; no other system reads the engine clock | ADR-0001 §1 ✅ |
| TR-time-service-002 | Injectable `TimeSource` (two-method contract); `SystemTimeSource` sole clock caller; `FakeTimeSource` test-only | ADR-0001 §1 ✅ |
| TR-time-service-003 | `TimeProvider` Autoload holds one production instance; only `GameRoot` reads it | ADR-0001 §2 ✅ |
| TR-time-service-004 | No gameplay policy in Time Service | GDD rule — no architectural decision needed |
| TR-time-service-005 | `AppLifecycle` → `app_backgrounded` / `app_resumed`; one ordered resume handler in `GameRoot` | ADR-0001 §4 ✅ |

## Carried Constraints and Checks

- **Before the first story's code** (ADR-0001 Verification #4, #5, local 4.7.1):
  a body-less `@abstract func` compiles; a `class_name` script in `tests/helpers/`
  and an inner class can both `extends TimeSource`. Fallback if either fails:
  plain base class whose methods `push_error()` and `return 0` (interface unchanged).
  Correct `docs/engine-reference/godot/current-best-practices.md` once confirmed.
- **Existing test**: `tests/unit/time_service/time_service_contract_test.gd` is
  specification-first. Implement by changing the one `ServiceUnderTest` line to
  preload the real script, and move its inner fake to
  `tests/helpers/fake_time_source.gd`. Do not fork the tests.
- **CI**: the `clock-discipline` job exempts only `src/core/time/system_time_source.gd`
  — that path is part of the contract. ADR-0001 Risks adds a second grep:
  `TimeProvider` may appear only under `src/core/app/` and `src/core/time/`.
- **Resume-order slots**: `offline_sim.reanchor_with_cap()` and the save-on-background
  call are no-op slots until Offline Time Simulation and ADR-0003 exist.
- **Before this epic closes (on device)** — ADR-0001 Verification #1–#3:
  PAUSED/RESUMED fire on Android and iOS for home, app switcher and lock screen
  and reach a non-root child `Node`; the sign of `Time.get_time_zone_from_system().bias`
  checked independently on Android and iOS (godot#37571); a one-shot `Timer` expired
  during suspension does not burst on resume.
- **Open GDD questions not blocking this epic**: bounded timestamp domain and the
  anchor-timestamp contract (→ ADR-0003 / Save GDD); DST limitation wording.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/time-service.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- The on-device checks above are recorded in `production/qa/evidence/`

## Next Step

Run `/create-stories time-service` to break this epic into implementable stories.
