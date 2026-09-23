# Story 001: TimeSource abstraction and test clock

> **Epic**: Time Service
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (~2 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/time-service.md`
**Requirement**: `TR-time-service-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Time and Event Injection
**ADR Decision Summary**: Time is read through an abstract two-method `TimeSource` injected into a plain `RefCounted` `TimeService`; `SystemTimeSource` is the single file allowed to call engine clock APIs, and `FakeTimeSource` is test-only.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: `@abstract` is a 4.5 feature (post-cutoff). ADR-0001 Verification #4 and #5 must be run on local 4.7.1 **before** writing the production files: (4) a body-less `@abstract func get_unix_time() -> int` in an `@abstract` `RefCounted` compiles — the project's `current-best-practices.md` shows abstract methods *with* a `pass` body, which external sources say is a parse error; (5) a `class_name` script in `tests/helpers/` **and** an inner class inside a test suite can both `extends TimeSource`. 4.7 rule: a method with a typed return must return on every path.

**Control Manifest Rules (this layer)**:
- Required: logic classes are `RefCounted` and receive collaborators through `_init()` (ADR-0001 §2)
- Forbidden: `autoload_access_from_logic`; any engine clock API (`Time.get_unix_time_from_system`, `Time.get_datetime_dict_from_system`, `Time.get_ticks_msec/usec`, `Time.get_time_zone_from_system`, `OS.get_datetime`) outside `src/core/time/system_time_source.gd` — enforced by the `clock-discipline` CI job
- Guardrail: `FakeTimeSource` never lives under `src/`

---

## Acceptance Criteria

*From GDD `design/gdd/time-service.md` Core Rule 2 and ADR-0001 §1, scoped to this story:*

- [ ] Verification #4 and #5 run on local 4.7.1 and their results recorded in this story's completion notes (pass, or fallback applied)
- [ ] `src/core/time/time_source.gd` declares `@abstract class_name TimeSource extends RefCounted` with exactly two abstract methods: `get_unix_time() -> int` and `get_timezone_bias_minutes() -> int` (minutes **east** of UTC)
- [ ] `src/core/time/system_time_source.gd` returns `floori(Time.get_unix_time_from_system())` and `Time.get_time_zone_from_system().bias`, and is the only file under `src/` calling an engine clock API (the `clock-discipline` job passes)
- [ ] `tests/helpers/fake_time_source.gd` (`class_name FakeTimeSource extends TimeSource`) has a settable `now` and bias and an `advance(seconds)` method
- [ ] `docs/engine-reference/godot/current-best-practices.md` corrected to match what Verification #4 showed

---

## Implementation Notes

*Derived from ADR-0001 §1 and Risks:*

- Paths are part of the contract: `src/core/time/time_source.gd`, `src/core/time/system_time_source.gd`, `tests/helpers/fake_time_source.gd`. The CI lint exempts only `system_time_source.gd` by exact path.
- Bias sign convention is **minutes east of UTC** (Tokyo = +540, Los Angeles = −480). Do not flip it in `SystemTimeSource` yet — the per-platform sign is verified on device in Story 005, which may add an `OS.get_name()` branch. The `TimeSource` contract does not change either way.
- **Fallback if `@abstract` fails Verification #4 or #5**: a plain `class_name TimeSource extends RefCounted` whose two methods call `push_error("TimeSource.<method> is abstract")` and `return 0`. The interface and subclasses are unchanged. Record which path was taken.
- Match the existing test double in `tests/unit/time_service/time_service_contract_test.gd` (constructor `FakeTimeSource.new(now, tz_bias)` with a default bias of 0), so Story 002 can delete the inner class without touching call sites.
- Doc-comment every public method (coding standards).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `TimeService` itself and the contract-test swap
- Story 003: `TimeProvider` Autoload and `GameRoot`
- Story 005: on-device bias-sign check and any per-OS branch in `SystemTimeSource`

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: `FakeTimeSource` reports the injected time and bias
  - Given: `FakeTimeSource.new(1000, 540)`
  - When: `get_unix_time()` and `get_timezone_bias_minutes()` are called
  - Then: they return `1000` and `540`
  - Edge cases: default bias is `0` when omitted; negative bias (`-480`) returns `-480`
- **AC-2**: `advance()` moves the fake clock forward
  - Given: `FakeTimeSource.new(1000)`
  - When: `advance(1)` then `advance(299)`
  - Then: `get_unix_time()` returns `1300`
  - Edge cases: `advance(0)` leaves time unchanged
- **AC-3**: `FakeTimeSource` is a `TimeSource`
  - Given: a `FakeTimeSource` instance
  - When: checked with `is TimeSource`
  - Then: `true`
- **AC-4**: an inner class can subclass `TimeSource` (Verification #5)
  - Given: an inner class in the test suite, `class StubSource extends TimeSource`, implementing both methods
  - When: instantiated and passed where a `TimeSource` is expected
  - Then: it compiles, and its values come back unchanged
- **AC-5**: `TimeSource` itself cannot be used directly
  - Given: the `@abstract` path — **When**: the suite loads — **Then**: no test calls `TimeSource.new()` (abstract instantiation is a compile error by design, so this is covered by code review, not a runtime test)
  - Given: the fallback path — **When**: a bare `TimeSource.new().get_unix_time()` is called — **Then**: it returns `0` and logs an error
- **AC-6**: clock discipline
  - Given: the repository after this story
  - When: the `clock-discipline` CI job's grep runs locally
  - Then: it reports no violations; `system_time_source.gd` is the only match before the exemption filter

`SystemTimeSource` gets no unit test: it reads the real clock, which would break the determinism rule. It is covered by the lint (AC-6) and by Story 005 on device.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/time_service/time_source_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002
