class_name FighterControllerPlayer
extends Node

## Player controller for fighter entity in duel arena
## Maps Keyboard, Gamepad, and Virtual Touch Input to combat commands

@export var fighter: FighterBase

# Touch virtual inputs injected by on-screen controls
var touch_move_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	if fighter == null and get_parent() is FighterBase:
		fighter = get_parent()

func _physics_process(_delta: float) -> void:
	if fighter == null or not fighter.is_player_controlled:
		return

	# Gather movement input
	var move_x = Input.get_axis("duel_move_left", "duel_move_right")
	var move_y = Input.get_axis("duel_move_up", "duel_move_down")
	var move_dir = Vector2(move_x, move_y)

	# Combine with touch joystick if active
	if touch_move_vector.length_squared() > 0.01:
		move_dir = touch_move_vector

	fighter.input_vector = move_dir

func _unhandled_input(event: InputEvent) -> void:
	if fighter == null or not fighter.is_player_controlled:
		return

	if event.is_action_pressed("duel_attack_light"):
		fighter.execute_light_attack()
	elif event.is_action_pressed("duel_attack_heavy"):
		fighter.execute_heavy_attack()
	elif event.is_action_pressed("duel_dodge"):
		fighter.execute_dodge()
	elif event.is_action_pressed("duel_special"):
		fighter.execute_special()
