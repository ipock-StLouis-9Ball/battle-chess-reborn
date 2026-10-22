class_name CinematicCamera
extends Camera3D

## Heroic 3D Isometric & Action Duel Camera
## - Features ~39.5° elevation pitch aimed at board center for full character silhouettes
## - Narrow 35° FOV eliminates wide-angle distortion, keeping back-rank Monarchs as prominent as Pawns
## - Dynamic dolly zoom plunge during combat duels with impact screenshake

@export var base_elevation_angle: float = 39.5 # Elevation degrees
@export var base_distance: float = 26.5 # Distance from board center to fill ~85% mobile landscape
@export var base_fov: float = 35.0

var base_pos: Vector3 = Vector3(0.0, 16.5, 21.0)
var base_look_target: Vector3 = Vector3(0.0, 0.5, 1.2)
var current_look_target: Vector3 = Vector3(0.0, 0.5, 1.2)

var is_in_duel: bool = false
var active_tween: Tween

func _ready() -> void:
	current = true
	fov = base_fov
	position = base_pos
	look_at(base_look_target, Vector3.UP)

	if has_node("/root/DuelDirector"):
		var dd = get_node("/root/DuelDirector")
		dd.camera_framing_requested.connect(_on_framing_requested)
		dd.duel_impact_hit.connect(_on_duel_impact)
		dd.duel_completed.connect(_on_duel_completed)

## Calculate and restore heroic overview framing
func reset_to_heroic_overview(duration: float = 0.8) -> void:
	is_in_duel = false
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_property(self, "position", base_pos, duration)
	active_tween.tween_property(self, "fov", base_fov, duration)
	
	var look_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	look_tw.tween_method(func(t: Vector3):
		current_look_target = t
		look_at(current_look_target, Vector3.UP)
	, current_look_target, base_look_target, duration)

## Dynamic plunge into 3D duel clash
func zoom_to_duel_focus(world_target: Vector3, duration: float = 0.7) -> void:
	is_in_duel = true
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	# Position camera for close-up action silhouette (~45° offset)
	var focus_pos = world_target + Vector3(0.0, 5.2, 7.8)
	var focus_target = world_target + Vector3(0.0, 2.2, 0.0)

	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "position", focus_pos, duration)
	active_tween.tween_property(self, "fov", 32.0, duration)

	var look_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	look_tw.tween_method(func(t: Vector3):
		current_look_target = t
		look_at(current_look_target, Vector3.UP)
	, current_look_target, focus_target, duration)

func _on_framing_requested(_angle: String, zoom_level: float, target_pos: Vector2) -> void:
	var w_target = Vector3(target_pos.x, 0.0, target_pos.y)
	if zoom_level > 1.0:
		zoom_to_duel_focus(w_target, 0.65)
	else:
		reset_to_heroic_overview(0.85)

func _on_duel_impact(_anim_data: Dictionary) -> void:
	# Impact screen shake
	var original_pos = position
	var shake_tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	shake_tw.tween_property(self, "position", original_pos + Vector3(0.25, -0.2, 0.15), 0.05)
	shake_tw.tween_property(self, "position", original_pos + Vector3(-0.2, 0.15, -0.1), 0.06)
	shake_tw.tween_property(self, "position", original_pos, 0.08)

func _on_duel_completed(_atk: Dictionary, _vic: Dictionary) -> void:
	reset_to_heroic_overview(0.9)
