extends Node2D
class_name SnowWhiteBurstBeam

@export var duration: float = 0.8
@export var beam_range: float = 1200.0
@export var beam_angle_degrees: float = 90.0
@export var outer_color: Color = Color(0.55, 0.75, 1.0, 0.5)
@export var mid_color: Color = Color(0.68, 0.85, 1.0, 0.65)
@export var inner_color: Color = Color(0.82, 0.94, 1.0, 0.8)
@export var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var flash_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export_range(6, 96, 1) var arc_steps: int = 32

var _age: float = 0.0
var _forward: Vector2 = Vector2.RIGHT

func _ready() -> void:
	set_process(true)
	set_notify_transform(true)
	z_index = 420
	queue_redraw()

func configure(forward: Vector2, range_distance: float, angle_degrees: float, colors: Dictionary = {}) -> void:
	_forward = forward.normalized() if forward.length() > 0.0 else Vector2.RIGHT
	beam_range = clampf(range_distance, 200.0, 2400.0)
	beam_angle_degrees = clampf(angle_degrees, 5.0, 170.0)
	if not colors.is_empty():
		outer_color = colors.get("outer", outer_color)
		mid_color = colors.get("mid", mid_color)
		inner_color = colors.get("inner", inner_color)
		core_color = colors.get("core", core_color)
		flash_color = colors.get("flash", flash_color)
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if duration <= 0.0:
		return
	var progress := clampf(_age / max(duration, 0.0001), 0.0, 1.0)
	var alpha_multiplier := _alpha_from_progress(progress)
	if alpha_multiplier <= 0.01:
		return
	_draw_flash(alpha_multiplier)
	_draw_beam_layers(alpha_multiplier)

func _alpha_from_progress(progress: float) -> float:
	if progress < 0.1:
		return 1.0
	if progress < 0.4:
		return 1.0 - ((progress - 0.1) / 0.3)
	return 0.0

func _draw_flash(alpha_multiplier: float) -> void:
	var base_radius := beam_range * 0.22
	var flash := Color(flash_color.r, flash_color.g, flash_color.b, flash_color.a * alpha_multiplier)
	draw_circle(Vector2.ZERO, base_radius, flash)
	var glow := Color(inner_color.r, inner_color.g, inner_color.b, inner_color.a * 0.6 * alpha_multiplier)
	draw_circle(Vector2.ZERO, base_radius * 0.66, glow)

func _draw_beam_layers(alpha_multiplier: float) -> void:
	var base_angle := _forward.angle()
	var total_angle := deg_to_rad(beam_angle_degrees)
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(arc_steps + 1):
		var t := float(i) / float(max(arc_steps, 1))
		var angle := base_angle - total_angle * 0.5 + total_angle * t
		var direction := Vector2.RIGHT.rotated(angle)
		points.append(direction * beam_range)
	var layer_settings := [
		{ "color": outer_color, "scale": 1.0 },
		{ "color": mid_color, "scale": 0.88 },
		{ "color": inner_color, "scale": 0.76 },
		{ "color": core_color, "scale": 0.62 }
	]
	for settings in layer_settings:
		var color: Color = settings["color"]
		var layer_scale: float = settings["scale"]
		var final_color := Color(color.r, color.g, color.b, color.a * alpha_multiplier)
		if final_color.a <= 0.01:
			continue
		var scaled := PackedVector2Array()
		for point in points:
			scaled.append(point * layer_scale)
		var colors := PackedColorArray()
		colors.resize(scaled.size())
		for index in range(scaled.size()):
			colors[index] = final_color
		draw_polygon(scaled, colors)
	_draw_edge_highlights(points, alpha_multiplier)

func _draw_edge_highlights(points: PackedVector2Array, alpha_multiplier: float) -> void:
	if points.size() < 3:
		return
	var outline_color := Color(inner_color.r, inner_color.g, inner_color.b, inner_color.a * 0.55 * alpha_multiplier)
	var base_angle := _forward.angle()
	var total_angle := deg_to_rad(beam_angle_degrees)
	var left_dir := Vector2.RIGHT.rotated(base_angle - total_angle * 0.5)
	var right_dir := Vector2.RIGHT.rotated(base_angle + total_angle * 0.5)
	draw_line(Vector2.ZERO, left_dir * beam_range, outline_color, max(8.0, beam_range * 0.012), true)
	draw_line(Vector2.ZERO, right_dir * beam_range, outline_color, max(8.0, beam_range * 0.012), true)
	var shimmer_color := Color(core_color.r, core_color.g, core_color.b, core_color.a * 0.8 * alpha_multiplier)
	var segments := 6
	for index in range(segments):
		var fraction := (float(index) + 1.0) / (float(segments) + 1.0)
		var midpoint_a := left_dir.lerp(right_dir, fraction) * beam_range
		var midpoint_b := midpoint_a * 0.7
		draw_circle(midpoint_a, beam_range * 0.045, shimmer_color)
		draw_circle(midpoint_b, beam_range * 0.035, shimmer_color * Color(1.0, 1.0, 1.0, 0.6))
