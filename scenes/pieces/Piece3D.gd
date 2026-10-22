class_name Piece3D
extends Node3D

## Heroic 3D Combat Chess Piece
## - Detailed multi-part articulated 3D character hierarchies for every piece type:
##   * Pawn (Infantry): Armored torso, helmeted head, shield in left hand, spear/shortsword in right hand.
##   * Rook (Castle Golem): Broad hulking torso, battlement shoulder pauldrons, glowing eyes, heavy warhammer/fists.
##   * Knight (Armored Cavalier): Plumed visored knight helmet, breastplate, cape, broadsword, and cavalry shield.
##   * Bishop (High Cleric): Mitre/hooded head, flowing robes, shoulder trim, and an ornate crosier staff.
##   * Queen (Royal Sorceress): Slender armored gown, high gold crown, cape, and arcane scepter.
##   * King (War Monarch): Broad royal mantle, ornate gold crown, bearded head, and two-handed royal greatsword.
## - Classic 1988 Battle Chess Faction Colors:
##   * Player 1 (Bottom): Royal Sapphire Blue & Polished Silver Steel armor with gold trim.
##   * Player 2 (Top): Crimson Ruby Red & Dark Bronze/Obsidian armor with gold trim.
##   * Zero blinding emission, realistic PBR metallic/roughness shading and crisp shadows.
## - Scaled proportionally: 1.8m to 2.6m tall on the 2.5m squares for clean visibility without row overlap.

signal clicked(pos: Vector2i)
signal movement_finished()

@export var piece_type: String = "P" # "P", "N", "B", "R", "Q", "K"
@export var piece_color: String = "white" # "white" (Player 1) or "black" (Player 2)
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

	# Ensure legacy primitive mesh is cleared
	if is_instance_valid(mesh_instance):
		mesh_instance.visible = false
		mesh_instance.mesh = null

	_init_heroic_scale()
	_setup_picking()
	_load_or_build_model()
	set_selected(false)

## Scale pieces proportionally: 1.8m to 2.6m tall on 2.5m squares
func get_target_height() -> float:
	match piece_type.to_upper():
		"P": return 1.80 # 1.80m tall (Infantry Pawn)
		"N": return 2.05 # 2.05m tall (Armored Cavalier Knight)
		"B": return 2.15 # 2.15m tall (High Cleric Bishop)
		"R": return 2.25 # 2.25m tall (Castle Golem Rook)
		"Q": return 2.45 # 2.45m tall (Royal Sorceress Queen)
		"K": return 2.60 # 2.60m tall (War Monarch King)
		_: return 1.80

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

## Palette material generator for classic 1988 Battle Chess
func _create_pbr_palette() -> Dictionary:
	var is_white = (piece_color == "white")
	var palette = {}

	# 1. Primary Armor: Polished Silver Steel vs Dark Bronze/Obsidian
	var mat_armor = StandardMaterial3D.new()
	if is_white:
		mat_armor.albedo_color = Color(0.88, 0.90, 0.94, 1.0)
		mat_armor.metallic = 0.82
		mat_armor.roughness = 0.22
	else:
		mat_armor.albedo_color = Color(0.18, 0.16, 0.16, 1.0)
		mat_armor.metallic = 0.78
		mat_armor.roughness = 0.32
	mat_armor.emission_enabled = false
	palette["armor"] = mat_armor

	# 2. Faction Fabric: Royal Sapphire Blue vs Crimson Ruby Red
	var mat_faction = StandardMaterial3D.new()
	if is_white:
		mat_faction.albedo_color = Color(0.12, 0.28, 0.78, 1.0)
		mat_faction.metallic = 0.15
		mat_faction.roughness = 0.55
	else:
		mat_faction.albedo_color = Color(0.75, 0.10, 0.14, 1.0)
		mat_faction.metallic = 0.15
		mat_faction.roughness = 0.55
	mat_faction.emission_enabled = false
	palette["faction"] = mat_faction

	# 3. Gold Trim: Imperial Gold vs Antique Gold
	var mat_trim = StandardMaterial3D.new()
	if is_white:
		mat_trim.albedo_color = Color(0.95, 0.80, 0.22, 1.0)
		mat_trim.metallic = 0.90
		mat_trim.roughness = 0.20
	else:
		mat_trim.albedo_color = Color(0.85, 0.68, 0.20, 1.0)
		mat_trim.metallic = 0.85
		mat_trim.roughness = 0.25
	mat_trim.emission_enabled = false
	palette["trim"] = mat_trim

	# 4. Soft Eye Glow (Non-blinding tiny accent)
	var mat_eyes = StandardMaterial3D.new()
	if is_white:
		mat_eyes.albedo_color = Color(0.4, 0.8, 1.0, 1.0)
		mat_eyes.emission_enabled = true
		mat_eyes.emission = Color(0.4, 0.8, 1.0)
	else:
		mat_eyes.albedo_color = Color(1.0, 0.25, 0.25, 1.0)
		mat_eyes.emission_enabled = true
		mat_eyes.emission = Color(1.0, 0.25, 0.25)
	mat_eyes.emission_energy_multiplier = 0.4
	palette["eyes"] = mat_eyes

	return palette

## Construct an articulated, multi-part 3D character hierarchy
func _build_procedural_warrior_figurine(p_type: String, _p_color: String) -> Node3D:
	var warrior = Node3D.new()
	warrior.name = "ArticulatedWarrior"

	var pal = _create_pbr_palette()
	var mat_arm = pal["armor"]
	var mat_fac = pal["faction"]
	var mat_trm = pal["trim"]
	var mat_eye = pal["eyes"]

	# Pedestal Base: Beveled plinth with trim ring
	var base_inst = MeshInstance3D.new()
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 0.62
	base_mesh.bottom_radius = 0.68
	base_mesh.height = 0.16
	base_mesh.radial_segments = 16
	base_inst.mesh = base_mesh
	base_inst.material_override = mat_arm
	base_inst.position = Vector3(0.0, 0.08, 0.0)
	warrior.add_child(base_inst)

	var ring_inst = MeshInstance3D.new()
	var ring_mesh = CylinderMesh.new()
	ring_mesh.top_radius = 0.63
	ring_mesh.bottom_radius = 0.63
	ring_mesh.height = 0.04
	ring_mesh.radial_segments = 16
	ring_inst.mesh = ring_mesh
	ring_inst.material_override = mat_trm
	ring_inst.position = Vector3(0.0, 0.16, 0.0)
	warrior.add_child(ring_inst)

	match p_type.to_upper():
		"P": # Pawn (Infantry): Armored torso, helmeted head, shield in left hand, spear/shortsword in right hand
			# Greaves / Legs
			var leg_l = MeshInstance3D.new()
			var leg_r = MeshInstance3D.new()
			var leg_mesh = CapsuleMesh.new()
			leg_mesh.radius = 0.10
			leg_mesh.height = 0.55
			leg_l.mesh = leg_mesh
			leg_r.mesh = leg_mesh
			leg_l.material_override = mat_arm
			leg_r.material_override = mat_arm
			leg_l.position = Vector3(-0.16, 0.44, 0.0)
			leg_r.position = Vector3(0.16, 0.44, 0.0)
			warrior.add_child(leg_l)
			warrior.add_child(leg_r)

			# Armored Torso & Tabard
			var torso_inst = MeshInstance3D.new()
			var torso_mesh = BoxMesh.new()
			torso_mesh.size = Vector3(0.48, 0.52, 0.32)
			torso_inst.mesh = torso_mesh
			torso_inst.material_override = mat_arm
			torso_inst.position = Vector3(0.0, 0.95, 0.0)
			warrior.add_child(torso_inst)

			var tabard_inst = MeshInstance3D.new()
			var tabard_mesh = BoxMesh.new()
			tabard_mesh.size = Vector3(0.26, 0.48, 0.34)
			tabard_inst.mesh = tabard_mesh
			tabard_inst.material_override = mat_fac
			tabard_inst.position = Vector3(0.0, 0.95, 0.0)
			warrior.add_child(tabard_inst)

			# Pauldrons
			var pauld_l = MeshInstance3D.new()
			var pauld_r = MeshInstance3D.new()
			var p_mesh = BoxMesh.new()
			p_mesh.size = Vector3(0.18, 0.12, 0.24)
			pauld_l.mesh = p_mesh
			pauld_r.mesh = p_mesh
			pauld_l.material_override = mat_trm
			pauld_r.material_override = mat_trm
			pauld_l.position = Vector3(-0.32, 1.15, 0.0)
			pauld_r.position = Vector3(0.32, 1.15, 0.0)
			warrior.add_child(pauld_l)
			warrior.add_child(pauld_r)

			# Helmeted Head with Visor
			var head_inst = MeshInstance3D.new()
			var head_mesh = CylinderMesh.new()
			head_mesh.top_radius = 0.18
			head_mesh.bottom_radius = 0.17
			head_mesh.height = 0.28
			head_inst.mesh = head_mesh
			head_inst.material_override = mat_arm
			head_inst.position = Vector3(0.0, 1.38, 0.0)
			warrior.add_child(head_inst)

			var visor_inst = MeshInstance3D.new()
			var visor_mesh = BoxMesh.new()
			visor_mesh.size = Vector3(0.20, 0.04, 0.05)
			visor_inst.mesh = visor_mesh
			visor_inst.material_override = mat_trm
			visor_inst.position = Vector3(0.0, 1.38, 0.16)
			warrior.add_child(visor_inst)

			# Right Arm & Spear/Shortsword
			var arm_r = MeshInstance3D.new()
			var arm_mesh = CapsuleMesh.new()
			arm_mesh.radius = 0.08
			arm_mesh.height = 0.45
			arm_r.mesh = arm_mesh
			arm_r.material_override = mat_arm
			arm_r.position = Vector3(0.32, 0.88, 0.10)
			warrior.add_child(arm_r)

			var spear_inst = MeshInstance3D.new()
			var spear_shaft = CylinderMesh.new()
			spear_shaft.top_radius = 0.02
			spear_shaft.bottom_radius = 0.02
			spear_shaft.height = 1.30
			spear_inst.mesh = spear_shaft
			spear_inst.material_override = mat_trm
			spear_inst.position = Vector3(0.36, 1.10, 0.20)
			warrior.add_child(spear_inst)

			var tip_inst = MeshInstance3D.new()
			var tip_mesh = ConeMesh.new()
			tip_mesh.top_radius = 0.0
			tip_mesh.bottom_radius = 0.06
			tip_mesh.height = 0.22
			tip_inst.mesh = tip_mesh
			tip_inst.material_override = mat_arm
			tip_inst.position = Vector3(0.36, 1.80, 0.20)
			warrior.add_child(tip_inst)

			# Left Arm & Heater Shield
			var arm_l = MeshInstance3D.new()
			arm_l.mesh = arm_mesh
			arm_l.material_override = mat_arm
			arm_l.position = Vector3(-0.32, 0.88, 0.10)
			warrior.add_child(arm_l)

			var shield_inst = MeshInstance3D.new()
			var shield_mesh = BoxMesh.new()
			shield_mesh.size = Vector3(0.06, 0.58, 0.36)
			shield_inst.mesh = shield_mesh
			shield_inst.material_override = mat_fac
			shield_inst.position = Vector3(-0.40, 0.90, 0.18)
			shield_inst.rotation_degrees = Vector3(0.0, 15.0, 0.0)
			warrior.add_child(shield_inst)

			var shield_trim = MeshInstance3D.new()
			var st_mesh = BoxMesh.new()
			st_mesh.size = Vector3(0.04, 0.44, 0.08)
			shield_trim.mesh = st_mesh
			shield_trim.material_override = mat_trm
			shield_trim.position = Vector3(-0.43, 0.90, 0.18)
			shield_trim.rotation_degrees = Vector3(0.0, 15.0, 0.0)
			warrior.add_child(shield_trim)

		"R": # Rook (Castle Golem): Broad hulking torso, battlement shoulder pauldrons, glowing eyes, heavy warhammer/fists
			# Hulking Pillar Legs
			var leg_l = MeshInstance3D.new()
			var leg_r = MeshInstance3D.new()
			var leg_box = BoxMesh.new()
			leg_box.size = Vector3(0.28, 0.60, 0.30)
			leg_l.mesh = leg_box
			leg_r.mesh = leg_box
			leg_l.material_override = mat_arm
			leg_r.material_override = mat_arm
			leg_l.position = Vector3(-0.25, 0.46, 0.0)
			leg_r.position = Vector3(0.25, 0.46, 0.0)
			warrior.add_child(leg_l)
			warrior.add_child(leg_r)

			# Broad Hulking Torso
			var chest_inst = MeshInstance3D.new()
			var chest_mesh = BoxMesh.new()
			chest_mesh.size = Vector3(0.85, 0.70, 0.55)
			chest_inst.mesh = chest_mesh
			chest_inst.material_override = mat_arm
			chest_inst.position = Vector3(0.0, 1.05, 0.0)
			warrior.add_child(chest_inst)

			var crest_inst = MeshInstance3D.new()
			var crest_mesh = BoxMesh.new()
			crest_mesh.size = Vector3(0.40, 0.45, 0.58)
			crest_inst.mesh = crest_mesh
			crest_inst.material_override = mat_fac
			crest_inst.position = Vector3(0.0, 1.05, 0.0)
			warrior.add_child(crest_inst)

			# Battlement Shoulder Pauldrons (Crenellated Fortress Blocks)
			var pauld_l = MeshInstance3D.new()
			var pauld_r = MeshInstance3D.new()
			var pb_mesh = BoxMesh.new()
			pb_mesh.size = Vector3(0.35, 0.35, 0.45)
			pauld_l.mesh = pb_mesh
			pauld_r.mesh = pb_mesh
			pauld_l.material_override = mat_arm
			pauld_r.material_override = mat_arm
			pauld_l.position = Vector3(-0.55, 1.35, 0.0)
			pauld_r.position = Vector3(0.55, 1.35, 0.0)
			warrior.add_child(pauld_l)
			warrior.add_child(pauld_r)

			# Crenellations
			for px in [-0.55, 0.55]:
				for pz in [-0.14, 0.14]:
					var cren = MeshInstance3D.new()
					var cren_mesh = BoxMesh.new()
					cren_mesh.size = Vector3(0.12, 0.12, 0.12)
					cren.mesh = cren_mesh
					cren.material_override = mat_trm
					cren.position = Vector3(px, 1.58, pz)
					warrior.add_child(cren)

			# Deep-Set Head & Glowing Eyes
			var head_inst = MeshInstance3D.new()
			var head_mesh = BoxMesh.new()
			head_mesh.size = Vector3(0.32, 0.28, 0.32)
			head_inst.mesh = head_mesh
			head_inst.material_override = mat_arm
			head_inst.position = Vector3(0.0, 1.32, 0.08)
			warrior.add_child(head_inst)

			var eyes_inst = MeshInstance3D.new()
			var eyes_mesh = BoxMesh.new()
			eyes_mesh.size = Vector3(0.22, 0.05, 0.05)
			eyes_inst.mesh = eyes_mesh
			eyes_inst.material_override = mat_eye
			eyes_inst.position = Vector3(0.0, 1.34, 0.25)
			warrior.add_child(eyes_inst)

			# Heavy Warhammer
			var hammer_head = MeshInstance3D.new()
			var hh_mesh = BoxMesh.new()
			hh_mesh.size = Vector3(0.28, 0.34, 0.32)
			hammer_head.mesh = hh_mesh
			hammer_head.material_override = mat_arm
			hammer_head.position = Vector3(0.50, 1.45, 0.35)
			warrior.add_child(hammer_head)

			var hammer_shaft = MeshInstance3D.new()
			var hs_mesh = CylinderMesh.new()
			hs_mesh.top_radius = 0.035
			hs_mesh.bottom_radius = 0.035
			hs_mesh.height = 1.30
			hammer_shaft.mesh = hs_mesh
			hammer_shaft.material_override = mat_trm
			hammer_shaft.position = Vector3(0.48, 0.95, 0.30)
			hammer_shaft.rotation_degrees = Vector3(15.0, 0.0, -10.0)
			warrior.add_child(hammer_shaft)

		"N": # Knight (Armored Cavalier): Plumed visored helmet, breastplate, cape, broadsword, and cavalry shield
			# Armored Legs
			var leg_l = MeshInstance3D.new()
			var leg_r = MeshInstance3D.new()
			var leg_mesh = CapsuleMesh.new()
			leg_mesh.radius = 0.11
			leg_mesh.height = 0.62
			leg_l.mesh = leg_mesh
			leg_r.mesh = leg_mesh
			leg_l.material_override = mat_arm
			leg_r.material_override = mat_arm
			leg_l.position = Vector3(-0.17, 0.48, 0.0)
			leg_r.position = Vector3(0.17, 0.48, 0.0)
			warrior.add_child(leg_l)
			warrior.add_child(leg_r)

			# Steel Breastplate
			var torso_inst = MeshInstance3D.new()
			var torso_mesh = BoxMesh.new()
			torso_mesh.size = Vector3(0.52, 0.58, 0.36)
			torso_inst.mesh = torso_mesh
			torso_inst.material_override = mat_arm
			torso_inst.position = Vector3(0.0, 1.05, 0.0)
			warrior.add_child(torso_inst)

			# Flowing Cavalry Cape
			var cape_inst = MeshInstance3D.new()
			var cape_mesh = BoxMesh.new()
			cape_mesh.size = Vector3(0.56, 0.85, 0.06)
			cape_inst.mesh = cape_mesh
			cape_inst.material_override = mat_fac
			cape_inst.position = Vector3(0.0, 0.88, -0.21)
			cape_inst.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
			warrior.add_child(cape_inst)

			# Pauldrons
			var pauld_l = MeshInstance3D.new()
			var pauld_r = MeshInstance3D.new()
			var p_mesh = BoxMesh.new()
			p_mesh.size = Vector3(0.20, 0.14, 0.28)
			pauld_l.mesh = p_mesh
			pauld_r.mesh = p_mesh
			pauld_l.material_override = mat_trm
			pauld_r.material_override = mat_trm
			pauld_l.position = Vector3(-0.35, 1.28, 0.0)
			pauld_r.position = Vector3(0.35, 1.28, 0.0)
			warrior.add_child(pauld_l)
			warrior.add_child(pauld_r)

			# Plumed Visored Knight Helmet
			var head_inst = MeshInstance3D.new()
			var head_mesh = CylinderMesh.new()
			head_mesh.top_radius = 0.20
			head_mesh.bottom_radius = 0.19
			head_mesh.height = 0.32
			head_inst.mesh = head_mesh
			head_inst.material_override = mat_arm
			head_inst.position = Vector3(0.0, 1.52, 0.0)
			warrior.add_child(head_inst)

			var visor_inst = MeshInstance3D.new()
			var visor_mesh = BoxMesh.new()
			visor_mesh.size = Vector3(0.24, 0.05, 0.05)
			visor_inst.mesh = visor_mesh
			visor_inst.material_override = mat_trm
			visor_inst.position = Vector3(0.0, 1.52, 0.18)
			warrior.add_child(visor_inst)

			# Plume Crest curving backwards
			var plume_inst = MeshInstance3D.new()
			var plume_mesh = BoxMesh.new()
			plume_mesh.size = Vector3(0.08, 0.24, 0.38)
			plume_inst.mesh = plume_mesh
			plume_inst.material_override = mat_fac
			plume_inst.position = Vector3(0.0, 1.76, -0.08)
			plume_inst.rotation_degrees = Vector3(18.0, 0.0, 0.0)
			warrior.add_child(plume_inst)

			# Right Arm & Broadsword
			var arm_r = MeshInstance3D.new()
			var arm_mesh = CapsuleMesh.new()
			arm_mesh.radius = 0.09
			arm_mesh.height = 0.50
			arm_r.mesh = arm_mesh
			arm_r.material_override = mat_arm
			arm_r.position = Vector3(0.36, 0.98, 0.10)
			warrior.add_child(arm_r)

			var sword_inst = MeshInstance3D.new()
			var sword_mesh = BoxMesh.new()
			sword_mesh.size = Vector3(0.06, 0.95, 0.16)
			sword_inst.mesh = sword_mesh
			sword_inst.material_override = mat_arm
			sword_inst.position = Vector3(0.42, 1.25, 0.25)
			sword_inst.rotation_degrees = Vector3(15.0, 0.0, 0.0)
			warrior.add_child(sword_inst)

			var hilt_inst = MeshInstance3D.new()
			var hilt_mesh = BoxMesh.new()
			hilt_mesh.size = Vector3(0.18, 0.04, 0.06)
			hilt_inst.mesh = hilt_mesh
			hilt_inst.material_override = mat_trm
			hilt_inst.position = Vector3(0.42, 0.82, 0.15)
			warrior.add_child(hilt_inst)

			# Left Arm & Cavalry Kite Shield
			var arm_l = MeshInstance3D.new()
			arm_l.mesh = arm_mesh
			arm_l.material_override = mat_arm
			arm_l.position = Vector3(-0.36, 0.98, 0.10)
			warrior.add_child(arm_l)

			var shield_inst = MeshInstance3D.new()
			var shield_mesh = BoxMesh.new()
			shield_mesh.size = Vector3(0.07, 0.68, 0.42)
			shield_inst.mesh = shield_mesh
			shield_inst.material_override = mat_fac
			shield_inst.position = Vector3(-0.45, 1.02, 0.20)
			shield_inst.rotation_degrees = Vector3(0.0, 20.0, 0.0)
			warrior.add_child(shield_inst)

			var shield_rim = MeshInstance3D.new()
			var sr_mesh = BoxMesh.new()
			sr_mesh.size = Vector3(0.05, 0.52, 0.10)
			shield_rim.mesh = sr_mesh
			shield_rim.material_override = mat_trm
			shield_rim.position = Vector3(-0.49, 1.02, 0.20)
			shield_rim.rotation_degrees = Vector3(0.0, 20.0, 0.0)
			warrior.add_child(shield_rim)

		"B": # Bishop (High Cleric / Sorcerer): Mitre head, flowing robes, shoulder trim, ornate crosier staff
			# Cascading Tiered Robes
			var robe_bot = MeshInstance3D.new()
			var rb_mesh = CylinderMesh.new()
			rb_mesh.top_radius = 0.36
			rb_mesh.bottom_radius = 0.54
			rb_mesh.height = 0.65
			rb_mesh.radial_segments = 16
			robe_bot.mesh = rb_mesh
			robe_bot.material_override = mat_fac
			robe_bot.position = Vector3(0.0, 0.48, 0.0)
			warrior.add_child(robe_bot)

			var robe_top = MeshInstance3D.new()
			var rt_mesh = CylinderMesh.new()
			rt_mesh.top_radius = 0.25
			rt_mesh.bottom_radius = 0.36
			rt_mesh.height = 0.50
			rt_mesh.radial_segments = 14
			robe_top.mesh = rt_mesh
			robe_top.material_override = mat_fac
			robe_top.position = Vector3(0.0, 1.05, 0.0)
			warrior.add_child(robe_top)

			# Embroidered Stole / Shoulder Trim
			var stole_inst = MeshInstance3D.new()
			var st_mesh = BoxMesh.new()
			st_mesh.size = Vector3(0.55, 0.12, 0.32)
			stole_inst.mesh = st_mesh
			stole_inst.material_override = mat_trm
			stole_inst.position = Vector3(0.0, 1.30, 0.0)
			warrior.add_child(stole_inst)

			var stole_ribbon = MeshInstance3D.new()
			var srib_mesh = BoxMesh.new()
			srib_mesh.size = Vector3(0.16, 0.60, 0.04)
			stole_ribbon.mesh = srib_mesh
			stole_ribbon.material_override = mat_trm
			stole_ribbon.position = Vector3(0.0, 0.95, 0.26)
			warrior.add_child(stole_ribbon)

			# Cleric Head & Mitre
			var head_inst = MeshInstance3D.new()
			var head_mesh = SphereMesh.new()
			head_mesh.radius = 0.18
			head_inst.mesh = head_mesh
			head_inst.material_override = mat_arm
			head_inst.position = Vector3(0.0, 1.48, 0.0)
			warrior.add_child(head_inst)

			var mitre_inst = MeshInstance3D.new()
			var mitre_mesh = PrismMesh.new()
			mitre_mesh.size = Vector3(0.36, 0.48, 0.30)
			mitre_inst.mesh = mitre_mesh
			mitre_inst.material_override = mat_fac
			mitre_inst.position = Vector3(0.0, 1.82, 0.0)
			warrior.add_child(mitre_inst)

			var cross_inst = MeshInstance3D.new()
			var cross_mesh = BoxMesh.new()
			cross_mesh.size = Vector3(0.08, 0.16, 0.04)
			cross_inst.mesh = cross_mesh
			cross_inst.material_override = mat_trm
			cross_inst.position = Vector3(0.0, 1.80, 0.16)
			warrior.add_child(cross_inst)

			# Ornate Crosier Battle Staff
			var staff_inst = MeshInstance3D.new()
			var staff_mesh = CylinderMesh.new()
			staff_mesh.top_radius = 0.025
			staff_mesh.bottom_radius = 0.025
			staff_mesh.height = 1.95
			staff_inst.mesh = staff_mesh
			staff_inst.material_override = mat_trm
			staff_inst.position = Vector3(0.38, 1.10, 0.18)
			warrior.add_child(staff_inst)

			var crook_inst = MeshInstance3D.new()
			var crook_mesh = TorusMesh.new()
			crook_mesh.inner_radius = 0.07
			crook_mesh.outer_radius = 0.16
			crook_inst.mesh = crook_mesh
			crook_inst.material_override = mat_trm
			crook_inst.position = Vector3(0.38, 2.10, 0.18)
			crook_inst.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			warrior.add_child(crook_inst)

			var gem_inst = MeshInstance3D.new()
			var gem_mesh = SphereMesh.new()
			gem_mesh.radius = 0.07
			gem_inst.mesh = gem_mesh
			gem_inst.material_override = mat_fac
			gem_inst.position = Vector3(0.38, 2.10, 0.18)
			warrior.add_child(gem_inst)

		"Q": # Queen (Royal Sorceress): Slender armored gown, high gold crown, cape, and arcane scepter
			# Flared Royal Gown
			var gown_bot = MeshInstance3D.new()
			var gb_mesh = CylinderMesh.new()
			gb_mesh.top_radius = 0.32
			gb_mesh.bottom_radius = 0.52
			gb_mesh.height = 0.70
			gb_mesh.radial_segments = 16
			gown_bot.mesh = gb_mesh
			gown_bot.material_override = mat_fac
			gown_bot.position = Vector3(0.0, 0.51, 0.0)
			warrior.add_child(gown_bot)

			# Corset Armor Bodice
			var bodice_inst = MeshInstance3D.new()
			var bodice_mesh = CylinderMesh.new()
			bodice_mesh.top_radius = 0.22
			bodice_mesh.bottom_radius = 0.30
			bodice_mesh.height = 0.45
			bodice_inst.mesh = bodice_mesh
			bodice_inst.material_override = mat_arm
			bodice_inst.position = Vector3(0.0, 1.08, 0.0)
			warrior.add_child(bodice_inst)

			# Gold Waist Band
			var band_inst = MeshInstance3D.new()
			var band_mesh = CylinderMesh.new()
			band_mesh.top_radius = 0.27
			band_mesh.bottom_radius = 0.27
			band_mesh.height = 0.06
			band_inst.mesh = band_mesh
			band_inst.material_override = mat_trm
			band_inst.position = Vector3(0.0, 0.88, 0.0)
			warrior.add_child(band_inst)

			# Royal Cape
			var cape_inst = MeshInstance3D.new()
			var cape_mesh = BoxMesh.new()
			cape_mesh.size = Vector3(0.50, 1.0, 0.05)
			cape_inst.mesh = cape_mesh
			cape_inst.material_override = mat_fac
			cape_inst.position = Vector3(0.0, 0.95, -0.22)
			cape_inst.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
			warrior.add_child(cape_inst)

			# Regal Head
			var head_inst = MeshInstance3D.new()
			var head_mesh = SphereMesh.new()
			head_mesh.radius = 0.17
			head_inst.mesh = head_mesh
			head_inst.material_override = mat_arm
			head_inst.position = Vector3(0.0, 1.50, 0.0)
			warrior.add_child(head_inst)

			# High Gold Crown with 5 Spire Points
			var crown_base = MeshInstance3D.new()
			var cb_mesh = CylinderMesh.new()
			cb_mesh.top_radius = 0.19
			cb_mesh.bottom_radius = 0.18
			cb_mesh.height = 0.12
			crown_base.mesh = cb_mesh
			crown_base.material_override = mat_trm
			crown_base.position = Vector3(0.0, 1.70, 0.0)
			warrior.add_child(crown_base)

			for i in range(5):
				var ang = 2.0 * PI * float(i) / 5.0
				var cx = cos(ang) * 0.17
				var cz = sin(ang) * 0.17
				var spire = MeshInstance3D.new()
				var spire_mesh = ConeMesh.new()
				spire_mesh.top_radius = 0.0
				spire_mesh.bottom_radius = 0.04
				spire_mesh.height = 0.18
				spire.mesh = spire_mesh
				spire.material_override = mat_trm
				spire.position = Vector3(cx, 1.84, cz)
				warrior.add_child(spire)

			# Arcane Royal Scepter
			var scepter_inst = MeshInstance3D.new()
			var scepter_mesh = CylinderMesh.new()
			scepter_mesh.top_radius = 0.02
			scepter_mesh.bottom_radius = 0.02
			scepter_mesh.height = 1.15
			scepter_inst.mesh = scepter_mesh
			scepter_inst.material_override = mat_trm
			scepter_inst.position = Vector3(0.38, 1.15, 0.18)
			warrior.add_child(scepter_inst)

			var orb_inst = MeshInstance3D.new()
			var orb_mesh = SphereMesh.new()
			orb_mesh.radius = 0.09
			orb_inst.mesh = orb_mesh
			orb_inst.material_override = mat_fac
			orb_inst.position = Vector3(0.38, 1.75, 0.18)
			warrior.add_child(orb_inst)

		"K": # King (War Monarch): Broad royal mantle, ornate gold crown, bearded/visored head, and two-handed royal greatsword
			# Broad Royal Mantle
			var mantle_inst = MeshInstance3D.new()
			var mantle_mesh = CylinderMesh.new()
			mantle_mesh.top_radius = 0.36
			mantle_mesh.bottom_radius = 0.58
			mantle_mesh.height = 0.85
			mantle_mesh.radial_segments = 16
			mantle_inst.mesh = mantle_mesh
			mantle_inst.material_override = mat_fac
			mantle_inst.position = Vector3(0.0, 0.58, 0.0)
			warrior.add_child(mantle_inst)

			# Heavy Armored Cuirass
			var chest_inst = MeshInstance3D.new()
			var chest_mesh = BoxMesh.new()
			chest_mesh.size = Vector3(0.60, 0.65, 0.42)
			chest_inst.mesh = chest_mesh
			chest_inst.material_override = mat_arm
			chest_inst.position = Vector3(0.0, 1.20, 0.0)
			warrior.add_child(chest_inst)

			var lion_crest = MeshInstance3D.new()
			var lc_mesh = BoxMesh.new()
			lc_mesh.size = Vector3(0.24, 0.28, 0.44)
			lion_crest.mesh = lc_mesh
			lion_crest.material_override = mat_trm
			lion_crest.position = Vector3(0.0, 1.22, 0.0)
			warrior.add_child(lion_crest)

			# Heavy Gold Pauldrons
			var pauld_l = MeshInstance3D.new()
			var pauld_r = MeshInstance3D.new()
			var p_mesh = BoxMesh.new()
			p_mesh.size = Vector3(0.25, 0.18, 0.32)
			pauld_l.mesh = p_mesh
			pauld_r.mesh = p_mesh
			pauld_l.material_override = mat_trm
			pauld_r.material_override = mat_trm
			pauld_l.position = Vector3(-0.42, 1.48, 0.0)
			pauld_r.position = Vector3(0.42, 1.48, 0.0)
			warrior.add_child(pauld_l)
			warrior.add_child(pauld_r)

			# Fur / Ermine Collar
			var collar_inst = MeshInstance3D.new()
			var collar_mesh = CylinderMesh.new()
			collar_mesh.top_radius = 0.32
			collar_mesh.bottom_radius = 0.35
			collar_mesh.height = 0.14
			collar_inst.mesh = collar_mesh
			collar_inst.material_override = mat_arm
			collar_inst.position = Vector3(0.0, 1.55, 0.0)
			warrior.add_child(collar_inst)

			# Monarch Head
			var head_inst = MeshInstance3D.new()
			var head_mesh = SphereMesh.new()
			head_mesh.radius = 0.20
			head_inst.mesh = head_mesh
			head_inst.material_override = mat_arm
			head_inst.position = Vector3(0.0, 1.74, 0.0)
			warrior.add_child(head_inst)

			# Ornate Imperial Gold Crown
			var crown_base = MeshInstance3D.new()
			var cb_mesh = CylinderMesh.new()
			cb_mesh.top_radius = 0.23
			cb_mesh.bottom_radius = 0.22
			cb_mesh.height = 0.14
			crown_base.mesh = cb_mesh
			crown_base.material_override = mat_trm
			crown_base.position = Vector3(0.0, 1.94, 0.0)
			warrior.add_child(crown_base)

			var crown_dome = MeshInstance3D.new()
			var cd_mesh = SphereMesh.new()
			cd_mesh.radius = 0.18
			crown_dome.mesh = cd_mesh
			crown_dome.material_override = mat_fac
			crown_dome.position = Vector3(0.0, 2.04, 0.0)
			warrior.add_child(crown_dome)

			var crown_cross = MeshInstance3D.new()
			var cc_mesh = BoxMesh.new()
			cc_mesh.size = Vector3(0.06, 0.16, 0.04)
			crown_cross.mesh = cc_mesh
			crown_cross.material_override = mat_trm
			crown_cross.position = Vector3(0.0, 2.26, 0.0)
			warrior.add_child(crown_cross)

			# Two-Handed Royal Greatsword (held majestically forward)
			var blade_inst = MeshInstance3D.new()
			var blade_mesh = BoxMesh.new()
			blade_mesh.size = Vector3(0.09, 1.25, 0.04)
			blade_inst.mesh = blade_mesh
			blade_inst.material_override = mat_arm
			blade_inst.position = Vector3(0.0, 0.85, 0.36)
			warrior.add_child(blade_inst)

			var guard_inst = MeshInstance3D.new()
			var guard_mesh = BoxMesh.new()
			guard_mesh.size = Vector3(0.40, 0.05, 0.06)
			guard_inst.mesh = guard_mesh
			guard_inst.material_override = mat_trm
			guard_inst.position = Vector3(0.0, 1.48, 0.36)
			warrior.add_child(guard_inst)

			var grip_inst = MeshInstance3D.new()
			var grip_mesh = CylinderMesh.new()
			grip_mesh.top_radius = 0.025
			grip_mesh.bottom_radius = 0.025
			grip_mesh.height = 0.28
			grip_inst.mesh = grip_mesh
			grip_inst.material_override = mat_trm
			grip_inst.position = Vector3(0.0, 1.64, 0.36)
			warrior.add_child(grip_inst)

	return warrior

## Apply classic 1988 Battle Chess PBR materials across imported 3D models
func _apply_pbr_materials(root: Node) -> void:
	var pal = _create_pbr_palette()
	var mat_arm = pal["armor"]
	var mat_fac = pal["faction"]
	var mat_trm = pal["trim"]

	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D and n.material_override == null:
			# If the model has existing mesh surface materials from GLB, ensure emission is disabled
			if n.mesh != null and n.mesh.get_surface_count() > 0:
				for s in range(n.mesh.get_surface_count()):
					var surf_mat = n.get_active_material(s)
					if surf_mat is StandardMaterial3D:
						surf_mat.emission_enabled = false
					elif surf_mat == null:
						n.set_surface_override_material(s, mat_arm)
			else:
				n.material_override = mat_arm

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
		combined_aabb = AABB(Vector3(-0.35, 0, -0.35), Vector3(0.7, get_target_height(), 0.7))

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
			ring_tween.tween_property(selection_ring, "scale", Vector3(1.10, 1.0, 1.10), 0.45).set_trans(Tween.TRANS_SINE)
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

## Smooth parabolic hop for peaceful movements
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

	# High parabolic jump
	var apex_height = maxf(position.y, target_pos.y) + 1.2
	var hop_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hop_tween.tween_property(self, "position:y", apex_height, duration * 0.45)
	hop_tween.set_ease(Tween.EASE_IN)
	hop_tween.tween_property(self, "position:y", target_pos.y, duration * 0.55)

	# Landing impact
	hop_tween.chain().tween_property(self, "scale", base_scale * Vector3(1.15, 0.85, 1.15), 0.08)
	hop_tween.chain().tween_property(self, "scale", base_scale, 0.12)

	hop_tween.finished.connect(func(): movement_finished.emit(), CONNECT_ONE_SHOT)
	return movement_finished

## Combat attack lunge towards opposing square
func execute_attack_strike(target_pos: Vector3) -> Signal:
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var original_pos = position
	var strike_dir = (target_pos - position).normalized()
	var lunge_pos = position + strike_dir * 1.0

	# Turn to face victim
	if strike_dir.length_squared() > 0.01:
		rotation.y = atan2(strike_dir.x, strike_dir.z)

	tw.tween_property(self, "position", lunge_pos, 0.22)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(1.15, 1.15, 1.15), 0.18)
	tw.chain().tween_property(self, "position", original_pos, 0.2)
	tw.parallel().tween_property(self, "scale", base_scale, 0.2)
	return tw.finished

## Act 1: Attacker delivers heavy opening blow
func play_act1_strike(target_pos: Vector3) -> void:
	face_target(target_pos)
	var dir = (target_pos - position).normalized()
	var start_pos = position
	var strike_pos = position + dir * 0.85

	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Windup (0.0 - 0.35s)
	tw.tween_property(self, "position", start_pos - dir * 0.25, 0.35)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(0.92, 1.12, 0.92), 0.35)
	# Heavy Strike Lunge (0.35 - 0.75s)
	tw.chain().tween_property(self, "position", strike_pos, 0.4)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(1.20, 0.88, 1.20), 0.4)
	# Stance Recovery (0.75 - 1.6s)
	tw.chain().tween_property(self, "position", start_pos, 0.85)
	tw.parallel().tween_property(self, "scale", base_scale, 0.85)

## Act 1: Defender parries/blocks with shield or weapon
func play_act1_block(attacker_pos: Vector3) -> void:
	face_target(attacker_pos)
	var dir = (position - attacker_pos).normalized()
	var start_pos = position

	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	# Impact recoil
	tw.chain().tween_property(self, "position", start_pos + dir * 0.35, 0.18)
	tw.parallel().tween_property(self, "rotation_degrees:x", -12.0, 0.18)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(1.12, 0.9, 1.12), 0.18)
	# Recover to combat stance
	tw.chain().tween_property(self, "position", start_pos, 0.7)
	tw.parallel().tween_property(self, "rotation_degrees:x", 0.0, 0.7)
	tw.parallel().tween_property(self, "scale", base_scale, 0.7)

## Act 2: Defender retaliates with a counter-attack
func play_act2_counter(target_pos: Vector3) -> void:
	face_target(target_pos)
	var dir = (target_pos - position).normalized()
	var start_pos = position
	var counter_pos = position + dir * 0.95

	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", counter_pos, 0.4)
	tw.parallel().tween_property(self, "rotation_degrees:z", 18.0, 0.4)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(1.12, 1.12, 1.12), 0.4)
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
	tw.chain().tween_property(self, "position", start_pos + side_dir * 0.65 - Vector3(0, 0.25, 0), 0.3)
	tw.parallel().tween_property(self, "rotation_degrees:z", -12.0, 0.3)
	# Recover into stance
	tw.chain().tween_property(self, "position", start_pos, 0.55)
	tw.parallel().tween_property(self, "rotation_degrees:z", 0.0, 0.55)

## Act 3: Attacker executes signature theme kill shot
func play_act3_finisher(target_pos: Vector3, _atk_type: String, _theme_id: String) -> void:
	face_target(target_pos)
	var dir = (target_pos - position).normalized()
	var start_pos = position
	var impact_pos = target_pos - dir * 0.25

	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	# Windup leap into air
	tw.tween_property(self, "position", start_pos + Vector3(0, 1.6, 0) - dir * 0.4, 0.75)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(1.22, 1.22, 1.22), 0.75)
	# Devastating Execution Plunge
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tw.chain().tween_property(self, "position", impact_pos, 0.2)
	tw.parallel().tween_property(self, "scale", base_scale * Vector3(1.30, 0.75, 1.30), 0.15)
	# Settle scale
	tw.chain().tween_property(self, "scale", base_scale, 0.35)

## Impact reaction when hit
func play_hit_stagger() -> void:
	var target_node: Node3D = model_root if is_instance_valid(model_root) else self
	var tw = create_tween()
	tw.tween_property(target_node, "rotation_degrees:z", -14.0, 0.08)
	tw.tween_property(target_node, "rotation_degrees:z", 10.0, 0.08)
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
				head_tw.tween_property(head_socket, "position:y", head_socket.position.y + 2.0, 0.3)
				head_tw.tween_property(head_socket, "position:z", head_socket.position.z - 2.5, 0.5)
			tw.tween_property(self, "rotation_degrees:x", 85.0, 0.4)
			tw.parallel().tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.75)
		"disintegrate":
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_property(self, "scale", Vector3(1.4, 0.01, 1.4), 0.35)
			tw.chain().tween_property(self, "scale", Vector3(0.001, 0.001, 0.001), 0.35)
		_: # collapse
			tw.tween_property(self, "rotation_degrees:z", -85.0, 0.45)
			tw.parallel().tween_property(self, "position:y", position.y - 0.3, 0.45)
			tw.chain().tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.45)

func _on_input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		clicked.emit(board_pos)
