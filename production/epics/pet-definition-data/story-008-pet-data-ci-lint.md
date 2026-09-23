# Story 008: CI lint for pet-data forbidden patterns

> **Epic**: Pet Definition Data
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S (~2 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/pet-definition-data.md` (Core Rule 3)
**Requirement**: `TR-pet-definition-data-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Pet Catalog Loading, Injection and Immutability
**ADR Decision Summary**: The setter guards can't cover engine `SpriteFrames` mutators, `duplicate()` (which yields an unlocked copy because `_locked` isn't stored) or a second `load()` with `CACHE_MODE_IGNORE` — CI lint closes those gaps.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: The 12 `SpriteFrames` mutators in 4.7: `add_frame`, `remove_frame`, `set_frame`, `clear`, `clear_all`, `add_animation`, `remove_animation`, `rename_animation`, `duplicate_animation`, `set_animation_speed`, `set_animation_loop`, `set_animation_loop_mode`. `clear` is a common method name — scope that pattern so it doesn't flag unrelated `Array.clear()` calls (see Implementation Notes).

**Control Manifest Rules (this layer)**:
- Required: each lint follows the existing `clock-discipline` job's `VIOLATIONS=… || true` pattern and error format
- Forbidden: `sprite_frames_mutation`, `definition_duplicate`, `pet_data_load_outside_loader`, `dictionary_in_definition_schema` — this story enforces all four
- Guardrail: lint searches `src/` only; `tests/` and `tools/` are excluded (tests duplicate deliberately; the placeholder tool writes sprite files)

---

## Acceptance Criteria

*From ADR-0002 §2 and `docs/registry/architecture.yaml`, scoped to this story:*

- [ ] **sprite_frames_mutation** — CI fails on any of the 12 mutators called on a `SpriteFrames` value under `src/`
- [ ] **definition_duplicate** — CI fails on `.duplicate(` / `.duplicate_deep(` in any `src/` file that names a `*Definition`, `NeedProfile`, `NeedParams`, `CareProfile` or `FormRule*` type
- [ ] **pet_data_load_outside_loader** — CI fails on `load(`, `preload(` or `ResourceLoader.` with a `res://assets/data/pets/` path anywhere under `src/` except `src/core/pet_data/pet_catalog_loader.gd`
- [ ] **dictionary_in_definition_schema** — CI fails on a `Dictionary`-typed `@export` in any `src/core/pet_data/` file
- [ ] Each lint is proven by planting a probe locally and seeing it fail, then removing it and seeing it pass; outputs recorded in the evidence doc

---

## Implementation Notes

*Derived from ADR-0002 §2:*

- Add a `pet-data-discipline` job to `.github/workflows/tests.yml` next to `clock-discipline` (or extend that job's steps — keep one step per pattern so failures name the rule).
- `SpriteFrames` mutators: grep calls whose receiver is typed or named as sprite frames — practical heuristic: flag the 11 unambiguous mutators anywhere under `src/`, and flag `.clear(` / `.clear_all(` only on lines containing `sprite_set` or `SpriteFrames`. Document the heuristic's limit in the job comment.
- `duplicate` rule is file-scoped per ADR-0002: a file is suspect if it names one of the types; then any `.duplicate(` in it fails.
- Error messages cite the pattern name, ADR-0002 and the offending lines.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Time Service Story 003: the `TimeProvider` lint
- Runtime guards (Stories 001–002)

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted).*

For each of the four rules:

- **AC-n**: `[rule]` catches a violation
  - Given: a throwaway probe file under `src/` containing one violation (e.g. `sprite_set.add_frame(&"idle", tex)`; `species.duplicate()` in a file declaring `var s: SpeciesDefinition`; `load("res://assets/data/pets/bloop/bloop.tres")` in `src/gameplay/`; `@export var extra: Dictionary` in `src/core/pet_data/`)
  - When: the job's grep runs locally
  - Then: exits non-zero naming the file and rule
  - Edge cases: after removing the probe it exits 0; `pet_catalog_loader.gd` loading the manifest does not trip rule 3; `some_array.clear()` in an unrelated file does not trip rule 1

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- The CI job in `.github/workflows/tests.yml`, green on the branch
- `production/qa/evidence/pet-data-lint-evidence.md` — probe outputs (fail then pass) for each rule

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007 must be DONE (the real loader and schema files exist to exempt and scan)
- Unlocks: None
