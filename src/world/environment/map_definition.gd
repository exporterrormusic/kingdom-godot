extends Resource
class_name MapDefinition

## Defines a playable map configuration for the character select mission setup.
@export var map_id: StringName = &""
@export var display_name: String = "Mission Map"
@export_multiline var description: String = ""
@export var preview_texture: Texture2D
@export var biome_id: StringName = &""
@export var time_of_day_id: StringName = &""
@export_range(0, 2147483647, 1) var environment_seed: int = 0
@export var available_time_ids: Array[StringName] = []
@export var difficulty_label: String = ""
@export var world_bounds: Rect2 = Rect2(Vector2(-1920.0, -1080.0), Vector2(3840.0, 2160.0))

func get_available_time_ids() -> Array[StringName]:
	if available_time_ids.is_empty():
		return [time_of_day_id] if time_of_day_id != StringName("") else []
	return available_time_ids


func get_world_bounds() -> Rect2:
	return world_bounds
