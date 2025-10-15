extends Node2D
class_name ShotgunTrailEffect

@export var fade_duration: float = 0.22
@export var spark_lifetime: float = 0.45
@export var spark_amount: int = 28

const LAYER_WIDTHS := [12.0, 8.0, 5.0, 2.0]
const LAYER_ALPHA_MULTIPLIERS := [0.45, 0.62, 0.78, 1.0]
const LAYER_COLOR_OFFSETS := [
	Vector3(0.0, -0.25, -0.4),
	Vector3(0.12, -0.12, -0.18),
	Vector3(0.22, 0.02, -0.05),
	Vector3(0.32, 0.18, 0.05)
]
const FIRE_LAYER_AMPLITUDES: Array[float] = [26.0, 18.0, 12.0, 6.0]
const FIRE_NOISE_SCALE: float = 0.015

var _pellet_refs: Array = []
var _last_world_positions: Array = []
var _last_local_points: PackedVector2Array = PackedVector2Array()
var _last_width_scale: float = 1.0
var _forward: Vector2 = Vector2.RIGHT
var _base_color: Color = Color(1.0, 0.55, 0.25, 0.85)
var _glow_color: Color = Color(1.0, 0.8, 0.4, 0.65)
var _is_special: bool = false
var _fading: bool = false
var _fade_timer: float = 0.0
var _life_ratio: float = 1.0
var _line_layers: Array[Line2D] = []
var _spark_node: GPUParticles2D = null
var _special_sprite: Sprite2D = null
var _white_texture: Texture2D = null
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _time_accumulator: float = 0.0
var _emit_glow: bool = true

func _ready() -> void:
	set_process(true)
	z_index = 340
	_ensure_white_texture()
	_rng.randomize()
	_noise.seed = _rng.randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.65
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3
	_noise.fractal_lacunarity = 2.0
	_noise.fractal_gain = 0.48

func configure(pellets: Array, forward: Vector2, base_color: Color, glow_color: Color, is_special: bool, emit_glow: bool = true) -> void:
	_pellet_refs.clear()
	for pellet in pellets:
		if pellet is Node2D:
			_pellet_refs.append(weakref(pellet))
	if _pellet_refs.is_empty():
		queue_free()
		return
	_forward = forward.normalized() if forward.length() > 0.0 else Vector2.RIGHT
	_base_color = base_color
	_glow_color = glow_color
	_is_special = is_special
	_emit_glow = emit_glow
	_fading = false
	_fade_timer = 0.0
	_life_ratio = 1.0
	_setup_layers()
	if _emit_glow:
		_setup_sparks()
		_setup_special_glow()
	else:
		_teardown_glow()
	_update_from_positions(_collect_positions())

func _process(delta: float) -> void:
	_time_accumulator += delta
	var positions := _collect_positions()
	if positions.size() >= 2:
		_last_world_positions = positions.duplicate()
		_update_from_positions(positions)
		if _fading:
			_fading = false
			_fade_timer = 0.0
		_life_ratio = 1.0
	else:
		if _last_world_positions.size() >= 2:
			_update_from_positions(_last_world_positions)
		_begin_fade()
	if _fading:
		_fade_timer += delta
		var fade_ratio: float = 1.0 - (_fade_timer / max(fade_duration, 0.001))
		_life_ratio = clampf(fade_ratio, 0.0, 1.0)
		if _life_ratio <= 0.0:
			queue_free()
			return
		_apply_cached_geometry()

func _collect_positions() -> Array:
	var positions: Array = []
	var valid_refs: Array = []
	for ref_variant in _pellet_refs:
		var pellet: Node = null
		if ref_variant is WeakRef:
			pellet = (ref_variant as WeakRef).get_ref()
		elif ref_variant is Node:
			pellet = ref_variant
		if pellet != null and is_instance_valid(pellet) and pellet is Node2D:
			positions.append((pellet as Node2D).global_position)
			valid_refs.append(weakref(pellet))
	_pellet_refs = valid_refs
	return positions

func _update_from_positions(positions: Array) -> void:
	if positions.size() < 2:
		_begin_fade()
		return
	var centroid := _compute_centroid(positions)
	global_position = centroid
	var local_points: Array = []
	for world_point in positions:
		local_points.append(world_point - centroid)
	var sorted_points := _sort_points(local_points)
	var packed := PackedVector2Array()
	for point in sorted_points:
		packed.append(point)
	_last_local_points = packed
	_last_width_scale = _compute_width_scale(packed)
	_apply_cached_geometry()

func _apply_cached_geometry() -> void:
	if _last_local_points.is_empty():
		return
	var width_factor := _life_ratio_width_factor()
	var deformed_layers: Array[PackedVector2Array] = []
	for i in range(_line_layers.size()):
		var line := _line_layers[i]
		var layer_points := _deform_points(_last_local_points, i)
		if layer_points.size() == 0:
			layer_points = _last_local_points
		line.points = layer_points
		line.width = max(1.0, LAYER_WIDTHS[i] * _last_width_scale * width_factor)
		deformed_layers.append(layer_points)
	_apply_line_colors()
	var spark_points: PackedVector2Array = _last_local_points
	if deformed_layers.size() > 0:
		spark_points = deformed_layers[0]
	_update_sparks(spark_points)
	_update_special_glow(spark_points)

func _setup_layers() -> void:
	for existing in _line_layers:
		if is_instance_valid(existing):
			existing.queue_free()
	_line_layers.clear()
	for _i in LAYER_WIDTHS:
		var line := Line2D.new()
		line.width = _i
		line.begin_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LineCapMode.LINE_CAP_ROUND
		line.joint_mode = Line2D.LineJointMode.LINE_JOINT_ROUND
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		line.material = mat
		add_child(line)
		_line_layers.append(line)

func _setup_sparks() -> void:
	if not _emit_glow:
		return
	if _spark_node and is_instance_valid(_spark_node):
		_spark_node.queue_free()
	_spark_node = GPUParticles2D.new()
	_spark_node.one_shot = false
	_spark_node.amount = spark_amount
	_spark_node.lifetime = spark_lifetime
	_spark_node.preprocess = spark_lifetime * 0.5
	_spark_node.emitting = true
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(24.0, 18.0, 0.0)
	process_material.initial_velocity_min = 50.0
	process_material.initial_velocity_max = 140.0
	process_material.gravity = Vector3.ZERO
	process_material.damping_min = 12.0
	process_material.damping_max = 18.0
	process_material.scale_min = 0.35
	process_material.scale_max = 0.7
	process_material.angle_min = 0.0
	process_material.angle_max = 360.0
	process_material.color = _glow_color
	_spark_node.process_material = process_material
	add_child(_spark_node)

func _setup_special_glow() -> void:
	if not _emit_glow:
		return
	if not _is_special:
		if _special_sprite and is_instance_valid(_special_sprite):
			_special_sprite.visible = false
		return
	if _special_sprite == null or not is_instance_valid(_special_sprite):
		_special_sprite = Sprite2D.new()
		_special_sprite.texture = _white_texture
		_special_sprite.centered = true
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_special_sprite.material = mat
		add_child(_special_sprite)
	_special_sprite.visible = true

func _apply_line_colors() -> void:
	for i in range(_line_layers.size()):
		var line := _line_layers[i]
		var color := _resolve_layer_color(i)
		var gradient := line.gradient
		if gradient == null:
			gradient = Gradient.new()
		gradient.colors = PackedColorArray([
			Color(color.r, color.g, color.b, 0.0),
			color,
			Color(color.r, color.g, color.b, 0.0)
		])
		line.gradient = gradient

func _resolve_layer_color(index: int) -> Color:
	var offset: Vector3 = LAYER_COLOR_OFFSETS[min(index, LAYER_COLOR_OFFSETS.size() - 1)]
	var alpha_mult: float = LAYER_ALPHA_MULTIPLIERS[min(index, LAYER_ALPHA_MULTIPLIERS.size() - 1)]
	return Color(
		clampf(_base_color.r + offset.x, 0.0, 1.0),
		clampf(_base_color.g + offset.y, 0.0, 1.0),
		clampf(_base_color.b + offset.z, 0.0, 1.0),
		clampf(alpha_mult * _life_ratio, 0.0, 1.0)
	)

func _update_sparks(points: PackedVector2Array) -> void:
	if not _emit_glow:
		return
	if _spark_node == null or not (_spark_node.process_material is ParticleProcessMaterial):
		return
	if points.size() < 2:
		_spark_node.emitting = false
		return
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	for point in points:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)
	var half_extents := Vector2(
		max(18.0, (max_x - min_x) * 0.5),
		max(12.0, (max_y - min_y) * 0.5)
	)
	var process_material := _spark_node.process_material as ParticleProcessMaterial
	process_material.emission_box_extents = Vector3(half_extents.x, half_extents.y, 0.0)
	process_material.color = Color(_glow_color.r, _glow_color.g, _glow_color.b, clampf(_glow_color.a * 0.85 * _life_ratio, 0.0, 1.0))
	_spark_node.position = Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	_spark_node.emitting = _life_ratio > 0.05

func _update_special_glow(points: PackedVector2Array) -> void:
	if not _emit_glow or not _is_special or _special_sprite == null:
		return
	var max_radius := 0.0
	for point in points:
		max_radius = max(max_radius, point.length())
	var glow_scale: float = max(max_radius * 0.015, 0.55)
	_special_sprite.position = Vector2.ZERO
	_special_sprite.scale = Vector2.ONE * glow_scale
	_special_sprite.modulate = Color(
		clampf(_glow_color.r * 0.9 + 0.1, 0.0, 1.0),
		clampf(_glow_color.g * 0.75 + 0.25, 0.0, 1.0),
		clampf(_glow_color.b * 0.55 + 0.35, 0.0, 1.0),
		clampf(0.55 * _life_ratio, 0.0, 1.0)
	)
	_special_sprite.visible = _life_ratio > 0.05

func _compute_centroid(points: Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in points:
		sum += point
	return sum / float(points.size())

func _sort_points(points: Array) -> Array:
	var annotated: Array = []
	for point in points:
		var vec := point as Vector2
		if vec.length() <= 0.0:
			continue
		var angle := _forward.angle_to(vec.normalized())
		annotated.append({"point": vec, "angle": angle})
	annotated.sort_custom(Callable(self, "_compare_angle"))
	var sorted: Array = []
	for entry in annotated:
		sorted.append(entry.get("point", Vector2.ZERO))
	return sorted

func _compare_angle(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("angle", 0.0)) < float(b.get("angle", 0.0))

func _compute_width_scale(points: PackedVector2Array) -> float:
	var max_radius := 0.0
	for point in points:
		max_radius = max(max_radius, point.length())
	return clampf(max_radius / 140.0, 0.7, 1.8)

func _life_ratio_width_factor() -> float:
	return 0.6 + 0.4 * _life_ratio

func _begin_fade() -> void:
	if _fading:
		return
	_fading = true
	_fade_timer = 0.0

func _ensure_white_texture() -> void:
	if _white_texture != null:
		return
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 1.0, 1.0, 1.0))
	_white_texture = ImageTexture.create_from_image(img)

func _deform_points(points: PackedVector2Array, layer_index: int) -> PackedVector2Array:
	if points.size() == 0:
		return PackedVector2Array()
	var amplitude: float = FIRE_LAYER_AMPLITUDES[min(layer_index, FIRE_LAYER_AMPLITUDES.size() - 1)] * clampf(_life_ratio, 0.1, 1.0)
	if amplitude <= 0.0:
		return points
	var deformed := PackedVector2Array()
	var noise_scale := FIRE_NOISE_SCALE * (1.0 + float(layer_index) * 0.18)
	var time_offset := _time_accumulator * (1.6 + float(layer_index) * 0.35)
	for i in range(points.size()):
		var point := points[i]
		var prev := points[max(0, i - 1)]
		var next := points[min(points.size() - 1, i + 1)]
		var tangent := (next - prev)
		if tangent.length() <= 0.001:
			tangent = Vector2.RIGHT
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		var radial := Vector2.ZERO
		if point.length() > 0.001:
			radial = point.normalized()
		var noise_value: float = _noise.get_noise_3d(point.x * noise_scale, point.y * noise_scale, time_offset)
		var flicker: float = sin(time_offset * 3.4 + float(i) * 0.72 + float(layer_index) * 0.33)
		var offset: Vector2 = normal * amplitude * noise_value + radial * amplitude * 0.18 * flicker
		deformed.append(point + offset)
	return deformed

func _teardown_glow() -> void:
	if _spark_node and is_instance_valid(_spark_node):
		_spark_node.queue_free()
	_spark_node = null
	if _special_sprite and is_instance_valid(_special_sprite):
		_special_sprite.queue_free()
	_special_sprite = null
