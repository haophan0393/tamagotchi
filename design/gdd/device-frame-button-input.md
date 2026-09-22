# Device Frame & Button Input

> **Status**: In Design
> **Author**: Hao Phan + Claude (solo review mode)
> **Last Updated**: 2026-09-22
> **Implements Pillar**: 1 (The Device Is Real), 5 (Simple Core, Infinite Shells)

## Overview

Device Frame & Button Input is the device itself: the three round buttons, the shell and bezel that hold them, the safe-area layout that positions them on any phone, and the sensory feedback that fires on every press. It owns the navigation state machine that every other system reaches the player through, and it is the **only system that accepts player input** — nothing else in the game reads touch. Without it there is no way to play: every care action, every menu, every confirmation is routed through its three buttons. It exists to make Pillar 1 literal — the phone is not showing a UI, it is showing a gadget.

## Player Fantasy

Direct, and the most direct in the game — this is the system the player physically touches.

The player should feel they are holding a real toy. A button depresses under the thumb, clicks, and answers. The target is the exact moment recorded in `prototypes/device-button-feel-concept/REPORT.md`: pressing the buttons again just to feel them, before there is any reason to. If the device is satisfying to poke while idle, the fantasy is working.

*(Thin by design — reduced-depth pass per the compressed path. `creative-director` not consulted — Solo mode. Review manually before production.)*

## Detailed Rules

### Core Rules

1. **Three buttons, fixed for the life of the project.** Left **A**, centre **B**, right **C**. No fourth input, no gesture, no swipe, no long-press, no multi-touch chord. (Pillar 5 — a fourth input is grounds for rejecting a feature, not for extending this system.)

2. **Button meaning is per-state, and every state publishes all three meanings.** A button is never silently inert: a state that has no use for a button must declare it explicitly as `—` and still play the "nothing here" feedback (press visual + muted tick, no haptic). A dead-feeling button reads as a broken device.

3. **Default (non-modal) mapping is a ring**: **A** = next item, **C** = previous item, **B** = select. The menu ring holds exactly **three** items — feed, clean, play — which is what makes the concept's ≤3-press budget achievable (see Formulas).

4. **Lights on/off is not a menu item.** It is a contextual toggle surfaced only while the sleep need is active, occupying the **B** slot from `IDLE` when the pet is sleepy. It is a state change to the device, not a care action performed on the pet.

5. **Presses register on press-down, not release.** Verified as the source of the synced feel in `prototypes/device-button-feel-concept/`. Release drives only the spring-back animation and never triggers game logic.

6. **One press at a time.** While any button is held, other button presses are discarded — not queued. Simultaneous presses resolve to whichever arrived first; a tie resolves in the order A, then B, then C.

7. **Every accepted press fires the feedback triad on the same frame**: press visual, audio, haptic. Never staggered, never awaited. This is the prototype's confirmed finding and the mechanism behind Pillar 1.

8. **The visual channel must carry the press alone.** Audio and haptics are amplifiers. With both disabled the device must remain fully playable and legible — a hard acceptance criterion, not an aspiration, because the stated use context (morning, bedtime) is the most mute-prone there is.

9. **Device Frame owns the feedback flags** (`sfx_enabled`, `haptics_enabled`). Settings writes them one-way and never reads back. This ownership direction is what resolves the only dependency cycle in the systems index — do not invert it.

10. **Haptics degrade silently.** If `vibrate_handheld` is unavailable, or the platform ignores `amplitude`, the press is still complete. No error, no fallback buzz, no user-visible message.

11. **Input is locked during a reaction.** From press-accept until the reaction animation completes, all presses are discarded (not queued). This keeps a mashed button from stacking four feed actions, without ever showing a "too fast" message.

12. **The LCD rect snaps to an integer multiple** of the LCD resolution; the remainder is absorbed by the shell, never by scaling the panel. (From `prototypes/lcd-rendering-spike/REPORT.md` — non-integer scale makes the pixel grid shimmer.)

13. **All three buttons and the LCD live inside the safe area** reported by `DisplayServer.get_display_safe_area()`. The shell may bleed outside it; nothing interactive or informational may.

### States and Transitions

| State | A | B | C | Notes |
|---|---|---|---|---|
| `BOOT` | — | — | — | Input ignored until the first frame is rendered |
| `IDLE` | open menu, cursor on most urgent need | lights toggle *(only while sleepy)*, else — | — | Pet and need icons visible |
| `MENU` | next item | select item | previous item | Ring of 3; wraps in both directions |
| `ACTING` | — | — | — | All input discarded until the reaction ends |
| `CONFIRM` | — | confirm | cancel | **Modal. Ring suspended.** The only state where C means cancel |

| Transition | Trigger |
|---|---|
| `BOOT → IDLE` | First frame rendered |
| `IDLE → MENU` | A pressed |
| `MENU → ACTING` | B pressed (item selected) |
| `MENU → IDLE` | Menu idle timeout elapses (see Tuning Knobs) |
| `ACTING → IDLE` | Reaction animation completes |
| `IDLE → CONFIRM` | Life Stage & Growth calls `request_confirm()` |
| `CONFIRM → ACTING` | B pressed (confirmed) |
| `CONFIRM → IDLE` | C pressed (cancelled) |

### Interactions with Other Systems

| System | Data In | Data Out | Owns the interface |
|---|---|---|---|
| Need System | active needs + urgency ranking | — | Need System |
| Care Actions | — | `action_selected(action_id)` | **Device Frame** |
| LCD Screen Renderer | — | `state`, `cursor_index`, `menu_items[]` | **Device Frame** |
| Life Stage & Growth | `request_confirm(prompt_id)` | `confirm_result(bool)` | Life Stage & Growth |
| Settings | `sfx_enabled`, `haptics_enabled` (write-only) | — | **Device Frame** |
| Device Shells | active shell skin | — | Device Shells |

*Specialist agents (`game-designer`, `ux-designer`, `gameplay-programmer`) not consulted — Solo mode. Review manually before production.*

## Formulas

The `ring_distance` formula is defined as:

`ring_distance = min((to - from) mod n, (from - to) mod n)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| from | f | int | 0 … n−1 | Cursor's current ring index |
| to | t | int | 0 … n−1 | Target item's ring index |
| n | n | int | 3 (fixed, MVP) | Ring size |

**Output Range:** 0 to ⌊n/2⌋. For n=3 the only possible values are 0 and 1.
**Example:** `from = 0`, `to = 2`, `n = 3` → `min(2 mod 3, 1 mod 3)` = `min(2, 1)` = **1** — one C press (backwards), not two A presses.

---

The `press_cost` formula is defined as:

`press_cost = 1 + ring_distance + 1` (open + traverse + select), i.e. `ring_distance + 2`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| ring_distance | d | int | 0 … ⌊n/2⌋ | Output of `ring_distance` above |

**Output Range:** 2 to ⌊n/2⌋+2. For n=3 → **2 or 3. Never 4.**
**Example:** cursor on FEED, target PLAY → `d = 1` → `press_cost = 3` (A to open, C to step back, B to select).

> **This is a constraint, not a tuning knob: `n ≤ 3`.** At n=4 `press_cost` reaches 4 and the concept-level ≤3-press budget breaks. Adding a fourth ring item is a change to `game-concept.md`, not a balance decision. See Open Questions.

---

The `lcd_scale` formula is defined as:

`lcd_scale = max(1, floor(min(avail_w / LCD_W, avail_h / LCD_H)))`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| avail_w | — | int (px) | > 0 | Bezel interior width, already inset for safe area |
| avail_h | — | int (px) | > 0 | Bezel interior height, already inset for safe area |
| LCD_W | — | int (px) | 64 (provisional) | LCD panel resolution, width |
| LCD_H | — | int (px) | 64 (provisional) | LCD panel resolution, height |

**Output Range:** integer ≥ 1. The `floor` is the entire point — a fractional scale makes the pixel grid shimmer and beat against the pixel art (verified in `prototypes/lcd-rendering-spike/REPORT.md`). The remainder `avail − LCD × lcd_scale` is absorbed as shell padding and centred.
**Example:** `avail = 400 × 420`, `LCD = 64 × 64` → `min(6.25, 6.56)` → `floor` → **6** → panel renders at 384 × 384; 16 px and 36 px are absorbed by the shell.
**Behavior at extremes:** on a screen too small for scale 1, `max(1, …)` clamps and the panel is allowed to overflow the bezel rather than render at sub-pixel scale. A device that cannot fit a 1× panel is below the support floor — an explicit, visible failure rather than a silent shimmer.

---

**Feedback timings** — measured in `prototypes/device-button-feel-concept/` and confirmed as reading synced on desktop.

| Channel | Value | Notes |
|---|---|---|
| Press visual | 40 ms; +10 px down, scale 0.94 | via `Control.offset_transform_*` with `visual_only = true` |
| Release visual | 160 ms, `TRANS_BACK` / `EASE_OUT` | overshoot spring-back |
| Audio | 70 ms square wave, linear decay | 660 / 880 / 1100 Hz for A / B / C |
| Haptic | `Input.vibrate_handheld(15, 0.8)` | `amplitude` may be ignored per platform — see Edge Cases |

*`systems-designer` not consulted — Solo mode. Review manually before production.*

## Edge Cases

- **If a press arrives while another button is held**: discard it. No queue, no buffer — the second press never fires.
- **If two presses land on the same frame**: resolve in the fixed order A, then B, then C. Deterministic by construction, so it is unit-testable.
- **If a press arrives during `ACTING`**: discard it. The reaction animation plays to completion and no "too fast" message is ever shown (Pillar 2 — never scold).
- **If `Input.vibrate_handheld` is unavailable, or the platform ignores `amplitude`**: the press still completes on the visual and audio channels. No error, no fallback buzz, no user-visible message.
- **If both `sfx_enabled` and `haptics_enabled` are false**: the device remains fully playable and fully legible. This is the mute-context default, not a degraded mode, and it is covered by a blocking acceptance criterion.
- **If the safe area changes mid-session** (rotation, split-screen, a foldable unfolding): re-run layout on the next frame. Never re-layout mid-press — a button must not move out from under a finger that is already down.
- **If the safe area is smaller than the shell requires**: shrink the shell first, then the bezel, and only then reduce `lcd_scale` by 1. The LCD is the last element to shrink, because legibility of the pet is the whole product.
- **If `lcd_scale` would evaluate to 0**: clamp to 1 and allow the panel to overflow the bezel. The device is below the support floor; this fails loudly rather than rendering a shimmering sub-pixel grid.
- **If the sleep need clears while the menu is open**: the menu ring is unaffected, because lights was never a ring item. B's `IDLE` meaning reverts on the next return to `IDLE`.
- **If `request_confirm()` arrives while in `MENU` or `ACTING`**: queue it and enter `CONFIRM` on the next return to `IDLE`. A graduation prompt must never interrupt a care action mid-reaction.
- **If the app is backgrounded mid-press**: treat it as a release with no action fired. The press does not resolve on resume.

*`systems-designer` not consulted — Solo mode. Review manually before production.*

## Dependencies

**Upstream (what Device Frame depends on):** None. Like Time Service, this is a Foundation-layer system with no dependencies on other game systems — by design, since it must be buildable first and every other system routes through it.

**Downstream (what depends on Device Frame):**

| Depends on Device Frame | Dependency Type | Interface Used |
|---|---|---|
| LCD Screen Renderer | Hard | `state`, `cursor_index`, `menu_items[]` |
| Care Actions | Hard | `action_selected(action_id)` |
| Hatching Onboarding | Hard | full button/state machine |
| Settings | Hard | writes `sfx_enabled`, `haptics_enabled` (one-way) |
| Device Shells | Hard | supplies the active shell skin |
| Life Stage & Growth | Soft (two-way) | `request_confirm()` / `confirm_result()` — Growth functions without a confirm prompt |

This matches the systems index, with one correction: the index lists Device Frame as depending on nothing, and lists Life Stage & Growth as unrelated to it. The `request_confirm` channel is a real soft edge that the index does not record — flagged in Open Questions.

## Tuning Knobs

| Knob | Default | Too low | Too high |
|---|---|---|---|
| `menu_idle_timeout` | 8 s | Menu closes mid-decision; feels twitchy | Player is stranded in a menu they forgot about |
| `press_visual_ms` | 40 ms | Press reads as instant/unfelt | Press feels laggy, breaks triad sync |
| `release_visual_ms` | 160 ms | Spring-back feels stiff | Button feels rubbery, blocks rapid input |
| `haptic_ms` | 15 ms | Below perceptual threshold | Reads as a buzz, not a click |
| `haptic_amplitude` | 0.8 | Unnoticed | Harsh; may be ignored per platform anyway |
| `beep_hz` (per button) | 660 / 880 / 1100 | Buttons become indistinguishable by ear | Shrill; fights the cozy register |

**Explicitly not knobs:**
- **Ring size `n`** — a constraint, not a knob. `n > 3` breaks the ≤3-press budget. See Formulas.
- **Button count** — a pillar (Pillar 5). Changing it is a concept-level decision.
- **`lcd_scale`** — derived, never authored. Setting it by hand reintroduces fractional scale.

## Visual/Audio Requirements

**Visual.** The shell, bezel and buttons are the **smooth layer** — vector/painted, soft highlights, rounded forms, saturated candy colour. Nothing in this system is pixel art; the two-layer rule (`game-concept.md`) says nothing straddles both layers, and the LCD contents belong to LCD Screen Renderer, not here. Press animation uses `Control.offset_transform_*` with `visual_only = true`, so the button moves without disturbing layout or hit targets. Every button has a visible rest state, press state, and spring-back.

**Audio.** Piezo-style square wave, deliberately cheap and toy-like — the reference is a tiny 90s speaker, not a modern UI click. **A distinct pitch per button** (660 / 880 / 1100 Hz) so the device is identifiable by ear alone. Audio is an amplifier, never a carrier: see the sound-off blocking criterion.

**Sync.** All three channels fire on the same frame as the press. This is the confirmed mechanism behind the prototype's PROCEED verdict.

*`art-director` and `audio-director` not consulted — Solo mode. Review manually before production.*

## UI Requirements

The device frame **is** the UI. There is no overlay, no modern chrome, no HUD outside the LCD — a full-screen UI layer over the device is an explicit anti-pillar (`game-concept.md`: "NOT a full-screen touch-the-pet sim").

- Three round buttons, minimum **48 dp** touch target each, regardless of rendered size.
- All interactive and informational elements inside `DisplayServer.get_display_safe_area()`; only decorative shell may bleed outside it.
- The LCD rect is positioned by `lcd_scale` (see Formulas) and centred in the bezel; the remainder is shell padding.
- No hover states — touch only, per `technical-preferences.md`.
- Layout recomputes on safe-area change, but never mid-press.

*`ux-designer` not consulted — Solo mode. Review manually before production.*

## Acceptance Criteria

- **GIVEN** the app is running, **WHEN** any input other than a tap on one of the three buttons occurs (swipe, long-press, second finger, gesture), **THEN** no game state changes. *(Core Rule 1)*
- **GIVEN** any state, **WHEN** that state is queried for its button map, **THEN** it returns a meaning for all three buttons, with unused buttons explicitly marked `—`. *(Core Rule 2)*
- **GIVEN** a 3-item ring and a cursor at any index, **WHEN** `press_cost` is computed for every item, **THEN** every result is ≤ 3. **BLOCKING** *(Core Rule 3, `press_cost`)*
- **GIVEN** `from = 0`, `to = 2`, `n = 3`, **WHEN** `ring_distance` is computed, **THEN** it returns 1, not 2. *(`ring_distance`)*
- **GIVEN** state `IDLE` and the sleep need active, **WHEN** B is pressed, **THEN** the lights toggle and no care action fires. *(Core Rule 4)*
- **GIVEN** a button, **WHEN** it is pressed and held without release, **THEN** the action fires on press-down, not on release. *(Core Rule 5)*
- **GIVEN** button A is held down, **WHEN** button B is pressed, **THEN** B is discarded and does not fire when A is released. *(Core Rule 6)*
- **GIVEN** an accepted press, **WHEN** the frame is inspected, **THEN** the visual, audio and haptic channels were all triggered on that same frame. *(Core Rule 7)*
- **GIVEN** `sfx_enabled = false` and `haptics_enabled = false`, **WHEN** a full care loop is played from open to need-cleared, **THEN** every state, cursor position and action outcome is determinable from the screen alone. **BLOCKING** *(Core Rule 8)*
- **GIVEN** Settings writes `sfx_enabled`, **WHEN** Device Frame's flag is inspected, **THEN** it matches the written value, and Settings never reads the flag back. *(Core Rule 9)*
- **GIVEN** a platform where `Input.vibrate_handheld` is a no-op, **WHEN** a button is pressed, **THEN** the press completes with no error and no user-visible message. *(Core Rule 10)*
- **GIVEN** state `ACTING`, **WHEN** any button is pressed, **THEN** the press is discarded, no action is queued, and no message is shown. *(Core Rule 11)*
- **GIVEN** a bezel interior of 400 × 420 px and an LCD of 64 × 64, **WHEN** `lcd_scale` is computed, **THEN** it returns exactly 6 and the panel renders at 384 × 384. *(`lcd_scale`)*
- **GIVEN** a device with a display notch, **WHEN** layout completes, **THEN** all three buttons and the full LCD rect lie inside `DisplayServer.get_display_safe_area()`. *(Core Rule 13)*
- **GIVEN** state `CONFIRM`, **WHEN** C is pressed, **THEN** the action is cancelled — this is the only state in which C does not mean "previous item". *(States and Transitions)*
- **GIVEN** state `ACTING`, **WHEN** `request_confirm()` arrives, **THEN** `CONFIRM` is entered only after the reaction animation completes. *(Edge Cases)*

*`qa-lead` not consulted — Solo mode. Review manually before production.*

## Open Questions

**Blocking-ish — resolve before or during implementation:**

- **Q**: Haptics have never run on a real phone. `Input.vibrate_handheld(duration_ms, amplitude)` is signature-verified against 4.7.1, but per-platform `amplitude` support is unknown and the whole triad-sync feel is unvalidated on glass. This is the riskiest assumption in the system and it underpins Pillar 1. **Owner**: engineering. **Target**: on-device spike before the Vertical Slice tier. Fallback already designed in (Core Rule 10 — silent degradation), so this cannot block MVP, only weaken it.
- **Q**: **This GDD reclassifies "lights on/off" from a care action to a contextual device toggle** (Core Rule 4), so that the menu ring can hold exactly 3 items and satisfy the ≤3-press budget. `game-concept.md` line 75 lists four care actions including lights. Either the concept is updated to match, or Care Actions must accept lights as a non-menu toggle. **Owner**: game-designer / creative-director. **Target**: the Care Actions design session — do not let it drift.
- **Q**: The ring is pinned at `n ≤ 3` by arithmetic, not preference (see Formulas). Any future feature wanting a fourth menu item breaks a concept-level constraint. **Owner**: creative-director. **Target**: standing constraint; re-check at every scope addition.

**Provisional assumptions about undesigned dependencies:**

- **Q**: `LCD_W` / `LCD_H` are assumed 64 × 64 (the value the LCD spike used). LCD Screen Renderer owns the real value. If it differs, `lcd_scale` examples in Formulas need recomputing — the formula itself is unaffected. **Owner**: LCD Screen Renderer. **Target**: that GDD's session.
- **Q**: This GDD assumes Need System exposes an **urgency ranking** over active needs, used to place the menu cursor on open. Need System does not exist yet and may not rank. **Owner**: Need System. **Target**: that GDD's session.
- **Q**: Care Actions owns the Play mini-game, whose input model is unresolved. If it needs anything beyond the three buttons in `ACTING`, it collides with Core Rule 1. **Owner**: Care Actions. **Target**: that GDD's session.

**Corrections to other documents:**

- **Q**: The systems index lists Device Frame as depending on nothing and records no edge to Life Stage & Growth. The `request_confirm()` / `confirm_result()` channel is a real soft two-way edge. **Owner**: — . **Target**: fix on the next touch of `systems-index.md`.

**Tuning and polish:**

- **Q**: `menu_idle_timeout = 8 s` is an unvalidated guess, as are all feedback timings beyond those the prototype measured. **Owner**: design. **Target**: first playtest.
- **Q**: The 48 dp minimum touch target may exceed the shell's visually appropriate button size on small screens, forcing hit areas larger than the drawn buttons. Acceptable (invisible), but must be verified on a small device. **Owner**: UX / engineering. **Target**: on-device layout pass.
- **Q**: MVP ships SFX-only with no ambient bed — a conscious choice flagged in `game-concept.md`'s pillar tensions (Sensation vs. Submission). **Owner**: audio-director. **Target**: revisit at Vertical Slice.
