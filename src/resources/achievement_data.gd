extends Resource
class_name AchievementData

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var stat_key: String = ""
@export var target_value: int = 1
@export var category: String = "General"
@export var is_hidden: bool = false
@export var icon: Texture2D

func is_valid() -> bool:
	return id != "" and stat_key != "" and target_value > 0
