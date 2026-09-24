# Story 001: Code enums and the DefinitionResource base

> **Epic**: Pet Definition Data
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S–M (~2–3 h)
> **Manifest Version**: N/A — no control manifest (compressed path); rules below come from `docs/registry/architecture.yaml` forbidden_patterns (2026-09-23)
> **Last Updated**: 2026-09-24

## Context

**GDD**: `design/gdd/pet-definition-data.md`
**Requirement**: `TR-pet-definition-data-001`, `TR-pet-definition-data-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Pet Catalog Loading, Injection and Immutability
**ADR Decision Summary**: Definitions are typed custom `Resource`s extending one `DefinitionResource` base, whose non-exported `_locked` flag gates every guarded setter; `lock()` walks stored properties recursively and makes arrays read-only.

**Engine**: Godot 4.7.1 | **Risk**: HIGH
**Engine Notes**: No post-cutoff APIs; relies on `Resource`, `@export` typed arrays, `Array.make_read_only()` and property setters. ADR-0002 Verification #1–#4 must run on local 4.7.1 **before** the schema is built on top of this base (Story 002). Inside schema classes use `floorf()` / `floori()` — `NeedParams.floor` will shadow the global `floor()`.

**Control Manifest Rules (this layer)**:
- Required: `_locked` is a plain `var`, never `@export` — it must not serialise or survive `duplicate()`
- Forbidden: `dictionary_in_definition_schema`; `definition_duplicate`
- Guardrail: a rejected write never crashes — `push_error` and ignore, in all build types (Pillar 2)

---

## Acceptance Criteria

*From GDD `design/gdd/pet-definition-data.md` and ADR-0002 §1–2, scoped to this story:*

- [x] GDD AC (Core Rule 1) — `src/core/pet_data/pet_enums.gd` defines exactly four needs (`hunger`, `cleanliness`, `fun`, `sleep`), four care actions (`feed`, `clean`, `play`, `lights`) and four life stages (`egg`, `baby`, `child`, `adult`), in that order, as `Need.Id`, `CareAction.Id`, `LifeStage.Id`, not sourced from data
- [x] `DefinitionResource._reject_write(field)` returns `false` when unlocked, and `true` plus a `push_error` naming `resource_path` and the field when locked
- [x] `DefinitionResource.lock()` sets `_locked`, recurses into `DefinitionResource` values, calls `make_read_only()` on `Array` values and `lock()` on their `DefinitionResource` elements; calling it twice is harmless
- [x] ADR-0002 Verification #1–#4 run on local 4.7.1 and each result recorded in the story's completion notes

---

## Implementation Notes

*Derived from ADR-0002 §1–2 and Verification Required:*

- Files: `src/core/pet_data/pet_enums.gd`, `src/core/pet_data/definition_resource.gd` (`class_name DefinitionResource extends Resource`).
- `lock()` iterates `get_property_list()` filtered by `PROPERTY_USAGE_STORAGE`. Skip `_locked` itself and engine-owned properties (`resource_*`, `script`).
- Needs and actions are **named fields** on the profiles (Story 002), not enum-indexed arrays — the enums here are for callers' parameters (`get_params(need: Need.Id)`).
- **Verification probes** (put them in the test file; they stay as regression tests):
  1. Load a tiny fixture `.tres` (`tests/fixtures/pet_data/probe_definition.tres`, a one-field `DefinitionResource` subclass defined under `tests/`) and assert its guarded setter ran with `_locked == false` — e.g. the setter increments a non-exported counter.
  2. After `lock()`, `obj.set(&"field", v)` leaves the value unchanged and logs an error.
  3. A `Dictionary` keyed by `StringName` resolves when looked up through a function with a `StringName`-typed parameter that is passed a `String` literal (godot#62957).
  4. `Array[T].make_read_only()` → `append`, `[i] =` and `sort()` each leave the array unchanged, log an error, and don't crash.
- If a probe fails, stop and record it: ADR-0002 Risks lists the fallback for each (e.g. #1 failing is safe — storage bypasses the setter; the guard stays correct).
- Doc-comment every public method.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the nine schema classes and their guarded setters
- Story 005: the catalog calling `lock()` at `Ready`
- Story 008: CI lint for `duplicate()` and `Dictionary` fields

---

## QA Test Cases

*Written at story creation (solo mode — qa-lead not consulted). The developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: exactly four of each enum
  - Given: `Need.Id`, `CareAction.Id`, `LifeStage.Id`
  - When: their `keys()` are read
  - Then: `[HUNGER, CLEANLINESS, FUN, SLEEP]`, `[FEED, CLEAN, PLAY, LIGHTS]`, `[EGG, BABY, CHILD, ADULT]` exactly, in order
- **AC-2**: `_reject_write` gates on the lock
  - Given: a test subclass of `DefinitionResource` with one guarded `@export var value: int`
  - When: `value = 5` before `lock()`, then `value = 9` after
  - Then: `value == 5`, and exactly one error was logged, naming the field
- **AC-3**: `lock()` recurses and freezes arrays
  - Given: a test definition holding a nested `DefinitionResource` and an `Array[DefinitionResource]` of two elements
  - When: `lock()` on the outer object
  - Then: the nested object and both elements reject writes; `append` on the array leaves its size at 2
  - Edge cases: `lock()` called twice raises no error; an empty array is locked without error
- **AC-4 to AC-7**: Verification probes #1–#4 as in Implementation Notes, one test each; each asserts the documented expected behaviour

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/pet_definition_data/definition_resource_test.gd` — must exist and pass

**Status**: [x] Created — 15 tests, all passing (suite 49/49, 2026-09-24)

---

## Dependencies

- Depends on: None (can run in parallel with Time Service story 001)
- Unlocks: Story 002

---

## Completion Notes
**Completed**: 2026-09-24
**Criteria**: 4/4 passing (all covered by automated tests)
**Deviations** (advisory, docs amended 2026-09-24):
- Enums live in three files — `pet_enums.gd` (`Need`), `care_action.gd` (`CareAction`), `life_stage.gd` (`LifeStage`) — because GDScript allows one global `class_name` per script and callers use bare `Need.Id`. ADR-0002 §1 amended.
- `lock()` returns early when already locked (idempotent and cycle-safe) — ADR-0002 §2 amended.
**ADR-0002 Verification on local 4.7.1**:
- #1 PASS — `ResourceLoader` runs the guarded `@export` setter during `.tres` load while `_locked == false` (`setter_call_count == 1`, `value == 42`).
- #2 PASS — `obj.set(&"value", 9)` on a locked definition goes through the setter: one `push_error`, value unchanged.
- #3 PASS — a `String` literal passed to a `StringName`-typed parameter resolves a `StringName`-keyed `Dictionary`.
- #4 PARTIAL — the array is never modified and the process never crashes, but only `append()`/`sort()` are non-fatal C++ errors (gdUnit4 captures them as `Condition "_p->read_only" is true.`); `arr[i] = v` is a GDScript runtime error (`Invalid assignment on read-only value (on base: 'Array[int]').`) that aborts the calling function. ADR-0002 §2 amended; new forbidden pattern `definition_array_index_write` in `docs/registry/architecture.yaml`; lint AC added to Story 008.
**Test Evidence**: Logic — `tests/unit/pet_definition_data/definition_resource_test.gd` (15 tests); fixtures in `tests/fixtures/pet_data/`
**Code Review**: Complete — CHANGES REQUIRED (lock() entry guard) + suggestions, all applied 2026-09-24; godot-gdscript-specialist and qa-tester consulted
**Standards change**: narrow exception for loading read-only `res://tests/fixtures/` resources in unit tests (`.claude/docs/coding-standards.md`, `.claude/rules/test-standards.md`) — user ruling 2026-09-24
