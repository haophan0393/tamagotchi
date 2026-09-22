## Procedural pixel art for the spike. Keeps the prototype self-contained —
## no binary assets to commit, and the LCD palette constraint stays visible
## in code (game-concept.md: "the LCD uses a restrained 4-8 color palette").
class_name LcdArt
extends RefCounted

## LCD panel resolution. 64x64 gives a 32x32 pet room to sit in with HUD space.
const LCD_W := 64
const LCD_H := 64
const PET_SIZE := 32
const ICON_SIZE := 8

## The restrained LCD palette. Warm greenish backlight, dark pixels — a colour
## LCD, not monochrome, but only 6 entries so the pet reads at 32x32.
const BG := Color("c7d89b")
const INK := Color("2f3b22")
const INK_SOFT := Color("5e6b46")
const ACCENT := Color("d96b6b")
const HILITE := Color("f2f7de")
const SHADOW := Color("8fa06d")


## Builds one frame of the "bloop" pet as a 32x32 image with transparent
## background. [param bounce] shifts the body up a pixel for the idle tick;
## [param blink] closes the eyes. Motion means alive (game-concept pillar).
static func make_pet_frame(bounce: int, blink: bool) -> Image:
	var img := Image.create_empty(PET_SIZE, PET_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var cx := 16
	var body_top := 10 - bounce
	var body_bottom := 26

	# Rounded blob body, drawn as a stack of spans so the silhouette reads
	# clearly at this size — an ellipse formula produces mushy edges at 32px.
	var spans := {
		0: 5, 1: 7, 2: 9, 3: 10, 4: 11, 5: 11, 6: 12, 7: 12,
		8: 12, 9: 12, 10: 12, 11: 11, 12: 11, 13: 10, 14: 9, 15: 8,
	}
	for row: int in spans.keys():
		var y: int = body_top + row
		if y < 0 or y >= PET_SIZE:
			continue
		var half: int = spans[row]
		for x in range(cx - half, cx + half):
			if x < 0 or x >= PET_SIZE:
				continue
			# Rim light on the upper-left, shadow along the bottom.
			var c := INK_SOFT
			if row <= 2 and x < cx:
				c = HILITE
			elif row >= 13:
				c = SHADOW
			img.set_pixel(x, y, c)

	# Outline pass — a hard dark edge is what makes pixel art read small.
	_outline(img, INK)

	# Eyes.
	var eye_y := body_top + 6
	for dx: int in [-5, 4]:
		if blink:
			for x in range(cx + dx, cx + dx + 3):
				img.set_pixel(x, eye_y + 1, INK)
		else:
			for x in range(cx + dx, cx + dx + 3):
				for y in range(eye_y, eye_y + 3):
					img.set_pixel(x, y, INK)
			img.set_pixel(cx + dx + 2, eye_y, HILITE)

	# Mouth — a small upward curve. Cheer without a face full of detail.
	var mouth_y := body_top + 11
	img.set_pixel(cx - 2, mouth_y, INK)
	img.set_pixel(cx - 1, mouth_y + 1, INK)
	img.set_pixel(cx, mouth_y + 1, INK)
	img.set_pixel(cx + 1, mouth_y, INK)

	# Feet.
	for dx: int in [-6, 3]:
		for x in range(cx + dx, cx + dx + 4):
			img.set_pixel(x, body_bottom, INK)
	return img


## Draws a 1px dark outline around every opaque pixel that touches transparency.
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
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if img.get_pixel(nx, ny).a > 0.0:
					edges.append(Vector2i(x, y))
					break
	for e: Vector2i in edges:
		img.set_pixel(e.x, e.y, color)


## Builds an 8x8 need icon. [param kind]: 0 food, 1 clean, 2 play.
## [param filled] draws the "need is active" state.
static func make_icon(kind: int, filled: bool) -> Image:
	var img := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := ACCENT if filled else INK_SOFT

	match kind:
		0:  # Food — a little dish with a dome.
			for x in range(1, 7):
				img.set_pixel(x, 5, c)
			for x in range(2, 6):
				img.set_pixel(x, 4, c)
			img.set_pixel(3, 3, c)
			img.set_pixel(4, 3, c)
		1:  # Clean — a droplet.
			img.set_pixel(4, 1, c)
			for x in range(3, 6):
				img.set_pixel(x, 2, c)
			for x in range(2, 7):
				for y in range(3, 6):
					img.set_pixel(x, y, c)
			for x in range(3, 6):
				img.set_pixel(x, 6, c)
		2:  # Play — a ball with a highlight.
			for x in range(2, 7):
				for y in range(2, 7):
					var d := Vector2(x - 4, y - 4).length()
					if d <= 2.4:
						img.set_pixel(x, y, c)
			img.set_pixel(3, 3, HILITE)
	return img
