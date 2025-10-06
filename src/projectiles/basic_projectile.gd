extends Area2D
class_name BasicProjectile

@export var speed := 1200.0
@export var lifetime := 0.75
@export var color := Color(1, 0.9, 0.4, 1)
@export var radius := 4.0
@export var damage := 1
@export var penetration := 1
@export var max_range := 800.0
@export var shape := "standard"
@export var bounce_enabled := false
@export var max_bounces := 0
@export var bounce_range := 0.0
@export var enemy_targeting := false
@export var trail_enabled := false
@export var trail_interval := 48.0
@export var trail_duration := 1.5
@export var trail_damage := 0
@export var trail_color := Color(1.0, 0.4, 0.1, 0.65)
@export var owner_reference: Node = null

var _direction: Vector2 = Vector2.RIGHT
var _age := 0.0
var _is_retired := false
var _remaining_penetration := 1
var _distance_travelled := 0.0
var _hit_instances: Dictionary = {}
var _bounces_remaining := 0
var _distance_since_trail := 0.0
var _impact_callback: Callable = Callable()
var _impact_payload: Dictionary = {}

const GroundFireScript := preload("res://src/effects/ground_fire.gd")
const SniperTrailSegmentScript := preload("res://src/effects/sniper_trail_segment.gd")

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
var _last_collision_radius: float = -1.0

func _ready() -> void:
	if _direction == Vector2.ZERO:
		_direction = Vector2.RIGHT
	_remaining_penetration = max(1, penetration)
	_bounces_remaining = max(0, max_bounces)
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("area_entered", Callable(self, "_on_area_entered"))
	set_process(true)
	_update_collision_shape_radius()
	queue_redraw()

func set_direction(direction: Vector2) -> void:
	if direction.length() == 0.0:
		_direction = Vector2.RIGHT
	else:
		_direction = direction.normalized()
	queue_redraw()

func _update_collision_shape_radius() -> void:
	if _collision_shape == null:
		return
	var circle_shape := _collision_shape.shape
	if circle_shape is CircleShape2D:
		var cast_shape := circle_shape as CircleShape2D
		if abs(radius - _last_collision_radius) > 0.01:
			cast_shape.radius = radius
			_last_collision_radius = radius

func set_owner_reference(new_owner: Node) -> void:
	owner_reference = new_owner

func set_impact_callback(callback: Callable, payload: Dictionary = {}) -> void:
	_impact_callback = callback
	_impact_payload = payload.duplicate(true) if not payload.is_empty() else {}

func _physics_process(delta: float) -> void:
	if _is_retired:
		return
	_update_collision_shape_radius()
	var displacement := _direction * speed * delta
	position += displacement
	_distance_travelled += displacement.length()
	if trail_enabled:
		_distance_since_trail += displacement.length()
		if _distance_since_trail >= trail_interval:
			_distance_since_trail = 0.0
			_spawn_trail_segment()
	_age += delta
	var should_retire := false
	if lifetime > 0.0 and _age >= lifetime:
		should_retire = true
	if max_range > 0.0 and _distance_travelled >= max_range:
		should_retire = true
	if should_retire:
		_impact()
		return
	queue_redraw()

func _draw() -> void:
	match shape.to_lower():
		"laser":
			_draw_sniper_laser()
		"tracer":
			draw_line(Vector2(-radius, 0), Vector2(radius, 0), color, max(1.0, radius * 0.5))
		"rocket":
			draw_circle(Vector2.ZERO, radius, color)
			draw_circle(Vector2(-radius * 0.6, 0), radius * 0.6, color.darkened(0.25))
		_:
			draw_circle(Vector2.ZERO, radius, color)

func _draw_sniper_laser() -> void:
	var forward := _direction
	if forward.length_squared() == 0.0:
		forward = Vector2.RIGHT
	else:
		forward = forward.normalized()
	var perp := Vector2(-forward.y, forward.x)
	var beam_length := float(max(radius * 75.0, 480.0))
	var base_width := float(max(radius * 2.0, 20.0))
	var body_start := -forward * beam_length * 0.06
	var body_end := forward * beam_length * 0.78
	var tail_tip := body_start - forward * (base_width * 0.85 + beam_length * 0.06)
	var nose_tip := body_end + forward * (base_width * 0.95 + beam_length * 0.08)
	var back_shoulder := body_start + forward * base_width * 0.22
	var front_shoulder := body_end - forward * base_width * 0.1
	var target_blue := Color(0.58, 0.82, 1.0, 1.0)
	var sheath_color := color.lerp(target_blue, 0.72)
	sheath_color.a = 0.9
	var halo_color := Color(0.4, 0.72, 1.0, 0.22)
	var flicker := 0.78 + 0.22 * sin(_age * 10.2)
	_draw_beam_glow(tail_tip, nose_tip, base_width, halo_color, flicker)
	_draw_diamond_layer(tail_tip, back_shoulder, front_shoulder, nose_tip, forward, perp, base_width, sheath_color, flicker)
	var core_color := target_blue.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.5)
	core_color.a = 0.9
	var inner_color := Color(0.94, 0.99, 1.0, 0.95)
	_draw_core_spine(back_shoulder, front_shoulder, forward, base_width, core_color, inner_color)
	_draw_tip_flare(nose_tip, forward, perp, base_width, inner_color, sheath_color)
	_draw_tail_flare(tail_tip, forward, perp, base_width, halo_color)
	_draw_energy_crackle(back_shoulder, front_shoulder, forward, perp, base_width * 0.82)

func _draw_beam_glow(tail_tip: Vector2, nose_tip: Vector2, base_width: float, halo_color: Color, flicker: float) -> void:
	var steps := 3
	for i in range(steps):
		var t: float = 0.0
		if steps > 1:
			t = float(i) / float(steps - 1)
		var width: float = lerp(base_width * 2.9, base_width * 1.4, t)
		var alpha: float = clampf(halo_color.a * lerp(0.55, 0.12, t) * flicker, 0.02, 0.65)
		var glow := Color(halo_color.r, halo_color.g, halo_color.b, alpha)
		draw_line(tail_tip, nose_tip, glow, width, true)

func _draw_diamond_layer(tail_tip: Vector2, back_shoulder: Vector2, front_shoulder: Vector2, nose_tip: Vector2, forward: Vector2, perp: Vector2, base_width: float, sheath_color: Color, flicker: float) -> void:
	var mid_point := back_shoulder.lerp(front_shoulder, 0.5)
	var shoulder_half := base_width * 0.54
	var mid_half := base_width * 0.48
	var front_half := base_width * 0.34
	var points := PackedVector2Array([
		tail_tip,
		back_shoulder - perp * shoulder_half,
		mid_point - perp * mid_half,
		front_shoulder - perp * front_half,
		nose_tip,
		front_shoulder + perp * front_half,
		mid_point + perp * mid_half,
		back_shoulder + perp * shoulder_half
	])
	var colors := PackedColorArray([
		Color(sheath_color.r, sheath_color.g, sheath_color.b, sheath_color.a * 0.05),
		Color(sheath_color.r, sheath_color.g, sheath_color.b, sheath_color.a * 0.92),
		Color(sheath_color.r, sheath_color.g, sheath_color.b, sheath_color.a),
		Color(sheath_color.r, sheath_color.g, sheath_color.b, sheath_color.a * 0.94),
		Color(sheath_color.r, sheath_color.g, sheath_color.b, sheath_color.a * 0.28 * flicker),
		Color(sheath_color.r, sheath_color.g, sheath_color.b, sheath_color.a * 0.94),
		Color(sheath_color.r, sheath_color.g, sheath_color.b, sheath_color.a),
		Color(sheath_color.r, sheath_color.g, sheath_color.b, sheath_color.a * 0.92)
	])
	draw_polygon(points, colors)
	var inner_tail := tail_tip + forward * base_width * 0.24
	var inner_mid := back_shoulder.lerp(front_shoulder, 0.5)
	var inner_half := base_width * 0.26
	var inner_front_half := base_width * 0.18
	var bright_color := Color(0.92, 0.98, 1.0, clampf(0.62 * flicker, 0.25, 0.7))
	var inner_points := PackedVector2Array([
		inner_tail,
		back_shoulder - perp * inner_half,
		inner_mid - perp * (inner_half * 0.85),
		front_shoulder - perp * inner_front_half,
		nose_tip,
		front_shoulder + perp * inner_front_half,
		inner_mid + perp * (inner_half * 0.85),
		back_shoulder + perp * inner_half
	])
	var inner_colors := PackedColorArray([
		Color(bright_color.r, bright_color.g, bright_color.b, bright_color.a * 0.12),
		bright_color,
		Color(bright_color.r, bright_color.g, bright_color.b, clampf(bright_color.a * 1.05, 0.0, 1.0)),
		Color(bright_color.r, bright_color.g, bright_color.b, clampf(bright_color.a * 0.88, 0.0, 1.0)),
		Color(bright_color.r, bright_color.g, bright_color.b, clampf(bright_color.a * 0.36, 0.0, 1.0)),
		Color(bright_color.r, bright_color.g, bright_color.b, clampf(bright_color.a * 0.88, 0.0, 1.0)),
		Color(bright_color.r, bright_color.g, bright_color.b, clampf(bright_color.a * 1.05, 0.0, 1.0)),
		bright_color
	])
	draw_polygon(inner_points, inner_colors)

func _draw_core_spine(back_shoulder: Vector2, front_shoulder: Vector2, forward: Vector2, base_width: float, core_color: Color, inner_color: Color) -> void:
	var mid := back_shoulder.lerp(front_shoulder, 0.5)
	var core_points := PackedVector2Array([
		back_shoulder,
		mid,
		front_shoulder
	])
	var core_colors := PackedColorArray([
		Color(core_color.r, core_color.g, core_color.b, core_color.a * 0.4),
		core_color,
		Color(core_color.r, core_color.g, core_color.b, core_color.a * 0.4)
	])
	draw_polyline_colors(core_points, core_colors, base_width * 0.24, true)
	var inner_points := PackedVector2Array([
		back_shoulder + forward * base_width * 0.12,
		front_shoulder - forward * base_width * 0.05
	])
	var inner_colors := PackedColorArray([
		Color(inner_color.r, inner_color.g, inner_color.b, inner_color.a * 0.6),
		Color(inner_color.r, inner_color.g, inner_color.b, inner_color.a * 0.45)
	])
	draw_polyline_colors(inner_points, inner_colors, base_width * 0.12, true)

func _draw_tip_flare(nose_tip: Vector2, forward: Vector2, perp: Vector2, base_width: float, inner_color: Color, sheath_color: Color) -> void:
	var tip_color := Color(inner_color.r, inner_color.g, inner_color.b, clampf(inner_color.a * 1.05, 0.0, 1.0))
	var sheath := Color(sheath_color.r, sheath_color.g, sheath_color.b, clampf(sheath_color.a * 1.15, 0.0, 1.0))
	var triangle := PackedVector2Array([
		nose_tip,
		nose_tip - forward * base_width * 0.72 + perp * base_width * 0.22,
		nose_tip - forward * base_width * 0.72 - perp * base_width * 0.22
	])
	var colors := PackedColorArray([
		tip_color,
		sheath,
		sheath
	])
	draw_polygon(triangle, colors)
	draw_circle(nose_tip, base_width * 0.24, tip_color)

func _draw_tail_flare(tail_tip: Vector2, forward: Vector2, perp: Vector2, base_width: float, halo_color: Color) -> void:
	var tail_color := Color(halo_color.r, halo_color.g, halo_color.b, clampf(halo_color.a * 1.8, 0.0, 0.55))
	var triangle := PackedVector2Array([
		tail_tip,
		tail_tip + forward * base_width * 0.68 + perp * base_width * 0.2,
		tail_tip + forward * base_width * 0.68 - perp * base_width * 0.2
	])
	var tail_colors := PackedColorArray([
		tail_color,
		Color(tail_color.r, tail_color.g, tail_color.b, tail_color.a * 0.35),
		Color(tail_color.r, tail_color.g, tail_color.b, tail_color.a * 0.35)
	])
	draw_polygon(triangle, tail_colors)
	draw_circle(tail_tip + forward * base_width * 0.32, base_width * 0.22, Color(tail_color.r, tail_color.g, tail_color.b, tail_color.a * 0.5))

func _draw_energy_crackle(start: Vector2, finish: Vector2, forward: Vector2, perp: Vector2, base_width: float) -> void:
	var length := (finish - start).length()
	if length <= 0.0:
		return
	var segments := 6
	for i in range(segments):
		var phase := _age * 9.5 + float(i) * 0.9
		var t := fposmod(phase, 1.0)
		var center := start + forward * (length * t)
		var variance := sin(_age * 16.0 + float(i) * 2.5)
		var span := base_width * (0.22 + 0.16 * float(i % 3))
		var offset := perp * span * variance
		var alpha := clampf(0.48 + 0.22 * abs(cos(phase * 2.3)), 0.36, 0.86)
		var arc_color := Color(0.72, 0.9, 1.0, alpha)
		draw_line(center - offset, center + offset, arc_color, max(1.0, base_width * 0.06))
		draw_circle(center + offset * 0.1, base_width * 0.12, Color(0.9, 0.97, 1.0, 0.6))

func _on_body_entered(body: Node) -> void:
	_apply_damage_to(body)

func _on_area_entered(area: Area2D) -> void:
	_apply_damage_to(area)

func _apply_damage_to(target: Node) -> void:
	if _is_retired:
		return
	if not is_instance_valid(target):
		return
	if target == get_parent():
		return
	var instance_id := target.get_instance_id()
	if _hit_instances.has(instance_id):
		return
	_hit_instances[instance_id] = true
	if target.has_method("apply_damage"):
		target.apply_damage(damage)
		if owner_reference and is_instance_valid(owner_reference) and owner_reference.has_method("register_burst_hit"):
			owner_reference.register_burst_hit(target)
	if _impact_callback.is_valid():
		_impact_callback.call_deferred(target, self, _impact_payload)
	_remaining_penetration = max(0, _remaining_penetration - 1)
	var bounced := false
	if bounce_enabled and _bounces_remaining > 0:
		bounced = _attempt_bounce(instance_id)
	if not bounced and _remaining_penetration <= 0:
		_impact()

func _attempt_bounce(excluded_id: int) -> bool:
	_bounces_remaining -= 1
	var candidates := get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node2D = null
	var closest_distance := INF
	var effective_range := bounce_range if bounce_range > 0.0 else max_range
	for enemy in candidates:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D) or not enemy.has_method("apply_damage"):
			continue
		if enemy.get_instance_id() == excluded_id:
			continue
		var enemy_node := enemy as Node2D
		var distance := enemy_node.global_position.distance_to(global_position)
		if distance > effective_range:
			continue
		if _hit_instances.has(enemy_node.get_instance_id()) and not enemy_targeting:
			continue
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy_node
	if closest_enemy == null:
		return false
	_direction = (closest_enemy.global_position - global_position).normalized()
	if enemy_targeting:
		_hit_instances.erase(closest_enemy.get_instance_id())
	return true

func _spawn_trail_segment() -> void:
	if trail_damage <= 0:
		return
	if shape.to_lower() == "laser":
		var segment := SniperTrailSegmentScript.new()
		segment.radius = max(trail_interval * 0.55, 46.0)
		segment.damage_per_tick = trail_damage
		segment.duration = trail_duration
		segment.tick_interval = 0.28
		var target_blue := Color(0.58, 0.82, 1.0, 1.0)
		var blended := trail_color.lerp(target_blue, 0.6)
		var strength := clampf(trail_color.a, 0.3, 1.0)
		segment.core_color = Color(0.88, 0.96, 1.0, 0.82 * strength)
		segment.glow_color = Color(blended.r, blended.g, blended.b, 0.46 * strength)
		segment.ring_color = Color(blended.r * 0.9 + 0.05, blended.g * 0.95, 1.0, 0.58 * strength)
		segment.global_position = global_position
		if get_parent():
			get_parent().add_child(segment)
		return
	var fire_node: Node2D = GroundFireScript.new()
	fire_node.set("radius", max(trail_interval * 0.6, 40.0))
	fire_node.set("damage_per_tick", trail_damage)
	fire_node.set("duration", trail_duration)
	fire_node.set("color", trail_color)
	var glow := Color(trail_color.r * 0.7 + 0.05, trail_color.g * 0.8 + 0.05, trail_color.b, clampf(trail_color.a * 0.6 + 0.1, 0.0, 1.0))
	var ember := Color(
		clampf(trail_color.r * 0.6 + 0.15, 0.0, 1.0),
		clampf(trail_color.g * 0.9 + 0.05, 0.0, 1.0),
		clampf(trail_color.b * 1.05, 0.0, 1.0),
		clampf(trail_color.a * 0.85 + 0.1, 0.0, 1.0)
	)
	var smoke := Color(trail_color.r * 0.4, trail_color.g * 0.5, trail_color.b * 0.8, 0.32)
	fire_node.set("glow_color", glow)
	fire_node.set("ember_color", ember)
	fire_node.set("smoke_color", smoke)
	fire_node.global_position = global_position
	if get_parent():
		get_parent().add_child(fire_node)

func _impact() -> void:
	if _is_retired:
		return
	_is_retired = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	queue_free()
