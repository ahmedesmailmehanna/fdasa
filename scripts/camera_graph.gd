extends Resource
class_name CameraGraph

# The map itself, as a directed graph.
# Key   = a node id, e.g. "F1_Deputy"
# Value = an Array of node ids reachable directly from that node.
# This is what Animatronic._attempt_move() reads to decide where it can go.
@export var nodes: Dictionary = {}
