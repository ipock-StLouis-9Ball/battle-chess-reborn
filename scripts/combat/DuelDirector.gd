extends Node

## Duel Director
## Orchestrates cinematic duel capture sequences:
## - Freezes chess clocks during duels
## - Applies 0.4x slow-motion on critical impact frames
## - Coordinates dynamic camera framing and letterboxing
## - Triggers KillMatrix animations and audio

signal duel_started(attacker: Dictionary, victim: Dictionary, anim_data: Dictionary)
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

## Initiate a cinematic duel capture
func start_cinematic_duel(attacker: Dictionary, victim: Dictionary, board_world_pos: Vector2) -> void:
	if is_duel_in_progress:
		return

	is_duel_in_progress = true

	# 1. Pause the Chess Clock Hook
	chess_clock_paused.emit(true)

	# 2. Lookup KillMatrix data
	var atk_type = attacker.get("type", "P")
	var vic_type = victim.get("type", "P")
	if has_node("/root/KillMatrix"):
		active_duel_data = get_node("/root/KillMatrix").get_duel_animation(active_theme, atk_type, vic_type)
	else:
		active_duel_data = {"duration": 2.5, "impact_time": 1.2, "narrative": "Combat engaged!"}

	var camera_angle = active_duel_data.get("camera_angle", "cinematic_action_tracking")
	var duration = active_duel_data.get("duration", 2.5)
	var impact_time = active_duel_data.get("impact_time", 1.2)

	# 3. Dynamic Camera Framing Hook
	camera_framing_requested.emit(camera_angle, 1.45, board_world_pos)
	duel_started.emit(attacker, victim, active_duel_data)

	# 4. Play audio and narrative
	var sfx_name = active_duel_data.get("sfx", "sword_slash")
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("clash", "Combat")

	# Wait until impact moment
	await get_tree().create_timer(impact_time).timeout

	# 5. Slow-Motion (0.4x) on impact frame!
	_apply_slow_motion(slow_mo_scale)
	duel_impact_hit.emit(active_duel_data)

	# Brief impact pause / screenshake
	if has_node("/root/PlatformManager"):
		get_node("/root/PlatformManager").trigger_haptic(60)

	var slow_mo_duration = 0.55
	await get_tree().create_timer(slow_mo_duration * slow_mo_scale).timeout

	# 6. Restore standard speed
	_restore_normal_speed()

	# Remaining animation resolution
	var remaining_time = maxf(0.1, duration - impact_time - slow_mo_duration)
	await get_tree().create_timer(remaining_time).timeout

	# 7. Conclude duel & unpause chess clock
	camera_framing_requested.emit("default_overview", 1.0, board_world_pos)
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
