extends Node2D
class_name SwordBeam

@export var owner_reference: Node2D = null
@export_range(10.0, 1400.0, 1.0) var beam_range: float = 500.0
@export_range(4.0, 120.0, 0.5) var beam_width: float = 18.0
@export_range(1, 2000, 1) var damage: int = 80
@export_range(0.05, 2.0, 0.01) var duration: float = 0.4
@export var color: Color = Color(0.39, 1.0, 0.78, 0.95)
@export_range(-180.0, 180.0, 0.5) var relative_angle: float = 0.0

var _elapsed: float = 0.0
var _forward: Vector2 = Vector2.RIGHT
var _damaged_enemies: Dictionary = {}
var _particles: Array = []
var _rng := RandomNumberGenerator.new()
var _glow_texture: Texture2D = null
var _origin_glow: Sprite2D = null
var _tip_glow: Sprite2D = null

const SwordSparkleScript := preload("res://src/effects/sword_sparkle.gd")

func _ready() -> void:
	_rng.randomize()
	set_process(true)
	_ensure_glow_sprites()
	var additive_material := CanvasItemMaterial.new()
	additive_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive_material
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if not _update_transform():
		queue_free()
		return
	if _elapsed >= duration:
		queue_free()
		return
	_apply_damage()
	_update_particles()
	_update_glow_sprites()
	queue_redraw()

func _update_transform() -> bool:
	if owner_reference == null or not is_instance_valid(owner_reference):
		return false
	var origin: Vector2 = owner_reference.global_position
	var aim: Vector2 = Vector2.ZERO
	if owner_reference.has_method("get_gun_tip_position"):
		var tip_variant: Variant = owner_reference.call("get_gun_tip_position")
		if tip_variant is Vector2:
			origin = tip_variant
	if owner_reference.has_method("_get_aim_direction"):
		var aim_variant: Variant = owner_reference.call("_get_aim_direction")
		if aim_variant is Vector2 and Vector2(aim_variant).length() > 0.0:
			aim = Vector2(aim_variant)
	if aim.length() == 0.0:
		if owner_reference is Node2D:
			var owner_node := owner_reference as Node2D
			var to_origin := origin - owner_node.global_position
			if to_origin.length() > 0.01:
				aim = to_origin.normalized()
	if aim.length() == 0.0:
		aim = Vector2.RIGHT
	_forward = aim.normalized()
	global_position = origin
	rotation = _forward.angle() + deg_to_rad(relative_angle)
	return true

func _compute_activation_progress() -> float:
	var ramp_duration := maxf(duration * 0.3, 0.001)
	return clampf(_elapsed / ramp_duration, 0.0, 1.0)

func _apply_damage() -> void:
	var active_length: float = beam_range * _compute_activation_progress()
	if active_length <= 0.0:
		return
	var start_world: Vector2 = global_position
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D) or not enemy.has_method("apply_damage"):
			continue
		var enemy_node := enemy as Node2D
		var to_enemy: Vector2 = enemy_node.global_position - start_world
		var projection: float = _forward.dot(to_enemy)
		if projection < 0.0 or projection > active_length:
			continue
		var closest_point: Vector2 = start_world + _forward * projection
		var distance: float = enemy_node.global_position.distance_to(closest_point)
		var enemy_radius: float = _resolve_enemy_radius(enemy_node)
		var beam_radius: float = beam_width * 0.5
		if distance <= beam_radius + enemy_radius:
			var enemy_id := enemy_node.get_instance_id()
			if _damaged_enemies.has(enemy_id):
				continue
			enemy_node.apply_damage(damage)
			_damaged_enemies[enemy_id] = true
			if owner_reference and is_instance_valid(owner_reference) and owner_reference.has_method("register_burst_hit"):
				owner_reference.register_burst_hit(enemy_node)
			_spawn_hit_spark(enemy_node.global_position)

func _resolve_enemy_radius(enemy: Node2D) -> float:
	if enemy.has_method("get_collision_radius"):
		var result: Variant = enemy.call("get_collision_radius")
		if result is float or result is int:
			return maxf(float(result), 12.0)
	var rect := enemy.get_node_or_null("CollisionShape2D")
	if rect and rect is CollisionShape2D:
		var shape: Shape2D = (rect as CollisionShape2D).shape
		if shape is CircleShape2D:
			return maxf((shape as CircleShape2D).radius, 12.0)
	return 18.0

func _update_particles() -> void:
	_particles.clear()
	var active_length: float = beam_range * _compute_activation_progress()
	if active_length <= 0.0:
		return
	var count: int = max(4, int(active_length / 24.0))
	for i in range(count):
		var t: float = float(i) / max(1.0, float(count - 1))
		var x_pos: float = active_length * t
		var lateral: float = _rng.randf_range(-beam_width * 0.35, beam_width * 0.35)
		_particles.append({
			"position": Vector2(x_pos, lateral),
			"size": _rng.randf_range(2.0, 4.5),
			"pulse": _rng.randf_range(2.0, 4.5)
		})

func _draw() -> void:
	var active_length: float = beam_range * _compute_activation_progress()
	if active_length <= 0.0:
		return
	var progress: float = clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var fade: float = maxf(0.3, 1.0 - progress * 0.65)
	var base_width: float = maxf(beam_width, 2.0)
	var layer_colors := [
		Color(color.r * 0.4, color.g * 0.45, color.b * 0.6, fade * 0.55),
		Color(color.r * 0.65, color.g * 0.75, color.b * 0.85, fade * 0.65),
		Color(color.r, color.g, color.b, fade * 0.85),
		Color(minf(1.0, color.r + 0.18), minf(1.0, color.g + 0.18), minf(1.0, color.b + 0.18), fade * 0.7),
		Color(0.95, 0.98, 1.0, fade * 0.8)
	]
	var segments: int = 24
	for layer_index in range(layer_colors.size()):
		var layer_width: float = maxf(1.0, base_width * (2.2 - float(layer_index) * 0.35))
		var layer_color: Color = layer_colors[layer_index]
		for segment in range(segments):
			var t0: float = float(segment) / float(segments)
			var t1: float = float(segment + 1) / float(segments)
			var segment_start := Vector2(active_length * t0, 0.0)
			var segment_end := Vector2(active_length * t1, 0.0)
			var taper0 := _segment_taper(t0)
			var taper1 := _segment_taper(t1)
			var width0 := layer_width * taper0
			var width1 := layer_width * taper1
			var segment_width := maxf(1.0, (width0 + width1) * 0.5)
			var alpha_scale := minf(1.0, _compute_activation_progress() / maxf(t1, 0.001))
			if alpha_scale <= 0.0:
				continue
			var final_color := Color(layer_color.r, layer_color.g, layer_color.b, clampf(layer_color.a * alpha_scale, 0.02, 1.0))
			draw_line(segment_start, segment_end, final_color, segment_width, true)
	_draw_particles(fade)
	_draw_flares(base_width, fade, active_length)

func _segment_taper(t: float) -> float:
	if t < 0.1:
		return lerpf(0.25, 1.0, t / 0.1)
	if t > 0.9:
		return lerpf(1.0, 0.35, (t - 0.9) / 0.1)
	return 1.0

func _draw_particles(fade: float) -> void:
	for particle in _particles:
		if not (particle is Dictionary):
			continue
		var pos: Vector2 = particle.get("position", Vector2.ZERO)
		var size: float = float(particle.get("size", 3.0))
		var pulse: float = float(particle.get("pulse", 3.0))
		var pulse_alpha := 0.4 + 0.6 * sin((_elapsed + pulse) * pulse)
		var alpha := clampf(fade * pulse_alpha, 0.1, 0.9)
		var sparkle_color := Color(0.95, 0.98, 1.0, alpha)
		draw_circle(pos, size, sparkle_color)

func _draw_flares(base_width: float, fade: float, active_length: float) -> void:
	var origin_radius: float = maxf(base_width * 0.8, 14.0)
	var tip_radius: float = maxf(base_width * 0.95, 18.0)
	var glow_color := Color(color.r, color.g, color.b, fade * 0.6)
	var core_color := Color(0.98, 1.0, 0.95, fade * 0.85)
	draw_circle(Vector2.ZERO, origin_radius, glow_color)
	draw_circle(Vector2.ZERO, origin_radius * 0.45, core_color)
	draw_circle(Vector2(active_length, 0.0), tip_radius, glow_color)
	draw_circle(Vector2(active_length, 0.0), tip_radius * 0.5, core_color)
	var cross_length: float = tip_radius * 1.8
	for i in range(2):
		var angle: float = PI * 0.25 + PI * 0.5 * float(i)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		draw_line(Vector2(active_length, 0.0) - dir * cross_length * 0.15, Vector2(active_length, 0.0) + dir * cross_length, Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * 0.7), maxf(2.0, tip_radius * 0.18), true)
		draw_line(Vector2(active_length, 0.0) - dir * cross_length * 0.05, Vector2(active_length, 0.0) + dir * cross_length * 0.55, Color(core_color.r, core_color.g, core_color.b, core_color.a * 0.9), maxf(1.2, tip_radius * 0.1), true)

func _spawn_hit_spark(impact_position: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var sparkle := SwordSparkleScript.new()
	sparkle.color = Color(color.r, color.g, color.b, minf(color.a * 1.1, 1.0))
	sparkle.radius = maxf(beam_width * 2.2, 48.0)
	sparkle.duration = 0.32
	sparkle.spin_speed = 8.0
	sparkle.pulse_scale = 0.4
	sparkle.z_as_relative = false
	sparkle.z_index = int(max(z_index + 10, 80))
	parent.add_child(sparkle)
	sparkle.global_position = impact_position

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
	var activation := _compute_activation_progress()
	var active_length := beam_range * activation
	var lifetime_ratio := clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var fade := maxf(0.35, 1.0 - lifetime_ratio * 0.75)
	var glow_alpha := clampf(color.a * 0.82 * fade + 0.08, 0.08, 0.92)
	var glow_color := Color(
		clampf(color.r * 0.92 + 0.08, 0.0, 1.0),
		clampf(color.g * 0.95 + 0.04, 0.0, 1.0),
		clampf(color.b * 1.05, 0.0, 1.0),
		glow_alpha
	)
	_origin_glow.modulate = glow_color
	_tip_glow.modulate = glow_color
	var base_scale := clampf(beam_width * 0.035, 0.28, 0.6)
	_origin_glow.scale = Vector2.ONE * base_scale
	_tip_glow.scale = Vector2.ONE * maxf(base_scale * 1.6, 0.38)
	_origin_glow.position = Vector2.ZERO
	_tip_glow.position = Vector2(active_length, 0.0)

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
