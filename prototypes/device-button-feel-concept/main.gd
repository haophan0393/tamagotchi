# PROTOTYPE - NOT FOR PRODUCTION
# Question: Do the three round device buttons feel tactile and satisfying — do the
#           press-down visual, haptic pulse, and beep read as ONE unified click?
# Date: 2026-09-18
extends Control

# ---- tuning knobs (hardcoded on purpose — tweak between iteration rounds) ----
const DEVICE_SIZE := Vector2(720, 1280)
const BUTTON_DIAMETER := 170.0
const BUTTON_Y := 980.0
const BUTTON_XS: Array[float] = [150.0, 360.0, 570.0]
const BUTTON_LABELS: Array[String] = ["A", "B", "C"]
const BUTTON_COLORS: Array[Color] = [Color("ffd23f"), Color("3dd6f5"), Color("8cf26e")]
const SHELL_COLOR := Color("f4649b")

const SHADOW_DEPTH := 10.0      # px the button sinks toward its shadow
const PRESS_SCALE := 0.94
const PRESS_IN_SEC := 0.04
const RELEASE_SEC := 0.16       # spring back (TRANS_BACK / EASE_OUT)

const HAPTIC_MS := 15
const HAPTIC_AMP := 0.8         # -1.0 = platform default strength

const BEEP_FREQS: Array[float] = [660.0, 880.0, 1100.0]
const BEEP_SEC := 0.07
const BEEP_VOLUME := 0.35
const MIX_RATE := 44100

const SIGNAL_WINDOW_SEC := 30.0  # hypothesis: playful repeat presses within 30 s

var _players: Array[AudioStreamPlayer] = []
var _tweens: Dictionary = {}
var _stats: Label
var _press_count := 0
var _first_press_msec := -1
var _presses_in_window := -1


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = SHELL_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var device := Control.new()
	device.size = DEVICE_SIZE
	device.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	add_child(device)

	_stats = Label.new()
	_stats.position = Vector2(24, 40)
	_stats.size = Vector2(DEVICE_SIZE.x - 48, 80)
	_stats.add_theme_font_size_override("font_size", 22)
	_stats.add_theme_color_override("font_color", Color(0, 0, 0, 0.6))
	device.add_child(_stats)

	for i in BUTTON_XS.size():
		_build_button(device, i)
		var player := AudioStreamPlayer.new()
		player.stream = _make_beep(BEEP_FREQS[i])
		player.max_polyphony = 4
		add_child(player)
		_players.append(player)


func _build_button(parent: Control, i: int) -> void:
	var d := BUTTON_DIAMETER
	var top_left := Vector2(BUTTON_XS[i] - d * 0.5, BUTTON_Y - d * 0.5)
	var color: Color = BUTTON_COLORS[i]

	var shadow := Panel.new()
	shadow.size = Vector2(d, d)
	shadow.position = top_left + Vector2(0, SHADOW_DEPTH)
	shadow.add_theme_stylebox_override("panel", _circle_style(color.darkened(0.45)))
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shadow)

	var btn := Button.new()
	btn.size = Vector2(d, d)
	btn.position = top_left
	btn.text = BUTTON_LABELS[i]
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 56)
	for state in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(state, Color(0, 0, 0, 0.5))
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		btn.add_theme_stylebox_override(state, _circle_style(color))
	btn.offset_transform_enabled = true
	btn.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	btn.button_down.connect(_on_button_down.bind(i, btn))
	btn.button_up.connect(_on_button_up.bind(btn))
	parent.add_child(btn)


func _circle_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(BUTTON_DIAMETER * 0.5))
	style.anti_aliasing = true
	return style


# Chip-style square-wave beep with a linear decay — no audio assets needed.
func _make_beep(freq: float) -> AudioStreamWAV:
	var n := int(BEEP_SEC * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := 1.0 - float(i) / float(n)
		var s := 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0
		var v := int(clampf(s * env * BEEP_VOLUME, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav


func _on_button_down(i: int, btn: Button) -> void:
	# The three feedback channels fire on the same frame — the hypothesis is whether they read as one click.
	Input.vibrate_handheld(HAPTIC_MS, HAPTIC_AMP)
	_players[i].play()

	_kill_tween(btn)
	var tw := btn.create_tween().set_parallel(true)
	tw.tween_property(btn, "offset_transform_scale", Vector2.ONE * PRESS_SCALE, PRESS_IN_SEC)
	tw.tween_property(btn, "offset_transform_position", Vector2(0, SHADOW_DEPTH), PRESS_IN_SEC)
	_tweens[btn] = tw

	_press_count += 1
	if _first_press_msec < 0:
		_first_press_msec = Time.get_ticks_msec()


func _on_button_up(btn: Button) -> void:
	_kill_tween(btn)
	var tw := btn.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "offset_transform_scale", Vector2.ONE, RELEASE_SEC)
	tw.tween_property(btn, "offset_transform_position", Vector2.ZERO, RELEASE_SEC)
	_tweens[btn] = tw


func _kill_tween(btn: Button) -> void:
	if _tweens.has(btn):
		var tw: Tween = _tweens[btn]
		if tw.is_valid():
			tw.kill()
		_tweens.erase(btn)


func _process(_delta: float) -> void:
	if _first_press_msec < 0:
		_stats.text = "presses: 0"
		return
	var elapsed := (Time.get_ticks_msec() - _first_press_msec) / 1000.0
	if elapsed >= SIGNAL_WINDOW_SEC and _presses_in_window < 0:
		_presses_in_window = _press_count
	var line := "presses: %d   since first press: %.1fs" % [_press_count, elapsed]
	if _presses_in_window >= 0:
		line += "\npresses in first %ds: %d" % [int(SIGNAL_WINDOW_SEC), _presses_in_window]
	_stats.text = line
