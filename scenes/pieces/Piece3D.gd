class_name Piece3D
extends Node3D

## Modular Godot 4 3D Chess Piece
## Supports dynamic theme swapping, bone attachment sockets (Hand_R, Head),
## material coloring (White vs Black), and cinematic duel animations.

signal movement_finished()

@export var piece_type: String = "P" # "P", "N", "B", "R", "Q", "K"
@export var piece_color: String = "white" # "white" or "black"
@export var board_pos: Vector2i = Vector2i.ZERO

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var hand_r_socket: Marker3D = $Hand_R_Socket
@onready var head_socket: Marker3D = $Head_Socket

var current_tween: Tween
var active_theme: PieceTheme

func _ready() -> void:
	_update_materials()

## Initialize piece attributes and apply optional theme
func setup(type: String, color: String, theme_res: PieceTheme = null) -> void:
	piece_type = type.to_upper()
	piece_color = color.to_lower()
	if theme_res != null:
		apply_theme(theme_res)
	else:
		_update_materials()

## Swap mesh and visual styling dynamically based on PieceTheme
func apply_theme(theme_res: PieceTheme) -> void:
	active_theme = theme_res
	if theme_res == null or not is_instance_valid(mesh_instance):
		return

	var thematic_mesh = theme_res.get_piece_mesh(piece_type)
	if thematic_mesh is Mesh:
		mesh_instance.mesh = thematic_mesh
	elif thematic_mesh is PackedScene:
		var inst = thematic_mesh.instantiate()
		var found_mesh: Mesh = null
		if inst is MeshInstance3D and inst.mesh != null:
			found_mesh = inst.mesh
		else:
			for child in inst.get_children():
				if child is MeshInstance3D and child.mesh != null:
					found_mesh = child.mesh
					break
		if found_mesh != null:
			mesh_instance.mesh = found_mesh
		inst.queue_free()

	_update_materials()

## Update white/black piece shading and emissive theme accents
func _update_materials() -> void:
	if not is_instance_valid(mesh_instance):
		return

	var emissive_col = Color.WHITE
	if active_theme != null:
		emissive_col = active_theme.emissive_color

	var mat = StandardMaterial3D.new()
	if piece_color == "white":
		mat.albedo_color = Color(0.92, 0.94, 0.98, 1.0)
		mat.metallic = 0.25
		mat.roughness = 0.3
		mat.rim_enabled = true
		mat.rim = 0.4
		mat.emission_enabled = true
		mat.emission = emissive_col * 0.25
	else:
		mat.albedo_color = Color(0.12, 0.14, 0.18, 1.0)
		mat.metallic = 0.55
		mat.roughness = 0.4
		mat.rim_enabled = true
		mat.rim = 0.3
		mat.emission_enabled = true
		mat.emission = emissive_col * 0.85
		mat.emission_energy_multiplier = 1.2

	mesh_instance.material_override = mat

## Attach a weapon, spell prop, or VFX node to designated socket
func attach_to_socket(socket_name: String, child_node: Node3D) -> void:
	var socket = get_socket(socket_name)
	if socket != null:
		socket.add_child(child_node)

## Retrieve socket marker node by name
func get_socket(socket_name: String) -> Marker3D:
	match socket_name.to_lower():
		"hand_r", "hand_r_socket":
			return hand_r_socket
		"head", "head_socket":
			return head_socket
		_:
			return null

## Detach all attached accessories from a socket
func clear_socket(socket_name: String) -> void:
	var socket = get_socket(socket_name)
	if socket != null:
		for child in socket.get_children():
			child.queue_free()

## Smooth 3D hop-and-glide movement across the chess board
func animate_move_to(target_pos: Vector3, duration: float = 0.35) -> Signal:
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(self, "position:x", target_pos.x, duration)
	current_tween.tween_property(self, "position:z", target_pos.z, duration)

	# Vertical parabolic hop
	var peak_height = position.y + 0.6
	var hop_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop_tween.tween_property(self, "position:y", peak_height, duration * 0.5)
	hop_tween.set_ease(Tween.EASE_IN)
	hop_tween.tween_property(self, "position:y", target_pos.y, duration * 0.5)

	hop_tween.finished.connect(func(): movement_finished.emit())
	return movement_finished

## Cinematic duel death reaction: fall, dissolve, or decapitation
func play_death_reaction(reaction: String = "collapse") -> void:
	var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	match reaction:
		"decapitate":
			if head_socket:
				var head_tw = create_tween()
				head_tw.tween_property(head_socket, "position:y", head_socket.position.y + 1.2, 0.25)
				head_tw.tween_property(head_socket, "position:z", head_socket.position.z - 2.0, 0.4)
			tw.tween_property(self, "rotation_degrees:x", 85.0, 0.4)
		"disintegrate":
			tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
		_: # collapse
			tw.tween_property(self, "rotation_degrees:z", -80.0, 0.35)
			tw.parallel().tween_property(self, "position:y", position.y - 0.2, 0.35)
