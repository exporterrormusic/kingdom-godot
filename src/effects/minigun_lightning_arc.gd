@tool
extends Node2D
class_name MinigunLightningArc

@export var lifetime: float = 0.28
@export var jitter_amount: float = 18.0
@export var segment_length: float = 64.0
@export var glow_color: Color = Color(0.55, 0.85, 1.0, 0.9)

var _elapsed: float = 0.0
var _base_width: float = 24.0
var _intensity: float = 1.0
var _points: PackedVector2Array = PackedVector2Array()
var _line: Line2D = null
var _glow: Sprite2D = null
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_ensure_nodes()
	set_process(true)
	if Engine.is_editor_hint():
		_configure_preview()

func configure(start_point: Vector2, end_point: Vector2, width: float, intensity: float) -> void:
	_ensure_nodes()
	global_position = start_point
	_base_width = max(4.0, width)
	_intensity = clampf(intensity, 0.1, 1.3)
	_points = _build_arc_points(end_point - start_point)
	_line.points = _points
	_line.width = _base_width
	_line.default_color = _resolve_line_color(1.0)
	_glow.texture = _ensure_white_texture()
	_glow.modulate = Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * _intensity)
	_glow.position = _points[_points.size() - 1] if _points.size() > 0 else Vector2.ZERO

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_elapsed += delta
	var ratio := 1.0 - clampf(_elapsed / max(lifetime, 0.001), 0.0, 1.0)
	if ratio <= 0.0:
		queue_free()
		return
	_line.width = _base_width * pow(ratio, 0.6)
	_line.default_color = _resolve_line_color(ratio)
	if _glow:
		_glow.modulate = Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * _intensity * ratio)

func _build_arc_points(delta: Vector2) -> PackedVector2Array:
	var direction := delta
	var length := direction.length()
	if length <= 1.0:
		return PackedVector2Array([Vector2.ZERO, delta])
	var forward := direction.normalized()
	var normal := Vector2(-forward.y, forward.x)
	var steps: int = max(2, int(round(length / max(segment_length, 1.0))))
	var builder: Array = []
	builder.append(Vector2.ZERO)
	for i in range(1, steps):
		var along := float(i) / float(steps)
		var point_along := direction * along
		var jitter_scale := (1.0 - absf(along - 0.5) * 1.6)
		var offset := normal * (_rng.randf_range(-jitter_amount, jitter_amount) * jitter_scale)
		builder.append(point_along + offset)
	builder.append(direction)
	return PackedVector2Array(builder)

func _resolve_line_color(ratio: float) -> Color:
	var alpha := clampf(glow_color.a * _intensity * ratio, 0.0, 1.0)
	return Color(glow_color.r, glow_color.g, glow_color.b, alpha)

func _ensure_white_texture() -> Texture2D:
	if _glow.texture and is_instance_valid(_glow.texture):
		return _glow.texture
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	_glow.texture = texture
	return texture

func _ensure_nodes() -> void:
	if _line == null or not is_instance_valid(_line):
		_line = Line2D.new()
		_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_line.joint_mode = Line2D.LINE_JOINT_ROUND
		_line.texture_mode = Line2D.LINE_TEXTURE_TILE
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_line.material = mat
		_line.z_index = 420
	if _line.get_parent() != self:
		add_child(_line)
	if _glow == null or not is_instance_valid(_glow):
		_glow = Sprite2D.new()
		_glow.centered = true
		_glow.scale = Vector2.ONE * 0.32
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = glow_mat
	if _glow.get_parent() != self:
		add_child(_glow)


func _configure_preview() -> void:
	# Populate a stable arc so the scene is visible in the editor viewport.
	var start := Vector2.ZERO
	var finish := Vector2(220.0, -60.0)
	_elapsed = 0.0
	configure(start, finish, 18.0, 1.0)
	if _glow:
		_glow.modulate = Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a)
