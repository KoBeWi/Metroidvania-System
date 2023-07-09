@tool
extends "res://addons/MetroidvaniaSystem/Scripts/MapView.gd"

enum {MODE_LAYOUT = 1, MODE_ROOM_SYMBOL, MODE_ROOM_COLOR, MODE_ROOM_GROUP, MODE_BORDER_TYPE, MODE_BORDER_COLOR, MODE_MAP}

@onready var ghost_map: Control = %GhostMap

@export var mode_group: ButtonGroup

var mode: int = MODE_LAYOUT
var preview_layer := -1

func _ready() -> void:
	if not plugin:
		return
	super()
	
	MetSys.map_updated.connect(map.queue_redraw)
	mode_group.pressed.connect(mode_pressed)
	get_current_sub_editor()._editor_enter()

func mode_pressed(button: BaseButton):
	get_current_sub_editor()._editor_exit()
	mode = button.get_index()
	get_current_sub_editor()._editor_enter()
	
	map_overlay.queue_redraw()

func on_layer_changed(l: int):
	super(l)
	ghost_map.queue_redraw()

func preview_layer_changed(value: float) -> void:
	preview_layer = value
	ghost_map.queue_redraw()

func get_current_sub_editor() -> Control:
	return mode_group.get_buttons()[mode - 1]

func _on_overlay_input(event: InputEvent) -> void:
	super(event)
	get_current_sub_editor()._editor_input(event)

func _on_drag():
	ghost_map.queue_redraw()

func _on_overlay_draw() -> void:
	if not plugin:
		return
	
	map_overlay.draw_set_transform(Vector2(map_offset) * MetSys.ROOM_SIZE)
	
	var sub := get_current_sub_editor()
	sub.top_draw = Callable()
	sub._editor_draw(map_overlay)
	
	map_overlay.draw_set_transform_matrix(Transform2D())
	map_overlay.draw_string(get_theme_font(&"font", &"Label"), Vector2(0, 20), str(get_cursor_pos()))
	
	if sub.top_draw.is_valid():
		sub.top_draw.call(map_overlay)

func _on_ghost_map_draw() -> void:
	if not plugin:
		return
	
	if preview_layer == -1 or preview_layer == current_layer:
		return
	
	for x in range(-100, 100):
		for y in range(-100, 100):
			MetSys.draw_map_square(ghost_map, Vector2i(x, y) + map_offset, Vector3i(x, y, preview_layer))
