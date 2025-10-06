extends Node
class_name AudioDirector

## Centralized audio playback and bus management.
## Autoload to coordinate music, ambience, and SFX routing.
## Expects "Music" and "SFX" buses defined in the project settings; adjust as needed.

var _music_player: AudioStreamPlayer
var _sfx_bus := "SFX"
var _music_bus := "Music"
var _master_volume := 1.0

func initialize() -> void:
	## Instantiate default players and configure buses.
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.bus = _music_bus
		add_child(_music_player)
	_apply_master_volume()

func play_music(stream: AudioStream, fade_time: float = 0.5) -> void:
	## TODO: Implement cross-fade logic.
	if stream == null:
		return
	if _music_player == null:
		initialize()
	_music_player.stream = stream
	_music_player.play()
	# Fade logic placeholder until implemented.
	if fade_time <= 0.0:
		_music_player.volume_db = 0.0

func play_sfx(stream: AudioStream, pitch_scale: float = 1.0) -> void:
	## TODO: Route quick sound effects through SFX bus.
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.bus = _sfx_bus
	player.pitch_scale = pitch_scale
	player.stream = stream
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func stop_music(fade_time: float = 0.5) -> void:
	if _music_player == null:
		return
	if fade_time <= 0.0:
		_music_player.stop()
	else:
		# TODO: replace with tweened fade-out.
		_music_player.stop()

func set_master_volume(value: float) -> void:
	_master_volume = clamp(value, 0.0, 1.0)
	_apply_master_volume()

func get_master_volume() -> float:
	return _master_volume

func _apply_master_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus == -1:
		return
	var linear_value: float = max(_master_volume, 0.0001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(linear_value))
