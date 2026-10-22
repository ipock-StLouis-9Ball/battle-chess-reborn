class_name SplashScreen
extends Control

## Boot Splash Screen with cinematic logo presentation

signal splash_finished()

@onready var logo_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/SubtitleLabel
@onready var anim_root: Control = $CenterContainer/VBoxContainer

func _ready() -> void:
	play_intro()

func play_intro() -> void:
	anim_root.modulate.a = 0.0
	anim_root.scale = Vector2(0.9, 0.9)
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(anim_root, "modulate:a", 1.0, 0.8)
	tween.parallel().tween_property(anim_root, "scale", Vector2.ONE, 0.8)
	
	EventBus.play_sfx_requested.emit("victory", "UI")
	
	await get_tree().create_timer(1.8).timeout
	
	var fade_out = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade_out.tween_property(anim_root, "modulate:a", 0.0, 0.5)
	await fade_out.finished
	
	splash_finished.emit()
