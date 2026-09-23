## Stateless clock and calendar operations, built on an injected [TimeSource].
##
## These four operations are the whole contract (TR-time-service-001) — this
## class holds nothing but the injected source and applies no gameplay policy
## of its own: no offline cap, no meaning for "a new day" beyond the local
## calendar date (TR-time-service-004; Core Rule 3). [method get_local_calendar_date]
## always converts using the [b]current[/b] timezone bias reported by the
## injected [TimeSource] — a timestamp minted under a different bias is not
## retroactively corrected, and daylight-saving time cannot be recovered from a
## bare epoch. Both are accepted limitations (ADR-0001 §1).
##
## [b]Example[/b]:
## [codeblock]
## var service := TimeService.new(SystemTimeSource.new())
## var elapsed := service.get_elapsed_seconds(last_save_utc)
## [/codeblock]
class_name TimeService extends RefCounted

var _source: TimeSource


## Constructs a service wired to [param source]. Only a composition root should
## construct this — logic classes receive it via their own [code]_init()[/code]
## (ADR-0001 §1-2). Never referenced from an Autoload or the scene tree.
func _init(source: TimeSource) -> void:
	_source = source


## Returns the current UTC epoch time, in whole seconds, as reported by the
## injected [TimeSource].
func get_now_utc() -> int:
	return _source.get_unix_time()


## Returns the whole seconds elapsed since [param since_utc], clamped to
## [code]0[/code] if [param since_utc] is in the future (e.g. a rolled-back
## device clock). No upper bound is applied — any cap on the result is a
## gameplay decision made elsewhere (TR-time-service-004).
func get_elapsed_seconds(since_utc: int) -> int:
	return maxi(0, get_now_utc() - since_utc)


## Converts [param utc_timestamp] to a local calendar date using the
## [b]current[/b] timezone bias from the injected [TimeSource], and returns
## [code]{"year": int, "month": int, "day": int}[/code]. Daylight-saving time
## cannot be recovered from a bare epoch — an accepted limitation (ADR-0001 §1).
func get_local_calendar_date(utc_timestamp: int) -> Dictionary:
	var local := utc_timestamp + _source.get_timezone_bias_minutes() * 60
	var dt := Time.get_datetime_dict_from_unix_time(local)
	return {"year": dt.year, "month": dt.month, "day": dt.day}


## Returns [code]true[/code] if [param last_utc] and [param current_utc] fall
## on different local calendar dates, per [method get_local_calendar_date].
func is_new_calendar_day(last_utc: int, current_utc: int) -> bool:
	return get_local_calendar_date(last_utc) != get_local_calendar_date(current_utc)
