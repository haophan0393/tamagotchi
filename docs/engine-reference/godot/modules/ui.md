# Godot UI — Quick Reference

Last verified: 2026-09-18 | Engine: Godot 4.7.1

## What Changed Since ~4.3 (LLM Cutoff)

### 4.7 Changes
- **`Control.offset_transform_*`**: visual-only translate/rotate/scale that does not affect layout
- **`PopupMenu` search bar** for long menus
- **`RichTextLabel`**: font-size-relative images (`[img height=1em]`); `UPDATE_WIDTH_IN_PERCENT` → `UPDATE_WIDTH_UNIT`; `add_image()`/`update_image()` width/height are `float` and take `width_unit`/`height_unit: ImageUnit`
- **`TextureRect`** now tiles `AtlasTexture`
- **Landmark navigation** for screen readers
- **`Tree`** drag-and-drop drop-position indicator; `TreeItem.select()` gains `set_as_cursor`
- **New project defaults**: `display/window/stretch/mode = canvas_items`, `display/window/stretch/aspect = expand`

### Visual Feedback Without Layout Churn (4.7 — NEW)
```gdscript
# Press-down effect on a device button that lives inside a container.
# offset_transform_* is purely visual — the container never re-lays-out.
func _press_visual() -> void:
    var tween := create_tween()
    tween.tween_property(self, "offset_transform_scale", Vector2(0.94, 0.94), 0.04)
    tween.tween_property(self, "offset_transform_scale", Vector2.ONE, 0.08)
```

### 4.6 Changes
- **Dual-focus system**: Mouse/touch focus is now SEPARATE from keyboard/gamepad focus
  - Visual feedback differs by input method
  - Custom focus implementations may need updating
- **TabContainer**: Tab properties editable directly in Inspector
- **TileMapLayer scene tile rotation**: Scene tiles can be rotated like atlas tiles

### 4.5 Changes
- **FoldableContainer**: New accordion-style UI node for collapsible sections
- **Recursive Control behavior**: Disable mouse/focus for entire node hierarchies
  with a single property
- **Screen reader support**: Control nodes work with AccessKit
- **Live translation preview**: Test different locales in-editor
- **`RichTextLabel.push_meta`**: Added optional `tooltip` parameter (from 4.4)

### 4.4 Changes
- **`GraphEdit.connect_node`**: Added optional `keep_alive` parameter

## Current API Patterns

### Theme and Style (4.6)
```gdscript
# Editor uses new "Modern" theme by default
# For game UI, use custom themes as before:
var theme := Theme.new()
theme.set_color(&"font_color", &"Label", Color.WHITE)
theme.set_font_size(&"font_size", &"Label", 24)
```

### Focus Management (4.6 — CHANGED)
```gdscript
# Keyboard/gamepad focus (grab_focus still works)
func _ready() -> void:
    %StartButton.grab_focus()

# IMPORTANT: In 4.6, mouse hover is separate from keyboard focus
# Both can be active simultaneously on different controls
# Test your UI with BOTH mouse and keyboard/gamepad

# Focus neighbors (unchanged)
%Button1.focus_neighbor_bottom = %Button2.get_path()
%Button1.focus_neighbor_right = %Button3.get_path()
```

### FoldableContainer (4.5 — NEW)
```gdscript
# Accordion-style collapsible container
# Add as parent of content you want to make collapsible
# Children show/hide when header is clicked
# Configure via editor properties or code
```

### Recursive Disable (4.5 — NEW)
```gdscript
# Disable all mouse/focus interactions for a hierarchy
# Useful for disabling entire menu sections
%SettingsPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
# In 4.5+, this can propagate recursively to children
```

### Localization-Ready UI (best practice)
```gdscript
# Use tr() for all visible strings
label.text = tr("MENU_START_GAME")

# Use auto-wrap for labels (text length varies by language)
label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# Test with live translation preview in editor (4.5+)
```

## Common Mistakes
- Assuming `grab_focus()` affects mouse focus (keyboard/gamepad only in 4.6)
- Not testing UI with both mouse and gamepad after upgrading to 4.6
- Hardcoding strings instead of using `tr()` for localization
- Not using `FoldableContainer` for collapsible UI (new in 4.5, cleaner than custom)
