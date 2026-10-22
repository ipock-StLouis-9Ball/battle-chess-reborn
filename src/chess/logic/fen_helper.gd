class_name FENHelper
extends RefCounted

## FEN string generator and parser for standard starting setup & serializing

const STARTING_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

static func parse_fen_piece(c: String) -> Dictionary:
	var is_white = (c == c.to_upper())
	var color = GameEnums.PieceColor.WHITE if is_white else GameEnums.PieceColor.BLACK
	var piece_type = GameEnums.PieceType.NONE
	match c.to_lower():
		"p": piece_type = GameEnums.PieceType.PAWN
		"n": piece_type = GameEnums.PieceType.KNIGHT
		"b": piece_type = GameEnums.PieceType.BISHOP
		"r": piece_type = GameEnums.PieceType.ROOK
		"q": piece_type = GameEnums.PieceType.QUEEN
		"k": piece_type = GameEnums.PieceType.KING
	return {"type": piece_type, "color": color}

static func piece_to_fen_char(type: GameEnums.PieceType, color: GameEnums.PieceColor) -> String:
	var ch = ""
	match type:
		GameEnums.PieceType.PAWN: ch = "p"
		GameEnums.PieceType.KNIGHT: ch = "n"
		GameEnums.PieceType.BISHOP: ch = "b"
		GameEnums.PieceType.ROOK: ch = "r"
		GameEnums.PieceType.QUEEN: ch = "q"
		GameEnums.PieceType.KING: ch = "k"
		_: return ""
	return ch.to_upper() if color == GameEnums.PieceColor.WHITE else ch
