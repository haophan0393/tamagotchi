# Story 003: CatalogValidator, part 1 (ids, structure, ranges, palette)

> **Epic**: Pet Definition Data
> **Status**: Ready (pre-work: GDD amendment, wording approved 2026-09-23)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (~3–4 h, including the GDD edit)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/pet-definition-data.md`
**Requirement**: `TR-pet-definition-data-002`, `-004`, `-005`, `-006`, `-008`, `-009`, `-010`, `-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Pet Catalog Loading, Injection and Immutability
**ADR Decision Summary**: A pure `CatalogValidator` (no I/O) takes candidate species and returns a `CatalogValidationResult` of accepted species, one error per rejected species × violation, and non-rejecting warnings.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: Id grammar check — use `RegEx` compiled once (`^[a-z][a-z0-9_]*$`), plus `String(id).length() <= 32`. Non-ASCII fails the regex by construction.

**Control Manifest Rules (this layer)**:
- Required: the validator is pure — no `load()`, no file access, no logging decisions (it returns errors; Story 005 applies the policy)
- Forbidden: `pet_data_load_outside_loader`
- Guardrail: one error message per violation, naming the species id and the field

---

## Pre-work: amend PDD Core Rule 12 (approved wording, 2026-09-23)

Before writing code, edit `design/gdd/pet-definition-data.md`:

1. **Core Rule 12** — add to the rejection list: for every need, `floor < sad_threshold < 100` and `decay_per_hour ≥ 0.01` (asks from `need-system.md` Open Questions).
2. **Core Rule 12** — replace "≥1 non-retired adult form" with: a non-retired species needs ≥1 non-retired adult form; a retired species needs ≥1 adult form of any status (PDD OQ#8).
3. **Core Rules 11 and 12** — `min_share` range becomes `(0, 1]`, not `[0, 1]` (PDD OQ#11). The check itself is implemented in Story 004.
4. Update the matching ACs (NeedProfile ranges; the Rule 12 violation list), mark OQ#8 and OQ#11 resolved with today's date, and strike the two Need System Open Questions it closes.
5. Update `TR-pet-definition-data-009` and `-012` requirement text in `docs/architecture/tr-registry.yaml` with a `revised` date (same IDs).

---

## Acceptance Criteria

*From GDD `design/gdd/pet-definition-data.md` (as amended above), scoped to this story:*

- [ ] GDD AC (Rules 2, 12) — ids matching `^[a-z][a-z0-9_]*$`, ≤32 chars pass; uppercase, leading digit, hyphen, non-ASCII, or 33+ chars fail
- [ ] Species ids and form ids are each unique across the whole candidate set; a duplicate rejects the species that repeats it
- [ ] GDD AC (Rule 4) — a species missing any required part (`display_name`, `palette`, any of egg/baby/child, `adult_forms` empty, `form_rules`, `need_profile`, `care_profile`) or with `adult_days_to_nearly_grown < 1` is rejected
- [ ] Amended Rule 12 — non-retired species with zero non-retired forms rejected; retired species with ≥1 form of any status accepted
- [ ] `days_to_advance ≥ 0` for every stage (Rule 5)
- [ ] GDD AC (Rules 8, 12) — palette size outside 4–8 rejected (species palette and any non-empty `palette_override`)
- [ ] GDD AC (Rule 9, amended) — `decay_per_hour ≥ 0.01`; `floor ≥ 0`; `floor < sad_threshold < 100`
- [ ] GDD AC (Rule 10) — `restore_amount` in `[1, 100]` for all four actions
- [ ] A species with several violations produces one error per violation; valid species in the same call are still accepted

---

## Implementation Notes

*Derived from ADR-0002 §4:*

- Files: `src/core/pet_data/catalog_validator.gd` (`class_name CatalogValidator extends RefCounted`), `src/core/pet_data/catalog_validation_result.gd` (`accepted: Array[SpeciesDefinition]`, `errors: Array[String]`, `warnings: Array[String]`).
- `validate(candidates: Array[SpeciesDefinition]) -> CatalogValidationResult`. Structure it as one private check function per rule group so Story 004 adds its checks alongside without touching these.
- Uniqueness is a catalog-level check (needs all candidates); everything else is per species.
- Error message shape: `"%s: %s" % [species_id, violation]`, e.g. `"bloop: need_profile.hunger.sad_threshold (40) must be > floor (50)"`. Tests match on substrings, not full text.
- Pure: do not `push_error` here. Story 005's `build_catalog` logs according to the `strict` policy.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: form rule table checks, `min_share` range, unreachable-rule warning, animation contract and frame size
- Story 005: strict / release policy, logging, catalog state

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted). The developer implements against these — do not invent new test cases during implementation.*

All cases start from `PetDataFactory.species()` (valid) and override one field.

- **AC-1**: valid baseline
  - Given: one factory species — Then: `accepted.size() == 1`, `errors.is_empty()`
- **AC-2**: id grammar
  - Given: ids `&"bloop"`, `&"a"`, `&"a_1"`, and a 32-char id — Then: all accepted
  - Edge cases: `&"Bloop"`, `&"1bloop"`, `&"bl-oop"`, `&"blöop"`, a 33-char id — each rejected with an error naming the id
  - Apply the same set to an adult form id
- **AC-3**: uniqueness
  - Given: two species both `&"bloop"` — Then: an error names the duplicate id
  - Given: two species with a form id in common — Then: an error names the duplicate form id
- **AC-4**: required parts
  - Given: one species per missing part (each of the 8 listed) and one with `adult_days_to_nearly_grown = 0`
  - Then: each is rejected with an error naming the missing or invalid field
- **AC-5**: retired-form rule (amended)
  - Given: a non-retired species whose only form is retired — Then: rejected
  - Given: a retired species whose only form is retired — Then: accepted
- **AC-6**: palette size
  - Given: palettes of 3, 4, 8, 9 colors — Then: 3 and 9 rejected, 4 and 8 accepted
  - Edge cases: a form `palette_override` of 3 rejects the species; an empty override is accepted
- **AC-7**: need profile (amended)
  - Given: `decay_per_hour` 0.0, 0.009, 0.01 — Then: first two rejected, 0.01 accepted
  - Given: `floor = -1` — Then: rejected
  - Given: `floor=40, sad_threshold=40`; `floor=50, sad_threshold=40`; `sad_threshold=100` — Then: all rejected
  - Given: `floor=0, sad_threshold=99` — Then: accepted
- **AC-8**: care profile
  - Given: `restore_amount` 0, 1, 100, 101 on `lights` — Then: 0 and 101 rejected
- **AC-9**: multiple violations
  - Given: one species with a bad id and a 3-color palette, plus one valid species
  - Then: two errors for the bad one; the valid one is in `accepted`
- **AC-10**: stage days
  - Given: `baby.days_to_advance = -1` — Then: rejected

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/pet_definition_data/catalog_validator_structure_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 must be DONE
- Unlocks: Story 005
