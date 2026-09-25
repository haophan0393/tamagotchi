# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does the 30-second loop make the pet feel alive and glad
#   to see me, and is the 3-button ring learnable with no text?
# Date: 2026-09-25
#
# The device: shell, three buttons, the LCD, and the Device Frame state machine
# (design/gdd/device-frame-button-input.md, States and Transitions). Reaction
# sequences are scripted coroutines. Throwaway code, so that is fine here.
#
# Desktop keys: 1/2/3 or Left/Down/Right = A/B/C. F = +6 game hours.
#               R = restart. D = debug readout.
extends Control

enum State { BOOT, IDLE, MENU, ACTING, PLAYING }

const BTN_A := 0
const BTN_B := 1
const BTN_C := 2

## Result of routing a press: accepted (full triad), nothing-here (tick only),
## or discarded (press visual only, Core Rule 11).
enum Press { ACCEPTED, NOTHING, DISCARDED }

const EXCLAIM_POS := Vector2i(45, 20)
const QUESTION_POS := Vector2i(30, 19)
const FOOD_POS := Vector2i(44, 40)
const BUBBLES: Array[Vector2i] = [
	Vector2i(17, 40), Vector2i(26, 44), Vector2i(36, 42),
	Vector2i(43, 37), Vector2i(21, 34), Vector2i(39, 31),
]
const SPARKLES: Array[Vector2i] = [Vector2i(14, 28), Vector2i(44, 26), Vector2i(29, 22)]
const Z_POS: Array[Vector2i] = [Vector2i(40, 30), Vector2i(44, 25), Vector2i(48, 20)]

var _state: State = State.BOOT
var _clock: SliceClock
var _needs: SliceNeeds
var _sfx: Sfx
var _lcd: LcdScreen
var _lcd_material: ShaderMaterial
var _buttons: Array[Button] = []
var _btn_tweens: Dictionary = {}
var _held := -1
var _cursor := 0
var _menu_idle := 0.0
var _since_press := 0.0
var _idle_accum := 0.0
var _idle_frame := 0
var _crossing_accum := 0.0
var _attention_busy := false
var _play_guess := 0
var _hint_button := -1
var _hint_tween: Tween
var _debug_label: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_clock = SliceClock.new()
	_needs = SliceNeeds.new(_clock, SliceConfig.START_VALUES)
	_needs.need_became_sad.connect(_on_need_became_sad)
	_sfx = Sfx.new()
	add_child(_sfx)
	_build_device()
	_run_greeting()


# ---------------------------------------------------------------- building --

func _build_device() -> void:
	var bg := ColorRect.new()
	bg.color = SliceConfig.BACKDROP_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var device := Control.new()
	device.size = SliceConfig.DEVICE_SIZE
	device.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	device.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(device)

	var shell := Panel.new()
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = SliceConfig.SHELL_COLOR
	shell_style.set_corner_radius_all(SliceConfig.SHELL_RADIUS)
	shell_style.shadow_color = Color(0, 0, 0, 0.35)
	shell_style.shadow_size = 24
	shell_style.shadow_offset = Vector2(0, 12)
	shell.add_theme_stylebox_override("panel", shell_style)
	shell.position = SliceConfig.SHELL_RECT.position
	shell.size = SliceConfig.SHELL_RECT.size
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	device.add_child(shell)

	var brand := Label.new()
	brand.text = SliceConfig.BRAND_TEXT
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.position = Vector2(0, SliceConfig.BRAND_Y)
	brand.size = Vector2(SliceConfig.DEVICE_SIZE.x, 40)
	brand.add_theme_font_size_override("font_size", 30)
	brand.add_theme_color_override("font_color", SliceConfig.SHELL_COLOR.darkened(0.3))
	device.add_child(brand)

	var scale := SliceConfig.lcd_scale(SliceConfig.BEZEL_INNER)
	var panel_size := Vector2(PetArt.LCD_W, PetArt.LCD_H) * scale
	var panel_pos := Vector2((SliceConfig.DEVICE_SIZE.x - panel_size.x) * 0.5, SliceConfig.LCD_TOP)

	var bezel := Panel.new()
	var bezel_style := StyleBoxFlat.new()
	bezel_style.bg_color = SliceConfig.BEZEL_COLOR
	bezel_style.set_corner_radius_all(18)
	bezel.add_theme_stylebox_override("panel", bezel_style)
	bezel.position = panel_pos - Vector2.ONE * SliceConfig.BEZEL_PAD
	bezel.size = panel_size + Vector2.ONE * SliceConfig.BEZEL_PAD * 2.0
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	device.add_child(bezel)

	# SubViewport at LCD resolution, scaled up by an integer (LCD spike verdict A).
	_lcd_material = ShaderMaterial.new()
	_lcd_material.shader = load("res://lcd_grid.gdshader")
	_lcd_material.set_shader_parameter("lcd_resolution", Vector2(PetArt.LCD_W, PetArt.LCD_H))
	_lcd_material.set_shader_parameter("backlight", SliceConfig.LCD_BACKLIGHT)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = scale
	container.position = panel_pos
	container.size = panel_size
	container.material = _lcd_material
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	device.add_child(container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(PetArt.LCD_W, PetArt.LCD_H)
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	container.add_child(viewport)

	_lcd = LcdScreen.new()
	_lcd.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(_lcd)

	for i in SliceConfig.BUTTON_XS.size():
		_build_button(device, i)

	_debug_label = Label.new()
	_debug_label.position = Vector2(24, 20)
	_debug_label.size = Vector2(SliceConfig.DEVICE_SIZE.x - 48, 90)
	_debug_label.add_theme_font_size_override("font_size", 20)
	_debug_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_debug_label.visible = false
	device.add_child(_debug_label)


func _build_button(parent: Control, i: int) -> void:
	var d := SliceConfig.BUTTON_DIAMETER
	var top_left := Vector2(SliceConfig.BUTTON_XS[i] - d * 0.5, SliceConfig.BUTTON_Y - d * 0.5)
	var color: Color = SliceConfig.BUTTON_COLORS[i]

	var shadow := Panel.new()
	shadow.size = Vector2(d, d)
	shadow.position = top_left + Vector2(0, SliceConfig.SHADOW_DEPTH)
	shadow.add_theme_stylebox_override("panel", _circle_style(color.darkened(0.45)))
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shadow)

	# Deliberately unlabelled: the playtest checks the buttons teach themselves.
	var btn := Button.new()
	btn.size = Vector2(d, d)
	btn.position = top_left
	btn.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		btn.add_theme_stylebox_override(state, _circle_style(color))
	btn.offset_transform_enabled = true
	btn.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	btn.button_down.connect(_on_button_down.bind(i))
	btn.button_up.connect(_on_button_up.bind(i))
	parent.add_child(btn)
	_buttons.append(btn)


func _circle_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(SliceConfig.BUTTON_DIAMETER * 0.5))
	style.anti_aliasing = true
	return style


# ------------------------------------------------------------------- input --

func _on_button_down(i: int) -> void:
	# One press at a time (Core Rule 6): other buttons are ignored while one is held.
	if _held >= 0:
		return
	_held = i
	_since_press = 0.0
	_press_visual(i, true)
	# Feedback triad on the same frame (Core Rule 7).
	match _route(i):
		Press.ACCEPTED:
			Input.vibrate_handheld(SliceConfig.HAPTIC_MS, SliceConfig.HAPTIC_AMP)
			_sfx.play(SliceConfig.BUTTON_SOUNDS[i])
		Press.NOTHING:
			_sfx.play("tick")


func _on_button_up(i: int) -> void:
	if _held != i:
		return
	_held = -1
	_press_visual(i, false)


func _route(i: int) -> Press:
	match _state:
		State.IDLE:
			if i == BTN_A:
				_open_menu()
				return Press.ACCEPTED
			if i == BTN_B and _needs.is_sad(SliceConfig.Need.SLEEP):
				_act(SliceConfig.Action.LIGHTS)
				return Press.ACCEPTED
			return Press.NOTHING
		State.MENU:
			_menu_idle = 0.0
			var n := SliceConfig.MENU_ITEMS.size()
			if i == BTN_A:
				_cursor = (_cursor + 1) % n
			elif i == BTN_C:
				_cursor = (_cursor - 1 + n) % n
			else:
				_act(SliceConfig.MENU_ITEMS[_cursor])
			return Press.ACCEPTED
		State.PLAYING:
			if i == BTN_B:
				return Press.NOTHING
			_play_guess = -1 if i == BTN_A else 1
			return Press.ACCEPTED
	return Press.DISCARDED


func _press_visual(i: int, down: bool) -> void:
	var btn := _buttons[i]
	if _btn_tweens.has(i):
		var old: Tween = _btn_tweens[i]
		if old.is_valid():
			old.kill()
	var tw := btn.create_tween().set_parallel(true)
	if down:
		tw.tween_property(btn, "offset_transform_scale", Vector2.ONE * SliceConfig.PRESS_SCALE, SliceConfig.PRESS_IN_SEC)
		tw.tween_property(btn, "offset_transform_position", Vector2(0, SliceConfig.SHADOW_DEPTH), SliceConfig.PRESS_IN_SEC)
	else:
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "offset_transform_scale", Vector2.ONE, SliceConfig.RELEASE_SEC)
		tw.tween_property(btn, "offset_transform_position", Vector2.ZERO, SliceConfig.RELEASE_SEC)
	_btn_tweens[i] = tw


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	var idx := -1
	match key.keycode:
		KEY_1, KEY_LEFT:
			idx = BTN_A
		KEY_2, KEY_DOWN, KEY_SPACE:
			idx = BTN_B
		KEY_3, KEY_RIGHT:
			idx = BTN_C
		KEY_F:
			if key.pressed:
				_clock.skip_hours(SliceConfig.DEBUG_SKIP_HOURS)
				_needs.check_crossings()
			return
		KEY_R:
			if key.pressed:
				get_tree().reload_current_scene()
			return
		KEY_D:
			if key.pressed:
				_debug_label.visible = not _debug_label.visible
			return
	if idx < 0:
		return
	if key.pressed:
		_on_button_down(idx)
	else:
		_on_button_up(idx)


# ------------------------------------------------------------------- frame --

func _process(delta: float) -> void:
	_since_press += delta
	_crossing_accum += delta
	if _crossing_accum >= SliceConfig.CROSSING_CHECK_SEC:
		_crossing_accum = 0.0
		_needs.check_crossings()

	for need in _lcd.need_sad.size():
		_lcd.need_sad[need] = _needs.is_sad(need)
	_lcd.done_heart = _needs.all_addressed()

	match _state:
		State.IDLE:
			_lcd.bottom = "lights" if _needs.is_sad(SliceConfig.Need.SLEEP) else ""
			_tick_idle(delta)
		State.MENU:
			_lcd.cursor = _cursor
			_tick_idle(delta)
			_menu_idle += delta
			if _menu_idle >= SliceConfig.MENU_IDLE_TIMEOUT:
				_enter_idle()

	_update_hint()
	if _debug_label.visible:
		_debug_label.text = _debug_text()
	_lcd.queue_redraw()


func _tick_idle(delta: float) -> void:
	var mood := _mood()
	var tick := SliceConfig.IDLE_TICK_SAD if mood == "sad" else SliceConfig.IDLE_TICK
	_idle_accum += delta
	if _idle_accum < tick:
		return
	_idle_accum = 0.0
	_idle_frame += 1
	var f := _idle_frame
	var blink := f % SliceConfig.BLINK_EVERY == 0
	_lcd.pet_offset = Vector2i.ZERO
	match mood:
		"happy":
			var beam := f % 4 == 0
			_lcd.pose = PetArt.pose(
				"happy" if beam else ("blink" if blink else "open"),
				"wide" if beam else "smile", f % 2, 0, true)
			if f % 6 == 0:
				_lcd.pet_offset = Vector2i(0, -2)
		"sleepy":
			_lcd.pose = PetArt.pose("closed" if f % 3 != 0 else "blink", "flat", 0)
		_:
			_lcd.pose = PetArt.pose("blink" if blink else "sad", "frown", -(f % 2))


func _mood() -> String:
	var sad := _needs.sad_needs_ranked()
	if sad.is_empty():
		return "happy"
	if sad.size() == 1 and sad[0] == SliceConfig.Need.SLEEP:
		return "sleepy"
	return "sad"


## Pulses the button that would help once the player has been idle a while.
func _update_hint() -> void:
	var want := -1
	if _state == State.IDLE and _since_press >= SliceConfig.HINT_DELAY:
		if _needs.has_sad_ring_need():
			want = BTN_A
		elif _needs.is_sad(SliceConfig.Need.SLEEP):
			want = BTN_B
	if want == _hint_button:
		return
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	if _hint_button >= 0:
		_buttons[_hint_button].modulate = Color.WHITE
	_hint_button = want
	if want >= 0:
		var btn := _buttons[want]
		_hint_tween = btn.create_tween().set_loops()
		_hint_tween.tween_property(btn, "modulate", SliceConfig.HINT_BRIGHT, SliceConfig.HINT_PULSE_SEC)
		_hint_tween.tween_property(btn, "modulate", Color.WHITE, SliceConfig.HINT_PULSE_SEC)


func _debug_text() -> String:
	var names: Array[String] = ["hunger", "clean", "fun", "sleep"]
	var parts: Array[String] = []
	for need in names.size():
		parts.append("%s %.0f%s" % [names[need], _needs.value(need), "*" if _needs.is_sad(need) else ""])
	return "game +%.1fh  state %s\n%s\nF +6h · R restart · D hide" % [
		_clock.elapsed_game_hours(), State.keys()[_state], "  ".join(parts)]


# ----------------------------------------------------------------- states --

func _enter_idle() -> void:
	_state = State.IDLE
	_lcd.bottom = ""
	_lcd.pet_offset = Vector2i.ZERO
	_idle_accum = SliceConfig.IDLE_TICK_SAD  # refresh the pose on the next frame


func _open_menu() -> void:
	_state = State.MENU
	_menu_idle = 0.0
	_cursor = _needs.menu_cursor_start(SliceConfig.MENU_ITEMS)
	_lcd.cursor = _cursor
	_lcd.bottom = "menu"


func _on_need_became_sad(need: int) -> void:
	if _state == State.IDLE and not _attention_busy:
		_attention(need)


# ------------------------------------------------------------- sequences --

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## The pet notices you first (game-concept Core Loop), before any press.
func _run_greeting() -> void:
	_state = State.BOOT
	_lcd.pose = PetArt.pose("closed", "flat")
	await _wait(0.7)
	_sfx.play("attention")
	_lcd.set_prop("alert", "exclaim", EXCLAIM_POS)
	_lcd.pose = PetArt.pose("open", "open")
	await _wait(0.5)
	_lcd.clear_prop("alert")
	_sfx.play("greet")
	await _hop(2)
	await _wait(0.3)
	_enter_idle()


func _attention(need: int) -> void:
	_attention_busy = true
	_sfx.play("attention")
	_lcd.set_prop("alert", "exclaim", EXCLAIM_POS)
	_lcd.pose = PetArt.pose("open", "open")
	_idle_accum = 0.0  # hold the surprised face for one idle tick
	_lcd.flash_need = need
	for k in 6:
		_lcd.flash_on = k % 2 == 0
		await _wait(0.15)
	_lcd.flash_need = -1
	_lcd.clear_prop("alert")
	_attention_busy = false


func _act(action: int) -> void:
	_state = State.ACTING
	_lcd.bottom = ""
	var need: int = SliceConfig.ACTION_NEED[action]
	var was_sad := _needs.is_sad(need)
	var was_done := _needs.all_addressed()
	match action:
		SliceConfig.Action.FEED:
			await _anim_feed()
		SliceConfig.Action.CLEAN:
			await _anim_clean()
		SliceConfig.Action.PLAY:
			await _anim_play()
		SliceConfig.Action.LIGHTS:
			await _anim_lights()
	_needs.apply_care(action)
	await _hop(2)
	if was_sad and not _needs.is_sad(need):
		await _anim_icon_clear(need)
	if not was_done and _needs.all_addressed():
		await _anim_done()
	_enter_idle()


func _hop(times: int) -> void:
	for k in times:
		_lcd.pet_offset = Vector2i(0, -SliceConfig.HOP_PX)
		_lcd.pose = PetArt.pose("happy", "wide", 1, 0, true)
		await _wait(SliceConfig.HOP_SEC)
		_lcd.pet_offset = Vector2i.ZERO
		_lcd.pose = PetArt.pose("happy", "smile", 0, 0, true)
		await _wait(SliceConfig.HOP_SEC)


func _anim_feed() -> void:
	_lcd.pet_offset = Vector2i(-6, 0)
	_lcd.set_prop("food", "bowl_full", FOOD_POS)
	_lcd.pose = PetArt.pose("open", "open", 0, 1)
	await _wait(0.35)
	for next: String in ["bowl_half", "bowl_crumbs", ""]:
		_lcd.pose = PetArt.pose("happy", "open", 1, 1)
		_sfx.play("chomp")
		await _wait(SliceConfig.CHOMP_SEC)
		_lcd.pose = PetArt.pose("happy", "smile", 0, 1)
		if next.is_empty():
			_lcd.clear_prop("food")
		else:
			_lcd.set_prop("food", next, FOOD_POS)
		await _wait(SliceConfig.CHOMP_SEC)
	_lcd.pet_offset = Vector2i.ZERO


func _anim_clean() -> void:
	for step in SliceConfig.CLEAN_STEPS:
		for b in BUBBLES.size():
			var rise := (step * 2 + b * 3) % 14
			_lcd.set_prop("bubble%d" % b, "bubble", BUBBLES[b] + Vector2i(0, -rise))
		if step % 3 == 0:
			_sfx.play("bubble")
		_lcd.pose = PetArt.pose("blink" if step % 4 < 2 else "happy", "smile", step % 2)
		await _wait(SliceConfig.CLEAN_STEP_SEC)
	_lcd.clear_props()
	_sfx.play("sparkle")
	for s in SPARKLES.size():
		_lcd.set_prop("sparkle%d" % s, "sparkle", SPARKLES[s])
	_lcd.pose = PetArt.pose("happy", "wide", 0, 0, true)
	await _wait(0.45)
	_lcd.clear_props()


## Left/right guess: will Bloop look left (A) or right (C)? There is no fail
## state. Fun restores whatever the result.
func _anim_play() -> void:
	_lcd.play_mode = true
	_lcd.play_wins = 0
	var wins := 0
	for r in SliceConfig.PLAY_ROUNDS:
		_lcd.pet_offset = Vector2i.ZERO
		_lcd.pose = PetArt.pose("open", "smile")
		_lcd.set_prop("q", "question", QUESTION_POS)
		_lcd.bottom = "arrows"
		_lcd.arrow_pick = 0
		_play_guess = 0
		_state = State.PLAYING
		var waited := 0.0
		while _play_guess == 0 and waited < SliceConfig.PLAY_GUESS_TIMEOUT:
			await get_tree().process_frame
			waited += get_process_delta_time()
		_state = State.ACTING
		_lcd.arrow_pick = _play_guess
		_lcd.clear_prop("q")
		var turn := -1 if _rng.randf() < 0.5 else 1
		await _wait(0.2)
		_lcd.pose = PetArt.pose("open", "smile", 0, turn)
		_lcd.pet_offset = Vector2i(turn * SliceConfig.PLAY_TURN_PX, 0)
		await _wait(0.25)
		if _play_guess == turn:
			wins += 1
			_lcd.play_wins = wins
			_sfx.play("ding")
			_lcd.bottom = ""
			await _hop(1)
		else:
			_sfx.play("giggle")
			_lcd.pose = PetArt.pose("happy", "open", 1, turn)
			_lcd.bottom = ""
		await _wait(SliceConfig.PLAY_RESULT_SEC)
	_lcd.play_mode = false
	_lcd.pet_offset = Vector2i.ZERO


## Lights is a momentary beat, not a persistent dark state (Need System Rule 9).
func _anim_lights() -> void:
	_sfx.play("lights_off")
	var off := create_tween()
	off.tween_property(_lcd_material, "shader_parameter/backlight", SliceConfig.LCD_BACKLIGHT_DARK, 0.3)
	_lcd.pet_modulate = Color(0.7, 0.7, 0.8)
	_lcd.pose = PetArt.pose("closed", "flat")
	var steps := 6
	for k in steps:
		_lcd.set_prop("z", "z", Z_POS[k % Z_POS.size()])
		_lcd.pose = PetArt.pose("closed", "flat", k % 2)
		await _wait(SliceConfig.LIGHTS_OUT_SEC / steps)
	_lcd.clear_prop("z")
	_sfx.play("lights_on")
	var on := create_tween()
	on.tween_property(_lcd_material, "shader_parameter/backlight", SliceConfig.LCD_BACKLIGHT, 0.3)
	_lcd.pet_modulate = Color.WHITE
	_lcd.pose = PetArt.pose("open", "wide", 1)
	await _wait(0.4)


func _anim_icon_clear(need: int) -> void:
	_sfx.play("clear")
	_lcd.flash_need = need
	for k in 6:
		_lcd.flash_on = k % 2 == 0
		await _wait(SliceConfig.FLASH_SEC)
	_lcd.flash_need = -1


## "Done for today": the explicit end-of-session signal.
func _anim_done() -> void:
	_sfx.play("done")
	for s in SPARKLES.size():
		_lcd.set_prop("sparkle%d" % s, "sparkle", SPARKLES[s])
	await _hop(3)
	_lcd.clear_props()
