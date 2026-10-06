extends Node
class_name TeacherDispatch

# The principal can call a teacher and send them to a room, e.g. to stop
# Joe's music. Limited uses per night: starts full, refills by 1 every
# in-game hour, never above max_uses. One teacher can be on the way at a time.

signal uses_changed(uses: int)
signal teacher_sent(spot: String)                       # hook for the phone voice line later
# A teacher reached the room. Always fires, whatever they found there.
signal teacher_arrived(spot: String, stopped_joe: bool)
# Exactly one of these two fires right after teacher_arrived:
signal teacher_found_joe(spot: String)     # Joe was blasting there and got stopped
signal teacher_missed_joe(spot: String)    # wrong room, or Joe wasn't playing: a wasted teacher
# The player asked for a teacher but none could go.
# reason is "none_left" or "busy" (one is already on the way).
signal send_refused(spot: String, reason: String)

@export var max_uses := 3
@export var travel_time := 4.0   # seconds between the call and the teacher arriving
# Prints every call, arrival and refill to Output. See dev_log.gd.
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
			_log("can't go to %s: none left" % spot)
			send_refused.emit(spot, "none_left")
		else:
			_log("can't go to %s: one is already heading to %s" % [spot, en_route_spot])
			send_refused.emit(spot, "busy")
		return false
	uses -= 1
	en_route_spot = spot
	_log("sent to %s, arrives in %ds (%d/%d left)" % [spot, int(travel_time), uses, max_uses])
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
		_log("found Joe in %s" % spot)
		joe.get_stopped()
	elif joe != null and joe.is_music_blasting:
		_log("missed Joe: went to %s, he's in %s" % [spot, joe.current_node])
	else:
		_log("found nobody in %s (Joe isn't playing)" % spot)
	teacher_arrived.emit(spot, stopped)
	if stopped:
		teacher_found_joe.emit(spot)
	else:
		teacher_missed_joe.emit(spot)

# +1 use every in-game hour, capped at max_uses
func _on_hour_changed(_hour: int) -> void:
	if uses < max_uses:
		uses += 1
		_log("+1 for the new hour (%d/%d)" % [uses, max_uses])
		uses_changed.emit(uses)

func _log(text: String) -> void:
	if debug_log:
		DevLog.event("Teacher", text)
