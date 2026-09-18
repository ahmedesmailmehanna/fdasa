extends Control
class_name CameraSystem

# Fill this in from the Inspector (or from code, like night_test.gd does):
# maps node_id -> the background image for that camera.
@export var backgrounds: Dictionary
@onready var bg_display: TextureRect = %CameraBackground
@onready var overlay_display: TextureRect = %CameraOverlay

var game_manager: GameManager   # typed properly — this is the actual fix

func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game_manager") as GameManager

# Call this whenever the player picks a different camera to look at.
# Input: which camera/node id to display, e.g. "F1_Deputy"
# Output: none — updates what's drawn on screen (background + optional
#         student overlay on top of it)
func show_camera(camera_id: String) -> void:
	bg_display.texture = backgrounds.get(camera_id)

	# Now Texture2D is inferable, because game_manager is typed as
	# GameManager — so this line is what was throwing the error before.
	var overlay := game_manager.get_camera_overlay(camera_id)

	overlay_display.texture = overlay
	# If overlay came back null (nobody standing there), hide the overlay
	# TextureRect entirely instead of showing an empty/broken image.
	overlay_display.visible = overlay != null
