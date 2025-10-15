extends Node2D
class_name SwordBeam

@export var owner_reference: Node2D = null
@export_range(10.0, 1400.0, 1.0) var beam_range: float = 500.0
@export_range(4.0, 120.0, 0.5) var beam_width: float = 18.0
@export_range(1, 2000, 1) var damage: int = 80
@export_range(0.05, 2.0, 0.01) var duration: float = 0.4
@export var color: Color = Color(0.39, 1.0, 0.78, 0.95)
@export_range(-180.0, 180.0, 0.5) var relative_angle: float = 0.0

var _elapsed: float = 0.0
var _forward: Vector2 = Vector2.RIGHT
var _damaged_enemies: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _visual_seed: int = 0
var _visual: Node2D = null

const SwordSparkleScript := preload("res://src/effects/sword_sparkle.gd")
const SwordBeamVisualScene: PackedScene = preload("res://scenes/effects/visuals/sword/SwordBeamVisual.tscn")

func _ready() -> void:
	_rng.randomize()
	_visual_seed = int(_rng.randi())
	set_process(true)
	_ensure_visual()

func _process(delta: float) -> void:
	_elapsed += delta
	if not _update_transform():
		queue_free()
		return
	if _elapsed >= duration:
		queue_free()
		return
	_apply_damage()
	_update_visual_state()

func _update_transform() -> bool:
	if owner_reference == null or not is_instance_valid(owner_reference):
		return false
	var origin: Vector2 = owner_reference.global_position
	var aim: Vector2 = Vector2.ZERO
	if owner_reference.has_method("get_gun_tip_position"):
		var tip_variant: Variant = owner_reference.call("get_gun_tip_position")
		if tip_variant is Vector2:
			origin = tip_variant
	if owner_reference.has_method("_get_aim_direction"):
		var aim_variant: Variant = owner_reference.call("_get_aim_direction")
		if aim_variant is Vector2 and Vector2(aim_variant).length() > 0.0:
			aim = Vector2(aim_variant)
	if aim.length() == 0.0:
		if owner_reference is Node2D:
			var owner_node := owner_reference as Node2D
			var to_origin := origin - owner_node.global_position
			if to_origin.length() > 0.01:
				aim = to_origin.normalized()
	if aim.length() == 0.0:
		aim = Vector2.RIGHT
	_forward = aim.normalized()
	global_position = origin
	rotation = _forward.angle() + deg_to_rad(relative_angle)
	return true

func _compute_activation_progress() -> float:
	var ramp_duration := maxf(duration * 0.3, 0.001)
	return clampf(_elapsed / ramp_duration, 0.0, 1.0)

func _apply_damage() -> void:
	var active_length: float = beam_range * _compute_activation_progress()
	if active_length <= 0.0:
		return
	var start_world: Vector2 = global_position
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D) or not enemy.has_method("apply_damage"):
			continue
		var enemy_node := enemy as Node2D
		var to_enemy: Vector2 = enemy_node.global_position - start_world
		var projection: float = _forward.dot(to_enemy)
		if projection < 0.0 or projection > active_length:
			continue
		var closest_point: Vector2 = start_world + _forward * projection
		var distance: float = enemy_node.global_position.distance_to(closest_point)
		var enemy_radius: float = _resolve_enemy_radius(enemy_node)
		var beam_radius: float = beam_width * 0.5
		if distance <= beam_radius + enemy_radius:
			var enemy_id := enemy_node.get_instance_id()
			if _damaged_enemies.has(enemy_id):
				continue
			enemy_node.apply_damage(damage)
			_damaged_enemies[enemy_id] = true
			if owner_reference and is_instance_valid(owner_reference) and owner_reference.has_method("register_burst_hit"):
				owner_reference.register_burst_hit(enemy_node)
			_spawn_hit_spark(enemy_node.global_position)

func _resolve_enemy_radius(enemy: Node2D) -> float:
	if enemy.has_method("get_collision_radius"):
		var result: Variant = enemy.call("get_collision_radius")
		if result is float or result is int:
			return maxf(float(result), 12.0)
	var rect := enemy.get_node_or_null("CollisionShape2D")
	if rect and rect is CollisionShape2D:
		var shape: Shape2D = (rect as CollisionShape2D).shape
		if shape is CircleShape2D:
			return maxf((shape as CircleShape2D).radius, 12.0)
	return 18.0
func _spawn_hit_spark(impact_position: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var sparkle := SwordSparkleScript.new()
	sparkle.color = Color(color.r, color.g, color.b, minf(color.a * 1.1, 1.0))
	sparkle.radius = maxf(beam_width * 2.2, 48.0)
	sparkle.duration = 0.32
	sparkle.spin_speed = 8.0
	sparkle.pulse_scale = 0.4
	sparkle.z_as_relative = false
	sparkle.z_index = int(max(z_index + 10, 80))
	parent.add_child(sparkle)
	sparkle.global_position = impact_position

func _ensure_visual() -> void:
	if _visual != null:
		return
	if SwordBeamVisualScene == null:
		return
	var instance := SwordBeamVisualScene.instantiate()
	if instance == null:
		return
	if not instance.has_method("update_visual"):
		instance.queue_free()
		return
	_visual = instance
	_visual.z_index = z_index
	_visual.z_as_relative = false
	add_child(_visual)
	_update_visual_state()

func _update_visual_state() -> void:
	if _visual == null:
		return
	if not _visual.has_method("update_visual"):
		return
	var activation: float = _compute_activation_progress()
	var active_length: float = beam_range * activation
	var lifetime_ratio: float = clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var fade: float = maxf(0.3, 1.0 - lifetime_ratio * 0.65)
	_visual.call("update_visual", {
		"active_length": active_length,
		"beam_width": beam_width,
		"color": color,
		"fade": fade,
		"activation": activation,
		"lifetime_ratio": lifetime_ratio,
		"seed": _visual_seed,
		"time": _elapsed
	})
