@tool
extends "res://src/projectiles/visuals/weapons/base_weapon_bullet_visual.gd"
class_name ShotgunSpecialPelletVisual

@export var preview_radius: float = 6.0
@export var preview_color: Color = Color(1.0, 0.74, 0.32, 1.0)

const SMG_GLOW_SHADER := preload("res://src/projectiles/shaders/smg_glow.gdshader")

@onready var bullet_sprite: Sprite2D = $BulletSprite
@onready var fire_particles: GPUParticles2D = $FireParticles
@onready var spark_particles: GPUParticles2D = $SparkParticles
@onready var base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	if bullet_sprite:
		bullet_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		base_scale = bullet_sprite.scale
		
		# Apply glow shader to the bullet sprite
		var shader_material := ShaderMaterial.new()
		shader_material.shader = SMG_GLOW_SHADER
		shader_material.set_shader_parameter("glow_color", Color(1.0, 0.2, 0.0, 1.0))
		shader_material.set_shader_parameter("glow_intensity", 1.2)
		shader_material.set_shader_parameter("glow_size", 0.018)
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
		
		# Adjust glow based on lighting conditions (day vs night) with pulsing effect
		var is_day_scene: bool = BasicProjectileVisual._is_day_time
		var base_glow_intensity: float = 0.4 if is_day_scene else 1.2
		var base_glow_size: float = 0.006 if is_day_scene else 0.018

		# Apply pulsing effect for special bullet
		var time := Time.get_ticks_msec() / 1000.0
		var pulse := 1.0 + sin(time * 10.0) * 0.4
		var glow_intensity := base_glow_intensity * pulse
		var glow_size := base_glow_size * pulse

		if bullet_sprite.material is ShaderMaterial:
			var shader_material: ShaderMaterial = bullet_sprite.material as ShaderMaterial
			shader_material.set_shader_parameter("glow_intensity", glow_intensity)
			shader_material.set_shader_parameter("glow_size", glow_size)

	# Configure fire particles
	if fire_particles:
		fire_particles.emitting = true
		fire_particles.amount = 8
		fire_particles.lifetime = 0.3
		fire_particles.process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		fire_particles.process_material.emission_sphere_radius = radius * 0.8
		fire_particles.process_material.initial_velocity_min = 20.0
		fire_particles.process_material.initial_velocity_max = 40.0
		fire_particles.process_material.direction = Vector3(dir.x, dir.y, 0.0)
		fire_particles.process_material.spread = 30.0
		fire_particles.process_material.color = Color(1.0, 0.4, 0.0, 0.8)  # Orange fire
		fire_particles.scale = Vector2.ONE * scale_factor

	# Configure spark particles
	if spark_particles:
		spark_particles.emitting = true
		spark_particles.amount = 12
		spark_particles.lifetime = 0.2
		spark_particles.process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		spark_particles.process_material.emission_sphere_radius = radius * 0.5
		spark_particles.process_material.initial_velocity_min = 50.0
		spark_particles.process_material.initial_velocity_max = 80.0
		spark_particles.process_material.direction = Vector3(dir.x, dir.y, 0.0)
		spark_particles.process_material.spread = 45.0
		spark_particles.process_material.color = Color(1.0, 0.8, 0.0, 1.0)  # Yellow sparks
		spark_particles.scale = Vector2.ONE * scale_factor
