# Story 002: apply_care, re-anchoring and the care signals

> **Epic**: Need System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (~3 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/need-system.md`
**Requirement**: `TR-need-system-005`, `-007`, `-008`, `-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: ADR-0002: Pet Catalog Loading, Injection and Immutability (primary — `CareProfile.get_restore_amount()`); ADR-0001: Time and Event Injection (typed signals on logic classes)
**ADR Decision Summary**: Care restores come from the injected `CareProfile`; events are typed signals declared on `NeedSystem` itself, connected by `GameRoot`, with no global event bus.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: `RefCounted` supports signals. Typed signal parameters: `signal need_changed(need_id: Need.Id, value: float)`. gdUnit4 `monitor_signals()` / `assert_signal()` work on `Object`, so a `RefCounted` emitter is testable without a scene tree.

**Control Manifest Rules (this layer)**:
- Required: re-anchoring is the only way to change a need (Core Rule 5)
- Forbidden: `global_event_bus`; `autoload_access_from_logic`
- Guardrail: care on a full need is legal and still emits `need_changed` — Pillar 2 forbids a "you didn't need to do that" response

---

## Acceptance Criteria

*From GDD `design/gdd/need-system.md` Acceptance Criteria, scoped to this story:*

**`apply_care`**
- [ ] `need_value(now)=28`, `restore_amount=100` → `anchor_value=100`, `anchor_utc=now`
- [ ] `need_value(now)=100` → value stays `100`, `anchor_utc` still updates (re-anchoring is unconditional)
- [ ] restore below threshold (`restore=10`, `value=5`, `threshold=40`) → value `15`, state stays `SAD`, no `need_cleared`, `need_changed` fires
- [ ] sleep `SAD` at `28`, `restore(lights)=100` → `apply_care(lights)` makes sleep `100.0`, `CONTENT`, and `need_cleared(sleep)` fires
- [ ] sleep anchored at `t=0` at `100`, `decay=1.5`, `restore(lights)=10`; `apply_care(lights)` at `t=36000` then `t=72000` → anchors `95.0` then `90.0`; `need_value` at `t=108000` is exactly `75.0`

**State transition**
- [ ] a `SAD`/`AT_FLOOR` need re-anchored above `sad_threshold` → `CONTENT` and `need_cleared` fires

**`all_needs_addressed`**
- [ ] (a) all four `CONTENT` → `true`; (b) three `CONTENT` + sleep `SAD` → `false`; (c) (b) after `apply_care(lights)` with `restore=100` → `true`, and the `all_needs_addressed` signal is emitted on the transition into (c)
- [ ] `sad_threshold=100` for a need at `100.0` → `SAD`, not `CONTENT` (documents why PDD's amended rule excludes this data)

**No-cascade guarantee**
- [ ] all four needs `AT_FLOOR`; care applied to each in any order → each restores fully, with no interaction, ordering dependency or blocked state

---

## Implementation Notes

*Derived from the GDD Formulas, Core Rules 5, 7, 9, and ADR-0001 §3:*

- `apply_care(action: CareAction.Id) -> void`. Map action → need in code (feed→hunger, clean→cleanliness, play→fun, lights→sleep, PDD Core Rule 10); `match` with a final error branch so the 4.7 typed-return rule holds.
- Re-anchor: `var before := get_state(need)`; `anchor_value = clampf(get_value(need) + float(care.get_restore_amount(action)), float(floor), 100.0)`; `anchor_utc = time.get_now_utc()`.
- Signals declared on `NeedSystem`:
  - `need_changed(need_id: Need.Id, value: float)` — on every `apply_care`, always
  - `need_cleared(need_id: Need.Id)` — when `before` was `SAD`/`AT_FLOOR` and the new state is `CONTENT`
  - `all_needs_addressed()` — when `all_needs_addressed()` goes `false → true` because of this call
  - (`need_became_sad` is Story 004's)
- `all_needs_addressed() -> bool` — every need `CONTENT`. Evaluate it before and after the re-anchor to detect the transition; don't store it.
- Leave a hook for Story 004: re-anchoring must reset that need's `last_observed_state`. Put the re-anchor in one private method (`_reanchor(need, value)`) that Story 004 extends.
- Emission order within one `apply_care`: `need_changed` → `need_cleared` (if any) → `all_needs_addressed` (if any). Pin it in a test so Pet Animation can rely on it later.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: `need_became_sad` and `last_observed_state`
- Story 006: `GameRoot` connecting these signals and re-arming the scheduler after `need_changed`
- Care Actions (no GDD yet): cooldowns, mini-game outcome, reaction sequencing, when lights is offered

---

## QA Test Cases

*From the GDD's Acceptance Criteria (qa-lead consulted at GDD authoring, lean mode). The developer implements against these — do not invent new test cases during implementation.*

Setup: `FakeTimeSource`, `TimeService`, factory profiles overridden per case, `monitor_signals(needs)`.

- **AC-1** Full restore: hunger decayed to 28 (anchor 100, decay 3.0, elapsed 86400); `apply_care(FEED)`, `restore=100` → anchor `100.0`, anchor time `== now`
- **AC-2** Full need: hunger at 100, elapsed 0, advance clock 10 s, `apply_care(FEED)` → value `100.0`, anchor time moved by 10; `need_changed` emitted
- **AC-3** Partial restore: `restore(feed)=10`, hunger at 5, threshold 40 → value `15.0`, state `SAD`; `need_changed` emitted, `need_cleared` not
- **AC-4** Sleep via lights: sleep at 28, `restore(lights)=100` → `100.0`, `CONTENT`, `need_cleared(SLEEP)` emitted
- **AC-5** Lossless chain: as the GDD criterion — anchors `95.0`, `90.0`; value at `t=108000` exactly `75.0`
- **AC-6** Clear on recovery: hunger `AT_FLOOR`; `apply_care(FEED)` → `CONTENT`, `need_cleared(HUNGER)`
- **AC-7** Done for today: states (a), (b), (c) → `true`, `false`, `true`; `all_needs_addressed` emitted exactly once, on the call that produced (c)
  - Edge case: a further `apply_care` while already all `CONTENT` does not emit `all_needs_addressed` again
- **AC-8** `sad_threshold=100`: need at `100.0` reads `SAD`; `all_needs_addressed()` is `false`
- **AC-9** No cascade: all four `AT_FLOOR`; apply care in orders `[F,C,P,L]` and `[L,P,C,F]` (fresh instance each) → all four `100.0` and `CONTENT` in both
- **AC-10** Emission order: one `apply_care` that clears the last sad need emits `need_changed`, `need_cleared`, `all_needs_addressed` in that order

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/need_system/apply_care_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE
- Unlocks: Stories 004, 006
