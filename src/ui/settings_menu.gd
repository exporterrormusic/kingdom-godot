extends Control
class_name SettingsMenu

signal back_requested
signal master_volume_changed(value: float)
signal music_volume_changed(value: float)
signal sfx_volume_changed(value: float)
signal resolution_changed(size: Vector2i)
signal fullscreen_toggled(enabled: bool)
signal key_binding_changed(action: String, keycode: int)

const TAB_AUDIO := "audio"
const TAB_VIDEO := "video"
const TAB_CONTROLS := "controls"
const TAB_ORDER := [TAB_AUDIO, TAB_VIDEO, TAB_CONTROLS]

const DEFAULT_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

const OPTION_ON := "ON"
const OPTION_OFF := "OFF"
const CONTROL_ACTION_DEFINITIONS := [
	{"action": "move_up", "label": "Move Up", "node": "%MoveUpButton"},
	{"action": "move_down", "label": "Move Down", "node": "%MoveDownButton"},
	{"action": "move_left", "label": "Move Left", "node": "%MoveLeftButton"},
	{"action": "move_right", "label": "Move Right", "node": "%MoveRightButton"},
	{"action": "dash", "label": "Dash", "node": "%DashButton"},
	{"action": "burst", "label": "Burst", "node": "%BurstButton"},
	{"action": "ui_cancel", "label": "Pause", "node": "%PauseButton"}
]

@onready var _tabs: Dictionary = {
	TAB_AUDIO: %AudioTab,
	TAB_VIDEO: %VideoTab,
	TAB_CONTROLS: %ControlsTab
}

@onready var _panels: Dictionary = {
	TAB_AUDIO: %AudioPanel,
	TAB_VIDEO: %VideoPanel,
	TAB_CONTROLS: %ControlsPanel
}

# Audio controls
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_value: Label = %MusicValue
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value: Label = %SfxValue

# Video controls
@onready var _resolution_options: OptionButton = %ResolutionOptions
@onready var _fullscreen_options: OptionButton = %FullscreenOptions

# Control bindings
var _control_buttons: Dictionary = {}

var _available_resolutions: Array[Vector2i] = []
var _current_tab: String = TAB_AUDIO
var _capturing_action: String = ""
var _capturing_button: Button = null
var _capturing_original_text: String = ""
var _suppress_signals: bool = false

func _ready() -> void:
	for tab_name in TAB_ORDER:
		var button: Button = _tabs[tab_name]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(Callable(self, "_on_tab_pressed").bind(tab_name))

	_music_slider.value_changed.connect(_on_music_slider_value_changed)
	_sfx_slider.value_changed.connect(_on_sfx_slider_value_changed)

	_resolution_options.item_selected.connect(_on_resolution_selected)
	_fullscreen_options.item_selected.connect(_on_fullscreen_selected)

	for definition in CONTROL_ACTION_DEFINITIONS:
		var button: Button = get_node(definition["node"])
		button.focus_mode = Control.FOCUS_NONE
		var action_name: String = String(definition["action"])
		var button_ref: Button = button
		button.pressed.connect(func() -> void:
			_begin_key_capture(action_name, button_ref)
		)
		_control_buttons[definition["action"]] = button

	_initialize_resolutions()
	_initialize_dropdowns()
	_current_tab = ""
	_switch_tab(TAB_AUDIO)
	_update_music_label(_music_slider.value)
	_update_sfx_label(_sfx_slider.value)
	_refresh_key_binding_labels()
	set_process_unhandled_input(true)

func _initialize_resolutions() -> void:
	_available_resolutions = DEFAULT_RESOLUTIONS.duplicate()
	_available_resolutions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or (a.x == b.x and a.y < b.y)
	)
	_refresh_resolution_options()

func _refresh_resolution_options() -> void:
	_resolution_options.clear()
	for resolution in _available_resolutions:
		_resolution_options.add_item("%d x %d" % [resolution.x, resolution.y])

func _initialize_dropdowns() -> void:
	_fullscreen_options.clear()
	_fullscreen_options.add_item(OPTION_ON)
	_fullscreen_options.add_item(OPTION_OFF)

func _on_tab_pressed(tab_name: String) -> void:
	_switch_tab(tab_name)

func _switch_tab(tab_name: String) -> void:
	if _current_tab == tab_name:
		return
	if _panels.has(_current_tab):
		_panels[_current_tab].visible = false
	if _tabs.has(_current_tab):
		_tabs[_current_tab].button_pressed = false
	_current_tab = tab_name
	if _panels.has(_current_tab):
		_panels[_current_tab].visible = true
	if _tabs.has(_current_tab):
		_tabs[_current_tab].button_pressed = true
	_update_tab_colors()

func _update_tab_colors() -> void:
	for tab_name in TAB_ORDER:
		if not _tabs.has(tab_name):
			continue
		var button: Button = _tabs[tab_name]
		var active: bool = _current_tab == tab_name
		var inactive_color: Color = Color(0.862745, 0.862745, 0.905882)
		var inactive_hover: Color = Color(0.956863, 0.956863, 1.0)
		var active_color: Color = Color(0.219608, 0.219608, 0.219608)
		var active_hover: Color = Color(0.160784, 0.160784, 0.160784)
		if active:
			button.add_theme_color_override("font_color", active_color)
			button.add_theme_color_override("font_color_pressed", active_color)
			button.add_theme_color_override("font_color_hover", active_hover)
			button.add_theme_color_override("font_color_hover_pressed", active_hover)
		else:
			button.add_theme_color_override("font_color", inactive_color)
			button.add_theme_color_override("font_color_hover", inactive_hover)
			button.add_theme_color_override("font_color_pressed", active_color)
			button.add_theme_color_override("font_color_hover_pressed", active_color)

func _on_music_slider_value_changed(value: float) -> void:
	_update_music_label(value)
	if _suppress_signals:
		return
	emit_signal("music_volume_changed", value)
	emit_signal("master_volume_changed", value)
	_apply_bus_volume("Music", value)

func _on_sfx_slider_value_changed(value: float) -> void:
	_update_sfx_label(value)
	if _suppress_signals:
		return
	emit_signal("sfx_volume_changed", value)
	_apply_bus_volume("SFX", value)

func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= _available_resolutions.size():
		return
	if _suppress_signals:
		return
	emit_signal("resolution_changed", _available_resolutions[index])

func _on_fullscreen_selected(index: int) -> void:
	if _suppress_signals:
		return
	var enabled: bool = index == 0
	emit_signal("fullscreen_toggled", enabled)

func _begin_key_capture(action: String, button: Button) -> void:
	if _capturing_action == action:
		return
	_cancel_key_capture()
	_capturing_action = action
	_capturing_button = button
	_capturing_original_text = button.text
	button.text = "PRESS KEY..."
	button.add_theme_color_override("font_color", Color(1, 0.94, 0.74))

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.is_pressed() or key_event.is_echo():
		return
	if _capturing_action != "":
		_apply_key_binding(_capturing_action, key_event)
		get_viewport().set_input_as_handled()
		return
	var is_escape: bool = key_event.physical_keycode == KEY_ESCAPE or key_event.keycode == KEY_ESCAPE
	if key_event.is_action_pressed("ui_cancel") or is_escape:
		emit_signal("back_requested")
		get_viewport().set_input_as_handled()

func _apply_key_binding(action: String, event: InputEventKey) -> void:
	var copy: InputEventKey = InputEventKey.new()
	copy.physical_keycode = event.physical_keycode
	copy.keycode = event.keycode if event.keycode != 0 else event.physical_keycode
	copy.shift_pressed = event.shift_pressed
	copy.ctrl_pressed = event.ctrl_pressed
	copy.alt_pressed = event.alt_pressed
	copy.meta_pressed = event.meta_pressed

	var existing: Array = InputMap.action_get_events(action)
	for ev in existing:
		InputMap.action_erase_event(action, ev)
	InputMap.action_add_event(action, copy)
	_update_button_for_action(action, copy.physical_keycode)
	if not _suppress_signals:
		emit_signal("key_binding_changed", action, copy.physical_keycode)
	_cancel_key_capture()

func _update_button_for_action(action: String, keycode: int) -> void:
	if not _control_buttons.has(action):
		return
	var button: Button = _control_buttons[action]
	var label: String = _keycode_to_string(keycode)
	button.text = label
	button.remove_theme_color_override("font_color")
	button.remove_theme_color_override("font_color_pressed")
	button.remove_theme_color_override("font_color_hover")
	button.add_theme_color_override("font_color", Color(0.862745, 0.862745, 0.905882))
	button.add_theme_color_override("font_color_hover", Color(0.956863, 0.956863, 1.0))
	button.add_theme_color_override("font_color_pressed", Color(0.219608, 0.219608, 0.219608))

func _cancel_key_capture() -> void:
	if _capturing_button:
		_capturing_button.text = _capturing_original_text if _capturing_original_text != "" else _capturing_button.text
		_capturing_button.remove_theme_color_override("font_color")
	_capturing_action = ""
	_capturing_button = null
	_capturing_original_text = ""

func _update_music_label(value: float) -> void:
	_music_value.text = "%d%%" % int(round(value * 100.0))

func _update_sfx_label(value: float) -> void:
	_sfx_value.text = "%d%%" % int(round(value * 100.0))

func _apply_bus_volume(bus_name: String, value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	var linear: float = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(max(linear, 0.0001)))

func _keycode_to_string(keycode: int) -> String:
	if keycode == 0:
		return "UNBOUND"
	return OS.get_keycode_string(keycode)

# -- Public setters -----------------------------------------------------------------

func set_master_volume(value: float) -> void:
	set_music_volume(value)

func set_music_volume(value: float) -> void:
	_suppress_signals = true
	_music_slider.value = clamp(value, _music_slider.min_value, _music_slider.max_value)
	_update_music_label(_music_slider.value)
	_suppress_signals = false

func set_sfx_volume(value: float) -> void:
	_suppress_signals = true
	_sfx_slider.value = clamp(value, _sfx_slider.min_value, _sfx_slider.max_value)
	_update_sfx_label(_sfx_slider.value)
	_suppress_signals = false

func set_resolution(target: Vector2i) -> void:
	if not _available_resolutions.has(target):
		_available_resolutions.append(target)
		_available_resolutions.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x < b.x or (a.x == b.x and a.y < b.y)
		)
		_refresh_resolution_options()
	var index: int = _available_resolutions.find(target)
	if index != -1:
		_suppress_signals = true
		_resolution_options.select(index)
		_suppress_signals = false

func set_fullscreen(enabled: bool) -> void:
	_suppress_signals = true
	_fullscreen_options.select(0 if enabled else 1)
	_suppress_signals = false

func set_key_bindings(bindings: Dictionary) -> void:
	_suppress_signals = true
	for definition in CONTROL_ACTION_DEFINITIONS:
		var action: String = definition["action"]
		if bindings.has(action):
			var keycode: int = int(bindings[action])
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = keycode as Key
			event.keycode = keycode as Key
			var existing: Array = InputMap.action_get_events(action)
			for ev in existing:
				InputMap.action_erase_event(action, ev)
			InputMap.action_add_event(action, event)
			_update_button_for_action(action, keycode)
	_suppress_signals = false
	_refresh_key_binding_labels()
func clear_capture_state() -> void:
	_cancel_key_capture()

func _refresh_key_binding_labels() -> void:
	for definition in CONTROL_ACTION_DEFINITIONS:
		var action: String = definition["action"]
		if not InputMap.has_action(action):
			continue
		var events: Array = InputMap.action_get_events(action)
		var keycode: int = 0
		for ev in events:
			if ev is InputEventKey:
				var key_event: InputEventKey = ev
				keycode = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
				break
		_update_button_for_action(action, keycode)
