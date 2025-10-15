@tool
extends Node2D
class_name TracerBulletVisual

var apply_color_callback: Callable = Callable()
var _white_texture: Texture2D = null
var _body: Line2D = null
var _tip: Sprite2D = null

func _ready() -> void:
	if Engine.is_editor_hint():
		configure_visual({
			"color": Color(1.0, 0.85, 0.35, 1.0),
			"radius": 6.0
		})

func set_apply_color_callback(callback: Callable) -> void:
	apply_color_callback = callback

func set_white_texture(texture: Texture2D) -> void:
	_white_texture = texture
	if _tip:
		_tip.texture = _white_texture if _white_texture else _create_white_texture()

func configure_visual(params: Dictionary) -> void:
	var color: Color = params.get("color", Color(1.0, 0.9, 0.4, 1.0))
	var radius: float = float(params.get("radius", 4.0))
	_update_visual(Vector2.RIGHT, radius, color, 0.0)

func update_visual(direction: Vector2, radius: float, color: Color, context: Dictionary = {}) -> void:
	var speed_value: float = float(context.get("speed", 0.0))
	_update_visual(direction, radius, color, speed_value)

func _update_visual(direction: Vector2, radius: float, color: Color, speed_value: float) -> void:
	_ensure_nodes()
	var dir := direction
	if dir.length_squared() == 0.0:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var compensated_color := _apply_color(color, Vector2.ZERO)
	var speed_scale := 1.0
	if speed_value > 0.0:
		speed_scale = clampf(speed_value / 900.0, 0.8, 1.6)
	var length: float = max(radius * 2.6 * speed_scale, 14.0)
	var front: Vector2 = dir * (length * 0.5)
	var back: Vector2 = -dir * (length * 0.35)
	_body.points = PackedVector2Array([back, front])
	_body.width = max(1.8, radius * 0.65)
	var gradient := _body.gradient
	if gradient:
		gradient.colors = PackedColorArray([
			Color(compensated_color.r, compensated_color.g, compensated_color.b, 0.0),
			Color(compensated_color.r, compensated_color.g, compensated_color.b, compensated_color.a),
			Color(compensated_color.r, compensated_color.g, compensated_color.b, 0.0)
		])
	_body.rotation = 0.0
	_tip.position = front
	var tip_scale: float = max(_body.width * 0.85, 3.0)
	_tip.scale = Vector2.ONE * (tip_scale * 0.25)
	_tip.rotation = dir.angle()
	var tip_color := _apply_color(color, front)
	_tip.modulate = Color(tip_color.r, tip_color.g, tip_color.b, clampf(tip_color.a * 1.05, 0.0, 1.0))

func _ensure_nodes() -> void:
	if _body == null:
		_body = Line2D.new()
		_body.width = 6.0
		_body.joint_mode = Line2D.LINE_JOINT_ROUND
		_body.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_body.end_cap_mode = Line2D.LINE_CAP_ROUND
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([
			Color(1.0, 0.8, 0.2, 0.0),
			Color(1.0, 0.8, 0.2, 1.0),
			Color(1.0, 0.8, 0.2, 0.0)
		])
		gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		_body.gradient = gradient
		add_child(_body)
	if _tip == null:
		_tip = Sprite2D.new()
		_tip.centered = true
		_tip.texture = _white_texture if _white_texture else _create_white_texture()
		var tip_material := CanvasItemMaterial.new()
		tip_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_tip.material = tip_material
		add_child(_tip)

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
