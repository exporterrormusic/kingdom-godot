@tool
extends Node2D
class_name CircleBulletVisual

const BULLET_SHADER := preload("res://src/projectiles/shaders/bullet_circle.gdshader")

var apply_color_callback: Callable = Callable()
var _white_texture: Texture2D = null
var _sprite: Sprite2D = null

func _ready() -> void:
	if Engine.is_editor_hint():
		configure_visual({
			"color": Color(1.0, 0.9, 0.4, 1.0),
			"radius": 6.0
		})

func set_apply_color_callback(callback: Callable) -> void:
	apply_color_callback = callback

func set_white_texture(texture: Texture2D) -> void:
	_white_texture = texture
	if _sprite:
		_sprite.texture = _white_texture if _white_texture else _create_white_texture()

func configure_visual(params: Dictionary) -> void:
	var color: Color = params.get("color", Color(1.0, 0.9, 0.4, 1.0))
	var radius: float = float(params.get("radius", 4.0))
	_ensure_sprite()
	_sprite.scale = Vector2.ONE * max(radius * 1.4, 1.2)
	_update_colors(color)

func update_visual(_direction: Vector2, radius: float, color: Color, _context := {}) -> void:
	configure_visual({"color": color, "radius": radius})

func _ensure_sprite() -> void:
	if _sprite:
		return
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_sprite.texture = _white_texture if _white_texture else _create_white_texture()
	var shader_material := ShaderMaterial.new()
	shader_material.shader = BULLET_SHADER
	_sprite.material = shader_material
	add_child(_sprite)

func _update_colors(color: Color) -> void:
	if _sprite == null or _sprite.material == null:
		return
	var shaded: Color = _apply_color(color)
	var shader_material := _sprite.material as ShaderMaterial
	shader_material.set_shader_parameter("fill_color", shaded)
	shader_material.set_shader_parameter("edge_softness", 0.18)
	shader_material.set_shader_parameter("intensity", 1.8)

func _apply_color(color: Color) -> Color:
	if apply_color_callback and apply_color_callback.is_valid():
		return apply_color_callback.call(color, Vector2.ZERO)
	return color

func _create_white_texture() -> Texture2D:
	if _white_texture:
		return _white_texture
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_white_texture = ImageTexture.create_from_image(image)
	return _white_texture
