extends Node

## Duel Director
## Orchestrates pure 1988 Battle Chess 3-act choreographed execution duels:
## - Freezes chess clocks during duels
## - Targeted square zoom (Vector3(sq_x, 3.2, sq_z + 4.8))
## - Act 1 (0.0s - 2.5s) Opening Strike: Attacker heavy strike -> Defender parries/blocks
## - Act 2 (2.5s - 5.0s) Counter-Blow: Defender retaliates -> Attacker sidesteps/deflects
## - Act 3 (5.0s - 7.5s) The Finisher: Attacker executes signature theme kill -> Defender collapse
## - 7.5s - 8.0s: Camera smoothly pulls back to stationary isometric overview
## - 8.0s: Attacker claims square, clock unpauses, turn advances
## NO HIT POINTS / NO COMBAT CONTROLS: Chess rules are absolute; attacker always wins the square.

signal duel_started(attacker: Dictionary, victim: Dictionary, anim_data: Dictionary)
signal duel_act_started(act_number: int, act_name: String, description: String)
signal duel_impact_hit(anim_data: Dictionary)
signal duel_completed(attacker: Dictionary, victim: Dictionary)
signal chess_clock_paused(is_paused: bool)
signal camera_framing_requested(camera_angle: String, zoom_level: float, target_pos: Vector2)
signal slow_motion_changed(time_scale: float)

@export var slow_mo_scale: float = 0.4
@export var default_time_scale: float = 1.0
@export var active_theme: String = "high_fantasy"

var is_duel_in_progress: bool = false
var active_duel_data: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Initiate a 5-8 second 3-act scripted cinematic duel capture
func start_cinematic_duel(attacker: Dictionary, victim: Dictionary, board_world_pos: Vector2) -> void:
	if is_duel_in_progress:
		return

	is_duel_in_progress = true

	# 1. Freeze the Chess Clock Hook
	chess_clock_paused.emit(true)

	# 2. Lookup KillMatrix 3-act choreographed data
	var atk_type = attacker.get("type", "P")
	var vic_type = victim.get("type", "P")
	if has_node("/root/KillMatrix"):
		active_duel_data = get_node("/root/KillMatrix").get_duel_animation(active_theme, atk_type, vic_type)
	else:
		active_duel_data = {
			"act1_name": "Opening Strike",
			"act1_desc": "The attacker delivers a heavy opening blow, met by the defender's guard!",
			"act2_name": "Counter-Blow",
			"act2_desc": "The defender retaliates with a fierce counter-strike, but the attacker sidesteps!",
			"act3_name": "The Finisher",
			"act3_desc": "The attacker executes their signature theme finisher, striking down the defender!",
			"narrative": "Combat engaged!",
			"sfx": "clash"
		}

	# 3. Targeted Square Duel Zoom (zooms to square in 0.4s)
	camera_framing_requested.emit("capture_zoom", 1.5, board_world_pos)
	duel_started.emit(attacker, victim, active_duel_data)

	# -------------------------------------------------------------
	# ACT 1 (0.0s - 2.5s): Opening Strike & Parry/Block
	# -------------------------------------------------------------
	duel_act_started.emit(1, active_duel_data.get("act1_name", "Opening Strike"), active_duel_data.get("act1_desc", "Heavy opening strike!"))
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("clash", "Combat")

	# Wait until Act 2 (2.5s)
	await get_tree().create_timer(2.5).timeout

	# -------------------------------------------------------------
	# ACT 2 (2.5s - 5.0s): Counter-Blow & Evade/Deflect
	# -------------------------------------------------------------
	duel_act_started.emit(2, active_duel_data.get("act2_name", "Counter-Blow"), active_duel_data.get("act2_desc", "Retaliation counter-strike!"))
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("move", "SFX")

	# Wait until Act 3 (2.5s -> 5.0s total)
	await get_tree().create_timer(2.5).timeout

	# -------------------------------------------------------------
	# ACT 3 (5.0s - 7.5s): The Finisher & Dramatic Collapse
	# -------------------------------------------------------------
	duel_act_started.emit(3, active_duel_data.get("act3_name", "The Finisher"), active_duel_data.get("act3_desc", "Signature theme kill shot!"))
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("critical", "Combat")

	# Finisher strike windup (~0.8s)
	await get_tree().create_timer(0.8).timeout

	# Kill Impact: Slow-mo (0.4x), haptics, emissive flash, screenshake
	_apply_slow_motion(slow_mo_scale)
	duel_impact_hit.emit(active_duel_data)
	if has_node("/root/PlatformManager"):
		get_node("/root/PlatformManager").trigger_haptic(75)

	# Slow motion duration (0.35s in scaled time)
	await get_tree().create_timer(0.35 * slow_mo_scale).timeout
	_restore_normal_speed()

	# Remaining Act 3 resolution time until 7.5s (5.0 + 0.8 + 0.35 = 6.15s -> ~1.35s remaining)
	await get_tree().create_timer(1.35).timeout

	# -------------------------------------------------------------
	# CAMERA PULLBACK (7.5s - 8.0s): Smooth overview return
	# -------------------------------------------------------------
	camera_framing_requested.emit("default_overview", 1.0, board_world_pos)
	await get_tree().create_timer(0.5).timeout

	# 8.0s: Conclude duel & unpause chess clock
	chess_clock_paused.emit(false)
	is_duel_in_progress = false

	duel_completed.emit(attacker, victim)

func _apply_slow_motion(scale_val: float) -> void:
	Engine.time_scale = scale_val
	slow_motion_changed.emit(scale_val)

func _restore_normal_speed() -> void:
	Engine.time_scale = default_time_scale
	slow_motion_changed.emit(default_time_scale)

func set_active_theme(theme_id: String) -> void:
	active_theme = theme_id.to_lower()
