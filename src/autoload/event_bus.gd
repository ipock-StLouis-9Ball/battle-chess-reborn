extends Node

## Central Event Bus for Duel of Kings: Animated Chess
## Provides decoupled pub/sub signal architecture across game systems.

# --- Game Flow & State Signals ---
signal game_state_changed(new_state: GameEnums.GameState, old_state: GameEnums.GameState)
signal match_started(mode: GameEnums.GameMode, ai_difficulty: GameEnums.AIDifficulty)
signal match_paused(is_paused: bool)
signal match_ended(winner_color: GameEnums.PieceColor, reason: String)
signal turn_changed(active_color: GameEnums.PieceColor, turn_number: int)

# --- Chess Board Interaction Signals ---
signal tile_hovered(grid_pos: Vector2i)
signal tile_unhovered(grid_pos: Vector2i)
signal tile_selected(grid_pos: Vector2i, piece_data: Resource)
signal selection_cleared()
signal valid_moves_updated(moves: Array)
signal move_executed(from_pos: Vector2i, to_pos: Vector2i, is_attack: bool)
signal piece_promoted(pos: Vector2i, new_type: GameEnums.PieceType)
signal check_alert(king_color: GameEnums.PieceColor)
signal checkmate_alert(winner_color: GameEnums.PieceColor)
signal stalemate_alert()

# --- Duel Arena Signals (Combat Chess Core) ---
signal duel_triggered(attacker: Resource, defender: Resource, battle_pos: Vector2i)
signal duel_countdown_started(duration: float)
signal duel_health_changed(fighter_side: int, current_hp: float, max_hp: float) # 0=attacker, 1=defender
signal duel_clash_occurred(damage: float, is_critical: bool, position: Vector2)
signal duel_special_triggered(fighter_side: int, ability_name: String)
signal duel_completed(winner_side: int, winner_data: Resource, loser_data: Resource, battle_pos: Vector2i)

# --- Platform & Input Signals ---
signal platform_detected(platform_type: GameEnums.PlatformType, details: Dictionary)
signal input_scheme_changed(scheme: GameEnums.InputScheme)
signal safe_area_changed(safe_area_rect: Rect2i)
signal haptic_feedback_requested(duration_ms: int)

# --- Audio & VFX Signals ---
signal play_sfx_requested(sound_id: String, bus: String)
signal play_music_requested(music_id: String, crossfade: float)
signal screen_shake_requested(intensity: float, duration: float)

# --- Settings & Save Signals ---
signal settings_saved()
signal settings_loaded()
signal profile_updated(stats: Dictionary)
