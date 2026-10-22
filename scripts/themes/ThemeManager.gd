class_name ThemeManager
extends Node

## Theme Manager
## Manages High Fantasy, Cyberpunk, and Eldritch visual styles, palettes, and piece models

signal theme_changed(new_theme: String, theme_data: Dictionary)

const THEMES = {
	"high_fantasy": {
		"id": "high_fantasy",
		"name": "High Fantasy: Realm of Valor",
		"description": "Noble steel knights, radiant sorceresses, and living fortress colossi.",
		"light_square": Color(0.82, 0.84, 0.88, 1.0),
		"dark_square": Color(0.24, 0.28, 0.36, 1.0),
		"accent": Color(0.95, 0.8, 0.25, 1.0),
		"arena_bg": Color(0.12, 0.14, 0.18, 1.0)
	},
	"cyberpunk": {
		"id": "cyberpunk",
		"name": "Cyberpunk: Neon Overclock",
		"description": "High-frequency mono-wire blades, hoverbike outrunners, and corporate mechs.",
		"light_square": Color(0.15, 0.3, 0.38, 1.0),
		"dark_square": Color(0.05, 0.08, 0.14, 1.0),
		"accent": Color(0.0, 0.95, 0.85, 1.0),
		"arena_bg": Color(0.04, 0.05, 0.09, 1.0)
	},
	"eldritch": {
		"id": "eldritch",
		"name": "Eldritch: Abyssal Madness",
		"description": "Non-Euclidean star spawn, void cultists, and cosmic horrors.",
		"light_square": Color(0.38, 0.32, 0.42, 1.0),
		"dark_square": Color(0.12, 0.09, 0.16, 1.0),
		"accent": Color(0.85, 0.25, 0.95, 1.0),
		"arena_bg": Color(0.08, 0.04, 0.12, 1.0)
	}
}

var current_theme: String = "high_fantasy"

func _ready() -> void:
	set_theme("high_fantasy")

func set_theme(theme_id: String) -> bool:
	var tid = theme_id.to_lower()
	if not THEMES.has(tid):
		return false

	# Validate platform license unlock
	if has_node("/root/PlatformManager") and not get_node("/root/PlatformManager").is_theme_unlocked(tid):
		return false

	current_theme = tid
	if has_node("/root/DuelDirector"):
		get_node("/root/DuelDirector").set_active_theme(tid)

	theme_changed.emit(current_theme, THEMES[current_theme])
	return true

func get_current_theme_data() -> Dictionary:
	return THEMES.get(current_theme, THEMES["high_fantasy"])
