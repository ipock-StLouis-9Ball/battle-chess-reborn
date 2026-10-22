class_name Piece3D
extends Node3D

## Heroic 3D Combat Chess Piece
## - Articulated 3D warrior figurines (GLB models with procedural anatomical fallbacks)
## - PBR noble steel/gold (White) and obsidian/iron (Black) with zero blinding emission
## - 3D raycast touch picking colliders and soft halo selection ring
## - Bone/weapon attachment sockets (Hand_R_Socket, Head_Socket)
## - 3-Act choreographed battle animations:
##   * Act 1: Heavy Opening Strike & Defensive Block/Parry
##   * Act 2: Retaliation Counter-Blow & Sidestep Evade/Deflect
##   * Act 3: Signature Finisher Execution & Dramatic Collapse
## - Parabolic leap movement, attack lunges, hit stagger, and execution reactions

signal clicked(pos: Vector2i)
signal movement_finished()

@export var piece_type: String = "P" # "P", "N", "B", "R", "Q", "K"
@export var piece_color: String = "white" # "white" or "black"
@export var board_pos: Vector2i = Vector2i.ZERO

@onready var model_root: Node3D = $ModelRoot if has_node("ModelRoot") else null
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var hand_r_socket: Marker3D = $Hand_R_Socket if has_node("Hand_R_Socket") else null
@onready var head_socket: Marker3D = $Head_Socket if has_node("Head_Socket") else null
@onready var selection_ring: MeshInstance3D = $SelectionRing if has_node("SelectionRing") else null
@onready var pick_area: Area3D = $PickArea if has_node("PickArea") else null

var current_tween: Tween
var active_theme: Resource = null
var is_selected: bool = false
var base_scale: Vector3 = Vector3.ONE
var ring_tween: Tween
var active_model_instance: Node3D = null

func _ready() -> void:
	if model_root == null:
		model_root = Node3D.new()
		model_root.name = "ModelRoot"
		add_child(model_root)

	# Hide or clear legacy primitive mesh if present
	if is_instance_valid(mesh_instance):
		mesh_instance.visible = false
		mesh_instance.mesh = null

	_init_heroic_scale()
	_setup_picking()
	_load_or_build_model()
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

func setup(type: String, color: String, theme_res: Resource = null) -> void:
	piece_type = type.to_upper()
	piece_color = color.to_lower()
	_init_heroic_scale()
	if theme_res != null:
		apply_theme(theme_res)
	else:
		_load_or_build_model()

func apply_theme(theme_res: Resource) -> void:
	active_theme = theme_res
	_load_or_build_model()

## Load the 3D warrior figurine from theme resource, disk GLB, or procedural anatomical fallback
func _load_or_build_model() -> void:
	if model_root == null:
		if has_node("ModelRoot"):
			model_root = get_node("ModelRoot") as Node3D
		else:
			model_root = Node3D.new()
			model_root.name = "ModelRoot"
			add_child(model_root)

	# Clean previous model
	for child in model_root.get_children():
		child.queue_free()
	active_model_instance = null

	var loaded_model: Node3D = null

	# 1. Try loading from active_theme resource
	if active_theme != null and active_theme.has_method("get_piece_mesh"):
		var thematic_res = active_theme.get_piece_mesh(piece_type)
		if thematic_res != null:
			loaded_model = _try_instantiate_model(thematic_res)

	# 2. Try direct GLB file on disk
	if loaded_model == null:
		var theme_folder = "high_fantasy"
		if active_theme != null and "theme_name" in active_theme:
			var tname = str(active_theme.theme_name).to_lower()
			if "cyber" in tname:
				theme_folder = "cyberpunk"
			elif "eldritch" in tname:
				theme_folder = "eldritch"
		loaded_model = _try_load_glb_fallback(theme_folder, piece_type)

	# 3. Procedural multi-part warrior figurine fallback (guarantees zero naked cylinders)
	if loaded_model == null:
		loaded_model = _build_procedural_warrior_figurine(piece_type, piece_color)

	if loaded_model != null:
		model_root.add_child(loaded_model)
		active_model_instance = loaded_model
		_apply_pbr_materials(loaded_model)
		_scale_and_center_model(loaded_model)

## Instantiate from PackedScene or Mesh resource
func _try_instantiate_model(res: Resource) -> Node3D:
	if res is PackedScene:
		var inst = res.instantiate()
		if inst is Node3D:
			return inst
	elif res is Mesh:
		var mi = MeshInstance3D.new()
		mi.mesh = res
		return mi
	return null

## Direct GLB loader fallback via ResourceLoader or runtime GLTF
func _try_load_glb_fallback(theme_folder: String, p_type: String) -> Node3D:
	var piece_name = "pawn"
	match p_type.to_upper():
		"P": piece_name = "pawn"
		"N": piece_name = "knight"
		"B": piece_name = "bishop"
		"R": piece_name = "rook"
		"Q": piece_name = "queen"
		"K": piece_name = "king"

	var glb_path = "res://assets/models/%s/%s.glb" % [theme_folder, piece_name]
	if ResourceLoader.exists(glb_path):
		var res = load(glb_path)
		if res is PackedScene:
			var inst = res.instantiate()
			if inst is Node3D:
				return inst

	# Runtime GLTFDocument fallback
	var doc = GLTFDocument.new()
	var state = GLTFState.new()
	var err = doc.append_from_file(glb_path, state)
	if err == OK:
		var scene = doc.generate_scene(state)
		if scene is Node3D:
			return scene

	return null

## Construct an articulated, multi-part 3D warrior figurine
## Pedestal plinth + armored torso + pauldrons + helmet/crest + signature weapons & shields
func _build_procedural_warrior_figurine(p_type: String, p_color: String) -> Node3D:
	var warrior = Node3D.new()
	warrior.name = "ArticulatedWarrior"

	var target_h = get_target_height()

	# Pedestal Base: Beveled plinth
	var base_inst = MeshInstance3D.new()
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 0.85
	base_mesh.bottom_radius = 0.95
	base_mesh.height = 0.35
	base_mesh.radial_segments = 16
	base_inst.mesh = base_mesh
	base_inst.position = Vector3(0.0, 0.175, 0.0)
	warrior.add_child(base_inst)

	# Armored Greaves / Legs
	var leg_l = MeshInstance3D.new()
	var leg_r = MeshInstance3D.new()
	var leg_mesh = CapsuleMesh.new()
	leg_mesh.radius = 0.22
	leg_mesh.height = 1.1
	leg_l.mesh = leg_mesh
	leg_r.mesh = leg_mesh
	leg_l.position = Vector3(-0.35, 0.85, 0.0)
	leg_r.position = Vector3(0.35, 0.85, 0.0)
	warrior.add_child(leg_l)
	warrior.add_child(leg_r)

	# Armored Torso / Breastplate
	var torso_inst = MeshInstance3D.new()
	var torso_mesh = BoxMesh.new()
	torso_mesh.size = Vector3(1.1, 1.35, 0.75)
	torso_inst.mesh = torso_mesh
	torso_inst.position = Vector3(0.0, 1.95, 0.0)
	warrior.add_child(torso_inst)

	# Shoulder Pauldrons
	var pauldron_l = MeshInstance3D.new()
	var pauldron_r = MeshInstance3D.new()
	var pauldron_mesh = SphereMesh.new()
	pauldron_mesh.radius = 0.38
	pauldron_mesh.height = 0.55
	pauldron_l.mesh = pauldron_mesh
	pauldron_r.mesh = pauldron_mesh
	pauldron_l.position = Vector3(-0.75, 2.45, 0.0)
	pauldron_r.position = Vector3(0.75, 2.45, 0.0)
	warrior.add_child(pauldron_l)
	warrior.add_child(pauldron_r)

	# Helmet / Head
	var head_inst = MeshInstance3D.new()
	var head_mesh: Mesh
	var crest_mesh: Mesh = null

	match p_type.to_upper():
		"K": # Sovereign King Crown
			head_mesh = CylinderMesh.new()
			head_mesh.top_radius = 0.42
			head_mesh.bottom_radius = 0.38
			head_mesh.height = 0.75
		"Q": # Regal Queen Diadem
			head_mesh = CylinderMesh.new()
			head_mesh.top_radius = 0.36
			head_mesh.bottom_radius = 0.34
			head_mesh.height = 0.72
		"B": # Sacred Cleric Mitre
			head_mesh = PrismMesh.new()
			head_mesh.size = Vector3(0.65, 0.85, 0.55)
		"N": # Knight Steed Crest
			head_mesh = BoxMesh.new()
			head_mesh.size = Vector3(0.65, 0.8, 0.95)
		"R": # Fortress Battlements
			head_mesh = BoxMesh.new()
			head_mesh.size = Vector3(0.9, 0.75, 0.9)
		_: # Pawn Infantry Barbute Helm
			head_mesh = SphereMesh.new()
			head_mesh.radius = 0.38
			head_mesh.height = 0.65

	head_inst.mesh = head_mesh
	head_inst.position = Vector3(0.0, 2.95, 0.0)
	warrior.add_child(head_inst)

	# Right Arm & Handheld Weapon
	var weapon_inst = MeshInstance3D.new()
	var weapon_mesh = BoxMesh.new()

	match p_type.to_upper():
		"K": # King Royal Claymore
			weapon_mesh.size = Vector3(0.12, 2.2, 0.35)
			weapon_inst.position = Vector3(0.95, 1.9, 0.4)
			weapon_inst.rotation_degrees = Vector3(15.0, 0.0, -10.0)
		"Q": # Queen Scepter of Command
			weapon_mesh.size = Vector3(0.1, 1.95, 0.1)
			weapon_inst.position = Vector3(0.9, 1.85, 0.35)
		"B": # Bishop Holy Staff / Crosier
			weapon_mesh.size = Vector3(0.1, 2.3, 0.1)
			weapon_inst.position = Vector3(0.85, 2.0, 0.3)
		"N": # Knight Heavy Lance
			weapon_mesh.size = Vector3(0.15, 2.4, 0.15)
			weapon_inst.position = Vector3(0.95, 2.1, 0.6)
			weapon_inst.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
		"R": # Rook Fortress War-Hammer
			weapon_mesh.size = Vector3(0.28, 2.1, 0.65)
			weapon_inst.position = Vector3(1.05, 1.85, 0.3)
		_: # Pawn Gladius Broadsword
			weapon_mesh.size = Vector3(0.1, 1.5, 0.28)
			weapon_inst.position = Vector3(0.85, 1.75, 0.35)

	weapon_inst.mesh = weapon_mesh
	warrior.add_child(weapon_inst)

	# Left Arm: Shield or Off-Hand Relic
	var shield_inst = MeshInstance3D.new()
	var shield_mesh = BoxMesh.new()
	shield_mesh.size = Vector3(0.12, 1.25, 0.75)
	shield_inst.mesh = shield_mesh
	shield_inst.position = Vector3(-0.9, 1.85, 0.25)
	warrior.add_child(shield_inst)

	return warrior

## Apply PBR materials (Noble Steel & Gold for White, Obsidian & Iron for Black)
## Strictly emission_enabled = false on all armor/body meshes to prevent bloom blowout
func _apply_pbr_materials(root: Node) -> void:
	var armor_mat = StandardMaterial3D.new()

	if piece_color == "white":
		# White: Noble polished plate steel & ivory
		armor_mat.albedo_color = Color(0.93, 0.94, 0.97, 1.0)
		armor_mat.metallic = 0.75
		armor_mat.roughness = 0.28
		armor_mat.rim_enabled = true
		armor_mat.rim = 0.35
		armor_mat.rim_tint = 0.2
		armor_mat.emission_enabled = false
	else:
		# Black: Dark obsidian iron & brushed alloy
		armor_mat.albedo_color = Color(0.14, 0.15, 0.18, 1.0)
		armor_mat.metallic = 0.85
		armor_mat.roughness = 0.32
		armor_mat.rim_enabled = true
		armor_mat.rim = 0.45
		armor_mat.rim_tint = 0.35
		armor_mat.emission_enabled = false

	# Apply across all MeshInstance3D nodes in the hierarchy
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D:
			n.material_override = armor_mat
		for c in n.get_children():
			stack.append(c)

## Scale and center the model to meet target chess figurine height
func _scale_and_center_model(model: Node3D) -> void:
	var aabb = _compute_total_aabb(model)
	var raw_h = maxf(0.5, aabb.size.y)
	var target_h = get_target_height()
	var scale_factor = target_h / raw_h

	model.scale = Vector3(scale_factor, scale_factor, scale_factor)
	# Align bottom of model to ground (Y = 0)
	model.position.y = -aabb.position.y * scale_factor

## Recursively compute combined AABB of all mesh instances
func _compute_total_aabb(node: Node) -> AABB:
	var combined_aabb = AABB()
	var has_aabb = false

	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and n.mesh != null:
			var m_aabb = n.mesh.get_aabb()
			if not has_aabb:
				combined_aabb = m_aabb
				has_aabb = true
			else:
				combined_aabb = combined_aabb.merge(m_aabb)
		for c in n.get_children():
			stack.append(c)

	if not has_aabb:
		combined_aabb = AABB(Vector3(-0.5, 0, -0.5), Vector3(1.0, get_target_height(), 1.0))

	return combined_aabb

func _update_materials() -> void:
	if is_instance_valid(model_root):
		_apply_pbr_materials(model_root)

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

## Smoothly face a target world position
func face_target(target_pos: Vector3) -> void:
	var dir = (target_pos - position).normalized()
	if dir.length_squared() > 0.01:
		var target_yaw = atan2(dir.x, dir.z)
		var rot_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		rot_tw.tween_property(self, "rotation:y", target_yaw, 0.18)

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

## Act 1: Attacker delivers heavy opening blow
func play_act1_strike(target_pos: Vector3) -> void:
	face_target(target_pos)
	var dir = (target_pos - position).normalized()
	var start_pos = position
	var strike_pos = position + dir * 1.15

	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Windup (0.0 - 0.35s)
	tw.tween_property(self, "position", start_pos - dir * 0.35, 0.35)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(0.92, 1.12, 0.92), 0.35)
	# Heavy Strike Lunge (0.35 - 0.75s)
	tw.chain().tween_property(self, "position", strike_pos, 0.4)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(1.22, 0.88, 1.22), 0.4)
	# Recoil/Stance Recovery (0.75 - 1.6s)
	tw.chain().tween_property(self, "position", start_pos, 0.85)
	tw.parallel().tween_property(self, "scale", base_scale, 0.85)

## Act 1: Defender parries/blocks with shield or weapon
func play_act1_block(attacker_pos: Vector3) -> void:
	face_target(attacker_pos)
	var dir = (position - attacker_pos).normalized()
	var start_pos = position

	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Brace anticipation (0.0 - 0.4s)
	tw.tween_interval(0.4)
	# Impact recoil (0.4 - 0.65s)
	tw.chain().tween_property(self, "position", start_pos + dir * 0.45, 0.18)
	tw.parallel().tween_property(self, "rotation_degrees:x", -14.0, 0.18)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(1.15, 0.9, 1.15), 0.18)
	# Recover to combat stance
	tw.chain().tween_property(self, "position", start_pos, 0.7)
	tw.parallel().tween_property(self, "rotation_degrees:x", 0.0, 0.7)
	tw.parallel().tween_property(self, "scale", base_scale, 0.7)

## Act 2: Defender retaliates with a counter-attack
func play_act2_counter(target_pos: Vector3) -> void:
	face_target(target_pos)
	var dir = (target_pos - position).normalized()
	var start_pos = position
	var counter_pos = position + dir * 1.25

	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Fast counter-strike lunge
	tw.tween_property(self, "position", counter_pos, 0.4)
	tw.parallel().tween_property(self, "rotation_degrees:z", 22.0, 0.4)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(1.15, 1.15, 1.15), 0.4)
	# Reset
	tw.chain().tween_property(self, "position", start_pos, 0.65)
	tw.parallel().tween_property(self, "rotation_degrees:z", 0.0, 0.65)
	tw.parallel().tween_property(self, "scale", base_scale, 0.65)

## Act 2: Attacker sidesteps, ducks, or deflects the strike
func play_act2_dodge() -> void:
	var start_pos = position
	var side_dir = transform.basis.x.normalized()

	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.2)
	# Evade: sidestep and duck
	tw.chain().tween_property(self, "position", start_pos + side_dir * 0.9 - Vector3(0, 0.35, 0), 0.3)
	tw.parallel().tween_property(self, "rotation_degrees:z", -15.0, 0.3)
	# Recover into stance
	tw.chain().tween_property(self, "position", start_pos, 0.55)
	tw.parallel().tween_property(self, "rotation_degrees:z", 0.0, 0.55)

## Act 3: Attacker executes signature theme kill shot
func play_act3_finisher(target_pos: Vector3, _atk_type: String, _theme_id: String) -> void:
	face_target(target_pos)
	var dir = (target_pos - position).normalized()
	var start_pos = position
	var impact_pos = target_pos - dir * 0.3

	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	# Windup leap into air (0.0 - 0.75s)
	tw.tween_property(self, "position", start_pos + Vector3(0, 2.4, 0) - dir * 0.6, 0.75)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(1.3, 1.3, 1.3), 0.75)
	# Devastating Execution Plunge (0.75 - 0.95s)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tw.chain().tween_property(self, "position", impact_pos, 0.2)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(1.4, 0.7, 1.4), 0.15)
	# Settle scale
	tw.chain().tween_property(self, "scale", base_scale, 0.35)

## Impact reaction when hit
func play_hit_stagger() -> void:
	var target_node: Node3D = model_root if is_instance_valid(model_root) else self
	var tw = create_tween()
	tw.tween_property(target_node, "rotation_degrees:z", -18.0, 0.08)
	tw.tween_property(target_node, "rotation_degrees:z", 12.0, 0.08)
	tw.tween_property(target_node, "rotation_degrees:z", 0.0, 0.1)

## Dramatic death collapse / execution reaction
func play_death_reaction(reaction_type: String = "collapse") -> void:
	if ring_tween and ring_tween.is_valid():
		ring_tween.kill()
	if selection_ring:
		selection_ring.visible = false

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
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(self, "scale", Vector3(1.6, 0.01, 1.6), 0.35)
			tw.chain().tween_property(self, "scale", Vector3(0.001, 0.001, 0.001), 0.35)
		_: # collapse
			tw.tween_property(self, "rotation_degrees:z", -85.0, 0.45)
			tw.parallel().tween_property(self, "position:y", position.y - 0.4, 0.45)
			tw.chain().tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.45)

func _on_input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		clicked.emit(board_pos)
