extends Area2D
class_name GroundFire

@export var radius: float = 120.0
@export var duration: float = 3.0
@export var damage_per_tick: int = 6
@export var tick_interval: float = 0.5
@export var color: Color = Color(1.0, 0.45, 0.1, 0.6)
@export var glow_color: Color = Color(1.0, 0.42, 0.1, 0.4)
@export var ember_color: Color = Color(1.0, 0.65, 0.25, 0.8)
@export var smoke_color: Color = Color(0.4, 0.4, 0.4, 0.35)
@export var ember_count: int = 18

var _elapsed := 0.0
var _tick_elapsed := 0.0
var _rng := RandomNumberGenerator.new()
var _embers: Array = []

func _ready() -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	_rng.randomize()
	_embers = []
	for i in range(max(ember_count, 0)):
		_embers.append({
			"angle": _rng.randf_range(0.0, TAU),
			"offset": _rng.randf_range(0.2, 0.9),
			"speed": _rng.randf_range(1.5, 3.5),
			"size": _rng.randf_range(radius * 0.05, radius * 0.12)
		})
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	_tick_elapsed += delta
	if _elapsed >= duration:
		queue_free()
		return
	if _tick_elapsed >= tick_interval:
		_tick_elapsed = 0.0
		_apply_damage()
	for i in range(_embers.size()):
		var ember: Dictionary = _embers[i]
		ember["angle"] = ember.get("angle", 0.0) + delta * ember.get("speed", 2.0)
		_embers[i] = ember
	queue_redraw()

func _apply_damage() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if not (enemy is Node2D) or not enemy.has_method("apply_damage"):
			continue
		var distance := (enemy as Node2D).global_position.distance_to(global_position)
		if distance <= radius:
			enemy.apply_damage(damage_per_tick)

func _draw() -> void:
	var progress := clampf(_elapsed / max(duration, 0.01), 0.0, 1.0)
	var fade := 1.0 - progress
	var base_glow := Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * fade * 0.9)
	draw_circle(Vector2.ZERO, radius * 1.15, base_glow)
	var core := Color(color.r, color.g, color.b, color.a * fade)
	draw_circle(Vector2.ZERO, radius, core)
	var ember_alpha := ember_color.a * fade
	for ember_variant in _embers:
		if not (ember_variant is Dictionary):
			continue
		var ember := ember_variant as Dictionary
		var angle: float = float(ember.get("angle", 0.0))
		var offset: float = float(ember.get("offset", 0.5))
		var dist := radius * offset * (0.6 + 0.4 * sin(_elapsed * 3.0 + angle))
		var pos := Vector2(cos(angle), sin(angle)) * dist
		var ember_size := float(ember.get("size", radius * 0.08))
		var flicker := 0.6 + 0.4 * sin(_elapsed * 10.0 + angle * 2.0)
		var ember_col := Color(ember_color.r, ember_color.g, ember_color.b, ember_alpha * flicker)
		draw_circle(pos, ember_size, ember_col)
	var smoke_alpha := smoke_color.a * fade * 0.6
	if smoke_alpha > 0.02:
		draw_circle(Vector2.ZERO, radius * 1.4, Color(smoke_color.r, smoke_color.g, smoke_color.b, smoke_alpha))
	var indicator_color := Color(1.0, 0.2, 0.05, 0.4 * fade)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, indicator_color, 3.0)
