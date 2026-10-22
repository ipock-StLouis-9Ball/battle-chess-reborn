class_name Board3D
extends Node3D

## Heroic 3D Isometric Combat Chess Coordinator
## - Multi-tiered architectural dais staging with chiseled basalt plinth and beveled border frame
## - Engraved algebraic notation labels (A-H, 1-8) along all four perimeter rims
## - Four corner guardian braziers with dynamic atmospheric lighting
## - Physical 3D raycast picking on all 64 tiles and standing pieces
## - Emissive glowing selection rings and emerald/gold legal move markers
## - Parabolic leap movements, cinematic duel plunges, and dynamic theme switching

signal square_clicked(pos: Vector2i)

const BOARD_SIZE: int = 8
@export var tile_size: float = 2.5
@export var square_size: float = 2.5 # Backwards compatibility alias
@export var board_height: float = 1.4

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var base_plinth: MeshInstance3D = $BasePlinth
@onready var pedestal_mesh: MeshInstance3D = $PedestalMesh
@onready var border_frame: MeshInstance3D = $BorderFrame
@onready var notation_root: Node3D = $NotationRoot
@onready var braziers_root: Node3D = $BraziersRoot
@onready var tiles_root: Node3D = $TilesRoot
@onready var pieces_root: Node3D = $PiecesRoot
@onready var highlights_root: Node3D = $HighlightsRoot
@onready var camera_rig: Node3D = $CameraRig
@onready var camera_3d: Camera3D = $CameraRig/CinematicCamera
@onready var key_light: DirectionalLight3D = $DirectionalLight3D
@onready var rim_light: DirectionalLight3D = $RimLight3D
@onready var fill_light: OmniLight3D = $FillLight

var chess_board: ChessBoard
var active_pieces: Dictionary = {} # Vector2i -> Piece3D
var tile_areas: Dictionary = {} # Vector2i -> Area3D
var active_highlights: Dictionary = {} # Vector2i -> MeshInstance3D

var notation_labels: Array[Label3D] = []
var brazier_lights: Array[OmniLight3D] = []
var brazier_flames: Array[MeshInstance3D] = []

var is_animating_move: bool = false

func _ready() -> void:
	if tile_size != 2.5 and square_size == 2.5:
		tile_size = square_size
	square_size = tile_size

	_build_board_staging()
	_build_3d_tiles()
	if is_instance_valid(camera_3d):
		camera_3d.make_current()
	if has_node("/root/ThemeManager"):
		get_node("/root/ThemeManager").piece_theme_changed.connect(apply_theme)
		apply_theme(get_node("/root/ThemeManager").get_current_piece_theme())

## Bind the core ChessBoard rules engine to the 3D battlefield
func bind_chess_board(board_logic: ChessBoard) -> void:
	chess_board = board_logic
	chess_board.board_updated.connect(_sync_3d_pieces)
	chess_board.piece_selected.connect(_on_piece_selected)
	chess_board.selection_cleared.connect(_clear_highlights)
	chess_board.theme_swapped.connect(func(_id, theme_res): apply_theme(theme_res))
	chess_board.duel_triggered.connect(_on_duel_triggered)
	_sync_3d_pieces()

## Build heroic architectural board staging (coordinates, corner braziers)
func _build_board_staging() -> void:
	_build_notation_labels()
	_build_corner_braziers()

## Engrave 3D algebraic coordinate notation (A-H, 1-8) along all 4 perimeter borders
func _build_notation_labels() -> void:
	for child in notation_root.get_children():
		child.queue_free()
	notation_labels.clear()

	var file_names = ["A", "B", "C", "D", "E", "F", "G", "H"]
	var rank_names = ["8", "7", "6", "5", "4", "3", "2", "1"]

	var rim_dist = 10.45
	var label_y = 0.12

	# 1. Front and Back Rims (Files A through H)
	for i in range(BOARD_SIZE):
		var x_pos = (float(i) - 3.5) * tile_size
		var text = file_names[i]

		# Front Rim (facing camera)
		var front_label = _create_notation_label(text)
		front_label.position = Vector3(x_pos, label_y, rim_dist)
		front_label.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
		notation_root.add_child(front_label)
		notation_labels.append(front_label)

		# Back Rim (opposite side)
		var back_label = _create_notation_label(text)
		back_label.position = Vector3(x_pos, label_y, -rim_dist)
		back_label.rotation_degrees = Vector3(-45.0, 180.0, 0.0)
		notation_root.add_child(back_label)
		notation_labels.append(back_label)

	# 2. Left and Right Rims (Ranks 8 through 1)
	for j in range(BOARD_SIZE):
		var z_pos = (float(j) - 3.5) * tile_size
		var text = rank_names[j]

		# Left Rim
		var left_label = _create_notation_label(text)
		left_label.position = Vector3(-rim_dist, label_y, z_pos)
		left_label.rotation_degrees = Vector3(-45.0, 90.0, 0.0)
		notation_root.add_child(left_label)
		notation_labels.append(left_label)

		# Right Rim
		var right_label = _create_notation_label(text)
		right_label.position = Vector3(rim_dist, label_y, z_pos)
		right_label.rotation_degrees = Vector3(-45.0, -90.0, 0.0)
		notation_root.add_child(right_label)
		notation_labels.append(right_label)

func _create_notation_label(text: String) -> Label3D:
	var l = Label3D.new()
	l.text = text
	l.font_size = 54
	l.pixel_size = 0.016
	l.modulate = Color(1.0, 0.85, 0.35, 0.95)
	l.outline_modulate = Color(0.04, 0.05, 0.08, 0.95)
	l.outline_size = 10
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

## Construct 4 Heroic Corner Braziers / Beacon Obelisks
func _build_corner_braziers() -> void:
	for child in braziers_root.get_children():
		child.queue_free()
	brazier_lights.clear()
	brazier_flames.clear()

	var corner_coords = [
		Vector3(-11.5, 0.0, -11.5),
		Vector3(11.5, 0.0, -11.5),
		Vector3(-11.5, 0.0, 11.5),
		Vector3(11.5, 0.0, 11.5)
	]

	var col_mesh = CylinderMesh.new()
	col_mesh.top_radius = 0.55
	col_mesh.bottom_radius = 0.75
	col_mesh.height = 1.6
	col_mesh.radial_segments = 8

	var bowl_mesh = CylinderMesh.new()
	bowl_mesh.top_radius = 0.85
	bowl_mesh.bottom_radius = 0.45
	bowl_mesh.height = 0.35
	bowl_mesh.radial_segments = 12

	var orb_mesh = SphereMesh.new()
	orb_mesh.radius = 0.35
	orb_mesh.height = 0.7
	orb_mesh.radial_segments = 16
	orb_mesh.rings = 8

	var stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.12, 0.13, 0.17, 1.0)
	stone_mat.roughness = 0.45
	stone_mat.metallic = 0.25

	for i in range(corner_coords.size()):
		var cpos = corner_coords[i]
		var brazier_node = Node3D.new()
		brazier_node.name = "CornerBrazier_%d" % i
		brazier_node.position = cpos

		# Pedestal Column
		var col_inst = MeshInstance3D.new()
		col_inst.mesh = col_mesh
		col_inst.material_override = stone_mat
		col_inst.position = Vector3(0.0, 0.4, 0.0)
		brazier_node.add_child(col_inst)

		# Brazier Bowl
		var bowl_inst = MeshInstance3D.new()
		bowl_inst.mesh = bowl_mesh
		bowl_inst.material_override = stone_mat
		bowl_inst.position = Vector3(0.0, 1.35, 0.0)
		brazier_node.add_child(bowl_inst)

		# Emissive Flame / Plasma Orb
		var flame_mat = StandardMaterial3D.new()
		flame_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		flame_mat.albedo_color = Color(1.0, 0.7, 0.2)
		flame_mat.emission_enabled = true
		flame_mat.emission = Color(1.0, 0.7, 0.2)
		flame_mat.emission_energy_multiplier = 3.0

		var flame_inst = MeshInstance3D.new()
		flame_inst.mesh = orb_mesh
		flame_inst.material_override = flame_mat
		flame_inst.position = Vector3(0.0, 1.65, 0.0)
		brazier_node.add_child(flame_inst)
		brazier_flames.append(flame_inst)

		# Atmospheric Corner Omni Light
		var olight = OmniLight3D.new()
		olight.light_color = Color(1.0, 0.72, 0.25)
		olight.light_energy = 1.3
		olight.omni_range = 14.0
		olight.position = Vector3(0.0, 1.85, 0.0)
		brazier_node.add_child(olight)
		brazier_lights.append(olight)

		braziers_root.add_child(brazier_node)

## Construct 64 physical 3D tile areas with individual colliders for raycast picking
func _build_3d_tiles() -> void:
	for child in tiles_root.get_children():
		child.queue_free()
	tile_areas.clear()

	var tile_box = BoxMesh.new()
	tile_box.size = Vector3(tile_size * 0.95, 0.15, tile_size * 0.95)

	var tile_shape = BoxShape3D.new()
	tile_shape.size = Vector3(tile_size * 0.98, 0.35, tile_size * 0.98)

	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var pos = Vector2i(x, y)
			var w_pos = board_to_world(pos)

			# 3D Area for mouse / touch picking
			var area = Area3D.new()
			area.name = "TileArea_%d_%d" % [x, y]
			area.position = w_pos + Vector3(0, 0.08, 0)

			var col = CollisionShape3D.new()
			col.shape = tile_shape
			area.add_child(col)

			# Visual tile slab
			var mesh_inst = MeshInstance3D.new()
			mesh_inst.mesh = tile_box
			area.add_child(mesh_inst)

			area.input_event.connect(_on_tile_input_event.bind(pos))
			tiles_root.add_child(area)
			tile_areas[pos] = area

	_update_tile_materials()

func _update_tile_materials() -> void:
	var theme_data = {}
	if has_node("/root/ThemeManager"):
		theme_data = get_node("/root/ThemeManager").get_current_theme_data()

	var light_col = theme_data.get("light_square", Color(0.88, 0.9, 0.95))
	var dark_col = theme_data.get("dark_square", Color(0.18, 0.22, 0.3))

	var mat_light = StandardMaterial3D.new()
	mat_light.albedo_color = light_col
	mat_light.roughness = 0.3
	mat_light.metallic = 0.25

	var mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = dark_col
	mat_dark.roughness = 0.35
	mat_dark.metallic = 0.35

	for pos in tile_areas.keys():
		var is_dark = ((pos.x + pos.y) % 2 == 1)
		var area: Area3D = tile_areas[pos]
		var mesh_inst = area.get_child(1) as MeshInstance3D
		if mesh_inst:
			mesh_inst.material_override = mat_dark if is_dark else mat_light

## Convert 2D grid matrix coordinates to centered 3D world space
func board_to_world(pos: Vector2i) -> Vector3:
	var offset_x = (float(pos.x) - 3.5) * tile_size
	var offset_z = (float(pos.y) - 3.5) * tile_size
	return Vector3(offset_x, 0.0, offset_z)

## Synchronize 3D piece instances with ChessBoard logic matrix
func _sync_3d_pieces() -> void:
	if chess_board == null:
		return

	for p in active_pieces.values():
		if is_instance_valid(p):
			p.queue_free()
	active_pieces.clear()

	var pt = chess_board.get_current_piece_theme()
	if pt == null and has_node("/root/ThemeManager"):
		pt = get_node("/root/ThemeManager").get_current_piece_theme()

	for x in range(BOARD_SIZE):
		for y in range(BOARD_SIZE):
			var pos = Vector2i(x, y)
			var data = chess_board.get_piece(pos)
			if data != null:
				var piece_node: Piece3D = null
				if pt != null:
					piece_node = pt.instantiate_3d_piece(data["type"], data["color"])
				else:
					var p_scene = load("res://scenes/pieces/Piece3D_Pawn.tscn")
					piece_node = p_scene.instantiate()
					piece_node.setup(data["type"], data["color"])

				if piece_node:
					piece_node.board_pos = pos
					piece_node.position = board_to_world(pos)
					if data["color"] == "black":
						piece_node.rotation_degrees.y = 180.0
					piece_node.clicked.connect(_on_piece_clicked)
					pieces_root.add_child(piece_node)
					active_pieces[pos] = piece_node

## Apply active theme materials to the pedestal, notation, braziers, and pieces
func apply_theme(theme_res: PieceTheme) -> void:
	if theme_res == null:
		return

	if is_instance_valid(pedestal_mesh) and theme_res.board_material != null:
		pedestal_mesh.material_override = theme_res.board_material

	_update_tile_materials()

	# Theme-specific staging colors
	var theme_id = "high_fantasy"
	if has_node("/root/ThemeManager"):
		theme_id = get_node("/root/ThemeManager").current_theme

	var notation_color = Color(1.0, 0.85, 0.35, 0.95)
	var flame_color = Color(1.0, 0.68, 0.2)
	var rim_color = Color(0.85, 0.92, 1.0)
	var sky_horizon = Color(0.28, 0.32, 0.42)

	match theme_id:
		"high_fantasy":
			notation_color = Color(1.0, 0.85, 0.35, 0.95)
			flame_color = Color(1.0, 0.68, 0.2)
			rim_color = Color(0.9, 0.85, 0.75)
			sky_horizon = Color(0.35, 0.3, 0.38)
		"cyberpunk":
			notation_color = Color(0.0, 0.95, 0.88, 0.95)
			flame_color = Color(0.0, 0.92, 0.85)
			rim_color = Color(0.0, 0.8, 1.0)
			sky_horizon = Color(0.05, 0.18, 0.25)
		"eldritch":
			notation_color = Color(0.88, 0.4, 1.0, 0.95)
			flame_color = Color(0.78, 0.22, 0.95)
			rim_color = Color(0.75, 0.3, 0.95)
			sky_horizon = Color(0.2, 0.08, 0.28)

	# Update notation labels
	for label in notation_labels:
		if is_instance_valid(label):
			label.modulate = notation_color

	# Update corner braziers
	for flame in brazier_flames:
		if is_instance_valid(flame) and flame.material_override is StandardMaterial3D:
			var mat = flame.material_override as StandardMaterial3D
			mat.albedo_color = flame_color
			mat.emission = flame_color

	for olight in brazier_lights:
		if is_instance_valid(olight):
			olight.light_color = flame_color

	if is_instance_valid(rim_light):
		rim_light.light_color = rim_color

	if is_instance_valid(world_env) and world_env.environment and world_env.environment.sky:
		var sky_mat = world_env.environment.sky.sky_material
		if sky_mat is ProceduralSkyMaterial:
			sky_mat.sky_horizon_color = sky_horizon

	for piece in active_pieces.values():
		if is_instance_valid(piece):
			piece.apply_theme(theme_res)

## 3D Tile input routing
func _on_tile_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, grid_pos: Vector2i) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or \
	   (event is InputEventScreenTouch and event.pressed):
		_handle_interaction(grid_pos)

func _on_piece_clicked(pos: Vector2i) -> void:
	_handle_interaction(pos)

func _handle_interaction(pos: Vector2i) -> void:
	if is_animating_move or chess_board == null:
		return
	if chess_board.current_state == ChessBoard.TurnState.DUEL_IN_PROGRESS or chess_board.current_state == ChessBoard.TurnState.GAME_OVER:
		return

	# If a piece is already selected, check if this is a peaceful move to animate
	if chess_board.selected_tile != Vector2i(-1, -1):
		for move in chess_board.cached_legal_moves:
			if move["to"] == pos:
				var is_capture = (chess_board.get_piece(pos) != null) or move.get("is_en_passant", false)
				if not is_capture:
					_animate_peaceful_move(move)
					return
				break

	chess_board.select_square(pos)
	square_clicked.emit(pos)

## Smooth parabolic hop for peaceful movements
func _animate_peaceful_move(move: Dictionary) -> void:
	var from_pos: Vector2i = move["from"]
	var to_pos: Vector2i = move["to"]
	var moving_piece: Piece3D = active_pieces.get(from_pos, null)
	if moving_piece == null:
		chess_board.select_square(to_pos)
		return

	is_animating_move = true
	_clear_highlights()

	var target_wpos = board_to_world(to_pos)
	moving_piece.animate_move_to(target_wpos, 0.42)
	await moving_piece.movement_finished

	# Transfer tracking in active_pieces dict
	active_pieces.erase(from_pos)
	moving_piece.board_pos = to_pos
	active_pieces[to_pos] = moving_piece

	is_animating_move = false
	chess_board.select_square(to_pos)

## Display glowing 3D selection and move indicators
func _on_piece_selected(pos: Vector2i, _info: Dictionary) -> void:
	_clear_highlights()

	# Highlight selected piece with glowing ring
	if active_pieces.has(pos):
		active_pieces[pos].set_selected(true)

	# Highlight origin tile with glowing gold/amber
	_spawn_tile_highlight(pos, Color(1.0, 0.85, 0.2, 0.85), false, true)

	# Highlight legal destination squares
	for move in chess_board.cached_legal_moves:
		var target: Vector2i = move["to"]
		var is_capture = move.get("is_capture", false)
		if is_capture:
			# Pulsing gold/ruby combat target
			_spawn_tile_highlight(target, Color(1.0, 0.25, 0.2, 0.9), true, false)
		else:
			# Glowing emerald green destination marker
			_spawn_tile_highlight(target, Color(0.2, 0.95, 0.35, 0.85), false, false)

func _spawn_tile_highlight(pos: Vector2i, color: Color, is_combat_target: bool, is_origin: bool) -> void:
	var quad = MeshInstance3D.new()
	var box = BoxMesh.new()
	var pad = 0.94 if not is_combat_target else 0.96
	box.size = Vector3(tile_size * pad, 0.08, tile_size * pad)
	quad.mesh = box

	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.4 if (is_combat_target or is_origin) else 1.8
	quad.material_override = mat

	quad.position = board_to_world(pos) + Vector3(0, 0.17, 0)
	highlights_root.add_child(quad)
	active_highlights[pos] = quad

	if is_combat_target:
		# Pulsating combat threat indicator
		var tw = create_tween().set_loops()
		tw.tween_property(quad, "scale", Vector3(1.08, 1.0, 1.08), 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_property(quad, "scale", Vector3(0.96, 1.0, 0.96), 0.35).set_trans(Tween.TRANS_SINE)
	elif is_origin:
		var tw = create_tween().set_loops()
		tw.tween_property(quad, "scale", Vector3(1.04, 1.0, 1.04), 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_property(quad, "scale", Vector3(0.98, 1.0, 0.98), 0.45).set_trans(Tween.TRANS_SINE)

func _clear_highlights() -> void:
	for p in active_pieces.values():
		if is_instance_valid(p):
			p.set_selected(false)

	for h in active_highlights.values():
		if is_instance_valid(h):
			h.queue_free()
	active_highlights.clear()

## Cinematic duel clash animation sequence
func _on_duel_triggered(attacker: Dictionary, victim: Dictionary, board_pos: Vector2i) -> void:
	var from_pos = Vector2i(-1, -1)
	for pos in active_pieces.keys():
		var p: Piece3D = active_pieces[pos]
		if is_instance_valid(p) and p.piece_type == attacker.get("type") and p.piece_color == attacker.get("color"):
			from_pos = pos
			break

	var target_wpos = board_to_world(board_pos)

	# Camera plunges into dynamic duel action
	if has_node("/root/DuelDirector"):
		get_node("/root/DuelDirector").start_cinematic_duel(attacker, victim, Vector2(target_wpos.x, target_wpos.z))

	if active_pieces.has(from_pos):
		var atk_piece: Piece3D = active_pieces[from_pos]
		atk_piece.execute_attack_strike(target_wpos)

	if active_pieces.has(board_pos):
		var vic_piece: Piece3D = active_pieces[board_pos]
		await get_tree().create_timer(0.4).timeout
		if is_instance_valid(vic_piece):
			vic_piece.play_hit_stagger()
		await get_tree().create_timer(0.8).timeout
		if is_instance_valid(vic_piece):
			vic_piece.play_death_reaction("collapse")

## Screen touch raycast fallback to guarantee touch picking across all mobile devices
func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(camera_3d):
		return
	var click_pos = Vector2.ZERO
	var is_click = false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_pos = event.position
		is_click = true
	elif event is InputEventScreenTouch and event.pressed:
		click_pos = event.position
		is_click = true

	if not is_click:
		return

	var from = camera_3d.project_ray_origin(click_pos)
	var to = from + camera_3d.project_ray_normal(click_pos) * 1000.0
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit = space.intersect_ray(query)

	if hit and hit.has("collider"):
		var collider = hit["collider"]
		if collider.has_meta("piece_pos"):
			_handle_interaction(collider.get_meta("piece_pos"))
			return
		var parent = collider.get_parent()
		if parent is Piece3D:
			_handle_interaction(parent.board_pos)
			return
		for grid_pos in tile_areas.keys():
			if tile_areas[grid_pos] == collider:
				_handle_interaction(grid_pos)
				return
