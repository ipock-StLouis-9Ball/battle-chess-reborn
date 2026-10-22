class_name ChessBoard2D
extends Control

## Chess Board Controller
## Manages 8x8 grid tiles, pieces, player interaction, and battle transitions

signal match_state_changed(is_check: bool, is_checkmate: bool)

const BOARD_SIZE = 8
const TILE_PIXEL_SIZE = 84.0

@export var tile_scene: PackedScene = preload("res://src/chess/board/board_tile.tscn")
@export var piece_scene: PackedScene = preload("res://src/chess/pieces/piece_view.tscn")

var engine: ChessEngine = ChessEngine.new()

var _tiles: Dictionary = {} # Vector2i -> BoardTile
var _piece_views: Dictionary = {} # ChessPieceData -> PieceView

var selected_pos: Vector2i = Vector2i(-1, -1)
var current_legal_moves: Array[ChessMove] = []
var is_busy_animating: bool = false

@onready var grid_container: GridContainer = $BoardFrame/BoardGrid
@onready var pieces_layer: Control = $BoardFrame/PiecesLayer
@onready var board_frame: PanelContainer = $BoardFrame

func _ready() -> void:
	_init_board_tiles()
	_connect_events()
	start_fresh_game()

func _connect_events() -> void:
	EventBus.duel_completed.connect(_on_duel_completed)
	EventBus.turn_changed.connect(_on_turn_changed)

func start_fresh_game() -> void:
	_clear_all_pieces()
	engine.reset_board()
	_spawn_all_pieces_from_engine()
	clear_selection()

func _init_board_tiles() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	_tiles.clear()

	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var pos = Vector2i(x, y)
			var tile: BoardTile = tile_scene.instantiate()
			tile.custom_minimum_size = Vector2(TILE_PIXEL_SIZE, TILE_PIXEL_SIZE)
			grid_container.add_child(tile)
			tile.setup(pos)
			tile.tile_clicked.connect(_on_tile_clicked)
			_tiles[pos] = tile

func _clear_all_pieces() -> void:
	for piece_data in _piece_views:
		var view = _piece_views[piece_data]
		if is_instance_valid(view):
			view.queue_free()
	_piece_views.clear()

func _spawn_all_pieces_from_engine() -> void:
	for x in range(BOARD_SIZE):
		for y in range(BOARD_SIZE):
			var piece = engine.get_piece_at(Vector2i(x, y))
			if piece != null:
				_create_piece_view(piece)

func _create_piece_view(piece: ChessPieceData) -> PieceView:
	var view: PieceView = piece_scene.instantiate()
	view.custom_minimum_size = Vector2(TILE_PIXEL_SIZE, TILE_PIXEL_SIZE)
	view.position = _grid_to_pixel(piece.grid_position)
	pieces_layer.add_child(view)
	view.set_piece_data(piece)
	_piece_views[piece] = view
	return view

func _grid_to_pixel(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * TILE_PIXEL_SIZE, pos.y * TILE_PIXEL_SIZE)

func _on_tile_clicked(clicked_pos: Vector2i) -> void:
	if is_busy_animating:
		return
	if GameManager.current_state != GameEnums.GameState.BOARD_TURN:
		return

	# If it's AI turn in single-player, block human input
	if GameManager.current_mode == GameEnums.GameMode.VS_AI and GameManager.active_turn_color == GameEnums.PieceColor.BLACK:
		return

	var clicked_piece = engine.get_piece_at(clicked_pos)

	# If a destination tile from legal moves is clicked, execute move!
	for m in current_legal_moves:
		if m.to_pos == clicked_pos:
			_execute_move(m)
			return

	# If clicked own piece, select it
	if clicked_piece != null and clicked_piece.color == GameManager.active_turn_color:
		_select_piece(clicked_pos, clicked_piece)
	else:
		clear_selection()

func _select_piece(pos: Vector2i, piece: ChessPieceData) -> void:
	clear_selection()
	selected_pos = pos
	
	if _tiles.has(pos):
		_tiles[pos].set_selected(true)

	current_legal_moves = engine.get_legal_moves_for_piece(pos)
	for m in current_legal_moves:
		if _tiles.has(m.to_pos):
			if m.is_attack:
				_tiles[m.to_pos].set_highlight_attack(true)
			else:
				_tiles[m.to_pos].set_highlight_move(true)

	PlatformManager.trigger_haptic(25)
	EventBus.tile_selected.emit(pos, piece)
	EventBus.valid_moves_updated.emit(current_legal_moves)

func clear_selection() -> void:
	if selected_pos != Vector2i(-1, -1) and _tiles.has(selected_pos):
		_tiles[selected_pos].set_selected(false)

	for m in current_legal_moves:
		if _tiles.has(m.to_pos):
			_tiles[m.to_pos].set_highlight_move(false)
			_tiles[m.to_pos].set_highlight_attack(false)

	selected_pos = Vector2i(-1, -1)
	current_legal_moves.clear()
	EventBus.selection_cleared.emit()

func _execute_move(move: ChessMove) -> void:
	clear_selection()
	var attacker_piece = engine.get_piece_at(move.from_pos)
	if attacker_piece == null:
		return

	if move.is_attack:
		# Attack initiated -> Start Combat Chess Duel!
		var defender_piece = engine.get_piece_at(move.to_pos)
		Logger.info("ChessBoard", "Duel engaged! %s (%s) attacks %s (%s) at %s" % [
			MathHelpers.piece_type_to_name(attacker_piece.type),
			MathHelpers.color_to_name(attacker_piece.color),
			MathHelpers.piece_type_to_name(defender_piece.type),
			MathHelpers.color_to_name(defender_piece.color),
			MathHelpers.grid_to_algebraic(move.to_pos)
		])
		EventBus.move_executed.emit(move.from_pos, move.to_pos, true)
		GameManager.start_duel(attacker_piece, defender_piece, move.to_pos)
	else:
		# Standard peaceful move or castling
		is_busy_animating = true
		engine.set_piece_at(move.from_pos, null)
		engine.set_piece_at(move.to_pos, attacker_piece)
		attacker_piece.has_moved = true

		var view = _piece_views.get(attacker_piece)
		if view:
			var target_px = _grid_to_pixel(move.to_pos)
			await view.animate_move_to(target_px)

		# Castling rook repositioning
		if move.is_castling:
			_handle_castling_rook(move)

		# Pawn promotion check
		if move.is_promotion:
			attacker_piece.type = GameEnums.PieceType.QUEEN
			attacker_piece._init_stats_by_type()
			if view:
				view.update_view()

		is_busy_animating = false
		EventBus.move_executed.emit(move.from_pos, move.to_pos, false)
		_check_post_move_conditions()

func _handle_castling_rook(move: ChessMove) -> void:
	var rank = move.from_pos.y
	if move.to_pos.x == 6: # Kingside
		var rook = engine.get_piece_at(Vector2i(7, rank))
		if rook:
			engine.set_piece_at(Vector2i(7, rank), null)
			engine.set_piece_at(Vector2i(5, rank), rook)
			rook.has_moved = true
			var rook_view = _piece_views.get(rook)
			if rook_view:
				rook_view.animate_move_to(_grid_to_pixel(Vector2i(5, rank)), 0.2)
	elif move.to_pos.x == 2: # Queenside
		var rook = engine.get_piece_at(Vector2i(0, rank))
		if rook:
			engine.set_piece_at(Vector2i(0, rank), null)
			engine.set_piece_at(Vector2i(3, rank), rook)
			rook.has_moved = true
			var rook_view = _piece_views.get(rook)
			if rook_view:
				rook_view.animate_move_to(_grid_to_pixel(Vector2i(3, rank)), 0.2)

func _on_duel_completed(winner_side: int, winner_data: Resource, loser_data: Resource, battle_pos: Vector2i) -> void:
	# winner_side: 0 = attacker, 1 = defender
	var attacker = GameManager.active_attacker_piece as ChessPieceData
	var defender = GameManager.active_defender_piece as ChessPieceData
	var from_pos = attacker.grid_position

	is_busy_animating = true

	if winner_side == 0:
		# Attacker won -> Defender destroyed, attacker advances to battle_pos
		var def_view = _piece_views.get(defender)
		if def_view:
			await def_view.play_defeat_animation()
			def_view.queue_free()
			_piece_views.erase(defender)

		engine.set_piece_at(from_pos, null)
		engine.set_piece_at(battle_pos, attacker)
		attacker.has_moved = true

		var atk_view = _piece_views.get(attacker)
		if atk_view:
			await atk_view.animate_move_to(_grid_to_pixel(battle_pos))
			atk_view.update_view()

		# Pawn promotion check
		if attacker.type == GameEnums.PieceType.PAWN:
			if (attacker.color == GameEnums.PieceColor.WHITE and battle_pos.y == 0) or (attacker.color == GameEnums.PieceColor.BLACK and battle_pos.y == 7):
				attacker.type = GameEnums.PieceType.QUEEN
				attacker._init_stats_by_type()
				if atk_view:
					atk_view.update_view()
	else:
		# Defender won -> Attacker destroyed, defender keeps the tile!
		var atk_view = _piece_views.get(attacker)
		if atk_view:
			await atk_view.play_defeat_animation()
			atk_view.queue_free()
			_piece_views.erase(attacker)

		engine.set_piece_at(from_pos, null)
		var def_view = _piece_views.get(defender)
		if def_view:
			def_view.update_view()

	is_busy_animating = false
	_check_post_move_conditions()

func _check_post_move_conditions() -> void:
	var next_color = GameEnums.PieceColor.BLACK if GameManager.active_turn_color == GameEnums.PieceColor.WHITE else GameEnums.PieceColor.WHITE
	
	# Verify King existence (in Duel of Kings, a king might be defeated in duel!)
	var white_king = engine.find_king(GameEnums.PieceColor.WHITE)
	var black_king = engine.find_king(GameEnums.PieceColor.BLACK)

	if white_king == Vector2i(-1, -1):
		GameManager.end_match(GameEnums.PieceColor.BLACK, "White King was defeated in battle!")
		return
	elif black_king == Vector2i(-1, -1):
		GameManager.end_match(GameEnums.PieceColor.WHITE, "Black King was defeated in battle!")
		return

	if engine.is_checkmate(next_color):
		EventBus.checkmate_alert.emit(GameManager.active_turn_color)
		GameManager.end_match(GameManager.active_turn_color, "Checkmate!")
		return
	elif engine.is_stalemate(next_color):
		EventBus.stalemate_alert.emit()
		GameManager.end_match(GameEnums.PieceColor.WHITE, "Stalemate - Draw")
		return

	if engine.is_in_check(next_color):
		EventBus.check_alert.emit(next_color)

	GameManager.advance_turn()

func _on_turn_changed(new_color: GameEnums.PieceColor, turn_num: int) -> void:
	if GameManager.current_mode == GameEnums.GameMode.VS_AI and new_color == GameEnums.PieceColor.BLACK:
		_trigger_ai_turn()

func _trigger_ai_turn() -> void:
	# Add slight natural delay for AI thought
	await get_tree().create_timer(0.6).timeout
	if GameManager.current_state != GameEnums.GameState.BOARD_TURN:
		return

	var ai_move = engine.pick_ai_move(GameEnums.PieceColor.BLACK, SettingsManager.ai_duel_difficulty)
	if ai_move != null:
		_execute_move(ai_move)
