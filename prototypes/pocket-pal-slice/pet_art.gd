# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does the 30-second loop make the pet feel alive and glad
#   to see me, and is the 3-button ring learnable with no text?
# Date: 2026-09-25
#
# Procedural pixel art: the "Bloop" pet (built from the LCD spike's blob) plus
# small icons and props defined as character grids. No binary assets.
class_name PetArt
extends RefCounted

const LCD_W := 64
const LCD_H := 64
const PET_SIZE := 32

## The restrained LCD palette, taken from the LCD spike.
const BG := Color("c7d89b")
const INK := Color("2f3b22")
const INK_SOFT := Color("5e6b46")
const ACCENT := Color("d96b6b")
const HILITE := Color("f2f7de")
const SHADOW := Color("8fa06d")

const PALETTE := {
	"X": INK, "o": INK_SOFT, "r": ACCENT, "w": HILITE, "s": SHADOW,
}

## Sprite grids. "." is transparent, and every row of a sprite must be the same width.
const SPRITES := {
	"icon_food": [
		"....X...",
		"...X....",
		".rr.rr..",
		"rrrrrrr.",
		"rrwrrrr.",
		"rrrrrrr.",
		".rrrrr..",
		"..rrr...",
	],
	"icon_clean": [
		"...X....",
		"...X....",
		"..XwX...",
		"..XwX...",
		".XwwoX..",
		".XwooX..",
		".XoooX..",
		"..XXX...",
	],
	"icon_fun": [
		"..XXXX..",
		".XwrrrX.",
		"XwrrrrrX",
		"XXXXXXXX",
		"XrrrrrrX",
		"XrrrrrrX",
		".XrrrrX.",
		"..XXXX..",
	],
	"icon_sleep": [
		"..XXXX..",
		".XooX...",
		"XooX....",
		"XoX.....",
		"XoX.....",
		"XooX..X.",
		".XooXXX.",
		"..XXXX..",
	],
	"heart": [
		".rr.rr.",
		"rwrrrrr",
		"rrrrrrr",
		".rrrrr.",
		"..rrr..",
		"...r...",
	],
	"exclaim": [
		"XX",
		"XX",
		"XX",
		"XX",
		"..",
		"XX",
	],
	"question": [
		".XXX.",
		"X...X",
		"....X",
		"..XX.",
		"..X..",
		".....",
		"..X..",
	],
	"arrow_l": [
		"...X",
		"..XX",
		".XXX",
		"XXXX",
		".XXX",
		"..XX",
		"...X",
	],
	"arrow_r": [
		"X...",
		"XX..",
		"XXX.",
		"XXXX",
		"XXX.",
		"XX..",
		"X...",
	],
	"z": [
		"wwww",
		"..w.",
		".w..",
		"wwww",
	],
	"bubble": [
		".XX.",
		"Xw.X",
		"X..X",
		".XX.",
	],
	"sparkle": [
		"..w..",
		"..X..",
		"wXwXw",
		"..X..",
		"..w..",
	],
	"bowl_full": [
		"...rrrr...",
		"..rrwrrr..",
		".rrrrrrrr.",
		"XXXXXXXXXX",
		".XooooooX.",
		"..XXXXXX..",
	],
	"bowl_half": [
		"..........",
		"..........",
		".rrr..rrr.",
		"XXXXXXXXXX",
		".XooooooX.",
		"..XXXXXX..",
	],
	"bowl_crumbs": [
		"..........",
		"..........",
		"..r....r..",
		"XXXXXXXXXX",
		".XooooooX.",
		"..XXXXXX..",
	],
}

const NEED_ICONS: Array[String] = ["icon_food", "icon_clean", "icon_fun", "icon_sleep"]

static var _sprite_cache: Dictionary = {}
static var _pet_cache: Dictionary = {}


## The icon for a [enum SliceConfig.Need].
static func need_icon(need: int) -> ImageTexture:
	return sprite(NEED_ICONS[need])


## A named sprite from [constant SPRITES], built once and cached.
static func sprite(sprite_name: String) -> ImageTexture:
	if _sprite_cache.has(sprite_name):
		return _sprite_cache[sprite_name]
	if not SPRITES.has(sprite_name):
		push_error("PetArt: unknown sprite '%s'" % sprite_name)
		sprite_name = "question"
	var rows: Array = SPRITES[sprite_name]
	var w := (rows[0] as String).length()
	var img := Image.create_empty(w, rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var row: String = rows[y]
		if row.length() != w:
			push_error("PetArt: sprite '%s' row %d is %d wide, expected %d" % [sprite_name, y, row.length(), w])
		for x in mini(row.length(), w):
			var ch := row[x]
			if PALETTE.has(ch):
				img.set_pixel(x, y, PALETTE[ch])
	var tex := ImageTexture.create_from_image(img)
	_sprite_cache[sprite_name] = tex
	return tex


## Builds a pose dictionary. [param eyes]: open, blink, closed, happy, sad.
## [param mouth]: smile, frown, flat, open, wide.
static func pose(eyes := "open", mouth := "smile", bounce := 0, look := 0, cheeks := false) -> Dictionary:
	return {"eyes": eyes, "mouth": mouth, "bounce": bounce, "look": look, "cheeks": cheeks}


## One 32×32 frame of Bloop for [param p] (see [method pose]). Cached per pose.
static func pet(p: Dictionary) -> ImageTexture:
	var eyes: String = p.get("eyes", "open")
	var mouth: String = p.get("mouth", "smile")
	var bounce: int = p.get("bounce", 0)
	var look: int = p.get("look", 0)
	var cheeks: bool = p.get("cheeks", false)
	var key := "%s|%s|%d|%d|%s" % [eyes, mouth, bounce, look, cheeks]
	if _pet_cache.has(key):
		return _pet_cache[key]

	var img := Image.create_empty(PET_SIZE, PET_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := 16
	var body_top := 10 - bounce
	var body_bottom := 26

	# Rounded blob body from the LCD spike: a stack of half-widths per row.
	var spans: Array[int] = [5, 7, 9, 10, 11, 11, 12, 12, 12, 12, 12, 11, 11, 10, 9, 8]
	for row in spans.size():
		var y := body_top + row
		if y < 0 or y >= PET_SIZE:
			continue
		var half := spans[row]
		for x in range(cx - half, cx + half):
			# Lighter body than the LCD spike so the face reads during reactions.
			var c := SHADOW
			if row <= 2 and x < cx:
				c = HILITE
			elif row >= 13:
				c = INK_SOFT
			img.set_pixel(x, y, c)
	_outline(img, INK)

	var eye_y := body_top + 6
	for dx: int in [-6, 3]:
		var ex := cx + dx + look
		var left := dx < 0
		match eyes:
			"blink":
				_hline(img, ex, ex + 2, eye_y + 1, INK)
			"closed":
				_px(img, ex, eye_y + 1, INK)
				_px(img, ex + 1, eye_y + 2, INK)
				_px(img, ex + 2, eye_y + 1, INK)
			"happy":
				_px(img, ex, eye_y + 1, INK)
				_px(img, ex + 1, eye_y, INK)
				_px(img, ex + 2, eye_y + 1, INK)
			"sad":
				_hline(img, ex, ex + 2, eye_y + 1, INK)
				_hline(img, ex, ex + 2, eye_y + 2, INK)
				# Brows slope down toward the outside.
				if left:
					_px(img, ex, eye_y - 1, INK)
					_px(img, ex + 1, eye_y - 2, INK)
					_px(img, ex + 2, eye_y - 2, INK)
				else:
					_px(img, ex, eye_y - 2, INK)
					_px(img, ex + 1, eye_y - 2, INK)
					_px(img, ex + 2, eye_y - 1, INK)
			_:
				for y in range(eye_y, eye_y + 3):
					_hline(img, ex, ex + 2, y, INK)
				_px(img, ex + (0 if look < 0 else 2), eye_y, HILITE)

	var my := body_top + 11
	var mx := cx + look
	match mouth:
		"frown":
			_px(img, mx - 2, my + 1, INK)
			_px(img, mx - 1, my, INK)
			_px(img, mx, my, INK)
			_px(img, mx + 1, my + 1, INK)
		"flat":
			_hline(img, mx - 1, mx, my, INK)
		"open":
			_hline(img, mx - 1, mx, my, INK)
			_px(img, mx - 2, my + 1, INK)
			_hline(img, mx - 1, mx, my + 1, ACCENT)
			_px(img, mx + 1, my + 1, INK)
			_hline(img, mx - 1, mx, my + 2, INK)
		"wide":
			_hline(img, mx - 3, mx + 2, my, INK)
			_px(img, mx - 2, my + 1, INK)
			_hline(img, mx - 1, mx, my + 1, ACCENT)
			_px(img, mx + 1, my + 1, INK)
			_hline(img, mx - 1, mx, my + 2, INK)
		_:
			_px(img, mx - 2, my, INK)
			_px(img, mx - 1, my + 1, INK)
			_px(img, mx, my + 1, INK)
			_px(img, mx + 1, my, INK)

	if cheeks:
		_hline(img, cx - 9, cx - 8, my - 1, ACCENT)
		_hline(img, cx + 7, cx + 8, my - 1, ACCENT)

	for dx: int in [-6, 3]:
		_hline(img, cx + dx, cx + dx + 3, body_bottom, INK)

	var tex := ImageTexture.create_from_image(img)
	_pet_cache[key] = tex
	return tex


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _hline(img: Image, x0: int, x1: int, y: int, c: Color) -> void:
	for x in range(x0, x1 + 1):
		_px(img, x, y, c)


## 1px dark outline around every opaque pixel that touches transparency.
static func _outline(img: Image, color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var edges: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for n: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + n.x
				var ny := y + n.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and img.get_pixel(nx, ny).a > 0.0:
					edges.append(Vector2i(x, y))
					break
	for e: Vector2i in edges:
		img.set_pixel(e.x, e.y, color)
