extends Node
class_name JoeMusic

# Plays Joe's music the way you'd hear it from where you're listening
# (NightAudio decides that: the camera on the feed, or the office):
#   - a camera that SEES Joe's room hears it clear and at full volume
#   - anywhere else it's quieter with distance and muffled through the walls
#   - it pans left/right depending on which way the listener faces
# Joe decides WHEN there is music and how loud it is at the source
# (joe.gd: music_level). This node only turns that into sound.

# The music: a SoundEvent whose stream is an AudioStreamRandomizer holding
# all of Joe's songs. Its bus should be Music.
@export var music: SoundEvent = preload("res://audio/events/joe_music.tres")
# Prints how the music is heard (loudness, muffling, pan) to Output, once each
# time you start listening from somewhere else. See dev_log.gd.
@export var debug_log := true

var joe: Joe
var night_audio: NightAudio
var _sound: SpatialPlayer     # the player + its own bus with muffling and panning
var _last_listener := ""      # for the debug log

func _ready() -> void:
	_sound = SpatialPlayer.new()
	_sound.name = "JoeSound"
	_sound.event = music
	add_child(_sound)
	# A song ended while Joe is still going: play again. With a randomizer,
	# that's a new song (it avoids repeating the same one twice in a row).
	_sound.player.finished.connect(func() -> void:
		if joe and joe.music_level > 0.0:
			_sound.play())
	# Deferred so Joe and NightAudio exist wherever they sit in the tree
	_connect.call_deferred()

func _connect() -> void:
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	joe = gm.joe if gm else null
	night_audio = get_tree().get_first_node_in_group("night_audio") as NightAudio
	if joe == null or night_audio == null or music == null or music.stream == null:
		if joe and night_audio == null:
			push_warning("JoeMusic: no NightAudio in the scene, so nothing to listen from.")
		set_process(false)
		return
	joe.music_started.connect(_on_music_started)

# Joe just appeared and started blasting
func _on_music_started(_spot: String) -> void:
	_sound.play()
	_last_listener = ""   # so the first "heard from" line prints for this song

func _process(delta: float) -> void:
	if not _sound.player.playing:
		return
	# How the music reaches the player right now: loudness, muffling, pan
	var heard := night_audio.hear(joe.music_spot, joe.hearing_range, joe.floor_dampening)
	var loudness: float = heard.loudness * (joe.music_level / 100.0)
	_sound.set_target(loudness, heard.cutoff_hz, heard.pan, delta)

	# Joe was stopped and the music has fully faded: stop the track
	if not joe.is_music_blasting and joe.music_level <= 0.0:
		_sound.stop()
		return
	_log_listener(heard, loudness)

# --- Debug log -----------------------------------------------------------------

func _log(text: String) -> void:
	if debug_log:
		DevLog.event("Audio", text)

# One line each time the listener changes (camera switch, tablet flip) while
# the music plays, so Output shows what you should be hearing from there.
func _log_listener(heard: Dictionary, loudness: float) -> void:
	var listener := night_audio.get_listener()
	if listener == _last_listener:
		return
	_last_listener = listener
	var side := "center"
	if heard.pan < -0.2:
		side = "left"
	elif heard.pan > 0.2:
		side = "right"
	_log("Joe's music from %s: loudness %.2f, %s, %s" % [
		listener, loudness,
		"clear" if heard.direct else "muffled to %d Hz" % int(heard.cutoff_hz),
		side])
