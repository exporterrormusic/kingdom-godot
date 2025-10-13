extends Node2D
class_name PlayerGroundMarker

@export_range(4.0, 256.0, 1.0) var radius: float = 72.0:
	set(value):
		radius = max(value, 4.0)
		queue_redraw()

@export_range(2, 12, 1) var layers: int = 7:
	set(value):
		layers = maxi(2, value)
		queue_redraw()

@export var base_color: Color = Color(0.9, 0.98, 1.0, 0.45):
	set(value):
		base_color = value
		queue_redraw()

@export_range(0.2, 6.0, 0.05) var falloff_power: float = 2.4:
	set(value):
		falloff_power = clampf(value, 0.2, 6.0)
		queue_redraw()

func set_marker_color(color: Color) -> void:
	base_color = color
	queue_redraw()

func _ready() -> void:
	set_notify_local_transform(true)
	_scale_origin = scale
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_VISIBILITY_CHANGED:
		queue_redraw()

func _draw() -> void:
	if base_color.a <= 0.0:
		return
	var steps := maxi(layers, 2)
	var max_radius: float = max(radius, 1.0)
	var previous_weight: float = 0.0
	for index in range(steps):
		var t := float(index + 1) / float(steps)
		var weight := pow(t, falloff_power)
		var alpha := clampf(base_color.a * max(weight - previous_weight, 0.0), 0.0, 1.0)
		if alpha > 0.001:
			var color := Color(base_color.r, base_color.g, base_color.b, alpha)
			var ring_radius: float = max_radius * t
			draw_circle(Vector2.ZERO, ring_radius, color)
		previous_weight = weight

func get_native_scale() -> Vector2:
	return _scale_origin

func set_scale_multiplier(multiplier: Vector2) -> void:
	scale = Vector2(_scale_origin.x * multiplier.x, _scale_origin.y * multiplier.y)

var _scale_origin: Vector2 = Vector2.ONE
