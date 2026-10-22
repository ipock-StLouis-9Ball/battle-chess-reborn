class_name StateMachine
extends Node

## Generic Finite State Machine manager

signal transition_completed(new_state: Node, previous_state: Node)

@export var initial_state: Node

var current_state: Node
var previous_state: Node
var states: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.state_machine = self
			child.transitioned.connect(transition_to)

	if initial_state:
		initial_state.enter()
		current_state = initial_state

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func transition_to(target_state_name: String, msg: Dictionary = {}) -> void:
	var target_key = target_state_name.to_lower()
	if not states.has(target_key):
		push_warning("[StateMachine] State %s does not exist" % target_state_name)
		return

	if current_state:
		current_state.exit()

	previous_state = current_state
	current_state = states[target_key]
	current_state.enter(msg)
	transition_completed.emit(current_state, previous_state)
