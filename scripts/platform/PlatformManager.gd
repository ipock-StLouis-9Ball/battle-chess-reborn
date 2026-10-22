class_name PlatformManager
extends Node

## Platform Manager & Feature Flags
## Manages Steam ($9.99 all-unlocked) vs Android ($4.99 Premium Pass) feature gates,
## Samsung Galaxy display safe-areas, high-refresh rates, and platform input routing.

signal feature_flags_updated()
signal premium_pass_status_changed(is_unlocked: bool)
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

# Feature Flags
var is_steam_edition: bool = false
var has_premium_pass: bool = false # Android $4.99 IAP
var all_themes_unlocked: bool = false
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
	var screen_id = DisplayServer.window_get_current_screen()
	display_refresh_rate = DisplayServer.screen_get_refresh_rate(screen_id)
	if display_refresh_rate <= 0:
		display_refresh_rate = 60.0

func _load_license_data() -> void:
	if is_steam_edition:
		# Steam $9.99 model: full ownership upfront
		has_premium_pass = true
		return

	# Android license check
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				has_premium_pass = parsed.get("has_premium_pass", false)
			file.close()

func _save_license_data() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {"has_premium_pass": has_premium_pass}
		file.store_string(JSON.stringify(data))
		file.close()

func _apply_feature_flags() -> void:
	if is_steam_edition:
		# Steam ($9.99 Upfront) -> Everything unlocked
		all_themes_unlocked = true
		ranked_multiplayer_unlocked = true
		replay_theater_unlocked = true
		ad_free = true
		steam_achievements_enabled = true
	else:
		# Android Freemium + $4.99 Premium Pass
		if has_premium_pass:
			all_themes_unlocked = true
			ranked_multiplayer_unlocked = true
			replay_theater_unlocked = true
			ad_free = true
		else:
			# Free Android Tier: High Fantasy unlocked, Cyberpunk & Eldritch locked
			all_themes_unlocked = false
			ranked_multiplayer_unlocked = false
			replay_theater_unlocked = false
			ad_free = false
		steam_achievements_enabled = false

	feature_flags_updated.emit()

## Unlock Android $4.99 Premium Pass
func purchase_premium_pass() -> void:
	has_premium_pass = true
	_save_license_data()
	_apply_feature_flags()
	premium_pass_status_changed.emit(true)

func is_theme_unlocked(theme_name: String) -> bool:
	if all_themes_unlocked or is_steam_edition:
		return true
	# In free Android tier, only High Fantasy is available
	return theme_name.to_lower() == "high_fantasy"

func get_store_pricing_label() -> String:
	if is_steam_edition:
		return "Steam PC Edition - $9.99 (All Themes & Features Unlocked)"
	elif has_premium_pass:
		return "Android Premium Pass - Unlocked"
	else:
		return "Android Free Tier (Unlock All Themes & Ranked for $4.99)"

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

func is_android() -> bool:
	return current_platform == TargetPlatform.ANDROID_GALAXY or current_platform == TargetPlatform.ANDROID_GENERIC

func is_desktop() -> bool:
	return current_platform == TargetPlatform.STEAM_PC or current_platform == TargetPlatform.STEAM_DECK

func _handle_android_back_button() -> void:
	if get_tree().paused:
		get_tree().paused = false
	else:
		get_tree().paused = true
