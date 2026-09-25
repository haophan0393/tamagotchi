# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does the 30-second loop make the pet feel alive and glad
#   to see me, and is the 3-button ring learnable with no text?
# Date: 2026-09-25
#
# Every tunable value in the slice lives here. Need numbers follow the shapes in
# design/gdd/need-system.md and pet-definition-data.md; timings are guesses to
# tune during the playtest.
class_name SliceConfig
extends RefCounted

enum Need { HUNGER, CLEANLINESS, FUN, SLEEP }
enum Action { FEED, CLEAN, PLAY, LIGHTS }

# ---- Time ------------------------------------------------------------------
## Game seconds per real second. At 120x, one real minute is two game hours.
const TIME_SCALE := 120.0
## Desktop debug key F jumps the clock forward by this much.
const DEBUG_SKIP_HOURS := 6.0
## How often Need System's crossing check runs (real seconds).
const CROSSING_CHECK_SEC := 0.5

# ---- Needs (0–100 scale, Need System Core Rule 2) --------------------------
const NEED_PROFILE := {
	Need.HUNGER: {"decay_per_hour": 3.0, "sad_threshold": 30, "floor": 0},
	Need.CLEANLINESS: {"decay_per_hour": 2.0, "sad_threshold": 30, "floor": 0},
	Need.FUN: {"decay_per_hour": 2.5, "sad_threshold": 30, "floor": 0},
	Need.SLEEP: {"decay_per_hour": 1.5, "sad_threshold": 30, "floor": 0},
}
## The slice starts with three needs already sad, so the loop is playable at
## once. Fun starts content and goes sad about 5 real minutes in, so a need
## crossing happens during the session.
const START_VALUES := {
	Need.HUNGER: 18.0,
	Need.CLEANLINESS: 24.0,
	Need.FUN: 55.0,
	Need.SLEEP: 26.0,
}
const RESTORE_AMOUNT := {
	Action.FEED: 60,
	Action.CLEAN: 100,
	Action.PLAY: 70,
	Action.LIGHTS: 100,
}
## The action → need map, fixed in code (PDD Core Rule 10).
const ACTION_NEED := {
	Action.FEED: Need.HUNGER,
	Action.CLEAN: Need.CLEANLINESS,
	Action.PLAY: Need.FUN,
	Action.LIGHTS: Need.SLEEP,
}
## The menu ring holds exactly three items (Device Frame Core Rule 3).
## Lights is not in the ring. It is the contextual B action in IDLE (Rule 4).
const MENU_ITEMS: Array[int] = [Action.FEED, Action.CLEAN, Action.PLAY]

# ---- Device frame ----------------------------------------------------------
const DEVICE_SIZE := Vector2(720, 1280)
const BACKDROP_COLOR := Color("2b2d3a")
const SHELL_RECT := Rect2(60, 110, 600, 1060)
const SHELL_COLOR := Color("f4649b")
const SHELL_RADIUS := 150
const BRAND_TEXT := "POCKET PAL"
const BRAND_Y := 170.0
const LCD_TOP := 250.0
## Interior space available to the LCD panel. The scale is floored to an integer
## (Device Frame Formulas, lcd_scale) so the pixel grid never shimmers.
const BEZEL_INNER := Vector2(520, 520)
const BEZEL_PAD := 22.0
const BEZEL_COLOR := Color("2a2f22")
const LCD_BACKLIGHT := Color(0.78, 0.85, 0.61)
const LCD_BACKLIGHT_DARK := Color(0.2, 0.23, 0.3)

const BUTTON_DIAMETER := 150.0
const BUTTON_Y := 960.0
const BUTTON_XS: Array[float] = [190.0, 360.0, 530.0]
const BUTTON_COLORS: Array[Color] = [Color("ffd23f"), Color("3dd6f5"), Color("8cf26e")]
const SHADOW_DEPTH := 10.0
const PRESS_SCALE := 0.94
const PRESS_IN_SEC := 0.04
const RELEASE_SEC := 0.16
const HAPTIC_MS := 15
const HAPTIC_AMP := 0.8

## Menu closes if untouched this long (Device Frame Tuning Knobs).
const MENU_IDLE_TIMEOUT := 8.0
## In IDLE, the button that would help starts pulsing after this long without
## a press. This is the concept's "one blinking button" onboarding cue.
const HINT_DELAY := 4.0
const HINT_PULSE_SEC := 0.45
const HINT_BRIGHT := Color(1.35, 1.35, 1.35)

# ---- Pet animation timings (real seconds) ---------------------------------
const IDLE_TICK := 0.45
const IDLE_TICK_SAD := 0.8
const BLINK_EVERY := 7
const HOP_PX := 4
const HOP_SEC := 0.12
const CHOMP_SEC := 0.18
const CLEAN_STEPS := 14
const CLEAN_STEP_SEC := 0.1
const LIGHTS_OUT_SEC := 2.4
const FLASH_SEC := 0.1

# ---- Play mini-game --------------------------------------------------------
const PLAY_ROUNDS := 3
## If the player never guesses, Bloop turns anyway. The game has no fail state.
const PLAY_GUESS_TIMEOUT := 6.0
const PLAY_TURN_PX := 6
const PLAY_RESULT_SEC := 0.6

# ---- Sounds: name → [[freq_hz, seconds], ...]; freq 0 = rest ---------------
const BUTTON_SOUNDS: Array[String] = ["press_a", "press_b", "press_c"]
const SOUNDS := {
	"press_a": [[660.0, 0.07]],
	"press_b": [[880.0, 0.07]],
	"press_c": [[1100.0, 0.07]],
	"tick": [[220.0, 0.025]],
	"greet": [[880.0, 0.08], [1175.0, 0.08], [1568.0, 0.16]],
	"attention": [[740.0, 0.08], [0.0, 0.06], [740.0, 0.08]],
	"chomp": [[330.0, 0.05]],
	"bubble": [[1400.0, 0.03], [1800.0, 0.03]],
	"sparkle": [[2093.0, 0.04], [2637.0, 0.08]],
	"ding": [[1319.0, 0.08], [1760.0, 0.16]],
	"giggle": [[988.0, 0.05], [880.0, 0.05], [988.0, 0.05], [880.0, 0.05]],
	"clear": [[1568.0, 0.05], [2093.0, 0.1]],
	"done": [[1047.0, 0.1], [1319.0, 0.1], [1568.0, 0.1], [2093.0, 0.28]],
	"lights_off": [[660.0, 0.1], [440.0, 0.2]],
	"lights_on": [[440.0, 0.08], [660.0, 0.08], [880.0, 0.14]],
}
## Per-sound volume (0–1). Anything absent uses SOUND_VOLUME.
const SOUND_VOLUME := 0.3
const SOUND_VOLUMES := {"tick": 0.12, "chomp": 0.25, "bubble": 0.15}


## Device Frame Formulas: integer LCD scale, never below 1.
static func lcd_scale(avail: Vector2) -> int:
	return maxi(1, floori(minf(avail.x / PetArt.LCD_W, avail.y / PetArt.LCD_H)))
