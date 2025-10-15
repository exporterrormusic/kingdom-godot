extends Area2D
class_name BasicProjectile

const BasicProjectileVisualScene: PackedScene = preload("res://scenes/projectiles/BasicProjectileVisual.tscn")
const BasicProjectileVisualScript := preload("res://src/projectiles/basic_projectile_visual.gd")

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
@export var trail_width_multiplier: float = 1.0

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

const GroundFireScene: PackedScene = preload("res://scenes/effects/GroundFire.tscn")
const GroundFireScript := preload("res://src/effects/ground_fire.gd")
const SniperTrailSegmentScene: PackedScene = preload("res://scenes/effects/SniperTrailSegment.tscn")
const SniperTrailSegmentScript := preload("res://src/effects/sniper_trail_segment.gd")
const PROJECTILE_BASE_Z_INDEX := 900

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
var _last_collision_radius: float = -1.0

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = PROJECTILE_BASE_Z_INDEX
	if _direction == Vector2.ZERO:
		_direction = Vector2.RIGHT
	_remaining_penetration = max(1, penetration)
	_bounces_remaining = max(0, max_bounces)
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("area_entered", Callable(self, "_on_area_entered"))
	set_process(true)
	
	_last_trail_sample = global_position
	_append_trail_point(global_position)
	_bounce_visuals_enabled = projectile_archetype.to_lower() == "smg_special"
	_visual = _create_basic_projectile_visual()
	if _visual:
		add_child(_visual)
		_visual.setup(self, _bounce_visuals_enabled)
		_visual.set_trail_enabled(trail_enabled)
		_ensure_default_glow()
	
	# Find collision shape after visual is created
	_collision_shape = _find_collision_shape()
	_update_collision_shape_radius()
	
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

func _find_collision_shape() -> CollisionShape2D:
	# First check if the visual has its own collision shape
	if _visual:
		for child in _visual.get_children():
			if child is CollisionShape2D:
				return child as CollisionShape2D
	
	# Fallback to the default collision shape in BasicProjectile
	var default_shape = $CollisionShape2D
	if default_shape:
		return default_shape
	
	return null

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

func apply_default_glow() -> void:
	var base_color := color if color else Color(1.0, 0.8, 0.4, 1.0)
	var archetype := projectile_archetype.to_lower()
	var shape_key := String(shape).to_lower()
	if archetype == "minigun":
		configure_glow(false, Color(), 0, 0, 0)
		return
	var params := _resolve_default_glow_parameters(base_color, archetype, shape_key)
	configure_glow(true, params.get("color", base_color), params.get("energy", 0.8), params.get("scale", 0.6), params.get("height", 0.0))

func _ensure_default_glow() -> void:
	if _glow_enabled:
		_apply_glow_to_visual()
		return
	apply_default_glow()

func _resolve_default_glow_parameters(base_color: Color, archetype: String, shape_key: String) -> Dictionary:
	var glow_color := _warm_glow_from(base_color)
	var glow_energy := 0.78
	var glow_scale := clampf(radius * 0.28, 0.32, 1.15)
	var glow_height := -1.0
	match shape_key:
		"laser":
			glow_color = Color(0.75, 0.92, 1.0, 0.9)
			glow_energy = 1.6
			glow_scale = clampf(radius * 0.22 + 1.4, 1.4, 2.8)
			glow_height = 0.0
		"tracer":
			var tracer_base := _warm_glow_from(base_color)
			glow_color = Color(
				clampf(tracer_base.r * 0.75 + 0.12, 0.0, 1.0),
				clampf(tracer_base.g * 0.48 + 0.1, 0.0, 1.0),
				clampf(tracer_base.b * 0.28 + 0.05, 0.0, 1.0),
				0.5
			)
			glow_energy = 0.72
			glow_scale = clampf(radius * 0.42, 0.38, 1.4)
			glow_height = -1.6
		"neon":
			glow_color = Color(0.2, 0.9, 1.0, 0.85)
			glow_energy = 1.35
			glow_scale = clampf(radius * 0.36, 0.5, 1.7)
			glow_height = -1.5
		"pellet":
			glow_color = _warm_glow_from(base_color).lerp(Color(1.0, 0.52, 0.2, 0.36), 0.32)
			glow_energy = 0.24
			glow_scale = clampf(radius * 0.09, 0.12, 0.36)
			glow_height = -0.08
	match archetype:
		"assault":
			glow_color = Color(0.96, 0.52, 0.2, 0.56)
			glow_energy = 0.7
			glow_scale = clampf(radius * 0.42, 0.48, 1.4)
			glow_height = -1.5
		"assault_special":
			glow_color = Color(1.0, 0.58, 0.24, 0.72)
			glow_energy = 0.95
			glow_scale = clampf(radius * 0.55, 0.6, 1.8)
			glow_height = -1.6
		"smg":
			glow_color = _warm_glow_from(base_color).lerp(Color(1.0, 0.58, 0.3, 0.32), 0.34)
			glow_energy = 0.3
			glow_scale = clampf(radius * 0.12, 0.16, 0.48)
			glow_height = -0.08
		"smg_special":
			glow_color = Color(0.22, 0.88, 1.0, 0.9)
			glow_energy = 1.4
			glow_scale = clampf(radius * 0.4, 0.5, 1.6)
			glow_height = -2.2
		"shotgun":
			var ember_base := _warm_glow_from(base_color)
			glow_color = Color(
				clampf(ember_base.r * 1.05, 0.0, 1.0),
				clampf(ember_base.g * 0.62, 0.0, 1.0),
				clampf(ember_base.b * 0.5, 0.0, 1.0),
				0.82
			)
			glow_energy = 0.28
			glow_scale = clampf(radius * 0.26, 0.28, 0.72)
			glow_height = -0.18
		"shotgun_special":
			var blaze := Color(
				clampf(base_color.r * 1.08 + 0.05, 0.0, 1.0),
				clampf(base_color.g * 0.38, 0.0, 1.0),
				clampf(base_color.b * 0.24, 0.0, 1.0),
				0.95
			)
			glow_color = blaze
			glow_energy = 0.44
			glow_scale = clampf(radius * 0.34, 0.4, 1.1)
			glow_height = -0.22
		"minigun":
			glow_color = Color(0.28, 0.6, 0.96, 0.5)
			glow_energy = 0.76
			glow_scale = clampf(radius * 0.44, 0.48, 1.45)
			glow_height = -1.3
		"minigun_special":
			glow_color = Color(0.45, 0.84, 1.0, 0.82)
			glow_energy = 1.25
			glow_scale = clampf(radius * 0.58, 0.8, 2.1)
			glow_height = -1.4
		"sniper":
			glow_color = Color(0.82, 0.98, 1.0, 0.92)
			glow_energy = 2.1
			glow_scale = clampf(radius * 0.8, 1.2, 3.0)
			glow_height = -6.0
		"sniper_special":
			glow_color = Color(0.72, 0.95, 1.0, 0.95)
			glow_energy = 3.2
			glow_scale = clampf(radius * 1.1, 1.6, 3.8)
			glow_height = -10.0
	return {
		"color": glow_color,
		"energy": glow_energy,
		"scale": glow_scale,
		"height": glow_height
	}

func _warm_glow_from(base_color: Color) -> Color:
	return Color(
		clampf(base_color.r * 1.05 + 0.15, 0.0, 1.0),
		clampf(base_color.g * 0.6 + 0.12, 0.0, 1.0),
		clampf(base_color.b * 0.28 + 0.05, 0.0, 1.0),
		clampf(base_color.a * 0.78 + 0.18, 0.0, 1.0)
	)


func _create_basic_projectile_visual() -> BasicProjectileVisual:
	if BasicProjectileVisualScene:
		var instance: Node = BasicProjectileVisualScene.instantiate()
		if instance is BasicProjectileVisual:
			return instance as BasicProjectileVisual
		instance.queue_free()
	if BasicProjectileVisualScript:
		return BasicProjectileVisualScript.new()
	return null


func _create_ground_fire_trail() -> GroundFire:
	if GroundFireScene:
		var instance: Node = GroundFireScene.instantiate()
		if instance is GroundFire:
			return instance as GroundFire
		instance.queue_free()
	if GroundFireScript:
		return GroundFireScript.new()
	return null


func _create_sniper_trail_segment() -> SniperTrailSegment:
	if SniperTrailSegmentScene:
		var instance: Node = SniperTrailSegmentScene.instantiate()
		if instance is SniperTrailSegment:
			return instance as SniperTrailSegment
		instance.queue_free()
	if SniperTrailSegmentScript:
		return SniperTrailSegmentScript.new()
	return null

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
		var segment: SniperTrailSegment = _create_sniper_trail_segment()
		if segment == null:
			return
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
		trail_width *= clampf(trail_width_multiplier, 0.25, 4.0)
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
	var fire_node: GroundFire = _create_ground_fire_trail()
	if fire_node == null:
		return
	fire_node.radius = max(trail_interval * 0.6, 40.0)
	fire_node.damage_per_tick = trail_damage
	fire_node.duration = trail_duration
	fire_node.color = trail_color
	var glow := Color(trail_color.r * 0.7 + 0.05, trail_color.g * 0.8 + 0.05, trail_color.b, clampf(trail_color.a * 0.6 + 0.1, 0.0, 1.0))
	var ember := Color(
		clampf(trail_color.r * 0.6 + 0.15, 0.0, 1.0),
		clampf(trail_color.g * 0.9 + 0.05, 0.0, 1.0),
		clampf(trail_color.b * 1.05, 0.0, 1.0),
		clampf(trail_color.a * 0.85 + 0.1, 0.0, 1.0)
	)
	var smoke := Color(trail_color.r * 0.4, trail_color.g * 0.5, trail_color.b * 0.8, 0.32)
	fire_node.glow_color = glow
	fire_node.ember_color = ember
	fire_node.smoke_color = smoke
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
