extends Node
class_name GameManager
# class_name lets other scripts declare a variable AS a GameManager (not just a
# generic Node), which is what fixes the type-inference error below.

# Fired after any student changes spot. CameraSystem listens to this so the
# feed you're looking at updates live when someone walks in or out of view.
signal student_moved(student: Animatronic, from_spot: String, to_spot: String)

# Who is standing where. A spot can hold SEVERAL students at once
# (Bees and Meer can both end up on F1_OfficeHall or a shared hallway).
# Key = spot id (String, e.g. "F1_HallL2"), Value = Array of Animatronic
var occupants: Dictionary = {}

# The reverse lookup: which spot each student is on.
# Key = Animatronic, Value = spot id. Lets us find a student's old spot
# without searching every spot.
var _spot_of: Dictionary = {}

func _ready() -> void:
	# Adds this node to a "group" — a tag any node can look up later with
	# get_tree().get_first_node_in_group("game_manager"), from anywhere in
	# this scene, without needing a direct node path.
	add_to_group("game_manager")

# Called once by an Animatronic when it first enters the scene.
# Input: a reference to itself (a), and which spot it's starting on.
# Output: nothing — just records the starting position.
func register_animatronic(a: Animatronic, starting_spot: String) -> void:
	_place(a, starting_spot)

# Called every time an Animatronic finishes a move.
# Input: which animatronic moved (a), and its new spot id.
# Output: nothing — moves it in the occupancy lists and tells listeners.
func on_animatronic_moved(a: Animatronic, new_spot: String) -> void:
	var old_spot: String = _spot_of.get(a, "")
	_remove(a)
	_place(a, new_spot)
	student_moved.emit(a, old_spot, new_spot)

# Input: a spot id, e.g. "F1_HallL2"
# Output: every student standing there right now (empty Array if nobody).
#   e.g. get_students_at("F1_OfficeHall") -> [Bees, Meer]
func get_students_at(spot: String) -> Array:
	return occupants.get(spot, [])

# Input: a student
# Output: the spot it's on, or "" if it never registered.
func get_spot_of(a: Animatronic) -> String:
	return _spot_of.get(a, "")

func _place(a: Animatronic, spot: String) -> void:
	if not occupants.has(spot):
		occupants[spot] = []
	occupants[spot].append(a)
	_spot_of[a] = spot

func _remove(a: Animatronic) -> void:
	var spot: String = _spot_of.get(a, "")
	if spot == "":
		return
	occupants[spot].erase(a)
	if occupants[spot].is_empty():
		occupants.erase(spot)
	_spot_of.erase(a)

# --- Joe's music ------------------------------------------------------------

# Set once by the night from the config. 0 = disabled.
var joe_level := 0

# 0 = silent, 100 = full blast. Rises while Joe is blasting, decays when stopped.
var music_level := 0.0
var is_music_blasting := false

@export var music_rise_per_sec := 4.0     # how fast it climbs while blasting
@export var music_decay_per_sec := 2.0    # how fast it falls back after stopping

# Joe's effect AT FULL BLAST, at level 1 and at level 20.
# Levels in between are blended linearly. At half music you get half the effect.
@export var aggression_bonus_at_level_1 := 2.0
@export var aggression_bonus_at_level_20 := 10.0
@export var speed_at_level_1 := 1.1
@export var speed_at_level_20 := 1.5

# Called once by the night at the start.
# Input: Joe's level from the config (0..20)
# Output: none. 0 means music never starts and has no effect.
func set_joe_level(level: int) -> void:
	joe_level = level

# Every frame: music rises while blasting, decays back toward 0 when stopped.
func _process(delta: float) -> void:
	if is_music_blasting:
		music_level = min(music_level + music_rise_per_sec * delta, 100.0)
	else:
		music_level = move_toward(music_level, 0.0, music_decay_per_sec * delta)

# Joe's own logic will call this later. Does nothing if Joe is disabled.
func start_music() -> void:
	if joe_level > 0:
		is_music_blasting = true

# Called when the player turns the music down.
func stop_music() -> void:
	is_music_blasting = false

# Where Joe's level sits between 1 and 20, as 0.0..1.0.
# Level 1 -> 0.0, level 10 -> ~0.47, level 20 -> 1.0
func _joe_level_t() -> float:
	return (joe_level - 1) / 19.0

# Called by every student before each move roll.
# Output: extra aggression to add right now.
#   e.g. Joe level 20, music at 50 -> full-blast bonus 10, halved -> +5
func get_aggression_bonus() -> float:
	if joe_level == 0:
		return 0.0
	var at_full := lerpf(aggression_bonus_at_level_1, aggression_bonus_at_level_20, _joe_level_t())
	return at_full * (music_level / 100.0)

# Called by every student every frame.
# Output: how fast their countdown runs. 1.0 = normal.
#   e.g. Joe level 20, music at 50 -> full-blast 1.5x, halfway -> 1.25x
func get_speed_multiplier() -> float:
	if joe_level == 0:
		return 1.0
	var at_full := lerpf(speed_at_level_1, speed_at_level_20, _joe_level_t())
	return lerpf(1.0, at_full, music_level / 100.0)
