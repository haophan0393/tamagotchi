# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does the 30-second loop make the pet feel alive and glad
#   to see me, and is the 3-button ring learnable with no text?
# Date: 2026-09-25
#
# The four needs, using Need System's anchor model (design/gdd/need-system.md,
# Formulas): value = clamp(anchor − decay × elapsed_h, floor, 100). Nothing is
# persisted. The slice has no save.
class_name SliceNeeds
extends RefCounted

## A need moved from content to sad since the last check (Core Rule 14).
signal need_became_sad(need: int)

var _clock: SliceClock
var _anchor_value: Dictionary = {}
var _anchor_time: Dictionary = {}
var _was_sad: Dictionary = {}


func _init(clock: SliceClock, start_values: Dictionary) -> void:
	_clock = clock
	var now := _clock.now()
	for need: int in SliceConfig.NEED_PROFILE:
		_anchor_value[need] = float(start_values.get(need, 100.0))
		_anchor_time[need] = now
		_was_sad[need] = is_sad(need)


## Current value of [param need] on the 0–100 scale.
func value(need: int) -> float:
	var p: Dictionary = SliceConfig.NEED_PROFILE[need]
	var elapsed_h := (_clock.now() - float(_anchor_time[need])) / 3600.0
	var v := float(_anchor_value[need]) - float(p["decay_per_hour"]) * elapsed_h
	return clampf(v, float(p["floor"]), 100.0)


## True for SAD and AT_FLOOR (Core Rule 10).
func is_sad(need: int) -> bool:
	var p: Dictionary = SliceConfig.NEED_PROFILE[need]
	return value(need) <= float(p["sad_threshold"])


## Re-anchors the target need upward (Core Rule 7). Legal on a full need.
func apply_care(action: int) -> void:
	var need: int = SliceConfig.ACTION_NEED[action]
	var p: Dictionary = SliceConfig.NEED_PROFILE[need]
	var restored := value(need) + float(SliceConfig.RESTORE_AMOUNT[action])
	_anchor_value[need] = clampf(restored, float(p["floor"]), 100.0)
	_anchor_time[need] = _clock.now()
	_was_sad[need] = is_sad(need)


## Sad needs, most depleted first, ties broken in enum order (Core Rule 11).
func sad_needs_ranked() -> Array[int]:
	var sad: Array[int] = []
	for need: int in SliceConfig.NEED_PROFILE:
		if is_sad(need):
			sad.append(need)
	sad.sort_custom(func(a: int, b: int) -> bool:
		var va := value(a)
		var vb := value(b)
		return va < vb if not is_equal_approx(va, vb) else a < b)
	return sad


## The "done for today" signal: every need is content.
func all_addressed() -> bool:
	return sad_needs_ranked().is_empty()


## True if any need reachable from the menu ring (not sleep) is sad.
func has_sad_ring_need() -> bool:
	for action: int in SliceConfig.MENU_ITEMS:
		if is_sad(SliceConfig.ACTION_NEED[action]):
			return true
	return false


## Menu cursor start: the ring item for the most urgent sad need, else 0.
func menu_cursor_start(items: Array[int]) -> int:
	for need: int in sad_needs_ranked():
		for i in items.size():
			if SliceConfig.ACTION_NEED[items[i]] == need:
				return i
	return 0


## Emits [signal need_became_sad] for each new content → sad move. Idempotent.
func check_crossings() -> void:
	for need: int in SliceConfig.NEED_PROFILE:
		var sad_now := is_sad(need)
		if sad_now and not bool(_was_sad[need]):
			need_became_sad.emit(need)
		_was_sad[need] = sad_now
