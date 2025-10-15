@tool
extends Node2D
class_name NeonBulletVisual

var apply_color_callback: Callable = Callable()
var _white_texture: Texture2D = null
var _glow_line: Line2D = null
var _core_line: Line2D = null
var _tip_sprite: Sprite2D = null

func _ready() -> void:
	if Engine.is_editor_hint():
		configure_visual({
			"color": Color(0.0, 0.85, 1.0, 1.0),
			"radius": 6.0
		})

func set_apply_color_callback(callback: Callable) -> void:
	apply_color_callback = callback

func set_white_texture(texture: Texture2D) -> void:
	_white_texture = texture
	if _tip_sprite:
		_tip_sprite.texture = _white_texture if _white_texture else _create_white_texture()

func configure_visual(params: Dictionary) -> void:
	var color: Color = params.get("color", Color(0.0, 0.85, 1.0, 1.0))
	var radius: float = float(params.get("radius", 4.0))
	_update_visual(Vector2.RIGHT, radius, color, false)

func update_visual(direction: Vector2, radius: float, color: Color, context: Dictionary = {}) -> void:
	var has_bounced: bool = bool(context.get("has_bounced", false))
	_update_visual(direction, radius, color, has_bounced)

func _update_visual(direction: Vector2, radius: float, color: Color, has_bounced: bool) -> void:
	_ensure_nodes()
	var dir := direction
	if dir.length_squared() == 0.0:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var size_multiplier := 1.5
	var length: float = max(radius * 16.0 * size_multiplier, 36.0 * size_multiplier)
	var width: float = max(radius * 3.5 * size_multiplier, 8.0 * size_multiplier)
	var half_length: float = length * 0.5
	var front: Vector2 = dir * half_length
	var back: Vector2 = -front
	var points := PackedVector2Array([back, front])
	_glow_line.points = points
	_core_line.points = points
	_glow_line.width = width * 2.4
	_core_line.width = width
	var base_color := color
	var glow_color := Color(0.0, 0.8, 1.0, 0.65)
	var core_color := Color(0.85, 1.0, 1.0, 0.95)
	if has_bounced:
		base_color = Color(1.0, 0.62, 0.18, 1.0)
		glow_color = Color(1.0, 0.5, 0.1, 0.7)
		core_color = Color(1.0, 0.85, 0.4, 0.95)
	var compensated_glow: Color = _apply_color(glow_color, Vector2.ZERO)
	var compensated_core: Color = _apply_color(Color(base_color.r, base_color.g, base_color.b, 1.0), Vector2.ZERO)
	_glow_line.gradient = _build_gradient(compensated_glow, 0.4)
	_core_line.gradient = _build_gradient(compensated_core, 0.1)
	_tip_sprite.position = front
	var tip_scale: float = max(width * 0.6, 4.0 * size_multiplier)
	_tip_sprite.scale = Vector2.ONE * (tip_scale * 0.5)
	_tip_sprite.rotation = dir.angle()
	var tip_offset := to_global(front) - global_position
	_tip_sprite.modulate = _apply_color(core_color, tip_offset)

func _ensure_nodes() -> void:
	if _glow_line == null:
		_glow_line = Line2D.new()
		_glow_line.joint_mode = Line2D.LINE_JOINT_ROUND
		_glow_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_glow_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(_glow_line)
	if _core_line == null:
		_core_line = Line2D.new()
		_core_line.joint_mode = Line2D.LINE_JOINT_ROUND
		_core_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_core_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(_core_line)
	if _tip_sprite == null:
		_tip_sprite = Sprite2D.new()
		_tip_sprite.centered = true
		_tip_sprite.texture = _white_texture if _white_texture else _create_white_texture()
		add_child(_tip_sprite)

func _build_gradient(color: Color, fade_strength: float) -> Gradient:
	var gradient := Gradient.new()
	var transparent := Color(color.r, color.g, color.b, max(0.0, color.a - fade_strength))
	gradient.colors = PackedColorArray([
		Color(transparent.r, transparent.g, transparent.b, 0.0),
		color,
		Color(transparent.r, transparent.g, transparent.b, 0.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	return gradient

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
