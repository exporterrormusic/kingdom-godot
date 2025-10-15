extends Node2D
class_name EnemyDeathBurst

@export var max_radius: float = 48.0
@export var duration: float = 0.42
@export var base_color: Color = Color(1.0, 0.46, 0.3, 0.85)
@export var glow_color: Color = Color(1.0, 0.68, 0.42, 0.65)
@export var rim_color: Color = Color(1.0, 0.85, 0.6, 0.72)
@export var spark_color: Color = Color(1.0, 0.9, 0.65, 0.9)
@export var shard_color: Color = Color(1.0, 0.76, 0.48, 0.75)
@export var shard_count: int = 10
@export var haze_layers: int = 3

var _elapsed := 0.0
var _rng := RandomNumberGenerator.new()
var _rotation_seed := 0.0
var _shard_scale: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	_rng.randomize()
	_rotation_seed = _rng.randf_range(0.0, TAU)
	_shard_scale.resize(maxi(1, shard_count))
	for i in range(_shard_scale.size()):
		_shard_scale[i] = _rng.randf_range(0.75, 1.4)
	set_process(true)
	queue_redraw()

func configure(primary: Color, accent: Color, radius: float) -> void:
	base_color = primary
	rim_color = accent
	max_radius = maxf(radius, 24.0)
	glow_color = primary.lerp(accent, 0.35)
	spark_color = accent.lerp(Color(1.0, 0.95, 0.75, 0.85), 0.4)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if duration <= 0.0:
		return
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	var fade := 1.0 - progress
	var radius := max_radius * (0.55 + 0.45 * progress)
	_draw_haze(radius, fade)
	_draw_core(radius, fade)
	_draw_rim(radius, fade)
	_draw_shards(radius, fade)

func _draw_haze(radius: float, fade: float) -> void:
	var layers := maxi(1, haze_layers)
	for i in range(layers):
		var t := float(i) / float(layers)
		var layer_radius := radius * (1.0 + 0.35 * t)
		var alpha := glow_color.a * fade * pow(1.0 - t, 1.2)
		if alpha <= 0.0:
			continue
		var color := Color(glow_color.r, glow_color.g, glow_color.b, alpha)
		draw_circle(Vector2.ZERO, layer_radius, color)

func _draw_core(radius: float, fade: float) -> void:
	var inner_radius := radius * 0.42
	var core_alpha := base_color.a * fade
	var core := Color(base_color.r, base_color.g, base_color.b, core_alpha)
	draw_circle(Vector2.ZERO, inner_radius, core)
	var highlight := Color(rim_color.r, rim_color.g, rim_color.b, rim_color.a * fade * 0.6)
	draw_circle(Vector2.ZERO, inner_radius * 0.55, highlight)

func _draw_rim(radius: float, fade: float) -> void:
	var rim_alpha := rim_color.a * fade
	var rim := Color(rim_color.r, rim_color.g, rim_color.b, rim_alpha)
	draw_arc(Vector2.ZERO, radius * 0.95, 0.0, TAU, 48, rim, maxf(2.0, radius * 0.12))

func _draw_shards(radius: float, fade: float) -> void:
	if shard_count <= 0:
		return
	var shard_alpha := shard_color.a * fade
	var color := Color(shard_color.r, shard_color.g, shard_color.b, shard_alpha)
	for i in range(shard_count):
		var angle := _rotation_seed + TAU * float(i) / float(maxi(1, shard_count))
		var scale_factor := 1.0
		if i < _shard_scale.size():
			scale_factor = _shard_scale[i]
		var inner := Vector2.ZERO
		var outer := Vector2(cos(angle), sin(angle)) * radius * (1.1 + 0.35 * scale_factor * (1.0 - fade))
		draw_line(inner, outer, color, maxf(2.0, radius * 0.04), true)
		draw_circle(outer, maxf(1.5, radius * 0.06), Color(color.r, color.g, color.b, color.a * 0.65))
