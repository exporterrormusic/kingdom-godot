extends Node2D
class_name PlayerOverheadHud

const HEALTH_BAR_WIDTH := 132.0
const HEALTH_BAR_HEIGHT := 12.0
const BURST_BAR_HEIGHT := 9.0
const BAR_SPACING := 4.0
const TOP_OFFSET_Y := -78.0
const AMMO_OFFSET_Y := 28.0
const TEXT_SECOND_LINE_OFFSET := 14.0
const BORDER_THICKNESS := 2.0

@export var health_fill_color: Color = Color(0.32, 0.86, 0.48, 1.0)
@export var health_background_color: Color = Color(0.11, 0.14, 0.18, 0.92)
@export var health_border_color: Color = Color(0.26, 0.36, 0.51, 1.0)
@export var burst_fill_color: Color = Color(0.95, 0.82, 0.32, 1.0)
@export var burst_background_color: Color = Color(0.18, 0.14, 0.05, 0.92)
@export var burst_border_color: Color = Color(0.62, 0.5, 0.18, 1.0)
@export var ammo_text_color: Color = Color(0.95, 0.95, 1.0, 0.95)
@export var special_ammo_text_color: Color = Color(0.98, 0.9, 0.52, 1.0)
@export var special_ammo_label: String = "SPECIAL"

var _player: Node = null
var _current_health: int = 1
var _max_health: int = 1
var _current_burst: float = 0.0
var _max_burst: float = 1.0
var _ammo_current: int = 0
var _ammo_max: int = 0
var _special_ammo_current: int = 0
var _special_ammo_max: int = 0

func _ready() -> void:
	z_index = 25
	_process_initial_owner()
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var left_x := -HEALTH_BAR_WIDTH * 0.5
	var health_rect := Rect2(Vector2(left_x, TOP_OFFSET_Y), Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT))
	_draw_bar(health_rect, _current_health, _max_health, health_background_color, health_fill_color, health_border_color)

	var burst_top := TOP_OFFSET_Y + HEALTH_BAR_HEIGHT + BAR_SPACING
	var burst_rect := Rect2(Vector2(left_x, burst_top), Vector2(HEALTH_BAR_WIDTH, BURST_BAR_HEIGHT))
	_draw_bar(burst_rect, _current_burst, _max_burst, burst_background_color, burst_fill_color, burst_border_color)

	_draw_ammo_text(AMMO_OFFSET_Y)

func _draw_bar(rect: Rect2, current_value: float, max_value: float, background_color: Color, fill_color: Color, border_color: Color) -> void:
	var clamped_max: float = maxf(0.0001, max_value)
	draw_rect(rect, background_color, true)
	var ratio: float = clampf(current_value / clamped_max, 0.0, 1.0)
	if ratio > 0.0:
		var fill_rect := Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y))
		draw_rect(fill_rect, fill_color, true)
	draw_rect(rect, border_color, false, BORDER_THICKNESS)

func _draw_ammo_text(base_y: float) -> void:
	var font: Font = ThemeDB.get_fallback_font()
	if font == null:
		return
	var font_size := 14
	var primary_text := str(_ammo_current)
	if _ammo_max > 0:
		primary_text = "%d / %d" % [_ammo_current, _ammo_max]
	var primary_size: Vector2 = font.get_string_size(primary_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var primary_pos := Vector2(-primary_size.x * 0.5, base_y)
	draw_string(font, primary_pos, primary_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, ammo_text_color)
	if _special_ammo_max <= 0 and _special_ammo_current <= 0:
		return
	var secondary_text := "%s: %d" % [special_ammo_label, _special_ammo_current]
	if _special_ammo_max > 0:
		secondary_text = "%s: %d / %d" % [special_ammo_label, _special_ammo_current, _special_ammo_max]
	var secondary_size: Vector2 = font.get_string_size(secondary_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size - 1)
	var secondary_pos := Vector2(-secondary_size.x * 0.5, base_y + TEXT_SECOND_LINE_OFFSET)
	draw_string(font, secondary_pos, secondary_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size - 1, special_ammo_text_color)

func _process_initial_owner() -> void:
	_player = get_parent()
	if _player == null:
		return
	if _player.has_method("get_current_health"):
		_current_health = int(_player.get_current_health())
	if _player.has_method("get_max_health"):
		_max_health = int(max(1, _player.get_max_health()))
	if _player.has_method("get_burst_charge"):
		_current_burst = float(_player.get_burst_charge())
	if _player.has_method("get_burst_charge_max"):
		_max_burst = max(0.001, float(_player.get_burst_charge_max()))
	if _player.has_method("emit_ammo_state"):
		_player.emit_ammo_state()
	_connect_player_signals()
	queue_redraw()

func _connect_player_signals() -> void:
	if not is_instance_valid(_player):
		return
	if _player.has_signal("health_changed"):
		_player.health_changed.connect(_on_player_health_changed)
	if _player.has_signal("burst_changed"):
		_player.burst_changed.connect(_on_player_burst_changed)
	if _player.has_signal("ammo_changed"):
		_player.ammo_changed.connect(_on_player_ammo_changed)

func _on_player_health_changed(current: int, maximum: int, _delta: int) -> void:
	_current_health = current
	_max_health = max(1, maximum)
	queue_redraw()

func _on_player_burst_changed(current: float, maximum: float) -> void:
	_current_burst = current
	_max_burst = max(0.001, maximum)
	queue_redraw()

func _on_player_ammo_changed(current: int, maximum: int, special_current: int, special_max: int) -> void:
	_ammo_current = current
	_ammo_max = maximum
	_special_ammo_current = special_current
	_special_ammo_max = special_max
	queue_redraw()
