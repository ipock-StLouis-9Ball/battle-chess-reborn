class_name Board3D
extends Node3D

## Heroic 3D Isometric Chess Board Coordinator
## Manages 64 interactive 3D tiles on a colossal battlefield pedestal,
## coordinates heroic piece animations, 3D picking, and dynamic theme materials.

signal square_clicked(pos: Vector2i)

const BOARD_SIZE: int = 8
@export var square_size: float = 2.4
@export var board_height: float = 1.2

@onready var pedestal_mesh: MeshInstance3D = $PedestalMesh
@onready var tiles_root: Node3D = $TilesRoot
@onready var pieces_root: Node3D = $PiecesRoot
@onready var highlights_root: Node3D = $HighlightsRoot
@onready var camera_rig: Node3D = $CameraRig
@onready var camera_3d: Camera3D = $CameraRig/Camera3D

var chess_board: ChessBoard
var active_pieces: Dictionary = {} # Vector2i -> Piece3D
var tile_areas: Dictionary = {} # Vector2i -> Area3D
var active_highlights: Dictionary = {} # Vector2i -> MeshInstance3D

var is_animating_move: bool = false
var camera_base_pos: Vector3 = Vector3(0, 16.0, 18.0)
var camera_base_rot: Vector3 = Vector3(-42.0, 0.0, 0.0)

func _ready() -> void:
	_build_3d_tiles()
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

## Construct 64 physical 3D tile areas with individual colliders for raycast picking
func _build_3d_tiles() -> void:
	for child in tiles_root.get_children():
		child.queue_free()
	tile_areas.clear()

	var tile_box = BoxMesh.new()
	tile_box.size = Vector3(square_size * 0.94, 0.15, square_size * 0.94)

	var tile_shape = BoxShape3D.new()
	tile_shape.size = Vector3(square_size * 0.96, 0.3, square_size * 0.96)

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

	var light_col = theme_data.get("light_square", Color(0.85, 0.88, 0.94))
	var dark_col = theme_data.get("dark_square", Color(0.2, 0.24, 0.32))

	var mat_light = StandardMaterial3D.new()
	mat_light.albedo_color = light_col
	mat_light.roughness = 0.35
	mat_light.metallic = 0.2

	var mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = dark_col
	mat_dark.roughness = 0.4
	mat_dark.metallic = 0.35

	for pos in tile_areas.keys():
		var is_dark = ((pos.x + pos.y) % 2 == 1)
		var area: Area3D = tile_areas[pos]
		var mesh_inst = area.get_child(1) as MeshInstance3D
		if mesh_inst:
			mesh_inst.material_override = mat_dark if is_dark else mat_light

## Convert 2D grid matrix coordinates to centered 3D world space
func board_to_world(pos: Vector2i) -> Vector3:
	var offset_x = (float(pos.x) - 3.5) * square_size
	var offset_z = (float(pos.y) - 3.5) * square_size
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

## Apply active theme materials to the pedestal and pieces
func apply_theme(theme_res: PieceTheme) -> void:
	if theme_res == null:
		return

	if is_instance_valid(pedestal_mesh) and theme_res.board_material != null:
		pedestal_mesh.material_override = theme_res.board_material

	_update_tile_materials()

	for piece in active_pieces.values():
		if is_instance_valid(piece):
			piece.apply_theme(theme_res)

## 3D Tile input routing
func _on_tile_input_event(_cam: Camera3D, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, grid_pos: Vector2i) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or \
	   (event is InputEventScreenTouch and event.pressed):
		if chess_board:
			chess_board.select_square(grid_pos)
			square_clicked.emit(grid_pos)

func _on_piece_clicked(pos: Vector2i) -> void:
	if chess_board:
		chess_board.select_square(pos)
		square_clicked.emit(pos)

## Display glowing 3D selection and move indicators
func _on_piece_selected(pos: Vector2i, _info: Dictionary) -> void:
	_clear_highlights()

	# Highlight selected piece
	if active_pieces.has(pos):
		active_pieces[pos].set_selected(true)

	# Highlight origin tile
	_spawn_tile_highlight(pos, Color(1.0, 0.85, 0.2, 0.65), false)

	# Highlight legal moves
	for move in chess_board.cached_legal_moves:
		var target: Vector2i = move["to"]
		var is_capture = move.get("is_capture", false)
		var col = Color(0.95, 0.2, 0.25, 0.7) if is_capture else Color(0.2, 0.8, 1.0, 0.6)
		_spawn_tile_highlight(target, col, is_capture)

func _spawn_tile_highlight(pos: Vector2i, color: Color, is_combat_target: bool) -> void:
	var quad = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(square_size * 0.92, 0.05, square_size * 0.92)
	quad.mesh = box

	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5 if is_combat_target else 1.0
	quad.material_override = mat

	quad.position = board_to_world(pos) + Vector3(0, 0.16, 0)
	highlights_root.add_child(quad)
	active_highlights[pos] = quad

	if is_combat_target:
		# Pulsating combat threat indicator
		var tw = create_tween().set_loops()
		tw.tween_property(quad, "scale", Vector3(1.06, 1.0, 1.06), 0.35)
		tw.tween_property(quad, "scale", Vector3(1.0, 1.0, 1.0), 0.35)

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

	# Dynamic 3D camera zoom focus
	var cam_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	cam_tween.tween_property(camera_rig, "position", target_wpos + Vector3(0, 4.5, 6.0), 0.8)

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

	# Restore isometric camera overview
	await get_tree().create_timer(1.8).timeout
	var restore_cam = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	restore_cam.tween_property(camera_rig, "position", Vector3.ZERO, 0.9)
