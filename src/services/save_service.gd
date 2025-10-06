extends Node
class_name SaveService

## Handles persistence of player progress, achievements, and settings.
## Intended for autoload registration.

const SAVE_PATH := "user://saves/game_state.json"

var _last_loaded_state: Dictionary = {}

func load_initial_state() -> Dictionary:
	## TODO: Implement JSON loading with validation and fallback defaults.
	ensure_directories()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_last_loaded_state = _default_state()
		return _last_loaded_state
	var text := file.get_as_text()
	file.close()
	var data: Variant = JSON.parse_string(text)
	if typeof(data) == TYPE_DICTIONARY:
		_last_loaded_state = data
	else:
		_last_loaded_state = _default_state()
	_apply_defaults()
	return _last_loaded_state

func save_state(state: Dictionary = _last_loaded_state) -> void:
	## TODO: Write dictionary to SAVE_PATH using FileAccess.
	ensure_directories()
	var payload := state if not state.is_empty() else _last_loaded_state
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	_last_loaded_state = payload.duplicate(true)

func ensure_directories() -> void:
	## Utility to prepare filesystem structure before saving.
	var dir := DirAccess.open("user://saves")
	if dir == null:
		dir = DirAccess.open("user://")
		dir.make_dir_recursive("saves")

func get_state() -> Dictionary:
	return _last_loaded_state

func _apply_defaults() -> void:
	var defaults := _default_state()
	if _last_loaded_state.is_empty():
		_last_loaded_state = defaults.duplicate(true)
	else:
		for key in defaults.keys():
			if not _last_loaded_state.has(key):
				_last_loaded_state[key] = defaults[key]

func _default_state() -> Dictionary:
	return {
		"achievements": {},
		"achievement_stats": {},
	}
