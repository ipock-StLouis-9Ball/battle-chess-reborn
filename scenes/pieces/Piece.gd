class_name Piece
extends Control

## Visual Piece View
## Renders piece glyph / sprite and animates board movement with theme awareness

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

	var current_tid = "high_fantasy"
	var accent_col = Color(0.95, 0.8, 0.25, 1.0)
	if has_node("/root/ThemeManager"):
		var tm = get_node("/root/ThemeManager")
		current_tid = tm.current_theme
		var data = tm.get_current_theme_data()
		accent_col = data.get("accent", accent_col)

	match current_tid:
		"cyberpunk":
			if piece_color == "white":
				label.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0, 1.0))
				label.add_theme_color_override("font_shadow_color", Color(0.0, 0.95, 0.85, 0.9))
			else:
				label.add_theme_color_override("font_color", Color(0.12, 0.16, 0.22, 1.0))
				label.add_theme_color_override("font_shadow_color", Color(1.0, 0.15, 0.45, 0.9))
		"eldritch":
			if piece_color == "white":
				label.add_theme_color_override("font_color", Color(0.96, 0.9, 1.0, 1.0))
				label.add_theme_color_override("font_shadow_color", Color(0.85, 0.25, 0.95, 0.9))
			else:
				label.add_theme_color_override("font_color", Color(0.14, 0.1, 0.18, 1.0))
				label.add_theme_color_override("font_shadow_color", Color(0.65, 0.1, 0.4, 0.9))
		_: # high_fantasy
			if piece_color == "white":
				label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
				label.add_theme_color_override("font_shadow_color", Color(0.95, 0.8, 0.25, 0.9))
			else:
				label.add_theme_color_override("font_color", Color(0.18, 0.2, 0.25, 1.0))
				label.add_theme_color_override("font_shadow_color", Color(0.8, 0.25, 0.25, 0.9))

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
