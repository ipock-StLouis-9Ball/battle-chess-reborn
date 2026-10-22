class_name MainView
extends Control

## Top-Level Master Scene
## Assembles Board, DuelArena, CinematicCamera, and HUD with theme switching and Elo ranking

@onready var board_view: BoardView = $Board
@onready var duel_arena_view: DuelArenaView = $DuelArena
@onready var camera: CinematicCamera = $CinematicCamera

# HUD elements
@onready var turn_label: Label = $HUD/TopBar/TurnLabel
@onready var white_clock_label: Label = $HUD/TopBar/WhiteClock
@onready var black_clock_label: Label = $HUD/TopBar/BlackClock
@onready var elo_badge: Label = $HUD/TopBar/EloBadge
@onready var platform_label: Label = $HUD/BottomBar/PlatformLabel
@onready var btn_theme_hf: Button = $HUD/BottomBar/ThemeHF
@onready var btn_theme_cp: Button = $HUD/BottomBar/ThemeCP
@onready var btn_theme_el: Button = $HUD/BottomBar/ThemeEL

var white_time: float = 600.0 # 10 minute blitz
var black_time: float = 600.0
var is_clock_running: bool = true
var player_elo: int = 1450 # Player Elo rating

func _ready() -> void:
	_update_platform_info()
	_update_elo_display()
	_connect_events()

func _connect_events() -> void:
	var chess_board = board_view.chess_board
	chess_board.turn_changed.connect(_on_turn_changed)
	chess_board.game_over.connect(_on_game_over)

	if has_node("/root/DuelDirector"):
		var dd = get_node("/root/DuelDirector")
		dd.chess_clock_paused.connect(func(paused): is_clock_running = not paused)

	btn_theme_hf.pressed.connect(func(): ThemeManager.set_theme("high_fantasy"))
	btn_theme_cp.pressed.connect(func(): ThemeManager.set_theme("cyberpunk"))
	btn_theme_el.pressed.connect(func(): ThemeManager.set_theme("eldritch"))

func _process(delta: float) -> void:
	if not is_clock_running:
		return

	var active_color = board_view.chess_board.get_active_color()
	if active_color == "white":
		white_time = maxf(0.0, white_time - delta)
	else:
		black_time = maxf(0.0, black_time - delta)

	_update_clock_display()

func _update_clock_display() -> void:
	white_clock_label.text = "White: %02d:%02d" % [int(white_time) / 60, int(white_time) % 60]
	black_clock_label.text = "Black: %02d:%02d" % [int(black_time) / 60, int(black_time) % 60]

func _on_turn_changed(turn_color: String, turn_num: int) -> void:
	turn_label.text = "%s's Turn (Turn %d)" % [turn_color.to_upper(), turn_num]
	turn_label.add_theme_color_override("font_color", Color(1, 1, 1) if turn_color == "white" else Color(1, 0.4, 0.4))

func _on_game_over(winner_color: String, reason: String) -> void:
	is_clock_running = false
	turn_label.text = "GAME OVER: %s (%s)" % [winner_color.to_upper(), reason]

	# Calculate Ranked Elo adjustment
	var score = 1.0 if winner_color == "white" else (0.5 if winner_color == "draw" else 0.0)
	var opponent_elo = 1420
	var elo_result = EloCalculator.calculate_rating_change(player_elo, opponent_elo, score)
	player_elo = elo_result["player_a"]["new_rating"]
	_update_elo_display()

func _update_elo_display() -> void:
	var division = EloCalculator.get_division_label(player_elo)
	var color = EloCalculator.get_tier_color(player_elo)
	elo_badge.text = "🎖️ %s (%d Elo)" % [division, player_elo]
	elo_badge.add_theme_color_override("font_color", color)

func _update_platform_info() -> void:
	if has_node("/root/PlatformManager"):
		var pm = get_node("/root/PlatformManager")
		platform_label.text = pm.get_store_pricing_label()
