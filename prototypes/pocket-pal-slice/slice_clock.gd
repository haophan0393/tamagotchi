# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does the 30-second loop make the pet feel alive and glad
#   to see me, and is the 3-button ring learnable with no text?
# Date: 2026-09-25
#
# Accelerated game clock. Stands in for Time Service (ADR-0001) so decay is
# visible within one play session.
class_name SliceClock
extends RefCounted

var _base_unix: float
var _start_msec: int
var _skip_sec := 0.0


func _init() -> void:
	_base_unix = Time.get_unix_time_from_system()
	_start_msec = Time.get_ticks_msec()


## Game time in UTC seconds, running at [constant SliceConfig.TIME_SCALE].
func now() -> float:
	var real_elapsed := (Time.get_ticks_msec() - _start_msec) / 1000.0
	return _base_unix + real_elapsed * SliceConfig.TIME_SCALE + _skip_sec


## Debug: jump the clock forward.
func skip_hours(hours: float) -> void:
	_skip_sec += hours * 3600.0


## Game hours since the slice started (for the debug readout).
func elapsed_game_hours() -> float:
	return (now() - _base_unix) / 3600.0
