extends Node
class_name JoeMusic

# Plays Joe's music, and sets how loud you hear it from where you're listening:
#   tablet up   -> from the camera you're watching
#   tablet down -> from the office (for now: the camera nearest to it)
# Joe decides WHEN there is music and how loud it is at the source
# (joe.gd: music_level and get_loudness_at). This node only turns that into sound.

# Every audio file in this folder is a track. One is picked at random each
# time Joe starts blasting. Drop .ogg / .mp3 / .wav files in, no code changes.
const TRACKS_DIR := "res://assets/audio/joe"

# The tablet, to know if it's up and which camera is on the feed.
@export var tablet: Tablet
# Where you "stand" while the tablet is down. Any id that has a position in
# the camera map works: a camera ("F1_CAM_HallR") or a spot ("F1_PrincipalOffice").
@export var office_listener := "F1_CAM_HallR"
# Volume at loudness 1.0, in dB. 0 = the file's own volume, -6 = about half.
@export var max_volume_db := 0.0
# How fast the volume follows a change (camera switch, tablet flip), in
# loudness per second. Higher = snappier. Stops clicks from instant jumps.
@export var volume_speed := 6.0
# Prints the track, the listener and the loudness to Output when they change.
@export var debug_log := true

var joe: Joe
var camera_map: CameraMap
var _player: AudioStreamPlayer
var _tracks: Array[AudioStream] = []
var _volume := 0.0            # the loudness we're playing at right now, 0..1
var _last_listener := ""      # for the debug log
var _log_timer := 0.0

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = -80.0
	add_child(_player)
	# Tracks don't need a loop flag: when one ends, it just starts again.
	_player.finished.connect(func() -> void:
		if joe and joe.music_level > 0.0:
			_player.play())
	_load_tracks()
	# Deferred so Joe has registered with GameManager wherever he sits in the tree
	_connect_joe.call_deferred()

func _connect_joe() -> void:
	var gm := get_tree().get_first_node_in_group("game_manager") as GameManager
	joe = gm.joe if gm else null
	if joe == null:
		set_process(false)   # this night has no Joe: nothing to play
		return
	camera_map = joe.camera_map
	joe.music_started.connect(_on_music_started)

# Joe just appeared and started blasting: pick a random track and play it.
func _on_music_started(_spot: String) -> void:
	if _tracks.is_empty():
		return
	var i := randi() % _tracks.size()
	_player.stream = _tracks[i]
	_player.play()
	_log("playing track %d of %d: %s" % [i + 1, _tracks.size(), _tracks[i].resource_path.get_file()])

func _process(delta: float) -> void:
	if not _player.playing:
		return
	var listener := get_listener()
	var target := 0.0
	if camera_map.positions.has(listener):
		target = joe.get_loudness_at(camera_map.positions[listener], CameraSystem.floor_of(listener))
	_volume = move_toward(_volume, target, volume_speed * delta)
	# linear_to_db turns 0..1 into decibels (1 -> 0 dB, 0.5 -> -6 dB, 0 -> silent)
	_player.volume_db = maxf(linear_to_db(_volume) + max_volume_db, -80.0)

	# Joe was stopped and the music has fully faded: stop the track
	if not joe.is_music_blasting and joe.music_level <= 0.0:
		_player.stop()
		_volume = 0.0
		_log("music faded out, track stopped.")
		return
	_log_listener(listener, target, delta)

# Output: the id you're listening from right now, e.g. "F1_CAM_Biology"
# (tablet up: the camera on the feed) or office_listener (tablet down).
func get_listener() -> String:
	if tablet and tablet.is_open and tablet.camera_system.current_camera != "":
		return tablet.camera_system.current_camera
	return office_listener

# Loads every audio file in TRACKS_DIR. In an exported game the folder holds
# "song.ogg.import" instead of "song.ogg", so both spellings are handled.
func _load_tracks() -> void:
	var dir := DirAccess.open(TRACKS_DIR)
	if dir == null:
		push_warning("JoeMusic: folder %s doesn't exist. Joe will be silent." % TRACKS_DIR)
		return
	var seen := {}
	for f in dir.get_files():
		var file_name := f.trim_suffix(".import")
		if seen.has(file_name) or file_name.get_extension().to_lower() not in ["ogg", "mp3", "wav"]:
			continue
		seen[file_name] = true
		var stream := load(TRACKS_DIR.path_join(file_name)) as AudioStream
		if stream:
			_tracks.append(stream)
	if _tracks.is_empty():
		push_warning("JoeMusic: no .ogg / .mp3 / .wav files in %s. Joe will be silent." % TRACKS_DIR)
	else:
		_log("%d track(s) loaded from %s" % [_tracks.size(), TRACKS_DIR])

# --- Debug log -----------------------------------------------------------------

func _log(text: String) -> void:
	if debug_log:
		print("[JoeMusic] ", text)

# One line when the listener changes (camera switch, tablet flip), and one
# every 5 seconds while music plays, so Output shows what you should be hearing.
func _log_listener(listener: String, loudness: float, delta: float) -> void:
	_log_timer -= delta
	if listener == _last_listener and _log_timer > 0.0:
		return
	_last_listener = listener
	_log_timer = 5.0
	var where := "tablet up" if tablet and tablet.is_open else "tablet down, office"
	_log("listening from %s (%s): loudness %.2f, Joe in %s at music %d" % [
		listener, where, loudness, joe.music_spot, int(joe.music_level)])
