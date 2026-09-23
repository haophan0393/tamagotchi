## Integration coverage for the TimeProvider Autoload and GameRoot composition
## root (Story 003, TR-time-service-003, ADR-0001 §2).
##
## gdUnit4's headless runner (tests/gdunit4_runner.gd) loads project Autoloads,
## so these tests read [code]TimeProvider[/code] directly — no test-only
## substitute is needed (Story 003 Engine Notes).
##
## Determinism: every assertion below compares identity ([method
## GdUnitObjectAssert.is_same]) and type, never a time value — this suite
## proves wiring, not clock behaviour (that's time_service_contract_test.gd).
class_name TimeProviderTest
extends GdUnitTestSuite


## Captures [code]TimeProvider.service[/code] from inside its own
## [code]_ready()[/code], so AC-1's reads genuinely come from scene-tree nodes.
class ServiceReader extends Node:
	var read_in_ready: TimeService

	func _ready() -> void:
		read_in_ready = TimeProvider.service


## AC-1 — on boot, TimeProvider exposes exactly one TimeService instance
## wired to SystemTimeSource, reachable from any scene-tree node without
## constructing its own. Edge case: the service is already non-null in a
## node's [code]_ready()[/code], because TimeProvider builds it in
## [code]_init()[/code].
func test_time_provider_service_is_one_shared_time_service_on_system_time_source() -> void:
	var reader_a: ServiceReader = auto_free(ServiceReader.new())
	var reader_b: ServiceReader = auto_free(ServiceReader.new())

	add_child(reader_a)
	add_child(reader_b)

	assert_object(reader_a.read_in_ready).is_not_null()
	assert_bool(reader_a.read_in_ready is TimeService).is_true()
	assert_object(reader_a.read_in_ready).is_same(reader_b.read_in_ready)

	# TimeService._source has no public accessor (TR-time-service-002 keeps
	# TimeService stateless besides the injected source); read it by name
	# rather than adding one, per Story 003's stated preference.
	assert_bool(reader_a.read_in_ready.get("_source") is SystemTimeSource).is_true()


## AC-2 — TimeProvider.service is read-only: assigning to it is rejected, the
## original instance is left in place, and an error is logged.
func test_time_provider_service_assignment_rejected_and_instance_unchanged() -> void:
	var original: TimeService = TimeProvider.service

	await assert_error(func() -> void:
		TimeProvider.service = TimeService.new(SystemTimeSource.new())
	).is_push_error("TimeProvider.service is read-only; ignoring assignment.")

	assert_object(TimeProvider.service).is_same(original)


## AC-3 — GameRoot.tscn instantiates and adds to the tree with no pushed errors
## or warnings (asserted, since gdUnit4 does not fail on push_error by default), and
## _ready() has stored the same TimeService instance TimeProvider exposes.
func test_game_root_ready_holds_the_time_provider_service_instance() -> void:
	var game_root := auto_free(
		load("res://src/core/app/GameRoot.tscn").instantiate()
	) as GameRoot
	assert_object(game_root).is_not_null()

	await assert_error(func() -> void:
		add_child(game_root)
	).is_success()

	assert_object(game_root.time_service).is_not_null()
	assert_object(game_root.time_service).is_same(TimeProvider.service)
