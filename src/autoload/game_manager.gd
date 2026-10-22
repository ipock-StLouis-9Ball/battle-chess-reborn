extends Node

## Game Manager
## Global state orchestrator for Duel of Kings: Animated Chess

# Game States (matching GameEnums.GameState)
const STATE_BOOT: int = 0
const STATE_MAIN_MENU: int = 1
const STATE_MATCH_INIT: int = 2
const STATE_BOARD_TURN: int = 3
const STATE_DUEL_COMBAT: int = 4
const STATE_PAUSED: int = 5
const STATE_GAME_OVER: int = 6

# Piece Colors (matching GameEnums.PieceColor)
const COLOR_WHITE: int = 0
const COLOR_BLACK: int = 1

# Game Modes (matching GameEnums.GameMode)
const MODE_VS_AI: int = 0
const MODE_LOCAL_PASS_AND_PLAY: int = 1
const MODE_FAST_RESOLUTION: int = 2

var current_state: int = STATE_BOOT
var previous_state: int = STATE_BOOT

var current_mode: int = MODE_VS_AI
var active_turn_color: int = COLOR_WHITE
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
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").duel_completed.connect(_on_duel_completed)

func change_state(new_state: int) -> void:
	if current_state == new_state:
		return
	previous_state = current_state
	current_state = new_state
	print("[GameManager] State changed: %s -> %s" % [previous_state, new_state])
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").game_state_changed.emit(new_state, previous_state)

func start_new_match(mode: int = MODE_VS_AI, ai_diff: int = 1) -> void:
	current_mode = mode
	active_turn_color = COLOR_WHITE
	turn_count = 1
	match_duels_count = 0
	white_pieces_captured = 0
	black_pieces_captured = 0
	
	if has_node("/root/PlatformManager"):
		get_node("/root/PlatformManager").set_keep_screen_on(true)
	change_state(STATE_BOARD_TURN)
	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		eb.match_started.emit(mode, ai_diff)
		eb.turn_changed.emit(active_turn_color, turn_count)

func advance_turn() -> void:
	active_turn_color = COLOR_BLACK if active_turn_color == COLOR_WHITE else COLOR_WHITE
	if active_turn_color == COLOR_WHITE:
		turn_count += 1
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").turn_changed.emit(active_turn_color, turn_count)

func start_duel(attacker: Resource, defender: Resource, target_tile: Vector2i) -> void:
	active_attacker_piece = attacker
	active_defender_piece = defender
	active_duel_position = target_tile
	match_duels_count += 1
	
	change_state(STATE_DUEL_COMBAT)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").duel_triggered.emit(attacker, defender, target_tile)

func _on_duel_completed(winner_side: int, winner_data: Resource, loser_data: Resource, battle_pos: Vector2i) -> void:
	# winner_side: 0 = attacker, 1 = defender
	var winner_color = winner_data.get("color") if winner_data != null else COLOR_WHITE
	var loser_color = loser_data.get("color") if loser_data != null else COLOR_BLACK
	
	if loser_color == COLOR_WHITE:
		white_pieces_captured += 1
	else:
		black_pieces_captured += 1

	var player_won = (winner_color == COLOR_WHITE)
	if has_node("/root/SaveManager"):
		var atk_type = winner_data.get("type") if winner_data else 1
		var def_type = loser_data.get("type") if loser_data else 1
		get_node("/root/SaveManager").record_duel_result(
			winner_side == 0,
			atk_type,
			def_type,
			player_won
		)

	# Return to board turn state
	change_state(STATE_BOARD_TURN)

func end_match(winner_color: int, reason: String) -> void:
	change_state(STATE_GAME_OVER)
	if has_node("/root/PlatformManager"):
		get_node("/root/PlatformManager").set_keep_screen_on(false)
	var player_won = (winner_color == COLOR_WHITE)
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").record_match_end(player_won)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").match_ended.emit(winner_color, reason)

func toggle_pause() -> void:
	if current_state == STATE_PAUSED:
		get_tree().paused = false
		change_state(previous_state)
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").match_paused.emit(false)
	elif current_state == STATE_BOARD_TURN or current_state == STATE_DUEL_COMBAT:
		get_tree().paused = true
		change_state(STATE_PAUSED)
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").match_paused.emit(true)
