extends RefCounted
class_name DevLog

# One format for every debug line in the game, so Output reads as a timeline:
#
#   [0:10] Joe      appeared in F1_BiologyLab (on F1_CAM_Biology)
#   [0:14] Bees     moved F1_HallL1 -> F1_HallL2
#   [0:31] Teacher  found Joe in F1_BiologyLab
#
# Call it from anywhere: DevLog.event("Joe", "appeared in ...")
# The time is minutes:seconds since the night started.
#
# What belongs here: things that HAPPEN in the game (someone moved, appeared,
# got stopped, an hour passed). What doesn't: things that didn't happen
# (a student staying put), what the player clicks, and anything per-frame.

# Master switch: false silences every line at once.
static var enabled := true
# Tags to hide while you focus on something else, e.g. ["Audio", "Clock"].
static var muted: Array[String] = []

static var _night_start_msec := 0

# Called by the night when it starts, so times count from 0:00.
static func start_night() -> void:
	_night_start_msec = Time.get_ticks_msec()

# Prints one line.
# Input: who it's about ("Joe", "Bees", "Teacher", "Clock"...), and what happened
# Output: none
static func event(tag: String, text: String) -> void:
	if not enabled or tag in muted:
		return
	var seconds := (Time.get_ticks_msec() - _night_start_msec) / 1000
	# %-8s pads the tag to 8 characters, so the messages line up in a column
	print("[%d:%02d] %-8s %s" % [seconds / 60, seconds % 60, tag, text])
