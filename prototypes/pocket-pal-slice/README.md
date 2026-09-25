# Pocket Pal — quick slice

> VERTICAL SLICE, NOT FOR PRODUCTION. Throwaway. Never import into `src/`.

**Status**: in progress (built 2026-09-25, awaiting playtest)

## What it tests

*Does the 30-second loop make the pet feel alive and glad to see me, and can a
new player learn the 3-button ring with no text?*

The loop: open → Bloop wakes and greets you → need icons show along the top →
**A** (left, yellow) opens the menu → **A** / **C** cycle feed · clean · play →
**B** (centre, blue) selects → reaction + beep + haptic → the icon flashes and
clears → with every need content, Bloop does its happy idle and a heart appears
("done for today"). While Bloop is sleepy, a moon sits in the centre slot and
**B** turns the lights off for a moment.

Play is a left/right guess: will Bloop look left (**A**) or right (**C**)? It
runs 3 rounds and has no fail state. Fun restores whatever the result.

## How to run

```sh
godot --path prototypes/pocket-pal-slice          # play it
godot -e --path prototypes/pocket-pal-slice       # or open in the editor, press F5
```

Click or tap the round buttons. Desktop keys: `1` `2` `3` (or ← ↓ →) = A B C ·
`F` = +6 game hours · `R` = restart · `D` = debug readout (need values, state).

Automated smoke run with screenshots (not a playtest):
`godot --path prototypes/pocket-pal-slice --script drive.gd -- <out_dir>`

## What is in and what was cut

- **In**: shell + 3 buttons (press feel from `device-button-feel-concept`), a
  64×64 SubViewport LCD with the pixel-grid shader (verdict of
  `lcd-rendering-spike`), 4 needs using the Need System anchor formula, the
  Device Frame state table (IDLE / MENU / ACTING, contextual lights on B,
  8 s menu timeout, one press at a time, input locked during reactions),
  and a pulsing hint on the button that would help after 4 s of no presses.
- **Cheats for testing**: needs start already sad (hunger, cleanliness, sleep),
  the clock runs at 120× (one real minute = two game hours), and fun goes sad
  ~5 real minutes in.
- **Cut**: save, offline catch-up, growth/life stages, settings, shells,
  safe-area layout, phone export.

All tuning values are in `slice_config.gd`.

## Files

| File | Role |
|---|---|
| `device.gd` | Shell, buttons, state machine, reaction sequences |
| `lcd_screen.gd` | Draws the LCD contents (pure renderer) |
| `pet_art.gd` | Procedural Bloop + icon/prop sprites |
| `slice_needs.gd` | Need model (anchor + decay formula) |
| `slice_clock.gd` | Accelerated clock |
| `sfx.gd` | Synthesized chip sounds |
| `slice_config.gd` | Every tunable value |
| `drive.gd` | Scripted smoke run + screenshots |

## Findings

*Pending the playtest. See REPORT.md once written.*
