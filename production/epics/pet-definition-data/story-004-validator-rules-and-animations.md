# Story 004: CatalogValidator, part 2 (form rules and animation contract)

> **Epic**: Pet Definition Data
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (~3 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/pet-definition-data.md`
**Requirement**: `TR-pet-definition-data-007`, `TR-pet-definition-data-011`, `TR-pet-definition-data-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Pet Catalog Loading, Injection and Immutability
**ADR Decision Summary**: The same pure `CatalogValidator` also checks each species' `FormRuleTable` and `SpriteFrames` animation contract; unreachable rules are warnings, not rejections.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: `SpriteFrames` read API: `has_animation(name)`, `get_animation_names()`, `get_frame_count(anim)`, `get_frame_texture(anim, idx)`, `get_animation_speed(anim)`, `get_animation_loop(anim)` — confirm names against the 4.7 class reference before use. Frame-size validation reads each frame texture's `get_size()`; cost is negligible at MVP scale (ADR-0002 Performance).

**Control Manifest Rules (this layer)**:
- Required: read-only use of `SpriteFrames` — never call a mutator
- Forbidden: `sprite_frames_mutation`
- Guardrail: an unreachable rule degrades to "default form", so it warns and never rejects (GDD Edge Cases)

---

## Acceptance Criteria

*From GDD `design/gdd/pet-definition-data.md` (Rule 11 as amended in Story 003), scoped to this story:*

- [ ] GDD AC (Rule 11) — `window_days ≥ 1`; every `form_id` in the rules and `default_form_id` exists among that species' adult forms; every `min_share` in `(0.0, 1.0]`; no `FormRule` with two `ShareCondition`s on the same action; each rule has 1–2 conditions
- [ ] GDD AC (Rules 11, 12) — a rule on distinct actions whose `min_share` sum exceeds 1.0 loads successfully and produces exactly one warning naming the species id, the rule index and the sum
- [ ] GDD AC (Rule 7) — baby, child and every adult form provide `idle_content`, `idle_sad`, `greeting`, `react_feed`, `react_clean`, `react_play`, `react_lights`, `stage_up`; adult forms also `nearly_grown` and `graduate`; the egg only `idle` and `hatch`; any missing required name rejects the species (no fallback to idle)
- [ ] Every required animation has ≥1 frame, `fps` in 1–12, and every frame is exactly 32×32 px
- [ ] Extra animation names beyond the required set are accepted

---

## Implementation Notes

*Derived from ADR-0002 §1, §4 and PDD Core Rules 7, 11, 12:*

- Add the checks as new private functions in `catalog_validator.gd`, called from `validate()` next to Story 003's.
- Keep the required-name lists and the 32 px frame size as named constants at the top of the validator. The 32×32 value is provisional (PDD OQ#3/#12, owned by LCD Screen Renderer) — one constant, so changing it later is one line.
- Warning text shape: `"%s: form_rules.rules[%d] is unreachable (min_share sum %.2f > 1.0)"`.
- Reachability only needs the sum check because conditions within a rule target distinct actions (Rule 11). Don't try to reason across rules.
- A `null` `sprite_set` is a rejection, reported once, not a crash on the next line.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: ids, structure, ranges, palette, profiles
- Story 007: the shipped-catalog CI fixture that fails the build on an unreachable rule
- Palette *conformance* of pixels (asset audit, not load time — Rule 8)
- Life Stage & Growth: evaluating the rule table

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted). The developer implements against these — do not invent new test cases during implementation.*

All cases start from `PetDataFactory.species()` (valid) and override one field.

- **AC-1**: window and references
  - Given: `window_days = 0` — Then: rejected
  - Given: a rule with `form_id = &"ghost"` — Then: rejected, error names `ghost`
  - Given: `default_form_id = &"ghost"` — Then: rejected
- **AC-2**: `min_share` range (amended)
  - Given: `min_share` −0.1, 0.0, 0.01, 1.0, 1.01 — Then: −0.1, 0.0 and 1.01 rejected; 0.01 and 1.0 accepted
- **AC-3**: condition shape
  - Given: a rule with two conditions on `play` — Then: rejected
  - Given: a rule with zero conditions; a rule with three — Then: both rejected
- **AC-4**: unreachable rule warns once
  - Given: a rule `play ≥ 0.6 AND feed ≥ 0.5`
  - Then: species accepted; `warnings.size() == 1`; the warning contains the species id, `rules[0]` and `1.10`
  - Edge cases: `play ≥ 0.5 AND feed ≥ 0.5` (sum exactly 1.0) — no warning
- **AC-5**: authored order preserved in the result
  - Given: three rules in order A, B, C — Then: the accepted species' `form_rules.rules` is A, B, C
- **AC-6**: required animations
  - Given: the baby sprite set missing `react_lights` — Then: rejected, error names the stage and `react_lights`
  - Given: an adult form missing `graduate` — Then: rejected
  - Given: an egg with only `idle` and `hatch` — Then: accepted
  - Edge cases: a sprite set with an extra `dance` animation — accepted
- **AC-7**: frame and timing constraints
  - Given: one frame of 32×31 px in `idle_content` — Then: rejected
  - Given: an animation with 0 frames — Then: rejected
  - Given: fps 0 and fps 13 — Then: rejected; fps 1 and 12 accepted
  - Given: `sprite_set = null` on the child stage — Then: rejected with one error, no crash

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/pet_definition_data/catalog_validator_rules_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 must be DONE (Story 003 for the amended `min_share` wording in the GDD)
- Unlocks: Story 005
