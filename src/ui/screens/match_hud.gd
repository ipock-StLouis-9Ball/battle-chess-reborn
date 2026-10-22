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
	if is_instance_valid(btn_pause):
		btn_pause.pressed.connect(_on_pause_pressed)
	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		eb.turn_changed.connect(_on_turn_changed)
		eb.check_alert.connect(_on_check_alert)
		eb.duel_completed.connect(func(_w, _wd, _ld, _p): _update_capture_counters())
	if is_instance_valid(check_banner):
		check_banner.visible = false
	_update_capture_counters()

func _on_pause_pressed() -> void:
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").play_sfx_requested.emit("click", "UI")
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").toggle_pause()

func _on_turn_changed(color: GameEnums.PieceColor, turn_num: int) -> void:
	if is_instance_valid(check_banner):
		check_banner.visible = false
	var is_white = (color == GameEnums.PieceColor.WHITE)
	if is_instance_valid(turn_icon):
		turn_icon.text = "♔" if is_white else "♚"
	if is_instance_valid(turn_label):
		turn_label.text = ("WHITE'S TURN (Turn %d)" if is_white else "BLACK'S TURN (Turn %d)") % turn_num
		if is_white:
			turn_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
		else:
			turn_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))

func _on_check_alert(king_color: GameEnums.PieceColor) -> void:
	var color_name = MathHelpers.color_to_name(king_color)
	if is_instance_valid(check_banner):
		check_banner.text = "⚠️ %s IS IN CHECK!" % color_name.to_upper()
		check_banner.visible = true
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").play_sfx_requested.emit("crit", "SFX")

func _update_capture_counters() -> void:
	var w = 0
	var b = 0
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		w = gm.get("white_pieces_captured")
		b = gm.get("black_pieces_captured")
	if is_instance_valid(white_captures_label):
		white_captures_label.text = "White Captures: %d" % w
	if is_instance_valid(black_captures_label):
		black_captures_label.text = "Black Captures: %d" % b
