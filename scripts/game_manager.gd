extends Node
class_name GameManager
# class_name lets other scripts declare a variable AS a GameManager (not just a
# generic Node), which is what fixes the type-inference error below.

# Tracks which student (Animatronic) is currently standing on which graph node.
# Key = node_id (String, e.g. "F1_Deputy"), Value = the Animatronic occupying it.
var camera_occupants: Dictionary = {}

func _ready() -> void:
	# Adds this node to a "group" — a tag any node can look up later with
	# get_tree().get_first_node_in_group("game_manager"), from anywhere in
	# this scene, without needing a direct node path.
	add_to_group("game_manager")

# Called once by an Animatronic when it first enters the scene.
# Input: a reference to itself (a), and which node it's starting on.
# Output: nothing — just records the starting position.
func register_animatronic(a: Animatronic, starting_node: String) -> void:
	camera_occupants[starting_node] = a

# Called every time an Animatronic finishes a move.
# Input: which animatronic moved (a), and its new node id.
# Output: nothing — updates the occupancy dictionary: removes it from its old
# spot (wherever that was) and adds it at the new one.
func on_animatronic_moved(a: Animatronic, new_node: String) -> void:
	for id in camera_occupants.keys():
		if camera_occupants[id] == a:
			camera_occupants.erase(id)
	camera_occupants[new_node] = a

# Called by CameraSystem when it wants to know what to draw on top of a
# camera's background.
# Input: a camera/node id, e.g. "F1_Deputy"
# Output: a Texture2D if a student is standing there, otherwise null
#         (null = "nobody here, don't draw an overlay").
func get_camera_overlay(camera_id: String) -> Texture2D:
	if camera_occupants.has(camera_id):
		return camera_occupants[camera_id].get_frame_for(camera_id)
	return null

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
