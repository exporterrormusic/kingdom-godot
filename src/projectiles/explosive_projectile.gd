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

const ExplosionEffectScript := preload("res://src/effects/explosion_effect.gd")
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

func _ready() -> void:
	_connect_collision_signals()
	_configure_collision_shape()
	_configure_motion()
	_rng.randomize()
	_flicker_seed = _rng.randf_range(0.0, TAU)
	if trail_enabled:
		_trail_points.append(global_position)
		_trail_ages.append(0.0)
	set_process(true)
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
	queue_redraw()

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
	var effect: ExplosionEffect = ExplosionEffectScript.new()
	effect.radius = explosion_radius
	effect.base_color = explosion_color
	effect.duration = 0.55 if special_attack else 0.4
	effect.ring_thickness = max(6.0, explosion_radius * 0.12)
	if get_parent():
		effect.global_position = global_position
		get_parent().add_child(effect)

func _spawn_ground_fire_if_needed() -> void:
	if not ground_fire_enabled and ground_fire_damage <= 0:
		return
	var fire := GroundFireScript.new()
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
			draw_circle(Vector2.ZERO, 10.0, explosion_color)

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
		draw_circle(local, radius * 1.6, outer)
		draw_circle(local, radius, core)

func _draw_rocket() -> void:
	var dir := _velocity
	if dir.length() == 0.0:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var body_length: float = 58.0
	var body_width: float = 18.0
	if special_attack:
		body_length = 72.0
		body_width = 24.0
	if exhaust_enabled:
		_draw_rocket_exhaust(dir, perp, body_length, body_width)
	_draw_rocket_body(dir, perp, body_length, body_width)

func _draw_rocket_exhaust(dir: Vector2, perp: Vector2, body_length: float, body_width: float) -> void:
	var tail := -dir * (body_length * 0.5)
	var flicker := 1.0 + 0.25 * sin(_exhaust_time * exhaust_flicker_speed + _flicker_seed)
	var flame_scale := 1.0
	var width_scale := 1.0
	if special_attack:
		flame_scale = 1.35
		width_scale = 1.2
	var flame_length: float = exhaust_length * flame_scale * flicker
	var flame_width: float = exhaust_width * width_scale
	var base_left := tail + perp * (flame_width * 0.6)
	var base_right := tail - perp * (flame_width * 0.6)
	var mid_base := tail - dir * (flame_length * 0.25)
	var tip := tail - dir * flame_length
	var outer_color := Color(exhaust_glow_color.r, exhaust_glow_color.g, exhaust_glow_color.b, exhaust_glow_color.a)
	var mid_alpha := 0.6
	if special_attack:
		mid_alpha = 0.75
	var mid_color := Color(1.0, 0.78, 0.32, mid_alpha)
	var core_color := Color(1.0, 0.95, 0.85, 0.9)
	draw_polygon(
		PackedVector2Array([tip, base_right, mid_base, base_left]),
		PackedColorArray([mid_color, outer_color, outer_color, mid_color])
	)
	draw_polygon(
		PackedVector2Array([tip, mid_base, base_left * 0.7 + tip * 0.3, base_right * 0.7 + tip * 0.3]),
		PackedColorArray([core_color, core_color, mid_color, mid_color])
	)
	var glow_radius: float = max(flame_width * 0.8, body_width * 0.8)
	var glow_color := Color(outer_color.r, outer_color.g, outer_color.b, outer_color.a * 0.6)
	draw_circle(tail, glow_radius, glow_color)
	draw_circle(tail - dir * (flame_length * 0.55), glow_radius * 0.4, core_color)

func _draw_rocket_body(dir: Vector2, perp: Vector2, body_length: float, body_width: float) -> void:
	var half_length := body_length * 0.5
	var tip := dir * half_length
	var tail := -dir * half_length
	var nose_length := body_length * 0.28
	var nose_base := tip - dir * nose_length
	var tail_left := tail + perp * (body_width * 0.55)
	var tail_right := tail - perp * (body_width * 0.55)
	var nose_left := nose_base + perp * (body_width * 0.38)
	var nose_right := nose_base - perp * (body_width * 0.38)
	var body_base_color := Color(0.88, 0.93, 1.0, 0.95)
	var body_shadow_color := Color(0.4, 0.45, 0.6, 0.9)
	if special_attack:
		body_base_color = Color(1.0, 0.45, 0.35, 0.95)
		body_shadow_color = Color(0.65, 0.12, 0.08, 0.9)
	draw_polygon(
		PackedVector2Array([tail_left, nose_left, nose_right, tail_right]),
		PackedColorArray([body_shadow_color, body_base_color, body_base_color, body_shadow_color])
	)
	var nose_color := Color(0.96, 0.96, 0.98, 0.95)
	if special_attack:
		nose_color = Color(1.0, 0.68, 0.48, 0.95)
	draw_polygon(
		PackedVector2Array([nose_left, tip, nose_right]),
		PackedColorArray([nose_color, Color(1.0, 0.95, 0.9, 0.95), nose_color])
	)
	var stripe_color := Color(0.65, 0.75, 0.95, 0.85)
	if special_attack:
		stripe_color = Color(0.95, 0.25, 0.2, 0.85)
	for stripe_index in range(3):
		var stripe_t := (float(stripe_index) + 1.0) / 4.0
		var stripe_center := tail.lerp(nose_base, stripe_t)
		var stripe_half := perp * (body_width * 0.42)
		var stripe_offset := dir * (body_length * 0.02)
		var stripe_points := PackedVector2Array([
			stripe_center - stripe_offset + stripe_half,
			stripe_center + stripe_offset + stripe_half,
			stripe_center + stripe_offset - stripe_half,
			stripe_center - stripe_offset - stripe_half
		])
		draw_polygon(stripe_points, PackedColorArray([stripe_color, stripe_color, stripe_color, stripe_color]))
	var cockpit_center := tail.lerp(nose_base, 0.4) + perp * (body_width * 0.18)
	var cockpit_color := Color(0.45, 0.65, 0.95, 0.9)
	if special_attack:
		cockpit_color = Color(1.0, 0.8, 0.65, 0.9)
	var cockpit_glow := Color(cockpit_color.r, cockpit_color.g, cockpit_color.b, cockpit_color.a * 0.5)
	draw_circle(cockpit_center, body_width * 0.18, cockpit_glow)
	draw_circle(cockpit_center, body_width * 0.12, cockpit_color)
	var highlight_color := Color(1.0, 1.0, 1.0, 0.25)
	draw_line(tail + perp * (body_width * 0.15), nose_base + perp * (body_width * 0.05), highlight_color, 2.0, true)
	draw_line(tail - perp * (body_width * 0.15), nose_base - perp * (body_width * 0.05), Color(0.0, 0.0, 0.0, 0.2), 2.0, true)
	var fin_length := body_length * 0.18
	var fin_offset := body_width * 0.75
	var fin_color := Color(0.75, 0.82, 0.95, 0.85)
	if special_attack:
		fin_color = Color(1.0, 0.42, 0.28, 0.85)
	var top_fin := PackedVector2Array([
		tail + perp * fin_offset,
		tail + perp * (fin_offset + body_width * 0.25),
		tail - dir * fin_length + perp * fin_offset * 0.8
	])
	var bottom_fin := PackedVector2Array([
		tail - perp * fin_offset,
		tail - perp * (fin_offset + body_width * 0.25),
		tail - dir * fin_length - perp * fin_offset * 0.8
	])
	draw_polygon(top_fin, PackedColorArray([fin_color, fin_color, fin_color]))
	draw_polygon(bottom_fin, PackedColorArray([fin_color, fin_color, fin_color]))

func _draw_grenade_body() -> void:
	var grenade_radius := 12.0
	var base_color := Color(0.28, 0.34, 0.2, 1.0)
	var shadow_color := Color(0.16, 0.2, 0.11, 1.0)
	var highlight_color := Color(0.65, 0.72, 0.48, 0.65)
	var groove_color := Color(0.18, 0.22, 0.12, 0.95)
	var outline_color := Color(0.12, 0.14, 0.08, 1.0)
	var center := Vector2.ZERO
	draw_circle(center, grenade_radius, base_color)
	draw_circle(center + Vector2(0, grenade_radius * 0.12), grenade_radius * 0.94, shadow_color)
	draw_circle(center - Vector2(grenade_radius * 0.35, grenade_radius * 0.35), grenade_radius * 0.42, highlight_color)
	draw_arc(center, grenade_radius, 0.0, TAU, 32, outline_color, 2.0)
	for groove_index in range(-1, 2):
		var groove_y := float(groove_index) * grenade_radius * 0.35
		draw_line(Vector2(-grenade_radius * 0.7, groove_y), Vector2(grenade_radius * 0.7, groove_y), groove_color, 2.0)
	for groove_index in range(-1, 2):
		var groove_x := float(groove_index) * grenade_radius * 0.35
		draw_line(Vector2(groove_x, -grenade_radius * 0.7), Vector2(groove_x, grenade_radius * 0.7), groove_color, 2.0)
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
	draw_polygon(strap_points, PackedColorArray([groove_color, groove_color, groove_color, groove_color]))
	var pin_base := Vector2(0, -grenade_radius * 0.7)
	var pin_color := Color(0.78, 0.78, 0.8, 1.0)
	draw_circle(pin_base, grenade_radius * 0.3, pin_color)
	var ring_radius := grenade_radius * 0.55
	var ring_points := 36
	var ring_color := Color(0.9, 0.9, 0.92, 0.9)
	var previous_point := Vector2.ZERO
	for i in range(ring_points + 1):
		var angle := TAU * float(i) / float(ring_points)
		var point := pin_base + Vector2(cos(angle), sin(angle)) * ring_radius
		if i > 0:
			draw_line(previous_point, point, ring_color, 2.0)
		previous_point = point
	var pin_handle := PackedVector2Array([
		pin_base + Vector2(-grenade_radius * 0.25, 0),
		pin_base + Vector2(grenade_radius * 0.35, -grenade_radius * 0.15),
		pin_base + Vector2(grenade_radius * 0.45, grenade_radius * 0.1)
	])
	draw_polygon(pin_handle, PackedColorArray([pin_color, pin_color, pin_color]))
