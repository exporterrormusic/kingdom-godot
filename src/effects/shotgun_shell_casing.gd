extends Node2D
class_name ShotgunShellCasing

@export var lifetime: float = 1.6
@export var friction: float = 4.2
@export var bounce_damping: float = 0.36
@export var vertical_gravity: float = 640.0
@export var casing_color: Color = Color(1.0, 0.82, 0.28, 1.0)

var _age: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _angular_velocity: float = 0.0
var _height: float = 0.0
var _vertical_velocity: float = 0.0
var _sprite: Sprite2D = null
var _base_scale: Vector2 = Vector2(12.0, 4.4)
var _white_texture: Texture2D = null
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_create_sprite()
	set_process(true)
	z_index = 80

func configure(forward: Vector2, base_color: Color) -> void:
	var side_sign := -1.0 if _rng.randf() < 0.55 else 1.0
	var eject_angle := deg_to_rad(side_sign * _rng.randf_range(70.0, 110.0))
	var dir := forward.normalized() if forward.length() > 0.0 else Vector2.RIGHT
	var eject_direction := dir.rotated(eject_angle)
	_velocity = eject_direction * _rng.randf_range(140.0, 240.0)
	_angular_velocity = deg_to_rad(_rng.randf_range(-540.0, 540.0))
	_height = _rng.randf_range(16.0, 26.0)
	_vertical_velocity = _rng.randf_range(140.0, 200.0)
	var tinted := Color(
		clampf(base_color.r * 0.85 + 0.15, 0.0, 1.0),
		clampf(base_color.g * 0.7 + 0.25, 0.0, 1.0),
		clampf(base_color.b * 0.25 + 0.35, 0.0, 1.0),
		1.0
	)
	_sprite.modulate = tinted
	_sprite.scale = _base_scale
	_sprite.rotation = 0.0
	rotation = dir.angle()

func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var damping := clampf(delta * friction, 0.0, 0.9)
	_velocity = _velocity.lerp(Vector2.ZERO, damping)
	position += _velocity * delta
	rotation += _angular_velocity * delta
	_angular_velocity = lerp(_angular_velocity, 0.0, damping * 0.65)
	_vertical_velocity -= vertical_gravity * delta
	_height += _vertical_velocity * delta
	if _height <= 0.0:
		_height = 0.0
		_vertical_velocity = -_vertical_velocity * bounce_damping
		if absf(_vertical_velocity) < 28.0:
			_vertical_velocity = 0.0
	_sprite.position.y = -_height
	var life_ratio := clampf(1.0 - (_age / max(lifetime, 0.001)), 0.0, 1.0)
	var fade := pow(life_ratio, 1.2)
	_sprite.modulate.a = fade
	_sprite.scale = _base_scale * (0.82 + 0.18 * life_ratio)
	if life_ratio <= 0.02:
		queue_free()

func _create_sprite() -> void:
	_ensure_white_texture()
	_sprite = Sprite2D.new()
	_sprite.texture = _white_texture
	_sprite.centered = true
	_sprite.scale = _base_scale
	_sprite.modulate = casing_color
	_sprite.position = Vector2.ZERO
	add_child(_sprite)

func _ensure_white_texture() -> void:
	if _white_texture != null:
		return
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 1.0))
	_white_texture = ImageTexture.create_from_image(image)
