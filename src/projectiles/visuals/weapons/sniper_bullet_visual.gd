@tool
extends "res://src/projectiles/visuals/weapons/base_weapon_bullet_visual.gd"
class_name SniperBulletVisual

@export var preview_radius: float = 5.5
@export var preview_color: Color = Color(0.95, 0.98, 1.0, 1.0)
@export_range(12, 60, 1) var arc_segments: int = 22
@export var glow_length_factor: float = 1.15
@export var glow_width_factor: float = 1.6
@export var trail_glow_factor: float = 1.6
@export var trail_multiplier: float = 6.5

@onready var outline_polygon: Polygon2D = $OutlinePolygon
@onready var core_polygon: Polygon2D = $BodyPolygon
@onready var tail_core_polygon: Polygon2D = $TailCorePolygon
@onready var highlight_polygon: Polygon2D = $HighlightPolygon
@onready var glow_sprite: Sprite2D = $GlowSprite
@onready var trail_glow_sprite: Sprite2D = $TrailGlowSprite

func _ready() -> void:
	_ensure_sprites_textured([glow_sprite, trail_glow_sprite])
	if glow_sprite:
		glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		glow_sprite.z_index = -1
	if trail_glow_sprite:
		trail_glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		trail_glow_sprite.z_index = -2
	if Engine.is_editor_hint():
		update_visual(Vector2.RIGHT, preview_radius, preview_color)

func update_visual(direction: Vector2, radius: float, color: Color, context: Dictionary = {}) -> void:
	var dir := direction
	if dir.length_squared() < 0.000001:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	rotation = dir.angle()

	var speed_distance: float = float(context.get("speed", 1800.0)) * 0.02
	var target_length: float = max(speed_distance, radius * trail_multiplier)
	var base_radius: float = max(radius, 0.5)
	var half_width: float = max(base_radius * 0.62, 0.85)
	var body_length: float = max(target_length, half_width * 4.4)
	var outline_thickness: float = max(base_radius * 0.22, 1.05)
	var base_start: float = -body_length * 0.5
	var tail_length: float = body_length - half_width
	var nose_center_x: float = base_start + tail_length
	var outer_half_width: float = half_width + outline_thickness
	var inner_base_start: float = base_start + outline_thickness * 0.74
	var inner_tail_length_raw: float = tail_length - outline_thickness * 1.36
	var inner_tail_length: float = clampf(inner_tail_length_raw, half_width * 0.58, tail_length * 0.99)
	var inner_nose_center_x: float = inner_base_start + inner_tail_length

	var core_color := _apply_color(color)
	var outline_mix := Color(0.45, 0.68, 1.0, 1.0)
	var outline_color := _apply_color(color.darkened(0.55).lerp(outline_mix, 0.4))
	var fill_target := _apply_color(Color(0.86, 0.94, 1.0, 1.0))
	var fill_color := _blend_colors(core_color, fill_target, 0.5)
	var tail_target := _apply_color(Color(0.62, 0.88, 1.0, 1.0))
	var tail_color := _blend_colors(core_color, tail_target, 0.48)
	var highlight_color := _apply_color(Color(1.0, 1.0, 1.0, 0.82))

	if outline_polygon:
		outline_polygon.polygon = _build_bullet_shell(base_start, nose_center_x, outer_half_width, arc_segments)
		outline_polygon.color = outline_color

	if core_polygon:
		core_polygon.polygon = _build_bullet_shell(inner_base_start, inner_nose_center_x, half_width, arc_segments)
		core_polygon.color = fill_color

	var tail_core_width: float = clampf(outline_thickness * 2.1, 0.1, tail_length * 0.96)
	var tail_core_rect := Rect2(Vector2(base_start, -half_width * 0.54), Vector2(tail_core_width, half_width * 1.08))
	if tail_core_polygon:
		tail_core_polygon.polygon = _build_rect(tail_core_rect)
		tail_core_polygon.color = tail_color
		tail_core_polygon.visible = tail_color.a > 0.02

	var tip_highlight_width: float = half_width * 0.56
	var highlight_start: float = inner_base_start + inner_tail_length - tip_highlight_width * 0.22
	highlight_start = clampf(highlight_start, inner_base_start, inner_nose_center_x)
	var highlight_width: float = clampf(tip_highlight_width, 0.05, max(inner_nose_center_x - highlight_start, 0.1))
	var highlight_rect := Rect2(Vector2(highlight_start, -half_width * 0.36), Vector2(highlight_width, half_width * 0.72))
	if highlight_polygon:
		highlight_polygon.polygon = _build_rect(highlight_rect)
		highlight_polygon.color = highlight_color
		highlight_polygon.visible = highlight_color.a > 0.02

	var glow_length: float = max(body_length * glow_length_factor, half_width * 4.5)
	var glow_width: float = max(half_width * glow_width_factor, half_width * 1.1)
	var glow_center_x: float = inner_base_start + inner_tail_length * 0.7

	if glow_sprite:
		glow_sprite.texture = glow_sprite.texture if glow_sprite.texture else _resolve_white_texture()
		glow_sprite.position = Vector2(glow_center_x, 0.0)
		glow_sprite.scale = Vector2(glow_length * 0.5, glow_width * 0.5)
		var glow_color := Color(0.6, 0.86, 1.0, 0.75).lerp(color, 0.4)
		glow_color.a = clampf(color.a * 0.58 + 0.28, 0.32, 0.92)
		glow_sprite.modulate = _apply_color(glow_color, glow_sprite.position)

	if trail_glow_sprite:
		var trail_length: float = max(target_length * trail_glow_factor, body_length * 1.25)
		var trail_width: float = max(glow_width * 0.55, half_width * 1.1)
		trail_glow_sprite.texture = trail_glow_sprite.texture if trail_glow_sprite.texture else _resolve_white_texture()
		var trail_center_x: float = base_start - trail_length * 0.25
		trail_glow_sprite.position = Vector2(trail_center_x, 0.0)
		trail_glow_sprite.scale = Vector2(trail_length * 0.5, trail_width * 0.5)
		var trail_color := Color(0.32, 0.6, 1.0, 0.55).lerp(color, 0.35)
		trail_color.a = clampf(color.a * 0.4 + 0.2, 0.25, 0.75)
		trail_glow_sprite.modulate = _apply_color(trail_color, trail_glow_sprite.position)

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
