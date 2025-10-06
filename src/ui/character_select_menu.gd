extends Control
class_name CharacterSelectMenu

signal back_requested
signal character_confirmed(character_data: CharacterData)

const CharacterCardScene := preload("res://scenes/ui/components/CharacterCard.tscn")
const CharacterCardScript := preload("res://src/ui/components/character_card.gd")
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

enum MenuStage { SELECTING, TRANSITIONING, CONFIGURING }

@onready var _grid_root: Control = %GridRoot
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
@onready var _buttons_bar: HBoxContainer = %ButtonsBar
@onready var _confirm_button: Button = %ConfirmButton
@onready var _back_button: Button = %BackButton

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
var _stage: int = MenuStage.SELECTING
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

func _ready() -> void:
	_rng.randomize()
	_back_button.pressed.connect(_on_back_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_build_stat_rows()
	_update_buttons()
	if _roster:
		_populate_cards()
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
		var card_instance := CharacterCardScene.instantiate()
		var card := card_instance as CharacterCardScript
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
	var random_instance := CharacterCardScene.instantiate()
	var random_card := random_instance as CharacterCardScript
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
		var card := entry.get("card") as CharacterCardScript
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
			var card := entry.get("card") as CharacterCardScript
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
		var card := _entries[i].get("card") as CharacterCardScript
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
	var card := card_node as CharacterCardScript
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
	var card := card_node as CharacterCardScript
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
	_stage = MenuStage.TRANSITIONING
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
	_grid_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_stage = MenuStage.CONFIGURING
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
		emit_signal("character_confirmed", chosen)

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
	_stage = MenuStage.TRANSITIONING
	_grid_root.visible = true
	_grid_root.modulate = Color(1, 1, 1, 0)
	_grid_root.position = Vector2(_grid_base_position.x, _grid_hidden_position_y)
	_grid_root.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_grid_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_details_panel.position = _details_base_position
	_stage = MenuStage.SELECTING
	_update_buttons()

func _emit_back_requested() -> void:
	if _stage == MenuStage.CONFIGURING:
		_exit_configuration_mode()
	elif _stage == MenuStage.TRANSITIONING:
		return
	else:
		emit_signal("back_requested")
