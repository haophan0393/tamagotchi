# Story 004: AppLifecycle adapter and resume/background handler slots

> **Epic**: Time Service
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S–M (~2–3 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: 2026-09-23

## Context

**GDD**: `design/gdd/time-service.md` (Open Question on `PAUSED`/`RESUMED`); `design/gdd/need-system.md` Core Rule 14 (resume order)
**Requirement**: `TR-time-service-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Time and Event Injection
**ADR Decision Summary**: One `AppLifecycle` node maps `PAUSED` + `FOCUS_OUT` → `app_backgrounded` and `RESUMED` + `FOCUS_IN` → `app_resumed`, edge-detected so each transition emits once; `GameRoot._on_app_resumed()` is the single definition of resume order.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: `NOTIFICATION_APPLICATION_PAUSED` / `_RESUMED` exist in 4.7 but fire on Android and iOS only; `FOCUS_IN` / `FOCUS_OUT` make desktop and editor runs behave the same. Propagation of these notifications to a **non-root child** is inferred, not documented — verified on device in Story 005. `Node.notification(what)` dispatches to `_notification()`, which is how the tests deliver them.

**Control Manifest Rules (this layer)**:
- Required: `AppLifecycle` contains no logic and no time reads; it only translates notifications into two signals
- Forbidden: `global_event_bus`; `engine_timer_in_logic`
- Guardrail: iOS allows ~5 s after `PAUSED`, so whatever fills the background slot later must be synchronous and small

---

## Acceptance Criteria

*From ADR-0001 §4, scoped to this story:*

- [x] `src/core/app/app_lifecycle.gd` — `class_name AppLifecycle extends Node` with `signal app_backgrounded` and `signal app_resumed`
- [x] `PAUSED` alone, `FOCUS_OUT` alone, and `PAUSED` + `FOCUS_OUT` in either order each emit `app_backgrounded` exactly once; the same holds for `RESUMED` / `FOCUS_IN` → `app_resumed`
- [x] A repeated resume notification with no background in between emits nothing
- [x] `AppLifecycle` is a child of `GameRoot` in `GameRoot.tscn`, and `GameRoot` connects both signals to `_on_app_backgrounded()` / `_on_app_resumed()`
- [x] `GameRoot._on_app_resumed()` contains the three ordered slots from ADR-0001 §4 — (1) `offline_sim.reanchor_with_cap(...)`, (2) `needs.on_resumed()`, (3) `crossing_scheduler.rearm()` — as no-ops with comments until those systems exist; `_on_app_backgrounded()` contains the save-request slot (ADR-0003)

---

## Implementation Notes

*Derived from ADR-0001 §4 and Risks:*

- A private `_in_background: bool = false` does the edge detection: background notification → if not already `true`, set it and emit; resume notification → if `true`, clear it and emit. That is the whole class.
- Start in the foreground (`false`), so a spurious `FOCUS_IN` at launch emits nothing.
- A spurious resume (focus flicker) reaching `GameRoot` is harmless by design: `on_resumed()` → `check_crossings()` is idempotent (Need System GDD). Don't add debouncing.
- Slot order is fixed and must not be reordered: the offline cap re-anchors **before** `on_resumed()` checks crossings, and the scheduler re-arms last.
- Fallback if Story 005 finds notifications don't reach a non-root child: move `_notification()` into `GameRoot` itself; the two signals and every consumer stay the same.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: proving the notifications fire on real Android and iOS devices
- Need System epic: filling slots (2) and (3), and the resume-order test with real collaborators
- Offline Time Simulation (no GDD yet): slot (1)
- ADR-0003 / Save & Persistence: the background save slot

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: background translation, single notification
  - Given: a fresh `AppLifecycle` in the tree, with signal monitoring (`monitor_signals`)
  - When: `notification(NOTIFICATION_APPLICATION_PAUSED)`
  - Then: `app_backgrounded` emitted exactly once, `app_resumed` not emitted
  - Edge cases: same with `NOTIFICATION_APPLICATION_FOCUS_OUT` alone
- **AC-2**: double delivery is edge-detected
  - Given: a fresh `AppLifecycle`
  - When: `PAUSED` then `FOCUS_OUT` (and, in a second test, `FOCUS_OUT` then `PAUSED`)
  - Then: `app_backgrounded` emitted exactly once
- **AC-3**: resume translation
  - Given: an `AppLifecycle` that has received `PAUSED`
  - When: `RESUMED` then `FOCUS_IN`
  - Then: `app_resumed` emitted exactly once
- **AC-4**: no resume without a background
  - Given: a fresh `AppLifecycle` (foreground)
  - When: `FOCUS_IN`, then `RESUMED`
  - Then: nothing emitted
- **AC-5**: full cycle repeats
  - Given: a fresh `AppLifecycle`
  - When: background → resume → background → resume
  - Then: two `app_backgrounded` and two `app_resumed`, alternating
- **AC-6**: GameRoot wiring
  - Given: `GameRoot.tscn` instantiated in the tree
  - When: its `AppLifecycle` child receives `PAUSED` then `RESUMED`
  - Then: `_on_app_backgrounded()` then `_on_app_resumed()` run once each with no errors (spy on the handlers, or have each set a test-visible counter)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/time_service/app_lifecycle_test.gd` — must exist and pass

**Status**: [x] Created — 9 tests, passing

---

## Dependencies

- Depends on: Story 003 must be DONE
- Unlocks: Story 005; Need System epic's resume-wiring story

---

## Completion Notes
**Completed**: 2026-09-23
**Criteria**: 5/5 passing (none deferred)
**Test-Criterion Traceability**: AC-1 through AC-4 COVERED by direct tests; AC-5 (ordered no-op resume slots) UNTESTED — no observable side effect exists to assert until the Need System epic supplies real collaborators (Out of Scope, acknowledged in the story itself). 1/5 untested (20%) — ADVISORY, does not block.
**Deviations**: None (implementation matches ADR-0001 §4 and TR-time-service-005 exactly; no forbidden patterns, no hardcoded values, no out-of-scope files touched)
**Test Evidence**: Integration — `tests/integration/time_service/app_lifecycle_test.gd` (9 tests); full suite 34/34 pass
**Code Review**: Complete — `/code-review` APPROVED WITH SUGGESTIONS (2026-09-23). godot-specialist: CLEAN, no on-device-risk resolution beyond ADR framing. godot-gdscript-specialist: 2 WARN, both fixed (`@onready` node ref; typed `Dictionary[String, int]`). qa-tester: 3 coverage gaps found, 2 fixed (added FOCUS_IN-before-RESUMED test; wrapped AC-6 notification calls in `assert_error().is_success()`, probe-verified with a planted `push_error` → test failed, exit 100). Remaining gap: AC-6 handler *order* is not asserted (gdUnit4 has no in-order verify in this version) — only holds by construction of the test's call order.
**Engine note**: on-device propagation of `NOTIFICATION_APPLICATION_*` to a non-root child `Node` remains unverified (ADR-0001 Risks) — Story 005's job, not this one.
