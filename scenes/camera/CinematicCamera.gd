class_name CinematicCamera
extends Camera2D

## Dynamic Duel & Chess Board Camera
## Responds to DuelDirector framing requests with dynamic zoom, tracking, and letterboxing

var target_position: Vector2 = Vector2(960, 540)
var target_zoom: float = 1.0

func _ready() -> void:
	if has_node("/root/DuelDirector"):
		get_node("/root/DuelDirector").camera_framing_requested.connect(_on_framing_requested)

func _process(delta: float) -> void:
	global_position = global_position.lerp(target_position, 8.0 * delta)
	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), 6.0 * delta)

func _on_framing_requested(_angle: String, zoom_level: float, target_pos: Vector2) -> void:
	target_position = target_pos if zoom_level > 1.0 else Vector2(960, 540)
	target_zoom = zoom_level
