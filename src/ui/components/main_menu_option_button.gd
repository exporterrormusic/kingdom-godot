extends Button
class_name MainMenuOptionButton

@export var option_id: String = "PLAY"
@export var icon_type: String = "play"
@export var label_text: String = "PLAY"
@export var accent_color: Color = Color(0.75, 0.75, 0.78)
@export var play_option: bool = false

var _base_style_normal: StyleBoxFlat
var _base_style_hover: StyleBoxFlat
var _selected_style: StyleBoxFlat
var _icon: Node = null
var _label: Label = null

func _ready() -> void:
	var content := get_node_or_null("Content")
	if content:
		_icon = content.get_node_or_null("Icon")
		_label = content.get_node_or_null("Label") as Label
	else:
		_icon = null
		_label = null
	flat = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	toggle_mode = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text = ""
	_setup_styles()
	_update_visuals(false)
	if _label:
		_label.text = label_text
	if _icon and _icon.has_method("set_base_color"):
		_icon.set("icon_type", icon_type)
		_icon.call("set_base_color", _get_icon_base_color(false))
		_icon.call("set_selected", false)

func set_selected(selected: bool) -> void:
	_update_visuals(selected)
	if _icon and _icon.has_method("set_selected"):
		_icon.call("set_selected", selected and not play_option)

func set_accent_color(color: Color) -> void:
	accent_color = color
	_update_visuals(false)

func _setup_styles() -> void:
	if play_option:
		_base_style_normal = _create_style_box(Color(0.68, 0.68, 0.72, 1.0), 3.0, Color(0.5, 0.5, 0.54, 1.0))
		_base_style_hover = _create_style_box(Color(0.74, 0.74, 0.78, 1.0), 3.0, Color(0.56, 0.56, 0.6, 1.0))
		_selected_style = _create_style_box(Color(0.82, 0.82, 0.86, 1.0), 4.0, Color(0.68, 0.68, 0.72, 1.0))
	else:
		_base_style_normal = _create_style_box(Color(0.18, 0.18, 0.24, 0.95), 2.0, Color(0.47, 0.47, 0.58, 0.95))
		_base_style_hover = _create_style_box(Color(0.23, 0.23, 0.31, 0.98), 2.5, Color(0.6, 0.6, 0.7, 1.0))
		_selected_style = _create_style_box(Color(0.38, 0.38, 0.5, 1.0), 3.0, Color(0.96, 0.96, 1.0, 1.0))
	update_styles(_base_style_normal, _base_style_hover, _base_style_normal, _base_style_hover)

func _create_style_box(bg_color: Color, border_width: float, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(int(round(border_width)))
	style.border_color = border_color
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = int(round(border_width))
	return style

func _update_visuals(selected: bool) -> void:
	if selected:
		update_styles(_selected_style, _selected_style, _selected_style, _selected_style)
	else:
		update_styles(_base_style_normal, _base_style_hover, _base_style_hover, _base_style_normal)
	var text_color := Color(0.28, 0.28, 0.28) if play_option and not selected else (Color(0.96, 0.96, 1.0) if selected else accent_color)
	if _label:
		_label.add_theme_color_override("font_color", text_color)
	if _icon and _icon.has_method("set_base_color"):
		_icon.call("set_base_color", _get_icon_base_color(selected))

func update_styles(normal: StyleBoxFlat, hover: StyleBoxFlat, pressed_style: StyleBoxFlat, focus: StyleBoxFlat) -> void:
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("focus", focus)
	add_theme_stylebox_override("disabled", normal)
	add_theme_stylebox_override("hover_pressed", pressed_style)

func _get_icon_base_color(selected: bool) -> Color:
	if play_option:
		return Color(0.34, 0.34, 0.34)
	return Color(0.86, 0.86, 0.9) if selected else accent_color
