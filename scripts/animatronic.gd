extends Node
class_name Animatronic

# --- Set these in the Inspector ---
@export var student_id: Students.Id          # which student this node is
@export var graph: CameraGraph               # the map this student walks
@export var starting_node: String            # e.g. "F2_Bathroom"
@export var move_interval_min := 2.0         # seconds, shortest wait
@export var move_interval_max := 5.0         # seconds, longest wait
# The "stay" weight rolled against aggression. Higher = lazier student.
# 10 means aggression 10 is a 50/50 chance to move.
@export var stay_weight := 10.0
@export var placeholder_texture: Texture2D   # icon.svg for now

# --- Set by the night from the config, not in the Inspector ---
# 0 = disabled, 1..20 = difficulty
var aggression := 0

var current_node: String
var game_manager: GameManager
var rng := RandomNumberGenerator.new()
var _time_until_move := 0.0   # counts down in _process, faster with Joe's music

func _ready() -> void:
	current_node = starting_node
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	# Register even if disabled, so he can sit visibly on a camera
	game_manager.register_animatronic(self, current_node)
	add_to_group("students")
	# Start asleep. The night wakes him up with set_level() if his level > 0.
	set_process(false)

# Called once by the night at the start.
# Input: this student's level from the config (0..20)
# Output: none. 0 = stays disabled all night, anything else starts the countdown.
func set_level(level: int) -> void:
	print(name, " (", Students.Id.keys()[student_id], ") level set to ", level)
	aggression = level
	if aggression > 0:
		_schedule_next_move()
		set_process(true)

# Picks a fresh random wait before the next move attempt.
func _schedule_next_move() -> void:
	_time_until_move = rng.randf_range(move_interval_min, move_interval_max)

# Every frame: count down, roll a move at 0.
func _process(delta: float) -> void:
	# Joe's music makes the countdown run faster, even mid-wait
	_time_until_move -= delta * game_manager.get_speed_multiplier()
	if _time_until_move <= 0.0:
		_attempt_move()   # this ends by calling _schedule_next_move() again

# Step 1: does he move? (aggression + Joe vs. stay weight)
# Step 2: if yes, where to? (weighted neighbor pick)
func _attempt_move() -> void:
	# --- Step 1 ---
	# e.g. aggression 5, Joe bonus 3, stay 10 -> 8 / 18 = 44% to move
	var move_weight := aggression + game_manager.get_aggression_bonus()
	var move_chance := move_weight / (move_weight + stay_weight)

	if rng.randf() >= move_chance:
		print(name, " stayed at ", current_node, " (", snappedf(move_chance * 100, 1), "% chance)")
		_schedule_next_move()
		return

	
	# --- Step 2 ---
	# e.g. {"F1_HallL3": 3, "F1_MrNabil": 1} -> HallL3 is 3x as likely
	var options: Dictionary = graph.nodes.get(current_node, {})
	
	if options.is_empty():
		print(name, " has nowhere to go from '", current_node, "' (not in graph, or a stop node)")
	
	if not options.is_empty():
		var ids: Array = options.keys()
		var weights := PackedFloat32Array(options.values())
		
		# rand_weighted returns the INDEX of the picked entry (0, 1, 2...),
		# with higher weights picked more often. Returns -1 if every
		# weight is 0, which we treat as "don't move this tick".
		var picked := rng.rand_weighted(weights)
		if picked != -1:
			current_node = ids[picked]
			game_manager.on_animatronic_moved(self, current_node)
			print(name, " moved to: ", current_node)

	_schedule_next_move()

# Called by GameManager (via get_camera_overlay) when CameraSystem wants to
# know what this student looks like on a given camera.
# Input: which node/camera is asking (unused for now — every camera gets the
#        same placeholder texture until you have real per-pose art)
# Output: a Texture2D to draw on top of that camera's background
func get_frame_for(_node_id: String) -> Texture2D:
	return placeholder_texture
