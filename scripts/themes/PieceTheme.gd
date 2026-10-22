class_name PieceTheme
extends Resource

## Piece Theme Resource
## Configures visual 3D piece mesh models, board materials, and theme-specific lighting/emissive colors.

@export var theme_name: String = ""

@export_group("Piece Meshes")
@export var pawn_mesh: Resource
@export var knight_mesh: Resource
@export var bishop_mesh: Resource
@export var rook_mesh: Resource
@export var queen_mesh: Resource
@export var king_mesh: Resource

@export_group("Theme Visuals")
@export var board_material: Material
@export var emissive_color: Color = Color.WHITE

@export_group("Piece Materials (Optional Overrides)")
@export var white_piece_material: Material
@export var black_piece_material: Material

const PIECE_3D_SCENE_PATHS = {
	"P": "res://scenes/pieces/Piece3D_Pawn.tscn",
	"N": "res://scenes/pieces/Piece3D_Knight.tscn",
	"B": "res://scenes/pieces/Piece3D_Bishop.tscn",
	"R": "res://scenes/pieces/Piece3D_Rook.tscn",
	"Q": "res://scenes/pieces/Piece3D_Queen.tscn",
	"K": "res://scenes/pieces/Piece3D_King.tscn"
}

## Lookup helper to get the corresponding mesh for standard chess notation
func get_piece_mesh(piece_type: String) -> Resource:
	match piece_type.to_upper():
		"P": return pawn_mesh
		"N": return knight_mesh
		"B": return bishop_mesh
		"R": return rook_mesh
		"Q": return queen_mesh
		"K": return king_mesh
		_: return null

## Returns a dictionary of all piece meshes for quick iteration
func get_all_meshes() -> Dictionary:
	return {
		"P": pawn_mesh,
		"N": knight_mesh,
		"B": bishop_mesh,
		"R": rook_mesh,
		"Q": queen_mesh,
		"K": king_mesh
	}

## Get the PackedScene for the modular 3D piece of the given type
func get_piece_scene(piece_type: String) -> PackedScene:
	var key = piece_type.to_upper()
	if PIECE_3D_SCENE_PATHS.has(key):
		var path = PIECE_3D_SCENE_PATHS[key]
		if ResourceLoader.exists(path):
			return load(path)
	return null

## Convenience helper to instantiate and initialize a 3D piece with this theme
func instantiate_3d_piece(piece_type: String, color: String = "white") -> Node3D:
	var scn = get_piece_scene(piece_type)
	if scn:
		var node = scn.instantiate()
		if node.has_method("setup"):
			node.setup(piece_type, color, self)
		return node
	return null
