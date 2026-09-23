# Need System

> **Status**: Approved (revised) — 2026-09-22 after `/design-review` (NEEDS REVISION → revised; see `reviews/need-system-review-log.md`)
> **Author**: Hao Phan + Claude (lean review mode)
> **Last Updated**: 2026-09-22
> **Implements Pillar**: 2 (Never Guilt, Always Welcome), 3 (Two Minutes of Joy)

## Overview

Need System is the game's clock-driven appetite: it holds the four needs every pet has — `hunger`, `cleanliness`, `fun` and `sleep` — on a fixed 0–100 scale, decays them in real time against the injected Time Service, and raises each one's "sad" flag when it falls to or below the threshold its species defines. It owns the *behaviour* of needs, never their numbers: every decay rate, sad threshold and floor is read from the `NeedProfile` in Pet Definition Data, so re-tuning a species is a data edit and never a code change (Pillar 5). Decay runs live while the app is open, not only on resume — Offline Time Simulation reuses the same decay rule to catch up a closed-app gap, rather than implementing a second one. To the player, this system is the entire reason to come back: it is what makes need icons appear overnight, what shifts the pet's idle from content to sad, and what clears — one icon at a time, with a visible payoff — when Care Actions applies a restore. Without it the pet is a static sprite and the daily ritual has nothing to be *about*. Its hardest constraint is Pillar 2: needs decay toward a non-fatal floor and stop there, so an absence of any length leaves a pet that is sad and messy but never dying, never scolding, and always fully addressable in a single two-minute session.

## Player Fantasy

Gentle responsibility, and the small clean satisfaction of a finished ritual.

The player should feel *needed but never harassed*. Needs are a soft tug, not an alarm: opening the app to two waiting icons should read as "oh, there you are" — a creature that got on with its day and could use a hand — never as a backlog or a reprimand. The target moment is the one `game-concept.md` calls the "done for today" signal: icons clearing one at a time under the player's thumb, each with its own reaction beat, until the last one goes and the pet drops into its happy idle. That final empty screen is the payoff this system exists to produce, and it must be reachable in a single two-minute session no matter how long the player has been away.

The inverse is the thing to protect against hardest. A need that decays too fast turns the ritual into a chore; a need that never decays makes the visit pointless. Pillar 2 sets the asymmetry: the pet may look sad, but a returning player's first feeling must be *relief that it's fine*, not guilt at what they let happen.

*(Thin by design — reduced-depth pass per the compressed path. `creative-director` consulted at the 2026-09-22 `/design-review`.)*

## Detailed Rules

### Core Rules

1. **Four needs, fixed in code.** `hunger`, `cleanliness`, `fun`, `sleep` — an enum, not data (inherited from Pet Definition Data Core Rule 1). Need System adds no fifth need, and a new species varies the *numbers*, never the set.

2. **Need System owns the 0–100 scale.** 100 is fully content, 0 fully depleted. Values are computed and stored as `float`; `NeedProfile`'s `sad_threshold` and `floor` and `CareProfile`'s `restore_amount` remain `int` as authored, and comparisons are made against the float value. *(This closes Pet Definition Data Open Question #4, which explicitly deferred scale ownership to this GDD.)*

3. **A need is an anchor, not a running total.** Each need holds exactly two persisted fields: `anchor_value: float` and `anchor_utc: int`. The current value is **computed on read** from those two plus the elapsed time — never accumulated into. There is no decay timer and no per-frame subtraction.

4. **One decay rule, online and offline.** Because value is derived from elapsed time, a closed app, a suspended app and a running app are arithmetically identical. Offline Time Simulation does not implement a second decay path; resuming from a two-week gap and idling for two weeks produce the same number.

5. **Every mutation re-anchors.** Applying care or applying an Offline Sim cap follow the same two-step: compute the value at `now`, then write it back as the new `anchor_value` with `anchor_utc = now`. Re-anchoring is the only legal way to change a need.

6. **Decay rates are fixed for the life of an anchor.** Each need decays at its species' `decay_per_hour` and nothing changes that rate at runtime in MVP. This is what makes the anchor valid: the anchor was computed under that rate. Any future feature that changes a rate mid-flight must re-anchor *before* the change takes effect — a rate change is a mutation under Core Rule 5.

7. **Care restores by re-anchoring upward — all four needs, including sleep.** `anchor_value = clamp(value(now) + restore_amount, floor, 100)`. The action→need map is fixed in code (feed→hunger, clean→cleanliness, play→fun, lights→sleep, per Pet Definition Data Core Rule 10). Restoring a need already at 100 is legal, costs nothing, and is not an error — Pillar 2 forbids a "you didn't need to do that" response.

8. **Decay stops at the floor and nothing happens there.** A need clamps at `floor` (default 0) and stays. There is no death, no cascade to other needs, no escalating penalty, and no state below the floor. This is the hard Pillar 2 guarantee and the reason the system has no fail state to test for.

9. **Sleep is press-restored like every other need.** The lights action restores sleep by `CareProfile.restore_amount` through `apply_care`, exactly as feed restores hunger. "Lights out" is a momentary reaction beat presented by Pet Animation & Reactions, not a persistent device state: Need System holds no `dark` flag and has no rate that depends on one. How the lights action is *surfaced* (Device Frame's contextual **B** slot, Core Rule 4 of that GDD) is Device Frame's concern; it reaches Need System only as `apply_care(lights)` via Care Actions. *(Revised 2026-09-22: replaces the earlier rate-switched-by-`dark` model, which had no way back to lights-on, no reaction beat, and depended on a `recover_per_hour` field Pet Definition Data does not define.)*

10. **State is derived, never stored, with a fixed precedence.** A need's state is computed from `value(now)` in this order, first match wins:
    1. `value > sad_threshold` → `CONTENT`
    2. `value == floor` → `AT_FLOOR`
    3. otherwise → `SAD`

    No state is persisted, so a need can never be saved in a state that disagrees with its own value. The precedence is what keeps the states disjoint for *any* data: when `floor > sad_threshold`, a need at its floor is `CONTENT`, not simultaneously `CONTENT` and `AT_FLOOR`. `is_sad(need)` is true for both `SAD` and `AT_FLOOR`.

11. **Urgency ranking is a UX convenience with no mechanical weight.** Need System exposes the sad needs (`SAD` and `AT_FLOOR`) ordered ascending by current value, ties broken by the fixed enum order (`hunger`, `cleanliness`, `fun`, `sleep`). Deterministic by construction. `game-concept.md` states the order a player tends needs never matters mechanically — this ranking only informs Device Frame's cursor placement.

12. **Need System never reads the wall clock.** All time comes from an injected `TimeService` (Time Service Core Rules 1–2). This is what makes every rule above unit-testable against a fake clock, and it is enforced by the existing `clock-discipline` CI job. This applies to crossing detection too (Core Rule 14): no engine `Timer` lives inside the logic layer.

13. **Need System owns the live anchors; Save & Persistence serialises them.** The in-memory anchor set is this system's state and only this system mutates it. Save reads a copy of the anchor set and hands one back on load; it never holds a live reference. *(Pet Definition Data currently describes current need levels as "runtime state owned by Save & Persistence" — see Open Questions.)*

14. **Threshold crossings are detected by a pure check, and only *scheduled* by an adapter.** Detection and scheduling are split so the logic stays testable:
    - **Logic (Need System, pure, unit-tested):** Need System keeps an in-memory, non-persisted `last_observed_state` per need, initialised on construction to the state of `anchor_value` itself and reset on every re-anchor. `check_crossings()` reads `now` from `TimeService`, recomputes every need, emits `need_became_sad(need_id)` for each need whose state moved from `CONTENT` into `SAD`/`AT_FLOOR` since it was last observed, and updates `last_observed_state`. It is idempotent: a second call at the same `now` emits nothing. `next_crossing_utc(need) -> int` returns the absolute UTC moment of the next downward crossing (`now + seconds_until_sad`), `now` if already sad, or `-1` for never.
    - **Resume (Need System, pure):** `on_resumed()` is the single entry point for returning from background. It calls `check_crossings()`, so any crossing that happened while suspended fires exactly once. If Offline Time Simulation applies a cap on the same resume, its `reanchor_with_cap()` runs **before** `on_resumed()`.
    - **Adapter (production only, no logic):** a thin `NeedCrossingScheduler` node arms one one-shot engine `Timer` for the soonest `next_crossing_utc()` across the four needs, calls `check_crossings()` when it fires, and re-arms after every check, re-anchor and resume. It holds no rule of its own and is the only part of this system that touches the engine's timer — it is excluded from the unit-tested surface and covered by an ADVISORY integration check (see Acceptance Criteria). A late or dropped timer is harmless: the next `check_crossings()` call catches up, because detection is state-based, not event-based.

### States and Transitions

Each need is independently in one of three states, derived from its computed value by the Core Rule 10 precedence — none is stored:

| State | Condition (evaluated in order) | Notes |
|---|---|---|
| `CONTENT` | `value > sad_threshold` | No icon shown; contributes nothing to the urgency ranking |
| `AT_FLOOR` | not `CONTENT`, and `value == floor` | A sub-state of sad, not a worse one. Shows the same icon as `SAD` and ranks first by value. Exists so the Pillar 2 guarantee is explicitly testable. Unreachable when `floor > sad_threshold` |
| `SAD` | neither of the above (`floor < value ≤ sad_threshold`) | Icon shown; enters the urgency ranking |

| Transition | Trigger |
|---|---|
| `CONTENT → SAD` | Elapsed time carries the computed value to or below `sad_threshold` |
| `SAD → AT_FLOOR` | Elapsed time carries the computed value to `floor` |
| `SAD`/`AT_FLOOR` → `CONTENT` | Care re-anchors the value above `sad_threshold` |
| `SAD → SAD` | Care restores, but not above the threshold — legal, produces a reaction, clears no icon |

**There is no global system state.** Needs do not interact, gate, or cascade into one another; four needs at floor is not a distinct condition, it is just four needs at floor. The one aggregate fact this system publishes is `all_needs_addressed` — the concept's explicit "done for today" signal — and it is true exactly when every need is `CONTENT`, so the signal can never coexist with a lit need icon.

### Interactions with Other Systems

| System | Data In | Data Out | Owns the interface |
|---|---|---|---|
| Time Service | — | `get_now_utc()`, `get_elapsed_seconds()` | Time Service |
| Pet Definition Data | `NeedProfile` (decay_per_hour, sad_threshold, floor), `CareProfile.restore_amount` | — | Pet Definition Data |
| Care Actions | `apply_care(action_id)` — all four actions, including `lights` | `need_changed`, `need_cleared` | **Need System** |
| Device Frame & Button Input | — | `get_urgency_ranking() -> Array[Need]` | **Need System** |
| Save & Persistence | anchor set on load | anchor set on save (a copy) | Save & Persistence |
| Offline Time Simulation | `reanchor_with_cap(max_offline_s)` on resume, before `on_resumed()` | — | Offline Time Simulation |
| App lifecycle (resume handler) | `on_resumed()` | — | **Need System** (caller wiring → time/event ADR) |
| Pet Animation & Reactions | — | `need_became_sad`, `need_cleared`, `all_needs_addressed` | **Need System** |
| Daily Notification | — | `seconds_until_sad(need) -> int`, `next_crossing_utc(need) -> int` | **Need System** |

**Signals published:** `need_changed(need_id, value)`, `need_became_sad(need_id)`, `need_cleared(need_id)`, `all_needs_addressed()`.

**`seconds_until_sad()` is a free consequence of the anchor model** and worth calling out: because value is a function of time, the system can solve for *when* a need will cross its threshold rather than polling for it. Daily Notification needs exactly this to schedule a reminder, and an accumulating tick model could not answer it without simulating forward.

**Offline Time Simulation's cap is applied by re-anchoring, not by Need System knowing about it.** `MAX_OFFLINE` stays Offline Sim's tuning knob (as Time Service's GDD already specifies); Offline Sim calls a re-anchor with the capped elapsed on resume. Note that with floor-clamping, a long absence lands at `floor` with or without the cap — the cap's real job is letting a returning player land *above* floor, which is a Pillar 2 lever, not a correctness one.

*Specialist agents not consulted for this section — Lean mode (specialists are spawned for Formulas and Acceptance Criteria). Reviewed by game-designer, systems-designer, qa-lead and godot-gdscript-specialist at the 2026-09-22 `/design-review`.*

## Formulas

The `need_value` formula is defined as:

`need_value = clamp(anchor_value − decay_per_hour × (elapsed_seconds / 3600.0), floor, 100)`

Every need, sleep included, uses this one formula. There is no recovery branch: needs only ever rise through `apply_care`.

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| anchor_value | a | float | [floor, 100] | Value written at the last re-anchor |
| decay_per_hour | d | float | > 0 (PDD); proposed ≥ 0.01 (see Open Questions) | Points lost per real hour, from `NeedProfile` |
| elapsed_seconds | e | int | ≥ 0 | `TimeService.get_elapsed_seconds(anchor_utc)` — never negative by construction |
| floor | F | int | 0 ≤ F < sad_threshold (proposed PDD rule) | Non-fatal minimum, from `NeedProfile` |

**Output Range:** `[floor, 100]`, always — the clamp is total, so no corrupted anchor or absurd elapsed can produce an out-of-range value. **Behaviour at extremes:** `elapsed = 0` returns `anchor_value` exactly (clamped), so repeated reads never drift. A five-year gap (≈1.58 × 10⁸ s) stays well inside float64 precision and simply clamps to `floor`.
**Example:** `anchor_value = 100`, `decay_per_hour = 3.0`, `elapsed = 72000` (20 h) → `100 − 3.0 × 20 = 40`.
**Example (sleep):** `anchor_value = 100`, `decay_per_hour = 1.5`, `elapsed = 86400` (24 h) → `100 − 1.5 × 24 = 64`.

---

The `apply_care` formula is defined as:

`new_anchor_value = clamp(need_value(now) + restore_amount, floor, 100)`, with `new_anchor_utc = now`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| restore_amount | R | int | 1–100 | Points restored, from `CareProfile` for the action that targets this need |

**Output Range:** `[floor, 100]`. **Behaviour at extremes:** at `R = 100` the result is 100 from any starting value — one press always fully clears. Applying care to a need already at 100 is a legal no-op on the value, never an error (Core Rule 7).
**Example:** `need_value(now) = 28`, `restore_amount = 100` → `clamp(128, 0, 100) = 100`.

---

The `seconds_until_sad` formula is defined as:

```
v0 = need_value(now);  d = decay_per_hour;  S = sad_threshold;  F = floor
if v0 ≤ S:   return 0      // already sad (SAD or AT_FLOOR)
if F > S:    return -1     // floor sits above the threshold — can never go sad
return ceili((v0 − S) / d × 3600.0)
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| v0 | v₀ | float | [floor, 100] | Current value at call time |
| S | S | int | 0–100 | `sad_threshold` from `NeedProfile` |
| d | d | float | > 0 | `decay_per_hour` from `NeedProfile` |

**Output Range:** `0`, `-1`, or a positive int. **The sentinel contract is fixed here and is part of the interface: `0` means already sad, `-1` means never.** No null, no error, no exception. **Behaviour at extremes:** `d > 0` is guaranteed by Pet Definition Data's schema, so the division is always defined; the earlier `rate ≥ 0` guard is gone because, with no recovery branch, it could never fire. `F == S` is *not* a never case: the need reaches `S` exactly as it reaches the floor, and the formula returns that moment. The largest possible result is `100 / d × 3600`; with the proposed minimum `d ≥ 0.01` that is `3.6 × 10⁷` s (~417 days), comfortably inside a 64-bit `int`. Without that minimum a legal-but-absurd `d` (e.g. `1e-300`) would overflow `ceili()` — which is why the minimum is owed to Pet Definition Data (see Open Questions).
**Example:** `v0 = 100`, `S = 40`, `decay_per_hour = 3.0` → `(100 − 40) / 3.0 = 20 h` → `72000`.

`next_crossing_utc(need)` is derived directly: `-1` if `seconds_until_sad` is `-1`, otherwise `now + seconds_until_sad`.

---

The `all_needs_addressed` condition is defined as:

`all_needs_addressed = every need is CONTENT`

**Output Range:** boolean. This is the concept's "done for today" signal, and because it is defined on the same state the icons are drawn from, it is true exactly when the last icon has cleared. **Behaviour at extremes:** a species with `sad_threshold == 100` for any need can never make that need `CONTENT` (it would require `value > 100`, which the clamp forbids), so the signal would be permanently unreachable. That data is excluded by the proposed Pet Definition Data rule `floor < sad_threshold < 100` (see Open Questions), which must land before Need System ships.

---

**Urgency ranking is a comparator, not a formula.** Sad needs sort ascending by current value, ties broken by fixed enum index (`hunger`, `cleanliness`, `fun`, `sleep`). Stated explicitly so no one looks for a missing equation.

### MVP balance values (species `bloop`)

| Need | `decay_per_hour` | `sad_threshold` | `floor` | `restore_amount` (action) |
|---|---|---|---|---|
| hunger | 3.0 | 40 | 0 | 100 (feed) |
| cleanliness | 3.0 | 40 | 0 | 100 (clean) |
| fun | 3.0 | 40 | 0 | 100 (play) |
| sleep | 1.5 | 40 | 0 | 100 (lights) |

Derivation against the concept's "one check-in per day keeps the pet content" target: hunger crosses `sad_threshold` at `(100 − 40) / 3.0 = 20 h` — sad roughly 4 h before a 24 h check-in, a reliable margin against a player who checks in slightly early. At exactly 24 h it sits at `100 − 3.0 × 24 = 28`: visibly sad, yet 28 points clear of the floor, which is the Pillar 2 shape — a reason to return, not a reproach. Total neglect reaches the floor only at `100 / 3.0 ≈ 33 h`. Sleep is deliberately the *occasional* need (sad at `60 / 1.5 = 40 h`, floor at ~67 h): a routine daily player tends it every other day or so, which keeps the lights action a pleasant variation rather than a daily chore. This intentionally places sleep outside the daily-rhythm safe band in Tuning Knobs — see the exemption there.

### Implementation notes (GDScript)

These are correctness requirements, not style preferences — each is a case where the naive translation is silently wrong:

- **`elapsed_seconds / 3600.0`, never `/ 3600`.** Both operands are `int`; integer division truncates toward zero, so 1800 s would yield 0 and drop 30 minutes of decay without any error.
- **`ceili()` for `seconds_until_sad`, not a truncating `int()`** — so a scheduled notification fires at or after the crossing, never seconds early.
- **`clamp(value, float(floor), 100.0)` — cast the `int` bounds explicitly.** `NeedProfile` fields are `int`; mixed-type `clamp()` works through implicit widening, but the project treats unsafe-cast warnings as errors under static typing, so the casts are written out. Argument order is (value, min, max).
- **State comparisons use `>` / `<=` against `float(sad_threshold)`, never `==`.** `sad_threshold` is not a clamp bound, so a computed value lands on it exactly only for binary-exact inputs; the precedence in Core Rule 10 is written as inequalities so correctness never depends on hitting it exactly.
- **`value == floor` is a safe float equality here** *only* because `clamp()` returns the exact bound. Do not generalise that to other float comparisons in this system.
- **Every typed-return function returns on every path.** Godot 4.7 errors on a typed-return method that can fall off the end. Write `seconds_until_sad` as early `return`s followed by an unconditional final `return`, so adding a guard later cannot silently open a path with no return.
- **Collections are typed.** `get_urgency_ranking() -> Array[Need]`, never a bare `Array`.

*`systems-designer` consulted (Lean mode) — formulas, balance values and boundary analysis reviewed. Re-examined at the 2026-09-22 `/design-review`.*

## Edge Cases

**Time and elapsed**

- **If `elapsed_seconds` is 0** (two reads in the same second): the computed value equals `anchor_value` exactly. Repeated reads never drift, because nothing accumulates.
- **If the device clock rolls back** (`anchor_utc` in the future): Time Service already clamps `get_elapsed_seconds()` to 0, so the need simply holds its anchor value. Need System adds no defence of its own and must not — duplicating the guard would create two places to get it wrong.
- **If elapsed spans years** (a dormant install): the arithmetic is exact well past any plausible gap, and the clamp lands the value at `floor`. No special-casing, no overflow, no precision loss.

**Corrupt or hostile data**

- **If `anchor_value` is out of range** (150, or −20, from a corrupted or tampered save): `clamp()` heals the *computed* value on every read, so gameplay never sees a bad number. But the *persisted* anchor stays corrupt until the next mutation, because a read is not a mutation (Core Rule 5). **Save & Persistence must validate anchors on load** — this is the one case Need System cannot fix for itself.
- **If `floor == sad_threshold`**: the `SAD` band collapses to nothing and the need transitions `CONTENT → AT_FLOOR` directly. Legal, but it means the need is never "a bit sad" — it is fine, then bottomed. `seconds_until_sad` still returns the finite crossing moment.
- **If `floor > sad_threshold`**: the need can never become sad. By the Core Rule 10 precedence it reads `CONTENT` at every value, including at the floor, so states stay disjoint; `seconds_until_sad` returns `-1` and the icon never shows. Excluded by the proposed Pet Definition Data rule; the precedence keeps behaviour defined until then.
- **If `floor == 100`**: `clamp(x, 100, 100)` freezes the need at 100 forever; decay has no observable effect. Excluded by the same proposed rule (`floor < sad_threshold < 100`).
- **If `sad_threshold == 100`**: the need reads sad at any value below full and can never be `CONTENT`, so `all_needs_addressed` is permanently unreachable — the "done for today" payoff silently disappears. This is the most harmful case in this list, and the reason the proposed rule's upper bound is strict (`< 100`, not `≤ 100`).
- **If `sad_threshold == 0`**: only a need sitting exactly at floor is sad; the `SAD` state never fires on its own.
- **If `decay_per_hour` is legal but vanishingly small** (e.g. `1e-300`): `need_value` is fine, but `seconds_until_sad` overflows `ceili()`. Excluded by the proposed minimum `decay_per_hour ≥ 0.01`.

**Care**

- **If care is applied to a need already at 100**: legal no-op on the value, but the reaction still plays and the press still feels answered. Pillar 2 forbids a "you didn't need to do that" response (Core Rule 7).
- **If care restores a need but not above `sad_threshold`** (a small `restore_amount` against a deeply decayed need): the need stays `SAD`, the icon stays lit, and the reaction still plays. At MVP's `restore_amount = 100` this cannot occur, but the rule must hold for future tuning.
- **If the lights action is applied when sleep is not sad**: identical to any other care on a content need — sleep re-anchors upward (usually to 100), the lights-out beat plays, and no icon changes. Whether Device Frame *offers* the action in that case is its own decision (see Open Questions); Need System accepts it either way.

**Crossing detection**

- **If the production timer fires late, early, or not at all** (suspension, OS throttling): detection is state-based, so the next `check_crossings()` — from the next timer, the next re-anchor, or `on_resumed()` — emits any missed crossing exactly once. A timer that fires early finds no state change and emits nothing.
- **If a need crosses and is cared for before any check runs** (app suspended through the crossing, player tends it immediately on resume before `on_resumed()` is called): the re-anchor resets `last_observed_state` to `CONTENT`, so no stale `need_became_sad` fires afterwards. The resume ordering in Core Rule 14 makes this case rare; it is harmless when it occurs.

**Queries**

- **If the urgency ranking is requested when no need is sad**: return an empty `Array[Need]`. Device Frame must handle this — its GDD currently assumes a cursor position derived from "most urgent need" and does not define the all-content case. This is the normal state of a pet immediately after a care session (see Open Questions).
- **If sleep is the most urgent need**: it ranks first like any other need. Device Frame's ring holds only feed/clean/play (lights is a contextual **B** action), so "cursor on most urgent need" has no ring item to land on in that case. The ranking stays correct; cursor placement is Device Frame's to define (see Open Questions).

**Persistence and aggregate state**

- **If the app is killed mid-session**: an anchor is two plain fields with no intermediate state, so there is no partial write to recover from. Whatever was last saved is internally consistent by construction.
- **If all four needs reach `floor` simultaneously**: nothing happens. There is no cascade, no compound penalty, no distinct "critical" condition — four needs at floor is just four needs at floor, and one care session still fully restores each. This is the Pillar 2 guarantee stated as an edge case so it is explicitly testable.

*`systems-designer` boundary analysis (Lean mode, Formulas pass) fed this section directly; the precedence, `sad_threshold == 100` and tiny-decay cases were added at the 2026-09-22 `/design-review`.*

## Dependencies

**Upstream (what Need System depends on):**

| Depends on | Type | Interface Used |
|---|---|---|
| Time Service | Hard | `get_now_utc()`, `get_elapsed_seconds(anchor_utc)` |
| Pet Definition Data | Hard | `NeedProfile` (`decay_per_hour`, `sad_threshold`, `floor`), `CareProfile.restore_amount` for all four actions |

That is the complete upstream list. Need System is buildable as soon as those two exist, which matches its Core-layer position in the systems index. Every field it reads already exists in Pet Definition Data's approved schema; the only owed amendment is a validation tightening (see Open Questions), not a new field.

**No edge from Device Frame into Need System.** With sleep press-restored, the lights action reaches Need System the same way feed does — Device Frame emits `action_selected(lights)`, Care Actions calls `apply_care(lights)`. Device Frame writes nothing to Need System, so the earlier `dark`-flag mirroring pattern, and the cycle it existed to break, are gone.

**Downstream (what depends on Need System):**

| Depends on Need System | Type | Interface Used |
|---|---|---|
| Care Actions | Hard | `apply_care(action_id)` for feed, clean, play and lights; listens to `need_changed`, `need_cleared` |
| Offline Time Simulation | Hard | `reanchor_with_cap(max_offline_s)`, called before `on_resumed()` on the same resume |
| App lifecycle (resume handler) | Hard | `on_resumed()`. Who owns the handler is set by the time/event ADR |
| Pet Animation & Reactions | Hard | `need_became_sad`, `need_cleared`, `all_needs_addressed` |
| Daily Notification | Hard | `seconds_until_sad(need)`, `next_crossing_utc(need)` |
| Save & Persistence | Hard (two-way) | Reads a copy of the anchor set to serialise; hands one back on load. Save owns the storage format; Need System owns the values and their validity |
| LCD Screen Renderer | Hard | Current values and derived states, to draw the need icons and the "done for today" state |
| Device Frame & Button Input | **Soft** | `get_urgency_ranking()`. Soft by design: with an empty or unavailable ranking the menu cursor defaults to ring index 0 and the device remains fully usable |

**Why the Device Frame edge must stay soft.** Device Frame sits in the Foundation layer and Need System in the Core layer; a hard Foundation→Core dependency would invert the build order and make the input framework unbuildable until needs exist. Keeping it soft preserves Device Frame's "buildable first" property while still letting it use the ranking when present.

**Systems-index edges.** The three edges found while writing this GDD — Device Frame → Need System (soft), LCD Screen Renderer → Need System (hard), Save & Persistence ↔ Need System (hard, two-way) — were recorded in `systems-index.md` on 2026-09-22. The index's note that "Device Frame writes `dark` to Need System one-way" is now stale (see Open Questions).

## Tuning Knobs

**Need System owns no tuning values of its own.** Every number it operates on lives in Pet Definition Data's `NeedProfile` and `CareProfile`, per Core Rule 2 and the coding standard's ban on hardcoded gameplay values. This section documents the knobs it *consumes*, the consequences the decay model gives them, and the band they must stay inside — Pet Definition Data remains the source of truth for the values themselves.

| Knob (owned by PDD) | MVP default | Too low | Too high |
|---|---|---|---|
| `decay_per_hour` | 3.0 (sleep 1.5) | Needs never go sad between daily check-ins — the visit has no purpose and the daily hypothesis fails. Below 0.01, `seconds_until_sad` can overflow (proposed PDD minimum) | Pet is at `floor` before the player's next check-in; every return starts bottomed out, which reads as punishment (Pillar 2) |
| `sad_threshold` | 40 | Icon appears only when the need is nearly bottomed — no warning, and the urgency ranking has nothing to order | Need reads sad almost permanently; at 100 it can never be content and "done for today" is unreachable |
| `floor` | 0 | N/A — 0 is the safe default and the floor cannot be negative | Approaching 100 makes decay invisible; at or above `sad_threshold` the need can never go sad |
| `restore_amount` | 100 (all four actions) | Care cannot clear a need in one press, breaking the two-minute session promise. Very small values (≈1) produce a reaction for a change the player cannot see | Capped at 100 by the clamp; 100 means one press always fully clears from any value |

**The derived safe band for `decay_per_hour` (daily needs).** Two concept-level requirements bracket it, given a 24-hour check-in rhythm:

- To be **sad by the next check-in**: `(100 − sad_threshold) / decay_per_hour < 24` → `decay_per_hour > (100 − sad_threshold) / 24`
- To **not be at floor** by the next check-in: `100 / decay_per_hour > 24` → `decay_per_hour < 100 / 24 ≈ 4.17`

At the MVP `sad_threshold` of 40 this gives a band of roughly **2.5 to 4.17**, and the chosen 3.0 sits comfortably inside it with margin at both ends. Any future re-tune of hunger, cleanliness or fun should be checked against this band rather than by feel alone — a value outside it breaks either the reason to return or the no-guilt promise, and does so silently.

**Exemption: sleep.** The band's lower bound encodes "sad by every daily check-in". Sleep is designed *not* to meet it — at 1.5 it is the occasional need, sad roughly every other day. Only the upper bound (`< 4.17`, never at floor by the next check-in) applies to sleep, because that one is the Pillar 2 guarantee. A re-tune of sleep should keep it below the daily needs' rate and above the Pillar 2 ceiling.

**Explicitly not knobs:**

- **The 0–100 scale** — a constraint. Changing it invalidates every threshold, floor and restore value in every species definition simultaneously.
- **The enum tie-break order** (`hunger`, `cleanliness`, `fun`, `sleep`) — a constraint that exists to make the urgency ranking deterministic and therefore testable. Making it configurable would make the ranking untestable for no player-visible gain.
- **The anchor model itself** — architecture, not tuning. There is no "decay interval" or "tick rate" to adjust, because there is no tick.
- **`MAX_OFFLINE`** — owned by Offline Time Simulation, as Time Service's GDD already establishes. Not duplicated here.

*(Thin by design — reduced-depth pass per the compressed path.)*

## Visual/Audio Requirements

Need System renders nothing and plays nothing. It owns no sprites, no icons, no sound, and has no presence on the LCD layer of its own. What it owns is the **set of moments** other systems present, and those moments are listed here so no one has to infer them from signal names.

| Moment | Trigger | Presented by |
|---|---|---|
| A need icon appears | `need_became_sad(need_id)` | LCD Screen Renderer |
| A need icon clears | `need_cleared(need_id)` | LCD Screen Renderer |
| Pet idle shifts content ↔ sad | any need entering/leaving `SAD`/`AT_FLOOR` | Pet Animation & Reactions |
| "Done for today" | `all_needs_addressed()` | LCD Screen Renderer + Pet Animation & Reactions (happy idle) |
| Care reaction beat — feed, clean, play | `need_changed` following `apply_care` | Pet Animation & Reactions |
| Care reaction beat — lights ("lights out") | `need_changed` following `apply_care(lights)` | Pet Animation & Reactions: a short beat (screen dims, pet dozes, lights return), same length class as the other reactions |

Three constraints this system places on whoever presents those moments:

- **`AT_FLOOR` must not get its own escalated visual.** It shows the same icon as `SAD`. A distinct "critical" presentation would reintroduce the punishment Pillar 2 forbids, through the art rather than the rules.
- **A care press on an already-full need still gets a reaction** (Core Rule 7). The visual layer must not suppress the beat just because the value did not change.
- **"Lights out" is momentary.** The screen returns to normal when the beat ends; the device never stays dark. A persistent dark screen would read as a switched-off toy (Pillar 1) and has no way back through three buttons.

## UI Requirements

Need System has no UI surface. It exposes no screen, no menu and no control, and the player never interacts with it directly — every interaction arrives through Device Frame's three buttons and is applied by Care Actions.

Its only UI-adjacent obligation is the **urgency ranking contract** consumed by Device Frame: an `Array[Need]` of sad needs, ascending by value, tie-broken by enum index, **and empty when no need is sad**. Device Frame's GDD does not currently define its behaviour for the empty case, nor for sleep ranking first (see Open Questions).

Need icon layout, cursor rendering and the "done for today" presentation all belong to LCD Screen Renderer.

## Acceptance Criteria

All criteria below are **BLOCKING** and independently automatable in gdUnit4 against a `FakeTimeSource`, except one **ADVISORY** criterion for the production timer adapter (last block). The logic layer is pure; the adapter is the single place engine timing is involved, and it is kept out of the unit-tested surface by Core Rule 14.

**Enum and scale**

- **GIVEN** the Need enum, **WHEN** inspected, **THEN** it contains exactly `{hunger, cleanliness, fun, sleep}` in that order and no fifth value. *(Core Rule 1)*
- **GIVEN** any valid anchor/elapsed input, **WHEN** `need_value()` is called, **THEN** the return is a `float` satisfying `floor ≤ value ≤ 100`. *(Core Rule 2)*

**`need_value`**

- **GIVEN** `anchor_value=100`, `decay_per_hour=3.0`, `elapsed=0`, **WHEN** called twice in a row, **THEN** both calls return exactly `100.0` — no drift on a same-instant re-read, because nothing accumulates. *(Core Rule 3, Edge Cases)*
- **GIVEN** `anchor_value=100`, `decay_per_hour=3.0`, `elapsed=72000`, **WHEN** called, **THEN** it returns `40.0`. *(`need_value`)*
- **GIVEN** `anchor_value=100`, `decay_per_hour=3.0`, `elapsed_seconds=1800`, **WHEN** called, **THEN** it returns `98.5`. **An implementation using `elapsed_seconds / 3600` truncates to zero decay and must fail this assertion.** *(Implementation notes)*
- **GIVEN** sleep with `anchor_value=100`, `decay_per_hour=1.5`, `elapsed=86400`, **WHEN** called, **THEN** it returns `64.0` — sleep uses the same formula as every other need. *(Core Rule 9, `need_value`)*
- **GIVEN** a ~5-year elapsed gap (`elapsed=157680000`), **WHEN** called, **THEN** the result is exactly `float(floor)`. *(Edge Cases)*
- **GIVEN** `floor=0`, `elapsed=0`, and a corrupted `anchor_value` of `150`, **WHEN** called, **THEN** it returns exactly `100.0`; **AND GIVEN** a corrupted `anchor_value` of `-20`, **THEN** it returns exactly `0.0`. *(Edge Cases)*
- **GIVEN** `anchor_value=70` and an `anchor_utc` 3600 s ahead of the fake clock (simulated rollback), **WHEN** called, **THEN** it returns exactly `70.0`. *(Edge Cases)*
- **GIVEN** `floor == sad_threshold == 40`, `anchor_value=100`, `decay_per_hour=3.0`, **WHEN** sampled at `elapsed=71999` and `elapsed=72000`, **THEN** the states are `CONTENT` then `AT_FLOOR`, with no `SAD` observed. *(Edge Cases)*

**`apply_care`**

- **GIVEN** `need_value(now)=28`, `restore_amount=100`, **WHEN** care is applied, **THEN** `anchor_value=100` and `anchor_utc=now`. *(`apply_care`, Core Rule 5)*
- **GIVEN** `need_value(now)=100`, **WHEN** care is applied, **THEN** the value stays `100` but `anchor_utc` still updates — re-anchoring is unconditional. *(Core Rules 5, 7)*
- **GIVEN** a restore landing below `sad_threshold` (`restore_amount=10`, `value=5`, `threshold=40`), **WHEN** applied, **THEN** the value is `15`, the state stays `SAD`, no `need_cleared` fires, and `need_changed` does. *(States and Transitions)*
- **GIVEN** sleep `SAD` at value `28` and `CareProfile.restore_amount(lights)=100`, **WHEN** `apply_care(lights)` is called, **THEN** sleep's value is `100.0`, its state is `CONTENT`, and `need_cleared(sleep)` fires. *(Core Rules 7, 9)*
- **GIVEN** sleep anchored at `t=0` with `anchor_value=100`, `decay_per_hour=1.5`, `restore_amount(lights)=10`, **WHEN** `apply_care(lights)` is called at `t=36000` and again at `t=72000`, **THEN** the anchors are `95.0` then `90.0`, and `need_value` at `t=108000` is exactly `75.0` — a chain of re-anchors is lossless. *(Core Rules 5, 6)*

**`seconds_until_sad` and `next_crossing_utc`**

- **GIVEN** `v0 ≤ sad_threshold`, **WHEN** called, **THEN** it returns `0`. *(sentinel contract)*
- **GIVEN** `floor=50`, `sad_threshold=40`, **WHEN** called at any value, **THEN** it returns `-1`. *(sentinel contract)*
- **GIVEN** `floor == sad_threshold == 40`, `v0=100`, `decay_per_hour=3.0`, **WHEN** called, **THEN** it returns `72000`, not `-1`. *(`seconds_until_sad`)*
- **GIVEN** `v0=100`, `sad_threshold=40`, `decay_per_hour=7.0` (exact answer `30857.14…`), **WHEN** called, **THEN** it returns `30858`. **A truncating `int()` returning `30857` must fail this assertion.** *(Implementation notes)*
- **GIVEN** a need anchored at `t=1000` with `anchor_value=100`, `decay_per_hour=3.0`, `sad_threshold=40`, and the fake clock at `t=1000`, **WHEN** `next_crossing_utc()` is called, **THEN** it returns `73000`; for a need with `floor > sad_threshold` it returns `-1`. *(Core Rule 14)*

**`all_needs_addressed`**

- **GIVEN** (a) all four needs `CONTENT`, (b) three `CONTENT` with sleep `SAD`, (c) the state from (b) after `apply_care(lights)` with `restore_amount=100`, **WHEN** evaluated, **THEN** the results are `true`, `false`, `true` respectively, and `all_needs_addressed()` is emitted on the transition into (c). *(`all_needs_addressed`)*
- **GIVEN** a `NeedProfile` with `sad_threshold=100` for any need, **WHEN** that need is at `100.0`, **THEN** its state is `SAD`, not `CONTENT` — documenting why the Pet Definition Data rule must exclude this data. *(Edge Cases)*

**Urgency ranking**

- **GIVEN** hunger=10 and fun=25 both `SAD`, cleanliness `CONTENT`, sleep `AT_FLOOR`(0), **WHEN** `get_urgency_ranking()` is called, **THEN** it returns the `Array[Need]` `[sleep, hunger, fun]`. *(Core Rule 11)*
- **GIVEN** two sad needs at an identical value, **WHEN** ranked, **THEN** they order by enum index (hunger < cleanliness < fun < sleep). *(Core Rule 11)*
- **GIVEN** no need is sad, **WHEN** called, **THEN** it returns an empty `Array[Need]`, never null. *(Edge Cases)*

**State derivation**

- **GIVEN** `anchor_value=100`, `decay_per_hour=3.0`, `sad_threshold=40`, **WHEN** sampled at `elapsed=71999`, `72000` and `72001`, **THEN** the states are `CONTENT`, `SAD`, `SAD`. The inputs are binary-exact, so `elapsed=72000` yields exactly `40.0`; the implementation must compare with `<=`, not `==`. *(Core Rule 10, Implementation notes)*
- **GIVEN** decay carrying a value to exactly `floor` (with `floor < sad_threshold`), **WHEN** queried, **THEN** the state reads `AT_FLOOR` and ranks first among ties. *(States and Transitions)*
- **GIVEN** `floor=50`, `sad_threshold=40`, and a need decayed to its floor, **WHEN** state is queried, **THEN** it reads `CONTENT` — not `AT_FLOOR`, and never both. *(Core Rule 10 precedence)*
- **GIVEN** a `SAD`/`AT_FLOOR` need, **WHEN** care re-anchors it above `sad_threshold`, **THEN** the state reads `CONTENT` and `need_cleared` fires. *(States and Transitions)*
- **GIVEN** an instance constructed only from a persisted anchor pair with no mutation yet, **WHEN** state is queried at three different fake-clock times, **THEN** each result matches the state computed from `need_value` at that time — proving state is recomputed, never cached. *(Core Rule 10)*

**Anchor ownership**

- **GIVEN** a Need System with non-default anchors on all four needs, **WHEN** its anchor set is read and a fresh instance is constructed from that set with the same `TimeService`, **THEN** every need's value and state are identical between the two instances; **AND WHEN** the read-out set is modified afterwards, **THEN** the original instance's values do not change. *(Core Rule 13 — accessor names provisional, see Open Questions)*

**Crossing detection (logic layer)**

- **GIVEN** hunger anchored at `t=0` with `anchor_value=100`, `decay_per_hour=3.0`, `sad_threshold=40`, **WHEN** `check_crossings()` is called with the fake clock at `71999`, then at `72000`, then again at `72000`, **THEN** `need_became_sad(hunger)` is emitted exactly once, on the second call. *(Core Rule 14)*
- **GIVEN** hunger `CONTENT` at its anchor and the fake clock advanced from `t=0` to `t=100000` with no intervening `check_crossings()` (simulated suspension), **WHEN** `on_resumed()` is called, **THEN** `need_became_sad(hunger)` is emitted exactly once, and a second `on_resumed()` at the same time emits nothing. *(Core Rule 14)*
- **GIVEN** a need that crossed while unobserved, **WHEN** care re-anchors it above `sad_threshold` before any `check_crossings()` runs, **THEN** a subsequent `check_crossings()` emits no `need_became_sad` for it. *(Edge Cases)*

**No-cascade guarantee**

- **GIVEN** all four needs simultaneously `AT_FLOOR`, **WHEN** care is applied to each in any order, **THEN** each restores fully with no interaction, ordering dependency or blocked state. *(Core Rule 8)*

**Production timer adapter — ADVISORY**

- **GIVEN** a build on a real device with `NeedCrossingScheduler` active and a need 2 minutes from its crossing (test species with a fast `decay_per_hour`), **WHEN** the app is (a) left in the foreground past the crossing and (b) backgrounded across the crossing and resumed, **THEN** the need icon appears in both cases without further input. Evidence: integration test or on-device walkthrough in `production/qa/evidence/`. *(Core Rule 14 adapter — not unit-testable by design)*

Every BLOCKING clock-dependent criterion uses a `FakeTimeSource`; none depends on real wall-clock time, sleeps, engine timers, or inter-test ordering. Core Rules 4 and 12 have no dedicated criterion by design: 4 is proven jointly by the `need_value` and `on_resumed()` criteria (elapsed time is the only input, whether or not the app was running), and 12 is enforced project-wide by the existing `clock-discipline` CI job.

*`qa-lead` consulted (Lean mode) — coverage and gate levels validated. Revised at the 2026-09-22 `/design-review`.*

## Open Questions

**Contract changes owed by Pet Definition Data (Approved GDD — not edited from this session):**

- **Q**: PDD's load-time validation (its Core Rule 12) permits `floor ≥ sad_threshold`, `sad_threshold == 100` and vanishingly small `decay_per_hour`. Each silently breaks a need; `sad_threshold == 100` removes the "done for today" payoff entirely (see Edge Cases). Proposed checks: `floor < sad_threshold < 100` for every need, and `decay_per_hour ≥ 0.01`. The upper bound must be strict — the earlier `≤ 100` draft let the worst case through. **Owner**: systems-designer. **Target**: PDD Core Rule 12 amendment, before the first catalog validator is implemented and before Need System ships.
- **Q**: PDD's Overview describes current need levels as "runtime state owned by Save & Persistence", while Core Rule 13 here says Need System owns the live anchors and Save serialises them. Wording correction only — no schema impact. **Owner**: Pet Definition Data. **Target**: next touch of that file.
- **Q**: A very small `restore_amount` (≈1) produces a full reaction for a change the player cannot see. Consider a minimum-perceptible-restore guideline alongside the existing `restore_amount` range. **Owner**: systems-designer. **Target**: PDD tuning pass; not blocking at MVP's `restore_amount = 100`.
- ~~**Q**: `recover_per_hour` is required by Core Rule 9 but has no home in PDD's `NeedProfile` schema.~~ **Resolved 2026-09-22** — sleep is press-restored (Core Rule 9); the field is no longer needed.
- ~~**Q**: `CareProfile.restore_amount` for the `lights` action is dead data.~~ **Resolved 2026-09-22** — it is now the sleep restore amount.

**Undefined downstream interfaces:**

- **Q**: `reanchor_with_cap(max_offline_s)` is named in the Interactions table but has no formula, no Core Rule, and no specified behaviour when elapsed is already under the cap. Its ordering relative to `on_resumed()` is fixed here (cap first). **Owner**: Offline Time Simulation. **Target**: that GDD's session, once `MAX_OFFLINE` is defined there.
- **Q**: The accessor shape Save & Persistence uses to read and write the anchor set is unspecified (getter/setter names, exposure form); the Core Rule 13 criterion fixes only the copy semantics. Same class of gap as Time Service's open anchor-timestamp contract. **Owner**: Save & Persistence. **Target**: that GDD's session.
- **Q**: Who calls `on_resumed()`, and from which engine notification? It depends on `NOTIFICATION_APPLICATION_RESUMED` behaviour, which is still unverified for 4.7 (Time Service Open Questions). Where `NeedCrossingScheduler` lives in the scene tree belongs to the same decision. **Owner**: technical-director. **Target**: the time/event injection ADR.

**Cross-GDD corrections owed to other documents:**

- **Q**: Device Frame's lights contract must be restated for the press-restored model. Lights is a contextual **B** action that emits `action_selected(lights)` to Care Actions — not a device state, and there is no `dark` flag or `set_dark()`. "Sleepy" (the condition that surfaces the toggle) is undefined; the proposal is "sleep is `SAD` or `AT_FLOOR`". **Owner**: Device Frame & Button Input. **Target**: its revision session (it already carries 11 blocking items from the 2026-09-22 review).
- **Q**: Device Frame assumes a cursor position derived from the "most urgent need" but defines neither the **empty** ranking (the normal state after a completed care session) nor the case where **sleep ranks first**, since sleep has no ring item. **Owner**: Device Frame & Button Input. **Target**: same revision session.
- **Q**: Care Actions must accept `lights` as a non-ring contextual action that calls `apply_care(lights)` and requests the lights-out reaction. This matches Device Frame's existing Open Question on reclassifying lights. **Owner**: Care Actions. **Target**: that GDD's session.
- **Q**: `systems-index.md` scope notes still say "Device Frame writes `dark` to Need System one-way — the same cycle-breaking pattern used for Device Frame ↔ Settings." That is stale: Device Frame has no data path into Need System. **Owner**: — . **Target**: next touch of the index.

**Tuning and validation:**

- **Q**: The MVP balance values (`decay_per_hour = 3.0`, sleep `1.5`, `sad_threshold = 40`) are derived arithmetically against a 24-hour check-in target and have never been played. The derived safe band (2.5–4.17 at threshold 40) bounds the daily needs, but only playtest can confirm the rhythm feels right rather than merely computing right, and whether sleep as the every-other-day need reads as a pleasant variation. **Owner**: design. **Target**: first playtest.
- **Q**: The Player Fantasy claims a returning player feels *relief* rather than guilt. Need System alone cannot deliver that — it depends on the greeting beat owned by Pet Animation & Reactions and on the decay rate landing well. **Owner**: design. **Target**: vertical slice.
