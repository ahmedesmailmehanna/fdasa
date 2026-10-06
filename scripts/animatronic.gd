extends Node
class_name Animatronic

# --- Set these in the Inspector ---
@export var student_id: Students.Id          # which student this node is
@export var graph: StudentGraph               # the map this student walks
@export var starting_node: String            # e.g. "F2_Bathroom"
@export var move_interval_min := 2.0         # seconds, shortest wait
@export var move_interval_max := 5.0         # seconds, longest wait
# The "stay" weight rolled against aggression. Higher = lazier student.
# 10 means aggression 10 is a 50/50 chance to move.
@export var stay_weight := 10.0
# Prints this student's events (moves, arrivals) to Output. See dev_log.gd.
@export var debug_log := true

# --- Set by the night from the config, not in the Inspector ---
# 0 = disabled, 1..20 = difficulty
var aggression := 0

var current_node: String
var game_manager: GameManager
var rng := RandomNumberGenerator.new()
var _time_until_move := 0.0   # counts down in _process, faster with Joe's music
var _warned_lost := false     # so the "not in my graph" warning prints once

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
		_schedule_next_move()
		return

	# --- Step 2 ---
	# e.g. {"F1_HallL3": 3, "F1_MrNabil": 1} -> HallL3 is 3x as likely
	var options: Dictionary = graph.nodes.get(current_node, {})

	# An empty {} is a stop spot (the office door): staying there is correct.
	# A spot that isn't in the graph at all is a mistake in the data.
	if not graph.nodes.has(current_node) and not _warned_lost:
		_warned_lost = true
		push_warning("%s is on '%s', which isn't in its graph, so it can't move." % [get_display_name(), current_node])

	if not options.is_empty():
		var ids: Array = options.keys()
		var weights := PackedFloat32Array(options.values())
		
		# rand_weighted returns the INDEX of the picked entry (0, 1, 2...),
		# with higher weights picked more often. Returns -1 if every
		# weight is 0, which we treat as "don't move this tick".
		var picked := rng.rand_weighted(weights)
		if picked != -1:
			var from := current_node
			current_node = ids[picked]
			_log("moved %s -> %s" % [from, current_node])
			game_manager.on_animatronic_moved(self, current_node)

	_schedule_next_move()

# Where this student's overlays live. Must match build_asset_layout.gd.
#   e.g. res://assets/students/bees/F1_CAM_HallL/F1_AtriumL.png
const STUDENT_ART := "res://assets/students/%s/%s/%s.png"

var _frame_cache: Dictionary = {}   # path -> Texture2D or null (missing)

# Called by CameraSystem when a camera that sees this student's spot is shown.
# Input: the camera being viewed and the spot the student is on,
#        e.g. ("F1_CAM_HallL", "F1_AtriumL")
# Output: the overlay texture, or null if that PNG doesn't exist yet
#         (CameraSystem then lists the student as "no art yet").
func get_frame_for(camera_id: String, spot_id: String) -> Texture2D:
	var path := STUDENT_ART % [get_art_name(), camera_id, spot_id]
	if not _frame_cache.has(path):
		_frame_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _frame_cache[path]

# Output: this student's asset folder name, e.g. Students.Id.BEES -> "bees"
func get_art_name() -> String:
	return Students.Id.keys()[student_id].to_lower()

# Output: this student's name for logs and UI, e.g. Students.Id.BEES -> "Bees"
func get_display_name() -> String:
	var n := get_art_name()
	return n.left(1).to_upper() + n.substr(1)

# Prints one line about this student, in the shared format (see dev_log.gd).
func _log(text: String) -> void:
	if debug_log:
		DevLog.event(get_display_name(), text)
