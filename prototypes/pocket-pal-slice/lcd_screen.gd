# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does the 30-second loop make the pet feel alive and glad
#   to see me, and is the 3-button ring learnable with no text?
# Date: 2026-09-25
#
# Draws the 64×64 LCD contents inside the SubViewport. This is a pure renderer.
# device.gd sets the public fields and this node redraws every frame. The
# backlight and pixel grid come from lcd_grid.gdshader on the container.
class_name LcdScreen
extends Node2D

const PET_ORIGIN := Vector2i(16, 19)
const GROUND_Y := 46
## Need icons have fixed slots in the top strip, so an icon's position tells
## you which need it is.
const ICON_XS: Array[int] = [4, 20, 36, 52]
const ICON_Y := 1
const HEART_POS := Vector2i(28, 1)
const MENU_XS: Array[int] = [12, 28, 44]
const MENU_Y := 53
const ARROW_L_POS := Vector2i(13, 53)
const ARROW_R_POS := Vector2i(47, 53)

var pose: Dictionary = PetArt.pose()
var pet_offset := Vector2i.ZERO
var pet_modulate := Color.WHITE
var need_sad: Array[bool] = [false, false, false, false]
## While >= 0, that need's icon follows [member flash_on] instead of its state.
var flash_need := -1
var flash_on := false
var done_heart := false
## Bottom strip: "", "menu", "lights", "arrows".
var bottom := ""
var cursor := 0
var menu_items: Array[int] = SliceConfig.MENU_ITEMS
## Play: 0 shows both arrows, -1 / 1 shows only the picked one.
var arrow_pick := 0
var play_mode := false
var play_wins := 0
var _props: Dictionary = {}


## Shows sprite [param sprite_name] at [param pos] under [param key].
func set_prop(key: String, sprite_name: String, pos: Vector2i) -> void:
	_props[key] = [sprite_name, pos]


func clear_prop(key: String) -> void:
	_props.erase(key)


func clear_props() -> void:
	_props.clear()


func _draw() -> void:
	for x in range(1, PetArt.LCD_W - 1, 2):
		draw_rect(Rect2(x, GROUND_Y, 1, 1), PetArt.SHADOW)

	if play_mode:
		for r in SliceConfig.PLAY_ROUNDS:
			var pip := Rect2i(25 + r * 5, 2, 3, 3)
			if r < play_wins:
				draw_rect(Rect2(pip), PetArt.INK)
			else:
				_frame(pip, PetArt.INK_SOFT)
	else:
		for need in need_sad.size():
			var show := need_sad[need]
			if need == flash_need:
				show = flash_on
			if show:
				draw_texture(PetArt.need_icon(need), Vector2(ICON_XS[need], ICON_Y))
		if done_heart:
			draw_texture(PetArt.sprite("heart"), Vector2(HEART_POS))

	draw_texture(PetArt.pet(pose), Vector2(PET_ORIGIN + pet_offset), pet_modulate)

	for key: String in _props:
		var p: Array = _props[key]
		draw_texture(PetArt.sprite(p[0]), Vector2(p[1] as Vector2i))

	match bottom:
		"menu":
			for i in menu_items.size():
				var need: int = SliceConfig.ACTION_NEED[menu_items[i]]
				draw_texture(PetArt.need_icon(need), Vector2(MENU_XS[i], MENU_Y))
			_frame(Rect2i(MENU_XS[cursor] - 2, MENU_Y - 2, 12, 12), PetArt.INK)
		"lights":
			# The B slot sits in the centre, directly above the centre button.
			draw_texture(PetArt.need_icon(SliceConfig.Need.SLEEP), Vector2(MENU_XS[1], MENU_Y))
			_frame(Rect2i(MENU_XS[1] - 2, MENU_Y - 2, 12, 12), PetArt.INK_SOFT)
		"arrows":
			if arrow_pick <= 0:
				draw_texture(PetArt.sprite("arrow_l"), Vector2(ARROW_L_POS))
			if arrow_pick >= 0:
				draw_texture(PetArt.sprite("arrow_r"), Vector2(ARROW_R_POS))


## A 1px rectangle outline built from filled rects, which avoids half-pixel line offsets.
func _frame(r: Rect2i, c: Color) -> void:
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), c)
	draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), c)
	draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), c)
	draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), c)
