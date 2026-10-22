class_name DuelArena
extends Node2D

## Tactical Duel Arena
## Where pieces clash in real-time combat to claim squares on the board

@export var fighter_scene: PackedScene = preload("res://src/combat/fighters/fighter_base.tscn")

@onready var camera: DuelCamera = $DuelCamera
@onready var spawn_left: Marker2D = $SpawnPoints/SpawnLeft
@onready var spawn_right: Marker2D = $SpawnPoints/SpawnRight
@onready var announcement_label: Label = $CanvasLayer/AnnouncementLabel
@onready var round_timer_label: Label = $CanvasLayer/TimerLabel

var attacker_fighter: FighterBase
var defender_fighter: FighterBase
var player_controller: FighterControllerPlayer
var ai_controller: FighterControllerAI

var duel_tile_pos: Vector2i
var round_time_remaining: float = 30.0
var is_duel_active: bool = false
var is_resolving: bool = false

func _ready() -> void:
	EventBus.duel_triggered.connect(start_duel)

func start_duel(attacker_data: Resource, defender_data: Resource, target_tile: Vector2i) -> void:
	duel_tile_pos = target_tile
	is_resolving = false
	visible = true

	# Fast Auto-Resolution check
	if SettingsManager.auto_resolve_duels:
		_auto_resolve_duel(attacker_data as ChessPieceData, defender_data as ChessPieceData)
		return

	_cleanup_previous_fighters()

	# Spawn Attacker (Side 0)
	attacker_fighter = fighter_scene.instantiate()
	attacker_fighter.position = spawn_left.position
	add_child(attacker_fighter)
	var attacker_is_human = (attacker_data.color == GameEnums.PieceColor.WHITE or GameManager.current_mode == GameEnums.GameMode.LOCAL_PASS_AND_PLAY)
	attacker_fighter.setup_fighter(attacker_data as ChessPieceData, 0, attacker_is_human)

	# Spawn Defender (Side 1)
	defender_fighter = fighter_scene.instantiate()
	defender_fighter.position = spawn_right.position
	add_child(defender_fighter)
	var defender_is_human = (defender_data.color == GameEnums.PieceColor.WHITE and GameManager.current_mode == GameEnums.GameMode.LOCAL_PASS_AND_PLAY)
	defender_fighter.setup_fighter(defender_data as ChessPieceData, 1, defender_is_human)

	# Attach controllers
	if attacker_is_human:
		player_controller = FighterControllerPlayer.new()
		player_controller.fighter = attacker_fighter
		attacker_fighter.add_child(player_controller)
	else:
		var ai_atk = FighterControllerAI.new()
		ai_atk.fighter = attacker_fighter
		ai_atk.opponent = defender_fighter
		ai_atk.difficulty = SettingsManager.ai_duel_difficulty
		attacker_fighter.add_child(ai_atk)

	if defender_is_human:
		var p2_ctrl = FighterControllerPlayer.new()
		p2_ctrl.fighter = defender_fighter
		defender_fighter.add_child(p2_ctrl)
	else:
		ai_controller = FighterControllerAI.new()
		ai_controller.fighter = defender_fighter
		ai_controller.opponent = attacker_fighter
		ai_controller.difficulty = SettingsManager.ai_duel_difficulty
		defender_fighter.add_child(ai_controller)

	camera.setup_targets(attacker_fighter, defender_fighter)
	_run_countdown_sequence()

func _cleanup_previous_fighters() -> void:
	if is_instance_valid(attacker_fighter):
		attacker_fighter.queue_free()
	if is_instance_valid(defender_fighter):
		defender_fighter.queue_free()

func _run_countdown_sequence() -> void:
	is_duel_active = false
	round_time_remaining = 30.0
	round_timer_label.text = "30"

	announcement_label.visible = true
	announcement_label.text = "READY..."
	announcement_label.scale = Vector2(0.5, 0.5)
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(announcement_label, "scale", Vector2.ONE, 0.4)
	
	await get_tree().create_timer(0.6).timeout
	announcement_label.text = "FIGHT!"
	EventBus.play_sfx_requested.emit("duel_start", "Combat")
	
	await get_tree().create_timer(0.5).timeout
	announcement_label.visible = false
	is_duel_active = true

func _process(delta: float) -> void:
	if not is_duel_active or is_resolving:
		return

	round_time_remaining -= delta
	round_timer_label.text = str(maxi(0, int(round_time_remaining)))

	# Check fighter HP
	if attacker_fighter.current_hp <= 0.001:
		_conclude_duel(1) # Defender won
	elif defender_fighter.current_hp <= 0.001:
		_conclude_duel(0) # Attacker won
	elif round_time_remaining <= 0.0:
		# Time out: Fighter with higher remaining health % wins!
		var atk_pct = attacker_fighter.current_hp / attacker_fighter.max_hp
		var def_pct = defender_fighter.current_hp / defender_fighter.max_hp
		if atk_pct >= def_pct:
			_conclude_duel(0)
		else:
			_conclude_duel(1)

func _conclude_duel(winner_side: int) -> void:
	if is_resolving:
		return
	is_resolving = true
	is_duel_active = false

	var winner_fighter = attacker_fighter if winner_side == 0 else defender_fighter
	var loser_fighter = defender_fighter if winner_side == 0 else attacker_fighter

	winner_fighter.set_victory()

	announcement_label.visible = true
	announcement_label.text = "%s WINS!" % MathHelpers.piece_type_to_name(winner_fighter.piece_data.type).to_upper()
	
	EventBus.play_sfx_requested.emit("victory", "Combat")
	PlatformManager.trigger_haptic(60)

	await get_tree().create_timer(1.2).timeout
	announcement_label.visible = false
	visible = false

	EventBus.duel_completed.emit(
		winner_side,
		winner_fighter.piece_data,
		loser_fighter.piece_data,
		duel_tile_pos
	)

func _auto_resolve_duel(attacker: ChessPieceData, defender: ChessPieceData) -> void:
	# Statistical simulation
	var atk_score = (attacker.attack_power * 1.5) + (attacker.current_hp * 0.4) + randf_range(-15.0, 15.0)
	var def_score = (defender.defense_power * 2.0) + (defender.current_hp * 0.4) + randf_range(-15.0, 15.0)

	var winner_side = 0 if atk_score >= def_score else 1
	var winner_data = attacker if winner_side == 0 else defender
	var loser_data = defender if winner_side == 0 else attacker

	# Winner takes chip damage
	winner_data.take_damage(randf_range(15.0, 35.0))

	visible = false
	EventBus.duel_completed.emit(winner_side, winner_data, loser_data, duel_tile_pos)
