class_name VictoryScreen
extends Control

## End of Match Screen presenting Victor, Reason, and Duel recap

signal rematch_pressed()
signal menu_pressed()

@onready var title_label: Label = $SafeArea/Center/Panel/VBox/TitleLabel
@onready var reason_label: Label = $SafeArea/Center/Panel/VBox/ReasonLabel
@onready var stats_label: Label = $SafeArea/Center/Panel/VBox/StatsLabel
@onready var btn_rematch: Button = $SafeArea/Center/Panel/VBox/HBoxButtons/BtnRematch
@onready var btn_menu: Button = $SafeArea/Center/Panel/VBox/HBoxButtons/BtnMenu

func _ready() -> void:
	btn_rematch.pressed.connect(_on_rematch)
	btn_menu.pressed.connect(_on_menu)
	EventBus.match_ended.connect(show_victory)

func show_victory(winner_color: GameEnums.PieceColor, reason: String) -> void:
	visible = true
	var is_white = (winner_color == GameEnums.PieceColor.WHITE)
	title_label.text = "VICTORY FOR %s!" % ("WHITE" if is_white else "BLACK")
	
	if is_white:
		title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	else:
		title_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3, 1.0))

	reason_label.text = reason

	var recap = "MATCH BATTLE RECAP:\n"
	recap += "• Total Turns: %d\n" % GameManager.turn_count
	recap += "• Total Arena Duels Fought: %d\n" % GameManager.match_duels_count
	recap += "• White Pieces Casualties: %d\n" % GameManager.white_pieces_captured
	recap += "• Black Pieces Casualties: %d\n" % GameManager.black_pieces_captured
	stats_label.text = recap

func _on_rematch() -> void:
	EventBus.play_sfx_requested.emit("click", "UI")
	visible = false
	rematch_pressed.emit()
	GameManager.start_new_match(GameManager.current_mode)

func _on_menu() -> void:
	EventBus.play_sfx_requested.emit("click", "UI")
	visible = false
	menu_pressed.emit()
	GameManager.change_state(GameEnums.GameState.MAIN_MENU)
