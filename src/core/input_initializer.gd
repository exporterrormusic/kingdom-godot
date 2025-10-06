extends Node
class_name InputInitializer

static func ensure_actions() -> void:
	var definitions := [
		{
			"name": "move_up",
			"events": [
				{"keycode": KEY_W},
				{"keycode": KEY_UP}
			]
		},
		{
			"name": "move_down",
			"events": [
				{"keycode": KEY_S},
				{"keycode": KEY_DOWN}
			]
		},
		{
			"name": "move_left",
			"events": [
				{"keycode": KEY_A},
				{"keycode": KEY_LEFT}
			]
		},
		{
			"name": "move_right",
			"events": [
				{"keycode": KEY_D},
				{"keycode": KEY_RIGHT}
			]
		},
		{
			"name": "fire_primary",
			"events": [
				{"mouse_button": MOUSE_BUTTON_LEFT}
			]
		},
		{
			"name": "fire_secondary",
			"events": [
				{"mouse_button": MOUSE_BUTTON_RIGHT}
			]
		},
		{
			"name": "dash",
			"events": [
				{"keycode": KEY_SHIFT}
			]
		},
		{
			"name": "burst",
			"events": [
				{"keycode": KEY_E}
			]
		},
		{
			"name": "reload",
			"events": [
				{"keycode": KEY_R}
			]
		},
		{
			"name": "ui_cancel",
			"events": [
				{"keycode": KEY_P},
				{"keycode": KEY_ESCAPE}
			]
		},
		{
			"name": "pause",
			"events": [
				{"keycode": KEY_PAUSE},
				{"keycode": KEY_P},
				{"keycode": KEY_ESCAPE}
			]
		}
	]

	for definition in definitions:
		var action_name: String = definition["name"]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		_remove_all_events(action_name)
		for event_def in definition["events"]:
			var event := _create_event(event_def)
			if event:
				InputMap.action_add_event(action_name, event)

static func _remove_all_events(action_name: String) -> void:
	var existing_events := InputMap.action_get_events(action_name)
	for ev in existing_events:
		InputMap.action_erase_event(action_name, ev)

static func _create_event(definition: Dictionary) -> InputEvent:
	if definition.has("mouse_button"):
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = definition["mouse_button"]
		return mouse_event
	var key_event := InputEventKey.new()
	if definition.has("keycode"):
		key_event.keycode = definition["keycode"]
		key_event.physical_keycode = definition["keycode"]
	return key_event
