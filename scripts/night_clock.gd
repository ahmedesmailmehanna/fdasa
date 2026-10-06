extends Node
class_name NightClock

# The in-game clock: a "night" is a school day, 9 AM to 3 PM.
# Other systems listen to hour_changed (e.g. teachers refill once per hour).

signal hour_changed(hour: int)   # 10, 11, 12, 13, 14, then 15 = 3 PM
signal night_finished            # reached end_hour: the player survived

@export var start_hour := 9
@export var end_hour := 15
# Real seconds per in-game hour. FNAF1 is about 89 s, so a night is ~9 minutes.
@export var seconds_per_hour := 90.0

var hour := 9
var _elapsed := 0.0

func _ready() -> void:
	add_to_group("night_clock")
	hour = start_hour

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < seconds_per_hour:
		return
	_elapsed -= seconds_per_hour
	hour += 1
	DevLog.event("Clock", get_time_text() + (": night survived" if hour >= end_hour else ""))
	hour_changed.emit(hour)
	if hour >= end_hour:
		set_process(false)
		night_finished.emit()

# Output: the current time as shown to the player, e.g. "9 AM", "12 PM", "2 PM"
func get_time_text() -> String:
	var h12 := hour % 12
	if h12 == 0:
		h12 = 12
	return "%d %s" % [h12, "AM" if hour < 12 else "PM"]
