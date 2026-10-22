class_name Piece3D
extends Node3D

## Heroic 3D Chess Piece (1988 Battle Chess Style)
## - Scaled gladiator character standing ~1.8x to 2.2x tile width (4.5m - 5.5m tall)
## - 3D raycast touch picking colliders and emissive glowing selection ring
## - Bone attachment sockets (Hand_R_Socket, Head_Socket)
## - Parabolic leap movement, attack lunges, hit stagger, and dramatic execution reactions

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
var base_scale: Vector3 = Vector3.ONE
var ring_tween: Tween

func _ready() -> void:
	_init_heroic_scale()
	_setup_picking()
	_update_materials()
	set_selected(false)

func get_target_height() -> float:
	match piece_type.to_upper():
		"P": return 4.50 # 1.80x tile width (2.5)
		"N": return 4.75 # 1.90x tile width
		"B": return 4.875 # 1.95x tile width
		"R": return 5.125 # 2.05x tile width
		"Q": return 5.375 # 2.15x tile width
		"K": return 5.50 # 2.20x tile width
		_: return 4.50

func _init_heroic_scale() -> void:
	base_scale = Vector3.ONE
	scale = base_scale

func _setup_picking() -> void:
	if is_instance_valid(pick_area):
		if not pick_area.input_event.is_connected(_on_input_event):
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
		_scale_thematic_mesh()
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
			_scale_thematic_mesh()
		inst.queue_free()

	_update_materials()

func _scale_thematic_mesh() -> void:
	if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
		return
	var aabb = mesh_instance.mesh.get_aabb()
	var mesh_h = maxf(0.5, aabb.size.y)
	var desired_h = get_target_height()
	var factor = desired_h / mesh_h
	mesh_instance.scale = Vector3(factor, factor, factor)
	# Align bottom of mesh to Y = 0
	mesh_instance.position.y = -aabb.position.y * factor

func _update_materials() -> void:
	if not is_instance_valid(mesh_instance):
		return

	var emissive_col = Color.WHITE
	if active_theme != null:
		emissive_col = active_theme.emissive_color

	var mat = StandardMaterial3D.new()
	if piece_color == "white":
		# Noble burnished silver & polished ivory
		mat.albedo_color = Color(0.95, 0.96, 1.0, 1.0)
		mat.metallic = 0.3
		mat.roughness = 0.25
		mat.rim_enabled = true
		mat.rim = 0.65
		mat.emission_enabled = true
		mat.emission = emissive_col * 0.35
	else:
		# Imposing dark obsidian & crimson/gold alloy
		mat.albedo_color = Color(0.12, 0.13, 0.18, 1.0)
		mat.metallic = 0.75
		mat.roughness = 0.35
		mat.rim_enabled = true
		mat.rim = 0.55
		mat.emission_enabled = true
		mat.emission = emissive_col * 0.95
		mat.emission_energy_multiplier = 1.5

	mesh_instance.material_override = mat

func set_selected(selected: bool) -> void:
	is_selected = selected
	if is_instance_valid(selection_ring):
		selection_ring.visible = selected
		if ring_tween and ring_tween.is_valid():
			ring_tween.kill()

		if selected:
			ring_tween = create_tween().set_loops()
			ring_tween.tween_property(selection_ring, "scale", Vector3(1.12, 1.0, 1.12), 0.45).set_trans(Tween.TRANS_SINE)
			ring_tween.tween_property(selection_ring, "scale", Vector3(0.95, 1.0, 0.95), 0.45).set_trans(Tween.TRANS_SINE)
		else:
			selection_ring.scale = Vector3.ONE

## Smooth heroic leap across the 3D battlefield
func animate_move_to(target_pos: Vector3, duration: float = 0.45) -> Signal:
	if current_tween and current_tween.is_valid():
		current_tween.kill()

	# Rotate towards destination vector
	var move_dir = (target_pos - position).normalized()
	if move_dir.length_squared() > 0.01:
		var target_yaw = atan2(move_dir.x, move_dir.z)
		var rot_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rot_tw.tween_property(self, "rotation:y", target_yaw, 0.14)

	current_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	current_tween.tween_property(self, "position:x", target_pos.x, duration)
	current_tween.tween_property(self, "position:z", target_pos.z, duration)

	# High parabolic heroic jump
	var apex_height = maxf(position.y, target_pos.y) + 2.4
	var hop_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop_tween.tween_property(self, "position:y", apex_height, duration * 0.45)
	hop_tween.set_ease(Tween.EASE_IN)
	hop_tween.tween_property(self, "position:y", target_pos.y, duration * 0.55)

	# Landing impact squash & stretch
	hop_tween.chain().tween_property(self, "scale", base_scale * Vector3(1.2, 0.8, 1.2), 0.08)
	hop_tween.chain().tween_property(self, "scale", base_scale, 0.12)

	hop_tween.finished.connect(func(): movement_finished.emit(), CONNECT_ONE_SHOT)
	return movement_finished

## Combat attack lunge towards opposing square
func execute_attack_strike(target_pos: Vector3) -> Signal:
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var original_pos = position
	var strike_dir = (target_pos - position).normalized()
	var lunge_pos = position + strike_dir * 1.5

	# Turn to face victim
	if strike_dir.length_squared() > 0.01:
		rotation.y = atan2(strike_dir.x, strike_dir.z)

	tw.tween_property(self, "position", lunge_pos, 0.22)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(1.18, 1.18, 1.18), 0.18)
	tw.chain().tween_property(self, "position", original_pos, 0.2)
	tw.parallel().tween_property(self, "scale", base_scale, 0.2)
	return tw.finished

## Impact reaction when hit
func play_hit_stagger() -> void:
	var tw = create_tween()
	tw.tween_property(mesh_instance, "rotation_degrees:z", -18.0, 0.08)
	tw.tween_property(mesh_instance, "rotation_degrees:z", 12.0, 0.08)
	tw.tween_property(mesh_instance, "rotation_degrees:z", 0.0, 0.1)

## Dramatic death collapse / execution reaction
func play_death_reaction(reaction_type: String = "collapse") -> void:
	var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	match reaction_type:
		"decapitate":
			if head_socket:
				var head_tw = create_tween()
				head_tw.tween_property(head_socket, "position:y", head_socket.position.y + 3.0, 0.3)
				head_tw.tween_property(head_socket, "position:z", head_socket.position.z - 3.5, 0.5)
			tw.tween_property(self, "rotation_degrees:x", 85.0, 0.4)
			tw.parallel().tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.75)
		"disintegrate":
			tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.45)
		_: # collapse
			tw.tween_property(self, "rotation_degrees:z", -85.0, 0.45)
			tw.parallel().tween_property(self, "position:y", position.y - 0.4, 0.45)
			tw.chain().tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.35)

func _on_input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or \
	   (event is InputEventScreenTouch and event.pressed):
		clicked.emit(board_pos)
