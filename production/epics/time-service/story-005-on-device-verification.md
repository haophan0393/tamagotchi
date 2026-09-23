# Story 005: On-device lifecycle and timezone verification

> **Epic**: Time Service
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration (manual on-device evidence)
> **Estimate**: M (~3–4 h) **plus** first-time Android/iOS export setup if not done elsewhere
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/time-service.md` (Open Questions: `PAUSED`/`RESUMED` on 4.7; DST/timezone on device)
**Requirement**: `TR-time-service-005`, `TR-time-service-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Time and Event Injection
**ADR Decision Summary**: The lifecycle adapter and the `TimeSource` bias contract rest on three engine behaviours that can only be proven on real phones; this story closes ADR-0001's on-device Verification #1–#3.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: godotengine/godot#37571 — `Time.get_time_zone_from_system().bias` has shown **opposite signs on different platforms for the same zone** (Windows vs Android, UTC+8); the 4.7 docs state no convention. Must be checked **independently on Android and on iOS**. `NOTIFICATION_APPLICATION_*` reaching a non-root child is inferred, not documented.

**Control Manifest Rules (this layer)**:
- Required: the `TimeSource` contract stays "minutes **east** of UTC" whatever the platforms report — any correction lives inside `SystemTimeSource`
- Forbidden: engine clock APIs outside `system_time_source.gd`, including in any debug overlay built for this check (read through `TimeProvider.service` from `src/core/app/`, or keep the overlay under `prototypes/`)
- Guardrail: a Timer measures a delay, never elapsed wall time

---

## Acceptance Criteria

*From ADR-0001 Verification Required (on device), scoped to this story:*

- [ ] **V1** — on a real Android device and a real iOS device, `app_backgrounded` and `app_resumed` each fire exactly once for: home button, app switcher, and lock screen; and the notifications reach `AppLifecycle` as a non-root child
- [ ] **V2** — on each platform, with the device set to a known positive-offset zone (e.g. Tokyo, UTC+9) and a known negative-offset zone (e.g. Los Angeles), `SystemTimeSource.get_timezone_bias_minutes()` returns `+540` and `−420`/`−480` (DST-dependent) respectively
- [ ] **V3** — a one-shot `Timer` started before backgrounding, which expires while the app is suspended, fires at most once on resume (no burst of stale timeouts)
- [ ] Results for all three recorded per platform in the evidence doc, with device model and OS version
- [ ] If V2 shows a platform reporting the opposite sign: `SystemTimeSource` gains an `OS.get_name()` branch that normalises to minutes east, and the evidence doc records the before/after readings
- [ ] If V1 shows notifications don't reach a non-root child: Story 004's fallback is applied (handler moved into `GameRoot`) and re-verified

---

## Implementation Notes

*Derived from ADR-0001 Verification Required and Risks:*

- Needs Android and iOS export presets, signing, and physical devices — **none exist yet**. If the Pet Definition Data epic's export checks (ADR-0002 Verification #5/#6) run first, reuse that export setup; otherwise this story sets it up.
- Build a minimal on-screen debug readout (under `prototypes/` or a debug-only node in `src/core/app/`) showing: a counter per lifecycle signal, the current `get_timezone_bias_minutes()`, and a Timer timeout counter. Don't ship it in a release build.
- For V3, start a 10 s one-shot Timer, background the app for 60 s, resume, and read the timeout counter (expected `0` or `1`, never more).
- The desktop editor cannot answer any of this: `PAUSED`/`RESUMED` are mobile-only and the bias sign is exactly what differs per platform.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- DST-transition behaviour of `is_new_calendar_day` (accepted limitation; revisit with Offline Time Simulation / Life Stage & Growth)
- Need System's ADVISORY on-device crossing check (Need System epic)

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted). Manual on-device verification.*

- **V1**: lifecycle notifications on device
  - Setup: debug build on the device with the lifecycle counters visible
  - Verify: press home → reopen; open the app switcher → return; lock → unlock. Read both counters after each
  - Pass condition: each action increments `app_backgrounded` and `app_resumed` by exactly 1, on both Android and iOS
- **V2**: timezone bias sign
  - Setup: set device timezone manually (automatic timezone off) to Tokyo, relaunch; then Los Angeles, relaunch
  - Verify: the displayed bias value
  - Pass condition: Tokyo = `+540`; Los Angeles = `−420` (PDT) or `−480` (PST) — on both platforms after any `SystemTimeSource` correction
- **V3**: stale Timer on resume
  - Setup: start a 10 s one-shot Timer, then background immediately
  - Verify: wait 60 s, resume, read the timeout counter
  - Pass condition: counter is `0` or `1`, never `≥ 2`, on both platforms

---

## Test Evidence

**Story Type**: Integration (manual)
**Required evidence**:
- `production/qa/evidence/time-service-on-device-evidence.md` — V1–V3 per platform, device model, OS version, screenshots or photos of the readout

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 must be DONE; Android and iOS export presets and devices available
- Unlocks: closing the Time Service epic
