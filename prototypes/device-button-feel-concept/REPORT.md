# Concept Prototype Report: device-button-feel

> **Date**: 2026-09-18
> **Prototype Path**: Engine (Godot 4.7.1, GDScript)
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

"If the player taps the three round device buttons, each press will feel tactile and
satisfying — we will know this is true if a first-time tester presses a button
repeatedly/playfully without being asked to, within the first 30 seconds."

---

## Riskiest Assumption Tested

**Haptic + audio + visual sync** — that the press-down animation, haptic pulse, and
beep would read as one unified "click" rather than three loosely-related events.

**Proved out on desktop for two of the three channels:** the press-down visual and
the beep fire on the same frame from `button_down` and were reported as feeling
synced. **Haptic remains untested** — the desktop build has no vibration, and the
phone deploy was deferred this round. This is the single open risk carried forward.

---

## Approach

Three round `Button` controls on a plain shell-colored background, built entirely
in code with no art or audio assets. Built and playable in a single session
(~1 hour including API verification against the installed 4.7.1 class reference).

**Path chosen:** Engine
**Reason for path:** Button feel is timing-sensitive; browser rendering variance
(50–133 ms) would have produced false results, and haptics are not testable in HTML.

**What fires on press (`button_down`, same frame):**
- `Input.vibrate_handheld(15, 0.8)` — haptic pulse (no-op on desktop)
- Synthesized square-wave beep (70 ms, linear decay; 660 / 880 / 1100 Hz per button)
- `offset_transform_position` → +10 px down onto a darker shadow disc,
  `offset_transform_scale` → 0.94, over 40 ms

**On release (`button_up`):** spring back to rest over 160 ms with
`TRANS_BACK` / `EASE_OUT` overshoot.

**Shortcuts taken (intentional):**
- No device shell art — flat `ColorRect` in candy pink; buttons are `StyleBoxFlat` circles
- No LCD, pet, menu logic, needs, life stages, save data, or offline simulation
- All tuning values hardcoded as constants at the top of `main.gd`
- Beeps generated in code as `AudioStreamWAV` PCM — zero imported assets
- Buttons labelled A / B / C rather than menu / select / cancel semantics
- Single-pointer only (mouse-emulated touch); simultaneous two-button presses not supported
- No error handling; nodes built procedurally in `_ready()` to avoid hand-editing `.tscn`

**4.7-specific APIs verified before use** (via `godot --doctool` on the installed build):
`Input.vibrate_handheld(duration_ms: int = 500, amplitude: float = -1.0)`;
`Control.offset_transform_{enabled, position, scale, pivot_ratio, visual_only}`.

---

## Result

- Headless and windowed launches ran with no script errors on the first attempt
  (0 fix iterations needed).
- Developer report after desktop play: "runs fine on desktop, press and beep feel synced."
- Player-mode play (developer, solo): hypothesis **CONFIRMED** — presses were
  repeated playfully within the first 30 seconds without prompting.
- Worst moment: **nothing notable** — no friction recorded on spring-back timing,
  beep tone, or button size/placement.
- No external testers this round.

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | Engine (Godot 4.7.1) |
| Iterations to playable | 1 (first run was playable) |
| Prototype duration | ~1 hour |
| Playtesters | 1 internal (developer) / 0 external |
| Feel assessment | Press-down (40 ms in) + beep (same frame) read as one click on desktop; 160 ms `TRANS_BACK` release not flagged as floaty or abrupt. Haptic channel untested. |
| Hypothesis verdict | CONFIRMED (desktop; haptic pending) |

---

## Recommendation: PROCEED

The core interaction the whole game routes through — pressing a skeuomorphic round
button — invited playful repeat presses on first contact with only placeholder
visuals and a synthesized beep, and produced no friction worth recording. That is
strong signal for Pillar 1 (Sensation) with almost nothing spent. The one unproven
channel is haptics, which cannot be evaluated off-device; it does not block design
work but must be closed on a real phone before the Device Frame & Button Input GDD
is finalised, and before any architecture decision that depends on `vibrate_handheld`
amplitude behaviour on iOS vs Android.

---

## If Proceeding

- **Core tuning values discovered (starting points for the GDD Tuning Knobs section):**
  press depth 10 px, press scale 0.94, press-in 40 ms, release 160 ms with
  `TRANS_BACK`/`EASE_OUT`; beep 70 ms square wave with linear decay at 660/880/1100 Hz,
  volume 0.35; haptic 15 ms @ 0.8 amplitude (unvalidated).
- **Assumptions confirmed:** a flat touchscreen tap can read as a satisfying click
  when visual and audio fire on the same frame; a distinct pitch per button is enough
  to make the three buttons feel like separate physical keys.
- **Assumptions disproved:** none this round.
- **Emergent mechanics:** none — scope was deliberately a single mechanic.
- **Open risk to close on device:** haptic timing relative to the visual/beep, and
  whether the `amplitude` argument is honoured on iOS and Android.
- **Design notes for the GDD:** `Control.offset_transform_*` (visual-only) is the
  right tool for press animation — layout is untouched, so it composes cleanly with
  safe-area margins later. Synthesized chip beeps are viable as a placeholder audio
  direction and may even be the final aesthetic.

**Next steps:**
1. `/design-review design/gdd/game-concept.md`
2. `/gate-check`
3. `/art-bible` (Candy Gadget anchor — optional but planned)
4. `/map-systems`
5. `/design-system device-frame-button-input` (seed Tuning Knobs from the values above)

---

## If Pivoting

N/A — verdict is PROCEED.

---

## If Killing

N/A — verdict is PROCEED.

---

## Lessons Learned

- **What assumptions were broken by actually building this?**
  None on the interaction itself. Procedurally-built scenes plus code-generated
  audio made the Engine path as fast as an HTML build would have been — the
  "50–60% one-shot" expectation for Engine prototypes was beaten (1 iteration).

- **What surprised us that didn't show up in the brainstorm?**
  Dumping the installed engine's class reference (`godot --doctool`) resolved the
  two post-cutoff API questions in seconds — cheaper and more authoritative than a
  web search for this pinned version. Worth making the default move for any 4.4+ API.

- **What would we test differently next time?**
  Deploy to a phone in the same session. Haptics were the stated riskiest assumption
  and the round ended without testing them — the prototype answered the question it
  *could* answer on desktop, not the one it was designed for. Also recruit at least
  one non-developer tester; a solo developer cannot give clean first-impression data.

---

> *Prototype code location: `prototypes/device-button-feel-concept/`*
> *This code is throwaway. Never refactor into production.*
