# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.7.1 (stable, official build `a13da4feb`) |
| **Release Date** | 4.7: 2026-06-18 · 4.7.1: 2026-07-14 |
| **Project Pinned** | 2026-09-18 |
| **Last Docs Verified** | 2026-09-18 |
| **LLM Knowledge Cutoff** | May 2025 (template baseline — see warning below) |
| **Risk Level** | HIGH — 4.4 through 4.7 are all post-cutoff |
| **Local Install** | Homebrew cask `godot` → `/Applications/Godot.app`; `godot` on PATH |
| **Language** | GDScript (see `.claude/docs/technical-preferences.md`) |

## Knowledge Gap Warning

The LLM's training data reliably covers Godot up to ~4.3. Versions 4.4, 4.5,
4.6, and 4.7 introduced significant changes the model may not know or may
half-remember. Always cross-reference this directory before suggesting Godot
API calls, project settings, or export steps. When uncertain, WebSearch the
official 4.7 docs (`https://docs.godotengine.org/en/4.7/`).

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 4.4 | Mar 2025 | MEDIUM | Jolt physics option, FileAccess return types, shader texture type changes |
| 4.5 | Sep 2025 | HIGH | Accessibility (AccessKit), variadic args, @abstract, shader baker, SMAA |
| 4.6 | Jan 2026 | HIGH | Jolt default, glow rework, D3D12 default on Windows, IK restored |
| 4.7 | Jun 2026 | HIGH | HDR output, `VirtualJoystick`, `DrawableTexture2D`, Control offset transforms, `Tween.tween_await()`, new stretch defaults, standalone Android export (GABE) |
| 4.7.1 | Jul 2026 | LOW (patch) | 78 fixes, no known incompatibilities with 4.7 — Android soft-keyboard and touchscreen regressions fixed |

## Project-Relevant Highlights (Pocket Pal — 2D mobile, GDScript)

- **New project defaults**: `display/window/stretch/mode = canvas_items`,
  `display/window/stretch/aspect = expand`. Good fit for portrait mobile; verify
  the device frame layout under `expand` on tall and short aspect ratios.
- **`VirtualJoystick` node** exists now — not needed (3-button design) but do not
  hand-roll touch controls the engine already ships.
- **`DrawableTexture2D`** is a simpler alternative to SubViewport for drawing into a
  texture — candidate for the LCD screen layer; evaluate in the prototype.
- **`Tween.tween_await(signal)`** — pause a tween until a signal fires; useful for
  pet reaction → beep → need-clear sequencing.
- **`Control.offset_transform_*`** — visual-only transforms on UI without touching
  layout; ideal for button "press-down" animation on the device buttons.
- **`AudioStreamPlayer.area_mask` default changed 1 → 0** — only matters if
  `audio_bus_override` is used.
- **CanvasItem lines no longer add antialiasing feather** — custom-drawn lines
  look thinner than in 4.6.
- **GDScript**: methods inheriting a typed return now need an explicit `return`.

## Verified Sources

- Official docs (4.7 branch): https://docs.godotengine.org/en/4.7/
- 4.6→4.7 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html
- 4.5→4.6 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.4→4.5 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- 4.7 release notes: https://godotengine.org/releases/4.7/
- 4.7.1 maintenance release: https://godotengine.org/article/maintenance-release-godot-4-7-1/
- GitHub releases: https://github.com/godotengine/godot/releases/tag/4.7.1-stable
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md
