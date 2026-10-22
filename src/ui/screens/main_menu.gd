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
	if is_instance_valid(btn_vs_ai):
		btn_vs_ai.pressed.connect(_on_vs_ai_pressed)
	if is_instance_valid(btn_pass_play):
		btn_pass_play.pressed.connect(_on_pass_play_pressed)
	if is_instance_valid(btn_settings):
		btn_settings.pressed.connect(_on_settings_pressed)
	if is_instance_valid(btn_quit):
		btn_quit.pressed.connect(_on_quit_pressed)
		if has_node("/root/PlatformManager") and get_node("/root/PlatformManager").is_mobile():
			btn_quit.visible = false

	_update_stats_display()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").profile_updated.connect(func(_p): _update_stats_display())

func _update_stats_display() -> void:
	var stats = {}
	if has_node("/root/SaveManager"):
		stats = get_node("/root/SaveManager").profile_data
	var text = "PLAYER CAREER:\n"
	text += "• Matches Won: %d / %d\n" % [stats.get("matches_won", 0), stats.get("matches_played", 0)]
	text += "• Arena Duels Won: %d / %d\n" % [stats.get("duels_won", 0), stats.get("duels_fought", 0)]
	text += "• Underdog Upsets: %d\n" % stats.get("underdog_victories", 0)

	var platform_str = OS.get_name()
	var hz = 60.0
	if has_node("/root/PlatformManager"):
		var pm = get_node("/root/PlatformManager")
		hz = pm.device_refresh_rate
		if pm.has_method("get_device_summary"):
			var summary = pm.get_device_summary()
			if pm.is_mobile():
				platform_str = "%s %s (%s)" % [summary.get("vendor", "Mobile"), summary.get("form_factor", "Device"), summary.get("model", "")]
			elif pm.is_desktop():
				platform_str = "Steam PC Edition"
			else:
				platform_str = summary.get("os", OS.get_name())
	text += "\nPLATFORM: %s\n" % platform_str
	text += "Display: %.0f Hz" % hz
	if is_instance_valid(stats_label):
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
