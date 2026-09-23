# Epic: Pet Definition Data

> **Layer**: Foundation
> **GDD**: design/gdd/pet-definition-data.md
> **Architecture Module**: `src/core/pet_data/` (schema, validator, loader, catalog) + `assets/data/pets/` (manifest and `bloop` content). *No `docs/architecture/architecture.md` exists (compressed path, 2026-09-22) — module boundaries are taken from ADR-0002 §1–5.*
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories pet-definition-data`

## Overview

Implements the read-only content layer that says what a pet *is*: the code enums
(`Need.Id`, `CareAction.Id`, `LifeStage.Id`), the typed `DefinitionResource`
schema classes with setter guards and a recursive `lock()`, the pure
`CatalogValidator`, the `PetCatalogLoader` (with an injected `strict` build-type
flag), and the `PetCatalog` with its four lookups. It also delivers the first
content: `catalog_manifest.tres` and the `bloop` species with its provisional arc,
need/care profiles and form rule table. `GameRoot` (from the Time Service epic)
loads the catalog synchronously in `_ready()` before any logic object is built.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Pet Catalog Loading, Injection and Immutability | Typed `.tres` Resources via one manifest of `ext_resource` refs; pure validator; setter guards + recursive lock + CI lint; injected `PetCatalog`, unknown id → `null` | HIGH |
| ADR-0001: Time and Event Injection | Composition root and constructor injection that the catalog wiring reuses | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-pet-definition-data-001 | Needs, actions, stages are code enums | ADR-0002 §1 ✅ |
| TR-pet-definition-data-002 | Id grammar, uniqueness, `StringName` in memory / `String` persisted | ADR-0002 §4 ✅ |
| TR-pet-definition-data-003 | Enforced immutability after `Ready` | ADR-0002 §2 ✅ |
| TR-pet-definition-data-004 | `SpeciesDefinition` schema | ADR-0002 §1 ✅ |
| TR-pet-definition-data-005 | `StageDefinition`; bloop arc 0/3/4/2 | ADR-0002 §1 ✅ |
| TR-pet-definition-data-006 | `AdultFormDefinition` | ADR-0002 §1 ✅ |
| TR-pet-definition-data-007 | Animation contract (`SpriteFrames`) | ADR-0002 §1 ✅ |
| TR-pet-definition-data-008 | Palette 4–8 colors | ADR-0002 §1 ✅ |
| TR-pet-definition-data-009 | `NeedProfile` ranges | ADR-0002 §1 ✅ |
| TR-pet-definition-data-010 | `CareProfile` ranges | ADR-0002 §1 ✅ |
| TR-pet-definition-data-011 | `FormRuleTable` shape and authored order | ADR-0002 §1 ✅ |
| TR-pet-definition-data-012 | Load-time validation; strict vs release policy; unreachable-rule warning | ADR-0002 §4 ✅ |
| TR-pet-definition-data-013 | Four lookups; unknown → `null` | ADR-0002 §4 ✅ |
| TR-pet-definition-data-014 | New species = file + manifest entry, no code change | ADR-0002 §3 ✅ |

## Carried Constraints and Checks

- **Before the first story's code** (ADR-0002 Verification #1–#4, local 4.7.1):
  loader runs `@export` setters on load with `_locked == false`; `Object.set()` on a
  locked definition hits the setter and is rejected; `String` argument resolves a
  `StringName`-keyed lookup; `Array[T].make_read_only()` rejects `append`, `[i] =`
  and `sort()` without crashing.
- **GDD amendment owed before the validator story** (Core Rule 12): Need System's
  checks `floor < sad_threshold < 100` and `decay_per_hour ≥ 0.01` (need-system.md
  Open Questions); OQ#8 (retired species need ≥1 form of any status) and OQ#11
  (`min_share` range `(0, 1]`) change the same rule. Fold them in together.
- **Test layout**: unit tests build definitions via `tests/helpers/pet_data_factory.gd`
  and never load `.tres`; the shipped-catalog fixture does file I/O and lives in
  `tests/integration/pet_definition_data/` (ADR-0002 §5, OQ#13). The GDD AC still
  names `tests/unit/` — the ADR path wins.
- **CI lint** (ADR-0002 §2): the 12 `SpriteFrames` mutators under `src/`;
  `.duplicate(`/`.duplicate_deep(` on definition types outside `tests/`; `load`/
  `ResourceLoader` on `res://assets/data/pets/` outside `PetCatalogLoader`.
- **Before the first export build**: a manifest-only `.tres` is included in Android
  and iOS exports under both export filters (Verification #5).
- **Before this epic closes (on a real exported build)**: `catalog.state == READY`
  and `get_all_species().size() > 0` on Android and iOS (Verification #6,
  godot#98798). Fallback: untyped manifest array cast in the loader.
- **Open GDD questions not blocking this epic**: OQ#3/#12 (32×32 sprite constant,
  LCD Renderer), OQ#5 (Life Stage & Growth), OQ#10 (zero hatchable species,
  Hatching Onboarding), OQ#13 backlog items.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/pet-definition-data.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- The exported-build catalog check above is recorded in `production/qa/evidence/`

## Next Step

Run `/create-stories pet-definition-data` to break this epic into implementable stories.
