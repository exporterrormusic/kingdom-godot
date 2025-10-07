extends Node
class_name WorldManager

## Drives wave progression, spawn pacing, and survival objectives within a run.
## Equivalent to the Pygame world manager but tailored for Godot scenes.

signal wave_started(wave_index: int, definition: Dictionary)
signal wave_completed(wave_index: int, definition: Dictionary)
signal objective_updated(text: String)
signal run_time_updated(total_seconds: float)

const DEFAULT_WAVES := [
	{
		"id": 1,
		"count": 12,
		"spawn_interval": 1.35,
		"health_multiplier": 1.0,
		"speed_multiplier": 1.0,
		"damage_multiplier": 1.0,
		"enemy_mix": [
			{"type": "grunt", "weight": 1.0}
		]
	},
	{
		"id": 2,
		"count": 20,
		"spawn_interval": 1.15,
		"health_multiplier": 1.1,
		"speed_multiplier": 1.05,
		"damage_multiplier": 1.0,
		"enemy_mix": [
			{"type": "grunt", "weight": 0.6},
			{"type": "striker", "weight": 0.4, "speed_bonus": 0.15}
		]
	},
	{
		"id": 3,
		"count": 34,
		"spawn_interval": 1.0,
		"health_multiplier": 1.2,
		"speed_multiplier": 1.1,
		"damage_multiplier": 1.1,
		"enemy_mix": [
			{"type": "grunt", "weight": 0.4},
			{"type": "striker", "weight": 0.4, "speed_bonus": 0.2},
			{"type": "brute", "weight": 0.2, "health_bonus": 0.4}
		]
	},
	{
		"id": 4,
		"count": 58,
		"spawn_interval": 0.85,
		"health_multiplier": 1.35,
		"speed_multiplier": 1.15,
		"damage_multiplier": 1.2,
		"enemy_mix": [
			{"type": "striker", "weight": 0.5, "speed_bonus": 0.2},
			{"type": "brute", "weight": 0.35, "health_bonus": 0.35},
			{"type": "grenadier", "weight": 0.15}
		]
	},
	{
		"id": 5,
		"count": 96,
		"spawn_interval": 0.72,
		"health_multiplier": 1.55,
		"speed_multiplier": 1.2,
		"damage_multiplier": 1.35,
		"enemy_mix": [
			{"type": "striker", "weight": 0.4, "speed_bonus": 0.2},
			{"type": "brute", "weight": 0.35, "health_bonus": 0.4},
			{"type": "grenadier", "weight": 0.15},
			{"type": "warden", "weight": 0.1, "health_bonus": 0.55, "damage_bonus": 0.25}
		]
	}
]

var _enemy_catalog: Dictionary = {}
var _current_wave_index: int = 0
var _current_wave: Dictionary = {}
var _enemies_spawned_in_wave: int = 0
var _spawn_progress: float = 0.0
var _total_run_time: float = 0.0
var _run_time_emit_accumulator: float = 0.0
var _objective_emit_accumulator: float = 0.0
var _active: bool = false

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func configure_enemy_catalog(catalog: Dictionary) -> void:
	_enemy_catalog.clear()
	for key in catalog.keys():
		var entry: Dictionary = catalog[key]
		var scene: PackedScene = entry.get("scene")
		if scene == null:
			continue
		var base_tuning: Dictionary = entry.get("base_tuning", {}).duplicate(true)
		_enemy_catalog[key] = {
			"scene": scene,
			"base_tuning": base_tuning,
			"label": entry.get("label", key)
		}

func start(start_wave: int = 1) -> void:
	if _enemy_catalog.is_empty():
		push_warning("WorldManager started without enemy catalog; no spawns will occur.")
	_active = true
	_total_run_time = 0.0
	_run_time_emit_accumulator = 0.0
	_objective_emit_accumulator = 0.0
	_current_wave_index = max(1, start_wave) - 1
	_advance_to_next_wave()

func stop() -> void:
	_active = false

func update(delta: float, active_enemy_count: int) -> Array[Dictionary]:
	if not _active or _current_wave.is_empty():
		return []
	_total_run_time += delta
	_run_time_emit_accumulator += delta
	_objective_emit_accumulator += delta
	if _run_time_emit_accumulator >= 1.0:
		emit_signal("run_time_updated", _total_run_time)
		_run_time_emit_accumulator = 0.0
	if _objective_emit_accumulator >= 0.5:
		emit_signal("objective_updated", _format_survival_objective(_total_run_time))
		_objective_emit_accumulator = 0.0
	var spawn_requests: Array[Dictionary] = []
	_spawn_progress += delta
	var spawn_interval: float = float(_current_wave.get("spawn_interval", 1.0))
	while _enemies_spawned_in_wave < int(_current_wave.get("count", 0)) and _spawn_progress >= spawn_interval:
		_spawn_progress -= spawn_interval
		var request: Dictionary = _build_spawn_request()
		if not request.is_empty():
			spawn_requests.append(request)
		_enemies_spawned_in_wave += 1
	if _enemies_spawned_in_wave >= int(_current_wave.get("count", 0)) and active_enemy_count <= 0:
		emit_signal("wave_completed", _current_wave_index, _current_wave.duplicate(true))
		_advance_to_next_wave()
	return spawn_requests

func record_enemy_defeated() -> void:
	# Placeholder for future stat tracking or adaptive difficulty.
	pass

func get_current_wave_index() -> int:
	return _current_wave_index

func get_total_run_time() -> float:
	return _total_run_time

func _advance_to_next_wave() -> void:
	_current_wave_index += 1
	_current_wave = _get_wave_definition(_current_wave_index)
	_enemies_spawned_in_wave = 0
	var spawn_interval: float = float(_current_wave.get("spawn_interval", 1.0))
	_spawn_progress = spawn_interval # Guarantees an immediate spawn on the next update.
	if _current_wave.is_empty():
		push_warning("WorldManager has no wave data to advance to; stopping spawn loop.")
		_active = false
		return
	emit_signal("wave_started", _current_wave_index, _current_wave.duplicate(true))

func _get_wave_definition(wave_index: int) -> Dictionary:
	if wave_index <= DEFAULT_WAVES.size():
		return DEFAULT_WAVES[wave_index - 1].duplicate(true)
	return _build_scaled_wave_definition(wave_index)

func _build_scaled_wave_definition(wave_index: int) -> Dictionary:
	var base_count: int = 10
	var wave_multiplier: float = pow(2.0, float(wave_index - 1))
	var spawn_count: int = max(8, roundi(base_count * wave_multiplier))
	var spawn_interval: float = max(0.45, 1.4 - float(wave_index) * 0.08)
	var health_multiplier: float = 1.0 + 0.12 * float(wave_index - 1)
	var speed_multiplier: float = 1.0 + 0.06 * float(wave_index - 1)
	var damage_multiplier: float = 1.0 + 0.1 * float(wave_index - 1)
	return {
		"id": wave_index,
		"count": spawn_count,
		"spawn_interval": spawn_interval,
		"health_multiplier": health_multiplier,
		"speed_multiplier": speed_multiplier,
		"damage_multiplier": damage_multiplier,
		"enemy_mix": _generate_enemy_mix_for_wave(wave_index)
	}

func _generate_enemy_mix_for_wave(wave_index: int) -> Array[Dictionary]:
	var available_types: Array = _enemy_catalog.keys()
	if available_types.is_empty():
		return []
	var mix: Array[Dictionary] = []
	var tier_count: int = max(1, available_types.size())
	for i in range(available_types.size()):
		var type_name: String = String(available_types[i])
		var weight: float = 1.0 / float(tier_count)
		weight += float(wave_index - 1) * 0.05 * float(i + 1)
		mix.append({
			"type": type_name,
			"weight": max(weight, 0.05)
		})
	return mix

func _build_spawn_request() -> Dictionary:
	if _enemy_catalog.is_empty():
		return {}
	var mix: Array = _current_wave.get("enemy_mix", [])
	if mix.is_empty():
		mix = _generate_enemy_mix_for_wave(_current_wave_index)
	var type_name: String = _select_enemy_type(mix)
	if not _enemy_catalog.has(type_name):
		type_name = _enemy_catalog.keys()[0]
	var entry: Dictionary = _enemy_catalog[type_name]
	var scene: PackedScene = entry.get("scene")
	if scene == null:
		return {}
	var tuning: Dictionary = _prepare_enemy_tuning(entry, _current_wave, _find_mix_entry(type_name, mix))
	return {
		"type": type_name,
		"scene": scene,
		"tuning": tuning,
		"wave_index": _current_wave_index,
		"wave_definition": _current_wave.duplicate(true)
	}

func _prepare_enemy_tuning(entry: Dictionary, wave: Dictionary, mix_entry: Dictionary) -> Dictionary:
	var tuning: Dictionary = entry.get("base_tuning", {}).duplicate(true)
	var health_multiplier: float = float(wave.get("health_multiplier", 1.0))
	var speed_multiplier: float = float(wave.get("speed_multiplier", 1.0))
	var damage_multiplier: float = float(wave.get("damage_multiplier", 1.0))
	if mix_entry.has("health_bonus"):
		health_multiplier *= 1.0 + float(mix_entry.get("health_bonus"))
	if mix_entry.has("speed_bonus"):
		speed_multiplier *= 1.0 + float(mix_entry.get("speed_bonus"))
	if mix_entry.has("damage_bonus"):
		damage_multiplier *= 1.0 + float(mix_entry.get("damage_bonus"))
	if tuning.has("max_health"):
		tuning["max_health"] = max(1, int(round(float(tuning.get("max_health")) * health_multiplier)))
	if tuning.has("move_speed"):
		tuning["move_speed"] = float(tuning.get("move_speed")) * speed_multiplier
	if tuning.has("contact_damage"):
		tuning["contact_damage"] = max(1, int(round(float(tuning.get("contact_damage")) * damage_multiplier)))
	return tuning

func _select_enemy_type(mix: Array) -> String:
	var total_weight: float = 0.0
	for entry in mix:
		total_weight += float(entry.get("weight", 0.0))
	if total_weight <= 0.0:
		return String(mix[0].get("type", ""))
	var roll: float = _rng.randf_range(0.0, total_weight)
	var cumulative: float = 0.0
	for entry in mix:
		cumulative += float(entry.get("weight", 0.0))
		if roll <= cumulative:
			return String(entry.get("type", ""))
	return String(mix.back().get("type", ""))

func _find_mix_entry(type_name: String, mix: Array) -> Dictionary:
	for entry in mix:
		if String(entry.get("type", "")) == type_name:
			return entry
	return {}

func _format_survival_objective(total_seconds: float) -> String:
	var seconds: int = int(total_seconds)
	var minutes: int = int(seconds / 60.0)
	var rem: int = seconds % 60
	return "SURVIVE %02d:%02d" % [minutes, rem]
