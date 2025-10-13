extends Node2D
class_name PlayerOverheadHud

const HEALTH_BAR_WIDTH := 112.0
const HEALTH_BAR_HEIGHT := 12.0
const BURST_BAR_HEIGHT := 9.0
const BAR_SPACING := 4.0
const TOP_OFFSET_Y := -78.0
const AMMO_BAR_WIDTH := 112.0
const AMMO_BAR_HEIGHT := 9.0
const SPECIAL_BAR_HEIGHT := 9.0
const AMMO_FONT_SIZE := 12
const SPECIAL_BAR_SPACING := 6.0
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
@export var special_ammo_fill_color: Color = Color(0.95, 0.72, 0.28, 0.95)
@export var special_ammo_low_fill_color: Color = Color(1.0, 0.48, 0.26, 0.95)
@export var special_ammo_background_color: Color = Color(0.16, 0.1, 0.05, 0.9)
@export var special_ammo_border_color: Color = Color(0.62, 0.36, 0.12, 1.0)
@export var special_bar_offset_y: float = 0.0
@export var ammo_fill_color: Color = Color(0.58, 0.76, 1.0, 0.95)
@export var ammo_low_fill_color: Color = Color(1.0, 0.48, 0.42, 0.95)
@export var ammo_background_color: Color = Color(0.11, 0.14, 0.18, 0.88)
@export var ammo_border_color: Color = Color(0.28, 0.36, 0.54, 1.0)
@export var ammo_bar_offset_y: float = 80.0
@export_range(0.0, 1.0, 0.05) var ammo_low_threshold: float = 0.25

var _player: Node = null
var _current_health: int = 1
var _max_health: int = 1
var _current_burst: float = 0.0
var _max_burst: float = 1.0
var _ammo_current: int = 0
var _ammo_max: int = 0
var _special_ammo_current: int = 0
var _special_ammo_max: int = 0
var _show_ammo_bar: bool = true

func _ready() -> void:
	top_level = true
	z_as_relative = false
	light_mask = 0
	z_index = 220
	material = _build_unshaded_material()
	_process_initial_owner()
	set_process(true)

func _process(_delta: float) -> void:
	var player_node2d := _player as Node2D
	if player_node2d == null or not is_instance_valid(player_node2d):
		visible = false
		return
	global_position = player_node2d.global_position.round()
	visible = true
	queue_redraw()

func _build_unshaded_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	return mat

func _draw() -> void:
	var left_x := -HEALTH_BAR_WIDTH * 0.5
	var health_rect := Rect2(Vector2(left_x, TOP_OFFSET_Y), Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT))
	_draw_bar(health_rect, _current_health, _max_health, health_background_color, health_fill_color, health_border_color)

	var burst_top := TOP_OFFSET_Y + HEALTH_BAR_HEIGHT + BAR_SPACING
	var burst_rect := Rect2(Vector2(left_x, burst_top), Vector2(HEALTH_BAR_WIDTH, BURST_BAR_HEIGHT))
	_draw_bar(burst_rect, _current_burst, _max_burst, burst_background_color, burst_fill_color, burst_border_color)

	_draw_ammo_bar()

func _draw_bar(rect: Rect2, current_value: float, max_value: float, background_color: Color, fill_color: Color, border_color: Color) -> void:
	var clamped_max: float = maxf(0.0001, max_value)
	draw_rect(rect, background_color, true)
	var ratio: float = clampf(current_value / clamped_max, 0.0, 1.0)
	if ratio > 0.0:
		var fill_rect := Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y))
		draw_rect(fill_rect, fill_color, true)
	draw_rect(rect, border_color, false, BORDER_THICKNESS)

func _draw_ammo_bar() -> void:
	var rect_position := Vector2(-AMMO_BAR_WIDTH * 0.5, ammo_bar_offset_y)
	var bar_rect := Rect2(rect_position, Vector2(AMMO_BAR_WIDTH, AMMO_BAR_HEIGHT))
	var max_value := float(_ammo_max)
	var current_value := float(_ammo_current)
	var infinite_ammo := false
	if max_value <= 0.0:
		infinite_ammo = true
		max_value = 1.0
		current_value = 1.0
	var ratio := 1.0 if infinite_ammo else clampf(current_value / maxf(0.0001, max_value), 0.0, 1.0)
	var fill_color := ammo_fill_color
	if not infinite_ammo and ratio <= ammo_low_threshold:
		fill_color = ammo_low_fill_color
	var font: Font = ThemeDB.get_fallback_font()
	var rendered_primary := false
	if _show_ammo_bar:
		_draw_bar(bar_rect, current_value, max_value, ammo_background_color, fill_color, ammo_border_color)
		rendered_primary = true
		if font:
			var display_text := "∞" if infinite_ammo else "%d / %d" % [_ammo_current, max(1, _ammo_max)]
			var font_size := AMMO_FONT_SIZE
			var text_size := font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
			var baseline := bar_rect.position.y + (bar_rect.size.y + float(font_size)) * 0.5 - 1.0
			var text_pos := Vector2(bar_rect.position.x + (bar_rect.size.x - text_size.x) * 0.5, baseline)
			draw_string(font, text_pos, display_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, ammo_text_color)

	_draw_special_ammo_bar(font, bar_rect, rendered_primary)

func _draw_special_ammo_bar(font: Font, ammo_rect: Rect2, primary_rendered: bool) -> void:
	var has_special := (_special_ammo_max > 0) or (_special_ammo_current > 0)
	if not has_special:
		return
	var special_top := ammo_rect.position.y + (ammo_rect.size.y + SPECIAL_BAR_SPACING + special_bar_offset_y if primary_rendered else 0.0)
	var special_rect := Rect2(Vector2(-AMMO_BAR_WIDTH * 0.5, special_top), Vector2(AMMO_BAR_WIDTH, SPECIAL_BAR_HEIGHT))
	var max_value: float = float(_special_ammo_max)
	var current_value: float = float(_special_ammo_current)
	var treat_infinite := false
	if max_value <= 0.0:
		max_value = max(1.0, current_value)
		if max_value <= 0.0:
			max_value = 1.0
		treat_infinite = true
	var ratio: float = clampf(current_value / maxf(0.0001, max_value), 0.0, 1.0)
	var fill_color: Color = special_ammo_fill_color
	if not treat_infinite and ratio <= ammo_low_threshold:
		fill_color = special_ammo_low_fill_color
	_draw_bar(special_rect, current_value, max_value, special_ammo_background_color, fill_color, special_ammo_border_color)
	if font == null:
		return
	var font_size: int = max(10, AMMO_FONT_SIZE - 1)
	var label_text: String = "%s %d" % [special_ammo_label, _special_ammo_current]
	if _special_ammo_max > 0:
		label_text = "%s %d / %d" % [special_ammo_label, _special_ammo_current, _special_ammo_max]
	var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var baseline: float = special_rect.position.y + (special_rect.size.y + float(font_size)) * 0.5 - 1.0
	var text_pos: Vector2 = Vector2(special_rect.position.x + (special_rect.size.x - text_size.x) * 0.5, baseline)
	draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, special_ammo_text_color)

func _process_initial_owner() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		_player = null
		return
	if parent_node is CharacterBody2D or parent_node.has_method("get_current_health"):
		_player = parent_node
	elif parent_node.get_parent():
		_player = parent_node.get_parent()
	else:
		_player = parent_node
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
	_show_ammo_bar = (_ammo_max > 0 or _ammo_current > 0)
	queue_redraw()
