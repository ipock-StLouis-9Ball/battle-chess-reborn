class_name StateMachine
extends Node

## Generic Finite State Machine manager

signal transition_completed(new_state: State, previous_state: State)

@export var initial_state: State

var current_state: State
var previous_state: State
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
		Logger.warn("StateMachine", "State %s does not exist" % target_state_name)
		return

	if current_state:
		current_state.exit()

	previous_state = current_state
	current_state = states[target_key]
	current_state.enter(msg)
	transition_completed.emit(current_state, previous_state)
