extends Control
class_name MainMenuIcon

@export var icon_type: String = "play"
@export var base_color: Color = Color(0.7, 0.7, 0.7)
@export var selected_color: Color = Color(1, 1, 1)

var _current_color: Color = base_color

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_base_color(color: Color) -> void:
	base_color = color
	if _current_color != selected_color:
		_current_color = base_color
	queue_redraw()

func set_selected(selected: bool) -> void:
	_current_color = selected_color if selected else base_color
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var bounds := get_size()
	var center := bounds * 0.5
	var icon_size: float = min(bounds.x, bounds.y)
	var color := _current_color

	match icon_type:
		"leaderboards":
			_draw_crown(center, icon_size, color)
		"achievements":
			_draw_trophy(center, icon_size, color)
		"shop":
			_draw_bag(center, icon_size, color)
		"play":
			_draw_play(center, icon_size, color)
		"outpost":
			_draw_house(center, icon_size, color)
		"settings":
			_draw_cog(center, icon_size, color)
		"quit":
			_draw_quit(center, icon_size, color)
		_:
			_draw_play(center, icon_size, color)


func _draw_crown(center: Vector2, icon_size: float, color: Color) -> void:
	var base_width := icon_size * 0.6
	var base_height := icon_size * 0.22
	var base_rect := Rect2(Vector2(center.x - base_width * 0.5, center.y + icon_size * 0.12), Vector2(base_width, base_height))
	draw_rect(base_rect, color)
	for i in range(3):
		var offset := float(i - 1) * base_width / 3.0
		var peak_x := center.x + offset
		var peak_height := icon_size * 0.35
		var top := center.y - peak_height * 0.6
		var points := PackedVector2Array([
			Vector2(peak_x, top),
			Vector2(peak_x - icon_size * 0.08, top + peak_height),
			Vector2(peak_x + icon_size * 0.08, top + peak_height)
		])
		draw_polygon(points, PackedColorArray([color, color, color]))
		draw_circle(Vector2(peak_x, top), icon_size * 0.045, Color(1, 1, 0.4))


func _draw_trophy(center: Vector2, icon_size: float, color: Color) -> void:
	var cup_radius := icon_size * 0.26
	draw_arc(center + Vector2(0, -icon_size * 0.08), cup_radius, PI, TAU, 32, color, 3.0)
	draw_line(center + Vector2(-cup_radius, -icon_size * 0.14), center + Vector2(-cup_radius - icon_size * 0.18, icon_size * 0.02), color, 2.0)
	draw_line(center + Vector2(cup_radius, -icon_size * 0.14), center + Vector2(cup_radius + icon_size * 0.18, icon_size * 0.02), color, 2.0)
	var stem_rect := Rect2(Vector2(center.x - icon_size * 0.04, center.y + icon_size * 0.02), Vector2(icon_size * 0.08, icon_size * 0.22))
	draw_rect(stem_rect, color)
	var base_rect := Rect2(Vector2(center.x - icon_size * 0.18, center.y + icon_size * 0.18), Vector2(icon_size * 0.36, icon_size * 0.14))
	draw_rect(base_rect, color)

func _draw_bag(center: Vector2, icon_size: float, color: Color) -> void:
	var bag_width := icon_size * 0.5
	var bag_height := icon_size * 0.6
	var bag_rect := Rect2(Vector2(center.x - bag_width * 0.5, center.y - bag_height * 0.3), Vector2(bag_width, bag_height))
	draw_rect(bag_rect, color, false, 3.0)
	var handle_radius := icon_size * 0.18
	var handle_center_left := Vector2(center.x - bag_width * 0.22, center.y - bag_height * 0.45)
	var handle_center_right := Vector2(center.x + bag_width * 0.22, center.y - bag_height * 0.45)
	draw_arc(handle_center_left, handle_radius, PI, TAU, 24, color, 2.0)
	draw_arc(handle_center_right, handle_radius, PI, TAU, 24, color, 2.0)
	draw_line(Vector2(bag_rect.position.x, center.y - bag_height * 0.1), Vector2(bag_rect.position.x + bag_rect.size.x, center.y - bag_height * 0.1), color, 2.0)

func _draw_play(center: Vector2, icon_size: float, color: Color) -> void:
	var radius := icon_size * 0.33
	draw_arc(center, radius, 0.0, TAU, 48, color, 3.0)
	var tri_height := radius * 1.1
	var points := PackedVector2Array([
		Vector2(center.x - radius * 0.4, center.y - tri_height * 0.5),
		Vector2(center.x - radius * 0.4, center.y + tri_height * 0.5),
		Vector2(center.x + radius * 0.65, center.y)
	])
	draw_polygon(points, PackedColorArray([color, color, color]))

func _draw_house(center: Vector2, icon_size: float, color: Color) -> void:
	var base_width := icon_size * 0.45
	var base_height := icon_size * 0.3
	var base_rect := Rect2(Vector2(center.x - base_width * 0.5, center.y + icon_size * 0.05), Vector2(base_width, base_height))
	draw_rect(base_rect, color, false, 2.0)
	var roof_height := icon_size * 0.28
	var roof_points := PackedVector2Array([
		Vector2(center.x - base_width * 0.5, center.y + icon_size * 0.05),
		Vector2(center.x + base_width * 0.5, center.y + icon_size * 0.05),
		Vector2(center.x, center.y - roof_height)
	])
	draw_polygon(roof_points, PackedColorArray([color, color, color]))
	draw_polyline(roof_points + PackedVector2Array([roof_points[0]]), color, 2.0)
	var door_rect := Rect2(Vector2(center.x - base_width * 0.12, center.y + base_height * 0.15), Vector2(base_width * 0.24, base_height * 0.55))
	draw_rect(door_rect, color, false, 2.0)
	var window_rect := Rect2(Vector2(center.x + base_width * 0.18, center.y - base_height * 0.15), Vector2(base_width * 0.22, base_height * 0.22))
	draw_rect(window_rect, color, false, 1.5)

func _draw_cog(center: Vector2, icon_size: float, color: Color) -> void:
	var outer_radius := icon_size * 0.35
	var inner_radius := icon_size * 0.15
	draw_arc(center, inner_radius, 0.0, TAU, 32, color, 2.0)
	var teeth := 8
	for i in range(teeth):
		var angle := TAU * float(i) / float(teeth)
		var outer_point := center + Vector2(cos(angle), sin(angle)) * outer_radius
		var inner_point := center + Vector2(cos(angle), sin(angle)) * inner_radius * 1.5
		draw_line(inner_point, outer_point, color, 3.0)
	draw_arc(center, outer_radius, 0.0, TAU, 64, color, 2.0)

func _draw_quit(center: Vector2, icon_size: float, color: Color) -> void:
	var radius := icon_size * 0.36
	draw_arc(center, radius, 0.0, TAU, 64, color, 2.5)
	var line_length := radius * 1.1
	var offset := line_length * 0.5
	var dir := Vector2(1, 1).normalized()
	var start1 := center - dir * offset
	var end1 := center + dir * offset
	var start2 := center + Vector2(-dir.x, dir.y) * offset
	var end2 := center + Vector2(dir.x, -dir.y) * offset
	draw_line(start1, end1, color, 4.0)
	draw_line(start2, end2, color, 4.0)
