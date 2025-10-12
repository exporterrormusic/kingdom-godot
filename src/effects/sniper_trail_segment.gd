extends Area2D
class_name SniperTrailSegment

const MIN_LENGTH := 6.0
const MIN_COOLDOWN := 0.05
const TRAIL_FADE_BEGIN := 0.65
const PARTICLE_LIFETIME := 0.45
const MIN_ALPHA := 0.05
const DEBUG_TRAIL := true

var _start_point: Vector2 = Vector2.ZERO
var _end_point: Vector2 = Vector2.ZERO
var _mid_point: Vector2 = Vector2.ZERO
var _length: float = 0.0
var _half_width: float = 24.0
var _elapsed: float = 0.0
var _damage_timer: float = 0.0
var _damage_cooldown: float = 0.3
var _damage_amount: int = 12
var _duration: float = 4.0
var _direction: Vector2 = Vector2.RIGHT
var _enemy_last_damage: Dictionary = {}
var _core_color: Color = Color(0.78, 0.92, 1.0, 0.85)
var _glow_color: Color = Color(0.36, 0.78, 1.0, 0.5)
var _ember_color: Color = Color(0.52, 0.86, 1.0, 0.9)
var _particle_count: int = 26

var _collision_shape: CollisionShape2D = null
var _rectangle_shape: RectangleShape2D = null
var _glow_line: Line2D = null
var _core_line: Line2D = null
var _particle_node: GPUParticles2D = null
var _glow_gradient: Gradient = Gradient.new()
var _core_gradient: Gradient = Gradient.new()
var _burn_polygon: Polygon2D = null
var _configured: bool = false

func configure_segment(start_point: Vector2, end_point: Vector2, width: float, segment_duration: float, damage: int, cooldown: float, core_color: Color, glow_color: Color, ember_color: Color) -> void:
	_start_point = start_point
	_end_point = end_point
	_mid_point = start_point.lerp(end_point, 0.5)
	_direction = end_point - start_point
	_length = _direction.length()
	if _length < MIN_LENGTH:
		_length = MIN_LENGTH
		_direction = Vector2.RIGHT
	else:
		_direction = _direction / _length
	_half_width = max(width * 0.5, 6.0)
	_duration = max(segment_duration, 0.2)
	_damage_amount = max(damage, 0)
	_damage_cooldown = max(cooldown, MIN_COOLDOWN)
	_enemy_last_damage.clear()
	_elapsed = 0.0
	_damage_timer = 0.0
	_core_color = core_color
	_glow_color = glow_color
	_ember_color = ember_color
	_particle_count = max(12, int(_length / 8.0))
	_configured = true
	if DEBUG_TRAIL:
		print("[SniperTrailSegment] configure -> length:", _length, " width:", width, " duration:", _duration, " damage:", _damage_amount)
	_rotation_setup()
	_setup_collision_shape()
	_setup_visuals()
	visible = true
	z_index = 60
	set_process(true)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(_configured)
	if _configured:
		align_to_world(_mid_point)
	if DEBUG_TRAIL:
		print("[SniperTrailSegment] ready -> configured:", _configured, " process_mode:", process_mode)

func _rotation_setup() -> void:
	rotation = _direction.angle()

func _setup_collision_shape() -> void:
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		add_child(_collision_shape)
	_rectangle_shape = RectangleShape2D.new()
	_rectangle_shape.extents = Vector2(_length * 0.5, _half_width)
	_collision_shape.shape = _rectangle_shape
	_collision_shape.position = Vector2.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

func _setup_visuals() -> void:
	if _glow_line == null:
		_glow_line = Line2D.new()
		_glow_line.begin_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
		_glow_line.end_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
		_glow_line.joint_mode = Line2D.LineJointMode.LINE_JOINT_ROUND
		_glow_line.z_index = 62
		add_child(_glow_line)
	if _core_line == null:
		_core_line = Line2D.new()
		_core_line.begin_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
		_core_line.end_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
		_core_line.joint_mode = Line2D.LineJointMode.LINE_JOINT_ROUND
		_core_line.z_index = 61
		add_child(_core_line)
	if _burn_polygon == null:
		_burn_polygon = Polygon2D.new()
		_burn_polygon.z_index = 60
		add_child(_burn_polygon)
	var half_length := _length * 0.5
	_burn_polygon.polygon = PackedVector2Array([
		Vector2(-half_length, -_half_width),
		Vector2(half_length, -_half_width),
		Vector2(half_length, _half_width),
		Vector2(-half_length, _half_width)
	])
	_burn_polygon.color = Color(_core_color.r, _core_color.g, _core_color.b, 0.25)
	var points := PackedVector2Array([
		Vector2(-_length * 0.5, 0.0),
		Vector2(_length * 0.5, 0.0)
	])
	_glow_line.points = points
	_core_line.points = points
	_glow_line.width = _half_width * 2.6
	_core_line.width = _half_width * 1.6
	_glow_gradient = Gradient.new()
	_glow_gradient.colors = PackedColorArray([
		Color(_glow_color.r, _glow_color.g, _glow_color.b, 0.0),
		_glow_color,
		Color(_glow_color.r, _glow_color.g, _glow_color.b, 0.0)
	])
	_core_gradient = Gradient.new()
	_core_gradient.colors = PackedColorArray([
		Color(_core_color.r, _core_color.g, _core_color.b, 0.0),
		_core_color,
		Color(_core_color.r, _core_color.g, _core_color.b, 0.0)
	])
	_glow_line.gradient = _glow_gradient
	_core_line.gradient = _core_gradient
	if _particle_node == null:
		_particle_node = GPUParticles2D.new()
		_particle_node.one_shot = false
		_particle_node.lifetime = PARTICLE_LIFETIME
		_particle_node.preprocess = 0.2
		add_child(_particle_node)
	_particle_node.amount = _particle_count
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(_length * 0.5, _half_width, 0.0)
	process_material.initial_velocity_min = 40.0
	process_material.initial_velocity_max = 120.0
	process_material.damping_min = 10.0
	process_material.damping_max = 16.0
	process_material.scale_min = 0.25
	process_material.scale_max = 0.55
	process_material.color = _ember_color
	process_material.angle_min = 0.0
	process_material.angle_max = 360.0
	process_material.angular_velocity_min = -32.0
	process_material.angular_velocity_max = 32.0
	process_material.gravity = Vector3.ZERO
	_particle_node.process_material = process_material
	_particle_node.emitting = true
	_update_visual_state()

func align_to_world(mid_point: Vector2) -> void:
	_mid_point = mid_point
	global_position = mid_point

func _process(delta: float) -> void:
	if not _configured:
		return
	_elapsed += delta
	_damage_timer += delta
	if DEBUG_TRAIL and _elapsed <= delta * 1.5:
		print("[SniperTrailSegment] process start -> duration:", _duration)
	while _damage_timer >= _damage_cooldown:
		_damage_timer -= _damage_cooldown
		_apply_damage_tick()
	_update_visual_state()
	if _elapsed >= _duration:
		if DEBUG_TRAIL:
			print("[SniperTrailSegment] queue_free at elapsed:", _elapsed)
		queue_free()

func _apply_damage_tick() -> void:
	if _damage_amount <= 0:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		if DEBUG_TRAIL:
			print("[SniperTrailSegment] damage tick -> no enemies in group")
		return
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D) or not enemy.has_method("apply_damage"):
			continue
		var enemy_position := (enemy as Node2D).global_position
		var distance: float = _distance_to_segment(enemy_position, _start_point, _end_point)
		if distance > _half_width:
			continue
		var enemy_id := enemy.get_instance_id()
		var last_time := float(_enemy_last_damage.get(enemy_id, -INF))
		if _elapsed - last_time < _damage_cooldown * 0.95:
			continue
		enemy.apply_damage(_damage_amount)
		if DEBUG_TRAIL:
			print("[SniperTrailSegment] damage applied -> enemy:", enemy, " distance:", distance, " elapsed:", _elapsed)
		_enemy_last_damage[enemy_id] = _elapsed

func _update_visual_state() -> void:
	var progress := clampf(_elapsed / max(_duration, 0.001), 0.0, 1.0)
	var fade_strength: float = 1.0
	if progress > TRAIL_FADE_BEGIN:
		var fade_progress: float = (progress - TRAIL_FADE_BEGIN) / max(1.0 - TRAIL_FADE_BEGIN, 0.001)
		fade_strength = clampf(1.0 - fade_progress, MIN_ALPHA, 1.0)
	var flicker := 1.0 + sin(_elapsed * 9.0) * 0.12
	if _glow_gradient:
		_glow_gradient.colors = PackedColorArray([
			Color(_glow_color.r, _glow_color.g, _glow_color.b, 0.0),
			Color(_glow_color.r, _glow_color.g, _glow_color.b, _glow_color.a * fade_strength),
			Color(_glow_color.r, _glow_color.g, _glow_color.b, 0.0)
		])
	if _core_gradient:
		_core_gradient.colors = PackedColorArray([
			Color(_core_color.r, _core_color.g, _core_color.b, 0.0),
			Color(_core_color.r, _core_color.g, _core_color.b, _core_color.a * fade_strength),
			Color(_core_color.r, _core_color.g, _core_color.b, 0.0)
		])
	if _glow_line:
		_glow_line.width = _half_width * 2.6 * flicker
	if _core_line:
		_core_line.width = _half_width * 1.6 * flicker
	if _burn_polygon:
		_burn_polygon.color = Color(_core_color.r, _core_color.g, _core_color.b, 0.18 * fade_strength)
	if _particle_node and _particle_node.process_material is ParticleProcessMaterial:
		var ppm := _particle_node.process_material as ParticleProcessMaterial
		ppm.color = Color(_ember_color.r, _ember_color.g, _ember_color.b, _ember_color.a * fade_strength)
		_particle_node.emitting = progress < 0.98

func get_mid_point() -> Vector2:
	return _mid_point

func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t: float = 0.0
	var ab_length_sq: float = ab.length_squared()
	if ab_length_sq > 0.0:
		t = clamp(((point - a).dot(ab)) / ab_length_sq, 0.0, 1.0)
	var closest := a + ab * t
	return point.distance_to(closest)
