extends CanvasLayer
class_name Tablet

# The camera tablet: a screen that flips up over the office, FNAF-style.
# Hover the bar at the bottom (or press Space) to raise or lower it.
# Other systems (power drain, Joe, Sha3er...) listen to the signals below
# instead of the tablet knowing about them.

# Fired when the tablet finishes deciding to open or close.
signal tablet_toggled(is_open: bool)
# Re-emitted from CameraSystem, so listeners only need to know the tablet.
signal camera_changed(camera_id: String)

@export var flip_time := 0.25     # seconds for the flip up / down
@export var toggle_key := KEY_SPACE

@onready var screen: Control = %Screen
@onready var camera_system: CameraSystem = %CameraSystem
@onready var hover_bar: Control = %HoverBar
@onready var hover_label: Label = %HoverLabel

var is_open := false
var _flip_tween: Tween

func _ready() -> void:
	# Start lowered: parked just below the bottom of the window, hidden
	screen.visible = false
	screen.position.y = _screen_height()

	hover_bar.mouse_entered.connect(toggle)
	camera_system.camera_changed.connect(camera_changed.emit)
	get_viewport().size_changed.connect(_on_resized)
	_update_hover_label()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		toggle()
		get_viewport().set_input_as_handled()

# Flips the tablet the other way.
func toggle() -> void:
	set_open(not is_open)

# Input: true to raise the tablet, false to lower it
# Output: none. Animates, bursts static on opening, emits tablet_toggled.
func set_open(open: bool) -> void:
	if open == is_open:
		return
	is_open = open
	if _flip_tween:
		_flip_tween.kill()   # reverse smoothly if toggled mid-flip

	_flip_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if open:
		screen.visible = true
		_flip_tween.tween_property(screen, "position:y", 0.0, flip_time)
		_flip_tween.tween_callback(camera_system.burst_static)
	else:
		_flip_tween.tween_property(screen, "position:y", _screen_height(), flip_time)
		_flip_tween.tween_callback(screen.hide)

	_update_hover_label()
	tablet_toggled.emit(open)

func _screen_height() -> float:
	return get_viewport().get_visible_rect().size.y

func _update_hover_label() -> void:
	hover_label.text = "▼  CAMERAS  ▼" if is_open else "▲  CAMERAS  ▲"

# Keep the lowered tablet parked below the window when it's resized
func _on_resized() -> void:
	if not is_open and (_flip_tween == null or not _flip_tween.is_running()):
		screen.position.y = _screen_height()
