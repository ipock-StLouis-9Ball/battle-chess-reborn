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
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").input_scheme_changed.connect(func(_scheme): _update_visibility())

	if is_instance_valid(btn_light):
		btn_light.button_down.connect(func(): _on_button_down("duel_attack_light"))
		btn_light.button_up.connect(func(): _on_button_up("duel_attack_light"))

	if is_instance_valid(btn_heavy):
		btn_heavy.button_down.connect(func(): _on_button_down("duel_attack_heavy"))
		btn_heavy.button_up.connect(func(): _on_button_up("duel_attack_heavy"))

	if is_instance_valid(btn_dodge):
		btn_dodge.button_down.connect(func(): _on_button_down("duel_dodge"))
		btn_dodge.button_up.connect(func(): _on_button_up("duel_dodge"))

	if is_instance_valid(btn_special):
		btn_special.button_down.connect(func(): _on_button_down("duel_special"))
		btn_special.button_up.connect(func(): _on_button_up("duel_special"))

func _update_visibility() -> void:
	var touch_enabled = false
	var opacity = 0.85
	if has_node("/root/SettingsManager"):
		var sm = get_node("/root/SettingsManager")
		touch_enabled = sm.get("show_touch_controls")
		opacity = sm.get("touch_controls_opacity")
	if has_node("/root/PlatformManager"):
		var pm = get_node("/root/PlatformManager")
		if pm.has_method("is_mobile") and pm.is_mobile():
			touch_enabled = true
	elif OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS", "iPadOS"]:
		touch_enabled = true

	visible = touch_enabled
	modulate.a = opacity

func _on_button_down(action_name: String) -> void:
	Input.action_press(action_name)
	if has_node("/root/PlatformManager"):
		get_node("/root/PlatformManager").trigger_haptic(20)

func _on_button_up(action_name: String) -> void:
	Input.action_release(action_name)
