@tool
extends Control

enum {MODE_LAYOUT = 1, MODE_ROOM_SYMBOL, MODE_ROOM_COLOR, MODE_ROOM_GROUP, MODE_BORDER_TYPE, MODE_BORDER_COLOR, MODE_MAP}

@onready var map_overlay: Control = $MapOverlay
@onready var map: Control = %Map
@onready var ghost_map: Control = %GhostMap

@export var mode_group: ButtonGroup

const NULL_VECTOR2I = Vector2i(-9999999, -9999999)
var plugin: EditorPlugin

var drag_from: Vector2i = NULL_VECTOR2I
var view_drag: Vector4
var map_offset := Vector2i(10, 10)

var mode: int = MODE_LAYOUT
var current_layer: int
var preview_layer := -1

func _enter_tree() -> void:
	if owner:
		plugin = owner.plugin

func _ready() -> void:
	if not plugin:
		return
	
	MetSys.map_updated.connect(map.queue_redraw)
	mode_group.pressed.connect(mode_pressed)
	get_current_sub_editor()._editor_enter()

func mode_pressed(button: BaseButton):
	get_current_sub_editor()._editor_exit()
	mode = button.get_index()
	get_current_sub_editor()._editor_enter()
	
	map_overlay.queue_redraw()

func layer_changed(l: int):
	current_layer = l
	map.queue_redraw()
	ghost_map.queue_redraw()
	map_overlay.queue_redraw()

func preview_layer_changed(value: float) -> void:
	preview_layer = value
	ghost_map.queue_redraw()

func get_current_sub_editor() -> Control:
	return mode_group.get_buttons()[mode - 1]

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if view_drag != Vector4():
			map_offset = Vector2(view_drag.z, view_drag.w) + (map_overlay.get_local_mouse_position() - Vector2(view_drag.x, view_drag.y)) / MetSys.ROOM_SIZE
			map.queue_redraw()
			ghost_map.queue_redraw()
			map_overlay.queue_redraw()
		else:
			map_overlay.queue_redraw()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				view_drag.x = map_overlay.get_local_mouse_position().x
				view_drag.y = map_overlay.get_local_mouse_position().y
				view_drag.z = map_offset.x
				view_drag.w = map_offset.y
			else:
				view_drag = Vector4()
	
	get_current_sub_editor()._editor_input(event)

func _on_overlay_draw() -> void:
	if not plugin:
		return
	
	map_overlay.draw_set_transform(Vector2(map_offset) * MetSys.ROOM_SIZE)
	
	var sub := get_current_sub_editor()
	sub.top_draw = Callable()
	sub._editor_draw(map_overlay)
	
	map_overlay.draw_set_transform_matrix(Transform2D())
	map_overlay.draw_string(get_theme_font(&"font", &"Label"), Vector2(0, 20), str(get_current_sub_editor().get_cursor_pos()))
	
	if sub.top_draw.is_valid():
		sub.top_draw.call(map_overlay)

func _on_map_draw() -> void:
	if not plugin:
		return
	
	for x in range(-100, 100):
		for y in range(-100, 100):
			MetSys.draw_map_square(map, Vector2i(x, y) + map_offset, Vector3i(x, y, current_layer))

func _on_ghost_map_draw() -> void:
	if not plugin:
		return
	
	if preview_layer == -1 or preview_layer == current_layer:
		return
	
	for x in range(-100, 100):
		for y in range(-100, 100):
			MetSys.draw_map_square(ghost_map, Vector2i(x, y) + map_offset, Vector3i(x, y, preview_layer))

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Q:
			%CurrentLayer.value -= 1
			accept_event()
		elif event.keycode == KEY_E:
			%CurrentLayer.value += 1
			accept_event()

func recenter_view() -> void:
	map_offset = Vector2i(10, 10)
	map_overlay.queue_redraw()
	map.queue_redraw()
