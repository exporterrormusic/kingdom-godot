extends Control
class_name AchievementsMenu

signal closed

const GENERAL_FILTER := "GENERAL"
const DEFAULT_PORTRAIT_PATH := "res://assets/images/example_character.png"
const CharacterRosterResource := preload("res://resources/characters/characters.tres")
const PretendardBold := preload("res://resources/fonts/pretendard_bold.tres")
const PretendardMedium := preload("res://resources/fonts/pretendard_medium.tres")
const FuturaFont := preload("res://resources/fonts/futura_condensed_extra_bold.tres")

const CHARACTER_NORMAL_COLOR := Color(0.121, 0.129, 0.176, 0.95)
const CHARACTER_HOVER_COLOR := Color(0.196, 0.207, 0.286, 0.98)
const CHARACTER_SELECTED_COLOR := Color(0.313, 0.321, 0.423, 1.0)
const CHARACTER_BORDER_COLOR := Color(0.419, 0.431, 0.529, 0.9)
const ACHIEVEMENT_BG_COLOR := Color(0.133, 0.137, 0.188, 0.94)
const ACHIEVEMENT_BORDER_COLOR := Color(0.337, 0.345, 0.447, 0.9)
const ACHIEVEMENT_UNLOCKED_COLOR := Color(0.392, 0.86, 0.549, 1.0)
const ACHIEVEMENT_LOCKED_COLOR := Color(0.705, 0.705, 0.756, 1.0)
const ACHIEVEMENT_PROGRESS_BG := Color(0.211, 0.215, 0.286, 1.0)
const ACHIEVEMENT_PROGRESS_FG := Color(0.533, 0.611, 0.980, 1.0)

@onready var _character_scroll: ScrollContainer = %CharacterScroll
@onready var _character_list: VBoxContainer = %CharacterList
@onready var _achievement_scroll: ScrollContainer = %AchievementScroll
@onready var _achievement_list: VBoxContainer = %AchievementList
@onready var _title_label: Label = %TitleLabel
@onready var _header_label: Label = %HeaderLabel
@onready var _empty_state_label: Label = %EmptyStateLabel

var _achievement_service: AchievementService = null
var _roster: CharacterRoster = null
var _default_portrait: Texture2D = null
var _character_entries: Array = []
var _definitions: Array = []
var _definition_property_cache: Dictionary = {}
var _selected_filter: String = GENERAL_FILTER
var _character_button_group: ButtonGroup = ButtonGroup.new()

func _ready() -> void:
	set_process_unhandled_input(true)
	set_process_input(true)
	# Removed close button and instructions label handling
	_configure_title_label()
	_configure_header_label()
	_resolve_dependencies()
	_connect_service_signals()
	_reload_definitions()
	_build_character_list()
	_select_filter(GENERAL_FILTER)

func set_achievement_service(service: AchievementService) -> void:
	_achievement_service = service
	_connect_service_signals()
	if is_inside_tree():
		_reload_definitions()
		_update_character_counts()
		_select_filter(_selected_filter)

func set_roster(roster: CharacterRoster) -> void:
	_roster = roster
	if _roster and _roster.has_method("ensure_loaded"):
		_roster.ensure_loaded()
	if is_inside_tree():
		_build_character_list()
		_update_character_counts()

func _resolve_dependencies() -> void:
	if not _achievement_service:
		_achievement_service = _resolve_achievement_service()
	if not _roster:
		_roster = _resolve_roster_resource()

func _connect_service_signals() -> void:
	if not _achievement_service:
		return
	if not _achievement_service.achievement_unlocked.is_connected(_on_achievement_unlocked):
		_achievement_service.achievement_unlocked.connect(_on_achievement_unlocked)

func _resolve_achievement_service() -> AchievementService:
	if not get_tree():
		return null
	var root := get_tree().root
	if not root:
		return null
	if root.has_node("/root/AchievementService"):
		var service_node := root.get_node("/root/AchievementService")
		if service_node is AchievementService:
			return service_node
	return null

func _resolve_roster_resource() -> CharacterRoster:
	if CharacterRosterResource:
		var roster: CharacterRoster = CharacterRosterResource.duplicate(true)
		if roster and roster.has_method("ensure_loaded"):
			roster.ensure_loaded()
		return roster
	return null

func _reload_definitions() -> void:
	_definitions.clear()
	_definition_property_cache.clear()
	if _achievement_service:
		var defs := _achievement_service.get_all_definitions()
		if defs:
			for definition in defs:
				if definition:
					_definitions.append(definition)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close_menu()
		get_viewport().set_input_as_handled()

func _build_character_list() -> void:
	if not _character_list:
		return
	for child in _character_list.get_children():
		child.queue_free()
	_character_entries.clear()

	var general_info := {
		"code": GENERAL_FILTER,
		"display": "General",
		"portrait": null
	}
	_character_entries.append(_create_character_entry(general_info))

	if _roster and _roster.has_method("ensure_loaded"):
		_roster.ensure_loaded()
	var characters: Array = []
	if _roster:
		characters = _roster.characters
	for character in characters:
		if character == null:
			continue
		var code := ""
		var display := ""
		var portrait: Texture2D = null
		if character.has_method("get"):
			code = String(character.get("code_name"))
			display = String(character.get("display_name"))
			portrait = character.get("portrait_texture") if character.has_method("get") else null
		if code == "":
			continue
		if display == "":
			display = code.capitalize()
		var entry_info := {
			"code": code,
			"display": display,
			"portrait": portrait
		}
		_character_entries.append(_create_character_entry(entry_info))

	_update_character_counts()

func _create_character_entry(info: Dictionary) -> Dictionary:
	if not _character_list:
		return {}
	var entry_wrapper := MarginContainer.new()
	entry_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	entry_wrapper.add_theme_constant_override("margin_left", 0)
	entry_wrapper.add_theme_constant_override("margin_right", 16)
	entry_wrapper.add_theme_constant_override("margin_top", 0)
	entry_wrapper.add_theme_constant_override("margin_bottom", 0)

	var button := Button.new()
	button.toggle_mode = true
	button.button_group = _character_button_group
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.custom_minimum_size = Vector2(0, 116)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_FILL
	button.add_theme_constant_override("content_margin_left", 16)
	button.add_theme_constant_override("content_margin_right", 0)
	button.add_theme_constant_override("content_margin_top", 8)
	button.add_theme_constant_override("content_margin_bottom", 8)
	_apply_character_button_styles(button)

	var layout := HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout.custom_minimum_size = Vector2(0, 100)
	layout.add_theme_constant_override("separation", 16)
	button.add_child(layout)

	var portrait_slot := CenterContainer.new()
	portrait_slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(portrait_slot)

	var portrait_wrapper := MarginContainer.new()
	portrait_wrapper.add_theme_constant_override("margin_left", 2)
	portrait_wrapper.add_theme_constant_override("margin_right", 4)
	portrait_wrapper.add_theme_constant_override("margin_top", 2)
	portrait_wrapper.add_theme_constant_override("margin_bottom", 2)
	portrait_slot.add_child(portrait_wrapper)

	var portrait_panel := Panel.new()
	portrait_panel.custom_minimum_size = Vector2(116, 116)
	portrait_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_panel.add_theme_stylebox_override("panel", _make_portrait_style())
	portrait_wrapper.add_child(portrait_panel)

	var portrait_texture := TextureRect.new()
	portrait_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_texture.custom_minimum_size = Vector2(116, 116)
	portrait_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_texture.texture = info.get("portrait") if info.has("portrait") else null
	if portrait_texture.texture == null and info.get("code") != GENERAL_FILTER:
		var fallback := _get_default_portrait()
		if fallback:
			portrait_texture.texture = fallback
	portrait_panel.add_child(portrait_texture)

	if portrait_texture.texture == null:
		var icon_label := Label.new()
		icon_label.text = "🏆"
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_override("font", FuturaFont)
		icon_label.add_theme_font_size_override("font_size", 60)
		icon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		icon_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		portrait_panel.add_child(icon_label)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_column.alignment = BoxContainer.ALIGNMENT_CENTER
	text_column.add_theme_constant_override("separation", 4)
	layout.add_child(text_column)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout.add_child(spacer)

	var name_label := Label.new()
	name_label.text = String(info.get("display", ""))
	name_label.add_theme_font_override("font", PretendardBold)
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = false
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	text_column.add_child(name_label)

	var count_wrapper := MarginContainer.new()
	count_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_END
	count_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	count_wrapper.add_theme_constant_override("margin_left", 8)
	count_wrapper.add_theme_constant_override("margin_right", 0)
	count_wrapper.add_theme_constant_override("margin_top", 4)
	count_wrapper.add_theme_constant_override("margin_bottom", 4)
	layout.add_child(count_wrapper)

	var count_panel := Panel.new()
	count_panel.custom_minimum_size = Vector2(148, 0)
	count_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	count_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_panel.add_theme_stylebox_override("panel", _make_count_style())
	count_wrapper.add_child(count_panel)

	var count_center := CenterContainer.new()
	count_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	count_panel.add_child(count_center)

	var count_label := Label.new()
	count_label.text = "0/0"
	count_label.add_theme_font_override("font", PretendardBold)
	count_label.add_theme_font_size_override("font_size", 40)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	count_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	count_label.clip_text = false
	count_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	count_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	count_center.add_child(count_label)

	var code := String(info.get("code", GENERAL_FILTER))
	button.set_meta("code", code)
	button.pressed.connect(Callable(self, "_on_character_button_pressed").bind(code))
	entry_wrapper.add_child(button)
	_character_list.add_child(entry_wrapper)

	return {
		"code": code,
		"display": String(info.get("display", code)),
		"button": button,
		"count_label": count_label
	}

func _make_portrait_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.149, 0.152, 0.211, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = CHARACTER_BORDER_COLOR
	return style

func _apply_character_button_styles(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_character_stylebox(CHARACTER_NORMAL_COLOR))
	button.add_theme_stylebox_override("hover", _make_character_stylebox(CHARACTER_HOVER_COLOR))
	button.add_theme_stylebox_override("pressed", _make_character_stylebox(CHARACTER_SELECTED_COLOR))
	button.add_theme_stylebox_override("focus", _make_character_stylebox(CHARACTER_HOVER_COLOR))

func _make_character_stylebox(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = CHARACTER_BORDER_COLOR
	return style

func _on_character_button_pressed(code: String) -> void:
	if code == _selected_filter:
		return
	_select_filter(code)

func _select_filter(filter_code: String) -> void:
	_selected_filter = filter_code
	for entry in _character_entries:
		var button: Button = entry.get("button")
		if button:
			button.button_pressed = (entry.get("code") == filter_code)
	_update_header(filter_code)
	_rebuild_achievement_list(filter_code)
	_update_character_counts()
	if _character_scroll:
		for entry in _character_entries:
			if entry.get("code") == filter_code:
				var button: Control = entry.get("button")
				_character_scroll.ensure_control_visible(button)
				break

func _update_header(_filter_code: String) -> void:
	if _header_label:
		_header_label.visible = false
		_header_label.text = ""

func _rebuild_achievement_list(filter_code: String) -> void:
	if not _achievement_list:
		return
	for child in _achievement_list.get_children():
		child.queue_free()

	var definitions := _filter_definitions_for(filter_code)
	_empty_state_label.visible = definitions.is_empty()
	for definition in definitions:
		var item := _create_achievement_item(definition)
		if item:
			_achievement_list.add_child(item)
	if _achievement_scroll:
		_achievement_scroll.set_v_scroll(0)

func _filter_definitions_for(filter_code: String) -> Array:
	if filter_code == GENERAL_FILTER:
		return _definitions.duplicate()
	var matches: Array = []
	for definition in _definitions:
		if not definition:
			continue
		var category := String(_get_definition_value(definition, "category", "")).to_lower()
		if category == filter_code.to_lower():
			matches.append(definition)
	return matches

func _get_definition_value(definition, property: String, default_value = null):
	if not definition:
		return default_value
	if definition is Dictionary:
		return definition.get(property, default_value)
	if definition is Object and _definition_has_property(definition, property):
		return definition.get(property)
	return default_value

func _definition_has_property(definition: Object, property: String) -> bool:
	if not definition:
		return false
	var cache: Dictionary
	if _definition_property_cache.has(definition):
		cache = _definition_property_cache[definition]
	else:
		cache = {}
		for property_data in definition.get_property_list():
			if property_data.has("name"):
				cache[property_data["name"]] = true
		_definition_property_cache[definition] = cache
	return cache.has(property)

func _create_achievement_item(definition) -> Control:
	if definition == null:
		return null
	var achievement_id := String(_get_definition_value(definition, "id", ""))
	var achievement_name := String(_get_definition_value(definition, "name", achievement_id))
	var description := String(_get_definition_value(definition, "description", ""))
	var category := String(_get_definition_value(definition, "category", "General"))
	var target := int(_get_definition_value(definition, "target_value", 0))
	var stat_key := String(_get_definition_value(definition, "stat_key", ""))

	var unlocked := _achievement_service and achievement_id != "" and _achievement_service.is_unlocked(achievement_id)
	var progress_value: int = 0
	if _achievement_service and stat_key != "":
		progress_value = int(_achievement_service.get_stat_value(stat_key))

	var container := PanelContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_stylebox_override("panel", _make_achievement_stylebox(unlocked))

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(layout)

	var heading_row := HBoxContainer.new()
	heading_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	heading_row.add_theme_constant_override("separation", 16)
	layout.add_child(heading_row)

	var name_label := Label.new()
	name_label.text = achievement_name
	name_label.add_theme_font_override("font", PretendardBold)
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(name_label)

	var category_badge := Label.new()
	category_badge.text = category.to_upper()
	category_badge.add_theme_font_override("font", PretendardMedium)
	category_badge.add_theme_font_size_override("font_size", 18)
	category_badge.modulate = Color(0.6, 0.72, 0.95, 1.0)
	category_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	category_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	category_badge.size_flags_horizontal = Control.SIZE_SHRINK_END
	heading_row.add_child(category_badge)

	var description_label := Label.new()
	description_label.text = description
	description_label.add_theme_font_override("font", PretendardMedium)
	description_label.add_theme_font_size_override("font_size", 22)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	layout.add_child(description_label)

	var progress_row := HBoxContainer.new()
	progress_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	progress_row.add_theme_constant_override("separation", 16)
	layout.add_child(progress_row)

	var progress_label := Label.new()
	progress_label.add_theme_font_override("font", PretendardMedium)
	progress_label.add_theme_font_size_override("font_size", 20)
	if unlocked:
		progress_label.text = "Unlocked"
		progress_label.modulate = ACHIEVEMENT_UNLOCKED_COLOR
	else:
		var clamped := int(min(progress_value, target))
		var requirement := int(max(target, 1))
		progress_label.text = "%d / %d" % [clamped, requirement]
		progress_label.modulate = ACHIEVEMENT_LOCKED_COLOR
	progress_row.add_child(progress_label)

	if not unlocked and target > 0:
		var progress_bar := ProgressBar.new()
		progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress_bar.max_value = target
		progress_bar.value = clamp(progress_value, 0, target)
		progress_bar.show_percentage = false
		progress_bar.add_theme_stylebox_override("panel", _make_progress_panel_style())
		progress_bar.add_theme_stylebox_override("fill", _make_progress_fill_style())
		progress_row.add_child(progress_bar)
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress_row.add_child(spacer)

	return container

func _configure_title_label() -> void:
	if not _title_label:
		return
	_title_label.anchor_left = 0.0
	_title_label.anchor_right = 1.0
	_title_label.offset_left = 0.0
	_title_label.offset_right = 0.0
	_title_label.offset_top = 0.0
	_title_label.offset_bottom = 0.0
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _configure_header_label() -> void:
	if not _header_label:
		return
	_header_label.visible = false
	_header_label.text = ""

func _make_achievement_stylebox(unlocked: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ACHIEVEMENT_BG_COLOR
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = ACHIEVEMENT_UNLOCKED_COLOR if unlocked else ACHIEVEMENT_BORDER_COLOR
	return style

func _make_progress_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ACHIEVEMENT_PROGRESS_BG
	return style

func _make_progress_fill_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ACHIEVEMENT_PROGRESS_FG
	return style

func _make_count_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.16, 0.21, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = CHARACTER_BORDER_COLOR
	return style

func _get_default_portrait() -> Texture2D:
	if _default_portrait:
		return _default_portrait
	if ResourceLoader.exists(DEFAULT_PORTRAIT_PATH):
		var tex := load(DEFAULT_PORTRAIT_PATH)
		if tex is Texture2D:
			_default_portrait = tex
	return _default_portrait

func _update_character_counts() -> void:
	for entry in _character_entries:
		var count_label: Label = entry.get("count_label")
		if not count_label:
			continue
		var code := String(entry.get("code"))
		var counts := _calculate_counts_for(code)
		count_label.text = "%d/%d" % [counts.get("unlocked", 0), counts.get("total", 0)]

func _calculate_counts_for(filter_code: String) -> Dictionary:
	var defs := _filter_definitions_for(filter_code)
	var total := defs.size()
	var unlocked := 0
	if _achievement_service:
		for definition in defs:
			if not definition:
				continue
			var identifier := String(_get_definition_value(definition, "id", ""))
			if identifier != "" and _achievement_service.is_unlocked(identifier):
				unlocked += 1
	return {
		"unlocked": unlocked,
		"total": total
	}

func _on_achievement_unlocked(_id: String) -> void:
	_reload_definitions()
	_update_character_counts()
	_rebuild_achievement_list(_selected_filter)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()

func _move_selection(direction: int) -> void:
	if _character_entries.is_empty():
		return
	var index := 0
	for i in _character_entries.size():
		if _character_entries[i].get("code") == _selected_filter:
			index = i
			break
	index = clamp(index + direction, 0, _character_entries.size() - 1)
	var target_code := String(_character_entries[index].get("code"))
	_select_filter(target_code)

func close_menu() -> void:
	emit_signal("closed")
	queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		set_process_unhandled_input(false)
	elif what == NOTIFICATION_READY and visible:
		set_process_unhandled_input(true)
