## Executable specification for the Pet Definition Data enums and the
## [DefinitionResource] immutability base.
##
## Story: production/epics/pet-definition-data/story-001-enums-and-definition-base.md
## Requirements: TR-pet-definition-data-001, TR-pet-definition-data-003
## (docs/architecture/tr-registry.yaml)
## ADR: docs/architecture/adr-0002-pet-catalog-loading-and-immutability.md §1-2
##
## Every test below names the QA test case (AC-1..AC-7) it encodes. Do not
## invent new test cases here — see the story's "developer implements against
## these" instruction. AC-4..AC-7 are ADR-0002 Verification probes #1-#4 and
## stay in the suite as permanent regression tests.
class_name DefinitionResourceTest
extends GdUnitTestSuite

const PROBE_TRES_PATH := "res://tests/fixtures/pet_data/probe_definition.tres"


#region AC-1: exactly four of each enum, in order
func test_need_id_has_exactly_four_values_in_order() -> void:
	assert_array(Need.Id.keys()).is_equal(["HUNGER", "CLEANLINESS", "FUN", "SLEEP"])


func test_care_action_id_has_exactly_four_values_in_order() -> void:
	assert_array(CareAction.Id.keys()).is_equal(["FEED", "CLEAN", "PLAY", "LIGHTS"])


func test_life_stage_id_has_exactly_four_values_in_order() -> void:
	assert_array(LifeStage.Id.keys()).is_equal(["EGG", "BABY", "CHILD", "ADULT"])
#endregion


#region AC-2: _reject_write gates on the lock
## Counts PUSH_ERROR entries captured by [param logger].
func _push_error_count(logger: GodotGdErrorMonitor.GdUnitLogger) -> int:
	var count := 0
	for entry: ErrorLogEntry in logger.entries():
		if entry._type == ErrorLogEntry.TYPE.PUSH_ERROR:
			count += 1
	return count


func test_reject_write_gates_on_the_lock() -> void:
	var probe := ProbeDefinition.new()

	probe.value = 5
	assert_int(probe.value).is_equal(5)

	probe.lock()
	# A second logger counts every push_error, because is_push_error() only
	# proves that at least one matching error was logged.
	var counter := GodotGdErrorMonitor.GdUnitLogger.new(true, true)
	await assert_error(func() -> void: probe.value = 9).is_push_error(
		"Definition is immutable after catalog Ready: .value"
	)
	OS.remove_logger(counter)

	assert_int(_push_error_count(counter)).is_equal(1)
	assert_int(probe.value).is_equal(5)


## AC-2 — the error names the definition's resource_path when it has one.
func test_reject_write_error_names_resource_path_of_loaded_definition() -> void:
	# CACHE_MODE_IGNORE gives this test its own instance, so locking it cannot
	# leak into the shared cached copy other tests load.
	var probe: ProbeDefinition = ResourceLoader.load(
		PROBE_TRES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	probe.lock()

	await assert_error(func() -> void: probe.value = 9).is_push_error(
		"Definition is immutable after catalog Ready: %s.value" % probe.resource_path
	)
	assert_str(probe.resource_path).is_not_empty()
	assert_int(probe.value).is_equal(42)
#endregion


#region AC-3: lock() recurses and freezes arrays
func test_lock_recurses_into_nested_definition_and_freezes_arrays() -> void:
	var nested := ProbeDefinition.new()
	nested.value = 1
	var item_a := ProbeDefinition.new()
	var item_b := ProbeDefinition.new()
	var container := ProbeContainerDefinition.new()
	container.nested = nested
	container.items = [item_a, item_b]

	container.lock()

	# The nested object rejects writes.
	await assert_error(func() -> void: nested.value = 99).is_push_error(
		"Definition is immutable after catalog Ready: .value"
	)
	assert_int(nested.value).is_equal(1)

	# Both array elements reject writes.
	await assert_error(func() -> void: item_a.value = 99).is_push_error(
		"Definition is immutable after catalog Ready: .value"
	)
	await assert_error(func() -> void: item_b.value = 99).is_push_error(
		"Definition is immutable after catalog Ready: .value"
	)

	# append() on the locked array leaves its size unchanged. The captured
	# push_error message is the engine's raw ERR_FAIL_COND_MSG condition text,
	# not the human-readable rationale printed to console — see
	# Verification #4's test for the full explanation.
	await assert_error(func() -> void: container.items.append(ProbeDefinition.new())).is_push_error(
		"Condition \"_p->read_only\" is true."
	)
	assert_int(container.items.size()).is_equal(2)


## AC-3 edge case — calling lock() twice raises no error.
func test_lock_called_twice_raises_no_error() -> void:
	var container := ProbeContainerDefinition.new()
	container.nested = ProbeDefinition.new()
	container.items = [ProbeDefinition.new()]

	container.lock()

	await assert_error(func() -> void: container.lock()).is_success()


## AC-3 edge case — a definition reachable from itself locks without
## recursing forever.
func test_lock_on_cyclic_graph_terminates_and_locks() -> void:
	var container := ProbeContainerDefinition.new()
	container.nested = container
	container.items = [container]

	await assert_error(func() -> void: container.lock()).is_success()

	await assert_error(func() -> void: container.nested = null).is_push_error(
		"Definition is immutable after catalog Ready: .nested"
	)
	assert_object(container.nested).is_same(container)

	# Break the reference cycle so the RefCounted graph is freed.
	container._locked = false
	container.nested = null
	container.items = []


## AC-3 edge case — a null nested definition is skipped without error.
func test_lock_with_null_nested_definition_raises_no_error() -> void:
	var container := ProbeContainerDefinition.new()

	await assert_error(func() -> void: container.lock()).is_success()
	assert_object(container.nested).is_null()


## AC-3 edge case — an array of non-definition values is made read-only and
## its elements are skipped.
func test_lock_freezes_non_definition_array() -> void:
	var container := ProbeContainerDefinition.new()
	container.tags = [&"a", &"b"]

	await assert_error(func() -> void: container.lock()).is_success()

	await assert_error(func() -> void: container.tags.append(&"c")).is_push_error(
		"Condition \"_p->read_only\" is true."
	)
	assert_array(container.tags).is_equal([&"a", &"b"])


## AC-3 edge case — an empty array is locked without error.
func test_lock_with_empty_array_field_raises_no_error() -> void:
	var container := ProbeContainerDefinition.new()
	container.items = []

	await assert_error(func() -> void: container.lock()).is_success()
	assert_int(container.items.size()).is_equal(0)
#endregion


#region AC-4 / ADR-0002 Verification #1
## ResourceLoader runs @export property setters while loading a .tres, and
## _locked is still false at that point — the storage path goes through the
## guarded setter, not a raw field write.
func test_verification_1_resource_loader_runs_setter_while_unlocked() -> void:
	var probe: ProbeDefinition = ResourceLoader.load(
		PROBE_TRES_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	)

	assert_bool(probe._locked).is_false()
	assert_int(probe.setter_call_count).is_equal(1)
	assert_int(probe.value).is_equal(42)
#endregion


#region AC-5 / ADR-0002 Verification #2
## Object.set(&"field", v) on a locked definition goes through the GDScript
## setter and is rejected — dynamic writes are not a bypass.
func test_verification_2_object_set_on_locked_definition_is_rejected() -> void:
	var probe := ProbeDefinition.new()
	probe.value = 5
	probe.lock()

	await assert_error(func() -> void: probe.set(&"value", 9)).is_push_error(
		"Definition is immutable after catalog Ready: .value"
	)
	assert_int(probe.value).is_equal(5)
#endregion


#region AC-6 / ADR-0002 Verification #3
## A Dictionary keyed by StringName resolves when looked up through a
## function whose parameter is typed StringName and called with a String
## literal — the typed parameter converts it (godot#62957).
func _lookup_by_id(index: Dictionary, id: StringName) -> Variant:
	return index.get(id)


func test_verification_3_string_name_keyed_dictionary_resolves_string_literal() -> void:
	var index: Dictionary = {}
	index[StringName("bloop")] = "found"

	var result: Variant = _lookup_by_id(index, "bloop")

	assert_str(result).is_equal("found")
#endregion


#region AC-7 / ADR-0002 Verification #4
## Array[T].make_read_only() rejects append(), indexed assignment and sort(),
## each logging an error and leaving the array unchanged, and none of them
## crash the process. Exact error text confirmed locally on 4.7.1
## (see story completion notes): [code]append()[/code] and [code]sort()[/code]
## are C++-side [code]ERR_FAIL_COND_MSG[/code] rejections — the console prints
## their human-readable rationale ("Array is in read-only state."), but the
## [code]message[/code] gdUnit4's logger actually captures (and the only
## field [method GdUnitGodotErrorAssert.is_push_error] matches against) is
## the raw condition text, [code]Condition "_p->read_only" is true.[/code]
## Indexed assignment instead raises a GDScript VM-level runtime error, whose
## full human-readable text [i]is[/i] the captured message, asserted with
## [method GdUnitGodotErrorAssert.is_runtime_error]. All three are non-fatal —
## confirmed by the unchanged array after every attempt.
func test_verification_4_read_only_array_rejects_mutators_without_crashing() -> void:
	var arr: Array[int] = [1, 2, 3]
	arr.make_read_only()

	await assert_error(func() -> void: arr.append(4)).is_push_error(
		"Condition \"_p->read_only\" is true."
	)
	assert_array(arr).is_equal([1, 2, 3])

	await assert_error(func() -> void: arr[0] = 99).is_runtime_error(
		"Invalid assignment on read-only value (on base: 'Array[int]')."
	)
	assert_array(arr).is_equal([1, 2, 3])

	await assert_error(func() -> void: arr.sort()).is_push_error(
		"Condition \"_p->read_only\" is true."
	)
	assert_array(arr).is_equal([1, 2, 3])
#endregion
