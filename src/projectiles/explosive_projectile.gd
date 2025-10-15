extends Area2D
class_name ExplosiveProjectile

@export var speed: float = 600.0
@export var direction: Vector2 = Vector2.RIGHT
@export var target_position: Vector2 = Vector2.ZERO
@export var explode_at_target: bool = false
@export var lifetime: float = 2.5
@export var max_flight_time: float = 5.0
@export var damage: int = 40
@export var explosion_damage: int = 60
@export var explosion_radius: float = 150.0
@export var explosion_color: Color = Color(1.0, 0.5, 0.2, 0.8)
@export var owner_node: Node = null
@export var render_style: String = "grenade" # "grenade" | "rocket"
@export var special_attack: bool = false
@export var trail_enabled: bool = false
@export var trail_color: Color = Color(1.0, 0.8, 0.3, 0.8)
@export var trail_width: float = 18.0
@export var trail_spacing: float = 32.0
@export var trail_max_points: int = 14
@export var trail_core_color: Color = Color(1.0, 0.95, 0.8, 0.9)
@export var trail_glow_color: Color = Color(1.0, 0.6, 0.2, 0.6)
@export var exhaust_enabled: bool = false
@export var exhaust_length: float = 42.0
@export var exhaust_width: float = 22.0
@export var exhaust_flicker_speed: float = 18.0
@export var exhaust_glow_color: Color = Color(1.0, 0.55, 0.1, 0.7)
@export var smoke_enabled: bool = false
@export var smoke_color: Color = Color(0.55, 0.55, 0.55, 0.85)
@export var smoke_initial_radius: float = 10.0
@export var smoke_growth_rate: float = 28.0
@export var smoke_fade_speed: float = 0.9
@export var smoke_spawn_interval: float = 0.05
@export var ground_fire_enabled: bool = false
@export var ground_fire_duration: float = 0.0
@export var ground_fire_damage: int = 0
@export var ground_fire_radius: float = 0.0
@export var ground_fire_color: Color = Color(1.0, 0.5, 0.3, 0.85)

const ExplosionEffectScene := preload("res://scenes/effects/ExplosionEffect.tscn")
const PROJECTILE_BASE_Z_INDEX := 900
const GroundFireScene: PackedScene = preload("res://scenes/effects/GroundFire.tscn")
const GroundFireScript := preload("res://src/effects/ground_fire.gd")

var _age := 0.0
var _flight_time := 0.0
var _collision_shape: CollisionShape2D
var _velocity: Vector2 = Vector2.ZERO
var _trail_points: Array = []
var _trail_ages: Array = []
var _trail_distance := 0.0
var _exploded := false
var _smoke_puffs: Array = []
var _smoke_timer := 0.0
var _exhaust_time := 0.0
var _flicker_seed := 0.0
var _rng := RandomNumberGenerator.new()
var _audio_director: AudioDirector = null
var _flight_audio_handle: int = -1
var _glow_sprite: Sprite2D = null
var _glow_texture: Texture2D = null

func _environment_tint(color: Color, local_offset: Vector2 = Vector2.ZERO) -> Color:
	var viewport := get_viewport()
	if viewport == null:
		return color
	return BasicProjectileVisual._apply_compensation(color, global_position + local_offset, viewport)

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = PROJECTILE_BASE_Z_INDEX
	_connect_collision_signals()
	collision_layer = 2
	collision_mask = 4
	monitorable = false
	_configure_collision_shape()
	_configure_motion()
	_rng.randomize()
	_flicker_seed = _rng.randf_range(0.0, TAU)
	if trail_enabled:
		_trail_points.append(global_position)
		_trail_ages.append(0.0)
	_audio_director = _resolve_audio_director()
	_start_flight_audio_if_needed()
	set_process(true)
	_ensure_glow_sprite()
	_update_glow_visual()
	queue_redraw()

func _process(delta: float) -> void:
	if _exploded:
		return
	_age += delta
	_flight_time += delta
	if lifetime > 0.0 and _age >= lifetime:
		_explode()
		return
	if max_flight_time > 0.0 and _flight_time >= max_flight_time:
		_explode()
		return
	var step := _velocity * delta
	var new_position := global_position + step
	if explode_at_target and target_position != Vector2.ZERO:
		var to_target := target_position - global_position
		var max_distance := step.length() + 6.0
		if to_target.length() <= max_distance:
			global_position = target_position
			_explode()
			return
	global_position = new_position
	var is_rocket := render_style.to_lower() == "rocket"
	if trail_enabled:
		_update_trail(step.length())
		_advance_trail_ages(delta)
	if smoke_enabled and is_rocket:
		_update_smoke(delta)
	if exhaust_enabled and is_rocket:
		_exhaust_time += delta
	_update_glow_visual()
	queue_redraw()

func _exit_tree() -> void:
	_stop_flight_audio()
	if _glow_sprite and is_instance_valid(_glow_sprite):
		_glow_sprite.queue_free()

func _connect_collision_signals() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("area_entered", Callable(self, "_on_area_entered"))

func _configure_collision_shape() -> void:
	_collision_shape = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = max(8.0, explosion_radius * 0.15)
	_collision_shape.shape = shape
	add_child(_collision_shape)

func _configure_motion() -> void:
	if explode_at_target and target_position != Vector2.ZERO:
		var to_target := target_position - global_position
		if to_target.length() > 0.01:
			direction = to_target.normalized()
	if direction.length() == 0.0:
		direction = Vector2.RIGHT
	_velocity = direction.normalized() * speed

func _update_trail(distance_step: float) -> void:
	_trail_distance += distance_step
	if _trail_distance < trail_spacing:
		return
	_trail_distance = 0.0
	_trail_points.append(global_position)
	_trail_ages.append(0.0)
	if _trail_points.size() > trail_max_points:
		_trail_points.pop_front()
		_trail_ages.pop_front()

func _advance_trail_ages(delta: float) -> void:
	for i in range(_trail_ages.size()):
		_trail_ages[i] += delta

func _spawn_smoke_puff() -> void:
	var dir := _velocity.normalized()
	if dir.length() == 0.0:
		dir = Vector2.RIGHT
	var base_offset: Vector2 = -dir * max(exhaust_length * 0.4, 24.0)
	var jitter: Vector2 = Vector2(
		_rng.randf_range(-smoke_initial_radius * 0.6, smoke_initial_radius * 0.6),
		_rng.randf_range(-smoke_initial_radius * 0.4, smoke_initial_radius * 0.4)
	)
	var puff_position: Vector2 = global_position + base_offset + jitter
	var initial_radius: float = smoke_initial_radius * _rng.randf_range(0.7, 1.2)
	var initial_alpha: float = clampf(smoke_color.a * _rng.randf_range(0.8, 1.1), 0.0, 1.0)
	_smoke_puffs.append({
		"position": puff_position,
		"radius": initial_radius,
		"alpha": initial_alpha,
		"color": smoke_color,
		"age": 0.0
	})

func _update_smoke(delta: float) -> void:
	_smoke_timer += delta
	while _smoke_timer >= smoke_spawn_interval:
		_smoke_timer -= smoke_spawn_interval
		_spawn_smoke_puff()
	for i in range(_smoke_puffs.size() - 1, -1, -1):
		var puff: Dictionary = _smoke_puffs[i]
		puff["age"] = puff.get("age", 0.0) + delta
		puff["radius"] = puff.get("radius", smoke_initial_radius) + smoke_growth_rate * delta
		var new_alpha: float = float(puff.get("alpha", smoke_color.a)) - smoke_fade_speed * delta
		puff["alpha"] = new_alpha
		_smoke_puffs[i] = puff
		if new_alpha <= 0.02:
			_smoke_puffs.remove_at(i)

func _on_body_entered(body: Node) -> void:
	if _should_ignore_target(body):
		return
	_explode()

func _on_area_entered(area: Area2D) -> void:
	if _should_ignore_target(area):
		return
	_explode()

func _should_ignore_target(target: Node) -> bool:
	if not is_instance_valid(target):
		return true
	if target == owner_node:
		return true
	return false

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_apply_explosion_damage()
	_play_explosion_audio()
	_stop_flight_audio()
	_spawn_explosion_effect()
	_spawn_ground_fire_if_needed()
	queue_free()

func _apply_explosion_damage() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D) or not enemy.has_method("apply_damage"):
			continue
		var enemy_node := enemy as Node2D
		var distance := enemy_node.global_position.distance_to(global_position)
		if distance <= explosion_radius:
			enemy_node.apply_damage(explosion_damage)
			if owner_node and is_instance_valid(owner_node) and owner_node.has_method("register_burst_hit"):
				owner_node.register_burst_hit(enemy_node)

func _spawn_explosion_effect() -> void:
	if ExplosionEffectScene == null:
		return
	var effect_instance := ExplosionEffectScene.instantiate()
	if not (effect_instance is ExplosionEffect):
		effect_instance.queue_free()
		return
	var effect: ExplosionEffect = effect_instance
	effect.radius = explosion_radius
	effect.base_color = explosion_color
	effect.duration = 0.55 if special_attack else 0.4
	effect.ring_thickness = max(6.0, explosion_radius * 0.12)
	if get_parent():
		effect.global_position = global_position
		get_parent().add_child(effect)
	else:
		effect.queue_free()


func _create_ground_fire_effect() -> GroundFire:
	if GroundFireScene:
		var instance: Node = GroundFireScene.instantiate()
		if instance is GroundFire:
			return instance as GroundFire
		instance.queue_free()
	if GroundFireScript:
		return GroundFireScript.new()
	return null

func _spawn_ground_fire_if_needed() -> void:
	if not ground_fire_enabled and ground_fire_damage <= 0:
		return
	var fire: GroundFire = _create_ground_fire_effect()
	if fire == null:
		return
	fire.radius = ground_fire_radius if ground_fire_radius > 0.0 else max(explosion_radius * 0.7, 80.0)
	fire.duration = max(ground_fire_duration, 0.1)
	fire.damage_per_tick = max(1, ground_fire_damage)
	fire.color = ground_fire_color
	fire.global_position = global_position
	if get_parent():
		get_parent().add_child(fire)

func _draw() -> void:
	var style := render_style.to_lower()
	if smoke_enabled and style == "rocket" and not _smoke_puffs.is_empty():
		_draw_smoke()
	if trail_enabled and (_trail_points.size() > 0):
		_draw_trail()
	match style:
		"rocket":
			_draw_rocket()
		"grenade":
			_draw_grenade_body()
		_:
			draw_circle(Vector2.ZERO, 10.0, _environment_tint(explosion_color, Vector2.ZERO))
	_draw_glow_guides_if_debug()

func _ensure_glow_sprite() -> void:
	if _glow_sprite:
		return
	if _glow_texture == null:
		_glow_texture = _create_radial_glow_texture()
	_glow_sprite = Sprite2D.new()
	_glow_sprite.texture = _glow_texture
	_glow_sprite.centered = true
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_sprite.material = glow_material
	_glow_sprite.visible = true
	_glow_sprite.z_as_relative = false
	_glow_sprite.z_index = PROJECTILE_BASE_Z_INDEX + 1
	_glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_glow_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	add_child(_glow_sprite)

func _update_glow_visual() -> void:
	if _glow_sprite == null:
		return
	var style := render_style.to_lower()
	var dir := _velocity
	if dir.length() == 0.0:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	var base_color := explosion_color
	var scale_value := 0.8
	var alpha := clampf(base_color.a * 0.75, 0.0, 1.0)
	var offset := Vector2.ZERO
	var angle := dir.angle()
	if style == "rocket":
		var flame_color := exhaust_glow_color if exhaust_glow_color.a > 0.0 else trail_glow_color
		if flame_color.a <= 0.0:
			flame_color = explosion_color
		base_color = Color(
			clampf(flame_color.r * 1.05 + 0.05, 0.0, 1.0),
			clampf(flame_color.g * 0.9 + 0.02, 0.0, 1.0),
			clampf(flame_color.b * 0.6 + 0.03, 0.0, 1.0),
			clampf(flame_color.a * 0.9 + 0.1, 0.0, 1.0)
		)
		scale_value = 1.08 if special_attack else 0.96
		scale_value = clampf(scale_value, 0.7, 1.35)
		alpha = clampf(base_color.a * 1.08, 0.45, 1.0)
		offset = -dir * max(exhaust_length * 0.34, 18.0)
		angle = dir.angle()
	else:
		angle = 0.0
		alpha = clampf(base_color.a * 0.5 + 0.12, 0.0, 0.6)
		scale_value = clampf(explosion_radius * 0.0024 + 0.38, 0.32, 0.82)
	_glow_sprite.modulate = _environment_tint(Color(base_color.r, base_color.g, base_color.b, alpha), offset)
	_glow_sprite.scale = Vector2.ONE * scale_value
	_glow_sprite.position = offset
	_glow_sprite.rotation = angle

func _create_radial_glow_texture(size: int = 128) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var max_distance := center.length()
	for y in size:
		for x in size:
			var pos := Vector2(x + 0.5, y + 0.5)
			var distance := pos.distance_to(center)
			var normalized := clampf(distance / max_distance, 0.0, 1.0)
			var falloff := pow(1.0 - normalized, 2.4)
			var alpha := clampf(falloff, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(img)

func _draw_glow_guides_if_debug() -> void:
	pass

func _draw_trail() -> void:
	if _trail_points.is_empty() and trail_width <= 0.0:
		return
	var total_points := _trail_points.size() + 1
	if total_points <= 1:
		return
	for idx in range(total_points):
		var array_index := total_points - 1 - idx
		var point: Vector2
		var age: float = 0.0
		if array_index == _trail_points.size():
			point = global_position
		else:
			point = _trail_points[array_index]
			if array_index < _trail_ages.size():
				age = _trail_ages[array_index]
		var t: float = float(idx) / max(1.0, float(total_points - 1))
		var fade: float = clampf(1.0 - t * 0.9, 0.0, 1.0) * clampf(1.0 - age * 0.7, 0.0, 1.0)
		if fade <= 0.01:
			continue
		var local := point - global_position
		var main_radius: float = lerpf(trail_width, trail_width * 0.2, t)
		if main_radius <= 0.5:
			continue
		var outer_color := trail_color
		outer_color.a = trail_color.a * fade
		var core_color := trail_core_color
		core_color.a = trail_core_color.a * fade * 0.9
		var glow_color := trail_glow_color
		glow_color.a = trail_glow_color.a * fade * 0.6
		outer_color = _environment_tint(outer_color, local)
		core_color = _environment_tint(core_color, local)
		glow_color = _environment_tint(glow_color, local)
		draw_circle(local, main_radius, outer_color)
		draw_circle(local, main_radius * 0.45, core_color)
		draw_circle(local, main_radius * 1.5, glow_color)

func _draw_smoke() -> void:
	for puff_variant in _smoke_puffs:
		if not (puff_variant is Dictionary):
			continue
		var puff := puff_variant as Dictionary
		var radius: float = float(puff.get("radius", smoke_initial_radius))
		var alpha: float = clampf(float(puff.get("alpha", smoke_color.a)), 0.0, 1.0)
		if alpha <= 0.01 or radius <= 0.5:
			continue
		var stored_color: Variant = puff.get("color", smoke_color)
		var puff_color: Color = smoke_color
		if stored_color is Color:
			puff_color = stored_color
		var outer := Color(puff_color.r, puff_color.g, puff_color.b, alpha * 0.35)
		var core := Color(puff_color.r * 0.9, puff_color.g * 0.9, puff_color.b * 0.9, alpha)
		var local := (puff.get("position", global_position) as Vector2) - global_position
		outer = _environment_tint(outer, local)
		core = _environment_tint(core, local)
		draw_circle(local, radius * 1.6, outer)
		draw_circle(local, radius, core)

func _draw_rocket() -> void:
	var dir := _velocity
	if dir.length() == 0.0:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var body_length: float = 92.0 if special_attack else 74.0
	var body_width: float = 26.0 if special_attack else 20.0
	if exhaust_enabled:
		_draw_rocket_exhaust(dir, perp, body_length, body_width)
	_draw_rocket_body(dir, perp, body_length, body_width)

func _draw_rocket_exhaust(dir: Vector2, perp: Vector2, body_length: float, body_width: float) -> void:
	var tail := -dir * (body_length * 0.5 - body_width * 0.12)
	var flicker := 1.0 + 0.3 * sin(_exhaust_time * exhaust_flicker_speed + _flicker_seed)
	var outer_length: float = exhaust_length * 1.15 * flicker
	var outer_width: float = body_width * (1.7 if special_attack else 1.4)
	var outer_tip := tail - dir * outer_length
	var outer_left := tail + perp * outer_width
	var outer_right := tail - perp * outer_width
	var outer_color: Color = Color(1.0, 0.44, 0.12, 0.9) if special_attack else Color(1.0, 0.58, 0.16, 0.85)
	var outer_center := (outer_tip + outer_right + tail + outer_left) * 0.25
	var tinted_outer := _environment_tint(outer_color, outer_center)
	draw_polygon(
		PackedVector2Array([outer_tip, outer_right, tail, outer_left]),
		PackedColorArray([tinted_outer, tinted_outer, tinted_outer, tinted_outer])
	)
	var inner_length: float = outer_length * 0.62
	var inner_width: float = outer_width * 0.55
	var inner_tip := tail - dir * inner_length
	var inner_left := tail + perp * inner_width
	var inner_right := tail - perp * inner_width
	var inner_color: Color = Color(1.0, 0.78, 0.36, 0.92) if special_attack else Color(1.0, 0.88, 0.46, 0.92)
	var inner_center := (inner_tip + inner_right + tail + inner_left) * 0.25
	var tinted_inner := _environment_tint(inner_color, inner_center)
	draw_polygon(
		PackedVector2Array([inner_tip, inner_right, tail, inner_left]),
		PackedColorArray([tinted_inner, tinted_inner, tinted_inner, tinted_inner])
	)
	var core_length: float = inner_length * 0.55
	var core_width: float = inner_width * 0.45
	var core_tip := tail - dir * core_length
	var core_left := tail + perp * core_width
	var core_right := tail - perp * core_width
	var core_color := Color(1.0, 0.97, 0.78, 0.95)
	var core_center := (core_tip + core_right + tail + core_left) * 0.25
	var tinted_core := _environment_tint(core_color, core_center)
	draw_polygon(
		PackedVector2Array([core_tip, core_right, tail, core_left]),
		PackedColorArray([tinted_core, tinted_core, tinted_core, tinted_core])
	)
	var glow_radius: float = max(body_width * 0.85, inner_width * 0.9)
	var glow_color := Color(outer_color.r, outer_color.g, outer_color.b, outer_color.a * 0.5)
	var tinted_glow := _environment_tint(glow_color, tail)
	var inner_glow_color := Color(core_color.r, core_color.g, core_color.b, 0.7)
	var inner_glow_center := tail - dir * (outer_length * 0.4)
	var tinted_inner_glow := _environment_tint(inner_glow_color, inner_glow_center)
	draw_circle(tail, glow_radius, tinted_glow)
	draw_circle(inner_glow_center, glow_radius * 0.45, tinted_inner_glow)

func _draw_rocket_body(dir: Vector2, perp: Vector2, body_length: float, body_width: float) -> void:
	var half_length := body_length * 0.5
	var segment_count := 5 if special_attack else 4
	var segment_span: float = body_length / float(segment_count)
	var segment_half_width: float = body_width * 0.5
	for segment_index in range(segment_count):
		var start_offset := -half_length + segment_span * float(segment_index)
		var end_offset := start_offset + segment_span * 0.9
		var start_vec := dir * start_offset
		var end_vec := dir * end_offset
		var intensity: float = float(segment_index) / max(1.0, float(segment_count - 1))
		var segment_color: Color
		if special_attack:
			segment_color = Color(0.68 + 0.18 * intensity, 0.32 + 0.14 * intensity, 0.32 + 0.12 * intensity, 1.0)
		else:
			segment_color = Color(0.58 + 0.18 * intensity, 0.58 + 0.18 * intensity, 0.68 + 0.2 * intensity, 1.0)
		var body_points := PackedVector2Array([
			end_vec + perp * segment_half_width,
			end_vec - perp * segment_half_width,
			start_vec - perp * segment_half_width,
			start_vec + perp * segment_half_width
		])
		var body_center := (body_points[0] + body_points[1] + body_points[2] + body_points[3]) * 0.25
		var tinted_segment := _environment_tint(segment_color, body_center)
		draw_polygon(body_points, PackedColorArray([tinted_segment, tinted_segment, tinted_segment, tinted_segment]))
		var highlight_width: float = segment_half_width * 0.55
		var highlight_color := segment_color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.35)
		var highlight_points := PackedVector2Array([
			end_vec + perp * highlight_width,
			end_vec - perp * highlight_width * 0.2,
			start_vec - perp * highlight_width * 0.2,
			start_vec + perp * highlight_width
		])
		var highlight_center := (highlight_points[0] + highlight_points[1] + highlight_points[2] + highlight_points[3]) * 0.25
		var tinted_highlight := _environment_tint(highlight_color, highlight_center)
		draw_polygon(highlight_points, PackedColorArray([tinted_highlight, tinted_highlight, tinted_highlight, tinted_highlight]))
	var tip_front := dir * half_length
	var tip_back: Vector2 = dir * (half_length - max(body_width * 0.85, 14.0))
	var tip_color: Color = Color(1.0, 0.58, 0.32, 1.0) if special_attack else Color(1.0, 0.86, 0.45, 1.0)
	var tip_points := PackedVector2Array([
		tip_front,
		tip_back + perp * (body_width * 0.5),
		tip_back - perp * (body_width * 0.5)
	])
	var tip_center := (tip_points[0] + tip_points[1] + tip_points[2]) / 3.0
	var tinted_tip := _environment_tint(tip_color, tip_center)
	draw_polygon(tip_points, PackedColorArray([tinted_tip, tinted_tip, tinted_tip]))
	var tip_highlight := tip_color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.4)
	var inner_tip_points := PackedVector2Array([
		tip_front,
		tip_back + perp * (body_width * 0.28),
		tip_back - perp * (body_width * 0.28)
	])
	var tip_highlight_center := (inner_tip_points[0] + inner_tip_points[1] + inner_tip_points[2]) / 3.0
	var tinted_tip_highlight := _environment_tint(tip_highlight, tip_highlight_center)
	draw_polygon(inner_tip_points, PackedColorArray([tinted_tip_highlight, tinted_tip_highlight, tinted_tip_highlight]))
	var nose_center := tip_front - dir * (body_width * 0.1)
	var nose_color := Color(tip_color.r, tip_color.g, tip_color.b, 0.45)
	var tinted_nose := _environment_tint(nose_color, nose_center)
	draw_circle(nose_center, body_width * 0.45, tinted_nose)
	var fin_origin := dir * (-half_length * 0.82)
	var fin_length := body_width * (1.7 if special_attack else 1.35)
	var fin_root_offset := body_width * 0.28
	var fin_angles: Array = [0.75, -0.75, 2.35, -2.35]
	if special_attack:
		fin_angles = fin_angles + [0.0, PI]
	for fin_angle in fin_angles:
		var fin_dir := dir.rotated(fin_angle)
		var fin_tip := fin_origin + fin_dir * fin_length
		var fin_base_left := fin_origin + perp * fin_root_offset
		var fin_base_right := fin_origin - perp * fin_root_offset
		var fin_color: Color = Color(0.82, 0.34, 0.34, 0.85) if special_attack else Color(0.7, 0.52, 0.52, 0.85)
		var fin_points := PackedVector2Array([fin_base_left, fin_tip, fin_base_right])
		var fin_center := (fin_points[0] + fin_points[1] + fin_points[2]) / 3.0
		var tinted_fin := _environment_tint(fin_color, fin_center)
		draw_polygon(fin_points, PackedColorArray([tinted_fin, tinted_fin, tinted_fin]))
		var fin_highlight := fin_color.lerp(Color(1.0, 0.92, 0.92, 1.0), 0.4)
		var highlight_tip := fin_origin + fin_dir * (fin_length * 0.68)
		var highlight_points := PackedVector2Array([
			fin_origin + perp * (fin_root_offset * 0.5),
			highlight_tip,
			fin_origin - perp * (fin_root_offset * 0.5)
		])
		var fin_highlight_center := (highlight_points[0] + highlight_points[1] + highlight_points[2]) / 3.0
		var tinted_fin_highlight := _environment_tint(fin_highlight, fin_highlight_center)
		draw_polygon(highlight_points, PackedColorArray([tinted_fin_highlight, tinted_fin_highlight, tinted_fin_highlight]))

func _draw_grenade_body() -> void:
	var grenade_radius := 12.0
	var base_color := Color(0.28, 0.34, 0.2, 1.0)
	var shadow_color := Color(0.16, 0.2, 0.11, 1.0)
	var highlight_color := Color(0.65, 0.72, 0.48, 0.65)
	var groove_color := Color(0.18, 0.22, 0.12, 0.95)
	var outline_color := Color(0.12, 0.14, 0.08, 1.0)
	var center := Vector2.ZERO
	var base_tinted := _environment_tint(base_color, center)
	var shadow_offset := center + Vector2(0, grenade_radius * 0.12)
	var shadow_tinted := _environment_tint(shadow_color, shadow_offset)
	var highlight_offset := center - Vector2(grenade_radius * 0.35, grenade_radius * 0.35)
	var highlight_tinted := _environment_tint(highlight_color, highlight_offset)
	var outline_tinted := _environment_tint(outline_color, center)
	draw_circle(center, grenade_radius, base_tinted)
	draw_circle(shadow_offset, grenade_radius * 0.94, shadow_tinted)
	draw_circle(highlight_offset, grenade_radius * 0.42, highlight_tinted)
	draw_arc(center, grenade_radius, 0.0, TAU, 32, outline_tinted, 2.0)
	for groove_index in range(-1, 2):
		var groove_y := float(groove_index) * grenade_radius * 0.35
		var y_start := Vector2(-grenade_radius * 0.7, groove_y)
		var y_end := Vector2(grenade_radius * 0.7, groove_y)
		var groove_tinted := _environment_tint(groove_color, (y_start + y_end) * 0.5)
		draw_line(y_start, y_end, groove_tinted, 2.0)
	for groove_index in range(-1, 2):
		var groove_x := float(groove_index) * grenade_radius * 0.35
		var x_start := Vector2(groove_x, -grenade_radius * 0.7)
		var x_end := Vector2(groove_x, grenade_radius * 0.7)
		var groove_tinted_v := _environment_tint(groove_color, (x_start + x_end) * 0.5)
		draw_line(x_start, x_end, groove_tinted_v, 2.0)
	var strap_width := grenade_radius * 1.4
	var strap_height := grenade_radius * 0.35
	var strap_center := center - Vector2(0, grenade_radius * 0.15)
	var strap_half_w := strap_width * 0.5
	var strap_half_h := strap_height * 0.5
	var strap_points := PackedVector2Array([
		Vector2(-strap_half_w, -strap_half_h) + strap_center,
		Vector2(strap_half_w, -strap_half_h) + strap_center,
		Vector2(strap_half_w, strap_half_h) + strap_center,
		Vector2(-strap_half_w, strap_half_h) + strap_center
	])
	var strap_center_local := (strap_points[0] + strap_points[1] + strap_points[2] + strap_points[3]) * 0.25
	var strap_tinted := _environment_tint(groove_color, strap_center_local)
	draw_polygon(strap_points, PackedColorArray([strap_tinted, strap_tinted, strap_tinted, strap_tinted]))
	var pin_base := Vector2(0, -grenade_radius * 0.7)
	var pin_color := Color(0.78, 0.78, 0.8, 1.0)
	var pin_tinted := _environment_tint(pin_color, pin_base)
	draw_circle(pin_base, grenade_radius * 0.3, pin_tinted)
	var ring_radius := grenade_radius * 0.55
	var ring_points := 36
	var ring_color := Color(0.9, 0.9, 0.92, 0.9)
	var previous_point := Vector2.ZERO
	for i in range(ring_points + 1):
		var angle := TAU * float(i) / float(ring_points)
		var point := pin_base + Vector2(cos(angle), sin(angle)) * ring_radius
		if i > 0:
			var ring_mid := (previous_point + point) * 0.5
			var ring_tinted := _environment_tint(ring_color, ring_mid)
			draw_line(previous_point, point, ring_tinted, 2.0)
		previous_point = point
	var pin_handle := PackedVector2Array([
		pin_base + Vector2(-grenade_radius * 0.25, 0),
		pin_base + Vector2(grenade_radius * 0.35, -grenade_radius * 0.15),
		pin_base + Vector2(grenade_radius * 0.45, grenade_radius * 0.1)
	])
	var handle_center := (pin_handle[0] + pin_handle[1] + pin_handle[2]) / 3.0
	var handle_tinted := _environment_tint(pin_color, handle_center)
	draw_polygon(pin_handle, PackedColorArray([handle_tinted, handle_tinted, handle_tinted]))

func _resolve_audio_director() -> AudioDirector:
	if not get_tree():
		return null
	var root := get_tree().root
	var candidate := root.find_child("AudioDirector", true, false)
	if candidate and candidate is AudioDirector:
		return candidate
	return null

func _get_audio_director() -> AudioDirector:
	if _audio_director == null or not is_instance_valid(_audio_director):
		_audio_director = _resolve_audio_director()
	return _audio_director

func _start_flight_audio_if_needed() -> void:
	if not _should_play_flight_audio():
		return
	if _flight_audio_handle != -1:
		return
	var director := _get_audio_director()
	if director == null:
		return
	var handle := director.play_rocket_flight_sound()
	if handle != -1:
		_flight_audio_handle = handle

func _stop_flight_audio() -> void:
	if _flight_audio_handle == -1:
		return
	var director := _get_audio_director()
	if director:
		director.stop_rocket_flight_sound(_flight_audio_handle)
	_flight_audio_handle = -1

func _play_explosion_audio() -> void:
	if not _should_play_explosion_audio():
		return
	var director := _get_audio_director()
	if director == null:
		return
	director.play_rocket_explosion_sound()

func _should_play_flight_audio() -> bool:
	return render_style.to_lower() == "rocket"

func _should_play_explosion_audio() -> bool:
	var style := render_style.to_lower()
	return style == "rocket" or style == "grenade"
