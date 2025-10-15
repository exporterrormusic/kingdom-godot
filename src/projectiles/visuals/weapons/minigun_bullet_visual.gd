@tool
extends "res://src/projectiles/visuals/weapons/base_weapon_bullet_visual.gd"
class_name MinigunBulletVisual

@export var preview_radius: float = 7.0
@export var preview_color: Color = Color(0.5, 0.55, 0.6, 1.0)

const MINIGUN_GLOW_SHADER := preload("res://src/projectiles/shaders/minigun_normal_glow.gdshader")

@onready var bullet_sprite: Sprite2D = $BulletSprite
@onready var base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	if bullet_sprite:
		bullet_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		base_scale = bullet_sprite.scale
		
		# Apply glow shader to the bullet sprite
		var shader_material := ShaderMaterial.new()
		shader_material.shader = MINIGUN_GLOW_SHADER
		shader_material.set_shader_parameter("glow_color", Color.WHITE)
		shader_material.set_shader_parameter("glow_intensity", 0.5)
		shader_material.set_shader_parameter("glow_size", 0.004)
		bullet_sprite.material = shader_material
	
	if Engine.is_editor_hint():
		update_visual(Vector2.RIGHT, preview_radius, preview_color)

func update_visual(direction: Vector2, radius: float, color: Color, _context: Dictionary = {}) -> void:
	var dir := direction
	if dir.length_squared() < 0.000001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	rotation = dir.angle()

	var scale_factor: float = max(radius / 6.0, 0.5)
	if bullet_sprite:
		bullet_sprite.scale = base_scale * scale_factor
	var modulated_color := _apply_color(color)
	bullet_sprite.modulate = modulated_color
	
	# Adjust glow based on lighting conditions (day vs night)
	var is_day_scene: bool = BasicProjectileVisual._is_day_time
	var glow_intensity: float = 0.2 if is_day_scene else 0.5
	var glow_size: float = 0.002 if is_day_scene else 0.004
	
	if bullet_sprite.material is ShaderMaterial:
		var shader_material: ShaderMaterial = bullet_sprite.material as ShaderMaterial
		shader_material.set_shader_parameter("glow_intensity", glow_intensity)
		shader_material.set_shader_parameter("glow_size", glow_size)
