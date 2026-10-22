class_name Main
extends Node

## Root Scene Controller for Duel of Kings: Animated Chess
## Manages high-level screen transitions and view switching

@onready var splash_screen: SplashScreen = $Screens/SplashScreen
@onready var main_menu: MainMenu = $Screens/MainMenu
@onready var settings_menu: SettingsMenu = $Screens/SettingsMenu
@onready var pause_menu: PauseMenu = $Screens/PauseMenu
@onready var victory_screen: VictoryScreen = $Screens/VictoryScreen

@onready var match_container: Control = $GameplayLayers/MatchLayer
@onready var chess_board: ChessBoard2D = $GameplayLayers/MatchLayer/ChessBoard
@onready var match_hud: MatchHUD = $GameplayLayers/MatchLayer/MatchHUD

@onready var duel_container: Control = $GameplayLayers/DuelLayer
@onready var duel_arena: DuelArena = $GameplayLayers/DuelLayer/DuelArena
@onready var duel_hud: DuelHUD = $GameplayLayers/DuelLayer/DuelHUD

func _ready() -> void:
	_connect_screen_events()
	_connect_game_state_events()
	_show_splash()

func _connect_screen_events() -> void:
	splash_screen.splash_finished.connect(func():
		splash_screen.visible = false
		GameManager.change_state(GameEnums.GameState.MAIN_MENU)
	)

	main_menu.play_pressed.connect(func(mode):
		main_menu.visible = false
		GameManager.start_new_match(mode)
	)

	main_menu.settings_pressed.connect(func():
		settings_menu.visible = true
	)

	pause_menu.settings_requested.connect(func():
		settings_menu.visible = true
	)

func _connect_game_state_events() -> void:
	EventBus.game_state_changed.connect(_on_game_state_changed)

func _show_splash() -> void:
	_hide_all_layers()
	splash_screen.visible = true

func _hide_all_layers() -> void:
	splash_screen.visible = false
	main_menu.visible = false
	match_container.visible = false
	duel_container.visible = false
	pause_menu.visible = false
	settings_menu.visible = false
	victory_screen.visible = false

func _on_game_state_changed(new_state: GameEnums.GameState, _old_state: GameEnums.GameState) -> void:
	match new_state:
		GameEnums.GameState.MAIN_MENU:
			_hide_all_layers()
			main_menu.visible = true

		GameEnums.GameState.BOARD_TURN:
			match_container.visible = true
			duel_container.visible = false
			pause_menu.visible = false
			main_menu.visible = false

		GameEnums.GameState.DUEL_COMBAT:
			# Seamless transition into Duel Arena!
			match_container.visible = false
			duel_container.visible = true

		GameEnums.GameState.PAUSED:
			pause_menu.visible = true

		GameEnums.GameState.GAME_OVER:
			# Board stays partially visible under victory modal
			pause_menu.visible = false
			victory_screen.visible = true
