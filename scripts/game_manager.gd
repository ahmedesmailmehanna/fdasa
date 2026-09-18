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
