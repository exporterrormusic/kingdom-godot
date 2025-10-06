extends Node
class_name NetworkFacade

## Placeholder multiplayer API mirroring the pygame multiplayer manager.
## Swap out once a concrete networking strategy is chosen.

signal lobby_updated()
signal game_started()

var is_multiplayer_enabled := false

func host_game() -> void:
	## TODO: Implement host lobby creation using MultiplayerAPI.
	is_multiplayer_enabled = true
	emit_signal("lobby_updated")

func join_game(address: String) -> void:
	## TODO: Connect to remote host.
	assert(address.length() > 0)
	is_multiplayer_enabled = true
	emit_signal("lobby_updated")

func start_game() -> void:
	if not is_multiplayer_enabled:
		return
	emit_signal("game_started")
