extends Resource
class_name AppearSpots

# Rooms a student who doesn't walk (like Joe) can show up in, with weights.
# Key   = spot id, e.g. "F1_1A"
# Value = weight: higher = more likely. Relative, like path weights:
#         {"F1_1A": 2, "F1_1B": 1} means 1A is twice as likely as 1B.
# Designed in the Student paths tool (Appear mode), saved by generate_graphs.gd.
@export var spots: Dictionary = {}
