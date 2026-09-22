# Pet Definition Data

> **Status**: Approved (accepted with notes) — 2026-09-22
> **Author**: user + agents
> **Last Updated**: 2026-09-22
> **Implements Pillar**: Pillar 5: Simple Core, Infinite Shells (primary); Pillar 4: Color Is the Character (palettes); indirectly Pillar 2: Never Guilt, Always Welcome (thresholds must never encode punishment)
> **Creative Director Review (CD-GDD-ALIGN)**: Skipped — Solo mode

## Overview

Pet Definition Data is the read-only content layer that describes *what a pet is*: every species, its life stages (egg, baby, child, adult), the adult forms it can grow into, the sprite animations and LCD palette each stage/form uses, and every pet-specific balance value — need decay rates, stage day-thresholds, and the care-style rule table that selects an adult form. It exists because the coding standard forbids hardcoded gameplay values and because Pillar 5 ("Simple Core, Infinite Shells") requires that the game grow through data rather than new mechanics: a new species, a new adult form, or a re-tuned decay curve must be a new or edited data file, never a code change. The player never interacts with this system; it is loaded once at startup and read by six other systems — Need System, Save & Persistence, Life Stage & Growth, LCD Screen Renderer, Care Actions, and Pet Animation & Reactions — none of which hold their own copy of any value defined here. Pet Definition Data holds no runtime state: a pet's *current* hunger, stage, or care history belongs to Save & Persistence; this system only says what the possible values, forms and rules *are*. Because it is the most-depended-on schema in the project, its shape is treated as a contract — schema changes after the first dependent is built are ADR-worthy, and the storage format and versioning strategy are architecture decisions (→ becomes an ADR), not fixed here.

## Player Fantasy

Pet Definition Data has no player fantasy of its own — the player never sees a definition file. What it enables is the game's **Discovery** aesthetic: *"Which adult form will emerge from your care habits? Hidden forms, later shells and species."* That curiosity — "what is it becoming?" — is entirely a property of the data this system holds. The rule table that maps care style to adult form, the number and distinctness of forms a species can grow into, and the visible "nearly grown" state that precedes graduation are all definitions, not code; the fantasy is exactly as rich as the data is. The concept is honest that Discovery does not land at MVP scope (two forms is a binary outcome, solved in one or two arcs) and only becomes real at v1.0's four-plus forms — Pet Definition Data is what makes that expansion a content drop rather than a rewrite, which is the promise of **Pillar 5: Simple Core, Infinite Shells**: *"Growth comes through art and content layers, not new mechanics."*

The secondary fantasy it serves is identity: players talk about graduates as individuals ("my first one was a Bloop") because each species and form has a name, a sprite set and a palette that are distinct and stable — the album's narrative work depends on definitions never drifting after a pet is recorded. And under **Pillar 2: Never Guilt, Always Welcome**, the data must never smuggle punishment back in: no threshold, decay rate or rule-table entry defined here may make a form *unreachable* because of absence or *worse* because of neglect — only *different* because of style.

*`creative-director` not consulted — Solo mode. Review manually before production.*

## Detailed Rules

### Core Rules

1. **Definitions are data, enums are code.** Exactly three things about a pet are fixed in code because Pillar 5 says the core never changes: the four needs (`hunger`, `cleanliness`, `fun`, `sleep`), the four care actions (`feed`, `clean`, `play`, `lights`), and the four life stages (`egg`, `baby`, `child`, `adult`). Everything else — species, forms, sprites, palettes, every number — is a definition loaded from data.

2. **Every definition has a stable, permanent ID.** Species and adult forms carry a `StringName` id, globally unique within its type (e.g. `bloop`, `bloop_playful`). **Id grammar:** ASCII only, matching `^[a-z][a-z0-9_]*$`, at most 32 characters — enforced at load (rule 12). **Type boundary:** in memory an id is a `StringName`; its canonical persisted form is the plain `String` of the name. Save & Persistence converts at its boundary — `String(id)` on write, `StringName(text)` on read — and catalog lookups (rule 13) accept a `StringName` and compare by name equality. A `StringName`'s hash or internal pointer is never persisted, compared across sessions, or used as a key in saved data. IDs are the *only* thing other systems store — Save & Persistence and Graduation & Album reference pets by species id + form id, never by array index or display name. An id, once shipped, is never renamed or reused; retiring a species or form means marking it `retired: true`, not deleting it (the album must still resolve it).

3. **Definitions are immutable at runtime — enforced, not assumed.** The full catalog is loaded once at boot, validated, and thereafter shared read-only by reference. No consumer mutates a definition or holds a private copy of a value. Because a plain GDScript `@export` Resource cannot enforce this on its own, immutability is a contract that MUST be backed by an enforcement mechanism selected in the Open Question #2 ADR. Candidates for that ADR: (a) setter guards on every definition field that `assert`/`push_error` once the catalog reaches `Ready`; (b) the catalog hands out a read-only wrapper rather than the Resource itself; (c) convention plus a CI lint that fails on any assignment to a definition field outside the loader. Whichever is chosen, a test must exist that demonstrates a post-`Ready` write attempt is rejected or detected (see Acceptance Criteria). A pet's *current* need levels, stage, days-in-stage, care history and chosen form are runtime state owned by Save & Persistence.

4. **Species definition.** One species = one definition containing: `id`, `display_name`, one `palette`, three `StageDefinition`s (egg, baby, child), a list of ≥1 `AdultFormDefinition`s, one `FormRuleTable`, one `NeedProfile`, one `CareProfile`, `adult_days_to_nearly_grown` (int ≥ 1: check-in days spent as an adult before the "nearly grown" state), and `retired: bool` (default `false`; a retired species is never offered as a new egg, but existing pets of it keep running and the album keeps resolving it — rule 13).

5. **Stage definitions.** Each of egg/baby/child has: `sprite_set` and `days_to_advance` (int ≥ 0: check-in days in this stage before advancing). Egg is special-cased by convention: `days_to_advance = 0`, and the actual hatch is triggered by the player's first press (Hatching Onboarding) — the value exists so the arc reads uniformly. MVP provisional arc: egg 0 → baby 3 → child 4 → adult 2 → nearly grown → graduate = **~9 check-in days**, inside the concept's 7–10 band.

6. **Adult form definitions.** Each has: `id`, `display_name`, `sprite_set`, optional `palette_override` (a full palette that replaces the species palette for this form only), `hidden: bool` (album shows a silhouette until first graduated), `retired: bool`. The adult stage's day threshold is species-level (rule 4), not per form — all forms of a species live the same length.

7. **Animation contract.** A `sprite_set` is a named collection of frame animations at the fixed pet sprite size (32×32 px — a constant owned by LCD Screen Renderer, provisional). Baby, child and every adult form MUST provide the **core set**: `idle_content`, `idle_sad`, `greeting`, `react_feed`, `react_clean`, `react_play`, `react_lights`, `stage_up`. Adult forms MUST additionally provide `nearly_grown` and `graduate`. The egg provides only `idle` and `hatch`. Each animation declares `fps` (1–12) and `loop: bool`. Any other names are optional extras Pet Animation may use if present. Missing required names fail validation (rule 12) — there is no silent fallback to idle.

8. **Palette.** A palette is an ordered list of 4–8 `Color`s. Every pixel in every frame of a sprite set must use a color from the palette in effect (species palette, or the form's override). Palette conformance is checked at authoring time (asset audit), palette *size* at load time.

9. **Need profile.** For each of the four needs: `decay_per_hour` (float > 0, points per real hour on a fixed 0–100 scale), `sad_threshold` (int 0–100: at or below this the need icon shows and idle switches to `idle_sad`), and `floor` (int ≥ 0, default 0 — the non-fatal minimum). Need System owns *how* decay is applied (live tick, offline catch-up); this profile only supplies the numbers.

10. **Care profile.** For each of the four care actions: `restore_amount` (int 1–100, points restored to its target need). The action→need mapping (feed→hunger, clean→cleanliness, play→fun, lights→sleep) is fixed in code. Care Actions owns cooldowns, mini-game outcome and reaction sequencing.

11. **Form rule table.** `window_days` (int ≥ 1: rolling window in check-in days), an ordered list of `FormRule`s, and a mandatory `default_form_id`. A `FormRule` = `form_id` + 1–2 `ShareCondition`s (ANDed) that MUST target **distinct** actions (two conditions on the same action is a load error, rule 12); a `ShareCondition` = `action` + `min_share` (float 0–1), where *share* = that action's count ÷ all care actions in the window. Because conditions target distinct actions and the shares within one window sum to 1.0, a rule is **unreachable** exactly when its `min_share` values sum above 1.0 — rule 12 warns on this at load and the CI fixture (Acceptance Criteria) blocks it from shipping. Life Stage & Growth evaluates the table at the child→adult transition: first matching rule wins; no match → default. Growth owns what counts as a care action, tie-breaking and the empty-window case — PDD validates only shape. **MVP provisional table** (species `bloop`, window 5): rule 1 → `bloop_playful` if `play ≥ 0.40`; default → `bloop_cozy`.

12. **Load-time validation (fail-fast).** On boot the catalog rejects any species that fails: unique ids (species and form, across the whole catalog); every id matches the rule 2 grammar; every `form_id` in the rule table exists in that species; `default_form_id` exists; ≥1 non-retired adult form; every `min_share` in [0,1]; `window_days ≥ 1`; the `ShareCondition`s within each `FormRule` target distinct actions; every stage and form sprite set has its required animations at the correct frame size; palette size 4–8; all numeric fields within their declared ranges. In dev builds a failure is a hard error; in release the species is excluded from the catalog entirely (absent from both rule 13 lookups) and an error is logged — what happens to a live pet whose species is missing is Save & Persistence's edge case. **Non-rejecting warning:** after a species passes, any `FormRule` whose `min_share` values sum above 1.0 (unreachable, rule 11) logs a warning in every build type; the species still loads. The warning is a dev-time aid — the shipping gate for unreachable rules is the CI unit-test fixture in Acceptance Criteria (Open Question #6, resolved).

13. **Access.** Consumers read through a catalog with four lookups: `get_species(id)`, `get_form(id)`, `get_all_species()`, `get_hatchable_species()`. `get_all_species()` returns every species that passed validation, *including* retired ones — Graduation & Album must resolve a retired species forever. `get_hatchable_species()` returns the subset with `retired == false` and is the only list Hatching Onboarding and the post-graduation new-egg step may draw from. Lookups take a `StringName` (rule 2). Catalog wiring, file format, injection mechanics and the immutability enforcement mechanism (rule 3) → becomes an ADR.

14. **Authoring.** One species = one data file (containing its forms). Adding a species or form is adding/editing a file and listing it in the catalog manifest — never a code change. Editing a shipped species' *numbers* is allowed; changing the *schema* after the first dependent is implemented requires an ADR.

### States and Transitions

Pet Definition Data holds no runtime state. Two state graphs are relevant to it:

**The pet lifecycle it parameterises** (executed by Life Stage & Growth; PDD supplies the thresholds):

| From | To | Trigger | Data source |
|---|---|---|---|
| Egg | Baby | player's first press (onboarding) | `egg.days_to_advance = 0` by convention |
| Baby | Child | `days_to_advance` check-in days elapsed | `baby.days_to_advance` |
| Child | Adult (form chosen) | `days_to_advance` check-in days elapsed; form = rule table result | `child.days_to_advance`, `FormRuleTable` |
| Adult | Nearly grown | `adult_days_to_nearly_grown` check-in days elapsed | species field |
| Nearly grown | Graduated → new Egg | player press | — (no data; Graduation & Album) |

**The catalog's own load state**: `Unloaded → Validating → Ready` or `→ Failed` (nothing registered; game cannot start a pet). No transitions after `Ready`.

### Interactions with Other Systems

| System | Reads from PDD | Writes to PDD | Notes |
|---|---|---|---|
| Need System | `NeedProfile` (decay rates, sad thresholds, floors) | — | Applies decay; PDD never ticks |
| Care Actions | `CareProfile.restore_amount`; which animation name to request | — | Action→need map is code |
| Life Stage & Growth | `days_to_advance` per stage, `adult_days_to_nearly_grown`, `FormRuleTable` | — | Owns the care-history log and rule evaluation |
| Save & Persistence | species/form **ids** only | — | Persists ids as plain `String`, converts to/from `StringName` at its boundary (Core Rule 2); must handle an id missing from the catalog |
| LCD Screen Renderer | active palette (species or form override), sprite frame size | — | Renders within the 4–8 color constraint |
| Pet Animation & Reactions | `sprite_set` by stage/form; animation names, `fps`, `loop` | — | Relies on the required-name contract, no fallback |
| Graduation & Album *(Vertical Slice)* | `display_name`, form `hidden`/`retired`, species `retired`, form sprite for the album; `get_hatchable_species()` for the new egg | — | Must resolve retired ids forever via `get_all_species()` |

Nothing writes to Pet Definition Data at runtime.

*Specialist agents not consulted — Solo mode. Review manually before production.*

Provisional assumptions flagged for downstream GDDs: the 32×32 sprite constant (LCD Renderer), the `bloop` species and its two forms and day thresholds (Growth), the 0–100 need scale (Need System), the empty-window/tie-break rule (Growth).

## Formulas

### care_action_share

The `care_action_share` formula is defined as:

`care_action_share = action_count / total_actions_in_window`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| action_count | a | int | 0 to total_actions_in_window | Count of times one specific care action (feed/clean/play/lights) was performed within the rolling window |
| total_actions_in_window | n | int | ≥ 0 | Total count of all care actions of any kind performed within the rolling `window_days` check-in days |

**Output Range:** 0.0 to 1.0 when `total_actions_in_window > 0`. Undefined at `n = 0` (a window with zero care actions) — Life Stage & Growth's empty-window rule resolves what happens then; PDD's schema only guarantees what the number means when it exists, per Core Rule 11.
**Example:** `window_days = 5` (bloop's MVP table). Across the window the player performed 20 total care actions, 9 of them `play`. `care_action_share(play) = 9 / 20 = 0.45`. Checked against the MVP rule (`play ≥ 0.40`), this window's value would satisfy rule 1 (→ `bloop_playful`) — making that comparison is Life Stage & Growth's job; this formula only defines the number being compared.

### total_arc_days

The `total_arc_days` formula is defined as:

`total_arc_days = baby.days_to_advance + child.days_to_advance + adult_days_to_nearly_grown`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| baby.days_to_advance | b | int | ≥ 0 | Check-in days spent in Baby stage before advancing to Child |
| child.days_to_advance | c | int | ≥ 0 | Check-in days spent in Child stage before advancing to Adult (form chosen here) |
| adult_days_to_nearly_grown | g | int | ≥ 1 | Check-in days spent as Adult before reaching Nearly Grown |

`egg.days_to_advance` is fixed at 0 by convention (Core Rule 5) and excluded — the egg hatches on the player's first press, not on elapsed days. Nearly Grown → Graduate is a player press with no day cost and is also excluded.

**Output Range:** No hard min/max is enforced by the schema — Core Rule 12's load-time validation does not check this value, because the 7–10 check-in day band is a design constraint from `game-concept.md`, not a data-shape constraint. A species definition producing a value outside that band still loads successfully; it should instead be caught as a tuning review item (see Tuning Knobs).
**Example:** bloop = 3 (baby) + 4 (child) + 2 (adult_days_to_nearly_grown) = **9 check-in days**, inside the concept's 7–10 band.

*`systems-designer` not consulted — Solo mode. Review manually before production.*

## Edge Cases

- **If `total_actions_in_window` = 0** (no care actions performed at all within the window at child→adult evaluation time): `care_action_share` is undefined for every action (division by zero). PDD does not resolve this — Core Rule 11 already assigns the empty-window case to Life Stage & Growth. This GDD's only claim is that the formula has no defined value at n=0; Growth's GDD must state what it falls back to (almost certainly `default_form_id`).
- **If a `FormRule`'s `ShareCondition`s are individually valid but jointly impossible** (two ANDed conditions on different actions whose `min_share`s sum above 1.0): the rule is permanently unreachable — no window can ever satisfy it, so evaluation silently falls through to the next rule or the default every time. Resolution (Open Question #6, resolved 2026-09-21): Core Rule 11 requires distinct actions per rule, which makes reachability decidable; Core Rule 12 logs a non-rejecting warning at load; and a CI-blocking unit-test fixture over every shipped species' rule table fails the build on any unreachable rule (see Acceptance Criteria). The species is *not* rejected at load because an unreachable rule degrades to "default form", never to a crash or a punished player.
- **If a species is marked `retired: true` while a player's live pet belongs to it**: the pet keeps running unchanged — `get_species(id)` still resolves it because `get_all_species()` includes retired species (Core Rule 13). Only `get_hatchable_species()` drops it, so the *next* egg cannot be that species. Retiring is therefore always safe for live pets and album entries; only deleting the file (forbidden by Core Rule 2) would break them.
- **If a saved id string does not match the Core Rule 2 grammar** (hand-edited or corrupted save): the catalog lookup returns its defined "not found" result — such an id cannot exist in a validated catalog. Recovery is Save & Persistence's missing-id edge case; PDD guarantees only that no malformed id is ever mistaken for a valid one.
- **If `default_form_id` refers to a form later marked `retired: true`**: the species still passes load validation (Core Rule 12 only requires *some* non-retired adult form to exist, not that the default specifically is one), but any pet that falls through to default now graduates into a retired form. Resolution: authoring convention, not load-enforced — never retire the form a species' `default_form_id` points to without first repointing `default_form_id` to a live form.
- **If `window_days` exceeds the Child stage's `days_to_advance`** (e.g., `window_days = 5` but `child.days_to_advance = 4`): the rolling window, evaluated at the moment of the Child→Adult transition, necessarily includes care actions performed during Baby. This is intentional, not a bug — the window is calendar/check-in-day based, not stage-scoped, and Life Stage & Growth's care-history log is not partitioned by stage. PDD does not validate `window_days` against stage lengths for this reason; a designer who wants the window confined to one stage sets `window_days ≤ child.days_to_advance` manually.
- **If a saved pet references a species id no longer present in the catalog** (removed in a content update): PDD holds no runtime state to lose, so there is nothing here to resolve — this is Save & Persistence's edge case, already deferred to it by Core Rule 12. PDD's only relevant guarantee is Core Rule 2: ids are never renamed or reused, so "missing" can only happen via deliberate removal, never silent rename collision.
- **If a form is both `hidden: true` and `retired: true`**: the album shows a permanent silhouette for a form that can now never be earned to reveal it. This is accepted, not resolved — Core Rule 2 requires the id survive forever once shipped, but no pillar promises every hidden form is eventually revealed. Authoring guidance: only retire a hidden form if it's acceptable for it to stay silhouetted permanently.

*`systems-designer` not consulted — Solo mode. Review manually before production.*

## Dependencies

Pet Definition Data has no upstream dependencies — it is a Foundation-layer system, loaded first, that reads nothing from any other game system. It has the widest fan-out in the project: every dependent below is a **hard** dependency — none can function without PDD's data; there is no "enhanced by, works without" case for a pure content schema.

| Dependent | Interface (reads) | Hard/Soft | Notes |
|---|---|---|---|
| Need System | `NeedProfile` (decay_per_hour, sad_threshold, floor) | Hard | Applies decay; PDD never ticks |
| Care Actions | `CareProfile.restore_amount`; animation name to request | Hard | Action→need map fixed in code |
| Life Stage & Growth | `days_to_advance` per stage, `adult_days_to_nearly_grown`, `FormRuleTable` | Hard | Owns care-history log & rule evaluation |
| Save & Persistence | species/form **ids** only | Hard | Must handle a missing id (see Edge Cases) |
| LCD Screen Renderer | active palette, sprite frame size | Hard | Renders within 4–8 color constraint |
| Pet Animation & Reactions | `sprite_set` by stage/form, animation names, `fps`, `loop` | Hard | Required-name contract, no fallback |
| Graduation & Album *(Vertical Slice)* | `display_name`, form `hidden`/`retired`, species `retired`, form sprite; `get_hatchable_species()` | Hard | Must resolve retired ids forever |

**Correction (applied 2026-09-21)**: `design/gdd/systems-index.md`'s dependency map omitted the Graduation & Album → Pet Definition Data edge (it currently lists only Life Stage & Growth, Save & Persistence, and Pet Animation & Reactions as Graduation's dependencies). This GDD has specified the direct read since Section C was written; Phase 5d of this session adds the missing edge to the systems index rather than changing this GDD's contract.

Nothing writes to Pet Definition Data at runtime (Core Rule 3) — every dependency listed here is strictly one-directional, PDD → dependent.

## Tuning Knobs

Since PDD's whole purpose is designer-adjustable content, nearly every numeric field from Sections C/D is a tuning knob. The table below defines the knob *classes*, their safe ranges, and what breaks at the extremes — the reference a designer tunes against, not the current `bloop` values (those stay in Core Rules as the shipped example).

| Knob | Scope | Safe Range | Too Low | Too High | Interacts With |
|---|---|---|---|---|---|
| `decay_per_hour` | Per need, per species | float > 0, tuned so ~24h decay ≈ one comfortable check-in | Pet never needs attention — breaks the daily-ritual loop (concept's core hypothesis) | Needs crash before a player's next check-in — breaks Pillar 2's "one check-in a day is enough" promise | `sad_threshold`, `floor`, Offline Time Sim's `MAX_OFFLINE` cap (owned downstream) |
| `sad_threshold` | Per need, per species | int 0–100, well below the "just decayed a bit" range | Sad state barely ever shows — need feedback loop feels inert | Pet reads as sad almost constantly — contradicts "Never Guilt" | `decay_per_hour`, `floor` |
| `floor` | Per need, per species | int ≥ 0, default 0, must stay well below `sad_threshold` | N/A (0 is the safe default) | A floor at or above `sad_threshold` doesn't block care from working, but a floor near 100 makes decay nearly invisible — the need never meaningfully drops | `decay_per_hour`, `sad_threshold` |
| `restore_amount` | Per care action, per species | int 1–100, high enough to clear one need from sad back to content in a single press | Care feels ineffective — player presses but sees no payoff, breaking Pillar 3's "two minutes of joy" | 100 always fully restores regardless of how decayed — acceptable here, since instant full relief matches the no-punishment pillar | `decay_per_hour`, `sad_threshold` |
| `days_to_advance` | Per stage, per species | int ≥ 0; 0 reserved for egg only (Core Rule 5's convention) | A non-egg stage at 0 instantly skips that stage — almost certainly an authoring mistake, not a valid design choice | Pushes `total_arc_days` outside the concept's 7–10 day band (see Formulas) | `total_arc_days`, `window_days` |
| `adult_days_to_nearly_grown` | Per species | int ≥ 1 | 1 gives almost no time to enjoy the chosen adult form before graduation looms | A long adult stage back-loads the whole arc's pacing | `total_arc_days` |
| `window_days` | Per species (FormRuleTable) | int ≥ 1; recommended ≈ `child.days_to_advance` | A 1-day window makes form selection twitchy — one great/bad day flips the outcome, undermining "style" as the read signal | A window much longer than `child.days_to_advance` pulls in Baby-stage actions the player didn't think of as "shaping the adult" (see Edge Cases) | `days_to_advance` (child), `care_action_share` |
| `min_share` | Per `ShareCondition` | float 0.0–1.0 | Near 0 — almost any care pattern satisfies the rule, so the form becomes a near-default and Discovery collapses | Near 1.0, or multiple ANDed conditions whose values jointly exceed 1.0 — the rule becomes unreachable (see Edge Cases) | Other `ShareCondition`s in the same rule; `care_action_share` |
| Palette size | Per species/form-override | 4–8 colors (hard-enforced at load, Core Rule 12) | 4 — least shading fidelity for the pixel art | 8 — the ceiling exists to protect LCD Screen Renderer's readability budget ("clarity is the screen's job") | LCD Screen Renderer's palette budget |
| `hidden` / `retired` | Per form | boolean | — | Retiring a form still referenced by `default_form_id` or left `hidden` produces the failure modes in Edge Cases | `default_form_id`, album resolution |
| `retired` | Per species | boolean | — | Retiring every species leaves `get_hatchable_species()` empty and no new egg can start — a catalog-level condition Core Rule 12 cannot see per species, so the CI fixture asserts ≥1 hatchable species | `get_hatchable_species()`, Hatching Onboarding, Graduation & Album |

*`systems-designer` not consulted for this section — Solo mode; knobs derived directly from Sections C/D. Review manually before production.*

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

- **GIVEN** the compiled game code, **WHEN** inspecting the need/action/stage enums, **THEN** exactly four needs (`hunger`, `cleanliness`, `fun`, `sleep`), four care actions (`feed`, `clean`, `play`, `lights`), and four life stages (`egg`, `baby`, `child`, `adult`) exist and are not sourced from data (Core Rule 1).
- **GIVEN** a species or adult form definition, **WHEN** the catalog loads it, **THEN** its `id` is a `StringName` matching `^[a-z][a-z0-9_]*$`, at most 32 characters, unique across the whole catalog within its type; an id violating the grammar (uppercase, leading digit, hyphen, non-ASCII, or 33+ characters) fails validation (Core Rules 2, 12).
- **GIVEN** a valid id `s` as a `StringName`, **WHEN** it is converted with `String(s)` and back with `StringName(String(s))`, **THEN** `get_species()` / `get_form()` with the round-tripped value resolves to the identical definition object as with the original; and no persisted representation of an id is anything other than that plain string (Core Rule 2).
- **GIVEN** a loaded catalog in `Ready` state, **WHEN** two consumers call `get_species()` with the same id, **THEN** both receive the identical object (reference equality), not copies (Core Rule 3).
- **GIVEN** the immutability enforcement mechanism selected in the Open Question #2 ADR, **WHEN** test code attempts to assign to any definition field after the catalog reaches `Ready`, **THEN** the attempt is rejected at runtime (dev-build assertion or error) or detected by the CI lint — whichever the ADR chose — and a test demonstrating this exists before the first dependent system is implemented (Core Rule 3).
- **GIVEN** a species definition file, **WHEN** validated, **THEN** it contains exactly one `id`, `display_name`, `palette`, three `StageDefinition`s (egg/baby/child), ≥1 `AdultFormDefinition`, one `FormRuleTable`, one `NeedProfile`, one `CareProfile`, `adult_days_to_nearly_grown ≥ 1`, and `retired: bool` defaulting to `false` (Core Rule 4).
- **GIVEN** the `bloop` species definition, **WHEN** inspected, **THEN** `egg.days_to_advance = 0`, `baby.days_to_advance = 3`, `child.days_to_advance = 4`, `adult_days_to_nearly_grown = 2` (Core Rule 5).
- **GIVEN** an adult form definition, **WHEN** validated, **THEN** it has `id`, `display_name`, `sprite_set`, an optional `palette_override`, `hidden: bool`, and `retired: bool`; the adult day threshold is read from the species, never the form (Core Rule 6).
- **GIVEN** a baby, child, or adult form `sprite_set`, **WHEN** validated against Core Rule 7, **THEN** all core-set animation names are present (`idle_content`, `idle_sad`, `greeting`, `react_feed`, `react_clean`, `react_play`, `react_lights`, `stage_up`); adult forms additionally have `nearly_grown` and `graduate`; the egg's `sprite_set` requires only `idle` and `hatch`; any missing required name fails validation with no fallback to `idle`.
- **GIVEN** a palette, **WHEN** its size is outside 4–8 colors, **THEN** load-time validation rejects the species — hard error in dev builds, species excluded from the catalog (absent from both `get_all_species()` and `get_hatchable_species()`) plus a logged error in release (Core Rules 8, 12).
- **GIVEN** a `NeedProfile` entry, **WHEN** validated, **THEN** `decay_per_hour > 0`, `sad_threshold` is in `[0, 100]`, and `floor ≥ 0` (Core Rule 9).
- **GIVEN** a `CareProfile` entry, **WHEN** validated, **THEN** `restore_amount` is in `[1, 100]` (Core Rule 10).
- **GIVEN** a `FormRuleTable`, **WHEN** validated, **THEN** `window_days ≥ 1`, every `form_id` referenced (in rules and `default_form_id`) exists among that species' adult forms, every `min_share` is in `[0.0, 1.0]`, and no `FormRule` has two `ShareCondition`s on the same action (Core Rule 11).
- **GIVEN** a `FormRuleTable` read back from the catalog, **WHEN** its rules are iterated, **THEN** they come back in the exact authored order — so any consumer implementing "first match wins" (Life Stage & Growth) has a well-defined order to walk (Core Rule 11).
- **GIVEN** a species definition violating any Core Rule 12 constraint (duplicate or malformed id, dangling `form_id`, missing default, zero non-retired adult forms, out-of-range `min_share`, `window_days < 1`, two `ShareCondition`s on the same action within one `FormRule`, a missing required animation, wrong palette size, or an out-of-range numeric field), **WHEN** the catalog loads it, **THEN** a dev build hard-errors and a release build excludes the species from both `get_all_species()` and `get_hatchable_species()` and logs an error (Core Rule 12).
- **GIVEN** a species whose `FormRuleTable` contains a rule with two `ShareCondition`s on distinct actions whose `min_share` values sum above 1.0 (e.g. `play ≥ 0.6` AND `feed ≥ 0.5`), **WHEN** the catalog loads it, **THEN** the species loads successfully and exactly one warning naming the species id, the rule index and the offending sum is logged, in dev and release builds alike (Core Rules 11, 12).
- **GIVEN** the shipped catalog data, **WHEN** the CI unit-test fixture in `tests/unit/pet_definition_data/` runs, **THEN** it fails if any species has a `FormRule` whose `min_share` values sum above 1.0, or if `get_hatchable_species()` would be empty — BLOCKING Logic evidence per `coding-standards.md`, and the shipping gate that closes Open Question #6.
- **GIVEN** a loaded catalog, **WHEN** calling `get_species(id)` / `get_form(id)` with an unknown id, **THEN** each returns a defined "not found" result (null or explicit error), never a silent default (Core Rule 13).
- **GIVEN** a catalog containing one species with `retired: true` and one with `retired: false`, **WHEN** the lookups are called, **THEN** `get_all_species()` returns both and `get_species()` resolves the retired one, while `get_hatchable_species()` returns only the non-retired one (Core Rule 13).
- **GIVEN** `action_count = 9` and `total_actions_in_window = 20` (the Formulas worked example), **WHEN** `care_action_share` is computed per its formula definition, **THEN** the result equals `0.45` — a pure-math contract test, independently unit-testable regardless of which system (Life Stage & Growth) invokes it.
- **GIVEN** `bloop`'s stage thresholds (`baby=3`, `child=4`, `adult_days_to_nearly_grown=2`), **WHEN** `total_arc_days` is computed, **THEN** the result equals `9`, inside the concept's 7–10 day band; a balance smoke check computing this for any species definition outside `[7, 10]` produces a warning for designer review, not a load failure (per Config/Data test evidence in `coding-standards.md`).
- **GIVEN** the MVP catalog (1 species) at app boot, **WHEN** it is parsed and validated, **THEN** loading completes before the first frame is presented — this is a one-time boot cost outside the 16.6 ms per-frame budget, not a per-frame concern.

*`qa-lead` not consulted — Solo mode. Review manually before production.*

## Open Questions

| # | Question | Owner | Target Resolution |
|---|---|---|---|
| 1 | Storage format & schema versioning strategy (Resource/.tres vs. JSON vs. custom binary; how a saved species catalog migrates across content updates) | technical-director | Architecture phase, as an ADR — before Save & Persistence is implemented |
| 2 | Catalog wiring & injection mechanics (how definitions are loaded and exposed to consumers — Autoload singleton vs. injected service), **and** the immutability enforcement mechanism for Core Rule 3 (setter guards vs. read-only wrapper vs. convention + CI lint) | godot-specialist | Same ADR pass as #1 — must land before the first dependent system is implemented |
| 3 | 32×32 sprite frame size is provisional, borrowed from LCD Screen Renderer's expected scope, but that GDD's own rendering approach (SubViewport+shader vs. `DrawableTexture2D`) is still unvalidated (systems-index High-Risk Systems) | LCD Screen Renderer design session | Confirm or replace this constant when that GDD's Formulas section is written |
| 4 | The 0–100 need scale is assumed here but is properly Need System's own scale to own | Need System design session | Confirm at that GDD's Detailed Rules — next MVP system in the design order |
| 5 | Empty-window and tie-break rules for form selection (Core Rule 11 defers both to Life Stage & Growth) | Life Stage & Growth design session | Resolve in that GDD's Core Rules / Edge Cases |
| 6 | ~~No tooling catches an unreachable `FormRule` at load time~~ **Resolved 2026-09-21**: distinct-actions constraint (Core Rule 11) makes reachability decidable; non-rejecting load-time warning (Core Rule 12); CI-blocking unit-test fixture (Acceptance Criteria) is the shipping gate | — | Closed |
| 7 | ~~Species-level `retired` flag undeclared~~ **Resolved 2026-09-21**: `retired: bool` added to Core Rule 4; Core Rule 13 split into `get_all_species()` (includes retired, for the album) and `get_hatchable_species()` (excludes retired, for new eggs) | — | Closed |
| 8 | Rule 12's "≥1 non-retired adult form" check evicts a fully-retired species that Rules 2/13 promise the album can resolve forever. Fix: scope the check — non-retired species need ≥1 non-retired form; retired species need ≥1 form of any status | systems-designer | Life Stage & Growth design session, or first catalog-validator implementation — **review blocker accepted 2026-09-22** |
| 9 | Unknown-id lookup result is not pinned (Rule 13 says "null or explicit error"). Fix: pin `null` in Rule 13 and the matching AC | qa-lead | When the catalog API is implemented (OQ#2 ADR) — **review blocker accepted 2026-09-22** |
| 10 | "Ready with 0 hatchable species" in a shipped build is a silent outage — needs an explicit terminal failure state or a named signal that Hatching Onboarding must handle | systems-designer | Hatching Onboarding design session — **review blocker accepted 2026-09-22** |
| 11 | `min_share` range must be `(0, 1]` — `0.0` always matches and shadows every later rule and the default. Fix: Rule 11 range, Rule 12 check, new AC | systems-designer | With Life Stage & Growth's rule-table design — **review blocker accepted 2026-09-22** |
| 12 | 32×32 sprite constant is owned by a dependent (LCD Renderer) while PDD claims no upstream deps. Fix: PDD declares the constant (value provisional per OQ#3); LCD Renderer reads it | systems-designer | LCD Screen Renderer design session, resolved together with OQ#3 — **review blocker accepted 2026-09-22** |
| 13 | 10 recommended items from the 2026-09-22 review remain unaddressed: CI gate implementability (injectable build-type flag; move shipped-catalog fixture out of `tests/unit/`), Rule 12 cross-checks, shadowing detector, `duplicate()` ban in Rule 3, hidden+retired policy, Rule 14 minor-revision clarity, missing ACs, numeric boot budget, bloop `window_days = 4`, species-prefixed form ids — see `design/gdd/reviews/pet-definition-data-review-log.md` | — | Backlog: fold in opportunistically during implementation; none gate first code |
