extends Node2D
class_name WorldController

signal pause_requested
signal run_ended(outcome: String, record: Dictionary)

const PlayerScene := preload("res://scenes/actors/Player.tscn")
const EnemyScene := preload("res://scenes/enemies/BasicEnemy.tscn")
const BossEnemyScene := preload("res://scenes/enemies/BossEnemy.tscn")

@export var enemy_spawn_ring_radius: float = 640.0
@export var enemy_spawn_variance: float = 120.0
@export var max_enemies := 6
@export var threat_color_inactive: Color = Color(0.85, 0.92, 1.0, 1.0)
@export var threat_color_low: Color = Color(0.72, 0.93, 0.68, 1.0)
@export var threat_color_med: Color = Color(1.0, 0.88, 0.5, 1.0)
@export var threat_color_high: Color = Color(1.0, 0.62, 0.45, 1.0)
@export var threat_color_critical: Color = Color(1.0, 0.35, 0.35, 1.0)
@export_range(0.1, 2.0, 0.05) var threat_pulse_period: float = 0.9
@export_range(1.0, 1.5, 0.01) var threat_pulse_scale: float = 1.08
@export_range(0, 3, 1) var threat_pulse_min_severity: int = 2
@export var biome_override: StringName = &""
@export var time_of_day_override: StringName = &""
@export var randomize_environment_each_run: bool = true
@export_range(0, 2147483647, 1) var environment_seed: int = 0

const SNOW_PATH_STEP := 56.0
const SNOW_PATH_RADIUS := 146.0
const SNOW_FOOTPRINT_RADIUS := 58.0
const SNOW_EDGE_OFFSET := 26.0
const SNOW_KICKUP_INTERVAL := 0.14
const SNOW_KICKUP_SPEED_THRESHOLD := 28.0
const SNOW_KICKUP_MAX_SPEED := 420.0
const SNOW_KICKUP_VERTICAL_OFFSET := 42.0
const SPAWN_SAFE_PADDING := 96.0
const BOSS_ALERT_SFX_PATH := "res://assets/sounds/sfx/growl.mp3"
const DEFAULT_WORLD_BOUNDS := Rect2(Vector2(-1920.0, -1080.0), Vector2(3840.0, 2160.0))

@onready var _enemy_container: Node2D = $EnemyContainer
@onready var _player_hud: PlayerHudCluster = $HUD/MarginContainer/VBoxContainer/PlayerHudCluster
@onready var _objective_label: Label = %ObjectiveLabel
@onready var _world_manager: WorldManager = %WorldManager
@onready var _environment_controller: EnvironmentController = %Environment
@onready var _audio_director: AudioDirector = _resolve_audio_director()

var _player: CharacterBody2D = null
var _camera: Camera2D = null
var _character_profile: Resource = null
var _achievement_service: AchievementService = null
var _leaderboard_service: LeaderboardService = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _pending_spawn_requests: Array[Dictionary] = []
var _wave_label_text: String = ""
var _wave_threat_text: String = ""
var _objective_status_text: String = ""
var _wave_threat_level: String = ""
var _wave_threat_severity: int = -1
var _objective_pulse_tween: Tween = null
var _total_kills: int = 0
var _current_wave_index: int = 0
var _current_run_time: float = 0.0
var _last_snow_path_position: Vector2 = Vector2.ZERO
var _snow_kickup_timer: float = 0.0
var _last_snow_move_direction: Vector2 = Vector2.DOWN
var _active_bosses: int = 0
var _upcoming_boss_label: String = ""
var _active_boss_label: String = ""
var _battle_music_started: bool = false
var _run_summary_submitted: bool = false
var _world_bounds: Rect2 = Rect2()

func _ready() -> void:
	_rng.randomize()
	_achievement_service = _resolve_achievement_service()
	_leaderboard_service = _resolve_leaderboard_service()
	_configure_environment()
	_player = _spawn_player()
	_camera = _create_camera()
	_configure_player_hud()
	_configure_world_bounds()
	_configure_world_manager()
	if is_instance_valid(_player):
		_last_snow_path_position = _player.global_position
		if _environment_controller and _environment_controller.supports_snow_imprints():
			_environment_controller.add_snow_path_sample(_player.global_position, SNOW_PATH_RADIUS, 0.6)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		emit_signal("pause_requested")
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _camera and _player:
		_camera.position = _player.position
	if _world_manager:
		var raw_spawn_requests: Variant = _world_manager.update(_delta, _enemy_container.get_child_count())
		if raw_spawn_requests is Array:
			var spawn_requests: Array = raw_spawn_requests
			for request_variant: Variant in spawn_requests:
				if request_variant is Dictionary:
					_pending_spawn_requests.append(request_variant as Dictionary)
	_flush_spawn_queue()
	_update_continuous_snow_kickup(_delta)
	_update_snow_interactions()

func _spawn_player() -> CharacterBody2D:
	var player := PlayerScene.instantiate()
	player.position = Vector2.ZERO
	add_child(player)
	if _character_profile and player.has_method("apply_profile"):
		player.apply_profile(_character_profile)
	if player.has_signal("player_died"):
		var callable := Callable(self, "_on_player_died")
		if not player.is_connected("player_died", callable):
			player.player_died.connect(callable)
	if _environment_controller and player.has_method("apply_ground_accent_profile"):
		player.apply_ground_accent_profile(_environment_controller.is_night_time(), _compute_accent_ambient_scale())
	return player

func _create_camera() -> Camera2D:
	var camera := Camera2D.new()
	camera.name = "GameCamera"
	add_child(camera)
	camera.position = _player.position
	camera.make_current()
	return camera

func _flush_spawn_queue() -> void:
	if _pending_spawn_requests.is_empty():
		return
	if not is_instance_valid(_player):
		_pending_spawn_requests.clear()
		return
	while _pending_spawn_requests.size() > 0 and _enemy_container.get_child_count() < max_enemies:
		var request: Dictionary = _pending_spawn_requests[0]
		_pending_spawn_requests.remove_at(0)
		_spawn_enemy_from_request(request)
	if _enemy_container.get_child_count() >= max_enemies and _pending_spawn_requests.size() > max_enemies * 3:
		var max_buffer: int = max_enemies * 3
		while _pending_spawn_requests.size() > max_buffer:
			_pending_spawn_requests.remove_at(0)

func _spawn_enemy_from_request(request: Dictionary) -> void:
	if request.is_empty():
		return
	var scene: PackedScene = request.get("scene")
	if scene == null:
		return
	var enemy := scene.instantiate()
	if enemy == null:
		return
	_apply_enemy_tuning(enemy, request.get("tuning", {}))
	var is_boss: bool = bool(request.get("is_boss", false))
	if is_boss:
		_active_bosses += 1
		enemy.set_meta("is_boss", true)
		var reward_payload: Variant = request.get("reward", {})
		if typeof(reward_payload) == TYPE_DICTIONARY:
			enemy.set_meta("reward_payload", (reward_payload as Dictionary).duplicate(true))
		var boss_label := String(request.get("label", ""))
		if boss_label != "":
			enemy.set_meta("boss_label", boss_label)
			_announce_boss_spawn(boss_label)
		enemy.add_to_group("boss_enemies")
	enemy.global_position = _choose_spawn_position(is_boss)
	if enemy.has_method("set_target"):
		enemy.set_target(_player)
	if enemy.has_signal("defeated"):
		enemy.defeated.connect(Callable(self, "_on_enemy_defeated"))
	_enemy_container.add_child(enemy)

func _choose_spawn_position(is_boss: bool = false) -> Vector2:
	var angle: float = _rng.randf_range(0.0, TAU)
	var spawn_radius: float = _compute_safe_spawn_radius(is_boss)
	var spawn_variance: float = enemy_spawn_variance * (0.6 if is_boss else 1.0)
	var distance: float = spawn_radius + _rng.randf_range(-spawn_variance, spawn_variance)
	distance = maxf(distance, spawn_radius)
	var offset: Vector2 = Vector2.RIGHT.rotated(angle) * distance
	return _clamp_to_world_bounds(_player.global_position + offset)


func _compute_safe_spawn_radius(is_boss: bool) -> float:
	var base_radius: float = enemy_spawn_ring_radius
	if is_boss:
		base_radius *= 1.2
	var safe_radius: float = base_radius
	if _camera:
		var viewport: Viewport = _camera.get_viewport()
		if viewport:
			var visible_rect: Rect2 = viewport.get_visible_rect()
			var rect_size: Vector2 = visible_rect.size
			var half_diagonal: float = rect_size.length() * 0.5
			safe_radius = maxf(safe_radius, half_diagonal + SPAWN_SAFE_PADDING)
	return safe_radius

func _update_snow_interactions() -> void:
	if not _environment_controller or not _environment_controller.supports_snow_imprints():
		_last_snow_path_position = Vector2.ZERO
		return
	if not is_instance_valid(_player):
		return
	var current_pos := _player.global_position
	if _last_snow_path_position == Vector2.ZERO:
		_last_snow_path_position = current_pos
		_environment_controller.add_snow_path_sample(current_pos, SNOW_PATH_RADIUS, 0.6)
		return
	var displacement := current_pos - _last_snow_path_position
	var distance := displacement.length()
	if distance < SNOW_PATH_STEP:
		return
	var direction := displacement.normalized()
	var step := SNOW_PATH_STEP
	var iterations := int(distance / step)
	for index: int in range(1, iterations + 1):
		var sample: Vector2 = _last_snow_path_position + direction * step * float(index)
		_environment_controller.add_snow_path_sample(sample, SNOW_PATH_RADIUS, 0.6)
		var lateral := direction.rotated(-PI * 0.5) * SNOW_EDGE_OFFSET
		_environment_controller.add_snow_footprint(sample + lateral, SNOW_FOOTPRINT_RADIUS, 0.55)
		_environment_controller.add_snow_footprint(sample - lateral, SNOW_FOOTPRINT_RADIUS, 0.55)
	_last_snow_path_position = _last_snow_path_position + direction * step * float(iterations)
	if distance - float(iterations) * step >= SNOW_PATH_STEP * 0.5:
		_environment_controller.add_snow_path_sample(current_pos, SNOW_PATH_RADIUS, 0.6)
		var lateral := direction.rotated(-PI * 0.5) * SNOW_EDGE_OFFSET
		_environment_controller.add_snow_footprint(current_pos + lateral, SNOW_FOOTPRINT_RADIUS, 0.5)
		_environment_controller.add_snow_footprint(current_pos - lateral, SNOW_FOOTPRINT_RADIUS, 0.5)
	_last_snow_path_position = current_pos

func _update_continuous_snow_kickup(delta: float) -> void:
	if not _environment_controller or not _environment_controller.supports_snow_imprints():
		_snow_kickup_timer = 0.0
		return
	if not is_instance_valid(_player):
		return
	var velocity: Vector2 = _player.velocity
	var speed: float = velocity.length()
	if speed < SNOW_KICKUP_SPEED_THRESHOLD:
		_snow_kickup_timer = SNOW_KICKUP_INTERVAL
		return
	_snow_kickup_timer += delta
	if _snow_kickup_timer < SNOW_KICKUP_INTERVAL:
		return
	_snow_kickup_timer = 0.0
	var move_dir: Vector2 = velocity.normalized()
	if move_dir.length() > 0.0:
		_last_snow_move_direction = move_dir
	else:
		move_dir = _last_snow_move_direction
	if move_dir.length() == 0.0:
		move_dir = Vector2.DOWN
	var normalized_strength: float = 0.0
	var max_delta: float = maxf(0.001, SNOW_KICKUP_MAX_SPEED - SNOW_KICKUP_SPEED_THRESHOLD)
	normalized_strength = clampf((speed - SNOW_KICKUP_SPEED_THRESHOLD) / max_delta, 0.2, 1.0)
	var base_position: Vector2 = _player.global_position + Vector2(0.0, SNOW_KICKUP_VERTICAL_OFFSET)
	var forward_offset: Vector2 = move_dir * -14.0
	var lateral: Vector2 = move_dir.orthogonal()
	if lateral.is_zero_approx():
		lateral = Vector2.RIGHT
	lateral = lateral.normalized()
	var edge_offset: float = SNOW_EDGE_OFFSET * 0.85
	var positions: Array[Vector2] = [
		base_position + lateral * edge_offset + forward_offset,
		base_position - lateral * edge_offset + forward_offset,
		base_position + forward_offset * 0.4
	]
	for sample_position: Vector2 in positions:
		_environment_controller.emit_snow_kickup(sample_position, normalized_strength)

func _on_enemy_defeated(_enemy) -> void:
	_record_stat("enemies_defeated", 1)
	_record_stat("enemies_defeated_run", 1)
	if _world_manager:
		_world_manager.record_enemy_defeated()
	_total_kills += 1
	if _player_hud:
		_player_hud.update_kill_count(_total_kills)
	if is_instance_valid(_player) and _player.has_method("add_burst_points"):
		var burst_gain := float(_player.burst_points_per_enemy)
		_player.add_burst_points(burst_gain)
	if _enemy and _enemy.has_meta("is_boss"):
		_active_bosses = max(0, _active_bosses - 1)
		var reward_payload: Variant = _enemy.get_meta("reward_payload")
		if typeof(reward_payload) == TYPE_DICTIONARY:
			var rewards: Dictionary = reward_payload as Dictionary
			var cores: int = int(rewards.get("rapture_cores", 0))
			if cores > 0:
				_award_rapture_cores(cores)
		if _active_bosses == 0:
			_active_boss_label = ""
			_update_objective_label()
	call_deferred("_flush_spawn_queue")

func set_character_profile(profile) -> void:
	_character_profile = profile
	if _player and _player.has_method("apply_profile"):
		_player.apply_profile(profile)
	_configure_player_hud()

func set_environment_profile(biome_id: StringName, time_of_day_id: StringName, seed_override: int = 0) -> void:
	biome_override = biome_id
	time_of_day_override = time_of_day_id
	if seed_override > 0:
		environment_seed = seed_override
	if _environment_controller:
		_environment_controller.set_environment(biome_id, time_of_day_id, seed_override)

func randomize_environment(seed_override: int = 0) -> void:
	if seed_override > 0:
		environment_seed = seed_override
	elif randomize_environment_each_run:
		environment_seed = _rng.randi()
	if _environment_controller:
		_environment_controller.initialize_environment(environment_seed, biome_override, time_of_day_override)

func _resolve_achievement_service() -> AchievementService:
	if not get_tree():
		return null
	var root: Node = get_tree().root
	var candidate: Node = root.find_child("AchievementService", true, false)
	if candidate and candidate is AchievementService:
		return candidate as AchievementService
	return null

func _resolve_leaderboard_service() -> LeaderboardService:
	if not get_tree():
		return null
	var root: Node = get_tree().root
	var candidate: Node = root.find_child("LeaderboardService", true, false)
	if candidate and candidate is LeaderboardService:
		return candidate as LeaderboardService
	return null

func _resolve_audio_director() -> AudioDirector:
	if not get_tree():
		return null
	var root: Node = get_tree().root
	var candidate: Node = root.find_child("AudioDirector", true, false)
	if candidate and candidate is AudioDirector:
		return candidate as AudioDirector
	return null

func _get_audio_director() -> AudioDirector:
	if _audio_director == null or not is_instance_valid(_audio_director):
		_audio_director = _resolve_audio_director()
	return _audio_director

func _record_stat(stat_key: String, amount: int) -> void:
	if _achievement_service:
		_achievement_service.record_stat(stat_key, amount)

func _configure_player_hud() -> void:
	if not _player_hud:
		return
	var current := 0
	var maximum := 1
	var burst_value := 0.0
	var burst_max := 1.0
	if is_instance_valid(_player):
		if _player.has_method("get_current_health"):
			current = int(_player.get_current_health())
		if _player.has_method("get_max_health"):
			maximum = maxi(1, int(_player.get_max_health()))
		if _player.has_method("get_burst_charge"):
			burst_value = float(_player.get_burst_charge())
		if _player.has_method("get_burst_charge_max"):
			burst_max = maxf(0.001, float(_player.get_burst_charge_max()))
	_player_hud.configure(current, maximum, burst_value, burst_max)
	if _player_hud:
		_player_hud.set_character_profile(_character_profile)
		var wave_index: int = 0
		if _world_manager:
			wave_index = _world_manager.get_current_wave_index()
			_current_wave_index = wave_index
		_player_hud.set_run_stats(wave_index, _total_kills)
		_player_hud.update_run_time(0.0)
	if Engine.is_editor_hint():
		return
	var profile_name: String = "<none>"
	if _character_profile:
		profile_name = _character_profile.display_name
	print_debug("WorldController: HUD profile applied -> %s" % profile_name)
	_connect_player_health_signal()
	_connect_player_burst_signal()
	_connect_player_ammo_signal()
	_connect_player_burst_ready_signal()

func _configure_environment() -> void:
	if not _environment_controller:
		return
	var handler := Callable(self, "_on_environment_changed")
	if not _environment_controller.environment_changed.is_connected(handler):
		_environment_controller.environment_changed.connect(handler)
	var seed_value := environment_seed
	if seed_value <= 0 and randomize_environment_each_run:
		seed_value = _rng.randi()
	_environment_controller.initialize_environment(seed_value, biome_override, time_of_day_override)
	if seed_value > 0:
		environment_seed = seed_value
	_refresh_player_ground_accent()
	_configure_world_bounds()

func _refresh_player_ground_accent() -> void:
	if not is_instance_valid(_player):
		return
	if _environment_controller == null:
		return
	var is_night := _environment_controller.is_night_time()
	var ambient_scale := _compute_accent_ambient_scale()
	if _player.has_method("apply_ground_accent_profile"):
		_player.apply_ground_accent_profile(is_night, ambient_scale)

func _compute_accent_ambient_scale() -> float:
	if _environment_controller == null:
		return 1.0
	var time_def := _environment_controller.get_active_time_of_day()
	if time_def == null:
		return 1.0
	var ambient := clampf(time_def.ambient_intensity, 0.1, 1.6)
	var night_bias := 0.25 if _environment_controller.is_night_time() else 0.0
	return clampf(1.2 - ambient * 0.6 + night_bias, 0.4, 1.5)

func _on_environment_changed(_biome_id: StringName, _time_id: StringName) -> void:
	_refresh_player_ground_accent()

func _configure_world_manager() -> void:
	if not _world_manager:
		return
	_total_kills = 0
	_current_wave_index = 0
	_current_run_time = 0.0
	_run_summary_submitted = false
	_world_manager.configure_enemy_catalog(_build_enemy_catalog())
	if not _world_manager.is_connected("wave_started", Callable(self, "_on_wave_started")):
		_world_manager.wave_started.connect(Callable(self, "_on_wave_started"))
	if not _world_manager.is_connected("wave_completed", Callable(self, "_on_wave_completed")):
		_world_manager.wave_completed.connect(Callable(self, "_on_wave_completed"))
	if not _world_manager.is_connected("objective_updated", Callable(self, "_on_objective_updated")):
		_world_manager.objective_updated.connect(Callable(self, "_on_objective_updated"))
	if not _world_manager.is_connected("run_time_updated", Callable(self, "_on_run_time_updated")):
		_world_manager.run_time_updated.connect(Callable(self, "_on_run_time_updated"))
	if not _world_manager.is_connected("boss_spawn_scheduled", Callable(self, "_on_boss_spawn_scheduled")):
		_world_manager.boss_spawn_scheduled.connect(Callable(self, "_on_boss_spawn_scheduled"))
	_world_manager.start()
	if _player_hud:
		_player_hud.update_kill_count(_total_kills)
		_player_hud.update_run_time(0.0)
	_start_battle_music()

func _configure_world_bounds() -> void:
	_world_bounds = DEFAULT_WORLD_BOUNDS
	if is_instance_valid(_player) and _player.has_method("set_world_bounds"):
		_player.set_world_bounds(_world_bounds)
		var min_corner := _world_bounds.position
		var max_corner := _world_bounds.position + _world_bounds.size
		var player_position := _player.global_position
		var clamped_x := clampf(player_position.x, min_corner.x, max_corner.x)
		var clamped_y := clampf(player_position.y, min_corner.y, max_corner.y)
		var clamped_position := Vector2(clamped_x, clamped_y)
		if not clamped_position.is_equal_approx(player_position):
			_player.global_position = clamped_position
			if _camera:
				_camera.position = clamped_position
			_last_snow_path_position = clamped_position
	if _environment_controller and _environment_controller.has_method("set_world_bounds"):
		_environment_controller.set_world_bounds(_world_bounds)


func get_world_bounds() -> Rect2:
	return _world_bounds


func _clamp_to_world_bounds(world_position: Vector2) -> Vector2:
	if _world_bounds.size == Vector2.ZERO:
		return world_position
	var min_corner := _world_bounds.position
	var max_corner := _world_bounds.position + _world_bounds.size
	return Vector2(
		clampf(world_position.x, min_corner.x, max_corner.x),
		clampf(world_position.y, min_corner.y, max_corner.y)
	)

func _start_battle_music() -> void:
	if _battle_music_started:
		return
	var director := _get_audio_director()
	if director == null:
		return
	director.play_random_battle_track()
	_battle_music_started = true

func _build_enemy_catalog() -> Dictionary:
	var catalog: Dictionary = {}
	var grunt_tuning: Dictionary = {
		"max_health": 40,
		"move_speed": 100.0,
		"arrival_tolerance": 16.0,
		"contact_damage": 20,
		"visual_tint": Color(1.0, 1.0, 1.0, 1.0),
		"scale_multiplier": 1.0
	}
	catalog["grunt"] = {
		"scene": EnemyScene,
		"label": "Rapture Grunt",
		"description": "Balanced fodder that anchors early waves.",
		"base_tuning": grunt_tuning
	}
	var striker_tuning: Dictionary = {
		"max_health": 50,
		"move_speed": 200.0,
		"arrival_tolerance": 14.0,
		"contact_damage": 15,
		"visual_modulate": Color(0.6, 0.75, 1.0, 1.0),
		"scale_multiplier": 0.9
	}
	catalog["striker"] = {
		"scene": EnemyScene,
		"label": "Striker",
		"description": "Fast flankers that punish kiting.",
		"base_tuning": striker_tuning
	}
	var brute_tuning: Dictionary = {
		"max_health": 150,
		"move_speed": 50.0,
		"arrival_tolerance": 20.0,
		"contact_damage": 35,
		"visual_modulate": Color(1.0, 0.55, 0.55, 1.0),
		"scale_multiplier": 1.35
	}
	catalog["brute"] = {
		"scene": EnemyScene,
		"label": "Brute",
		"description": "Slow juggernauts that soak burst fire.",
		"base_tuning": brute_tuning
	}
	var grenadier_tuning: Dictionary = {
		"max_health": 100,
		"move_speed": 110.0,
		"arrival_tolerance": 18.0,
		"contact_damage": 20,
		"visual_modulate": Color(1.0, 0.82, 0.45, 1.0),
		"scale_multiplier": 1.1
	}
	catalog["grenadier"] = {
		"scene": EnemyScene,
		"label": "Grenadier",
		"description": "Mid-line pressure units prepping future ranged kits.",
		"base_tuning": grenadier_tuning
	}
	var warden_tuning: Dictionary = {
		"max_health": 225,
		"move_speed": 75.0,
		"arrival_tolerance": 20.0,
		"contact_damage": 45,
		"visual_modulate": Color(0.85, 0.7, 1.0, 1.0),
		"scale_multiplier": 1.45
	}
	catalog["warden"] = {
		"scene": EnemyScene,
		"label": "Warden",
		"description": "Mini-boss guardians that close distance relentlessly.",
		"base_tuning": warden_tuning
	}
	var overseer_boss_tuning: Dictionary = {
		"max_health": 160,
		"move_speed": 170.0,
		"arrival_tolerance": 32.0,
		"contact_damage": 24,
		"visual_modulate": Color(0.85, 0.65, 1.0, 1.0),
		"scale_multiplier": 2.6
	}
	catalog["overseer_boss"] = {
		"scene": BossEnemyScene,
		"label": "Overseer",
		"description": "Towering boss tuned for wave finales.",
		"base_tuning": overseer_boss_tuning
	}
	return catalog

func _apply_enemy_tuning(enemy: Object, tuning: Dictionary) -> void:
	if tuning.is_empty():
		return
	if enemy.has_method("apply_tuning"):
		enemy.apply_tuning(tuning)
		return
	var properties: Dictionary = {}
	for property_data in enemy.get_property_list():
		if property_data.has("name"):
			properties[property_data["name"]] = true
	for key in tuning.keys():
		if properties.has(key):
			enemy.set(key, tuning[key])

func _on_wave_started(wave_index: int, definition: Dictionary) -> void:
	if not _battle_music_started:
		_start_battle_music()
	var threat_info: Dictionary = _classify_wave_threat(definition)
	_wave_label_text = "WAVE %02d" % wave_index
	_wave_threat_text = threat_info.get("text", "")
	_wave_threat_level = threat_info.get("tier", "")
	_wave_threat_severity = threat_info.get("severity", -1)
	_current_wave_index = max(0, wave_index)
	_update_objective_label()
	if _player_hud:
		_player_hud.set_run_stats(wave_index, _total_kills)
	if _active_boss_label != "" and _objective_status_text.findn("Boss") == -1:
		_objective_status_text = "Boss: %s" % _active_boss_label
		_update_objective_label()
	print_debug("WorldController: Wave %d started" % wave_index)

func _on_wave_completed(_wave_index: int, _definition: Dictionary) -> void:
	print_debug("WorldController: Wave %d completed" % _wave_index)

func _on_objective_updated(text: String) -> void:
	_objective_status_text = text
	_update_objective_label()
	if _active_bosses > 0 and _active_boss_label != "":
		_objective_status_text = "Boss: %s" % _active_boss_label
		_update_objective_label()

func _on_run_time_updated(_total_seconds: float) -> void:
	_current_run_time = maxf(0.0, _total_seconds)
	if _player_hud:
		_player_hud.update_run_time(_current_run_time)

func get_current_wave_index() -> int:
	return _current_wave_index

func get_total_kills() -> int:
	return _total_kills

func get_total_run_time() -> float:
	return _current_run_time

func _update_objective_label() -> void:
	if not _objective_label:
		return
	var segments: Array = []
	if _wave_label_text != "":
		segments.append(_wave_label_text)
	if _wave_threat_text != "":
		segments.append(_wave_threat_text)
	if _objective_status_text != "":
		segments.append(_objective_status_text)
	var display := ""
	for index: int in range(segments.size()):
		if index > 0:
			display += " • "
		display += String(segments[index])
	_objective_label.text = display if display != "" else ""
	_apply_threat_styling()

func _classify_wave_threat(definition: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"text": "",
		"tier": "",
		"severity": -1
	}
	if definition.is_empty():
		return result
	var count := int(definition.get("count", 0))
	var interval := float(definition.get("spawn_interval", 1.0))
	if count <= 0:
		return result
	var safe_interval: float = interval if interval > 0.2 else 0.2
	var danger_score: float = float(count) / safe_interval
	if danger_score < 25.0:
		result["text"] = "Threat: LOW"
		result["tier"] = "low"
		result["severity"] = 0
		return result
	if danger_score < 55.0:
		result["text"] = "Threat: MED"
		result["tier"] = "med"
		result["severity"] = 1
		return result
	if danger_score < 90.0:
		result["text"] = "Threat: HIGH"
		result["tier"] = "high"
		result["severity"] = 2
		return result
	result["text"] = "Threat: CRITICAL"
	result["tier"] = "critical"
	result["severity"] = 3
	return result

func _connect_player_health_signal() -> void:
	if not is_instance_valid(_player) or not _player.has_signal("health_changed"):
		return
	var callable := Callable(self, "_on_player_health_changed")
	if _player.is_connected("health_changed", callable):
		_player.disconnect("health_changed", callable)
	_player.health_changed.connect(callable)
	if _player.has_method("emit_health_state"):
		_player.emit_health_state()
	elif _player.has_method("get_current_health") and _player.has_method("get_max_health"):
		_on_player_health_changed(_player.get_current_health(), _player.get_max_health(), 0)

func _on_player_health_changed(current: int, maximum: int, delta: int) -> void:
	if _player_hud:
		var animate := delta != 0
		_player_hud.update_health(current, maximum, delta, animate)

func _connect_player_burst_signal() -> void:
	if not is_instance_valid(_player) or not _player.has_signal("burst_changed"):
		return
	var callable := Callable(self, "_on_player_burst_changed")
	if _player.is_connected("burst_changed", callable):
		_player.disconnect("burst_changed", callable)
	_player.burst_changed.connect(callable)
	if _player.has_method("emit_burst_state"):
		_player.emit_burst_state()
	elif _player.has_method("get_burst_charge") and _player.has_method("get_burst_charge_max"):
		_on_player_burst_changed(_player.get_burst_charge(), _player.get_burst_charge_max())

func _on_player_burst_changed(current: float, maximum: float) -> void:
	if _player_hud:
		_player_hud.update_burst(current, maximum, true)

func _connect_player_ammo_signal() -> void:
	if not is_instance_valid(_player) or not _player.has_signal("ammo_changed"):
		return
	var callable := Callable(self, "_on_player_ammo_changed")
	if _player.is_connected("ammo_changed", callable):
		_player.disconnect("ammo_changed", callable)
	_player.ammo_changed.connect(callable)
	if _player.has_method("emit_ammo_state"):
		_player.emit_ammo_state()

func _on_player_ammo_changed(current_ammo: int, magazine_size: int, special_current: int, special_max: int) -> void:
	if _player_hud and _player_hud.has_method("update_ammo"):
		_player_hud.update_ammo(current_ammo, magazine_size, special_current, special_max)

func _on_boss_spawn_scheduled(wave_index: int, definition: Dictionary) -> void:
	_upcoming_boss_label = String(definition.get("label", "BOSS"))
	if _player_hud and _player_hud.has_method("update_wave_index"):
		_player_hud.update_wave_index(wave_index)
	if _upcoming_boss_label != "":
		_objective_status_text = "Boss Incoming: %s" % _upcoming_boss_label
		_update_objective_label()

func _announce_boss_spawn(label: String) -> void:
	var announcement := label if label != "" else "BOSS"
	_active_boss_label = announcement
	_upcoming_boss_label = ""
	_objective_status_text = "Boss: %s" % announcement
	_update_objective_label()
	if _player_hud and _player_hud.has_method("set_run_stats"):
		_player_hud.set_run_stats(_current_wave_index, _total_kills)
	_play_boss_alert_sfx()

func _award_rapture_cores(amount: int) -> void:
	if amount <= 0:
		return
	if _leaderboard_service and _leaderboard_service.has_method("add_player_rapture_cores"):
		_leaderboard_service.add_player_rapture_cores(amount)
	if _achievement_service and _achievement_service.has_method("record_stat"):
		_achievement_service.record_stat("rapture_cores_collected", amount)
	print_debug("WorldController: Awarded %d rapture cores" % amount)

func _play_boss_alert_sfx() -> void:
	var director := _get_audio_director()
	if director == null:
		return
	if not ResourceLoader.exists(BOSS_ALERT_SFX_PATH):
		return
	director.play_sfx_by_path(BOSS_ALERT_SFX_PATH)

func _connect_player_burst_ready_signal() -> void:
	if not is_instance_valid(_player) or not _player.has_signal("burst_ready_changed"):
		return
	var callable := Callable(self, "_on_player_burst_ready_changed")
	if _player.is_connected("burst_ready_changed", callable):
		_player.disconnect("burst_ready_changed", callable)
	_player.burst_ready_changed.connect(callable)
	if _player_hud and _player_hud.has_method("set_burst_ready") and _player.has_method("is_burst_ready"):
		_player_hud.set_burst_ready(_player.is_burst_ready(), false)

func _on_player_burst_ready_changed(is_ready: bool) -> void:
	if _player_hud and _player_hud.has_method("set_burst_ready"):
		_player_hud.set_burst_ready(is_ready)

func _apply_threat_styling() -> void:
	if not _objective_label:
		return
	var severity := _wave_threat_severity if _wave_threat_text != "" else -1
	var color := threat_color_inactive
	match severity:
		0:
			color = threat_color_low
		1:
			color = threat_color_med
		2:
			color = threat_color_high
		3:
			color = threat_color_critical
	_objective_label.modulate = color
	if severity >= threat_pulse_min_severity:
		_start_threat_pulse()
	else:
		_stop_threat_pulse()

func _start_threat_pulse() -> void:
	if not is_inside_tree() or not _objective_label:
		return
	if _wave_threat_severity < threat_pulse_min_severity:
		return
	if _objective_pulse_tween and _objective_pulse_tween.is_running():
		return
	_stop_threat_pulse()
	_objective_label.scale = Vector2.ONE
	var half_period: float = threat_pulse_period * 0.5
	if half_period < 0.05:
		half_period = 0.05
	_objective_pulse_tween = create_tween()
	var tween_ref: Tween = _objective_pulse_tween
	_objective_pulse_tween.set_trans(Tween.TRANS_SINE)
	_objective_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_objective_pulse_tween.tween_property(_objective_label, "scale", Vector2(threat_pulse_scale, threat_pulse_scale), half_period)
	_objective_pulse_tween.tween_property(_objective_label, "scale", Vector2.ONE, half_period)
	_objective_pulse_tween.finished.connect(func():
		if _objective_pulse_tween != tween_ref:
			return
		_objective_pulse_tween = null
		if _wave_threat_severity >= threat_pulse_min_severity:
			call_deferred("_start_threat_pulse")
		else:
			_stop_threat_pulse()
	)

func _stop_threat_pulse() -> void:
	if _objective_pulse_tween:
		if _objective_pulse_tween.is_running():
			_objective_pulse_tween.kill()
		_objective_pulse_tween = null
	if _objective_label:
		_objective_label.scale = Vector2.ONE

func _exit_tree() -> void:
	_stop_threat_pulse()

func _on_player_died() -> void:
	if _world_manager:
		_world_manager.stop()
	_submit_leaderboard_record("death")

func _submit_leaderboard_record(outcome: String = "death") -> void:
	if _run_summary_submitted:
		return
	_run_summary_submitted = true
	if not _leaderboard_service or not _leaderboard_service.has_method("update_record"):
		return
	var character_code := ""
	var character_name := ""
	if _character_profile:
		var raw_code: Variant = _character_profile.get("code_name")
		if typeof(raw_code) == TYPE_STRING:
			character_code = String(raw_code)
		var raw_display: Variant = _character_profile.get("display_name")
		if typeof(raw_display) == TYPE_STRING:
			character_name = String(raw_display)
	if character_code == "":
		character_code = "default"
	var waves_survived: int = max(1, _current_wave_index)
	var enemies_killed: int = max(0, _total_kills)
	var survival_seconds: int = max(0, int(round(_current_run_time)))
	var score: int = _calculate_run_score(waves_survived, enemies_killed, survival_seconds)
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var record: Dictionary = {
		"score": score,
		"waves_survived": waves_survived,
		"enemies_killed": enemies_killed,
		"survival_time_seconds": survival_seconds,
		"date": timestamp,
		"outcome": outcome,
		"character_code": character_code
	}
	if character_name != "":
		record["character_name"] = character_name
	_leaderboard_service.update_record(character_code, record)
	emit_signal("run_ended", outcome, record.duplicate(true))

func _calculate_run_score(waves: int, kills: int, survival_seconds: int) -> int:
	var wave_score := waves * 100
	var kill_score := kills * 10
	var time_bonus := int(floor(float(survival_seconds) * 0.2))
	return wave_score + kill_score + time_bonus
