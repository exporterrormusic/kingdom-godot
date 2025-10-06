extends Node2D
class_name ExplosionEffect

@export var radius: float = 120.0
@export var base_color: Color = Color(1.0, 0.5, 0.2, 0.7)
@export var duration: float = 0.35
@export var ring_thickness: float = 6.0
@export var glow_color: Color = Color(1.0, 0.55, 0.18, 0.6)
@export var core_color: Color = Color(1.0, 0.88, 0.6, 0.9)
@export var shockwave_color: Color = Color(1.0, 0.7, 0.25, 0.9)
@export var shockwave_thickness: float = 12.0
@export var spark_color: Color = Color(1.0, 0.82, 0.45, 0.85)
@export var spark_count: int = 12

var _elapsed := 0.0
var _rng := RandomNumberGenerator.new()
var _rotation_offset := 0.0
var _spark_lengths: Array = []

func _ready() -> void:
	_rng.randomize()
	_rotation_offset = _rng.randf_range(0.0, TAU)
	_spark_lengths.clear()
	for i in range(max(spark_count, 0)):
		_spark_lengths.append(_rng.randf_range(0.75, 1.25))
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if duration <= 0.0:
		return
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	var fade := 1.0 - progress
	var glow := Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * fade * 0.75)
	var glow_radius := radius * (1.15 + 0.35 * progress)
	draw_circle(Vector2.ZERO, glow_radius, glow)
	var core := Color(core_color.r, core_color.g, core_color.b, core_color.a * fade)
	var core_radius := radius * (0.35 + 0.25 * (1.0 - progress))
	draw_circle(Vector2.ZERO, core_radius, core)
	var main_ring := Color(base_color.r, base_color.g, base_color.b, base_color.a * fade)
	var ring_radius := radius * (0.8 + 0.25 * progress)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 60, main_ring, max(1.5, ring_thickness))
	var shock := Color(shockwave_color.r, shockwave_color.g, shockwave_color.b, shockwave_color.a * fade)
	var shock_radius := radius * (0.95 + 0.8 * progress)
	draw_arc(Vector2.ZERO, shock_radius, 0.0, TAU, 48, shock, shockwave_thickness)
	_draw_sparks(progress, fade)
	_draw_debris(progress, fade)

func _draw_sparks(progress: float, fade: float) -> void:
	if spark_count <= 0:
		return
	var spark_alpha := spark_color.a * fade
	var base_radius := radius * (0.45 + 0.25 * progress)
	for i in range(spark_count):
		var angle := _rotation_offset + TAU * float(i) / float(max(spark_count, 1))
		var length_factor := 1.0
		if i < _spark_lengths.size():
			length_factor = _spark_lengths[i]
		var expansion := (1.0 - progress) * length_factor
		var inner := Vector2(cos(angle), sin(angle)) * base_radius * 0.6
		var outer := Vector2(cos(angle), sin(angle)) * base_radius * (1.1 + 0.5 * expansion)
		var spark := Color(spark_color.r, spark_color.g, spark_color.b, spark_alpha)
		draw_line(inner, outer, spark, 3.0, true)
		spark.a *= 0.8
		draw_circle(outer, max(2.0, radius * 0.08 * expansion), spark)

func _draw_debris(progress: float, fade: float) -> void:
	var debris_count := int(clampf(radius / 24.0, 6.0, 20.0))
	var debris_color := Color(base_color.r, base_color.g, base_color.b, base_color.a * fade * 0.6)
	for i in range(debris_count):
		var angle := _rotation_offset + TAU * float(i) / float(debris_count)
		var wobble := sin(_elapsed * 6.0 + float(i)) * 0.12
		var distance := radius * (0.6 + progress * 0.8 + wobble)
		var point := Vector2(cos(angle), sin(angle)) * distance
		draw_circle(point, radius * 0.05, debris_color)
