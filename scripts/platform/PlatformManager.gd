extends Node

## Platform Manager & Feature Flags
## Manages Steam PC ($9.99 Upfront) and Mobile ($9.99 Full Game Unlock) unified monetization,
## Samsung Galaxy display safe-areas, high-refresh rates, and platform input routing.

signal feature_flags_updated()
signal full_game_unlock_changed(is_unlocked: bool)
signal premium_pass_status_changed(is_unlocked: bool) # Backward compatibility alias
signal safe_area_changed(margins: Dictionary)

enum TargetPlatform {
	STEAM_PC,
	STEAM_DECK,
	ANDROID_GALAXY,
	ANDROID_GENERIC,
	STANDALONE
}

const SAVE_PATH: String = "user://license_data.json"

var current_platform: TargetPlatform = TargetPlatform.STANDALONE
var is_samsung_galaxy: bool = false
var device_model: String = ""
var display_refresh_rate: float = 60.0
var device_refresh_rate: float = 60.0

# Feature Flags
var is_steam_edition: bool = false
var has_full_game_unlock: bool = false # Unified $9.99 Mobile Full Game Unlock
var has_premium_pass: bool:
	get: return has_full_game_unlock
	set(val): has_full_game_unlock = val

var all_themes_unlocked: bool = false
var all_duels_unlocked: bool = true # Capture duels active across all tiers
var ranked_multiplayer_unlocked: bool = false
var replay_theater_unlocked: bool = false
var ad_free: bool = true
var steam_achievements_enabled: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_detect_platform()
	_detect_display()
	_load_license_data()
	_apply_feature_flags()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_android_back_button()

func _detect_platform() -> void:
	var os_name = OS.get_name()
	device_model = OS.get_model_name()

	if os_name == "Android":
		if device_model.begins_with("SM-") or device_model.to_lower().contains("samsung") or device_model.to_lower().contains("galaxy"):
			is_samsung_galaxy = true
			current_platform = TargetPlatform.ANDROID_GALAXY
		else:
			current_platform = TargetPlatform.ANDROID_GENERIC
		is_steam_edition = false
	elif os_name in ["Windows", "Linux", "macOS"]:
		if OS.has_feature("steamdeck") or OS.get_environment("SteamDeck") == "1":
			current_platform = TargetPlatform.STEAM_DECK
		else:
			current_platform = TargetPlatform.STEAM_PC
		is_steam_edition = true
	else:
		current_platform = TargetPlatform.STANDALONE
		is_steam_edition = false

func _detect_display() -> void:
	display_refresh_rate = 60.0
	if DisplayServer.has_feature(DisplayServer.FEATURE_SCREEN):
		var screen_count = DisplayServer.get_screen_count()
		if screen_count > 0:
			var screen_id = DisplayServer.window_get_current_screen()
			if screen_id >= 0 and screen_id < screen_count:
				display_refresh_rate = DisplayServer.screen_get_refresh_rate(screen_id)
			else:
				display_refresh_rate = DisplayServer.screen_get_refresh_rate(0)
	if display_refresh_rate <= 0.0:
		display_refresh_rate = 60.0
	device_refresh_rate = display_refresh_rate

func _load_license_data() -> void:
	if is_steam_edition:
		# Steam $9.99 model: full ownership upfront
		has_full_game_unlock = true
		return

	# Android license check
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				has_full_game_unlock = parsed.get("has_full_game_unlock", parsed.get("has_premium_pass", false))
			file.close()

func _save_license_data() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"has_full_game_unlock": has_full_game_unlock,
			"has_premium_pass": has_full_game_unlock
		}
		file.store_string(JSON.stringify(data))
		file.close()

func _apply_feature_flags() -> void:
	if is_steam_edition or has_full_game_unlock:
		# Unified $9.99 Full Game: 100% Unlocked across Steam PC & Mobile
		all_themes_unlocked = true
		all_duels_unlocked = true
		ranked_multiplayer_unlocked = true
		replay_theater_unlocked = true
		ad_free = true
		steam_achievements_enabled = is_steam_edition
	else:
		# Free Mobile Trial Tier: High Fantasy unlocked, Cyberpunk & Eldritch locked
		all_themes_unlocked = false
		all_duels_unlocked = true
		ranked_multiplayer_unlocked = false
		replay_theater_unlocked = false
		ad_free = false
		steam_achievements_enabled = false

	feature_flags_updated.emit()

## Unlock Mobile $9.99 Unified 'Full Game Unlock'
func purchase_full_game() -> void:
	has_full_game_unlock = true
	_save_license_data()
	_apply_feature_flags()
	full_game_unlock_changed.emit(true)
	premium_pass_status_changed.emit(true)

## Backward compatibility alias
func purchase_premium_pass() -> void:
	purchase_full_game()

func is_theme_unlocked(theme_name: String) -> bool:
	if all_themes_unlocked or is_steam_edition:
		return true
	# In free mobile trial tier, only High Fantasy is available
	return theme_name.to_lower() == "high_fantasy"

func get_store_pricing_label() -> String:
	if is_steam_edition:
		return "Steam PC Edition - $9.99 (Full Game Unlocked)"
	elif has_full_game_unlock:
		return "Mobile Edition - Full Game Unlocked ($9.99)"
	else:
		return "Free Trial (Full Game Unlock: $9.99 - All Themes & Ranked)"

func get_safe_area_margins() -> Dictionary:
	var screen_size = DisplayServer.screen_get_size()
	var safe_rect = DisplayServer.get_display_safe_area()
	if screen_size.x <= 0 or screen_size.y <= 0 or safe_rect.size == Vector2i.ZERO:
		return {"left": 0, "top": 0, "right": 0, "bottom": 0}

	return {
		"left": maxi(0, safe_rect.position.x),
		"top": maxi(0, safe_rect.position.y),
		"right": maxi(0, screen_size.x - (safe_rect.position.x + safe_rect.size.x)),
		"bottom": maxi(0, screen_size.y - (safe_rect.position.y + safe_rect.size.y))
	}

func trigger_haptic(duration_ms: int = 40) -> void:
	if is_android():
		Input.vibrate_handheld(duration_ms)

func is_mobile() -> bool:
	return is_android()

func is_android() -> bool:
	return current_platform == TargetPlatform.ANDROID_GALAXY or current_platform == TargetPlatform.ANDROID_GENERIC

func is_desktop() -> bool:
	return current_platform == TargetPlatform.STEAM_PC or current_platform == TargetPlatform.STEAM_DECK

func set_keep_screen_on(enabled: bool) -> void:
	DisplayServer.screen_set_keep_on(enabled)

func get_safe_area() -> Rect2i:
	return DisplayServer.get_display_safe_area()

func _handle_android_back_button() -> void:
	if get_tree().paused:
		get_tree().paused = false
	else:
		get_tree().paused = true
