extends Area2D
class_name SniperTrailSegment

@export var radius: float = 56.0
@export var duration: float = 1.4
@export var damage_per_tick: int = 12
@export var tick_interval: float = 0.35
@export var core_color: Color = Color(0.82, 0.93, 1.0, 0.78)
@export var glow_color: Color = Color(0.32, 0.66, 1.0, 0.45)
@export var ring_color: Color = Color(0.5, 0.8, 1.0, 0.55)

var _age: float = 0.0
var _tick_time: float = 0.0
var _spark_data: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_rng.randomize()
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	_generate_sparks()
	set_process(true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	queue_redraw()

func _generate_sparks() -> void:
	_spark_data.clear()
	var spark_count := 14
	for _i in range(spark_count):
		_spark_data.append({
			"angle": _rng.randf_range(0.0, TAU),
			"radius": _rng.randf_range(0.25, 0.85),
			"speed": _rng.randf_range(0.6, 1.6),
			"size": _rng.randf_range(radius * 0.05, radius * 0.11)
		})

func _process(delta: float) -> void:
	_age += delta
	_tick_time += delta
	if _age >= duration:
		queue_free()
		return
	if _tick_time >= tick_interval:
		_tick_time = 0.0
		_apply_damage()
	queue_redraw()

func _apply_damage() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var radius_sq := radius * radius
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D) or not enemy.has_method("apply_damage"):
			continue
		var enemy_node := enemy as Node2D
		var dist_sq := enemy_node.global_position.distance_squared_to(global_position)
		if dist_sq <= radius_sq:
			enemy_node.apply_damage(damage_per_tick)

func _draw() -> void:
	var progress := clampf(_age / max(duration, 0.001), 0.0, 1.0)
	var fade := 1.0 - progress
	var glow := Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * fade)
	var core := Color(core_color.r, core_color.g, core_color.b, core_color.a * fade)
	var ring := Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * fade)
	var center_ring := Color(0.92, 0.98, 1.0, 0.65 * fade)
	var outer_radius := radius * (1.1 + 0.05 * sin(_age * 6.0))
	draw_circle(Vector2.ZERO, outer_radius, glow)
	draw_circle(Vector2.ZERO, radius * 0.68, core)
	draw_arc(Vector2.ZERO, radius * 0.94, 0.0, TAU, 24, ring, radius * 0.14)
	draw_circle(Vector2.ZERO, radius * 0.32, center_ring)
	var perp_scale := radius * 0.85
	for spark_variant in _spark_data:
		if not (spark_variant is Dictionary):
			continue
		var spark := spark_variant as Dictionary
		var angle := float(spark.get("angle", 0.0)) + _age * float(spark.get("speed", 1.0))
		var radial := float(spark.get("radius", 0.5))
		var dist := perp_scale * radial * (0.8 + 0.2 * sin(_age * 4.0 + angle))
		var pos := Vector2(cos(angle), sin(angle)) * dist
		var base_size := float(spark.get("size", radius * 0.08))
		var size := base_size * (0.6 + 0.4 * sin(_age * 5.0 + angle * 1.7))
		var spark_color := Color(0.85, 0.95, 1.0, 0.5 * fade)
		draw_circle(pos, max(size, 1.0), spark_color)
