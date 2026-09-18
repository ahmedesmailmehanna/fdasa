extends Node2D

@onready var camera_system: CameraSystem = $CameraSystem
@onready var test_student: Animatronic = $TestStudent

func _ready() -> void:
	test_student.graph = build_floor1_test_graph()
	camera_system.backgrounds = {
		"F1_Deputy": load("res://icon.svg"),
		"F1_ChemistryLab": load("res://icon.svg"),
		"F1_1B": load("res://icon.svg"),
	}
	camera_system.show_camera("F1_Deputy")

func build_floor1_test_graph() -> CameraGraph:
	var g := CameraGraph.new()
	g.nodes = {
		"F1_Deputy": ["F1_ChemistryLab"],
		"F1_ChemistryLab": ["F1_Deputy", "F1_1B"],
		"F1_1B": ["F1_ChemistryLab"],
	}
	return g
