extends Resource
class_name LocationList

# Every node id that exists anywhere in the building, on every floor.
# No connections here, just the names. Student graphs and the camera map
# are validated against this list so typos get caught in the generator.
@export var nodes: PackedStringArray = []
