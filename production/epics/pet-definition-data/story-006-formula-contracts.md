# Story 006: Formula contracts: care_action_share and total_arc_days

> **Epic**: Pet Definition Data
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (~1 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/pet-definition-data.md` (Formulas)
**Requirement**: `TR-pet-definition-data-011` (share semantics), `TR-pet-definition-data-005` (arc)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR: N/A — pure math over definition values, no architectural pattern required
**ADR Decision Summary**: —

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: `a / n` with two `int`s is integer division in GDScript — `care_action_share` must convert to `float` first or `9 / 20` returns `0`.

**Control Manifest Rules (this layer)**:
- Required: static, pure functions; no state
- Forbidden: none specific
- Guardrail: the 7–10 day band is a *warning* for designer review, never a load failure (GDD Formulas)

---

## Acceptance Criteria

*From GDD `design/gdd/pet-definition-data.md`, scoped to this story:*

- [ ] GDD AC — `care_action_share(9, 20)` returns `0.45`
- [ ] `care_action_share` with `total_actions_in_window = 0` does not divide by zero — returns a documented sentinel and never crashes (the *meaning* of an empty window is Life Stage & Growth's, PDD OQ#5)
- [ ] GDD AC — `total_arc_days` for bloop's thresholds (`baby=3`, `child=4`, `adult_days_to_nearly_grown=2`) equals `9`
- [ ] GDD AC — a balance smoke check computing `total_arc_days` for any species outside `[7, 10]` produces a warning for designer review, not a load failure

---

## Implementation Notes

- File: `src/core/pet_data/pet_formulas.gd` — `class_name PetFormulas extends RefCounted` with static functions:
  - `static func care_action_share(action_count: int, total_actions_in_window: int) -> float` — `float(action_count) / float(total_actions_in_window)`; for `total == 0` return `-1.0` and document it as "undefined; caller decides" (a negative value can never satisfy a `min_share` in `(0, 1]`).
  - `static func total_arc_days(species: SpeciesDefinition) -> int` — `baby.days_to_advance + child.days_to_advance + adult_days_to_nearly_grown`; the egg and the graduation press are excluded by definition.
  - `static func arc_band_warning(species: SpeciesDefinition) -> String` — empty inside `[7, 10]`, otherwise a message naming the species and its arc length. Keep the band as named constants.
- Story 007's shipped-catalog fixture calls `arc_band_warning` for every shipped species.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Life Stage & Growth: counting care actions over the window and evaluating rules
- Story 007: running the band check over the shipped catalog

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: share worked example
  - Given: `action_count = 9`, `total = 20`
  - Then: `care_action_share` returns `0.45` (compare with `is_equal_approx`)
  - Edge cases: `(0, 20)` → `0.0`; `(20, 20)` → `1.0` — an integer-division implementation fails `(9, 20)`
- **AC-2**: empty window
  - Given: `(0, 0)` — Then: returns `-1.0`, no error, no crash
- **AC-3**: bloop arc
  - Given: a factory species with `baby=3`, `child=4`, `adult_days_to_nearly_grown=2`
  - Then: `total_arc_days` returns `9`
  - Edge cases: `egg.days_to_advance` set to 5 does not change the result
- **AC-4**: band warning
  - Given: arcs of 6, 7, 10, 11 days
  - Then: 6 and 11 produce a non-empty warning naming the species; 7 and 10 produce `""`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/pet_definition_data/pet_formulas_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 must be DONE (uses `SpeciesDefinition` and the factory)
- Unlocks: Story 007
