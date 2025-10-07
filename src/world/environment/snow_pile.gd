extends StaticBody2D
class_name SnowPile

@export_range(16.0, 256.0, 1.0) var radius: float = 96.0:
	set(value):
		radius = value
		_update_shapes()
@export_range(8.0, 256.0, 1.0) var height: float = 64.0:
	set(value):
		height = value
		_update_visual()
@export_range(0.0, 1.0, 0.01) var opacity: float = 0.85:
	set(value):
		opacity = clampf(value, 0.0, 1.0)
		_update_visual()

var _collision_shape: CollisionShape2D
var _sprite: Sprite2D
var _gradient_texture: GradientTexture2D

func _ready() -> void:
	_collision_shape = CollisionShape2D.new()
	add_child(_collision_shape)
	if Engine.is_editor_hint():
		_collision_shape.owner = self
	_sprite = Sprite2D.new()
	_sprite.z_index = -30
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)
	if Engine.is_editor_hint():
		_sprite.owner = self
	_create_gradient_texture()
	_update_shapes()
	_update_visual()

func _create_gradient_texture() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.45),
		Color(0.96, 0.99, 1.0, 0.92),
		Color(0.94, 0.98, 1.0, 1.0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.78, 1.0])
	_gradient_texture = GradientTexture2D.new()
	_gradient_texture.gradient = gradient
	_gradient_texture.width = 512
	_gradient_texture.height = 512
	_gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	_sprite.texture = _gradient_texture

func _update_shapes() -> void:
	if _collision_shape == null:
		return
	var shape := CircleShape2D.new()
	shape.radius = radius
	_collision_shape.shape = shape

func _update_visual() -> void:
	if _sprite == null:
		return
	var uniform_scale: float = max(radius, 1.0) / 128.0
	_sprite.scale = Vector2.ONE * uniform_scale
	_sprite.modulate = Color(1.0, 1.0, 1.0, opacity)
	_sprite.position = Vector2.ZERO
