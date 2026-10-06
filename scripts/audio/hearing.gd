extends RefCounted
class_name Hearing

# The one rule for "how loud is a sound from over there, heard from here".
# Joe's music uses it, and so should every positional sound later (Bees at
# the door, footsteps, whispers), so the player's ear learns one consistent
# world. Positions are in map units, the same as the tool and c.positions.
#
# Only static functions: you never create a Hearing, you just call
# Hearing.loudness(...)

# Input: where the listener is (position + floor like "F1"), where the sound
#        is, how far it carries on one floor, and how much is kept per floor
#        between them (0.35 = 35%)
# Output: 0.0 (can't hear it) .. 1.0 (right next to it), before the sound's
#         own volume is applied
static func loudness(listener_pos: Vector2, listener_floor: String,
		source_pos: Vector2, source_floor: String,
		hearing_range: float, floor_dampening: float) -> float:
	# 1 right next to it, 0 at hearing_range or further; squared so it drops
	# off quickly and the nearest listener clearly stands out
	var near := clampf(1.0 - listener_pos.distance_to(source_pos) / hearing_range, 0.0, 1.0)
	near *= near
	# Every floor in between muffles it
	var floors_apart := absi(source_floor.to_int() - listener_floor.to_int())
	return near * pow(floor_dampening, floors_apart)
	
	
# Which speaker a sound comes from, for a listener facing a direction.
# Input: where the listener is, the direction it faces (radians in map space:
#        0 = right, -PI/2 = up the map, PI/2 = down), where the sound is
# Output: -1 (fully left) .. 1 (fully right). 0 = straight ahead or right behind
static func pan(listener_pos: Vector2, facing: float, source_pos: Vector2) -> float:
	if listener_pos.distance_to(source_pos) < 1.0:
		return 0.0   # same place: no direction
	# The sound's angle relative to where the listener looks, in -PI..PI
	var relative := wrapf((source_pos - listener_pos).angle() - facing, -PI, PI)
	# sin is +1 when the sound is 90 degrees to the right, -1 to the left
	return sin(relative)
