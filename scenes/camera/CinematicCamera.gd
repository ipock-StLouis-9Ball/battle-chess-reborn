class_name CinematicCamera
extends Camera3D

## Heroic 3D Isometric & Action Duel Camera
## - Recreates the iconic 1988 perspective with stationary isometric overview:
##   * Position: Vector3(0.0, 24.5, 29.5)
##   * Pitch: Vector3(-38.5, 0.0, 0.0) (~38.5° elevation angle looking down at board center)
##   * FOV: 38.0 (frames the entire 25.4m dais, plinths, and braziers without distortion)
##   * White at bottom of screen, Black at top of screen
## - Targeted square zoom on capture execution:
##   * Smoothly tweens in 0.4s to Vector3(sq_x, 4.2, sq_z + 6.2) looking at Vector3(sq_x, 1.4, sq_z)
##   * Smoothly returns to stationary overview in 0.5s at duel conclusion

@export var base_elevation_angle: float = 38.5 # Classic ~38.5° elevation pitch
@export var base_fov: float = 38.0

var base_pos: Vector3 = Vector3(0.0, 24.5, 29.5)
var base_rot: Vector3 = Vector3(-38.5, 0.0, 0.0)

var is_in_duel: bool = false
var active_tween: Tween

func _ready() -> void:
	current = true
	_update_adaptive_fov()
	fov = base_fov
	position = base_pos
	rotation_degrees = base_rot
	make_current()

	var vp = get_viewport()
	if is_instance_valid(vp):
		vp.size_changed.connect(_on_viewport_resized)

	if has_node("/root/DuelDirector"):
		var dd = get_node("/root/DuelDirector")
		dd.camera_framing_requested.connect(_on_framing_requested)
		dd.duel_impact_hit.connect(_on_duel_impact)
		dd.duel_completed.connect(_on_duel_completed)

func _on_viewport_resized() -> void:
	_update_adaptive_fov()
	if not is_in_duel:
		fov = base_fov

func _update_adaptive_fov() -> void:
	var vp = get_viewport()
	if not is_instance_valid(vp):
		return
	var vp_size = vp.get_visible_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
	var aspect = vp_size.x / vp_size.y
	# Standard landscape is 16:9 (~1.778). On tablets (4:3 = 1.33, 16:10 = 1.6) or foldables (~1.0),
	# adapt FOV so the full board and plinth staging are framed perfectly without horizontal cropping.
	if aspect < 1.7:
		var factor = 1.7778 / aspect
		base_fov = clampf(38.0 * factor, 38.0, 52.0)
	else:
		base_fov = 38.0

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

	# Looking directly at Vector3(sq_x, 1.4, sq_z) from Vector3(sq_x, 4.2, sq_z + 6.2)
	var focus_pos = Vector3(sq_x, 4.2, sq_z + 6.2)
	var focus_rot = Vector3(-24.3, 0.0, 0.0)

	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "position", focus_pos, duration)
	active_tween.tween_property(self, "rotation_degrees", focus_rot, duration)
	active_tween.tween_property(self, "fov", 35.0, duration)

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
