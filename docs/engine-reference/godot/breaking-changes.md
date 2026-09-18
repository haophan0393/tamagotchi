# Godot — Breaking Changes

Last verified: 2026-09-18

Changes between Godot versions, focused on post-LLM-cutoff changes (4.4+).

## 4.7 → 4.7.1 (Jul 2026 — maintenance, LOW RISK)

Maintenance release: 78 fixes, "no known incompatibilities" with 4.7. Notable
for mobile: Android soft-keyboard backspace fixed, touchscreen drag-and-drop
regression fixed, virtual keyboard no longer auto-opens on popup menus.

## 4.6 → 4.7 (Jun 2026 — POST-CUTOFF, HIGH RISK)

Source: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.7.html

| Subsystem | Change | Details |
|-----------|--------|---------|
| Project Settings | `display/window/stretch/mode` default is `canvas_items` for NEW projects | Was `disabled`. Existing projects keep their value. |
| Project Settings | `display/window/stretch/aspect` default is `expand` for NEW projects | Was `keep`. |
| Project Settings | `rendering/reflections/sky_reflections/roughness_layers` default 7 → 8 | 3D only. |
| Project Settings | `ResourceImporterDynamicFont.hinting` default 1 → 3 | Imported fonts may render slightly differently; re-check pixel fonts. |
| GDScript | Methods inheriting a typed return require an explicit `return` | Add `return null` (or a value) where a subclass override previously fell through. |
| GDScript | Setting packed array elements no longer calls the property setter | `my_packed[0] = x` on a property with a setter no longer triggers the setter. |
| Core | `Object.is_class()` parameter is `StringName` (was `String`) | Source-compatible in GDScript; matters for C#. |
| Core | `OptimizedTranslation.generate()` returns `bool` (was `void`) | C# binary incompatible. |
| Core | `ZIPPacker.start_file()` | Added optional `permissions`, `modified_time`. |
| Input | Keyboard/mouse device IDs are no longer `0` | Compare against `InputEvent.DEVICE_ID_KEYBOARD` / `InputEvent.DEVICE_ID_MOUSE`. |
| Rendering | `CanvasItem` line drawing no longer adds an antialiasing feather | Lines look thinner. Increase width if the old look was relied upon. |
| Rendering | `LinearToSRGB` visual shader node no longer clamps to [0,1] | Mobile and Forward+ renderers only. |
| Rendering | `ImageTexture.get_format()` / `PortableCompressedTexture2D.get_format()` moved to `Texture2D` | Now available on all `Texture2D`. |
| Rendering | `RenderingServer.particles_request_process_time()` param `time` → `process_time`; added `process_time_residual` | C# source incompatible. |
| Rendering | `RenderingServer.viewport_set_size()` | Added optional `view_count`. |
| Rendering | `Image.save_exr()` / `save_exr_to_buffer()` | Added optional `color_image`, `max_linear_value`. |
| Particles | `CPUParticles2D/3D`, `GPUParticles2D/3D` `request_particles_process()` | Added optional `process_time_residual`. |
| UI | `RichTextLabel.ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` → `UPDATE_WIDTH_UNIT` | GDScript source incompatible. |
| UI | `RichTextLabel.add_image()` / `update_image()` | width/height `int` → `float`; `width_in_percent`/`height_in_percent` → `width_unit`/`height_unit` of type `RichTextLabel.ImageUnit`. |
| UI | `Control.accessibility_live` type → `AccessibilityServer.AccessibilityLiveMode` | Was `DisplayServer.AccessibilityLiveMode`. C# incompatible. |
| UI | `TreeItem.select()` | Added optional `set_as_cursor`. |
| Fonts | `Font.find_variation()` | Added optional `palette_index`, `custom_colors`. |
| Audio | `AudioEffectSpectrumAnalyzer.tap_back_pos` REMOVED | GDScript and C# incompatible. |
| Audio | `AudioStreamPlayer.area_mask` default 1 → 0 | Reset to layer 1 if using `audio_bus_override`. |
| Animation | `Animation.length` metadata `float` → `double` | C# incompatible. |
| Animation | `AnimationNodeBlendSpace1D/2D.add_blend_point()` | Added optional `name`. |
| Animation | `LookAtModifier3D.relative` default `true` → `false` | 3D only. |
| Physics 2D | `PhysicsServer2D.body_set_shape_as_one_way_collision()` | Added optional `direction` (per-shape one-way direction, also on `CollisionShape2D`). |
| Physics 2D | `PhysicsServer2DExtension._body_set_shape_as_one_way_collision()` | Added REQUIRED `direction` — GDScript/C# extension classes must update. |
| Physics 3D (Jolt) | `WorldBoundaryShape3D.plane.d` sign interpretation reversed | Flip sign manually. |
| Physics 3D (Jolt) | `SoftBody3D` mass defaults to 1 kg (was 0) | Re-tune `linear_stiffness`, `damping_coefficient`. |
| Physics 3D (Jolt) | `Area3D` now reports `SoftBody3D` overlaps | Adjust layers/masks. |
| XR | `OpenXRExtensionWrapper._on_register_metadata()` | Added REQUIRED `interaction_profile_metadata`. |
| XR | `OpenXRSpatialAnchorCapability.create_new_anchor()` | Added optional `next`. |
| Editor | `EditorSceneFormatImporter.IMPORT_*` constants moved to `ImportFlags` enum | GDScript source incompatible for import plugins. |
| Editor | `EditorVCSInterface._commit()` | Added REQUIRED `amend`. |

## 4.5 → 4.6 (Jan 2026 — POST-CUTOFF, HIGH RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Physics | Jolt is now the DEFAULT 3D physics engine | New projects use Jolt automatically. Existing projects keep their setting. Some HingeJoint3D properties (like `damp`) only work with GodotPhysics. |
| Rendering | Glow processes BEFORE tonemapping | Was after tonemapping. Scenes with glow will look different. Adjust intensity/blend in WorldEnvironment. |
| Rendering | D3D12 default on Windows | Was Vulkan. For better driver compatibility. |
| Rendering | AgX tonemapper new controls | White point and contrast parameters added. |
| Core | Quaternion initializes to identity | Was zero. Unlikely to affect most code but technically breaking. |
| UI | Dual-focus system | Mouse/touch focus now separate from keyboard/gamepad focus. Visual feedback differs by input method. |
| Animation | IK system fully restored | CCDIK, FABRIK, Jacobian IK, Spline IK, TwoBoneIK via SkeletonModifier3D nodes. |
| Editor | New "Modern" theme default | Grayscale replaces blue-tint. Restore: Editor Settings → Interface → Theme → Style: Classic |
| Editor | "Select Mode" keybind changed | New "Select Mode" (v key) prevents accidental transforms. Old mode renamed "Transform Mode" (q key). |
| 2D | TileMapLayer scene tile rotation | Scene tiles can now be rotated like atlas tiles. |
| Localization | CSV plural form support | No longer requires Gettext for plurals. Context columns added. |
| C# | Automatic string extraction | Translation strings auto-extracted from C# code. |
| Plugins | New EditorDock class | Specialized container for plugin docks with layout control. |

## 4.4 → 4.5 (Late 2025 — POST-CUTOFF, HIGH RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| GDScript | Variadic arguments added | Functions can accept `...` arbitrary params — new language feature |
| GDScript | `@abstract` decorator | Abstract classes and methods now enforceable |
| GDScript | Script backtracing | Detailed call stacks available even in Release builds |
| Rendering | Stencil buffer support | New capability for advanced visual effects |
| Rendering | SMAA 1x antialiasing | New post-processing AA option |
| Rendering | Shader Baker | Pre-compiles shaders — reportedly 20x faster startup on some demos |
| Rendering | Bent normal maps, specular occlusion | New material features |
| Accessibility | Screen reader support | Control nodes work with accessibility tools via AccessKit |
| Editor | Live translation preview | Test GUI layouts in different languages in-editor |
| Physics | 3D interpolation rearchitected | Moved from RenderingServer to SceneTree. API unchanged but internals differ. |
| Animation | BoneConstraint3D | New: AimModifier3D, CopyTransformModifier3D, ConvertTransformModifier3D |
| Resources | `duplicate_deep()` added | New explicit method for deep duplication of nested resources |
| Navigation | Dedicated 2D navigation server | No longer a proxy to 3D navigation; smaller export for 2D games |
| UI | FoldableContainer node | New accordion-style container for collapsible UI sections |
| UI | Recursive Control behavior | Disable mouse/focus interactions across entire node hierarchies |
| Platform | visionOS export support | New platform target |
| Platform | SDL3 gamepad driver | Delegated gamepad handling to SDL library |
| Platform | Android 16KB page support | Required for Google Play targeting Android 15+ |

## 4.3 → 4.4 (Mid 2025 — NEAR CUTOFF, VERIFY)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Core | `FileAccess.store_*` return `bool` | Was `void`. Methods: `store_8`, `store_16`, `store_32`, `store_64`, `store_buffer`, `store_csv_line`, `store_double`, `store_float`, `store_half`, `store_line`, `store_pascal_string`, `store_real`, `store_string`, `store_var` |
| Core | `OS.execute_with_pipe` | Added optional `blocking` parameter |
| Core | `RegEx.compile/create_from_string` | Added optional `show_error` parameter |
| Rendering | `RenderingDevice.draw_list_begin` | Many parameters removed; `breadcrumb` parameter added |
| Rendering | Shader texture types | Parameter/return types changed from `Texture2D` to `Texture` |
| Particles | `.restart()` method | Added optional `keep_seed` parameter (CPU/GPU 2D/3D) |
| GUI | `RichTextLabel.push_meta` | Added optional `tooltip` parameter |
| GUI | `GraphEdit.connect_node` | Added optional `keep_alive` parameter |

## 4.2 → 4.3 (In Training Data — LOW RISK)

| Subsystem | Change | Details |
|-----------|--------|---------|
| Animation | `Skeleton3D.add_bone` returns `int32` | Was `void` |
| Animation | `bone_pose_updated` signal | Replaced by `skeleton_updated` |
| TileMap | `TileMapLayer` replaces `TileMap` | One node per layer instead of multi-layer single node |
| Navigation | `NavigationRegion2D` | Removed `avoidance_layers`, `constrain_avoidance` properties |
| Editor | `EditorSceneFormatImporterFBX` | Renamed to `EditorSceneFormatImporterFBX2GLTF` |
| Animation | AnimationMixer base class | AnimationPlayer and AnimationTree now extend AnimationMixer |
