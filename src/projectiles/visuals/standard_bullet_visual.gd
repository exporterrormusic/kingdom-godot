@tool
extends Node2D
class_name StandardBulletVisual

var apply_color_callback: Callable = Callable()
var _base_color: Color = Color(1.0, 0.9, 0.4, 1.0)
var _radius: float = 4.0

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func set_apply_color_callback(callback: Callable) -> void:
	apply_color_callback = callback

func configure(color: Color, radius_value: float) -> void:
	_base_color = color
	_radius = max(0.5, radius_value)
	queue_redraw()


func configure_visual(params: Dictionary) -> void:
	var color: Color = params.get("color", _base_color)
	var radius_value: float = float(params.get("radius", _radius))
	configure(color, radius_value)


func update_visual(direction: Vector2, radius_value: float, color: Color, _context := {}) -> void:
	configure(color, radius_value)
	if direction.length() > 0.001:
		rotation = direction.angle()
	else:
		rotation = 0.0

func _apply(color: Color) -> Color:
	if apply_color_callback and apply_color_callback.is_valid():
		return apply_color_callback.call(color, Vector2.ZERO)
	return color

func _blend(base_color: Color, target: Color, weight: float) -> Color:
	var inv := clampf(1.0 - weight, 0.0, 1.0)
	var w := clampf(weight, 0.0, 1.0)
	return Color(
		maxf(base_color.r * inv + target.r * w, 0.0),
		maxf(base_color.g * inv + target.g * w, 0.0),
		maxf(base_color.b * inv + target.b * w, 0.0),
		1.0
	)

func _draw() -> void:
	var compensated_base := _apply(_base_color)
	var base_radius: float = max(_radius, 0.5)
	var half_width: float = max(base_radius * 0.8, 1.2)
	var body_length: float = max(base_radius * 3.4, half_width * 3.1)
	var outline_thickness: float = max(base_radius * 0.28, 1.4)
	var base_start: float = -body_length * 0.5
	var nose_start: float = base_start + (body_length - half_width)
	var outer_half_width: float = half_width + outline_thickness
	var fill_target := _apply(Color(1.0, 0.94, 0.25, 1.0))
	var fill_color: Color = _blend(compensated_base, fill_target, 0.55)
	var outline_color: Color = _apply(Color(1.0, 0.62, 0.18, 1.0))
	var tip_center: Vector2 = Vector2(nose_start, 0.0)
	var tail_rect := Rect2(Vector2(base_start, -outer_half_width), Vector2(body_length - half_width, outer_half_width * 2.0))
	draw_rect(tail_rect, outline_color)
	draw_circle(tip_center, outer_half_width, outline_color)
	var inner_tail_start: float = base_start + outline_thickness
	var inner_tail_rect_length: float = max(tail_rect.size.x - outline_thickness * 1.6, 0.0)
	var inner_tail_rect := Rect2(Vector2(inner_tail_start, -half_width), Vector2(inner_tail_rect_length, half_width * 2.0))
	draw_rect(inner_tail_rect, fill_color)
	draw_circle(Vector2(inner_tail_start + inner_tail_rect_length, 0.0), half_width, fill_color)
	var tip_highlight_width: float = half_width * 0.6
	var highlight_offset: Vector2 = Vector2(inner_tail_start + inner_tail_rect_length - tip_highlight_width * 0.3, -half_width * 0.45)
	var highlight_rect := Rect2(highlight_offset, Vector2(tip_highlight_width, half_width * 0.9))
	draw_rect(highlight_rect, _apply(Color(1.0, 1.0, 0.85, 0.6)))
	var tail_core_height: float = half_width * 1.3
	var tail_core_rect := Rect2(Vector2(base_start, -tail_core_height * 0.5), Vector2(outline_thickness * 1.8, tail_core_height))
	var tail_target := _apply(Color(0.95, 0.78, 0.18, 1.0))
	draw_rect(tail_core_rect, _blend(compensated_base, tail_target, 0.4))
