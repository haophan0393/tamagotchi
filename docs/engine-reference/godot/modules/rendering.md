# Godot Rendering — Quick Reference

Last verified: 2026-09-22 | Engine: Godot 4.7.1

## What Changed Since ~4.3 (LLM Cutoff)

### 4.7 Changes
- **HDR output** on Windows, macOS, iOS, visionOS, Linux/Wayland
- **`DrawableTexture2D`**: **blit**-into-texture API (alternative to SubViewport).
  **Not a canvas** — it has `blit_rect` / `blit_rect_multi` only, and NO `draw_*`
  methods. Everything composited into it must already be a `Texture2D`. Verified
  2026-09-22 via `--doctool`; see `prototypes/lcd-rendering-spike/REPORT.md`.
- **`GradientTexture2D`** conic fill mode
- **Nearest-neighbor 3D viewport scaling** (3D only)
- **`CanvasItem` line drawing no longer adds AA feather** — lines look thinner
- **`LinearToSRGB` visual shader node** no longer clamps to [0,1] on Mobile/Forward+
- **`get_format()`** moved up to `Texture2D`
- **`AreaLight3D`**, clearcoat improvements, Vulkan subsampled images (3D/XR only)

### Low-Res LCD Layer (RESOLVED 2026-09-22 — `prototypes/lcd-rendering-spike/`)

**Decision: Option A.** Option B was eliminated; the reasoning below was wrong.

```
Option A (CHOSEN): SubViewport at LCD resolution (e.g. 64x64) → SubViewportContainer
                   with stretch = true AND stretch_shrink = <integer scale>;
                   texture_filter = NEAREST; pixel-grid shader as the container's
                   material. Keeps a real scene tree inside the panel, so
                   AnimatedSprite2D, Tween and Control layout all work.
Option B (4.7):    REJECTED. The old note here said DrawableTexture2D works "if all
                   pet/UI drawing is done via draw_* calls" — but DrawableTexture2D
                   has NO draw_* calls at all. It is blit-only. Every element must
                   already be a Texture2D: no AnimatedSprite2D, no Tween, no Label.
Option C:          REJECTED. Sprites drawn directly with the shader on their parent
                   Control produce NO grid — a Control's material does not apply to
                   its children. The grid shader requires the LCD contents to be
                   flattened into a single texture first.
```

**Gotchas confirmed by the spike:**
- `setup()` takes `DrawableTexture2D.DrawableFormat`, NOT `Image.Format`. Passing
  `Image.FORMAT_RGBA8` is a hard parse error.
- `SubViewportContainer.stretch = true` alone resizes the SubViewport to the
  container, defeating low-res rendering. `stretch_shrink` is what gives a
  low-res viewport scaled up.
- The LCD's on-screen rect must be an **exact integer multiple** of the LCD
  resolution, or the pixel grid shimmers. This constrains safe-area layout.

### 4.6 Changes
- **D3D12 is the default rendering backend on Windows** (was Vulkan)
- **Glow processes before tonemapping** (was after) — uses screen blending mode
- **AgX tonemapper**: new white point and contrast controls
- **SSR overhauled**: better realism, visual stability, and performance

### 4.5 Changes
- **Shader Baker**: Pre-compiles shaders to reduce startup time
- **SMAA 1x**: New anti-aliasing option (sharper than FXAA, cheaper than TAA)
- **Stencil buffer support**: Enables selective geometry masking/portal effects
- **Bent normal maps**: Directional occlusion encoded in normal map textures
- **Specular occlusion**: Ambient occlusion now correctly affects reflections

### 4.4 Changes
- **`RenderingDevice.draw_list_begin`**: Many parameters removed; optional `breadcrumb` added
- **Shader texture types**: Changed from `Texture2D` to `Texture` base type
- **Particles `.restart()`**: Added optional `keep_seed` parameter

### 4.3 Changes (in training data)
- **Compositor node**: `Compositor` + `CompositorEffect` for post-processing chains

## Current API Patterns

### Post-Processing (4.3+)
```gdscript
# Use Compositor node — NOT manual viewport shader chains
# Add Compositor as child of WorldEnvironment or Camera3D
# Create CompositorEffect resources for each post-process step
```

### Anti-Aliasing Options (4.6)
```
Project Settings → Rendering → Anti Aliasing:
- MSAA 2D/3D: Hardware MSAA (quality but expensive)
- Screen Space AA: FXAA (fast, blurry) or SMAA (sharp, moderate cost)  # SMAA new in 4.5
- TAA: Temporal (best quality, ghosting on fast motion)
```

### Rendering Backend Selection (4.6)
```
Project Settings → Rendering → Renderer:
- Forward+ (default): Full featured, desktop-focused
- Mobile: Optimized for mobile/low-end, limited features
- Compatibility: OpenGL 3.3 / WebGL 2, broadest hardware support

Windows default backend: D3D12 (was Vulkan pre-4.6)
```

## Common Mistakes
- Assuming Vulkan is the default backend on Windows (D3D12 since 4.6)
- Using manual viewport chains instead of Compositor for post-processing
- Using `Texture2D` in shader uniform types (use `Texture` since 4.4)
- Not using Shader Baker for projects with many shader variants
