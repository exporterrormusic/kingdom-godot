extends Node2D
class_name EnemyHealthBar

const BAR_WIDTH := 104.0
const BAR_HEIGHT := 8.0
const TOP_OFFSET_Y := -64.0
const BORDER_THICKNESS := 2.0

@export var health_fill_color: Color = Color(0.92, 0.28, 0.32, 1.0)
@export var health_background_color: Color = Color(0.12, 0.08, 0.09, 0.92)
@export var health_border_color: Color = Color(0.55, 0.2, 0.24, 1.0)

var _enemy: Node = null
var _current_health: int = 1
var _max_health: int = 1

func _ready() -> void:
	z_index = 20
	_enemy = get_parent()
	if _enemy == null:
		return
	if _enemy.has_method("emit_health_state"):
		_enemy.emit_health_state()
	_connect_enemy_signals()

func _draw() -> void:
	if _max_health <= 0:
		return
	if _current_health >= _max_health:
		return
	var left_x := -BAR_WIDTH * 0.5
	var rect := Rect2(Vector2(left_x, TOP_OFFSET_Y), Vector2(BAR_WIDTH, BAR_HEIGHT))
	draw_rect(rect, health_background_color, true)
	var ratio: float = clampf(float(_current_health) / float(_max_health), 0.0, 1.0)
	if ratio > 0.0:
		var fill_rect := Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y))
		draw_rect(fill_rect, health_fill_color, true)
	draw_rect(rect, health_border_color, false, BORDER_THICKNESS)

func _connect_enemy_signals() -> void:
	if not is_instance_valid(_enemy):
		return
	if _enemy.has_signal("health_changed"):
		_enemy.health_changed.connect(_on_enemy_health_changed)

func _on_enemy_health_changed(current: int, maximum: int, _delta: int) -> void:
	_current_health = current
	_max_health = max(1, maximum)
	queue_redraw()
