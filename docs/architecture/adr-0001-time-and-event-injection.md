# ADR-0001: Time and Event Injection

## Status
Proposed

## Date
2026-09-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core (scripting architecture, app lifecycle) |
| **Knowledge Risk** | HIGH — 4.4–4.7 are post-LLM-cutoff (VERSION.md) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/mobile-export.md`; 4.7 class reference for `Node` (notification constants) and `Time` (fetched 2026-09-23) |
| **Post-Cutoff APIs Used** | `@abstract` (4.5) on `TimeSource`; typed-return "must return on every path" rule (4.7) |
| **Verification Required** | **Before the first Foundation `/dev-story`** (local 4.7.1 install): (4) a body-less `@abstract func get_unix_time() -> int` in an `@abstract` `RefCounted` compiles — the project's own `current-best-practices.md` shows abstract methods *with* a `pass` body, which external sources say is a parse error; correct that doc once confirmed; (5) a `class_name` script in `tests/helpers/` **and** an inner class in a test suite can both `extends TimeSource`. **On device, before the Foundation epic closes:** (1) `NOTIFICATION_APPLICATION_PAUSED`/`_RESUMED` fire on real Android and iOS devices for home button, app switcher and lock screen, and reach a non-root child `Node`; (2) the sign of `Time.get_time_zone_from_system().bias` — checked **independently on Android and on iOS**, since godotengine/godot#37571 shows the sign differing across platforms for the same zone and the 4.7 docs state no convention; (3) a one-shot `Timer` that expired during suspension does not fire a burst of stale timeouts on resume. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (pet catalog loading), which reuses this ADR's composition root; ADR-0003 (save format, schema versioning), which uses its lifecycle signal for save-on-background |
| **Blocks** | Foundation epic stories for Time Service and Need System (Core Rule 14 adapter, `on_resumed()` wiring) |
| **Ordering Note** | Offline Time Simulation and Save & Persistence GDDs are not approved; this ADR fixes only their *call slot* in the resume sequence, not their behaviour |

## Context

### Problem Statement
Two approved GDDs require that game logic never reads the wall clock and is unit-testable against a fake one (Time Service Core Rules 1–2, Need System Core Rule 12). Both GDDs explicitly defer three questions to this ADR: the exact `TimeSource` interface (Time Service OQ, raised during `/test-setup`), how the production `TimeService` is constructed and reached (`TimeProvider` Autoload wiring), and who calls `NeedSystem.on_resumed()` on return from background, in what order relative to Offline Sim's cap. Need System's `NeedCrossingScheduler` also needs a defined boundary between pure logic and engine timers. These must be pinned before the first `/dev-story`, or each system invents its own wiring.

### Constraints
- Coding standard: dependency injection over singletons; all public methods unit-testable.
- CI `clock-discipline` job already bans engine clock APIs outside `src/core/time/system_time_source.gd` — that path is a fixed contract.
- `tests/unit/time_service/time_service_contract_test.gd` already encodes the two-method `TimeSource` contract; the production classes must satisfy it unchanged (one-line `ServiceUnderTest` swap).
- `NOTIFICATION_APPLICATION_PAUSED`/`_RESUMED` are **Android/iOS only** (4.7 class ref). Desktop and the editor only deliver `FOCUS_OUT`/`FOCUS_IN`, and those also fire on mobile for partial occlusion (notification shade).
- `Time.get_unix_time_from_system()` returns `float`.
- Small scope: ~10 MVP systems, one scene, solo developer.

### Requirements
- Every logic class is constructible in a unit test with a `FakeTimeSource`, no scene tree, no Autoload.
- One place in the codebase defines the resume order.
- Logic emits events without depending on who listens.
- Resume and background handling works identically on device and in the editor.

## Decision

**Constructor injection into plain `RefCounted` logic classes, wired by one composition root node; events are typed signals declared on the logic classes; OS lifecycle is translated by one adapter node into two signals, handled by one ordered handler in the composition root.**

### 1. Clock abstraction

- `TimeSource` (`src/core/time/time_source.gd`) — `@abstract class_name TimeSource extends RefCounted` with exactly two abstract methods:
  - `get_unix_time() -> int` — current UTC epoch seconds.
  - `get_timezone_bias_minutes() -> int` — current local offset, minutes **east** of UTC.
- `SystemTimeSource` (`src/core/time/system_time_source.gd`) — the *only* file that calls `Time.*_from_system()`. Returns `floori(Time.get_unix_time_from_system())` and `Time.get_time_zone_from_system().bias`.
- `FakeTimeSource` (`tests/helpers/fake_time_source.gd`) — settable `now` and bias, plus `advance(seconds)`. Test-only; never under `src/`. The inner class in the existing contract test moves here.
- `TimeService` (`src/core/time/time_service.gd`) — `class_name TimeService extends RefCounted`, `_init(source: TimeSource)`, the four GDD operations, stateless. `get_local_calendar_date()` applies the **current** bias to any timestamp (DST is not recoverable from an epoch — accepted limitation, per the 4.7 `Time` reference).

### 2. Wiring

- **Logic classes** (`TimeService`, `NeedSystem`, later `OfflineTimeSim`, `SaveService`, …) are `RefCounted`, take every collaborator through `_init()` and **never reference an Autoload or `get_tree()`**.
- **`TimeProvider` Autoload** (`src/core/time/time_provider.gd`) — a `Node` that constructs one `TimeService(SystemTimeSource.new())` in `_init()` and exposes it as a read-only `service` property. Satisfies Time Service AC #10. It holds nothing else.
- **Composition root** — `GameRoot` (`src/core/app/game_root.gd`, root of `GameRoot.tscn`, the main scene). The only script that reads `TimeProvider.service`. It constructs every logic object in dependency order, passes collaborators in, creates the adapters, and connects signals. Adding a system means editing this one file.

### 3. Events

- Logic classes declare typed signals directly (`signal need_became_sad(need_id: Need.Id)`). `RefCounted` supports signals.
- Consumers never reach for the emitter — `GameRoot` connects `emitter.signal.connect(consumer.method)` with typed callables.
- No global event bus in MVP.

### 4. App lifecycle

- `AppLifecycle` (`src/core/app/app_lifecycle.gd`) — a `Node` child of `GameRoot`. In `_notification()` it maps `NOTIFICATION_APPLICATION_PAUSED` **and** `NOTIFICATION_APPLICATION_FOCUS_OUT` → `app_backgrounded`, and `NOTIFICATION_APPLICATION_RESUMED` **and** `NOTIFICATION_APPLICATION_FOCUS_IN` → `app_resumed`. A private `_in_background: bool` edge-detects, so each transition emits exactly once even when a mobile OS delivers both the focus and the pause notification. No logic, no time reads.
- `GameRoot._on_app_resumed()` is **the single definition of resume order**:
  1. `offline_sim.reanchor_with_cap(...)` — once Offline Time Simulation exists; a no-op slot until then
  2. `needs.on_resumed()` — pure; fires any crossing that happened while suspended
  3. `crossing_scheduler.rearm()`
- `GameRoot._on_app_backgrounded()` requests a save (slot filled by ADR-0003). iOS allows ~5 s after `PAUSED`, so the save must be synchronous and small.
- A spurious resume (focus flicker) is harmless: `on_resumed()` → `check_crossings()` is idempotent per the Need System GDD.

### 5. Crossing scheduler (Need System Core Rule 14 adapter)

- `NeedCrossingScheduler` (`src/gameplay/needs/need_crossing_scheduler.gd`) — a `Node` with one child one-shot `Timer`, constructed by `GameRoot` with `NeedSystem` and `TimeService` references (set before `add_child`).
- `rearm()` — takes the soonest non-`-1` `next_crossing_utc()` across the four needs, and calls `start()` with `wait_time = maxf(1.0, float(next_utc - time.get_now_utc()))`. `start()` resets a running timer, so no `stop()` is needed first. If every need returns `-1`, `rearm()` calls `stop()`. Arms only; no rules.
- On `timeout`: `needs.check_crossings()`, then `rearm()`. `GameRoot` also calls `rearm()` after every `need_changed`.
- The `Timer` measures a *delay*, never reads the clock, so it is lint-compliant. A late, early or dropped timeout is harmless because detection is state-based.

### Architecture Diagram

```
            OS notifications
                  │
        ┌─────────▼─────────┐     app_resumed / app_backgrounded
        │   AppLifecycle    │──────────────────────┐
        │  (Node, adapter)  │                      │
        └───────────────────┘                      ▼
┌─────────────────┐  .service   ┌──────────────────────────────────────┐
│ TimeProvider    │◀────────────│ GameRoot (composition root, Node)    │
│ (Autoload Node) │  read ONLY  │  constructs · injects · connects     │
│  └ TimeService  │  here       │  _on_app_resumed(): 1 cap 2 resume 3 │
│     └ System    │             └──┬──────────────┬──────────────┬─────┘
│       TimeSource│                │ _init(time,…) │              │
└─────────────────┘                ▼               ▼              ▼
                           ┌────────────┐  ┌──────────────┐ ┌──────────────────┐
  tests: FakeTimeSource ──▶│ NeedSystem │  │ OfflineSim   │ │ NeedCrossing     │
  (no tree, no Autoload)   │ (RefCounted│  │ (RefCounted, │ │ Scheduler (Node, │
                           │  signals)  │  │  later)      │ │  one-shot Timer) │
                           └─────┬──────┘  └──────────────┘ └────────┬─────────┘
                                 │ need_became_sad, need_cleared …    │ check_crossings()
                                 ▼ (connected by GameRoot)            │ next_crossing_utc()
                          consumers (Animation, LCD, Device Frame) ◀──┘
```

### Key Interfaces

```gdscript
@abstract
class_name TimeSource extends RefCounted
@abstract func get_unix_time() -> int
@abstract func get_timezone_bias_minutes() -> int   # minutes EAST of UTC

class_name TimeService extends RefCounted
func _init(source: TimeSource) -> void
func get_now_utc() -> int
func get_elapsed_seconds(since_utc: int) -> int
func get_local_calendar_date(utc_timestamp: int) -> Dictionary  # {year, month, day}
func is_new_calendar_day(last_utc: int, current_utc: int) -> bool

# TimeProvider (Autoload) — read by GameRoot only
var service: TimeService   # read-only

class_name AppLifecycle extends Node
signal app_backgrounded
signal app_resumed

class_name NeedCrossingScheduler extends Node
func setup(needs: NeedSystem, time: TimeService) -> void   # before add_child
func rearm() -> void
```

## Alternatives Considered

### Alternative 1: Time Service Autoload called directly
- **Description**: `TimeService` is itself an Autoload; logic calls `TimeProvider.get_now_utc()` anywhere.
- **Pros**: Least wiring code; idiomatic in small Godot projects.
- **Cons**: Every logic test must mutate a shared global clock; tests become order-dependent; violates the coding standard's DI rule and Time Service Core Rule 2.
- **Rejection Reason**: Breaks the determinism and isolation testing rules the whole design depends on.

### Alternative 2: Service-locator Autoload
- **Description**: A `Services` Autoload registry; logic calls `Services.get(&"time")`.
- **Pros**: Swappable in tests; one registry for every future service.
- **Cons**: Dependencies become invisible in signatures; lookups are stringly typed and lose static typing; tests still share global state.
- **Rejection Reason**: Hides exactly the dependencies DI is meant to show, and trades static typing for flexibility this project does not need.

### Alternative 3: Global event bus for signals
- **Description**: One `Events` Autoload declares every signal; systems emit and listen through it.
- **Pros**: Decouples wiring; easy to add listeners.
- **Cons**: Hidden coupling; shared global state in tests; any system can emit any event.
- **Rejection Reason**: ~10 MVP systems with a known graph — direct typed signals are simpler and keep ownership visible. Revisit if the connection list in `GameRoot` becomes unmanageable.

### Alternative 4: Connection-order resume
- **Description**: Each system connects to `app_resumed` itself; order follows `connect()` order.
- **Rejection Reason**: The Need System GDD requires the cap *before* `on_resumed()`. Encoding that in implicit connect order is invisible and fragile.

## Consequences

### Positive
- Every logic class is testable with `FakeTimeSource` alone; no scene tree needed.
- The whole object graph and resume order are readable in one file.
- The existing contract test carries over with a one-line swap.
- Editor play-testing exercises the same resume path as a phone.

### Negative
- `GameRoot` grows with every system — a deliberate hub.
- Adapters (`AppLifecycle`, `NeedCrossingScheduler`) are outside the unit-tested surface; they need ADVISORY integration or on-device checks.
- Focus flicker on mobile (notification shade) triggers extra resume/background passes. They are harmless but cost a save.

### Risks
- **Lifecycle notifications misbehave on 4.7 devices** → on-device check (Verification #1) before the Foundation epic closes; edge detection limits the damage.
- **Timezone bias sign is inconsistent across platforms** (godotengine/godot#37571 — same UTC+8 zone, opposite signs on Windows and Android) → Verification #2 on both target OSes independently. `SystemTimeSource` may need an `OS.get_name()` branch rather than one global flip; the `TimeSource` contract (minutes **east**) does not change, so no consumer is affected.
- **`@abstract` behaves differently from what's assumed** (4.5 feature), including the cross-file and inner-class subclassing cases the tests depend on (Verification #4, #5) → fall back to a plain `TimeSource` base class whose methods `push_error()` and `return 0`. Interface and subclasses are unchanged.
- **`NOTIFICATION_APPLICATION_*` does not reach a non-root child** — propagation to all nodes is inferred from engine behaviour, not stated in the docs → if the device check fails, move the `_notification()` handler into `GameRoot` itself; the `app_resumed`/`app_backgrounded` signals stay the same.
- **The Timer is not a clock.** During OS suspension no frames are processed, so the Timer's remaining time says nothing about elapsed wall time. Resume correctness depends only on `TimeService`'s epoch difference plus `on_resumed()`; the Timer only gives prompt in-session feedback.
- **RefCounted→Node signal lifetime** — auto-disconnect when a connected `Node` is freed is commonly observed engine behaviour, not doc-cited. Low risk: `GameRoot`'s connections live as long as the app.
- **Someone reads `TimeProvider` from logic code** → add a CI grep alongside `clock-discipline`: `TimeProvider` may appear only under `src/core/app/` and `src/core/time/`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| time-service.md | Core Rule 2 — injectable `TimeSource`, `SystemTimeSource`/`FakeTimeSource`, `TimeProvider` Autoload | §1–2 fix the classes, paths and wiring |
| time-service.md | OQ — `TimeSource` must expose timezone bias | §1: two-method contract, bias in minutes east of UTC |
| time-service.md | OQ — `TimeProvider` Autoload wiring deferred to ADR | §2: Autoload holds one instance; only `GameRoot` reads it |
| time-service.md | AC #10 — one production instance reachable from the tree | `TimeProvider.service` |
| time-service.md | OQ — `PAUSED`/`RESUMED` unconfirmed for 4.7 | Verified to exist (Android/iOS only); §4 adds the focus fallback; device check listed |
| need-system.md | Core Rule 12 — no clock reads, no engine `Timer` in logic | Logic is `RefCounted` with injected `TimeService`; the `Timer` lives only in the scheduler adapter |
| need-system.md | Core Rule 14 — `on_resumed()` single entry; cap before resume; scheduler adapter re-arms | §4 ordered handler; §5 scheduler |
| need-system.md | Interactions table — "App lifecycle (resume handler) → time/event ADR" | `AppLifecycle` + `GameRoot._on_app_resumed()` |

## Performance Implications
- **CPU**: Negligible — no per-frame work; one timer and a few dozen signal connections.
- **Memory**: Negligible — a handful of `RefCounted` objects.
- **Load Time**: None measurable.
- **Network**: N/A.

## Migration Plan
No production code exists. The first `/dev-story` for Time Service: create the four `src/core/time/` files, move `FakeTimeSource` into `tests/helpers/fake_time_source.gd` and change it from `extends RefCounted` to `extends TimeSource`, delete `RefTimeService` from the contract test, and point `ServiceUnderTest` at `TimeService`. Register `TimeProvider` in `project.godot` and set `GameRoot.tscn` as the main scene.

## Validation Criteria
- The existing contract test passes against production `TimeService` with only the `ServiceUnderTest` line changed.
- `NeedSystem` unit tests construct it with no scene tree and no Autoload.
- The CI lint fails on a planted `TimeProvider` reference in `src/gameplay/`.
- On device: background for over 20 h with fresh needs; on resume, `need_became_sad` fires exactly once per crossed need.

## Related Decisions
- ADR-0002 — pet catalog loading, injection and immutability
- ADR-0003 (planned) — save format, schema versioning, missing-species handling
- ADR-0004 (planned) — LCD rendering approach (SubViewport, per the 2026-09-22 spike)
- design/gdd/time-service.md, design/gdd/need-system.md
