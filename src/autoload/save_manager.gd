extends Node

## Save Manager
## Manages persistent game profile, match history, and duel statistics.

const PROFILE_PATH = "user://player_profile.json"
const SAVE_MATCH_PATH = "user://active_match.json"

var profile_data: Dictionary = {
	"player_name": "Grandmaster Duelist",
	"matches_played": 0,
	"matches_won": 0,
	"matches_lost": 0,
	"duels_fought": 0,
	"duels_won": 0,
	"pawns_ascended": 0,
	"underdog_victories": 0, # e.g. pawn beating queen or rook
	"favorite_piece": "Knight",
	"unlocked_arenas": ["The Throne Room", "Colosseum of Checkmate"],
}

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	if not FileAccess.file_exists(PROFILE_PATH):
		save_profile()
		return

	var file = FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		var parsed = JSON.parse_string(json_str)
		if parsed is Dictionary:
			for key in parsed:
				profile_data[key] = parsed[key]
			Logger.info("SaveManager", "Player profile loaded")
		file.close()

func save_profile() -> void:
	var file = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(profile_data, "\t")
		file.store_string(json_str)
		file.close()
		Logger.info("SaveManager", "Player profile persisted")
		EventBus.profile_updated.emit(profile_data)

func record_duel_result(winner_is_attacker: bool, winner_piece_type: GameEnums.PieceType, loser_piece_type: GameEnums.PieceType, player_won: bool) -> void:
	profile_data["duels_fought"] = profile_data.get("duels_fought", 0) + 1
	if player_won:
		profile_data["duels_won"] = profile_data.get("duels_won", 0) + 1
	
	# Underdog detection (e.g. Pawn defeating higher tier piece)
	if winner_piece_type == GameEnums.PieceType.PAWN and loser_piece_type != GameEnums.PieceType.PAWN:
		profile_data["underdog_victories"] = profile_data.get("underdog_victories", 0) + 1
	
	save_profile()

func record_match_end(player_won: bool) -> void:
	profile_data["matches_played"] = profile_data.get("matches_played", 0) + 1
	if player_won:
		profile_data["matches_won"] = profile_data.get("matches_won", 0) + 1
	else:
		profile_data["matches_lost"] = profile_data.get("matches_lost", 0) + 1
	save_profile()

func has_saved_match() -> bool:
	return FileAccess.file_exists(SAVE_MATCH_PATH)

func save_active_match(match_dict: Dictionary) -> void:
	var file = FileAccess.open(SAVE_MATCH_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(match_dict))
		file.close()
		Logger.info("SaveManager", "Active match saved")

func load_saved_match() -> Dictionary:
	if not has_saved_match():
		return {}
	var file = FileAccess.open(SAVE_MATCH_PATH, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		var parsed = JSON.parse_string(json_str)
		file.close()
		if parsed is Dictionary:
			return parsed
	return {}

func clear_saved_match() -> void:
	if has_saved_match():
		DirAccess.remove_absolute(SAVE_MATCH_PATH)
