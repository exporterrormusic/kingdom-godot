@tool
extends Node2D
class_name SwordBeamVisual

@export var preview_range: float = 520.0
@export var preview_width: float = 18.0
@export var preview_color: Color = Color(0.39, 1.0, 0.78, 0.95)
@export var additive_blend: bool = true
@export_range(0.1, 2.0, 0.01) var preview_fade: float = 1.0

var _active_length: float = 0.0
var _beam_width: float = 1.0
var _color: Color = Color.WHITE
var _fade: float = 1.0
var _activation: float = 1.0
var _lifetime_ratio: float = 0.0
var _seed: int = 0
var _time: float = 0.0
var _glow_texture: Texture2D = null
var _origin_glow: Sprite2D = null
var _tip_glow: Sprite2D = null

func _ready() -> void:
	if additive_blend:
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive
	_ensure_glow_sprites()
	if Engine.is_editor_hint():
		_set_preview_state()

func update_visual(params: Dictionary) -> void:
	_active_length = maxf(float(params.get("active_length", preview_range)), 0.0)
	_beam_width = maxf(float(params.get("beam_width", preview_width)), 1.0)
	_color = params.get("color", preview_color)
	_fade = clampf(float(params.get("fade", preview_fade)), 0.0, 2.0)
	_activation = clampf(float(params.get("activation", 1.0)), 0.0, 1.0)
	_lifetime_ratio = clampf(float(params.get("lifetime_ratio", 0.0)), 0.0, 1.0)
	_seed = int(params.get("seed", 0))
	_time = float(params.get("time", 0.0))
	_update_glow_sprites()
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_set_preview_state()

func _set_preview_state() -> void:
	_active_length = preview_range
	_beam_width = preview_width
	_color = preview_color
	_fade = preview_fade
	_activation = 1.0
	_lifetime_ratio = 0.0
	_seed = 0
	_update_glow_sprites()
	queue_redraw()

func _draw() -> void:
	if _active_length <= 0.1:
		return
	var fade := maxf(0.1, _fade * (1.0 - _lifetime_ratio * 0.65))
	var base_width := maxf(_beam_width, 2.0)
	var layer_colors := [
		Color(_color.r * 0.4, _color.g * 0.45, _color.b * 0.6, fade * 0.55),
		Color(_color.r * 0.65, _color.g * 0.75, _color.b * 0.85, fade * 0.65),
		Color(_color.r, _color.g, _color.b, fade * 0.85),
		Color(minf(1.0, _color.r + 0.18), minf(1.0, _color.g + 0.18), minf(1.0, _color.b + 0.18), fade * 0.7),
		Color(0.95, 0.98, 1.0, fade * 0.8)
	]
	var segments: int = 24
	for layer_index in range(layer_colors.size()):
		var layer_width: float = maxf(1.0, base_width * (2.2 - float(layer_index) * 0.35))
		var layer_color: Color = layer_colors[layer_index]
		for segment in range(segments):
			var t0: float = float(segment) / float(segments)
			var t1: float = float(segment + 1) / float(segments)
			var segment_start := Vector2(_active_length * t0, 0.0)
			var segment_end := Vector2(_active_length * t1, 0.0)
			var taper0: float = _segment_taper(t0)
			var taper1: float = _segment_taper(t1)
			var segment_width: float = maxf(1.0, (layer_width * taper0 + layer_width * taper1) * 0.5)
			var alpha_scale: float = minf(1.0, _activation / maxf(t1, 0.001))
			if alpha_scale <= 0.0:
				continue
			var final_color := Color(layer_color.r, layer_color.g, layer_color.b, clampf(layer_color.a * alpha_scale, 0.02, 1.0))
			draw_line(segment_start, segment_end, final_color, segment_width, true)
	_draw_particles(fade)
	_draw_flares(base_width, fade)

func _segment_taper(t: float) -> float:
	if t < 0.1:
		return lerpf(0.25, 1.0, t / 0.1)
	if t > 0.9:
		return lerpf(1.0, 0.35, (t - 0.9) / 0.1)
	return 1.0

func _draw_particles(fade: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var count: int = max(4, int(_active_length / 24.0))
	for i in range(count):
		var t: float = float(i) / max(1.0, float(count - 1))
		var x_pos: float = _active_length * t
		var lateral: float = rng.randf_range(-_beam_width * 0.35, _beam_width * 0.35)
		var size: float = rng.randf_range(2.0, 4.5)
		var pulse: float = rng.randf_range(2.0, 4.5)
		var pulse_alpha := 0.4 + 0.6 * sin((_time + pulse) * pulse)
		var alpha := clampf(fade * pulse_alpha, 0.1, 0.9)
		var sparkle_color := Color(0.95, 0.98, 1.0, alpha)
		draw_circle(Vector2(x_pos, lateral), size, sparkle_color)

func _draw_flares(base_width: float, fade: float) -> void:
	var origin_radius: float = maxf(base_width * 0.8, 14.0)
	var tip_radius: float = maxf(base_width * 0.95, 18.0)
	var glow_color := Color(_color.r, _color.g, _color.b, fade * 0.6)
	var core_color := Color(0.98, 1.0, 0.95, fade * 0.85)
	draw_circle(Vector2.ZERO, origin_radius, glow_color)
	draw_circle(Vector2.ZERO, origin_radius * 0.45, core_color)
	draw_circle(Vector2(_active_length, 0.0), tip_radius, glow_color)
	draw_circle(Vector2(_active_length, 0.0), tip_radius * 0.5, core_color)
	var cross_length: float = tip_radius * 1.8
	for i in range(2):
		var angle: float = PI * 0.25 + PI * 0.5 * float(i)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		draw_line(Vector2(_active_length, 0.0) - dir * cross_length * 0.15, Vector2(_active_length, 0.0) + dir * cross_length, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.7), maxf(2.0, tip_radius * 0.18), true)
		draw_line(Vector2(_active_length, 0.0) - dir * cross_length * 0.05, Vector2(_active_length, 0.0) + dir * cross_length * 0.55, Color(core_color.r, core_color.g, core_color.b, core_color.a * 0.9), maxf(1.2, tip_radius * 0.1), true)

func _ensure_glow_sprites() -> void:
	if _glow_texture == null:
		_glow_texture = _create_radial_glow_texture()
	if _origin_glow == null:
		_origin_glow = _make_glow_sprite()
		add_child(_origin_glow)
	if _tip_glow == null:
		_tip_glow = _make_glow_sprite()
		add_child(_tip_glow)

func _make_glow_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _glow_texture
	sprite.centered = true
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = glow_material
	sprite.z_index = max(z_index + 8, 80)
	sprite.z_as_relative = false
	sprite.visible = true
	return sprite

func _update_glow_sprites() -> void:
	if _origin_glow == null or _tip_glow == null:
		return
	var fade := maxf(0.35, 1.0 - _lifetime_ratio * 0.75)
	var glow_alpha := clampf(_color.a * 0.82 * fade + 0.08, 0.08, 0.92)
	var glow_color := Color(
		clampf(_color.r * 0.92 + 0.08, 0.0, 1.0),
		clampf(_color.g * 0.95 + 0.04, 0.0, 1.0),
		clampf(_color.b * 1.05, 0.0, 1.0),
		glow_alpha
	)
	_origin_glow.modulate = glow_color
	_tip_glow.modulate = glow_color
	var base_scale := clampf(_beam_width * 0.035, 0.28, 0.6)
	_origin_glow.scale = Vector2.ONE * base_scale
	_tip_glow.scale = Vector2.ONE * maxf(base_scale * 1.6, 0.38)
	_origin_glow.position = Vector2.ZERO
	_tip_glow.position = Vector2(_active_length, 0.0)

func _create_radial_glow_texture(size: int = 128) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var max_distance := center.length()
	for y in size:
		for x in size:
			var pos := Vector2(x + 0.5, y + 0.5)
			var distance := pos.distance_to(center)
			var normalized := clampf(distance / max_distance, 0.0, 1.0)
			var falloff := pow(1.0 - normalized, 2.4)
			var alpha := clampf(falloff, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
