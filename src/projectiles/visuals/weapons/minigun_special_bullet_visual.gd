@tool
extends "res://src/projectiles/visuals/weapons/base_weapon_bullet_visual.gd"
class_name MinigunSpecialBulletVisual

@export var preview_radius: float = 7.5
@export var preview_color: Color = Color(0.95, 0.65, 0.25, 1.0)
@export_range(12, 56, 1) var arc_segments: int = 26
@export var glow_length_factor: float = 1.1
@export var glow_width_factor: float = 2.25
@export var crackle_count: int = 6
@export var crackle_spread: float = 26.0

@onready var outline_polygon: Polygon2D = $OutlinePolygon
@onready var core_polygon: Polygon2D = $BodyPolygon
@onready var tail_core_polygon: Polygon2D = $TailCorePolygon
@onready var highlight_polygon: Polygon2D = $HighlightPolygon
@onready var glow_sprite: Sprite2D = $GlowSprite
@onready var crackle_container: Node2D = $CrackleContainer

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_ensure_sprites_textured([glow_sprite])
	if glow_sprite:
		glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glow_sprite.z_index = -1
	if Engine.is_editor_hint():
		update_visual(Vector2.RIGHT, preview_radius, preview_color)

func update_visual(direction: Vector2, radius: float, color: Color, context: Dictionary = {}) -> void:
	var dir := direction
	if dir.length_squared() < 0.000001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	rotation = dir.angle()

	var surge_factor: float = float(context.get("charge_scale", 1.0))
	var surge_scale: float = clampf(surge_factor, 0.7, 1.6)
	var base_radius: float = max(radius, 0.65)
	var half_width: float = max(base_radius * 1.0, 1.8)
	var body_length: float = max(base_radius * 4.8, half_width * 4.2) * surge_scale
	var outline_thickness: float = max(base_radius * 0.38, 2.0)
	var base_start: float = -body_length * 0.5
	var tail_length: float = body_length - half_width
	var nose_center_x: float = base_start + tail_length
	var outer_half_width: float = half_width + outline_thickness
	var inner_base_start: float = base_start + outline_thickness * 0.82
	var inner_tail_length_raw: float = tail_length - outline_thickness * 1.5
	var inner_tail_length: float = clampf(inner_tail_length_raw, half_width * 0.62, tail_length * 0.99)
	var inner_nose_center_x: float = inner_base_start + inner_tail_length

	var core_color := _apply_color(color)
	var outline_color := _apply_color(color.darkened(0.55))
	var fill_target := _apply_color(Color(1.0, 0.68, 0.24, 1.0))
	var fill_color := _blend_colors(core_color, fill_target, 0.6)
	var tail_target := _apply_color(Color(1.0, 0.82, 0.38, 1.0))
	var tail_color := _blend_colors(core_color, tail_target, 0.52)
	var highlight_color := _apply_color(Color(1.0, 0.96, 0.8, 0.92))

	if outline_polygon:
		outline_polygon.polygon = _build_bullet_shell(base_start, nose_center_x, outer_half_width, arc_segments)
		outline_polygon.color = outline_color

	if core_polygon:
		core_polygon.polygon = _build_bullet_shell(inner_base_start, inner_nose_center_x, half_width, arc_segments)
		core_polygon.color = fill_color

	var tail_core_width: float = clampf(outline_thickness * 2.4, 0.1, tail_length * 0.95)
	var tail_core_rect := Rect2(Vector2(base_start, -half_width * 0.72), Vector2(tail_core_width, half_width * 1.44))
	if tail_core_polygon:
		tail_core_polygon.polygon = _build_rect(tail_core_rect)
		tail_core_polygon.color = tail_color
		tail_core_polygon.visible = tail_color.a > 0.02

	var tip_highlight_width: float = half_width * 0.78
	var highlight_start: float = inner_base_start + inner_tail_length - tip_highlight_width * 0.32
	highlight_start = clampf(highlight_start, inner_base_start, inner_nose_center_x)
	var highlight_width: float = clampf(tip_highlight_width, 0.05, max(inner_nose_center_x - highlight_start, 0.1))
	var highlight_rect := Rect2(Vector2(highlight_start, -half_width * 0.5), Vector2(highlight_width, half_width * 1.0))
	if highlight_polygon:
		highlight_polygon.polygon = _build_rect(highlight_rect)
		highlight_polygon.color = highlight_color
		highlight_polygon.visible = highlight_color.a > 0.02

	if glow_sprite:
		var glow_length: float = max(body_length * glow_length_factor, half_width * 4.0)
		var glow_width: float = max(half_width * glow_width_factor, half_width * 1.6)
		var glow_center_x: float = inner_base_start + inner_tail_length * 0.65
		glow_sprite.texture = glow_sprite.texture if glow_sprite.texture else _resolve_white_texture()
		glow_sprite.position = Vector2(glow_center_x, 0.0)
		glow_sprite.scale = Vector2(glow_length * 0.5, glow_width * 0.5)
		var glow_color := Color(1.0, 0.78, 0.36, 0.78).lerp(color, 0.5)
		glow_color.a = clampf(color.a * 0.62 + 0.28, 0.35, 0.95)
		glow_sprite.modulate = _apply_color(glow_color, glow_sprite.position)

	_update_crackles(body_length, half_width, color)

func _update_crackles(body_length: float, half_width: float, color: Color) -> void:
	if crackle_container == null:
		return
	_ensure_crackle_lines()
	var children := crackle_container.get_children()
	for child in children:
		if not (child is Line2D):
			continue
		var crackle := child as Line2D
		var base := Vector2(_rng.randf_range(-body_length * 0.45, body_length * 0.4), 0.0)
		var offset_distance: float = _rng.randf_range(half_width * 0.9, half_width * 2.8)
		var angle: float = _rng.randf_range(0.0, TAU)
		var offset := Vector2(cos(angle), sin(angle)) * offset_distance
		crackle.points = PackedVector2Array([base, base + offset])
		crackle.width = max(half_width * 0.16, 1.4)
		var crackle_color := color.lightened(0.25)
		crackle_color.a = 0.9
		var sample_point := base + offset * 0.5
		crackle.default_color = _apply_color(crackle_color, sample_point)

func _ensure_crackle_lines() -> void:
	if crackle_container == null:
		return
	var existing := crackle_container.get_child_count()
	if existing >= crackle_count:
		return
	for _i in range(crackle_count - existing):
		var line := Line2D.new()
		line.antialiased = true
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		crackle_container.add_child(line)

func _build_bullet_shell(base_start: float, nose_center_x: float, half_width: float, segments: int) -> PackedVector2Array:
	var segment_count: int = max(segments, 4)
	var arc_center := Vector2(nose_center_x, 0.0)
	var points := PackedVector2Array()
	points.append(Vector2(base_start, half_width))
	for i in range(segment_count + 1):
		var angle: float = PI * 0.5 - float(i) / float(segment_count) * PI
		points.append(arc_center + Vector2(cos(angle), sin(angle)) * half_width)
	points.append(Vector2(base_start, -half_width))
	return points

func _build_rect(rect: Rect2) -> PackedVector2Array:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return PackedVector2Array()
	var top_left := rect.position
	var top_right := rect.position + Vector2(rect.size.x, 0.0)
	var bottom_right := rect.position + rect.size
	var bottom_left := rect.position + Vector2(0.0, rect.size.y)
	return PackedVector2Array([top_left, top_right, bottom_right, bottom_left])

func _blend_colors(base_color: Color, target: Color, weight: float) -> Color:
	var w := clampf(weight, 0.0, 1.0)
	var inv := 1.0 - w
	return Color(
		maxf(base_color.r * inv + target.r * w, 0.0),
		maxf(base_color.g * inv + target.g * w, 0.0),
		maxf(base_color.b * inv + target.b * w, 0.0),
		maxf(base_color.a * inv + target.a * w, 0.0)
	)
