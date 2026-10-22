extends Node

## Platform Manager & Feature Flags
## Consolidated Singleton in res://src/autoload/platform_manager.gd
## Manages Steam PC ($9.99 Upfront) and Mobile ($9.99 Full Game Unlock) unified monetization,
## Samsung Galaxy display safe-areas, high-refresh rates, haptic feedback, and platform input routing.

signal feature_flags_updated()
signal full_game_unlock_changed(is_unlocked: bool)
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
var current_platform_type: GameEnums.PlatformType = GameEnums.PlatformType.UNKNOWN
var current_input_scheme: GameEnums.InputScheme = GameEnums.InputScheme.KEYBOARD_MOUSE
var is_touch_device: bool = false
var is_samsung_galaxy: bool = false
var device_model: String = ""
var display_refresh_rate: float = 60.0
var device_refresh_rate: float = 60.0
var cached_safe_area: Rect2i = Rect2i()

# Feature Flags & Monetization
var is_steam_edition: bool = false
var has_full_game_unlock: bool = false # Unified $9.99 Mobile Full Game Unlock
var has_premium_pass: bool = false # Backward compatibility alias

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
	_update_safe_area()
	_load_license_data()
	_apply_feature_flags()
	set_process_unhandled_input(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_android_back_button()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_update_safe_area()

func _detect_platform() -> void:
	var os_name = OS.get_name()
	device_model = OS.get_model_name()

	if os_name == "Android":
		if device_model.begins_with("SM-") or device_model.to_lower().contains("samsung") or device_model.to_lower().contains("galaxy"):
			is_samsung_galaxy = true
			current_platform = TargetPlatform.ANDROID_GALAXY
			current_platform_type = GameEnums.PlatformType.ANDROID_SAMSUNG
		else:
			current_platform = TargetPlatform.ANDROID_GENERIC
			current_platform_type = GameEnums.PlatformType.GENERIC_MOBILE
		is_touch_device = true
		current_input_scheme = GameEnums.InputScheme.TOUCH
		is_steam_edition = false
		OS.set_restart_on_exit(false)
	elif os_name in ["Windows", "Linux", "macOS"]:
		if OS.has_feature("steamdeck") or OS.get_environment("SteamDeck") == "1":
			current_platform = TargetPlatform.STEAM_DECK
			current_platform_type = GameEnums.PlatformType.STEAM_DECK
			current_input_scheme = GameEnums.InputScheme.GAMEPAD
			is_touch_device = true
		else:
			current_platform = TargetPlatform.STEAM_PC
			current_platform_type = GameEnums.PlatformType.PC_STEAM
			current_input_scheme = GameEnums.InputScheme.KEYBOARD_MOUSE
			is_touch_device = DisplayServer.is_touchscreen_available()
		is_steam_edition = true
	else:
		current_platform = TargetPlatform.STANDALONE
		current_platform_type = GameEnums.PlatformType.UNKNOWN
		is_touch_device = DisplayServer.is_touchscreen_available()
		is_steam_edition = false

	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		var details = {
			"os": os_name,
			"model": device_model,
			"is_samsung": is_samsung_galaxy,
			"touch_supported": is_touch_device,
			"platform_type": current_platform_type
		}
		eb.platform_detected.emit(current_platform_type, details)
		eb.input_scheme_changed.emit(current_input_scheme)

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

func _update_safe_area() -> void:
	var safe_area = DisplayServer.get_display_safe_area()
	if safe_area != cached_safe_area:
		cached_safe_area = safe_area
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").safe_area_changed.emit(cached_safe_area)

func get_safe_area() -> Rect2i:
	if cached_safe_area.size == Vector2i.ZERO:
		_update_safe_area()
	return cached_safe_area

func get_safe_area_margins() -> Dictionary:
	var screen_size = DisplayServer.screen_get_size()
	var safe_rect = get_safe_area()
	if screen_size.x <= 0 or screen_size.y <= 0 or safe_rect.size == Vector2i.ZERO:
		return {"left": 0, "top": 0, "right": 0, "bottom": 0}

	var left = safe_rect.position.x
	var top = safe_rect.position.y
	var right = screen_size.x - (safe_rect.position.x + safe_rect.size.x)
	var bottom = screen_size.y - (safe_rect.position.y + safe_rect.size.y)
	return {
		"left": maxi(0, left),
		"top": maxi(0, top),
		"right": maxi(0, right),
		"bottom": maxi(0, bottom)
	}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_input_scheme(GameEnums.InputScheme.TOUCH)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if (event is InputEventJoypadMotion and abs((event as InputEventJoypadMotion).axis_value) > 0.3) or event is InputEventJoypadButton:
			_set_input_scheme(GameEnums.InputScheme.GAMEPAD)
	elif event is InputEventKey or (event is InputEventMouseButton and not is_touch_device):
		_set_input_scheme(GameEnums.InputScheme.KEYBOARD_MOUSE)

func _set_input_scheme(new_scheme: GameEnums.InputScheme) -> void:
	if current_input_scheme != new_scheme:
		current_input_scheme = new_scheme
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").input_scheme_changed.emit(new_scheme)

func _load_license_data() -> void:
	if is_steam_edition:
		has_full_game_unlock = true
		has_premium_pass = true
		return

	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				has_full_game_unlock = parsed.get("has_full_game_unlock", parsed.get("has_premium_pass", false))
				has_premium_pass = has_full_game_unlock
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
		all_themes_unlocked = true
		all_duels_unlocked = true
		ranked_multiplayer_unlocked = true
		replay_theater_unlocked = true
		ad_free = true
		steam_achievements_enabled = is_steam_edition
	else:
		all_themes_unlocked = false
		all_duels_unlocked = true
		ranked_multiplayer_unlocked = false
		replay_theater_unlocked = false
		ad_free = false
		steam_achievements_enabled = false

	feature_flags_updated.emit()

func purchase_full_game() -> void:
	has_full_game_unlock = true
	has_premium_pass = true
	_save_license_data()
	_apply_feature_flags()
	full_game_unlock_changed.emit(true)
	premium_pass_status_changed.emit(true)

func purchase_premium_pass() -> void:
	purchase_full_game()

func is_theme_unlocked(theme_name: String) -> bool:
	if all_themes_unlocked or is_steam_edition:
		return true
	return theme_name.to_lower() == "high_fantasy"

func get_store_pricing_label() -> String:
	if is_steam_edition:
		return "Steam PC Edition - $9.99 (Full Game Unlocked)"
	elif has_full_game_unlock:
		return "Mobile Edition - Full Game Unlocked ($9.99)"
	else:
		return "Free Trial (Full Game Unlock: $9.99 - All Themes & Ranked)"

func trigger_haptic(duration_ms: int = 40) -> void:
	if is_mobile():
		Input.vibrate_handheld(duration_ms)
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").haptic_feedback_requested.emit(duration_ms)

func is_mobile() -> bool:
	return is_android()

func is_android() -> bool:
	return current_platform == TargetPlatform.ANDROID_GALAXY or current_platform == TargetPlatform.ANDROID_GENERIC

func is_desktop() -> bool:
	return current_platform == TargetPlatform.STEAM_PC or current_platform == TargetPlatform.STEAM_DECK

func set_keep_screen_on(enabled: bool) -> void:
	DisplayServer.screen_set_keep_on(enabled)

func _handle_android_back_button() -> void:
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		if gm.current_state == GameEnums.GameState.DUEL_COMBAT or gm.current_state == GameEnums.GameState.BOARD_TURN:
			gm.toggle_pause()
		elif gm.current_state == GameEnums.GameState.PAUSED:
			gm.toggle_pause()
		elif gm.current_state == GameEnums.GameState.MAIN_MENU:
			get_tree().quit()
	elif get_tree().paused:
		get_tree().paused = false
	else:
		get_tree().paused = true
