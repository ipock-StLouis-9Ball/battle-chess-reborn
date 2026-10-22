class_name DuelCamera
extends Camera2D

## Dynamic Action Camera for Duel Arena
## Frames both combatants, zooms smoothly, and shakes on heavy impacts

@export var target_a: Node2D
@export var target_b: Node2D

@export var min_zoom: float = 0.8
@export var max_zoom: float = 1.35
@export var zoom_margin: float = 280.0

var shake_intensity: float = 0.0
var shake_duration: float = 0.0

func _ready() -> void:
	EventBus.screen_shake_requested.connect(trigger_shake)

func setup_targets(fighter_a: Node2D, fighter_b: Node2D) -> void:
	target_a = fighter_a
	target_b = fighter_b

func _process(delta: float) -> void:
	if not is_instance_valid(target_a) or not is_instance_valid(target_b):
		return

	# Midpoint position tracking
	var mid = (target_a.global_position + target_b.global_position) * 0.5
	global_position = global_position.lerp(mid, 10.0 * delta)

	# Dynamic zoom based on separation distance
	var dist = target_a.global_position.distance_to(target_b.global_position)
	var desired_zoom = clampf(800.0 / (dist + zoom_margin), min_zoom, max_zoom)
	zoom = zoom.lerp(Vector2(desired_zoom, desired_zoom), 5.0 * delta)

	# Screen Shake
	if shake_duration > 0.0 and SettingsManager.screen_shake:
		shake_duration -= delta
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_intensity
		shake_intensity = lerpf(shake_intensity, 0.0, 8.0 * delta)
	else:
		offset = Vector2.ZERO

func trigger_shake(intensity: float, duration: float) -> void:
	shake_intensity = intensity
	shake_duration = duration
