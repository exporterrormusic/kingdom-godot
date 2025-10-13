extends Node
class_name AudioDirector

## Centralized audio playback and bus management.
## Autoload to coordinate music, ambience, and SFX routing.
## Expects "Music" and "SFX" buses defined in the project settings; adjust as needed.

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const MASTER_BUS := "Master"
const ASSET_PREFIX := "res://"
const BATTLE_MUSIC_DIR := "res://assets/sounds/music/battle"

const MUSIC_TRACKS := {
	"main_menu": "res://assets/sounds/music/main-menu.mp3",
	"character_select": "res://assets/sounds/music/character-select.mp3",
	"victory": "res://assets/sounds/music/victory.mp3",
	"defeat": "res://assets/sounds/music/defeat.mp3"
}

const WEAPON_FILE_MAP := {
	"Assault Rifle": "AR",
	"assault_rifle": "AR",
	"Rocket Launcher": "rocket",
	"rocket_launcher": "rocket",
	"Shotgun": "shotgun",
	"shotgun": "shotgun",
	"SMG": "SMG",
	"smg": "SMG",
	"Sniper": "sniper",
	"sniper": "sniper",
	"Sword": "sword",
	"sword": "sword",
	"Minigun": "minigun",
	"minigun": "minigun"
}

var _music_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _looping_players: Dictionary = {}
var _stream_cache: Dictionary = {}
var _weapon_fire_counters: Dictionary = {}

var _master_volume := 1.0
var _music_volume := 1.0
var _sfx_volume := 1.0
var _current_music_path: String = ""

func initialize() -> void:
	## Instantiate default players and configure buses.
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "MusicPlayer"
		_music_player.bus = MUSIC_BUS
		add_child(_music_player)
	if _ambient_player == null:
		_ambient_player = AudioStreamPlayer.new()
		_ambient_player.name = "AmbientPlayer"
		_ambient_player.bus = MUSIC_BUS
		add_child(_ambient_player)
	_apply_bus_volumes()


func play_music_by_name(track_name: StringName, loop: bool = true, fade_time: float = 0.5) -> void:
	var path: String = MUSIC_TRACKS.get(String(track_name).to_lower(), "")
	if path == "":
		push_warning("AudioDirector: Unknown music track %s" % track_name)
		return
	play_music_by_path(path, loop, fade_time)

func play_random_battle_track(fade_time: float = 0.5) -> void:
	var candidates := _list_files_in_directory(BATTLE_MUSIC_DIR)
	if candidates.is_empty():
		push_warning("AudioDirector: No battle music files found in %s" % BATTLE_MUSIC_DIR)
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var choice := candidates[rng.randi_range(0, candidates.size() - 1)]
	play_music_by_path(choice, true, fade_time)

func play_music_by_path(path: String, loop: bool = true, fade_time: float = 0.5) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	initialize()
	var prepared := _ensure_loop_state(stream, loop)
	if fade_time > 0.05 and _music_player.playing:
		_start_music_with_fade(prepared, fade_time)
	else:
		_music_player.stop()
		_music_player.stream = prepared
		_music_player.volume_db = -12.0 if fade_time > 0.05 else 0.0
		_music_player.play()
		if fade_time > 0.05:
			var tween := create_tween()
			tween.tween_property(_music_player, "volume_db", 0.0, fade_time)
	_current_music_path = _resolve_path(path)

func stop_music(fade_time: float = 0.3) -> void:
	if _music_player == null or not _music_player.playing:
		return
	if fade_time <= 0.05:
		_music_player.stop()
		_current_music_path = ""
		return
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -48.0, fade_time)
	tween.finished.connect(func():
		if _music_player:
			_music_player.stop()
			_music_player.volume_db = 0.0
			_current_music_path = ""
	)

func play_ambient_loop(path: String, fade_time: float = 0.4) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	initialize()
	var prepared := _ensure_loop_state(stream, true)
	if fade_time > 0.05 and _ambient_player.playing:
		var tween := create_tween()
		tween.tween_property(_ambient_player, "volume_db", -48.0, fade_time)
		tween.finished.connect(func():
			if _ambient_player:
				_ambient_player.stop()
				_ambient_player.stream = prepared
				_ambient_player.volume_db = -24.0
				_ambient_player.play()
				var fade_in := create_tween()
				fade_in.tween_property(_ambient_player, "volume_db", -3.0, fade_time)
		)
	else:
		_ambient_player.stop()
		_ambient_player.stream = prepared
		_ambient_player.volume_db = -6.0
		_ambient_player.play()

func stop_ambient(fade_time: float = 0.3) -> void:
	if _ambient_player == null or not _ambient_player.playing:
		return
	if fade_time <= 0.05:
		_ambient_player.stop()
		return
	var tween := create_tween()
	tween.tween_property(_ambient_player, "volume_db", -48.0, fade_time)
	tween.finished.connect(func():
		if _ambient_player:
			_ambient_player.stop()
			_ambient_player.volume_db = -6.0
	)

func play_sfx_by_path(path: String, pitch_scale: float = 1.0) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	var player := _request_sfx_player()
	player.pitch_scale = pitch_scale
	player.stream = stream
	player.volume_db = 0.0
	player.play()

func play_weapon_fire_sound(weapon_name: String, is_special_attack: bool = false) -> void:
	var key := _resolve_weapon_key(weapon_name)
	if key == "":
		push_warning("AudioDirector: No fire sound mapping for %s" % weapon_name)
		return
	var directory := "res://assets/sounds/sfx/weapons/%s" % key
	if is_special_attack:
		var special_path := "%s/special_%s.mp3" % [directory, key]
		if _stream_exists(special_path):
			play_sfx_by_path(special_path)
			return
	var variants := _collect_indexed_variants(directory, "fire", key)
	if variants.size() > 1:
		var counter: int = int(_weapon_fire_counters.get(key, 0))
		var index: int = counter % variants.size()
		_weapon_fire_counters[key] = (counter + 1) % variants.size()
		play_sfx_by_path(variants[index])
		return
	if variants.size() == 1:
		play_sfx_by_path(variants[0])
		return
	var fallback_mp3 := "%s/fire_%s.mp3" % [directory, key]
	if _stream_exists(fallback_mp3):
		play_sfx_by_path(fallback_mp3)
		return
	var fallback_wav := "%s/fire_%s.wav" % [directory, key]
	if _stream_exists(fallback_wav):
		play_sfx_by_path(fallback_wav)
		return
	push_warning("AudioDirector: Missing fire sound for weapon %s" % weapon_name)

func play_weapon_reload_sound(weapon_name: String) -> void:
	var key := _resolve_weapon_key(weapon_name)
	if key == "":
		push_warning("AudioDirector: No reload sound mapping for %s" % weapon_name)
		return
	var base := "res://assets/sounds/sfx/weapons/%s" % key
	var mp3_path := "%s/reload_%s.mp3" % [base, key]
	if _stream_exists(mp3_path):
		play_sfx_by_path(mp3_path)
		return
	var wav_path := "%s/reload_%s.wav" % [base, key]
	if _stream_exists(wav_path):
		play_sfx_by_path(wav_path)
		return
	push_warning("AudioDirector: Missing reload sound for weapon %s" % weapon_name)

func play_rocket_flight_sound() -> int:
	return play_looping_sfx("res://assets/sounds/sfx/weapons/rocket/rocket_fly.mp3", 1.0)

func stop_rocket_flight_sound(handle: int) -> void:
	stop_looping_sfx(handle)

func play_rocket_explosion_sound() -> void:
	play_sfx_by_path("res://assets/sounds/sfx/weapons/rocket/rocket_explosion.mp3")

func play_burst_voice(character_name: String) -> void:
	if character_name == "":
		return
	var lower_name := character_name.to_lower()
	var base := "res://assets/images/Characters/%s" % lower_name
	var wav_path := "%s/burst.wav" % base
	if _stream_exists(wav_path):
		play_sfx_by_path(wav_path)
		return
	var mp3_path := "%s/burst.mp3" % base
	if _stream_exists(mp3_path):
		play_sfx_by_path(mp3_path)
		return
	var fallback := "res://assets/sounds/voices/%s_burst.wav" % lower_name
	if _stream_exists(fallback):
		play_sfx_by_path(fallback)
		return
	push_warning("AudioDirector: Burst voice not found for %s" % character_name)

func play_looping_sfx(path: String, pitch_scale: float = 1.0) -> int:
	var stream := _load_stream(path)
	if stream == null:
		return -1
	var player := AudioStreamPlayer.new()
	player.bus = SFX_BUS
	player.pitch_scale = pitch_scale
	player.stream = _ensure_loop_state(stream, true)
	add_child(player)
	player.play()
	player.finished.connect(func(): player.play())
	var handle := player.get_instance_id()
	_looping_players[handle] = player
	player.tree_exited.connect(func():
		if _looping_players.has(handle):
			_looping_players.erase(handle)
	)
	return handle

func stop_looping_sfx(handle: int) -> void:
	if not _looping_players.has(handle):
		return
	var player: AudioStreamPlayer = _looping_players[handle]
	if player:
		player.stop()
		player.queue_free()
	_looping_players.erase(handle)

func set_master_volume(value: float) -> void:
	_master_volume = clamp(value, 0.0, 1.0)
	_apply_bus_volumes()

func set_music_volume(value: float) -> void:
	_music_volume = clamp(value, 0.0, 1.0)
	_apply_bus_volumes()

func set_sfx_volume(value: float) -> void:
	_sfx_volume = clamp(value, 0.0, 1.0)
	_apply_bus_volumes()

func get_master_volume() -> float:
	return _master_volume

func get_music_volume() -> float:
	return _music_volume

func get_sfx_volume() -> float:
	return _sfx_volume

func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing

func get_current_music_path() -> String:
	return _current_music_path

func _apply_bus_volumes() -> void:
	_set_bus_volume(MASTER_BUS, _master_volume)
	_set_bus_volume(MUSIC_BUS, _music_volume)
	_set_bus_volume(SFX_BUS, _sfx_volume)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	var linear: float = clampf(value, 0.0001, 1.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear))

func _start_music_with_fade(stream: AudioStream, fade_time: float) -> void:
	var fade_out := create_tween()
	fade_out.tween_property(_music_player, "volume_db", -48.0, fade_time * 0.5)
	fade_out.finished.connect(func():
		if not _music_player:
			return
		_music_player.stop()
		_music_player.stream = stream
		_music_player.volume_db = -30.0
		_music_player.play()
		var fade_in := create_tween()
		fade_in.tween_property(_music_player, "volume_db", 0.0, max(0.01, fade_time * 0.5))
	)

func _request_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if player == null:
			continue
		if not player.playing:
			return player
	var new_player := AudioStreamPlayer.new()
	new_player.bus = SFX_BUS
	add_child(new_player)
	_sfx_pool.append(new_player)
	return new_player

func _resolve_path(path: String) -> String:
	if path == "":
		return ""
	if path.begins_with("res://"):
		return path
	if path.begins_with("user://"):
		return path
	if path.begins_with("assets/"):
		return ASSET_PREFIX + path
	return path

func _load_stream(path: String) -> AudioStream:
	var resolved := _resolve_path(path)
	if resolved == "":
		return null
	if _stream_cache.has(resolved):
		return _stream_cache[resolved]
	var stream: AudioStream = ResourceLoader.load(resolved)
	if stream == null:
		push_warning("AudioDirector: Failed to load stream %s" % resolved)
		return null
	_stream_cache[resolved] = stream
	return stream

func _stream_exists(path: String) -> bool:
	var resolved := _resolve_path(path)
	return resolved != "" and ResourceLoader.exists(resolved)

func _ensure_loop_state(stream: AudioStream, should_loop: bool) -> AudioStream:
	if stream == null:
		return null
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var desired := AudioStreamWAV.LOOP_FORWARD if should_loop else AudioStreamWAV.LOOP_DISABLED
		if wav.loop_mode == desired:
			return wav
		var wav_clone := wav.duplicate() as AudioStreamWAV
		wav_clone.loop_mode = desired
		return wav_clone
	if stream is AudioStreamMP3:
		var mp3 := stream as AudioStreamMP3
		if mp3.loop == should_loop:
			return mp3
		var mp3_clone := mp3.duplicate() as AudioStreamMP3
		mp3_clone.loop = should_loop
		return mp3_clone
	if stream is AudioStreamOggVorbis:
		var ogg := stream as AudioStreamOggVorbis
		if ogg.loop == should_loop:
			return ogg
		var ogg_clone := ogg.duplicate() as AudioStreamOggVorbis
		ogg_clone.loop = should_loop
		return ogg_clone
	return stream

func _collect_indexed_variants(directory: String, prefix: String, key: String) -> Array[String]:
	var variants: Array[String] = []
	for i in range(1, 9):
		var candidate := "%s/%s%d_%s.mp3" % [directory, prefix, i, key]
		if _stream_exists(candidate):
			variants.append(candidate)
			continue
		break
	return variants

func _resolve_weapon_key(weapon_name: String) -> String:
	if weapon_name == "":
		return ""
	if WEAPON_FILE_MAP.has(weapon_name):
		return WEAPON_FILE_MAP[weapon_name]
	var normalized := weapon_name.strip_edges().to_lower()
	if WEAPON_FILE_MAP.has(normalized):
		return WEAPON_FILE_MAP[normalized]
	return ""

func _list_files_in_directory(path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if not dir.current_is_dir():
			var full_path := "%s/%s" % [path, entry_name]
			if ResourceLoader.exists(full_path):
				files.append(full_path)
		entry_name = dir.get_next()
	dir.list_dir_end()
	return files
