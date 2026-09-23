# Epic: Need System

> **Layer**: Core *(created in the foundation batch at the user's request, 2026-09-23 — stories start only after the Time Service and Pet Definition Data epics' interfaces exist)*
> **GDD**: design/gdd/need-system.md
> **Architecture Module**: `src/gameplay/needs/` (pure `NeedSystem` logic + `NeedCrossingScheduler` adapter). *No `docs/architecture/architecture.md` exists (compressed path, 2026-09-22) — module boundaries are taken from ADR-0001 §2, §5 and ADR-0002 §5.*
> **Status**: Ready
> **Stories**: 7 created 2026-09-23 — see table below

## Overview

Implements the four decaying needs as lazily evaluated anchors: each need stores
`anchor_value` + `anchor_utc`, its value is computed on read from elapsed time
against the injected `TimeService`, and every mutation re-anchors. On top of that
sit care restores (`apply_care`, including press-restored sleep via `lights`),
derived state with fixed precedence (`CONTENT` / `AT_FLOOR` / `SAD`), the urgency
ranking, `seconds_until_sad` / `next_crossing_utc`, `all_needs_addressed`, and the
pure crossing check with its `on_resumed()` entry point. The only engine-timing
code is the thin `NeedCrossingScheduler` node, wired by `GameRoot`. The logic class
is constructed as `NeedSystem._init(time: TimeService, needs: NeedProfile, care: CareProfile)`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Time and Event Injection | Injected `TimeService`; typed signals; ordered resume handler; `NeedCrossingScheduler` adapter owns the only `Timer` | HIGH |
| ADR-0002: Pet Catalog Loading, Injection and Immutability | `NeedProfile` / `CareProfile` injected into `_init()`; read via `get_params()` / `get_restore_amount()` | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-need-system-001 | Four needs fixed in code | ADR-0002 §1 (`Need.Id`) ✅ |
| TR-need-system-002 | 0–100 float scale owned here | GDD rule — pure logic, no architectural decision needed |
| TR-need-system-003 | Anchor + computed-on-read value | GDD rule — pure logic |
| TR-need-system-004 | One decay rule online and offline | GDD rule — pure logic |
| TR-need-system-005 | Every mutation re-anchors | GDD rule — pure logic |
| TR-need-system-006 | Rate fixed for an anchor's life | GDD rule — pure logic |
| TR-need-system-007 | Care restores by re-anchoring upward | ADR-0002 §5 (`CareProfile`) ✅ |
| TR-need-system-008 | Stops at floor, no cascade | GDD rule — pure logic |
| TR-need-system-009 | Sleep press-restored via `apply_care(lights)` | ADR-0002 §5 ✅ |
| TR-need-system-010 | Derived state with precedence | GDD rule — pure logic |
| TR-need-system-011 | Urgency ranking | GDD rule — pure logic |
| TR-need-system-012 | No wall-clock reads; no `Timer` in logic | ADR-0001 §1–2 ✅ |
| TR-need-system-013 | Need System owns live anchors; Save gets copies | ❌ **No ADR** — accessor shape waits on ADR-0003 (save format) |
| TR-need-system-014 | Pure crossing check, `on_resumed()`, scheduler adapter | ADR-0001 §4–5 ✅ |

## Carried Constraints and Checks

- **Untraced requirement**: TR-need-system-013. The copy-semantics AC (read out the
  anchor set, rebuild a fresh instance, mutations to the copy don't leak back) can
  be implemented now with provisional accessor names. The final accessor names are
  fixed by the Save & Persistence GDD / ADR-0003 — expect a small rename then.
- **Depends on**: Time Service epic (`TimeService`, `FakeTimeSource`, `GameRoot`,
  resume handler) and Pet Definition Data epic (`Need.Id`, `CareAction.Id`,
  `NeedProfile`, `CareProfile`, `tests/helpers/pet_data_factory.gd`).
- **GDScript traps pinned as ACs**: `elapsed_seconds / 3600.0` (integer division
  drops sub-hour decay); `ceili()` not `int()` for `seconds_until_sad`; compare
  with `<=`, not `==`, at the threshold.
- **Out of scope**: `reanchor_with_cap()` (Offline Time Simulation); its resume
  slot runs as a no-op until that epic exists.
- **ADVISORY integration check**: `NeedCrossingScheduler` on a real device, foreground
  and backgrounded across a crossing — evidence in `production/qa/evidence/`.
- **Stale registry**: `design/registry/entities.yaml` Need System entries predate
  the 2026-09-22 revision (rate-switched sleep). Stories use the GDD, not the registry.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Need anchors, need_value and derived state](story-001-need-value-and-state.md) | Logic | Ready | ADR-0001, ADR-0002 |
| 002 | [apply_care, re-anchoring and the care signals](story-002-apply-care-and-signals.md) | Logic | Ready | ADR-0002, ADR-0001 |
| 003 | [Queries: seconds_until_sad, next_crossing_utc, urgency ranking](story-003-need-queries.md) | Logic | Ready | ADR-0001 |
| 004 | [Crossing detection: check_crossings and on_resumed](story-004-crossing-detection.md) | Logic | Ready | ADR-0001 |
| 005 | [Anchor set copy semantics for Save](story-005-anchor-ownership.md) | Logic | Ready (names provisional) | N/A — pending ADR-0003 |
| 006 | [NeedCrossingScheduler and GameRoot wiring](story-006-scheduler-and-wiring.md) | Integration | Ready | ADR-0001, ADR-0002 |
| 007 | [On-device crossing check (ADVISORY)](story-007-on-device-crossing-check.md) | Integration (manual) | Ready — needs export presets + devices | ADR-0001 |

Build order: 001 → 002 → 003 and 004 (either order) → then 005 and 006 (005 needs 004; 006 needs 002–004) → 007. Story 001 needs Time Service 002 and Pet Definition Data 002; Story 006 needs Time Service 004 and Pet Definition Data 007.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/need-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Start with the foundation epics. Once their prerequisites are done, run `/story-readiness production/epics/need-system/story-001-need-value-and-state.md`.
