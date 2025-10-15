extends Node2D
class_name SwordSlash

@export var owner_reference: Node2D = null
@export_range(0.05, 2.0, 0.01) var duration: float = 0.4
@export_range(20.0, 1000.0, 1.0) var slash_range: float = 300.0
@export_range(10.0, 180.0, 1.0) var arc_degrees: float = 90.0
@export var damage: int = 60
@export_range(-180.0, 180.0, 0.5) var relative_angle: float = 0.0
@export var core_color: Color = Color(0.62, 0.36, 0.95, 0.85)
@export var glow_color: Color = Color(0.3, 0.16, 0.55, 0.55)
@export var edge_color: Color = Color(0.9, 0.82, 1.0, 0.9)

var _age: float = 0.0
var _forward: Vector2 = Vector2.RIGHT
var _damaged_instances: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _hit_spark_spawned: bool = false
var _sparkle_seed: int = 0

var _visual: Node2D = null

const SwordSparkleScript := preload("res://src/effects/sword_sparkle.gd")
const SwordSlashVisualScene: PackedScene = preload("res://scenes/effects/visuals/sword/SwordSlashVisual.tscn")

func _ready() -> void:
	_rng.randomize()
	_sparkle_seed = int(randi())
	z_index = 40
	set_process(true)
	_ensure_visual()

func assign_owner(owner_node: Node2D) -> void:
	owner_reference = owner_node
	_refresh_orientation()

func set_forward_vector(direction: Vector2) -> void:
	if direction.length() == 0.0:
		_forward = Vector2.RIGHT
	else:
		_forward = direction.normalized()
	_refresh_orientation()

func set_colors(core: Color, edge: Color, glow: Color) -> void:
	core_color = Color(
		clampf(core.r * 1.08 + 0.06, 0.0, 1.0),
		clampf(core.g * 1.05 + 0.04, 0.0, 1.0),
		clampf(core.b * 1.12 + 0.05, 0.0, 1.0),
		clampf(core.a * 1.1 + 0.05, 0.0, 1.0)
	)
	edge_color = Color(
		clampf(edge.r * 1.02 + 0.08, 0.0, 1.0),
		clampf(edge.g * 1.02 + 0.06, 0.0, 1.0),
		clampf(edge.b * 1.05 + 0.04, 0.0, 1.0),
		clampf(edge.a * 1.05 + 0.05, 0.0, 1.0)
	)
	glow_color = Color(
		clampf(glow.r * 1.25 + 0.12, 0.0, 1.0),
		clampf(glow.g * 1.2 + 0.08, 0.0, 1.0),
		clampf(glow.b * 1.3 + 0.1, 0.0, 1.0),
		clampf(glow.a * 1.4 + 0.1, 0.0, 1.0)
	)

func refresh_immediate() -> void:
	_refresh_orientation()
	_update_visual_state()

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	if not _refresh_orientation():
		queue_free()
		return
	_apply_damage()
	_update_visual_state()

func _refresh_orientation() -> bool:
	if owner_reference == null or not is_instance_valid(owner_reference):
		return false
	var origin: Vector2 = owner_reference.get_gun_tip_position()
	global_position = origin
	var base_position: Vector2 = owner_reference.global_position
	var forward_vector: Vector2 = origin - base_position
	if forward_vector.length() > 0.01:
		_forward = forward_vector.normalized()
	rotation = _forward.angle() + deg_to_rad(relative_angle)
	return true

func _apply_damage() -> void:
	var wipe_progress: float = _compute_wipe_progress()
	if wipe_progress <= 0.0:
		return
	var current_range: float = slash_range * wipe_progress
	if current_range <= 4.0:
		return
	var half_arc: float = deg_to_rad(arc_degrees) * 0.5
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D) or not enemy.has_method("apply_damage"):
			continue
		var enemy_node := enemy as Node2D
		var instance_id := enemy_node.get_instance_id()
		if _damaged_instances.has(instance_id):
			continue
		var offset: Vector2 = enemy_node.global_position - global_position
		var distance: float = offset.length()
		if distance > current_range:
			continue
		var angle_to_enemy: float = offset.angle()
		var angle_diff: float = wrapf(angle_to_enemy - rotation, -PI, PI)
		if abs(angle_diff) > half_arc:
			continue
		_damaged_instances[instance_id] = true
		enemy_node.apply_damage(damage)
		if owner_reference and is_instance_valid(owner_reference) and owner_reference.has_method("register_burst_hit"):
			owner_reference.register_burst_hit(enemy_node)
		if not _hit_spark_spawned:
			_spawn_hit_spark(enemy_node.global_position)
			_hit_spark_spawned = true

func _compute_wipe_progress() -> float:
	var normalized: float = clampf(_age / maxf(duration, 0.001), 0.0, 1.0)
	return clampf(normalized * 1.6, 0.0, 1.0)

func _spawn_hit_spark(spark_pos: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var sparkle := SwordSparkleScript.new()
	sparkle.color = Color(edge_color.r, edge_color.g, edge_color.b, min(edge_color.a * 1.1, 1.0))
	sparkle.radius = clampf(slash_range * 0.18, 20.0, 64.0)
	sparkle.duration = 0.28
	sparkle.spin_speed = 9.0
	sparkle.pulse_scale = 0.36
	sparkle.z_as_relative = false
	sparkle.z_index = int(max(z_index + 10, 80))
	parent.add_child(sparkle)
	sparkle.global_position = spark_pos
	_update_visual_state()

func _ensure_visual() -> void:
	if _visual != null:
		return
	if SwordSlashVisualScene == null:
		return
	var instance := SwordSlashVisualScene.instantiate()
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
	var progress: float = clampf(_age / maxf(duration, 0.001), 0.0, 1.0)
	var wipe_progress: float = _compute_wipe_progress()
	var fade: float = pow(1.0 - progress, 1.2)
	_visual.call("update_visual", {
		"radius": slash_range,
		"arc_degrees": arc_degrees,
		"core_color": core_color,
		"edge_color": edge_color,
		"glow_color": glow_color,
		"fade": fade,
		"wipe_progress": wipe_progress,
		"sparkle_seed": _sparkle_seed,
		"sparkle_count": 6
	})
