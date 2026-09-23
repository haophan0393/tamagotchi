## Abstract clock contract injected into [TimeService].
##
## Verified locally on Godot 4.7.1 (ADR-0001 Verification #4, 2026-09-23):
## a body-less [code]@abstract func[/code] compiles and can be subclassed by
## both an external [code]class_name[/code] script and an inner class
## (Verification #5); a statically-typed [code]TimeSource.new()[/code] is a
## compile-time [code]Parse Error: Cannot construct abstract class[/code], so
## no fallback is needed here.
##
## [b]Do not call an engine clock API anywhere except
## [code]src/core/time/system_time_source.gd[/code][/b] — enforced by the
## [code]clock-discipline[/code] CI job.
##
## [b]Example[/b] (a test double; see [code]tests/helpers/fake_time_source.gd[/code]):
## [codeblock]
## var source := FakeTimeSource.new(1000, 540)
## var service := TimeService.new(source)
## [/codeblock]
@abstract
class_name TimeSource extends RefCounted

## Returns the current UTC epoch time, in whole seconds.
@abstract func get_unix_time() -> int

## Returns the current local UTC offset, in minutes **east** of UTC
## (e.g. Tokyo is [code]540[/code], Los Angeles is [code]-480[/code]).
@abstract func get_timezone_bias_minutes() -> int
