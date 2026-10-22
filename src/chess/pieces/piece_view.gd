class_name PieceView
extends Control

## Visual representation of a piece on the chess board with HP bar and animation tweens

@export var piece_data: ChessPieceData

@onready var label_symbol: Label = $SymbolLabel
@onready var hp_bar: ProgressBar = $HPBar
@onready var glow_rect: TextureRect = $Glow

var current_tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if piece_data != null:
		update_view()

func set_piece_data(data: ChessPieceData) -> void:
	piece_data = data
	update_view()

func update_view() -> void:
	if piece_data == null:
		visible = false
		return

	visible = true
	var symbol = MathHelpers.piece_symbol(piece_data.type, piece_data.color)
	label_symbol.text = symbol

	# Color styling
	if piece_data.color == GameEnums.PieceColor.WHITE:
		label_symbol.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label_symbol.add_theme_color_override("font_shadow_color", Color(0.1, 0.2, 0.4, 0.9))
	else:
		label_symbol.add_theme_color_override("font_color", Color(0.2, 0.2, 0.25, 1.0))
		label_symbol.add_theme_color_override("font_shadow_color", Color(0.9, 0.2, 0.2, 0.8))

	# HP bar update
	hp_bar.max_value = piece_data.max_hp
	hp_bar.value = piece_data.current_hp
	hp_bar.visible = piece_data.current_hp < piece_data.max_hp

func animate_move_to(target_pos: Vector2, duration: float = 0.28) -> Signal:
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	current_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Little lift and landing arc
	current_tween.parallel().tween_property(self, "position", target_pos, duration)
	current_tween.parallel().tween_property(self, "scale", Vector2(1.15, 1.15), duration * 0.5)
	current_tween.chain().tween_property(self, "scale", Vector2.ONE, duration * 0.5)
	
	return current_tween.finished

func play_defeat_animation() -> Signal:
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	current_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	current_tween.parallel().tween_property(self, "scale", Vector2.ZERO, 0.35)
	current_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	current_tween.parallel().tween_property(self, "rotation", deg_to_rad(45.0), 0.35)
	return current_tween.finished

func play_hit_flash() -> void:
	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", Color(2.5, 0.5, 0.5, 1.0), 0.08)
	flash_tween.tween_property(self, "modulate", Color.WHITE, 0.12)
