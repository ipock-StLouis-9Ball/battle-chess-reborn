class_name Piece
extends Control

## Visual Piece View
## Renders piece glyph / sprite and animates board movement

@export var piece_type: String = "P"
@export var piece_color: String = "white"

@onready var label: Label = $Label
var tween: Tween

func setup(type: String, color: String) -> void:
	piece_type = type
	piece_color = color
	if is_node_ready():
		_update_visuals()

func _ready() -> void:
	_update_visuals()

func _update_visuals() -> void:
	var symbol = _get_symbol(piece_type, piece_color)
	label.text = symbol
	if piece_color == "white":
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_color_override("font_shadow_color", Color(0.1, 0.2, 0.4, 0.9))
	else:
		label.add_theme_color_override("font_color", Color(0.18, 0.2, 0.25, 1.0))
		label.add_theme_color_override("font_shadow_color", Color(0.95, 0.25, 0.25, 0.9))

func animate_to(target_pos: Vector2, duration: float = 0.25) -> Signal:
	if tween and tween.is_valid():
		tween.kill()
	tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, duration)
	return tween.finished

func _get_symbol(type: String, color: String) -> String:
	var is_white = (color == "white")
	match type:
		"P": return "♙" if is_white else "♟"
		"N": return "♘" if is_white else "♞"
		"B": return "♗" if is_white else "♝"
		"R": return "♖" if is_white else "♜"
		"Q": return "♕" if is_white else "♛"
		"K": return "♔" if is_white else "♚"
		_: return "?"
