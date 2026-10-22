class_name FighterControllerAI
extends Node

## AI Combat Controller for opponent fighter in Duel Arena
## Employs distance appraisal, reaction dodges, and strategic combo timing.

@export var fighter: FighterBase
@export var opponent: FighterBase
@export var difficulty: GameEnums.AIDifficulty = GameEnums.AIDifficulty.MEDIUM

var decision_timer: float = 0.0
var preferred_distance: float = 75.0
var strafe_direction: float = 1.0

func _ready() -> void:
	if fighter == null and get_parent() is FighterBase:
		fighter = get_parent()

func _physics_process(delta: float) -> void:
	if fighter == null or opponent == null or fighter.current_state == GameEnums.FighterState.DEFEAT or opponent.current_state == GameEnums.FighterState.DEFEAT:
		if fighter:
			fighter.input_vector = Vector2.ZERO
		return

	decision_timer -= delta
	if decision_timer <= 0.0:
		_make_tactical_decision()
		# Decision frequency based on difficulty
		match difficulty:
			GameEnums.AIDifficulty.EASY: decision_timer = randf_range(0.4, 0.7)
			GameEnums.AIDifficulty.MEDIUM: decision_timer = randf_range(0.25, 0.45)
			GameEnums.AIDifficulty.HARD: decision_timer = randf_range(0.12, 0.25)
			GameEnums.AIDifficulty.MASTER: decision_timer = randf_range(0.08, 0.15)

func _make_tactical_decision() -> void:
	var to_opponent = opponent.global_position - fighter.global_position
	var dist = to_opponent.length()
	var dir_to_opponent = to_opponent.normalized()

	# Keep facing opponent
	fighter.facing_direction = signf(to_opponent.x) if abs(to_opponent.x) > 5.0 else fighter.facing_direction
	fighter._update_facing()

	# 1. Reaction Dodge: If opponent is attacking and in range, chance to dodge!
	var opponent_attacking = (opponent.current_state == GameEnums.FighterState.ATTACK_LIGHT or
		opponent.current_state == GameEnums.FighterState.ATTACK_HEAVY or
		opponent.current_state == GameEnums.FighterState.SPECIAL)

	if opponent_attacking and dist < 120.0:
		var dodge_chance = 0.2
		if difficulty == GameEnums.AIDifficulty.HARD: dodge_chance = 0.55
		elif difficulty == GameEnums.AIDifficulty.MASTER: dodge_chance = 0.85

		if randf() < dodge_chance:
			# Dodge backward or perpendicular
			fighter.input_vector = -dir_to_opponent
			fighter.execute_dodge()
			return

	# 2. Attack Range execution
	if dist <= preferred_distance:
		# In striking range!
		fighter.input_vector = Vector2.ZERO

		# Try special first if available
		if fighter.special_cooldown_timer <= 0.001 and randf() < 0.6:
			fighter.execute_special()
			return

		# Light or Heavy Attack
		if randf() < 0.65:
			fighter.execute_light_attack()
		else:
			fighter.execute_heavy_attack()
	else:
		# Approach with slight erratic strafing to evade straight attacks
		if randf() < 0.15:
			strafe_direction *= -1.0
		var perpendicular = Vector2(-dir_to_opponent.y, dir_to_opponent.x) * strafe_direction * 0.4
		fighter.input_vector = (dir_to_opponent + perpendicular).normalized()
