extends Node2D
class_name CommanderStunEffect

@export var clock_radius: float = 26.0
@export var outer_ring_count: int = 3
@export var base_color: Color = Color(0.72, 0.45, 0.22, 0.85)
@export var accent_color: Color = Color(1.0, 0.84, 0.28, 0.95)
@export var marker_color: Color = Color(1.0, 0.93, 0.65, 0.9)

var _time: float = 0.0

func _ready() -> void:
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if _should_remove():
		queue_free()
		return
	queue_redraw()

func _should_remove() -> bool:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return true
	if parent.has_method("is_stunned") and not parent.is_stunned():
		return true
	return false

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 3.5)
	var glow_alpha: float = 0.16 + 0.12 * pulse
	draw_circle(Vector2.ZERO, clock_radius + 14.0, Color(base_color.r, base_color.g, base_color.b, glow_alpha))
	draw_circle(Vector2.ZERO, clock_radius + 6.0, Color(base_color.r, base_color.g, base_color.b, 0.25 + 0.15 * pulse))
	var face_color := Color(base_color.r, base_color.g, base_color.b, 0.45 + 0.2 * pulse)
	draw_circle(Vector2.ZERO, clock_radius, face_color)
	for ring in range(outer_ring_count):
		var radius: float = clock_radius + 4.0 + float(ring) * 6.0
		var thickness: float = maxf(1.5, 3.5 - float(ring))
		var ring_alpha: float = maxf(0.12, 0.32 - float(ring) * 0.08)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(accent_color.r, accent_color.g, accent_color.b, ring_alpha), thickness)
	_draw_clock_hands()
	_draw_markers(pulse)
	var hub_color := Color(accent_color.r, accent_color.g, accent_color.b, 0.65 + 0.25 * pulse)
	draw_circle(Vector2.ZERO, 4.0, hub_color)
	draw_circle(Vector2.ZERO, 2.0, Color(1.0, 0.96, 0.68, 0.9))

func _draw_clock_hands() -> void:
	var hour_angle: float = _time * 3.0 - PI * 0.5
	var minute_angle: float = _time * 6.0 - PI * 0.5
	var hour_length: float = clock_radius - 6.0
	var minute_length: float = clock_radius - 10.0
	var hour_end := Vector2.RIGHT.rotated(hour_angle) * hour_length
	var minute_end := Vector2.RIGHT.rotated(minute_angle) * minute_length
	var hour_glow_color := Color(accent_color.r, accent_color.g, accent_color.b, 0.5)
	var hour_core_color := Color(accent_color.r, accent_color.g, accent_color.b, 0.95)
	draw_line(Vector2.ZERO, hour_end, hour_glow_color, 7.0)
	draw_line(Vector2.ZERO, hour_end, hour_core_color, 3.5)
	var minute_glow_color := Color(base_color.r, base_color.g, base_color.b, 0.45)
	var minute_core_color := Color(base_color.r, base_color.g, base_color.b, 0.9)
	draw_line(Vector2.ZERO, minute_end, minute_glow_color, 5.0)
	draw_line(Vector2.ZERO, minute_end, minute_core_color, 2.5)
	var second_angle: float = _time * 10.0 - PI * 0.5
	var second_length: float = clock_radius
	var second_end := Vector2.RIGHT.rotated(second_angle) * second_length
	var second_color := Color(1.0, 0.95, 0.75, 0.8)
	draw_line(Vector2.ZERO, second_end, second_color, 1.5)
	draw_circle(second_end, 2.0, second_color)

func _draw_markers(pulse: float) -> void:
	var glow_strength: float = 0.35 + 0.2 * pulse
	for i in range(4):
		var angle: float = float(i) * PI * 0.5 - PI * 0.5
		var marker_pos := Vector2.RIGHT.rotated(angle) * (clock_radius + 10.0)
		var glow_color := Color(marker_color.r, marker_color.g, marker_color.b, glow_strength)
		draw_circle(marker_pos, 6.5, glow_color)
		draw_circle(marker_pos, 3.5, Color(marker_color.r, marker_color.g, marker_color.b, 0.85 + 0.1 * pulse))
