# ADR-0002: Pet Catalog Loading, Injection and Immutability

## Status
Proposed

## Date
2026-09-23

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core (resources, data loading) |
| **Knowledge Risk** | HIGH — 4.4–4.7 are post-LLM-cutoff (VERSION.md) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `current-best-practices.md`, `modules/mobile-export.md`; 4.7 class reference for `Resource` and `Array` (fetched 2026-09-23) |
| **Post-Cutoff APIs Used** | None directly. Relies on long-standing `Resource`, `@export` typed arrays, `Array.make_read_only()`, and GDScript property setters. The 4.7 rule that typed returns must return on every path applies to all lookups |
| **Verification Required** | **Before the first Pet Definition Data `/dev-story`** (local 4.7.1): (1) `ResourceLoader` runs `@export` property setters while loading a `.tres`, and `_locked` is still `false` at that point (source-confirmed by the godot-specialist 2026-09-23: the loader calls `Object::set()` per property after `_init()`, and a typed array arrives as one whole-array `set()`; one test pins it); (2) `Object.set(&"field", v)` on a locked definition goes through the GDScript setter and is rejected; (3) a `Dictionary` keyed by `StringName` resolves when a lookup's `StringName` parameter is passed a `String` literal (the typed parameter converts it); (4) `Array[T].make_read_only()` rejects `append`, `[i] =` and `sort()` with a logged error and no crash. **Before the first export build:** (5) a `.tres` reached only through the manifest's `ext_resource` references is included in an Android and an iOS export with the default "export all resources" filter **and** with a "selected scenes/resources" filter. **On a real exported build, not editor play:** (6) `catalog.state == READY` and `get_all_species().size() > 0` on Android and iOS. That the file is in the PCK doesn't prove the typed array deserialised non-empty (godot/godot#98798). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (composition root, constructor injection, no Autoload access from logic) |
| **Enables** | ADR-0003 (planned): save format, schema versioning and missing-species handling, which build on the id and lookup contract fixed here |
| **Blocks** | Foundation epic stories for Pet Definition Data and Need System (Need System's constructor takes `NeedProfile`/`CareProfile`) |
| **Ordering Note** | Covers only the **definition** half of PDD Open Question #1. How a *save file* stores species/form ids, and how it migrates across content updates, is deferred until the Save & Persistence GDD is approved |

## Context

### Problem Statement
Pet Definition Data is the most depended-on schema in the project (8 dependents). Its GDD sends four questions to this ADR: the file format for definitions (OQ#1, definition half), how the catalog is loaded and reaches consumers (OQ#2), how Core Rule 3's "immutable at runtime, enforced" is actually enforced (OQ#2), and what an unknown-id lookup returns (OQ#9). Need System, the first gameplay system to be coded, reads `NeedProfile` and `CareProfile`, so all four answers are needed before its first `/dev-story`.

### Constraints
- ADR-0001: logic classes take collaborators through `_init()`, never read an Autoload, and `GameRoot` is the only composition root.
- Coding standard: unit tests do no file I/O, so validation must be testable on in-memory definitions.
- **4.7 `Resource` has no read-only mode.** `Array.make_read_only()` exists but is **shallow**. `ResourceLoader` caches by path and hands every `load()` the same shared instance.
- Content must be authorable in the Godot inspector without code changes (PDD Core Rule 14, Pillar 5).
- Mobile export: dynamically built resource paths risk being silently left out of the PCK (godot-specialist, 2026-09-22).
- MVP catalog: 1 species; loading must finish before the first frame.

### Requirements
- Every consumer gets the identical definition object (PDD AC: reference equality).
- A post-`Ready` write to any definition field is rejected at runtime, and a test proves it (PDD AC, Core Rule 3).
- Validation implements PDD Core Rule 12. It hard-fails in dev and excludes the bad species in release, and the build type is injectable for tests.
- An unknown id returns a defined result, never a silent default.

## Decision

**Definitions are typed custom `Resource`s authored as `.tres`. They are reached only through one manifest `Resource` that references each species directly, loaded once by `PetCatalogLoader` in `GameRoot`, validated by a pure `CatalogValidator`, locked recursively, and served by an injected `PetCatalog` whose lookups return `null` for unknown ids. Per-pet consumers receive the specific profile they need, not the catalog.**

### 1. Schema as Resources

All schema classes live in `src/core/pet_data/` and extend one base:

```gdscript
class_name DefinitionResource extends Resource
var _locked: bool = false          # NOT exported — never serialised, never copied by duplicate()
```

| Class | Holds | PDD rule |
|---|---|---|
| `SpeciesDefinition` | `id: StringName`, `display_name`, `palette: Array[Color]`, `egg`/`baby`/`child: StageDefinition`, `adult_forms: Array[AdultFormDefinition]`, `form_rules: FormRuleTable`, `need_profile: NeedProfile`, `care_profile: CareProfile`, `adult_days_to_nearly_grown: int`, `retired: bool` | 4 |
| `StageDefinition` | `sprite_set: SpriteFrames`, `days_to_advance: int` | 5, 7 |
| `AdultFormDefinition` | `id`, `display_name`, `sprite_set`, `palette_override: Array[Color]` (empty = none), `hidden`, `retired` | 6 |
| `NeedProfile` | `hunger`, `cleanliness`, `fun`, `sleep: NeedParams`; `get_params(need: Need.Id) -> NeedParams` | 9 |
| `NeedParams` | `decay_per_hour: float`, `sad_threshold: int`, `floor: int` | 9 |
| `CareProfile` | `feed`, `clean`, `play`, `lights: int` (restore amounts); `get_restore_amount(action: CareAction.Id) -> int` | 10 |
| `FormRuleTable` / `FormRule` / `ShareCondition` | as PDD Core Rule 11, with `rules: Array[FormRule]` in authored order | 11 |

- The code enums (PDD Core Rule 1) are `Need.Id`, `CareAction.Id` and `LifeStage.Id`, in `src/core/pet_data/pet_enums.gd`. Needs and actions are **named fields** on the profiles, not enum-indexed arrays, so the inspector labels them and a mis-ordered array can't silently swap two needs.
- **No `Dictionary` fields anywhere in the schema.** `make_read_only()` is shallow and dictionaries can't be setter-guarded per key.
- `sprite_set` uses the engine's `SpriteFrames` (animation names, `fps`, `loop` per PDD Core Rule 7).

### 2. Immutability — setter guards plus a recursive lock

Every `@export` field has a guarded setter:

```gdscript
@export var decay_per_hour: float = 3.0:
	set(value):
		if _reject_write(&"decay_per_hour"):
			return
		decay_per_hour = value
```

- `DefinitionResource._reject_write(field: StringName) -> bool` returns `true` and calls `push_error("Definition is immutable after catalog Ready: %s.%s" % [resource_path, field])` when `_locked`. Otherwise it returns `false`. It fires in **all build types**. The write is ignored, never applied, and nothing crashes (Pillar 2: never a crash for the player).
- `DefinitionResource.lock() -> void` sets `_locked = true` and then walks `get_property_list()` for `PROPERTY_USAGE_STORAGE` properties. A `DefinitionResource` value gets `lock()`. An `Array` value gets `make_read_only()` and then `lock()` on each `DefinitionResource` element. Locking is idempotent.
- Setters guard dynamic writes too, since `set()`, `set_indexed()` and inspector-style writes all go through them (Verification #2).
- **Not covered by the guard, closed by CI lint instead:**
  - `SpriteFrames` is an engine class and can't be guarded. CI fails on any of the 12 4.7 mutators under `src/`: `add_frame`, `remove_frame`, `set_frame`, `clear`, `clear_all`, `add_animation`, `remove_animation`, `rename_animation`, `duplicate_animation`, `set_animation_speed`, `set_animation_loop` or `set_animation_loop_mode`.
  - `duplicate()`/`duplicate_deep()` on a definition would produce an **unlocked** copy, because `_locked` isn't stored. CI fails on `.duplicate(`/`.duplicate_deep(` in any file that names a `*Definition`, `NeedProfile`, `NeedParams`, `CareProfile` or `FormRule*` type, outside `tests/`. (Also closes PDD OQ#13's "`duplicate()` ban".)
  - A second `load()` with `CACHE_MODE_IGNORE` would bypass the lock. Only `PetCatalogLoader` may call `load`/`ResourceLoader` on `res://assets/data/pets/`, and CI enforces it.

### 3. Files and the manifest

```
assets/data/pets/
  catalog_manifest.tres          # CatalogManifest
  bloop/
    bloop.tres                   # SpeciesDefinition (forms, profiles, rule table as sub-resources)
    sprites/…                    # SpriteFrames .tres + atlas PNGs
```

- `CatalogManifest extends Resource` has `@export var species: Array[SpeciesDefinition]`, filled by dragging `.tres` files in the inspector. They are stored as `ext_resource` references, **never as path strings**, so Godot's export dependency tracking pulls every species into the PCK (Verification #5). Adding a species means creating the file and adding it to the manifest, with no code change (PDD Core Rule 14).
- One species per file, with its forms, profiles and rule table as embedded sub-resources. Sprite sets may be external `.tres` files so they can be shared and reimported.

### 4. Loading, validation, catalog

```gdscript
class_name CatalogValidator extends RefCounted        # pure; no I/O
func validate(candidates: Array[SpeciesDefinition]) -> CatalogValidationResult

class_name CatalogValidationResult extends RefCounted
var accepted: Array[SpeciesDefinition]
var errors: Array[String]      # one per rejected species × violation
var warnings: Array[String]    # e.g. FormRule min_share sum > 1.0 (PDD Core Rule 12)

class_name PetCatalogLoader extends RefCounted
static func load_catalog(manifest_path: String, strict: bool) -> PetCatalog
static func build_catalog(candidates: Array[SpeciesDefinition], strict: bool) -> PetCatalog   # no I/O; used by tests

class_name PetCatalog extends RefCounted
enum State { UNLOADED, VALIDATING, READY, FAILED }
var state: State                                     # read-only
func get_species(id: StringName) -> SpeciesDefinition     # null if unknown
func get_form(id: StringName) -> AdultFormDefinition      # null if unknown
func get_all_species() -> Array[SpeciesDefinition]        # read-only array, includes retired
func get_hatchable_species() -> Array[SpeciesDefinition]  # read-only array, retired == false
```

- **Sequence** (`build_catalog`): state `VALIDATING` → `CatalogValidator.validate()` → apply the build-type policy → build `StringName`-keyed indexes for species and forms → `lock()` every accepted species → `make_read_only()` the two list results → `READY`.
- **Build-type policy is injected** as `strict: bool` (PDD OQ#13). `GameRoot` passes `OS.is_debug_build()`, and tests pass either value. `strict == true` with any error → `push_error` for each, state `FAILED`, and nothing registered. `strict == false` → bad species are excluded, each error is `push_error`ed, and the catalog is `READY` with the rest. Warnings are `push_warning`ed in both modes.
- **Unknown id → `null`**, for both lookups. That pins the result PDD Open Question #9 asked for; the PDD AC's "null or explicit error" becomes "null". Callers must null-check. Save & Persistence owns what a missing species *means*.
- `READY` with zero hatchable species is left to PDD OQ#10 (Hatching Onboarding). `PetCatalog` exposes the empty list and makes no decision.

### 5. Injection

- `GameRoot` (ADR-0001) calls `PetCatalogLoader.load_catalog("res://assets/data/pets/catalog_manifest.tres", OS.is_debug_build())` synchronously in `_ready()`, before any logic object is constructed. In a debug build, `assert(catalog.state == PetCatalog.State.READY)` stops boot on bad content.
- **Per-pet consumers receive profiles, not the catalog.** `NeedSystem._init(time: TimeService, needs: NeedProfile, care: CareProfile)`. Consumers that genuinely need lookups (Save & Persistence, Hatching Onboarding, Graduation & Album) receive the `PetCatalog`.
- Unit tests build definitions with factory functions in `tests/helpers/pet_data_factory.gd`. They never load `.tres`. The shipped-catalog CI fixture (PDD AC, OQ#6) does real file I/O, so it lives in `tests/integration/pet_definition_data/`, per PDD OQ#13.

### Architecture Diagram

```
 assets/data/pets/catalog_manifest.tres ──ext_resource──▶ bloop/bloop.tres (SpeciesDefinition tree)
                    │ load() — only here
          ┌─────────▼──────────┐   candidates   ┌──────────────────┐
          │  PetCatalogLoader  │───────────────▶│ CatalogValidator │ pure, unit-tested
          │  (strict injected) │◀───────────────│  → Result        │
          └─────────┬──────────┘   accepted/err └──────────────────┘
                    │ index by StringName · lock() tree · make_read_only lists
          ┌─────────▼──────────┐
          │ PetCatalog (READY) │  get_species/get_form → object | null
          └─────────┬──────────┘
                    │ constructed in GameRoot._ready() (ADR-0001)
     ┌──────────────┼───────────────────────────────┐
     ▼              ▼                               ▼
 NeedSystem(time, need_profile, care_profile)   SaveService(catalog, …)   Hatching/Album(catalog)
```

## Alternatives Considered

### Alternative 1: JSON files parsed into plain RefCounted objects
- **Description**: Species authored as `.json` and parsed by hand into getter-only value objects.
- **Pros**: Diff-friendly, engine-agnostic, and immutability is natural (no setters).
- **Cons**: No inspector authoring and no `SpriteFrames` integration, so sprite references become path strings, which is exactly the silent export-drop risk. A hand-written schema parser also carries its own test burden.
- **Rejection Reason**: Loses Godot's authoring and export dependency tracking to solve a problem that setter guards solve more cheaply.

### Alternative 2: Read-only wrapper objects over the Resources
- **Description**: The loader copies every `.tres` into a parallel set of getter-only `RefCounted` classes, and consumers never see a `Resource`.
- **Pros**: Airtight. No `_locked` flag and no lint for the schema itself.
- **Cons**: Every schema type exists twice, and the ~30 fields need copy code kept in sync. `SpriteFrames` would still be shared by reference, so it needs the same lint anyway.
- **Rejection Reason**: Twice the schema surface for a guarantee the setter guards already give; the remaining holes (SpriteFrames, duplicate) are the same in both designs.

### Alternative 3: Convention plus CI lint only
- **Description**: No runtime guard; CI fails on assignments to definition fields outside the loader.
- **Rejection Reason**: A grep can't see `set()`, `set_indexed()` or writes through a variable. PDD's AC requires a runtime rejection *or* a detection that actually works, and grep can only approximate it.

### Alternative 4: Catalog Autoload
- **Description**: A `PetCatalog` Autoload read directly by consumers.
- **Rejection Reason**: Forbidden by ADR-0001 (`autoload_access_from_logic`).

## Consequences

### Positive
- Designers edit species in the inspector, and a new species is a new file plus one manifest entry.
- Every consumer shares one locked object graph, so reference equality comes for free.
- Validation is unit-testable with no file I/O, and the build-type policy is testable both ways.
- Need System's tests need nothing but a `NeedProfile` and a `CareProfile`.

### Negative
- Setter boilerplate on every exported field (~30 today). A missed setter is a silent hole, so the "every exported field is guarded" rule gets its own test (Validation Criteria).
- Three new CI lint rules to maintain (SpriteFrames mutators, `duplicate`, pet-data `load`).
- `get_species()` returns `null`, and every caller has to handle it.

### Risks
- **The ResourceLoader doesn't call setters on load, or calls them after something locks** → Verification #1. If setters aren't called, fields still load (the storage path bypasses the setter) and the guard stays correct. If a loaded field ever arrives after `lock()`, it would be rejected, which the validator's range checks would surface immediately at boot.
- **Deferred `@export` default values** — inline initialisers don't run setters, so defaults are unaffected. Noted so no one "fixes" that.
- **`StringName`/`String` dictionary key mismatch** — a documented 4.x inconsistency (godot/godot#62957): a `Dictionary` can treat `"bloop"` and `&"bloop"` as different keys. Mitigation: every index key is inserted as `StringName`, every lookup parameter is typed `StringName` so the call converts, and there is a test that looks up with a `String` literal (Verification #3).
- **Species silently missing from a mobile export** → Verification #5. The manifest stores references, not paths, and the integration fixture asserts the manifest's species count after an export smoke test.
- **Typed `@export` arrays load empty in exported builds** (godot/godot#98798: filed against 4.4.dev3, not confirmed fixed in 4.7.1; setters don't fire and `Array[CustomResource]` arrives empty). This is distinct from the export-drop risk: the file is present but the data isn't. Mitigation: Verification #6 on the first export. If it reproduces, fall back to storing the manifest's species as an untyped `Array` and casting in `PetCatalogLoader`, which keeps the schema and consumers unchanged.
- **Multi-hop `ext_resource` inclusion** under a filtered export is only moderately documented. If Verification #5 fails, switch the preset to "export all resources" rather than debug the filter.
- **Renaming a `DefinitionResource` subclass's `class_name`** after content exists can break `Array[CustomResource]` properties in authored `.tres` until each is resaved (godot/godot#92068). Any schema rename (already ADR-worthy under PDD Core Rule 14) must include "resave every `.tres` under `assets/data/pets/`".
- **`NeedParams.floor` shadows the global `floor()`** inside that class. External access (`params.floor`) is unaffected. Inside schema classes, use the typed `floorf()`/`floori()`, which don't collide.
- **`duplicate()` really does produce a writable copy** (confirmed: only `PROPERTY_USAGE_STORAGE` properties are copied, so `_locked` resets to `false`). The CI ban in §2 is required, not optional.
- **Hot reload in the editor** re-creates resources unlocked. This only affects editor iteration; runtime builds are unaffected.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| pet-definition-data.md | OQ#1 (definition half) — storage format | §1, §3: typed `.tres` Resources plus a manifest |
| pet-definition-data.md | OQ#2 — catalog wiring and injection | §4–5: `PetCatalogLoader` in `GameRoot`; profiles or catalog injected via `_init()` |
| pet-definition-data.md | Core Rule 3 + AC — immutability enforced, with a test | §2: setter guards, recursive `lock()`, read-only arrays, CI lint for the gaps |
| pet-definition-data.md | AC — same object to all consumers | One locked instance graph held by `PetCatalog` |
| pet-definition-data.md | Core Rule 2 — `StringName` ids, persisted as `String` | Indexes keyed by `StringName`; lookups typed `StringName` |
| pet-definition-data.md | Core Rule 12 + ACs — dev hard error, release exclusion, warnings | §4: pure `CatalogValidator`, injected `strict` policy |
| pet-definition-data.md | Core Rule 13 — four lookups; OQ#9 unknown id | §4: exact signatures; unknown → `null` |
| pet-definition-data.md | Core Rule 14 — new species without code change | §3: manifest plus one file per species |
| pet-definition-data.md | OQ#13 — injectable build-type flag; shipped-catalog fixture out of `tests/unit/`; `duplicate()` ban | §4 `strict`; §5 `tests/integration/`; §2 lint |
| pet-definition-data.md | AC — load before first frame | Synchronous load in `GameRoot._ready()`; 1 species |
| need-system.md | Reads `NeedProfile` (decay, threshold, floor) and `CareProfile.restore_amount` | §5: injected into `NeedSystem._init()`; `get_params()` / `get_restore_amount()` |

## Performance Implications
- **CPU**: One-time validation of a few hundred fields at boot; negligible. No per-frame cost.
- **Memory**: One shared definition graph; sprite atlases dominate (~tens of KB per species at 32×32).
- **Load Time**: One manifest plus one species `.tres` and its sprite sets, loaded synchronously before the first frame (PDD AC).
- **Network**: N/A.

## Migration Plan
No production code exists. The first Pet Definition Data `/dev-story` creates `src/core/pet_data/` (enums, `DefinitionResource`, the schema classes, validator, loader, catalog), `tests/helpers/pet_data_factory.gd`, `assets/data/pets/catalog_manifest.tres` and `bloop.tres` with placeholder `SpriteFrames` that satisfy the animation contract. It also adds the three lint rules (the SpriteFrames list is the full set of 12 mutators) next to `clock-discipline` in `.github/workflows/tests.yml`.

## Validation Criteria
- A unit test locks a factory-built species and attempts writes via assignment, `set()` and `append` on each array field. Every attempt logs an error and leaves the value unchanged.
- A reflection test walks every `DefinitionResource` subclass and asserts that each `@export` field rejects writes after `lock()`, which catches a forgotten setter.
- `build_catalog()` with one invalid species: `strict=true` → `FAILED`; `strict=false` → `READY` without it.
- `get_species(&"nope")` and `get_species("nope")` both return `null`; `get_species("bloop")` resolves.
- The integration fixture loads the real manifest and asserts `READY`, at least one hatchable species, and no warning for an unreachable rule.

## Related Decisions
- ADR-0001 — time and event injection (composition root, constructor injection)
- ADR-0003 (planned) — save format, schema versioning, missing-species handling
- design/gdd/pet-definition-data.md, design/gdd/need-system.md
