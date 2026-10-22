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
	if is_instance_valid(btn_resume):
		btn_resume.pressed.connect(_on_resume)
	if is_instance_valid(btn_settings):
		btn_settings.pressed.connect(_on_settings)
	if is_instance_valid(btn_forfeit):
		btn_forfeit.pressed.connect(_on_forfeit)

func _on_resume() -> void:
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").play_sfx_requested.emit("click", "UI")
	resume_requested.emit()
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").toggle_pause()

func _on_settings() -> void:
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").play_sfx_requested.emit("click", "UI")
	settings_requested.emit()

func _on_forfeit() -> void:
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").play_sfx_requested.emit("click", "UI")
	forfeit_requested.emit()
	get_tree().paused = false
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").change_state(1) # MAIN_MENU
