extends Animatronic
class_name Joe

# Joe doesn't walk the halls. He waits hidden, then shows up in a room that a
# camera can see and blasts music. The louder it gets, the more aggressive
# and faster every other student becomes. The player has to find him on the
# cameras and send a teacher to that exact room to stop him (TeacherDispatch).
#
# He extends Animatronic so he shows up on cameras exactly like the others
# (overlays, the debug list, the static flicker when he appears).

signal music_started(spot: String)
signal music_stopped(spot: String)

# Rooms Joe can appear in, with weights. Designed in the Student paths tool
# (Appear mode) and saved by generate_graphs.gd. If the file is missing or
# empty, he can appear in any room except NEVER_HERE.
const APPEAR_FILE := "res://data/graphs/appear_joe.tres"
const NEVER_HERE: Array[String] = ["F1_PrincipalOffice", "F1_OfficeHall"]
@export var appear_spots: AppearSpots   # leave empty: loaded from APPEAR_FILE

@export var camera_map: CameraMap = preload("res://data/graphs/cameras.tres")

@export_group("Timing")
@export var first_appearance_delay := 20.0   # seconds into the night before his first song
# Hidden time between songs, as (min, max) seconds, at level 1 and level 20.
# Levels in between blend linearly.
@export var hide_time_at_level_1 := Vector2(50, 75)
@export var hide_time_at_level_20 := Vector2(10, 20)

@export_group("Hearing")
# How far the music carries on the same floor, in map units (a floor is 1060
# wide). At this distance or further it can't be heard.
@export var hearing_range := 700.0
# Volume kept per floor of separation: 0.35 = a floor apart, you hear 35% of it.
@export var floor_dampening := 0.35

@export_group("Music")
@export var music_rise_per_sec := 4.0     # how fast it climbs while blasting
@export var music_decay_per_sec := 30.0    # how fast it falls back after he's stopped
# His effect on the other students AT FULL BLAST, at level 1 and level 20.
@export var aggression_bonus_at_level_1 := 2.0
@export var aggression_bonus_at_level_20 := 10.0
@export var speed_at_level_1 := 1.1
@export var speed_at_level_20 := 1.5

@export_group("Debug")
# (debug_log, the on/off switch for Joe's lines, comes from Animatronic.)
# While blasting, print a line each time the music climbs past another
# multiple of this (50 -> at 50 and 100). 0 = never.
@export var debug_music_step := 50.0

var music_level := 0.0          # 0 = silent, 100 = full blast
var is_music_blasting := false
# Where the music is coming from. Kept after Joe leaves the room, so the
# fading music is still heard from the right place.
var music_spot := ""
var _hide_timer := 0.0          # counts down while hidden; at 0 he appears

var _night_time := 0.0          # seconds since his level was set
var _appeared_at := 0.0         # _night_time when the current song started
var _next_music_mark := 0.0     # next music level that gets a log line

func _ready() -> void:
	# Not calling super._ready(): Joe starts hidden, not on a spot.
	student_id = Students.Id.JOE
	current_node = ""
	if appear_spots == null and ResourceLoader.exists(APPEAR_FILE):
		appear_spots = load(APPEAR_FILE)
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	game_manager.register_joe(self)
	add_to_group("students")
	set_process(false)

# Called once by the night with Joe's level from the config.
# Input: 0..20. 0 = Joe never shows up and has no effect.
func set_level(level: int) -> void:
	aggression = level   # Joe's level uses the same field as the other students
	if aggression > 0:
		_hide_timer = first_appearance_delay
		set_process(true)

func _process(delta: float) -> void:
	_night_time += delta
	if is_music_blasting:
		music_level = min(music_level + music_rise_per_sec * delta, 100.0)
		_log_music_marks()
	else:
		music_level = move_toward(music_level, 0.0, music_decay_per_sec * delta)
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_appear()

# Picks a room a camera can see, shows up there and starts the music.
func _appear() -> void:
	# Rooms and their weights: from the designed list, or every room equally
	var ids: Array[String] = []
	var weights := PackedFloat32Array()
	if appear_spots and not appear_spots.spots.is_empty():
		for spot: String in appear_spots.spots:
			ids.append(spot)
			weights.append(float(appear_spots.spots[spot]))
	else:
		for spot in _all_spots():
			ids.append(spot)
			weights.append(1.0)
	var picked := rng.rand_weighted(weights)   # index, or -1 if every weight is 0
	if picked == -1:
		push_warning("Joe has nowhere to appear: his room list is empty or all weights are 0.")
		set_process(false)
		return
	current_node = ids[picked]
	music_spot = current_node
	game_manager.on_animatronic_moved(self, current_node)
	is_music_blasting = true
	_appeared_at = _night_time
	if debug_music_step > 0.0:
		_next_music_mark = (floorf(music_level / debug_music_step) + 1.0) * debug_music_step
	var cams := _cameras_seeing(current_node)
	_log("appeared in %s (%s)" % [current_node,
		"on " + ", ".join(cams) if not cams.is_empty() else "on no camera"])
	music_started.emit(current_node)

# Called by TeacherDispatch when a teacher reaches Joe's room.
# Output: none. Music starts fading, Joe leaves the room (cameras no longer
#         show him) and hides for a while.
func get_stopped() -> void:
	var spot := current_node
	is_music_blasting = false
	current_node = ""
	game_manager.on_animatronic_left(self)
	var t := _level_t()
	_hide_timer = rng.randf_range(
		lerpf(hide_time_at_level_1.x, hide_time_at_level_20.x, t),
		lerpf(hide_time_at_level_1.y, hide_time_at_level_20.y, t))
	_log("stopped in %s after %ds (music %d), back in %ds" % [
		spot, int(_night_time - _appeared_at), int(music_level), int(_hide_timer)])
	music_stopped.emit(spot)

# Input: a spot id. Output: true if Joe is playing music right there right now.
func is_blasting_at(spot: String) -> bool:
	return is_music_blasting and current_node == spot

# Fallback when there's no room list: every spot on the map, minus NEVER_HERE.
# (Positions come from the tool's "Camera map + minimap layout" export.)
func _all_spots() -> Array[String]:
	var out: Array[String] = []
	for id: String in camera_map.positions:
		if "_CAM_" not in id and id not in NEVER_HERE:
			out.append(id)
	return out

# How loud Joe's music is for someone listening at a given place.
# Input: a position in map units and that place's floor, e.g. a camera's
#        (Vector2(372, 154), "F1"), or the office's position
# Output: 0.0 (silent) .. 1.0 (full blast, right next to him)
func get_loudness_at(listener_pos: Vector2, listener_floor: String) -> float:
	if music_level <= 0.0 or music_spot == "" or not camera_map.positions.has(music_spot):
		return 0.0
	# Distance and floors: the shared rule every positional sound uses
	var heard := Hearing.loudness(listener_pos, listener_floor,
		camera_map.positions[music_spot], CameraSystem.floor_of(music_spot),
		hearing_range, floor_dampening)
	return heard * (music_level / 100.0)

# --- Debug log ---------------------------------------------------------------

# (_log itself comes from Animatronic, so Joe's lines look like everyone's.)

# While blasting: one line each time the music passes a debug_music_step mark,
# with what it's doing to the other students at that point.
func _log_music_marks() -> void:
	if debug_music_step <= 0.0 or music_level < _next_music_mark:
		return
	_log("music at %d: students +%.1f aggression, %.2fx speed" % [
		int(_next_music_mark), get_aggression_bonus(), get_speed_multiplier()])
	_next_music_mark += debug_music_step
	if _next_music_mark > 100.0:
		_next_music_mark = INF   # nothing left to report until he's stopped

# Input: a spot id. Output: every camera that can see it, e.g. ["F1_CAM_StairsL"]
func _cameras_seeing(spot: String) -> Array[String]:
	var out: Array[String] = []
	for cam: String in camera_map.cameras:
		if spot in camera_map.cameras[cam]:
			out.append(cam)
	out.sort()
	return out

# Joe's level as 0..1: level 1 -> 0.0, level 20 -> 1.0
func _level_t() -> float:
	return clampf((aggression - 1) / 19.0, 0.0, 1.0)

# Called (through GameManager) by every student before each move roll.
# Output: extra aggression right now, e.g. level 20 at half volume -> +5
func get_aggression_bonus() -> float:
	if aggression == 0:
		return 0.0
	var at_full := lerpf(aggression_bonus_at_level_1, aggression_bonus_at_level_20, _level_t())
	return at_full * (music_level / 100.0)

# Called (through GameManager) by every student every frame.
# Output: how fast their countdown runs. 1.0 = normal.
func get_speed_multiplier() -> float:
	if aggression == 0:
		return 1.0
	var at_full := lerpf(speed_at_level_1, speed_at_level_20, _level_t())
	return lerpf(1.0, at_full, music_level / 100.0)
