class_name ChessEngine
extends RefCounted

## Pure GDScript Chess Rules Engine with move generation, check validation, and AI

var grid: Array = [] # 8x8 Array of ChessPieceData or null

func _init() -> void:
	_init_grid()

func _init_grid() -> void:
	grid = []
	for x in range(8):
		var col = []
		col.resize(8)
		for y in range(8):
			col[y] = null
		grid.append(col)

func reset_board() -> void:
	_init_grid()
	_setup_standard_starting_pieces()

func _setup_standard_starting_pieces() -> void:
	# Black back rank (row 0)
	var black_order = [
		GameEnums.PieceType.ROOK, GameEnums.PieceType.KNIGHT, GameEnums.PieceType.BISHOP,
		GameEnums.PieceType.QUEEN, GameEnums.PieceType.KING,
		GameEnums.PieceType.BISHOP, GameEnums.PieceType.KNIGHT, GameEnums.PieceType.ROOK
	]
	for x in range(8):
		set_piece_at(Vector2i(x, 0), ChessPieceData.create(black_order[x], GameEnums.PieceColor.BLACK, Vector2i(x, 0)))
		# Black pawns (row 1)
		set_piece_at(Vector2i(x, 1), ChessPieceData.create(GameEnums.PieceType.PAWN, GameEnums.PieceColor.BLACK, Vector2i(x, 1)))

	# White pawns (row 6)
	for x in range(8):
		set_piece_at(Vector2i(x, 6), ChessPieceData.create(GameEnums.PieceType.PAWN, GameEnums.PieceColor.WHITE, Vector2i(x, 6)))

	# White back rank (row 7)
	var white_order = [
		GameEnums.PieceType.ROOK, GameEnums.PieceType.KNIGHT, GameEnums.PieceType.BISHOP,
		GameEnums.PieceType.QUEEN, GameEnums.PieceType.KING,
		GameEnums.PieceType.BISHOP, GameEnums.PieceType.KNIGHT, GameEnums.PieceType.ROOK
	]
	for x in range(8):
		set_piece_at(Vector2i(x, 7), ChessPieceData.create(white_order[x], GameEnums.PieceColor.WHITE, Vector2i(x, 7)))

func get_piece_at(pos: Vector2i) -> ChessPieceData:
	if not MathHelpers.is_valid_grid_pos(pos):
		return null
	return grid[pos.x][pos.y]

func set_piece_at(pos: Vector2i, piece: ChessPieceData) -> void:
	if MathHelpers.is_valid_grid_pos(pos):
		grid[pos.x][pos.y] = piece
		if piece != null:
			piece.grid_position = pos

func get_all_pieces_of_color(color: GameEnums.PieceColor) -> Array[ChessPieceData]:
	var result: Array[ChessPieceData] = []
	for x in range(8):
		for y in range(8):
			var p = grid[x][y]
			if p != null and p.color == color:
				result.append(p)
	return result

func find_king(color: GameEnums.PieceColor) -> Vector2i:
	for x in range(8):
		for y in range(8):
			var p = grid[x][y]
			if p != null and p.color == color and p.type == GameEnums.PieceType.KING:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

## Calculate pseudo-legal and check-safe moves for a piece at given coordinates
func get_legal_moves_for_piece(pos: Vector2i) -> Array[ChessMove]:
	var piece = get_piece_at(pos)
	if piece == null:
		return []

	var pseudo_moves = _generate_pseudo_moves(piece)
	var legal_moves: Array[ChessMove] = []

	# Filter out moves that leave king in check
	for m in pseudo_moves:
		if not _move_causes_self_check(piece.color, m):
			legal_moves.append(m)

	return legal_moves

func _generate_pseudo_moves(piece: ChessPieceData) -> Array[ChessMove]:
	var moves: Array[ChessMove] = []
	var pos = piece.grid_position

	match piece.type:
		GameEnums.PieceType.PAWN:
			var dir = -1 if piece.color == GameEnums.PieceColor.WHITE else 1
			var start_rank = 6 if piece.color == GameEnums.PieceColor.WHITE else 1
			var promo_rank = 0 if piece.color == GameEnums.PieceColor.WHITE else 7

			# 1 step forward
			var one_step = Vector2i(pos.x, pos.y + dir)
			if MathHelpers.is_valid_grid_pos(one_step) and get_piece_at(one_step) == null:
				var m = ChessMove.new(pos, one_step, false)
				if one_step.y == promo_rank:
					m.is_promotion = true
				moves.append(m)

				# 2 steps forward from starting rank
				var two_step = Vector2i(pos.x, pos.y + dir * 2)
				if pos.y == start_rank and get_piece_at(two_step) == null:
					moves.append(ChessMove.new(pos, two_step, false))

			# Diagonal captures
			for dx in [-1, 1]:
				var diag = Vector2i(pos.x + dx, pos.y + dir)
				if MathHelpers.is_valid_grid_pos(diag):
					var target = get_piece_at(diag)
					if target != null and target.color != piece.color:
						var m = ChessMove.new(pos, diag, true)
						m.captured_piece = target
						if diag.y == promo_rank:
							m.is_promotion = true
						moves.append(m)

		GameEnums.PieceType.KNIGHT:
			var offsets = [
				Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
				Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)
			]
			for off in offsets:
				var target_pos = pos + off
				if MathHelpers.is_valid_grid_pos(target_pos):
					var target = get_piece_at(target_pos)
					if target == null:
						moves.append(ChessMove.new(pos, target_pos, false))
					elif target.color != piece.color:
						var m = ChessMove.new(pos, target_pos, true)
						m.captured_piece = target
						moves.append(m)

		GameEnums.PieceType.BISHOP:
			_add_ray_moves(moves, piece, [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)])

		GameEnums.PieceType.ROOK:
			_add_ray_moves(moves, piece, [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)])

		GameEnums.PieceType.QUEEN:
			_add_ray_moves(moves, piece, [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
				Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
			])

		GameEnums.PieceType.KING:
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var target_pos = pos + Vector2i(dx, dy)
					if MathHelpers.is_valid_grid_pos(target_pos):
						var target = get_piece_at(target_pos)
						if target == null:
							moves.append(ChessMove.new(pos, target_pos, false))
						elif target.color != piece.color:
							var m = ChessMove.new(pos, target_pos, true)
							m.captured_piece = target
							moves.append(m)

			# Castling
			if not piece.has_moved and not is_square_attacked(pos, _opposite_color(piece.color)):
				var rank = pos.y
				# Kingside castling
				var rook_k = get_piece_at(Vector2i(7, rank))
				if rook_k != null and not rook_k.has_moved and rook_k.type == GameEnums.PieceType.ROOK:
					if get_piece_at(Vector2i(5, rank)) == null and get_piece_at(Vector2i(6, rank)) == null:
						if not is_square_attacked(Vector2i(5, rank), _opposite_color(piece.color)):
							var cm = ChessMove.new(pos, Vector2i(6, rank), false)
							cm.is_castling = true
							moves.append(cm)
				# Queenside castling
				var rook_q = get_piece_at(Vector2i(0, rank))
				if rook_q != null and not rook_q.has_moved and rook_q.type == GameEnums.PieceType.ROOK:
					if get_piece_at(Vector2i(1, rank)) == null and get_piece_at(Vector2i(2, rank)) == null and get_piece_at(Vector2i(3, rank)) == null:
						if not is_square_attacked(Vector2i(3, rank), _opposite_color(piece.color)):
							var cm = ChessMove.new(pos, Vector2i(2, rank), false)
							cm.is_castling = true
							moves.append(cm)

	return moves

func _add_ray_moves(moves: Array[ChessMove], piece: ChessPieceData, directions: Array[Vector2i]) -> void:
	var pos = piece.grid_position
	for d in directions:
		var cur = pos + d
		while MathHelpers.is_valid_grid_pos(cur):
			var target = get_piece_at(cur)
			if target == null:
				moves.append(ChessMove.new(pos, cur, false))
			else:
				if target.color != piece.color:
					var m = ChessMove.new(pos, cur, true)
					m.captured_piece = target
					moves.append(m)
				break
			cur += d

func _opposite_color(c: GameEnums.PieceColor) -> GameEnums.PieceColor:
	return GameEnums.PieceColor.BLACK if c == GameEnums.PieceColor.WHITE else GameEnums.PieceColor.WHITE

func is_square_attacked(pos: Vector2i, by_color: GameEnums.PieceColor) -> bool:
	for x in range(8):
		for y in range(8):
			var p = grid[x][y]
			if p != null and p.color == by_color:
				var pseudo = _generate_pseudo_moves(p)
				for m in pseudo:
					if m.to_pos == pos:
						return true
	return false

func is_in_check(color: GameEnums.PieceColor) -> bool:
	var king_pos = find_king(color)
	if king_pos == Vector2i(-1, -1):
		return false
	return is_square_attacked(king_pos, _opposite_color(color))

func _move_causes_self_check(color: GameEnums.PieceColor, move: ChessMove) -> bool:
	# Temporarily perform move on grid
	var piece = get_piece_at(move.from_pos)
	var dest_piece = get_piece_at(move.to_pos)
	
	set_piece_at(move.from_pos, null)
	set_piece_at(move.to_pos, piece)
	if piece != null:
		piece.grid_position = move.to_pos

	var check = is_in_check(color)

	# Revert
	set_piece_at(move.to_pos, dest_piece)
	set_piece_at(move.from_pos, piece)
	if piece != null:
		piece.grid_position = move.from_pos

	return check

func get_all_legal_moves(color: GameEnums.PieceColor) -> Array[ChessMove]:
	var all_moves: Array[ChessMove] = []
	for p in get_all_pieces_of_color(color):
		var moves = get_legal_moves_for_piece(p.grid_position)
		all_moves.append_array(moves)
	return all_moves

func is_checkmate(color: GameEnums.PieceColor) -> bool:
	return is_in_check(color) and get_all_legal_moves(color).is_empty()

func is_stalemate(color: GameEnums.PieceColor) -> bool:
	return not is_in_check(color) and get_all_legal_moves(color).is_empty()

## Simple heuristic evaluation AI for Single Player match
func pick_ai_move(color: GameEnums.PieceColor, difficulty: GameEnums.AIDifficulty = GameEnums.AIDifficulty.MEDIUM) -> ChessMove:
	var moves = get_all_legal_moves(color)
	if moves.is_empty():
		return null

	if difficulty == GameEnums.AIDifficulty.EASY:
		return moves.pick_random()

	# Score moves based on capture value and strategic control
	var best_score = -999999.0
	var best_moves: Array[ChessMove] = []

	for m in moves:
		var score = 0.0
		if m.is_attack and m.captured_piece != null:
			score += _get_piece_value(m.captured_piece.type) * 10.0
			# Aggression bonus in Combat Chess
			score += 15.0
		# Center control bonus
		var center_dist = abs(m.to_pos.x - 3.5) + abs(m.to_pos.y - 3.5)
		score -= center_dist * 2.0

		if score > best_score:
			best_score = score
			best_moves = [m]
		elif is_equal_approx(score, best_score):
			best_moves.append(m)

	return best_moves.pick_random()

func _get_piece_value(type: GameEnums.PieceType) -> float:
	match type:
		GameEnums.PieceType.PAWN: return 1.0
		GameEnums.PieceType.KNIGHT: return 3.0
		GameEnums.PieceType.BISHOP: return 3.2
		GameEnums.PieceType.ROOK: return 5.0
		GameEnums.PieceType.QUEEN: return 9.5
		GameEnums.PieceType.KING: return 100.0
		_: return 0.0
