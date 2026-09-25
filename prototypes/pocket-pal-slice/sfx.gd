# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: does the 30-second loop make the pet feel alive and glad
#   to see me, and is the 3-button ring learnable with no text?
# Date: 2026-09-25
#
# Chip-style square-wave sounds synthesized from SliceConfig.SOUNDS, using the
# button-feel prototype's technique. No audio assets.
class_name Sfx
extends Node

const MIX_RATE := 22050

var _players: Dictionary = {}


func _ready() -> void:
	for sound_name: String in SliceConfig.SOUNDS:
		var player := AudioStreamPlayer.new()
		var vol: float = SliceConfig.SOUND_VOLUMES.get(sound_name, SliceConfig.SOUND_VOLUME)
		player.stream = _make(SliceConfig.SOUNDS[sound_name], vol)
		player.max_polyphony = 3
		add_child(player)
		_players[sound_name] = player


## Plays [param sound_name]. Unknown names are reported once and ignored.
func play(sound_name: String) -> void:
	if not _players.has(sound_name):
		push_warning("Sfx: unknown sound '%s'" % sound_name)
		return
	(_players[sound_name] as AudioStreamPlayer).play()


static func _make(notes: Array, volume: float) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	for note: Array in notes:
		var freq: float = note[0]
		var n := int(float(note[1]) * MIX_RATE)
		var start := bytes.size()
		bytes.resize(start + n * 2)
		for i in n:
			var s := 0.0
			if freq > 0.0:
				var t := float(i) / MIX_RATE
				var env := 1.0 - float(i) / float(n)
				s = (1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0) * env * volume
			bytes.encode_s16(start + i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
