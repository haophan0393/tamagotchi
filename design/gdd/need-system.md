# Need System

> **Status**: In Design
> **Author**: Hao Phan + Claude (lean review mode)
> **Last Updated**: 2026-09-22
> **Implements Pillar**: 2 (Never Guilt, Always Welcome), 3 (Two Minutes of Joy)

## Overview

Need System is the game's clock-driven appetite: it holds the four needs every pet has — `hunger`, `cleanliness`, `fun` and `sleep` — on a fixed 0–100 scale, decays them in real time against the injected Time Service, and raises each one's "sad" flag when it falls to or below the threshold its species defines. It owns the *behaviour* of needs, never their numbers: every decay rate, sad threshold and floor is read from the `NeedProfile` in Pet Definition Data, so re-tuning a species is a data edit and never a code change (Pillar 5). Decay runs live while the app is open, not only on resume — Offline Time Simulation reuses the same decay rule to catch up a closed-app gap, rather than implementing a second one. To the player, this system is the entire reason to come back: it is what makes need icons appear overnight, what shifts the pet's idle from content to sad, and what clears — one icon at a time, with a visible payoff — when Care Actions applies a restore. Without it the pet is a static sprite and the daily ritual has nothing to be *about*. Its hardest constraint is Pillar 2: needs decay toward a non-fatal floor and stop there, so an absence of any length leaves a pet that is sad and messy but never dying, never scolding, and always fully addressable in a single two-minute session.

## Player Fantasy

Gentle responsibility, and the small clean satisfaction of a finished ritual.

The player should feel *needed but never harassed*. Needs are a soft tug, not an alarm: opening the app to two waiting icons should read as "oh, there you are" — a creature that got on with its day and could use a hand — never as a backlog or a reprimand. The target moment is the one `game-concept.md` calls the "done for today" signal: icons clearing one at a time under the player's thumb, each with its own reaction beat, until the last one goes and the pet drops into its happy idle. That final empty screen is the payoff this system exists to produce, and it must be reachable in a single two-minute session no matter how long the player has been away.

The inverse is the thing to protect against hardest. A need that decays too fast turns the ritual into a chore; a need that never decays makes the visit pointless. Pillar 2 sets the asymmetry: the pet may look sad, but a returning player's first feeling must be *relief that it's fine*, not guilt at what they let happen.

*(Thin by design — reduced-depth pass per the compressed path. `creative-director` not consulted — Lean mode. Review manually before production.)*

## Detailed Rules

### Core Rules

1. **Four needs, fixed in code.** `hunger`, `cleanliness`, `fun`, `sleep` — an enum, not data (inherited from Pet Definition Data Core Rule 1). Need System adds no fifth need, and a new species varies the *numbers*, never the set.

2. **Need System owns the 0–100 scale.** 100 is fully content, 0 fully depleted. Values are computed and stored as `float`; `NeedProfile`'s `sad_threshold` and `floor` and `CareProfile`'s `restore_amount` remain `int` as authored, and comparisons are made against the float value. *(This closes Pet Definition Data Open Question #4, which explicitly deferred scale ownership to this GDD.)*

3. **A need is an anchor, not a running total.** Each need holds exactly two persisted fields: `anchor_value: float` and `anchor_utc: int`. The current value is **computed on read** from those two plus the elapsed time — never accumulated into. There is no decay timer and no per-frame subtraction.

4. **One decay rule, online and offline.** Because value is derived from elapsed time, a closed app, a suspended app and a running app are arithmetically identical. Offline Time Simulation does not implement a second decay path; resuming from a two-week gap and idling for two weeks produce the same number.

5. **Every mutation re-anchors.** Applying care, changing a rate, or applying an Offline Sim cap all follow the same two-step: compute the value at `now`, then write it back as the new `anchor_value` with `anchor_utc = now`. Re-anchoring is the only legal way to change a need.

6. **A rate change is a mutation.** This is the non-obvious consequence of rule 3: if a need's decay rate changes mid-flight, the old anchor is no longer valid, because it was computed under the old rate. The sleep need's lights transition (rule 9) is the only case in MVP, and it **must** re-anchor on both edges.

7. **Care restores by re-anchoring upward.** `anchor_value = clamp(value(now) + restore_amount, floor, 100)`. Restoring a need already at 100 is legal, costs nothing, and is not an error — Pillar 2 forbids a "you didn't need to do that" response.

8. **Decay stops at the floor and nothing happens there.** A need clamps at `floor` (default 0) and stays. There is no death, no cascade to other needs, no escalating penalty, and no state below the floor. This is the hard Pillar 2 guarantee and the reason the system has no fail state to test for.

9. **Sleep is rate-switched by the dark state, not restored by a press.** Device Frame owns the `dark` flag (its Core Rule 4: a state change to the device, not an action on the pet). While `dark` is true, sleep moves *toward* 100 at `recover_per_hour`; while false, it decays at `decay_per_hour` like every other need. Device Frame must notify Need System on every toggle so rule 6 can re-anchor. *(Deviation from Pet Definition Data — see Open Questions.)*

10. **`sad` is derived, never stored.** `is_sad(need) = value(now) <= sad_threshold`. No flag is persisted, so a need can never be saved in a state that disagrees with its own value.

11. **Urgency ranking is a UX convenience with no mechanical weight.** Need System exposes the sad needs ordered ascending by current value, ties broken by the fixed enum order (`hunger`, `cleanliness`, `fun`, `sleep`). Deterministic by construction. `game-concept.md` states the order a player tends needs never matters mechanically — this ranking only places Device Frame's menu cursor.

12. **Need System never reads the wall clock.** All time comes from an injected `TimeService` (Time Service Core Rules 1–2). This is what makes every rule above unit-testable against a fake clock, and it is enforced by the existing `clock-discipline` CI job.

13. **Need System owns the live anchors; Save & Persistence serialises them.** The in-memory anchor set is this system's state and only this system mutates it. *(Pet Definition Data currently describes current need levels as "runtime state owned by Save & Persistence" — see Open Questions.)*

14. **Threshold crossings are scheduled, not polled.** Because `seconds_until_sad()` solves for the exact crossing moment, Need System arms one one-shot timer per need on every re-anchor rather than sampling each frame: `0` fires `need_became_sad` immediately, a positive value arms the timer, `-1` arms nothing. On app resume the timer cannot be trusted — it may not have fired while suspended — so Need System recomputes every need, emits any crossing that was missed, and re-arms. This is not a tick: the timer *observes* the formula, it never advances it.

### States and Transitions

Each need is independently in one of three states, derived from its computed value — none is stored:

| State | Condition | Notes |
|---|---|---|
| `CONTENT` | `value > sad_threshold` | No icon shown; contributes nothing to the urgency ranking |
| `SAD` | `floor < value ≤ sad_threshold` | Icon shown; enters the urgency ranking |
| `AT_FLOOR` | `value == floor` | A sub-state of `SAD`, not a worse one. Shows the same icon and ranks first by value. Exists so the Pillar 2 guarantee is explicitly testable |

| Transition | Trigger |
|---|---|
| `CONTENT → SAD` | Elapsed time carries the computed value to or below `sad_threshold` |
| `SAD → AT_FLOOR` | Elapsed time carries the computed value to `floor` |
| `SAD`/`AT_FLOOR` → `CONTENT` | Care re-anchors the value above `sad_threshold` |
| `SAD → SAD` | Care restores, but not above the threshold — legal, produces a reaction, clears no icon |
| *(sleep only)* rate flip | `dark` toggles; need re-anchors and reverses direction. The state itself does not change on the flip — only the rate does |

**There is no global system state.** Needs do not interact, gate, or cascade into one another; four needs at floor is not a distinct condition, it is just four needs at floor. The one aggregate fact this system publishes is `all_needs_addressed` — the concept's explicit "done for today" signal. Sleep counts as addressed while `dark` is true (see Formulas).

### Interactions with Other Systems

| System | Data In | Data Out | Owns the interface |
|---|---|---|---|
| Time Service | — | `get_now_utc()`, `get_elapsed_seconds()` | Time Service |
| Pet Definition Data | `NeedProfile` (decay_per_hour, sad_threshold, floor), `CareProfile` | — | Pet Definition Data |
| Care Actions | `apply_care(action_id)` | `need_changed`, `need_cleared` | **Need System** |
| Device Frame & Button Input | `set_dark(bool, at_utc)` | `get_urgency_ranking() -> Array` | **Need System** |
| Save & Persistence | anchor set on load | anchor set on save | Save & Persistence |
| Offline Time Simulation | `reanchor_with_cap(max_offline_s)` on resume | — | Offline Time Simulation |
| Pet Animation & Reactions | — | `need_became_sad`, `need_cleared`, `all_needs_addressed` | **Need System** |
| Daily Notification | — | `seconds_until_sad(need) -> int` | **Need System** |

**Signals published:** `need_changed(need_id, value)`, `need_became_sad(need_id)`, `need_cleared(need_id)`, `all_needs_addressed()`.

**`seconds_until_sad()` is a free consequence of the anchor model** and worth calling out: because value is a function of time, the system can solve for *when* a need will cross its threshold rather than polling for it. Daily Notification needs exactly this to schedule a reminder, and an accumulating tick model could not answer it without simulating forward.

**Offline Time Simulation's cap is applied by re-anchoring, not by Need System knowing about it.** `MAX_OFFLINE` stays Offline Sim's tuning knob (as Time Service's GDD already specifies); Offline Sim calls a re-anchor with the capped elapsed on resume. Note that with floor-clamping, a long absence lands at `floor` with or without the cap — the cap's real job is letting a returning player land *above* floor, which is a Pillar 2 lever, not a correctness one.

*Specialist agents not consulted for this section — Lean mode (specialists are spawned for Formulas and Acceptance Criteria). Review manually before production.*

## Formulas

The `need_value` formula is defined as:

`need_value = clamp(anchor_value + rate × (elapsed_seconds / 3600.0), floor, 100)`

where `rate = +recover_per_hour` when the need is `sleep` and `dark` is true, and `rate = −decay_per_hour` in every other case. A single signed-rate formula covers both directions; there is no separate recovery formula.

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| anchor_value | a | float | [floor, 100] | Value written at the last re-anchor |
| rate | r | float | ≠ 0 | Signed points per hour; negative decays, positive recovers |
| elapsed_seconds | e | int | ≥ 0 | `TimeService.get_elapsed_seconds(anchor_utc)` — never negative by construction |
| floor | F | int | 0 ≤ F < sad_threshold | Non-fatal minimum, from `NeedProfile` |

**Output Range:** `[floor, 100]`, always — the clamp is total, so no corrupted anchor or absurd elapsed can produce an out-of-range value. **Behaviour at extremes:** `elapsed = 0` returns `anchor_value` exactly, so repeated reads never drift. A five-year gap (≈1.58 × 10⁸ s) stays well inside float64 precision and simply clamps to `floor`.
**Example:** `anchor_value = 100`, `decay_per_hour = 3.0`, `elapsed = 72000` (20 h) → `100 − 3.0 × 20 = 40`.
**Example (dark):** `anchor_value = 28`, `recover_per_hour = 5.0`, `elapsed = 18000` (5 h) → `clamp(28 + 25, 0, 100) = 53`.

---

The `apply_care` formula is defined as:

`new_anchor_value = clamp(need_value(now) + restore_amount, floor, 100)`, with `new_anchor_utc = now`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| restore_amount | R | int | 1–100 | Points restored, from `CareProfile` |

**Output Range:** `[floor, 100]`. **Behaviour at extremes:** at `R = 100` the result is 100 from any starting value — one press always fully clears. Applying care to a need already at 100 is a legal no-op, never an error (Core Rule 7).
**Example:** `need_value(now) = 28`, `restore_amount = 100` → `clamp(128, 0, 100) = 100`.

---

The `seconds_until_sad` formula is defined as:

```
v0 = need_value(now);  r = active signed rate;  S = sad_threshold;  F = floor
if v0 ≤ S:   return 0      // already sad
if r ≥ 0:    return -1     // recovering or flat — will never cross downward
if F > S:    return -1     // floor sits above the threshold — unreachable
return ceili((v0 − S) / (−r) × 3600.0)
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| v0 | v₀ | float | [floor, 100] | Current value at call time |
| S | S | int | 0–100 | `sad_threshold` from `NeedProfile` |
| r | r | float | ≠ 0 | Active signed rate (see `need_value`) |

**Output Range:** `0`, `-1`, or a positive int. **The sentinel contract is fixed here and is part of the interface: `0` means already sad, `-1` means never.** No null, no error, no exception. **Behaviour at extremes:** the three guards are evaluated *before* the division, so `−r` is only reached once `r < 0` is established — there is no division-by-zero path.
**Example:** `v0 = 100`, `S = 40`, `decay_per_hour = 3.0` → `(100 − 40) / 3.0 = 20 h` → `72000`.

---

The `all_needs_addressed` condition is defined as:

`all_needs_addressed = every need is CONTENT, OR (need is sleep AND dark is true)`

**Output Range:** boolean. This is the concept's "done for today" signal. Sleep counts as addressed while the pet is in the dark because putting the pet to bed *is* the resolution for that need — it then recovers unattended and is `CONTENT` by morning. **Behaviour at extremes:** a player who clears three needs and leaves the lights on does **not** get the signal; the same player who also darkens the device does. This is the one place where a device state participates in a need condition.

---

**Urgency ranking is a comparator, not a formula.** Sad needs sort ascending by current value, ties broken by fixed enum index (`hunger`, `cleanliness`, `fun`, `sleep`). Stated explicitly so no one looks for a missing equation.

### MVP balance values (species `bloop`)

| Need | `decay_per_hour` | `recover_per_hour` | `sad_threshold` | `floor` | `restore_amount` |
|---|---|---|---|---|---|
| hunger | 3.0 | — | 40 | 0 | 100 |
| cleanliness | 3.0 | — | 40 | 0 | 100 |
| fun | 3.0 | — | 40 | 0 | 100 |
| sleep | 1.5 | 5.0 *(while dark)* | 40 | 0 | — *(rate-switched, not press-restored)* |

Derivation against the concept's "one check-in per day keeps the pet content" target: hunger crosses `sad_threshold` at `(100 − 40) / 3.0 = 20 h` — sad roughly 4 h before a 24 h check-in, a reliable margin against a player who checks in slightly early. At exactly 24 h it sits at `100 − 3.0 × 24 = 28`: visibly sad, yet 28 points clear of the floor, which is the Pillar 2 shape — a reason to return, not a reproach. Total neglect reaches the floor only at `100 / 3.0 ≈ 33 h`. Sleep is deliberately slower (sad at ~40 h, floor at ~67 h) so the routine daily player rarely meets a sad sleep need at all; recovery from 28 to 100 at 5.0/hr takes 14.4 h, about one night.

### Implementation notes (GDScript)

These are correctness requirements, not style preferences — each is a case where the naive translation is silently wrong:

- **`elapsed_seconds / 3600.0`, never `/ 3600`.** Both operands are `int`; integer division truncates toward zero, so 1800 s would yield 0 and drop 30 minutes of decay without any error.
- **`ceili()` for `seconds_until_sad`, not a truncating `int()`** — so a scheduled notification fires at or after the crossing, never seconds early.
- **`clamp(value, floor, 100)` takes (value, min, max) in that order.** A `floor > 100` is currently legal per the `NeedProfile` schema and would make this call incoherent rather than raise — see Open Questions.
- **`value == floor` is a safe float equality here** *only* because `clamp()` returns the exact bound. Do not generalise that to other float comparisons in this system.

*`systems-designer` consulted (Lean mode) — formulas, balance values and boundary analysis reviewed.*

## Edge Cases

**Time and elapsed**

- **If `elapsed_seconds` is 0** (two reads in the same second): the computed value equals `anchor_value` exactly. Repeated reads never drift, because nothing accumulates.
- **If the device clock rolls back** (`anchor_utc` in the future): Time Service already clamps `get_elapsed_seconds()` to 0, so the need simply holds its anchor value. Need System adds no defence of its own and must not — duplicating the guard would create two places to get it wrong.
- **If elapsed spans years** (a dormant install): the arithmetic is exact well past any plausible gap, and the clamp lands the value at `floor`. No special-casing, no overflow, no precision loss.

**Corrupt or hostile data**

- **If `anchor_value` is out of range** (150, or −20, from a corrupted or tampered save): `clamp()` heals the *computed* value on every read, so gameplay never sees a bad number. But the *persisted* anchor stays corrupt until the next mutation, because a read is not a mutation (Core Rule 5). **Save & Persistence must validate anchors on load** — this is the one case Need System cannot fix for itself.
- **If `floor == sad_threshold`**: the `SAD` band collapses to nothing and the need transitions `CONTENT → AT_FLOOR` directly. Legal, but it means the need is never "a bit sad" — it is fine, then bottomed.
- **If `floor > sad_threshold`**: the need can never become sad. `seconds_until_sad` returns `-1` and the icon never shows. Currently legal data — flagged for a Pet Definition Data load-time validation rule (see Open Questions).
- **If `floor == 100`**: `clamp(x, 100, 100)` freezes the need at 100 forever; decay has no observable effect. Silently breaks the need with no error. Same validation gap.
- **If `sad_threshold == 100`**: the need reads sad at any value below full. A Pillar 2 violation achievable purely through legal data, which is exactly why the validation rule matters.
- **If `sad_threshold == 0`**: only a need sitting exactly at floor is sad; the `SAD` state never fires on its own.

**Care**

- **If care is applied to a need already at 100**: legal no-op on the value, but the reaction still plays and the press still feels answered. Pillar 2 forbids a "you didn't need to do that" response (Core Rule 7).
- **If care restores a need but not above `sad_threshold`** (a small `restore_amount` against a deeply decayed need): the need stays `SAD`, the icon stays lit, and the reaction still plays. At MVP's `restore_amount = 100` this cannot occur, but the rule must hold for future tuning.

**The dark state**

- **If `dark` is toggled while sleep is already at 100**: the need re-anchors as required, and recovery has no visible effect because the clamp holds at 100. Harmless, and re-anchoring anyway keeps Core Rule 6 unconditional — a conditional re-anchor is how drift bugs start.
- **If `dark` is toggled rapidly**: every toggle re-anchors from the exact current value, so any number of flips in any pattern is lossless. There is no debounce and none is needed.
- **If `dark` is left on indefinitely**: sleep reaches 100 and holds; the other three needs decay normally. A player who leaves the pet in the dark forever still returns to a hungry, dirty, bored pet — darkness is not a pause button.
- **If `set_dark()` is called with a stale `at_utc`** (older than the current anchor): treat it as `now`. A rate change cannot be applied retroactively, because the elapsed time before it was genuinely spent at the old rate.

**Queries**

- **If the urgency ranking is requested when no need is sad**: return an empty array. Device Frame must handle this — its GDD currently assumes a cursor position derived from "most urgent need" and does not define the all-content case. This is a live cross-GDD gap, not a hypothetical: it is the normal state of a pet immediately after a care session (see Open Questions).
- **If `seconds_until_sad` is called on a recovering need** (sleep while dark): returns `-1` (never), since the value is moving away from the threshold, not toward it.

**Persistence and aggregate state**

- **If the app is killed mid-session**: an anchor is two plain fields with no intermediate state, so there is no partial write to recover from. Whatever was last saved is internally consistent by construction.
- **If all four needs reach `floor` simultaneously**: nothing happens. There is no cascade, no compound penalty, no distinct "critical" condition — four needs at floor is just four needs at floor, and one care session still fully restores each. This is the Pillar 2 guarantee stated as an edge case so it is explicitly testable.

*`systems-designer` boundary analysis (Lean mode, Formulas pass) fed this section directly.*

## Dependencies

**Upstream (what Need System depends on):**

| Depends on | Type | Interface Used |
|---|---|---|
| Time Service | Hard | `get_now_utc()`, `get_elapsed_seconds(anchor_utc)` |
| Pet Definition Data | Hard | `NeedProfile` (`decay_per_hour`, `recover_per_hour`, `sad_threshold`, `floor`), `CareProfile.restore_amount` |

That is the complete upstream list. Need System is buildable as soon as those two exist, which matches its Core-layer position in the systems index.

**Notably *not* an upstream dependency: Device Frame.** The `dark` flag would otherwise create a cycle — Need System needs `dark` to pick sleep's rate, while Device Frame needs the urgency ranking to place its cursor. **Resolution: Device Frame owns `dark` and writes it one-way via `set_dark(bool, at_utc)`; Need System holds its own mirrored copy and never reads back.** This is deliberately the identical pattern the systems index already uses to break Device Frame ↔ Settings, and it must not be inverted for the same reason: the writer owns the value, the reader mirrors it.

**Downstream (what depends on Need System):**

| Depends on Need System | Type | Interface Used |
|---|---|---|
| Care Actions | Hard | `apply_care(action_id)`; listens to `need_changed`, `need_cleared` |
| Offline Time Simulation | Hard | `reanchor_with_cap(max_offline_s)` |
| Pet Animation & Reactions | Hard | `need_became_sad`, `need_cleared`, `all_needs_addressed` |
| Daily Notification | Hard | `seconds_until_sad(need)` |
| Save & Persistence | Hard (two-way) | Reads the anchor set to serialise; writes it back on load. Save owns the storage format; Need System owns the values and their validity |
| LCD Screen Renderer | Hard | Current values and `SAD` flags, to draw the need icons and the "done for today" state |
| Device Frame & Button Input | **Soft** | `get_urgency_ranking()`. Soft by design: with an empty or unavailable ranking the menu cursor defaults to ring index 0 and the device remains fully usable |

**Why the Device Frame edge must stay soft.** Device Frame sits in the Foundation layer and Need System in the Core layer; a hard Foundation→Core dependency would invert the build order and make the input framework unbuildable until needs exist. Keeping it soft preserves Device Frame's "buildable first" property while still letting it use the ranking when present.

**Three corrections to `systems-index.md`** found while writing this section, none of which the index currently records:

| Missing edge | Nature |
|---|---|
| Device Frame & Button Input → Need System | Soft. Device Frame's own GDD already assumes the urgency ranking exists; the index lists Device Frame as depending on nothing |
| LCD Screen Renderer → Need System | Hard. The index folds "need icons" into LCD Renderer's scope but lists its dependencies as only Device Frame and Pet Definition Data |
| Save & Persistence ↔ Need System | Hard, two-way. The index lists Save as depending on Time Service and Pet Definition Data only, though it must serialise this system's anchors |

## Tuning Knobs

**Need System owns no tuning values of its own.** Every number it operates on lives in Pet Definition Data's `NeedProfile` and `CareProfile`, per Core Rule 2 and the coding standard's ban on hardcoded gameplay values. This section documents the knobs it *consumes*, the consequences the decay model gives them, and the band they must stay inside — Pet Definition Data remains the source of truth for the values themselves.

| Knob (owned by PDD) | MVP default | Too low | Too high |
|---|---|---|---|
| `decay_per_hour` | 3.0 | Needs never go sad between daily check-ins — the visit has no purpose and the daily hypothesis fails | Pet is at `floor` before the player's next check-in; every return starts bottomed out, which reads as punishment (Pillar 2) |
| `recover_per_hour` *(sleep)* | 5.0 | Sleep does not recover across one night, so darkening the device feels inert | Sleep refills almost instantly, making the lights toggle vestigial |
| `sad_threshold` | 40 | Icon appears only when the need is nearly bottomed — no warning, and the urgency ranking has nothing to order | Need reads sad almost permanently; at 100 it is sad at any value below full |
| `floor` | 0 | N/A — 0 is the safe default and the floor cannot be negative | Approaching 100 makes decay invisible; at or above `sad_threshold` it breaks the `SAD` state entirely |
| `restore_amount` | 100 | Care cannot clear a need in one press, breaking the two-minute session promise | Capped at 100 by the clamp; 100 means one press always fully clears from any value |

**The derived safe band for `decay_per_hour`.** Two concept-level requirements bracket it, given a 24-hour check-in rhythm:

- To be **sad by the next check-in**: `(100 − sad_threshold) / decay_per_hour < 24` → `decay_per_hour > (100 − sad_threshold) / 24`
- To **not be at floor** by the next check-in: `100 / decay_per_hour > 24` → `decay_per_hour < 100 / 24 ≈ 4.17`

At the MVP `sad_threshold` of 40 this gives a band of roughly **2.5 to 4.17**, and the chosen 3.0 sits comfortably inside it with margin at both ends. Any future re-tune should be checked against this band rather than by feel alone — a value outside it breaks either the reason to return or the no-guilt promise, and does so silently.

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
| Pet idle shifts content ↔ sad | any need entering/leaving `SAD` | Pet Animation & Reactions |
| "Done for today" | `all_needs_addressed()` | LCD Screen Renderer + Pet Animation & Reactions (happy idle) |
| Care reaction beat | `need_changed` following `apply_care` | Pet Animation & Reactions |

Two constraints this system places on whoever presents those moments:

- **`AT_FLOOR` must not get its own escalated visual.** It shows the same icon as `SAD`. A distinct "critical" presentation would reintroduce the punishment Pillar 2 forbids, through the art rather than the rules.
- **A care press on an already-full need still gets a reaction** (Core Rule 7). The visual layer must not suppress the beat just because the value did not change.

## UI Requirements

Need System has no UI surface. It exposes no screen, no menu and no control, and the player never interacts with it directly — every interaction arrives through Device Frame's three buttons and is applied by Care Actions.

Its only UI-adjacent obligation is the **urgency ranking contract** consumed by Device Frame: an ordered array of sad needs, ascending by value, tie-broken by enum index, **and empty when no need is sad**. Device Frame's GDD does not currently define its behaviour for the empty case, which is the normal state after a completed care session (see Open Questions).

Need icon layout, cursor rendering and the "done for today" presentation all belong to LCD Screen Renderer.

## Acceptance Criteria

All criteria below are **BLOCKING** and independently automatable in gdUnit4. Need System is pure logic over an injected `TimeService`, so unlike a rendering or feel system there is no criterion here requiring human judgement — no ADVISORY tier is listed because none is warranted.

**Enum and scale**

- **GIVEN** the Need enum, **WHEN** inspected, **THEN** it contains exactly `{hunger, cleanliness, fun, sleep}` in that order and no fifth value. *(Core Rule 1)*
- **GIVEN** any valid anchor/elapsed input, **WHEN** `need_value()` is called, **THEN** the return is a `float` satisfying `floor ≤ value ≤ 100`. *(Core Rule 2)*

**`need_value`**

- **GIVEN** `anchor_value=100`, `decay_per_hour=3.0`, `elapsed=0`, **WHEN** called, **THEN** it returns exactly `100.0` — no drift on a same-instant re-read. *(Edge Cases)*
- **GIVEN** `anchor_value=100`, `decay_per_hour=3.0`, `elapsed=72000`, **WHEN** called, **THEN** it returns `40.0`. *(`need_value`)*
- **GIVEN** `anchor_value=100`, `decay_per_hour=3.0`, `elapsed_seconds=1800`, **WHEN** called, **THEN** it returns `98.5`. **An implementation using `elapsed_seconds / 3600` truncates to zero decay and must fail this assertion.** *(Implementation notes)*
- **GIVEN** `anchor_value=28`, `recover_per_hour=5.0`, `dark=true`, `elapsed=18000`, **WHEN** called, **THEN** it returns `53.0`. *(`need_value`, dark branch)*
- **GIVEN** a ~5-year elapsed gap, **WHEN** called, **THEN** the result clamps exactly to `floor` with no precision loss or overflow. *(Edge Cases)*
- **GIVEN** a corrupted `anchor_value` of `150` or `-20`, **WHEN** called, **THEN** the returned value is clamped within `[floor, 100]` on every read. *(Edge Cases)*
- **GIVEN** an `anchor_utc` in the future (simulated rollback), **WHEN** called, **THEN** it returns `anchor_value` unchanged. *(Edge Cases)*
- **GIVEN** `floor == sad_threshold`, **WHEN** a need decays through that value, **THEN** it transitions `CONTENT → AT_FLOOR` with no `SAD`-only state observed. *(Edge Cases)*

**`apply_care`**

- **GIVEN** `need_value(now)=28`, `restore_amount=100`, **WHEN** care is applied, **THEN** `anchor_value=100` and `anchor_utc=now`. *(`apply_care`)*
- **GIVEN** `need_value(now)=100`, **WHEN** care is applied, **THEN** the value stays `100` but `anchor_utc` still updates — re-anchoring is unconditional. *(Core Rules 5, 7)*
- **GIVEN** a restore landing below `sad_threshold` (`restore_amount=10`, `value=5`, `threshold=40`), **WHEN** applied, **THEN** the value is `15`, the state stays `SAD`, no `need_cleared` fires, and `need_changed` does. *(States and Transitions)*

**`seconds_until_sad`**

- **GIVEN** `v0 ≤ sad_threshold`, **WHEN** called, **THEN** it returns `0`. *(sentinel contract)*
- **GIVEN** a recovering need (`dark=true`), **WHEN** called, **THEN** it returns `-1`. *(sentinel contract)*
- **GIVEN** `floor > sad_threshold`, **WHEN** called, **THEN** it returns `-1` without ever dividing. *(sentinel contract)*
- **GIVEN** `v0=100`, `sad_threshold=40`, `decay_per_hour=7.0` (exact answer `30857.14…`), **WHEN** called, **THEN** it returns `30858`. **A truncating `int()` returning `30857` must fail this assertion.** *(Implementation notes)*

**`all_needs_addressed`**

- **GIVEN** (a) all four `CONTENT` with `dark=false`, (b) three `CONTENT` with sleep `SAD` and `dark=true`, (c) three `CONTENT` with one non-sleep need `SAD`, **WHEN** evaluated, **THEN** the results are `true`, `true`, `false` respectively — (c) regardless of `dark`. *(`all_needs_addressed`)*

**Urgency ranking**

- **GIVEN** hunger=10 and fun=25 both `SAD`, cleanliness `CONTENT`, sleep `AT_FLOOR`(0), **WHEN** `get_urgency_ranking()` is called, **THEN** it returns `[sleep, hunger, fun]`. *(Core Rule 11)*
- **GIVEN** two sad needs at an identical value, **WHEN** ranked, **THEN** they order by enum index (hunger < cleanliness < fun < sleep). *(Core Rule 11)*
- **GIVEN** no need is `SAD`, **WHEN** called, **THEN** it returns an empty array, never null. *(Edge Cases)*

**State transitions**

- **GIVEN** decay carrying a value to `sad_threshold`, **WHEN** queried at the crossing, **THEN** `value == sad_threshold` reads `SAD`, not `CONTENT`. *(States and Transitions)*
- **GIVEN** decay carrying a value to exactly `floor`, **WHEN** queried, **THEN** the state reads `AT_FLOOR` and ranks first among ties. *(States and Transitions)*
- **GIVEN** a `SAD`/`AT_FLOOR` need, **WHEN** care re-anchors it above `sad_threshold`, **THEN** the state reads `CONTENT` and `need_cleared` fires. *(States and Transitions)*
- **GIVEN** sleep decaying, **WHEN** `set_dark(true, now)` is called, **THEN** sleep re-anchors at its current computed value and thereafter moves at `+recover_per_hour`; the derived state is unchanged at the instant of the flip. *(Core Rules 6, 9)*

**Dark state**

- **GIVEN** sleep already at `100`, **WHEN** `dark` toggles on, **THEN** `anchor_utc` updates but the value stays `100`. *(Core Rule 6)*
- **GIVEN** N rapid alternating `set_dark()` calls, **WHEN** the value is queried after the Nth, **THEN** it is identical to computing directly from the final anchor and rate — no drift with toggle count. *(Edge Cases)*
- **GIVEN** `set_dark()` called with an `at_utc` older than the current `anchor_utc`, **WHEN** applied, **THEN** it is treated as `now`. *(Edge Cases)*

**Scheduled crossings**

- **GIVEN** a need re-anchored with `seconds_until_sad() = 72000`, **WHEN** the fake clock advances to exactly that moment, **THEN** `need_became_sad` fires exactly once. *(Core Rule 14)*
- **GIVEN** a need whose crossing moment passed while the app was suspended, **WHEN** the app resumes, **THEN** `need_became_sad` fires once on resume and the timer is re-armed. *(Core Rule 14)*

**No-cascade guarantee**

- **GIVEN** all four needs simultaneously `AT_FLOOR`, **WHEN** care is applied to each, **THEN** each restores fully with no interaction, ordering dependency or blocked state. *(Core Rule 8)*

**Derived state**

- **GIVEN** an instance constructed only from a persisted anchor pair with no mutation yet, **WHEN** state is queried, **THEN** it returns the value-correct state — proving state is recomputed, never cached. *(Core Rule 10)*

Every clock-dependent criterion uses a `FakeTimeSource`; none depends on real wall-clock time, sleeps, or inter-test ordering. Core Rules 4, 5 and 12 have no dedicated criterion by design: 4 and 5 are proven jointly by the criteria above, and 12 is already enforced project-wide by the existing `clock-discipline` CI job.

*`qa-lead` consulted (Lean mode) — coverage and gate levels validated.*

## Open Questions

**Contract gaps with Pet Definition Data (Approved GDD — not edited from this session):**

- **Q**: `recover_per_hour` is required by Core Rule 9 but has no home in PDD's `NeedProfile` schema, which defines only `decay_per_hour`, `sad_threshold` and `floor`. **Owner**: systems-designer / Pet Definition Data. **Target**: PDD amendment before the Care Actions session.
- **Q**: `CareProfile.restore_amount` for the `lights` action is now dead data — Core Rule 9 makes sleep rate-switched rather than press-restored, so the field has no consumer. Either remove it from the schema or document it as reserved. **Owner**: systems-designer / Pet Definition Data. **Target**: same amendment.
- **Q**: PDD's load-time validation (its Core Rule 12) permits `floor > sad_threshold`, `floor > 100` and `sad_threshold == 100` — each of which silently breaks a need (see Edge Cases). Proposed new checks: `floor < sad_threshold ≤ 100` and `floor ≤ 100`. **Owner**: systems-designer. **Target**: PDD Core Rule 12 amendment, before the first catalog validator is implemented.
- **Q**: PDD's Overview describes current need levels as "runtime state owned by Save & Persistence", while Core Rule 13 here says Need System owns the live anchors and Save serialises them. Wording correction only — no schema impact. **Owner**: Pet Definition Data. **Target**: next touch of that file.

**Undefined downstream interfaces:**

- **Q**: `reanchor_with_cap(max_offline_s)` is named in the Interactions table but has no formula, no Core Rule, and no specified behaviour when elapsed is already under the cap. **Owner**: Offline Time Simulation. **Target**: that GDD's session, once `MAX_OFFLINE` is defined there.
- **Q**: The accessor shape Save & Persistence uses to read and write the anchor set is unspecified (getter/setter names, exposure form). Same class of gap as Time Service's open anchor-timestamp contract. **Owner**: Save & Persistence. **Target**: that GDD's session.

**Cross-GDD corrections owed to other documents:**

- **Q**: Device Frame assumes a cursor position derived from the "most urgent need" but does not define its behaviour when the urgency ranking is **empty** — which is the normal state immediately after a completed care session. **Owner**: Device Frame & Button Input. **Target**: its revision session (it already carries 11 blocking items from the 2026-09-22 review).
- **Q**: `systems-index.md` is missing three dependency edges found while writing this GDD: Device Frame → Need System (soft), LCD Screen Renderer → Need System (hard), and Save & Persistence ↔ Need System (hard, two-way). **Owner**: — . **Target**: next touch of the index.

**Tuning and validation:**

- **Q**: The MVP balance values (`decay_per_hour = 3.0`, `sad_threshold = 40`, `recover_per_hour = 5.0`) are derived arithmetically against a 24-hour check-in target and have never been played. The derived safe band (2.5–4.17 at threshold 40) bounds them, but only playtest can confirm the rhythm feels right rather than merely computing right. **Owner**: design. **Target**: first playtest.
- **Q**: The Player Fantasy claims a returning player feels *relief* rather than guilt. Need System alone cannot deliver that — it depends on the greeting beat owned by Pet Animation & Reactions and on the decay rate landing well. **Owner**: design. **Target**: vertical slice.
