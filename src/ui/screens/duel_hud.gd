class_name DuelHUD
extends Control

## Duel Combat HUD
## Displays health bars, piece portraits, special attack indicators, and touch controls

@onready var atk_name_label: Label = $SafeArea/CombatantBars/AttackerBox/NameLabel
@onready var atk_hp_bar: ProgressBar = $SafeArea/CombatantBars/AttackerBox/HPBar
@onready var atk_symbol_label: Label = $SafeArea/CombatantBars/AttackerBox/IconLabel

@onready var def_name_label: Label = $SafeArea/CombatantBars/DefenderBox/NameLabel
@onready var def_hp_bar: ProgressBar = $SafeArea/CombatantBars/DefenderBox/HPBar
@onready var def_symbol_label: Label = $SafeArea/CombatantBars/DefenderBox/IconLabel

@onready var virtual_joystick: VirtualJoystick = $SafeArea/TouchControls/VirtualJoystick
@onready var touch_buttons: TouchActionButtons = $SafeArea/TouchControls/TouchActionButtons

func _ready() -> void:
	EventBus.duel_triggered.connect(_on_duel_triggered)
	EventBus.duel_health_changed.connect(_on_health_changed)

func _on_duel_triggered(attacker: Resource, defender: Resource, _pos: Vector2i) -> void:
	var atk = attacker as ChessPieceData
	var def = defender as ChessPieceData

	if atk:
		atk_name_label.text = "%s (%s)" % [MathHelpers.piece_type_to_name(atk.type), MathHelpers.color_to_name(atk.color)]
		atk_symbol_label.text = MathHelpers.piece_symbol(atk.type, atk.color)
		atk_hp_bar.max_value = atk.max_hp
		atk_hp_bar.value = atk.current_hp

	if def:
		def_name_label.text = "%s (%s)" % [MathHelpers.piece_type_to_name(def.type), MathHelpers.color_to_name(def.color)]
		def_symbol_label.text = MathHelpers.piece_symbol(def.type, def.color)
		def_hp_bar.max_value = def.max_hp
		def_hp_bar.value = def.current_hp

func _on_health_changed(side: int, current: float, max_v: float) -> void:
	if side == 0:
		atk_hp_bar.max_value = max_v
		atk_hp_bar.value = current
	else:
		def_hp_bar.max_value = max_v
		def_hp_bar.value = current
