class_name SettingsMenu
extends Control

## Cross-platform settings screen for Steam PC and Samsung Galaxy Android

signal back_pressed()

# Audio Sliders
@onready var slider_master: HSlider = $SafeArea/Scroll/Content/AudioSection/MasterRow/Slider
@onready var slider_music: HSlider = $SafeArea/Scroll/Content/AudioSection/MusicRow/Slider
@onready var slider_sfx: HSlider = $SafeArea/Scroll/Content/AudioSection/SFXRow/Slider

# Display / Performance
@onready var option_fps: OptionButton = $SafeArea/Scroll/Content/DisplaySection/FPSRow/Option
@onready var check_vsync: CheckBox = $SafeArea/Scroll/Content/DisplaySection/VSyncRow/CheckBox
@onready var check_fullscreen: CheckBox = $SafeArea/Scroll/Content/DisplaySection/FullscreenRow/CheckBox

# Mobile / Controls
@onready var check_touch: CheckBox = $SafeArea/Scroll/Content/MobileSection/TouchControlsRow/CheckBox
@onready var slider_touch_opacity: HSlider = $SafeArea/Scroll/Content/MobileSection/OpacityRow/Slider
@onready var check_haptics: CheckBox = $SafeArea/Scroll/Content/MobileSection/HapticsRow/CheckBox

# Gameplay
@onready var check_auto_duel: CheckBox = $SafeArea/Scroll/Content/GameplaySection/AutoDuelRow/CheckBox
@onready var option_difficulty: OptionButton = $SafeArea/Scroll/Content/GameplaySection/DifficultyRow/Option

@onready var btn_back: Button = $SafeArea/Scroll/Content/BtnBack
@onready var device_info_label: Label = $SafeArea/Scroll/Content/DeviceInfoLabel

func _ready() -> void:
	_init_fps_options()
	_init_difficulty_options()
	_load_current_values()
	_connect_signals()
	_display_device_info()

func _init_fps_options() -> void:
	option_fps.clear()
	option_fps.add_item("30 FPS", 30)
	option_fps.add_item("60 FPS (Standard)", 60)
	option_fps.add_item("90 FPS", 90)
	option_fps.add_item("120 FPS (Galaxy 120Hz / High Refresh)", 120)

func _init_difficulty_options() -> void:
	option_difficulty.clear()
	option_difficulty.add_item("Apprentice (Easy)", 0)
	option_difficulty.add_item("Warrior (Medium)", 1)
	option_difficulty.add_item("Champion (Hard)", 2)
	option_difficulty.add_item("Grandmaster (Master)", 3)

func _load_current_values() -> void:
	# Audio
	slider_master.value = SettingsManager.master_volume * 100.0
	slider_music.value = SettingsManager.music_volume * 100.0
	slider_sfx.value = SettingsManager.sfx_volume * 100.0

	# Display
	check_vsync.button_pressed = SettingsManager.vsync_enabled
	check_fullscreen.button_pressed = SettingsManager.fullscreen
	check_fullscreen.visible = not PlatformManager.is_mobile()

	# Select FPS item
	var fps_val = SettingsManager.target_fps
	for i in range(option_fps.item_count):
		if option_fps.get_item_id(i) == fps_val:
			option_fps.selected = i
			break

	# Mobile
	check_touch.button_pressed = SettingsManager.show_touch_controls
	slider_touch_opacity.value = SettingsManager.touch_controls_opacity * 100.0
	check_haptics.button_pressed = SettingsManager.haptics_enabled

	# Gameplay
	check_auto_duel.button_pressed = SettingsManager.auto_resolve_duels
	option_difficulty.selected = int(SettingsManager.ai_duel_difficulty)

func _connect_signals() -> void:
	slider_master.value_changed.connect(func(v): SettingsManager.set_master_volume(v / 100.0))
	slider_music.value_changed.connect(func(v): SettingsManager.set_music_volume(v / 100.0))
	slider_sfx.value_changed.connect(func(v): SettingsManager.set_sfx_volume(v / 100.0))

	option_fps.item_selected.connect(func(idx):
		var fps = option_fps.get_item_id(idx)
		SettingsManager.set_target_fps(fps)
	)

	check_vsync.toggled.connect(func(b): SettingsManager.set_vsync(b))
	check_fullscreen.toggled.connect(func(b):
		SettingsManager.fullscreen = b
		SettingsManager.apply_all_settings()
	)

	check_touch.toggled.connect(func(b):
		SettingsManager.show_touch_controls = b
		SettingsManager.save_settings()
	)

	slider_touch_opacity.value_changed.connect(func(v):
		SettingsManager.touch_controls_opacity = v / 100.0
		SettingsManager.save_settings()
	)

	check_haptics.toggled.connect(func(b):
		SettingsManager.haptics_enabled = b
		if b: PlatformManager.trigger_haptic(40)
		SettingsManager.save_settings()
	)

	check_auto_duel.toggled.connect(func(b):
		SettingsManager.auto_resolve_duels = b
		SettingsManager.save_settings()
	)

	option_difficulty.item_selected.connect(func(idx):
		SettingsManager.ai_duel_difficulty = idx as GameEnums.AIDifficulty
		SettingsManager.save_settings()
	)

	btn_back.pressed.connect(_on_back_pressed)

func _display_device_info() -> void:
	var safe = PlatformManager.get_safe_area()
	var info = "Device: %s | Model: %s | Refresh: %.0f Hz\nSafe Area: %s" % [
		OS.get_name(),
		PlatformManager.device_model if PlatformManager.device_model != "" else "Desktop / Standard",
		PlatformManager.device_refresh_rate,
		str(safe)
	]
	device_info_label.text = info

func _on_back_pressed() -> void:
	EventBus.play_sfx_requested.emit("click", "UI")
	SettingsManager.save_settings()
	back_pressed.emit()
	visible = false
