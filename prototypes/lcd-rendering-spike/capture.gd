## Automated screenshot + metrics capture for the LCD spike.
##
## Usage: godot --script capture.gd --  <out_dir>
##
## Loads main.tscn, switches to each approach in turn, lets it settle, then
## saves a PNG and records averaged metrics. Produces the visual evidence the
## spike verdict rests on — a rendering decision cannot be made from numbers
## alone, and it cannot be made headlessly either.
extends SceneTree

const SETTLE_FRAMES := 90
const MEASURE_FRAMES := 240

var _out_dir := "res://captures"
## When >= 0, measure only this approach. Each approach is measured in its own
## process so shader-compile warmup and render-target churn from an earlier
## approach cannot be charged to a later one.
var _only := -1
## Forces approach B to repaint every frame — its realistic worst case.
var _stress := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	if args.size() > 1:
		_only = args[1].to_int()
	if args.size() > 2:
		_stress = args[2] == "stress"
	_run.call_deferred()


func _run() -> void:
	# Uncap the frame rate, or every approach reports the same vsync-limited
	# number and the comparison measures the display, not the renderer.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var packed: PackedScene = load("res://main.tscn")
	var scene: Node = packed.instantiate()
	root.add_child(scene)

	# Give the scene a frame to run _ready() and build its art.
	await process_frame
	await process_frame

	var results: Array[Dictionary] = []

	for approach in 3:
		if _only >= 0 and approach != _only:
			continue
		scene.call("_set_approach", approach)
		scene.set("stress_repaint", _stress)

		for i in SETTLE_FRAMES:
			await process_frame

		# Measure over a window so a single hitchy frame does not decide anything.
		# Wall-clock frame delta is the honest metric here: TIME_PROCESS excludes
		# the rendering work that is exactly what this spike is comparing.
		var peak_draw_calls := 0
		var t_start := Time.get_ticks_usec()
		for i in MEASURE_FRAMES:
			await process_frame
			peak_draw_calls = maxi(
				peak_draw_calls,
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			)
		var total_time := float(Time.get_ticks_usec() - t_start) / 1_000_000.0

		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var name: String = scene.get("APPROACH_NAMES")[approach]
		if _stress:
			name += " [stress]"
		var slug := name.split(" ")[0].to_lower()
		var path := "%s/lcd_%s.png" % [_out_dir, slug]
		img.save_png(path)

		results.append({
			"approach": name,
			"avg_frame_ms": (total_time / MEASURE_FRAMES) * 1000.0,
			"fps": float(MEASURE_FRAMES) / maxf(total_time, 0.0001),
			"peak_draw_calls": peak_draw_calls,
			"png": path,
		})

	print("\n=== LCD SPIKE METRICS ===")
	for r: Dictionary in results:
		print("%-24s  frame %6.3f ms   %6.1f fps   peak draw calls %3d   -> %s" % [
			r["approach"], r["avg_frame_ms"], r["fps"], r["peak_draw_calls"], r["png"]
		])
	print("=========================\n")
	quit(0)
