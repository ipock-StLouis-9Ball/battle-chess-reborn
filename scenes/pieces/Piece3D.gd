class_name Piece3D
extends Node3D

## Heroic 3D Chess Piece
## Scaled gladiator character model with 3D raycast picking,
## weapon sockets (Hand_R, Head), combat strikes, and cinematic death reactions.

signal clicked(pos: Vector2i)
signal movement_finished()

@export var piece_type: String = "P" # "P", "N", "B", "R", "Q", "K"
@export var piece_color: String = "white" # "white" or "black"
@export var board_pos: Vector2i = Vector2i.ZERO

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var hand_r_socket: Marker3D = $Hand_R_Socket
@onready var head_socket: Marker3D = $Head_Socket
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var pick_area: Area3D = $PickArea

var current_tween: Tween
var active_theme: PieceTheme
var is_selected: bool = false
var base_scale: Vector3 = Vector3(1.8, 1.8, 1.8)

func _ready() -> void:
	_init_heroic_scale()
	_setup_picking()
	_update_materials()
	set_selected(false)

func _init_heroic_scale() -> void:
	# Differentiated heroic heights per chess tier
	match piece_type.to_upper():
		"P": base_scale = Vector3(1.6, 1.6, 1.6) # Agile vanguard
		"N": base_scale = Vector3(1.9, 1.9, 1.9) # Armored cavalier
		"B": base_scale = Vector3(1.85, 1.85, 1.85) # Arcane inquisitor
		"R": base_scale = Vector3(2.4, 2.4, 2.4) # Colossal siege titan
		"Q": base_scale = Vector3(2.1, 2.1, 2.1) # Towering royal matriarch
		"K": base_scale = Vector3(2.2, 2.2, 2.2) # Resplendent war monarch
	scale = base_scale

func _setup_picking() -> void:
	if is_instance_valid(pick_area):
		pick_area.input_event.connect(_on_input_event)

func setup(type: String, color: String, theme_res: PieceTheme = null) -> void:
	piece_type = type.to_upper()
	piece_color = color.to_lower()
	_init_heroic_scale()
	if theme_res != null:
		apply_theme(theme_res)
	else:
		_update_materials()

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

func _update_materials() -> void:
	if not is_instance_valid(mesh_instance):
		return

	var emissive_col = Color.WHITE
	if active_theme != null:
		emissive_col = active_theme.emissive_color

	var mat = StandardMaterial3D.new()
	if piece_color == "white":
		# Noble burnished silver & ivory
		mat.albedo_color = Color(0.94, 0.96, 1.0, 1.0)
		mat.metallic = 0.35
		mat.roughness = 0.25
		mat.rim_enabled = true
		mat.rim = 0.6
		mat.emission_enabled = true
		mat.emission = emissive_col * 0.3
	else:
		# Imposing dark obsidian & crimson/gold alloy
		mat.albedo_color = Color(0.12, 0.13, 0.18, 1.0)
		mat.metallic = 0.75
		mat.roughness = 0.35
		mat.rim_enabled = true
		mat.rim = 0.5
		mat.emission_enabled = true
		mat.emission = emissive_col * 0.95
		mat.emission_energy_multiplier = 1.4

	mesh_instance.material_override = mat

func set_selected(selected: bool) -> void:
	is_selected = selected
	if is_instance_valid(selection_ring):
		selection_ring.visible = selected
		if selected:
			var tw = create_tween().set_loops()
			tw.tween_property(selection_ring, "scale", Vector3(1.15, 1.15, 1.15), 0.5)
			tw.tween_property(selection_ring, "scale", Vector3(1.0, 1.0, 1.0), 0.5)

## Smooth heroic leap across the 3D battlefield
func animate_move_to(target_pos: Vector3, duration: float = 0.42) -> Signal:
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	# Rotate towards destination vector
	var move_dir = (target_pos - position).normalized()
	if move_dir.length_squared() > 0.01:
		var target_yaw = atan2(move_dir.x, move_dir.z)
		var rot_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rot_tw.tween_property(self, "rotation:y", target_yaw, 0.12)

	current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(self, "position:x", target_pos.x, duration)
	current_tween.tween_property(self, "position:z", target_pos.z, duration)

	# High parabolic heroic jump
	var apex_height = maxf(position.y, target_pos.y) + 1.8
	var hop_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop_tween.tween_property(self, "position:y", apex_height, duration * 0.45)
	hop_tween.set_ease(Tween.EASE_IN)
	hop_tween.tween_property(self, "position:y", target_pos.y, duration * 0.55)

	# Landing impact squash & stretch
	hop_tween.chain().tween_property(self, "scale", base_scale * Vector3(1.2, 0.8, 1.2), 0.08)
	hop_tween.chain().tween_property(self, "scale", base_scale, 0.12)

	hop_tween.finished.connect(func(): movement_finished.emit())
	return movement_finished

## Combat attack lunge towards opposing square
func execute_attack_strike(target_pos: Vector3) -> Signal:
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var original_pos = position
	var strike_dir = (target_pos - position).normalized()
	var lunge_pos = position + strike_dir * 0.9

	tw.tween_property(self, "position", lunge_pos, 0.22)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(1.25, 1.25, 1.25), 0.15)
	tw.chain().tween_property(self, "position", original_pos, 0.2)
	tw.parallel().tween_property(self, "scale", base_scale, 0.2)
	return tw.finished

## Impact reaction when hit
func play_hit_stagger() -> void:
	var tw = create_tween()
	tw.tween_property(mesh_instance, "rotation_degrees:z", -15.0, 0.08)
	tw.tween_property(mesh_instance, "rotation_degrees:z", 10.0, 0.08)
	tw.tween_property(mesh_instance, "rotation_degrees:z", 0.0, 0.1)

## Dramatic death collapse / execution reaction
func play_death_reaction(reaction_type: String = "collapse") -> void:
	var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	match reaction_type:
		"decapitate":
			if head_socket:
				var head_tw = create_tween()
				head_tw.tween_property(head_socket, "position:y", head_socket.position.y + 2.5, 0.3)
				head_tw.tween_property(head_socket, "position:z", head_socket.position.z - 3.0, 0.5)
			tw.tween_property(self, "rotation_degrees:x", 85.0, 0.4)
			tw.parallel().tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.8)
		"disintegrate":
			tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.45)
		_: # collapse
			tw.tween_property(self, "rotation_degrees:z", -85.0, 0.4)
			tw.parallel().tween_property(self, "position:y", position.y - 0.4, 0.4)
			tw.chain().tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3)

func _on_input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(board_pos)
	elif event is InputEventScreenTouch and event.pressed:
		clicked.emit(board_pos)
