extends Node2D
class_name ShotgunMuzzleFlash

@export var duration: float = 0.18
@export var flash_radius: float = 68.0
@export var cone_angle: float = 36.0
@export var base_color: Color = Color(1.0, 0.68, 0.32, 0.88)
@export var glow_color: Color = Color(1.0, 0.92, 0.75, 0.95)
@export var spark_color: Color = Color(1.0, 0.86, 0.42, 0.86)

var _age: float = 0.0
var _forward: Vector2 = Vector2.RIGHT
var _spark_particles: GPUParticles2D = null
var _spark_material: ParticleProcessMaterial = null

func _ready() -> void:
	set_process(true)
	z_index = 360
	_setup_sparks()
	queue_redraw()

func configure(forward: Vector2, muzzle_color: Color) -> void:
	_forward = forward.normalized() if forward.length() > 0.0 else Vector2.RIGHT
	base_color = Color(
		clampf(muzzle_color.r * 0.9 + 0.1, 0.0, 1.0),
		clampf(muzzle_color.g * 0.75 + 0.18, 0.0, 1.0),
		clampf(muzzle_color.b * 0.55 + 0.25, 0.0, 1.0),
		0.88
	)
	glow_color = Color(1.0, 0.94, 0.82, 0.95)
	spark_color = Color(1.0, 0.86, 0.45, 0.88)
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
	var life_ratio: float = clampf(1.0 - (_age / max(duration, 0.001)), 0.0, 1.0)
	var eased := pow(life_ratio, 0.28)
	var core_radius := flash_radius * (0.28 + 0.22 * eased)
	var flare_radius := flash_radius * (0.85 + 0.15 * eased)
	var half_angle := deg_to_rad(cone_angle * 0.5)
	var left_dir := _forward.rotated(-half_angle)
	var right_dir := _forward.rotated(half_angle)

	var core := Color(glow_color.r, glow_color.g, glow_color.b, clampf(glow_color.a * (0.65 + 0.35 * eased), 0.0, 1.0))
	draw_circle(Vector2.ZERO, core_radius, core)

	var base := Color(base_color.r, base_color.g, base_color.b, clampf(base_color.a * (0.75 + 0.25 * eased), 0.0, 1.0))
	var forward_point := _forward * flare_radius
	draw_line(Vector2.ZERO, forward_point, base, max(18.0, flash_radius * 0.32) * (0.55 + 0.45 * eased), true)
	draw_line(Vector2.ZERO, left_dir * (flare_radius * 0.92), base, max(12.0, flash_radius * 0.24) * (0.45 + 0.55 * eased), true)
	draw_line(Vector2.ZERO, right_dir * (flare_radius * 0.92), base, max(12.0, flash_radius * 0.24) * (0.45 + 0.55 * eased), true)

	var tip_highlight := Color(1.0, 0.96, 0.76, clampf(0.85 * eased, 0.0, 1.0))
	draw_circle(_forward * (flare_radius * 0.58), max(10.0, flash_radius * 0.18) * (0.6 + 0.4 * eased), tip_highlight)

	var crossbar_center := _forward * (flare_radius * 0.48)
	var normal := Vector2(-_forward.y, _forward.x).normalized()
	draw_line(crossbar_center - normal * (flash_radius * 0.22), crossbar_center + normal * (flash_radius * 0.22), tip_highlight, max(6.0, flash_radius * 0.12) * (0.6 + 0.4 * eased), true)

	for i in range(6):
		var t := float(i) / 5.0
		var spark_pos := _forward * (flare_radius * (0.32 + 0.46 * t))
		spark_pos += normal.rotated((t - 0.5) * PI * 0.5) * flash_radius * 0.08 * (1.0 - t)
		var spark_alpha := clampf(0.6 * eased * (1.0 - t * 0.6), 0.0, 1.0)
		draw_circle(spark_pos, max(3.0, flash_radius * 0.04 * (1.0 - t)), Color(spark_color.r, spark_color.g, spark_color.b, spark_alpha))

func _setup_sparks() -> void:
	_spark_particles = GPUParticles2D.new()
	_spark_particles.one_shot = true
	_spark_particles.amount = 30
	_spark_particles.lifetime = 0.32
	_spark_particles.preprocess = 0.0
	_spark_particles.emitting = false
	_spark_particles.z_index = z_index + 1
	_spark_material = ParticleProcessMaterial.new()
	_spark_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	_spark_material.initial_velocity_min = 160.0
	_spark_material.initial_velocity_max = 300.0
	_spark_material.gravity = Vector3.ZERO
	_spark_material.damping_min = 18.0
	_spark_material.damping_max = 26.0
	_spark_material.scale_min = 0.45
	_spark_material.scale_max = 0.8
	_spark_material.angle_min = -18.0
	_spark_material.angle_max = 18.0
	_spark_material.angular_velocity_min = -24.0
	_spark_material.angular_velocity_max = 24.0
	_spark_material.spread = 28.0
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
