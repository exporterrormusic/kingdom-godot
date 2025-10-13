extends Node2D
class_name SwordSparkle

@export var color: Color = Color(0.7, 1.0, 0.85, 1.0)
@export_range(4.0, 160.0, 0.5) var radius: float = 42.0
@export_range(0.1, 1.6, 0.01) var duration: float = 0.45
@export_range(0.0, 12.0, 0.01) var spin_speed: float = 6.5
@export_range(0.0, 1.0, 0.01) var pulse_scale: float = 0.32

var _elapsed: float = 0.0

func _ready() -> void:
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	rotation += spin_speed * delta
	if _elapsed >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_elapsed / max(duration, 0.001), 0.0, 1.0)
	var fade: float = pow(1.0 - progress, 1.2)
	var wobble: float = 1.0 + pulse_scale * sin(_elapsed * 9.0)
	var cross_radius: float = radius * wobble
	var halo_color: Color = Color(color.r, color.g, color.b, color.a * 0.22 * fade)
	var mid_color: Color = Color(color.r, color.g, color.b, color.a * 0.55 * fade)
	var core_color: Color = Color(1.0, 0.98, 0.9, 0.88 * fade)
	var flicker: float = 0.75 + 0.25 * sin(_elapsed * 14.0)
	draw_circle(Vector2.ZERO, cross_radius * 0.7, halo_color)
	draw_circle(Vector2.ZERO, cross_radius * 0.32, Color(color.r, color.g, color.b, color.a * 0.28 * fade * flicker))
	var axis_width: float = max(2.0, cross_radius * 0.08)
	var diag_width: float = max(1.5, cross_radius * 0.06)
	var arms: int = 4
	for i in range(arms):
		var angle: float = PI * 0.5 * float(i)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var arm_length: float = cross_radius * (1.08 if i % 2 == 0 else 0.78)
		draw_line(-dir * arm_length * 0.18, dir * arm_length, halo_color, axis_width, true)
		draw_line(-dir * arm_length * 0.05, dir * arm_length * 0.58, mid_color, axis_width * 0.8, true)
	for i in range(arms):
		var angle: float = PI * 0.25 + PI * 0.5 * float(i)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var arm_length: float = cross_radius * 0.9
		draw_line(-dir * arm_length * 0.1, dir * arm_length, Color(color.r, color.g, color.b, color.a * 0.38 * fade), diag_width, true)
	draw_circle(Vector2.ZERO, cross_radius * 0.18, core_color)
