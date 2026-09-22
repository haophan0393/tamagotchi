## LCD rendering spike — compares three ways to produce the Pocket Pal LCD panel.
##
## Question this spike answers (design/gdd/game-concept.md "Key Technical
## Challenges"): how do we render a ~32x32 pixel pet inside a low-res LCD with a
## visible pixel grid, at 60fps on a low-end Android target, under 50 draw calls?
##
## THROWAWAY. Never import into src/.
##
## The three approaches all feed the SAME lcd_grid.gdshader, so only the
## image-production strategy differs:
##
##   A  SubViewport      64x64 SubViewport holding real Sprite2D nodes.
##   B  DrawableTexture2D 4.7's blit-into-texture API, composited manually.
##   C  Direct sprites    No intermediate texture at all; sprites drawn straight
##                        onto the panel at integer scale.
##
## Press 1/2/3 or tap the panel to switch. Metrics update live.
extends Control

const LCD_W := LcdArt.LCD_W
const LCD_H := LcdArt.LCD_H

enum Approach { SUBVIEWPORT, DRAWABLE, DIRECT }

const APPROACH_NAMES := {
	Approach.SUBVIEWPORT: "A — SubViewport",
	Approach.DRAWABLE: "B — DrawableTexture2D",
	Approach.DIRECT: "C — Direct sprites",
}

## How often the pet's idle animation ticks. Slow — this is a calm pet.
const IDLE_TICK_SECONDS := 0.45
## How many frames to average metrics over before reporting.
const METRIC_WINDOW := 30

var _approach: Approach = Approach.SUBVIEWPORT
var _frame := 0
var _idle_accum := 0.0
var _blink := false
var _needs := [true, false, true]

# Pre-built art. Generated once — regenerating per frame would measure image
# construction, not rendering, and skew every number in this spike.
var _pet_frames: Array[ImageTexture] = []
var _icons_on: Array[ImageTexture] = []
var _icons_off: Array[ImageTexture] = []

# Approach B state.
var _drawable: DrawableTexture2D
var _blits_this_frame := 0
var _drawable_dirty := true
## Stress switch: when true, approach B repaints the panel every single frame
## instead of only when state changes. This is the realistic worst case once
## Pet Animation & Reactions drives a per-frame animation.
var stress_repaint := false

# Metrics.
var _frame_times: Array[float] = []
var _draw_calls := 0

var _panel_sub: SubViewportContainer
var _sub_viewport: SubViewport
var _sub_pet: Sprite2D
var _sub_icons: Node2D
var _panel_drawable: TextureRect
var _panel_direct: Control
var _direct_pet: Sprite2D
var _direct_icons: Node2D
var _readout: RichTextLabel

## The LCD panel's on-screen rectangle, inside the device bezel.
const PANEL_RECT := Rect2(Vector2(64, 150), Vector2(384, 384))
## Screen pixels per LCD pixel. 384 / 64 = 6 — an exact integer, which is what
## keeps the pixel grid from shimmering. Non-integer scale is the classic way
## to ruin a pixel-art panel.
const PANEL_SCALE := 6


func _ready() -> void:
	_build_shell()
	_build_art()
	_build_subviewport_content()
	_build_drawable()
	_build_direct_content()
	_set_approach(Approach.SUBVIEWPORT)


## Builds the device shell and the three interchangeable LCD panels in code.
## Hand-authored .tscn was not worth the format guesswork for a throwaway.
func _build_shell() -> void:
	var bg := ColorRect.new()
	bg.color = Color("21242e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Candy-coloured plastic shell (game-concept: "glossy, saturated plastic").
	var shell := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ee5a73")
	sb.set_corner_radius_all(56)
	shell.add_theme_stylebox_override("panel", sb)
	shell.position = Vector2(24, 70)
	shell.size = Vector2(464, 620)
	add_child(shell)

	# Dark bezel around the panel — the "boxy LCD" framing.
	var bezel := ColorRect.new()
	bezel.color = Color("2a2f22")
	bezel.position = PANEL_RECT.position - Vector2(16, 16)
	bezel.size = PANEL_RECT.size + Vector2(32, 32)
	add_child(bezel)

	var mat := _make_lcd_material()

	# --- Approach A: SubViewportContainer -------------------------------
	_panel_sub = SubViewportContainer.new()
	# stretch alone resizes the SubViewport to the container, which defeats the
	# whole point — we want a 64x64 render scaled up 6x, not a 384x384 render.
	# stretch_shrink is what gives a low-res viewport: viewport size becomes
	# container size / shrink = 384 / 6 = 64.
	_panel_sub.stretch = true
	_panel_sub.stretch_shrink = PANEL_SCALE
	_panel_sub.position = PANEL_RECT.position
	_panel_sub.size = PANEL_RECT.size
	_panel_sub.material = mat
	add_child(_panel_sub)

	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(LCD_W, LCD_H)
	_sub_viewport.transparent_bg = true
	_sub_viewport.handle_input_locally = false
	_panel_sub.add_child(_sub_viewport)

	var sub_bg := ColorRect.new()
	sub_bg.color = LcdArt.BG
	sub_bg.size = Vector2(LCD_W, LCD_H)
	_sub_viewport.add_child(sub_bg)
	_sub_icons = Node2D.new()
	_sub_viewport.add_child(_sub_icons)
	_sub_pet = Sprite2D.new()
	_sub_pet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sub_viewport.add_child(_sub_pet)

	# --- Approach B: TextureRect fed by DrawableTexture2D ---------------
	_panel_drawable = TextureRect.new()
	_panel_drawable.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel_drawable.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel_drawable.stretch_mode = TextureRect.STRETCH_SCALE
	_panel_drawable.position = PANEL_RECT.position
	_panel_drawable.size = PANEL_RECT.size
	_panel_drawable.material = mat
	add_child(_panel_drawable)

	# --- Approach C: sprites drawn straight onto the panel --------------
	_panel_direct = Control.new()
	_panel_direct.clip_contents = true
	_panel_direct.position = PANEL_RECT.position
	_panel_direct.size = PANEL_RECT.size
	_panel_direct.material = mat
	add_child(_panel_direct)

	var direct_bg := ColorRect.new()
	direct_bg.color = LcdArt.BG
	direct_bg.size = PANEL_RECT.size
	_panel_direct.add_child(direct_bg)

	var direct_root := Node2D.new()
	direct_root.scale = Vector2(PANEL_SCALE, PANEL_SCALE)
	_panel_direct.add_child(direct_root)
	_direct_icons = Node2D.new()
	direct_root.add_child(_direct_icons)
	_direct_pet = Sprite2D.new()
	_direct_pet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	direct_root.add_child(_direct_pet)

	# --- Readout --------------------------------------------------------
	_readout = RichTextLabel.new()
	_readout.bbcode_enabled = true
	_readout.position = Vector2(24, 720)
	_readout.size = Vector2(464, 200)
	_readout.add_theme_color_override("default_color", Color.WHITE)
	add_child(_readout)


## One ShaderMaterial shared by all three panels, so the comparison isolates
## image production and not the panel treatment.
func _make_lcd_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://lcd_grid.gdshader")
	mat.set_shader_parameter("lcd_resolution", Vector2(LCD_W, LCD_H))
	mat.set_shader_parameter("grid_strength", 0.25)
	mat.set_shader_parameter("grid_gap", 0.18)
	mat.set_shader_parameter("flicker_strength", 0.025)
	mat.set_shader_parameter("flicker_speed", 7.0)
	mat.set_shader_parameter("vignette_strength", 0.25)
	mat.set_shader_parameter("backlight", Vector3(0.78, 0.85, 0.61))
	return mat


## Generates every frame and icon once, up front.
func _build_art() -> void:
	for bounce in 2:
		for blink in [false, true]:
			var img := LcdArt.make_pet_frame(bounce, blink)
			_pet_frames.append(ImageTexture.create_from_image(img))
	for kind in 3:
		_icons_on.append(ImageTexture.create_from_image(LcdArt.make_icon(kind, true)))
		_icons_off.append(ImageTexture.create_from_image(LcdArt.make_icon(kind, false)))


func _pet_texture() -> ImageTexture:
	var bounce := 1 if (_frame / 2) % 2 == 0 else 0
	var idx := bounce * 2 + (1 if _blink else 0)
	return _pet_frames[idx]


#region Approach A — SubViewport
func _build_subviewport_content() -> void:
	# A real scene tree lives in here: the pet is a Sprite2D, icons are Sprite2Ds.
	# This is the "proven" path — everything Godot does for sprites works.
	_sub_pet.texture = _pet_texture()
	_sub_pet.position = Vector2(LCD_W * 0.5, 36)
	for i in 3:
		var s := Sprite2D.new()
		s.texture = _icons_off[i]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(14 + i * 18, 8)
		_sub_icons.add_child(s)


func _update_subviewport() -> void:
	_sub_pet.texture = _pet_texture()
	for i in 3:
		var s := _sub_icons.get_child(i) as Sprite2D
		s.texture = _icons_on[i] if _needs[i] else _icons_off[i]
#endregion


#region Approach B — DrawableTexture2D (Godot 4.7)
func _build_drawable() -> void:
	_drawable = DrawableTexture2D.new()
	# setup(width, height, format, fill colour, use_mipmaps).
	# NOTE: the format is DrawableTexture2D.DrawableFormat, NOT Image.Format —
	# passing Image.FORMAT_RGBA8 is a hard parse error, not a silent mismatch.
	_drawable.setup(LCD_W, LCD_H, DrawableTexture2D.DRAWABLE_FORMAT_RGBA8, LcdArt.BG, false)
	_panel_drawable.texture = _drawable


## Repaints the whole panel by blitting each element in turn.
##
## NOTE: DrawableTexture2D has NO draw_* canvas API — only blit_rect and
## blit_rect_multi. There is no way to draw a line, circle or polygon into it.
## Everything must already exist as a Texture2D. This is the single most
## important finding of the spike; see REPORT.md.
func _repaint_drawable() -> void:
	_blits_this_frame = 0

	# Clear. There is no "fill" call, so the background is itself a blit of a
	# 1x1 texture stretched over the panel.
	_drawable.blit_rect(Rect2i(0, 0, LCD_W, LCD_H), _bg_texture(), Color.WHITE)
	_blits_this_frame += 1

	# Icons.
	for i in 3:
		var tex: ImageTexture = _icons_on[i] if _needs[i] else _icons_off[i]
		var x := 10 + i * 18
		_drawable.blit_rect(Rect2i(x, 4, LcdArt.ICON_SIZE, LcdArt.ICON_SIZE), tex, Color.WHITE)
		_blits_this_frame += 1

	# Pet.
	var pet := _pet_texture()
	_drawable.blit_rect(Rect2i(16, 18, LcdArt.PET_SIZE, LcdArt.PET_SIZE), pet, Color.WHITE)
	_blits_this_frame += 1

	_drawable_dirty = false


var _bg_tex: ImageTexture


func _bg_texture() -> ImageTexture:
	if _bg_tex == null:
		var img := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
		img.set_pixel(0, 0, LcdArt.BG)
		_bg_tex = ImageTexture.create_from_image(img)
	return _bg_tex
#endregion


#region Approach C — Direct sprites
func _build_direct_content() -> void:
	_direct_pet.texture = _pet_texture()
	_direct_pet.position = Vector2(LCD_W * 0.5, 36)
	for i in 3:
		var s := Sprite2D.new()
		s.texture = _icons_off[i]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(14 + i * 18, 8)
		_direct_icons.add_child(s)


func _update_direct() -> void:
	_direct_pet.texture = _pet_texture()
	for i in 3:
		var s := _direct_icons.get_child(i) as Sprite2D
		s.texture = _icons_on[i] if _needs[i] else _icons_off[i]
#endregion


func _set_approach(a: Approach) -> void:
	_approach = a
	_panel_sub.visible = a == Approach.SUBVIEWPORT
	_panel_drawable.visible = a == Approach.DRAWABLE
	_panel_direct.visible = a == Approach.DIRECT
	# Only the active approach should cost anything.
	_sub_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if a == Approach.SUBVIEWPORT else SubViewport.UPDATE_DISABLED
	)
	_drawable_dirty = true
	_frame_times.clear()


func _process(delta: float) -> void:
	_idle_accum += delta
	if _idle_accum >= IDLE_TICK_SECONDS:
		_idle_accum = 0.0
		_frame += 1
		# Blink every 8th tick — sparse, so it reads as life rather than a twitch.
		_blink = _frame % 8 == 0
		_drawable_dirty = true
		match _approach:
			Approach.SUBVIEWPORT: _update_subviewport()
			Approach.DIRECT: _update_direct()

	if _approach == Approach.DRAWABLE and (_drawable_dirty or stress_repaint):
		_repaint_drawable()

	_frame_times.append(delta)
	if _frame_times.size() > METRIC_WINDOW:
		_frame_times.pop_front()
	_draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_update_readout()


func _update_readout() -> void:
	var avg := 0.0
	for t: float in _frame_times:
		avg += t
	avg = avg / maxf(1.0, float(_frame_times.size()))

	var notes := ""
	match _approach:
		Approach.SUBVIEWPORT:
			notes = "Real scene tree inside the panel. AnimatedSprite2D, Tween, particles all work."
		Approach.DRAWABLE:
			notes = "blit_rect only — NO draw_* API. Every element must be a Texture2D already."
			notes += "\nBlits last repaint: %d" % _blits_this_frame
		Approach.DIRECT:
			notes = "No intermediate texture. Panel is a clip rect; sprites at integer scale."

	_readout.text = (
		"[b]%s[/b]\n" % APPROACH_NAMES[_approach]
		+ "fps %d   frame %.2f ms   draw calls %d\n" % [
			Engine.get_frames_per_second(), avg * 1000.0, _draw_calls
		]
		+ "[color=#888]%s[/color]\n" % notes
		+ "[color=#666]1/2/3 switch · N toggle needs · S screenshot[/color]"
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_1: _set_approach(Approach.SUBVIEWPORT)
			KEY_2: _set_approach(Approach.DRAWABLE)
			KEY_3: _set_approach(Approach.DIRECT)
			KEY_N: _toggle_needs()
			KEY_S: _screenshot()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_set_approach(((_approach + 1) % 3) as Approach)


func _toggle_needs() -> void:
	for i in 3:
		_needs[i] = not _needs[i]
	_drawable_dirty = true
	_update_subviewport()
	_update_direct()


## Saves a PNG of the current panel so the visual result can be compared
## outside the running app. Screenshots are the evidence for a Visual/Feel
## story per .claude/docs/coding-standards.md.
func _screenshot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://lcd_%s.png" % _approach
	img.save_png(path)
	print("screenshot -> ", ProjectSettings.globalize_path(path))
