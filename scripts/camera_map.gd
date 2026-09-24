extends Resource
class_name CameraMap

# Every camera, and which node ids it can see.
# Key   = camera id, prefixed by floor, e.g. "F1_CAM_HallL"
# Value = Array of node ids visible on that feed, e.g. ["F1_StairsL", "F1_HallL1"]
# The floor prefix is what the floor-switch button will filter by later.
@export var cameras: Dictionary = {}
