extends Control
class_name AchievementToast

signal finished(toast: AchievementToast)

@export var display_time: float = 3.0

@onready var _title_label: Label = %TitleLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _timer: Timer = $DisplayTimer

func _ready() -> void:
	if _timer:
		_timer.wait_time = display_time
		_timer.timeout.connect(_on_timeout)
		_timer.start()

func set_achievement(data) -> void:
	if not data:
		return
	var title_text: String = "Achievement Unlocked"
	var description_text: String = ""
	if data.has_method("get"):
		var name_value = data.get("name")
		if typeof(name_value) == TYPE_STRING and name_value != "":
			title_text = name_value
		var description_value = data.get("description")
		if typeof(description_value) == TYPE_STRING:
			description_text = description_value
	if _title_label:
		_title_label.text = title_text
	if _description_label:
		_description_label.text = description_text

func _on_timeout() -> void:
	emit_signal("finished", self)
	queue_free()
