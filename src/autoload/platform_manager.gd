extends Node

## Universal Platform Manager & Feature Flags
## Consolidated Singleton in res://src/autoload/platform_manager.gd
## Provides 100% universal support for all mobile devices using standard Godot engine features:
## - Universal detection via OS.has_feature("mobile"), OS.has_feature("android"), OS.has_feature("ios")
## - Zero vendor-specific string sniffing
## - Clean DisplayServer.screen_get_refresh_rate() detection
## - Standard DisplayServer.get_display_safe_area() for punch-holes, notches, and tablet bezels
## - Universal haptic feedback suite with semantic presets
## - Lifecycle background / resume / back navigation handling
## - Unified $9.99 Full Game Unlock monetization across mobile and Steam PC

signal feature_flags_updated()
signal full_game_unlock_changed(is_unlocked: bool)
signal premium_pass_status_changed(is_unlocked: bool)
signal safe_area_changed(margins: Dictionary)
signal orientation_changed(is_landscape: bool)

enum TargetPlatform {
	STEAM_PC,
	STEAM_DECK,
	ANDROID,
	IOS,
	WEB,
	STANDALONE
}

# Input Schemes & Platform Types (matching GameEnums integer values)
const PLATFORM_PC_STEAM: int = 0
const PLATFORM_ANDROID_SAMSUNG: int = 1 # Backwards compatibility alias
const PLATFORM_GENERIC_MOBILE: int = 2
const PLATFORM_STEAM_DECK: int = 3
const PLATFORM_WEB: int = 4
const PLATFORM_UNKNOWN: int = 5

const INPUT_KEYBOARD_MOUSE: int = 0
const INPUT_GAMEPAD: int = 1
const INPUT_TOUCH: int = 2

const SAVE_PATH: String = "user://license_data.json"

# Active Platform State
var current_platform: TargetPlatform = TargetPlatform.STANDALONE
var current_platform_type: int = PLATFORM_UNKNOWN
var current_input_scheme: int = INPUT_KEYBOARD_MOUSE

# Universal Device Metadata (zero device-specific sniffing)
var os_name: String = ""
var device_model: String = ""
var is_touch_device: bool = false
var is_samsung_galaxy: bool = false # Backwards compatibility alias

# Display & Refresh
var display_refresh_rate: float = 60.0
var device_refresh_rate: float = 60.0
var cached_safe_area: Rect2i = Rect2i()

# Feature Flags & Monetization ($9.99 Full Game Unlock)
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

	var root_vp = get_tree().root
	if is_instance_valid(root_vp):
		root_vp.size_changed.connect(_on_viewport_size_changed)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_android_back_button()
		NOTIFICATION_APPLICATION_RESUMED:
			_update_safe_area()
			_detect_display()
		NOTIFICATION_APPLICATION_PAUSED:
			_handle_app_paused()
		NOTIFICATION_WM_SIZE_CHANGED:
			_on_viewport_size_changed()

func _detect_platform() -> void:
	os_name = OS.get_name()
	device_model = OS.get_model_name()

	# Universal mobile detection via standard Godot feature tags
	if OS.has_feature("android") or os_name == "Android":
		current_platform = TargetPlatform.ANDROID
		current_platform_type = PLATFORM_GENERIC_MOBILE
		is_touch_device = true
		current_input_scheme = INPUT_TOUCH
		is_steam_edition = false
		OS.set_restart_on_exit(false)
	elif OS.has_feature("ios") or os_name in ["iOS", "iPadOS"]:
		current_platform = TargetPlatform.IOS
		current_platform_type = PLATFORM_GENERIC_MOBILE
		is_touch_device = true
		current_input_scheme = INPUT_TOUCH
		is_steam_edition = false
	elif OS.has_feature("mobile"):
		current_platform = TargetPlatform.ANDROID
		current_platform_type = PLATFORM_GENERIC_MOBILE
		is_touch_device = true
		current_input_scheme = INPUT_TOUCH
		is_steam_edition = false
	elif OS.has_feature("steamdeck") or OS.get_environment("SteamDeck") == "1":
		current_platform = TargetPlatform.STEAM_DECK
		current_platform_type = PLATFORM_STEAM_DECK
		current_input_scheme = INPUT_GAMEPAD
		is_touch_device = true
		is_steam_edition = true
	elif OS.has_feature("web") or os_name == "Web":
		current_platform = TargetPlatform.WEB
		current_platform_type = PLATFORM_WEB
		is_touch_device = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
		current_input_scheme = INPUT_TOUCH if is_touch_device else INPUT_KEYBOARD_MOUSE
		is_steam_edition = false
	elif os_name in ["Windows", "Linux", "macOS"]:
		current_platform = TargetPlatform.STEAM_PC
		current_platform_type = PLATFORM_PC_STEAM
		current_input_scheme = INPUT_KEYBOARD_MOUSE
		is_touch_device = DisplayServer.is_touchscreen_available()
		is_steam_edition = true
	else:
		current_platform = TargetPlatform.STANDALONE
		current_platform_type = PLATFORM_UNKNOWN
		is_touch_device = DisplayServer.is_touchscreen_available()
		is_steam_edition = false

	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		var details = {
			"os": os_name,
			"model": device_model,
			"is_mobile": is_mobile(),
			"touch_supported": is_touch_device,
			"platform_type": current_platform_type
		}
		eb.platform_detected.emit(current_platform_type, details)
		eb.input_scheme_changed.emit(current_input_scheme)

## Clean, universal refresh rate detection (no invalid FEATURE_SCREEN)
func _detect_display() -> void:
	var refresh_rate: float = DisplayServer.screen_get_refresh_rate()
	if refresh_rate <= 0.0:
		refresh_rate = 60.0
	display_refresh_rate = refresh_rate
	device_refresh_rate = refresh_rate

## Universal safe-area adaptation via standard DisplayServer.get_display_safe_area()
func _update_safe_area() -> void:
	var safe_area = DisplayServer.get_display_safe_area()
	var screen_size = DisplayServer.screen_get_size()

	# If safe area is empty or uninitialized, fallback to the screen / window bounds
	if safe_area.size == Vector2i.ZERO:
		if screen_size != Vector2i.ZERO:
			safe_area = Rect2i(Vector2i.ZERO, screen_size)
		else:
			var win_size = DisplayServer.window_get_size()
			safe_area = Rect2i(Vector2i.ZERO, win_size)

	if safe_area != cached_safe_area:
		cached_safe_area = safe_area
		var margins = get_safe_area_margins()
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").safe_area_changed.emit(cached_safe_area)
		safe_area_changed.emit(margins)

func _on_viewport_size_changed() -> void:
	_update_safe_area()
	var vp = get_viewport()
	if is_instance_valid(vp):
		var vp_size = vp.get_visible_rect().size
		if vp_size != Vector2.ZERO:
			var is_landscape = vp_size.x >= vp_size.y
			orientation_changed.emit(is_landscape)

func _handle_app_paused() -> void:
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		var st = gm.get("current_state")
		# 3 = BOARD_TURN, 4 = DUEL_COMBAT
		if st == 3 or st == 4:
			if gm.has_method("toggle_pause"):
				gm.toggle_pause()

func get_safe_area() -> Rect2i:
	if cached_safe_area.size == Vector2i.ZERO:
		_update_safe_area()
	return cached_safe_area

## Returns safe area margins in physical screen pixels
func get_safe_area_margins() -> Dictionary:
	var screen_size = DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = DisplayServer.window_get_size()

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

## Returns safe area margins normalized to 0.0 - 1.0 range for UI anchor offsets
func get_safe_area_margins_normalized() -> Dictionary:
	var screen_size = DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = DisplayServer.window_get_size()

	if screen_size.x <= 0 or screen_size.y <= 0:
		return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}

	var m = get_safe_area_margins()
	return {
		"left": float(m.left) / float(screen_size.x),
		"top": float(m.top) / float(screen_size.y),
		"right": float(m.right) / float(screen_size.x),
		"bottom": float(m.bottom) / float(screen_size.y)
	}

func has_notch_or_cutout() -> bool:
	var m = get_safe_area_margins()
	return m.left > 0 or m.top > 0 or m.right > 0 or m.bottom > 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_set_input_scheme(INPUT_TOUCH)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if (event is InputEventJoypadMotion and abs((event as InputEventJoypadMotion).axis_value) > 0.3) or event is InputEventJoypadButton:
			_set_input_scheme(INPUT_GAMEPAD)
	elif event is InputEventKey or (event is InputEventMouseButton and not is_touch_device):
		_set_input_scheme(INPUT_KEYBOARD_MOUSE)

func _set_input_scheme(new_scheme: int) -> void:
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

func restore_purchases() -> void:
	_load_license_data()
	_apply_feature_flags()
	full_game_unlock_changed.emit(has_full_game_unlock)
	premium_pass_status_changed.emit(has_full_game_unlock)

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

# Universal Haptic Feedback Suite
func trigger_haptic(duration_ms: int = 40) -> void:
	if is_mobile() and is_haptics_enabled():
		Input.vibrate_handheld(duration_ms)
		if has_node("/root/EventBus"):
			get_node("/root/EventBus").haptic_feedback_requested.emit(duration_ms)

func haptic_selection() -> void:
	trigger_haptic(15)

func haptic_light() -> void:
	trigger_haptic(20)

func haptic_medium() -> void:
	trigger_haptic(45)

func haptic_heavy() -> void:
	trigger_haptic(75)

func haptic_success() -> void:
	trigger_haptic(50)

func haptic_error() -> void:
	trigger_haptic(30)
	var tw = create_tween()
	if is_instance_valid(tw):
		tw.tween_interval(0.06)
		tw.tween_callback(func(): trigger_haptic(30))

func is_haptics_enabled() -> bool:
	if has_node("/root/SettingsManager"):
		return get_node("/root/SettingsManager").get("haptics_enabled")
	return true

# Universal Mobile Detection Helpers using Godot standard feature checks
func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or is_android() or is_ios()

func is_android() -> bool:
	return OS.has_feature("android") or os_name == "Android" or current_platform == TargetPlatform.ANDROID

func is_ios() -> bool:
	return OS.has_feature("ios") or os_name in ["iOS", "iPadOS"] or current_platform == TargetPlatform.IOS

func is_desktop() -> bool:
	return current_platform in [TargetPlatform.STEAM_PC, TargetPlatform.STEAM_DECK] or (not is_mobile() and os_name in ["Windows", "Linux", "macOS"])

func has_high_refresh_rate() -> bool:
	return display_refresh_rate >= 89.0

func get_device_summary() -> Dictionary:
	return {
		"os": os_name,
		"model": device_model if not device_model.is_empty() else "Standard Mobile",
		"refresh_rate": device_refresh_rate,
		"high_refresh_supported": has_high_refresh_rate(),
		"safe_area_margins": get_safe_area_margins(),
		"is_mobile": is_mobile(),
		"touch_supported": is_touch_device,
		"full_game_unlocked": has_full_game_unlock,
		"store_pricing": get_store_pricing_label()
	}

func set_keep_screen_on(enabled: bool) -> void:
	DisplayServer.screen_set_keep_on(enabled)

func _handle_android_back_button() -> void:
	if has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		var st = gm.get("current_state")
		# 4 = DUEL_COMBAT, 3 = BOARD_TURN, 5 = PAUSED, 1 = MAIN_MENU
		if st == 4 or st == 3 or st == 5:
			if gm.has_method("toggle_pause"):
				gm.toggle_pause()
		elif st == 1:
			get_tree().quit()
	elif get_tree().paused:
		get_tree().paused = false
	else:
		get_tree().paused = true
