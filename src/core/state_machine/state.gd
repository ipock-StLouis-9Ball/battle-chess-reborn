class_name State
extends Node

## Base class for finite state machine states

signal transitioned(state_name: String, msg: Dictionary)

var state_machine: Node = null

func enter(_msg: Dictionary = {}) -> void:
	pass

func exit() -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
