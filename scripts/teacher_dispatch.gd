extends Node
class_name TeacherDispatch

# The principal can call a teacher and send them to a room, e.g. to stop
# Joe's music. Limited uses per night: starts full, refills by 1 every
# in-game hour, never above max_uses. One teacher can be on the way at a time.

signal uses_changed(uses: int)
signal teacher_sent(spot: String)                       # hook for the phone voice line later
signal teacher_arrived(spot: String, stopped_joe: bool)

@export var max_uses := 3
@export var travel_time := 4.0   # seconds between the call and the teacher arriving
# Prints every call, arrival and refill to the Output tab.
@export var debug_log := true

var uses := 3
var en_route_spot := ""          # where the current teacher is heading, "" if none
var game_manager: GameManager

func _ready() -> void:
	add_to_group("teacher_dispatch")
	uses = max_uses
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager
	# Deferred so the clock exists no matter where it sits in the scene tree
	_connect_clock.call_deferred()

func _connect_clock() -> void:
	var clock := get_tree().get_first_node_in_group("night_clock") as NightClock
	if clock:
		clock.hour_changed.connect(_on_hour_changed)

# Output: true if a teacher can be sent right now
func can_send() -> bool:
	return uses > 0 and en_route_spot == ""

# Input: the spot to send a teacher to, e.g. "F1_1B"
# Output: true if a teacher was sent (false if none left or one is already on the way)
func send_teacher(spot: String) -> bool:
	if not can_send():
		if uses <= 0:
			_log("can't send to %s: no teachers left." % spot)
		else:
			_log("can't send to %s: one is already on the way to %s." % [spot, en_route_spot])
		return false
	uses -= 1
	en_route_spot = spot
	_log("sent to %s, arrives in %ds (%d of %d left)." % [spot, int(travel_time), uses, max_uses])
	uses_changed.emit(uses)
	teacher_sent.emit(spot)
	get_tree().create_timer(travel_time).timeout.connect(_on_arrived)
	return true

# The teacher reaches the room: if Joe is blasting there, he's stopped.
func _on_arrived() -> void:
	var spot := en_route_spot
	en_route_spot = ""
	var joe := game_manager.joe
	var stopped := joe != null and joe.is_blasting_at(spot)
	if stopped:
		_log("arrived at %s: Joe is here, stopping him." % spot)
		joe.get_stopped()
	elif joe == null:
		_log("arrived at %s: nothing there (this night has no Joe)." % spot)
	elif joe.is_music_blasting:
		_log("arrived at %s: WRONG ROOM, Joe is blasting in %s. Teacher wasted." % [spot, joe.current_node])
	else:
		_log("arrived at %s: Joe isn't playing right now. Teacher wasted." % spot)
	teacher_arrived.emit(spot, stopped)

# +1 use every in-game hour, capped at max_uses
func _on_hour_changed(_hour: int) -> void:
	if uses < max_uses:
		uses += 1
		_log("new hour: +1 teacher (%d of %d)." % [uses, max_uses])
		uses_changed.emit(uses)

func _log(text: String) -> void:
	if debug_log:
		print("[Teacher] ", text)
