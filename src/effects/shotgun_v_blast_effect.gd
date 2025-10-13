extends Node2D
class_name ShotgunVBlastEffect

@export var duration: float = 0.35
@export var blast_range: float = 360.0
@export var blast_angle: float = 45.0
@export var arm_color: Color = Color(1.0, 0.45, 0.12, 1.0)
@export var core_color: Color = Color(1.0, 0.92, 0.55, 0.95)
@export var fill_color: Color = Color(0.96, 0.3, 0.05, 0.65)
@export var secondary_glow_color: Color = Color(1.0, 0.98, 0.9, 0.9)
@export var highlight_color: Color = Color(1.0, 0.75, 0.2, 0.85)

var _age: float = 0.0
var _forward: Vector2 = Vector2.RIGHT
var _base_arm_color: Color = arm_color
var _base_fill_color: Color = fill_color
var _base_core_color: Color = core_color

func _ready() -> void:
	set_process(true)
	set_notify_transform(true)
	z_index = 420
	queue_redraw()

func configure(forward: Vector2, range_distance: float, spread_degrees: float, color: Color) -> void:
	_forward = forward.normalized() if forward.length() > 0.0 else Vector2.RIGHT
	blast_range = clampf(range_distance, 120.0, 640.0)
	blast_angle = clampf(spread_degrees, 12.0, 120.0)
	arm_color = Color(color.r, color.g, color.b, color.a)
	_base_arm_color = arm_color
	fill_color = Color(color.r * 0.85 + 0.15, color.g * 0.35, color.b * 0.2, clampf(color.a * 0.75, 0.0, 1.0))
	_base_fill_color = fill_color
	_base_core_color = Color(1.0, 0.95, 0.55, clampf(0.9 * color.a + 0.1, 0.0, 1.0))
	queue_redraw()

func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var life_ratio: float = 1.0 - clampf(_age / max(duration, 0.001), 0.0, 1.0)
	var eased := pow(life_ratio, 0.45)
	var half_angle := deg_to_rad(blast_angle * 0.5)
	var left_dir := _forward.rotated(-half_angle)
	var right_dir := _forward.rotated(half_angle)
	var left_tip := left_dir * blast_range
	var right_tip := right_dir * blast_range

	_draw_core_flash(life_ratio)
	_draw_fill_sector(left_tip, right_tip, eased)
	_draw_arm(left_dir, left_tip, eased)
	_draw_arm(right_dir, right_tip, eased)
	_draw_fill_lines(eased)

func _draw_core_flash(life_ratio: float) -> void:
	var flash_alpha := clampf(_base_core_color.a * (0.8 + 0.2 * life_ratio), 0.0, 1.0)
	var flash := Color(_base_core_color.r, _base_core_color.g, _base_core_color.b, flash_alpha)
	var radius := blast_range * (0.18 + 0.12 * life_ratio)
	draw_circle(Vector2.ZERO, radius, flash)
	var white_alpha := clampf(secondary_glow_color.a * (0.6 + 0.4 * life_ratio), 0.0, 1.0)
	var white_glow := Color(secondary_glow_color.r, secondary_glow_color.g, secondary_glow_color.b, white_alpha)
	draw_circle(Vector2.ZERO, radius * 0.72, white_glow)

func _draw_fill_sector(left_tip: Vector2, right_tip: Vector2, eased: float) -> void:
	var sector_color := Color(_base_fill_color.r, _base_fill_color.g, _base_fill_color.b, clampf(_base_fill_color.a * eased, 0.0, 1.0))
	var half_length := blast_range * (0.6 + 0.4 * eased)
	var left_point := left_tip.normalized() * half_length
	var right_point := right_tip.normalized() * half_length
	var sector_points := PackedVector2Array([
		Vector2.ZERO,
		left_point,
		right_point
	])
	var sector_colors := PackedColorArray([
		sector_color,
		Color(sector_color.r, sector_color.g, sector_color.b, sector_color.a * 0.8),
		Color(sector_color.r, sector_color.g, sector_color.b, sector_color.a * 0.8)
	])
	draw_polygon(sector_points, sector_colors)

func _draw_arm(direction: Vector2, tip: Vector2, eased: float) -> void:
	var width: float = max(18.0, blast_range * 0.08) * (0.4 + 0.6 * eased)
	var glow_width: float = width * 1.8
	var arm_alpha := clampf(_base_arm_color.a * (0.65 + 0.35 * eased), 0.0, 1.0)
	var glow_alpha := clampf(arm_color.a * 0.75 * eased, 0.0, 1.0)
	var arm := Color(_base_arm_color.r, _base_arm_color.g, _base_arm_color.b, arm_alpha)
	var glow := Color(highlight_color.r, highlight_color.g, highlight_color.b, clampf(highlight_color.a * eased, 0.0, 1.0))
	draw_line(Vector2.ZERO, tip, Color(arm.r, arm.g, arm.b, glow_alpha), glow_width, true)
	draw_line(Vector2.ZERO, tip, arm, width, true)
	var highlight := Color(glow.r, glow.g, glow.b, clampf(glow.a * 1.2, 0.0, 1.0))
	draw_line(Vector2.ZERO, tip, highlight, max(4.0, width * 0.45), true)

	var sparkle_count := 5
	for i in range(sparkle_count):
		var factor := float(i + 1) / float(sparkle_count + 1)
		var pos := tip * factor
		var sparkle_alpha := clampf(glow.a * pow(eased, 0.65), 0.0, 1.0)
		draw_circle(pos, max(6.0, width * 0.25 * (1.0 - factor * 0.4)), Color(glow.r, glow.g, glow.b, sparkle_alpha))
	var normal := Vector2(-direction.y, direction.x).normalized() if direction.length() > 0.0 else Vector2.UP
	var crossbar_alpha := clampf(highlight.a * 0.9, 0.0, 1.0)
	var crossbar := Color(highlight.r, highlight.g, highlight.b, crossbar_alpha)
	var crossbar_half: float = width * 0.35
	draw_line(tip - normal * crossbar_half, tip + normal * crossbar_half, crossbar, max(3.0, width * 0.25), true)

func _draw_fill_lines(eased: float) -> void:
	var steps := 4
	if steps <= 1:
		return
	var total_angle := deg_to_rad(blast_angle)
	for step in range(1, steps):
		var t := float(step) / float(steps)
		var angle := -total_angle * 0.5 + total_angle * t
		var direction := _forward.rotated(angle)
		var reach := blast_range * (0.5 + 0.45 * eased)
		var width: float = max(8.0, blast_range * 0.05) * (0.6 + 0.4 * eased)
		var fill_alpha := clampf(_base_fill_color.a * (0.55 + 0.45 * eased), 0.0, 1.0)
		var fill := Color(_base_fill_color.r, _base_fill_color.g, _base_fill_color.b, fill_alpha)
		draw_line(Vector2.ZERO, direction * reach, fill, width, true)
		var accent := Color(highlight_color.r, highlight_color.g, highlight_color.b, clampf(highlight_color.a * (0.5 + 0.5 * eased), 0.0, 1.0))
		draw_circle(direction * (reach * 0.7), width * 0.55, accent)
