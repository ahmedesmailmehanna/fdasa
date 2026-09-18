extends Node

static func build_floor1_test_graph() -> CameraGraph:
	var g := CameraGraph.new()
	g.nodes = {
		"F1_Deputy": ["F1_ChemistryLab", "F1_PhysicsLab"],
		"F1_ChemistryLab": ["F1_Deputy", "F1_1B"],
		"F1_1B": ["F1_ChemistryLab", "F1_1A"],
		"F1_1A": ["F1_1B"],
		"F1_PhysicsLab": ["F1_Deputy", "F1_1E"],
		"F1_1E": ["F1_PhysicsLab", "F1_1D"],
		"F1_1D": ["F1_1E"],
	}
	return g
