class_name ChessPieceData
extends Resource

## Data container representing a piece on the board with Duel Combat stats

@export var type: GameEnums.PieceType = GameEnums.PieceType.PAWN
@export var color: GameEnums.PieceColor = GameEnums.PieceColor.WHITE

@export var grid_position: Vector2i = Vector2i.ZERO
@export var has_moved: bool = false

# Duel Combat RPG/Action Stats
@export var max_hp: float = 100.0
@export var current_hp: float = 100.0
@export var attack_power: float = 20.0
@export var defense_power: float = 5.0
@export var move_speed: float = 220.0
@export var crit_chance: float = 0.10
@export var special_name: String = "Strike"
@export var special_cooldown: float = 4.0

static func create(piece_type: GameEnums.PieceType, piece_color: GameEnums.PieceColor, pos: Vector2i) -> ChessPieceData:
	var piece = ChessPieceData.new()
	piece.type = piece_type
	piece.color = piece_color
	piece.grid_position = pos
	piece.has_moved = false
	piece._init_stats_by_type()
	return piece

func _init_stats_by_type() -> void:
	match type:
		GameEnums.PieceType.PAWN:
			max_hp = 100.0
			attack_power = 22.0
			defense_power = 5.0
			move_speed = 210.0
			crit_chance = 0.15
			special_name = "Underdog Rush"
			special_cooldown = 3.5

		GameEnums.PieceType.KNIGHT:
			max_hp = 190.0
			attack_power = 34.0
			defense_power = 12.0
			move_speed = 280.0
			crit_chance = 0.20
			special_name = "Flanking Charge"
			special_cooldown = 4.0

		GameEnums.PieceType.BISHOP:
			max_hp = 160.0
			attack_power = 38.0
			defense_power = 8.0
			move_speed = 250.0
			crit_chance = 0.25
			special_name = "Diagonal Smite"
			special_cooldown = 3.5

		GameEnums.PieceType.ROOK:
			max_hp = 260.0
			attack_power = 42.0
			defense_power = 25.0
			move_speed = 180.0
			crit_chance = 0.10
			special_name = "Castle Slam"
			special_cooldown = 5.0

		GameEnums.PieceType.QUEEN:
			max_hp = 320.0
			attack_power = 55.0
			defense_power = 18.0
			move_speed = 270.0
			crit_chance = 0.30
			special_name = "Royal Judgement"
			special_cooldown = 3.0

		GameEnums.PieceType.KING:
			max_hp = 360.0
			attack_power = 40.0
			defense_power = 30.0
			move_speed = 190.0
			crit_chance = 0.15
			special_name = "Monarch's Decree"
			special_cooldown = 4.5

		_:
			max_hp = 100.0
			attack_power = 20.0
			defense_power = 5.0
			move_speed = 200.0

	current_hp = max_hp

func take_damage(amount: float) -> float:
	var actual_dmg = maxf(1.0, amount - (defense_power * 0.35))
	current_hp = clampf(current_hp - actual_dmg, 0.0, max_hp)
	return actual_dmg

func is_alive() -> bool:
	return current_hp > 0.001

func heal_full() -> void:
	current_hp = max_hp
