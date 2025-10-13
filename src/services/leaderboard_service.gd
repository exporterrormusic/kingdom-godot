extends Node
class_name LeaderboardService

## Aggregates and exposes leaderboard statistics stored in the save file.
## Mirrors the structure of the legacy pygame ScoreManager for parity.

signal records_updated

const CharacterRosterResource := preload("res://resources/characters/characters.tres")
const MAX_RECORDS_PER_CHARACTER := 10

var _save_service: SaveService = null
var _leaderboard_payload: Dictionary = {}
var _roster: CharacterRoster = null

func initialize(save_service: SaveService, save_data: Dictionary = {}, roster: CharacterRoster = null) -> void:
	_save_service = save_service
	set_roster(roster)
	_load_from_save(save_data)

func refresh(save_data: Dictionary) -> void:
	_load_from_save(save_data)
	records_updated.emit()

func set_roster(roster: CharacterRoster) -> void:
	_roster = roster
	if _roster and _roster.has_method("ensure_loaded"):
		_roster.ensure_loaded()

func get_ranked_entries(limit: int = 10) -> Array:
	var summary: Array = []
	var roster := _ensure_roster()
	var character_map: Dictionary = {}
	if roster:
		for character in roster.characters:
			if character == null:
				continue
			var code: String = String(character.code_name)
			if code == "":
				continue
			character_map[code] = character
			summary.append(_build_character_summary(code, character))

	var recorded_characters: Dictionary = _get_character_leaderboards()
	for code in recorded_characters.keys():
		var code_name := String(code)
		if code_name == "":
			continue
		if not character_map.has(code_name):
			summary.append(_build_character_summary(code_name, null))

	summary.sort_custom(Callable(self, "_compare_entries"))
	if limit <= 0 or limit >= summary.size():
		return summary
	return summary.slice(0, limit)

func get_player_rapture_cores() -> int:
	return int(_leaderboard_payload.get("player_rapture_cores", 0))

func add_player_rapture_cores(amount: int) -> int:
	if amount == 0:
		return get_player_rapture_cores()
	var current := get_player_rapture_cores()
	var updated: int = maxi(0, current + amount)
	_leaderboard_payload["player_rapture_cores"] = updated
	_persist()
	records_updated.emit()
	return updated

func set_player_rapture_cores(amount: int) -> void:
	var sanitized: int = maxi(0, amount)
	if sanitized == get_player_rapture_cores():
		return
	_leaderboard_payload["player_rapture_cores"] = sanitized
	_persist()
	records_updated.emit()

func update_record(character_code: String, record: Dictionary) -> void:
	if character_code == "":
		return
	var payload: Dictionary = _get_character_leaderboards()
	var list: Array = payload.get(character_code, [])
	list.append(record.duplicate(true))
	list.sort_custom(Callable(self, "_compare_records"))
	if list.size() > MAX_RECORDS_PER_CHARACTER:
		list = list.slice(0, MAX_RECORDS_PER_CHARACTER)
	payload[character_code] = list
	_leaderboard_payload["character_leaderboards"] = payload
	_persist()
	records_updated.emit()

func clear_leaderboard(character_code: String) -> void:
	var payload: Dictionary = _get_character_leaderboards()
	if payload.has(character_code):
		payload.erase(character_code)
		_leaderboard_payload["character_leaderboards"] = payload
		_persist()
		records_updated.emit()

func clear_all() -> void:
	_leaderboard_payload["character_leaderboards"] = {}
	_leaderboard_payload["player_rapture_cores"] = 0
	_persist()
	records_updated.emit()

func _load_from_save(save_data: Dictionary) -> void:
	var defaults: Dictionary = {
		"player_rapture_cores": 0,
		"character_leaderboards": {}
	}
	if typeof(save_data) == TYPE_DICTIONARY and save_data.has("leaderboards"):
		var raw_payload_variant: Variant = save_data.get("leaderboards", {})
		if typeof(raw_payload_variant) == TYPE_DICTIONARY:
			var raw_payload: Dictionary = raw_payload_variant as Dictionary
			var merged: Dictionary = defaults.duplicate(true)
			merged.merge(raw_payload, true)
			_leaderboard_payload = merged
		else:
			_leaderboard_payload = defaults.duplicate(true)
	else:
		_leaderboard_payload = defaults.duplicate(true)

func _ensure_roster() -> CharacterRoster:
	if _roster:
		return _roster
	if CharacterRosterResource:
		var roster: CharacterRoster = CharacterRosterResource.duplicate(true)
		if roster and roster.has_method("ensure_loaded"):
			roster.ensure_loaded()
		_roster = roster
	return _roster

func _build_character_summary(code: String, character) -> Dictionary:
	var entries: Array = []
	var leaderboards: Dictionary = _get_character_leaderboards()
	var stored_entries_variant: Variant = leaderboards.get(code)
	if stored_entries_variant is Array:
		entries = stored_entries_variant as Array
	var best_score := 0
	var best_wave := 0
	for record in entries:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		var score := int(record.get("score", record.get("best_score", 0)))
		if score > best_score:
			best_score = score
		var wave := int(record.get("waves_survived", record.get("best_waves", record.get("wave", 0))))
		if wave > best_wave:
			best_wave = wave

	var display_name := code.capitalize()
	var portrait: Texture2D = null
	if character:
		display_name = String(character.display_name)
		portrait = character.portrait_texture

	return {
		"code": code,
		"display_name": display_name,
		"portrait": portrait,
		"best_score": best_score,
		"best_wave": best_wave,
		"entries": entries.duplicate(true)
	}

func _get_character_leaderboards() -> Dictionary:
	var leaderboards_variant: Variant = _leaderboard_payload.get("character_leaderboards", {})
	if typeof(leaderboards_variant) == TYPE_DICTIONARY:
		return (leaderboards_variant as Dictionary).duplicate(true)
	return {}

func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	var score_a := int(a.get("best_score", 0))
	var score_b := int(b.get("best_score", 0))
	if score_a == score_b:
		return String(a.get("display_name", "")).nocasecmp_to(String(b.get("display_name", ""))) < 0
	return score_a > score_b

func _compare_records(a: Dictionary, b: Dictionary) -> bool:
	var score_a := int(a.get("score", a.get("best_score", 0)))
	var score_b := int(b.get("score", b.get("best_score", 0)))
	if score_a == score_b:
		var wave_a := int(a.get("waves_survived", a.get("wave", 0)))
		var wave_b := int(b.get("waves_survived", b.get("wave", 0)))
		if wave_a == wave_b:
			var kills_a := int(a.get("enemies_killed", 0))
			var kills_b := int(b.get("enemies_killed", 0))
			return kills_a > kills_b
		return wave_a > wave_b
	return score_a > score_b

func _persist() -> void:
	if _save_service == null:
		return
	var state: Dictionary = _save_service.get_state()
	state["leaderboards"] = _leaderboard_payload.duplicate(true)
	_save_service.save_state(state)
