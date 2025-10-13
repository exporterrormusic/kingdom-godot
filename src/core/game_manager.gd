extends Node
class_name GameManager

## Godot entry point coordinating high-level game state.
##
## Responsibilities to port:
## - Bootstrapping config/save services
## - Driving menu/gameplay/pause state machine
## - Managing scene transitions and persistence
##
## The actual implementation will track an enum-based state and
## instantiate scenes into a root viewport container.

const GameStateServiceScript := preload("res://src/services/game_state_service.gd")
const ConfigServiceScript := preload("res://src/services/config_service.gd")
const SaveServiceScript := preload("res://src/services/save_service.gd")
const AudioDirectorScript := preload("res://src/services/audio_director.gd")
const InputInitializerScript := preload("res://src/core/input_initializer.gd")
const AchievementServiceScript := preload("res://src/services/achievement_service.gd")
const LeaderboardServiceScript := preload("res://src/services/leaderboard_service.gd")
const MainMenuScene := preload("res://scenes/ui/MainMenu.tscn")
const AchievementsMenuScene := preload("res://scenes/ui/AchievementsMenu.tscn")
const LeaderboardMenuScene := preload("res://scenes/ui/LeaderboardMenu.tscn")
const WorldScene := preload("res://scenes/world/WorldScene.tscn")
const SettingsMenuScene := preload("res://scenes/ui/SettingsMenu.tscn")
const PauseMenuScene := preload("res://scenes/ui/PauseMenu.tscn")
const CharacterSelectScene := preload("res://scenes/ui/CharacterSelectMenu.tscn")
const GameOverMenuScene := preload("res://scenes/ui/GameOverMenu.tscn")
const CharacterRosterResource := preload("res://resources/characters/characters.tres")

@onready var _state_service: GameStateService = _resolve_state_service()
@onready var _config_service: ConfigService = _resolve_config_service()
@onready var _save_service: SaveService = _resolve_save_service()
@onready var _audio_director: AudioDirector = _resolve_audio_director()
@onready var _achievement_service: AchievementService = _resolve_achievement_service()
@onready var _leaderboard_service: LeaderboardService = _resolve_leaderboard_service()
@onready var _scene_root: Node = _create_scene_root()
@onready var _overlay_layer: CanvasLayer = _create_overlay_layer()
@onready var _overlay_root: Control = _create_overlay_root()

var _current_scene: Node = null
var _overlay_scene: Node = null
var _return_to_pause_after_settings := false
var _return_to_game_over_after_settings := false
var _character_roster: Resource = null
var _selected_character: Resource = null
var _selected_mission_config: Dictionary = {}
var _last_run_record: Dictionary = {}
var _last_run_outcome: String = "death"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and _overlay_root:
		_sync_overlay_size()

func _ready() -> void:
	# Ensure config/save/autoload services have a chance to initialize.
	_config_service.ensure_loaded()
	_save_service.load_initial_state()
	InputInitializerScript.ensure_actions()
	_apply_display_settings()
	_apply_audio_settings()
	_apply_config_key_bindings()
	_initialize_achievement_service()
	_state_service.initialize()
	_state_service.state_changed.connect(_on_state_changed)
	_initialize_character_roster()
	_initialize_leaderboard_service()
	change_state("menu")

func change_state(new_state: String) -> void:
	_state_service.set_state(new_state)

func _resolve_state_service() -> GameStateService:
	var autoload_path := "/root/GameStateService"
	if get_tree() and get_tree().root and get_tree().root.has_node(autoload_path):
		return get_tree().root.get_node(autoload_path)
	var instance: GameStateService = GameStateServiceScript.new()
	instance.name = "GameStateService"
	add_child(instance)
	return instance

func _resolve_config_service() -> ConfigService:
	var autoload_path := "/root/ConfigService"
	if get_tree() and get_tree().root and get_tree().root.has_node(autoload_path):
		return get_tree().root.get_node(autoload_path)
	var instance: ConfigService = ConfigServiceScript.new()
	instance.name = "ConfigService"
	add_child(instance)
	return instance

func _resolve_save_service() -> SaveService:
	var autoload_path := "/root/SaveService"
	if get_tree() and get_tree().root and get_tree().root.has_node(autoload_path):
		return get_tree().root.get_node(autoload_path)
	var instance: SaveService = SaveServiceScript.new()
	instance.name = "SaveService"
	add_child(instance)
	return instance

func _resolve_audio_director() -> AudioDirector:
	var autoload_path := "/root/AudioDirector"
	if get_tree() and get_tree().root and get_tree().root.has_node(autoload_path):
		return get_tree().root.get_node(autoload_path)
	var instance: AudioDirector = AudioDirectorScript.new()
	instance.name = "AudioDirector"
	add_child(instance)
	instance.initialize()
	return instance

func _resolve_achievement_service() -> AchievementService:
	var autoload_path := "/root/AchievementService"
	if get_tree() and get_tree().root and get_tree().root.has_node(autoload_path):
		return get_tree().root.get_node(autoload_path)
	var instance: AchievementService = AchievementServiceScript.new()
	instance.name = "AchievementService"
	add_child(instance)
	return instance

func _resolve_leaderboard_service() -> LeaderboardService:
	var autoload_path := "/root/LeaderboardService"
	if get_tree() and get_tree().root and get_tree().root.has_node(autoload_path):
		return get_tree().root.get_node(autoload_path)
	var instance: LeaderboardService = LeaderboardServiceScript.new()
	instance.name = "LeaderboardService"
	add_child(instance)
	return instance

func _apply_display_settings() -> void:
	var fullscreen: bool = bool(_config_service.get_value("fullscreen", false))
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var width: int = int(_config_service.get_value("display_width", 1920))
		var height: int = int(_config_service.get_value("display_height", 1080))
		DisplayServer.window_set_size(Vector2i(width, height))

func _apply_audio_settings() -> void:
	var master_volume: float = float(_config_service.get_value("master_volume", 1.0))
	_audio_director.set_master_volume(master_volume)
	var music_volume: float = float(_config_service.get_value("music_volume", master_volume))
	var sfx_volume: float = float(_config_service.get_value("sfx_volume", master_volume))
	_audio_director.set_music_volume(music_volume)
	_audio_director.set_sfx_volume(sfx_volume)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	var linear: float = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(max(linear, 0.0001)))

func _apply_config_key_bindings() -> void:
	var bindings = _config_service.get_value("key_bindings", {})
	if typeof(bindings) != TYPE_DICTIONARY:
		return
	for action in bindings.keys():
		if not InputMap.has_action(action):
			continue
		var keycode := int(bindings[action])
		var event := InputEventKey.new()
		event.physical_keycode = keycode as Key
		event.keycode = keycode as Key
		var existing := InputMap.action_get_events(action)
		for ev in existing:
			InputMap.action_erase_event(action, ev)
		InputMap.action_add_event(action, event)

func _initialize_achievement_service() -> void:
	if not _achievement_service:
		return
	var save_data := _save_service.get_state()
	_achievement_service.initialize(_save_service, save_data)

func _initialize_leaderboard_service() -> void:
	if not _leaderboard_service:
		return
	var save_data := _save_service.get_state()
	_leaderboard_service.initialize(_save_service, save_data, _character_roster)

func _create_scene_root() -> Node:
	var root := Node.new()
	root.name = "SceneRoot"
	add_child(root)
	return root

func _create_overlay_layer() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "OverlayLayer"
	layer.layer = 100
	add_child(layer)
	return layer

func _create_overlay_root() -> Control:
	var root := Control.new()
	root.name = "OverlayRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.top_level = true
	root.position = Vector2.ZERO
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overlay_layer.add_child(root)
	root.set_deferred("size", get_viewport().get_visible_rect().size)
	return root

func _sync_overlay_size() -> void:
	if not _overlay_root:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	_overlay_root.set_deferred("size", viewport_size)

func _mount_overlay(node: Node) -> void:
	if node == null:
		return
	if node.get_parent():
		node.get_parent().remove_child(node)
	if node is Control:
		var control := node as Control
		control.top_level = false
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.offset_left = 0.0
		control.offset_top = 0.0
		control.offset_right = 0.0
		control.offset_bottom = 0.0
		control.set_deferred("size", _overlay_root.size)
		control.position = Vector2.ZERO
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_overlay_root.add_child(control)
		_set_main_menu_title_visible(false)
	else:
		_overlay_layer.add_child(node)

func _set_main_menu_title_visible(should_show: bool) -> void:
	if _current_scene and _current_scene is MainMenu:
		var menu := _current_scene as MainMenu
		if menu:
			menu.set_title_panel_visible(should_show)

func _on_state_changed(_previous_state: String, next_state: String) -> void:
	_match_state(next_state)

func _match_state(state_name: String) -> void:
	_clear_overlay(true)
	if _current_scene:
		_current_scene.queue_free()
		_current_scene = null

	var packed_scene: PackedScene = null
	match state_name:
		"menu":
			packed_scene = MainMenuScene
		"character_select":
			packed_scene = CharacterSelectScene
		"gameplay":
			packed_scene = WorldScene
		"settings":
			packed_scene = SettingsMenuScene
		_:
			push_warning("Unknown state: %s" % state_name)
			return

	_current_scene = packed_scene.instantiate()
	_scene_root.add_child(_current_scene)

	match state_name:
		"menu":
			_configure_main_menu_scene(_current_scene)
		"character_select":
			_configure_character_select_scene(_current_scene)
		"gameplay":
			_configure_world_scene(_current_scene)
		"settings":
			_configure_settings_scene(_current_scene, Callable(self, "_on_settings_back_requested"))

func _on_start_game_requested() -> void:
	change_state("character_select")

func _on_exit_to_menu_requested() -> void:
	change_state("menu")

func _on_settings_requested() -> void:
	var current_state := _state_service.get_state()
	if current_state == "gameplay":
		_show_settings_overlay(false)
	elif current_state != "settings":
		change_state("settings")

func _on_settings_back_requested() -> void:
	change_state("menu")

func _on_master_volume_changed(value: float) -> void:
	_config_service.set_value("master_volume", value)
	_config_service.set_value("music_volume", value)
	_audio_director.set_master_volume(value)
	_set_bus_volume("Music", value)

func _on_resolution_changed(resolution: Vector2i) -> void:
	_config_service.set_value("display_width", resolution.x)
	_config_service.set_value("display_height", resolution.y)
	DisplayServer.window_set_size(resolution)

func _on_music_volume_changed(value: float) -> void:
	_config_service.set_value("music_volume", value)
	_set_bus_volume("Music", value)

func _on_sfx_volume_changed(value: float) -> void:
	_config_service.set_value("sfx_volume", value)
	_set_bus_volume("SFX", value)

func _on_fullscreen_toggled(enabled: bool) -> void:
	_config_service.set_value("fullscreen", enabled)
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var width: int = int(_config_service.get_value("display_width", 1920))
		var height: int = int(_config_service.get_value("display_height", 1080))
		DisplayServer.window_set_size(Vector2i(width, height))

func _on_player_name_changed(player_name: String) -> void:
	_config_service.set_value("player_name", player_name)

func _on_default_character_changed(code: String) -> void:
	_config_service.set_value("default_character_code", code)
	_config_service.set_value("last_character_code", code)
	if _character_roster and _character_roster.has_method("get_character_by_code"):
		var character: Resource = _character_roster.get_character_by_code(code)
		if character:
			_selected_character = character

func _on_key_binding_changed(action: String, keycode: int) -> void:
	var stored: Variant = _config_service.get_value("key_bindings", {})
	var bindings: Dictionary = {}
	if typeof(stored) == TYPE_DICTIONARY:
		bindings = stored.duplicate()
	bindings[action] = keycode
	_config_service.set_value("key_bindings", bindings)

func _on_multiplayer_setting_changed(setting: String, value) -> void:
	match setting:
		"connection_method":
			_config_service.set_value("multiplayer_connection_method", String(value).to_upper())
		"show_ping":
			_config_service.set_value("multiplayer_show_ping", bool(value))
		"auto_ready":
			_config_service.set_value("multiplayer_auto_ready", bool(value))

func _configure_settings_scene(scene: Node, back_callable: Callable) -> void:
	if scene.has_signal("back_requested"):
		scene.connect("back_requested", back_callable)
	if scene.has_signal("master_volume_changed"):
		scene.connect("master_volume_changed", Callable(self, "_on_master_volume_changed"))
	if scene.has_signal("music_volume_changed"):
		scene.connect("music_volume_changed", Callable(self, "_on_music_volume_changed"))
	if scene.has_signal("sfx_volume_changed"):
		scene.connect("sfx_volume_changed", Callable(self, "_on_sfx_volume_changed"))
	if scene.has_signal("resolution_changed"):
		scene.connect("resolution_changed", Callable(self, "_on_resolution_changed"))
	if scene.has_signal("fullscreen_toggled"):
		scene.connect("fullscreen_toggled", Callable(self, "_on_fullscreen_toggled"))
	if scene.has_signal("player_name_changed"):
		scene.connect("player_name_changed", Callable(self, "_on_player_name_changed"))
	if scene.has_signal("default_character_changed"):
		scene.connect("default_character_changed", Callable(self, "_on_default_character_changed"))
	if scene.has_signal("key_binding_changed"):
		scene.connect("key_binding_changed", Callable(self, "_on_key_binding_changed"))
	if scene.has_signal("multiplayer_setting_changed"):
		scene.connect("multiplayer_setting_changed", Callable(self, "_on_multiplayer_setting_changed"))
	if scene.has_method("set_master_volume"):
		scene.set_master_volume(_config_service.get_value("master_volume", 1.0))
	if scene.has_method("set_music_volume"):
		var master: float = float(_config_service.get_value("master_volume", 1.0))
		scene.set_music_volume(_config_service.get_value("music_volume", master))
	if scene.has_method("set_sfx_volume"):
		var master_default: float = float(_config_service.get_value("master_volume", 1.0))
		scene.set_sfx_volume(_config_service.get_value("sfx_volume", master_default))
	if scene.has_method("set_resolution"):
		var width: int = int(_config_service.get_value("display_width", 1920))
		var height: int = int(_config_service.get_value("display_height", 1080))
		scene.set_resolution(Vector2i(width, height))
	if scene.has_method("set_fullscreen"):
		scene.set_fullscreen(bool(_config_service.get_value("fullscreen", false)))
	if scene.has_method("set_player_name"):
		scene.set_player_name(String(_config_service.get_value("player_name", "Player")))
	if scene.has_method("set_default_character"):
		var default_code: String = String(_config_service.get_value("default_character_code", "vanguard"))
		scene.set_default_character(default_code)
	if scene.has_method("set_key_bindings"):
		var stored_bindings: Variant = _config_service.get_value("key_bindings", {})
		var bindings_dict: Dictionary = {}
		if typeof(stored_bindings) == TYPE_DICTIONARY:
			bindings_dict = stored_bindings.duplicate()
		scene.set_key_bindings(bindings_dict)
	if scene.has_method("set_multiplayer_settings"):
		var multiplayer_settings: Dictionary = {
			"connection_method": _config_service.get_value("multiplayer_connection_method", "AUTO"),
			"show_ping": bool(_config_service.get_value("multiplayer_show_ping", true)),
			"auto_ready": bool(_config_service.get_value("multiplayer_auto_ready", false)),
		}
		scene.set_multiplayer_settings(multiplayer_settings)

func _show_pause_menu() -> void:
	_clear_overlay()
	_return_to_pause_after_settings = false
	_return_to_game_over_after_settings = false
	var pause_menu: Control = PauseMenuScene.instantiate()
	pause_menu.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_overlay_scene = pause_menu
	_mount_overlay(pause_menu)
	_assign_pause_run_summary(pause_menu)
	get_tree().paused = true
	if pause_menu.has_signal("resume_requested"):
		pause_menu.connect("resume_requested", Callable(self, "_on_pause_resume_requested"))
	if pause_menu.has_signal("restart_requested"):
		pause_menu.connect("restart_requested", Callable(self, "_on_pause_restart_requested"))
	if pause_menu.has_signal("character_select_requested"):
		pause_menu.connect("character_select_requested", Callable(self, "_on_pause_character_requested"))
	if pause_menu.has_signal("settings_requested"):
		pause_menu.connect("settings_requested", Callable(self, "_on_pause_settings_requested"))
	if pause_menu.has_signal("quit_to_menu_requested"):
		pause_menu.connect("quit_to_menu_requested", Callable(self, "_on_pause_quit_requested"))

func _show_settings_overlay(from_pause: bool, from_game_over: bool = false) -> void:
	_clear_overlay()
	_return_to_pause_after_settings = from_pause
	_return_to_game_over_after_settings = from_game_over
	var settings_overlay: Control = SettingsMenuScene.instantiate()
	settings_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_overlay_scene = settings_overlay
	_mount_overlay(settings_overlay)
	_configure_settings_scene(settings_overlay, Callable(self, "_on_settings_overlay_back"))
	get_tree().paused = true

func _on_pause_requested() -> void:
	if _overlay_scene:
		return
	_show_pause_menu()

func _on_pause_resume_requested() -> void:
	_clear_overlay(true)

func _on_pause_restart_requested() -> void:
	_on_game_over_retry_requested()

func _on_pause_character_requested() -> void:
	_clear_overlay(true)
	change_state("character_select")

func _on_pause_settings_requested() -> void:
	_clear_overlay()
	_show_settings_overlay(true)

func _on_pause_quit_requested() -> void:
	_clear_overlay(true)
	change_state("menu")

func _assign_pause_run_summary(pause_menu: Control) -> void:
	if not pause_menu:
		return
	if not pause_menu.has_method("set_run_summary"):
		return
	var wave_index: int = 0
	var total_kills: int = 0
	var total_time: float = 0.0
	if _current_scene and _current_scene is WorldController:
		var world := _current_scene as WorldController
		if world:
			wave_index = world.get_current_wave_index()
			total_kills = world.get_total_kills()
			total_time = world.get_total_run_time()
	pause_menu.set_run_summary(wave_index, total_kills, total_time)

func _on_settings_overlay_back() -> void:
	var return_to_pause := _return_to_pause_after_settings
	var return_to_game_over := _return_to_game_over_after_settings
	var should_unpause := not return_to_pause and not return_to_game_over
	_clear_overlay(should_unpause)
	if return_to_pause:
		_show_pause_menu()
	elif return_to_game_over:
		_show_game_over_overlay(_last_run_outcome, _last_run_record)

func _on_achievements_requested() -> void:
	_show_achievements_overlay()

func _on_leaderboards_requested() -> void:
	_show_leaderboard_overlay()

func _show_achievements_overlay() -> void:
	_clear_overlay()
	var achievements_menu: Control = AchievementsMenuScene.instantiate()
	_overlay_scene = achievements_menu
	_mount_overlay(achievements_menu)
	if achievements_menu.has_method("set_achievement_service") and _achievement_service:
		achievements_menu.set_achievement_service(_achievement_service)
	if achievements_menu.has_method("set_roster") and _character_roster:
		achievements_menu.set_roster(_character_roster)
	if achievements_menu.has_signal("closed"):
		achievements_menu.connect("closed", Callable(self, "_on_achievements_overlay_closed"))

func _on_achievements_overlay_closed() -> void:
	_clear_overlay()

func _show_leaderboard_overlay() -> void:
	_clear_overlay()
	var leaderboard_menu: Control = LeaderboardMenuScene.instantiate()
	_overlay_scene = leaderboard_menu
	_mount_overlay(leaderboard_menu)
	if leaderboard_menu.has_method("set_leaderboard_service") and _leaderboard_service:
		leaderboard_menu.set_leaderboard_service(_leaderboard_service)
	if leaderboard_menu.has_method("set_roster") and _character_roster:
		leaderboard_menu.set_roster(_character_roster)
	if leaderboard_menu.has_signal("closed"):
		leaderboard_menu.connect("closed", Callable(self, "_on_leaderboard_overlay_closed"))

func _on_leaderboard_overlay_closed() -> void:
	_clear_overlay()

func _clear_overlay(unpause: bool = false) -> void:
	if _overlay_scene:
		_overlay_scene.queue_free()
		_overlay_scene = null
		_set_main_menu_title_visible(true)
	if unpause:
		get_tree().paused = false
	_return_to_pause_after_settings = false
	_return_to_game_over_after_settings = false

func _show_game_over_overlay(outcome: String, record: Dictionary) -> void:
	_clear_overlay()
	_last_run_record = record.duplicate(true)
	_last_run_outcome = outcome
	var overlay: Control = GameOverMenuScene.instantiate()
	_overlay_scene = overlay
	_mount_overlay(overlay)
	get_tree().paused = true
	if overlay.has_method("set_record"):
		overlay.set_record(_last_run_record)
	elif overlay.has_method("set_run_summary"):
		var score := int(_last_run_record.get("score", 0))
		var waves := int(_last_run_record.get("waves_survived", 0))
		var kills := int(_last_run_record.get("enemies_killed", 0))
		var time_seconds := int(_last_run_record.get("survival_time_seconds", 0))
		overlay.set_run_summary(score, waves, kills, time_seconds, outcome)
	if overlay.has_signal("retry_requested"):
		overlay.connect("retry_requested", Callable(self, "_on_game_over_retry_requested"))
	if overlay.has_signal("character_select_requested"):
		overlay.connect("character_select_requested", Callable(self, "_on_game_over_character_requested"))
	if overlay.has_signal("settings_requested"):
		overlay.connect("settings_requested", Callable(self, "_on_game_over_settings_requested"))
	if overlay.has_signal("main_menu_requested"):
		overlay.connect("main_menu_requested", Callable(self, "_on_game_over_menu_requested"))

func _on_world_run_ended(outcome: String, record: Dictionary) -> void:
	_show_game_over_overlay(outcome, record)

func _on_game_over_retry_requested() -> void:
	_clear_overlay(true)
	if _state_service.get_state() == "gameplay":
		_match_state("gameplay")
	else:
		change_state("gameplay")

func _on_game_over_character_requested() -> void:
	_clear_overlay(true)
	change_state("character_select")

func _on_game_over_settings_requested() -> void:
	_show_settings_overlay(false, true)

func _on_game_over_menu_requested() -> void:
	_clear_overlay(true)
	change_state("menu")

func _initialize_character_roster() -> void:
	if CharacterRosterResource:
		_character_roster = CharacterRosterResource.duplicate(true)
	if _character_roster and _character_roster.has_method("ensure_loaded"):
		_character_roster.ensure_loaded()
	var saved_code := str(_config_service.get_value("last_character_code", ""))
	if _character_roster and _character_roster.has_method("get_character_by_code"):
		var saved_character: Resource = _character_roster.get_character_by_code(saved_code)
		_selected_character = saved_character if saved_character else _character_roster.get_default_character()
	else:
		_selected_character = null
	var stored_map_id := String(_config_service.get_value("last_map_id", ""))
	var stored_biome_id := String(_config_service.get_value("last_biome_id", ""))
	var stored_time_id := String(_config_service.get_value("last_time_of_day_id", ""))
	var stored_seed := int(_config_service.get_value("last_environment_seed", 0))
	var stored_random := bool(_config_service.get_value("last_random_events", false))
	_selected_mission_config = {}
	if stored_map_id != "" or stored_biome_id != "" or stored_time_id != "" or stored_seed != 0 or stored_random:
		_selected_mission_config = {
			"map_id": StringName(stored_map_id),
			"biome_id": StringName(stored_biome_id),
			"time_of_day_id": StringName(stored_time_id),
			"environment_seed": stored_seed,
			"random_events": stored_random
		}

func _configure_main_menu_scene(scene: Node) -> void:
	_ensure_music("main_menu")
	if scene.has_signal("start_game_requested"):
		scene.connect("start_game_requested", Callable(self, "_on_start_game_requested"))
	if scene.has_signal("settings_requested"):
		scene.connect("settings_requested", Callable(self, "_on_settings_requested"))
	if scene.has_signal("leaderboards_requested"):
		scene.connect("leaderboards_requested", Callable(self, "_on_leaderboards_requested"))
	if scene.has_signal("achievements_requested"):
		scene.connect("achievements_requested", Callable(self, "_on_achievements_requested"))
	if scene.has_method("set_last_selected_character") and _selected_character:
		scene.set_last_selected_character(_selected_character)

func _configure_character_select_scene(scene: Node) -> void:
	_ensure_music("character_select")
	if scene.has_signal("character_confirmed"):
		scene.connect("character_confirmed", Callable(self, "_on_character_confirmed"))
	if scene.has_signal("back_requested"):
		scene.connect("back_requested", Callable(self, "_on_character_select_back"))
	if scene.has_method("set_roster") and _character_roster:
		scene.set_roster(_character_roster)
	if scene.has_method("set_initial_selection") and _selected_character:
		var code: String = ""
		if _selected_character.has_method("get"):
			var value = _selected_character.get("code_name")
			if typeof(value) == TYPE_STRING:
				code = value
		if code != "":
			scene.set_initial_selection(code)
	if scene.has_method("set_mission_config") and not _selected_mission_config.is_empty():
		scene.set_mission_config(_selected_mission_config.duplicate(true))

func _configure_world_scene(scene: Node) -> void:
	if scene.has_signal("exit_to_menu_requested"):
		scene.connect("exit_to_menu_requested", Callable(self, "_on_exit_to_menu_requested"))
	if scene.has_signal("pause_requested"):
		scene.connect("pause_requested", Callable(self, "_on_pause_requested"))
	if scene.has_signal("run_ended"):
		scene.connect("run_ended", Callable(self, "_on_world_run_ended"))
	if _achievement_service:
		_achievement_service.reset_run_stats()
	var profile: Resource = _ensure_selected_character()
	if scene.has_method("set_character_profile") and profile:
		scene.set_character_profile(profile)
	if scene.has_method("set_environment_profile"):
		var mission_config: Dictionary = _selected_mission_config if _selected_mission_config else {}
		var biome_id: StringName = mission_config.get("biome_id", StringName(""))
		var time_id: StringName = mission_config.get("time_of_day_id", StringName(""))
		var env_seed: int = int(mission_config.get("environment_seed", 0))
		if biome_id != StringName("") or time_id != StringName("") or env_seed > 0:
			scene.set_environment_profile(biome_id, time_id, env_seed)

func _ensure_music(track_name: StringName) -> void:
	if _audio_director == null:
		return
	var desired_path := ""
	var track_key := String(track_name).to_lower()
	if typeof(_audio_director.MUSIC_TRACKS) == TYPE_DICTIONARY:
		desired_path = String(_audio_director.MUSIC_TRACKS.get(track_key, ""))
	var current_path := ""
	if _audio_director.has_method("get_current_music_path"):
		current_path = _audio_director.get_current_music_path()
	if desired_path != "" and current_path == desired_path:
		return
	if _audio_director.has_method("play_music_by_name"):
		_audio_director.play_music_by_name(track_name)

func _ensure_selected_character():
	if _selected_character:
		return _selected_character
	if _character_roster and _character_roster.has_method("get_default_character"):
		_selected_character = _character_roster.get_default_character()
	return _selected_character

func _on_character_confirmed(character, mission_config: Dictionary = {}) -> void:
	_selected_character = character
	if mission_config:
		_selected_mission_config = mission_config.duplicate(true)
		_cache_last_mission_selection(_selected_mission_config)
	else:
		_selected_mission_config = {}
	if _selected_character:
		var code: String = ""
		if _selected_character.has_method("get"):
			var value = _selected_character.get("code_name")
			if typeof(value) == TYPE_STRING:
				code = value
		if code != "":
			_config_service.set_value("last_character_code", code)
	change_state("gameplay")

func _on_character_select_back() -> void:
	change_state("menu")

func _cache_last_mission_selection(config: Dictionary) -> void:
	var map_id_value: Variant = config.get("map_id", "")
	var biome_id_value: Variant = config.get("biome_id", "")
	var time_id_value: Variant = config.get("time_of_day_id", "")
	var seed_value: int = int(config.get("environment_seed", 0))
	var random_events_value: bool = bool(config.get("random_events", false))
	_config_service.set_value("last_map_id", String(map_id_value))
	_config_service.set_value("last_biome_id", String(biome_id_value))
	_config_service.set_value("last_time_of_day_id", String(time_id_value))
	_config_service.set_value("last_environment_seed", seed_value)
	_config_service.set_value("last_random_events", random_events_value)
