class_name BoardTile
extends Control

## Visual interactive tile on the 8x8 chess board

signal tile_clicked(grid_pos: Vector2i)

@export var grid_position: Vector2i = Vector2i.ZERO
@export var is_dark_square: bool = false

var is_highlighted_move: bool = false
var is_highlighted_attack: bool = false
var is_selected: bool = false
var is_hovered: bool = false

@onready var bg_rect: ColorRect = $Background
@onready var highlight_rect: ColorRect = $Highlight
@onready var border_rect: ReferenceRect = $SelectionBorder

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_appearance()

func setup(pos: Vector2i) -> void:
	grid_position = pos
	is_dark_square = ((pos.x + pos.y) % 2 == 1)
	if is_node_ready():
		_update_appearance()

func _update_appearance() -> void:
	if not is_inside_tree():
		return

	# Base tile color (Rich dark slate vs warm ivory)
	if is_dark_square:
		bg_rect.color = Color(0.18, 0.22, 0.28, 1.0)
	else:
		bg_rect.color = Color(0.78, 0.82, 0.88, 1.0)

	# Overlays
	if is_selected:
		highlight_rect.visible = true
		highlight_rect.color = Color(0.9, 0.8, 0.2, 0.45)
		border_rect.visible = true
		border_rect.border_color = Color(1.0, 0.9, 0.3, 1.0)
	elif is_highlighted_attack:
		highlight_rect.visible = true
		highlight_rect.color = Color(0.95, 0.2, 0.25, 0.5)
		border_rect.visible = true
		border_rect.border_color = Color(1.0, 0.2, 0.3, 1.0)
	elif is_highlighted_move:
		highlight_rect.visible = true
		highlight_rect.color = Color(0.2, 0.75, 0.95, 0.38)
		border_rect.visible = false
	elif is_hovered:
		highlight_rect.visible = true
		highlight_rect.color = Color(1.0, 1.0, 1.0, 0.15)
		border_rect.visible = false
	else:
		highlight_rect.visible = false
		border_rect.visible = false

func set_highlight_move(enabled: bool) -> void:
	is_highlighted_move = enabled
	_update_appearance()

func set_highlight_attack(enabled: bool) -> void:
	is_highlighted_attack = enabled
	_update_appearance()

func set_selected(enabled: bool) -> void:
	is_selected = enabled
	_update_appearance()

func _on_mouse_entered() -> void:
	is_hovered = true
	EventBus.tile_hovered.emit(grid_position)
	_update_appearance()

func _on_mouse_exited() -> void:
	is_hovered = false
	EventBus.tile_unhovered.emit(grid_position)
	_update_appearance()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			tile_clicked.emit(grid_position)
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			tile_clicked.emit(grid_position)
			accept_event()
