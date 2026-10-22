extends Node

## Central Event Bus for Duel of Kings: Animated Chess
## Provides decoupled pub/sub signal architecture across game systems.
## All signal parameters are untyped to eliminate cyclic compile-time enum dependencies.

# --- Game Flow & State Signals ---
signal game_state_changed(new_state, old_state)
signal match_started(mode, ai_difficulty)
signal match_paused(is_paused)
signal match_ended(winner_color, reason)
signal turn_changed(active_color, turn_number)

# --- Chess Board Interaction Signals ---
signal tile_hovered(grid_pos)
signal tile_unhovered(grid_pos)
signal tile_selected(grid_pos, piece_data)
signal selection_cleared()
signal valid_moves_updated(moves)
signal move_executed(from_pos, to_pos, is_attack)
signal piece_promoted(pos, new_type)
signal check_alert(king_color)
signal checkmate_alert(winner_color)
signal stalemate_alert()

# --- Duel Arena Signals (Combat Chess Core) ---
signal duel_triggered(attacker, defender, battle_pos)
signal duel_countdown_started(duration)
signal duel_health_changed(fighter_side, current_hp, max_hp)
signal duel_clash_occurred(damage, is_critical, position)
signal duel_special_triggered(fighter_side, ability_name)
signal duel_completed(winner_side, winner_data, loser_data, battle_pos)

# --- Platform & Input Signals ---
signal platform_detected(platform_type, details)
signal input_scheme_changed(scheme)
signal safe_area_changed(safe_area_rect)
signal haptic_feedback_requested(duration_ms)

# --- Audio & VFX Signals ---
signal play_sfx_requested(sound_id, bus)
signal play_music_requested(music_id, crossfade)
signal screen_shake_requested(intensity, duration)

# --- Settings & Save Signals ---
signal settings_saved()
signal settings_loaded()
signal profile_updated(stats)
