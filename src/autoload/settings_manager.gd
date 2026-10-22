extends Node

## Settings Manager
## Handles cross-platform settings persistence (PC & Samsung Galaxy Android)

const SETTINGS_FILE_PATH = "user://settings.cfg"

# Audio Settings (0.0 to 1.0)
var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.85
var ui_volume: float = 0.8
var combat_volume: float = 0.9

# Graphics & Display
var target_fps: int = 60
var vsync_enabled: bool = true
var fullscreen: bool = false
var graphics_preset: GameEnums.GraphicsPreset = GameEnums.GraphicsPreset.HIGH
var screen_shake: bool = true

# Mobile / Touch Specifics
var show_touch_controls: bool = true
var touch_controls_opacity: float = 0.85
var haptics_enabled: bool = true

# Gameplay
var auto_resolve_duels: bool = false
var ai_duel_difficulty: GameEnums.AIDifficulty = GameEnums.AIDifficulty.MEDIUM

var _config: ConfigFile = ConfigFile.new()

func _ready() -> void:
	load_settings()
	apply_all_settings()

func load_settings() -> void:
	var err = _config.load(SETTINGS_FILE_PATH)
	if err != OK:
		Logger.info("Settings", "No existing settings found, initializing platform defaults")
		_init_platform_defaults()
		save_settings()
		return

	# Load Audio
	master_volume = _config.get_value("audio", "master_volume", 0.8)
	music_volume = _config.get_value("audio", "music_volume", 0.7)
	sfx_volume = _config.get_value("audio", "sfx_volume", 0.85)
	ui_volume = _config.get_value("audio", "ui_volume", 0.8)
	combat_volume = _config.get_value("audio", "combat_volume", 0.9)

	# Load Graphics
	target_fps = _config.get_value("display", "target_fps", 60)
	vsync_enabled = _config.get_value("display", "vsync_enabled", true)
	fullscreen = _config.get_value("display", "fullscreen", false)
	graphics_preset = _config.get_value("display", "graphics_preset", GameEnums.GraphicsPreset.HIGH)
	screen_shake = _config.get_value("display", "screen_shake", true)

	# Load Mobile / Touch
	show_touch_controls = _config.get_value("mobile", "show_touch_controls", PlatformManager.is_mobile())
	touch_controls_opacity = _config.get_value("mobile", "touch_controls_opacity", 0.85)
	haptics_enabled = _config.get_value("mobile", "haptics_enabled", true)

	# Load Gameplay
	auto_resolve_duels = _config.get_value("gameplay", "auto_resolve_duels", false)
	ai_duel_difficulty = _config.get_value("gameplay", "ai_duel_difficulty", GameEnums.AIDifficulty.MEDIUM)

	Logger.info("Settings", "Settings loaded successfully")
	EventBus.settings_loaded.emit()

func save_settings() -> void:
	# Audio
	_config.set_value("audio", "master_volume", master_volume)
	_config.set_value("audio", "music_volume", music_volume)
	_config.set_value("audio", "sfx_volume", sfx_volume)
	_config.set_value("audio", "ui_volume", ui_volume)
	_config.set_value("audio", "combat_volume", combat_volume)

	# Display
	_config.set_value("display", "target_fps", target_fps)
	_config.set_value("display", "vsync_enabled", vsync_enabled)
	_config.set_value("display", "fullscreen", fullscreen)
	_config.set_value("display", "graphics_preset", graphics_preset)
	_config.set_value("display", "screen_shake", screen_shake)

	# Mobile
	_config.set_value("mobile", "show_touch_controls", show_touch_controls)
	_config.set_value("mobile", "touch_controls_opacity", touch_controls_opacity)
	_config.set_value("mobile", "haptics_enabled", haptics_enabled)

	# Gameplay
	_config.set_value("gameplay", "auto_resolve_duels", auto_resolve_duels)
	_config.set_value("gameplay", "ai_duel_difficulty", ai_duel_difficulty)

	_config.save(SETTINGS_FILE_PATH)
	Logger.info("Settings", "Settings persisted to disk")
	EventBus.settings_saved.emit()

func _init_platform_defaults() -> void:
	if PlatformManager.is_mobile():
		show_touch_controls = true
		haptics_enabled = true
		fullscreen = true
		# Default to matching device refresh rate (e.g. 120 or 60)
		target_fps = int(PlatformManager.device_refresh_rate)
	else:
		show_touch_controls = false
		haptics_enabled = false
		target_fps = 60
		fullscreen = false

func apply_all_settings() -> void:
	_apply_audio()
	_apply_display()

func _apply_audio() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	_set_bus_volume("UI", ui_volume)
	_set_bus_volume("Combat", combat_volume)

func _set_bus_volume(bus_name: String, linear_vol: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		if linear_vol <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			var db = linear_to_db(linear_vol)
			AudioServer.set_bus_volume_db(bus_idx, db)

func _apply_display() -> void:
	Engine.max_fps = target_fps
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	
	if not PlatformManager.is_mobile():
		var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)

func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	_set_bus_volume("Master", master_volume)

func set_music_volume(val: float) -> void:
	music_volume = clampf(val, 0.0, 1.0)
	_set_bus_volume("Music", music_volume)

func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)
	_set_bus_volume("SFX", sfx_volume)

func set_target_fps(fps: int) -> void:
	target_fps = fps
	Engine.max_fps = fps

func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
