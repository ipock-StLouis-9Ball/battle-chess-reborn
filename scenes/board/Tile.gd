class_name Tile
extends Control

signal clicked(pos: Vector2i)

@export var grid_pos: Vector2i = Vector2i.ZERO
@export var is_dark: bool = false

@onready var bg: ColorRect = $BG
@onready var highlight: ColorRect = $Highlight

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	if has_node("/root/ThemeManager"):
		get_node("/root/ThemeManager").theme_changed.connect(func(_id, _data): _update_visuals())
	_update_visuals()

func setup(pos: Vector2i) -> void:
	grid_pos = pos
	is_dark = ((pos.x + pos.y) % 2 == 1)
	if is_node_ready():
		_update_visuals()

func _update_visuals() -> void:
	var theme_data = {}
	if has_node("/root/ThemeManager"):
		theme_data = get_node("/root/ThemeManager").get_current_theme_data()

	var light_c = theme_data.get("light_square", Color(0.82, 0.84, 0.88))
	var dark_c = theme_data.get("dark_square", Color(0.24, 0.28, 0.36))

	if bg:
		bg.color = dark_c if is_dark else light_c

func set_highlight(active: bool, is_capture: bool = false) -> void:
	highlight.visible = active
	if is_capture:
		highlight.color = Color(0.95, 0.2, 0.25, 0.5)
	else:
		highlight.color = Color(0.2, 0.75, 0.95, 0.4)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(grid_pos)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		clicked.emit(grid_pos)
		accept_event()
