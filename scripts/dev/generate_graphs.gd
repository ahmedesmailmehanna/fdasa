# Builds every map resource, checks them against the master location list,
# and saves them to res://data/. Re-run whenever the layout changes.
extends Node

func _ready() -> void:
	var locations := _locations()
	var bees := _bees_graph()
	var meer := _meer_graph()
	var cameras := _camera_map()

	# Validate everything before saving anything
	var errors := 0
	errors += _check_graph("Bees", bees, locations)
	errors += _check_graph("Meer", meer, locations)
	errors += _check_cameras(cameras, locations)

	if errors > 0:
		push_error("%d problem(s) found, nothing was saved. See Output." % errors)
		return

	_save(locations, "res://data/graphs/locations.tres")
	_save(bees, "res://data/graphs/graph_bees.tres")
	_save(meer, "res://data/graphs/graph_meer.tres")
	_save(cameras, "res://data/graphs/cameras.tres")
	_report_uncovered(cameras, locations)

# ============================================================
# Master list: every node in the building
# ============================================================
func _locations() -> LocationList:
	var l := LocationList.new()
	l.nodes = PackedStringArray([
		# --- Floor 1 (23 nodes) ---
		"F1_StairsL", "F1_StairsR",
		"F1_1A", "F1_1B", "F1_1C", "F1_1D", "F1_1E", "F1_1F",
		"F1_HallL1", "F1_HallL2", "F1_HallL3",
		"F1_HallR1", "F1_HallR2", "F1_HallR3",
		"F1_MrNabil", "F1_MrsSonya",
		"F1_ChemistryLab", "F1_BiologyLab",
		"F1_AtriumL", "F1_AtriumR",
		"F1_OfficeHall", "F1_PrincipalOffice", "F1_Bathroom",
		# --- Floor 0 (placeholders until it's designed) ---
		"F0_StairsL", "F0_StairsR", "F0_Bathroom",
		# --- Floor 2 (placeholders until it's designed) ---
		"F2_Bathroom", "F2_AtriumL",
	])
	return l

# ============================================================
# Student graphs
# ============================================================

# Bees: left wing + atrium drop from floor 2 + bathroom vents
func _bees_graph() -> StudentGraph:
	var g := StudentGraph.new()
	g.nodes = {
		"F2_Bathroom":     {"F2_AtriumL": 2, "F1_Bathroom": 1},
		"F2_AtriumL":      {"F1_AtriumL": 3, "F2_Bathroom": 1},   # one-way jump down
		"F1_AtriumL":      {"F1_HallL3": 3, "F1_HallL2": 1},
		"F1_StairsL":      {"F1_HallL1": 1},
		"F1_HallL1":       {"F1_HallL2": 3, "F1_1A": 1, "F1_1B": 1, "F1_1C": 1, "F1_StairsL": 1},
		"F1_1A":           {"F1_HallL1": 1},
		"F1_1B":           {"F1_HallL1": 1},
		"F1_1C":           {"F1_HallL1": 1},
		"F1_HallL2":       {"F1_HallL3": 3, "F1_MrNabil": 1, "F1_ChemistryLab": 1, "F1_AtriumL": 1, "F1_HallL1": 1},
		"F1_MrNabil":      {"F1_HallL2": 1},
		"F1_ChemistryLab": {"F1_HallL3": 2, "F1_HallL2": 1},
		"F1_HallL3":       {"F1_OfficeHall": 3, "F1_ChemistryLab": 1, "F1_AtriumL": 1, "F1_HallL2": 1},
		"F1_Bathroom":     {"F2_Bathroom": 2, "F0_Bathroom": 1, "F1_OfficeHall": 1},
		"F0_Bathroom":     {"F1_Bathroom": 1},
		"F1_OfficeHall":   {},   # at the door: attack logic takes over
	}
	return g

# Meer: right wing only
func _meer_graph() -> StudentGraph:
	var g := StudentGraph.new()
	g.nodes = {
		"F1_StairsR":    {"F1_HallR1": 1},
		"F1_HallR1":     {"F1_HallR2": 3, "F1_1E": 1, "F1_1D": 1, "F1_1F": 1, "F1_StairsR": 1},
		"F1_1E":         {"F1_HallR1": 1},
		"F1_1D":         {"F1_HallR1": 1},
		"F1_1F":         {"F1_HallR1": 1},
		"F1_HallR2":     {"F1_HallR3": 3, "F1_MrsSonya": 1, "F1_BiologyLab": 1, "F1_HallR1": 1},
		"F1_MrsSonya":   {"F1_HallR2": 1},
		"F1_BiologyLab": {"F1_HallR3": 2, "F1_HallR2": 1},
		"F1_HallR3":     {"F1_OfficeHall": 3, "F1_BiologyLab": 1, "F1_HallR2": 1},
		"F1_OfficeHall": {},
	}
	return g

# ============================================================
# Cameras (placeholder placement, adjust freely)
# ============================================================
func _camera_map() -> CameraMap:
	var c := CameraMap.new()
	c.cameras = {
		"F1_CAM_StairsL":   ["F1_StairsL", "F1_HallL1"],
		"F1_CAM_HallL":     ["F1_HallL2", "F1_AtriumL"],
		"F1_CAM_Chemistry": ["F1_ChemistryLab", "F1_HallL3"],
		"F1_CAM_StairsR":   ["F1_StairsR", "F1_HallR1"],
		"F1_CAM_HallR":     ["F1_HallR2", "F1_AtriumR"],
		"F1_CAM_Biology":   ["F1_BiologyLab", "F1_HallR3"],
	}
	return c

# ============================================================
# Validation
# ============================================================

# Checks every node and every neighbor in a student graph exists.
# Input: a label for printing, the graph, the master list
# Output: number of problems found (0 = all good)
func _check_graph(label: String, g: StudentGraph, locations: LocationList) -> int:
	var errors := 0
	for from in g.nodes:
		if not locations.nodes.has(from):
			print("[%s] unknown node: '%s'" % [label, from])
			errors += 1
		for to in g.nodes[from]:
			if not locations.nodes.has(to):
				print("[%s] '%s' points to unknown node: '%s'" % [label, from, to])
				errors += 1
			elif not g.nodes.has(to):
				# Exists in the building, but this student has no entry for it,
				# so he'd get stuck there forever
				print("[%s] '%s' leads to '%s', which has no entry in this graph" % [label, from, to])
				errors += 1
	return errors

# Checks every node a camera covers exists.
func _check_cameras(c: CameraMap, locations: LocationList) -> int:
	var errors := 0
	for cam in c.cameras:
		for node_id in c.cameras[cam]:
			if not locations.nodes.has(node_id):
				print("[Cameras] '%s' covers unknown node: '%s'" % [cam, node_id])
				errors += 1
	return errors

# Not an error, just info: lists spots no camera can see.
# Blind spots are normal (classrooms), but this makes them visible.
func _report_uncovered(c: CameraMap, locations: LocationList) -> void:
	var covered := {}
	for cam in c.cameras:
		for node_id in c.cameras[cam]:
			covered[node_id] = true
	var blind := []
	for node_id in locations.nodes:
		if not covered.has(node_id):
			blind.append(node_id)
	print("Blind spots (%d): %s" % [blind.size(), ", ".join(blind)])

func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	print(path, " -> ", "saved" if err == OK else "FAILED, error %d" % err)
