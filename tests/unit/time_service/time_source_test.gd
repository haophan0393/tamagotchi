## Executable specification for the [TimeSource] abstraction and its
## [FakeTimeSource] test double.
##
## Story: production/epics/time-service/story-001-time-source-abstraction.md
## Requirement: TR-time-service-002 (docs/architecture/tr-registry.yaml)
## ADR: docs/architecture/adr-0001-time-and-event-injection.md §1
##
## Every test below names the QA test case (AC-1..AC-5) it encodes. Do not
## invent new test cases here — see the story's "developer implements against
## these" instruction.
##
## [SystemTimeSource] gets no unit test here: it reads the real clock, which
## would break the determinism rule. It is covered by the `clock-discipline`
## CI lint (AC-6) and by Story 005 on device.
class_name TimeSourceTest
extends GdUnitTestSuite


#region Test doubles
## AC-4 / ADR-0001 Verification #5 — an inner class inside a test suite can
## subclass [TimeSource] and behaves identically to a top-level [class_name]
## subclass. Verified locally on 4.7.1 before this file was written.
class StubSource:
	extends TimeSource

	var _now: int
	var _tz_bias_minutes: int

	func _init(now: int, tz_bias_minutes: int) -> void:
		_now = now
		_tz_bias_minutes = tz_bias_minutes

	func get_unix_time() -> int:
		return _now

	func get_timezone_bias_minutes() -> int:
		return _tz_bias_minutes
#endregion


#region AC-1: FakeTimeSource reports the injected time and bias
func test_get_unix_time_returns_injected_time() -> void:
	var source := FakeTimeSource.new(1000, 540)

	assert_int(source.get_unix_time()).is_equal(1000)


func test_get_timezone_bias_minutes_returns_injected_bias() -> void:
	var source := FakeTimeSource.new(1000, 540)

	assert_int(source.get_timezone_bias_minutes()).is_equal(540)


## Edge case: default bias is 0 when omitted.
func test_get_timezone_bias_minutes_defaults_to_zero_when_omitted() -> void:
	var source := FakeTimeSource.new(1000)

	assert_int(source.get_timezone_bias_minutes()).is_equal(0)


## Edge case: a negative bias (west of UTC) round-trips unchanged.
func test_get_timezone_bias_minutes_returns_negative_bias() -> void:
	var source := FakeTimeSource.new(1000, -480)

	assert_int(source.get_timezone_bias_minutes()).is_equal(-480)


## "Settable now and bias" — set_now() can move the clock backwards.
func test_set_now_replaces_injected_time() -> void:
	var source := FakeTimeSource.new(1000)

	source.set_now(500)

	assert_int(source.get_unix_time()).is_equal(500)


## "Settable now and bias" — set_bias_minutes() changes the timezone mid-test.
func test_set_bias_minutes_replaces_injected_bias() -> void:
	var source := FakeTimeSource.new(1000, 540)

	source.set_bias_minutes(-480)

	assert_int(source.get_timezone_bias_minutes()).is_equal(-480)
#endregion


#region AC-2: advance() moves the fake clock forward
func test_advance_moves_the_clock_forward() -> void:
	var source := FakeTimeSource.new(1000)

	source.advance(1)
	source.advance(299)

	assert_int(source.get_unix_time()).is_equal(1300)


## Edge case: advance(0) leaves time unchanged.
func test_advance_zero_leaves_time_unchanged() -> void:
	var source := FakeTimeSource.new(1000)

	source.advance(0)

	assert_int(source.get_unix_time()).is_equal(1000)
#endregion


#region AC-3: FakeTimeSource is a TimeSource
func test_fake_time_source_is_a_time_source() -> void:
	var source := FakeTimeSource.new(1000)

	assert_bool(source is TimeSource).is_true()
#endregion


#region AC-4: an inner class can subclass TimeSource
func test_inner_class_subclass_reports_unchanged_values() -> void:
	var source: TimeSource = StubSource.new(2000, -480)

	assert_bool(source is StubSource).is_true()
	assert_int(source.get_unix_time()).is_equal(2000)
	assert_int(source.get_timezone_bias_minutes()).is_equal(-480)
#endregion


#region AC-5: TimeSource itself cannot be used directly
## @abstract path taken (ADR-0001 Verification #4 passed). Verified locally on
## 4.7.1: a statically-typed `TimeSource.new()` is a compile-time
## `Parse Error: Cannot construct abstract class "TimeSource"`. Per the story,
## this is covered by code review, not a runtime test — no test in this suite
## calls `TimeSource.new()`.
#endregion
