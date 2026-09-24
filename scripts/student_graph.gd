extends Resource
class_name StudentGraph

# The map one student is allowed to walk, as a weighted directed graph.
# Key   = node id the student is standing on, e.g. "F1_HallL2"
# Value = a Dictionary of { neighbor_id: weight }
#         Higher weight = more likely to be picked. Weights are relative:
#         {"A": 3, "B": 1} means A is 3x as likely as B.
#         A node with an empty {} is a stopping point (e.g. the office door).
@export var nodes: Dictionary = {}
