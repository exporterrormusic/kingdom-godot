extends Control
class_name PlayerHudCluster

signal portrait_shaken
signal health_fill_finished
signal burst_fill_finished

@export var shake_distance: float = 14.0
@export_range(0.05, 1.5, 0.01) var shake_duration: float = 0.35
@export_range(0.05, 1.0, 0.01) var fill_transition_time: float = 0.22
@export_range(0.05, 1.0, 0.01) var burst_transition_time: float = 0.22
@export_range(0.0, 1.0, 0.01) var low_health_threshold: float = 0.25
@export var auto_apply_styles: bool = true
@export var default_portrait_texture: Texture2D = preload("res://assets/images/example_character.png")

@export var portrait_border_color: Color = Color(0.56, 0.63, 0.92, 0.85)
@export var portrait_background_color: Color = Color(0.11, 0.11, 0.17, 0.92)
@export var hp_bar_color: Color = Color(0.32, 0.86, 0.48, 1.0)
@export var hp_bar_background: Color = Color(0.11, 0.14, 0.18, 0.92)
@export var hp_bar_frame_color: Color = Color(0.26, 0.36, 0.51, 1.0)
@export var burst_bar_color: Color = Color(0.95, 0.82, 0.32, 1.0)
@export var burst_bar_background: Color = Color(0.18, 0.14, 0.05, 0.92)
@export var burst_bar_frame_color: Color = Color(0.62, 0.5, 0.18, 1.0)
@export var burst_badge_background: Color = Color(0.98, 0.9, 0.52, 1.0)
@export var burst_badge_text_color: Color = Color(0.12, 0.1, 0.08, 1.0)
@export var hp_badge_background: Color = Color(1, 1, 1, 1)
@export var hp_badge_text_color: Color = Color(0.1, 0.12, 0.18, 1.0)
@export var low_health_color: Color = Color(1.0, 0.52, 0.42, 1.0)
@export var ammo_text_color: Color = Color(0.9, 0.95, 1.0, 1.0)
@export var ammo_low_text_color: Color = Color(1.0, 0.55, 0.45, 1.0)
@export_range(0.0, 1.0, 0.05) var ammo_low_threshold: float = 0.2
@export var burst_ready_badge_color: Color = Color(1.0, 0.74, 0.38, 1.0)
@export var burst_ready_text_color: Color = Color(0.12, 0.08, 0.06, 1.0)

@onready var _portrait_slot: Control = %PortraitShake
@onready var _portrait_frame: Panel = %PortraitFrame
@onready var _portrait_background: ColorRect = %PortraitBackground
@onready var _portrait_texture: TextureRect = %PortraitTexture
@onready var _hp_badge: ColorRect = %HPBadge
@onready var _hp_badge_label: Label = %HPBadgeLabel
@onready var _burst_badge: ColorRect = %BurstBadge
@onready var _burst_badge_label: Label = %BurstBadgeLabel
@onready var _hp_bar: ProgressBar = %HPBar
@onready var _burst_bar: ProgressBar = %BurstBar
@onready var _ammo_label: Label = %AmmoLabel
@onready var _special_label: Label = %SpecialLabel
@onready var _run_stats_label: Label = %RunStatsLabel
@onready var _run_timer_label: Label = %RunTimerLabel

var _profile: CharacterData = null
var _portrait_origin: Vector2 = Vector2.ZERO
var _default_portrait_modulate: Color = Color(1, 1, 1, 1)
var _portrait_cache: Dictionary = {}

var _health_tween: Tween = null
var _burst_tween: Tween = null
var _shake_tween: Tween = null

var _max_health: int = 1
var _current_health: int = 1
var _max_burst: float = 1.0
var _current_burst: float = 0.0
var _ammo_current: int = 0
var _ammo_max: int = 0
var _special_current: int = 0
var _special_max: int = 0
var _burst_ready_state: bool = false
var _burst_ready_tween: Tween = null
var _current_wave_index: int = 0
var _total_kills: int = 0
var _run_time_seconds: float = 0.0

func _ready() -> void:
	_portrait_origin = _portrait_slot.position
	_default_portrait_modulate = _portrait_texture.modulate
	if auto_apply_styles:
		_apply_styles()
	_refresh_bars()
	_apply_portrait_texture(_prepare_default_portrait(), false)
	_apply_low_health_state()
	_update_ammo_labels()
	_refresh_run_stats()
	_refresh_run_timer()
	set_burst_ready(false, false)

func set_character_profile(profile: CharacterData) -> void:
	_profile = profile
	_apply_portrait_texture(_build_profile_portrait(), true)

func set_portrait(texture: Texture2D) -> void:
	_profile = null
	var processed: Texture2D = _prepare_texture(texture, _cache_key(texture, "manual"))
	_apply_portrait_texture(processed, true)

func configure(current_health: int, max_health: int, burst_current: float = 0.0, burst_max: float = 1.0) -> void:
	_max_health = maxi(1, max_health)
	_current_health = clampi(current_health, 0, _max_health)
	_max_burst = maxf(0.001, burst_max)
	_current_burst = clampf(burst_current, 0.0, _max_burst)
	_refresh_bars()
	_apply_low_health_state()

func update_health(current: int, max_value: int, delta: int = 0, animate: bool = true) -> void:
	var new_max: int = maxi(1, max_value)
	var clamped: int = clampi(current, 0, new_max)
	var previous: int = _current_health
	_max_health = new_max
	_current_health = clamped
	_hp_bar.max_value = _max_health
	if _health_tween and _health_tween.is_running():
		_health_tween.kill()
		_health_tween = null
	if animate:
		_health_tween = create_tween()
		var tween_ref: Tween = _health_tween
		_health_tween.tween_property(_hp_bar, "value", float(_current_health), fill_transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_health_tween.finished.connect(func():
			emit_signal("health_fill_finished")
			if _health_tween == tween_ref:
				_health_tween = null
		)
	else:
		_hp_bar.value = _current_health
		emit_signal("health_fill_finished")
	_apply_low_health_state()
	if delta < 0 and _current_health < previous:
		_trigger_damage_shake()

func update_burst(current: float, max_value: float, animate: bool = true) -> void:
	var new_max: float = maxf(0.001, max_value)
	var clamped: float = clampf(current, 0.0, new_max)
	_max_burst = new_max
	_current_burst = clamped
	_burst_bar.max_value = _max_burst
	if _burst_tween and _burst_tween.is_running():
		_burst_tween.kill()
		_burst_tween = null
	if animate:
		_burst_tween = create_tween()
		var tween_ref: Tween = _burst_tween
		_burst_tween.tween_property(_burst_bar, "value", float(_current_burst), burst_transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_burst_tween.finished.connect(func():
			emit_signal("burst_fill_finished")
			if _burst_tween == tween_ref:
				_burst_tween = null
		)
	else:
		_burst_bar.value = _current_burst
		emit_signal("burst_fill_finished")

func update_ammo(current_ammo: int, magazine_size: int, special_current: int, special_max: int) -> void:
	_ammo_current = max(0, current_ammo)
	_ammo_max = max(0, magazine_size)
	_special_current = max(0, special_current)
	_special_max = max(0, special_max)
	_update_ammo_labels()

func update_wave_index(wave_index: int) -> void:
	_current_wave_index = max(0, wave_index)
	_refresh_run_stats()

func update_kill_count(total_kills: int) -> void:
	_total_kills = max(0, total_kills)
	_refresh_run_stats()

func set_run_stats(wave_index: int, total_kills: int) -> void:
	_current_wave_index = max(0, wave_index)
	_total_kills = max(0, total_kills)
	_refresh_run_stats()

func update_run_time(total_seconds: float) -> void:
	_run_time_seconds = maxf(0.0, total_seconds)
	_refresh_run_timer()

func set_burst_ready(is_ready: bool, animate: bool = true) -> void:
	if _burst_ready_state == is_ready and animate:
		return
	_burst_ready_state = is_ready
	if _burst_ready_tween and _burst_ready_tween.is_running():
		_burst_ready_tween.kill()
		_burst_ready_tween = null
	if _burst_badge:
		_burst_badge.color = burst_ready_badge_color if is_ready else burst_badge_background
		if not animate or not is_ready:
			_burst_badge.scale = Vector2.ONE
	if _burst_badge_label:
		_burst_badge_label.text = "BURST READY" if is_ready else "BURST"
		_burst_badge_label.modulate = burst_ready_text_color if is_ready else burst_badge_text_color
	if animate and is_ready and _burst_badge and is_inside_tree():
		_burst_ready_tween = create_tween()
		var tween_ref: Tween = _burst_ready_tween
		_burst_ready_tween.tween_property(_burst_badge, "scale", Vector2(1.08, 1.08), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_burst_ready_tween.tween_property(_burst_badge, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_burst_ready_tween.finished.connect(func():
			if _burst_ready_tween == tween_ref:
				_burst_ready_tween = null
		)

func set_hp_palette(fill_color: Color, background_color: Color, frame_color: Color) -> void:
	hp_bar_color = fill_color
	hp_bar_background = background_color
	hp_bar_frame_color = frame_color
	_apply_styles()

func set_portrait_palette(frame_color: Color, background_color: Color) -> void:
	portrait_border_color = frame_color
	portrait_background_color = background_color
	_apply_styles()

func _apply_portrait_texture(texture: Texture2D, allow_fallback: bool) -> void:
	var final_texture: Texture2D = texture
	if final_texture == null and allow_fallback:
		final_texture = _prepare_default_portrait()
	_portrait_texture.texture = final_texture
	_portrait_texture.visible = final_texture != null
	_portrait_texture.modulate = _default_portrait_modulate
	if final_texture == null:
		push_warning("PlayerHudCluster: portrait texture unavailable; displaying empty slot.")
		return
	if Engine.is_editor_hint():
		return
	var texture_path: String = final_texture.resource_path if final_texture.resource_path != "" else "generated"
	print_debug("PlayerHudCluster: portrait applied -> %s" % texture_path)

func _build_profile_portrait() -> Texture2D:
	if _profile == null:
		return null
	var base_key: String = _profile_code_suffix()
	var override_texture: Texture2D = _load_profile_portrait_override()
	if override_texture:
		return _prepare_texture(override_texture, _cache_key(override_texture, base_key + "::portrait_sq"))
	if _profile.portrait_texture:
		return _prepare_texture(_profile.portrait_texture, _cache_key(_profile.portrait_texture, base_key + "::portrait"))
	if _profile.burst_texture:
		return _prepare_texture(_profile.burst_texture, _cache_key(_profile.burst_texture, base_key + "::burst"))
	if _profile.sprite_sheet and _profile.sprite_sheet_columns > 0 and _profile.sprite_sheet_rows > 0:
		var frame: Texture2D = _extract_sprite_frame(_profile)
		if frame:
			return frame
	if _profile.sprite_sheet:
		return _prepare_texture(_profile.sprite_sheet, _cache_key(_profile.sprite_sheet, base_key + "::sheet"))
	return null

func _prepare_default_portrait() -> Texture2D:
	if default_portrait_texture == null:
		return null
	return _prepare_texture(default_portrait_texture, _cache_key(default_portrait_texture, "default"))

func _prepare_texture(texture: Texture2D, cache_key: String) -> Texture2D:
	if texture == null:
		return null
	if cache_key != "" and _portrait_cache.has(cache_key):
		return _portrait_cache[cache_key]
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		if cache_key != "":
			_portrait_cache[cache_key] = texture
		return texture
	if image.is_compressed():
		var err: Error = image.decompress()
		if err != OK:
			if cache_key != "":
				_portrait_cache[cache_key] = texture
			return texture
	image.convert(Image.FORMAT_RGBA8)
	image = _ensure_square_image(image)
	var prepared: ImageTexture = ImageTexture.create_from_image(image)
	if cache_key != "":
		_portrait_cache[cache_key] = prepared
	return prepared

func _load_profile_portrait_override() -> Texture2D:
	if _profile == null or _profile.code_name == "":
		return null
	var code: String = _profile.code_name
	var candidates: Array[String] = [
		"res://assets/images/Characters/%s/portrait-sq.png" % code,
		"res://assets/images/characters/%s/portrait-sq.png" % code,
		"res://assets/images/Characters/%s/portrait.png" % code,
		"res://assets/images/characters/%s/portrait.png" % code,
	]
	for path in candidates:
		if FileAccess.file_exists(path):
			var texture: Resource = ResourceLoader.load(path, "Texture2D")
			if texture is Texture2D:
				return texture
			if texture:
				var typed_texture: Texture2D = texture as Texture2D
				if typed_texture:
					return typed_texture
	return null

func _extract_sprite_frame(profile: CharacterData) -> Texture2D:
	var texture: Texture2D = profile.sprite_sheet
	if texture == null:
		return null
	var cache_key: String = _cache_key(texture, profile.code_name + "::frame")
	if cache_key != "" and _portrait_cache.has(cache_key):
		return _portrait_cache[cache_key]
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		var err: Error = image.decompress()
		if err != OK:
			return null
	image.convert(Image.FORMAT_RGBA8)
	var columns: int = maxi(1, profile.sprite_sheet_columns)
	var rows: int = maxi(1, profile.sprite_sheet_rows)
	var frame_width: int = int(floor(float(image.get_width()) / float(columns)))
	var frame_height: int = int(floor(float(image.get_height()) / float(rows)))
	if frame_width <= 0 or frame_height <= 0:
		return null
	var region: Rect2i = Rect2i(0, 0, frame_width, frame_height)
	var frame_image: Image = image.get_region(region)
	var prepared: ImageTexture = ImageTexture.create_from_image(frame_image)
	if cache_key != "":
		_portrait_cache[cache_key] = prepared
	return prepared

func _cache_key(texture: Texture2D, suffix: String = "") -> String:
	if texture == null:
		return ""
	var base: String = texture.resource_path if texture.resource_path != "" else str(texture.get_rid())
	if suffix == "":
		return base
	return "%s::%s" % [base, suffix]

func _ensure_square_image(image: Image) -> Image:
	if image == null:
		return image
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width <= 0 or height <= 0 or width == height:
		return image
	var square_size: int = maxi(width, height)
	var format: Image.Format = image.get_format()
	var padded: Image = Image.create(square_size, square_size, false, format)
	if padded == null:
		return image
	padded.fill(Color(0, 0, 0, 0))
	var dest_position: Vector2i = Vector2i(int((square_size - width) / 2), int((square_size - height) / 2))
	var source_rect: Rect2i = Rect2i(Vector2i.ZERO, Vector2i(width, height))
	padded.blit_rect(image, source_rect, dest_position)
	if not Engine.is_editor_hint():
		print_debug("PlayerHudCluster: portrait padded (%d x %d -> %d x %d)" % [width, height, square_size, square_size])
	return padded

func _profile_code_suffix() -> String:
	if _profile == null:
		return ""
	if _profile.code_name != "":
		return _profile.code_name
	return str(_profile.get_instance_id())

func _refresh_bars() -> void:
	_hp_bar.max_value = _max_health
	_hp_bar.value = _current_health
	_burst_bar.max_value = _max_burst
	_burst_bar.value = _current_burst

func _update_ammo_labels() -> void:
	if _ammo_label:
		var magazine_text: String = "∞"
		if _ammo_max > 0:
			magazine_text = "%d/%d" % [_ammo_current, _ammo_max]
		_ammo_label.text = "AMMO %s" % magazine_text
		var ammo_ratio: float = 1.0
		if _ammo_max > 0:
			ammo_ratio = float(_ammo_current) / float(max(1, _ammo_max))
		var low_ammo: bool = _ammo_max > 0 and ammo_ratio <= ammo_low_threshold
		_ammo_label.modulate = ammo_low_text_color if low_ammo else ammo_text_color
	if _special_label:
		if _special_max <= 0:
			_special_label.visible = false
		else:
			_special_label.visible = true
			_special_label.text = "SPECIAL %d/%d" % [_special_current, _special_max]
			var special_ratio: float = float(_special_current) / float(max(1, _special_max))
			var low_special: bool = special_ratio <= ammo_low_threshold
			_special_label.modulate = ammo_low_text_color if low_special else ammo_text_color
	_refresh_run_stats()

func _refresh_run_stats() -> void:
	if not _run_stats_label:
		return
	var wave_text: String = "WAVE %02d" % max(0, _current_wave_index)
	var kills_text: String = "KILLS %d" % max(0, _total_kills)
	_run_stats_label.text = "%s • %s" % [wave_text, kills_text]

func _refresh_run_timer() -> void:
	if not _run_timer_label:
		return
	var seconds: int = max(0, roundi(_run_time_seconds))
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	var rem_seconds: int = seconds % 60
	var time_text: String
	if hours > 0:
		time_text = "TIME %d:%02d:%02d" % [hours, minutes, rem_seconds]
	else:
		time_text = "TIME %02d:%02d" % [minutes, rem_seconds]
	_run_timer_label.text = time_text

func _apply_low_health_state() -> void:
	if _max_health <= 0:
		_portrait_texture.modulate = _default_portrait_modulate
		return
	var ratio: float = float(_current_health) / float(_max_health)
	_portrait_texture.modulate = low_health_color if ratio <= low_health_threshold else _default_portrait_modulate

func _apply_styles() -> void:
	if _portrait_background:
		_portrait_background.color = portrait_background_color
	if _portrait_frame:
		var frame_style: StyleBoxFlat = StyleBoxFlat.new()
		frame_style.bg_color = Color(0, 0, 0, 0)
		frame_style.border_color = portrait_border_color
		frame_style.border_width_top = 2
		frame_style.border_width_bottom = 2
		frame_style.border_width_left = 2
		frame_style.border_width_right = 2
		_portrait_frame.add_theme_stylebox_override("panel", frame_style)
	if _hp_badge:
		_hp_badge.color = hp_badge_background
	if _hp_badge_label:
		_hp_badge_label.modulate = hp_badge_text_color
	if _burst_badge:
		_burst_badge.color = burst_badge_background
	if _burst_badge_label:
		_burst_badge_label.modulate = burst_badge_text_color
	if _hp_bar:
		_hp_bar.add_theme_stylebox_override("background", _create_bar_background(hp_bar_background, hp_bar_frame_color))
		_hp_bar.add_theme_stylebox_override("fill", _create_bar_fill(hp_bar_color))
	if _burst_bar:
		_burst_bar.add_theme_stylebox_override("background", _create_bar_background(burst_bar_background, burst_bar_frame_color))
		_burst_bar.add_theme_stylebox_override("fill", _create_bar_fill(burst_bar_color))
	if _ammo_label:
		_ammo_label.modulate = ammo_text_color
	if _special_label:
		_special_label.modulate = ammo_text_color
	if _run_stats_label:
		_run_stats_label.modulate = ammo_text_color
	if _run_timer_label:
		_run_timer_label.modulate = ammo_text_color
	set_burst_ready(_burst_ready_state, false)
	_update_ammo_labels()

func _create_bar_background(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg_color
	box.border_color = border_color
	box.border_width_left = 2
	box.border_width_right = 2
	box.border_width_top = 2
	box.border_width_bottom = 2
	return box

func _create_bar_fill(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	return box

func _trigger_damage_shake() -> void:
	if not is_inside_tree():
		return
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
		_shake_tween = null
	_portrait_slot.position = _portrait_origin
	_shake_tween = create_tween()
	var tween_ref: Tween = _shake_tween
	_shake_tween.set_trans(Tween.TRANS_SINE)
	_shake_tween.set_ease(Tween.EASE_OUT)
	var left: Vector2 = _portrait_origin + Vector2(-shake_distance, 0)
	var right: Vector2 = _portrait_origin + Vector2(shake_distance * 0.6, 0)
	_shake_tween.tween_property(_portrait_slot, "position", left, shake_duration * 0.35)
	_shake_tween.tween_property(_portrait_slot, "position", right, shake_duration * 0.3)
	_shake_tween.tween_property(_portrait_slot, "position", _portrait_origin, shake_duration * 0.35)
	_shake_tween.finished.connect(func():
		_portrait_slot.position = _portrait_origin
		if _shake_tween == tween_ref:
			_shake_tween = null
		emit_signal("portrait_shaken")
	)

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and auto_apply_styles:
		_apply_styles()
