extends Node2D

# Used only when you run night.tscn directly (the menu hasn't set GameState).
@export var test_config: NightConfig

@onready var game_manager: GameManager = $GameManager
@onready var camera_system: CameraSystem = $CameraSystem
@onready var test_student: Animatronic = $BeesTest

var config: NightConfig

func _ready() -> void:
	# 1. Pick the config: the menu's choice if there is one, else the test one
	config = GameState.current_night if GameState.current_night else test_config
	if config == null:
		push_error("No NightConfig: set Test Config on the Night node")
		return

	# 2. Joe lives in GameManager, so his level goes there
	game_manager.set_joe_level(config.joe)

	# 3. Every other student: look up its level by id and apply it.
	#    Parent _ready runs after all children, so they've all joined
	#    the "students" group by now.
	print("students found: ", get_tree().get_nodes_in_group("students"))
	for s in get_tree().get_nodes_in_group("students"):
		s.set_level(config.get_level(s.student_id))

	# --- Test setup (temporary) ---
	test_student.graph = load("res://data/graphs/graph_bees.tres")
	camera_system.show_camera(test_student.starting_node)
	game_manager.start_music()   # remove once Joe has real behavior
