extends Resource
class_name CharacterRoster

const CharacterDataScript := preload("res://src/resources/character_data.gd")
const WeaponCatalogScript := preload("res://src/resources/weapon_catalog.gd")
const DEFAULT_PORTRAIT_PATH := "res://assets/images/example_character.png"
const DEFAULT_SPRITE_COLUMNS := 3
const DEFAULT_SPRITE_ROWS := 4
const DEFAULT_SPRITE_SCALE := 0.2
const DEFAULT_PROJECTILE_RADIUS := 4.0

@export var characters: Array[CharacterDataScript] = []
@export var auto_populate_from_legacy: bool = true
@export var legacy_source_directory: String = "res://assets/images/Characters"
@export var weapons_config_path: String = "res://assets/weapons.json"

var _loaded := false
var _weapon_catalog: Resource = null

func ensure_loaded() -> void:
	if _loaded:
		return
	if auto_populate_from_legacy and characters.is_empty():
		characters = _load_characters_from_legacy()
	_loaded = true

func get_default_character() -> CharacterDataScript:
	ensure_loaded()
	return characters[0] if characters.size() > 0 else null

func get_character_by_code(code_name: String) -> CharacterDataScript:
	ensure_loaded()
	for character in characters:
		if character and character.code_name == code_name:
			return character
	return null

func get_index_for_character(target: CharacterDataScript) -> int:
	ensure_loaded()
	return characters.find(target)

func _load_characters_from_legacy() -> Array[CharacterDataScript]:
	var roster: Array[CharacterDataScript] = []
	var dir := DirAccess.open(legacy_source_directory)
	if dir == null:
		push_warning("CharacterRoster: Unable to open legacy directory %s" % legacy_source_directory)
		return roster

	var folders: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			folders.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()

	folders.sort()
	for folder_name in folders:
		var config_path := "%s/%s/config.json" % [legacy_source_directory, folder_name]
		if not FileAccess.file_exists(config_path):
			continue
		var config: Dictionary = _read_config(config_path)
		if config.is_empty():
			continue
		var character := _build_character_from_config(folder_name, config)
		if character:
			roster.append(character)

	return roster

func _read_config(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("CharacterRoster: Failed to open %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed_result: Variant = JSON.parse_string(text)
	if parsed_result is Dictionary:
		return parsed_result as Dictionary
	push_warning("CharacterRoster: Invalid JSON in %s" % path)
	return {}

func _as_int(value: Variant, default_value: int = 0) -> int:
	match typeof(value):
		TYPE_NIL:
			return default_value
		TYPE_INT:
			return value
		TYPE_FLOAT:
			return int(value)
		TYPE_BOOL:
			return 1 if value else 0
		TYPE_STRING:
			var string_value: String = value
			string_value = string_value.strip_edges()
			if string_value.is_empty():
				return default_value
			if string_value.is_valid_int():
				return string_value.to_int()
			if string_value.is_valid_float():
				return int(string_value.to_float())
			return default_value
		_:
			return default_value

func _as_float(value: Variant, default_value: float = 0.0) -> float:
	match typeof(value):
		TYPE_NIL:
			return default_value
		TYPE_INT, TYPE_FLOAT:
			return float(value)
		TYPE_BOOL:
			return 1.0 if value else 0.0
		TYPE_STRING:
			var string_value: String = value
			string_value = string_value.strip_edges()
			if string_value.is_empty():
				return default_value
			if string_value.is_valid_float():
				return string_value.to_float()
			if string_value.is_valid_int():
				return float(string_value.to_int())
			return default_value
		_:
			return default_value

func _build_character_from_config(folder_name: String, config: Dictionary) -> CharacterDataScript:
	var character := CharacterDataScript.new()
	character.sprite_scale = DEFAULT_SPRITE_SCALE

	character.code_name = folder_name
	character.display_name = str(config.get("display_name", folder_name.capitalize()))
	character.description = str(config.get("description", character.description))

	if config.has("role"):
		character.role = str(config["role"])
	if config.has("difficulty" ):
		character.difficulty = str(config["difficulty"])

	var stats_variant: Variant = config.get("stats", {})
	if stats_variant is Dictionary:
		var stats: Dictionary = stats_variant as Dictionary
		character.speed_rating = _as_int(stats.get("speed", character.speed_rating), character.speed_rating)
		character.hp = _as_int(stats.get("hp", character.hp), character.hp)
		character.burst_rating = _as_int(stats.get("burst_multiplier", character.burst_rating), character.burst_rating)

	character.weapon_name = str(config.get("weapon_name", character.weapon_name))
	character.weapon_type = str(config.get("weapon_type", character.weapon_type))

	_apply_weapon_details(character)

	var burst_variant: Variant = config.get("burst_ability", {})
	if burst_variant is Dictionary:
		var burst: Dictionary = burst_variant as Dictionary
		character.burst_name = str(burst.get("name", character.burst_name))
		character.burst_description = str(burst.get("description", character.burst_description))
		character.burst_damage_multiplier = _as_float(burst.get("damage_multiplier", character.burst_damage_multiplier), character.burst_damage_multiplier)

	var sprite_info_variant: Variant = config.get("sprite_info", {})
	var sprite_info: Dictionary = {}
	if sprite_info_variant is Dictionary:
		sprite_info = sprite_info_variant as Dictionary
		character.sprite_animation_fps = _calculate_animation_fps(_as_float(sprite_info.get("animation_speed", 0.2), 0.2))

	_assign_visual_assets(character, folder_name, sprite_info)

	character.attack = _as_int(character.attack, character.attack)
	return character

func _get_weapon_catalog() -> Resource:
	if _weapon_catalog == null:
		_weapon_catalog = WeaponCatalogScript.new()
		if _weapon_catalog.has_method("set"):
			_weapon_catalog.set("weapons_config_path", weapons_config_path)
	if _weapon_catalog.has_method("ensure_loaded"):
		_weapon_catalog.ensure_loaded()
	return _weapon_catalog

func _apply_weapon_details(character: CharacterDataScript) -> void:
	var weapon_type := character.weapon_type
	if weapon_type.is_empty():
		return
	var catalog := _get_weapon_catalog()
	if catalog == null or not catalog.has_method("weapon_exists") or not catalog.weapon_exists(weapon_type):
		return
	var weapon_config: Dictionary = catalog.get_weapon_config(weapon_type)
	if weapon_config.is_empty():
		return
	character.weapon_description = str(weapon_config.get("description", character.weapon_description))
	character.fire_mode = catalog.get_fire_mode(weapon_type, character.fire_mode)
	character.fire_rate = max(catalog.get_fire_rate(weapon_type, character.fire_rate), 0.01)
	character.projectile_damage = catalog.get_damage(weapon_type, character.projectile_damage)
	character.attack = character.projectile_damage
	character.projectile_range = catalog.get_range(weapon_type, character.projectile_range)
	var ammo_data: Dictionary = catalog.get_category(weapon_type, "ammo")
	if not ammo_data.is_empty():
		character.magazine_size = _as_int(ammo_data.get("magazine_size", character.magazine_size), character.magazine_size)
		character.reload_time = _as_float(ammo_data.get("reload_time", character.reload_time), character.reload_time)
		character.grenade_rounds = _as_int(ammo_data.get("grenade_rounds", character.grenade_rounds), character.grenade_rounds)
		character.grenade_reload_time = _as_float(ammo_data.get("grenade_reload_time", character.grenade_reload_time), character.grenade_reload_time)
	var bullet_props: Dictionary = catalog.get_bullet_properties(weapon_type)
	if not bullet_props.is_empty():
		var speed_value := _as_float(bullet_props.get("speed", character.projectile_speed), character.projectile_speed)
		character.projectile_speed = max(0.0, speed_value)
		character.projectile_penetration = _as_int(bullet_props.get("penetration", character.projectile_penetration), character.projectile_penetration)
		character.projectile_shape = str(bullet_props.get("shape", character.projectile_shape))
		var size_multiplier := _as_float(bullet_props.get("size_multiplier", 1.0), 1.0)
		character.projectile_radius = max(1.0, DEFAULT_PROJECTILE_RADIUS * max(0.1, size_multiplier))
		var color_variant: Variant = bullet_props.get("color", character.projectile_color)
		character.projectile_color = _to_color(color_variant, character.projectile_color)
		if character.projectile_speed > 0.0 and character.projectile_range > 0.0:
			character.projectile_lifetime = max(0.05, character.projectile_range / character.projectile_speed)
	var special_mechanics: Dictionary = catalog.get_special_mechanics(weapon_type)
	character.special_mechanics = special_mechanics.duplicate(true) if not special_mechanics.is_empty() else {}
	if not special_mechanics.is_empty():
		character.pellet_count = _as_int(special_mechanics.get("pellet_count", character.pellet_count), character.pellet_count)
		character.spread_angle = _as_float(special_mechanics.get("spread_angle", character.spread_angle), character.spread_angle)
	var special_attack: Dictionary = catalog.get_special_attack(weapon_type)
	character.special_attack_data = special_attack.duplicate(true) if not special_attack.is_empty() else {}
	if not special_attack.is_empty():
		character.weapon_special_name = str(special_attack.get("name", character.weapon_special_name))
		character.weapon_special_description = str(special_attack.get("description", character.weapon_special_description))
	else:
		character.weapon_special_name = character.weapon_special_name
		character.weapon_special_description = character.weapon_special_description

func _assign_visual_assets(character: CharacterDataScript, folder_name: String, sprite_info: Dictionary) -> void:
	var base_paths := _gather_character_asset_paths(folder_name)
	var portrait_texture := _load_texture_from_candidates(base_paths, [
		"portrait-sq.png",
		"busrt-sq.png",
		"portrait.png"
	])
	var burst_texture := _load_texture_from_candidates(base_paths, ["burst.png"])
	if portrait_texture:
		character.portrait_texture = portrait_texture
	elif burst_texture:
		character.portrait_texture = burst_texture
	else:
		var default_texture: Texture2D = _load_texture_if_exists(DEFAULT_PORTRAIT_PATH)
		if default_texture:
			character.portrait_texture = default_texture
		else:
			push_warning("CharacterRoster: Missing portrait textures for %s" % folder_name)

	if burst_texture:
		character.burst_texture = burst_texture
	else:
		push_warning("CharacterRoster: Missing burst texture for %s" % folder_name)

	if typeof(sprite_info) == TYPE_DICTIONARY and sprite_info.has("filename"):
		var filename := str(sprite_info.get("filename", ""))
		if filename != "":
			var sprite_path := _find_existing_file(base_paths, filename)
			if sprite_path != "":
				var sprite_tex := load(sprite_path)
				if sprite_tex is Texture2D:
					character.sprite_sheet = sprite_tex
					var frame_width := _as_int(sprite_info.get("frame_width"), 0)
					var frame_height := _as_int(sprite_info.get("frame_height"), 0)
					var grid: Vector2i = _infer_sprite_grid(sprite_tex, frame_width, frame_height)
					character.sprite_sheet_columns = max(1, grid.x)
					character.sprite_sheet_rows = max(1, grid.y)
					character.sprite_animation_fps = character.sprite_animation_fps if character.sprite_animation_fps > 0.0 else _calculate_animation_fps(0.2)
					var scale_variant: Variant = sprite_info.get("scale_factor", null)
					if scale_variant == null:
						scale_variant = sprite_info.get("scale", null)
					var inferred_scale: float = _as_float(scale_variant, DEFAULT_SPRITE_SCALE)
					if inferred_scale <= 0.0:
						inferred_scale = DEFAULT_SPRITE_SCALE
					character.sprite_scale = inferred_scale

func _load_texture_if_exists(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not FileAccess.file_exists(path):
		return null
	var resource := ResourceLoader.load(path)
	if resource is Texture2D:
		return resource
	return null

func _gather_character_asset_paths(folder_name: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var primary := "%s/%s" % [legacy_source_directory, folder_name]
	if not paths.has(primary):
		paths.append(primary)
	var alternates := PackedStringArray([
		"res://assets/images/characters/%s" % folder_name
	])
	for alt in alternates:
		if alt != "" and not paths.has(alt):
			paths.append(alt)
	return paths

func _load_texture_from_candidates(base_paths: PackedStringArray, file_names: Array) -> Texture2D:
	for file_name in file_names:
		for base_path in base_paths:
			var candidate_path := "%s/%s" % [base_path, file_name]
			var texture := _load_texture_if_exists(candidate_path)
			if texture:
				return texture
	return null

func _find_existing_file(base_paths: PackedStringArray, file_name: String) -> String:
	for base_path in base_paths:
		var candidate_path := "%s/%s" % [base_path, file_name]
		if FileAccess.file_exists(candidate_path):
			return candidate_path
	return ""

func _infer_sprite_grid(sprite_tex: Texture2D, frame_width: int, frame_height: int) -> Vector2i:
	var tex_size: Vector2 = sprite_tex.get_size()
	if frame_width > 0 and frame_height > 0:
		var inferred_columns: int = max(1, int(round(tex_size.x / max(1.0, float(frame_width)))))
		var inferred_rows: int = max(1, int(round(tex_size.y / max(1.0, float(frame_height)))))
		return Vector2i(inferred_columns, inferred_rows)

	var width := int(tex_size.x)
	var height := int(tex_size.y)
	var columns: int = DEFAULT_SPRITE_COLUMNS
	var rows: int = DEFAULT_SPRITE_ROWS

	if width > 0:
		var column_candidates := PackedInt32Array([DEFAULT_SPRITE_COLUMNS, 4, 5, 6, 8])
		for candidate in column_candidates:
			if candidate > 1 and width % candidate == 0:
				columns = candidate
				break
	if height > 0:
		var row_candidates := PackedInt32Array([DEFAULT_SPRITE_ROWS, 4, 5, 6])
		for candidate in row_candidates:
			if candidate > 1 and height % candidate == 0:
				rows = candidate
				break

	return Vector2i(max(1, columns), max(1, rows))

func _calculate_animation_fps(frame_time: float) -> float:
	if frame_time <= 0.0:
		return 6.0
	return 1.0 / frame_time

func _to_color(value: Variant, default_color: Color) -> Color:
	match typeof(value):
		TYPE_COLOR:
			return value
		TYPE_ARRAY:
			return _array_to_color(value as Array, default_color)
		TYPE_PACKED_FLOAT32_ARRAY:
			return _array_to_color(Array(value), default_color)
		TYPE_PACKED_INT32_ARRAY:
			return _array_to_color(Array(value), default_color)
		TYPE_PACKED_BYTE_ARRAY:
			return _array_to_color(Array(value), default_color)
		TYPE_STRING:
			return Color.from_string(value, default_color)
	return default_color

func _array_to_color(values: Array, default_color: Color) -> Color:
	if values.is_empty():
		return default_color
	var r := _color_component_to_float(values[0], default_color.r)
	var g := r
	var b := r
	var a := 1.0
	if values.size() > 1:
		g = _color_component_to_float(values[1], default_color.g)
	if values.size() > 2:
		b = _color_component_to_float(values[2], default_color.b)
	if values.size() > 3:
		a = _color_component_to_float(values[3], default_color.a)
	return Color(r, g, b, a)

func _color_component_to_float(value: Variant, default_value: float = 0.0) -> float:
	match typeof(value):
		TYPE_FLOAT:
			return clampf(value, 0.0, 1.0)
		TYPE_INT:
			if value > 1:
				return clampf(float(value) / 255.0, 0.0, 1.0)
			return clampf(float(value), 0.0, 1.0)
		TYPE_BOOL:
			return 1.0 if value else 0.0
		TYPE_STRING:
			var number_str: String = value.strip_edges()
			if number_str.is_valid_float():
				var parsed := number_str.to_float()
				if parsed > 1.0:
					return clampf(parsed / 255.0, 0.0, 1.0)
				return clampf(parsed, 0.0, 1.0)
	return clampf(default_value, 0.0, 1.0)
