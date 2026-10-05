extends BaseButton
class_name MapPointButton

# A room on the tablet's minimap that a teacher can be sent to, shown while
# the TEACHER toggle is on. Its name appears when you hover it.

@export var radius := 9.0
@export var label := ""

const COLOR := Color(0.45, 0.9, 0.55)   # green: "send someone here"

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2.ONE * (radius * 2.0 + 8.0)
	size = custom_minimum_size
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

# Only the circle is clickable
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size / 2.0) <= radius + 4.0

func _draw() -> void:
	var c := size / 2.0
	var hover := is_hovered()
	draw_circle(c, radius, Color(COLOR, 0.75 if hover else 0.35))
	draw_arc(c, radius, 0.0, TAU, 24, COLOR, 3.0 if hover else 2.0, true)
	if hover and label != "":
		var font := get_theme_default_font()
		var fs := 16
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(c.x - w / 2.0, c.y - radius - 8.0)
		draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.9))
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COLOR)
