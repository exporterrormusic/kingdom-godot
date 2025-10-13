extends Control
class_name GameOverMenu

signal retry_requested
signal character_select_requested
signal settings_requested
signal main_menu_requested

@onready var _outcome_label: Label = %OutcomeLabel
@onready var _score_value_label: Label = %ScoreValue
@onready var _wave_value_label: Label = %WaveValue
@onready var _kills_value_label: Label = %KillsValue
@onready var _time_value_label: Label = %TimeValue
@onready var _retry_button: Button = %RetryButton
@onready var _character_button: Button = %CharacterButton
@onready var _settings_button: Button = %SettingsButton
@onready var _menu_button: Button = %MenuButton

var _score: int = 0
var _waves: int = 0
var _kills: int = 0
var _time_seconds: int = 0
var _outcome: String = "death"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	set_process_unhandled_input(true)
	if _retry_button:
		_retry_button.pressed.connect(_on_retry_pressed)
	if _character_button:
		_character_button.pressed.connect(_on_character_pressed)
	if _settings_button:
		_settings_button.pressed.connect(_on_settings_pressed)
	if _menu_button:
		_menu_button.pressed.connect(_on_menu_pressed)
	if _retry_button:
		_retry_button.grab_focus()
	_refresh_summary()

func set_run_summary(score: int, waves: int, kills: int, time_seconds: int, outcome: String = "death") -> void:
	_score = max(0, score)
	_waves = max(0, waves)
	_kills = max(0, kills)
	_time_seconds = max(0, time_seconds)
	_outcome = outcome
	_refresh_summary()

func set_record(record: Dictionary) -> void:
	var score := int(record.get("score", 0))
	var waves := int(record.get("waves_survived", record.get("best_waves", 0)))
	var kills := int(record.get("enemies_killed", 0))
	var time_seconds := int(record.get("survival_time_seconds", 0))
	var outcome := String(record.get("outcome", "death"))
	set_run_summary(score, waves, kills, time_seconds, outcome)

func _refresh_summary() -> void:
	if _outcome_label:
		var pretty_outcome := _outcome.capitalize()
		if pretty_outcome == "Death":
			pretty_outcome = "Defeated"
		_outcome_label.text = pretty_outcome
	if _score_value_label:
		_score_value_label.text = String.num_int64(_score)
	if _wave_value_label:
		_wave_value_label.text = "%02d" % max(0, _waves)
	if _kills_value_label:
		_kills_value_label.text = str(max(0, _kills))
	if _time_value_label:
		_time_value_label.text = _format_time(_time_seconds)

func _format_time(total_seconds: int) -> String:
	var safe_seconds: int = max(0, total_seconds)
	var hours: int = floori(float(safe_seconds) / 3600.0)
	var minutes: int = floori(float(safe_seconds % 3600) / 60.0)
	var seconds: int = safe_seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]

func _on_retry_pressed() -> void:
	emit_signal("retry_requested")

func _on_character_pressed() -> void:
	emit_signal("character_select_requested")

func _on_settings_pressed() -> void:
	emit_signal("settings_requested")

func _on_menu_pressed() -> void:
	emit_signal("main_menu_requested")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		emit_signal("retry_requested")
		get_viewport().set_input_as_handled()
