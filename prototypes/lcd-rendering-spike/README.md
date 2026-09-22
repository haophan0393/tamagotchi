# Prototype: lcd-rendering-spike

**Status**: concluded (2026-09-22)
**Verdict**: **Approach A — SubViewport + pixel-grid shader**
**Feeds**: ADR (a) LCD rendering approach; LCD Screen Renderer GDD (system 7)

## Hypothesis under test

The concept requires a boxy LCD showing a ~32×32 pixel pet with a **visible pixel
grid** and a faint flicker, at 60 fps under 50 draw calls on a low-end Android
phone. Two candidate approaches were named in `design/gdd/game-concept.md` and
`docs/engine-reference/godot/modules/rendering.md` but never validated:

- **A** — SubViewport at LCD resolution → `SubViewportContainer`, `NEAREST`
  filtering, pixel-grid overlay shader.
- **B** — Godot 4.7's new `DrawableTexture2D` as the LCD surface.

A third was added during the spike because it is the obvious cheap option and
needed ruling in or out explicitly:

- **C** — no intermediate texture at all; sprites drawn straight onto the panel
  at integer scale, shader on the containing `Control`.

## How to run

```bash
cd prototypes/lcd-rendering-spike
godot                                  # interactive: 1/2/3 switch, N toggle needs, S screenshot
godot --script capture.gd -- res://captures        # capture all three
godot --script capture.gd -- res://captures 1      # measure approach B alone
godot --script capture.gd -- res://captures 1 stress   # B, repainting every frame
```

Each approach is measured in its own process so shader warmup from one cannot be
charged to another. Screenshots land in `captures/`.

Art is generated procedurally in `lcd_art.gd` — no binary assets to commit, and
the 6-colour LCD palette constraint stays visible in code.

## Findings

See `REPORT.md` for the full write-up and the verdict rationale.
