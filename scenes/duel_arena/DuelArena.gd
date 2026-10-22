class_name DuelArenaView
extends Control

## Cinematic Duel Arena Overlay
## Displays letterbox bars, KillMatrix 3-act narrative execution, slow-motion badges, and impact VFX

@onready var letterbox_top: ColorRect = $LetterboxTop
@onready var letterbox_bottom: ColorRect = $LetterboxBottom
@onready var narrative_label: Label = $NarrativePanel/Label
@onready var slowmo_badge: Label = $SlowMoBadge
@onready var clock_paused_badge: Label = $ClockPausedBadge

func _ready() -> void:
	visible = false
	if has_node("/root/DuelDirector"):
		var dd = get_node("/root/DuelDirector")
		dd.duel_started.connect(_on_duel_started)
		dd.duel_act_started.connect(_on_duel_act_started)
		dd.duel_impact_hit.connect(_on_duel_impact)
		dd.duel_completed.connect(_on_duel_completed)
		dd.slow_motion_changed.connect(_on_slow_motion_changed)
		dd.chess_clock_paused.connect(_on_clock_paused)

func _on_duel_started(_attacker: Dictionary, _victim: Dictionary, anim_data: Dictionary) -> void:
	visible = true
	narrative_label.text = anim_data.get("narrative", "3D Combat Duel Commencing!")
	slowmo_badge.visible = false

	# Animate letterbox entrance
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(letterbox_top, "custom_minimum_size:y", 80.0, 0.3)
	tween.parallel().tween_property(letterbox_bottom, "custom_minimum_size:y", 80.0, 0.3)

func _on_duel_act_started(act_number: int, act_name: String, description: String) -> void:
	narrative_label.text = "⚔️ ACT %d: %s\n%s" % [act_number, act_name.to_upper(), description]
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	narrative_label.modulate = Color(1.4, 1.3, 0.7, 1.0)
	tw.tween_property(narrative_label, "modulate", Color.WHITE, 0.35)

func _on_duel_impact(_anim_data: Dictionary) -> void:
	# Flash effect
	var flash = create_tween()
	flash.tween_property(self, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.05)
	flash.tween_property(self, "modulate", Color.WHITE, 0.15)

func _on_slow_motion_changed(time_scale: float) -> void:
	slowmo_badge.visible = (time_scale < 0.9)

func _on_clock_paused(is_paused: bool) -> void:
	clock_paused_badge.visible = is_paused

func _on_duel_completed(_attacker: Dictionary, _victim: Dictionary) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(letterbox_top, "custom_minimum_size:y", 0.0, 0.25)
	tween.parallel().tween_property(letterbox_bottom, "custom_minimum_size:y", 0.0, 0.25)
	await tween.finished
	visible = false
