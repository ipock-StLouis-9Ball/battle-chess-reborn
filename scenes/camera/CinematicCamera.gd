class_name CinematicCamera
extends Camera3D

## Heroic 3D Isometric & Action Duel Camera
## - Recreates the iconic 1988 perspective with stationary isometric overview:
##   * Position: Vector3(0.0, 16.0, 20.0)
##   * Pitch: Vector3(-39.5, 0.0, 0.0) (classic ~40° elevation angle looking down at board center)
##   * FOV: 35.0 (eliminates wide-angle distortion)
##   * White at bottom of screen, Black at top of screen
## - Targeted square zoom on capture execution:
##   * Smoothly tweens in 0.4s to Vector3(sq_x, 3.2, sq_z + 4.8) looking at Vector3(sq_x, 1.2, sq_z)
##   * Smoothly returns to stationary overview in 0.5s at duel conclusion

@export var base_elevation_angle: float = 39.5 # Classic ~40° elevation pitch
@export var base_fov: float = 35.0

var base_pos: Vector3 = Vector3(0.0, 16.0, 20.0)
var base_rot: Vector3 = Vector3(-39.5, 0.0, 0.0)

var is_in_duel: bool = false
var active_tween: Tween

func _ready() -> void:
	current = true
	fov = base_fov
	position = base_pos
	rotation_degrees = base_rot
	make_current()

	if has_node("/root/DuelDirector"):
		var dd = get_node("/root/DuelDirector")
		dd.camera_framing_requested.connect(_on_framing_requested)
		dd.duel_impact_hit.connect(_on_duel_impact)
		dd.duel_completed.connect(_on_duel_completed)

## Calculate and restore stationary heroic overview framing
func reset_to_heroic_overview(duration: float = 0.5) -> void:
	is_in_duel = false
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_property(self, "position", base_pos, duration)
	active_tween.tween_property(self, "rotation_degrees", base_rot, duration)
	active_tween.tween_property(self, "fov", base_fov, duration)

## Targeted square zoom: focused directly on contested square (sq_x, sq_z)
func zoom_to_square(sq_x: float, sq_z: float, duration: float = 0.4) -> void:
	is_in_duel = true
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	# Looking directly at Vector3(sq_x, 1.2, sq_z) from Vector3(sq_x, 3.2, sq_z + 4.8)
	var focus_pos = Vector3(sq_x, 3.2, sq_z + 4.8)
	var focus_rot = Vector3(-22.62, 0.0, 0.0)

	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "position", focus_pos, duration)
	active_tween.tween_property(self, "rotation_degrees", focus_rot, duration)
	active_tween.tween_property(self, "fov", 33.0, duration)

## Dynamic plunge into 3D duel clash (alias for backward compatibility)
func zoom_to_duel_focus(world_target: Vector3, duration: float = 0.4) -> void:
	zoom_to_square(world_target.x, world_target.z, duration)

func _on_framing_requested(angle: String, zoom_level: float, target_pos: Vector2) -> void:
	if zoom_level > 1.0 or angle == "capture_zoom" or angle == "cinematic_action_tracking":
		zoom_to_square(target_pos.x, target_pos.y, 0.4)
	else:
		reset_to_heroic_overview(0.5)

func _on_duel_impact(_anim_data: Dictionary) -> void:
	# Impact screen shake
	var cur_pos = position
	var shake_tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	shake_tw.tween_property(self, "position", cur_pos + Vector3(0.18, -0.12, 0.1), 0.04)
	shake_tw.tween_property(self, "position", cur_pos + Vector3(-0.14, 0.1, -0.08), 0.05)
	shake_tw.tween_property(self, "position", cur_pos, 0.06)

func _on_duel_completed(_atk: Dictionary, _vic: Dictionary) -> void:
	reset_to_heroic_overview(0.5)
