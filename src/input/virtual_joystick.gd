class_name VirtualJoystick
extends Control

## Analog Virtual Joystick for mobile touchscreen devices (Samsung Galaxy)
## Translates touch drags into normalized direction vectors.

signal stick_moved(vector: Vector2)
signal stick_released()

@export var max_radius: float = 75.0
@export var deadzone: float = 0.15

var touch_pointer_id: int = -1
var stick_center_pos: Vector2 = Vector2.ZERO
var current_output: Vector2 = Vector2.ZERO

@onready var base_circle: Panel = get_node_or_null("Base")
@onready var tip_handle: Panel = get_node_or_null("Base/Tip")

func _ready() -> void:
	if base_circle:
		stick_center_pos = base_circle.position + (base_circle.size * 0.5)
	_update_visibility()
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").input_scheme_changed.connect(func(_scheme): _update_visibility())

func _update_visibility() -> void:
	var touch_enabled: bool = false
	var opacity: float = 0.85
	if has_node("/root/SettingsManager"):
		var sm = get_node("/root/SettingsManager")
		touch_enabled = sm.get("show_touch_controls")
		opacity = sm.get("touch_controls_opacity")
	if has_node("/root/PlatformManager"):
		var pm = get_node("/root/PlatformManager")
		if pm.has_method("is_mobile") and pm.is_mobile():
			touch_enabled = true
	elif OS.get_name() == "Android" or OS.get_name() == "iOS":
		touch_enabled = true

	visible = touch_enabled
	modulate.a = opacity

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_pointer_id == -1:
			touch_pointer_id = event.index
			_update_stick_position(event.position)
		elif not event.pressed and event.index == touch_pointer_id:
			_reset_stick()

	elif event is InputEventScreenDrag and event.index == touch_pointer_id:
		_update_stick_position(event.position)

func _update_stick_position(touch_pos: Vector2) -> void:
	var diff = touch_pos - (base_circle.position + (base_circle.size * 0.5))
	var dist = diff.length()
	var dir = diff.normalized()

	if dist > max_radius:
		diff = dir * max_radius

	tip_handle.position = (base_circle.size * 0.5) + diff - (tip_handle.size * 0.5)

	var normalized_dist = dist / max_radius
	if normalized_dist < deadzone:
		current_output = Vector2.ZERO
	else:
		var remapped_dist = (normalized_dist - deadzone) / (1.0 - deadzone)
		current_output = dir * remapped_dist

	stick_moved.emit(current_output)
	_inject_actions(current_output)

func _reset_stick() -> void:
	touch_pointer_id = -1
	current_output = Vector2.ZERO
	tip_handle.position = (base_circle.size * 0.5) - (tip_handle.size * 0.5)
	stick_released.emit()
	_inject_actions(Vector2.ZERO)

func _inject_actions(output: Vector2) -> void:
	# Inject into Godot's input map for seamless action detection
	if output.x < -0.3:
		Input.action_press("duel_move_left", -output.x)
	else:
		Input.action_release("duel_move_left")

	if output.x > 0.3:
		Input.action_press("duel_move_right", output.x)
	else:
		Input.action_release("duel_move_right")

	if output.y < -0.3:
		Input.action_press("duel_move_up", -output.y)
	else:
		Input.action_release("duel_move_up")

	if output.y > 0.3:
		Input.action_press("duel_move_down", output.y)
	else:
		Input.action_release("duel_move_down")
