class_name MainMenu
extends Control

## Main Menu Screen

signal play_pressed(mode: GameEnums.GameMode)
signal settings_pressed()
signal quit_pressed()

@onready var btn_vs_ai: Button = $SafeArea/VBoxRoot/HBoxContent/MenuButtons/BtnVsAI
@onready var btn_pass_play: Button = $SafeArea/VBoxRoot/HBoxContent/MenuButtons/BtnPassPlay
@onready var btn_settings: Button = $SafeArea/VBoxRoot/HBoxContent/MenuButtons/BtnSettings
@onready var btn_quit: Button = $SafeArea/VBoxRoot/HBoxContent/MenuButtons/BtnQuit
@onready var stats_label: Label = $SafeArea/VBoxRoot/HBoxContent/StatsPanel/VBox/StatsText

func _ready() -> void:
	btn_vs_ai.pressed.connect(_on_vs_ai_pressed)
	btn_pass_play.pressed.connect(_on_pass_play_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

	_update_stats_display()
	EventBus.profile_updated.connect(func(_p): _update_stats_display())

func _update_stats_display() -> void:
	var stats = SaveManager.profile_data
	var text = "PLAYER CAREER:\n"
	text += "• Matches Won: %d / %d\n" % [stats.get("matches_won", 0), stats.get("matches_played", 0)]
	text += "• Arena Duels Won: %d / %d\n" % [stats.get("duels_won", 0), stats.get("duels_fought", 0)]
	text += "• Underdog Upsets: %d\n" % stats.get("underdog_victories", 0)
	text += "\nPLATFORM: %s\n" % (
		"Samsung Galaxy (" + PlatformManager.device_model + ")" if PlatformManager.is_samsung_galaxy
		else ("Steam PC" if PlatformManager.is_desktop() else OS.get_name())
	)
	text += "Display: %.0f Hz" % PlatformManager.device_refresh_rate
	stats_label.text = text

func _on_vs_ai_pressed() -> void:
	EventBus.play_sfx_requested.emit("click", "UI")
	play_pressed.emit(GameEnums.GameMode.VS_AI)

func _on_pass_play_pressed() -> void:
	EventBus.play_sfx_requested.emit("click", "UI")
	play_pressed.emit(GameEnums.GameMode.LOCAL_PASS_AND_PLAY)

func _on_settings_pressed() -> void:
	EventBus.play_sfx_requested.emit("click", "UI")
	settings_pressed.emit()

func _on_quit_pressed() -> void:
	EventBus.play_sfx_requested.emit("click", "UI")
	quit_pressed.emit()
	get_tree().quit()
