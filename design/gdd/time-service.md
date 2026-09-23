# Time Service

> **Status**: Approved (accepted with notes) — 2026-09-19
> **Author**: user + agents
> **Last Updated**: 2026-09-18
> **Implements Pillar**: Infrastructure (indirectly serves Pillar 2: Never Guilt, Always Welcome; Pillar 3: Two Minutes of Joy)
> **Creative Director Review (CD-GDD-ALIGN)**: Skipped — Solo mode

## Overview

The Time Service is the single, injectable source of "now" and elapsed real-world time for the entire game. It is the only code in the project permitted to read the system wall clock (`Time.get_unix_time_from_system()` and related APIs); every other system that needs to know what time it is, or how much real time has passed since a stored moment, asks the Time Service rather than calling the engine clock directly. It exists because two of the game's core mechanics — Need decay and Offline Time Simulation — must be deterministic and unit-testable (a fixed test clock in, a fixed elapsed-time answer out), and because the coding standard requires dependency injection over singletons for anything that must be testable. The Time Service itself has no gameplay behavior: it does not decide what elapsed time *means* to a need or a growth stage — it only supplies the raw, clamped-safe time values that Need System, Save & Persistence, Life Stage & Growth, Offline Time Simulation, and Daily Notification build their logic on top of.

## Player Fantasy

Time Service has no player fantasy of its own — the player never knows it exists. What it enables is the fantasy stated in **Pillar 2: Never Guilt, Always Welcome**: *"The pet is glad to see you however long you've been gone... returning after months earns a greeting, not a state report."* That warmth is only possible because Time Service supplies a clean, clamped elapsed-time value regardless of how long the gap was — a day, two weeks, or six months all resolve to the same well-behaved number, which is what lets Offline Time Simulation land on "glad to see you" instead of a punishing catch-up state. Time Service's job is to make sure the *infrastructure* never surprises the systems built on the fantasy, not to deliver the fantasy itself.

*`creative-director` not consulted — Solo mode. Review manually before production.*

## Detailed Design

### Core Rules

1. Time Service exposes exactly four operations, and no other system reads the engine clock directly:
   - `get_now_utc() -> int` — current time as a UTC unix epoch (seconds).
   - `get_elapsed_seconds(since_utc: int) -> int` — elapsed time since a stored timestamp, computed as `max(0, get_now_utc() - since_utc)`. Guarantees a non-negative result even if `since_utc` is in the future (clock rolled back, device clock changed, or a corrupted/tampered save) — callers never have to defend against negative elapsed time themselves.
   - `get_local_calendar_date(utc_timestamp: int) -> Dictionary` — the `{year, month, day}` of a UTC timestamp converted to the device's local time zone.
   - `is_new_calendar_day(last_utc: int, current_utc: int) -> bool` — true if the local calendar date of `current_utc` differs from the local calendar date of `last_utc`. This is the single source of truth for "did the player check in on a new day," used by Life Stage & Growth.
2. Time Service is injectable, not a bare global. It is a plain class that takes a `TimeSource` interface at construction. Two implementations exist: `SystemTimeSource` (production — wraps Godot's `Time` singleton, the *only* place in the codebase allowed to call `Time.get_unix_time_from_system()` or equivalent) and `FakeTimeSource` (test — returns a settable fixed value). A thin Autoload (`TimeProvider`) constructs and holds the one production `TimeService` instance for convenient scene-tree access, but every system that consumes time receives a `TimeService` reference through its constructor (`_init()`) — so unit tests construct their own `TimeService` wrapping a `FakeTimeSource` and never touch the Autoload. Only the composition root (`GameRoot`) reads the Autoload. *(Wiring fixed by `docs/architecture/adr-0001-time-and-event-injection.md`, 2026-09-23.)*
3. Time Service applies no gameplay policy. It does not decide how much of an elapsed duration should count (that's Offline Time Simulation's `MAX_OFFLINE` clamp, layered on top of `get_elapsed_seconds()`), and it does not decide what a "new day" *means* for growth (that's Life Stage & Growth's rule) — it only answers "is this a new calendar day," not "should growth advance."

### States and Transitions

Time Service is stateless per call. It holds only its injected `TimeSource` reference; it has no internal state machine and nothing here transitions. (N/A — noted explicitly rather than left blank, since every other MVP system in this index does have states.)

### Interactions with Other Systems

| System | Data In | Data Out | Notes |
|---|---|---|---|
| Need System | a stored "last decay applied" UTC timestamp | `get_elapsed_seconds()` → seconds to apply as decay | Called live while the app is open, not just on resume |
| Save & Persistence | — | `get_now_utc()` → the timestamp written as `last_seen` on save | Save always stores UTC epoch, never local time |
| Life Stage & Growth | last check-in UTC timestamp, current UTC timestamp | `is_new_calendar_day()` → bool | Determines whether today counts toward the check-in-day growth arc |
| Offline Time Simulation | `last_seen` UTC timestamp from save | `get_elapsed_seconds()` → raw elapsed seconds | Offline Sim applies its own `clamp(elapsed, 0, MAX_OFFLINE)` — the cap is Offline Sim's tuning knob, not Time Service's |
| Daily Notification | last-notified UTC timestamp, current UTC timestamp | `is_new_calendar_day()` / `get_now_utc()` | Determines the reminder window |

*Specialist agents not consulted — Solo mode. Review manually before production.*

## Formulas

The `elapsed_seconds` formula is defined as:

`elapsed_seconds = max(0, now_utc - since_utc)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| now_utc | now | int (unix epoch seconds) | any valid epoch value | Current time, from `get_now_utc()` |
| since_utc | since | int (unix epoch seconds) | any valid epoch value | Stored timestamp being compared against (e.g. last save, last decay tick) |

**Output Range:** 0 to unbounded. Never negative, by construction — a `since_utc` in the future (clock rollback, manipulated device clock, corrupted save) clamps to 0 rather than producing a negative duration. No upper bound is applied here; any policy cap (e.g. Offline Time Simulation's `MAX_OFFLINE`) is a downstream concern, not part of this formula.
**Example:** `now_utc = 1791000300`, `since_utc = 1791000000` → `elapsed_seconds = 300` (5 minutes). Clock-rollback case: `now_utc = 1791000000`, `since_utc = 1791000300` → `elapsed_seconds = max(0, -300) = 0`.

---

The `is_new_calendar_day` formula is defined as:

`is_new_calendar_day = local_date(now_utc) ≠ local_date(last_utc)`

where `local_date(t)` converts a UTC epoch to the device's local-time-zone `{year, month, day}` tuple.

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| now_utc | now | int (unix epoch seconds) | any valid epoch value | Current time |
| last_utc | last | int (unix epoch seconds) | any valid epoch value | Timestamp of the last recorded check-in |

**Output Range:** boolean (`true`/`false`). **Behavior at extremes:** a same-second re-check returns `false`; a multi-year gap returns `true`; a gap that crosses local midnight but is less than 24 real hours (e.g. checking in at 11:58 PM then 12:02 AM) also returns `true` — day-boundary comparison is by local calendar date, not by a rolling 24-hour window. This is a deliberate design choice: it matches how a player intuitively thinks about "a new day," but means two check-ins 4 minutes apart can count as two different growth days if they straddle midnight.
**Example:** `last_utc` = Sept 18, 11:58 PM local; `now_utc` = Sept 19, 12:02 AM local → `is_new_calendar_day = true` (4 minutes elapsed, but different calendar dates).

*`systems-designer` not consulted — Solo mode. Review manually before production.*

## Edge Cases

- **If `since_utc` is later than `now_utc`** (clock rolled back, device clock manipulated, or a corrupted timestamp): `elapsed_seconds` clamps to 0. Time Service does not flag or reject this — it silently returns the safe floor value (see Formulas).
- **If the device clock is moved forward** (accidentally, or to exploit offline gains): Time Service reports the resulting `elapsed_seconds` truthfully — it has no anti-cheat responsibility of its own. Abuse resistance is owned downstream: Offline Time Simulation's `MAX_OFFLINE` clamp bounds how much of that elapsed time can heal needs, and Life Stage & Growth never advances from elapsed time at all (only from real check-in days), which neutralizes clock-forward exploitation of the growth arc specifically.
- **If a DST transition falls between two check-ins**: local calendar-date conversion already accounts for DST via the engine's local-time APIs — no special handling is implemented in Time Service. This assumption should be verified on-device during testing, since local-time conversion behavior for 4.7 is not separately confirmed in the engine reference docs.
- **If the player changes device time zone between check-ins** (e.g. travel): `get_local_calendar_date()` always uses the device's *current* time zone at call time — it is never stored or frozen. A timezone change can cause a calendar day to be silently skipped once, or (crossing back) counted twice. This is an accepted trade-off, not a defect: per Pillar 2, the correct behavior is "never punish, never crash," not "perfectly reconstruct a traveling player's day count."
- **If `since_utc` is 0, negative, or otherwise clearly invalid** (uninitialized field, corrupted save): Time Service does not validate the sanity of its inputs — it computes whatever `elapsed_seconds` results, even if implausibly large. Input validation is the caller's responsibility; Save & Persistence should reject or repair a timestamp that predates the app's own release before ever passing it to Time Service.
- **If elapsed spans multiple years** (long-dormant install): `elapsed_seconds` returns the true, large value with no special-casing — magnitude judgment belongs to Offline Time Simulation's clamp, not to Time Service.
- **Leap seconds**: not handled and not expected to matter. The game operates at 1-second-or-coarser granularity, and Godot's `Time` singleton does not expose sub-second leap-second correction. Explicitly out of scope.

*`systems-designer` not consulted — Solo mode. Review manually before production.*

## Dependencies

**Upstream (what Time Service depends on):** None. Time Service is a Foundation-layer system with no dependencies on any other game system — this is by design, since it must be the most stable, earliest-buildable piece of the project.

**Downstream (what depends on Time Service):** All hard dependencies — none of these systems can function without a time source.

| Depends on Time Service | Dependency Type | Interface Used |
|---|---|---|
| Need System | Hard | `get_elapsed_seconds()` |
| Save & Persistence | Hard | `get_now_utc()` |
| Life Stage & Growth | Hard | `is_new_calendar_day()` |
| Offline Time Simulation | Hard | `get_elapsed_seconds()` |
| Daily Notification | Hard | `get_now_utc()`, `is_new_calendar_day()` |

This matches the systems index's dependency map exactly (Time Service listed as a dependency of all five). No corrections needed there.

## Tuning Knobs

Time Service has no tuning knobs of its own. It exposes raw time facts (elapsed seconds, calendar-day comparison) with no designer-adjustable parameters — there's nothing here to tune without changing what "elapsed time" or "a calendar day" *means*, which isn't a knob, it's the contract. Tuning knobs that operate on the data Time Service provides belong to the consuming systems instead:
- `MAX_OFFLINE` (the cap on how much elapsed time counts toward offline healing) → owned by Offline Time Simulation
- Need decay rates → owned by Need System
- Notification reminder window → owned by Daily Notification

This section is intentionally empty of knobs rather than left as a placeholder — the absence is a design conclusion, not an oversight.

## Visual/Audio Requirements

N/A — Time Service is pure infrastructure with no player-visible presence. No visual or audio feedback originates from this system.

## UI Requirements

N/A — Time Service has no UI surface. It is consumed only by other systems' code, never rendered or exposed to the player directly.

## Acceptance Criteria

- **GIVEN** a `TimeService` constructed with a `FakeTimeSource` set to `1000`, **WHEN** `get_now_utc()` is called, **THEN** it returns `1000`.
- **GIVEN** a `TimeService` whose `FakeTimeSource` is set to `1000`, **WHEN** `get_now_utc()` is called, the fake clock is advanced by 1, and `get_now_utc()` is called again, **THEN** the second call returns a value ≥ the first by at least 1. *(Rewritten 2026-09-22: the original used a real one-second wall-clock sleep against `SystemTimeSource`, violating the determinism standard in `.claude/docs/coding-standards.md`. Monotonicity is a property of the service's pass-through, not of the OS clock — advancing the injected clock proves it deterministically. That `SystemTimeSource` itself returns a real advancing clock is a one-line wrapper, covered by the on-device check below, not by a unit test.)*
- **GIVEN** `since_utc = 1000` and the fake clock set to `1300`, **WHEN** `get_elapsed_seconds(1000)` is called, **THEN** it returns `300`.
- **GIVEN** `since_utc = 1300` and the fake clock set to `1000` (clock rolled back), **WHEN** `get_elapsed_seconds(1300)` is called, **THEN** it returns `0`, never a negative number.
- **GIVEN** `since_utc` equal to the current fake clock value, **WHEN** `get_elapsed_seconds()` is called, **THEN** it returns `0`.
- **GIVEN** two UTC timestamps that fall on the same local calendar date, **WHEN** `is_new_calendar_day(last_utc, now_utc)` is called, **THEN** it returns `false`.
- **GIVEN** two UTC timestamps 4 minutes apart that straddle local midnight (e.g. 11:58 PM → 12:02 AM), **WHEN** `is_new_calendar_day(last_utc, now_utc)` is called, **THEN** it returns `true`.
- **GIVEN** two UTC timestamps a full year apart, **WHEN** `is_new_calendar_day(last_utc, now_utc)` is called, **THEN** it returns `true`.
- **GIVEN** a `TimeService` built on a `FakeTimeSource`, **WHEN** every public method is called, **THEN** results are identical regardless of the machine's real clock and real timezone — proven by asserting the same outputs across three injected timezone offsets. **AND GIVEN** the repository's game code under `src/`, **WHEN** CI runs, **THEN** the `clock-discipline` job in `.github/workflows/tests.yml` fails the build if any engine clock API (`Time.get_unix_time_from_system`, `Time.get_datetime_dict_from_system`, `Time.get_ticks_msec/usec`, `Time.get_time_zone_from_system`, `OS.get_datetime`) appears outside `src/core/time/system_time_source.gd`. *(Rewritten 2026-09-22: the original was unfalsifiable — a unit test can only prove the code it calls is deterministic, never that some other file is. Split into a determinism assertion, which a test can carry, and a repository-wide lint gate, which CI can.)*
- **GIVEN** the production `TimeProvider` Autoload, **WHEN** the game boots, **THEN** it exposes exactly one `TimeService` instance wired to `SystemTimeSource`, reachable by any scene-tree node without constructing its own.

*`qa-lead` not consulted — Solo mode. Review manually before production.*

**Note:** DST-transition behavior (flagged in Edge Cases) cannot be fully unit-tested against a `FakeTimeSource` alone if `get_local_calendar_date()` relies on the OS's real timezone database — this should get an on-device or integration-level check during Offline Time Simulation / Life Stage & Growth implementation, not assumed safe from unit tests alone.

## Open Questions

- **Q**: `NOTIFICATION_APPLICATION_PAUSED` / `_RESUMED` behavior is unconfirmed for Godot 4.7 (flagged in `docs/engine-reference/godot/modules/mobile-export.md`). This affects when Offline Time Simulation captures the "app went to background" timestamp that it later hands to Time Service. **Owner**: engineering. **Target**: research spike during architecture, before Offline Time Simulation is designed. *(Partly answered 2026-09-23 by ADR-0001: both notifications exist in 4.7 but are Android/iOS only. ADR-0001 §4 also maps `FOCUS_IN`/`FOCUS_OUT` so desktop and editor runs behave the same. The on-device check is still open.)*
- **Q**: DST-transition and timezone-change behavior for `get_local_calendar_date()` / `is_new_calendar_day()` is asserted by design (Edge Cases) but not verified on real devices. **Owner**: QA / dev. **Target**: on-device verification before Life Stage & Growth and Offline Time Simulation implementation.
- ~~**Q**: `TimeSource` must expose the timezone offset, not just the clock. Writing the first test showed that injecting only `get_unix_time()` leaves `get_local_calendar_date()` reading the machine's real timezone, which makes every calendar-day assertion non-deterministic across CI machines and developer laptops. The test suite therefore assumes a two-method `TimeSource` contract: `get_unix_time() -> int` **and** `get_timezone_bias_minutes() -> int`. Core Rule 1 lists four Time Service operations but does not specify the `TimeSource` interface itself — it should be stated explicitly, including this second method. **Owner**: technical-director. **Target**: the time/event injection ADR, before Time Service is implemented. *(Raised 2026-09-22 during `/test-setup`.)*~~ **RESOLVED 2026-09-23** by ADR-0001 §1 — two-method contract, bias in minutes **east** of UTC. The bias sign is platform-inconsistent (godotengine/godot#37571) and must be verified on device.
- ~~**Q**: Exact `TimeProvider` Autoload wiring mechanics (how the production `TimeService` singleton is constructed and exposed) are deferred to an ADR rather than fixed here. **Owner**: technical-director. **Target**: architecture phase.~~ **RESOLVED 2026-09-23** by ADR-0001 §2.

### Accepted review blockers (2026-09-19 `/design-review`, converted to open questions 2026-09-22)

The 2026-09-19 review returned NEEDS REVISION with 6 blocking items. All were documentation/contract fixes — the architecture (injectable `TimeSource`, no gameplay policy, non-negative clamp) was judged correct and needs no redesign. The GDD was accepted as-is; the items are carried here. Pillar 2 ("no fail state") is why they matter: a bad time value fails silently rather than crashing.

- **Q**: Timestamp domain is "any epoch" — must be narrowed to a bounded window to rule out int64 wrap and negative-epoch input to `local_date`. **Owner**: technical-director. **Target**: the storage/versioning ADR, before Save & Persistence is implemented.
- **Q**: The anchor-timestamp data contract (field names, nullability, value on a new save) is unspecified for all five consumers. **Owner**: systems-designer. **Target**: Save & Persistence design session.
- **Q**: The GDD claims engine local-time APIs handle DST. This is false — Godot 4.7.1 ships no tzdb. Must be restated as an explicit accepted limitation. **Owner**: engineering. **Target**: correct when Offline Time Simulation is designed.
- ~~**Q**: AC #2 uses a real wall-clock sleep, violating the determinism standard in `.claude/docs/coding-standards.md`. Must be rewritten against the injected test clock.~~ **RESOLVED 2026-09-22** (`/test-setup`) — AC #2 rewritten against the injected clock; encoded as `test_get_now_utc_advances_with_the_injected_clock` in `tests/unit/time_service/time_service_contract_test.gd`.
- ~~**Q**: AC #9 is unfalsifiable as written ("no other system reads the wall clock"). Must become a CI lint gate plus a determinism test.~~ **RESOLVED 2026-09-22** (`/test-setup`) — split into `test_results_are_independent_of_real_wall_clock_and_timezone` plus the `clock-discipline` CI job in `.github/workflows/tests.yml`. The lint gate exempts only `src/core/time/system_time_source.gd`, which fixes that filename as part of the contract.
- **Q**: Section "Detailed Design" should be renamed "Detailed Rules" to match the required 8-section GDD standard. **Owner**: — . **Target**: cosmetic; fix on next touch of this file.
