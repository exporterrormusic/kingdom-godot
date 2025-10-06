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
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if owner_reference and is_instance_valid(owner_reference):
		global_position = owner_reference.global_position
		if owner_reference.has_method("get_gun_tip_position"):
			var tip: Variant = owner_reference.call("get_gun_tip_position")
			if tip is Vector2:
				global_position = tip
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
			if not _damaged_enemies.has(enemy_node):
				enemy_node.apply_damage(damage)
				_damaged_enemies[enemy_node] = true
				if owner_reference and is_instance_valid(owner_reference) and owner_reference.has_method("register_burst_hit"):
					owner_reference.register_burst_hit(enemy_node)

func _draw() -> void:
	var progress := clampf(_elapsed / max(duration, 0.01), 0.0, 1.0)
	var fade_color := color
	fade_color.a = color.a * (1.0 - progress)
	var half_width := width * 0.5
	var points := PackedVector2Array([
		Vector2.ZERO,
		direction.normalized() * beam_range
	])
	draw_line(points[0], points[1], fade_color, width)
	var cap_radius: float = max(half_width, 4.0)
	draw_circle(points[0], cap_radius, fade_color)
	draw_circle(points[1], cap_radius, fade_color)
