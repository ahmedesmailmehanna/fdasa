extends Node
class_name NightAudio

# The night's "audio director": game systems emit signals, this node decides
# which sound each one makes. Gameplay scripts never play sounds themselves,
# so adding, changing or removing a cue only ever touches this file.
#
# It also answers "where is the player listening from right now?" for
# positional sounds: the camera on the feed while the tablet is up, the
# office while it's down.

@export var tablet: Tablet
@export var camera_map: CameraMap = preload("res://data/graphs/cameras.tres")
# Where you listen from while the tablet is down. Any id with a position in
# the camera map works, a spot or a camera.
@export var office_listener := "F1_PrincipalOffice"

# Which way you face in the office, in degrees on the map (for left/right):
# -90 = up the map (towards the office door), 0 = right, 90 = down, 180 = left.
@export var office_facing_degrees := -90.0

@export_group("Ducking")
# How much quieter the music gets while a phone call plays (dB). -14 = about a fifth.
@export var call_duck_db := -14.0
# How long the music takes to fade down at the start of a call, and back up after
@export var duck_fade_time := 0.35

@export_group("Walls and panning")
# Muffling for sounds you hear through walls (a low-pass cutoff in Hz).
# A sound right behind a wall gets the "near" cutoff, a barely audible one the
# "far" cutoff. A camera that SEES the sound's spot hears it clear.
@export var muffled_cutoff_near := 3000.0
@export var muffled_cutoff_far := 350.0
# How far sounds pan: 1 = fully into one speaker, 0 = no panning.
@export_range(0.0, 1.0) var pan_strength := 0.8

@export_group("Cues")
@export var tablet_open: SoundEvent
@export var tablet_close: SoundEvent
@export var camera_switch: SoundEvent
@export var teacher_call: SoundEvent        # the phone ringing when you send a teacher
@export var teacher_found: SoundEvent       # teacher stops Joe: a voice IN that room (bus Voice)
@export var teacher_not_found: SoundEvent   # teacher calls back: nobody there (bus Phone)
# How far the teacher's voice carries when they find Joe (map units)
@export var teacher_voice_range := 700.0
@export var phone_pickup: SoundEvent        # the line opening before someone talks on the phone

var _calls_active := 0          # phone calls playing right now (they can overlap)
var _duck: AudioEffectAmplify    # ducking's own volume knob on the Music bus
var _duck_tween: Tween

func _ready() -> void:
	add_to_group("night_audio")
	# Deferred so every system it listens to has finished its own _ready
	_connect_cues.call_deferred()

# Signals in, sounds out. One line per cue.
func _connect_cues() -> void:
	if tablet:
		tablet.tablet_toggled.connect(func(open: bool) -> void:
			Sfx.play(tablet_open if open else tablet_close))
		tablet.camera_changed.connect(func(_cam: String) -> void:
			if tablet.is_open:   # not for the camera picked silently at night start
				Sfx.play(camera_switch))
	var teacher := get_tree().get_first_node_in_group("teacher_dispatch") as TeacherDispatch
	if teacher:
		teacher.teacher_sent.connect(func(_spot: String) -> void: Sfx.play(teacher_call))
		teacher.teacher_arrived.connect(func(spot: String, stopped_joe: bool) -> void:
			if stopped_joe:
				# Heard in Joe's room: clear on a camera that sees it, muffled elsewhere
				play_at(teacher_found, spot, teacher_voice_range)
			else:
				# A phone call back: in your ear
				play_phone_call(teacher_not_found))

# --- Where the player is listening from ----------------------------------------

# Output: the id you're listening from, e.g. "F1_CAM_Biology" (tablet up)
#         or office_listener (tablet down)
func get_listener() -> String:
	if tablet and tablet.is_open and tablet.camera_system.current_camera != "":
		return tablet.camera_system.current_camera
	return office_listener

# Everything about how a sound in `spot` reaches the player right now.
# Input: the spot it comes from, how far it carries, how much a floor keeps
# Output: a Dictionary:
#   loudness  0..1  (1 when the camera you're watching sees that spot)
#   cutoff_hz       low-pass cutoff: SpatialPlayer.OPEN_CUTOFF when seen, lower when muffled
#   pan       -1..1 left/right, from where the listener is facing
#   direct    true when the camera you're watching sees the spot
func hear(spot: String, hearing_range: float, floor_dampening: float) -> Dictionary:
	var result := {"loudness": 0.0, "cutoff_hz": SpatialPlayer.OPEN_CUTOFF, "pan": 0.0, "direct": false}
	var listener := get_listener()
	if not camera_map.positions.has(listener) or not camera_map.positions.has(spot):
		return result
	var from: Vector2 = camera_map.positions[listener]
	var to: Vector2 = camera_map.positions[spot]
	result.pan = Hearing.pan(from, get_listener_facing(), to) * pan_strength
	if can_see(listener, spot):
		# Nothing in between: full volume, nothing filtered
		result.direct = true
		result.loudness = 1.0
		return result
	var loud := Hearing.loudness(from, CameraSystem.floor_of(listener),
		to, CameraSystem.floor_of(spot), hearing_range, floor_dampening)
	result.loudness = loud
	# Quieter = further / more walls = more muffled. Blend in log space, since
	# hearing works in ratios (see SpatialPlayer.set_target).
	result.cutoff_hz = exp(lerpf(log(muffled_cutoff_far), log(muffled_cutoff_near), loud))
	return result

# Input: a listener id and a spot. Output: true if that listener is a camera
# whose view includes the spot (from cameras.tres)
func can_see(listener: String, spot: String) -> bool:
	return camera_map.cameras.has(listener) and spot in camera_map.cameras[listener]

# Output: the direction the listener faces, in radians on the map.
# A camera faces the middle of the spots it sees (where its cone points on
# the minimap); the office uses office_facing_degrees.
func get_listener_facing() -> float:
	var listener := get_listener()
	if not camera_map.cameras.has(listener) or not camera_map.positions.has(listener):
		return deg_to_rad(office_facing_degrees)
	var origin: Vector2 = camera_map.positions[listener]
	var sum := Vector2.ZERO
	var count := 0
	for spot: String in camera_map.cameras[listener]:
		if camera_map.positions.has(spot) and CameraSystem.floor_of(spot) == CameraSystem.floor_of(listener):
			sum += camera_map.positions[spot]
			count += 1
	if count == 0:
		return deg_to_rad(office_facing_degrees)
	return (sum / count - origin).angle()

# A phone call: the pickup sound, then the line, both in your ear (bus Phone).
# For the teacher calling back now, and the phone guy later.
# Input: the spoken line to play once the line is open
# A phone call: the pickup sound, then the line, both in your ear (bus Phone).
# For the teacher calling back now, and the phone guy later.
# The music is ducked from the pickup until the line ends, so calls are
# always heard over Joe.
# Input: the spoken line to play once the line is open
func play_phone_call(line: SoundEvent) -> void:
	_calls_active += 1
	_set_music_ducked(true)
	var pickup := Sfx.play(phone_pickup)
	if pickup:
		await pickup.finished   # wait for the click and line hiss to finish
	var voice := Sfx.play(line)
	if voice:
		await voice.finished    # keep the music down until they're done talking
	_calls_active -= 1
	if _calls_active == 0:      # only the last call ending brings the music back
		_set_music_ducked(false)

# Plays a one-shot IN a room: walls, distance and panning apply, and it keeps
# following the listener while it plays (switch cameras mid-line and it
# changes). Removes itself when done.
# Input: the event, the spot it happens in, how far it carries, floor dampening
# Output: the SpatialPlayer, or null if there was nothing to play
func play_at(event: SoundEvent, spot: String, hearing_range := 600.0, floor_dampening := 0.35) -> SpatialPlayer:
	if event == null or event.get_stream() == null:
		return null
	var sp := SpatialPlayer.new()
	sp.name = event.resource_path.get_file().get_basename()   # e.g. "teacher_found", for the bus name
	sp.event = event
	sp.spot = spot
	sp.hearing_range = hearing_range
	sp.floor_dampening = floor_dampening
	sp.auto_free = true
	add_child(sp)
	sp.play()
	return sp

# How loud a sound in a given spot is for the player right now.
# Input: the spot it comes from, how far it carries, how much a floor keeps
# Output: 0..1 (multiply by the sound's own volume, or pass to Sfx.play)
func loudness_of(spot: String, hearing_range: float, floor_dampening: float) -> float:
	var listener := get_listener()
	if not camera_map.positions.has(listener) or not camera_map.positions.has(spot):
		return 0.0
	return Hearing.loudness(
		camera_map.positions[listener], CameraSystem.floor_of(listener),
		camera_map.positions[spot], CameraSystem.floor_of(spot),
		hearing_range, floor_dampening)

# --- Ducking -------------------------------------------------------------------

# Fades the music down (true) or back up (false).
# It uses its own Amplify effect on the Music bus instead of the bus volume,
# so it never fights the player's music volume setting in the options menu.
func _set_music_ducked(ducked: bool) -> void:
	var amp := _get_duck_effect()
	if amp == null:
		return
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(amp, "volume_db", call_duck_db if ducked else 0.0, duck_fade_time)

# Finds the Amplify effect on the Music bus, adding it the first time.
# (Effects added in code live until the game closes, so it's reused after
# that instead of adding a new one every night.)
func _get_duck_effect() -> AudioEffectAmplify:
	if _duck:
		return _duck
	var bus := AudioServer.get_bus_index("Music")
	if bus == -1:
		return null
	for i in AudioServer.get_bus_effect_count(bus):
		var fx := AudioServer.get_bus_effect(bus, i)
		if fx is AudioEffectAmplify and fx.resource_name == "Ducking":
			_duck = fx
			return _duck
	_duck = AudioEffectAmplify.new()
	_duck.resource_name = "Ducking"
	AudioServer.add_bus_effect(bus, _duck)
	return _duck
