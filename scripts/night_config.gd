extends Resource
class_name NightConfig

# Every student's level for the whole night.
# 0 = disabled, 1..20 = difficulty. Fixed from start to finish.
@export_range(0, 20) var bees := 0
@export_range(0, 20) var meer := 0
@export_range(0, 20) var sha3er := 0
@export_range(0, 20) var joe := 0
@export_range(0, 20) var wakeel := 0
@export_range(0, 20) var hazem := 0
@export_range(0, 20) var sawy := 0
@export_range(0, 20) var feem := 0

# Night-wide settings
@export var night_number := 1          # e.g. 0 for custom night
@export var starting_power := 100.0

# Input: a student id
# Output: that student's level from this config
func get_level(id: Students.Id) -> int:
	match id:
		Students.Id.BEES: return bees
		Students.Id.MEER: return meer
		Students.Id.SHA3ER: return sha3er
		Students.Id.JOE: return joe
		Students.Id.WAKEEL: return wakeel
		Students.Id.HAZEM: return hazem
		Students.Id.SAWY: return sawy
		Students.Id.FEEM: return feem
	return 0
