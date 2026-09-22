# LCD Rendering Spike — Report

**Date**: 2026-09-22
**Engine**: Godot 4.7.1 (stable, official `a13da4feb`), Mobile renderer
**Measured on**: macOS (Apple Silicon), desktop. **Not** the low-end Android target.
**Verdict**: **PROCEED with Approach A — SubViewport + pixel-grid shader**

---

## Verdict

Use a **SubViewport at LCD resolution inside a `SubViewportContainer` with
`stretch_shrink` set to the integer scale factor**, with the pixel-grid shader as
the container's material.

Performance did not decide this. Capability did.

---

## The measurements, and why they did not decide it

Each approach measured in its own process, vsync disabled, 240 frames after a
90-frame settle. Two runs:

| Approach | Frame time | FPS | Peak draw calls | Pixel grid? |
|---|---|---|---|---|
| A — SubViewport | 4.17 / 4.06 ms | 240 / 246 | 11 | **yes** |
| B — DrawableTexture2D | 3.37 / 4.17 ms | 297 / 240 | 6 | **yes** |
| C — Direct sprites | 3.02 / 2.91 ms | 331 / 343 | 10 | **no** |

**A and B are within run-to-run noise of each other.** B's faster first run did
not reproduce. Reading a winner out of these two columns would be reading noise.
All three sit far under the 50-draw-call budget and far above 60 fps.

B was also stressed by forcing a full panel repaint **every frame** rather than
only on state change — its realistic worst case once Pet Animation & Reactions
drives a per-frame animation. Cost was unmeasurable (271 / 240 fps, same range as
baseline). B is not performance-limited either.

> **Caveat that matters**: these are desktop numbers. Nothing here has run on the
> low-end Android target. What they establish is that no approach is *obviously*
> too expensive — not that any is fast enough on device. The Device Frame GDD's
> on-device pass should re-check the winner, especially the SubViewport's extra
> render target on a tile-based mobile GPU, where offscreen targets are more
> costly than on desktop.

---

## The finding that actually decided it

### `DrawableTexture2D` has no drawing API

This is the headline. `DrawableTexture2D` is a **blit target, not a canvas**. Its
entire surface is:

```
setup(width, height, format, color, use_mipmaps)
blit_rect(rect, source: Texture2D, modulate, mipmap, material)
blit_rect_multi(rect, sources, extra_targets, modulate, mipmap, material)
generate_mipmaps()  set_format()  set_use_mipmaps()  get_use_mipmaps()
```

There is **no `draw_line`, `draw_circle`, `draw_rect`, `draw_string`, or any
other `draw_*` call.** (`Texture2D` contributes `draw`/`draw_rect`/
`draw_rect_region`, but those draw the texture *onto* a CanvasItem — they do not
draw *into* it.) Everything composited into a `DrawableTexture2D` must already
exist as a `Texture2D`. There is not even a fill: the spike clears the panel by
blitting a 1×1 texture stretched over it.

**This contradicts our own engine reference**, which said Option B was viable "if
all pet/UI drawing is done via `draw_*` calls rather than a scene tree" — the
exact thing `DrawableTexture2D` cannot do. `docs/engine-reference/godot/modules/rendering.md`
and `deprecated-apis.md` have been corrected.

### Why that disqualifies B for this game

LCD Screen Renderer (system 7) owns the **HUD and menu icons — need icons, the
menu cursor, and the "done for today" signal** — and Pet Animation & Reactions
(system 10) is a whole MVP system built on top of it. Under B:

- No `AnimatedSprite2D`. Frame animation becomes manual index bookkeeping.
- No `Tween` on anything inside the panel. The project specifically wants 4.7's
  `Tween.tween_await(signal)` for the pet-reaction → beep → need-clear sequence.
- No `Label` or `Control` layout. Menu text needs a bitmap font blitted glyph by
  glyph, hand-kerned.
- Manual dirty-tracking and repaint ordering, all of it ours to maintain.

Under A, all of it is just nodes.

### B's remaining virtue

B uses the fewest draw calls (6 vs 11) and needs no render target. If the LCD
were a **static** composite, B would be the cleaner choice. It is not static, so
this does not apply. Worth revisiting only if the render target turns out to be a
real cost on the Android target.

### `DrawableFormat` is not `Image.Format`

`setup()` takes `DrawableTexture2D.DrawableFormat`
(`DRAWABLE_FORMAT_RGBA8`, `_RGBA8_SRGB`, `_RGBAH`, `_RGBAF`), **not**
`Image.Format`. Passing `Image.FORMAT_RGBA8` is a hard parse error. Cheap to hit,
cheap to fix, but it is the second API surprise in an API this small — a fair
signal of how much 4.7-specific ground is untrodden.

---

## Approach C is eliminated on capability, not cost

C was the fastest and the simplest, and it **produced no pixel grid at all** —
see `captures/lcd_c.png` against `lcd_a.png`.

The material was on the containing `Control`, identical to A and B. But a
`Control`'s material applies to that node's *own* drawing; its children are
independent `CanvasItem`s that render with their own materials. The shader never
touched the sprites.

**The general rule this establishes: the pixel-grid shader requires the LCD
contents to be flattened into a single texture first.** A gets that from the
SubViewport; B gets it from the drawable texture. The remedy for C is a
`CanvasGroup`, which flattens children into one buffer — but that reintroduces
exactly the offscreen buffer C was meant to avoid, converging back to A with
fewer guarantees. Not worth pursuing.

This is the kind of thing that only shows up by looking at output. The frame
times were excellent and nothing errored.

---

## Constraint this hands to the Device Frame GDD

**The LCD's on-screen rectangle must be an exact integer multiple of the LCD
resolution.** The spike uses 64×64 at ×6 = 384×384. Non-integer scale makes the
pixel grid shimmer and beat against the pixel art — the exact "cheap emulator"
look the concept's two-layer rule is trying to avoid.

This collides with safe-area-aware layout on notched phones and with 4.7's new
`expand` stretch default across tall and short aspect ratios. **The device frame
cannot simply scale the LCD to fit available space.** It must snap the panel to
the largest integer multiple that fits and absorb the remainder in the shell.

Flagging this now because it constrains the Device Frame GDD, which is the next
document to be authored.

---

## What was not tested

- **On-device performance.** Desktop only. The SubViewport's render target is the
  specific risk on a tile-based mobile GPU.
- **Battery cost** of a continuously-updating render target during a 1–3 minute
  session.
- **The flicker's actual feel.** The shader's flicker is `0.025` depth by two
  detuned sines; whether that reads as "a warm LCD" or as "a broken screen"
  is a judgement call that needs eyes on a real phone, not a screenshot.
- **Text rendering inside the panel.** The menu cursor and "done for today"
  signal are specified but were not built — A makes them trivial, which is part
  of why A won, but that was reasoned rather than demonstrated.

## Recommendation for the ADR

Adopt A. Record B's elimination on the `draw_*` finding specifically, so the
decision does not get relitigated every time someone reads "4.7 has a simpler
alternative to SubViewport" in a changelog. Record the integer-scale constraint
as a binding rule on the Device Frame layout.
