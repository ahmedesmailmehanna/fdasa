extends Label
class_name ClockLabel

# The in-game time shown in the office, e.g. "9 AM". It finds the NightClock
# through its group and updates whenever the hour changes, so the clock never
# needs to know this label exists.

func _ready() -> void:
	# Deferred so the clock has joined its group no matter where it sits in
	# the scene tree.
	_connect_clock.call_deferred()

func _connect_clock() -> void:
	var clock := get_tree().get_first_node_in_group("night_clock") as NightClock
	if clock == null:
		text = ""   # this scene has no clock: show nothing rather than a wrong time
		return
	text = clock.get_time_text()
	clock.hour_changed.connect(func(_hour: int) -> void: text = clock.get_time_text())
