extends Node

## Game Manager
## Global state orchestrator for Duel Chess: Battle Remake

var current_state: GameEnums.GameState = GameEnums.GameState.BOOT
var previous_state: GameEnums.GameState = GameEnums.GameState.BOOT

var current_mode: GameEnums.GameMode = GameEnums.GameMode.VS_AI
var active_turn_color: GameEnums.PieceColor = GameEnums.PieceColor.WHITE
var turn_count: int = 1

# Active duel state container
var active_attacker_piece: Resource = null
var active_defender_piece: Resource = null
var active_duel_position: Vector2i = Vector2i(-1, -1)

# Match statistics
var match_duels_count: int = 0
var white_pieces_captured: int = 0
var black_pieces_captured: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_events()

func _connect_events() -> void:
	EventBus.duel_completed.connect(_on_duel_completed)

func change_state(new_state: GameEnums.GameState) -> void:
	if current_state == new_state:
		return
	previous_state = current_state
	current_state = new_state
	Logger.info("GameManager", "State changed: %s -> %s" % [previous_state, new_state])
	EventBus.game_state_changed.emit(new_state, previous_state)

func start_new_match(mode: GameEnums.GameMode = GameEnums.GameMode.VS_AI, ai_diff: GameEnums.AIDifficulty = GameEnums.AIDifficulty.MEDIUM) -> void:
	current_mode = mode
	active_turn_color = GameEnums.PieceColor.WHITE
	turn_count = 1
	match_duels_count = 0
	white_pieces_captured = 0
	black_pieces_captured = 0
	
	PlatformManager.set_keep_screen_on(true)
	change_state(GameEnums.GameState.BOARD_TURN)
	EventBus.match_started.emit(mode, ai_diff)
	EventBus.turn_changed.emit(active_turn_color, turn_count)

func advance_turn() -> void:
	active_turn_color = GameEnums.PieceColor.BLACK if active_turn_color == GameEnums.PieceColor.WHITE else GameEnums.PieceColor.WHITE
	if active_turn_color == GameEnums.PieceColor.WHITE:
		turn_count += 1
	EventBus.turn_changed.emit(active_turn_color, turn_count)

func start_duel(attacker: Resource, defender: Resource, target_tile: Vector2i) -> void:
	active_attacker_piece = attacker
	active_defender_piece = defender
	active_duel_position = target_tile
	match_duels_count += 1
	
	change_state(GameEnums.GameState.DUEL_COMBAT)
	EventBus.duel_triggered.emit(attacker, defender, target_tile)

func _on_duel_completed(winner_side: int, winner_data: Resource, loser_data: Resource, battle_pos: Vector2i) -> void:
	# winner_side: 0 = attacker, 1 = defender
	var winner_color = winner_data.color if winner_data != null else GameEnums.PieceColor.WHITE
	var loser_color = loser_data.color if loser_data != null else GameEnums.PieceColor.BLACK
	
	if loser_color == GameEnums.PieceColor.WHITE:
		white_pieces_captured += 1
	else:
		black_pieces_captured += 1

	var player_won = (winner_color == GameEnums.PieceColor.WHITE)
	SaveManager.record_duel_result(
		winner_side == 0,
		winner_data.type if winner_data else GameEnums.PieceType.PAWN,
		loser_data.type if loser_data else GameEnums.PieceType.PAWN,
		player_won
	)

	# Return to board turn state
	change_state(GameEnums.GameState.BOARD_TURN)

func end_match(winner_color: GameEnums.PieceColor, reason: String) -> void:
	change_state(GameEnums.GameState.GAME_OVER)
	PlatformManager.set_keep_screen_on(false)
	var player_won = (winner_color == GameEnums.PieceColor.WHITE)
	SaveManager.record_match_end(player_won)
	EventBus.match_ended.emit(winner_color, reason)

func toggle_pause() -> void:
	if current_state == GameEnums.GameState.PAUSED:
		get_tree().paused = false
		change_state(previous_state)
		EventBus.match_paused.emit(false)
	elif current_state == GameEnums.GameState.BOARD_TURN or current_state == GameEnums.GameState.DUEL_COMBAT:
		get_tree().paused = true
		change_state(GameEnums.GameState.PAUSED)
		EventBus.match_paused.emit(true)
