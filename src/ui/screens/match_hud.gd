class_name MatchHUD
extends Control

## Match HUD overlay during Chess Board gameplay

@onready var turn_label: Label = $SafeArea/TopBar/TurnBox/TurnLabel
@onready var turn_icon: Label = $SafeArea/TopBar/TurnBox/TurnIcon
@onready var check_banner: Label = $SafeArea/TopBar/CheckBanner
@onready var btn_pause: Button = $SafeArea/TopBar/BtnPause
@onready var white_captures_label: Label = $SafeArea/BottomBar/WhiteCaptures/CountLabel
@onready var black_captures_label: Label = $SafeArea/BottomBar/BlackCaptures/CountLabel

func _ready() -> void:
	btn_pause.pressed.connect(_on_pause_pressed)
	EventBus.turn_changed.connect(_on_turn_changed)
	EventBus.check_alert.connect(_on_check_alert)
	EventBus.duel_completed.connect(func(_w, _wd, _ld, _p): _update_capture_counters())
	check_banner.visible = false
	_update_capture_counters()

func _on_pause_pressed() -> void:
	EventBus.play_sfx_requested.emit("click", "UI")
	GameManager.toggle_pause()

func _on_turn_changed(color: GameEnums.PieceColor, turn_num: int) -> void:
	check_banner.visible = false
	var is_white = (color == GameEnums.PieceColor.WHITE)
	turn_icon.text = "♔" if is_white else "♚"
	turn_label.text = ("WHITE'S TURN (Turn %d)" if is_white else "BLACK'S TURN (Turn %d)") % turn_num

	if is_white:
		turn_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
	else:
		turn_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))

func _on_check_alert(king_color: GameEnums.PieceColor) -> void:
	var color_name = MathHelpers.color_to_name(king_color)
	check_banner.text = "⚠️ %s IS IN CHECK!" % color_name.to_upper()
	check_banner.visible = true
	EventBus.play_sfx_requested.emit("crit", "SFX")

func _update_capture_counters() -> void:
	white_captures_label.text = "White Captures: %d" % GameManager.white_pieces_captured
	black_captures_label.text = "Black Captures: %d" % GameManager.black_pieces_captured
