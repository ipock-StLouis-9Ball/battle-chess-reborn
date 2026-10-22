class_name MathHelpers
extends RefCounted

## Coordinate and math helpers for Duel of Kings 8x8 grid & duel arena

static func grid_to_algebraic(pos: Vector2i) -> String:
	if not is_valid_grid_pos(pos):
		return "??"
	var col_char = String.chr("a".unicode_at(0) + pos.x)
	var row_char = str(8 - pos.y)
	return col_char + row_char

static func algebraic_to_grid(coord: String) -> Vector2i:
	if coord.length() < 2:
		return Vector2i(-1, -1)
	var col_idx = coord.to_lower().unicode_at(0) - "a".unicode_at(0)
	var row_idx = 8 - coord.substr(1, 1).to_int()
	return Vector2i(col_idx, row_idx)

static func is_valid_grid_pos(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

static func tile_to_world(grid_pos: Vector2i, tile_size: float, board_origin: Vector2) -> Vector2:
	return board_origin + Vector2(grid_pos.x * tile_size + tile_size * 0.5, grid_pos.y * tile_size + tile_size * 0.5)

static func world_to_tile(world_pos: Vector2, tile_size: float, board_origin: Vector2) -> Vector2i:
	var local = world_pos - board_origin
	var gx = int(floor(local.x / tile_size))
	var gy = int(floor(local.y / tile_size))
	return Vector2i(gx, gy)

static func color_to_name(color_enum: GameEnums.PieceColor) -> String:
	return "White" if color_enum == GameEnums.PieceColor.WHITE else "Black"

static func piece_type_to_name(type_enum: GameEnums.PieceType) -> String:
	match type_enum:
		GameEnums.PieceType.PAWN: return "Pawn"
		GameEnums.PieceType.KNIGHT: return "Knight"
		GameEnums.PieceType.BISHOP: return "Bishop"
		GameEnums.PieceType.ROOK: return "Rook"
		GameEnums.PieceType.QUEEN: return "Queen"
		GameEnums.PieceType.KING: return "King"
		_: return "None"

static func piece_symbol(type_enum: GameEnums.PieceType, color_enum: GameEnums.PieceColor) -> String:
	var is_white = (color_enum == GameEnums.PieceColor.WHITE)
	match type_enum:
		GameEnums.PieceType.PAWN: return "♙" if is_white else "♟"
		GameEnums.PieceType.KNIGHT: return "♘" if is_white else "♞"
		GameEnums.PieceType.BISHOP: return "♗" if is_white else "♝"
		GameEnums.PieceType.ROOK: return "♖" if is_white else "♜"
		GameEnums.PieceType.QUEEN: return "♕" if is_white else "♛"
		GameEnums.PieceType.KING: return "♔" if is_white else "♚"
		_: return ""
