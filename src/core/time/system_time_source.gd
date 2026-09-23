## The only file permitted to call engine clock APIs.
##
## The [code]clock-discipline[/code] CI job (`.github/workflows/tests.yml`)
## greps `src/` for direct engine clock reads and exempts this exact path.
## Never call [code]Time.*_from_system()[/code] or [code]OS.get_datetime()[/code]
## anywhere else under `src/` — route every read through the injected
## [TimeSource] instead.
##
## [b]Example[/b] (composition root only — see ADR-0001 §2; this class is never
## constructed from gameplay code):
## [codeblock]
## var service := TimeService.new(SystemTimeSource.new())
## [/codeblock]
class_name SystemTimeSource extends TimeSource

## Returns the current UTC epoch time, in whole seconds, read from the system clock.
func get_unix_time() -> int:
	return floori(Time.get_unix_time_from_system())

## Returns the current local UTC offset, in minutes east of UTC, read from the
## system clock. Godot's `bias` sign convention is not documented as consistent
## across platforms (godotengine/godot#37571) — the per-platform sign is
## verified on device in Story 005, which may add an `OS.get_name()` branch.
## Do not flip the sign here; the [TimeSource] contract (minutes east) is
## unaffected either way.
func get_timezone_bias_minutes() -> int:
	return Time.get_time_zone_from_system().bias
