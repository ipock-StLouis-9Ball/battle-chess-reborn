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
	if is_instance_valid(btn_rematch):
		btn_rematch.pressed.connect(_on_rematch)
	if is_instance_valid(btn_menu):
		btn_menu.pressed.connect(_on_menu)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").match_ended.connect(show_victory)

func show_victory(winner_color: GameEnums.PieceColor, reason: String) -> void:
	visible = true
	var is_white = (winner_color == GameEnums.PieceColor.WHITE)
	if is_instance_valid(title_label):
		title_label.text = "VICTORY FOR %s!" % ("WHITE" if is_white else "BLACK")
		if is_white:
			title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
		else:
			title_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3, 1.0))

	if is_instance_valid(reason_label):
		reason_label.text = reason

	var turns = 0
	var duels = 0
	var white_caps = 0
	var black_caps = 0
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		turns = gm.get("turn_count")
		duels = gm.get("match_duels_count")
		white_caps = gm.get("white_pieces_captured")
		black_caps = gm.get("black_pieces_captured")

	var recap = "MATCH BATTLE RECAP:\n"
	recap += "• Total Turns: %d\n" % turns
	recap += "• Total Arena Duels Fought: %d\n" % duels
	recap += "• White Pieces Casualties: %d\n" % white_caps
	recap += "• Black Pieces Casualties: %d\n" % black_caps
	if is_instance_valid(stats_label):
		stats_label.text = recap

func _on_rematch() -> void:
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").play_sfx_requested.emit("click", "UI")
	visible = false
	rematch_pressed.emit()
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.start_new_match(gm.get("current_mode"))

func _on_menu() -> void:
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").play_sfx_requested.emit("click", "UI")
	visible = false
	menu_pressed.emit()
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").change_state(1) # MAIN_MENU
