extends CharacterBody2D
class_name BasicEnemy

const EnemySpriteSheet := preload("res://assets/images/Enemies/rapture1-sprite.png")
const ENEMY_COLUMNS := 3
const ENEMY_ROWS := 4
const ENEMY_SPRITE_SCALE := CharacterSpriteAnimator.DEFAULT_SCALE * (2.0 / 3.0)
const EnemyDeathBurstScene := preload("res://scenes/effects/EnemyDeathBurst.tscn")
const EnemyDeathBurstScript: GDScript = preload("res://src/effects/enemy_death_burst.gd")
const BODY_GLOW_COLOR := Color(1.0, 0.36, 0.22, 1.0)
const BODY_GLOW_RIM_COLOR := Color(1.0, 0.84, 0.62, 1.0)
const GROUND_GLOW_COLOR := Color(1.0, 0.28, 0.15, 1.0)
const BODY_GLOW_BASE_ENERGY := 0.7
const GROUND_GLOW_BASE_ENERGY := 0.92
const BODY_GLOW_TEXTURE_SCALE := 1.22
const GROUND_GLOW_TEXTURE_SCALE := 1.6
const BODY_GLOW_MAX_ALPHA := 0.62
const GROUND_GLOW_MAX_ALPHA := 0.52
const BODY_GLOW_FALLOFF_POWER := 3.1
const GROUND_GLOW_FALLOFF_POWER := 2.45
const BODY_GLOW_LUMA_BIAS := 0.46
const BODY_GLOW_RIM_SOFTNESS := 0.22
const BODY_GLOW_PULSE_SPEED := 2.8
const BODY_GLOW_PULSE_AMPLITUDE := 0.16
const GLOW_TEXTURE_SIZE := 192
const GLOW_SHADER_PATH := "res://resources/shaders/enemy_dual_glow.gdshader"
const ENEMY_BODY_GLOW_Z_INDEX := 910
const ENEMY_GROUND_GLOW_Z_INDEX := 909

signal defeated(enemy: BasicEnemy)
signal health_changed(current: int, max: int, delta: int)

@export var move_speed := 100.0
@export var max_health := 40
@export var arrival_tolerance := 12.0
@export var contact_damage := 20
@export_range(0.05, 2.5, 0.01) var contact_damage_cooldown := 0.6
@export var visual_tint: Color = Color(1, 1, 1, 1)
@export_range(0.1, 3.0, 0.05) var visual_scale_multiplier: float = 1.0
@export_range(0.2, 3.0, 0.05) var hurt_flash_intensity: float = 1.0
@export_range(0.1, 4.0, 0.01) var body_glow_intensity: float = BODY_GLOW_BASE_ENERGY
@export_range(0.1, 4.0, 0.01) var ground_glow_intensity: float = GROUND_GLOW_BASE_ENERGY
@export_range(0.25, 2.5, 0.01) var glow_radius_multiplier: float = 0.85

var _current_health := 0
var _target: Node2D = null
@onready var _animator: CharacterSpriteAnimator = $CharacterSpriteAnimator
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _body_light: PointLight2D = $BodyGlow
@onready var _ground_light: PointLight2D = $GroundGlow
var _body_glow_sprite: Sprite2D = null
var _ground_glow_sprite: Sprite2D = null

static var _body_glow_texture: Texture2D = null
static var _ground_glow_texture: Texture2D = null
static var _glow_shader: Shader = null
static var _cached_environment: WeakRef = null

const STUN_TINT := Color(0.6, 0.82, 1.0, 1.0)

var _stun_time_left: float = 0.0
var _contact_timer: float = 0.0
var _tuning_data: Dictionary = {}
var _current_visual_scale: float = 1.0
var _base_modulate: Color = Color(1, 1, 1, 1)
var _environment_controller: EnvironmentController = null
var _body_glow_energy_scale: float = BODY_GLOW_BASE_ENERGY
var _ground_glow_energy_scale: float = GROUND_GLOW_BASE_ENERGY
var _body_glow_base_scale: Vector2 = Vector2.ZERO
var _ground_glow_base_scale: Vector2 = Vector2.ZERO
var _body_glow_base_height: float = 0.0
var _ground_glow_base_height: float = 0.0
var _body_glow_base_position: Vector2 = Vector2.ZERO
var _ground_glow_base_position: Vector2 = Vector2.ZERO
var _current_glow_radius_scale: float = 1.0
var _glow_exposure: float = 1.0

func _ready() -> void:
	_current_health = max_health
	add_to_group("enemies")
	if _animator:
		_animator.configure(EnemySpriteSheet, ENEMY_COLUMNS, ENEMY_ROWS, 6.0, ENEMY_SPRITE_SCALE)
		_update_collision_shape()
		_apply_visual_customizations()
	_init_glow_components()
	emit_health_state()

func _exit_tree() -> void:
	if _environment_controller and is_instance_valid(_environment_controller):
		var handler := Callable(self, "_on_environment_changed")
		if _environment_controller.environment_changed.is_connected(handler):
			_environment_controller.environment_changed.disconnect(handler)

func _update_collision_shape() -> void:
	if not _collision_shape or not _collision_shape.shape:
		return
	var texture_size: Vector2 = EnemySpriteSheet.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var frame_width: float = texture_size.x / float(ENEMY_COLUMNS)
	var frame_height: float = texture_size.y / float(ENEMY_ROWS)
	var scaled_frame: float = max(frame_width, frame_height) * ENEMY_SPRITE_SCALE * max(0.1, _current_visual_scale)
	if _collision_shape.shape is CircleShape2D:
		var circle := _collision_shape.shape as CircleShape2D
		circle.radius = max(6.0, scaled_frame / 3.0)

func set_target(target: Node2D) -> void:
	_target = target


func _physics_process(_delta: float) -> void:
	if _contact_timer > 0.0:
		_contact_timer = max(_contact_timer - _delta, 0.0)
	if _stun_time_left > 0.0:
		_stun_time_left = max(_stun_time_left - _delta, 0.0)
	velocity = Vector2.ZERO
	var aim_vector := Vector2.ZERO
	var stunned := _stun_time_left > 0.0
	if not stunned and _target and is_instance_valid(_target):
		var to_target := _target.global_position - global_position
		aim_vector = to_target
		if to_target.length() > arrival_tolerance:
			velocity = to_target.normalized() * move_speed
	if _animator:
		_animator.update_state(velocity, aim_vector)
		_animator.speed_scale = 0.0 if stunned else 1.0
		_animator.modulate = STUN_TINT if stunned else _base_modulate
	move_and_slide()
	if _contact_timer == 0.0:
		_attempt_contact_damage()

func apply_damage(amount: int) -> int:
	var damage: int = maxi(0, amount)
	if damage <= 0:
		return 0
	var previous := _current_health
	_current_health = maxi(0, _current_health - damage)
	var delta := _current_health - previous
	emit_health_state(delta)
	if _current_health <= 0:
		_spawn_death_effect()
		defeated.emit(self)
		queue_free()
	return -delta

func emit_health_state(delta: int = 0) -> void:
	emit_signal("health_changed", _current_health, max_health, delta)

func apply_tuning(tuning: Dictionary) -> void:
	if tuning.is_empty():
		return
	_tuning_data = tuning.duplicate(true)
	for key in tuning.keys():
		if _has_property(key):
			set(key, tuning[key])
	_apply_visual_customizations()
	if tuning.has("max_health"):
		_current_health = maxi(1, int(tuning.get("max_health", max_health)))
		emit_health_state()
	_init_glow_components()

func apply_stun(duration: float) -> void:
	var applied: float = max(duration, 0.0)
	if applied <= 0.0:
		return
	_stun_time_left = max(_stun_time_left, applied)

func is_stunned() -> bool:
	return _stun_time_left > 0.0

func _attempt_contact_damage() -> void:
	if contact_damage <= 0:
		return
	if not _target or not is_instance_valid(_target):
		return
	var distance := global_position.distance_to(_target.global_position)
	var damage_radius = max(arrival_tolerance, 16.0)
	if distance > damage_radius:
		return
	if _target.has_method("apply_damage"):
		var dealt := int(_target.apply_damage(contact_damage))
		if dealt > 0:
			_contact_timer = contact_damage_cooldown

func _apply_visual_customizations() -> void:
	if not _animator:
		return
	var tint := visual_tint
	if _tuning_data.has("visual_modulate"):
		var modulate_variant = _tuning_data.get("visual_modulate")
		if modulate_variant is Color:
			tint = modulate_variant
		elif modulate_variant is Array:
			var arr := modulate_variant as Array
			if arr.size() >= 3:
				var alpha := 1.0
				if arr.size() > 3:
					alpha = arr[3]
				tint = Color(arr[0], arr[1], arr[2], alpha)
	_base_modulate = tint
	_animator.modulate = tint
	var scale_mul := visual_scale_multiplier
	if _tuning_data.has("scale_multiplier"):
		scale_mul = max(0.1, float(_tuning_data.get("scale_multiplier", scale_mul)))
	scale_mul = max(0.1, scale_mul)
	_current_visual_scale = scale_mul
	_animator.scale = Vector2.ONE * (ENEMY_SPRITE_SCALE * _current_visual_scale)
	_update_collision_shape()
	_update_glow_for_tint()

func _has_property(property_name: String) -> bool:
	for property_data in get_property_list():
		if property_data.has("name") and property_data["name"] == property_name:
			return true
	return false

func _init_glow_components() -> void:
	if not is_inside_tree():
		return
	_ensure_glow_resources()
	_body_glow_energy_scale = body_glow_intensity
	_ground_glow_energy_scale = ground_glow_intensity
	if _body_light:
		_body_light.z_as_relative = false
		_body_light.z_index = ENEMY_BODY_GLOW_Z_INDEX
		_body_glow_base_scale = _body_light.scale
		_body_glow_base_height = _body_light.height
		_body_glow_base_position = _body_light.position
	if _ground_light:
		_ground_light.z_as_relative = false
		_ground_light.z_index = ENEMY_GROUND_GLOW_Z_INDEX
		_ground_glow_base_scale = _ground_light.scale
		_ground_glow_base_height = _ground_light.height
		_ground_glow_base_position = _ground_light.position
	_ensure_glow_sprites()
	_apply_glow_material()
	_apply_glow_textures()
	_connect_environment_controller()
	_apply_environment_lighting()

func _ensure_glow_resources() -> void:
	if _glow_shader == null:
		var shader_resource := load(GLOW_SHADER_PATH)
		if shader_resource and shader_resource is Shader:
			_glow_shader = shader_resource
	if _body_glow_texture == null:
		_body_glow_texture = _create_radial_glow_texture(BODY_GLOW_COLOR, BODY_GLOW_FALLOFF_POWER, BODY_GLOW_MAX_ALPHA)
	if _ground_glow_texture == null:
		_ground_glow_texture = _create_radial_glow_texture(GROUND_GLOW_COLOR, GROUND_GLOW_FALLOFF_POWER, GROUND_GLOW_MAX_ALPHA)

func _apply_glow_material() -> void:
	if not _animator or _glow_shader == null:
		return
	var shader_material := ShaderMaterial.new()
	shader_material.shader = _glow_shader
	shader_material.set_shader_parameter("core_tint", BODY_GLOW_COLOR)
	shader_material.set_shader_parameter("rim_tint", BODY_GLOW_RIM_COLOR)
	shader_material.set_shader_parameter("glow_strength", 1.0)
	shader_material.set_shader_parameter("rim_strength", 0.85)
	shader_material.set_shader_parameter("luma_bias", BODY_GLOW_LUMA_BIAS)
	shader_material.set_shader_parameter("rim_softness", BODY_GLOW_RIM_SOFTNESS)
	shader_material.set_shader_parameter("pulse_speed", BODY_GLOW_PULSE_SPEED)
	shader_material.set_shader_parameter("pulse_amplitude", BODY_GLOW_PULSE_AMPLITUDE)
	_animator.material = shader_material
	_update_glow_for_tint()

func _apply_glow_textures() -> void:
	var radius_scale := clampf(glow_radius_multiplier, 0.25, 3.0)
	_current_glow_radius_scale = radius_scale
	if _body_light:
		if _body_glow_base_scale == Vector2.ZERO:
			_body_glow_base_scale = Vector2.ONE
		_body_light.texture = _body_glow_texture
		_body_light.color = BODY_GLOW_COLOR
		_body_light.energy = _body_glow_energy_scale
		_body_light.texture_scale = BODY_GLOW_TEXTURE_SCALE * radius_scale
		_body_light.scale = _body_glow_base_scale * clampf(radius_scale, 0.6, 2.2)
		_body_light.height = _body_glow_base_height
		_body_light.shadow_enabled = false
	if _ground_light:
		if _ground_glow_base_scale == Vector2.ZERO:
			_ground_glow_base_scale = Vector2.ONE
		_ground_light.texture = _ground_glow_texture
		_ground_light.color = GROUND_GLOW_COLOR
		_ground_light.energy = _ground_glow_energy_scale
		_ground_light.texture_scale = GROUND_GLOW_TEXTURE_SCALE * radius_scale
		_ground_light.scale = _ground_glow_base_scale * clampf(radius_scale, 0.7, 2.5)
		_ground_light.height = _ground_glow_base_height
		_ground_light.shadow_enabled = false
	_refresh_glow_sprites()

func _update_glow_for_tint() -> void:
	if not _animator:
		return
	if _animator.material and _animator.material is ShaderMaterial:
		var mat := _animator.material as ShaderMaterial
		var core := BODY_GLOW_COLOR.lerp(_base_modulate, 0.35)
		var rim := BODY_GLOW_RIM_COLOR.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.25).lerp(_base_modulate, 0.18)
		mat.set_shader_parameter("core_tint", core)
		mat.set_shader_parameter("rim_tint", rim)
	if _body_light:
		_body_light.color = BODY_GLOW_COLOR.lerp(_base_modulate, 0.28)
	if _ground_light:
		_ground_light.color = GROUND_GLOW_COLOR.lerp(_base_modulate, 0.22)
	_refresh_glow_sprites()

func _connect_environment_controller() -> void:
	_environment_controller = _locate_environment_controller()
	if not _environment_controller:
		return
	var handler := Callable(self, "_on_environment_changed")
	if not _environment_controller.environment_changed.is_connected(handler):
		_environment_controller.environment_changed.connect(handler)

func _apply_environment_lighting() -> void:
	var exposure := 1.0
	if _environment_controller and is_instance_valid(_environment_controller):
		var time_def := _environment_controller.get_active_time_of_day()
		if time_def:
			var ambient: float = clampf(time_def.ambient_intensity, 0.0, 2.0)
			var darkness: float = clampf(1.05 - ambient, 0.0, 1.0)
			exposure = lerpf(0.7, 1.45, darkness)
	if _body_light:
		_body_light.energy = _body_glow_energy_scale * exposure
	if _ground_light:
		_ground_light.energy = _ground_glow_energy_scale * exposure
	if _animator and _animator.material is ShaderMaterial:
		var mat := _animator.material as ShaderMaterial
		var base_strength := clampf(0.95 + (_body_glow_energy_scale - BODY_GLOW_BASE_ENERGY) * 0.45, 0.6, 1.6)
		var rim_strength := clampf(0.85 + (_ground_glow_energy_scale - GROUND_GLOW_BASE_ENERGY) * 0.35, 0.55, 1.7)
		mat.set_shader_parameter("glow_strength", base_strength * clampf(0.8 + (exposure - 1.0) * 0.55, 0.5, 1.8))
		mat.set_shader_parameter("rim_strength", rim_strength * clampf(0.85 + (exposure - 1.0) * 0.45, 0.5, 1.9))
	_glow_exposure = exposure
	_refresh_glow_sprites()

func _on_environment_changed(_biome_id: StringName, _time_id: StringName) -> void:
	_apply_environment_lighting()

func _ensure_glow_sprites() -> void:
	if not is_inside_tree():
		return
	if _body_glow_sprite == null or not is_instance_valid(_body_glow_sprite):
		_body_glow_sprite = _create_glow_sprite("BodyGlowSprite", ENEMY_BODY_GLOW_Z_INDEX)
	if _ground_glow_sprite == null or not is_instance_valid(_ground_glow_sprite):
		_ground_glow_sprite = _create_glow_sprite("GroundGlowSprite", ENEMY_GROUND_GLOW_Z_INDEX)
	_refresh_glow_sprites()

func _create_glow_sprite(node_name: String, z_index_value: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.z_as_relative = false
	sprite.z_index = z_index_value
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = mat
	sprite.visible = false
	add_child(sprite)
	return sprite

func _refresh_glow_sprites() -> void:
	if not is_inside_tree():
		return
	var radius_scale := _current_glow_radius_scale
	var exposure := _glow_exposure
	if _body_glow_sprite:
		if _body_glow_texture:
			_body_glow_sprite.texture = _body_glow_texture
		var base_scale := _body_glow_base_scale
		if base_scale == Vector2.ZERO:
			base_scale = Vector2.ONE
		_body_glow_sprite.scale = base_scale * clampf(radius_scale, 0.6, 2.2)
		_body_glow_sprite.position = _body_glow_base_position
		var body_color := BODY_GLOW_COLOR.lerp(_base_modulate, 0.28)
		body_color.a = clampf(BODY_GLOW_MAX_ALPHA * _body_glow_energy_scale * exposure, 0.0, 1.0)
		_body_glow_sprite.modulate = body_color
		_body_glow_sprite.visible = body_color.a > 0.01
	if _ground_glow_sprite:
		if _ground_glow_texture:
			_ground_glow_sprite.texture = _ground_glow_texture
		var ground_scale := _ground_glow_base_scale
		if ground_scale == Vector2.ZERO:
			ground_scale = Vector2.ONE
		_ground_glow_sprite.scale = ground_scale * clampf(radius_scale, 0.7, 2.5)
		_ground_glow_sprite.position = _ground_glow_base_position
		var ground_color := GROUND_GLOW_COLOR.lerp(_base_modulate, 0.22)
		ground_color.a = clampf(GROUND_GLOW_MAX_ALPHA * _ground_glow_energy_scale * exposure, 0.0, 1.0)
		_ground_glow_sprite.modulate = ground_color
		_ground_glow_sprite.visible = ground_color.a > 0.01

func _locate_environment_controller() -> EnvironmentController:
	if _cached_environment:
		var cached: Object = (_cached_environment as WeakRef).get_ref()
		if cached and cached is EnvironmentController and is_instance_valid(cached):
			return cached as EnvironmentController
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	var found := _find_environment_recursive(tree.root)
	if found:
		_cached_environment = weakref(found)
	return found

func _find_environment_recursive(node: Node) -> EnvironmentController:
	if node is EnvironmentController:
		return node
	for child in node.get_children():
		var candidate := _find_environment_recursive(child)
		if candidate:
			return candidate
	return null

func _create_enemy_death_burst() -> EnemyDeathBurst:
	if EnemyDeathBurstScene:
		var instance := EnemyDeathBurstScene.instantiate()
		if instance is EnemyDeathBurst:
			return instance as EnemyDeathBurst
		instance.queue_free()
	if EnemyDeathBurstScript:
		return EnemyDeathBurstScript.new()
	return null

func _spawn_death_effect() -> void:
	if not get_parent():
		return
	var burst := _create_enemy_death_burst()
	if burst == null:
		return
	var primary := BODY_GLOW_COLOR.lerp(_base_modulate, 0.5)
	var accent := BODY_GLOW_RIM_COLOR.lerp(_base_modulate, 0.35)
	var effect_radius := 42.0 * _current_visual_scale * clampf(glow_radius_multiplier, 0.6, 1.4)
	if burst.has_method("configure"):
		burst.call("configure", primary, accent, effect_radius)
	burst.global_position = global_position
	get_parent().add_child(burst)


func _create_radial_glow_texture(color: Color, falloff_power: float, max_alpha: float) -> Texture2D:
	var image := Image.create(GLOW_TEXTURE_SIZE, GLOW_TEXTURE_SIZE, false, Image.FORMAT_RGBAF)
	var center := Vector2(GLOW_TEXTURE_SIZE - 1, GLOW_TEXTURE_SIZE - 1) * 0.5
	var max_radius: float = minf(center.x, center.y)
	for y in range(GLOW_TEXTURE_SIZE):
		for x in range(GLOW_TEXTURE_SIZE):
			var distance: float = Vector2(x, y).distance_to(center) / max_radius
			var normalized := clampf(1.0 - distance, 0.0, 1.0)
			if normalized <= 0.0:
				continue
			var alpha := pow(normalized, falloff_power) * max_alpha
			if alpha <= 0.001:
				continue
			var pixel := Color(color.r, color.g, color.b, alpha)
			image.set_pixel(x, y, pixel)
	var texture := ImageTexture.create_from_image(image)
	return texture
