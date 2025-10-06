extends Node
class_name AchievementService

## Tracks and unlocks achievements; relays notifications to UI layers.
## Register as an AutoLoad to make signals globally available.

signal achievement_unlocked(id: String)

const AchievementCatalogPath := "res://resources/achievements/achievements.tres"

var _catalog: Resource = null
var _definitions: Dictionary = {}
var _unlocked: Dictionary = {}
var _stats_total: Dictionary = {}
var _stats_run: Dictionary = {}
var _save_service: SaveService = null

func initialize(save_service: SaveService, save_data: Dictionary) -> void:
	_save_service = save_service
	_catalog = _load_catalog()
	_unlocked = save_data.get("achievements", {}).duplicate(true)
	_stats_total = save_data.get("achievement_stats", {}).duplicate(true)
	_stats_run = {}
	_register_definitions()
	_evaluate_all()

func get_all_definitions() -> Array:
	return _catalog.get_all() if _catalog and _catalog.has_method("get_all") else []

func get_definition(id: String):
	return _definitions.get(id, null)

func load_from_save(save_data: Dictionary) -> void:
	_unlocked = save_data.get("achievements", {}).duplicate(true)
	_stats_total = save_data.get("achievement_stats", {}).duplicate(true)
	_evaluate_all()

func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)

func record_stat(stat_key: String, amount: int = 1) -> void:
	if stat_key == "" or amount == 0:
		return
	var is_run_stat := stat_key.ends_with("_run")
	if is_run_stat:
		_stats_run[stat_key] = _stats_run.get(stat_key, 0) + amount
	else:
		_stats_total[stat_key] = _stats_total.get(stat_key, 0) + amount
	_evaluate_for_stat(stat_key)
	if not is_run_stat:
		_persist_stats()

func reset_run_stats() -> void:
	_stats_run.clear()

func unlock(id: String) -> void:
	if is_unlocked(id):
		return
	_unlocked[id] = true
	emit_signal("achievement_unlocked", id)
	_persist_unlocks()

func get_stat_value(stat_key: String) -> int:
	if stat_key.ends_with("_run"):
		return _stats_run.get(stat_key, 0)
	return _stats_total.get(stat_key, 0)

func get_save_payload() -> Dictionary:
	return {
		"achievements": _unlocked.duplicate(true),
		"achievement_stats": _stats_total.duplicate(true),
	}

func _register_definitions() -> void:
	_definitions.clear()
	var definitions := get_all_definitions()
	for definition in definitions:
		if definition and definition.has_method("get"):
			var identifier = definition.get("id")
			if typeof(identifier) == TYPE_STRING and identifier != "":
				_definitions[identifier] = definition

func _evaluate_for_stat(stat_key: String) -> void:
	for definition in _definitions.values():
		if not definition:
			continue
		if definition.get("stat_key") != stat_key:
			continue
		var target := int(definition.get("target_value"))
		if target <= 0:
			continue
		if is_unlocked(definition.get("id")):
			continue
		var current := get_stat_value(stat_key)
		if current >= target:
			unlock(definition.get("id"))

func _evaluate_all() -> void:
	for definition in _definitions.values():
		if not definition:
			continue
		var stat_key := String(definition.get("stat_key"))
		if stat_key == "":
			continue
		var target := int(definition.get("target_value"))
		if target <= 0:
			continue
		if is_unlocked(definition.get("id")):
			continue
		var current := get_stat_value(stat_key)
		if current >= target:
			unlock(definition.get("id"))

func _persist_unlocks() -> void:
	if not _save_service:
		return
	var state := _save_service.get_state()
	state["achievements"] = _unlocked.duplicate(true)
	_save_service.save_state(state)

func _persist_stats() -> void:
	if not _save_service:
		return
	var state := _save_service.get_state()
	state["achievement_stats"] = _stats_total.duplicate(true)
	_save_service.save_state(state)

func _load_catalog() -> Resource:
	if ResourceLoader.exists(AchievementCatalogPath):
		return load(AchievementCatalogPath)
	return null
