# Story 003: TimeProvider Autoload and GameRoot composition root

> **Epic**: Time Service
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (~3 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: 2026-09-23

## Context

**GDD**: `design/gdd/time-service.md`
**Requirement**: `TR-time-service-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Time and Event Injection
**ADR Decision Summary**: A `TimeProvider` Autoload builds one `TimeService(SystemTimeSource.new())` and exposes it read-only; `GameRoot`, the main scene's root, is the only script that reads it and constructs every logic object in dependency order.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: Autoloads are registered in `project.godot` under `[autoload]` with a leading `*` for a singleton instance. Main scene is `application/run/main_scene`. Confirm the gdUnit4 v6.2.1 headless runner (`tests/gdunit4_runner.gd`) loads project Autoloads during a test run — if it doesn't, the integration test must add a `TimeProvider` instance itself and the AC is proven by boot instead.

**Control Manifest Rules (this layer)**:
- Required: `GameRoot` is the single composition root; adding a system means editing only `src/core/app/game_root.gd`
- Forbidden: `autoload_access_from_logic` — `TimeProvider` may be named only under `src/core/app/` and `src/core/time/`; `global_event_bus`
- Guardrail: `TimeProvider` holds nothing but the one service

---

## Acceptance Criteria

*From GDD `design/gdd/time-service.md` AC #10 and ADR-0001 §2 / Risks / Validation Criteria:*

- [x] AC #10 — on boot, the `TimeProvider` Autoload exposes exactly one `TimeService` instance wired to `SystemTimeSource`, reachable from any scene-tree node without constructing its own
- [x] `TimeProvider.service` is read-only (assigning to it is rejected)
- [x] `src/core/app/GameRoot.tscn` (root `GameRoot`, script `src/core/app/game_root.gd`) is set as the main scene and boots headless without errors
- [x] New CI step: fails the build if `TimeProvider` appears in any `.gd` under `src/` outside `src/core/app/` and `src/core/time/`; proven by planting a reference in `src/gameplay/` locally and seeing it fail (ADR-0001 Validation Criteria)

---

## Implementation Notes

*Derived from ADR-0001 §2 and Risks:*

- `src/core/time/time_provider.gd` — a `Node` that builds its `TimeService` in `_init()` (not `_ready()`), so it exists before any other node's `_ready()`. Expose it as `var service: TimeService` with a getter-only property (the setter `push_error`s and ignores). The Autoload **name** `TimeProvider` must not collide with a `class_name` — don't give the script `class_name TimeProvider`.
- `src/core/app/game_root.gd` — `class_name GameRoot extends Node`. In `_ready()` it reads `TimeProvider.service` once into a local and is the only script that does. For this story it holds just that reference. Later epics add the catalog load (Pet Definition Data) and `NeedSystem` construction here. Leave a short ordered comment block listing the construction order from ADR-0001 so later stories slot in.
- CI: add the `TimeProvider` grep as a step in the existing `clock-discipline` job in `.github/workflows/tests.yml` (or a sibling job), following the same `VIOLATIONS=… || true` pattern. Error message should cite ADR-0001 and the `autoload_access_from_logic` pattern.
- `tests/` is excluded from the grep, like the clock lint.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: `AppLifecycle` node and the resume/background handlers on `GameRoot`
- Pet Definition Data epic: catalog load in `GameRoot._ready()`
- Need System epic: `NeedSystem` / `NeedCrossingScheduler` construction and wiring

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: one production instance on the real clock
  - Given: the project's Autoloads loaded (headless test run)
  - When: `TimeProvider.service` is read twice from two different nodes
  - Then: it is a `TimeService`, both reads are the same object (`is_same`), and its source `is SystemTimeSource`
  - Edge cases: the service is non-null in the earliest `_ready()` (built in `_init()`)
- **AC-2**: read-only property
  - Given: `TimeProvider.service`
  - When: test code assigns a new `TimeService` to it
  - Then: the original instance is unchanged and an error is logged
- **AC-3**: GameRoot boots
  - Given: `GameRoot.tscn`
  - When: instantiated and added to the tree in a test
  - Then: `_ready()` completes with no errors and `GameRoot` holds the `TimeProvider.service` instance
- **AC-4**: `TimeProvider` lint
  - Given: a throwaway `src/gameplay/_lint_probe.gd` containing `TimeProvider.service`
  - When: the new CI step's grep runs locally
  - Then: it exits non-zero naming the file; after deleting the probe it exits 0. Record both outputs in the story completion notes (the probe is never committed)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/time_service/time_provider_test.gd` — must exist and pass

**Status**: [x] Created — 3 tests, passing

---

## Dependencies

- Depends on: Story 002 must be DONE
- Unlocks: Story 004; Pet Definition Data epic's catalog-load story

---

## Completion Notes
**Completed**: 2026-09-23
**Criteria**: 4/4 passing (none deferred)
**Deviations**:
- ADVISORY — AC-1 test reads `TimeService._source` via `.get("_source")` instead of a public accessor (keeps `TimeService` unchanged; a rename would fail the test quietly rather than at compile time).
- ADVISORY — the `TimeProvider` CI lint is a plain name grep and also matches comments; it may fire on cross-reference docs elsewhere in `src/`. Strict on purpose per ADR-0001; add comment exclusion if it gets noisy.
**Test Evidence**: Integration — `tests/integration/time_service/time_provider_test.gd` (3 tests); full suite 25/25 pass; `godot --headless --quit-after 60` boots clean
**Code Review**: Complete — `/code-review` CHANGES REQUIRED → fixed → APPROVED (2026-09-23). Fixes: hand-typed `GameRoot.tscn` uid (failed `ResourceUID` round-trip) replaced with generated `uid://bkplynyfn5rs5` in scene and `run/main_scene`; setter params renamed `_value`; `GameRoot.time_service` setter now `push_error`s; AC-1 reads from nodes' own `_ready()`; AC-3 asserts no pushed errors (proven by a planted `push_error` making it fail).
**Engine note**: gdUnit4 v6.2.1's headless runner loads project Autoloads (verified on 4.7.1) — the Engine Notes fallback was not needed.

**AC-4 lint proof** (step logic extracted from `.github/workflows/tests.yml`, run locally):

With `src/gameplay/_lint_probe.gd` containing `TimeProvider.service`:
```
::error::TimeProvider referenced outside src/core/app and src/core/time.
ADR-0001 §2: only the composition root (GameRoot) may read
TimeProvider.service — the autoload_access_from_logic forbidden
pattern. Logic classes must receive TimeService via _init().
Offending lines:
src/gameplay/_lint_probe.gd:4:	var x = TimeProvider.service
EXIT CODE: 1
```
After deleting the probe:
```
OK — no TimeProvider access outside src/core/app and src/core/time.
EXIT CODE: 0
```
