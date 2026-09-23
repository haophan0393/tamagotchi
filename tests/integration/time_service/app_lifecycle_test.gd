## Integration coverage for the AppLifecycle adapter and its wiring into
## GameRoot (Story 004, TR-time-service-005, ADR-0001 §4).
##
## Determinism: every test below delivers OS lifecycle notifications directly
## via [method Node.notification] — no real OS event, no engine [Timer], no
## wall-clock read. Signal emissions are counted with plain connected
## closures rather than gdUnit4's [code]assert_signal[/code] wait-until-
## timeout helper, so "emitted exactly once" is an exact synchronous count,
## not a bounded real-time wait (coding-standards.md: no time-dependent
## assertions).
##
## AC-6 (GameRoot wiring) spies on [code]GameRoot.tscn[/code] itself
## ([method GdUnitTestSuite.spy]) rather than adding test-only counters to
## production code, per the story's suggested approach.
class_name AppLifecycleTest
extends GdUnitTestSuite


## Connects a fresh counter dictionary to [param lifecycle]'s two signals and
## returns it; callers assert against [code]counts.backgrounded[/code] and
## [code]counts.resumed[/code] after delivering notifications.
func _counts(lifecycle: AppLifecycle) -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {"backgrounded": 0, "resumed": 0}
	lifecycle.app_backgrounded.connect(func() -> void: counts.backgrounded += 1)
	lifecycle.app_resumed.connect(func() -> void: counts.resumed += 1)
	return counts


#region AC-1 — background translation, single notification
func test_paused_alone_emits_app_backgrounded_once() -> void:
	var lifecycle: AppLifecycle = auto_free(AppLifecycle.new())
	var counts := _counts(lifecycle)

	lifecycle.notification(NOTIFICATION_APPLICATION_PAUSED)

	assert_int(counts.backgrounded).is_equal(1)
	assert_int(counts.resumed).is_equal(0)


func test_focus_out_alone_emits_app_backgrounded_once() -> void:
	var lifecycle: AppLifecycle = auto_free(AppLifecycle.new())
	var counts := _counts(lifecycle)

	lifecycle.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)

	assert_int(counts.backgrounded).is_equal(1)
	assert_int(counts.resumed).is_equal(0)
#endregion


#region AC-2 — double delivery is edge-detected, either order
func test_paused_then_focus_out_emits_app_backgrounded_once() -> void:
	var lifecycle: AppLifecycle = auto_free(AppLifecycle.new())
	var counts := _counts(lifecycle)

	lifecycle.notification(NOTIFICATION_APPLICATION_PAUSED)
	lifecycle.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)

	assert_int(counts.backgrounded).is_equal(1)


func test_focus_out_then_paused_emits_app_backgrounded_once() -> void:
	var lifecycle: AppLifecycle = auto_free(AppLifecycle.new())
	var counts := _counts(lifecycle)

	lifecycle.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	lifecycle.notification(NOTIFICATION_APPLICATION_PAUSED)

	assert_int(counts.backgrounded).is_equal(1)
#endregion


#region AC-3 — resume translation, after a background
func test_resumed_then_focus_in_after_paused_emits_app_resumed_once() -> void:
	var lifecycle: AppLifecycle = auto_free(AppLifecycle.new())
	var counts := _counts(lifecycle)

	lifecycle.notification(NOTIFICATION_APPLICATION_PAUSED)
	lifecycle.notification(NOTIFICATION_APPLICATION_RESUMED)
	lifecycle.notification(NOTIFICATION_APPLICATION_FOCUS_IN)

	assert_int(counts.backgrounded).is_equal(1)
	assert_int(counts.resumed).is_equal(1)


func test_focus_in_then_resumed_after_paused_emits_app_resumed_once() -> void:
	var lifecycle: AppLifecycle = auto_free(AppLifecycle.new())
	var counts := _counts(lifecycle)

	lifecycle.notification(NOTIFICATION_APPLICATION_PAUSED)
	lifecycle.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	lifecycle.notification(NOTIFICATION_APPLICATION_RESUMED)

	assert_int(counts.backgrounded).is_equal(1)
	assert_int(counts.resumed).is_equal(1)
#endregion


#region AC-4 — no resume without a background
func test_focus_in_then_resumed_without_prior_background_emits_nothing() -> void:
	var lifecycle: AppLifecycle = auto_free(AppLifecycle.new())
	var counts := _counts(lifecycle)

	lifecycle.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	lifecycle.notification(NOTIFICATION_APPLICATION_RESUMED)

	assert_int(counts.backgrounded).is_equal(0)
	assert_int(counts.resumed).is_equal(0)
#endregion


#region AC-5 — full cycle repeats, alternating
func test_full_background_resume_cycle_repeats_alternating() -> void:
	var lifecycle: AppLifecycle = auto_free(AppLifecycle.new())
	var counts := _counts(lifecycle)

	lifecycle.notification(NOTIFICATION_APPLICATION_PAUSED)   # background 1
	lifecycle.notification(NOTIFICATION_APPLICATION_RESUMED)  # resume 1
	lifecycle.notification(NOTIFICATION_APPLICATION_PAUSED)   # background 2
	lifecycle.notification(NOTIFICATION_APPLICATION_RESUMED)  # resume 2

	assert_int(counts.backgrounded).is_equal(2)
	assert_int(counts.resumed).is_equal(2)
#endregion


#region AC-6 — GameRoot wiring
## GameRoot.tscn's AppLifecycle child, when it receives PAUSED then RESUMED,
## runs GameRoot._on_app_backgrounded() and _on_app_resumed() exactly once
## each, with no errors. Spies on the whole scene rather than adding
## test-only counters to production code (story's suggested approach).
func test_game_root_wiring_invokes_background_and_resume_handlers_once() -> void:
	var game_root: Node = spy("res://src/core/app/GameRoot.tscn")

	await assert_error(func() -> void:
		add_child(auto_free(game_root))
	).is_success()

	var app_lifecycle: AppLifecycle = game_root.get_node("AppLifecycle")
	assert_object(app_lifecycle).is_not_null()

	await assert_error(func() -> void:
		app_lifecycle.notification(NOTIFICATION_APPLICATION_PAUSED)
		app_lifecycle.notification(NOTIFICATION_APPLICATION_RESUMED)
	).is_success()

	verify(game_root)._on_app_backgrounded()
	verify(game_root)._on_app_resumed()
#endregion
