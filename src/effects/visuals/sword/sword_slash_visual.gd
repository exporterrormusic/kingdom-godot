@tool
extends Node2D
class_name SwordSlashVisual

@export var preview_radius: float = 260.0
@export_range(10.0, 360.0, 1.0) var preview_arc_degrees: float = 110.0
@export var preview_core_color: Color = Color(0.62, 0.36, 0.95, 0.85)
@export var preview_edge_color: Color = Color(0.9, 0.82, 1.0, 0.9)
@export var preview_glow_color: Color = Color(0.3, 0.16, 0.55, 0.55)
@export_range(1, 16, 1) var preview_sparkle_count: int = 6
@export var additive_blend: bool = true

var _radius: float = 0.0
var _arc_degrees: float = 0.0
var _core_color: Color = Color.WHITE
var _edge_color: Color = Color.WHITE
var _glow_color: Color = Color.WHITE
var _fade: float = 1.0
var _wipe: float = 1.0
var _sparkle_seed: int = 0
var _sparkle_count: int = 6

func _ready() -> void:
	if additive_blend:
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive
	if Engine.is_editor_hint():
		_set_preview_state()

func update_visual(params: Dictionary) -> void:
	_radius = maxf(float(params.get("radius", preview_radius)), 0.0)
	_arc_degrees = clampf(float(params.get("arc_degrees", preview_arc_degrees)), 1.0, 360.0)
	_core_color = params.get("core_color", preview_core_color)
	_edge_color = params.get("edge_color", preview_edge_color)
	_glow_color = params.get("glow_color", preview_glow_color)
	_fade = clampf(float(params.get("fade", 1.0)), 0.0, 1.0)
	_wipe = clampf(float(params.get("wipe_progress", 1.0)), 0.0, 1.0)
	_sparkle_seed = int(params.get("sparkle_seed", 0))
	_sparkle_count = clampi(int(params.get("sparkle_count", preview_sparkle_count)), 0, 24)
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_set_preview_state()

func _set_preview_state() -> void:
	_radius = preview_radius
	_arc_degrees = preview_arc_degrees
	_core_color = preview_core_color
	_edge_color = preview_edge_color
	_glow_color = preview_glow_color
	_fade = 1.0
	_wipe = 1.0
	_sparkle_count = preview_sparkle_count
	queue_redraw()

func _draw() -> void:
	if _radius <= 0.01:
		return
	var effective_radius := _radius * clampf(_wipe, 0.0, 1.0)
	if effective_radius <= 0.5:
		return
	var layers := [
		{
			"outer": effective_radius * 1.2,
			"inner": effective_radius * 0.55,
			"color": Color(_glow_color.r, _glow_color.g, _glow_color.b, _glow_color.a * _fade * 0.65)
		},
		{
			"outer": effective_radius * 1.05,
			"inner": effective_radius * 0.42,
			"color": Color(_core_color.r, _core_color.g, _core_color.b, _core_color.a * _fade)
		},
		{
			"outer": effective_radius * 0.9,
			"inner": effective_radius * 0.2,
			"color": Color(_edge_color.r, _edge_color.g, _edge_color.b, _edge_color.a * _fade * 0.9)
		}
	]
	for layer in layers:
		_draw_arc_segment(float(layer["outer"]), float(layer["inner"]), layer["color"])
	_draw_sparkle_lines(effective_radius)

func _draw_arc_segment(outer_radius: float, inner_radius: float, color: Color) -> void:
	if outer_radius <= 0.5:
		return
	inner_radius = clampf(inner_radius, 0.0, maxf(outer_radius - 0.5, 0.0))
	var half_arc := deg_to_rad(_arc_degrees) * 0.5
	var segments: int = max(10, int(_arc_degrees / 4.0))
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = -half_arc + t * (half_arc * 2.0)
		points.append(Vector2(cos(angle), sin(angle)) * outer_radius)
	for i in range(segments, -1, -1):
		var t: float = float(i) / float(segments)
		var angle: float = -half_arc + t * (half_arc * 2.0)
		points.append(Vector2(cos(angle), sin(angle)) * inner_radius)
	var colors := PackedColorArray()
	for _p in points:
		colors.append(color)
	draw_polygon(points, colors)

func _draw_sparkle_lines(outer_radius: float) -> void:
	if _sparkle_count <= 0:
		return
	var half_arc := deg_to_rad(_arc_degrees) * 0.5
	var sparkle_color := Color(_edge_color.r, _edge_color.g, _edge_color.b, _edge_color.a * _fade)
	var rng := RandomNumberGenerator.new()
	rng.seed = _sparkle_seed
	for i in range(_sparkle_count):
		var t: float = float(i) / max(1.0, float(_sparkle_count - 1))
		var angle: float = -half_arc + t * (half_arc * 2.0)
		var jitter: float = rng.randf_range(-0.05, 0.05)
		angle += jitter
		var radius: float = lerpf(outer_radius * 0.35, outer_radius * 0.95, clampf(t + rng.randf_range(-0.08, 0.08), 0.0, 1.0))
		var center: Vector2 = Vector2(cos(angle), sin(angle)) * radius
		var size: float = lerpf(outer_radius * 0.08, outer_radius * 0.12, t)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		draw_line(center - dir * size, center + dir * size, sparkle_color, max(1.5, size * 0.08), true)
		var diag_dir: Vector2 = dir.rotated(PI * 0.5)
		draw_line(center - diag_dir * size * 0.6, center + diag_dir * size * 0.6, sparkle_color, max(1.2, size * 0.06), true)
