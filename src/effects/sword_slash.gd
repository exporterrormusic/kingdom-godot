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

const SwordSparkleScript := preload("res://src/effects/sword_sparkle.gd")

func _ready() -> void:
	_rng.randomize()
	z_index = 40
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	set_process(true)
	queue_redraw()

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
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	if not _refresh_orientation():
		queue_free()
		return
	_apply_damage()
	queue_redraw()

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

func _draw() -> void:
	var progress: float = clampf(_age / maxf(duration, 0.001), 0.0, 1.0)
	var wipe_progress: float = _compute_wipe_progress()
	var fade: float = pow(1.0 - progress, 1.2)
	var outer_radius: float = slash_range * wipe_progress
	if outer_radius <= 2.0:
		return
	var layers := [
		{
			"outer": outer_radius * 1.2,
			"inner": outer_radius * 0.55,
			"color": Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * fade * 0.65)
		},
		{
			"outer": outer_radius * 1.05,
			"inner": outer_radius * 0.42,
			"color": Color(core_color.r, core_color.g, core_color.b, core_color.a * fade)
		},
		{
			"outer": outer_radius * 0.9,
			"inner": outer_radius * 0.2,
			"color": Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * fade * 0.9)
		}
	]
	for layer in layers:
		_draw_arc_segment(float(layer["outer"]), float(layer["inner"]), layer["color"])
	_draw_sparkle_lines(outer_radius, fade)

func _draw_arc_segment(outer_radius: float, inner_radius: float, color: Color) -> void:
	if outer_radius <= 0.5:
		return
	inner_radius = clampf(inner_radius, 0.0, outer_radius - 0.5)
	var half_arc: float = deg_to_rad(arc_degrees) * 0.5
	var segments: int = max(10, int(arc_degrees / 4.0))
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = -half_arc + t * (half_arc * 2.0)
		points.append(Vector2(cos(angle), sin(angle)) * outer_radius)
	for i in range(segments, -1, -1):
		var t: float = float(i) / float(segments)
		var angle: float = -half_arc + t * (half_arc * 2.0)
		points.append(Vector2(cos(angle), sin(angle)) * inner_radius)
	var colors := PackedColorArray()
	for _i in points:
		colors.append(color)
	draw_polygon(points, colors)

func _draw_sparkle_lines(outer_radius: float, fade: float) -> void:
	var half_arc: float = deg_to_rad(arc_degrees) * 0.5
	var sparkle_count: int = 6
	var sparkle_color := Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * fade)
	for i in range(sparkle_count):
		var t: float = float(i) / max(1.0, float(sparkle_count - 1))
		var angle: float = -half_arc + t * (half_arc * 2.0)
		var radius: float = lerpf(outer_radius * 0.35, outer_radius * 0.95, t)
		var center: Vector2 = Vector2(cos(angle), sin(angle)) * radius
		var size: float = lerpf(outer_radius * 0.08, outer_radius * 0.12, t)
		var dir := Vector2.RIGHT.rotated(angle)
		draw_line(center - dir * size, center + dir * size, sparkle_color, max(1.5, size * 0.08), true)
		var diag_dir := dir.rotated(PI * 0.5)
		draw_line(center - diag_dir * size * 0.6, center + diag_dir * size * 0.6, sparkle_color, max(1.2, size * 0.06), true)
