class_name BoardView
extends Control

## Visual Board Coordinator
## Interfaces with scripts/chess/ChessBoard.gd to render the 8x8 grid & pieces

@export var tile_scene: PackedScene = preload("res://scenes/board/Tile.tscn")
@export var piece_scene: PackedScene = preload("res://scenes/pieces/Piece.tscn")

const TILE_SIZE: float = 80.0

@onready var chess_board: ChessBoard = $ChessLogic
@onready var grid_container: GridContainer = $CenterContainer/BoardFrame/Grid
@onready var pieces_layer: Control = $CenterContainer/BoardFrame/PiecesLayer

var tiles: Dictionary = {} # Vector2i -> Tile
var piece_nodes: Dictionary = {} # Vector2i -> Piece

func _ready() -> void:
	_build_grid()
	chess_board.board_updated.connect(_sync_pieces)
	chess_board.piece_selected.connect(_on_piece_selected)
	chess_board.selection_cleared.connect(_clear_highlights)
	chess_board.duel_triggered.connect(_on_duel_triggered)
	_sync_pieces()

func _build_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	tiles.clear()

	for y in range(ChessBoard.BOARD_SIZE):
		for x in range(ChessBoard.BOARD_SIZE):
			var pos = Vector2i(x, y)
			var tile: Tile = tile_scene.instantiate()
			grid_container.add_child(tile)
			tile.setup(pos)
			tile.clicked.connect(_on_tile_clicked)
			tiles[pos] = tile

func _on_tile_clicked(pos: Vector2i) -> void:
	chess_board.select_square(pos)

func _sync_pieces() -> void:
	# Clear old piece views
	for p in piece_nodes.values():
		if is_instance_valid(p):
			p.queue_free()
	piece_nodes.clear()

	# Spawn active pieces from chess_board matrix
	for x in range(ChessBoard.BOARD_SIZE):
		for y in range(ChessBoard.BOARD_SIZE):
			var pos = Vector2i(x, y)
			var data = chess_board.get_piece(pos)
			if data != null:
				var piece_node: Piece = piece_scene.instantiate()
				piece_node.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
				pieces_layer.add_child(piece_node)
				piece_node.setup(data["type"], data["color"])
				piece_nodes[pos] = piece_node

func _on_piece_selected(pos: Vector2i, _info: Dictionary) -> void:
	_clear_highlights()
	if tiles.has(pos):
		tiles[pos].set_highlight(true, false)

	for move in chess_board.cached_legal_moves:
		var target: Vector2i = move["to"]
		if tiles.has(target):
			tiles[target].set_highlight(true, move.get("is_capture", false))

func _clear_highlights() -> void:
	for tile in tiles.values():
		tile.set_highlight(false)

func _on_duel_triggered(attacker: Dictionary, victim: Dictionary, board_pos: Vector2i) -> void:
	var world_pos = Vector2(board_pos.x * TILE_SIZE + TILE_SIZE * 0.5, board_pos.y * TILE_SIZE + TILE_SIZE * 0.5)
	if has_node("/root/DuelDirector"):
		get_node("/root/DuelDirector").start_cinematic_duel(attacker, victim, world_pos)
