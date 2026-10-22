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

@onready var base_circle: Panel = $Base
@onready var tip_handle: Panel = $Base/Tip

func _ready() -> void:
	stick_center_pos = base_circle.position + (base_circle.size * 0.5)
	_update_visibility()
	EventBus.input_scheme_changed.connect(func(_scheme): _update_visibility())

func _update_visibility() -> void:
	# Show on mobile or if force-enabled in settings
	var should_show = SettingsManager.show_touch_controls or PlatformManager.is_mobile()
	visible = should_show
	modulate.a = SettingsManager.touch_controls_opacity

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
