extends BaseButton
class_name CamMapButton

# One camera on the tablet's minimap: a clickable circle with the camera's
# short name under it. The view cone is drawn by CameraSystem's map, behind
# all buttons, so cones never cover another camera's circle.

@export var radius := 13.0
@export var label := ""

const COLOR_IDLE := Color(0.12, 0.13, 0.15)
const COLOR_RING := Color(1, 1, 1, 0.85)
const COLOR_ACTIVE := Color(1.0, 0.8, 0.35)

func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Square just big enough for the circle; the name is drawn below it
	custom_minimum_size = Vector2.ONE * (radius * 2.0 + 6.0)
	size = custom_minimum_size
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_on: bool) -> void: queue_redraw())

# Only the circle is clickable, not the corners of the square around it
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size / 2.0) <= radius + 3.0

func _draw() -> void:
	var c := size / 2.0
	var active := button_pressed
	var hover := is_hovered()

	# Circle: amber when it's the camera you're watching
	draw_circle(c, radius, COLOR_ACTIVE if active else COLOR_IDLE)
	draw_arc(c, radius, 0.0, TAU, 32, COLOR_ACTIVE if active else COLOR_RING, 3.0 if hover else 2.0, true)
	# A small "lens" dot in the middle
	draw_circle(c, radius * 0.35, COLOR_IDLE if active else COLOR_RING)

	# Name under the circle, with a dark outline so it reads over the map
	if label != "":
		# The tablet's font (set by CameraSystem's theme), or Godot's default
		var font := get_theme_default_font()
		var fs := 15
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(c.x - w / 2.0, c.y + radius + 18.0)
		draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.9))
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COLOR_ACTIVE if active else Color.WHITE)
