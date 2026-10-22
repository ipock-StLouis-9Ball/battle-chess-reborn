class_name Board3D
extends Node3D

## Complete 3D Chess Board Coordinator
## Renders 3D board plane with active PieceTheme material and coordinates
## all 32 Piece3D instances with bone attachment sockets.

@export var square_size: float = 1.0
@export var board_thickness: float = 0.2

@onready var board_mesh: MeshInstance3D = $BoardMesh
@onready var pieces_root: Node3D = $PiecesRoot

var chess_board: ChessBoard
var active_pieces: Dictionary = {} # Vector2i -> Piece3D

func _ready() -> void:
	if has_node("/root/ThemeManager"):
		get_node("/root/ThemeManager").piece_theme_changed.connect(apply_theme)
		apply_theme(get_node("/root/ThemeManager").get_current_piece_theme())

func bind_chess_board(board_logic: ChessBoard) -> void:
	chess_board = board_logic
	chess_board.board_updated.connect(_sync_3d_pieces)
	chess_board.theme_swapped.connect(func(_id, theme_res): apply_theme(theme_res))
	_sync_3d_pieces()

## Dynamically swap 3D board surface material and piece models
func apply_theme(theme_res: PieceTheme) -> void:
	if theme_res == null:
		return

	if is_instance_valid(board_mesh) and theme_res.board_material != null:
		board_mesh.material_override = theme_res.board_material

	for piece in active_pieces.values():
		if is_instance_valid(piece):
			piece.apply_theme(theme_res)

## Convert 2D matrix coordinates (0..7, 0..7) to centered 3D world space
func board_to_world(pos: Vector2i) -> Vector3:
	var offset_x = (float(pos.x) - 3.5) * square_size
	var offset_z = (float(pos.y) - 3.5) * square_size
	return Vector3(offset_x, 0.0, offset_z)

## Re-synchronize 3D piece instances with ChessBoard logic matrix
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

	for x in range(ChessBoard.BOARD_SIZE):
		for y in range(ChessBoard.BOARD_SIZE):
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
					# Rotate black pieces 180 degrees to face white pieces
					if data["color"] == "black":
						piece_node.rotation_degrees.y = 180.0
					pieces_root.add_child(piece_node)
					active_pieces[pos] = piece_node
