class_name TouchActionButtons
extends Control

## Touch Action Buttons for Mobile (Samsung Galaxy)
## Ergonomically arranged for right thumb combat controls

@onready var btn_light: Button = $ButtonsContainer/BtnLight
@onready var btn_heavy: Button = $ButtonsContainer/BtnHeavy
@onready var btn_dodge: Button = $ButtonsContainer/BtnDodge
@onready var btn_special: Button = $ButtonsContainer/BtnSpecial

func _ready() -> void:
	_update_visibility()
	EventBus.input_scheme_changed.connect(func(_scheme): _update_visibility())

	btn_light.button_down.connect(func(): _on_button_down("duel_attack_light"))
	btn_light.button_up.connect(func(): _on_button_up("duel_attack_light"))

	btn_heavy.button_down.connect(func(): _on_button_down("duel_attack_heavy"))
	btn_heavy.button_up.connect(func(): _on_button_up("duel_attack_heavy"))

	btn_dodge.button_down.connect(func(): _on_button_down("duel_dodge"))
	btn_dodge.button_up.connect(func(): _on_button_up("duel_dodge"))

	btn_special.button_down.connect(func(): _on_button_down("duel_special"))
	btn_special.button_up.connect(func(): _on_button_up("duel_special"))

func _update_visibility() -> void:
	var should_show = SettingsManager.show_touch_controls or PlatformManager.is_mobile()
	visible = should_show
	modulate.a = SettingsManager.touch_controls_opacity

func _on_button_down(action_name: String) -> void:
	Input.action_press(action_name)
	PlatformManager.trigger_haptic(20)

func _on_button_up(action_name: String) -> void:
	Input.action_release(action_name)
