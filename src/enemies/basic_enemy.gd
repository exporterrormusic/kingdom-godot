extends CharacterBody2D
class_name BasicEnemy

const EnemySpriteSheet := preload("res://assets/images/Enemies/rapture1-sprite.png")
const ENEMY_COLUMNS := 3
const ENEMY_ROWS := 4
const ENEMY_SPRITE_SCALE := CharacterSpriteAnimator.DEFAULT_SCALE * (2.0 / 3.0)

signal defeated(enemy: BasicEnemy)
signal health_changed(current: int, max: int, delta: int)

@export var move_speed := 220.0
@export var max_health := 3
@export var arrival_tolerance := 12.0
@export var contact_damage := 10
@export_range(0.05, 2.5, 0.01) var contact_damage_cooldown := 0.6
@export var visual_tint: Color = Color(1, 1, 1, 1)
@export_range(0.1, 3.0, 0.05) var visual_scale_multiplier: float = 1.0
@export_range(0.2, 3.0, 0.05) var hurt_flash_intensity: float = 1.0

var _current_health := 0
var _target: Node2D = null
@onready var _animator: CharacterSpriteAnimator = $CharacterSpriteAnimator
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

const STUN_TINT := Color(0.6, 0.82, 1.0, 1.0)

var _stun_time_left: float = 0.0
var _contact_timer: float = 0.0
var _tuning_data: Dictionary = {}
var _current_visual_scale: float = 1.0
var _base_modulate: Color = Color(1, 1, 1, 1)

func _ready() -> void:
	_current_health = max_health
	add_to_group("enemies")
	if _animator:
		_animator.configure(EnemySpriteSheet, ENEMY_COLUMNS, ENEMY_ROWS, 6.0, ENEMY_SPRITE_SCALE)
		_update_collision_shape()
		_apply_visual_customizations()
	emit_health_state()

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

func _has_property(property_name: String) -> bool:
	for property_data in get_property_list():
		if property_data.has("name") and property_data["name"] == property_name:
			return true
	return false
