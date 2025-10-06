extends Node
class_name ConfigService

## Loads and exposes runtime configuration values (video, audio, gameplay tuning).
## To be registered as an autoload singleton.

var settings: Dictionary = {}
var _config_path: String = "user://config.cfg"
var _config_section: String = "game_settings"

func ensure_loaded() -> void:
	## TODO: Load from user settings file or defaults.
	if settings.is_empty():
		var cfg := ConfigFile.new()
		var load_result := cfg.load(_config_path)
		var defaults := _default_settings()
		if load_result == OK:
			for key in cfg.get_section_keys(_config_section):
				settings[key] = cfg.get_value(_config_section, key)
		else:
			settings = defaults.duplicate()
		for key in defaults.keys():
			if not settings.has(key):
				settings[key] = defaults[key]
		save()

func get_value(key: String, default_value = null):
	return settings.get(key, default_value)

func set_value(key: String, value) -> void:
	if key in ["master_volume", "music_volume", "sfx_volume"]:
		value = clamp(float(value), 0.0, 1.0)
	settings[key] = value
	save()

func save() -> void:
	var cfg := ConfigFile.new()
	for key in settings.keys():
		cfg.set_value(_config_section, key, settings[key])
	cfg.save(_config_path)

func _default_settings() -> Dictionary:
	return {
		"display_width": 1920,
		"display_height": 1080,
		"fullscreen": false,
		"target_fps": 90,
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"player_name": "Player",
		"default_character_code": "vanguard",
		"key_bindings": {},
		"multiplayer_connection_method": "AUTO",
		"multiplayer_show_ping": true,
		"multiplayer_auto_ready": false,
		"last_character_code": "",
	}
