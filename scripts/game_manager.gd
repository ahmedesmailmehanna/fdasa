extends Node
class_name GameManager
# class_name lets other scripts declare a variable AS a GameManager (not just a
# generic Node), which is what fixes the type-inference error below.

# Fired after any student changes spot. CameraSystem listens to this so the
# feed you're looking at updates live when someone walks in or out of view.
signal student_moved(student: Animatronic, from_spot: String, to_spot: String)
# Fired when a student arrives at the office door (office_door_spot), right
# after student_moved. This is where door logic, a warning sound or a
# jumpscare hooks in, without caring which student it is.
signal student_reached_office(student: Animatronic)
# Fired when a student who was at the office door moves away or leaves the map.
signal student_left_office(student: Animatronic)

# The spot right outside the player's office: the end of every walker's path.
@export var office_door_spot := "F1_OfficeHall"

# Who is standing where. A spot can hold SEVERAL students at once
# (Bees and Meer can both end up on F1_OfficeHall or a shared hallway).
# Key = spot id (String, e.g. "F1_HallL2"), Value = Array of Animatronic
var occupants: Dictionary = {}

# The reverse lookup: which spot each student is on.
# Key = Animatronic, Value = spot id. Lets us find a student's old spot
# without searching every spot.
var _spot_of: Dictionary = {}

func _ready() -> void:
	# Adds this node to a "group" — a tag any node can look up later with
	# get_tree().get_first_node_in_group("game_manager"), from anywhere in
	# this scene, without needing a direct node path.
	add_to_group("game_manager")

# Called once by an Animatronic when it first enters the scene.
# Input: a reference to itself (a), and which spot it's starting on.
# Output: nothing — just records the starting position.
func register_animatronic(a: Animatronic, starting_spot: String) -> void:
	_place(a, starting_spot)

# Called every time an Animatronic finishes a move.
# Input: which animatronic moved (a), and its new spot id.
# Output: nothing — moves it in the occupancy lists and tells listeners.
func on_animatronic_moved(a: Animatronic, new_spot: String) -> void:
	var old_spot: String = _spot_of.get(a, "")
	_remove(a)
	_place(a, new_spot)
	student_moved.emit(a, old_spot, new_spot)
	_check_office(a, old_spot, new_spot)

# Called when a student leaves the map altogether (Joe going back into hiding).
# Input: the student who left.
# Output: nothing — takes it off its spot and tells listeners, with "" as the
#         new spot, so a camera watching that room redraws without him.
func on_animatronic_left(a: Animatronic) -> void:
	var old_spot: String = _spot_of.get(a, "")
	if old_spot == "":
		return   # wasn't on the map anyway
	_remove(a)
	student_moved.emit(a, old_spot, "")
	_check_office(a, old_spot, "")

# Emits the office signals when a move starts or ends at the office door.
func _check_office(a: Animatronic, from_spot: String, to_spot: String) -> void:
	if from_spot == to_spot:
		return
	if to_spot == office_door_spot:
		if a.debug_log:
			DevLog.event(a.get_display_name(), "REACHED THE OFFICE DOOR (%s)" % to_spot)
		student_reached_office.emit(a)
	elif from_spot == office_door_spot:
		if a.debug_log:
			DevLog.event(a.get_display_name(), "left the office door")
		student_left_office.emit(a)

# Input: a spot id, e.g. "F1_HallL2"
# Output: every student standing there right now (empty Array if nobody).
#   e.g. get_students_at("F1_OfficeHall") -> [Bees, Meer]
func get_students_at(spot: String) -> Array:
	return occupants.get(spot, [])

# Input: a student
# Output: the spot it's on, or "" if it never registered.
func get_spot_of(a: Animatronic) -> String:
	return _spot_of.get(a, "")

func _place(a: Animatronic, spot: String) -> void:
	if not occupants.has(spot):
		occupants[spot] = []
	occupants[spot].append(a)
	_spot_of[a] = spot

func _remove(a: Animatronic) -> void:
	var spot: String = _spot_of.get(a, "")
	if spot == "":
		return
	occupants[spot].erase(a)
	if occupants[spot].is_empty():
		occupants.erase(spot)
	_spot_of.erase(a)

# --- Joe's music ------------------------------------------------------------

# Joe registers himself here when he enters the scene. Null if this night
# has no Joe node.
var joe: Joe = null

func register_joe(j: Joe) -> void:
	joe = j

# Students call these before each move, as before. GameManager just asks Joe,
# so students never need to know Joe exists.
# Output: extra aggression right now (0 without Joe)
func get_aggression_bonus() -> float:
	return joe.get_aggression_bonus() if joe else 0.0

# Output: how fast student countdowns run right now (1.0 without Joe)
func get_speed_multiplier() -> float:
	return joe.get_speed_multiplier() if joe else 1.0
