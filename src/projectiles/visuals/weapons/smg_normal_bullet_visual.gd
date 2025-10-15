@tool
extends "res://src/projectiles/visuals/weapons/base_weapon_bullet_visual.gd"
class_name SmgNormalBulletVisual

@export var preview_radius: float = 6.0
@export var preview_color: Color = Color(0.0, 1.0, 1.0, 1.0)

const SMG_GLOW_SHADER := preload("res://src/projectiles/shaders/smg_glow.gdshader")

@onready var bullet_sprite: Sprite2D = $BulletSprite
@onready var base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	if bullet_sprite:
		bullet_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		base_scale = bullet_sprite.scale
		
		# Apply glow shader to the bullet sprite
		var shader_material := ShaderMaterial.new()
		shader_material.shader = SMG_GLOW_SHADER
		shader_material.set_shader_parameter("glow_color", Color(0.0, 0.8, 1.0, 1.0))
		shader_material.set_shader_parameter("glow_intensity", 0.8)
		shader_material.set_shader_parameter("glow_size", 0.015)
		bullet_sprite.material = shader_material
	
	if Engine.is_editor_hint():
		update_visual(Vector2.RIGHT, preview_radius, preview_color)

func update_visual(direction: Vector2, radius: float, color: Color, _context: Dictionary = {}) -> void:
	var dir := direction
	if dir.length_squared() > 0.0001:
		rotation = dir.angle()
	else:
		rotation = 0.0

	var scale_factor: float = max(radius / 6.0, 0.5)
	if bullet_sprite:
		bullet_sprite.scale = base_scale * scale_factor
		var modulated_color := _apply_color(color)
		bullet_sprite.modulate = modulated_color
		
		# Adjust glow based on lighting conditions (day vs night)
		var is_day_scene: bool = BasicProjectileVisual._is_day_time
		var glow_intensity: float = 0.05 if is_day_scene else 0.8
		var glow_size: float = 0.001 if is_day_scene else 0.015
		
		if bullet_sprite.material is ShaderMaterial:
			var shader_material: ShaderMaterial = bullet_sprite.material as ShaderMaterial
			shader_material.set_shader_parameter("glow_intensity", glow_intensity)
			shader_material.set_shader_parameter("glow_size", glow_size)
