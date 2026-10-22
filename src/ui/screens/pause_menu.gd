class_name PauseMenu
extends Control

## In-game pause modal dialog

signal resume_requested()
signal settings_requested()
signal forfeit_requested()

@onready var btn_resume: Button = $CenterContainer/Panel/VBoxContainer/BtnResume
@onready var btn_settings: Button = $CenterContainer/Panel/VBoxContainer/BtnSettings
@onready var btn_forfeit: Button = $CenterContainer/Panel/VBoxContainer/BtnForfeit

func _ready() -> void:
	btn_resume.pressed.connect(_on_resume)
	btn_settings.pressed.connect(_on_settings)
	btn_forfeit.pressed.connect(_on_forfeit)

func _on_resume() -> void:
	EventBus.play_sfx_requested.emit("click", "UI")
	resume_requested.emit()
	GameManager.toggle_pause()

func _on_settings() -> void:
	EventBus.play_sfx_requested.emit("click", "UI")
	settings_requested.emit()

func _on_forfeit() -> void:
	EventBus.play_sfx_requested.emit("click", "UI")
	forfeit_requested.emit()
	get_tree().paused = false
	GameManager.change_state(GameEnums.GameState.MAIN_MENU)
