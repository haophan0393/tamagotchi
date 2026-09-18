# Technical Preferences

## Engine & Language

- **Engine**: Godot 4.7.1 (stable, official build — Homebrew cask, `/Applications/Godot.app`)
- **Language**: GDScript (static typing enforced)
- **Rendering**: Mobile renderer (Vulkan / Metal via Mobile backend); 2D only
- **Physics**: Not required for core gameplay — Godot default (Jolt) if any physics is used

## Input & Platform

- **Target Platforms**: Mobile (iOS, Android), portrait
- **Input Methods**: Touch
- **Primary Input**: Touch
- **Gamepad Support**: None
- **Touch Support**: Full
- **Platform Notes**: One-handed portrait. All gameplay routed through 3 on-screen
  device buttons (Pillar 1 / Pillar 5). Haptic + audio feedback on every press.
  No hover-only interactions. Safe-area aware layout for notched phones.

## Naming Conventions

- **Classes**: PascalCase (e.g., `PetController`)
- **Variables**: snake_case (e.g., `hunger_level`)
- **Functions**: snake_case (e.g., `apply_care_action()`)
- **Signals/Events**: snake_case, past tense (e.g., `need_cleared`, `stage_advanced`)
- **Files**: snake_case matching class (e.g., `pet_controller.gd`)
- **Scenes/Prefabs**: PascalCase matching root node (e.g., `PetController.tscn`)
- **Constants**: UPPER_SNAKE_CASE (e.g., `MAX_NEED_VALUE`)

## Performance Budgets

- **Target Framerate**: 60 fps
- **Frame Budget**: 16.6 ms
- **Draw Calls**: < 50 per frame (simple 2D scene: shell, LCD SubViewport, pet sprite, UI)
- **Memory Ceiling**: ~150 MB resident on low-end Android target

## Testing

- **Framework**: gdUnit4
- **Minimum Coverage**: Logic stories 100% (need decay, growth selection, offline time sim)
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)
- **CI Command**: `godot --headless --script tests/gdunit4_runner.gd`

## Forbidden Patterns

- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all .gd files)
- **Shader Specialist**: godot-shader-specialist (.gdshader files, VisualShader resources)
- **UI Specialist**: godot-specialist (no dedicated UI specialist — primary covers all UI)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension / native C++ bindings only)
- **Routing Notes**: Invoke primary for architecture decisions, ADR validation, and
  cross-cutting code review. Invoke GDScript specialist for code quality, signal
  architecture, static typing enforcement, and GDScript idioms. Invoke shader
  specialist for material design and shader code (e.g., the LCD pixel-grid shader).
  Invoke GDExtension specialist only when native extensions are involved.

### File Extension Routing

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer) | godot-specialist |
| Scene / prefab / level files (.tscn, .tres) | godot-specialist |
| Native extension / plugin files (.gdextension, C++) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
