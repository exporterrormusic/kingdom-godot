extends Node
class_name GameStateService

## Tracks the high-level flow state of the game and publishes transitions.
## Intended to be autoloaded for global access.

signal state_changed(previous_state: String, next_state: String)

var _current_state: String = "boot"

func initialize() -> void:
	## Called once during project boot to load configs and determine entry scene.
	## TODO: Integrate with ConfigService/SaveService once implemented.
	_current_state = "boot"

func get_state() -> String:
	return _current_state

func set_state(next_state: String) -> void:
	if next_state == _current_state:
		return
	var previous := _current_state
	_current_state = next_state
	emit_signal("state_changed", previous, _current_state)
