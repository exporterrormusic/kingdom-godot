extends Control
class_name CharacterSelectMenu

signal back_requested
signal character_confirmed(character_data: CharacterData, mission_config: Dictionary)

const CharacterCardScene := preload("res://scenes/ui/components/CharacterCard.tscn")
const RANDOM_CODE := "RANDOM"
const STAT_META := [
	{"key": "hp", "label": "HP", "max": 500},
	{"key": "attack", "label": "ATK", "max": 200},
	{"key": "speed_rating", "label": "SPD", "max": 400},
	{"key": "burst_rating", "label": "BRST", "max": 15}
]

const DETAILS_ENTRY_OFFSET := 200.0
const DETAILS_TARGET_Y_1080P := -23.4
const DETAILS_TARGET_MIN_Y := -400.0
const CONFIG_PANEL_RAISE := 140.0
const BUTTONS_RAISE := 80.0
const CONFIGURATION_ENTRY_OFFSET := 80.0
const BUTTON_ENTRY_OFFSET := 70.0
const MAPS_DIRECTORY := "res://resources/world/maps"
const BIOMES_DIRECTORY := "res://resources/world/biomes"
const TIMES_DIRECTORY := "res://resources/world/time_of_day"
const EnvironmentControllerScene := preload("res://src/world/environment/environment_controller.gd")

enum MenuStage { SELECTING, TRANSITIONING, CONFIGURING }

@onready var _grid_root: Control = %GridRoot
@onready var _content_root: Control = get_node_or_null("ContentRoot") as Control
@onready var _overlay: ColorRect = get_node_or_null("Overlay") as ColorRect
@onready var _title_bar: Control = %TitleBar
@onready var _details_panel: Panel = %DetailsPanel
@onready var _details_content: HBoxContainer = %DetailsContent
@onready var _random_details: CenterContainer = %RandomDetails
@onready var _character_name_label: Label = %CharacterName
@onready var _character_sprite: TextureRect = %CharacterSprite
@onready var _stats_container: VBoxContainer = %StatsContainer
@onready var _weapon_title: Label = %WeaponTitle
@onready var _weapon_type: Label = %WeaponType
@onready var _weapon_description: RichTextLabel = %WeaponDescription
@onready var _weapon_special_title: Label = %WeaponSpecialTitle
@onready var _weapon_special_description: RichTextLabel = %WeaponSpecialDescription
@onready var _burst_title: Label = %BurstTitle
@onready var _burst_description: RichTextLabel = %BurstDescription
@onready var _configuration_panel: Panel = %ConfigurationPanel
@onready var _configuration_background: ColorRect = get_node_or_null("ConfigurationPanel/ConfigurationBackground") as ColorRect
@onready var _configuration_border: ColorRect = get_node_or_null("ConfigurationPanel/ConfigurationBorder") as ColorRect
@onready var _configuration_content: HBoxContainer = get_node_or_null("ConfigurationPanel/ConfigurationContent") as HBoxContainer
@onready var _setup_column: VBoxContainer = get_node_or_null("ConfigurationPanel/ConfigurationContent/SetupColumn") as VBoxContainer
@onready var _mission_columns: HBoxContainer = get_node_or_null("ConfigurationPanel/ConfigurationContent/SetupColumn/MissionColumns") as HBoxContainer
@onready var _map_section: VBoxContainer = get_node_or_null("ConfigurationPanel/ConfigurationContent/SetupColumn/MissionColumns/MapSection") as VBoxContainer
@onready var _time_section: VBoxContainer = get_node_or_null("ConfigurationPanel/ConfigurationContent/SetupColumn/MissionColumns/TimeOfDaySection") as VBoxContainer
@onready var _map_row: HBoxContainer = get_node_or_null("ConfigurationPanel/ConfigurationContent/SetupColumn/MissionColumns/MapSection/MapRow") as HBoxContainer
@onready var _time_row: HBoxContainer = get_node_or_null("ConfigurationPanel/ConfigurationContent/SetupColumn/MissionColumns/TimeOfDaySection/TimeOfDayRow") as HBoxContainer
@onready var _buttons_bar: HBoxContainer = %ButtonsBar
@onready var _confirm_button: Button = %ConfirmButton
@onready var _back_button: Button = %BackButton
@onready var _map_preview_texture: TextureRect = %MapPreviewTexture
@onready var _map_preview_viewport: SubViewport = %MapPreviewViewport
@onready var _map_details: RichTextLabel = %MapDetails
@onready var _map_options: MenuButton = %MapOptions
@onready var _time_options: MenuButton = %TimeOfDayOptions
@onready var _modifiers_toggle: CheckBox = %ModifiersOptions

var _roster: CharacterRoster = null
var _entries: Array = []
var _selected_index: int = 0
var _stat_rows: Dictionary = {}
var _sprite_cache: Dictionary = {}
var _current_frames: Array = []
var _current_frame_fps: float = 6.0
var _animation_time: float = 0.0
var _top_row_count: int = 0
var _bottom_row_count: int = 0
var _bottom_row_columns: int = 1
var _stage: MenuStage = MenuStage.SELECTING as MenuStage
var _transition_tween: Tween = null
var _title_bar_base_position: Vector2
var _grid_base_position: Vector2
var _buttons_base_position: Vector2
var _buttons_entry_position_y: float = 0.0
var _buttons_raised_position_y: float = 0.0
var _configuration_base_position: Vector2
var _details_base_position: Vector2
var _grid_hidden_position_y: float
var _details_raised_position_y: float
var _configuration_hidden_position_y: float
var _rng := RandomNumberGenerator.new()
var _map_definitions: Array[MapDefinition] = []
var _biome_lookup: Dictionary = {}
var _time_lookup: Dictionary = {}
var _available_time_ids: Array[StringName] = []
var _selected_map_index: int = -1
var _mission_config: Dictionary = {
	"map_id": StringName(""),
	"biome_id": StringName(""),
	"time_of_day_id": StringName(""),
	"environment_seed": 0,
	"random_events": false
}
var _mission_config_initialized: bool = false
var _map_preview_environment: EnvironmentController = null
var _map_popup: PopupMenu = null
var _time_popup: PopupMenu = null
var _content_root_default_mouse_filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP as Control.MouseFilter

func _mouse_filter(value: int) -> Control.MouseFilter:
	return value as Control.MouseFilter

func _set_mouse_filter(control: Control, filter: Control.MouseFilter, _label: String) -> void:
	if control == null:
		return
	if control.mouse_filter == filter:
		return
	control.mouse_filter = filter

func _ready() -> void:
	_rng.randomize()
	mouse_filter = _mouse_filter(Control.MOUSE_FILTER_PASS)
	if _overlay:
		_overlay.mouse_filter = _mouse_filter(Control.MOUSE_FILTER_IGNORE)
		_overlay.z_index = -10
		if _overlay.has_method("set_pickable"):
			_overlay.set_pickable(false)
	if _content_root:
		_content_root_default_mouse_filter = _content_root.mouse_filter
	_set_mouse_filter(_configuration_panel, _mouse_filter(Control.MOUSE_FILTER_PASS), "ConfigurationPanel")
	_set_mouse_filter(_configuration_background, _mouse_filter(Control.MOUSE_FILTER_IGNORE), "ConfigurationBackground")
	_set_mouse_filter(_configuration_border, _mouse_filter(Control.MOUSE_FILTER_IGNORE), "ConfigurationBorder")
	_set_mouse_filter(_configuration_content, _mouse_filter(Control.MOUSE_FILTER_PASS), "ConfigurationContent")
	_set_mouse_filter(_setup_column, _mouse_filter(Control.MOUSE_FILTER_PASS), "SetupColumn")
	_set_mouse_filter(_mission_columns, _mouse_filter(Control.MOUSE_FILTER_PASS), "MissionColumns")
	_set_mouse_filter(_map_section, _mouse_filter(Control.MOUSE_FILTER_PASS), "MapSection")
	_set_mouse_filter(_time_section, _mouse_filter(Control.MOUSE_FILTER_PASS), "TimeOfDaySection")
	_set_mouse_filter(_map_row, _mouse_filter(Control.MOUSE_FILTER_PASS), "MapRow")
	_set_mouse_filter(_time_row, _mouse_filter(Control.MOUSE_FILTER_PASS), "TimeOfDayRow")
	_back_button.pressed.connect(_on_back_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_map_popup = _map_options.get_popup() if _map_options else null
	_time_popup = _time_options.get_popup() if _time_options else null
	_configure_menu_popup(_map_options, _map_popup, Callable(self, "_on_map_menu_id_pressed"))
	_configure_menu_popup(_time_options, _time_popup, Callable(self, "_on_time_menu_id_pressed"))
	_modifiers_toggle.toggled.connect(_on_modifiers_toggled)
	_build_stat_rows()
	_update_buttons()
	if _roster:
		_populate_cards()
	_initialize_mission_configuration()
	_title_bar_base_position = _title_bar.position
	_grid_base_position = _grid_root.position
	_buttons_base_position = _buttons_bar.position
	_configuration_base_position = _configuration_panel.position
	_details_base_position = _details_panel.position
	_refresh_button_positions(false)
	_grid_hidden_position_y = _grid_base_position.y
	_details_raised_position_y = _details_base_position.y
	_configuration_hidden_position_y = _compute_configuration_hidden_y()
	_configuration_panel.visible = false
	_configuration_panel.modulate = Color(1, 1, 1, 0)
	_configuration_panel.position = Vector2(_configuration_base_position.x, _configuration_hidden_position_y)
	_buttons_bar.visible = false
	_buttons_bar.modulate = Color(1, 1, 1, 1)
	_buttons_bar.position = _buttons_base_position
	_grid_root.visible = true
	_grid_root.modulate = Color(1, 1, 1, 1)
	set_process(true)

func set_roster(roster: CharacterRoster) -> void:
	_roster = roster
	if _grid_root:
		_populate_cards()

func set_initial_selection(code_name: String) -> void:
	if _entries.is_empty():
		return
	for i in range(_entries.size()):
		var entry: Dictionary = _entries[i]
		if entry.get("type") == "character":
			var character: CharacterData = entry.get("character")
			if character and character.code_name == code_name:
				_select_index(i)
				return

func _populate_cards() -> void:
	for child in _grid_root.get_children():
		child.queue_free()
	_entries.clear()
	_selected_index = 0
	var characters: Array = []
	if _roster and _roster.characters:
		characters = _roster.characters
	for character in characters:
		if character == null:
			continue
		var card: CharacterCard = CharacterCardScene.instantiate() as CharacterCard
		if card == null:
			continue
		_grid_root.add_child(card)
		card.configure(character.display_name, _get_card_texture(character), false, character)
		card.pressed.connect(_on_card_pressed)
		card.hovered.connect(_on_card_hovered)
		_entries.append({
			"type": "character",
			"character": character,
			"card": card
		})

	# Random selection card
	var random_card: CharacterCard = CharacterCardScene.instantiate() as CharacterCard
	if random_card:
		_grid_root.add_child(random_card)
		random_card.configure("RANDOM", null, true, null)
		random_card.pressed.connect(_on_card_pressed)
		random_card.hovered.connect(_on_card_hovered)
		_entries.append({
		"type": "random",
		"card": random_card
	})

	_layout_cards()
	_select_index(0)
	_update_buttons()

func _build_stat_rows() -> void:
	for child in _stats_container.get_children():
		child.queue_free()
	_stat_rows.clear()
	for stat_def in STAT_META:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 44)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		var label := Label.new()
		label.text = stat_def["label"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.custom_minimum_size = Vector2(70, 0)
		label.add_theme_font_size_override("font_size", 28)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(220, 18)
		bar.min_value = 0
		bar.max_value = stat_def["max"]
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.18, 0.18, 0.24, 1.0)
		bg_style.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("bg", bg_style)
		var fill_style := StyleBoxFlat.new()
		fill_style.bg_color = Color(0.6, 0.78, 1.0, 1.0)
		fill_style.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", fill_style)
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(50, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		value_label.add_theme_font_size_override("font_size", 28)
		row.add_child(label)
		row.add_child(bar)
		row.add_child(value_label)
		_stats_container.add_child(row)
		_stat_rows[stat_def["key"]] = {
			"bar": bar,
			"value": value_label,
			"max": stat_def["max"]
		}

func _initialize_mission_configuration() -> void:
	_map_definitions = _load_map_definitions()
	_biome_lookup = _load_biome_definitions()
	_time_lookup = _load_time_definitions()
	_setup_map_preview_environment()
	_populate_map_options()
	var random_events_enabled := bool(_mission_config.get("random_events", false))
	if _modifiers_toggle:
		_modifiers_toggle.button_pressed = random_events_enabled
	_mission_config_initialized = true
	_apply_mission_config_overrides()

func set_mission_config(config: Dictionary) -> void:
	if typeof(config) != TYPE_DICTIONARY or config.is_empty():
		return
	var merged: Dictionary = _mission_config.duplicate(true)
	if config.has("map_id"):
		merged["map_id"] = _to_string_name(config["map_id"])
	if config.has("biome_id"):
		merged["biome_id"] = _to_string_name(config["biome_id"])
	if config.has("time_of_day_id"):
		merged["time_of_day_id"] = _to_string_name(config["time_of_day_id"])
	if config.has("environment_seed"):
		merged["environment_seed"] = int(config["environment_seed"])
	if config.has("random_events"):
		merged["random_events"] = bool(config["random_events"])
	_mission_config = merged
	if _mission_config_initialized:
		_apply_mission_config_overrides()

func _load_map_definitions() -> Array[MapDefinition]:
	var results: Array[MapDefinition] = []
	var dir := DirAccess.open(MAPS_DIRECTORY)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				file_name = dir.get_next()
				continue
			if not file_name.ends_with(".tres"):
				file_name = dir.get_next()
				continue
			var resource_path := String("%s/%s" % [MAPS_DIRECTORY, file_name])
			var resource := ResourceLoader.load(resource_path)
			var map_def := resource as MapDefinition
			if map_def:
				results.append(map_def)
			file_name = dir.get_next()
		dir.list_dir_end()
	results.sort_custom(Callable(self, "_sort_map_definitions"))
	return results

func _load_biome_definitions() -> Dictionary:
	var lookup: Dictionary = {}
	var dir := DirAccess.open(BIOMES_DIRECTORY)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if dir.current_is_dir() or not file_name.ends_with(".tres"):
				file_name = dir.get_next()
				continue
			var resource_path := String("%s/%s" % [BIOMES_DIRECTORY, file_name])
			var resource := ResourceLoader.load(resource_path)
			var biome := resource as BiomeDefinition
			if biome:
				var key := biome.biome_id if biome.biome_id != StringName("") else StringName(biome.display_name.to_lower())
				lookup[key] = biome
			file_name = dir.get_next()
		dir.list_dir_end()
	return lookup

func _load_time_definitions() -> Dictionary:
	var lookup: Dictionary = {}
	var dir := DirAccess.open(TIMES_DIRECTORY)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if dir.current_is_dir() or not file_name.ends_with(".tres"):
				file_name = dir.get_next()
				continue
			var resource_path := String("%s/%s" % [TIMES_DIRECTORY, file_name])
			var resource := ResourceLoader.load(resource_path)
			var time_def := resource as TimeOfDayDefinition
			if time_def:
				var key := time_def.time_id if time_def.time_id != StringName("") else StringName(time_def.display_name.to_lower())
				lookup[key] = time_def
			file_name = dir.get_next()
		dir.list_dir_end()
	return lookup

func _setup_map_preview_environment() -> void:
	if not _map_preview_viewport or _map_preview_environment:
		return
	if EnvironmentControllerScene == null:
		return
	_map_preview_environment = EnvironmentControllerScene.new()
	_map_preview_environment.name = "EnvironmentPreview"
	_map_preview_environment.auto_initialize = false
	_map_preview_environment.use_fixed_seed = true
	_map_preview_environment.ground_extent = 960.0
	_map_preview_environment.set_physics_process(false)
	_map_preview_environment.set_process(true)
	_map_preview_viewport.add_child(_map_preview_environment)
	if _map_preview_texture:
		_map_preview_texture.texture = _map_preview_viewport.get_texture()
	_refresh_map_preview_environment(null)

func _configure_menu_popup(button: MenuButton, popup: PopupMenu, handler: Callable) -> void:
	if button == null or popup == null:
		return
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = _mouse_filter(Control.MOUSE_FILTER_STOP)
	_apply_menu_button_style(button)
	var pressed_callable := Callable(self, "_on_menu_button_pressed").bind(button, popup)
	if button.pressed.is_connected(pressed_callable):
		button.pressed.disconnect(pressed_callable)
	button.pressed.connect(pressed_callable)
	button.gui_input.connect(func(event: InputEvent) -> void:
		var mouse_event := event as InputEventMouseButton
		if mouse_event and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			button.grab_focus()
			button.show_popup()
			button.accept_event()
			return
		var key_event := event as InputEventKey
		if key_event and key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE):
			button.grab_focus()
			button.show_popup()
			button.accept_event()
	)
	if popup.id_pressed.is_connected(handler):
		popup.id_pressed.disconnect(handler)
	popup.id_pressed.connect(handler)
	popup.hide_on_checkable_item_selection = true

func _on_map_menu_id_pressed(id: int) -> void:
	_on_map_option_selected(id)

func _on_time_menu_id_pressed(id: int) -> void:
	_on_time_option_selected(id)

func _apply_menu_button_style(button: MenuButton) -> void:
	button.flat = false
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.expand_icon = false
	button.custom_minimum_size = Vector2(240, 48)
	var normal := _create_menu_button_style(Color(0.12, 0.13, 0.19, 0.96), Color(0.42, 0.49, 0.74, 0.92))
	var hover := _create_menu_button_style(Color(0.16, 0.18, 0.26, 0.98), Color(0.52, 0.6, 0.86, 0.96))
	var pressed := _create_menu_button_style(Color(0.18, 0.2, 0.3, 1.0), Color(0.58, 0.64, 0.89, 1.0))
	var disabled := _create_menu_button_style(Color(0.1, 0.1, 0.14, 0.6), Color(0.25, 0.25, 0.34, 0.6))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	var arrow_icon := _resolve_dropdown_icon(button)
	if arrow_icon:
		button.icon = arrow_icon
		button.add_theme_color_override("icon_color", Color(0.85, 0.9, 1.0, 0.95))

func _create_menu_button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.expand_margin_left = 6
	style.expand_margin_right = 6
	style.expand_margin_top = 4
	style.expand_margin_bottom = 4
	return style

func _resolve_dropdown_icon(button: MenuButton) -> Texture2D:
	var theme_pairs := [
		{"name": "arrow", "type": "OptionButton"},
		{"name": "arrow_down", "type": "OptionButton"},
		{"name": "gui_dropdown", "type": "MenuButton"},
		{"name": "arrow_down", "type": "Tree"},
		{"name": "arrow_down", "type": "Button"}
	]
	for pair in theme_pairs:
		var icon_name: StringName = StringName(pair["name"])
		var theme_type: StringName = StringName(pair["type"])
		if button.has_theme_icon(icon_name, theme_type):
			return button.get_theme_icon(icon_name, theme_type)
	return null

func _on_menu_button_pressed(button: MenuButton, popup: PopupMenu) -> void:
	if button == null or popup == null:
		return
	if popup.get_item_count() == 0:
		return
	popup.reset_size()
	var global_rect := button.get_global_rect()
	var popup_position := Vector2i(int(round(global_rect.position.x)), int(round(global_rect.position.y + global_rect.size.y)))
	var popup_size := Vector2i(int(round(max(global_rect.size.x, 1.0))), 0)
	popup.popup(Rect2i(popup_position, popup_size))

func _set_menu_button_selection(button: MenuButton, popup: PopupMenu, id: int) -> void:
	if button == null or popup == null:
		return
	var item_index := popup.get_item_index(id)
	if item_index == -1:
		return
	for i in range(popup.get_item_count()):
		popup.set_item_checked(i, i == item_index)
	var selection_text := popup.get_item_text(item_index)
	if button.icon == null and not selection_text.ends_with(" ▼"):
		selection_text = "%s ▼" % selection_text
	button.text = selection_text

func _clear_menu_button(button: MenuButton, popup: PopupMenu, placeholder: String) -> void:
	if popup:
		popup.clear()
	if button:
		var resolved_text := placeholder
		if button.icon == null and not resolved_text.ends_with(" ▼"):
			resolved_text = "%s ▼" % resolved_text
		button.text = resolved_text
		button.disabled = true

func _refresh_map_preview_environment(map_def: MapDefinition) -> void:
	if not _map_preview_environment:
		return
	var biome_defs: Array[BiomeDefinition] = []
	for value in _biome_lookup.values():
		if value is BiomeDefinition:
			biome_defs.append(value)
	var time_defs: Array[TimeOfDayDefinition] = []
	for value in _time_lookup.values():
		if value is TimeOfDayDefinition:
			time_defs.append(value)
	_map_preview_environment.biome_definitions = biome_defs
	_map_preview_environment.time_of_day_definitions = time_defs
	var target_biome: StringName = StringName("")
	var target_time: StringName = StringName("")
	var seed_value: int = _rng.randi()
	if map_def:
		target_biome = map_def.biome_id
		target_time = map_def.time_of_day_id
		seed_value = _compute_preview_seed(map_def)
	var configured_biome: StringName = _mission_config.get("biome_id", StringName(""))
	if configured_biome != StringName(""):
		target_biome = configured_biome
	var configured_time: StringName = _mission_config.get("time_of_day_id", StringName(""))
	if configured_time != StringName(""):
		target_time = configured_time
	var configured_seed: int = int(_mission_config.get("environment_seed", 0))
	if configured_seed > 0:
		seed_value = configured_seed
	if target_biome == StringName("") and not biome_defs.is_empty():
		target_biome = biome_defs[0].biome_id
	var available_times: Array[StringName] = []
	if map_def:
		available_times = map_def.get_available_time_ids()
	if target_time == StringName("") and not available_times.is_empty():
		target_time = available_times[0]
	if target_time == StringName("") and not time_defs.is_empty():
		target_time = time_defs[0].time_id
	_map_preview_environment.environment_seed = seed_value
	_map_preview_environment.initialize_environment(seed_value, target_biome, target_time)

func _compute_preview_seed(map_def: MapDefinition) -> int:
	if map_def == null:
		return _rng.randi()
	var seed_value := int(map_def.environment_seed)
	if seed_value != 0:
		return seed_value
	var hash_source := String(map_def.map_id)
	if hash_source.is_empty():
		hash_source = map_def.display_name
	if hash_source.is_empty():
		hash_source = "map"
	var hashed := hash(hash_source)
	if hashed < 0:
		hashed = -hashed
	return int((hashed % 2000000000) + 1)

func _populate_map_options() -> void:
	if not _map_options:
		return
	if _map_popup:
		_map_popup.clear()
	if _map_definitions.is_empty():
		if _map_preview_texture:
			_map_preview_texture.texture = null
		_refresh_map_preview_environment(null)
		if _map_details:
			_map_details.text = "[center][color=#FF8080]No mission maps are configured.[/color][/center]"
		_available_time_ids.clear()
		_selected_map_index = -1
		_mission_config["map_id"] = StringName("")
		_mission_config["biome_id"] = StringName("")
		_mission_config["time_of_day_id"] = StringName("")
		_clear_menu_button(_map_options, _map_popup, "No Mission Maps")
		_clear_menu_button(_time_options, _time_popup, "No Times Available")
		return
	_map_options.disabled = false
	var _added_map_count := 0
	for i in range(_map_definitions.size()):
		var map_def := _map_definitions[i]
		var label := map_def.display_name
		if map_def.difficulty_label != "":
			label = "%s (%s)" % [map_def.display_name, map_def.difficulty_label]
		if _map_popup:
			_map_popup.add_item(label, i)
			var popup_index := _map_popup.get_item_index(i)
			if popup_index >= 0:
				_map_popup.set_item_as_radio_checkable(popup_index, true)
		_added_map_count += 1
	var initial_index := clampi(_selected_map_index, 0, _map_definitions.size() - 1)
	var remembered_id: StringName = _mission_config.get("map_id", StringName(""))
	if remembered_id != StringName(""):
		for i in range(_map_definitions.size()):
			if _map_definitions[i].map_id == remembered_id:
				initial_index = i
				break
	_apply_selected_map(initial_index)

func _apply_selected_map(index: int) -> void:
	if index < 0 or index >= _map_definitions.size():
		return
	_selected_map_index = index
	if _map_popup and _map_options:
		_set_menu_button_selection(_map_options, _map_popup, index)
	var map_def := _map_definitions[index]
	if _map_preview_environment and _map_preview_texture:
		_refresh_map_preview_environment(map_def)
		_map_preview_texture.texture = _map_preview_viewport.get_texture()
	elif _map_preview_texture:
		_map_preview_texture.texture = map_def.preview_texture
	_mission_config["map_id"] = map_def.map_id
	_mission_config["biome_id"] = map_def.biome_id
	_mission_config["environment_seed"] = map_def.environment_seed
	_populate_time_options(map_def)
	_refresh_map_details_text()

func _apply_mission_config_overrides() -> void:
	if _map_definitions.is_empty():
		return
	var prior_config: Dictionary = _mission_config.duplicate(true)
	var remembered_map_id: StringName = prior_config.get("map_id", StringName(""))
	var target_index := clampi(_selected_map_index if _selected_map_index >= 0 else 0, 0, _map_definitions.size() - 1)
	if remembered_map_id != StringName(""):
		for i in range(_map_definitions.size()):
			if _map_definitions[i].map_id == remembered_map_id:
				target_index = i
				break
	_selected_map_index = target_index
	_apply_selected_map(_selected_map_index)
	var explicit_biome: StringName = prior_config.get("biome_id", StringName(""))
	if explicit_biome != StringName(""):
		_mission_config["biome_id"] = explicit_biome
	var explicit_seed: int = int(prior_config.get("environment_seed", _mission_config.get("environment_seed", 0)))
	_mission_config["environment_seed"] = explicit_seed
	var explicit_time: StringName = prior_config.get("time_of_day_id", StringName(""))
	if explicit_time != StringName(""):
		for i in range(_available_time_ids.size()):
			if _available_time_ids[i] == explicit_time:
				_on_time_option_selected(i)
				break
	if _modifiers_toggle:
		_modifiers_toggle.button_pressed = bool(prior_config.get("random_events", false))
	_mission_config["random_events"] = bool(prior_config.get("random_events", false))
	_refresh_map_details_text()
	if _map_preview_environment and _selected_map_index >= 0 and _selected_map_index < _map_definitions.size():
		_refresh_map_preview_environment(_map_definitions[_selected_map_index])

func _populate_time_options(map_def: MapDefinition) -> void:
	if not _time_options:
		return
	if _time_popup:
		_time_popup.clear()
	_available_time_ids.clear()
	var candidate_ids: Array = []
	if map_def:
		candidate_ids = map_def.get_available_time_ids()
	if candidate_ids.is_empty():
		candidate_ids = _time_lookup.keys()
	var default_time_id: StringName = map_def.time_of_day_id if map_def else StringName("")
	var seen_ids: Dictionary = {}
	var time_entries: Array = []
	for raw_id in candidate_ids:
		var time_id := _to_string_name(raw_id)
		if time_id == StringName(""):
			continue
		if seen_ids.has(time_id):
			continue
		seen_ids[time_id] = true
		var time_def: TimeOfDayDefinition = _time_lookup.get(time_id, null)
		var display := time_def.display_name if time_def else String(time_id)
		time_entries.append({
			"id": time_id,
			"display": display
		})
	if time_entries.is_empty():
		_mission_config["time_of_day_id"] = StringName("")
		_clear_menu_button(_time_options, _time_popup, "No Times Available")
		return
	time_entries.sort_custom(Callable(self, "_sort_time_entries"))
	for entry in time_entries:
		var entry_id: StringName = _to_string_name(entry.get("id", StringName("")))
		var display_text := String(entry.get("display", ""))
		var new_id := _available_time_ids.size()
		if _time_popup:
			_time_popup.add_item(display_text, new_id)
			var popup_index := _time_popup.get_item_index(new_id)
			if popup_index >= 0:
				_time_popup.set_item_as_radio_checkable(popup_index, true)
		_available_time_ids.append(entry_id)
	_time_options.disabled = false
	var select_index := 0
	var remembered_time: StringName = _mission_config.get("time_of_day_id", StringName(""))
	if remembered_time != StringName(""):
		for i in range(_available_time_ids.size()):
			if _available_time_ids[i] == remembered_time:
				select_index = i
				break
	elif default_time_id != StringName(""):
		for i in range(_available_time_ids.size()):
			if _available_time_ids[i] == default_time_id:
				select_index = i
				break
	_on_time_option_selected(select_index)

func _refresh_map_details_text() -> void:
	if not _map_details:
		return
	if _selected_map_index < 0 or _selected_map_index >= _map_definitions.size():
		_map_details.text = "[center][color=#8FA3FF]Select a mission map to view terrain information.[/color][/center]"
		return
	var map_def := _map_definitions[_selected_map_index]
	var biome_label := _get_biome_display_name(map_def.biome_id)
	var time_id: StringName = _mission_config.get("time_of_day_id", StringName(""))
	var time_label := _get_time_display_name(time_id)
	var lines: Array[String] = []
	lines.append("[center][b]%s[/b][/center]" % map_def.display_name)
	if map_def.difficulty_label != "":
		lines.append("[center][color=#FFB347]%s[/color][/center]" % map_def.difficulty_label)
	if map_def.description != "":
		lines.append("[color=#C8D4FF]%s[/color]" % map_def.description)
	var detail_segments: Array[String] = []
	detail_segments.append("[color=#8FA3FF]Biome:[/color] %s" % biome_label)
	if time_label != "":
		detail_segments.append("[color=#8FA3FF]Time of Day:[/color] %s" % time_label)
	var available_time_labels: Array[String] = []
	var listed_ids: Array[StringName] = []
	for time_id_option in map_def.get_available_time_ids():
		if time_id_option == StringName(""):
			continue
		if listed_ids.has(time_id_option):
			continue
		listed_ids.append(time_id_option)
		var option_label := _get_time_display_name(time_id_option)
		if option_label != "":
			available_time_labels.append(option_label)
	if available_time_labels.size() > 1:
		detail_segments.append("[color=#8FA3FF]Available Times:[/color] %s" % ", ".join(available_time_labels))
	var seed_value: int = int(_mission_config.get("environment_seed", map_def.environment_seed))
	if seed_value > 0:
		detail_segments.append("[color=#8FA3FF]Seed:[/color] %d" % seed_value)
	if not detail_segments.is_empty():
		lines.append("\n".join(detail_segments))
	_map_details.text = "\n".join(lines)

func _get_biome_display_name(biome_id: StringName) -> String:
	if biome_id == StringName(""):
		return "Random"
	var biome: BiomeDefinition = _biome_lookup.get(biome_id, null)
	if biome and biome is BiomeDefinition:
		return biome.display_name
	return String(biome_id)

func _get_time_display_name(time_id: StringName) -> String:
	if time_id == StringName(""):
		return "Random"
	var time_def: TimeOfDayDefinition = _time_lookup.get(time_id, null)
	if time_def and time_def is TimeOfDayDefinition:
		return time_def.display_name
	return String(time_id)

func _sort_map_definitions(a: MapDefinition, b: MapDefinition) -> bool:
	if a == null and b == null:
		return false
	if a == null:
		return false
	if b == null:
		return true
	return String(a.display_name).to_lower() < String(b.display_name).to_lower()

func _sort_time_entries(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() and b.is_empty():
		return false
	if a.is_empty():
		return false
	if b.is_empty():
		return true
	var a_display := String(a.get("display", "")).to_lower()
	var b_display := String(b.get("display", "")).to_lower()
	if a_display == b_display:
		return String(a.get("id", "")).to_lower() < String(b.get("id", "")).to_lower()
	return a_display < b_display

func _on_map_option_selected(index: int) -> void:
	_apply_selected_map(index)

func _on_time_option_selected(index: int) -> void:
	if index < 0 or index >= _available_time_ids.size():
		return
	if _time_popup and _time_options:
		_set_menu_button_selection(_time_options, _time_popup, index)
	_mission_config["time_of_day_id"] = _available_time_ids[index]
	_refresh_map_details_text()
	if _map_preview_environment and _selected_map_index >= 0 and _selected_map_index < _map_definitions.size():
		_refresh_map_preview_environment(_map_definitions[_selected_map_index])

func _on_modifiers_toggled(enabled: bool) -> void:
	_mission_config["random_events"] = enabled
	if _modifiers_toggle and _modifiers_toggle.button_pressed != enabled:
		_modifiers_toggle.button_pressed = enabled

func _layout_cards() -> void:
	if _entries.is_empty():
		return
	var total_cards := _entries.size()
	_top_row_count = min(7, total_cards)
	_bottom_row_count = max(0, total_cards - _top_row_count)
	var grid_size := _grid_root.size
	if grid_size.x <= 2.0 or grid_size.y <= 2.0:
		return
	var horizontal_margin := clampf(grid_size.x * 0.09, 96.0, 220.0)
	var row_spacing := clampf(grid_size.y * 0.12, 105.0, 220.0)
	var available_width: float = max(240.0, grid_size.x - horizontal_margin * 2.0)
	var min_card_width: float = 140.0
	var max_card_width: float = 232.0
	var target_card_width: float = clampf(grid_size.x * 0.12, 160.0, max_card_width)
	var min_spacing: float = 72.0
	var preferred_spacing: float = 96.0
	var max_spacing: float = 180.0
	var card_width: float = clampf(target_card_width, min_card_width, max_card_width)
	var spacing: float = 0.0
	if _top_row_count > 1:
		var max_columns_for_width := int(floor((available_width + min_spacing) / (min_card_width + min_spacing)))
		if max_columns_for_width < 1:
			max_columns_for_width = 1
		_top_row_count = clamp(_top_row_count, 1, max_columns_for_width)
	_bottom_row_count = max(0, total_cards - _top_row_count)
	var top_spacing_count: int = max(0, _top_row_count - 1)
	card_width = clampf(target_card_width, min_card_width, max_card_width)
	if _top_row_count > 1 and top_spacing_count > 0:
		var max_card_width_for_space := (available_width - min_spacing * float(top_spacing_count)) / float(_top_row_count)
		card_width = clampf(min(card_width, max_card_width_for_space), min_card_width, max_card_width)
		spacing = (available_width - card_width * float(_top_row_count)) / float(top_spacing_count)
		spacing = clampf(spacing, min_spacing, max_spacing)
		if spacing < preferred_spacing:
			var card_width_for_preferred := clampf((available_width - preferred_spacing * float(top_spacing_count)) / float(_top_row_count), min_card_width, max_card_width)
			if card_width_for_preferred >= min_card_width:
				card_width = card_width_for_preferred
				spacing = preferred_spacing
	else:
		spacing = 0.0
	var card_height: float = card_width * 0.86
	var min_row_spacing: float = max(card_height * 0.55, 120.0)
	row_spacing = max(row_spacing, min_row_spacing)
	var top_row_width: float = card_width * float(_top_row_count) + spacing * float(top_spacing_count)
	var top_start_x: float = max((grid_size.x - top_row_width) * 0.5, horizontal_margin * 0.5)
	var top_y: float = clampf(grid_size.y * 0.08, 52.0, grid_size.y * 0.22)
	for i in range(_top_row_count):
		var entry: Dictionary = _entries[i]
		var card: CharacterCard = entry.get("card") as CharacterCard
		if card == null:
			continue
		card.anchor_left = 0.0
		card.anchor_right = 0.0
		card.anchor_top = 0.0
		card.anchor_bottom = 0.0
		card.position = Vector2(top_start_x + float(i) * (card_width + spacing), top_y)
		card.size = Vector2(card_width, card_height)
		card.custom_minimum_size = Vector2(card_width, card_height)
		card.pivot_offset = card.size * 0.5

	_bottom_row_columns = 0
	if _bottom_row_count > 0:
		var max_columns := int(floor((available_width + spacing) / (card_width + spacing)))
		_bottom_row_columns = clamp(max_columns, 1, _bottom_row_count)
		var bottom_spacing_count: int = max(0, _bottom_row_columns - 1)
		var bottom_row_width: float = card_width * float(_bottom_row_columns) + spacing * float(bottom_spacing_count)
		var bottom_start_x: float = max((grid_size.x - bottom_row_width) * 0.5, horizontal_margin * 0.5)
		var bottom_start_y: float = top_y + card_height + row_spacing
		for i in range(_bottom_row_count):
			var entry_index := _top_row_count + i
			if entry_index >= _entries.size():
				break
			var entry: Dictionary = _entries[entry_index]
			var card: CharacterCard = entry.get("card") as CharacterCard
			if card == null:
				continue
			var row_index := int(floor(float(i) / float(_bottom_row_columns)))
			var column_index := i % _bottom_row_columns
			var pos_x: float = bottom_start_x + float(column_index) * (card_width + spacing)
			var pos_y: float = bottom_start_y + float(row_index) * (card_height + row_spacing)
			card.anchor_left = 0.0
			card.anchor_right = 0.0
			card.anchor_top = 0.0
			card.anchor_bottom = 0.0
			card.position = Vector2(pos_x, pos_y)
			card.size = Vector2(card_width, card_height)
			card.custom_minimum_size = Vector2(card_width, card_height)
			card.pivot_offset = card.size * 0.5
	else:
		_bottom_row_columns = 1

func _select_index(index: int) -> void:
	if _entries.is_empty():
		return
	_selected_index = wrapi(index, 0, _entries.size())
	for i in range(_entries.size()):
		var card: CharacterCard = _entries[i].get("card") as CharacterCard
		if card:
			card.set_selected(i == _selected_index)
	var entry: Dictionary = _entries[_selected_index]
	if entry.get("type") == "random":
		_update_random_details()
	else:
		var character: CharacterData = entry.get("character")
		_update_character_details(character)
	_update_buttons()

func _get_card_texture(character: CharacterData) -> Texture2D:
	if character == null:
		return null
	if character.portrait_texture:
		return character.portrait_texture
	if character.burst_texture:
		return character.burst_texture
	return character.sprite_sheet

func _update_character_details(character: CharacterData) -> void:
	if character == null:
		_update_random_details()
		return
	_details_content.visible = true
	_random_details.visible = false
	_character_name_label.text = character.display_name
	for key in STAT_META:
		var row_variant: Variant = _stat_rows.get(key["key"], null)
		if row_variant is Dictionary:
			var row: Dictionary = row_variant
			var bar: ProgressBar = row.get("bar")
			var value_label: Label = row.get("value")
			var max_value: float = float(row.get("max", 100))
			var value: float = float(character.get(key["key"]))
			bar.max_value = max_value
			bar.value = clamp(value, 0.0, max_value)
			value_label.text = str(int(round(value)))
	_weapon_title.text = character.weapon_name
	_weapon_type.text = "Type: %s" % character.weapon_type
	_weapon_description.text = character.weapon_description
	_weapon_special_title.text = character.weapon_special_name
	_weapon_special_description.text = character.weapon_special_description
	_burst_title.text = character.burst_name
	_burst_description.text = character.burst_description
	_set_animation_frames(character)

func _update_random_details() -> void:
	_details_content.visible = false
	_random_details.visible = true
	_character_sprite.texture = null
	_current_frames = []

func _set_animation_frames(character: CharacterData) -> void:
	var cache_key := character.code_name
	if _sprite_cache.has(cache_key):
		var cached_variant: Variant = _sprite_cache.get(cache_key)
		if cached_variant is Dictionary:
			var cached: Dictionary = cached_variant
			_current_frames = cached.get("frames", [])
			_current_frame_fps = cached.get("fps", 6.0)
			if character.has_sprite_animation() and _current_frames.size() <= 1:
				var refreshed_frames := _slice_sprite_sheet(character)
				if not refreshed_frames.is_empty():
					_current_frames = refreshed_frames
					_current_frame_fps = character.sprite_animation_fps
					_sprite_cache[cache_key] = {
						"frames": _current_frames,
						"fps": _current_frame_fps
					}
	else:
		var frames: Array = []
		var fps := character.sprite_animation_fps
		if character.sprite_sheet and character.sprite_sheet_columns > 0 and character.sprite_sheet_rows > 0:
			frames = _slice_sprite_sheet(character)
		if frames.is_empty() and character.portrait_texture:
			frames = [character.portrait_texture]
		elif frames.is_empty() and character.sprite_sheet:
			frames = [character.sprite_sheet]
		_sprite_cache[cache_key] = {
			"frames": frames,
			"fps": fps
		}
		_current_frames = frames
		_current_frame_fps = fps
	_animation_time = 0.0
	if _current_frames.is_empty():
		_character_sprite.texture = null
	else:
		_character_sprite.texture = _current_frames[0]

func _slice_sprite_sheet(character: CharacterData) -> Array:
	var frames: Array = []
	var texture := character.sprite_sheet
	if texture == null:
		return frames
	var image := texture.get_image()
	if image == null or image.is_empty():
		return frames
	if image.is_compressed():
		var err := image.decompress()
		if err != OK:
			return frames
	image.convert(Image.FORMAT_RGBA8)
	var columns: int = max(1, character.sprite_sheet_columns)
	var rows: int = max(1, character.sprite_sheet_rows)
	var frame_width := int(round(float(image.get_width()) / float(columns)))
	var frame_height := int(round(float(image.get_height()) / float(rows)))
	if frame_width <= 0 or frame_height <= 0:
		return frames
	var sampled_rows: int = min(rows, 1)
	for y in range(sampled_rows):
		for x in range(columns):
			var region := Rect2i(Vector2i(x * frame_width, y * frame_height), Vector2i(frame_width, frame_height))
			if region.position.x + region.size.x > image.get_width():
				continue
			if region.position.y + region.size.y > image.get_height():
				continue
			var frame_image := image.get_region(region)
			var frame_texture := ImageTexture.create_from_image(frame_image)
			frames.append(frame_texture)
	return frames

func _update_buttons() -> void:
	var allow_confirm := _stage == MenuStage.CONFIGURING and not _entries.is_empty()
	_confirm_button.disabled = not allow_confirm

func _compute_details_target_y() -> float:
	var viewport_height := float(get_viewport_rect().size.y)
	if viewport_height <= 0.0:
		return DETAILS_TARGET_Y_1080P
	var height_scale := viewport_height / 1080.0
	return DETAILS_TARGET_Y_1080P * height_scale

func _compute_configuration_hidden_y() -> float:
	var viewport_height := float(get_viewport_rect().size.y)
	if viewport_height <= 0.0:
		return _configuration_base_position.y + CONFIGURATION_ENTRY_OFFSET
	var offset: float = maxf(CONFIGURATION_ENTRY_OFFSET, viewport_height * 0.35)
	return _configuration_base_position.y + offset


func _refresh_button_positions(adjust_position: bool = false) -> void:
	if _buttons_bar == null:
		return
	_buttons_entry_position_y = _compute_buttons_entry_y()
	_buttons_raised_position_y = _compute_buttons_raised_y()
	if not adjust_position:
		return
	if _transition_tween and _transition_tween.is_running():
		return
	match _stage:
		MenuStage.CONFIGURING:
			_buttons_bar.position = Vector2(_buttons_base_position.x, _buttons_raised_position_y)
		MenuStage.SELECTING:
			_buttons_bar.position = _buttons_base_position
		_:
			pass


func _compute_buttons_entry_y() -> float:
	var base_y := _buttons_base_position.y
	var button_height := maxf(_buttons_bar.size.y, _buttons_bar.get_combined_minimum_size().y)
	var offset := maxf(BUTTON_ENTRY_OFFSET, button_height * 0.75)
	return base_y + offset


func _compute_buttons_raised_y() -> float:
	var base_y := _buttons_base_position.y
	var button_height := maxf(_buttons_bar.size.y, _buttons_bar.get_combined_minimum_size().y)
	var offset := maxf(BUTTONS_RAISE, button_height * 0.6)
	var viewport_height := float(get_viewport_rect().size.y)
	if viewport_height > 0.0:
		offset = clampf(offset, 48.0, viewport_height * 0.16)
	return base_y - offset

func _process(delta: float) -> void:
	if _current_frames.size() <= 1:
		return
	var fps: float = max(_current_frame_fps, 0.1)
	_animation_time += delta
	var frame_duration: float = 1.0 / fps
	var frame_index := int(_animation_time / frame_duration) % _current_frames.size()
	_character_sprite.texture = _current_frames[frame_index]

func _on_card_pressed(card_node) -> void:
	var card: CharacterCard = card_node as CharacterCard
	if card == null:
		return
	var index := _index_for_card(card)
	if index < 0:
		return
	_select_index(index)
	if card.is_random:
		_on_confirm_pressed()
		return
	if _stage == MenuStage.SELECTING:
		_enter_configuration_mode()

func _on_card_hovered(card_node) -> void:
	var card: CharacterCard = card_node as CharacterCard
	if card == null:
		return
	if _stage != MenuStage.SELECTING:
		return
	var index := _index_for_card(card)
	if index >= 0 and index != _selected_index:
		_select_index(index)

func _index_for_card(card_node) -> int:
	for i in range(_entries.size()):
		if _entries[i].get("card") == card_node:
			return i
	return -1

func _enter_configuration_mode() -> void:
	if _stage != MenuStage.SELECTING:
		return
	if _entries.is_empty():
		return
	var entry: Dictionary = _entries[_selected_index]
	if entry.get("type") != "character":
		return
	_stage = MenuStage.TRANSITIONING as MenuStage
	if _transition_tween and _transition_tween.is_running():
		_transition_tween.kill()
	_title_bar.position = _title_bar_base_position
	_grid_root.position = _grid_base_position
	_grid_root.visible = true
	_grid_root.modulate = Color(1, 1, 1, 1)
	_configuration_panel.visible = true
	_configuration_panel.modulate = Color(1, 1, 1, 0)
	_configuration_hidden_position_y = _compute_configuration_hidden_y()
	_configuration_panel.position = Vector2(_configuration_base_position.x, _configuration_hidden_position_y)
	_buttons_bar.visible = true
	_buttons_bar.modulate = Color(1, 1, 1, 0)
	_refresh_button_positions(false)
	_buttons_bar.position = Vector2(_buttons_base_position.x, _buttons_entry_position_y)
	_details_panel.position = Vector2(_details_base_position.x, _details_base_position.y + DETAILS_ENTRY_OFFSET)
	_grid_root.mouse_filter = _mouse_filter(Control.MOUSE_FILTER_IGNORE)
	if _content_root:
		_set_mouse_filter(_content_root, _mouse_filter(Control.MOUSE_FILTER_IGNORE), "ContentRoot")
	var duration := 0.6
	var title_target_y := _title_bar_base_position.y - (_title_bar.size.y + 60.0)
	var grid_height: float = max(_grid_root.size.y, 300.0)
	var grid_target_y: float = _grid_base_position.y - (grid_height + 160.0)
	_grid_hidden_position_y = grid_target_y
	var configuration_target_y: float = _configuration_base_position.y - CONFIG_PANEL_RAISE
	var details_target_y: float = minf(_compute_details_target_y(), configuration_target_y - 12.0)
	_details_raised_position_y = clampf(details_target_y, DETAILS_TARGET_MIN_Y, _details_base_position.y - 12.0)
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.finished.connect(_on_configuration_transition_finished)
	_transition_tween.tween_property(_title_bar, "position:y", title_target_y, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(_grid_root, "position:y", grid_target_y, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(_grid_root, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_transition_tween.tween_property(_details_panel, "position:y", _details_raised_position_y, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(_configuration_panel, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(_configuration_panel, "position:y", _configuration_base_position.y - CONFIG_PANEL_RAISE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(_buttons_bar, "position:y", _buttons_raised_position_y, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(_buttons_bar, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_update_buttons()

func _on_configuration_transition_finished() -> void:
	_transition_tween = null
	_grid_root.visible = false
	_stage = MenuStage.CONFIGURING as MenuStage
	if _map_options:
		_map_options.grab_focus()
	_update_buttons()

func _on_confirm_pressed() -> void:
	if _entries.is_empty():
		return
	var entry: Dictionary = _entries[_selected_index]
	var chosen: CharacterData = null
	if entry.get("type") == "random":
		var pool: Array[CharacterData] = []
		for candidate in _entries:
			if candidate.get("type") == "character":
				var character: CharacterData = candidate.get("character")
				if character:
					pool.append(character)
		if pool.is_empty():
			return
		var random_index := _rng.randi_range(0, pool.size() - 1)
		chosen = pool[random_index]
	else:
		chosen = entry.get("character")
	if chosen:
		var payload := {
			"map_id": _mission_config.get("map_id", StringName("")),
			"biome_id": _mission_config.get("biome_id", StringName("")),
			"time_of_day_id": _mission_config.get("time_of_day_id", StringName("")),
			"environment_seed": int(_mission_config.get("environment_seed", 0)),
			"random_events": bool(_mission_config.get("random_events", false))
		}
		emit_signal("character_confirmed", chosen, payload)

func _on_back_pressed() -> void:
	_emit_back_requested()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_emit_back_requested()
		get_viewport().set_input_as_handled()
		return
	if _entries.is_empty():
		return
	if _stage != MenuStage.SELECTING:
		if event.is_action_pressed("ui_accept") and _stage == MenuStage.CONFIGURING:
			_on_confirm_pressed()
		return
	if event.is_action_pressed("ui_left"):
		_select_index(_selected_index - 1)
	if event.is_action_pressed("ui_right"):
		_select_index(_selected_index + 1)
	if event.is_action_pressed("ui_up"):
		_move_vertical(-1)
	if event.is_action_pressed("ui_down"):
		_move_vertical(1)
	if event.is_action_pressed("ui_accept"):
		var entry: Dictionary = _entries[_selected_index]
		if entry.get("type") == "random":
			_on_confirm_pressed()
		else:
			_enter_configuration_mode()

func _move_vertical(direction: int) -> void:
	if _stage != MenuStage.SELECTING:
		return
	if direction < 0:
		if _selected_index >= _top_row_count and _top_row_count > 0:
			var bottom_index := _selected_index - _top_row_count
			var target_top := bottom_index % _bottom_row_columns
			if target_top < _top_row_count:
				_select_index(target_top)
	elif direction > 0:
		if _selected_index < _top_row_count and _bottom_row_count > 0:
			var target_bottom := _top_row_count + (_selected_index % _bottom_row_columns)
			if target_bottom < _entries.size():
				_select_index(target_bottom)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _grid_root:
		_layout_cards()
		if _configuration_panel:
			_configuration_hidden_position_y = _compute_configuration_hidden_y()
			if _stage == MenuStage.SELECTING:
				_configuration_panel.position = Vector2(_configuration_base_position.x, _configuration_hidden_position_y)
		_refresh_button_positions(not (_transition_tween and _transition_tween.is_running()))

func _exit_configuration_mode() -> void:
	if _stage != MenuStage.CONFIGURING:
		return
	if _transition_tween and _transition_tween.is_running():
		_transition_tween.kill()
		_transition_tween = null
	_stage = MenuStage.TRANSITIONING as MenuStage
	_grid_root.visible = true
	_grid_root.modulate = Color(1, 1, 1, 0)
	_grid_root.position = Vector2(_grid_base_position.x, _grid_hidden_position_y)
	_grid_root.mouse_filter = _mouse_filter(Control.MOUSE_FILTER_PASS)
	_details_panel.position = Vector2(_details_base_position.x, _details_raised_position_y)
	_configuration_hidden_position_y = _compute_configuration_hidden_y()
	var duration := 0.6
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.finished.connect(_on_exit_transition_finished)
	_transition_tween.tween_property(_title_bar, "position:y", _title_bar_base_position.y, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(_grid_root, "position:y", _grid_base_position.y, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(_grid_root, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(_details_panel, "position:y", _details_base_position.y, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(_configuration_panel, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(_configuration_panel, "position:y", _configuration_hidden_position_y, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(_buttons_bar, "position:y", _buttons_base_position.y, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(_buttons_bar, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _on_exit_transition_finished() -> void:
	_transition_tween = null
	_configuration_panel.visible = false
	_configuration_panel.position = Vector2(_configuration_base_position.x, _configuration_hidden_position_y)
	_configuration_panel.modulate = Color(1, 1, 1, 0)
	_buttons_bar.visible = false
	_buttons_bar.position = _buttons_base_position
	_buttons_bar.modulate = Color(1, 1, 1, 1)
	_grid_root.visible = true
	_grid_root.position = _grid_base_position
	_grid_root.modulate = Color(1, 1, 1, 1)
	_grid_root.mouse_filter = _mouse_filter(Control.MOUSE_FILTER_PASS)
	_details_panel.position = _details_base_position
	if _content_root:
		_content_root.mouse_filter = _content_root_default_mouse_filter
	_stage = MenuStage.SELECTING as MenuStage
	_update_buttons()

func _emit_back_requested() -> void:
	if _stage == MenuStage.CONFIGURING:
		_exit_configuration_mode()
	elif _stage == MenuStage.TRANSITIONING:
		return
	else:
		emit_signal("back_requested")

func _to_string_name(value) -> StringName:
	if value is StringName:
		return value
	return StringName(String(value))
