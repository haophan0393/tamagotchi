# Story 002: Schema classes, guarded setters and the test factory

> **Epic**: Pet Definition Data
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (~3–4 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/pet-definition-data.md`
**Requirement**: `TR-pet-definition-data-003` through `TR-pet-definition-data-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Pet Catalog Loading, Injection and Immutability
**ADR Decision Summary**: Nine typed `DefinitionResource` subclasses hold the schema, every `@export` field has a guarded setter, needs and actions are named fields rather than enum-indexed arrays, and there are no `Dictionary` fields.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: Inline `@export` initialisers don't run setters — defaults are unaffected by the guard; don't "fix" that. Renaming a `class_name` after `.tres` content exists can break typed arrays until each file is resaved (godot#92068) — pick names now and keep them.

**Control Manifest Rules (this layer)**:
- Required: every `@export` field uses the `if _reject_write(&"field"): return` setter pattern
- Forbidden: `dictionary_in_definition_schema`; `definition_duplicate` (except in `tests/`)
- Guardrail: schema field names are a contract — a change after the first dependent is built needs an ADR (Core Rule 14)

---

## Acceptance Criteria

*From GDD `design/gdd/pet-definition-data.md`, scoped to this story:*

- [ ] The nine classes exist in `src/core/pet_data/` with exactly the fields in ADR-0002 §1: `SpeciesDefinition`, `StageDefinition`, `AdultFormDefinition`, `NeedProfile`, `NeedParams`, `CareProfile`, `FormRuleTable`, `FormRule`, `ShareCondition`
- [ ] `NeedProfile.get_params(need: Need.Id) -> NeedParams` and `CareProfile.get_restore_amount(action: CareAction.Id) -> int` map every enum value to its named field
- [ ] `SpeciesDefinition.retired` defaults to `false` (Core Rule 4); `AdultFormDefinition.palette_override` defaults to empty (= none) (Core Rule 6)
- [ ] GDD AC (Core Rule 3) — after `lock()`, writes by assignment, `set()`, and `append` on each array field are ignored, the value is unchanged and an error is logged
- [ ] A reflection test walks every `DefinitionResource` subclass and fails if any `@export` field accepts a write after `lock()` (catches a forgotten setter — ADR-0002 Validation Criteria)
- [ ] `tests/helpers/pet_data_factory.gd` builds a valid, complete species in code (no `.tres`), with per-field overrides, for every later test

---

## Implementation Notes

*Derived from ADR-0002 §1–2 and §5:*

- Field list (ADR-0002 §1 table):
  - `SpeciesDefinition`: `id: StringName`, `display_name: String`, `palette: Array[Color]`, `egg`/`baby`/`child: StageDefinition`, `adult_forms: Array[AdultFormDefinition]`, `form_rules: FormRuleTable`, `need_profile: NeedProfile`, `care_profile: CareProfile`, `adult_days_to_nearly_grown: int`, `retired: bool`
  - `StageDefinition`: `sprite_set: SpriteFrames`, `days_to_advance: int`
  - `AdultFormDefinition`: `id`, `display_name`, `sprite_set`, `palette_override: Array[Color]`, `hidden`, `retired`
  - `NeedProfile`: `hunger`, `cleanliness`, `fun`, `sleep: NeedParams`
  - `NeedParams`: `decay_per_hour: float`, `sad_threshold: int`, `floor: int`
  - `CareProfile`: `feed`, `clean`, `play`, `lights: int` (restore amounts)
  - `FormRuleTable`: `window_days: int`, `rules: Array[FormRule]` (authored order), `default_form_id: StringName`
  - `FormRule`: `form_id: StringName`, `conditions: Array[ShareCondition]`
  - `ShareCondition`: `action: CareAction.Id`, `min_share: float`
- Use `match` in `get_params` / `get_restore_amount`, with a final branch that `push_error`s and returns `null` / `0` so the typed return is satisfied on every path (4.7 rule).
- `SpriteFrames` is an engine class and is **not** guarded here — Story 008's lint covers it. The reflection test should skip it.
- Factory defaults should match the bloop MVP values (decay 3.0, sleep 1.5, threshold 40, floor 0, restore 100) so tests read naturally, and use 1-frame 32×32 `SpriteFrames` built in memory with every required animation name.
- Ranges are **not** enforced here — the validator does that (Stories 003–004). Setters only guard the lock.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 003–004: validation of every range and structural rule
- Story 005: locking at catalog `Ready`
- Story 007: `.tres` authoring

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: profile accessors cover every enum value
  - Given: a factory `NeedProfile` with distinct `decay_per_hour` per need, and a `CareProfile` with distinct restore amounts
  - When: `get_params(n)` for each `Need.Id` and `get_restore_amount(a)` for each `CareAction.Id`
  - Then: each returns the matching named field
- **AC-2**: defaults
  - Given: `SpeciesDefinition.new()` and `AdultFormDefinition.new()`
  - Then: `retired == false`; `palette_override.is_empty()`
- **AC-3**: write-after-lock by assignment
  - Given: a factory species, `lock()`ed
  - When: `species.display_name = "x"`, `species.need_profile.hunger.decay_per_hour = 99.0`
  - Then: both unchanged; an error logged for each
- **AC-4**: write-after-lock by `set()`
  - Given: a locked factory species
  - When: `species.set(&"adult_days_to_nearly_grown", 99)`
  - Then: unchanged; an error logged
- **AC-5**: write-after-lock on arrays
  - Given: a locked factory species
  - When: `append` on `palette`, `adult_forms`, `form_rules.rules`, and a rule's `conditions`
  - Then: every array size is unchanged; no crash
- **AC-6**: reflection guard
  - Given: one factory instance of each of the nine classes, each `lock()`ed
  - When: every `@export` property (except `SpriteFrames`) is written via `set()` with a different valid value
  - Then: every value is unchanged
  - Edge cases: the test lists the nine classes explicitly and fails if a new `DefinitionResource` subclass appears in `src/core/pet_data/` without being added
- **AC-7**: the factory builds a complete species
  - Given: `PetDataFactory.species()`
  - Then: every field in the list above is non-null and non-empty where required

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/pet_definition_data/schema_immutability_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE
- Unlocks: Stories 003, 004, 005, 006
