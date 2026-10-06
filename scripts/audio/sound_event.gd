extends Resource
class_name SoundEvent

# One "thing that makes a sound" in the game, e.g. the tablet flipping up or a
# door slamming. Saved as a .tres in res://audio/events/ and edited in the
# Inspector, so changing how something sounds never means touching code.
#
# For several variations (4 footstep files, Joe's 4 songs), put an
# AudioStreamRandomizer in "stream": Godot picks one each time it plays.

# The sound itself: one file, or an AudioStreamRandomizer holding several
@export var stream: AudioStream
# Which mixer channel it goes through: Music, SFX, Voice, Ambience or UI
@export var bus: StringName = &"SFX"
# Extra volume in dB on top of the file. 0 = as recorded, -6 = about half
@export_range(-40.0, 12.0, 0.5) var volume_db := 0.0
# Random pitch per play, (min, max). (1, 1) = never changes.
# (0.95, 1.05) makes repeats sound less robotic.
@export var pitch_range := Vector2(1.0, 1.0)

# Spoken lines only: the English version. `stream` above is the Arabic one,
# the game's main language (and the only one for effects and music).
# Either can be an AudioStreamRandomizer of several takes.
@export var stream_en: AudioStream

# Output: what to play right now: stream_en when the voice language is
# English and this event has one, otherwise `stream` (can be null)
func get_stream() -> AudioStream:
	if GameState.voice_language == "en" and stream_en:
		return stream_en
	return stream
