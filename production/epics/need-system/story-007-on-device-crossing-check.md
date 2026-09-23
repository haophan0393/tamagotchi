# Story 007: On-device crossing check (ADVISORY)

> **Epic**: Need System
> **Status**: Ready — needs export presets + devices
> **Layer**: Core
> **Type**: Integration (manual on-device evidence) — ADVISORY gate
> **Estimate**: S–M (~2–3 h), reusing the export setup from Time Service Story 005 / Pet Definition Data Story 009
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/need-system.md` (Acceptance Criteria — Production timer adapter, ADVISORY)
**Requirement**: `TR-need-system-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Time and Event Injection
**ADR Decision Summary**: The scheduler adapter is deliberately outside the unit-tested surface; ADR-0001's Validation Criteria require proving on device that a crossed need fires `need_became_sad` exactly once, in the foreground and across a background/resume.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: Depends on Time Service Story 005's V1 (lifecycle notifications on device) and V3 (no stale-Timer burst). If those failed and their fallbacks were applied, run this story against the fallback build.

**Control Manifest Rules (this layer)**:
- Required: the fast-decay test species exists only in a debug build — it must never reach the shipped manifest
- Forbidden: `pet_data_load_outside_loader` — the debug species goes through the manifest and loader like any other
- Guardrail: the shipped-catalog fixture (Pet Definition Data Story 007) must still pass with the debug species excluded

---

## Acceptance Criteria

*From GDD `design/gdd/need-system.md` (ADVISORY) and ADR-0001 Validation Criteria:*

- [ ] With a test species whose hunger crosses about 2 minutes after a fresh anchor, on a real device: (a) left in the foreground past the crossing → `need_became_sad(hunger)` fires without further input; (b) backgrounded across the crossing and resumed → it fires on resume without further input
- [ ] In both cases it fires exactly once (a debug counter shows 1)
- [ ] Checked on Android and on iOS; results, device model and OS version recorded

---

## Implementation Notes

- No need icon exists yet (LCD Screen Renderer has no GDD). Use a debug-only readout — a per-need `need_became_sad` counter plus the current value — in place of "the need icon appears". Record this substitution in the evidence doc.
- Test species: a debug-only `.tres` (e.g. `assets/data/pets/_debug/bloop_fast.tres`, hunger `decay_per_hour = 1800.0` so 100 → 40 takes 2 min) referenced from a **debug-only manifest**. `GameRoot` picks the debug manifest only when a debug flag is set; release builds never see it. Keep the switch in `GameRoot`, not in logic code.
- For (b), background for about 3 minutes so the crossing happens while suspended.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Time Service Story 005: lifecycle and timezone checks
- Pet Definition Data Story 009: export inclusion checks

---

## QA Test Cases

*Manual on-device verification.*

- **Foreground**
  - Setup: debug build with the fast species, fresh launch (anchors at 100 now)
  - Verify: leave the app open for 3 minutes, watching the counter
  - Pass condition: hunger's counter goes `0 → 1` at about the 2-minute mark and stays at 1
- **Background across the crossing**
  - Setup: fresh launch, background within 30 s
  - Verify: wait 3 minutes, resume, read the counter
  - Pass condition: the counter reads 1 on resume, with no press; it doesn't reach 2 later

---

## Test Evidence

**Story Type**: Integration (manual, ADVISORY)
**Required evidence**:
- `production/qa/evidence/need-system-on-device-evidence.md` — both cases per platform, device model, OS version, screenshots

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 must be DONE; Time Service Story 005 done (or its fallbacks applied); export presets and devices available
- Unlocks: closing the Need System epic
