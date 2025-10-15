@tool
extends Node2D
class_name LaserBulletVisual

const LASER_LAYER_COUNT := 3
const LASER_CRACKLE_COUNT := 12

var apply_color_callback: Callable = Callable()
var _white_texture: Texture2D = null
var _layers: Array = []
var _core: Polygon2D = null
var _center_line: Line2D = null
var _tip_glow: Sprite2D = null
var _tip_highlight: Sprite2D = null
var _tip_particles: GPUParticles2D = null
var _crackles: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if Engine.is_editor_hint():
		configure_visual({
			"color": Color(0.65, 0.9, 1.0, 1.0),
			"radius": 6.0
		})

func set_apply_color_callback(callback: Callable) -> void:
	apply_color_callback = callback

func set_white_texture(texture: Texture2D) -> void:
	_white_texture = texture
	if _tip_glow:
		_tip_glow.texture = _white_texture if _white_texture else _create_white_texture()
	if _tip_highlight:
		_tip_highlight.texture = _white_texture if _white_texture else _create_white_texture()

func configure_visual(params: Dictionary) -> void:
	var color: Color = params.get("color", Color(0.65, 0.9, 1.0, 1.0))
	var radius: float = float(params.get("radius", 4.0))
	_update_visual(Vector2.RIGHT, radius, color, false)

func update_visual(direction: Vector2, radius: float, color: Color, context: Dictionary = {}) -> void:
	var is_special: bool = bool(context.get("is_special", false))
	_update_visual(direction, radius, color, is_special)

func _update_visual(direction: Vector2, radius: float, color: Color, is_special: bool) -> void:
	_ensure_nodes()
	var dir := direction
	if dir.length_squared() == 0.0:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var length_multiplier: float = 120.0 if is_special else 115.0
	var min_length: float = 360.0 if is_special else 420.0
	var beam_length: float = max(radius * length_multiplier, min_length)
	var beam_width: float = max(radius * 4.0, 10.0)
	if is_special:
		beam_width = max(radius * 6.0, 14.0)
	var neck_factor: float = 0.16 if is_special else 0.1
	var neck_max: float = 48.0 if is_special else 64.0
	var tip_factor: float = 0.12 if is_special else 0.08
	var tip_max: float = 48.0 if is_special else 72.0
	var neck_back: float = clampf(beam_length * neck_factor, 12.0, neck_max)
	var tip_length: float = clampf(beam_length * tip_factor, 18.0, tip_max)
	var front: Vector2 = dir * beam_length
	var beam_center_offset: Vector2 = to_global(front * 0.5) - global_position
	var layer_widths: Array = [beam_width * 3.0, beam_width * 2.0, beam_width * 1.3]
	var layer_colors: Array = _resolve_layer_colors(color, is_special)
	var compensated_color: Color = _apply_color(color, beam_center_offset)
	for i in range(_layers.size()):
		var layer_node: Polygon2D = _layers[i]
		layer_node.polygon = _build_diamond(front, dir, layer_widths[i], neck_back, tip_length)
		layer_node.color = _apply_color(layer_colors[i], beam_center_offset)
	_core.polygon = _build_diamond(front, dir, beam_width, neck_back, tip_length * 0.85)
	_core.color = compensated_color
	_center_line.points = PackedVector2Array([Vector2.ZERO, front])
	_center_line.width = max(beam_width * 0.22, 2.0)
	if _center_line.gradient == null:
		var line_gradient := Gradient.new()
		line_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		_center_line.gradient = line_gradient
	var center_gradient := _center_line.gradient
	if center_gradient:
		center_gradient.colors = PackedColorArray([
			_apply_color(Color(1.0, 1.0, 1.0, 0.15), beam_center_offset),
			_apply_color(Color(1.0, 1.0, 1.0, 1.0), beam_center_offset),
			_apply_color(Color(1.0, 1.0, 1.0, 0.2), beam_center_offset)
		])
	var tip_scale: float = max(beam_width * 0.14, 1.6)
	_tip_glow.position = front
	_tip_glow.scale = Vector2.ONE * tip_scale
	var tip_glow_color := Color(min(color.r + 0.4, 1.0), min(color.g + 0.4, 1.0), min(color.b + 0.4, 1.0), 0.9)
	var tip_offset := to_global(front) - global_position
	_tip_glow.modulate = _apply_color(tip_glow_color, tip_offset)
	var highlight_local: Vector2 = front - dir * tip_length * 0.25
	_tip_highlight.position = highlight_local
	_tip_highlight.scale = Vector2.ONE * (tip_scale * 0.6)
	var highlight_offset := to_global(highlight_local) - global_position
	_tip_highlight.modulate = _apply_color(Color(0.96, 0.99, 1.0, 0.65), highlight_offset)
	if _tip_particles and _tip_particles.process_material is ParticleProcessMaterial:
		var ppm := _tip_particles.process_material as ParticleProcessMaterial
		ppm.direction = Vector3(-dir.x, -dir.y, 0.0)
		ppm.color = compensated_color
		_tip_particles.position = front
		_tip_particles.rotation = dir.angle()
	_update_crackles(dir, beam_length, beam_width)

func _ensure_nodes() -> void:
	if _layers.is_empty():
		_layers.clear()
		for _i in range(LASER_LAYER_COUNT):
			var layer := Polygon2D.new()
			layer.antialiased = true
			layer.color = _apply_color(Color(1.0, 1.0, 1.0, 0.12), Vector2.ZERO)
			add_child(layer)
			_layers.append(layer)
	if _core == null:
		_core = Polygon2D.new()
		_core.antialiased = true
		add_child(_core)
	if _center_line == null:
		_center_line = Line2D.new()
		_center_line.width = 4.0
		_center_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_center_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(_center_line)
	if _tip_glow == null:
		_tip_glow = Sprite2D.new()
		_tip_glow.centered = true
		_tip_glow.texture = _white_texture if _white_texture else _create_white_texture()
		add_child(_tip_glow)
	if _tip_highlight == null:
		_tip_highlight = Sprite2D.new()
		_tip_highlight.centered = true
		_tip_highlight.texture = _white_texture if _white_texture else _create_white_texture()
		add_child(_tip_highlight)
	if _tip_particles == null:
		_tip_particles = GPUParticles2D.new()
		_tip_particles.amount = 36
		_tip_particles.lifetime = 0.4
		_tip_particles.one_shot = false
		_tip_particles.preprocess = 0.2
		_tip_particles.emitting = true
		var ppm := ParticleProcessMaterial.new()
		ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		ppm.emission_sphere_radius = 4.0
		ppm.direction = Vector3.ZERO
		ppm.spread = 45.0
		ppm.initial_velocity_min = 140.0
		ppm.initial_velocity_max = 220.0
		ppm.scale_min = 0.5
		ppm.scale_max = 0.9
		ppm.gravity = Vector3.ZERO
		ppm.damping_min = 4.0
		ppm.damping_max = 6.0
		ppm.angle_min = -30.0
		ppm.angle_max = 30.0
		ppm.angular_velocity_min = -18.0
		ppm.angular_velocity_max = 18.0
		ppm.color = Color(0.8, 0.95, 1.0, 1.0)
		_tip_particles.process_material = ppm
		add_child(_tip_particles)
	if _crackles.is_empty():
		for _i in range(LASER_CRACKLE_COUNT):
			var crackle := Line2D.new()
			crackle.width = 1.2
			crackle.begin_cap_mode = Line2D.LINE_CAP_ROUND
			crackle.end_cap_mode = Line2D.LINE_CAP_ROUND
			add_child(crackle)
			_crackles.append(crackle)

func _build_diamond(front: Vector2, dir: Vector2, width: float, neck_back: float, tip_length: float) -> PackedVector2Array:
	var neck_position: float = max(neck_back, 8.0)
	var tip_extent: float = max(tip_length, 6.0)
	var ortho: Vector2 = dir.orthogonal() * (width * 0.5)
	var neck_forward: Vector2 = dir * neck_position
	var near_tip: Vector2 = front - dir * tip_extent
	var tip_ortho: Vector2 = dir.orthogonal() * (width * 0.38)
	return PackedVector2Array([
		Vector2.ZERO,
		neck_forward + ortho,
		near_tip + tip_ortho,
		front,
		near_tip - tip_ortho,
		neck_forward - ortho
	])

func _resolve_layer_colors(base_color: Color, is_special: bool) -> Array:
	var outer: Color
	var mid: Color
	var inner: Color
	if is_special:
		outer = _offset_color(base_color, -0.25, -0.15, -0.1, 0.45)
		mid = _offset_color(base_color, 0.05, 0.05, 0.08, 0.68)
		inner = _offset_color(base_color, 0.22, 0.2, 0.18, 0.82)
	else:
		outer = _offset_color(base_color, -0.45, -0.3, -0.3, 0.18)
		mid = _offset_color(base_color, -0.25, 0.0, 0.0, 0.32)
		inner = _offset_color(base_color, 0.0, 0.0, 0.0, 0.45)
	return [outer, mid, inner]

func _offset_color(base: Color, r_offset: float, g_offset: float, b_offset: float, alpha: float) -> Color:
	return Color(
		clampf(base.r + r_offset, 0.0, 1.0),
		clampf(base.g + g_offset, 0.0, 1.0),
		clampf(base.b + b_offset, 0.0, 1.0),
		clampf(alpha, 0.0, 1.0)
	)

func _update_crackles(dir: Vector2, length: float, beam_width: float) -> void:
	if _crackles.is_empty():
		return
	var count: int = _crackles.size()
	for i in range(count):
		var t: float = float(i + 1) / float(count + 1)
		var base: Vector2 = dir * length * t
		var offset_distance: float = _rng.randf_range(beam_width * 0.45, beam_width * 1.35)
		var angle: float = _rng.randf_range(0.0, TAU)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * offset_distance
		var crackle: Line2D = _crackles[i]
		crackle.points = PackedVector2Array([base, base + offset])
		var color_choice := _rng.randf() > 0.45
		var crackle_color := Color(0.78, 0.9, 1.0, 0.9) if color_choice else Color(1.0, 1.0, 1.0, 0.9)
		var sample_local := base + offset * 0.5
		var sample_offset := to_global(sample_local) - global_position
		crackle.default_color = _apply_color(crackle_color, sample_offset)

func _apply_color(color: Color, offset: Vector2) -> Color:
	if apply_color_callback and apply_color_callback.is_valid():
		return apply_color_callback.call(color, offset)
	return color

func _create_white_texture() -> Texture2D:
	if _white_texture:
		return _white_texture
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_white_texture = ImageTexture.create_from_image(image)
	return _white_texture
