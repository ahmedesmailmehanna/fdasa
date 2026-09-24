# Builds each walking student's graph and saves it to res://data/.
# Re-run this scene whenever you change the layout or tweak weights.
extends Node

func _ready() -> void:
	_save(_bees_graph(), "res://data/graphs/graph_bees.tres")
	_save(_meer_graph(), "res://data/graphs/graph_meer.tres")

# Bees: left wing only. Forward (toward the office) is weighted 3,
# side rooms and going back are weighted 1.
func _bees_graph() -> CameraGraph:
	var g := CameraGraph.new()
	g.nodes = {
		"F1_StairsL":      {"F1_HallL1": 1},
		"F1_HallL1":       {"F1_HallL2": 3, "F1_1A": 1, "F1_1B": 1, "F1_1C": 1, "F1_StairsL": 1},
		"F1_1A":           {"F1_HallL1": 1},
		"F1_1B":           {"F1_HallL1": 1},
		"F1_1C":           {"F1_HallL1": 1},
		"F1_HallL2":       {"F1_HallL3": 3, "F1_MrNabil": 1, "F1_ChemistryLab": 1, "F1_HallL1": 1},
		"F1_MrNabil":      {"F1_HallL2": 1},
		"F1_ChemistryLab": {"F1_HallL3": 2, "F1_HallL2": 1},
		"F1_HallL3":       {"F1_OfficeHall": 3, "F1_ChemistryLab": 1, "F1_HallL2": 1},
		"F1_OfficeHall":   {},   # at the door: Bees' own attack logic takes over
	}
	return g

# Meer: mirror of Bees on the right wing.
func _meer_graph() -> CameraGraph:
	var g := CameraGraph.new()
	g.nodes = {
		"F1_StairsR":     {"F1_HallR1": 1},
		"F1_HallR1":      {"F1_HallR2": 3, "F1_1E": 1, "F1_1D": 1, "F1_1F": 1, "F1_StairsR": 1},
		"F1_1E":          {"F1_HallR1": 1},
		"F1_1D":          {"F1_HallR1": 1},
		"F1_1F":          {"F1_HallR1": 1},
		"F1_HallR2":      {"F1_HallR3": 3, "F1_MrsSonya": 1, "F1_BiologyLab": 1, "F1_HallR1": 1},
		"F1_MrsSonya":    {"F1_HallR2": 1},
		"F1_BiologyLab":  {"F1_HallR3": 2, "F1_HallR2": 1},
		"F1_HallR3":      {"F1_OfficeHall": 3, "F1_BiologyLab": 1, "F1_HallR2": 1},
		"F1_OfficeHall":  {},   # at the door: Meer's own attack logic takes over
	}
	return g

# Saves a graph to disk and reports the result in the Output tab.
# Input: the graph, and the file path to save it to
# Output: nothing, prints success or the error code
func _save(g: CameraGraph, path: String) -> void:
	var err := ResourceSaver.save(g, path)
	print(path, " -> ", "saved" if err == OK else "FAILED, error %d" % err)
