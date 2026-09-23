# Story 005: PetCatalog and build_catalog

> **Epic**: Pet Definition Data
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (~3 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/pet-definition-data.md`
**Requirement**: `TR-pet-definition-data-013`, `TR-pet-definition-data-012`, `TR-pet-definition-data-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Pet Catalog Loading, Injection and Immutability
**ADR Decision Summary**: `PetCatalogLoader.build_catalog(candidates, strict)` validates, applies the injected build-type policy, indexes by `StringName`, locks every accepted species and serves a `PetCatalog` whose lookups return `null` for unknown ids.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: `String`/`StringName` dictionary-key mismatch (godot#62957) — insert every index key as `StringName` and type every lookup parameter `StringName` so the call converts a `String` argument. Story 001's Verification #3 pins the behaviour. Typed returns must return on every path (4.7).

**Control Manifest Rules (this layer)**:
- Required: `build_catalog` does no I/O; `strict` is injected, never read from `OS` inside the loader
- Forbidden: `definition_duplicate`; `autoload_access_from_logic` (the catalog is not an Autoload — ADR-0002 Alternative 4)
- Guardrail: a failed catalog is a state, not a crash

---

## Acceptance Criteria

*From GDD `design/gdd/pet-definition-data.md` and ADR-0002 §4 / Validation Criteria, scoped to this story:*

- [ ] `PetCatalog.state` moves `UNLOADED → VALIDATING → READY` or `→ FAILED`, and is read-only to callers
- [ ] `strict = true` with any validator error → each error `push_error`ed, state `FAILED`, nothing registered
- [ ] `strict = false` → bad species excluded (absent from both `get_all_species()` and `get_hatchable_species()`), each error logged, state `READY` with the rest; warnings `push_warning`ed in both modes (GDD AC, Rule 12)
- [ ] GDD AC (Rule 13) — `get_species(id)` / `get_form(id)` with an unknown id return `null`; a `String` argument (`"nope"`) behaves the same as a `StringName`; `get_species("bloop")` resolves
- [ ] GDD AC (Rule 2) — `StringName(String(s))` round-trip resolves to the identical definition object
- [ ] GDD AC (Rule 3) — two calls to `get_species()` with the same id return the identical object (reference equality)
- [ ] GDD AC (Rule 13) — with one retired and one non-retired species, `get_all_species()` returns both, `get_species()` resolves the retired one, `get_hatchable_species()` returns only the non-retired one; both lists are read-only arrays
- [ ] GDD AC (Rule 11) — a `FormRuleTable` read back from the catalog iterates its rules in authored order
- [ ] Every accepted species is locked when state reaches `READY`

---

## Implementation Notes

*Derived from ADR-0002 §4–5:*

- Files: `src/core/pet_data/pet_catalog.gd` (`class_name PetCatalog extends RefCounted`, `enum State { UNLOADED, VALIDATING, READY, FAILED }`), `src/core/pet_data/pet_catalog_loader.gd` (`class_name PetCatalogLoader extends RefCounted`, `static func build_catalog(candidates: Array[SpeciesDefinition], strict: bool) -> PetCatalog`).
- Sequence: state `VALIDATING` → `CatalogValidator.new().validate()` → apply policy → build the species index and the form index (keyed by `StringName`) → `lock()` every accepted species → `make_read_only()` both list results → `READY`.
- `state` as a getter-only property; the loader sets it through a package-private method (e.g. `_set_state`) — GDScript has no real privacy, so document the convention.
- `READY` with zero hatchable species is **not** decided here (PDD OQ#10 → Hatching Onboarding). Expose the empty list and make no decision.
- The debug-build `assert(catalog.state == READY)` belongs in `GameRoot` (Story 007), not here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: `load_catalog(manifest_path, strict)` (file I/O) and the `GameRoot` call
- Story 008: CI lint
- Save & Persistence: what a missing species *means* for a live pet

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted). The developer implements against these — do not invent new test cases during implementation.*

Species come from `PetDataFactory`; "invalid" means a 3-color palette.

- **AC-1**: strict failure
  - Given: `[valid, invalid]`, `strict = true`
  - When: `build_catalog`
  - Then: `state == FAILED`; `get_all_species()` empty; one error logged for the invalid species
- **AC-2**: release exclusion
  - Given: `[valid, invalid]`, `strict = false`
  - Then: `state == READY`; `get_all_species()` and `get_hatchable_species()` each contain only the valid one; `get_species(invalid.id)` is `null`
- **AC-3**: warnings in both modes
  - Given: a valid species with an unreachable rule, built once with `strict = true` and once `false`
  - Then: both `READY`, each logs one warning
- **AC-4**: unknown ids
  - Given: a `READY` catalog with `bloop`
  - When: `get_species(&"nope")`, `get_species("nope")`, `get_form(&"nope")`, `get_form("nope")`
  - Then: all `null`; `get_species("bloop")` returns the bloop definition
- **AC-5**: id round-trip
  - Given: `var s := &"bloop"`
  - When: `get_species(StringName(String(s)))`
  - Then: `is_same()` with `get_species(s)`
- **AC-6**: same object to all consumers
  - Given: a `READY` catalog
  - Then: `is_same(get_species(&"bloop"), get_species(&"bloop"))`; same for `get_form`
- **AC-7**: retired vs hatchable
  - Given: species `a` (retired) and `b` (not retired)
  - Then: `get_all_species()` has both; `get_species(&"a")` resolves; `get_hatchable_species()` is `[b]`
  - Edge cases: `append` on either returned array leaves the catalog's lists unchanged
- **AC-8**: authored rule order
  - Given: a species with rules A, B, C
  - Then: `get_species(id).form_rules.rules` iterates A, B, C
- **AC-9**: locked at `READY`
  - Given: a `READY` catalog
  - When: `get_species(&"bloop").display_name = "x"`
  - Then: unchanged, error logged
- **AC-10**: state transitions
  - Given: `PetCatalog.new()` — Then: `state == UNLOADED`
  - Given: an empty candidate list, `strict = false` — Then: `READY` with empty lists, no crash

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/pet_definition_data/pet_catalog_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 003 and 004 must be DONE
- Unlocks: Story 007; Need System epic (profiles from a real catalog)
