extends Node
class_name SpatialPlayer

# Two ways to use it:
#   - Driven by its owner (JoeMusic): call set_target() every frame yourself.
#   - Placed in a spot (NightAudio.play_at): set `spot` and it follows the
#     listener on its own, and with auto_free it removes itself when done.

# A long-playing sound that lives somewhere in the school (Joe's music, later
# Sha3er's whispers...). Besides volume, it can be muffled (a low-pass filter
# cuts the high frequencies, like hearing through a wall) and panned (left or
# right speaker).
#
# Effects in Godot sit on buses, not on players, so each SpatialPlayer makes
# its OWN small bus at runtime:
#     [ its player ] -> Spatial_<name> bus (LowPassFilter, Panner) -> event.bus (e.g. Music)
# and removes it again when it leaves the scene.
#
# Every change is eased over a few frames, so switching cameras or flipping
# the tablet never makes a click or a sudden jump.

@export var event: SoundEvent
# How fast volume and pan follow a change, per second. Higher = snappier.
@export var ease_speed := 6.0

# Placed-in-a-spot mode: where the sound is ("" = driven by its owner),
# how far it carries, how much a floor keeps, and whether to delete itself
# when it finishes (for one-shots like a voice line).
var spot := ""
var hearing_range := 600.0
var floor_dampening := 0.35
var auto_free := false

var player: AudioStreamPlayer

var _bus_name := ""
var _lowpass: AudioEffectLowPassFilter
var _panner: AudioEffectPanner
var _volume := 0.0                  # current loudness 0..1
var _pan := 0.0                     # current pan -1..1
var _cutoff_log := log(20500.0)     # current cutoff, as a log (see set_target)

const OPEN_CUTOFF := 20500.0        # above human hearing: the filter does nothing

func _ready() -> void:
	_make_bus()
	player = AudioStreamPlayer.new()
	player.bus = _bus_name
	player.volume_db = -80.0
	if event:
		player.stream = event.get_stream()
	add_child(player)
	player.finished.connect(func() -> void:
		if auto_free:
			queue_free())

func _exit_tree() -> void:
	var i := AudioServer.get_bus_index(_bus_name)
	if i != -1:
		AudioServer.remove_bus(i)

func play() -> void:
	if event:
		# Picked at play time, so voice lines follow the current voice language
		player.stream = event.get_stream()
		player.pitch_scale = randf_range(event.pitch_range.x, event.pitch_range.y)
	if spot != "":
		_follow_listener(0.0, true)   # start at the right volume, no fade-in
	player.play()

# Placed-in-a-spot mode: every frame, ask NightAudio how this spot sounds
# from where the player is listening now (camera switches included).
func _process(delta: float) -> void:
	if spot != "" and player.playing:
		_follow_listener(delta, false)

func _follow_listener(delta: float, snap: bool) -> void:
	var na := get_tree().get_first_node_in_group("night_audio") as NightAudio
	if na == null:
		return
	var heard := na.hear(spot, hearing_range, floor_dampening)
	if snap:
		_volume = heard.loudness
		_pan = heard.pan
		_cutoff_log = log(heard.cutoff_hz)
	set_target(heard.loudness, heard.cutoff_hz, heard.pan, delta)

func stop() -> void:
	player.stop()
	_volume = 0.0

# Call every frame while playing. Eases towards these values.
# Input: loudness 0..1, cutoff in Hz (OPEN_CUTOFF = clear, ~400 = very muffled),
#        pan -1..1, and the frame's delta
func set_target(loudness: float, cutoff_hz: float, pan: float, delta: float) -> void:
	var step := ease_speed * delta
	_volume = move_toward(_volume, loudness, step)
	_pan = move_toward(_pan, pan, step)
	# Hearing is logarithmic: 400 -> 800 Hz sounds like as big a change as
	# 4000 -> 8000 Hz. Easing the log of the cutoff makes the change sound even.
	_cutoff_log = move_toward(_cutoff_log, log(cutoff_hz), step * 2.0)

	var base_db := event.volume_db if event else 0.0
	player.volume_db = maxf(linear_to_db(_volume) + base_db, -80.0)
	_lowpass.cutoff_hz = exp(_cutoff_log)
	_panner.pan = _pan

# Creates this sound's own bus with a LowPassFilter (slot 0) and a Panner
# (slot 1), feeding into the event's bus.
func _make_bus() -> void:
	_bus_name = "Spatial_%s_%d" % [name, get_instance_id()]
	var i := AudioServer.bus_count
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, _bus_name)
	var target: StringName = event.bus if event else &"Master"
	if AudioServer.get_bus_index(target) == -1:
		push_warning("SpatialPlayer: no bus called '%s', sending to Master." % target)
		target = &"Master"
	AudioServer.set_bus_send(i, target)
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = OPEN_CUTOFF
	_panner = AudioEffectPanner.new()
	AudioServer.add_bus_effect(i, _lowpass, 0)
	AudioServer.add_bus_effect(i, _panner, 1)
