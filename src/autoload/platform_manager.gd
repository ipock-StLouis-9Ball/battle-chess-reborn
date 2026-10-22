extends Node

## Platform Manager
## Tailored for Steam PC (Steam Deck / Windows / Linux) and Samsung Galaxy Android devices.

var current_platform: GameEnums.PlatformType = GameEnums.PlatformType.UNKNOWN
var current_input_scheme: GameEnums.InputScheme = GameEnums.InputScheme.KEYBOARD_MOUSE
var is_touch_device: bool = false
var is_samsung_galaxy: bool = false
var device_model: String = ""
var device_refresh_rate: float = 60.0
var cached_safe_area: Rect2i = Rect2i()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_detect_platform()
	_detect_display_capabilities()
	_update_safe_area()
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
		# Check for Samsung Galaxy device identification
		if device_model.begins_with("SM-") or device_model.to_lower().contains("samsung") or device_model.to_lower().contains("galaxy"):
			is_samsung_galaxy = true
			current_platform = GameEnums.PlatformType.ANDROID_SAMSUNG
			Logger.info("Platform", "Detected Samsung Galaxy device: %s" % device_model)
		else:
			current_platform = GameEnums.PlatformType.GENERIC_MOBILE
			Logger.info("Platform", "Detected Android device: %s" % device_model)
		is_touch_device = true
		current_input_scheme = GameEnums.InputScheme.TOUCH
		OS.set_restart_on_exit(false)
	elif os_name == "Windows" or os_name == "Linux" or os_name == "macOS":
		if OS.has_feature("steamdeck") or OS.get_environment("SteamDeck") == "1":
			current_platform = GameEnums.PlatformType.STEAM_DECK
			current_input_scheme = GameEnums.InputScheme.GAMEPAD
			is_touch_device = true
			Logger.info("Platform", "Detected Steam Deck environment")
		else:
			current_platform = GameEnums.PlatformType.PC_STEAM
			current_input_scheme = GameEnums.InputScheme.KEYBOARD_MOUSE
			is_touch_device = DisplayServer.is_touchscreen_available()
			Logger.info("Platform", "Detected PC (Steam / Desktop): %s" % os_name)
	else:
		current_platform = GameEnums.PlatformType.UNKNOWN
		is_touch_device = DisplayServer.is_touchscreen_available()

	var details = {
		"os": os_name,
		"model": device_model,
		"is_samsung": is_samsung_galaxy,
		"touch_supported": is_touch_device,
		"platform_type": current_platform
	}
	EventBus.platform_detected.emit(current_platform, details)
	EventBus.input_scheme_changed.emit(current_input_scheme)

func _detect_display_capabilities() -> void:
	# Detect display refresh rate (e.g. 120Hz on modern Galaxy S21-S24 / Fold screens)
	var screen_id = DisplayServer.window_get_current_screen()
	device_refresh_rate = DisplayServer.screen_get_refresh_rate(screen_id)
	if device_refresh_rate <= 0:
		device_refresh_rate = 60.0
	Logger.info("Platform", "Detected display refresh rate: %.1f Hz" % device_refresh_rate)

func _update_safe_area() -> void:
	var safe_area = DisplayServer.get_display_safe_area()
	if safe_area != cached_safe_area:
		cached_safe_area = safe_area
		Logger.info("Platform", "Safe area updated: %s (Screen size: %s)" % [str(safe_area), str(DisplayServer.screen_get_size())])
		EventBus.safe_area_changed.emit(cached_safe_area)

func get_safe_area() -> Rect2i:
	if cached_safe_area.size == Vector2i.ZERO:
		_update_safe_area()
	return cached_safe_area

func get_safe_area_margins() -> Dictionary:
	var screen_size = DisplayServer.screen_get_size()
	var safe_rect = get_safe_area()
	if screen_size.x <= 0 or screen_size.y <= 0 or safe_rect.size == Vector2i.ZERO:
		return {"left": 0, "top": 0, "right": 0, "bottom": 0}
	
	# Compute margin offsets relative to full screen
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
		EventBus.input_scheme_changed.emit(new_scheme)

func trigger_haptic(duration_ms: int = 40) -> void:
	if is_mobile():
		Input.vibrate_handheld(duration_ms)
		EventBus.haptic_feedback_requested.emit(duration_ms)

func set_keep_screen_on(enabled: bool) -> void:
	if OS.has_feature("mobile") or current_platform == GameEnums.PlatformType.ANDROID_SAMSUNG:
		OS.set_restart_on_exit(false)
		# Godot 4 DisplayServer screen sleep prevention
		DisplayServer.screen_set_keep_on(enabled)

func is_mobile() -> bool:
	return current_platform == GameEnums.PlatformType.ANDROID_SAMSUNG or current_platform == GameEnums.PlatformType.GENERIC_MOBILE

func is_desktop() -> bool:
	return current_platform == GameEnums.PlatformType.PC_STEAM or current_platform == GameEnums.PlatformType.STEAM_DECK

func _handle_android_back_button() -> void:
	Logger.info("Platform", "Android Back button triggered")
	if GameManager.current_state == GameEnums.GameState.DUEL_COMBAT or GameManager.current_state == GameEnums.GameState.BOARD_TURN:
		GameManager.toggle_pause()
	elif GameManager.current_state == GameEnums.GameState.PAUSED:
		GameManager.toggle_pause()
	elif GameManager.current_state == GameEnums.GameState.MAIN_MENU:
		get_tree().quit()
