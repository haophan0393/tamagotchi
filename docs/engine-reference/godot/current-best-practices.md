# Godot — Current Best Practices

Last verified: 2026-09-18 | Engine: Godot 4.7.1

Practices that are **new or changed** since the model's training data (~4.3).
Sections are newest-first; 4.7 items are the most likely to be unknown to the model.
This supplements (not replaces) the agent's built-in knowledge.

## GDScript (4.7)

- **Explicit returns in typed overrides**: a method that inherits a typed return
  from its parent must `return` explicitly — falling off the end is an error.
- **Packed array element assignment does not call the setter**:
  `stats[2] = 5` on `@export var stats: PackedInt32Array: set = _on_stats_set`
  no longer triggers `_on_stats_set`. Reassign the whole array if you need it.
- **Java interfaces from GDScript (Android)**: GDScript can implement and override
  Java interfaces — reduces the need for a Java/Kotlin plugin for small hooks.

## UI (4.7)

- **`Control.offset_transform_*`**: translate / rotate / scale a Control visually
  without affecting layout. Use for press-down, wobble, and bounce feedback.
- **`PopupMenu` search bar**: long menus can be filtered.
- **`RichTextLabel` font-size-relative images**: `[img height=1em]`.
- **`TextureRect` tiles `AtlasTexture`** correctly now.
- **Landmark navigation** for screen readers (builds on 4.5 AccessKit work).
- **New project defaults**: stretch mode `canvas_items`, aspect `expand`.

## Input & Mobile (4.7)

- **`VirtualJoystick` node**: built-in on-screen joystick (Fixed, Dynamic, Following).
- **Device ID constants**: `InputEvent.DEVICE_ID_KEYBOARD`, `InputEvent.DEVICE_ID_MOUSE`.
- **Gyroscope / accelerometer** exposed for motion input (joypads and handhelds).
- **iOS game controllers** now handled via SDL3.
- **Android**: picture-in-picture, embedded/movable game window, script editor
  orientation changes, Perfetto tracing default for debug builds.
- **Wayland touch** support on Linux.
- **4.7.1** fixed Android soft-keyboard backspace and touchscreen drag regressions.

## Rendering (4.7)

- **HDR output** on Windows, macOS, iOS, visionOS, Linux/Wayland.
- **`DrawableTexture2D`**: draw into a texture without a SubViewport or
  RenderingDevice code.
- **`GradientTexture2D` conic fill**: CSS-style conic gradients.
- **Nearest-neighbor 3D viewport scaling** for crisp retro rendering (3D only —
  2D pixel look still comes from `canvas_items` stretch + `Nearest` texture filter).
- **`AreaLight3D`**, clearcoat fixes, 3D particle scale/rotation (3D only).
- **CanvasItem lines no longer feathered** — widths look thinner than 4.6.
- **`LinearToSRGB` visual shader node** no longer clamps on Mobile/Forward+.

## Animation & Tweens (4.7)

- **`Tween.tween_await(signal)`**: pause the tween chain until a signal emits.
- **Collapsible animation editor tracks** with aggregate keys.

## Android & Export (4.7)

- **Standalone Android export via GABE** (Godot Android Build Environment) — no
  separate Android Studio install required for the standard export path.
- **Custom splash screens** in the Android export preset.
- **Selective export template download**: fetch only iOS + Android templates.
- **Editor shows installed GDExtensions** in Project Settings.

## GDScript (4.5+)

- **Variadic arguments**: Functions can accept arbitrary parameter counts
  ```gdscript
  func log_values(prefix: String, values: Variant...) -> void:
      for v in values:
          print(prefix, ": ", v)
  ```

- **Abstract classes and methods**: Use `@abstract` to enforce inheritance
  ```gdscript
  @abstract
  class_name BaseEnemy extends CharacterBody3D

  @abstract
  func get_attack_pattern() -> Array[Attack]:
      pass  # Subclasses MUST override
  ```

- **Script backtracing**: Detailed call stacks available even in Release builds

## Physics (4.6)

- **Jolt Physics is the default 3D engine** for new projects
  - Better determinism and stability than GodotPhysics3D
  - Some HingeJoint3D properties (`damp`) only work with GodotPhysics
  - Switch: Project Settings → Physics → 3D → Physics Engine
  - 2D physics unchanged (still Godot Physics 2D)

## Rendering (4.6)

- **D3D12 is the default backend on Windows** (was Vulkan) — for better driver compatibility
- **Glow now processes before tonemapping** with screen blending mode — existing glow setups may look different
- **SSR overhauled** — significant improvement in realism, stability, and performance
- **AgX tonemapper** — new white point and contrast controls

## Rendering (4.5)

- **Shader Baker**: Pre-compile shaders to eliminate startup hitching
- **SMAA 1x**: New AA option — sharper than FXAA, cheaper than TAA
- **Stencil buffer**: Available for advanced masking/portal effects
- **Bent normal maps**: Directional occlusion in normal map textures
- **Specular occlusion**: Ambient occlusion now affects reflections

## Accessibility (4.5+)

- **Screen reader support**: Control nodes integrate with accessibility tools via AccessKit
- **Live translation preview**: Test GUI layouts in different languages directly in-editor
- **FoldableContainer**: New accordion-style UI node for collapsible sections
- **Recursive Control disable**: Disable mouse/focus interactions for entire node hierarchies with a single property

## Animation (4.5+)

- **BoneConstraint3D**: Bind bones to other bones with modifiers
  - AimModifier3D, CopyTransformModifier3D, ConvertTransformModifier3D

## Animation (4.6)

- **IK system fully restored**: Complete inverse kinematics reintroduced for 3D
  - Available modifiers: CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK
  - Applied via `SkeletonModifier3D` nodes

## Resources (4.5+)

- **`duplicate_deep()`**: Explicit deep duplication for nested resource trees
  - Old `duplicate()` behavior retained for backward compatibility
  - Use `duplicate_deep()` when you need per-instance copies of nested resources

## Navigation (4.5+)

- **Dedicated 2D navigation server**: No longer proxied through 3D NavigationServer
  - Reduces export binary size for 2D-only games

## UI (4.6)

- **Dual-focus system**: Mouse/touch focus is now separate from keyboard/gamepad focus
  - Visual feedback differs depending on input method
  - Consider this when designing custom focus behavior

## Editor Workflow (4.6)

- Flexible dock drag-and-drop with blue outline preview (including bottom panel)
- Most panels support floating windows (except Debugger)
- New keyboard shortcuts: Alt+O (Output), Alt+S (Shader)
- Export variable auto-generation: drag resource from FileSystem into script editor
- Live preview in Quick Open dialog when "Live Preview" enabled
- New "Select Mode" (v key) prevents accidental transforms; old mode renamed "Transform Mode" (q key)

## Tooling

- **ripgrep has no `gdscript` type**: `*.gd` is registered under `gap` (GAP programming language).
  `rg --type gdscript` is a hard error — the search never executes.
  Always use `rg --glob "*.gd"` (shell) or `glob: "*.gd"` (Grep tool) to filter GDScript files.

## Platform (4.5+)

- **visionOS export**: First new platform since open-sourcing (windowed app mode)
- **SDL3 gamepad driver**: Better cross-platform gamepad support
- **Android**: Edge-to-edge display, camera feed access, 16KB page support (Android 15+)
- **Linux**: Wayland subwindow support for multi-window capability
