extends Node2D
class_name SnowWhiteLingeringEffect

@export var duration: float = 2.0
@export var particle_count: int = 40
@export var beam_range: float = 1200.0
@export var beam_angle_degrees: float = 45.0
@export var min_particle_radius: float = 100.0
@export var max_particle_radius: float = 900.0
@export var min_particle_size: float = 2.0
@export var max_particle_size: float = 6.0
@export var min_speed: float = -18.0
@export var max_speed: float = 18.0

const PARTICLE_COLORS := [
	Color(1.0, 1.0, 1.0, 1.0),
	Color(0.82, 0.93, 1.0, 1.0),
	Color(0.68, 0.85, 1.0, 1.0),
	Color(0.58, 0.78, 1.0, 1.0)
]

var _particles: Array = []
var _age: float = 0.0
var _forward: Vector2 = Vector2.RIGHT
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	set_process(true)
	set_notify_transform(true)
	z_index = 415

func configure(forward: Vector2, range_distance: float, angle_degrees: float) -> void:
	_forward = forward.normalized() if forward.length() > 0.0 else Vector2.RIGHT
	beam_range = clampf(range_distance, 200.0, 2400.0)
	beam_angle_degrees = clampf(angle_degrees, 5.0, 150.0)
	_particles = _generate_particles()
	queue_redraw()

func _generate_particles() -> Array:
	var result: Array = []
	var total: int = max(1, particle_count)
	var total_angle := deg_to_rad(beam_angle_degrees)
	for _i in range(total):
		var distance := _rng.randf_range(min_particle_radius, min(max_particle_radius, beam_range))
		var offset := _rng.randf_range(-total_angle * 0.5, total_angle * 0.5)
		var velocity := Vector2(_rng.randf_range(min_speed, max_speed), _rng.randf_range(min_speed, max_speed))
		var size := _rng.randf_range(min_particle_size, max_particle_size)
		var max_life := _rng.randf_range(duration * 0.6, duration * 1.1)
		var fade_start := clampf(max_life * _rng.randf_range(0.6, 0.95), 0.1, max_life)
		var color: Color = PARTICLE_COLORS[_rng.randi_range(0, PARTICLE_COLORS.size() - 1)]
		var direction := _forward.rotated(offset)
		result.append({
			"position": direction * distance,
			"velocity": velocity,
			"size": size,
			"life": max_life,
			"max_life": max_life,
			"fade_start": fade_start,
			"color": color
		})
	return result

func _process(delta: float) -> void:
	_age += delta
	if _particles.is_empty():
		queue_free()
		return
	for particle in _particles:
		particle["position"] = particle["position"] + particle["velocity"] * delta
		particle["velocity"] = particle["velocity"] * 0.94
		particle["life"] = particle["life"] - delta
	_particles = _particles.filter(func(particle): return float(particle["life"]) > 0.0)
	if _age >= duration and _particles.is_empty():
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if _particles.is_empty():
		return
	for particle in _particles:
		var draw_position: Vector2 = particle["position"]
		var size: float = particle["size"]
		var max_life: float = max(float(particle["max_life"]), 0.001)
		var life_fraction := clampf(float(particle["life"]) / max_life, 0.0, 1.0)
		var fade_ratio := clampf(float(particle["life"]) / max(float(particle["fade_start"]), 0.001), 0.0, 1.0)
		var alpha := life_fraction * 0.7 * fade_ratio
		if alpha <= 0.02:
			continue
		var color: Color = particle["color"]
		var particle_color := Color(color.r, color.g, color.b, color.a * alpha)
		draw_circle(draw_position, size, particle_color)
		if alpha > 0.25:
			var glow := Color(color.r, color.g, color.b, particle_color.a * 0.4)
			draw_circle(draw_position, size * 1.65, glow)
