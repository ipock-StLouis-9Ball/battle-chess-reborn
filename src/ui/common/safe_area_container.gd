class_name SafeAreaContainer
extends MarginContainer

## Responsive container adjusting margins for Samsung Galaxy notch/camera cutouts
## and system navigation insets.

@export var apply_left: bool = true
@export var apply_right: bool = true
@export var apply_top: bool = true
@export var apply_bottom: bool = true

@export var extra_padding: int = 16

func _ready() -> void:
	_update_margins()
	EventBus.safe_area_changed.connect(func(_rect): _update_margins())
	get_viewport().size_changed.connect(_update_margins)

func _update_margins() -> void:
	var margins = PlatformManager.get_safe_area_margins()
	
	var ml = (margins.left + extra_padding) if apply_left else extra_padding
	var mr = (margins.right + extra_padding) if apply_right else extra_padding
	var mt = (margins.top + extra_padding) if apply_top else extra_padding
	var mb = (margins.bottom + extra_padding) if apply_bottom else extra_padding

	add_theme_constant_override("margin_left", ml)
	add_theme_constant_override("margin_right", mr)
	add_theme_constant_override("margin_top", mt)
	add_theme_constant_override("margin_bottom", mb)
