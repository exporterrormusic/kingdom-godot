extends Control
class_name AchievementFeed

const DefaultToastScene := preload("res://scenes/ui/AchievementToast.tscn")

@export var max_visible: int = 3
@export var toast_scene: PackedScene

@onready var _container: VBoxContainer = %ToastContainer

var _achievement_service: AchievementService = null
var _queue: Array = []

func _ready() -> void:
	_achievement_service = _resolve_achievement_service()
	if not toast_scene:
		toast_scene = DefaultToastScene
	if _achievement_service:
		_achievement_service.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(id: String) -> void:
	if not _achievement_service:
		_achievement_service = _resolve_achievement_service()
	if not _achievement_service:
		return
	var data = _achievement_service.get_definition(id)
	if data:
		_queue.append(data)
		_process_queue()

func _process_queue() -> void:
	if not _container:
		return
	while _queue.size() > 0 and _container.get_child_count() < max_visible:
		var definition = _queue[0]
		_queue.remove_at(0)
		var toast := _create_toast(definition)
		if toast:
			_container.add_child(toast)

func _create_toast(definition) -> Control:
	if not toast_scene:
		return null
	var toast_instance := toast_scene.instantiate()
	if not toast_instance:
		return null
	if toast_instance.has_method("set_achievement"):
		toast_instance.set_achievement(definition)
	if toast_instance.has_signal("finished"):
		toast_instance.connect("finished", Callable(self, "_on_toast_finished"))
	return toast_instance

func _on_toast_finished(toast) -> void:
	if _container and toast and toast.get_parent() == _container:
		_container.remove_child(toast)
	_process_queue()


func _resolve_achievement_service() -> AchievementService:
	if not get_tree():
		return null
	var root := get_tree().root
	var candidate := root.find_child("AchievementService", true, false)
	if candidate and candidate is AchievementService:
		return candidate
	return null
