class_name ChessBoard
extends Node

## 8x8 Chess Board Manager
## Handles 8x8 matrix state, FEN parsing, full legal move generation (castling, en-passant, promotion),
## check/checkmate verification, and turn state machine.

signal board_updated()
signal turn_changed(turn_color: String, turn_number: int)
signal piece_selected(pos: Vector2i, piece_info: Dictionary)
signal selection_cleared()
signal duel_triggered(attacker: Dictionary, victim: Dictionary, board_pos: Vector2i)
signal check_declared(king_color: String)
signal game_over(winner_color: String, reason: String)
signal theme_swapped(theme_id: String, piece_theme: PieceTheme)

enum TurnState {
	WHITE_TURN,
	BLACK_TURN,
	PIECE_SELECTED,
	DUEL_IN_PROGRESS,
	GAME_OVER
}

const BOARD_SIZE: int = 8
const STARTING_FEN: String = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

# 8x8 Matrix: matrix[x][y] -> Dictionary or null
# Piece dict format: {"type": "P"|"N"|"B"|"R"|"Q"|"K", "color": "white"|"black", "has_moved": bool}
var matrix: Array = []

var current_state: TurnState = TurnState.WHITE_TURN
var turn_count: int = 1
var selected_tile: Vector2i = Vector2i(-1, -1)
var cached_legal_moves: Array = []

# Special chess state tracking
var en_passant_target: Vector2i = Vector2i(-1, -1) # Square behind a 2-square pawn push
var white_can_castle_kingside: bool = true
var white_can_castle_queenside: bool = true
var black_can_castle_kingside: bool = true
var black_can_castle_queenside: bool = true
var halfmove_clock: int = 0

# Theme wiring
var current_theme_id: String = "high_fantasy"
var current_piece_theme: PieceTheme = null

func _init() -> void:
	_init_matrix()

func _ready() -> void:
	load_fen(STARTING_FEN)
	_connect_theme_manager()

func _connect_theme_manager() -> void:
	if has_node("/root/ThemeManager"):
		var tm = get_node("/root/ThemeManager")
		if tm.has_signal("theme_changed"):
			tm.theme_changed.connect(_on_theme_changed)
		if tm.has_signal("piece_theme_changed"):
			tm.piece_theme_changed.connect(_on_piece_theme_changed)
		apply_theme(tm.current_theme)

func _on_theme_changed(theme_id: String, _data: Dictionary) -> void:
	apply_theme(theme_id)

func _on_piece_theme_changed(theme_res: PieceTheme) -> void:
	if theme_res != null:
		current_piece_theme = theme_res
		theme_swapped.emit(current_theme_id, current_piece_theme)
		board_updated.emit()

## Dynamically apply theme by ID or PieceTheme resource
func apply_theme(theme_id: String) -> void:
	current_theme_id = theme_id.to_lower()
	if has_node("/root/ThemeManager"):
		current_piece_theme = get_node("/root/ThemeManager").get_piece_theme(current_theme_id)
	theme_swapped.emit(current_theme_id, current_piece_theme)
	board_updated.emit()

func get_current_piece_theme() -> PieceTheme:
	return current_piece_theme

func _init_matrix() -> void:
	matrix = []
	for x in range(BOARD_SIZE):
		var column = []
		column.resize(BOARD_SIZE)
		for y in range(BOARD_SIZE):
			column[y] = null
		matrix.append(column)

## Load standard FEN notation into 8x8 matrix
func load_fen(fen: String) -> void:
	_init_matrix()
	var parts = fen.strip_edges().split(" ")
	if parts.is_empty():
		return

	var ranks = parts[0].split("/")
	for y in range(mini(BOARD_SIZE, ranks.size())):
		var rank_str = ranks[y]
		var x = 0
		for ch in rank_str:
			if ch.is_valid_int():
				x += ch.to_int()
			else:
				var is_white = (ch == ch.to_upper())
				matrix[x][y] = {
					"type": ch.to_upper(),
					"color": "white" if is_white else "black",
					"has_moved": false
				}
				x += 1

	# Active color
	if parts.size() > 1:
		current_state = TurnState.WHITE_TURN if parts[1] == "w" else TurnState.BLACK_TURN

	# Castling availability
	if parts.size() > 2:
		var castling = parts[2]
		white_can_castle_kingside = castling.contains("K")
		white_can_castle_queenside = castling.contains("Q")
		black_can_castle_kingside = castling.contains("k")
		black_can_castle_queenside = castling.contains("q")

	# En passant
	en_passant_target = Vector2i(-1, -1)
	if parts.size() > 3 and parts[3] != "-":
		en_passant_target = algebraic_to_coord(parts[3])

	board_updated.emit()
	var color_name = "white" if current_state == TurnState.WHITE_TURN else "black"
	turn_changed.emit(color_name, turn_count)

## Export current board matrix to FEN string
func export_fen() -> String:
	var fen = ""
	for y in range(BOARD_SIZE):
		var empty_count = 0
		for x in range(BOARD_SIZE):
			var piece = matrix[x][y]
			if piece == null:
				empty_count += 1
			else:
				if empty_count > 0:
					fen += str(empty_count)
					empty_count = 0
				var ch = piece["type"]
				fen += ch if piece["color"] == "white" else ch.to_lower()
		if empty_count > 0:
			fen += str(empty_count)
		if y < BOARD_SIZE - 1:
			fen += "/"

	var active_char = "w" if (current_state == TurnState.WHITE_TURN or current_state == TurnState.PIECE_SELECTED) else "b"
	var castling = ""
	if white_can_castle_kingside: castling += "K"
	if white_can_castle_queenside: castling += "Q"
	if black_can_castle_kingside: castling += "k"
	if black_can_castle_queenside: castling += "q"
	if castling == "": castling = "-"

	var ep = "-" if en_passant_target == Vector2i(-1, -1) else coord_to_algebraic(en_passant_target)
	return "%s %s %s %s %d %d" % [fen, active_char, castling, ep, halfmove_clock, turn_count]

func get_piece(pos: Vector2i) -> Variant:
	if not is_valid_pos(pos):
		return null
	return matrix[pos.x][pos.y]

func set_piece(pos: Vector2i, piece_data: Variant) -> void:
	if is_valid_pos(pos):
		matrix[pos.x][pos.y] = piece_data

func is_valid_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE

func get_active_color() -> String:
	return "white" if (current_state == TurnState.WHITE_TURN or (current_state == TurnState.PIECE_SELECTED and selected_tile != Vector2i(-1, -1) and get_piece(selected_tile)["color"] == "white")) else "black"

## Handle player square selection
func select_square(pos: Vector2i) -> void:
	if current_state == TurnState.DUEL_IN_PROGRESS or current_state == TurnState.GAME_OVER:
		return

	var active_color = get_active_color()
	var piece = get_piece(pos)

	# If already selected a piece, check if target square is a legal move
	if selected_tile != Vector2i(-1, -1):
		for move in cached_legal_moves:
			if move["to"] == pos:
				execute_move(move)
				return

	# Otherwise, select piece of active color
	if piece != null and piece["color"] == active_color:
		selected_tile = pos
		current_state = TurnState.PIECE_SELECTED
		cached_legal_moves = get_legal_moves_for_square(pos)
		piece_selected.emit(pos, piece)
	else:
		clear_selection()

func clear_selection() -> void:
	selected_tile = Vector2i(-1, -1)
	cached_legal_moves = []
	current_state = TurnState.WHITE_TURN if get_active_color() == "white" else TurnState.BLACK_TURN
	selection_cleared.emit()

## Move execution: peaceful move or capture/duel trigger
func execute_move(move: Dictionary) -> void:
	clear_selection()
	var from_pos: Vector2i = move["from"]
	var to_pos: Vector2i = move["to"]
	var piece = get_piece(from_pos)
	if piece == null:
		return

	var victim = get_piece(to_pos)
	var is_capture = (victim != null) or move.get("is_en_passant", false)

	if is_capture:
		# En-passant victim is on adjacent square
		if move.get("is_en_passant", false):
			var ep_victim_pos = Vector2i(to_pos.x, from_pos.y)
			victim = get_piece(ep_victim_pos)
			set_piece(ep_victim_pos, null)

		# Trigger Duel Director for battle resolution!
		current_state = TurnState.DUEL_IN_PROGRESS
		duel_triggered.emit(piece, victim, to_pos)

		if has_node("/root/DuelDirector"):
			var dd = get_node("/root/DuelDirector")
			await dd.duel_completed
		else:
			await get_tree().create_timer(1.8).timeout

		# Duel resolution finalizes placement:
		set_piece(from_pos, null)
		set_piece(to_pos, piece)
		piece["has_moved"] = true
	else:
		# Peaceful move
		set_piece(from_pos, null)
		set_piece(to_pos, piece)
		piece["has_moved"] = true

		# Castling rook move
		if move.get("is_castling", false):
			var rank = from_pos.y
			if to_pos.x == 6: # Kingside
				var rook = get_piece(Vector2i(7, rank))
				set_piece(Vector2i(7, rank), null)
				set_piece(Vector2i(5, rank), rook)
			elif to_pos.x == 2: # Queenside
				var rook = get_piece(Vector2i(0, rank))
				set_piece(Vector2i(0, rank), null)
				set_piece(Vector2i(3, rank), rook)

	# Pawn promotion
	if piece["type"] == "P":
		if (piece["color"] == "white" and to_pos.y == 0) or (piece["color"] == "black" and to_pos.y == 7):
			piece["type"] = "Q"

	# Update en-passant target
	if piece["type"] == "P" and abs(to_pos.y - from_pos.y) == 2:
		en_passant_target = Vector2i(from_pos.x, (from_pos.y + to_pos.y) / 2)
	else:
		en_passant_target = Vector2i(-1, -1)

	board_updated.emit()
	_advance_turn()

func _advance_turn() -> void:
	var next_color = "black" if get_active_color() == "white" else "white"
	if next_color == "white":
		turn_count += 1

	current_state = TurnState.WHITE_TURN if next_color == "white" else TurnState.BLACK_TURN

	if is_in_check(next_color):
		if is_checkmate(next_color):
			current_state = TurnState.GAME_OVER
			game_over.emit(get_active_color(), "Checkmate")
			return
		else:
			check_declared.emit(next_color)
	elif is_stalemate(next_color):
		current_state = TurnState.GAME_OVER
		game_over.emit("draw", "Stalemate")
		return

	turn_changed.emit(next_color, turn_count)

## Calculate legal moves filtered for king safety
func get_legal_moves_for_square(pos: Vector2i) -> Array:
	var piece = get_piece(pos)
	if piece == null:
		return []

	var pseudo_moves = _generate_pseudo_moves(pos, piece)
	var legal_moves = []

	for move in pseudo_moves:
		if not _move_leaves_king_in_check(move, piece["color"]):
			legal_moves.append(move)

	return legal_moves

func _generate_pseudo_moves(pos: Vector2i, piece: Dictionary) -> Array:
	var moves = []
	var color = piece["color"]
	var type = piece["type"]

	match type:
		"P":
			var dir = -1 if color == "white" else 1
			var start_row = 6 if color == "white" else 1

			# 1 forward
			var one_fwd = Vector2i(pos.x, pos.y + dir)
			if is_valid_pos(one_fwd) and get_piece(one_fwd) == null:
				moves.append({"from": pos, "to": one_fwd})
				# 2 forward
				var two_fwd = Vector2i(pos.x, pos.y + dir * 2)
				if pos.y == start_row and get_piece(two_fwd) == null:
					moves.append({"from": pos, "to": two_fwd})

			# Diagonal captures
			for dx in [-1, 1]:
				var target = Vector2i(pos.x + dx, pos.y + dir)
				if is_valid_pos(target):
					var dest_piece = get_piece(target)
					if dest_piece != null and dest_piece["color"] != color:
						moves.append({"from": pos, "to": target, "is_capture": true})
					elif target == en_passant_target:
						moves.append({"from": pos, "to": target, "is_en_passant": true, "is_capture": true})

		"N":
			var offsets = [
				Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
				Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)
			]
			for off in offsets:
				var target = pos + off
				if is_valid_pos(target):
					var dest = get_piece(target)
					if dest == null or dest["color"] != color:
						moves.append({"from": pos, "to": target, "is_capture": dest != null})

		"B":
			_add_ray_moves(moves, pos, color, [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)])

		"R":
			_add_ray_moves(moves, pos, color, [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)])

		"Q":
			_add_ray_moves(moves, pos, color, [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
			])

		"K":
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0: continue
					var target = pos + Vector2i(dx, dy)
					if is_valid_pos(target):
						var dest = get_piece(target)
						if dest == null or dest["color"] != color:
							moves.append({"from": pos, "to": target, "is_capture": dest != null})

			# Castling
			var rank = pos.y
			var opp_color = "black" if color == "white" else "white"
			if not piece.get("has_moved", false) and not is_square_attacked(pos, opp_color):
				# Kingside
				var rook_k = get_piece(Vector2i(7, rank))
				if rook_k != null and not rook_k.get("has_moved", false):
					if get_piece(Vector2i(5, rank)) == null and get_piece(Vector2i(6, rank)) == null:
						if not is_square_attacked(Vector2i(5, rank), opp_color) and not is_square_attacked(Vector2i(6, rank), opp_color):
							moves.append({"from": pos, "to": Vector2i(6, rank), "is_castling": true})
				# Queenside
				var rook_q = get_piece(Vector2i(0, rank))
				if rook_q != null and not rook_q.get("has_moved", false):
					if get_piece(Vector2i(1, rank)) == null and get_piece(Vector2i(2, rank)) == null and get_piece(Vector2i(3, rank)) == null:
						if not is_square_attacked(Vector2i(2, rank), opp_color) and not is_square_attacked(Vector2i(3, rank), opp_color):
							moves.append({"from": pos, "to": Vector2i(2, rank), "is_castling": true})

	return moves

func _add_ray_moves(moves: Array, pos: Vector2i, color: String, directions: Array) -> void:
	for d in directions:
		var cur = pos + d
		while is_valid_pos(cur):
			var dest = get_piece(cur)
			if dest == null:
				moves.append({"from": pos, "to": cur})
			else:
				if dest["color"] != color:
					moves.append({"from": pos, "to": cur, "is_capture": true})
				break
			cur += d

func _move_leaves_king_in_check(move: Dictionary, color: String) -> bool:
	var from_pos: Vector2i = move["from"]
	var to_pos: Vector2i = move["to"]
	var original_from = get_piece(from_pos)
	var original_to = get_piece(to_pos)

	set_piece(from_pos, null)
	set_piece(to_pos, original_from)

	var in_check = is_in_check(color)

	set_piece(to_pos, original_to)
	set_piece(from_pos, original_from)
	return in_check

func is_in_check(color: String) -> bool:
	var king_pos = find_king(color)
	if king_pos == Vector2i(-1, -1):
		return false
	var opp_color = "black" if color == "white" else "white"
	return is_square_attacked(king_pos, opp_color)

func is_square_attacked(pos: Vector2i, by_color: String) -> bool:
	for x in range(BOARD_SIZE):
		for y in range(BOARD_SIZE):
			var p = matrix[x][y]
			if p != null and p["color"] == by_color:
				var pseudo = _generate_pseudo_moves(Vector2i(x, y), p)
				for m in pseudo:
					if m["to"] == pos:
						return true
	return false

func find_king(color: String) -> Vector2i:
	for x in range(BOARD_SIZE):
		for y in range(BOARD_SIZE):
			var p = matrix[x][y]
			if p != null and p["color"] == color and p["type"] == "K":
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func get_all_legal_moves(color: String) -> Array:
	var all_moves = []
	for x in range(BOARD_SIZE):
		for y in range(BOARD_SIZE):
			var p = matrix[x][y]
			if p != null and p["color"] == color:
				all_moves.append_array(get_legal_moves_for_square(Vector2i(x, y)))
	return all_moves

func is_checkmate(color: String) -> bool:
	return is_in_check(color) and get_all_legal_moves(color).is_empty()

func is_stalemate(color: String) -> bool:
	return not is_in_check(color) and get_all_legal_moves(color).is_empty()

func coord_to_algebraic(pos: Vector2i) -> String:
	return String.chr("a".unicode_at(0) + pos.x) + str(8 - pos.y)

func algebraic_to_coord(alg: String) -> Vector2i:
	if alg.length() < 2: return Vector2i(-1, -1)
	var x = alg.to_lower().unicode_at(0) - "a".unicode_at(0)
	var y = 8 - alg.substr(1, 1).to_int()
	return Vector2i(x, y)
