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
const SwordSparkleScript := preload("res://src/effects/sword_sparkle.gd")
const SwordSlashScript := preload("res://src/effects/sword_slash.gd")
const SwordBeamScript := preload("res://src/effects/sword_beam.gd")
const SinDebuffEffectScript := preload("res://src/effects/sin_debuff_effect.gd")
const CommanderStunEffectScript := preload("res://src/effects/commander_stun_effect.gd")
const CecilStunEffectScript := preload("res://src/effects/cecil_stun_effect.gd")
const SnowWhiteBurstBeamScript := preload("res://src/effects/snow_white_burst_beam.gd")
const SnowWhiteLingeringEffectScript := preload("res://src/effects/snow_white_lingering_effect.gd")
const ShotgunVBlastEffectScript := preload("res://src/effects/shotgun_v_blast_effect.gd")
const ShotgunTrailEffectScript := preload("res://src/effects/shotgun_trail_effect.gd")
const ShotgunMuzzleFlashScript := preload("res://src/effects/shotgun_muzzle_flash.gd")
const ShotgunShellCasingScript := preload("res://src/effects/shotgun_shell_casing.gd")
const AssaultRifleMuzzleFlashScript := preload("res://src/effects/assault_rifle_muzzle_flash.gd")
const AssaultRifleShellCasingScript := preload("res://src/effects/assault_rifle_shell_casing.gd")
const MinigunLightningArcScript := preload("res://src/effects/minigun_lightning_arc.gd")
const SNIPER_PRIMARY_SPEED_CAP := 3600.0
const SNIPER_GLOW_COLOR := Color(0.82, 0.98, 1.0, 1.0)
const SNIPER_PRIMARY_GLOW_ENERGY := 4.1
const SNIPER_SPECIAL_GLOW_ENERGY := 4.1
const SNIPER_GLOW_SCALE := 2.1
const SNIPER_GLOW_HEIGHT := -12.0
const SNIPER_PRIMARY_BEAM_COLOR := Color(0.94, 0.99, 1.0, 1.0)
const SIN_DOT_DAMAGE := 8
const SIN_DOT_INTERVAL := 0.5
const SIN_HEAL_INTERVAL := 1.0
const SIN_HEAL_FRACTION := 0.05
const KILO_BURST_DURATION := 5.0
const KILO_BURST_COOLDOWN_MULTIPLIER := 0.33
const CROWN_BURST_DAMAGE := 150
const CROWN_BURST_RADIUS := 500.0
const CROWN_BURST_MIN_MULTIPLIER := 0.7
const TRONY_STEALTH_DURATION := 6.0
const TRONY_STEALTH_PUSH_RADIUS := 200.0
const TRONY_STEALTH_PUSH_FORCE := 320.0
const MARIAN_BURST_DURATION := 5.0
const MARIAN_BURST_EXPLOSION_RADIUS := 120.0
const MARIAN_BURST_EXPLOSION_DAMAGE_MULTIPLIER := 1.5
const MARIAN_BURST_COLOR := Color(0.78, 0.45, 1.0, 0.92)
const MARIAN_BURST_GLOW_COLOR := Color(0.95, 0.7, 1.0, 0.85)
const MARIAN_BURST_GLOW_ENERGY := 3.1
const MARIAN_BURST_GLOW_SCALE := 1.6
const MARIAN_BURST_GLOW_HEIGHT := -6.0
const SCARLET_TELEPORT_EFFECT_COLOR := Color(1.0, 0.78, 1.0, 0.85)
const MINIGUN_SPECIAL_CHARGE_MAX := 100.0
const MINIGUN_SPIN_RESET_DELAY := 1.5
const MINIGUN_BEAM_ACTIVATION_THRESHOLD := 0.98
const MINIGUN_LIGHTNING_MAX_RANGE := 1400.0
const MINIGUN_LIGHTNING_MAX_TARGETS := 6
const MINIGUN_LIGHTNING_CHAIN_RADIUS := 420.0
const MINIGUN_LIGHTNING_ARC_WIDTH := 12.0
const MINIGUN_LIGHTNING_FIRE_COST := 12.0
const MINIGUN_LIGHTNING_RECHARGE_RATE := 18.0
const MINIGUN_LIGHTNING_FIRE_COOLDOWN := 0.18
const MINIGUN_LIGHTNING_DAMAGE_BASE := 14
const MINIGUN_LIGHTNING_DAMAGE_MULTIPLIER := 2.0
const MINIGUN_LIGHTNING_DAMAGE_FALLOFF := 0.75
var move_speed := 400.0
var dash_speed := 900.0
var dash_duration := 0.2
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
var _smg_special_sound_played_this_frame := false
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
var _minigun_spin_progress := 0.0
var _minigun_spin_up_time := 2.2
var _minigun_spin_grace_time := 1.0
var _minigun_spin_grace_left := 0.0
var _minigun_initial_fire_rate := 0.0
var _minigun_full_damage_multiplier := 1.0
var _minigun_spin_decay_multiplier := 3.0
var _weapon_rng := RandomNumberGenerator.new()
var _shotgun_special_color_cache: Color = Color(1.0, 0.28, 0.08, 1.0)
var _minigun_special_charge: float = MINIGUN_SPECIAL_CHARGE_MAX
var _minigun_idle_time: float = 0.0
var _minigun_cached_forward: Vector2 = Vector2.RIGHT

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
var _sin_burst_targets: Array = []
var _sin_burst_end_time: float = 0.0
var _original_collision_layer: int = 0
var _original_collision_mask: int = 0
var _phase_modulate: Color = Color(1.0, 1.0, 1.0, 0.45)
var _kilo_burst_time_left: float = 0.0
var _marian_burst_time_left: float = 0.0
var _trony_stealth_time_left: float = 0.0
var _trony_stealth_active: bool = false
var _burst_gain_multiplier: float = 1.0
var _scarlet_teleport_ready: bool = false
var _scarlet_teleport_target: Vector2 = Vector2.ZERO
var _world_bounds: Rect2 = Rect2()

var _dash_time_left := 0.0
var _dash_direction := Vector2.ZERO
var _last_move_direction := Vector2.DOWN
var _fire_cooldown_left := 0.0
var _achievement_service: AchievementService = null
var _audio_director: AudioDirector = null
@onready var _animator: CharacterSpriteAnimator = $CharacterSpriteAnimator
@onready var _ground_accent: Node2D = $GroundAccent if has_node("GroundAccent") else null
@onready var _underlight: PointLight2D = $GroundAccent/Underlight if has_node("GroundAccent/Underlight") else null
@onready var _aura_light: PointLight2D = $AuraLight if has_node("AuraLight") else null
@onready var _night_glow: PointLight2D = $GroundAccent/NightGlow if has_node("GroundAccent/NightGlow") else null
@onready var _sprite_glow: Sprite2D = $CharacterSpriteAnimator/SpriteGlow if has_node("CharacterSpriteAnimator/SpriteGlow") else null
@onready var _light_marker: PlayerGroundMarker = $GroundAccent/LightMarker if has_node("GroundAccent/LightMarker") else null
@onready var _shadow_marker: PlayerGroundMarker = $GroundAccent/ShadowMarker if has_node("GroundAccent/ShadowMarker") else null
var _ground_accent_timer: float = 0.0
var _player_glow_texture: Texture2D = null

func _ready() -> void:
	_weapon_rng.randomize()
	_achievement_service = _resolve_achievement_service()
	_audio_director = _resolve_audio_director()
	if _animator:
		_animator.clear()
	var glow_texture: Texture2D = _ensure_player_glow_texture(_night_glow)
	_configure_sprite_glow(glow_texture)
	_original_collision_layer = collision_layer
	_original_collision_mask = collision_mask
	_reset_burst_effect_states()
	_initialize_health()
	_initialize_burst()
	emit_ammo_state()
	apply_ground_accent_profile(false, 1.0)
	_update_ground_accent_offset(true)

func apply_ground_accent_profile(is_night: bool, ambient_strength: float = 1.0) -> void:
	_configure_ground_accent_for_time(is_night, ambient_strength)
	_update_ground_accent_offset(true)

func _configure_ground_accent_for_time(is_night: bool, ambient_strength: float) -> void:
	var clamped_strength := clampf(ambient_strength, 0.25, 1.6)
	if _underlight:
		_underlight.enabled = true
		_underlight.visible = true
		if is_night:
			_underlight.color = Color(0.86, 0.96, 1.0, 1.0)
			var night_energy := clampf(0.32 + 0.34 * clamped_strength, 0.22, 0.82)
			_underlight.energy = night_energy
			_underlight.texture_scale = clampf(1.2 + 0.22 * clamped_strength, 1.05, 2.1)
		else:
			_underlight.color = Color(0.98, 0.94, 0.78, 0.88)
			var day_energy := clampf(0.08 + 0.1 * (1.75 - clamped_strength), 0.06, 0.24)
			_underlight.energy = day_energy
			_underlight.texture_scale = clampf(1.05 + 0.06 * (1.6 - clamped_strength), 0.9, 1.35)
	if _aura_light:
		_aura_light.enabled = true
		_aura_light.visible = true
		_aura_light.shadow_enabled = false
		if is_night:
			var aura_energy := clampf(0.52 + 0.35 * clamped_strength, 0.45, 1.05)
			_aura_light.energy = aura_energy
			_aura_light.texture_scale = clampf(4.2 + 1.6 * clamped_strength, 3.4, 6.2)
			_aura_light.color = Color(0.99, 0.8, 0.56, 1.0)
		else:
			var aura_day_energy := clampf(0.16 + 0.12 * clamped_strength, 0.1, 0.32)
			_aura_light.energy = aura_day_energy
			_aura_light.texture_scale = clampf(3.3 + 0.56 * clamped_strength, 3.0, 4.8)
			_aura_light.color = Color(0.95, 0.9, 0.74, 0.95)
	else:
		# Fallback: brighten underlight when aura node missing.
		if _underlight:
			_underlight.energy = clampf(_underlight.energy * 1.35, 0.15, 1.0)
			_underlight.texture_scale = clampf(_underlight.texture_scale * 1.12, 0.9, 2.4)
	if _light_marker:
		_light_marker.visible = is_night
		if is_night:
			var night_alpha := clampf(0.22 + 0.16 * clamped_strength, 0.12, 0.42)
			_light_marker.set_marker_color(Color(0.84, 0.98, 1.0, night_alpha))
			_light_marker.set_scale_multiplier(Vector2(1.0 + 0.08 * clamped_strength, 1.0))
	else:
		_light_marker.visible = false
	if _shadow_marker:
		_shadow_marker.visible = not is_night
		if not is_night:
			var shadow_alpha := clampf(0.18 + 0.22 * (1.35 - clamped_strength), 0.12, 0.46)
			_shadow_marker.set_marker_color(Color(0.06, 0.08, 0.12, shadow_alpha))
			_shadow_marker.set_scale_multiplier(Vector2(1.0 + 0.14 * (1.3 - clamped_strength), 1.0))
	else:
		_shadow_marker.visible = false
	if _night_glow:
		_night_glow.top_level = false
		_night_glow.position = Vector2.ZERO
		_night_glow.enabled = true
		_night_glow.visible = true
		var core_color := Color(1.0, 0.74, 0.48, 1.0)
		if is_night:
			_night_glow.color = core_color.lerp(Color(1.0, 0.74, 0.46, 1.0), 0.35)
			_night_glow.energy = clampf(0.22 + 0.12 * clamped_strength, 0.2, 0.42)
			_night_glow.texture_scale = clampf(1.9 + 0.45 * clamped_strength, 1.7, 2.9)
			_night_glow.height = -28.0
		else:
			_night_glow.color = Color(0.98, 0.9, 0.78, 0.95)
			_night_glow.energy = clampf(0.08 + 0.04 * (1.6 - clamped_strength), 0.06, 0.12)
			_night_glow.texture_scale = clampf(1.1 + 0.22 * (1.6 - clamped_strength), 1.0, 1.8)
			_night_glow.height = -24.0
		_night_glow.shadow_enabled = false
		if _night_glow.texture == null:
			_ensure_player_glow_texture(_night_glow)
	if _sprite_glow:
		_sprite_glow.visible = true
		if is_night:
			_sprite_glow.modulate = Color(1.0, 0.62, 0.34, 0.26)
			_sprite_glow.scale = Vector2(0.32, 0.28)
		else:
			_sprite_glow.modulate = Color(1.0, 0.8, 0.54, 0.12)
			_sprite_glow.scale = Vector2(0.26, 0.22)


func _create_player_glow_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 0.9, 0.62, 0.85),
		Color(0.98, 0.58, 0.28, 0.32),
		Color(0.2, 0.12, 0.08, 0.08),
		Color(0.0, 0.0, 0.0, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.65, 1.0])
	var texture := GradientTexture2D.new()
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 512
	texture.height = 512
	texture.use_hdr = true
	texture.gradient = gradient
	return texture


func _ensure_player_glow_texture(target_light: PointLight2D) -> Texture2D:
	if _player_glow_texture == null:
		_player_glow_texture = _create_player_glow_texture()
	if target_light and target_light.texture == null:
		target_light.texture = _player_glow_texture
	return _player_glow_texture


func _configure_sprite_glow(glow_texture: Texture2D) -> void:
	if _sprite_glow == null:
		return
	_sprite_glow.centered = true
	_sprite_glow.position = Vector2.ZERO
	_sprite_glow.z_index = -5
	_sprite_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if glow_texture == null:
		glow_texture = _player_glow_texture if _player_glow_texture != null else _create_player_glow_texture()
	_sprite_glow.texture = glow_texture
	var sprite_material := _sprite_glow.material
	if not (sprite_material is CanvasItemMaterial):
		sprite_material = CanvasItemMaterial.new()
		_sprite_glow.material = sprite_material
	(sprite_material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sprite_glow.modulate = Color(1.0, 0.75, 0.42, 0.18)
	_sprite_glow.scale = Vector2(0.28, 0.24)

func _update_ground_accent_offset(force: bool = false) -> void:
	if _ground_accent == null or _animator == null:
		return
	if _animator.sprite_frames == null:
		return
	var animation_name := _animator.animation
	if animation_name == "" and not _animator.sprite_frames.get_animation_names().is_empty():
		animation_name = _animator.sprite_frames.get_animation_names()[0]
	if animation_name == "":
		return
	var frame_index := clampi(_animator.frame, 0, _animator.sprite_frames.get_frame_count(animation_name) - 1)
	var frame_texture := _animator.sprite_frames.get_frame_texture(animation_name, frame_index)
	if frame_texture == null:
		return
	var texture_size: Vector2 = frame_texture.get_size()
	var scaled_height: float = texture_size.y * abs(_animator.scale.y)
	var foot_offset: float = scaled_height * 0.5 - 4.0
	var current := _ground_accent.position
	if force or abs(current.y - foot_offset) > 0.5:
		_ground_accent.position = Vector2(current.x, foot_offset)

func _physics_process(delta: float) -> void:
	_smg_special_sound_played_this_frame = false
	_update_dash_timers(delta)
	_update_fire_cooldown(delta)
	_update_reload_timer(delta)
	_update_grenade_reload(delta)
	_update_secondary_cooldown(delta)
	_update_minigun_boost(delta)
	_update_burst_hit_history(delta)
	_update_burst_effects(delta)
	_ground_accent_timer += delta
	if _ground_accent_timer >= 0.2:
		_update_ground_accent_offset()
		_ground_accent_timer = 0.0
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
	var holding_fire := wants_fire
	if _is_reloading:
		holding_fire = false
	_update_minigun_spin_state(delta, holding_fire)
	var wants_special := false
	if weapon_type == "Sword" or weapon_type == "Shotgun":
		wants_special = Input.is_action_just_pressed("fire_secondary")
	else:
		wants_special = Input.is_action_pressed("fire_secondary")
	if weapon_type == "Sniper":
		wants_special = Input.is_action_just_pressed("fire_secondary")
	if weapon_type == "Minigun":
		_update_minigun_special_state(delta, wants_special)
		if wants_special:
			_attempt_secondary_fire()
	elif wants_special:
		_attempt_secondary_fire()
	else:
		_reset_continuous_special_state()
	if Input.is_action_just_pressed("burst"):
		_attempt_burst_activation()
	velocity = _calculate_velocity(input_vector)
	_update_animation_state(velocity, _get_raw_aim_vector())
	move_and_slide()
	_constrain_to_world_bounds()
	if _scarlet_teleport_ready and _is_active_character("scarlet"):
		_perform_scarlet_teleport()
	_record_rewind_snapshot(delta)


func _perform_scarlet_teleport() -> void:
	var destination := _scarlet_teleport_target
	_scarlet_teleport_ready = false
	_scarlet_teleport_target = Vector2.ZERO
	if destination == Vector2.ZERO:
		return
	global_position = destination
	velocity = Vector2.ZERO
	if not get_parent():
		return
	var effect := ExplosionEffectScript.new()
	effect.radius = 170.0
	effect.duration = 0.35
	effect.base_color = SCARLET_TELEPORT_EFFECT_COLOR
	effect.glow_color = Color(SCARLET_TELEPORT_EFFECT_COLOR.r * 0.9 + 0.1, SCARLET_TELEPORT_EFFECT_COLOR.g, SCARLET_TELEPORT_EFFECT_COLOR.b, 0.7)
	effect.core_color = Color(1.0, 0.94, 1.0, 0.9)
	effect.shockwave_color = Color(1.0, 0.7, 1.0, 0.85)
	get_parent().add_child(effect)
	effect.global_position = destination


func set_world_bounds(bounds: Rect2) -> void:
	_world_bounds = bounds
	_constrain_to_world_bounds()


func get_world_bounds() -> Rect2:
	return _world_bounds


func _constrain_to_world_bounds() -> void:
	if _world_bounds.size == Vector2.ZERO:
		return
	var min_corner := _world_bounds.position
	var max_corner := _world_bounds.position + _world_bounds.size
	var original_position := global_position
	var clamped_position := Vector2(
		clampf(original_position.x, min_corner.x, max_corner.x),
		clampf(original_position.y, min_corner.y, max_corner.y)
	)
	if clamped_position.is_equal_approx(original_position):
		return
	global_position = clamped_position
	var changed_x := not is_equal_approx(clamped_position.x, original_position.x)
	var changed_y := not is_equal_approx(clamped_position.y, original_position.y)
	if changed_x:
		velocity.x = 0.0
	if changed_y:
		velocity.y = 0.0

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
	var dash_vector := input_vector
	if dash_vector == Vector2.ZERO:
		dash_vector = _last_move_direction
	if dash_vector == Vector2.ZERO:
		return
	_dash_direction = dash_vector.normalized()
	_dash_time_left = dash_duration
	_record_stat("dashes_performed", 1)

func _calculate_velocity(input_vector: Vector2) -> Vector2:
	if _dash_time_left > 0.0 and _dash_direction != Vector2.ZERO:
		return _dash_direction * dash_speed
	return input_vector * move_speed

func _attempt_primary_fire() -> void:
	if _fire_cooldown_left > 0.0:
		return
	if _is_reloading and weapon_type != "Sniper":
		return
	var direction := _get_aim_direction()
	if direction == Vector2.ZERO:
		direction = _last_move_direction
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var primary_requires_ammo := not (weapon_type == "Shotgun" or weapon_type == "Sniper" or weapon_type == "Rocket Launcher" or weapon_type == "Sword")
	if primary_requires_ammo and magazine_size > 0 and _ammo_in_magazine <= 0:
		_begin_reload()
		return
	var fired := false
	if weapon_type == "Rocket Launcher":
		fired = _fire_rocket_primary(direction)
	elif weapon_type == "Sword":
		fired = _fire_sword_primary(direction)
	else:
		var projectile := BasicProjectileScene.instantiate()
		var overrides: Dictionary = {}
		if weapon_type == "Minigun":
			overrides["per_pellet_callback"] = Callable(self, "_on_minigun_projectile_spawned")
		elif weapon_type == "Assault Rifle":
			overrides["color_override"] = Callable(self, "_assault_rifle_primary_color_override")
			overrides["per_pellet_callback"] = Callable(self, "_on_assault_rifle_projectile_spawned")
		elif weapon_type == "Sniper":
			overrides["per_pellet_callback"] = Callable(self, "_configure_sniper_primary_projectile")
		elif weapon_type == "SMG":
			overrides["color_override"] = Callable(self, "_smg_primary_color_override")
			overrides["per_pellet_callback"] = Callable(self, "_on_smg_primary_projectile_spawned")
		elif weapon_type == "Shotgun":
			overrides["color_override"] = Callable(self, "_shotgun_primary_color_override")
			overrides["radius_multiplier"] = Callable(self, "_shotgun_primary_radius_multiplier")
			overrides["per_pellet_callback"] = Callable(self, "_on_shotgun_primary_projectile_spawned")
		_fire_projectile_salvo(projectile, direction, Callable(), {}, overrides)
		fired = true
	if not fired:
		return
	_play_weapon_fire_audio(false)
	if weapon_type != "Sniper" and weapon_type != "Rocket Launcher" and weapon_type != "Sword":
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
		"Sword":
			fired = _fire_sword_special(direction)
		"Minigun":
			fired = _fire_minigun_special(direction)
		_:
			fired = false
	if not fired:
		return
	_play_weapon_fire_audio(true)
	var base_cooldown := _resolve_secondary_cooldown()
	var gating_cooldown := base_cooldown if base_cooldown > 0.0 else fire_rate
	_secondary_cooldown_left = gating_cooldown
	var allows_continuous := base_cooldown <= 0.0 and weapon_type != "Sword"
	if weapon_type == "Sniper" or weapon_type == "SMG":
		allows_continuous = false
	if weapon_type == "Minigun":
		allows_continuous = false
	_continuous_special_active = allows_continuous
	_record_stat("special_attacks_used", 1)

func _reset_continuous_special_state() -> void:
	if not _continuous_special_active:
		return
	_continuous_special_active = false
	if weapon_type == "Minigun":
		_reset_minigun_boost()

func _resolve_secondary_cooldown() -> float:
	if weapon_type == "Minigun":
		return max(0.0, float(_resolve_minigun_lightning_setting("lightning_fire_cooldown", MINIGUN_LIGHTNING_FIRE_COOLDOWN)))
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
	var explode_on_target := bool(grenade_config.get("explode_at_target", true))
	grenade.explode_at_target = explode_on_target
	grenade.target_position = get_global_mouse_position() if explode_on_target else Vector2.ZERO
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
	var requires_ammo := magazine_size > 0 and _infinite_ammo_time_left <= 0.0
	if requires_ammo and _ammo_in_magazine <= 0:
		_begin_reload()
		return false
	var requested_shots := 2
	if requires_ammo:
		requested_shots = clamp(_ammo_in_magazine, 1, 2)
	var shots_fired := _fire_smg_dual_stream(direction, requested_shots)
	if shots_fired <= 0:
		return false
	for _i in range(shots_fired):
		_consume_ammo()
	return true

func _fire_smg_dual_stream(direction: Vector2, shots_to_fire: int = 2) -> int:
	var range_multiplier := float(special_attack_data.get("range_multiplier", 0.5))
	var bounce_range_multiplier := float(special_attack_data.get("bounce_range_multiplier", 0.5))
	var max_bounce := int(special_attack_data.get("max_bounces", 1))
	var enemy_focus := bool(special_attack_data.get("enemy_targeting", true))
	var reduced_range := _projectile_range * range_multiplier
	var bounce_range := reduced_range * bounce_range_multiplier
	var special_color: Color = _color_from_variant(special_attack_data.get("color", _projectile_color), Color(0.0, 1.0, 1.0, 1.0))
	var offset_signs: Array = []
	if shots_to_fire >= 2:
		offset_signs = [-1, 1]
	elif shots_to_fire == 1:
		offset_signs = [0]
	if offset_signs.is_empty():
		return 0
	var shots_spawned := 0
	for offset_sign in offset_signs:
		if shots_spawned >= shots_to_fire:
			break
		var projectile := BasicProjectileScene.instantiate()
		_apply_projectile_profile(projectile)
		projectile.max_range = reduced_range
		if "projectile_archetype" in projectile:
			projectile.projectile_archetype = "smg_special"
		if projectile is BasicProjectileScript:
			var basic := projectile as BasicProjectileScript
			basic.shape = "pellet"
			basic.radius = maxf(basic.radius, maxf(_projectile_radius * 1.275, 8.3))
			basic.trail_enabled = false
			var dual_glow_color := _lighten_color(basic.color, 0.12).lerp(Color(1.0, 0.56, 0.26, 0.28), 0.26)
			var dual_glow_scale := clampf(basic.radius * 0.22, 1.0, 2.0)
			basic.configure_glow(true, dual_glow_color, 0.24, dual_glow_scale, -0.1)
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
		shots_spawned += 1
	return shots_spawned

func _fire_sniper_special(direction: Vector2) -> bool:
	if magazine_size > 0 and _infinite_ammo_time_left <= 0.0 and _ammo_in_magazine <= 0:
		_begin_reload()
		return false
	var projectile := BasicProjectileScene.instantiate()
	_apply_projectile_profile(projectile)
	var default_special_color := Color(0.6, 0.82, 1.0, 1.0)
	projectile.color = _color_from_variant(special_attack_data.get("color", default_special_color), default_special_color)
	var damage_multiplier := float(special_attack_data.get("damage_multiplier", 1.5))
	projectile.damage = int(round(float(_projectile_damage) * damage_multiplier))
	projectile.radius = _projectile_radius * float(special_attack_data.get("size_multiplier", 1.5))
	projectile.shape = "laser"
	projectile.trail_enabled = true
	projectile.trail_interval = 18.0
	projectile.trail_damage = int(special_attack_data.get("trail_damage", 12))
	var requested_trail_duration: float = float(special_attack_data.get("trail_duration", 4.0))
	projectile.trail_duration = max(4.0, requested_trail_duration)
	var default_trail_color := Color(1.0, 0.62, 0.24, 0.92)
	projectile.trail_color = _color_from_variant(special_attack_data.get("trail_color", default_trail_color), default_trail_color)
	if projectile is BasicProjectileScript:
		var basic := projectile as BasicProjectileScript
		basic.special_attack = true
		basic.penetration = 9999
		basic.max_range = max(basic.max_range, _projectile_range * 1.65)
		basic.lifetime = maxf(basic.lifetime, 1.35)
		basic.speed = basic.speed * (4.0 / 3.0)
		var thickness_multiplier := float(special_attack_data.get("thickness_multiplier", 2.0))
		basic.radius = max(basic.radius * thickness_multiplier * 0.6666667, 0.75)
		basic.bounce_enabled = false
		var glow_color := SNIPER_GLOW_COLOR
		var glow_energy := float(special_attack_data.get("glow_energy", SNIPER_SPECIAL_GLOW_ENERGY))
		var glow_scale := float(special_attack_data.get("glow_radius", SNIPER_GLOW_SCALE))
		basic.configure_glow(true, glow_color, glow_energy, glow_scale, SNIPER_GLOW_HEIGHT)
		basic.trail_width_multiplier = 2.0
		basic.trail_color = projectile.trail_color
	if projectile.has_method("set_direction"):
		projectile.set_direction(direction)
	projectile.global_position = get_gun_tip_position(direction)
	if get_parent():
		get_parent().add_child(projectile)
	if magazine_size > 0:
		_consume_ammo()
	return true

func _configure_sniper_primary_projectile(projectile: Node, _direction: Vector2, _pellet_index: int, _pellet_total: int) -> void:
	if not (projectile is BasicProjectileScript):
		return
	var basic := projectile as BasicProjectileScript
	basic.special_attack = false
	basic.speed = minf(basic.speed * 2.0, SNIPER_PRIMARY_SPEED_CAP)
	basic.lifetime = maxf(basic.lifetime * 3.0, 0.01)
	basic.configure_glow(true, SNIPER_GLOW_COLOR, SNIPER_PRIMARY_GLOW_ENERGY, SNIPER_GLOW_SCALE, SNIPER_GLOW_HEIGHT)
	basic.color = SNIPER_PRIMARY_BEAM_COLOR
	basic.radius = max(basic.radius * 0.4, 0.5)
	basic.penetration = 9999
	basic.bounce_enabled = false
	if basic.trail_enabled:
		basic.trail_enabled = false

func _fire_shotgun_special(direction: Vector2) -> bool:
	var projectile := BasicProjectileScene.instantiate()
	var blast_angle: float = float(special_attack_data.get("blast_angle", 45.0))
	var configured_range: float = float(special_attack_data.get("blast_range", 400.0))
	var override_range: float = float(special_attack_data.get("blast_range_override", -1.0))
	var blast_range: float = max(configured_range, 400.0)
	if override_range > 0.0:
		blast_range = override_range
	var origin_offset: float = float(special_attack_data.get("blast_origin_offset", 30.0))
	var damage_multiplier: float = float(special_attack_data.get("damage_multiplier", 0.67))
	var color: Color = _color_from_variant(special_attack_data.get("color", Color(1.0, 0.28, 0.08, 1.0)), Color(1.0, 0.28, 0.08, 1.0))
	_shotgun_special_color_cache = color
	var blast_damage: int = max(1, int(round(float(_projectile_damage) * damage_multiplier)))
	var payload: Dictionary = {
		"blast_range": blast_range,
		"blast_angle": blast_angle,
		"color": color,
		"blast_damage": blast_damage,
		"origin_offset": origin_offset
	}
	var overrides: Dictionary = {
		"special_attack": true,
		"color_override": Callable(self, "_shotgun_special_color_override"),
		"radius_multiplier": 1.5,
		"per_pellet_callback": Callable(self, "_on_shotgun_special_projectile_spawned")
	}
	_fire_projectile_salvo(projectile, direction, Callable(self, "_on_shotgun_special_hit"), payload, overrides)
	if magazine_size > 0:
		_consume_ammo(1, true)
	return true

func _fire_rocket_special(direction: Vector2) -> bool:
	if magazine_size > 0 and _infinite_ammo_time_left <= 0.0 and _ammo_in_magazine <= 0:
		_begin_reload()
		return false
	var fired := _launch_rocket(direction, true)
	if not fired:
		return false
	if magazine_size > 0:
		_consume_ammo(1, true)
	return true

func _fire_sword_special(direction: Vector2) -> bool:
	var beam := SwordBeamScript.new()
	beam.owner_reference = self
	beam.beam_range = float(special_attack_data.get("range", 500.0))
	beam.beam_width = float(special_attack_data.get("beam_width", 18.0))
	beam.damage = int(round(_projectile_damage * float(special_attack_data.get("damage_multiplier", 1.3))))
	beam.duration = float(special_attack_data.get("beam_duration", 0.4))
	beam.color = _color_from_variant(special_attack_data.get("beam_color", Color(0.39, 1.0, 0.78, 0.95)), Color(0.39, 1.0, 0.78, 0.95))
	if get_parent():
		var parent := get_parent()
		parent.add_child(beam)
		var beam_origin := global_position
		if beam.owner_reference and is_instance_valid(beam.owner_reference) and beam.owner_reference.has_method("get_gun_tip_position"):
			var tip_variant: Variant = beam.owner_reference.call("get_gun_tip_position")
			if tip_variant is Vector2:
				beam_origin = tip_variant
		beam.global_position = beam_origin
		var aim_direction := direction
		if aim_direction.length() == 0.0:
			aim_direction = _last_move_direction
		if aim_direction.length() == 0.0:
			aim_direction = Vector2.RIGHT
	return true

func _fire_sword_primary(direction: Vector2) -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	var forward := direction
	if forward.length() == 0.0:
		forward = _last_move_direction
	if forward.length() == 0.0:
		forward = Vector2.RIGHT
	forward = forward.normalized()
	var slash_range := float(special_mechanics.get("slash_range", _projectile_range))
	if slash_range <= 0.0:
		slash_range = maxf(_projectile_range, 220.0)
	var slash_duration := float(special_mechanics.get("slash_duration", 0.4))
	if slash_duration <= 0.0:
		slash_duration = 0.4
	var slash_arc := float(special_mechanics.get("slash_arc", 90.0))
	var slash_color := _color_from_variant(special_mechanics.get("slash_color", Color(0.64, 0.38, 0.95, 0.82)), Color(0.64, 0.38, 0.95, 0.82))
	var edge_color := Color(
		clampf(slash_color.r * 1.25, 0.0, 1.0),
		clampf(slash_color.g * 1.1 + 0.05, 0.0, 1.0),
		clampf(slash_color.b * 1.1 + 0.05, 0.0, 1.0),
		minf(slash_color.a * 1.05 + 0.05, 1.0)
	)
	var glow_color := Color(
		clampf(slash_color.r * 0.45, 0.0, 1.0),
		clampf(slash_color.g * 0.3, 0.0, 1.0),
		clampf(slash_color.b * 0.85, 0.0, 1.0),
		0.55
	)
	var slash := SwordSlashScript.new()
	slash.assign_owner(self)
	slash.slash_range = slash_range
	slash.duration = slash_duration
	slash.arc_degrees = slash_arc
	slash.damage = max(1, _projectile_damage)
	slash.relative_angle = float(special_mechanics.get("slash_angle_offset", 0.0))
	slash.set_colors(slash_color, edge_color, glow_color)
	slash.set_forward_vector(forward)
	parent.add_child(slash)
	slash.global_position = get_gun_tip_position(forward)
	slash.refresh_immediate()
	return true


func _fire_projectile_salvo(
		base_projectile: Node,
		direction: Vector2,
		impact_callback: Callable = Callable(),
		impact_payload: Dictionary = {},
		salvo_overrides: Dictionary = {}
	) -> void:
	var total_pellets: int = max(1, pellet_count)
	var spread_degrees: float = spread_angle
	var step_degrees: float = 0.0
	if total_pellets > 1:
		step_degrees = (spread_degrees * 2.0) / float(total_pellets - 1)
	var shotgun_pellets: Array = []
	var assault_projectile: Node = null
	for idx in range(total_pellets):
		var projectile := base_projectile if idx == 0 else BasicProjectileScene.instantiate()
		var offset_degrees := 0.0
		if total_pellets > 1:
			offset_degrees = (float(idx) - float(total_pellets - 1) * 0.5) * step_degrees
		var pellet_direction := direction.rotated(deg_to_rad(offset_degrees))
		if projectile.has_method("set_direction"):
			projectile.set_direction(pellet_direction)
		projectile.global_position = global_position
		_apply_projectile_profile(projectile)
		_apply_salvo_overrides(projectile, pellet_direction, idx, total_pellets, salvo_overrides)
		if projectile is BasicProjectileScript:
			_configure_projectile_defaults(projectile as BasicProjectileScript, idx, total_pellets)
			_apply_marian_burst_overrides(projectile as BasicProjectileScript)
		if get_parent() and projectile.get_parent() != get_parent():
			get_parent().add_child(projectile)
		if weapon_type == "Shotgun" and projectile is BasicProjectileScript:
			shotgun_pellets.append(projectile)
		if weapon_type == "Assault Rifle" and assault_projectile == null and projectile is BasicProjectileScript:
			assault_projectile = projectile
		if projectile.has_method("set_impact_callback"):
			_configure_projectile_impact_callback(projectile, impact_callback, impact_payload)
	if weapon_type == "Shotgun" and not shotgun_pellets.is_empty():
		var forward_dir := direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
		var shotgun_visuals: Dictionary = _resolve_shotgun_salvo_visuals(shotgun_pellets)
		if shotgun_pellets.size() >= 2:
			_spawn_shotgun_trail_effect(shotgun_pellets, forward_dir, shotgun_visuals)
		_spawn_shotgun_muzzle_flash(forward_dir, shotgun_visuals)
		_spawn_shotgun_shell_ejection(forward_dir, shotgun_visuals)
	if weapon_type == "Assault Rifle" and assault_projectile != null:
		var forward_dir := direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
		_spawn_assault_rifle_effects(assault_projectile, forward_dir)

func _apply_salvo_overrides(
		projectile: Node,
		pellet_direction: Vector2,
		pellet_index: int,
		pellet_total: int,
		overrides: Dictionary
	) -> void:
	if projectile == null or overrides.is_empty():
		return
	var special_override: Variant = overrides.get("special_attack", null)
	if special_override != null:
		var special_value: Variant = special_override
		if special_override is Callable and special_override.is_valid():
			special_value = special_override.call(pellet_index, pellet_total, projectile)
		if projectile is BasicProjectileScript:
			(projectile as BasicProjectileScript).special_attack = bool(special_value)
		elif projectile.has_method("set"):
			projectile.set("special_attack", bool(special_value))
	var color_override: Variant = overrides.get("color_override", null)
	if color_override != null and projectile is BasicProjectileScript:
		var color_value: Variant = color_override
		if color_override is Callable and color_override.is_valid():
			color_value = color_override.call(pellet_index, pellet_total, projectile)
		var resolved_color: Color = _color_from_variant(color_value, (projectile as BasicProjectileScript).color)
		(projectile as BasicProjectileScript).color = resolved_color
	var radius_override: Variant = overrides.get("radius_multiplier", null)
	if radius_override != null and projectile is BasicProjectileScript:
		var radius_multiplier: Variant = radius_override
		if radius_override is Callable and radius_override.is_valid():
			radius_multiplier = radius_override.call(pellet_index, pellet_total, projectile)
		var clamped_multiplier: float = max(0.01, float(radius_multiplier))
		var basic_projectile := projectile as BasicProjectileScript
		basic_projectile.radius = basic_projectile.radius * clamped_multiplier
	var speed_override: Variant = overrides.get("speed_multiplier", null)
	if speed_override != null and projectile is BasicProjectileScript:
		var speed_multiplier: Variant = speed_override
		if speed_override is Callable and speed_override.is_valid():
			speed_multiplier = speed_override.call(pellet_index, pellet_total, projectile)
		var basic := projectile as BasicProjectileScript
		basic.speed = basic.speed * max(0.01, float(speed_multiplier))
	var per_pellet_callback: Variant = overrides.get("per_pellet_callback", null)
	if per_pellet_callback is Callable and per_pellet_callback.is_valid():
		per_pellet_callback.call(projectile, pellet_direction, pellet_index, pellet_total)


func _configure_projectile_defaults(projectile: BasicProjectileScript, _pellet_index: int, _pellet_total: int) -> void:
	if projectile == null:
		return
	match weapon_type:
		"Assault Rifle":
			projectile.projectile_archetype = "assault"
			projectile.shape = "standard"
			var assault_radius := maxf(_projectile_radius, 8.5)
			projectile.radius = maxf(projectile.radius * 0.9, assault_radius)
			projectile.trail_enabled = false
		"SMG":
			if projectile.projectile_archetype.is_empty():
				projectile.projectile_archetype = "smg"
			projectile.shape = "pellet"
			var smg_radius: float = maxf(_projectile_radius, projectile.radius)
			projectile.radius = maxf(8.3, smg_radius * 1.275)
			projectile.trail_enabled = false
		"Shotgun":
			projectile.projectile_archetype = "shotgun"
			projectile.shape = "pellet"
			projectile.radius = maxf(projectile.radius, maxf(_projectile_radius, 7.0))
		"Minigun":
			if projectile.projectile_archetype.is_empty():
				projectile.projectile_archetype = "minigun"
		_:
			pass
	projectile.call_deferred("_update_collision_shape_radius")


func _configure_projectile_impact_callback(projectile: Node, impact_callback: Callable, impact_payload: Dictionary) -> void:
	if projectile is BasicProjectileScript:
		var payload := {
			"user_callback": impact_callback if impact_callback.is_valid() else Callable(),
			"user_payload": impact_payload.duplicate(true) if not impact_payload.is_empty() else {}
		}
		projectile.set_impact_callback(Callable(self, "_on_projectile_impact"), payload)
	elif impact_callback.is_valid():
		projectile.set_impact_callback(impact_callback, impact_payload.duplicate(true))


func _on_projectile_impact(target: Node, projectile: Node, payload: Dictionary) -> void:
	if payload.has("user_callback"):
		var original: Callable = payload.get("user_callback")
		if original.is_valid():
			var forwarded_payload: Dictionary = payload.get("user_payload", {})
			original.call_deferred(target, projectile, forwarded_payload)
	if _marian_burst_time_left <= 0.0:
		return
	if projectile is Node2D:
		_spawn_marian_explosion_effect((projectile as Node2D).global_position)
	elif target is Node2D:
		_spawn_marian_explosion_effect((target as Node2D).global_position)


func _apply_marian_burst_overrides(projectile: BasicProjectileScript) -> void:
	if _marian_burst_time_left <= 0.0:
		return
	projectile.special_attack = true
	projectile.color = MARIAN_BURST_COLOR
	projectile.configure_glow(true, MARIAN_BURST_GLOW_COLOR, MARIAN_BURST_GLOW_ENERGY, MARIAN_BURST_GLOW_SCALE, MARIAN_BURST_GLOW_HEIGHT)
	projectile.trail_color = MARIAN_BURST_GLOW_COLOR

func _spawn_shotgun_trail_effect(pellets: Array, forward: Vector2, visual_data: Dictionary) -> void:
	if pellets.is_empty() or pellets.size() < 2:
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	var effect := ShotgunTrailEffectScript.new()
	var base_color: Color = visual_data.get("color", _projectile_color)
	var is_special := bool(visual_data.get("special", false))
	var glow_color := _resolve_shotgun_trail_glow(base_color, is_special)
	parent_node.add_child(effect)
	effect.global_position = global_position
	effect.configure(pellets.duplicate(), forward, base_color, glow_color, is_special)

func _spawn_shotgun_muzzle_flash(_forward: Vector2, _visual_data: Dictionary) -> void:
	# Muzzle flash visuals have been retired for clarity.
	return

func _spawn_shotgun_shell_ejection(forward: Vector2, visual_data: Dictionary) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var shell_count := 4 if bool(visual_data.get("special", false)) else 2
	var base_forward := forward.normalized() if forward.length() > 0.0 else Vector2.RIGHT
	var shell_color := Color(1.0, 0.82, 0.28, 1.0)
	var perpendicular := Vector2(-base_forward.y, base_forward.x).normalized()
	for _i in range(shell_count):
		var shell := ShotgunShellCasingScript.new()
		parent_node.add_child(shell)
		var side_offset := perpendicular * _weapon_rng.randf_range(10.0, 18.0)
		var backward_offset := base_forward * _weapon_rng.randf_range(-12.0, -4.0)
		shell.global_position = global_position + side_offset + backward_offset
		shell.lifetime = 2.0 if shell_count > 2 else 1.6
		shell.configure(base_forward, shell_color)

func _spawn_assault_rifle_effects(_projectile: Node, _forward: Vector2) -> void:
	# Rifle primary no longer spawns muzzle or shell effects to keep visuals clean.
	pass

func _resolve_shotgun_salvo_visuals(pellets: Array) -> Dictionary:
	var base_color: Color = _projectile_color
	var special := false
	for pellet in pellets:
		if pellet is BasicProjectileScript:
			var basic := pellet as BasicProjectileScript
			base_color = basic.color
			special = basic.special_attack
			break
	if not special:
		for pellet in pellets:
			if pellet is BasicProjectileScript and (pellet as BasicProjectileScript).special_attack:
				special = true
				break
	return {
		"color": base_color,
		"special": special
	}

func _resolve_shotgun_trail_glow(base_color: Color, is_special: bool) -> Color:
	var glow := Color(
		clampf(base_color.r * 0.9 + 0.1, 0.0, 1.0),
		clampf(base_color.g * 0.78 + 0.14, 0.0, 1.0),
		clampf(base_color.b * 0.55 + 0.12, 0.0, 1.0),
		0.68
	)
	if is_special:
		glow = Color(
			clampf(glow.r + 0.1, 0.0, 1.0),
			clampf(glow.g + 0.05, 0.0, 1.0),
			clampf(glow.b + 0.18, 0.0, 1.0),
			0.76
		)
	return glow

func _shotgun_primary_color_override(pellet_index: int, pellet_total: int, _projectile: Node) -> Color:
	var base := Color(1.0, 0.46, 0.12, 0.94)
	var accent := Color(1.0, 0.32, 0.06, 0.9)
	var gradient_t := 0.5
	if pellet_total > 1:
		gradient_t = float(pellet_index) / float(pellet_total - 1)
	var color := base.lerp(accent, gradient_t)
	var jitter := (_weapon_rng.randf() - 0.5) * 0.08
	color.r = clampf(color.r + abs(jitter) * 0.04, 0.0, 1.0)
	color.g = clampf(color.g - (abs(jitter) * 0.32 + 0.02), 0.0, 1.0)
	color.b = clampf(color.b - (abs(jitter) * 0.4 + 0.01), 0.0, 1.0)
	color.a = 0.92
	return color

func _shotgun_special_color_override(pellet_index: int, pellet_total: int, _projectile: Node) -> Color:
	var fallback := Color(1.0, 0.26, 0.08, 0.94)
	var base := _shotgun_special_color_cache if _shotgun_special_color_cache.a > 0.0 else fallback
	var ember := Color(
		clampf(base.r * 1.05, 0.0, 1.0),
		clampf(base.g * 0.5, 0.0, 1.0),
		clampf(base.b * 0.28, 0.0, 1.0),
		0.96
	)
	var core := Color(
		clampf(base.r * 0.96 + 0.04, 0.0, 1.0),
		clampf(base.g * 0.3 + 0.02, 0.0, 1.0),
		clampf(base.b * 0.2 + 0.01, 0.0, 1.0),
		0.9
	)
	var gradient_t := 0.5
	if pellet_total > 1:
		gradient_t = float(pellet_index) / float(pellet_total - 1)
	var color := ember.lerp(core, gradient_t)
	var jitter := (_weapon_rng.randf() - 0.5) * 0.1
	color.r = clampf(color.r + abs(jitter) * 0.05, 0.0, 1.0)
	color.g = clampf(color.g - (abs(jitter) * 0.42 + 0.04), 0.0, 1.0)
	color.b = clampf(color.b - (abs(jitter) * 0.46 + 0.02), 0.0, 1.0)
	return color

func _assault_rifle_primary_color_override(_pellet_index: int, _pellet_total: int, _projectile: Node) -> Color:
	return Color(1.0, 0.97, 0.6, 1.0)

func _shotgun_primary_radius_multiplier(_pellet_index: int, _pellet_total: int, _projectile: Node) -> float:
	return 1.5

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
	rocket.speed = _projectile_speed * 1.5
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
	rocket.trail_width = 24.0 if is_special else 18.0
	rocket.trail_spacing = 16.0 if is_special else 22.0
	rocket.trail_max_points = 20 if is_special else 12
	var trail_outer: Color = Color(1.0, 0.68, 0.28, 0.85)
	var trail_core: Color = Color(1.0, 0.94, 0.72, 0.94)
	var trail_glow: Color = Color(1.0, 0.48, 0.16, 0.7)
	if is_special:
		trail_outer = Color(1.0, 0.5, 0.2, 0.9)
		trail_core = Color(1.0, 0.82, 0.56, 0.95)
		trail_glow = Color(1.0, 0.34, 0.1, 0.78)
	rocket.trail_color = trail_outer
	rocket.trail_core_color = trail_core
	rocket.trail_glow_color = trail_glow
	rocket.exhaust_enabled = true
	rocket.exhaust_length = 60.0 if is_special else 48.0
	rocket.exhaust_width = 28.0 if is_special else 22.0
	rocket.exhaust_glow_color = Color(1.0, 0.58, 0.18, 0.78) if is_special else Color(1.0, 0.62, 0.24, 0.72)
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

func _spawn_muzzle_explosion(_color: Color, _radius: float, _direction: Vector2 = Vector2.ZERO) -> void:
	# Universal muzzle explosions disabled to keep weapon fire clean.
	return

func _consume_ammo(amount: int = 1, force_for_shotgun: bool = false) -> void:
	if weapon_type == "Shotgun" and not force_for_shotgun:
		return
	if weapon_type == "Rocket Launcher" and not force_for_shotgun:
		return
	if weapon_type == "Sword":
		return
	if magazine_size <= 0:
		return
	if amount <= 0:
		return
	if _infinite_ammo_time_left > 0.0:
		if _ammo_in_magazine < magazine_size:
			_ammo_in_magazine = magazine_size
			emit_ammo_state()
		return
	var previous_ammo: int = _ammo_in_magazine
	_ammo_in_magazine = max(0, _ammo_in_magazine - amount)
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
	_play_weapon_reload_audio()

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

func get_gun_tip_position(preferred_forward: Vector2 = Vector2.ZERO) -> Vector2:
	var forward := _resolve_weapon_forward(preferred_forward)
	return global_position + _compute_muzzle_offset(forward)

func _resolve_weapon_forward(preferred_forward: Vector2 = Vector2.ZERO) -> Vector2:
	var forward := preferred_forward
	if forward.length() == 0.0:
		forward = _get_aim_direction()
	if forward.length() == 0.0:
		forward = _last_move_direction
	if forward.length() == 0.0:
		forward = Vector2.RIGHT
	forward = forward.normalized()
	if weapon_type != "Minigun":
		_minigun_cached_forward = forward
		return forward
	var eased_spin := _minigun_spin_ease(_minigun_spin_progress)
	if eased_spin < MINIGUN_BEAM_ACTIVATION_THRESHOLD:
		_minigun_cached_forward = forward
		return forward
	if _minigun_cached_forward.length_squared() <= 0.001:
		_minigun_cached_forward = forward
		return forward
	var activation_span: float = max(0.001, 1.0 - MINIGUN_BEAM_ACTIVATION_THRESHOLD)
	var blend_ratio: float = clampf((eased_spin - MINIGUN_BEAM_ACTIVATION_THRESHOLD) / activation_span, 0.0, 1.0)
	var retention: float = clampf(lerpf(0.65, 0.92, blend_ratio), 0.0, 0.95)
	var smoothed := (_minigun_cached_forward * retention + forward * (1.0 - retention)).normalized()
	_minigun_cached_forward = smoothed
	return smoothed

func _configure_minigun_profile_defaults() -> void:
	if weapon_type != "Minigun":
		return
	_minigun_spin_up_time = max(0.1, float(special_mechanics.get("spin_up_time", 5.0)))
	_minigun_spin_up_time = max(0.05, _minigun_spin_up_time * 0.5)
	_minigun_spin_decay_multiplier = max(1.0, float(special_mechanics.get("spin_down_multiplier", 3.0)))
	_minigun_spin_grace_time = max(0.0, float(special_mechanics.get("spin_grace_period", 1.0)))
	_minigun_initial_fire_rate = float(special_mechanics.get("initial_fire_rate", 0.0))
	if _minigun_initial_fire_rate <= 0.0:
		_minigun_initial_fire_rate = max(_base_fire_rate * 4.0, _base_fire_rate + 0.25)
	_minigun_initial_fire_rate = max(_base_fire_rate, _minigun_initial_fire_rate)
	_minigun_full_damage_multiplier = max(1.0, float(special_mechanics.get("spun_up_damage_multiplier", 1.8)))
	_minigun_spin_progress = 0.0
	_minigun_spin_grace_left = 0.0
	if _minigun_boost_time_left <= 0.0:
		_apply_minigun_spin_stats(0.0)
	_minigun_special_charge = 0.0

func _disable_minigun_spin_effects() -> void:
	_minigun_spin_progress = 0.0
	_minigun_spin_grace_left = 0.0
	_minigun_initial_fire_rate = 0.0
	_minigun_full_damage_multiplier = 1.0
	_minigun_spin_up_time = 2.2
	_minigun_spin_grace_time = 0.0
	_minigun_spin_decay_multiplier = 3.0
	_minigun_special_charge = 0.0

func _update_minigun_spin_state(delta: float, wants_fire: bool) -> void:
	if weapon_type != "Minigun":
		return
	if _minigun_initial_fire_rate <= 0.0:
		return
	if _minigun_boost_time_left > 0.0:
		_minigun_spin_progress = 1.0
		_minigun_spin_grace_left = max(_minigun_spin_grace_time, _minigun_spin_grace_left)
		return
	if wants_fire:
		_minigun_idle_time = 0.0
		var spin_duration: float = max(_minigun_spin_up_time, 0.001)
		_minigun_spin_progress = move_toward(_minigun_spin_progress, 1.0, delta / spin_duration)
		_minigun_spin_grace_left = _minigun_spin_grace_time
	else:
		if _minigun_spin_grace_left > 0.0:
			_minigun_spin_grace_left = max(_minigun_spin_grace_left - delta, 0.0)
		if _minigun_spin_grace_left == 0.0:
			var decay_multiplier: float = max(_minigun_spin_decay_multiplier, 1.0)
			var decay_duration: float = max(_minigun_spin_up_time * decay_multiplier, 0.001)
			_minigun_spin_progress = move_toward(_minigun_spin_progress, 0.0, delta / decay_duration)
		_minigun_idle_time += delta
	var eased := _minigun_spin_ease(_minigun_spin_progress)
	_apply_minigun_spin_stats(eased)
	if _minigun_idle_time >= MINIGUN_SPIN_RESET_DELAY and not wants_fire:
		_minigun_idle_time = 0.0
		_minigun_spin_progress = 0.0
		_apply_minigun_spin_stats(0.0)

func _update_minigun_special_state(delta: float, special_held: bool) -> void:
	if weapon_type != "Minigun":
		return
	var previous_charge: float = _minigun_special_charge
	var recharge_rate: float = float(_resolve_minigun_lightning_setting("lightning_recharge_rate", MINIGUN_LIGHTNING_RECHARGE_RATE))
	if recharge_rate > 0.0:
		var charge_cost: float = max(0.0, float(_resolve_minigun_lightning_setting("lightning_fire_cost", MINIGUN_LIGHTNING_FIRE_COST)))
		var needs_recharge := not special_held or charge_cost > 0.0 and _minigun_special_charge < charge_cost
		if needs_recharge and _minigun_special_charge < MINIGUN_SPECIAL_CHARGE_MAX:
			var new_charge := _minigun_special_charge + recharge_rate * delta
			_minigun_special_charge = clampf(new_charge, 0.0, MINIGUN_SPECIAL_CHARGE_MAX)
	if absf(previous_charge - _minigun_special_charge) >= 0.1:
		emit_ammo_state()

func _apply_minigun_spin_stats(progress: float) -> void:
	if weapon_type != "Minigun":
		return
	if _minigun_initial_fire_rate <= 0.0:
		return
	var clamped: float = clampf(progress, 0.0, 1.0)
	var initial_rate: float = max(_minigun_initial_fire_rate, _base_fire_rate)
	var resolved_rate: float = lerpf(initial_rate, _base_fire_rate, clamped)
	fire_rate = resolved_rate
	if _minigun_boost_time_left <= 0.0:
		var damage_multiplier: float = lerpf(1.0, _minigun_full_damage_multiplier, clamped)
		_projectile_damage = max(1, int(round(_base_projectile_damage * damage_multiplier)))

func _minigun_spin_ease(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 2.0)

func _smg_primary_color_override(_pellet_index: int, _pellet_total: int, projectile: Node) -> Color:
	var base_color := _projectile_color
	if projectile is BasicProjectileScript:
		base_color = (projectile as BasicProjectileScript).color
	return _lighten_color(base_color, 0.32)

func _on_smg_primary_projectile_spawned(projectile: Node, _pellet_direction: Vector2, _pellet_index: int, _pellet_total: int) -> void:
	if not (projectile is BasicProjectileScript):
		return
	var basic := projectile as BasicProjectileScript
	if basic.projectile_archetype.is_empty():
		basic.projectile_archetype = "smg"
	basic.shape = "pellet"
	basic.radius = maxf(basic.radius, maxf(_projectile_radius * 1.275, 8.3))
	basic.trail_enabled = false
	var glow_color := _lighten_color(basic.color, 0.1).lerp(Color(1.0, 0.52, 0.24, 0.26), 0.24)
	var glow_scale := clampf(basic.radius * 0.18, 0.8, 1.6)
	basic.configure_glow(true, glow_color, 0.18, glow_scale, -0.1)
	basic.call_deferred("_update_collision_shape_radius")

func _on_assault_rifle_projectile_spawned(projectile: Node, _pellet_direction: Vector2, _pellet_index: int, _pellet_total: int) -> void:
	if not (projectile is BasicProjectileScript):
		return
	var basic := projectile as BasicProjectileScript
	basic.projectile_archetype = "assault"
	basic.shape = "standard"
	var desired_radius: float = maxf(_projectile_radius, 9.0)
	basic.radius = maxf(basic.radius, desired_radius)
	basic.trail_enabled = false
	basic.call_deferred("_update_collision_shape_radius")
	basic.call_deferred("_sync_visual_state")

func _on_shotgun_primary_projectile_spawned(projectile: Node, _pellet_direction: Vector2, pellet_index: int, pellet_total: int) -> void:
	if not (projectile is BasicProjectileScript):
		return
	var basic := projectile as BasicProjectileScript
	basic.projectile_archetype = "shotgun"
	basic.shape = "pellet"
	var spread_ratio := 0.0
	if pellet_total > 1:
		spread_ratio = abs(float(pellet_index) - float(pellet_total - 1) * 0.5) / float(pellet_total - 1)
	var radius_scale := lerpf(1.1, 0.85, spread_ratio)
	basic.radius = maxf(maxf(_projectile_radius, 7.0) * radius_scale, basic.radius)
	basic.trail_enabled = false
	if basic.has_method("apply_default_glow"):
		basic.apply_default_glow()
	basic.call_deferred("_update_collision_shape_radius")
	basic.call_deferred("_sync_visual_state")

func _on_shotgun_special_projectile_spawned(projectile: Node, _pellet_direction: Vector2, pellet_index: int, pellet_total: int) -> void:
	if not (projectile is BasicProjectileScript):
		return
	var basic := projectile as BasicProjectileScript
	basic.projectile_archetype = "shotgun_special"
	basic.shape = "pellet"
	var spread_ratio := 0.0
	if pellet_total > 1:
		spread_ratio = abs(float(pellet_index) - float(pellet_total - 1) * 0.5) / float(pellet_total - 1)
	var base_radius := maxf(_projectile_radius * 1.35, 9.5)
	var radius_scale := lerpf(1.18, 0.92, spread_ratio)
	basic.radius = maxf(basic.radius, base_radius * radius_scale)
	basic.trail_enabled = false
	if basic.has_method("apply_default_glow"):
		basic.apply_default_glow()
	basic.call_deferred("_update_collision_shape_radius")
	basic.call_deferred("_sync_visual_state")

func _lighten_color(base_color: Color, amount: float) -> Color:
	var clamped := clampf(amount, 0.0, 1.0)
	var target_value := clampf(base_color.v + (1.0 - base_color.v) * clamped, 0.0, 1.0)
	var target_saturation := clampf(base_color.s * (1.0 - clamped * 0.4), 0.0, 1.0)
	return Color.from_hsv(base_color.h, target_saturation, target_value, base_color.a)

func _on_minigun_projectile_spawned(projectile: Node, _pellet_direction: Vector2, _pellet_index: int, _pellet_total: int) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	if not (projectile is Node2D):
		return
	if projectile is BasicProjectileScript:
		var basic := projectile as BasicProjectileScript
		var target_radius: float = maxf(_projectile_radius, 8.0)
		basic.radius = maxf(basic.radius, target_radius)
		basic.projectile_archetype = "minigun"
		basic.shape = "standard"
		basic.color = _projectile_color
		basic.trail_enabled = false
		basic.configure_glow(true, _projectile_color, 2.2, 1.25, -3.5)
		basic.call_deferred("_update_collision_shape_radius")
		basic.call_deferred("_sync_visual_state")

func _fire_minigun_special(direction: Vector2) -> bool:
	if weapon_type != "Minigun":
		return false
	var charge_cost: float = float(_resolve_minigun_lightning_setting("lightning_fire_cost", MINIGUN_LIGHTNING_FIRE_COST))
	charge_cost = max(0.0, charge_cost)
	if charge_cost > 0.0 and _minigun_special_charge < charge_cost:
		return false
	var parent := get_parent()
	if parent == null:
		return false
	var forward := direction.normalized() if direction.length() > 0.0 else _get_aim_direction().normalized()
	if forward.length_squared() == 0.0:
		forward = Vector2.RIGHT
	var origin := get_gun_tip_position(forward)
	var max_distance: float = float(_resolve_minigun_lightning_setting("lightning_range", maxf(_projectile_range, MINIGUN_LIGHTNING_MAX_RANGE)))
	var chain_radius: float = float(_resolve_minigun_lightning_setting("lightning_chain_radius", MINIGUN_LIGHTNING_CHAIN_RADIUS))
	var max_targets: int = max(1, int(_resolve_minigun_lightning_setting("lightning_chain_targets", MINIGUN_LIGHTNING_MAX_TARGETS)))
	var targets := _gather_minigun_lightning_targets(origin, forward, max_distance, chain_radius, max_targets)
	if targets.is_empty():
		return false
	var falloff: float = clampf(float(_resolve_minigun_lightning_setting("lightning_falloff", MINIGUN_LIGHTNING_DAMAGE_FALLOFF)), 0.1, 1.0)
	var current_damage: int = _resolve_minigun_lightning_damage()
	var strike_origin := origin
	var total_targets: int = targets.size()
	for index in range(total_targets):
		var target: Node2D = targets[index] as Node2D
		if target == null or not is_instance_valid(target):
			continue
		var target_position: Vector2 = target.global_position
		var width: float = maxf(_projectile_radius * 2.2, MINIGUN_LIGHTNING_ARC_WIDTH)
		var intensity: float = 1.0 - float(index) / max(1.0, float(total_targets))
		_spawn_minigun_lightning_arc(strike_origin, target_position, intensity, width)
		_apply_minigun_lightning_damage(target, current_damage)
		strike_origin = target_position
		current_damage = max(1, int(round(current_damage * falloff)))
	if charge_cost > 0.0:
		_minigun_special_charge = clampf(_minigun_special_charge - charge_cost, 0.0, MINIGUN_SPECIAL_CHARGE_MAX)
	emit_ammo_state()
	return true

func _resolve_minigun_lightning_damage() -> int:
	var scaled := int(round(_base_projectile_damage * MINIGUN_LIGHTNING_DAMAGE_MULTIPLIER))
	return max(MINIGUN_LIGHTNING_DAMAGE_BASE, scaled)

func _resolve_minigun_lightning_setting(key: String, fallback: Variant) -> Variant:
	if special_mechanics.has(key):
		return special_mechanics.get(key)
	if special_attack_data.has(key):
		return special_attack_data.get(key)
	return fallback

func _collect_minigun_lightning_candidates() -> Array:
	var candidates: Array = []
	if not get_tree():
		return candidates
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		if not enemy.has_method("apply_damage"):
			continue
		candidates.append(enemy)
	return candidates

func _gather_minigun_lightning_targets(origin: Vector2, forward: Vector2, max_distance: float, chain_radius: float, max_targets: int) -> Array:
	var candidates := _collect_minigun_lightning_candidates()
	if candidates.is_empty():
		return []
	var available := candidates.duplicate()
	var selected: Array = []
	var first_target := _select_minigun_lightning_entry(origin, forward, available, max_distance)
	if first_target == null:
		return selected
	selected.append(first_target)
	available.erase(first_target)
	var current_point := first_target.global_position
	while selected.size() < max_targets and not available.is_empty():
		var next_target := _select_minigun_lightning_chain(current_point, available, chain_radius)
		if next_target == null:
			break
		selected.append(next_target)
		available.erase(next_target)
		current_point = next_target.global_position
	return selected

func _select_minigun_lightning_entry(origin: Vector2, forward: Vector2, candidates: Array, max_distance: float) -> Node2D:
	var best: Node2D = null
	var best_score := INF
	var max_distance_sq := max_distance * max_distance if max_distance > 0.0 else INF
	var normal := Vector2(-forward.y, forward.x)
	var target_projection: float = max_distance if max_distance > 0.0 else MINIGUN_LIGHTNING_MAX_RANGE
	if target_projection <= 0.0:
		target_projection = MINIGUN_LIGHTNING_MAX_RANGE
	for candidate in candidates:
		if not (candidate is Node2D):
			continue
		var enemy := candidate as Node2D
		var delta := enemy.global_position - origin
		var projection := forward.dot(delta)
		if projection <= 0.0:
			continue
		if max_distance_sq != INF and delta.length_squared() > max_distance_sq:
			continue
		var lateral := absf(normal.dot(delta))
		var projection_error := absf(target_projection - projection)
		var score := projection_error * 0.6 + lateral
		if score < best_score:
			best_score = score
			best = enemy
	if best == null:
		var fallback_best: Node2D = null
		var fallback_projection := -INF
		for candidate in candidates:
			if not (candidate is Node2D):
				continue
			var enemy := candidate as Node2D
			var projection := forward.dot(enemy.global_position - origin)
			if projection <= 0.0:
				continue
			if projection > fallback_projection:
				fallback_projection = projection
				fallback_best = enemy
		best = fallback_best
	return best

func _select_minigun_lightning_chain(current_point: Vector2, candidates: Array, chain_radius: float) -> Node2D:
	if chain_radius <= 0.0:
		return null
	var best: Node2D = null
	var best_distance_sq := chain_radius * chain_radius
	for candidate in candidates:
		if not (candidate is Node2D):
			continue
		var enemy := candidate as Node2D
		var distance_sq := current_point.distance_squared_to(enemy.global_position)
		if distance_sq > best_distance_sq:
			continue
		best_distance_sq = distance_sq
		best = enemy
	return best

func _apply_minigun_lightning_damage(enemy: Node2D, damage: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not enemy.has_method("apply_damage"):
		return
	var result: int = enemy.apply_damage(damage)
	if result != 0:
		register_burst_hit(enemy)

func _spawn_minigun_lightning_arc(start_point: Vector2, end_point: Vector2, intensity: float, width: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var arc: Node2D = MinigunLightningArcScript.new()
	if arc == null:
		return
	parent.add_child(arc)
	if arc.has_method("configure"):
		arc.call("configure", start_point, end_point, width, intensity)
	else:
		arc.global_position = start_point

func _compute_muzzle_offset(forward: Vector2) -> Vector2:
	var forward_distance: float = max(44.0, _projectile_radius * 8.5)
	var height_offset: Vector2 = Vector2(0.0, -12.0)
	return forward * forward_distance + height_offset

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
	if weapon_type == "Shotgun":
		fire_mode = "automatic"
	if weapon_type == "Sniper":
		fire_mode = "automatic"
		_projectile_speed = minf(_projectile_speed, SNIPER_PRIMARY_SPEED_CAP)
	if weapon_type == "Assault Rifle":
		_projectile_shape = "standard"
		_projectile_radius = maxf(_projectile_radius, 8.0)
		_projectile_color = Color(1.0, 0.97, 0.6, 1.0)
	if weapon_type == "Minigun":
		_projectile_shape = "standard"
		_projectile_radius = maxf(_projectile_radius, 8.0)
		_projectile_color = Color(1.0, 0.97, 0.6, 1.0)
		_projectile_range *= 1.25
		_projectile_lifetime *= 1.25
		_configure_minigun_profile_defaults()
		_minigun_special_charge = 0.0
		_minigun_idle_time = 0.0
	else:
		_disable_minigun_spin_effects()
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
	if weapon_type == "Rocket Launcher":
		special_current = _ammo_in_magazine
		special_max = magazine_size
		current_ammo = 0
		mag_capacity = 0
	elif weapon_type == "Minigun":
		special_current = int(round(_minigun_special_charge))
		special_max = int(round(MINIGUN_SPECIAL_CHARGE_MAX))
	emit_signal("ammo_changed", current_ammo, mag_capacity, special_current, special_max)

func add_burst_points(points: float) -> void:
	if points <= 0.0 or _burst_charge_max <= 0.0:
		return
	var adjusted: float = points * maxf(0.0, _burst_gain_multiplier)
	_burst_charge_value = clampf(_burst_charge_value + adjusted, 0.0, _burst_charge_max)
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
	_play_burst_voice()
	_trigger_character_burst_effect()


func _trigger_character_burst_effect() -> void:
	if not get_parent():
		return
	var code := _get_active_character_code()
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
		"snow-white":
			_activate_snow_white_burst()
			return
		"kilo":
			_activate_kilo_burst()
			return
		"marian":
			_activate_marian_burst()
			return
		"scarlet":
			_activate_scarlet_burst()
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


func _get_active_character_code() -> String:
	var code := _character_code
	if code.is_empty() and _current_profile and _current_profile.has_method("get"):
		var raw_code: Variant = _current_profile.get("code_name")
		if raw_code != null:
			code = str(raw_code)
	return code.strip_edges().to_lower()


func _is_active_character(character_name: String) -> bool:
	return _get_active_character_code() == character_name.strip_edges().to_lower()


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
	_clear_sin_burst_targets()
	_rewind_history.clear()
	_rewind_snapshot_timer = 0.0
	_set_phase_state(false)
	fire_rate = _base_fire_rate
	_kilo_burst_time_left = 0.0
	_marian_burst_time_left = 0.0
	_trony_stealth_time_left = 0.0
	_trony_stealth_active = false
	_burst_gain_multiplier = 1.0
	_scarlet_teleport_ready = false
	_scarlet_teleport_target = Vector2.ZERO
	if weapon_type == "Minigun" and _minigun_initial_fire_rate > 0.0:
		_minigun_spin_progress = 0.0
		_minigun_spin_grace_left = 0.0
		if _minigun_boost_time_left <= 0.0:
			_apply_minigun_spin_stats(0.0)
	_minigun_special_charge = 0.0
	_minigun_idle_time = 0.0

func _clear_sin_burst_targets() -> void:
	for entry in _sin_burst_targets:
		if entry is Dictionary:
			var effect_ref: WeakRef = entry.get("effect_ref")
			if effect_ref:
				var effect: Node = effect_ref.get_ref()
				if effect and is_instance_valid(effect):
					effect.queue_free()
	_sin_burst_targets.clear()
	_sin_burst_end_time = 0.0

func _get_camera_view_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2(global_position, Vector2.ZERO)
	var camera := viewport.get_camera_2d()
	if camera == null:
		return Rect2(global_position, Vector2.ZERO)
	var rect_size := viewport.get_visible_rect().size
	rect_size.x *= camera.zoom.x
	rect_size.y *= camera.zoom.y
	var center := camera.global_position
	return Rect2(center - rect_size * 0.5, rect_size)

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
	if _kilo_burst_time_left > 0.0:
		_kilo_burst_time_left = max(_kilo_burst_time_left - delta, 0.0)
		if _kilo_burst_time_left == 0.0:
			_burst_gain_multiplier = 1.0
			fire_rate = _base_fire_rate
	if _marian_burst_time_left > 0.0:
		_marian_burst_time_left = max(_marian_burst_time_left - delta, 0.0)
	if _trony_stealth_time_left > 0.0:
		_trony_stealth_time_left = max(_trony_stealth_time_left - delta, 0.0)
		if _trony_stealth_time_left == 0.0 and _trony_stealth_active:
			_end_trony_stealth()
	elif _trony_stealth_active and _trony_stealth_time_left == 0.0:
		_end_trony_stealth()
	if _crown_aura_time_left > 0.0:
		_crown_aura_time_left = max(_crown_aura_time_left - delta, 0.0)
		_crown_aura_tick_timer += delta
		if _crown_aura_tick_timer >= 0.55:
			_crown_aura_tick_timer = 0.0
			_execute_crown_burst_tick()
	_update_sin_burst(delta)

func _update_sin_burst(_delta: float) -> void:
	if _sin_burst_targets.is_empty():
		return
	var now := Time.get_ticks_msec() * 0.001
	if now >= _sin_burst_end_time or not get_tree():
		_clear_sin_burst_targets()
		return
	var heal_amount := int(round(float(_max_health) * SIN_HEAL_FRACTION))
	var updated: Array = []
	for entry in _sin_burst_targets:
		if not (entry is Dictionary):
			continue
		var enemy_ref: WeakRef = entry.get("enemy_ref")
		var enemy: Node = enemy_ref.get_ref() if enemy_ref else null
		if enemy == null or not is_instance_valid(enemy):
			var effect_ref: WeakRef = entry.get("effect_ref")
			if effect_ref:
				var effect: Node = effect_ref.get_ref()
				if effect and is_instance_valid(effect):
					effect.queue_free()
			continue
		var next_damage: float = entry.get("next_damage_time", now)
		if now >= next_damage:
			var dealt := 0
			if enemy.has_method("apply_damage"):
				dealt = int(enemy.apply_damage(SIN_DOT_DAMAGE))
			if dealt > 0:
				register_burst_hit(enemy)
			entry["next_damage_time"] = now + SIN_DOT_INTERVAL
		var next_heal: float = entry.get("next_heal_time", now + SIN_HEAL_INTERVAL)
		if now >= next_heal and heal_amount > 0:
			restore_health(heal_amount)
			entry["next_heal_time"] = now + SIN_HEAL_INTERVAL
		updated.append(entry)
	_sin_burst_targets = updated
	if _sin_burst_targets.is_empty():
		_clear_sin_burst_targets()

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


func _end_trony_stealth() -> void:
	if not _trony_stealth_active:
		return
	_trony_stealth_active = false
	_trony_stealth_time_left = 0.0
	_phase_time_left = 0.0
	_set_phase_state(false)
	_push_enemies_away(global_position, TRONY_STEALTH_PUSH_RADIUS, TRONY_STEALTH_PUSH_FORCE)


func _push_enemies_away(center: Vector2, radius: float, force: float) -> void:
	if not get_tree() or radius <= 0.0 or force <= 0.0:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		var offset := enemy_node.global_position - center
		var distance := offset.length()
		if distance <= 0.0 or distance > radius:
			continue
		var direction := offset / distance
		var strength := force * (1.0 - (distance / radius))
		enemy_node.global_position += direction * strength * 0.5

func _apply_stun_to_enemies(duration: float, radius: float = -1.0, limit_to_view: bool = false, effect_style: String = "") -> void:
	if not get_tree():
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var radius_sq := -1.0
	if radius > 0.0:
		radius_sq = radius * radius
	var view_rect := Rect2()
	var filter_by_view := false
	if limit_to_view:
		view_rect = _get_camera_view_rect()
		filter_by_view = view_rect.size.x > 0.0 and view_rect.size.y > 0.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		if not enemy.has_method("apply_stun"):
			continue
		var enemy_node := enemy as Node2D
		if filter_by_view and not view_rect.has_point(enemy_node.global_position):
			continue
		if radius_sq > 0.0:
			var dist_sq := enemy_node.global_position.distance_squared_to(global_position)
			if dist_sq > radius_sq:
				continue
		enemy.apply_stun(duration)
		if not effect_style.is_empty():
			_attach_stun_effect(enemy_node, effect_style)

func _attach_stun_effect(target: Node2D, effect_style: String) -> void:
	var script: Script = null
	match effect_style:
		"commander":
			script = CommanderStunEffectScript
		"cecil":
			script = CecilStunEffectScript
		_:
			return
	if script == null:
		return
	for child in target.get_children():
		if child is Node2D and child.get_script() == script:
			return
	var instance: Object = script.new()
	if not (instance is Node2D):
		return
	var effect := instance as Node2D
	effect.position = Vector2.ZERO
	effect.z_index = target.z_index + 5
	target.add_child(effect)

func _rewind_player_state(position_duration: float, health_duration: float = -1.0) -> void:
	if position_duration <= 0.0:
		position_duration = 0.1
	if health_duration <= 0.0:
		health_duration = position_duration
	if _rewind_history.is_empty():
		_ammo_in_magazine = magazine_size
		grenade_rounds = _max_grenade_rounds
		emit_ammo_state()
		restore_health(_max_health)
		return
	var now := Time.get_ticks_msec() * 0.001
	var position_snapshot := _find_rewind_snapshot(now - position_duration)
	var health_snapshot := _find_rewind_snapshot(now - health_duration)
	if position_snapshot.is_empty():
		position_snapshot = _rewind_history[0]
	if health_snapshot.is_empty():
		health_snapshot = _rewind_history[0]
	if not position_snapshot.is_empty():
		var target_position: Variant = position_snapshot.get("position", global_position)
		if target_position is Vector2:
			global_position = target_position
		velocity = Vector2.ZERO
	var previous_health := _current_health
	var target_health := int(health_snapshot.get("health", _max_health))
	_current_health = clampi(target_health, 0, _max_health)
	_is_dead = _current_health <= 0
	var health_delta := _current_health - previous_health
	emit_signal("health_changed", _current_health, _max_health, health_delta)
	if _is_dead:
		_minigun_spin_progress = 0.0
		_minigun_spin_grace_left = 0.0
		_minigun_boost_time_left = 0.0
		if weapon_type == "Minigun" and _minigun_initial_fire_rate > 0.0:
			_apply_minigun_spin_stats(0.0)
			emit_signal("player_died")
	var restored_ammo := int(health_snapshot.get("ammo", magazine_size)) if magazine_size > 0 else _ammo_in_magazine
	var restored_grenades := int(health_snapshot.get("grenade", _max_grenade_rounds))
	var ammo_clamped := clampi(restored_ammo, 0, magazine_size) if magazine_size > 0 else restored_ammo
	var grenade_clamped := clampi(restored_grenades, 0, _max_grenade_rounds)
	var ammo_was_changed := ammo_clamped != _ammo_in_magazine
	var grenade_was_changed := grenade_clamped != grenade_rounds
	_ammo_in_magazine = ammo_clamped
	grenade_rounds = grenade_clamped
	if ammo_was_changed or grenade_was_changed:
		emit_ammo_state()
	if _infinite_ammo_time_left > 0.0 and _ammo_in_magazine < magazine_size:
		_ammo_in_magazine = magazine_size
		emit_ammo_state()
	if _infinite_ammo_time_left <= 0.0 and _ammo_in_magazine > magazine_size and magazine_size > 0:
		_ammo_in_magazine = clampi(_ammo_in_magazine, 0, magazine_size)
		emit_ammo_state()
	if _ammo_in_magazine <= 0 and magazine_size > 0:
		_begin_reload()

func _find_rewind_snapshot(target_time: float) -> Dictionary:
	if _rewind_history.is_empty():
		return {}
	var fallback_snapshot: Dictionary = _rewind_history[-1]
	for i in range(_rewind_history.size() - 1, -1, -1):
		var snapshot := _rewind_history[i]
		fallback_snapshot = snapshot
		var snap_time := float(snapshot.get("time", -INF))
		if snap_time <= target_time:
			return snapshot
	return fallback_snapshot

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


func _spawn_scarlet_enemy_flash(flash_position: Vector2) -> void:
	if not get_parent():
		return
	var effect := ExplosionEffectScript.new()
	effect.radius = 130.0
	effect.duration = 0.3
	effect.base_color = SCARLET_TELEPORT_EFFECT_COLOR
	effect.glow_color = Color(SCARLET_TELEPORT_EFFECT_COLOR.r, SCARLET_TELEPORT_EFFECT_COLOR.g * 0.85, SCARLET_TELEPORT_EFFECT_COLOR.b, 0.65)
	effect.core_color = Color(1.0, 0.95, 1.0, 0.92)
	effect.shockwave_color = Color(1.0, 0.7, 1.0, 0.8)
	get_parent().add_child(effect)
	effect.global_position = flash_position


func _spawn_marian_explosion_effect(impact_position: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var effect := ExplosionEffectScript.new()
	effect.radius = MARIAN_BURST_EXPLOSION_RADIUS
	effect.duration = 0.28
	effect.base_color = MARIAN_BURST_COLOR
	effect.glow_color = Color(MARIAN_BURST_GLOW_COLOR.r, MARIAN_BURST_GLOW_COLOR.g, MARIAN_BURST_GLOW_COLOR.b, 0.72)
	effect.core_color = Color(1.0, 0.95, 1.0, 0.86)
	effect.shockwave_color = Color(0.95, 0.6, 1.0, 0.78)
	parent.add_child(effect)
	effect.global_position = impact_position
	_apply_burst_damage_area(impact_position, MARIAN_BURST_EXPLOSION_RADIUS, _calculate_burst_damage(MARIAN_BURST_EXPLOSION_DAMAGE_MULTIPLIER))


func _spawn_crown_burst_effect(radius: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var effect := ExplosionEffectScript.new()
	effect.radius = max(200.0, radius)
	effect.duration = 0.6
	effect.base_color = Color(0.96, 0.82, 0.4, 0.78)
	effect.glow_color = Color(0.84, 0.62, 1.0, 0.68)
	effect.core_color = Color(1.0, 0.98, 0.9, 0.9)
	effect.shockwave_color = Color(0.9, 0.74, 1.0, 0.82)
	parent.add_child(effect)
	effect.global_position = global_position

func _activate_cecil_burst() -> void:
	_apply_stun_to_enemies(3.0, -1.0, true, "cecil")
	_spawn_support_burst_flash(Color(0.55, 0.82, 1.0, 0.85), 260.0, 0.5)

func _activate_commander_burst() -> void:
	_apply_stun_to_enemies(3.0, -1.0, true, "commander")
	_spawn_support_burst_flash(Color(0.86, 0.68, 0.32, 0.9), 280.0, 0.55)


func _activate_wells_burst() -> void:
	var position_duration: float = float(special_attack_data.get("burst_position_rewind", 5.0))
	var health_duration: float = float(special_attack_data.get("burst_health_rewind", 10.0))
	_rewind_player_state(position_duration, health_duration)
	_spawn_support_burst_flash(Color(0.95, 0.74, 0.45, 0.85), 240.0, 0.55)

func _activate_trony_burst() -> void:
	var duration: float = TRONY_STEALTH_DURATION
	_phase_time_left = max(_phase_time_left, duration)
	_trony_stealth_time_left = max(_trony_stealth_time_left, duration)
	_trony_stealth_active = true
	_set_phase_state(true)
	_invincible_time_left = max(_invincible_time_left, duration)
	_spawn_support_burst_flash(Color(0.58, 0.86, 1.0, 0.7), 260.0, 0.5)

func _activate_snow_white_burst() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var forward := _get_aim_direction()
	if forward.length() == 0.0:
		forward = _last_move_direction
	if forward.length() == 0.0:
		forward = Vector2.RIGHT
	forward = forward.normalized()
	var range_default := float(special_attack_data.get("snow_beam_range", special_attack_data.get("burst_range", 1400.0)))
	var beam_range: float = max(range_default, 900.0)
	var visual_angle := clampf(float(special_attack_data.get("snow_visual_angle", 90.0)), 30.0, 170.0)
	var damage_angle := clampf(float(special_attack_data.get("snow_damage_angle", 45.0)), 10.0, 120.0)
	var beam_duration: float = max(0.2, float(special_attack_data.get("snow_beam_duration", 0.8)))
	var linger_duration: float = max(0.5, float(special_attack_data.get("snow_particle_duration", 2.0)))
	var outer_color := _color_from_variant(special_attack_data.get("snow_outer_color", Color(0.55, 0.75, 1.0, 0.5)), Color(0.55, 0.75, 1.0, 0.5))
	var mid_color := _color_from_variant(special_attack_data.get("snow_mid_color", Color(0.68, 0.85, 1.0, 0.65)), Color(0.68, 0.85, 1.0, 0.65))
	var inner_color := _color_from_variant(special_attack_data.get("snow_inner_color", Color(0.82, 0.94, 1.0, 0.8)), Color(0.82, 0.94, 1.0, 0.8))
	var core_color := _color_from_variant(special_attack_data.get("snow_core_color", Color(1.0, 1.0, 1.0, 1.0)), Color(1.0, 1.0, 1.0, 1.0))
	var flash_color := _color_from_variant(special_attack_data.get("snow_flash_color", Color(1.0, 1.0, 1.0, 0.9)), Color(1.0, 1.0, 1.0, 0.9))
	var beam_colors := {
		"outer": outer_color,
		"mid": mid_color,
		"inner": inner_color,
		"core": core_color,
		"flash": flash_color
	}
	var beam := SnowWhiteBurstBeamScript.new()
	beam.duration = beam_duration
	beam.configure(forward, beam_range, visual_angle, beam_colors)
	parent.add_child(beam)
	beam.global_position = global_position
	var lingering := SnowWhiteLingeringEffectScript.new()
	lingering.duration = linger_duration
	lingering.beam_range = beam_range
	lingering.beam_angle_degrees = damage_angle
	lingering.configure(forward, beam_range, damage_angle)
	parent.add_child(lingering)
	lingering.global_position = global_position
	_spawn_support_burst_flash(Color(0.92, 0.98, 1.0, 0.7), min(beam_range * 0.22, 420.0), beam_duration * 0.75)
	_apply_snow_white_burst_damage(global_position, forward, beam_range, damage_angle)

func _activate_kilo_burst() -> void:
	var duration: float = KILO_BURST_DURATION
	_infinite_ammo_time_left = max(_infinite_ammo_time_left, duration)
	_rapid_fire_time_left = max(_rapid_fire_time_left, duration)
	_invincible_time_left = max(_invincible_time_left, duration)
	fire_rate = max(0.04, _base_fire_rate * float(special_attack_data.get("burst_fire_rate_multiplier", 0.35)))
	_ammo_in_magazine = magazine_size
	grenade_rounds = _max_grenade_rounds
	emit_ammo_state()
	_kilo_burst_time_left = max(_kilo_burst_time_left, duration)
	var cooldown_multiplier: float = KILO_BURST_COOLDOWN_MULTIPLIER
	_burst_gain_multiplier = maxf(_burst_gain_multiplier, 1.0 / maxf(0.01, cooldown_multiplier))
	_spawn_support_burst_flash(Color(1.0, 0.76, 0.32, 0.85), 280.0, 0.6)

func _activate_marian_burst() -> void:
	var duration: float = MARIAN_BURST_DURATION
	_marian_burst_time_left = max(_marian_burst_time_left, duration)
	_infinite_ammo_time_left = max(_infinite_ammo_time_left, duration)
	if _is_reloading:
		_is_reloading = false
		_reload_time_left = 0.0
	if magazine_size > 0:
		_ammo_in_magazine = magazine_size
		emit_ammo_state()
	_spawn_support_burst_flash(MARIAN_BURST_COLOR, 240.0, 0.5)

func _activate_scarlet_burst() -> void:
	_spawn_support_burst_flash(SCARLET_TELEPORT_EFFECT_COLOR, 260.0, 0.5)
	var killed_positions: Array = []
	var view_rect := _get_camera_view_rect()
	var filter_by_view := view_rect.size.x > 0.0 and view_rect.size.y > 0.0
	if not get_tree():
		_scarlet_teleport_ready = false
		_scarlet_teleport_target = Vector2.ZERO
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		if filter_by_view and not view_rect.has_point(enemy_node.global_position):
			continue
		var enemy_position := enemy_node.global_position
		var dealt := 0
		if enemy_node.has_method("apply_damage"):
			dealt = int(enemy_node.call("apply_damage", 99999))
		if dealt <= 0:
			continue
		register_burst_hit(enemy_node)
		_spawn_scarlet_enemy_flash(enemy_position)
		killed_positions.append(enemy_position)
	if killed_positions.is_empty():
		_scarlet_teleport_ready = false
		_scarlet_teleport_target = Vector2.ZERO
		return
	var choice_index := 0
	if killed_positions.size() > 1:
		choice_index = int(randi()) % killed_positions.size()
	_scarlet_teleport_target = killed_positions[choice_index]
	_scarlet_teleport_ready = true

func _activate_rapunzel_burst() -> void:
	_apply_stun_to_enemies(4.0, -1.0, true)
	var heal_target := int(round(float(_max_health) * 0.75))
	if heal_target > 0:
		restore_health(heal_target)
	_spawn_support_burst_flash(Color(1.0, 0.94, 0.72, 0.92), 320.0, 0.65)

func _activate_crown_burst() -> void:
	_crown_aura_time_left = 0.0
	_crown_aura_tick_timer = 0.0
	var radius := float(special_attack_data.get("burst_radius", CROWN_BURST_RADIUS))
	if radius <= 0.0:
		radius = CROWN_BURST_RADIUS
	var base_damage := int(round(float(special_attack_data.get("burst_damage", CROWN_BURST_DAMAGE))))
	if base_damage <= 0:
		base_damage = CROWN_BURST_DAMAGE
	_spawn_support_burst_flash(Color(0.78, 0.52, 1.0, 0.85), min(radius * 0.6, 320.0), 0.55)
	_spawn_crown_burst_effect(radius)
	_apply_crown_burst_damage(global_position, radius, base_damage)


func _apply_crown_burst_damage(center: Vector2, radius: float, base_damage: int) -> void:
	if not get_tree() or radius <= 0.0 or base_damage <= 0:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		var distance := enemy_node.global_position.distance_to(center)
		if distance > radius:
			continue
		var falloff := 1.0 - (distance / radius) * (1.0 - CROWN_BURST_MIN_MULTIPLIER)
		falloff = clampf(falloff, CROWN_BURST_MIN_MULTIPLIER, 1.0)
		var damage: int = max(1, int(round(base_damage * falloff)))
		var dealt := 0
		if enemy_node.has_method("apply_damage"):
			var result: Variant = enemy_node.call("apply_damage", damage)
			if result is int:
				dealt = int(result)
			elif typeof(result) == TYPE_BOOL:
				dealt = damage if bool(result) else 0
			else:
				dealt = damage
		if dealt > 0:
			register_burst_hit(enemy_node)
			if get_parent():
				var enemy_effect := ExplosionEffectScript.new()
				enemy_effect.radius = max(80.0, radius * 0.25)
				enemy_effect.duration = 0.32
				enemy_effect.base_color = Color(0.96, 0.82, 0.4, 0.6)
				enemy_effect.glow_color = Color(0.82, 0.6, 1.0, 0.5)
				enemy_effect.core_color = Color(1.0, 0.95, 0.88, 0.78)
				get_parent().add_child(enemy_effect)
				enemy_effect.global_position = enemy_node.global_position

func _apply_snow_white_burst_damage(origin: Vector2, direction: Vector2, range_distance: float, cone_angle_degrees: float) -> void:
	if not get_tree():
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var forward := direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	var max_range: float = max(range_distance, 300.0)
	var half_angle := deg_to_rad(clampf(cone_angle_degrees, 5.0, 150.0) * 0.5)
	var damage_value: int = max(_calculate_burst_damage(4.2), _projectile_damage * 6)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		if not enemy_node.has_method("apply_damage"):
			continue
		var to_enemy := enemy_node.global_position - origin
		var distance := to_enemy.length()
		if distance <= 0.0 or distance > max_range:
			continue
		var angle_offset := forward.angle_to(to_enemy.normalized())
		if absf(angle_offset) > half_angle:
			continue
		var dealt := 0
		var result: Variant = enemy_node.call("apply_damage", damage_value)
		match typeof(result):
			TYPE_INT:
				dealt = int(result)
			TYPE_BOOL:
				dealt = damage_value if bool(result) else 0
			_:
				dealt = damage_value
		if dealt <= 0:
			continue
		register_burst_hit(enemy_node)
		_spawn_snow_white_enemy_flash(enemy_node.global_position, max_range)

func _spawn_snow_white_enemy_flash(impact_position: Vector2, beam_range: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var effect := ExplosionEffectScript.new()
	effect.radius = clampf(beam_range * 0.18, 140.0, 420.0)
	effect.duration = 0.45
	effect.base_color = Color(0.65, 0.82, 1.0, 0.6)
	effect.glow_color = Color(0.58, 0.78, 1.0, 0.55)
	effect.core_color = Color(1.0, 1.0, 1.0, 0.9)
	effect.shockwave_color = Color(0.78, 0.9, 1.0, 0.75)
	effect.spark_color = Color(0.92, 0.98, 1.0, 0.7)
	parent.add_child(effect)
	effect.global_position = impact_position

func _activate_sin_burst() -> void:
	var duration := float(special_attack_data.get("burst_duration", 6.0))
	if duration <= 0.0:
		duration = 6.0
	_clear_sin_burst_targets()
	var viewport_targets: Array = []
	if get_tree():
		var view_rect := _get_camera_view_rect()
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			if not (enemy is Node2D):
				continue
			var enemy_node := enemy as Node2D
			if not view_rect.has_point(enemy_node.global_position):
				continue
			viewport_targets.append(enemy_node)
	var now := Time.get_ticks_msec() * 0.001
	_sin_burst_end_time = now + duration if not viewport_targets.is_empty() else now
	for enemy_node in viewport_targets:
		var effect: Node2D = SinDebuffEffectScript.new()
		if effect:
			enemy_node.add_child(effect)
			effect.position = Vector2.ZERO
			effect.z_index = enemy_node.z_index + 5
		var target_data: Dictionary = {
			"enemy_ref": weakref(enemy_node),
			"next_damage_time": now,
			"next_heal_time": now + SIN_HEAL_INTERVAL
		}
		if effect:
			target_data["effect_ref"] = weakref(effect)
		_sin_burst_targets.append(target_data)
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
		_minigun_spin_progress = 0.0
		_minigun_spin_grace_left = 0.0
		_minigun_boost_time_left = 0.0
		if weapon_type == "Minigun" and _minigun_initial_fire_rate > 0.0:
			_apply_minigun_spin_stats(0.0)
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
		if weapon_type == "Assault Rifle":
			(projectile as BasicProjectileScript).trail_color = _derive_assault_rifle_trail_color(projectile.color)
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

func _resolve_audio_director() -> AudioDirector:
	if not get_tree():
		return null
	var root := get_tree().root
	var candidate := root.find_child("AudioDirector", true, false)
	if candidate and candidate is AudioDirector:
		return candidate
	return null

func _get_audio_director() -> AudioDirector:
	if _audio_director == null or not is_instance_valid(_audio_director):
		_audio_director = _resolve_audio_director()
	return _audio_director

func _record_stat(stat_key: String, amount: int) -> void:
	if not _achievement_service:
		_achievement_service = _resolve_achievement_service()
	if _achievement_service:
		_achievement_service.record_stat(stat_key, amount)

func _resolve_weapon_audio_key() -> String:
	if weapon_type.strip_edges() != "":
		return weapon_type
	if weapon_name.strip_edges() != "":
		return weapon_name
	return ""

func _play_weapon_fire_audio(is_special: bool) -> void:
	var director := _get_audio_director()
	if director == null:
		return
	var weapon_key := _resolve_weapon_audio_key()
	if weapon_key == "":
		return
	if weapon_key == "SMG" and is_special:
		if _smg_special_sound_played_this_frame:
			return
		_smg_special_sound_played_this_frame = true
	director.play_weapon_fire_sound(weapon_key, is_special)

func _play_weapon_reload_audio() -> void:
	var director := _get_audio_director()
	if director == null:
		return
	var weapon_key := _resolve_weapon_audio_key()
	if weapon_key == "":
		return
	director.play_weapon_reload_sound(weapon_key)

func _play_burst_voice() -> void:
	var director := _get_audio_director()
	if director == null:
		return
	var burst_name := _resolve_burst_voice_key()
	if burst_name == "":
		return
	director.play_burst_voice(burst_name)

func _resolve_burst_voice_key() -> String:
	if _character_code.strip_edges() != "":
		return _character_code
	if _current_profile:
		if _current_profile.has_method("get"):
			var raw_code: Variant = _current_profile.get("code_name")
			if raw_code != null and String(raw_code).strip_edges() != "":
				return String(raw_code).strip_edges().to_lower()
			var raw_display: Variant = _current_profile.get("display_name")
			if raw_display != null and String(raw_display).strip_edges() != "":
				return String(raw_display).strip_edges().to_lower().replace(" ", "-")
	return ""

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
	_minigun_spin_progress = 1.0
	_minigun_spin_grace_left = max(_minigun_spin_grace_time, _minigun_spin_grace_left)
	fire_rate = max(0.01, _base_fire_rate * fire_rate_multiplier)
	_projectile_damage = int(round(_base_projectile_damage * damage_multiplier))
	return true

func _reset_minigun_boost() -> void:
	if weapon_type != "Minigun":
		return
	_minigun_boost_time_left = 0.0
	_apply_minigun_spin_stats(_minigun_spin_ease(_minigun_spin_progress))

func _spawn_v_blast_effect(direction: Vector2, blast_range: float, blast_angle: float, blast_color: Color, origin: Vector2 = global_position) -> void:
	if not get_parent():
		return
	var parent := get_parent()
	var effect_duration: float = max(0.05, float(special_attack_data.get("blast_duration", 0.25)))
	var effect := ShotgunVBlastEffectScript.new()
	effect.duration = effect_duration
	effect.configure(direction, blast_range, blast_angle, blast_color)
	parent.add_child(effect)
	effect.global_position = origin

func _on_shotgun_special_hit(target: Node, projectile: Node, payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var forward: Vector2 = Vector2.ZERO
	if projectile and projectile.has_method("get_direction"):
		var dir_variant: Variant = projectile.call("get_direction")
		if dir_variant is Vector2:
			forward = (dir_variant as Vector2)
	if forward.length() == 0.0:
		forward = _get_aim_direction()
	if forward.length() == 0.0:
		forward = _last_move_direction
	forward = forward.normalized() if forward.length() > 0.0 else Vector2.RIGHT
	var blast_range: float = float(payload.get("blast_range", 400.0))
	var blast_angle: float = float(payload.get("blast_angle", 45.0))
	var origin_offset: float = float(payload.get("origin_offset", 30.0))
	var color := _color_from_variant(payload.get("color", Color(1.0, 0.4, 0.2, 1.0)), Color(1.0, 0.4, 0.2, 1.0))
	var impact_position := global_position
	if target is Node2D:
		impact_position = (target as Node2D).global_position
	elif projectile is Node2D:
		impact_position = (projectile as Node2D).global_position
	var blast_origin := impact_position - forward * origin_offset
	_spawn_v_blast_effect(forward, blast_range, blast_angle, color, blast_origin)
	var blast_damage := int(payload.get("blast_damage", _projectile_damage))
	if blast_damage > 0:
		_apply_v_blast_damage(blast_origin, forward, blast_range, blast_angle, blast_damage, target)

func _apply_v_blast_damage(origin: Vector2, direction: Vector2, blast_range: float, blast_angle: float, blast_damage: int, excluded_target: Node = null) -> void:
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
		if excluded_target != null and enemy == excluded_target:
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

func _derive_assault_rifle_trail_color(base_color: Color) -> Color:
	var offset: float = 50.0 / 255.0
	return Color(
		clampf(base_color.r - offset, 0.0, 1.0),
		clampf(base_color.g - offset, 0.0, 1.0),
		clampf(base_color.b - offset, 0.0, 1.0),
		0.85
	)

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
