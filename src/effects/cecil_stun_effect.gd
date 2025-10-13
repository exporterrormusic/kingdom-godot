extends Node2D
class_name CecilStunEffect

@export var base_radius: float = 32.0
@export var ring_thickness: float = 3.0
@export var spark_count: int = 12
@export var static_refresh_interval: float = 0.08
@export var lightning_chance: float = 0.4
@export var static_chance: float = 0.7
@export var spark_jitter: float = 6.0

var _time: float = 0.0
var _noise_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _static_points: Array = []
var _spark_points: Array = []
var _lightning_paths: Array = []

func _ready() -> void:
	_rng.randomize()
	set_process(true)
	update_effect_geometry()
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	_noise_timer += delta
	if _should_remove():
		queue_free()
		return
	if _noise_timer >= static_refresh_interval:
		_noise_timer = 0.0
		update_effect_geometry()
	queue_redraw()

func _should_remove() -> bool:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return true
	if parent.has_method("is_stunned") and not parent.is_stunned():
		return true
	return false

func update_effect_geometry() -> void:
	_static_points.clear()
	_spark_points.clear()
	_lightning_paths.clear()
	var spark_radius := base_radius
	for i in range(spark_count):
		var angle := float(i) / float(max(1, spark_count)) * TAU
		var offset := Vector2.RIGHT.rotated(angle) * spark_radius
		offset += Vector2(
			_rng.randf_range(-spark_jitter, spark_jitter),
			_rng.randf_range(-spark_jitter, spark_jitter)
		)
		_spark_points.append(offset)
		if static_chance > 0.0 and _rng.randf() <= static_chance:
			var noise_angle := _rng.randf_range(0.0, TAU)
			var noise_radius := _rng.randf_range(0.4 * base_radius, 1.2 * base_radius)
			var noise_position := Vector2.RIGHT.rotated(noise_angle) * noise_radius
			var noise_size := _rng.randi_range(2, 4)
			_static_points.append({
				"position": noise_position,
				"size": noise_size,
				"alpha": _rng.randf_range(0.35, 0.9)
			})
	for i in range(_spark_points.size()):
		for j in range(i + 1, _spark_points.size()):
			if _rng.randf() > lightning_chance:
				continue
			var a: Vector2 = _spark_points[i]
			var b: Vector2 = _spark_points[j]
			if a.distance_squared_to(b) > base_radius * base_radius * 2.1:
				continue
			_lightning_paths.append(_build_lightning_path(a, b))

func _build_lightning_path(start: Vector2, end: Vector2) -> PackedVector2Array:
	var point_count := _rng.randi_range(3, 5)
	var points := PackedVector2Array()
	points.append(start)
	for k in range(1, point_count):
		var t := float(k) / float(point_count)
		var base := start.lerp(end, t)
		var offset := Vector2(
			_rng.randf_range(-spark_jitter * 1.6, spark_jitter * 1.6),
			_rng.randf_range(-spark_jitter * 1.6, spark_jitter * 1.6)
		)
		points.append(base + offset)
	points.append(end)
	return points

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	var base_color := Color(0.0, 0.58, 0.98, 0.65)
	var accent_color := Color(0.45, 0.85, 1.0, 0.8)
	var spark_color := Color(1.0, 1.0, 1.0, 0.85)
	var glow_radius := base_radius + 18.0
	draw_circle(Vector2.ZERO, glow_radius, Color(base_color.r, base_color.g, base_color.b, 0.18 + 0.12 * pulse))
	draw_circle(Vector2.ZERO, base_radius + 8.0, Color(base_color.r, base_color.g, base_color.b, 0.25 + 0.2 * pulse))
	for ring in range(3):
		var radius: float = base_radius + float(ring) * 6.0
		var thickness: float = maxf(1.5, ring_thickness - float(ring) * 0.7)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(accent_color.r, accent_color.g, accent_color.b, 0.35 + 0.1 * pulse), thickness)
	for static_data in _static_points:
		var pos: Vector2 = static_data["position"]
		var size := float(static_data["size"])
		var alpha := float(static_data["alpha"])
		var color := Color(
			accent_color.r + _rng.randf_range(-0.1, 0.1),
			accent_color.g + _rng.randf_range(-0.05, 0.05),
			accent_color.b,
			alpha
		)
		draw_rect(Rect2(pos - Vector2(size * 0.5, size * 0.5), Vector2(size, size)), color, true)
	for spark in _spark_points:
		var glow_alpha := 0.18 + 0.12 * pulse
		draw_circle(spark, 10.0, Color(base_color.r, base_color.g, base_color.b, glow_alpha))
		draw_circle(spark, 6.0, Color(accent_color.r, accent_color.g, accent_color.b, 0.35 + 0.25 * pulse))
		draw_circle(spark, 3.0, spark_color)
	for path in _lightning_paths:
		var glow := Color(accent_color.r, accent_color.g, accent_color.b, 0.25 + 0.15 * pulse)
		draw_polyline(path, glow, 6.0, true)
		draw_polyline(path, Color(0.9, 0.95, 1.0, 0.75), 2.5, true)
	draw_circle(Vector2.ZERO, 12.0 + 2.0 * pulse, Color(0.15, 0.32, 0.48, 0.6))
	draw_circle(Vector2.ZERO, 6.5, Color(0.85, 0.97, 1.0, 0.95))
