extends Resource
class_name CameraMap

# Every camera, and which node ids it can see.
# Key   = camera id, prefixed by floor, e.g. "F1_CAM_HallL"
# Value = Array of node ids visible on that feed, e.g. ["F1_StairsL", "F1_HallL1"]
# The floor prefix is what the floor-switch button will filter by later.
@export var cameras: Dictionary = {}

# Where every camera AND spot sits on the tablet's minimap, in the Student
# paths tool's coordinates (each floor is 1060 x 650). Copied from the tool's
# "Camera map + minimap layout" export.
# Key = camera or spot id, Value = Vector2, e.g. "F1_CAM_HallL": Vector2(372, 154)
@export var positions: Dictionary = {}
