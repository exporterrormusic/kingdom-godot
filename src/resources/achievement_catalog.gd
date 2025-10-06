extends Resource
class_name AchievementCatalog

@export var achievements: Array[Resource] = []

func get_all() -> Array[Resource]:
	return achievements

func get_by_id(id: String) -> Resource:
	for achievement in achievements:
		if achievement and achievement.has_method("get"):
			var value = achievement.get("id")
			if typeof(value) == TYPE_STRING and value == id:
				return achievement
	return null
