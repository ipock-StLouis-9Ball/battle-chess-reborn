class_name FighterBase
extends CharacterBody2D

## Action Fighter entity in the Duel Arena
## Represents a chess piece transformed into a real-time combat gladiator.

signal health_changed(new_hp: float, max_hp: float)
signal state_changed(new_state: GameEnums.FighterState)
signal attack_hit(target: FighterBase, damage: float, is_crit: bool)

@export var is_player_controlled: bool = true
@export var fighter_side: int = 0 # 0 = Attacker (Left), 1 = Defender (Right)

var piece_data: ChessPieceData
var current_state: GameEnums.FighterState = GameEnums.FighterState.IDLE

# Stats
var max_hp: float = 100.0
var current_hp: float = 100.0
var attack_power: float = 25.0
var defense_power: float = 8.0
var move_speed: float = 240.0
var crit_chance: float = 0.15
var special_name: String = "Strike"
var special_cooldown_max: float = 4.0
var special_cooldown_timer: float = 0.0

# Combat physics & state flags
var facing_direction: float = 1.0 # 1.0 = facing right, -1.0 = facing left
var input_vector: Vector2 = Vector2.ZERO
var attack_combo_index: int = 0
var attack_timer: float = 0.0
var dodge_timer: float = 0.0
var hurt_timer: float = 0.0
var is_invulnerable: bool = false

# Visual nodes
@onready var visual_root: Node2D = $Visuals
@onready var sprite_symbol: Label = $Visuals/SymbolLabel
@onready var body_rect: ColorRect = $Visuals/BodyRect
@onready var hit_box: Area2D = $Visuals/HitBox
@onready var hurt_box: Area2D = $HurtBox
@onready var anim_tween: Tween

func _ready() -> void:
	if hit_box:
		hit_box.area_entered.connect(_on_hit_box_entered)
		_set_hitbox_active(false)

func setup_fighter(data: ChessPieceData, side: int, is_human: bool) -> void:
	piece_data = data
	fighter_side = side
	is_player_controlled = is_human

	max_hp = data.max_hp
	current_hp = data.current_hp
	attack_power = data.attack_power
	defense_power = data.defense_power
	move_speed = data.move_speed
	crit_chance = data.crit_chance
	special_name = data.special_name
	special_cooldown_max = data.special_cooldown

	facing_direction = 1.0 if side == 0 else -1.0
	_apply_visual_styling()

func _apply_visual_styling() -> void:
	if piece_data == null:
		return
	
	sprite_symbol.text = MathHelpers.piece_symbol(piece_data.type, piece_data.color)
	
	if piece_data.color == GameEnums.PieceColor.WHITE:
		body_rect.color = Color(0.9, 0.92, 0.96, 0.95)
		sprite_symbol.add_theme_color_override("font_color", Color(0.1, 0.15, 0.25, 1.0))
	else:
		body_rect.color = Color(0.15, 0.16, 0.22, 0.95)
		sprite_symbol.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3, 1.0))

	_update_facing()

func _physics_process(delta: float) -> void:
	if special_cooldown_timer > 0.0:
		special_cooldown_timer = maxf(0.0, special_cooldown_timer - delta)

	match current_state:
		GameEnums.FighterState.IDLE, GameEnums.FighterState.RUN:
			_process_movement(delta)

		GameEnums.FighterState.ATTACK_LIGHT, GameEnums.FighterState.ATTACK_HEAVY, GameEnums.FighterState.SPECIAL:
			_process_attack_state(delta)

		GameEnums.FighterState.DODGE:
			_process_dodge_state(delta)

		GameEnums.FighterState.HURT:
			_process_hurt_state(delta)

		GameEnums.FighterState.VICTORY, GameEnums.FighterState.DEFEAT:
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			move_and_slide()

func _process_movement(delta: float) -> void:
	if input_vector.length_squared() > 0.01:
		velocity = input_vector.normalized() * move_speed
		if current_state != GameEnums.FighterState.RUN:
			_change_state(GameEnums.FighterState.RUN)
		# Face direction of horizontal motion
		if abs(input_vector.x) > 0.1:
			facing_direction = signf(input_vector.x)
			_update_facing()
	else:
		velocity = velocity.move_toward(Vector2.ZERO, move_speed * 6.0 * delta)
		if current_state != GameEnums.FighterState.IDLE:
			_change_state(GameEnums.FighterState.IDLE)

	move_and_slide()

func _process_attack_state(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, move_speed * 4.0 * delta)
	move_and_slide()
	attack_timer -= delta
	if attack_timer <= 0.0:
		_set_hitbox_active(false)
		_change_state(GameEnums.FighterState.IDLE)

func _process_dodge_state(delta: float) -> void:
	# Keep moving fast in dodge direction
	move_and_slide()
	dodge_timer -= delta
	if dodge_timer <= 0.0:
		is_invulnerable = false
		_change_state(GameEnums.FighterState.IDLE)

func _process_hurt_state(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, move_speed * 5.0 * delta)
	move_and_slide()
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		_change_state(GameEnums.FighterState.IDLE)

func execute_light_attack() -> bool:
	if not _can_act():
		return false

	_change_state(GameEnums.FighterState.ATTACK_LIGHT)
	attack_timer = 0.28
	velocity = Vector2(facing_direction * (move_speed * 0.8), 0.0)
	
	_trigger_visual_lunge(0.2)
	_set_hitbox_active(true)
	EventBus.play_sfx_requested.emit("move", "Combat")
	return true

func execute_heavy_attack() -> bool:
	if not _can_act():
		return false

	_change_state(GameEnums.FighterState.ATTACK_HEAVY)
	attack_timer = 0.45
	velocity = Vector2(facing_direction * (move_speed * 0.4), 0.0)
	
	_trigger_visual_heavy_windup()
	_set_hitbox_active(true)
	EventBus.play_sfx_requested.emit("move", "Combat")
	return true

func execute_dodge() -> bool:
	if not _can_act():
		return false

	_change_state(GameEnums.FighterState.DODGE)
	is_invulnerable = true
	dodge_timer = 0.32
	
	var dodge_dir = input_vector.normalized() if input_vector.length_squared() > 0.01 else Vector2(facing_direction, 0.0)
	velocity = dodge_dir * (move_speed * 1.8)
	
	_trigger_dodge_ghost()
	PlatformManager.trigger_haptic(20)
	return true

func execute_special() -> bool:
	if not _can_act() or special_cooldown_timer > 0.001:
		return false

	special_cooldown_timer = special_cooldown_max
	_change_state(GameEnums.FighterState.SPECIAL)
	attack_timer = 0.55
	velocity = Vector2(facing_direction * (move_speed * 1.4), 0.0)

	_trigger_special_burst()
	_set_hitbox_active(true)
	EventBus.duel_special_triggered.emit(fighter_side, special_name)
	EventBus.play_sfx_requested.emit("duel_start", "Combat")
	PlatformManager.trigger_haptic(50)
	return true

func take_damage(damage: float, is_crit: bool, attacker_pos: Vector2) -> void:
	if is_invulnerable or current_state == GameEnums.FighterState.DEFEAT:
		return

	var actual_dmg = piece_data.take_damage(damage) if piece_data != null else damage
	current_hp = piece_data.current_hp if piece_data != null else maxf(0.0, current_hp - actual_dmg)
	health_changed.emit(current_hp, max_hp)
	EventBus.duel_health_changed.emit(fighter_side, current_hp, max_hp)
	EventBus.duel_clash_occurred.emit(actual_dmg, is_crit, global_position)
	EventBus.screen_shake_requested.emit(8.0 if is_crit else 4.0, 0.2)
	PlatformManager.trigger_haptic(45 if is_crit else 25)

	# Knockback
	var knockback_dir = (global_position - attacker_pos).normalized()
	velocity = knockback_dir * (180.0 if not is_crit else 300.0)

	if current_hp <= 0.001:
		_die()
	else:
		_change_state(GameEnums.FighterState.HURT)
		hurt_timer = 0.22
		_trigger_hurt_flash()

func _die() -> void:
	_change_state(GameEnums.FighterState.DEFEAT)
	_set_hitbox_active(false)
	is_invulnerable = true
	var tween = create_tween()
	tween.tween_property(visual_root, "rotation", deg_to_rad(90.0 * facing_direction), 0.3)
	tween.parallel().tween_property(visual_root, "scale", Vector2(0.8, 0.8), 0.3)
	tween.parallel().tween_property(visual_root, "modulate:a", 0.5, 0.4)

func set_victory() -> void:
	_change_state(GameEnums.FighterState.VICTORY)
	_set_hitbox_active(false)
	velocity = Vector2.ZERO
	var tween = create_tween().set_loops(3)
	tween.tween_property(visual_root, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(visual_root, "scale", Vector2.ONE, 0.15)

func _can_act() -> bool:
	return current_state == GameEnums.FighterState.IDLE or current_state == GameEnums.FighterState.RUN

func _change_state(new_state: GameEnums.FighterState) -> void:
	current_state = new_state
	state_changed.emit(new_state)

func _update_facing() -> void:
	visual_root.scale.x = abs(visual_root.scale.x) * facing_direction

func _set_hitbox_active(active: bool) -> void:
	if hit_box:
		hit_box.monitoring = active
		hit_box.monitorable = active
		for child in hit_box.get_children():
			if child is CollisionShape2D:
				child.disabled = not active

func _on_hit_box_entered(area: Area2D) -> void:
	if area == hurt_box:
		return
	var target_fighter = area.get_parent() as FighterBase
	if target_fighter and target_fighter != self and target_fighter.fighter_side != fighter_side:
		var is_crit = (randf() < crit_chance)
		var dmg = attack_power * (1.8 if is_crit else 1.0)
		if current_state == GameEnums.FighterState.ATTACK_HEAVY:
			dmg *= 1.5
		elif current_state == GameEnums.FighterState.SPECIAL:
			dmg *= 2.0
		target_fighter.take_damage(dmg, is_crit, global_position)
		attack_hit.emit(target_fighter, dmg, is_crit)
		_set_hitbox_active(false)

func _trigger_visual_lunge(dur: float) -> void:
	var tween = create_tween()
	tween.tween_property(visual_root, "position:x", 20.0 * facing_direction, dur * 0.4)
	tween.tween_property(visual_root, "position:x", 0.0, dur * 0.6)

func _trigger_visual_heavy_windup() -> void:
	var tween = create_tween()
	tween.tween_property(visual_root, "position:x", -15.0 * facing_direction, 0.15)
	tween.tween_property(visual_root, "scale", Vector2(1.3, 1.3), 0.15)
	tween.chain().tween_property(visual_root, "position:x", 35.0 * facing_direction, 0.1)
	tween.parallel().tween_property(visual_root, "scale", Vector2.ONE, 0.1)
	tween.chain().tween_property(visual_root, "position:x", 0.0, 0.2)

func _trigger_dodge_ghost() -> void:
	var tween = create_tween()
	tween.tween_property(visual_root, "modulate:a", 0.3, 0.15)
	tween.tween_property(visual_root, "modulate:a", 1.0, 0.15)

func _trigger_special_burst() -> void:
	var tween = create_tween()
	tween.tween_property(visual_root, "modulate", Color(2.5, 2.0, 0.5, 1.0), 0.15)
	tween.tween_property(visual_root, "modulate", Color.WHITE, 0.3)

func _trigger_hurt_flash() -> void:
	var tween = create_tween()
	tween.tween_property(visual_root, "modulate", Color(3.0, 0.3, 0.3, 1.0), 0.08)
	tween.tween_property(visual_root, "modulate", Color.WHITE, 0.14)
