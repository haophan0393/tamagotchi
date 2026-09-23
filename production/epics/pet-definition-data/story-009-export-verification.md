# Story 009: Export verification on Android and iOS

> **Epic**: Pet Definition Data
> **Status**: Ready — needs export presets and devices
> **Layer**: Foundation
> **Type**: Integration (manual on-device evidence)
> **Estimate**: M (~3 h) **plus** first-time Android/iOS export setup if Time Service Story 005 hasn't done it
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/pet-definition-data.md` (load before first frame; Core Rule 14)
**Requirement**: `TR-pet-definition-data-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Pet Catalog Loading, Injection and Immutability
**ADR Decision Summary**: Species are reached only through the manifest's `ext_resource` references so export dependency tracking pulls them into the PCK; this story proves that and that the typed array actually deserialises non-empty on device.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: Two distinct failure modes. (a) **Export drop** — a manifest-only `.tres` missing from the PCK under a filtered preset. (b) **godot#98798** — the file is present but `Array[CustomResource]` arrives empty in an exported build (filed against 4.4.dev3, not confirmed fixed in 4.7.1). Multi-hop `ext_resource` inclusion under filtered exports is only moderately documented.

**Control Manifest Rules (this layer)**:
- Required: the check reads `GameRoot`'s catalog; it adds no second load of pet data
- Forbidden: `pet_data_load_outside_loader` — the debug readout must not `load()` pet files itself
- Guardrail: prove it on an exported build, not editor play

---

## Acceptance Criteria

*From ADR-0002 Verification Required (#5, #6), scoped to this story:*

- [ ] **V5** — `bloop.tres` (reached only via the manifest) is present in the Android and iOS export under the default "export all resources" filter **and** a "selected scenes/resources" filter
- [ ] **V6** — on a real exported build on Android and iOS: `catalog.state == READY` and `get_all_species().size() > 0`
- [ ] Results recorded per platform in the evidence doc, with device model and OS version
- [ ] If V5 fails under the filtered preset: switch the preset to "export all resources" and record it (ADR-0002 Risks — don't debug the filter)
- [ ] If V6 fails (godot#98798 reproduces): change `CatalogManifest.species` to an untyped `Array` and cast in `PetCatalogLoader`, re-run V6, and record the change; schema and consumers stay unchanged

---

## Implementation Notes

*Derived from ADR-0002 Verification Required and Risks:*

- Needs Android and iOS export presets, signing and physical devices. Share the setup with Time Service Story 005 — whichever runs first creates the presets.
- V5: inspect the exported PCK (Godot's PCK explorer or `--export-pack` then list contents) for `assets/data/pets/bloop/bloop.tres` (or its `.res` remap).
- V6: a debug-only on-screen readout in `GameRoot` (or a debug child node) showing `catalog.state` and the species count. Don't ship it in release.
- Also note in evidence whether the shipped-catalog integration test (Story 007) passes against an exported build if run there — optional, informative.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Time Service Story 005: lifecycle and timezone device checks (same devices, separate evidence)
- Release signing and store builds

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted). Manual verification.*

- **V5**: species included in the PCK
  - Setup: export Android and iOS with each of the two filter settings
  - Verify: PCK contents list the bloop species file
  - Pass condition: present in all four exports (or, after the documented fallback, in the "export all resources" exports)
- **V6**: catalog loads on device
  - Setup: install the exported debug build on a real Android and a real iOS device
  - Verify: the readout on launch
  - Pass condition: `READY` and species count ≥ 1 on both platforms

---

## Test Evidence

**Story Type**: Integration (manual)
**Required evidence**:
- `production/qa/evidence/pet-data-export-evidence.md` — V5 and V6 per platform, device model, OS version, screenshots of the readout and PCK listing

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007 must be DONE; Android and iOS export presets and devices available
- Unlocks: closing the Pet Definition Data epic
