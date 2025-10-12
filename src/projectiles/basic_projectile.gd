extends Area2D
class_name BasicProjectile

const BasicProjectileVisualResource := preload("res://src/projectiles/basic_projectile_visual.gd")

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
@export var special_attack: bool = false
@export var projectile_archetype: String = ""

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
var _visual: BasicProjectileVisual = null
var _has_bounced: bool = false
var _bounce_visuals_enabled: bool = false
var _trail_positions: Array = []
var _trail_distance_accumulator: float = 0.0
var _last_trail_sample: Vector2 = Vector2.ZERO
var _glow_enabled := false
var _glow_color: Color = Color(1.0, 1.0, 1.0, 1.0)
var _glow_energy := 1.0
var _glow_scale := 1.0
var _glow_height := 0.0

const TRAIL_SAMPLE_DISTANCE := 12.0
const MAX_TRAIL_POINTS := 36

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
	_last_trail_sample = global_position
	_append_trail_point(global_position)
	_bounce_visuals_enabled = projectile_archetype.to_lower() == "smg_special"
	_visual = BasicProjectileVisualResource.new()
	if _visual:
		add_child(_visual)
		_visual.setup(self, _bounce_visuals_enabled)
		_visual.set_trail_enabled(trail_enabled)
		_apply_glow_to_visual()
	_sync_visual_state()

func set_direction(direction: Vector2) -> void:
	if direction.length() == 0.0:
		_direction = Vector2.RIGHT
	else:
		_direction = direction.normalized()
	_update_collision_shape_radius()
	queue_redraw()

func _update_collision_shape_radius() -> void:
	if _collision_shape == null:
		return
	if shape.to_lower() == "laser":
		_update_laser_collision_shape()
		return
	var circle_shape := _collision_shape.shape
	if circle_shape is CircleShape2D:
		var cast_shape := circle_shape as CircleShape2D
		if abs(radius - _last_collision_radius) > 0.01:
			cast_shape.radius = radius
			_last_collision_radius = radius
	else:
		var new_circle := CircleShape2D.new()
		new_circle.radius = radius
		_collision_shape.shape = new_circle
		_last_collision_radius = radius
	_collision_shape.position = Vector2.ZERO
	_collision_shape.rotation = 0.0

func _update_laser_collision_shape() -> void:
	if _collision_shape == null:
		return
	var dir := _direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var beam_length: float = _compute_laser_beam_length()
	var beam_half_length: float = beam_length * 0.5
	var beam_half_width: float = max(_compute_laser_beam_width() * 0.5, radius)
	if not (_collision_shape.shape is RectangleShape2D):
		var rectangular := RectangleShape2D.new()
		rectangular.extents = Vector2(beam_half_length, beam_half_width)
		_collision_shape.shape = rectangular
	else:
		var rect_shape := _collision_shape.shape as RectangleShape2D
		var new_extents := Vector2(beam_half_length, beam_half_width)
		if rect_shape.extents != new_extents:
			rect_shape.extents = new_extents
	_collision_shape.position = dir * beam_half_length
	_collision_shape.rotation = dir.angle()

func _compute_laser_beam_length() -> float:
	return max(radius * 60.0, 180.0)

func _compute_laser_beam_width() -> float:
	return max(radius * 4.0, 10.0)

func set_owner_reference(new_owner: Node) -> void:
	owner_reference = new_owner

func configure_glow(enabled: bool, glow_color: Color, glow_energy: float, glow_scale: float, glow_height: float) -> void:
	_glow_enabled = enabled
	_glow_color = glow_color
	_glow_energy = glow_energy
	_glow_scale = glow_scale
	_glow_height = glow_height
	_apply_glow_to_visual()

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
	_update_trail_points()
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
	_sync_visual_state()


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
	var bounce_origin := global_position
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
	_on_successful_bounce(bounce_origin)
	return true

func _append_trail_point(point: Vector2) -> void:
	_trail_positions.append(point)
	if _trail_positions.size() > MAX_TRAIL_POINTS:
		_trail_positions.pop_front()

func _update_trail_points() -> void:
	var current_global := global_position
	if _trail_positions.is_empty():
		_append_trail_point(current_global)
		_last_trail_sample = current_global
		return
	_trail_distance_accumulator += current_global.distance_to(_last_trail_sample)
	if _trail_distance_accumulator >= TRAIL_SAMPLE_DISTANCE:
		_trail_distance_accumulator = 0.0
		_append_trail_point(current_global)
		_last_trail_sample = current_global

func _sync_visual_state() -> void:
	if _visual == null:
		return
	_visual.set_trail_enabled(trail_enabled)
	_visual.update_visual(_trail_positions, _direction, radius, color, _has_bounced)
	_apply_glow_to_visual()
	_update_collision_shape_radius()

func _apply_glow_to_visual() -> void:
	if _visual == null:
		return
	if not _visual.has_method("configure_glow"):
		return
	_visual.configure_glow(_glow_enabled, _glow_color, _glow_energy, _glow_scale, _glow_height)

func _on_successful_bounce(bounce_origin: Vector2) -> void:
	if not _has_bounced:
		_has_bounced = true
	if _visual:
		_visual.emit_bounce()
	_append_trail_point(bounce_origin)

func _spawn_trail_segment() -> void:
	if trail_damage <= 0:
		return
	if shape.to_lower() == "laser":
		var segment := SniperTrailSegmentScript.new()
		var end_point: Vector2 = global_position
		var start_point: Vector2 = end_point - (_direction.normalized() * max(trail_interval, 48.0))
		if _trail_positions.size() >= 2:
			start_point = _trail_positions[_trail_positions.size() - 2]
			end_point = _trail_positions[_trail_positions.size() - 1]
		print("[BasicProjectile] Sniper trail spawn -> start:", start_point, " end:", end_point, " interval:", trail_interval)
		var strength := clampf(trail_color.a, 0.25, 1.0)
		var base_r: float = clampf(trail_color.r * 0.75 + 0.15, 0.0, 1.0)
		var base_g: float = clampf(trail_color.g * 1.05 + 0.12, 0.0, 1.0)
		var base_b: float = clampf(trail_color.b * 1.1 + 0.2, 0.0, 1.0)
		var core_color := Color(base_r, base_g, base_b, 0.85 * strength)
		var glow_color := Color(clampf(base_r * 0.7, 0.0, 1.0), clampf(base_g * 0.95 + 0.05, 0.0, 1.0), clampf(base_b + 0.18, 0.0, 1.0), 0.55 * strength)
		var ember_color := Color(clampf(base_r * 0.8 + 0.1, 0.0, 1.0), clampf(base_g, 0.0, 1.0), clampf(base_b + 0.1, 0.0, 1.0), 0.9 * strength)
		var trail_width: float = max(_compute_laser_beam_width(), max(trail_interval * 0.7, 40.0))
		segment.configure_segment(
			start_point,
			end_point,
			trail_width,
			max(trail_duration, 4.0),
			max(trail_damage, 1),
			0.3,
			core_color,
			glow_color,
			ember_color
		)
		print("[BasicProjectile] Sniper trail configured -> width:", trail_width)
		segment.align_to_world(segment.get_mid_point())
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
	if trail_enabled and trail_damage > 0 and shape.to_lower() == "laser":
		_spawn_trail_segment()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	queue_free()
