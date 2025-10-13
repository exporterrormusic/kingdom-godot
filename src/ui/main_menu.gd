extends Control
class_name MainMenu

signal start_game_requested
signal settings_requested
signal achievements_requested
signal leaderboards_requested
signal shop_requested
signal outpost_requested
signal quit_requested

const MENU_OPTIONS := [
	{"id": "LEADERBOARDS", "icon": "leaderboards", "label": "LEADERBOARDS"},
	{"id": "ACHIEVEMENTS", "icon": "achievements", "label": "ACHIEVEMENTS"},
	{"id": "SHOP", "icon": "shop", "label": "SHOP"},
	{"id": "PLAY", "icon": "play", "label": "PLAY"},
	{"id": "THE OUTPOST", "icon": "outpost", "label": "THE OUTPOST"},
	{"id": "SETTINGS", "icon": "settings", "label": "SETTINGS"},
	{"id": "QUIT", "icon": "quit", "label": "QUIT"}
]

@onready var _background: Control = $Background
@onready var _button_row: Control = %ButtonRow
@onready var _title_panel: Panel = %TitlePanel
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _version_label: Label = %VersionLabel
@onready var _coming_soon_dialog: AcceptDialog = %ComingSoonDialog
var _buttons: Array = []
var _selected_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)
	_setup_background()
	_setup_title_block()
	_initialize_buttons()
	_update_selection(_get_initial_selection_index(), 1)
	_update_version_label()
	set_last_selected_character(null)

func _setup_background() -> void:
	if not _background:
		return
	if _background is VenetianBlindsBackground:
		var blinds := _background as VenetianBlindsBackground
		blinds.set_background_textures(blinds.background_textures)

func _setup_title_block() -> void:
	if _title_label:
		_title_label.text = "KINGDOM CLEANUP"
	if _subtitle_label:
		_subtitle_label.text = "A NIKKE FAN GAME"

func _initialize_buttons() -> void:
	_buttons.clear()
	_buttons.resize(MENU_OPTIONS.size())
	if not _button_row:
		return
	for i in MENU_OPTIONS.size():
		var config: Dictionary = MENU_OPTIONS[i]
		var option_id: String = str(config.get("id", ""))
		if option_id == "":
			continue
		if not _button_row.has_node(option_id):
			continue
		var button_node := _button_row.get_node(option_id)
		if button_node is MainMenuOptionButton:
			var button: MainMenuOptionButton = button_node
			button.set_selected(false)
			button.set_accent_color(_get_button_accent_color(option_id))
			button.pressed.connect(Callable(self, "_on_option_pressed").bind(i))
			button.mouse_entered.connect(Callable(self, "_on_option_hovered").bind(i))
			_buttons[i] = button

func _get_valid_index(start: int, direction: int) -> int:
	if _buttons.is_empty():
		return -1
	var index := wrapi(start, 0, _buttons.size())
	if direction == 0:
		return index if _buttons[index] is MainMenuOptionButton else -1
	var step := 1 if direction > 0 else -1
	for _i in _buttons.size():
		var button = _buttons[index]
		if button is MainMenuOptionButton:
			return index
		index = wrapi(index + step, 0, _buttons.size())
	return -1

func _get_initial_selection_index() -> int:
	for i in MENU_OPTIONS.size():
		var config: Dictionary = MENU_OPTIONS[i]
		if config.get("id", "") == "PLAY":
			return i
	return 0

func _on_option_hovered(index: int) -> void:
	_update_selection(index, 0)

func _on_option_pressed(index: int) -> void:
	_update_selection(index, 0)
	_activate_selection()

func _activate_selection() -> void:
	if _selected_index < 0 or _selected_index >= MENU_OPTIONS.size():
		return
	var config: Dictionary = MENU_OPTIONS[_selected_index]
	var option_id: String = config.get("id", "")
	match option_id:
		"LEADERBOARDS":
			emit_signal("leaderboards_requested")
		"ACHIEVEMENTS":
			emit_signal("achievements_requested")
		"SHOP":
			emit_signal("shop_requested")
			_show_placeholder_message("Shop")
		"PLAY":
			emit_signal("start_game_requested")
		"THE OUTPOST":
			emit_signal("outpost_requested")
			_show_placeholder_message("The Outpost")
		"SETTINGS":
			emit_signal("settings_requested")
		"QUIT":
			emit_signal("quit_requested")
			get_tree().quit()

func _update_selection(index: int, direction: int) -> void:
	if _buttons.is_empty():
		_selected_index = 0
		return
	var new_index := _get_valid_index(index, direction)
	if new_index == -1:
		return
	_selected_index = new_index
	for i in _buttons.size():
		var button = _buttons[i]
		if button is MainMenuOptionButton:
			button.set_selected(i == _selected_index)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_update_selection(_selected_index - 1, -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_update_selection(_selected_index + 1, 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		_activate_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		emit_signal("quit_requested")
		get_tree().quit()
		get_viewport().set_input_as_handled()

func set_last_selected_character(_character) -> void:
	pass

func set_title_panel_visible(should_show: bool) -> void:
	if _title_panel:
		_title_panel.visible = should_show

func _show_placeholder_message(feature_name: String) -> void:
	if not _coming_soon_dialog:
		return
	_coming_soon_dialog.title = "%s" % feature_name
	_coming_soon_dialog.dialog_text = "%s is not available in this slice yet." % feature_name
	_coming_soon_dialog.popup_centered()

func _get_button_accent_color(option_id: String) -> Color:
	match option_id:
		"PLAY":
			return Color(0.39, 0.39, 0.39)
		"QUIT":
			return Color(0.96, 0.39, 0.39)
		_:
			return Color(0.7, 0.7, 0.75)

func _update_version_label() -> void:
	if not _version_label:
		return
	var version_info := Engine.get_version_info()
	var readable := "v%s.%s.%s" % [version_info.get("major", 4), version_info.get("minor", 0), version_info.get("patch", 0)]
	_version_label.text = "%s" % readable
