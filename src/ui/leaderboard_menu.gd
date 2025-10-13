extends Control
class_name LeaderboardMenu

signal closed

const PretendardBold := preload("res://resources/fonts/pretendard_bold.tres")
const PretendardMedium := preload("res://resources/fonts/pretendard_medium.tres")
const FuturaBold := preload("res://resources/fonts/futura_condensed_extra_bold.tres")
const BACKGROUND_COLOR := Color(0.117, 0.125, 0.176, 0.96)
const BORDER_COLOR := Color(0.376, 0.384, 0.486, 0.9)
const ENTRY_BG_COLOR := Color(0.145, 0.149, 0.207, 0.92)
const ENTRY_BORDER_COLOR := Color(0.341, 0.341, 0.439, 0.9)
const ENTRY_SEPARATOR_COLOR := Color(0.329, 0.337, 0.427, 0.65)
const RANK_COLOR_PRIMARY := Color(0.996, 0.843, 0.392, 1.0)
const LABEL_COLOR := Color(0.784, 0.792, 0.878, 1.0)
const VALUE_COLOR := Color(0.996, 0.973, 0.902, 1.0)
const MUTED_VALUE_COLOR := Color(0.592, 0.6, 0.694, 1.0)
const MAX_VISIBLE_ENTRIES := 10
const ENTRIES_PER_COLUMN := 5
const ENTRY_COLUMN_STRETCH := {
	"rank": 0.75,
	"portrait": 0.9,
	"name": 2.6,
	"score": 1.25,
	"wave": 1.1
}
const LEGACY_PORTRAIT_TEMPLATE := "res://assets/images/Characters/%s/portrait-sq.png"

@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _left_column: VBoxContainer = %LeftColumn
@onready var _right_column: VBoxContainer = %RightColumn
@onready var _columns_scroll: ScrollContainer = %ColumnsScroll
@onready var _empty_state_label: Label = %EmptyStateLabel
@onready var _cores_label: Label = %CoresLabel

var _leaderboard_service: LeaderboardService = null
var _roster: CharacterRoster = null
var _portrait_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	set_process_unhandled_input(true)
	_update_static_labels()
	_refresh_entries()

func set_leaderboard_service(service: LeaderboardService) -> void:
	if _leaderboard_service and _leaderboard_service.records_updated.is_connected(_on_records_updated):
		_leaderboard_service.records_updated.disconnect(_on_records_updated)
	_leaderboard_service = service
	if _leaderboard_service and not _leaderboard_service.records_updated.is_connected(_on_records_updated):
		_leaderboard_service.records_updated.connect(_on_records_updated)
	_refresh_entries()

func set_roster(roster: CharacterRoster) -> void:
	_roster = roster
	if _roster and _roster.has_method("ensure_loaded"):
		_roster.ensure_loaded()
	if _leaderboard_service:
		_leaderboard_service.set_roster(_roster)
	_refresh_entries()

func close_menu() -> void:
	emit_signal("closed")
	queue_free()
func _input(event: InputEvent) -> void:
	if (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")) and not event.is_echo():
		_handle_escape()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_handle_escape()
		accept_event()

func _handle_escape() -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.set_input_as_handled()
	close_menu()

func _update_static_labels() -> void:
	if _title_label:
		_title_label.text = "LEADERBOARDS"
	if _subtitle_label:
		_subtitle_label.text = ""
		_subtitle_label.visible = false

func _on_records_updated() -> void:
	_refresh_entries()

func _refresh_entries() -> void:
	_clear_columns()
	var entries: Array = []
	if _leaderboard_service:
		entries = _leaderboard_service.get_ranked_entries(MAX_VISIBLE_ENTRIES)
	_update_cores_label()
	if entries.is_empty():
		_empty_state_label.visible = true
		return
	_empty_state_label.visible = false
	var left_entries := entries.slice(0, ENTRIES_PER_COLUMN)
	var right_entries := []
	if entries.size() > ENTRIES_PER_COLUMN:
		right_entries = entries.slice(ENTRIES_PER_COLUMN, entries.size())
	var rank := 1
	for entry in left_entries:
		var control := _create_entry_control(entry, rank)
		_left_column.add_child(control)
		rank += 1
	for entry in right_entries:
		var control := _create_entry_control(entry, rank)
		_right_column.add_child(control)
		rank += 1
	if _columns_scroll:
		_columns_scroll.set_v_scroll(0)

func _update_cores_label() -> void:
	if not _cores_label:
		return
	var cores := 0
	if _leaderboard_service:
		cores = _leaderboard_service.get_player_rapture_cores()
	_cores_label.text = "Rapture Cores: %d" % cores

func _clear_columns() -> void:
	for child in _left_column.get_children():
		child.queue_free()
	for child in _right_column.get_children():
		child.queue_free()

func _create_entry_control(entry: Dictionary, rank: int) -> Control:
	var wrapper := MarginContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("margin_left", 0)
	wrapper.add_theme_constant_override("margin_right", 0)
	wrapper.add_theme_constant_override("margin_top", 6)
	wrapper.add_theme_constant_override("margin_bottom", 6)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 132)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_entry_stylebox(rank == 1))
	wrapper.add_child(panel)

	var layout := HBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 0)
	panel.add_child(layout)

	var rank_block := _create_rank_block(rank)
	layout.add_child(rank_block)
	layout.add_child(_create_separator())
	var portrait_block := _create_portrait_block(entry)
	layout.add_child(portrait_block)
	layout.add_child(_create_separator())
	var name_block := _create_name_block(entry)
	layout.add_child(name_block)
	layout.add_child(_create_separator())
	var score_block := _create_score_block(entry)
	layout.add_child(score_block)
	layout.add_child(_create_separator())
	var wave_block := _create_wave_block(entry)
	layout.add_child(wave_block)

	_apply_column_stretch(rank_block, "rank")
	_apply_column_stretch(portrait_block, "portrait")
	_apply_column_stretch(name_block, "name")
	_apply_column_stretch(score_block, "score")
	_apply_column_stretch(wave_block, "wave")

	return wrapper

func _create_rank_block(rank: int) -> Control:
	var container := MarginContainer.new()
	container.custom_minimum_size = Vector2(80, 0)
	container.add_theme_constant_override("margin_left", 16)
	container.add_theme_constant_override("margin_right", 8)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var label := Label.new()
	label.text = "#%d" % rank
	label.add_theme_font_override("font", FuturaBold)
	label.add_theme_font_size_override("font_size", 44)
	if rank >= 100:
		label.add_theme_font_size_override("font_size", 32)
	elif rank >= 10:
		label.add_theme_font_size_override("font_size", 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.modulate = RANK_COLOR_PRIMARY if rank <= 3 else VALUE_COLOR
	container.add_child(label)
	return container

func _create_portrait_block(entry: Dictionary) -> Control:
	var container := MarginContainer.new()
	container.custom_minimum_size = Vector2(120, 0)
	container.add_theme_constant_override("margin_top", 12)
	container.add_theme_constant_override("margin_bottom", 12)
	container.add_theme_constant_override("margin_left", 8)
	container.add_theme_constant_override("margin_right", 8)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(108, 108)
	panel.add_theme_stylebox_override("panel", _make_portrait_stylebox())
	container.add_child(panel)

	var texture_rect := TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_rect.texture = _resolve_entry_portrait(entry)
	panel.add_child(texture_rect)

	if texture_rect.texture == null:
		var fallback := Label.new()
		fallback.text = _get_initial(entry)
		fallback.add_theme_font_override("font", PretendardBold)
		fallback.add_theme_font_size_override("font_size", 52)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fallback.size_flags_vertical = Control.SIZE_EXPAND_FILL
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(fallback)

	return container

func _create_name_block(entry: Dictionary) -> Control:
	var wrapper := MarginContainer.new()
	wrapper.add_theme_constant_override("margin_left", 12)
	wrapper.add_theme_constant_override("margin_right", 12)
	wrapper.add_theme_constant_override("margin_top", 12)
	wrapper.add_theme_constant_override("margin_bottom", 12)
	wrapper.custom_minimum_size = Vector2(320, 0)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(column)

	var name_label := Label.new()
	name_label.text = String(entry.get("display_name", ""))
	name_label.add_theme_font_override("font", PretendardBold)
	name_label.add_theme_font_size_override("font_size", 34)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(name_label)

	return wrapper

func _create_score_block(entry: Dictionary) -> Control:
	var wrapper := MarginContainer.new()
	wrapper.custom_minimum_size = Vector2(180, 0)
	wrapper.add_theme_constant_override("margin_left", 12)
	wrapper.add_theme_constant_override("margin_right", 12)
	wrapper.add_theme_constant_override("margin_top", 12)
	wrapper.add_theme_constant_override("margin_bottom", 12)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(container)

	var label := Label.new()
	label.text = "SCORE"
	label.add_theme_font_override("font", PretendardMedium)
	label.add_theme_font_size_override("font_size", 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = LABEL_COLOR
	container.add_child(label)

	var value_label := Label.new()
	var best_score := int(entry.get("best_score", 0))
	if best_score > 0:
		value_label.text = String.num_int64(best_score)
		value_label.modulate = VALUE_COLOR
	else:
		value_label.text = "NO DATA"
		value_label.modulate = MUTED_VALUE_COLOR
	value_label.add_theme_font_override("font", FuturaBold)
	value_label.add_theme_font_size_override("font_size", 38)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(value_label)

	return wrapper

func _create_wave_block(entry: Dictionary) -> Control:
	var wrapper := MarginContainer.new()
	wrapper.custom_minimum_size = Vector2(140, 0)
	wrapper.add_theme_constant_override("margin_left", 12)
	wrapper.add_theme_constant_override("margin_right", 20)
	wrapper.add_theme_constant_override("margin_top", 12)
	wrapper.add_theme_constant_override("margin_bottom", 12)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(container)

	var label := Label.new()
	label.text = "WAVE"
	label.add_theme_font_override("font", PretendardMedium)
	label.add_theme_font_size_override("font_size", 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = LABEL_COLOR
	container.add_child(label)

	var value_label := Label.new()
	var best_wave := int(entry.get("best_wave", 0))
	if best_wave > 0:
		value_label.text = "%d" % best_wave
		value_label.modulate = Color(0.588, 0.949, 0.588, 1.0)
	else:
		value_label.text = "--"
		value_label.modulate = MUTED_VALUE_COLOR
	value_label.add_theme_font_override("font", FuturaBold)
	value_label.add_theme_font_size_override("font_size", 34)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(value_label)

	return wrapper

func _create_separator() -> Control:
	var separator := ColorRect.new()
	separator.color = ENTRY_SEPARATOR_COLOR
	separator.custom_minimum_size = Vector2(2, 96)
	separator.size_flags_vertical = Control.SIZE_EXPAND_FILL
	separator.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return separator

func _make_entry_stylebox(is_top_rank: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ENTRY_BG_COLOR.lightened(0.06) if is_top_rank else ENTRY_BG_COLOR
	style.border_color = BORDER_COLOR if is_top_rank else ENTRY_BORDER_COLOR
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _make_portrait_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND_COLOR.darkened(0.2)
	style.border_color = BORDER_COLOR
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func _get_initial(entry: Dictionary) -> String:
	var display_name := String(entry.get("display_name", ""))
	if display_name.length() > 0:
		return display_name.substr(0, 1).to_upper()
	var code := String(entry.get("code", ""))
	if code.length() > 0:
		return code.substr(0, 1).to_upper()
	return "?"

func _apply_column_stretch(control: Control, key: String) -> void:
	if control == null:
		return
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_stretch_ratio = ENTRY_COLUMN_STRETCH.get(key, 1.0)

func _resolve_entry_portrait(entry: Dictionary) -> Texture2D:
	var raw_portrait: Variant = entry.get("portrait")
	if raw_portrait is Texture2D:
		return raw_portrait as Texture2D
	var code := String(entry.get("code", "")).strip_edges()
	if code.is_empty():
		return null
	if _portrait_cache.has(code):
		var cached_variant: Variant = _portrait_cache[code]
		if cached_variant is Texture2D:
			return cached_variant
	var roster_portrait := _resolve_portrait_from_roster(code)
	if roster_portrait:
		_portrait_cache[code] = roster_portrait
		return roster_portrait
	var resolved: Texture2D = null
	var candidates := _build_portrait_code_candidates(code)
	for candidate in candidates:
		if _portrait_cache.has(candidate):
			var cached_entry: Variant = _portrait_cache[candidate]
			if cached_entry is Texture2D:
				return cached_entry
			continue
		var path := LEGACY_PORTRAIT_TEMPLATE % candidate
		var loaded := ResourceLoader.load(path)
		if loaded is Texture2D:
			resolved = loaded as Texture2D
			_portrait_cache[candidate] = resolved
			return resolved
		_portrait_cache[candidate] = null
	if resolved:
		return resolved
	_portrait_cache[code] = null
	return null

func _resolve_portrait_from_roster(code: String) -> Texture2D:
	if _roster == null:
		return null
	if _roster.has_method("ensure_loaded"):
		_roster.ensure_loaded()
	if _roster.has_method("get_character_by_code"):
		var direct := _roster.get_character_by_code(code)
		if direct:
			var direct_portrait: Variant = direct.get("portrait_texture")
			if direct_portrait is Texture2D:
				return direct_portrait
	var candidate_character: CharacterData = _find_roster_character_fuzzy(code)
	if candidate_character:
		var portrait: Variant = candidate_character.get("portrait_texture")
		if portrait is Texture2D:
			return portrait
	return null

func _find_roster_character_fuzzy(code: String) -> CharacterData:
	if _roster == null:
		return null
	var normalized := code.strip_edges()
	if normalized == "":
		return null
	var lower := normalized.to_lower()
	var normalized_core := _normalize_identifier(lower)
	for character in _roster.characters:
		if character == null:
			continue
		var char_code := String(character.code_name)
		if char_code == "":
			continue
		if char_code == normalized:
			return character
		var char_lower := char_code.to_lower()
		if char_lower == lower:
			return character
		if _normalize_identifier(char_lower) == normalized_core:
			return character
	return null

func _build_portrait_code_candidates(code: String) -> Array[String]:
	var variants: Array[String] = []
	var seen := {}
	var normalized := code.strip_edges()
	_normalize_and_add_variant(normalized, variants, seen)
	var lower := normalized.to_lower()
	_normalize_and_add_variant(lower, variants, seen)
	_normalize_and_add_variant(lower.replace("_", "-"), variants, seen)
	_normalize_and_add_variant(lower.replace("-", "_"), variants, seen)
	_normalize_and_add_variant(lower.replace(" ", "-"), variants, seen)
	_normalize_and_add_variant(lower.replace(" ", "_"), variants, seen)
	_normalize_and_add_variant(lower.replace("-", ""), variants, seen)
	_normalize_and_add_variant(lower.replace("_", ""), variants, seen)
	return variants

func _normalize_and_add_variant(value: String, variants: Array[String], seen: Dictionary) -> void:
	var trimmed := value.strip_edges()
	if trimmed == "":
		return
	if seen.has(trimmed):
		return
	seen[trimmed] = true
	variants.append(trimmed)

func _normalize_identifier(value: String) -> String:
	return value.replace("-", "").replace("_", "").replace(" ", "")
