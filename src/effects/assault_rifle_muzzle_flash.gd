extends Node2D
class_name AssaultRifleMuzzleFlash

@export var duration: float = 0.14
@export var flash_length: float = 88.0
@export var flash_width: float = 26.0
@export var glow_color: Color = Color(1.0, 0.88, 0.62, 0.9)
@export var core_color: Color = Color(1.0, 0.95, 0.85, 0.95)
@export var spark_color: Color = Color(1.0, 0.72, 0.28, 0.85)

var _age: float = 0.0
var _forward: Vector2 = Vector2.RIGHT
var _spark_particles: GPUParticles2D = null
var _spark_material: ParticleProcessMaterial = null

func _ready() -> void:
	set_process(true)
	z_index = 340
	_setup_sparks()
	queue_redraw()

func configure(forward: Vector2, base_color: Color) -> void:
	_forward = forward.normalized() if forward.length() > 0.0 else Vector2.RIGHT
	var warmed := Color(
		clampf(base_color.r * 0.95 + 0.05, 0.0, 1.0),
		clampf(base_color.g * 0.85 + 0.1, 0.0, 1.0),
		clampf(base_color.b * 0.55 + 0.2, 0.0, 1.0),
		0.9
	)
	glow_color = Color(warmed.r, warmed.g, warmed.b, 0.9)
	core_color = Color(1.0, 0.97, 0.86, 0.96)
	spark_color = Color(1.0, 0.76, 0.32, 0.92)
	_update_spark_direction()
	_restart_particles()
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var life_ratio := clampf(1.0 - (_age / max(duration, 0.001)), 0.0, 1.0)
	var eased := pow(life_ratio, 0.3)
	var center := Vector2.ZERO
	var half_width := flash_width * 0.5 * (0.6 + 0.4 * eased)
	var length := flash_length * (0.72 + 0.28 * eased)
	var dir := _forward.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var right := Vector2(-dir.y, dir.x)

	var tip := center + dir * length
	var base := center - dir * length * 0.25
	var core_alpha := clampf(core_color.a * (0.7 + 0.3 * eased), 0.0, 1.0)
	draw_line(base - right * half_width, tip + right * (half_width * 0.2), Color(glow_color.r, glow_color.g, glow_color.b, core_alpha * 0.6), half_width * 1.8, true)
	draw_line(base + right * half_width, tip - right * (half_width * 0.2), Color(glow_color.r, glow_color.g, glow_color.b, core_alpha * 0.6), half_width * 1.8, true)
	draw_line(base, tip, Color(core_color.r, core_color.g, core_color.b, core_alpha), max(4.0, half_width * 0.9), true)

	var center_glow := Color(glow_color.r, glow_color.g, glow_color.b, core_alpha * 0.75)
	draw_circle(center, half_width * 0.9, center_glow)
	draw_circle(tip, max(6.0, half_width * 0.65), Color(core_color.r, core_color.g, core_color.b, core_alpha * 0.85))

	for i in range(5):
		var t := float(i) / 4.0
		var spark_pos := center.lerp(tip, 0.4 + 0.5 * t) + right * (half_width * 0.4 * (0.5 - t))
		var alpha := clampf(0.7 * eased * (1.0 - t * 0.6), 0.0, 1.0)
		draw_circle(spark_pos, max(2.0, half_width * 0.24 * (1.0 - t)), Color(spark_color.r, spark_color.g, spark_color.b, alpha))

func _setup_sparks() -> void:
	_spark_particles = GPUParticles2D.new()
	_spark_particles.one_shot = true
	_spark_particles.amount = 20
	_spark_particles.lifetime = 0.24
	_spark_particles.preprocess = 0.0
	_spark_particles.emitting = false
	_spark_particles.z_index = z_index + 1
	_spark_material = ParticleProcessMaterial.new()
	_spark_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	_spark_material.initial_velocity_min = 220.0
	_spark_material.initial_velocity_max = 360.0
	_spark_material.gravity = Vector3.ZERO
	_spark_material.damping_min = 16.0
	_spark_material.damping_max = 22.0
	_spark_material.scale_min = 0.35
	_spark_material.scale_max = 0.6
	_spark_material.angle_min = -22.0
	_spark_material.angle_max = 22.0
	_spark_material.angular_velocity_min = -18.0
	_spark_material.angular_velocity_max = 18.0
	_spark_material.spread = 32.0
	_spark_material.color = spark_color
	_spark_particles.process_material = _spark_material
	add_child(_spark_particles)

func _update_spark_direction() -> void:
	if _spark_particles == null or _spark_material == null:
		return
	var dir := _forward.normalized() if _forward.length() > 0.0 else Vector2.RIGHT
	_spark_material.direction = Vector3(dir.x, dir.y, 0.0)
	_spark_material.color = spark_color
	_spark_particles.rotation = dir.angle()

func _restart_particles() -> void:
	if _spark_particles == null:
		return
	_spark_particles.restart()
	_spark_particles.emitting = true