# Builds every map resource, checks them against the master location list,
# and saves them to res://data/. Re-run whenever the layout changes.
extends Node

func _ready() -> void:
	var locations := _locations()
	var bees := _bees_graph()
	var meer := _meer_graph()
	var cameras := _camera_map()
	var joe_spots := _joe_appear_spots()
	
	# Validate everything before saving anything
	var errors := 0
	errors += _check_graph("Bees", bees, locations)
	errors += _check_graph("Meer", meer, locations)
	errors += _check_cameras(cameras, locations)
	errors += _check_appear("Joe", joe_spots, locations)
	
	if errors > 0:
		push_error("%d problem(s) found, nothing was saved. See Output." % errors)
		return

	_save(locations, "res://data/graphs/locations.tres")
	_save(bees, "res://data/graphs/graph_bees.tres")
	_save(meer, "res://data/graphs/graph_meer.tres")
	_save(cameras, "res://data/graphs/cameras.tres")
	_save(joe_spots, "res://data/graphs/appear_joe.tres")

# ============================================================
# Master list: every node in the building
# ============================================================
func _locations() -> LocationList:
	var l := LocationList.new()
	l.nodes = PackedStringArray([
		# --- Floor 2 ---
		"F2_AtriumL", "F2_Bathroom", "F2_AtriumR", "F2_2C", "F2_2A", "F2_2B", "F2_2D", "F2_2E", "F2_2F", "F2_StairsR", "F2_StairsL", "F2_HallL1", "F2_HallL2", "F2_HallL3", "F2_HallR1", "F2_HallR2", "F2_HallR3", "F2_Library", "F2_ArtRoom", "F2_PhysicsLab", "F2_OfficeHall", "F2_TeacherOffice",
		# --- Floor 1 ---
		"F1_StairsL", "F1_1A", "F1_1C", "F1_HallL1", "F1_MrNabil", "F1_1B", "F1_HallL2", "F1_AtriumL", "F1_ChemistryLab", "F1_HallL3", "F1_Bathroom", "F1_OfficeHall", "F1_PrincipalOffice", "F1_StairsR", "F1_1F", "F1_1E", "F1_HallR1", "F1_MrsSonya", "F1_1D", "F1_HallR2", "F1_AtriumR", "F1_BiologyLab", "F1_HallR3",
		# --- Floor 0 ---
		"F0_StairsL", "F0_Bathroom", "F0_StairsR", "F0_BoysWC", "F0_MechanicsLab", "F0_Gym", "F0_Clinic", "F0_DeputyOffice", "F0_OfficeHall", "F0_FabLab1", "F0_GirlsWC", "F0_ServerRoom", "F0_FabLab2", "F0_AcademicOffice", "F0_HallL1", "F0_HallL2", "F0_HallL3", "F0_HallR1", "F0_HallR2", "F0_HallR3", "F0_AtriumL", "F0_AtriumR",
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
		"F1_CAM_StairsL":       ["F1_HallL1", "F1_1C", "F1_StairsL"],
		"F1_CAM_HallL":         ["F1_HallL2", "F1_HallL3", "F1_AtriumL"],
		"F1_CAM_Chemistry":     ["F1_ChemistryLab"],
		"F1_CAM_StairsR":       ["F1_StairsR", "F1_HallR1", "F1_1F"],
		"F1_CAM_HallR":         ["F1_HallR2", "F1_AtriumR", "F1_HallR3"],
		"F1_CAM_Biology":       ["F1_BiologyLab"],
		"F0_CAM_HallL":         ["F0_HallL2", "F0_HallL3", "F0_MechanicsLab", "F0_OfficeHall"],
		"F2_CAM_StairsL":       ["F2_HallL1", "F2_StairsL", "F2_2C"],
		"F2_CAM_HallL":         ["F2_AtriumR", "F2_HallL3", "F2_OfficeHall", "F2_HallL2"],
		"F2_CAM_HallR":         ["F2_HallR2", "F2_HallR3", "F2_OfficeHall", "F2_AtriumL"],
		"F2_CAM_StairsR":       ["F2_StairsR", "F2_HallR1", "F2_2F"],
		"F2_CAM_Library":       ["F2_Library"],
		"F2_CAM_TeacherOffice": ["F2_TeacherOffice", "F2_OfficeHall"],
		"F0_CAM_HallR":         ["F0_HallR2", "F0_HallR3"],
		"F0_CAM_OfficeHall":    ["F0_HallR3", "F0_OfficeHall", "F0_HallL3", "F0_AtriumL", "F0_AtriumR"],
		"F0_CAM_Gym":           ["F0_Gym"],
		"F0_CAM_FabLab":        ["F0_FabLab1"],
		"F2_CAM_ArtRoom":       ["F2_ArtRoom"],
		"F2_CAM_PhysicsLab":    ["F2_PhysicsLab"],
	}
	c.positions = {
		"F1_CAM_StairsL":       Vector2(150, 154),
		"F1_CAM_HallL":         Vector2(450, 443),
		"F1_CAM_Chemistry":     Vector2(217, 358),
		"F1_CAM_StairsR":       Vector2(901, 138),
		"F1_CAM_HallR":         Vector2(585, 453),
		"F1_CAM_Biology":       Vector2(839, 358),
		"F0_CAM_HallL":         Vector2(204, 207),
		"F2_CAM_StairsL":       Vector2(158, 155),
		"F2_CAM_HallL":         Vector2(284, 289),
		"F2_CAM_HallR":         Vector2(763, 292),
		"F2_CAM_StairsR":       Vector2(885, 137),
		"F2_CAM_Library":       Vector2(642, 179),
		"F2_CAM_TeacherOffice": Vector2(481, 607),
		"F0_CAM_HallR":         Vector2(857, 182),
		"F0_CAM_OfficeHall":    Vector2(550, 475),
		"F0_CAM_Gym":           Vector2(279, 423),
		"F0_CAM_FabLab":        Vector2(757, 435),
		"F2_CAM_ArtRoom":       Vector2(359, 487),
		"F2_CAM_PhysicsLab":    Vector2(641, 536),
		"F2_AtriumL":           Vector2(464, 320),
		"F2_Bathroom":          Vector2(420, 491),
		"F1_StairsL":           Vector2(259, 96),
		"F1_1A":                Vector2(101, 188),
		"F1_1C":                Vector2(313, 167),
		"F1_HallL1":            Vector2(254, 216),
		"F1_MrNabil":           Vector2(406, 233),
		"F1_1B":                Vector2(182, 282),
		"F1_HallL2":            Vector2(335, 284),
		"F1_AtriumL":           Vector2(463, 306),
		"F1_ChemistryLab":      Vector2(316, 395),
		"F1_HallL3":            Vector2(440, 392),
		"F1_Bathroom":          Vector2(410, 495),
		"F1_OfficeHall":        Vector2(512, 468),
		"F1_PrincipalOffice":   Vector2(516, 542),
		"F1_StairsR":           Vector2(792, 84),
		"F1_1F":                Vector2(724, 152),
		"F1_1E":                Vector2(954, 161),
		"F1_HallR1":            Vector2(797, 206),
		"F1_MrsSonya":          Vector2(645, 233),
		"F1_1D":                Vector2(868, 269),
		"F1_HallR2":            Vector2(692, 307),
		"F1_AtriumR":           Vector2(578, 309),
		"F1_BiologyLab":        Vector2(706, 421),
		"F1_HallR3":            Vector2(592, 397),
		"F0_StairsL":           Vector2(262, 92),
		"F0_Bathroom":          Vector2(406, 485),
		"F0_StairsR":           Vector2(794, 84),
		"F0_BoysWC":            Vector2(93, 187),
		"F0_MechanicsLab":      Vector2(345, 203),
		"F0_Gym":               Vector2(243, 321),
		"F0_Clinic":            Vector2(348, 426),
		"F0_DeputyOffice":      Vector2(512, 548),
		"F0_OfficeHall":        Vector2(513, 424),
		"F0_FabLab1":           Vector2(818, 316),
		"F0_GirlsWC":           Vector2(955, 165),
		"F0_ServerRoom":        Vector2(651, 473),
		"F0_FabLab2":           Vector2(721, 150),
		"F0_AcademicOffice":    Vector2(633, 240),
		"F0_HallL1":            Vector2(195, 154),
		"F0_HallL2":            Vector2(288, 254),
		"F0_HallL3":            Vector2(432, 374),
		"F0_HallR1":            Vector2(857, 137),
		"F0_HallR2":            Vector2(709, 296),
		"F0_HallR3":            Vector2(592, 389),
		"F0_AtriumL":           Vector2(452, 289),
		"F0_AtriumR":           Vector2(581, 296),
		"F2_AtriumR":           Vector2(585, 323),
		"F2_2C":                Vector2(315, 172),
		"F2_2A":                Vector2(110, 203),
		"F2_2B":                Vector2(191, 294),
		"F2_2D":                Vector2(833, 274),
		"F2_2E":                Vector2(919, 170),
		"F2_2F":                Vector2(683, 154),
		"F2_StairsR":           Vector2(789, 98),
		"F2_StairsL":           Vector2(220, 97),
		"F2_HallL1":            Vector2(233, 216),
		"F2_HallL2":            Vector2(350, 302),
		"F2_HallL3":            Vector2(427, 379),
		"F2_HallR1":            Vector2(758, 211),
		"F2_HallR2":            Vector2(696, 310),
		"F2_HallR3":            Vector2(598, 394),
		"F2_Library":           Vector2(510, 216),
		"F2_ArtRoom":           Vector2(282, 389),
		"F2_PhysicsLab":        Vector2(725, 399),
		"F2_OfficeHall":        Vector2(511, 450),
		"F2_TeacherOffice":     Vector2(511, 536),
	}
	return c

# Rooms Joe can appear in. Paste from the Student paths tool:
# Appear mode > Export > "Appear spots (a.spots = …)"
func _joe_appear_spots() -> AppearSpots:
	var a := AppearSpots.new()
	a.spots = {
		"F1_1F":           2,
		"F1_1A":           2,
		"F1_ChemistryLab": 2,
		"F0_FabLab1":      1,
		"F0_BoysWC":       1,
		"F0_Gym":          1,
		"F2_2C":           1,
		"F2_2B":           1,
		"F2_ArtRoom":      1,
		"F2_StairsR":      1,
		"F1_BiologyLab":   2,
		"F2_PhysicsLab":   1,
	}
	return a

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

# Checks every room in an appear list exists.
# Input: a label for printing, the list, the master spot list
# Output: number of problems found (0 = all good)
func _check_appear(label: String, a: AppearSpots, locations: LocationList) -> int:
	var errors := 0
	for spot in a.spots:
		if not locations.nodes.has(spot):
			print("[%s appear] unknown spot: '%s'" % [label, spot])
			errors += 1
	return errors

func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	print(path, " -> ", "saved" if err == OK else "FAILED, error %d" % err)
