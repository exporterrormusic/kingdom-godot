@tool
extends Node2D
class_name BeamAttack

@export var beam_range: float = 500.0
@export var width: float = 24.0
@export var damage: int = 80
@export var duration: float = 0.35
@export var color: Color = Color(0.4, 1.0, 0.8, 0.8)
@export var owner_reference: Node2D
@export var direction: Vector2 = Vector2.RIGHT

var _elapsed := 0.0
var _damaged_enemies: Dictionary = {}

func _ready() -> void:
	direction = direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	if Engine.is_editor_hint():
		_setup_editor_preview()
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_elapsed += delta
		if duration <= 0.0:
			duration = 0.35
		if _elapsed >= duration:
			_elapsed = 0.0
		queue_redraw()
		return
	_elapsed += delta
	if owner_reference and is_instance_valid(owner_reference):
		global_position = owner_reference.global_position
		if owner_reference.has_method("get_gun_tip_position"):
			var tip: Variant = owner_reference.call("get_gun_tip_position")
			if tip is Vector2:
				global_position = tip
		if owner_reference.has_method("_get_aim_direction"):
			var aim_variant: Variant = owner_reference.call("_get_aim_direction")
			if aim_variant is Vector2:
				var aim_vector: Vector2 = aim_variant
				if aim_vector.length() > 0.0:
					direction = aim_vector.normalized()
	if _elapsed >= duration:
		queue_free()
		return
	_apply_damage()
	queue_redraw()

func _apply_damage() -> void:
	var start: Vector2 = global_position
	var normalized_direction: Vector2 = direction.normalized()
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D) or not enemy.has_method("apply_damage"):
			continue
		var enemy_node := enemy as Node2D
		var to_enemy := enemy_node.global_position - start
		var projection := normalized_direction.dot(to_enemy)
		if projection < 0.0 or projection > beam_range:
			continue
		var closest := start + normalized_direction * projection
		var distance := enemy_node.global_position.distance_to(closest)
		if distance <= width * 0.5 + 12.0:
			var enemy_id := enemy_node.get_instance_id()
			if not _damaged_enemies.has(enemy_id):
				enemy_node.apply_damage(damage)
				_damaged_enemies[enemy_id] = true
				if owner_reference and is_instance_valid(owner_reference) and owner_reference.has_method("register_burst_hit"):
					owner_reference.register_burst_hit(enemy_node)

func _draw() -> void:
	var direction_vector := direction
	if direction_vector.length_squared() == 0.0:
		direction_vector = Vector2.RIGHT
	else:
		direction_vector = direction_vector.normalized()
	var start: Vector2 = Vector2.ZERO
	var end: Vector2 = direction_vector * beam_range
	var progress: float = clampf(_elapsed / max(duration, 0.001), 0.0, 1.0)
	var fade: float = pow(1.0 - progress, 1.4)
	var pulse: float = 0.9 + 0.1 * sin(_elapsed * 18.0)
	var base_width: float = max(width, 2.0) * pulse
	var glow_color: Color = Color(color.r, color.g, color.b, color.a * 0.22 * fade)
	var sheath_color: Color = Color(color.r, color.g, color.b, color.a * 0.65 * fade)
	var core_color: Color = Color(1.0, 0.98, 0.92, clampf(color.a * 0.92 * fade, 0.0, 1.0))
	for i in range(3):
		var layer_width: float = base_width * (2.2 - float(i) * 0.45)
		var layer_alpha: float = glow_color.a * (0.75 - float(i) * 0.18) * (0.85 + 0.15 * sin(_elapsed * (9.0 + float(i) * 0.8)))
		var layer_color: Color = Color(glow_color.r, glow_color.g, glow_color.b, clampf(layer_alpha, 0.02, 0.38))
		draw_line(start, end, layer_color, layer_width, true)
	draw_line(start, end, sheath_color, base_width * 1.25, true)
	draw_line(start, end, core_color, max(2.0, base_width * 0.55), true)
	var ripple_sections: int = 5
	for i in range(ripple_sections):
		var denominator: int = max(ripple_sections - 1, 1)
		var t: float = float(i) / float(denominator)
		var node_pos: Vector2 = start.lerp(end, t)
		var ripple_radius: float = base_width * (0.55 + 0.25 * sin(_elapsed * 8.0 + t * TAU))
		var ripple_alpha: float = 0.32 * fade * (1.0 - t * 0.35)
		var ripple_color: Color = Color(color.r, color.g, color.b, clampf(ripple_alpha, 0.05, 0.35))
		draw_circle(node_pos, ripple_radius, ripple_color)
		draw_circle(node_pos, ripple_radius * 0.42, Color(core_color.r, core_color.g, core_color.b, core_color.a * 0.65))
	var origin_radius: float = max(base_width * 0.75, 12.0)
	var tip_radius: float = max(base_width * 0.9, 16.0)
	var flare_color: Color = Color(color.r, color.g, color.b, sheath_color.a * 0.9)
	draw_circle(start, origin_radius, flare_color)
	draw_circle(end, tip_radius, flare_color)
	draw_circle(end, tip_radius * 0.45, core_color)
	draw_circle(start, origin_radius * 0.4, core_color)
	var cross_color: Color = Color(core_color.r, core_color.g, core_color.b, core_color.a * 0.75)
	var cross_length: float = tip_radius * 1.6
	for i in range(2):
		var angle: float = (PI * 0.25) + PI * 0.5 * float(i)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		draw_line(end - dir * cross_length * 0.2, end + dir * cross_length, Color(flare_color.r, flare_color.g, flare_color.b, flare_color.a * 0.65), max(2.0, tip_radius * 0.18), true)
		draw_line(end - dir * cross_length * 0.08, end + dir * cross_length * 0.6, cross_color, max(1.2, tip_radius * 0.1), true)


func _setup_editor_preview() -> void:
	if direction.length() == 0.0:
		direction = Vector2.RIGHT
	_elapsed = 0.0
	_damaged_enemies.clear()
