extends Node
class_name Animatronic

# Set these in the Inspector once you drag this script onto a node.
@export var graph: CameraGraph               # which map this student can walk
@export var starting_node: String            # e.g. "F1_Deputy"
@export var move_interval_min := 2.0         # seconds, fastest possible move
@export var move_interval_max := 5.0         # seconds, slowest possible move
@export var placeholder_texture: Texture2D   # drag icon.svg here for now

var current_node: String   # updated every time this student moves
var game_manager: GameManager
# ^ typed as GameManager now (not Node) — this is what makes := work in
# camera_system.gd, because GDScript now knows exactly what methods/return
# types are available on this variable.

func _ready() -> void:
	current_node = starting_node
	# "as GameManager" converts the generic Node that get_first_node_in_group
	# returns into the specific GameManager type, so we can call
	# GameManager-only methods on it.
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	game_manager.register_animatronic(self, current_node)
	_schedule_next_move()

# Waits a random amount of time, then tries to move.
# Input: none (reads move_interval_min/max)
# Output: none — calls _attempt_move() when the wait is over
func _schedule_next_move() -> void:
	await get_tree().create_timer(randf_range(move_interval_min, move_interval_max)).timeout
	_attempt_move()

# Picks a random neighboring node from the graph and moves there.
# Input: none (reads current_node + graph)
# Output: none — updates current_node, tells GameManager, then schedules
#         the next move (this repeats forever while the scene runs)
func _attempt_move() -> void:
	var neighbors: Array = graph.nodes.get(current_node, [])
	if not neighbors.is_empty():
		current_node = neighbors[randi() % neighbors.size()]
		game_manager.on_animatronic_moved(self, current_node)
		print("moved to: ", current_node)   # delete once you trust it works
	_schedule_next_move()

# Called by GameManager (via get_camera_overlay) when CameraSystem wants to
# know what this student looks like on a given camera.
# Input: which node/camera is asking (unused for now — every camera gets the
#        same placeholder texture until you have real per-pose art)
# Output: a Texture2D to draw on top of that camera's background
func get_frame_for(_node_id: String) -> Texture2D:
	return placeholder_texture
