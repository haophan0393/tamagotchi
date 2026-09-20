# Pet Definition Data

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-09-19
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

2. **Every definition has a stable, permanent ID.** Species and adult forms carry a `StringName` id (snake_case, globally unique within its type, e.g. `bloop`, `bloop_playful`). IDs are the *only* thing other systems store — Save & Persistence and Graduation & Album reference pets by species id + form id, never by array index or display name. An id, once shipped, is never renamed or reused; retiring a form means marking it `retired: true`, not deleting it (the album must still resolve it).

3. **Definitions are immutable at runtime.** The full catalog is loaded once at boot, validated, and thereafter shared read-only by reference. No consumer mutates a definition or holds a private copy of a value. A pet's *current* need levels, stage, days-in-stage, care history and chosen form are runtime state owned by Save & Persistence.

4. **Species definition.** One species = one definition containing: `id`, `display_name`, one `palette`, three `StageDefinition`s (egg, baby, child), a list of ≥1 `AdultFormDefinition`s, one `FormRuleTable`, one `NeedProfile`, one `CareProfile`, and `adult_days_to_nearly_grown` (int ≥ 1: check-in days spent as an adult before the "nearly grown" state).

5. **Stage definitions.** Each of egg/baby/child has: `sprite_set` and `days_to_advance` (int ≥ 0: check-in days in this stage before advancing). Egg is special-cased by convention: `days_to_advance = 0`, and the actual hatch is triggered by the player's first press (Hatching Onboarding) — the value exists so the arc reads uniformly. MVP provisional arc: egg 0 → baby 3 → child 4 → adult 2 → nearly grown → graduate = **~9 check-in days**, inside the concept's 7–10 band.

6. **Adult form definitions.** Each has: `id`, `display_name`, `sprite_set`, optional `palette_override` (a full palette that replaces the species palette for this form only), `hidden: bool` (album shows a silhouette until first graduated), `retired: bool`. The adult stage's day threshold is species-level (rule 4), not per form — all forms of a species live the same length.

7. **Animation contract.** A `sprite_set` is a named collection of frame animations at the fixed pet sprite size (32×32 px — a constant owned by LCD Screen Renderer, provisional). Baby, child and every adult form MUST provide the **core set**: `idle_content`, `idle_sad`, `greeting`, `react_feed`, `react_clean`, `react_play`, `react_lights`, `stage_up`. Adult forms MUST additionally provide `nearly_grown` and `graduate`. The egg provides only `idle` and `hatch`. Each animation declares `fps` (1–12) and `loop: bool`. Any other names are optional extras Pet Animation may use if present. Missing required names fail validation (rule 12) — there is no silent fallback to idle.

8. **Palette.** A palette is an ordered list of 4–8 `Color`s. Every pixel in every frame of a sprite set must use a color from the palette in effect (species palette, or the form's override). Palette conformance is checked at authoring time (asset audit), palette *size* at load time.

9. **Need profile.** For each of the four needs: `decay_per_hour` (float > 0, points per real hour on a fixed 0–100 scale), `sad_threshold` (int 0–100: at or below this the need icon shows and idle switches to `idle_sad`), and `floor` (int ≥ 0, default 0 — the non-fatal minimum). Need System owns *how* decay is applied (live tick, offline catch-up); this profile only supplies the numbers.

10. **Care profile.** For each of the four care actions: `restore_amount` (int 1–100, points restored to its target need). The action→need mapping (feed→hunger, clean→cleanliness, play→fun, lights→sleep) is fixed in code. Care Actions owns cooldowns, mini-game outcome and reaction sequencing.

11. **Form rule table.** `window_days` (int ≥ 1: rolling window in check-in days), an ordered list of `FormRule`s, and a mandatory `default_form_id`. A `FormRule` = `form_id` + 1–2 `ShareCondition`s (ANDed); a `ShareCondition` = `action` + `min_share` (float 0–1), where *share* = that action's count ÷ all care actions in the window. Life Stage & Growth evaluates the table at the child→adult transition: first matching rule wins; no match → default. Growth owns what counts as a care action, tie-breaking and the empty-window case — PDD validates only shape. **MVP provisional table** (species `bloop`, window 5): rule 1 → `bloop_playful` if `play ≥ 0.40`; default → `bloop_cozy`.

12. **Load-time validation (fail-fast).** On boot the catalog rejects any species that fails: unique ids (species and form, across the whole catalog); every `form_id` in the rule table exists in that species; `default_form_id` exists; ≥1 non-retired adult form; every `min_share` in [0,1]; `window_days ≥ 1`; every stage and form sprite set has its required animations at the correct frame size; palette size 4–8; all numeric fields within their declared ranges. In dev builds a failure is a hard error; in release the species is excluded from the catalog and an error is logged — what happens to a live pet whose species is missing is Save & Persistence's edge case.

13. **Access.** Consumers read through a catalog with three lookups: `get_species(id)`, `get_form(id)`, `get_all_species()`. Species available as a new egg are those not `retired`. Catalog wiring, file format and injection mechanics → becomes an ADR.

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
| Save & Persistence | species/form **ids** only | — | Stores ids; must handle an id missing from the catalog |
| LCD Screen Renderer | active palette (species or form override), sprite frame size | — | Renders within the 4–8 color constraint |
| Pet Animation & Reactions | `sprite_set` by stage/form; animation names, `fps`, `loop` | — | Relies on the required-name contract, no fallback |
| Graduation & Album *(Vertical Slice)* | `display_name`, `hidden`, `retired`, form sprite for the album | — | Must resolve retired ids forever |

Nothing writes to Pet Definition Data at runtime.

*Specialist agents not consulted — Solo mode. Review manually before production.*

Provisional assumptions flagged for downstream GDDs: the 32×32 sprite constant (LCD Renderer), the `bloop` species and its two forms and day thresholds (Growth), the 0–100 need scale (Need System), the empty-window/tie-break rule (Growth).

## Formulas

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
