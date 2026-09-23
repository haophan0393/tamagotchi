## Test-only injectable clock. Never lives under `src/` (ADR-0001 §1 guardrail).
##
## Settable time and timezone bias, plus [method advance] to move the clock
## forward without a real sleep — see `.claude/docs/coding-standards.md`
## ("no time-dependent assertions").
##
## [b]Example[/b]:
## [codeblock]
## var source := FakeTimeSource.new(1000, 540)
## source.advance(300)
## assert_int(source.get_unix_time()).is_equal(1300)
## [/codeblock]
class_name FakeTimeSource extends TimeSource

var _now: int
var _tz_bias_minutes: int

## Constructs a fake clock reporting [param now] with [param tz_bias_minutes]
## minutes east of UTC (defaults to UTC, i.e. [code]0[/code]).
func _init(now: int, tz_bias_minutes: int = 0) -> void:
	_now = now
	_tz_bias_minutes = tz_bias_minutes

## Returns the injected time.
func get_unix_time() -> int:
	return _now

## Returns the injected timezone bias, in minutes east of UTC.
func get_timezone_bias_minutes() -> int:
	return _tz_bias_minutes

## Sets the injected time to [param now]. Unlike [method advance], this can move
## the clock backwards — use it to simulate a rolled-back device clock.
func set_now(now: int) -> void:
	_now = now

## Sets the injected timezone bias to [param tz_bias_minutes] minutes east of UTC —
## use it to simulate the player changing timezone mid-test.
func set_bias_minutes(tz_bias_minutes: int) -> void:
	_tz_bias_minutes = tz_bias_minutes

## Moves the injected clock forward by [param seconds].
func advance(seconds: int) -> void:
	_now += seconds
