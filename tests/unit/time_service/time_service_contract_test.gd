## Executable specification for the Time Service contract.
##
## GDD: design/gdd/time-service.md — every test below names the Acceptance
## Criterion it encodes. Formulas: elapsed_seconds, is_new_calendar_day
## (design/registry/entities.yaml).
##
## [b]Status: specification-first.[/b] Time Service has no production
## implementation yet — it is scheduled for the Foundation-layer /dev-story pass.
## Until then the reference implementation lives in this file as the
## [code]RefTimeService[/code] inner class, which
## encodes the contract exactly as the GDD specifies it.
##
## [b]When the real Time Service lands[/b], the /dev-story pass changes ONE line —
## the [code]ServiceUnderTest[/code] constant below — to preload the production
## script. Every assertion carries over unchanged. Do not fork these tests.
##
## Determinism (AC #9): no test here touches the real wall clock. Every instance
## is constructed with a FakeTimeSource whose time AND timezone offset are both
## injected, so results are identical on any machine in any timezone. The
## companion half of AC #9 — proving no *other* system reads the clock directly —
## is a CI lint gate in .github/workflows/tests.yml, not a test.
class_name TimeServiceContractTest
extends GdUnitTestSuite


## The implementation under test. Swap this to the production script when it exists.
const ServiceUnderTest := RefTimeService

## 2026-09-18 11:58:00 PM in a UTC+0 locale, as a UTC unix epoch.
const SEP_18_2358_UTC := 1789775880
## 2026-09-19 12:02:00 AM in a UTC+0 locale — 4 minutes later, across local midnight.
const SEP_19_0002_UTC := 1789776120

## Fixed offsets used to prove timezone independence. Minutes east of UTC.
const TZ_UTC := 0
const TZ_TOKYO := 540
const TZ_LOS_ANGELES := -480


#region Test doubles
## FakeTimeSource is the shared test double in tests/helpers/fake_time_source.gd
## (removed from here in time-service Story 001 — a same-named inner class is a
## parse error once the global class_name exists).


## Reference implementation of the GDD's four operations. Stateless per call.
class RefTimeService:
	extends RefCounted

	var _source: FakeTimeSource

	func _init(source: FakeTimeSource) -> void:
		_source = source

	func get_now_utc() -> int:
		return _source.get_unix_time()

	func get_elapsed_seconds(since_utc: int) -> int:
		return maxi(0, get_now_utc() - since_utc)

	func get_local_calendar_date(utc_timestamp: int) -> Dictionary:
		var local := utc_timestamp + _source.get_timezone_bias_minutes() * 60
		var dt := Time.get_datetime_dict_from_unix_time(local)
		return {"year": dt.year, "month": dt.month, "day": dt.day}

	func is_new_calendar_day(last_utc: int, current_utc: int) -> bool:
		return get_local_calendar_date(last_utc) != get_local_calendar_date(current_utc)
#endregion


## Builds a service wired to a fake clock at [param now] in timezone [param tz_bias].
func _service_at(now: int, tz_bias: int = TZ_UTC) -> RefTimeService:
	return ServiceUnderTest.new(FakeTimeSource.new(now, tz_bias))


#region get_now_utc
## AC #1 — a fake clock set to 1000 reports exactly 1000.
func test_get_now_utc_returns_injected_time() -> void:
	assert_int(_service_at(1000).get_now_utc()).is_equal(1000)


## AC #2 (rewritten 2026-09-22) — monotonicity is proven by advancing the injected
## clock, never by sleeping. The original AC used a real one-second wall-clock
## sleep, which violates the determinism standard in
## .claude/docs/coding-standards.md ("no time-dependent assertions").
func test_get_now_utc_advances_with_the_injected_clock() -> void:
	var source := FakeTimeSource.new(1000)
	var service: RefTimeService = ServiceUnderTest.new(source)

	var first := service.get_now_utc()
	source.advance(1)
	var second := service.get_now_utc()

	assert_int(second).is_greater_equal(first + 1)
#endregion


#region get_elapsed_seconds
## AC #3 — ordinary forward elapse.
func test_get_elapsed_seconds_returns_difference() -> void:
	assert_int(_service_at(1300).get_elapsed_seconds(1000)).is_equal(300)


## AC #4 — a timestamp in the future (clock rollback, tampered device clock,
## corrupted save) clamps to 0 and never returns a negative duration.
func test_get_elapsed_seconds_clamps_rolled_back_clock_to_zero() -> void:
	assert_int(_service_at(1000).get_elapsed_seconds(1300)).is_equal(0)


## AC #5 — boundary: comparing against the current instant yields 0.
func test_get_elapsed_seconds_returns_zero_for_same_instant() -> void:
	assert_int(_service_at(1000).get_elapsed_seconds(1000)).is_equal(0)


## Edge case (GDD "elapsed spans multiple years") — no upper clamp lives here.
## MAX_OFFLINE is Offline Time Simulation's knob, not Time Service's.
func test_get_elapsed_seconds_applies_no_upper_bound() -> void:
	var three_years := 3 * 365 * 24 * 60 * 60
	assert_int(_service_at(1000 + three_years).get_elapsed_seconds(1000)).is_equal(three_years)
#endregion


#region is_new_calendar_day
## AC #6 — two instants on the same local date are not a new day.
func test_is_new_calendar_day_false_within_one_local_date() -> void:
	var service := _service_at(SEP_18_2358_UTC)
	assert_bool(service.is_new_calendar_day(SEP_18_2358_UTC, SEP_18_2358_UTC + 60)).is_false()


## AC #7 — the deliberate design choice: day boundaries are local calendar dates,
## not a rolling 24 hours. Four minutes across midnight IS a new day.
func test_is_new_calendar_day_true_across_local_midnight() -> void:
	var service := _service_at(SEP_19_0002_UTC)
	assert_bool(service.is_new_calendar_day(SEP_18_2358_UTC, SEP_19_0002_UTC)).is_true()


## AC #8 — a year-long gap is unambiguously a new day.
func test_is_new_calendar_day_true_across_a_full_year() -> void:
	var a_year := 365 * 24 * 60 * 60
	var service := _service_at(SEP_18_2358_UTC + a_year)
	assert_bool(service.is_new_calendar_day(SEP_18_2358_UTC, SEP_18_2358_UTC + a_year)).is_true()


## Edge case (GDD "player changes device time zone") — the SAME pair of UTC
## instants straddles midnight in UTC+0 but not in UTC+9, because the conversion
## always uses the current offset. This is the accepted trade-off, pinned as
## behaviour so a future refactor cannot silently change it.
func test_is_new_calendar_day_depends_on_current_timezone() -> void:
	var at_utc := _service_at(SEP_19_0002_UTC, TZ_UTC)
	var at_tokyo := _service_at(SEP_19_0002_UTC, TZ_TOKYO)

	assert_bool(at_utc.is_new_calendar_day(SEP_18_2358_UTC, SEP_19_0002_UTC)).is_true()
	assert_bool(at_tokyo.is_new_calendar_day(SEP_18_2358_UTC, SEP_19_0002_UTC)).is_false()
#endregion


#region Determinism (AC #9)
## AC #9 (rewritten 2026-09-22) — the original wording was unfalsifiable ("no
## other system reads the wall clock"). Its testable half is here: identical
## injected inputs must produce identical outputs, independent of the machine's
## real clock and real timezone. Its unfalsifiable half became a CI lint gate in
## .github/workflows/tests.yml that fails the build if Time.* or OS.*_time APIs
## appear outside the sanctioned SystemTimeSource.
func test_results_are_independent_of_real_wall_clock_and_timezone() -> void:
	var expected_elapsed := _service_at(1300).get_elapsed_seconds(1000)
	var expected_date := _service_at(SEP_18_2358_UTC).get_local_calendar_date(SEP_18_2358_UTC)

	# Re-deriving through services built in three different injected timezones
	# must not move elapsed seconds, and must not move a date read in the same zone.
	for tz: int in [TZ_UTC, TZ_TOKYO, TZ_LOS_ANGELES]:
		assert_int(_service_at(1300, tz).get_elapsed_seconds(1000)).is_equal(expected_elapsed)

	assert_dict(_service_at(SEP_18_2358_UTC).get_local_calendar_date(SEP_18_2358_UTC)) \
		.is_equal(expected_date)


## The fixtures themselves must be timezone-pinned, or every date assertion above
## would silently depend on the CI machine's locale.
func test_fixture_timestamps_land_on_their_documented_local_dates() -> void:
	assert_dict(_service_at(SEP_18_2358_UTC).get_local_calendar_date(SEP_18_2358_UTC)) \
		.is_equal({"year": 2026, "month": 9, "day": 18})
	assert_dict(_service_at(SEP_19_0002_UTC).get_local_calendar_date(SEP_19_0002_UTC)) \
		.is_equal({"year": 2026, "month": 9, "day": 19})
#endregion
