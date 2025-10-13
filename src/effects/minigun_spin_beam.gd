extends Node2D
class_name MinigunSpinBeam

@export var owner_reference: Node2D
@export var max_range: float = 480.0
@export var base_width: float = 19.0
@export var color: Color = Color(1.0, 0.86, 0.52, 0.82)
@export var fade_speed: float = 6.8
@export var pulse_speed: float = 11.6
@export var ripple_count: int = 5

var _current_intensity: float = 0.0
var _target_intensity: float = 0.0
var _active: bool = false
var _direction: Vector2 = Vector2.RIGHT
var _elapsed: float = 0.0
var _inactive_time: float = 0.0
var _beam_path: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	set_process(true)
	queue_redraw()

func set_active_state(enabled: bool, intensity: float) -> void:
	_active = enabled
	_target_intensity = clampf(intensity, 0.0, 1.0)
	if _active:
		_inactive_time = 0.0

func set_beam_color(new_color: Color) -> void:
	color = new_color

func _process(delta: float) -> void:
	if not owner_reference or not is_instance_valid(owner_reference):
		queue_free()
		return
	_elapsed += delta
	_update_anchor_from_owner()
	_update_beam_path()
	var target := _target_intensity if _active else 0.0
	_current_intensity = move_toward(_current_intensity, target, delta * fade_speed)
	if not _active and _current_intensity <= 0.01:
		_inactive_time += delta
		if _inactive_time >= 0.35:
			queue_free()
			return
	else:
		_inactive_time = 0.0
	queue_redraw()

func _update_anchor_from_owner() -> void:
	var aim_variant: Variant = null
	if owner_reference.has_method("_get_aim_direction"):
		aim_variant = owner_reference.call("_get_aim_direction")
	if aim_variant is Vector2:
		var aim_vector: Vector2 = aim_variant
		if aim_vector.length() > 0.0:
			_direction = aim_vector.normalized()
	var tip_variant: Variant = null
	if owner_reference.has_method("get_gun_tip_position"):
		tip_variant = owner_reference.call("get_gun_tip_position", _direction)
	if tip_variant is Vector2:
		global_position = tip_variant
	else:
		global_position = owner_reference.global_position

func _update_beam_path() -> void:
	var updated_path := PackedVector2Array()
	if owner_reference and is_instance_valid(owner_reference) and owner_reference.has_method("get_minigun_beam_path"):
		var path_variant: Variant = owner_reference.call("get_minigun_beam_path", global_position)
		match typeof(path_variant):
			TYPE_PACKED_VECTOR2_ARRAY:
				updated_path = path_variant
			TYPE_ARRAY:
				updated_path = PackedVector2Array(path_variant)
			_:
				pass
	_beam_path = updated_path
	if _beam_path.size() >= 2:
		_update_path_direction(_beam_path)

func _update_path_direction(path: PackedVector2Array) -> void:
	if path.size() < 2:
		return
	var tip := path[path.size() - 1]
	var prev := path[path.size() - 2]
	var segment := tip - prev
	if segment.length_squared() > 0.001:
		_direction = segment.normalized()

func _resolve_active_path() -> PackedVector2Array:
	if _beam_path.size() >= 2:
		return _beam_path
	var fallback := PackedVector2Array()
	var dir := _direction
	if dir.length_squared() == 0.0:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var reach := max_range * (0.5 + 0.5 * _current_intensity)
	if reach <= 0.0:
		reach = max_range
	if reach <= 0.0:
		reach = 360.0
	fallback.push_back(Vector2.ZERO)
	fallback.push_back(dir * reach)
	return fallback

func _compute_path_length(path: PackedVector2Array) -> float:
	if path.size() < 2:
		return 0.0
	var length := 0.0
	for i in range(path.size() - 1):
		length += (path[i + 1] - path[i]).length()
	return length

func _sample_path_at(path: PackedVector2Array, t: float) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	if path.size() == 1:
		return path[0]
	var total_length := _compute_path_length(path)
	if total_length <= 0.0:
		return path[0]
	var clamped_t := clampf(t, 0.0, 1.0)
	var target_length := total_length * clamped_t
	var accumulated := 0.0
	for i in range(path.size() - 1):
		var a := path[i]
		var b := path[i + 1]
		var segment := b - a
		var segment_length := segment.length()
		if segment_length <= 0.0:
			continue
		if accumulated + segment_length >= target_length:
			var local := (target_length - accumulated) / segment_length
			return a.lerp(b, local)
		accumulated += segment_length
	return path[path.size() - 1]

func _draw() -> void:
	if _current_intensity <= 0.01:
		return
	var path := _resolve_active_path()
	if path.size() < 2:
		return
	var path_length := _compute_path_length(path)
	if path_length <= 0.0:
		return
	var tip_segment := path[path.size() - 1] - path[path.size() - 2]
	var dir := tip_segment
	if dir.length_squared() == 0.0:
		dir = _direction
	if dir.length_squared() == 0.0:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var pulse := 0.8 + 0.2 * sin(_elapsed * pulse_speed)
	var width := base_width * (_current_intensity * 0.52 + 0.2) * pulse
	var glow_color := Color(color.r, color.g, color.b, color.a * 0.24 * _current_intensity)
	var sheath_color := Color(color.r, color.g * 0.82, color.b * 0.64, color.a * 0.4 * _current_intensity)
	var core_color := Color(1.0, 0.97, 0.92, clampf(color.a * 0.82 * _current_intensity, 0.0, 1.0))
	for i in range(2):
		var layer_width := width * (1.22 - float(i) * 0.2)
		var layer_alpha := glow_color.a * (0.7 - float(i) * 0.2)
		var layer_color := Color(glow_color.r, glow_color.g, glow_color.b, clampf(layer_alpha, 0.01, 0.18))
		draw_polyline(path, layer_color, layer_width, true)
	draw_polyline(path, sheath_color, width * 0.78, true)
	draw_polyline(path, core_color, max(1.2, width * 0.4), true)
	var origin_point := path[0]
	var tip_point := path[path.size() - 1]
	var origin_radius := maxf(width * 0.32, 7.5)
	var tip_radius := maxf(width * 0.48, 10.5)
	draw_circle(origin_point, origin_radius, glow_color)
	draw_circle(origin_point, origin_radius * 0.42, core_color)
	draw_circle(tip_point, tip_radius, glow_color)
	draw_circle(tip_point, tip_radius * 0.4, core_color)
	var tail_color := Color(glow_color.r, glow_color.g, glow_color.b, clampf(glow_color.a * 1.5, 0.0, 0.4))
	var tail_triangle := PackedVector2Array([
		origin_point,
		origin_point + dir * (width * 0.48) + perp * width * 0.14,
		origin_point + dir * (width * 0.48) - perp * width * 0.14
	])
	var tail_colors := PackedColorArray([
		tail_color,
		Color(tail_color.r, tail_color.g, tail_color.b, tail_color.a * 0.38),
		Color(tail_color.r, tail_color.g, tail_color.b, tail_color.a * 0.38)
	])
	draw_polygon(tail_triangle, tail_colors)
	draw_circle(origin_point + dir * width * 0.22, width * 0.16, Color(tail_color.r, tail_color.g, tail_color.b, tail_color.a * 0.45))
	var tip_color := Color(core_color.r, core_color.g, core_color.b, clampf(core_color.a * 1.08, 0.0, 1.0))
	var sheath := Color(sheath_color.r, sheath_color.g, sheath_color.b, clampf(sheath_color.a * 1.12, 0.0, 1.0))
	var tip_triangle := PackedVector2Array([
		tip_point,
		tip_point - dir * (width * 0.62) + perp * width * 0.16,
		tip_point - dir * (width * 0.62) - perp * width * 0.16
	])
	var tip_colors := PackedColorArray([
		tip_color,
		sheath,
		sheath
	])
	draw_polygon(tip_triangle, tip_colors)
	draw_circle(tip_point, width * 0.18, tip_color)
	var ripple_total: int = max(1, ripple_count)
	for i in range(ripple_total):
		var denom := maxf(1.0, float(ripple_total - 1))
		var t := float(i) / denom
		var pos := _sample_path_at(path, t)
		var ripple_radius := width * (0.18 + 0.22 * sin(_elapsed * (7.0 + float(i)) + t * TAU))
		var alpha := 0.14 * _current_intensity * (1.0 - t * 0.4)
		draw_circle(pos, ripple_radius, Color(glow_color.r, glow_color.g, glow_color.b, clampf(alpha, 0.028, 0.16)))