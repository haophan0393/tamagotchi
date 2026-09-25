# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does the 30-second loop make the pet feel alive and glad
#   to see me, and is the 3-button ring learnable with no text?
# Date: 2026-09-25
#
# Scripted run of the full loop, for a smoke check plus screenshots. This is not
# the playtest. Usage: godot --path . --script drive.gd -- <out_dir>
extends SceneTree

var _out := "res://captures"
var _scene: Node
var _shot := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	_scene = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	await _sec(0.9)
	await _snap("greeting")
	await _sec(1.5)
	_check(_state() == "IDLE", "greeting ends in IDLE")
	await _snap("idle_sad")

	# Feed: A opens menu with cursor on the most urgent (hunger 18), B selects.
	await _press(0)
	_check(_state() == "MENU", "A opens menu")
	_check(_scene.get("_cursor") == 0, "cursor starts on feed (most urgent)")
	await _snap("menu")
	await _press(1)
	await _sec(0.6)
	await _snap("feeding")
	await _until_idle()
	await _snap("after_feed")

	# Clean: cursor should now start on clean (the most urgent sad ring need).
	await _press(0)
	_check(_scene.get("_cursor") == 1, "cursor starts on clean")
	await _press(1)
	await _sec(0.7)
	await _snap("cleaning")
	await _until_idle()

	# Play: nothing in the ring is sad now, so the cursor sits on 0. Press C to wrap to play.
	await _press(0)
	await _press(2)
	_check(_scene.get("_cursor") == 2, "C wraps the cursor back to play")
	await _press(1)
	for r in 3:
		await _until_state("PLAYING")
		if r == 0:
			await _snap("play_guess")
		await _press(0 if r % 2 == 0 else 2)
		await _sec(0.3)
		if r == 0:
			await _snap("play_reveal")
	await _until_idle()

	# Lights: B in IDLE while sleepy.
	await _snap("idle_sleepy")
	await _press(1)
	await _sec(1.0)
	await _snap("lights_out")
	await _until_idle()
	await _sec(0.5)
	var needs: Object = _scene.get("_needs")
	_check(needs.call("all_addressed"), "all needs addressed after 4 actions")
	await _snap("done_for_today")

	# Time skip: needs decay back to sad and the attention beat fires.
	for k in 4:
		_scene.get("_clock").call("skip_hours", 6.0)
	await _sec(0.7)
	await _snap("after_24h")
	print("SLICE DRIVE: done, %d shots in %s" % [_shot, _out])
	quit(0)


func _state() -> String:
	return str(_scene.get("State").keys()[_scene.get("_state")])


func _press(i: int) -> void:
	_scene.call("_on_button_down", i)
	await _sec(0.08)
	_scene.call("_on_button_up", i)
	await _sec(0.12)


func _until_idle() -> void:
	await _until_state("IDLE")


func _until_state(s: String) -> void:
	var waited := 0.0
	while _state() != s and waited < 15.0:
		await process_frame
		waited += 1.0 / 60.0
	if _state() != s:
		push_error("SLICE DRIVE: timed out waiting for %s (now %s)" % [s, _state()])


func _sec(t: float) -> void:
	await create_timer(t).timeout


func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	_shot += 1
	var path := "%s/%02d_%s.png" % [_out, _shot, label]
	root.get_texture().get_image().save_png(path)


func _check(ok: bool, what: String) -> void:
	print("SLICE DRIVE: %s %s" % ["PASS" if ok else "FAIL", what])
