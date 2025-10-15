@tool
extends "res://src/projectiles/visuals/weapons/base_weapon_bullet_visual.gd"
class_name SmgSpecialBulletVisual

@export var preview_radius: float = 6.5
@export var preview_color: Color = Color(0.3, 0.95, 1.0, 1.0)

const SMG_GLOW_SHADER := preload("res://src/projectiles/shaders/smg_glow.gdshader")

@onready var bullet_sprite: Sprite2D = $BulletSprite
@onready var base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	if bullet_sprite:
		bullet_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		base_scale = bullet_sprite.scale
		
		# Apply enhanced glow shader to the bullet sprite
		var shader_material := ShaderMaterial.new()
		shader_material.shader = SMG_GLOW_SHADER
		shader_material.set_shader_parameter("glow_color", Color(0.2, 0.9, 1.0, 1.0))
		shader_material.set_shader_parameter("glow_intensity", 1.2)
		shader_material.set_shader_parameter("glow_size", 0.02)
		bullet_sprite.material = shader_material
	
	if Engine.is_editor_hint():
		update_visual(Vector2.RIGHT, preview_radius, preview_color)

func update_visual(direction: Vector2, radius: float, color: Color, context: Dictionary = {}) -> void:
	var dir := direction
	if dir.length_squared() > 0.0001:
		rotation = dir.angle()
	else:
		rotation = 0.0

	var special_pulse: bool = bool(context.get("special_attack", true)) if context else true
	var pulse_scale: float = 1.12 if special_pulse else 0.96
	var scale_factor: float = max(radius / 6.0, 0.5) * pulse_scale

	if bullet_sprite:
		bullet_sprite.scale = base_scale * scale_factor
		var modulated_color := _apply_color(color)
		bullet_sprite.modulate = modulated_color
		
		# Adjust glow based on lighting conditions (day vs night)
		var is_day_scene: bool = BasicProjectileVisual._is_day_time
		var base_glow_intensity: float = 0.05 if is_day_scene else 1.2
		var base_glow_size: float = 0.001 if is_day_scene else 0.02
		
		# Apply pulsing effect for special bullet
		var time := Time.get_ticks_msec() / 1000.0
		var pulse := 1.0 + sin(time * 8.0) * 0.3
		var glow_intensity := base_glow_intensity * pulse
		var glow_size := base_glow_size * pulse
		
		if bullet_sprite.material is ShaderMaterial:
			var shader_material: ShaderMaterial = bullet_sprite.material as ShaderMaterial
			shader_material.set_shader_parameter("glow_intensity", glow_intensity)
			shader_material.set_shader_parameter("glow_size", glow_size)
