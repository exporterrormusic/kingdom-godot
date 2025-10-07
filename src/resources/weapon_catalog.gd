extends Resource
class_name WeaponCatalog

@export var weapons_config_path: String = "res://assets/weapons.json"

var _weapon_data: Dictionary = {}
var _has_tried_load := false

func ensure_loaded() -> void:
	if _has_tried_load and not _weapon_data.is_empty():
		return
	_has_tried_load = true
	_weapon_data = {}
	if weapons_config_path.is_empty():
		return
	if not FileAccess.file_exists(weapons_config_path):
		return
	var file := FileAccess.open(weapons_config_path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed_variant: Variant = JSON.parse_string(text)
	if parsed_variant is Dictionary:
		var parsed_dict: Dictionary = parsed_variant as Dictionary
		var categories_variant: Variant = parsed_dict.get("weapon_categories", {})
		if categories_variant is Dictionary:
			_weapon_data = (categories_variant as Dictionary).duplicate(true)

func get_weapon_config(weapon_type: String) -> Dictionary:
	ensure_loaded()
	var variant: Variant = _weapon_data.get(weapon_type, {})
	return variant as Dictionary if variant is Dictionary else {}

func weapon_exists(weapon_type: String) -> bool:
	ensure_loaded()
	return _weapon_data.has(weapon_type)

func get_weapon_property(weapon_type: String, category: String, property_name: String, default_value = null):
	var config: Dictionary = get_weapon_config(weapon_type)
	if config.is_empty():
		return default_value
	if category.is_empty():
		return config.get(property_name, default_value)
	var sub_variant: Variant = config.get(category, {})
	if sub_variant is Dictionary:
		return (sub_variant as Dictionary).get(property_name, default_value)
	return default_value

func get_category(weapon_type: String, category: String) -> Dictionary:
	var config: Dictionary = get_weapon_config(weapon_type)
	if config.is_empty():
		return {}
	var variant: Variant = config.get(category, {})
	return variant as Dictionary if variant is Dictionary else {}

func get_fire_rate(weapon_type: String, default_value: float = 0.25) -> float:
	return float(get_weapon_property(weapon_type, "firing", "fire_rate", default_value))

func get_damage(weapon_type: String, default_value: int = 1) -> int:
	return int(get_weapon_property(weapon_type, "firing", "damage", default_value))

func get_range(weapon_type: String, default_value: float = 800.0) -> float:
	return float(get_weapon_property(weapon_type, "firing", "range", default_value))

func get_magazine_size(weapon_type: String, default_value: int = 30) -> int:
	return int(get_weapon_property(weapon_type, "ammo", "magazine_size", default_value))

func get_reload_time(weapon_type: String, default_value: float = 2.0) -> float:
	return float(get_weapon_property(weapon_type, "ammo", "reload_time", default_value))

func get_fire_mode(weapon_type: String, default_value: String = "automatic") -> String:
	var config: Dictionary = get_weapon_config(weapon_type)
	return str(config.get("fire_mode", default_value)) if not config.is_empty() else default_value

func get_bullet_properties(weapon_type: String) -> Dictionary:
	var config: Dictionary = get_weapon_config(weapon_type)
	if config.is_empty():
		return {}
	var bullet_variant: Variant = config.get("bullet_properties", {})
	var bullet_dict: Dictionary = bullet_variant as Dictionary if bullet_variant is Dictionary else {}
	if bullet_dict.is_empty():
		return {}
	var result: Dictionary = bullet_dict.duplicate(true)
	if not result.has("range"):
		result["range"] = get_range(weapon_type, 800.0)
	return result

func get_special_mechanics(weapon_type: String) -> Dictionary:
	return get_category(weapon_type, "special_mechanics")

func get_special_attack(weapon_type: String) -> Dictionary:
	return get_category(weapon_type, "special_attack")

func list_weapon_types() -> PackedStringArray:
	ensure_loaded()
	return PackedStringArray(_weapon_data.keys())
