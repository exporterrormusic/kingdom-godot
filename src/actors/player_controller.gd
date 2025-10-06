extends CharacterBody2D
class_name PlayerController

signal health_changed(current: int, max: int, delta: int)
signal burst_changed(current: float, max: float)
signal ammo_changed(current_ammo: int, magazine_size: int, special_current: int, special_max: int)
signal burst_ready_changed(is_ready: bool)
signal player_died

@export_range(1, 4000, 1) var base_max_health: int = 250
@export var burst_max_points: float = 100.0
@export var burst_points_per_enemy: float = 10.0
@export var burst_points_per_hit: float = 1.0
@export_range(0.0, 5.0, 0.01) var burst_hit_repeat_delay: float = 0.18

const BasicProjectileScene := preload("res://scenes/projectiles/BasicProjectile.tscn")
const CharacterDataScript := preload("res://src/resources/character_data.gd")
const BasicProjectileScript := preload("res://src/projectiles/basic_projectile.gd")
const ExplosiveProjectileScript := preload("res://src/projectiles/explosive_projectile.gd")
const BeamAttackScript := preload("res://src/effects/beam_attack.gd")
const ExplosionEffectScript := preload("res://src/effects/explosion_effect.gd")
const GroundFireScript := preload("res://src/effects/ground_fire.gd")

var move_speed := 400.0
var dash_speed := 900.0
var dash_duration := 0.2
var dash_cooldown := 1.0
var fire_rate := 0.25
var _projectile_speed := 1200.0
var _projectile_lifetime := 0.75
var _projectile_damage := 1
var _projectile_radius := 4.0
var _projectile_color := Color(1, 0.9, 0.4, 1)
var _projectile_penetration := 1
var _projectile_range := 800.0
var _projectile_shape := "standard"

var fire_mode := "automatic"
var magazine_size := 30
var _ammo_in_magazine := 30
var reload_time := 2.0
var _reload_time_left := 0.0
var _is_reloading := false
var grenade_rounds := 0
var grenade_reload_time := 0.0
var pellet_count := 1
var spread_angle := 0.0
var weapon_type := "Assault Rifle"
var weapon_name := ""
var special_mechanics: Dictionary = {}
var special_attack_data: Dictionary = {}
var _secondary_cooldown_left := 0.0
var _continuous_special_active := false
var _current_profile: CharacterDataScript = null
var _base_fire_rate := fire_rate
var _base_projectile_damage := _projectile_damage
var _max_grenade_rounds := 0
var _minigun_boost_time_left := 0.0
var _grenade_reload_timer := 0.0

var _max_health: int = 1
var _current_health: int = 1
var _is_dead: bool = false
var _burst_charge_max: float = 100.0
var _burst_charge_value: float = 0.0
var _burst_ready: bool = false
var _burst_hit_recent: Dictionary = {}
var _burst_hit_cleanup_timer: float = 0.0
var _character_code: String = ""
var _rewind_history: Array[Dictionary] = []
var _rewind_snapshot_interval: float = 0.25
var _rewind_snapshot_timer: float = 0.0
var _rewind_max_duration: float = 10.0
var _phase_time_left: float = 0.0
var _invincible_time_left: float = 0.0
var _infinite_ammo_time_left: float = 0.0
var _rapid_fire_time_left: float = 0.0
var _crown_aura_time_left: float = 0.0
var _crown_aura_tick_timer: float = 0.0
var _life_drain_time_left: float = 0.0
var _life_drain_tick_timer: float = 0.0
var _original_collision_layer: int = 0
var _original_collision_mask: int = 0
var _phase_modulate: Color = Color(1.0, 1.0, 1.0, 0.45)

var _dash_time_left := 0.0
var _dash_cooldown_left := 0.0
var _dash_direction := Vector2.ZERO
var _last_move_direction := Vector2.DOWN
var _fire_cooldown_left := 0.0
var _achievement_service: AchievementService = null
@onready var _animator: CharacterSpriteAnimator = $CharacterSpriteAnimator

func _ready() -> void:
	_achievement_service = _resolve_achievement_service()
	if _animator:
		_animator.clear()
	_original_collision_layer = collision_layer
	_original_collision_mask = collision_mask
	_reset_burst_effect_states()
	_initialize_health()
	_initialize_burst()
	emit_ammo_state()

func _physics_process(delta: float) -> void:
	_update_dash_timers(delta)
	_update_fire_cooldown(delta)
	_update_reload_timer(delta)
	_update_grenade_reload(delta)
	_update_secondary_cooldown(delta)
	_update_minigun_boost(delta)
	_update_burst_hit_history(delta)
	_update_burst_effects(delta)
	var input_vector := _get_input_vector()
	if input_vector != Vector2.ZERO:
		_last_move_direction = input_vector.normalized()
	if Input.is_action_just_pressed("dash"):
		_attempt_dash(input_vector)
	if Input.is_action_just_pressed("reload"):
		_request_reload()
	var wants_fire := false
	match fire_mode.to_lower():
		"semi-automatic":
			wants_fire = Input.is_action_just_pressed("fire_primary")
		"melee":
			wants_fire = Input.is_action_pressed("fire_primary")
		_:
			wants_fire = Input.is_action_pressed("fire_primary")
	if wants_fire:
		_attempt_primary_fire()
	var wants_special := Input.is_action_pressed("fire_secondary")
	if wants_special:
		_attempt_secondary_fire()
	else:
		_reset_continuous_special_state()
	if Input.is_action_just_pressed("burst"):
		_attempt_burst_activation()
	velocity = _calculate_velocity(input_vector)
	_update_animation_state(velocity, _get_raw_aim_vector())
	move_and_slide()
	_record_rewind_snapshot(delta)

func _get_input_vector() -> Vector2:
	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	return input_vector

func _update_dash_timers(delta: float) -> void:
	if _dash_time_left > 0.0:
		_dash_time_left = max(_dash_time_left - delta, 0.0)
		if _dash_time_left == 0.0:
			_dash_direction = Vector2.ZERO
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = max(_dash_cooldown_left - delta, 0.0)

func _update_fire_cooldown(delta: float) -> void:
	if _fire_cooldown_left > 0.0:
		_fire_cooldown_left = max(_fire_cooldown_left - delta, 0.0)

func _update_secondary_cooldown(delta: float) -> void:
	if _secondary_cooldown_left > 0.0:
		_secondary_cooldown_left = max(_secondary_cooldown_left - delta, 0.0)

func _update_grenade_reload(delta: float) -> void:
	if grenade_reload_time <= 0.0:
		return
	if _max_grenade_rounds <= 0:
		return
	if grenade_rounds >= _max_grenade_rounds:
		_grenade_reload_timer = 0.0
		return
	if _grenade_reload_timer > 0.0:
		_grenade_reload_timer = max(_grenade_reload_timer - delta, 0.0)
	else:
		_grenade_reload_timer = max(0.0, grenade_reload_time)
		return
	if _grenade_reload_timer == 0.0:
		var previous_rounds: int = grenade_rounds
		grenade_rounds = min(_max_grenade_rounds, grenade_rounds + 1)
		if grenade_rounds != previous_rounds:
			emit_ammo_state()
		if grenade_rounds < _max_grenade_rounds:
			_grenade_reload_timer = grenade_reload_time

func _update_minigun_boost(delta: float) -> void:
	if _minigun_boost_time_left <= 0.0:
		return
	_minigun_boost_time_left = max(_minigun_boost_time_left - delta, 0.0)
	if _minigun_boost_time_left == 0.0:
		_reset_minigun_boost()


func _update_burst_hit_history(delta: float) -> void:
	if _burst_hit_recent.is_empty():
		return
	if burst_hit_repeat_delay <= 0.0:
		_burst_hit_recent.clear()
		_burst_hit_cleanup_timer = 0.0
		return
	_burst_hit_cleanup_timer += delta
	if _burst_hit_cleanup_timer < max(0.05, burst_hit_repeat_delay * 0.5):
		return
	_burst_hit_cleanup_timer = 0.0
	var now := Time.get_ticks_msec() * 0.001
	var expiry := burst_hit_repeat_delay * 3.0
	var to_remove: Array = []
	for instance_id in _burst_hit_recent.keys():
		var last_time := float(_burst_hit_recent.get(instance_id, 0.0))
		if now - last_time >= expiry:
			to_remove.append(instance_id)
	for instance_id in to_remove:
		_burst_hit_recent.erase(instance_id)

func _update_reload_timer(delta: float) -> void:
	if not _is_reloading:
		return
	_reload_time_left = max(_reload_time_left - delta, 0.0)
	if _reload_time_left == 0.0:
		_finish_reload()

func _attempt_dash(input_vector: Vector2) -> void:
	if _dash_cooldown_left > 0.0:
		return
	var dash_vector := input_vector
	if dash_vector == Vector2.ZERO:
		dash_vector = _last_move_direction
	if dash_vector == Vector2.ZERO:
		return
	_dash_direction = dash_vector.normalized()
	_dash_time_left = dash_duration
	_dash_cooldown_left = dash_cooldown
	_record_stat("dashes_performed", 1)

func _calculate_velocity(input_vector: Vector2) -> Vector2:
	if _dash_time_left > 0.0 and _dash_direction != Vector2.ZERO:
		return _dash_direction * dash_speed
	return input_vector * move_speed

func _attempt_primary_fire() -> void:
	if _fire_cooldown_left > 0.0:
		return
	if _is_reloading:
		return
	var direction := _get_aim_direction()
	if direction == Vector2.ZERO:
		return
	if magazine_size > 0 and _ammo_in_magazine <= 0:
		_begin_reload()
		return
	var fired := false
	if weapon_type == "Rocket Launcher":
		fired = _fire_rocket_primary(direction)
	else:
		var projectile := BasicProjectileScene.instantiate()
		_fire_projectile_salvo(projectile, direction)
		fired = true
	if not fired:
		return
	_consume_ammo()
	_fire_cooldown_left = fire_rate
	_record_stat("projectiles_fired", 1)

func _attempt_secondary_fire() -> void:
	if _is_reloading:
		return
	if _secondary_cooldown_left > 0.0 and not _continuous_special_active:
		return
	var direction := _get_aim_direction()
	if direction == Vector2.ZERO:
		return
	var fired := false
	match weapon_type:
		"Assault Rifle":
			fired = _fire_assault_rifle_grenade(direction)
		"SMG":
			fired = _fire_smg_special(direction)
		"Sniper":
			fired = _fire_sniper_special(direction)
		"Shotgun":
			fired = _fire_shotgun_special(direction)
		"Rocket Launcher":
			fired = _fire_rocket_special(direction)
		"Minigun":
			fired = _fire_minigun_special()
		"Sword":
			fired = _fire_sword_special(direction)
		_:
			fired = false
	if not fired:
		return
	var base_cooldown := _resolve_secondary_cooldown()
	var gating_cooldown := base_cooldown if base_cooldown > 0.0 else fire_rate
	_secondary_cooldown_left = gating_cooldown
	_continuous_special_active = base_cooldown <= 0.0
	_record_stat("special_attacks_used", 1)

func _reset_continuous_special_state() -> void:
	if not _continuous_special_active:
		return
	_continuous_special_active = false
	if weapon_type == "Minigun":
		_reset_minigun_boost()

func _resolve_secondary_cooldown() -> float:
	if special_attack_data.has("cooldown"):
		return max(0.0, float(special_attack_data.get("cooldown", 0.0)))
	return fire_rate

func _fire_assault_rifle_grenade(direction: Vector2) -> bool:
	if grenade_rounds <= 0:
		return false
	var grenade := ExplosiveProjectileScript.new()
	var grenade_config: Dictionary = special_mechanics.get("grenade_launcher", {})
	grenade.direction = direction
	grenade.speed = float(grenade_config.get("projectile_speed", 600.0))
	grenade.lifetime = 3.0
	grenade.max_flight_time = 5.0
	grenade.damage = int(grenade_config.get("damage", _projectile_damage * 2))
	grenade.explosion_damage = grenade.damage
	grenade.explosion_radius = float(grenade_config.get("explosion_radius", 120.0))
	grenade.explosion_color = _color_from_variant(grenade_config.get("projectile_color", Color(1.0, 0.5, 0.2, 0.8)), Color(1.0, 0.5, 0.2, 0.8))
	grenade.owner_node = self
	grenade.render_style = "grenade"
	grenade.special_attack = false
	grenade.trail_enabled = false
	grenade.target_position = get_global_mouse_position()
	grenade.explode_at_target = true
	grenade.global_position = global_position
	if get_parent():
		get_parent().add_child(grenade)
	_spawn_muzzle_explosion(grenade.explosion_color, grenade.explosion_radius * 0.35, direction)
	grenade_rounds = max(0, grenade_rounds - 1)
	if grenade_reload_time > 0.0 and grenade_rounds < _max_grenade_rounds:
		_grenade_reload_timer = grenade_reload_time
	emit_ammo_state()
	return true

func _fire_smg_special(direction: Vector2) -> bool:
	return _fire_smg_dual_stream(direction)

func _fire_smg_dual_stream(direction: Vector2) -> bool:
	var range_multiplier := float(special_attack_data.get("range_multiplier", 0.5))
	var bounce_range_multiplier := float(special_attack_data.get("bounce_range_multiplier", 0.5))
	var max_bounce := int(special_attack_data.get("max_bounces", 1))
	var enemy_focus := bool(special_attack_data.get("enemy_targeting", true))
	var reduced_range := _projectile_range * range_multiplier
	var bounce_range := reduced_range * bounce_range_multiplier
	var special_color: Color = _color_from_variant(special_attack_data.get("color", _projectile_color), Color(0.0, 1.0, 1.0, 1.0))
	var offsets := [-1, 1]
	var fired := false
	for offset_sign in offsets:
		var projectile := BasicProjectileScene.instantiate()
		_apply_projectile_profile(projectile)
		projectile.max_range = reduced_range
		projectile.bounce_enabled = true
		projectile.max_bounces = max_bounce
		projectile.bounce_range = bounce_range
		projectile.enemy_targeting = enemy_focus
		projectile.trail_enabled = false
		projectile.color = special_color
		var perpendicular := direction.rotated(PI / 2.0) * 30.0 * float(offset_sign)
		projectile.global_position = global_position + perpendicular
		if projectile.has_method("set_direction"):
			projectile.set_direction(direction)
		if get_parent():
			get_parent().add_child(projectile)
		fired = true
	return fired

func _fire_sniper_special(direction: Vector2) -> bool:
	var projectile := BasicProjectileScene.instantiate()
	_apply_projectile_profile(projectile)
	var default_special_color := Color(0.6, 0.82, 1.0, 1.0)
	projectile.color = _color_from_variant(special_attack_data.get("color", default_special_color), default_special_color)
	var damage_multiplier := float(special_attack_data.get("damage_multiplier", 1.5))
	projectile.damage = int(round(float(_projectile_damage) * damage_multiplier))
	projectile.radius = _projectile_radius * float(special_attack_data.get("size_multiplier", 1.5))
	projectile.shape = "laser"
	projectile.trail_enabled = true
	projectile.trail_interval = 24.0
	projectile.trail_damage = int(special_attack_data.get("trail_damage", 12))
	projectile.trail_duration = float(special_attack_data.get("trail_duration", 1.25))
	var default_trail_color := Color(0.45, 0.78, 1.0, 0.88)
	projectile.trail_color = _color_from_variant(special_attack_data.get("trail_color", default_trail_color), default_trail_color)
	if projectile.has_method("set_direction"):
		projectile.set_direction(direction)
	projectile.global_position = global_position
	if get_parent():
		get_parent().add_child(projectile)
	return true

func _fire_shotgun_special(direction: Vector2) -> bool:
	var projectile := BasicProjectileScene.instantiate()
	var original_pellets := pellet_count
	var original_spread := spread_angle
	var original_damage := _projectile_damage
	var damage_multiplier := float(special_attack_data.get("damage_multiplier", 0.67))
	var blast_angle := float(special_attack_data.get("blast_angle", 45.0))
	var blast_range := float(special_attack_data.get("blast_range", 150.0))
	var color: Color = _color_from_variant(special_attack_data.get("color", Color(1.0, 0.4, 0.2, 1.0)), Color(1.0, 0.4, 0.2, 1.0))
	var blast_damage := int(special_attack_data.get("blast_damage", original_damage))
	_projectile_damage = int(round(original_damage * damage_multiplier))
	pellet_count = original_pellets + 2
	spread_angle = original_spread + blast_angle
	_apply_projectile_profile(projectile)
	projectile.color = color
	var payload: Dictionary = {
		"direction": direction,
		"blast_range": blast_range,
		"blast_angle": blast_angle,
		"color": color,
		"blast_damage": blast_damage
	}
	_fire_projectile_salvo(projectile, direction, Callable(self, "_on_shotgun_special_hit"), payload)
	pellet_count = original_pellets
	spread_angle = original_spread
	_projectile_damage = original_damage
	return true

func _fire_rocket_special(direction: Vector2) -> bool:
	return _launch_rocket(direction, true)

func _fire_minigun_special() -> bool:
	return _activate_minigun_boost()

func _fire_sword_special(direction: Vector2) -> bool:
	var beam := BeamAttackScript.new()
	beam.owner_reference = self
	beam.direction = direction
	beam.beam_range = float(special_attack_data.get("range", 500.0))
	beam.width = float(special_attack_data.get("beam_width", 18.0))
	beam.damage = int(round(_projectile_damage * float(special_attack_data.get("damage_multiplier", 1.3))))
	beam.duration = float(special_attack_data.get("beam_duration", 0.4))
	beam.color = _color_from_variant(special_attack_data.get("beam_color", Color(0.4, 1.0, 0.8, 0.8)), Color(0.4, 1.0, 0.8, 0.8))
	if get_parent():
		get_parent().add_child(beam)
	return true


func _fire_projectile_salvo(base_projectile: Node, direction: Vector2, impact_callback: Callable = Callable(), impact_payload: Dictionary = {}) -> void:
	var total_pellets: int = max(1, pellet_count)
	var spread_radians: float = deg_to_rad(spread_angle)
	for idx in range(total_pellets):
		var projectile := base_projectile if idx == 0 else BasicProjectileScene.instantiate()
		var offset := 0.0
		if total_pellets > 1:
			var step := spread_radians / float(total_pellets - 1)
			offset = -spread_radians * 0.5 + step * float(idx)
		var pellet_direction := direction.rotated(offset)
		if projectile.has_method("set_direction"):
			projectile.set_direction(pellet_direction)
		projectile.global_position = global_position
		if get_parent() and projectile.get_parent() != get_parent():
			get_parent().add_child(projectile)
		_apply_projectile_profile(projectile)
		if impact_callback.is_valid() and projectile.has_method("set_impact_callback"):
			projectile.set_impact_callback(impact_callback, impact_payload.duplicate(true))

func _fire_rocket_primary(direction: Vector2) -> bool:
	return _launch_rocket(direction, false)

func _launch_rocket(direction: Vector2, is_special: bool) -> bool:
	var rocket := ExplosiveProjectileScript.new()
	var target_position := get_global_mouse_position()
	rocket.global_position = global_position
	rocket.owner_node = self
	rocket.direction = direction
	rocket.target_position = target_position
	rocket.explode_at_target = true
	rocket.render_style = "rocket"
	rocket.special_attack = is_special
	rocket.speed = _projectile_speed
	rocket.lifetime = 4.0
	rocket.max_flight_time = 6.0
	var base_color := _projectile_color
	var explosion_radius := float(special_mechanics.get("explosion_radius", max(120.0, _projectile_range * 0.25)))
	var damage_multiplier := 1.0
	var radius_multiplier := 1.0
	if is_special:
		damage_multiplier = float(special_attack_data.get("damage_multiplier", 1.5))
		radius_multiplier = float(special_attack_data.get("explosion_radius_multiplier", 2.0))
		base_color = _color_from_variant(special_attack_data.get("color", base_color), base_color)
	else:
		base_color = _color_from_variant(special_mechanics.get("projectile_color", base_color), base_color)
	rocket.explosion_color = base_color
	rocket.damage = int(round(_projectile_damage * damage_multiplier))
	rocket.explosion_damage = rocket.damage
	rocket.explosion_radius = max(80.0, explosion_radius * radius_multiplier)
	rocket.trail_enabled = true
	rocket.trail_color = Color(base_color.r, base_color.g, base_color.b, 0.85)
	rocket.trail_width = 22.0 if is_special else 16.0
	rocket.trail_spacing = 18.0 if is_special else 24.0
	rocket.trail_max_points = 20 if is_special else 12
	var trail_core := Color(1.0, 0.96, 0.85, 0.92)
	var trail_glow := Color(base_color.r, base_color.g * 0.7, base_color.b * 0.45, 0.65)
	if is_special:
		trail_core = Color(1.0, 0.86, 0.62, 0.92)
		trail_glow = Color(base_color.r, base_color.g * 0.6, base_color.b * 0.4, 0.75)
	rocket.trail_core_color = trail_core
	rocket.trail_glow_color = trail_glow
	rocket.exhaust_enabled = true
	rocket.exhaust_length = 54.0 if is_special else 44.0
	rocket.exhaust_width = 26.0 if is_special else 20.0
	rocket.exhaust_glow_color = Color(base_color.r, base_color.g * 0.85, base_color.b * 0.6, 0.75)
	rocket.smoke_enabled = true
	rocket.smoke_color = Color(0.58, 0.58, 0.6, 0.85)
	if is_special:
		rocket.smoke_color = Color(0.62, 0.48, 0.46, 0.86)
	rocket.smoke_spawn_interval = 0.04 if is_special else 0.06
	rocket.smoke_initial_radius = 12.0 if is_special else 9.5
	rocket.smoke_growth_rate = 32.0
	rocket.smoke_fade_speed = 0.82
	if is_special:
		rocket.ground_fire_enabled = true
		rocket.ground_fire_duration = float(special_attack_data.get("ground_fire_duration", 5.0))
		rocket.ground_fire_damage = int(special_attack_data.get("ground_fire_damage", 15))
		rocket.ground_fire_radius = rocket.explosion_radius * 0.8
		rocket.ground_fire_color = Color(base_color.r, base_color.g * 0.9, base_color.b * 0.7, 0.85)
	else:
		rocket.ground_fire_enabled = false
	if get_parent():
		get_parent().add_child(rocket)
	_spawn_muzzle_explosion(base_color, rocket.explosion_radius * (0.35 if is_special else 0.28), direction)
	return true

func _spawn_muzzle_explosion(color: Color, radius: float, direction: Vector2 = Vector2.ZERO) -> void:
	if not get_parent():
		return
	var effect: ExplosionEffect = ExplosionEffectScript.new()
	effect.radius = max(24.0, radius)
	effect.duration = 0.2
	effect.base_color = Color(color.r, color.g, color.b, 0.8)
	effect.glow_color = Color(color.r, color.g, color.b, 0.6)
	effect.core_color = Color(1.0, 0.92, 0.78, 0.85)
	effect.shockwave_color = Color(color.r, color.g * 0.8, color.b * 0.6, 0.8)
	effect.spark_color = Color(1.0, 0.88, 0.6, 0.85)
	effect.spark_count = 8
	effect.shockwave_thickness = max(8.0, radius * 0.25)
	var spawn_offset := Vector2.ZERO
	if direction.length() > 0.01:
		spawn_offset = direction.normalized() * max(28.0, radius * 0.4)
	effect.global_position = global_position + spawn_offset
	get_parent().add_child(effect)

func _consume_ammo() -> void:
	if magazine_size <= 0:
		return
	if _infinite_ammo_time_left > 0.0:
		if _ammo_in_magazine < magazine_size:
			_ammo_in_magazine = magazine_size
			emit_ammo_state()
		return
	var previous_ammo: int = _ammo_in_magazine
	_ammo_in_magazine = max(0, _ammo_in_magazine - 1)
	if _ammo_in_magazine != previous_ammo:
		emit_ammo_state()
	if _ammo_in_magazine == 0:
		_begin_reload()

func _begin_reload() -> void:
	if _is_reloading:
		return
	if magazine_size <= 0:
		return
	if _infinite_ammo_time_left > 0.0:
		_ammo_in_magazine = magazine_size
		emit_ammo_state()
		return
	_is_reloading = true
	_reload_time_left = max(0.0, reload_time)
	_record_stat("reloads_triggered", 1)

func _finish_reload() -> void:
	_is_reloading = false
	_reload_time_left = 0.0
	_ammo_in_magazine = magazine_size if magazine_size > 0 else _ammo_in_magazine
	emit_ammo_state()

func _request_reload() -> void:
	if magazine_size <= 0:
		return
	if _is_reloading:
		return
	if _ammo_in_magazine >= magazine_size:
		return
	if _infinite_ammo_time_left > 0.0:
		_ammo_in_magazine = magazine_size
		emit_ammo_state()
		return
	_begin_reload()

func _get_aim_direction() -> Vector2:
	var direction := _get_raw_aim_vector()
	return direction.normalized() if direction.length() > 0.0 else Vector2.ZERO

func _get_raw_aim_vector() -> Vector2:
	var direction := get_global_mouse_position() - global_position
	if direction.length() == 0.0:
		direction = _last_move_direction
	return direction

func apply_profile(profile) -> void:
	if not profile:
		if _animator:
			_animator.clear()
		return
	var data = profile
	if profile is CharacterDataScript:
		data = profile
	elif profile.has_method("get"):
		data = profile
	else:
		return

	_move_property_if_present(data, "move_speed", func(value): move_speed = float(value))
	_move_property_if_present(data, "dash_speed", func(value): dash_speed = float(value))
	_move_property_if_present(data, "dash_duration", func(value): dash_duration = float(value))
	_move_property_if_present(data, "dash_cooldown", func(value): dash_cooldown = float(value))
	_move_property_if_present(data, "fire_rate", func(value): fire_rate = max(float(value), 0.05))
	_move_property_if_present(data, "projectile_speed", func(value): _projectile_speed = float(value))
	_move_property_if_present(data, "projectile_lifetime", func(value): _projectile_lifetime = float(value))
	_move_property_if_present(data, "projectile_damage", func(value): _projectile_damage = int(value))
	_move_property_if_present(data, "projectile_radius", func(value): _projectile_radius = float(value))
	_move_property_if_present(data, "projectile_color", func(value): _projectile_color = value)
	_move_property_if_present(data, "projectile_penetration", func(value): _projectile_penetration = int(value))
	_move_property_if_present(data, "projectile_range", func(value): _projectile_range = float(value))
	_move_property_if_present(data, "projectile_shape", func(value): _projectile_shape = str(value))
	_move_property_if_present(data, "fire_mode", func(value): fire_mode = str(value))
	_move_property_if_present(data, "magazine_size", func(value): magazine_size = max(0, int(value)))
	_move_property_if_present(data, "reload_time", func(value): reload_time = max(0.0, float(value)))
	_move_property_if_present(data, "grenade_rounds", func(value): grenade_rounds = max(0, int(value)))
	_move_property_if_present(data, "grenade_reload_time", func(value): grenade_reload_time = max(0.0, float(value)))
	_move_property_if_present(data, "pellet_count", func(value): pellet_count = max(1, int(value)))
	_move_property_if_present(data, "spread_angle", func(value): spread_angle = max(0.0, float(value)))
	_move_property_if_present(data, "weapon_type", func(value): weapon_type = str(value))
	_move_property_if_present(data, "weapon_name", func(value): weapon_name = str(value))
	_move_property_if_present(data, "burst_max_points", func(value): burst_max_points = max(1.0, float(value)))
	_move_property_if_present(data, "burst_points_per_enemy", func(value): burst_points_per_enemy = max(0.0, float(value)))
	_move_property_if_present(data, "burst_points_per_hit", func(value): burst_points_per_hit = max(0.0, float(value)))
	_move_property_if_present(data, "special_mechanics", func(value): special_mechanics = value.duplicate(true) if (value is Dictionary) else {})
	_move_property_if_present(data, "special_attack_data", func(value): special_attack_data = value.duplicate(true) if (value is Dictionary) else {})
	_move_property_if_present(data, "hp", func(value):
		var hp_value: int = maxi(1, int(value))
		base_max_health = hp_value
		set_max_health(hp_value, true)
	)
	_configure_animator_from_profile(data)
	# Reset cooldown timers to prevent immediate action conflicts when switching profiles.
	_fire_cooldown_left = 0.0
	_dash_cooldown_left = 0.0
	_dash_time_left = 0.0
	_is_reloading = false
	_reload_time_left = 0.0
	_ammo_in_magazine = magazine_size if magazine_size > 0 else 9999
	_base_fire_rate = fire_rate
	_base_projectile_damage = _projectile_damage
	_max_grenade_rounds = grenade_rounds
	_minigun_boost_time_left = 0.0
	_grenade_reload_timer = 0.0
	_current_profile = profile if profile is CharacterDataScript else null
	if not (special_mechanics is Dictionary):
		special_mechanics = {}
	if not (special_attack_data is Dictionary):
		special_attack_data = {}
	_character_code = ""
	if data and data.has_method("get"):
		var raw_code: Variant = data.get("code_name")
		if raw_code != null:
			_character_code = str(raw_code).strip_edges().to_lower()
	_reset_burst_effect_states()
	_initialize_burst()
	emit_ammo_state()

func _initialize_health() -> void:
	_max_health = maxi(1, base_max_health)
	_current_health = _max_health
	_is_dead = false
	emit_health_state()

func _initialize_burst() -> void:
	_burst_charge_max = max(1.0, burst_max_points)
	if not Engine.is_editor_hint():
		_burst_charge_value = 0.0
	_burst_charge_value = clampf(_burst_charge_value, 0.0, _burst_charge_max)
	_set_burst_ready(_burst_charge_value >= _burst_charge_max and _burst_charge_max > 0.0)
	emit_burst_state()

func emit_health_state() -> void:
	emit_signal("health_changed", _current_health, _max_health, 0)

func emit_burst_state() -> void:
	emit_signal("burst_changed", _burst_charge_value, _burst_charge_max)

func emit_ammo_state() -> void:
	var current_ammo := _ammo_in_magazine if magazine_size > 0 else 0
	var mag_capacity := magazine_size
	var special_current := grenade_rounds
	var special_max := _max_grenade_rounds
	emit_signal("ammo_changed", current_ammo, mag_capacity, special_current, special_max)

func add_burst_points(points: float) -> void:
	if points <= 0.0 or _burst_charge_max <= 0.0:
		return
	_burst_charge_value = clampf(_burst_charge_value + points, 0.0, _burst_charge_max)
	_set_burst_ready(_burst_charge_value >= _burst_charge_max)
	emit_burst_state()

func consume_burst_points(points: float) -> void:
	if points <= 0.0:
		return
	_burst_charge_value = clampf(_burst_charge_value - points, 0.0, _burst_charge_max)
	_set_burst_ready(_burst_charge_value >= _burst_charge_max)
	emit_burst_state()

func is_burst_ready() -> bool:
	return _burst_ready

func use_burst() -> bool:
	if not is_burst_ready():
		return false
	_burst_charge_value = 0.0
	_set_burst_ready(false)
	emit_burst_state()
	return true


func register_burst_hit(target: Node, custom_points: float = -1.0) -> void:
	if target == null or not is_instance_valid(target):
		return
	var points := custom_points if custom_points > 0.0 else burst_points_per_hit
	if points <= 0.0:
		return
	var instance_id := target.get_instance_id()
	var now := Time.get_ticks_msec() * 0.001
	if burst_hit_repeat_delay > 0.0:
		var last_time := float(_burst_hit_recent.get(instance_id, -INF))
		if last_time != -INF and now - last_time < burst_hit_repeat_delay:
			return
		_burst_hit_recent[instance_id] = now
	add_burst_points(points)


func _set_burst_ready(new_ready: bool) -> void:
	if _burst_ready == new_ready:
		return
	_burst_ready = new_ready
	emit_signal("burst_ready_changed", _burst_ready)

func _attempt_burst_activation() -> void:
	if _is_dead:
		return
	if use_burst():
		_on_burst_activated()

func _on_burst_activated() -> void:
	_record_stat("burst_activations", 1)
	_trigger_character_burst_effect()


func _trigger_character_burst_effect() -> void:
	if not get_parent():
		return
	var code := _character_code
	if code.is_empty() and _current_profile and _current_profile.has_method("get"):
		var raw_code: Variant = _current_profile.get("code_name")
		if raw_code != null:
			code = str(raw_code).strip_edges().to_lower()
	match code:
		"cecil":
			_activate_cecil_burst()
			return
		"commander":
			_activate_commander_burst()
			return
		"wells":
			_activate_wells_burst()
			return
		"trony":
			_activate_trony_burst()
			return
		"kilo":
			_activate_kilo_burst()
			return
		"rapunzel":
			_activate_rapunzel_burst()
			return
		"crown":
			_activate_crown_burst()
			return
		"sin":
			_activate_sin_burst()
			return
	var style := _determine_burst_style()
	match style:
		"sniper", "sniper_rifle":
			_spawn_sniper_burst()
		"rocket_launcher", "rocket":
			_spawn_rocket_burst()
		"shotgun":
			_spawn_shotgun_burst()
		"minigun":
			_spawn_minigun_burst()
		"sword":
			_spawn_sword_burst()
		"smg":
			_spawn_assault_burst(true)
		_:
			_spawn_assault_burst(false)


func _determine_burst_style() -> String:
	var style := ""
	if special_attack_data.has("burst_style"):
		style = str(special_attack_data.get("burst_style", ""))
	if style.is_empty() and _current_profile and _current_profile.has_method("get"):
		var profile_special: Dictionary = {}
		var raw_profile_special: Variant = _current_profile.get("special_attack_data")
		if raw_profile_special is Dictionary:
			profile_special = raw_profile_special
		if profile_special.has("burst_style"):
			style = str(profile_special.get("burst_style", ""))
	if style.is_empty():
		var weapon := weapon_type
		if weapon.is_empty() and _current_profile:
			if _current_profile.has_method("get_weapon_type"):
				weapon = str(_current_profile.call("get_weapon_type"))
			elif _current_profile.has_method("get"):
				var raw_weapon: Variant = _current_profile.get("weapon_type")
				if raw_weapon != null:
					weapon = str(raw_weapon)
		style = weapon
	return style.strip_edges().to_lower().replace(" ", "_")


func _spawn_assault_burst(is_smg: bool) -> void:
	var parent := get_parent()
	if not parent:
		return
	var direction := _get_aim_direction()
	if direction.length() == 0.0:
		direction = _last_move_direction
	direction = direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	var blast_count := 5 if is_smg else 3
	var base_distance := 120.0
	var spread_degrees := 18.0 if is_smg else 28.0
	var base_color := _color_from_variant(special_attack_data.get("burst_color", _projectile_color), _projectile_color)
	for i in range(blast_count):
		var offset_ratio := 0.0
		if blast_count > 1:
			offset_ratio = (float(i) / float(blast_count - 1)) * 2.0 - 1.0
		var angle := deg_to_rad(spread_degrees * offset_ratio)
		var distance := base_distance + float(i) * (40.0 if is_smg else 52.0)
		var effect := ExplosionEffectScript.new()
		effect.radius = (130.0 if is_smg else 180.0) * (1.0 - abs(offset_ratio) * 0.25)
		effect.duration = 0.4
		effect.base_color = base_color
		effect.glow_color = Color(base_color.r, base_color.g, base_color.b, min(1.0, base_color.a + 0.15))
		effect.core_color = Color(1.0, 0.92, 0.78, 0.9)
		effect.shockwave_color = Color(base_color.r, base_color.g * 0.8, base_color.b * 0.6, 0.85)
		parent.add_child(effect)
		effect.global_position = global_position + direction.rotated(angle) * distance
		_apply_burst_damage_area(effect.global_position, effect.radius * 0.9, _calculate_burst_damage())


func _spawn_sniper_burst() -> void:
	var parent := get_parent()
	if not parent:
		return
	var direction := _get_aim_direction()
	if direction.length() == 0.0:
		direction = _last_move_direction
	direction = direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	var beam := BeamAttackScript.new()
	beam.owner_reference = self
	beam.direction = direction
	beam.beam_range = max(_projectile_range * 1.5, 1000.0)
	beam.width = 42.0
	beam.damage = max(_calculate_burst_damage(3.0), _projectile_damage * 3)
	beam.duration = 0.55
	var beam_color := _color_from_variant(special_attack_data.get("burst_color", Color(0.65, 0.9, 1.0, 0.95)), Color(0.65, 0.9, 1.0, 0.95))
	beam.color = beam_color
	parent.add_child(beam)
	_spawn_trailing_explosions(direction, beam_color)


func _spawn_trailing_explosions(direction: Vector2, color: Color) -> void:
	var parent := get_parent()
	if not parent:
		return
	for step in range(3):
		var effect := ExplosionEffectScript.new()
		effect.radius = 120.0 + float(step) * 30.0
		effect.duration = 0.3
		effect.base_color = Color(color.r, color.g, color.b, 0.55)
		effect.glow_color = Color(color.r * 0.8, color.g, color.b, 0.35)
		parent.add_child(effect)
		var distance := 140.0 + float(step) * 160.0
		effect.global_position = global_position + direction * distance
		_apply_burst_damage_area(effect.global_position, effect.radius * 0.8, max(_calculate_burst_damage(1.8 - step * 0.3), 1))


func _spawn_rocket_burst() -> void:
	var parent := get_parent()
	if not parent:
		return
	var direction := _get_aim_direction()
	if direction.length() == 0.0:
		direction = _last_move_direction
	direction = direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	var target: Vector2 = global_position + direction * max(_projectile_range * 0.6, 360.0)
	var effect := ExplosionEffectScript.new()
	effect.radius = 260.0
	effect.duration = 0.55
	var base_color := _color_from_variant(special_attack_data.get("burst_color", Color(1.0, 0.6, 0.32, 0.9)), Color(1.0, 0.6, 0.32, 0.9))
	effect.base_color = base_color
	effect.glow_color = Color(base_color.r, base_color.g * 0.8, base_color.b * 0.6, 0.78)
	effect.core_color = Color(1.0, 0.9, 0.7, 0.92)
	effect.shockwave_color = Color(base_color.r, base_color.g * 0.7, base_color.b * 0.5, 0.9)
	effect.shockwave_thickness = 26.0
	parent.add_child(effect)
	effect.global_position = target
	_apply_burst_damage_area(effect.global_position, effect.radius * 1.1, _calculate_burst_damage(3.2))
	var scorch := GroundFireScript.new()
	scorch.radius = effect.radius * 0.8
	scorch.duration = 4.0
	scorch.damage_per_tick = max(1, int(round(_calculate_burst_damage(0.4))))
	scorch.color = Color(base_color.r, base_color.g * 0.8, base_color.b * 0.6, 0.6)
	scorch.glow_color = Color(base_color.r, base_color.g * 0.6, base_color.b * 0.4, 0.5)
	parent.add_child(scorch)
	scorch.global_position = target


func _spawn_shotgun_burst() -> void:
	var parent := get_parent()
	if not parent:
		return
	var direction := _get_aim_direction()
	if direction.length() == 0.0:
		direction = _last_move_direction
	direction = direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	var color := _color_from_variant(special_attack_data.get("burst_color", Color(1.0, 0.45, 0.2, 0.95)), Color(1.0, 0.45, 0.2, 0.95))
	_spawn_v_blast_effect(direction, 220.0, 70.0, color)
	_apply_v_blast_damage(global_position + direction * 180.0, direction, 240.0, 70.0, _calculate_burst_damage(2.6))


func _spawn_minigun_burst() -> void:
	var parent := get_parent()
	if not parent:
		return
	var fire := GroundFireScript.new()
	fire.radius = 190.0
	fire.duration = 5.0
	fire.tick_interval = 0.35
	fire.damage_per_tick = max(1, int(round(_calculate_burst_damage(0.55))))
	var base_color := _color_from_variant(special_attack_data.get("burst_color", Color(1.0, 0.78, 0.35, 0.8)), Color(1.0, 0.78, 0.35, 0.8))
	fire.color = Color(base_color.r, base_color.g, base_color.b, 0.55)
	fire.glow_color = Color(base_color.r, base_color.g * 0.8, base_color.b * 0.6, 0.4)
	fire.ember_color = Color(1.0, 0.86, 0.5, 0.85)
	parent.add_child(fire)
	fire.global_position = global_position
	_spawn_assault_burst(false)


func _spawn_sword_burst() -> void:
	var parent := get_parent()
	if not parent:
		return
	var direction := _get_aim_direction()
	if direction.length() == 0.0:
		direction = _last_move_direction
	direction = direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	var swings := 4
	var base_color := _color_from_variant(special_attack_data.get("burst_color", Color(0.9, 0.25, 0.35, 0.9)), Color(0.9, 0.25, 0.35, 0.9))
	for i in range(swings):
		var angle := deg_to_rad(-45.0 + 30.0 * float(i))
		var beam := BeamAttackScript.new()
		beam.owner_reference = self
		beam.direction = direction.rotated(angle)
		beam.beam_range = 420.0
		beam.width = 52.0
		beam.damage = max(_calculate_burst_damage(1.9), _projectile_damage * 4)
		beam.duration = 0.25 + 0.08 * float(i)
		beam.color = Color(base_color.r, base_color.g, base_color.b, base_color.a * (0.9 - 0.12 * i))
		parent.add_child(beam)
		var explosion := ExplosionEffectScript.new()
		explosion.radius = 150.0
		explosion.duration = 0.35
		explosion.base_color = base_color
		explosion.glow_color = Color(base_color.r, base_color.g * 0.6, base_color.b * 0.6, 0.6)
		explosion.core_color = Color(1.0, 0.92, 0.88, 0.85)
		parent.add_child(explosion)
		explosion.global_position = global_position + direction.rotated(angle) * 220.0
		_apply_burst_damage_area(explosion.global_position, explosion.radius, _calculate_burst_damage(2.1))


func _calculate_burst_damage(multiplier_override: float = -1.0) -> int:
	var multiplier := multiplier_override
	if multiplier <= 0.0:
		multiplier = _get_profile_burst_multiplier()
	return max(1, int(round(_base_projectile_damage * multiplier)))


func _get_profile_burst_multiplier(default_value: float = 2.0) -> float:
	if _current_profile and _current_profile.has_method("get"):
		var variant: Variant = _current_profile.get("burst_damage_multiplier")
		match typeof(variant):
			TYPE_FLOAT, TYPE_INT:
				return max(0.1, float(variant))
	return default_value


func _apply_burst_damage_area(center: Vector2, radius: float, damage: int) -> void:
	if damage <= 0 or not get_tree():
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D) or not enemy.has_method("apply_damage"):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node.global_position.distance_to(center) <= radius:
			enemy_node.apply_damage(damage)
			register_burst_hit(enemy_node)

func _reset_burst_effect_states() -> void:
	_phase_time_left = 0.0
	_invincible_time_left = 0.0
	_infinite_ammo_time_left = 0.0
	_rapid_fire_time_left = 0.0
	_crown_aura_time_left = 0.0
	_crown_aura_tick_timer = 0.0
	_life_drain_time_left = 0.0
	_life_drain_tick_timer = 0.0
	_rewind_history.clear()
	_rewind_snapshot_timer = 0.0
	_set_phase_state(false)
	fire_rate = _base_fire_rate

func _update_burst_effects(delta: float) -> void:
	var was_phase_active := _phase_time_left > 0.0
	if _phase_time_left > 0.0:
		_phase_time_left = max(_phase_time_left - delta, 0.0)
	if was_phase_active and _phase_time_left == 0.0:
		_set_phase_state(false)
	if _invincible_time_left > 0.0:
		_invincible_time_left = max(_invincible_time_left - delta, 0.0)
	if _infinite_ammo_time_left > 0.0:
		_infinite_ammo_time_left = max(_infinite_ammo_time_left - delta, 0.0)
		if _infinite_ammo_time_left == 0.0 and magazine_size > 0 and _ammo_in_magazine > magazine_size:
			_ammo_in_magazine = clampi(_ammo_in_magazine, 0, magazine_size)
			emit_ammo_state()
	if _rapid_fire_time_left > 0.0:
		_rapid_fire_time_left = max(_rapid_fire_time_left - delta, 0.0)
		if _rapid_fire_time_left == 0.0:
			fire_rate = _base_fire_rate
	if _crown_aura_time_left > 0.0:
		_crown_aura_time_left = max(_crown_aura_time_left - delta, 0.0)
		_crown_aura_tick_timer += delta
		if _crown_aura_tick_timer >= 0.55:
			_crown_aura_tick_timer = 0.0
			_execute_crown_burst_tick()
	if _life_drain_time_left > 0.0:
		_life_drain_time_left = max(_life_drain_time_left - delta, 0.0)
		_life_drain_tick_timer += delta
		if _life_drain_tick_timer >= 0.6:
			_life_drain_tick_timer = 0.0
			_execute_life_drain_tick()
		if _life_drain_time_left == 0.0:
			_life_drain_tick_timer = 0.0

func _record_rewind_snapshot(delta: float) -> void:
	if _rewind_max_duration <= 0.0:
		return
	_rewind_snapshot_timer += delta
	if _rewind_snapshot_timer < _rewind_snapshot_interval:
		return
	_rewind_snapshot_timer = 0.0
	var snapshot: Dictionary = {
		"time": Time.get_ticks_msec() * 0.001,
		"position": global_position,
		"health": _current_health,
		"ammo": _ammo_in_magazine,
		"grenade": grenade_rounds
	}
	_rewind_history.append(snapshot)
	var cutoff := float(snapshot.get("time", 0.0)) - _rewind_max_duration - 0.5
	while _rewind_history.size() > 0:
		var oldest: Dictionary = _rewind_history[0]
		var timestamp := float(oldest.get("time", 0.0))
		if timestamp >= cutoff:
			break
		_rewind_history.pop_front()

func _set_phase_state(enabled: bool) -> void:
	if enabled:
		if collision_layer != 0:
			collision_layer = 0
		if collision_mask != 0:
			collision_mask = 0
		if _animator:
			_animator.modulate = _phase_modulate
	else:
		if collision_layer != _original_collision_layer:
			collision_layer = _original_collision_layer
		if collision_mask != _original_collision_mask:
			collision_mask = _original_collision_mask
		if _animator:
			_animator.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _apply_stun_to_enemies(duration: float, radius: float = -1.0) -> void:
	if not get_tree():
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var radius_sq := -1.0
	if radius > 0.0:
		radius_sq = radius * radius
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		if not enemy.has_method("apply_stun"):
			continue
		if radius_sq > 0.0:
			var dist_sq := (enemy as Node2D).global_position.distance_squared_to(global_position)
			if dist_sq > radius_sq:
				continue
		enemy.apply_stun(duration)

func _rewind_player_state(duration: float) -> void:
	if duration <= 0.0:
		duration = 0.1
	if _rewind_history.is_empty():
		_ammo_in_magazine = magazine_size
		grenade_rounds = _max_grenade_rounds
		emit_ammo_state()
		restore_health(_max_health)
		return
	var now := Time.get_ticks_msec() * 0.001
	var target_time := now - duration
	var selected: Dictionary = _rewind_history[-1]
	for i in range(_rewind_history.size() - 1, -1, -1):
		var snapshot_at_index: Dictionary = _rewind_history[i]
		selected = snapshot_at_index
		var snap_time := float(snapshot_at_index.get("time", now))
		if snap_time <= target_time:
			break
	var previous_health := _current_health
	global_position = selected.get("position", global_position)
	velocity = Vector2.ZERO
	_current_health = clampi(int(selected.get("health", _max_health)), 0, _max_health)
	_is_dead = _current_health <= 0
	var health_delta := _current_health - previous_health
	emit_signal("health_changed", _current_health, _max_health, health_delta)
	var prior_ammo := _ammo_in_magazine
	_ammo_in_magazine = magazine_size
	grenade_rounds = _max_grenade_rounds
	var magazine_changed := magazine_size > 0 and _ammo_in_magazine != prior_ammo
	var special_changed := grenade_rounds != _max_grenade_rounds
	if magazine_changed or special_changed:
		emit_ammo_state()
	restore_health(_max_health - _current_health)
	_invincible_time_left = max(_invincible_time_left, 1.2)
	_rewind_history.clear()
	_rewind_snapshot_timer = 0.0

func _spawn_support_burst_flash(color: Color, radius: float = 220.0, duration: float = 0.45) -> void:
	if not get_parent():
		return
	var effect := ExplosionEffectScript.new()
	effect.radius = max(80.0, radius)
	effect.duration = max(0.1, duration)
	effect.base_color = Color(color.r, color.g, color.b, clampf(color.a, 0.0, 1.0))
	effect.glow_color = Color(color.r * 0.9 + 0.05, color.g * 0.9 + 0.05, color.b, clampf(color.a * 0.6 + 0.1, 0.0, 1.0))
	effect.core_color = Color(1.0, 0.98, 0.92, 0.9)
	effect.shockwave_color = Color(color.r * 0.8 + 0.1, color.g * 0.8 + 0.1, color.b * 0.9, clampf(color.a * 0.7 + 0.1, 0.0, 1.0))
	get_parent().add_child(effect)
	effect.global_position = global_position

func _activate_cecil_burst() -> void:
	_apply_stun_to_enemies(3.0, 900.0)
	_spawn_support_burst_flash(Color(0.55, 0.82, 1.0, 0.85), 260.0, 0.5)

func _activate_commander_burst() -> void:
	_apply_stun_to_enemies(3.5, 920.0)
	_spawn_support_burst_flash(Color(0.86, 0.68, 0.32, 0.9), 280.0, 0.55)

func _activate_wells_burst() -> void:
	_rewind_player_state(10.0)
	_spawn_support_burst_flash(Color(0.95, 0.74, 0.45, 0.85), 240.0, 0.55)

func _activate_trony_burst() -> void:
	var duration: float = float(special_attack_data.get("burst_duration", 5.0))
	_phase_time_left = max(_phase_time_left, duration)
	_set_phase_state(true)
	_invincible_time_left = max(_invincible_time_left, duration)
	_spawn_support_burst_flash(Color(0.58, 0.86, 1.0, 0.7), 260.0, 0.5)

func _activate_kilo_burst() -> void:
	var duration: float = float(special_attack_data.get("burst_duration", 5.5))
	_infinite_ammo_time_left = max(_infinite_ammo_time_left, duration)
	_rapid_fire_time_left = max(_rapid_fire_time_left, duration)
	_invincible_time_left = max(_invincible_time_left, duration)
	fire_rate = max(0.04, _base_fire_rate * float(special_attack_data.get("burst_fire_rate_multiplier", 0.35)))
	_ammo_in_magazine = magazine_size
	grenade_rounds = _max_grenade_rounds
	emit_ammo_state()
	_spawn_support_burst_flash(Color(1.0, 0.76, 0.32, 0.85), 280.0, 0.6)

func _activate_rapunzel_burst() -> void:
	_apply_stun_to_enemies(2.2, 920.0)
	var missing := _max_health - _current_health
	if missing > 0:
		restore_health(missing)
	_spawn_support_burst_flash(Color(1.0, 0.94, 0.72, 0.92), 320.0, 0.65)

func _activate_crown_burst() -> void:
	_crown_aura_time_left = max(_crown_aura_time_left, 4.5)
	_crown_aura_tick_timer = 0.0
	_execute_crown_burst_tick()
	_spawn_support_burst_flash(Color(0.78, 0.52, 1.0, 0.85), 300.0, 0.6)

func _activate_sin_burst() -> void:
	_life_drain_time_left = max(_life_drain_time_left, 5.0)
	_life_drain_tick_timer = 0.0
	_execute_life_drain_tick()
	_spawn_support_burst_flash(Color(0.9, 0.24, 0.38, 0.78), 260.0, 0.55)

func _execute_crown_burst_tick() -> void:
	var damage: int = _calculate_burst_damage(1.6)
	_apply_burst_damage_area(global_position, 300.0, damage)
	if get_parent():
		var effect := ExplosionEffectScript.new()
		effect.radius = 300.0
		effect.duration = 0.45
		effect.base_color = Color(0.78, 0.52, 1.0, 0.65)
		effect.glow_color = Color(0.66, 0.42, 0.95, 0.5)
		effect.core_color = Color(1.0, 0.95, 1.0, 0.85)
		get_parent().add_child(effect)
		effect.global_position = global_position

func _execute_life_drain_tick() -> void:
	if not get_tree():
		return
	var radius: float = float(special_attack_data.get("burst_radius", 340.0))
	var damage: int = max(1, int(round(_calculate_burst_damage(0.8))))
	var healed := 0
	var enemies := get_tree().get_nodes_in_group("enemies")
	var radius_sq := radius * radius
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		var dist_sq := enemy_node.global_position.distance_squared_to(global_position)
		if dist_sq > radius_sq:
			continue
		if enemy_node.has_method("apply_damage"):
			var dealt := int(enemy_node.apply_damage(damage))
			if dealt > 0:
				healed += dealt
				register_burst_hit(enemy_node)
	if healed > 0:
		restore_health(healed)



func get_current_health() -> int:
	return _current_health

func get_max_health() -> int:
	return _max_health

func get_burst_charge() -> float:
	return _burst_charge_value

func get_burst_charge_max() -> float:
	return _burst_charge_max

func set_max_health(value: int, refill: bool = false) -> void:
	var new_max: int = maxi(1, value)
	var previous := _current_health
	_max_health = new_max
	if refill or _current_health > _max_health:
		_current_health = _max_health
	else:
		_current_health = clampi(_current_health, 0, _max_health)
	_is_dead = _current_health <= 0
	var delta := _current_health - previous
	emit_signal("health_changed", _current_health, _max_health, delta)

func apply_damage(amount: int) -> int:
	var damage: int = maxi(0, amount)
	if damage <= 0 or _is_dead:
		return 0
	if _invincible_time_left > 0.0 or _phase_time_left > 0.0:
		return 0
	var previous := _current_health
	_current_health = maxi(0, _current_health - damage)
	var delta := _current_health - previous
	if delta == 0:
		return 0
	_is_dead = _current_health <= 0
	emit_signal("health_changed", _current_health, _max_health, delta)
	if _is_dead:
		emit_signal("player_died")
	return -delta

func restore_health(amount: int) -> int:
	var heal: int = maxi(0, amount)
	if heal <= 0 or _current_health >= _max_health:
		return 0
	var previous := _current_health
	_current_health = mini(_max_health, _current_health + heal)
	var delta := _current_health - previous
	if delta == 0:
		return 0
	_is_dead = false
	emit_signal("health_changed", _current_health, _max_health, delta)
	return delta

func _move_property_if_present(data, property_name: String, assigner: Callable) -> void:
	if data.has_method("get"):
		var value = data.get(property_name)
		if value != null:
			assigner.call(value)

func _apply_projectile_profile(projectile: Node) -> void:
	if projectile is BasicProjectileScript:
		projectile.speed = _projectile_speed
		projectile.lifetime = _projectile_lifetime
		projectile.damage = _projectile_damage
		projectile.radius = _projectile_radius
		projectile.color = _projectile_color
		projectile.penetration = max(1, _projectile_penetration)
		projectile.max_range = _projectile_range
		projectile.shape = _projectile_shape
		if projectile.has_method("set_owner_reference"):
			projectile.set_owner_reference(self)
	elif projectile.has_method("set"):
		projectile.set("speed", _projectile_speed)
		projectile.set("lifetime", _projectile_lifetime)
		projectile.set("damage", _projectile_damage)
		projectile.set("radius", _projectile_radius)
		projectile.set("color", _projectile_color)
		projectile.set("penetration", max(1, _projectile_penetration))
		projectile.set("max_range", _projectile_range)
		projectile.set("shape", _projectile_shape)

func _resolve_achievement_service() -> AchievementService:
	if not get_tree():
		return null
	var root := get_tree().root
	var candidate := root.find_child("AchievementService", true, false)
	if candidate and candidate is AchievementService:
		return candidate
	return null

func _record_stat(stat_key: String, amount: int) -> void:
	if not _achievement_service:
		_achievement_service = _resolve_achievement_service()
	if _achievement_service:
		_achievement_service.record_stat(stat_key, amount)

func _update_animation_state(move_velocity: Vector2, aim_vector: Vector2) -> void:
	if _animator:
		_animator.update_state(move_velocity, aim_vector)

func _configure_animator_from_profile(profile_data) -> void:
	if not _animator:
		return
	if profile_data is CharacterDataScript:
		_animator.configure_from_character(profile_data)
		return
	if not profile_data.has_method("get"):
		_animator.clear()
		return
	var sprite_sheet_variant: Variant = profile_data.get("sprite_sheet")
	var sprite_sheet: Texture2D = sprite_sheet_variant if sprite_sheet_variant is Texture2D else null
	var columns_value_variant: Variant = profile_data.get("sprite_sheet_columns")
	var rows_value_variant: Variant = profile_data.get("sprite_sheet_rows")
	var fps_value_variant: Variant = profile_data.get("sprite_animation_fps")
	var scale_value_variant: Variant = profile_data.get("sprite_scale")
	if sprite_sheet:
		var columns: int = int(columns_value_variant) if columns_value_variant != null else 0
		var rows: int = int(rows_value_variant) if rows_value_variant != null else 0
		var fps: float = float(fps_value_variant) if fps_value_variant != null else 6.0
		var scale_factor: float = CharacterSpriteAnimator.DEFAULT_SCALE
		match typeof(scale_value_variant):
			TYPE_FLOAT, TYPE_INT:
				scale_factor = max(0.0, float(scale_value_variant))
			_:
				pass
		_animator.configure(sprite_sheet, columns, rows, fps, scale_factor)
	else:
		_animator.clear()

func _activate_minigun_boost() -> bool:
	if weapon_type != "Minigun":
		return false
	var duration := float(special_attack_data.get("duration", special_mechanics.get("spin_up_time", 3.0)))
	if duration <= 0.0:
		duration = 3.0
	_minigun_boost_time_left = duration
	var fire_rate_multiplier := float(special_attack_data.get("fire_rate_multiplier", 0.5))
	if fire_rate_multiplier <= 0.0:
		fire_rate_multiplier = 0.5
	var damage_multiplier := float(special_attack_data.get("damage_multiplier", special_mechanics.get("spun_up_damage_multiplier", 1.8)))
	if damage_multiplier <= 0.0:
		damage_multiplier = 1.5
	fire_rate = max(0.01, _base_fire_rate * fire_rate_multiplier)
	_projectile_damage = int(round(_base_projectile_damage * damage_multiplier))
	return true

func _reset_minigun_boost() -> void:
	if weapon_type != "Minigun":
		return
	_minigun_boost_time_left = 0.0
	fire_rate = _base_fire_rate
	_projectile_damage = _base_projectile_damage

func _spawn_v_blast_effect(direction: Vector2, blast_range: float, blast_angle: float, blast_color: Color, origin: Vector2 = global_position) -> void:
	if not get_parent():
		return
	var parent := get_parent()
	var effect_duration: float = max(0.05, float(special_attack_data.get("blast_duration", 0.25)))
	var offsets := PackedFloat32Array([-blast_angle * 0.5, blast_angle * 0.5])
	for offset_degrees in offsets:
		var effect := ExplosionEffectScript.new()
		effect.radius = blast_range
		effect.base_color = blast_color
		effect.duration = effect_duration
		effect.ring_thickness = max(2.0, blast_range * 0.12)
		var offset_direction := direction.rotated(deg_to_rad(offset_degrees)).normalized() * (blast_range * 0.6)
		parent.add_child(effect)
		effect.global_position = origin + offset_direction

func _on_shotgun_special_hit(target: Node, projectile: Node, payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var direction: Vector2 = payload.get("direction", _get_aim_direction())
	if direction.length() == 0.0:
		direction = _last_move_direction
	direction = direction.normalized()
	var blast_range := float(payload.get("blast_range", 150.0))
	var blast_angle := float(payload.get("blast_angle", 45.0))
	var color := _color_from_variant(payload.get("color", Color(1.0, 0.4, 0.2, 1.0)), Color(1.0, 0.4, 0.2, 1.0))
	var impact_position := global_position
	if target is Node2D:
		impact_position = (target as Node2D).global_position
	elif projectile is Node2D:
		impact_position = (projectile as Node2D).global_position
	_spawn_v_blast_effect(direction, blast_range, blast_angle, color, impact_position)
	var blast_damage := int(payload.get("blast_damage", _projectile_damage))
	if blast_damage > 0:
		_apply_v_blast_damage(impact_position, direction, blast_range, blast_angle, blast_damage)

func _apply_v_blast_damage(origin: Vector2, direction: Vector2, blast_range: float, blast_angle: float, blast_damage: int) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var normalized_direction := direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	var half_angle := deg_to_rad(blast_angle * 0.5)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		if not enemy.has_method("apply_damage"):
			continue
		var enemy_node := enemy as Node2D
		var to_enemy := enemy_node.global_position - origin
		var distance := to_enemy.length()
		if distance <= 0.0 or distance > blast_range:
			continue
		var angle_offset := normalized_direction.angle_to(to_enemy.normalized())
		if abs(angle_offset) > half_angle:
			continue
		enemy_node.apply_damage(blast_damage)
		register_burst_hit(enemy_node)

func _color_from_variant(value: Variant, fallback: Color) -> Color:
	match typeof(value):
		TYPE_COLOR:
			return value
		TYPE_ARRAY:
			return _color_array_to_color(value as Array, fallback)
		TYPE_PACKED_FLOAT32_ARRAY:
			return _color_array_to_color(Array(value), fallback)
		TYPE_PACKED_INT32_ARRAY:
			return _color_array_to_color(Array(value), fallback)
		TYPE_PACKED_BYTE_ARRAY:
			return _color_array_to_color(Array(value), fallback)
		TYPE_DICTIONARY:
			return _color_dict_to_color(value as Dictionary, fallback)
		TYPE_STRING:
			return Color.from_string(value, fallback)
		_:
			pass
	return fallback

func _color_array_to_color(values: Array, fallback: Color) -> Color:
	if values.is_empty():
		return fallback
	var r := _color_component_to_float(values[0], fallback.r)
	var g := fallback.g
	var b := fallback.b
	var a := fallback.a
	if values.size() > 1:
		g = _color_component_to_float(values[1], fallback.g)
	if values.size() > 2:
		b = _color_component_to_float(values[2], fallback.b)
	if values.size() > 3:
		a = _color_component_to_float(values[3], fallback.a)
	return Color(r, g, b, a)

func _color_dict_to_color(values: Dictionary, fallback: Color) -> Color:
	var r := _color_component_to_float(values.get("r", fallback.r), fallback.r)
	var g := _color_component_to_float(values.get("g", fallback.g), fallback.g)
	var b := _color_component_to_float(values.get("b", fallback.b), fallback.b)
	var a := _color_component_to_float(values.get("a", fallback.a), fallback.a)
	return Color(r, g, b, a)

func _color_component_to_float(value: Variant, fallback: float) -> float:
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
			var text := str(value).strip_edges()
			if text.is_valid_float():
				var parsed := text.to_float()
				if parsed > 1.0:
					return clampf(parsed / 255.0, 0.0, 1.0)
				return clampf(parsed, 0.0, 1.0)
	return clampf(fallback, 0.0, 1.0)
