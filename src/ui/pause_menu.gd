extends Control
class_name PauseMenu

signal resume_requested
signal settings_requested
signal quit_to_menu_requested

@onready var _resume_button: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _wave_value_label: Label = %WaveValue
@onready var _kills_value_label: Label = %KillsValue
@onready var _time_value_label: Label = %TimeValue

var _current_wave: int = 0
var _current_kills: int = 0
var _current_time_seconds: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_process_unhandled_input(true)
	_resume_button.pressed.connect(_on_resume_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_resume_button.grab_focus()
	_refresh_run_summary()

func _on_resume_pressed() -> void:
	emit_signal("resume_requested")

func _on_settings_pressed() -> void:
	emit_signal("settings_requested")

func _on_quit_pressed() -> void:
	emit_signal("quit_to_menu_requested")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		emit_signal("resume_requested")
		get_viewport().set_input_as_handled()

func set_run_summary(wave_index: int, total_kills: int, total_seconds: float) -> void:
	_current_wave = max(0, wave_index)
	_current_kills = max(0, total_kills)
	_current_time_seconds = maxf(0.0, total_seconds)
	_refresh_run_summary()

func set_wave_index(wave_index: int) -> void:
	_current_wave = max(0, wave_index)
	_refresh_run_summary()

func set_total_kills(total_kills: int) -> void:
	_current_kills = max(0, total_kills)
	_refresh_run_summary()

func set_total_time(total_seconds: float) -> void:
	_current_time_seconds = maxf(0.0, total_seconds)
	_refresh_run_summary()

func _refresh_run_summary() -> void:
	if _wave_value_label:
		_wave_value_label.text = "%02d" % max(0, _current_wave)
	if _kills_value_label:
		_kills_value_label.text = str(max(0, _current_kills))
	if _time_value_label:
		_time_value_label.text = _format_time(_current_time_seconds)

func _format_time(total_seconds: float) -> String:
	var seconds: int = max(0, roundi(total_seconds))
	var hours: int = floori(float(seconds) / 3600.0)
	var minutes: int = floori(float(seconds % 3600) / 60.0)
	var rem_seconds: int = seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, rem_seconds]
	return "%02d:%02d" % [minutes, rem_seconds]
