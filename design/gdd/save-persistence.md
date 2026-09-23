# Save & Persistence

> **Status**: In Design
> **Author**: Hao Phan + Claude (solo review mode)
> **Last Updated**: 2026-09-22
> **Implements Pillar**: 2 (Never Guilt, Always Welcome)

## Overview

Save & Persistence is the game's memory across app launches: it writes the pet's runtime state to local device storage and restores it when the app opens, so the creature the player left is the one they come back to. It is a **serialiser, not an owner** — each gameplay system keeps authority over its own live state (Need System its need anchors, Life Stage & Growth the stage, check-in days and care-history log, and so on), and Save only takes a copy when it writes and hands one back when it loads. It persists plain data only: UTC epoch timestamps from Time Service, never local time; species and form ids as plain strings, never catalog objects or `StringName` internals (Pet Definition Data Core Rule 2); and each owner's values, which it validates on load rather than trusting. It writes whenever the app is backgrounded and after state-changing events, because a mobile OS may kill a backgrounded app without warning, and every write is crash-safe — an interrupted write can never replace a good save with a broken one. It exists because the whole game is a daily ritual: without it every launch is a new egg, and the growth arc, the album and the "come back tomorrow" hypothesis all collapse. Its hardest constraint is Pillar 2 in a game with no fail state — a missing, corrupt, outdated or tampered save must always resolve to a playable, unpunished pet, and because nothing in the game can visibly "die" as a symptom, a bad load would otherwise fail silently. Save owns the validation and recovery that prevent that. The storage format, schema versioning and migration mechanics are an architecture decision (→ becomes an ADR), not fixed here.

## Player Fantasy

Save & Persistence has no player fantasy of its own — the player never sees it, never presses a save button, and never waits on a loading screen. What it enables is the game's core fantasy, stated in `game-concept.md`: *"My little creature is alive in my pocket and is always glad to see me."* "Alive in my pocket" is a continuity claim, and continuity is exactly what this system supplies: the pet you fed last night is the same pet — same stage, same form, same history — when you open the app this morning. The album's identity fantasy depends on it too: players talk about graduates as individuals ("my first one was a Bloop") only if every graduate is kept, permanently and exactly.

Under **Pillar 2: Never Guilt, Always Welcome** — *"The pet is glad to see you however long you've been gone"* — this system's failure modes matter more than its successes. The player will never notice a save that worked; they will absolutely notice a pet that vanished, reset to an egg, or lost its album. Save's job is to make sure the infrastructure never produces that moment, and that when storage genuinely fails, the fallback is a pet that is still welcoming, never an error screen. The absence of any save UI is also a **Pillar 1** point: a real toy does not ask you to save.

*`creative-director` not consulted — Solo mode. Review manually before production.*

## Detailed Rules

### Core Rules

1. **Serialiser, not owner.** Every system with persistent state is an **owner** and registers one named **section** with Save. On write, Save calls the owner's `export_save_section() -> Dictionary`; on load it calls `import_save_section(data: Dictionary) -> ImportResult`. Save never reads or changes an owner's live state any other way, and it never keeps a reference to exported data after the write finishes. *(This settles the accessor shape Need System's Open Questions assigned here. The exact interface form is → ADR.)*

2. **Two files, two lifetimes, recovered independently.**
   - The **pet file** holds everything that resets when a new egg arrives: need anchors, stage and growth state, the care-history log, and pet identity.
   - The **keepsake file** holds everything that outlives one pet: the album (Vertical Slice), unlocked shells (Alpha), Device Frame's feedback flags, and quarantined pets (rule 10).
   - A corrupt pet file can never take the album with it, and vice versa.

3. **Plain data only.** Each file contains a header (`schema_version: int`, `saved_utc: int`) and a map from section name to `Dictionary`. Every value is an `int`, `float`, `bool` or `String`, or an `Array`/`Dictionary` of those. Never allowed: objects, `Resource`s, `StringName`, `NodePath`, engine types, or anything that can run code when loaded. The on-disk format and migration mechanics are → ADR.

4. **Ids cross the boundary as `String`.** They are written with `String(id)` and read back with `StringName(text)`, per Pet Definition Data Core Rule 2. Save converts at its boundary; owners only ever see `StringName`.

5. **The timestamp contract** (closes Time Service's accepted blocker "anchor-timestamp data contract"):
   - Every persisted timestamp is a non-null `int` of UTC epoch seconds, taken from `TimeService.get_now_utc()`.
   - Every timestamp field name ends in `_utc`.
   - In a new save, each one starts at the creation time. It is never `0` and never missing.
   - The pet file's header `saved_utc` **is** the `last_seen` that Offline Time Simulation reads.

6. **Validation happens in two layers.**
   - **Structural (Save).** The file reads and parses, the header is present, and `schema_version` is recognised: an older version is migrated per the ADR, and a *newer* one (the app was downgraded) counts as unreadable. Every section is a `Dictionary`, and every `*_utc` field is an `int` inside the valid window (rule 7).
   - **Semantic (owner).** `import_save_section()` checks ranges and cross-field rules and returns one of three results:
     - `OK`
     - `REPAIRED`: values were clamped or defaulted, and the section still loads
     - `REJECTED`: the section is unusable
   - Need System clamps out-of-range anchors on import and returns `REPAIRED`. That closes Need System's edge case "Save must validate anchors": the owner repairs its own data, and Save writes the repaired values on its next write.

7. **Out-of-window timestamps are repaired, not trusted.**
   - The valid window is `[EARLIEST_VALID_UTC, now + MAX_FUTURE_SKEW_S]`.
   - Any `*_utc` value outside it is set to `now`, and the file counts as `REPAIRED`.
   - A timestamp from before release is uninitialised or corrupt (Time Service Edge Cases). One far in the future (clock pushed forward then back, or tampering) would freeze decay until real time caught up.
   - Values inside the window are left alone, so Time Service's clamp of rollback to 0 still covers ordinary clock adjustments.

8. **The recovery ladder, run separately for each file:**
   1. primary
   2. backup
   3. fresh

   A file *loads* only if it passes structural validation and **no** section is `REJECTED`. If the primary doesn't load, Save tries the backup. If neither loads, the file starts fresh: the pet file gets the owners' new-pet defaults (a new egg), and the keepsake file gets default values. The one exception is rule 10.

9. **Writes are crash-safe and rotate the backup.**
   - Every write goes through these steps:
     1. export all sections
     2. write to a temp file
     3. re-read and parse the temp file to verify it
     4. move the current primary to backup
     5. move the temp file to primary
   - At every point in that sequence at least one complete, valid file exists.
   - Only a primary that passed validation at load, or was written this session, is ever promoted to backup. An invalid primary is overwritten, never rotated, so a known-good backup is never replaced by a bad file.
   - Whether rename is atomic over an existing file on iOS and Android is a MEDIUM knowledge gap → verified in the ADR.

10. **A catalog miss means quarantine plus a new egg.**
    - This is the case where the pet file is structurally valid but its species or form id doesn't resolve in the catalog (a release-build content bug; Pet Definition Data Core Rule 12 drops invalid species).
    - Save copies the whole raw pet section into the keepsake file's `quarantine` list, stamped with `quarantined_utc` and the reason. Nothing is destroyed.
    - The pet file then starts fresh (a new egg).
    - Quarantined pets are never loaded again automatically; restoring them is out of MVP scope.
    - A catalog miss does **not** fall back to the backup, because the backup would carry the same id.

11. **Write triggers.**
    - **(a) Backgrounding:** when the app is backgrounded or paused, Save writes **immediately and synchronously**, flushing anything pending, because the OS may kill the app with no further callback.
    - **(b) Events:** an owner calls `request_save()` after a state-changing event. In MVP those are:
      - care applied
      - check-in day recorded
      - stage advanced
      - form chosen
      - graduation
      - a feedback flag changed
    - Requests are **coalesced**: at most one write per `SAVE_COALESCE_MS`, always of the latest state.
    - **(c) Quit:** Save also writes on quit.
    - There's no periodic autosave.
    - Each file is written only when one of its own sections is dirty.

12. **Boot order is fixed.**
    1. Time Service
    2. The Pet Definition Data catalog reaches `Ready`
    3. Owners are constructed with defaults
    4. Save loads and imports
    5. Offline Time Simulation's `reanchor_with_cap()`
    6. Need System's `on_resumed()`
    7. First frame and greeting

    Save emits `load_completed(result)` with each file's outcome: `LOADED`, `REPAIRED`, `RECOVERED_FROM_BACKUP`, `QUARANTINED_NEW_EGG` or `FRESH_START`.

13. **Save never talks to the player.** It has no UI, no error message and no loading screen, and it never blocks play. Every outcome in rule 12 is logged; none is shown. A new egg that came from `FRESH_START` or `QUARANTINED_NEW_EGG` enters the ordinary hatching flow, not a special "your save was lost" flow (Pillar 2).

14. **A failed write changes nothing.**
    - Any `FileAccess.store_*` returning `false` (4.4+) or a failed rename aborts the write.
    - The existing primary and backup stay untouched.
    - Save stays dirty and retries on the next trigger. Nothing is shown to the player.

15. **One writer, one reader.** Only Save touches save files. Other systems get loaded facts through Save's API, for example `get_last_seen_utc()` for Offline Time Simulation, and never read files directly.

16. **Save never writes against a broken catalog.** If the Pet Definition Data catalog is `Failed`, or storage is unavailable, Save enters `READ_ONLY`: it loads what it can and writes nothing, so a broken build can't overwrite a good save.

### States and Transitions

| State | Meaning |
|---|---|
| `UNLOADED` | Before boot step 4 |
| `LOADING` | Reading, validating and importing both files |
| `READY` | Normal play; accepts `request_save()` |
| `WRITING` | A write is in progress. Requests arriving now set `dirty`, and one follow-up write runs afterwards |
| `READ_ONLY` | The catalog is `Failed` or storage is unavailable. Nothing is written |

| Transition | Trigger |
|---|---|
| `UNLOADED → LOADING` | Boot step 4 |
| `LOADING → READY` | Both files resolved (any outcome in rule 12) |
| `LOADING → READ_ONLY` | The catalog is `Failed`, or storage can't be opened |
| `READY → WRITING` | A background, quit or coalesced event trigger |
| `WRITING → READY` | The write succeeded or failed (rule 14). If `dirty`, one more write follows immediately |

### Interactions with Other Systems

| System | Data In | Data Out | Owns the interface |
|---|---|---|---|
| Time Service | — | `get_now_utc()` for `saved_utc`, new-save timestamps and the window check | Time Service |
| Pet Definition Data | — | `get_species()` / `get_form()` to resolve saved ids; the catalog's `Ready`/`Failed` state | Pet Definition Data |
| Need System | pet section `needs` (4 × `anchor_value`, `anchor_utc`) via export; `request_save()` after a re-anchor | `import_save_section()` | **Save** |
| Life Stage & Growth *(undesigned: provisional)* | pet section `growth` (species_id, stage, form_id, check-in-day count, `last_check_in_utc`, care-history log) | `import_save_section()` | **Save** |
| Offline Time Simulation *(undesigned)* | — | `get_last_seen_utc()`, `load_completed` | **Save** |
| Device Frame & Button Input | keepsake section `device` (`sfx_enabled`, `haptics_enabled`) | `import_save_section()` | **Save** |
| Graduation & Album *(VS)* | keepsake section `album` | `import_save_section()` | **Save** |
| Device Shells *(Alpha)* | keepsake section `shells` | `import_save_section()` | **Save** |
| Hatching Onboarding *(VS)* | — | `load_completed` with `FRESH_START` / `QUARANTINED_NEW_EGG` for the pet file | **Save** |
| App lifecycle | background/pause and quit notifications | — | (wiring → time/event ADR) |

*Specialist agents not consulted — Solo mode. Review manually before production.*

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
