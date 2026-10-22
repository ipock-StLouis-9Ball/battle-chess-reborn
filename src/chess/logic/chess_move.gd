class_name ChessMove
extends RefCounted

## Represents a candidate or executed chess move

var from_pos: Vector2i
var to_pos: Vector2i
var is_attack: bool = false
var is_castling: bool = false
var is_en_passant: bool = false
var is_promotion: bool = false
var promotion_type: GameEnums.PieceType = GameEnums.PieceType.QUEEN
var captured_piece: ChessPieceData = null

func _init(from: Vector2i = Vector2i.ZERO, to: Vector2i = Vector2i.ZERO, attack: bool = false) -> void:
	from_pos = from
	to_pos = to
	is_attack = attack

func to_algebraic() -> String:
	var move_str = MathHelpers.grid_to_algebraic(from_pos)
	move_str += "x" if is_attack else "-"
	move_str += MathHelpers.grid_to_algebraic(to_pos)
	if is_promotion:
		move_str += "=" + MathHelpers.piece_type_to_name(promotion_type).substr(0, 1)
	return move_str
