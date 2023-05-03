@tool
extends Control

enum {MODE_LAYOUT = 1, MODE_ROOM_SYMBOL, MODE_ROOM_COLOR, MODE_ROOM_GROUP, MODE_BORDER_TYPE, MODE_BORDER_COLOR, MODE_MAP}

@onready var map_overlay: Control = $MapOverlay
@onready var map: Control = %Map
@onready var panel: PanelContainer = $Panel

@export var mode_group: ButtonGroup

const NULL_VECTOR2I = Vector2i(-9999999, -9999999)
var plugin: EditorPlugin:
	set(p):
		plugin = p
		plugin.scene_changed.connect(map_overlay.queue_redraw.unbind(1))
		MetSys.map_updated.connect(map.queue_redraw)
		%Stats.plugin = plugin

var drag_from: Vector2i = NULL_VECTOR2I
var view_drag: Vector4
var map_offset := Vector2i(10, 10)

var current_layer: int
var room_under_cursor: MetroidvaniaSystem.MapData.RoomData
var current_hovered_item: Control

func layer_changed(l: int):
	current_layer = l
	map.queue_redraw()
	map_overlay.queue_redraw()

func _on_item_hover(item: Control):
	item.unhovered.connect(_on_item_unhover.bind(item))
	current_hovered_item = item
	map_overlay.queue_redraw()

func _on_item_unhover(item: Control):
	item.unhovered.disconnect(_on_item_unhover)
	if item == current_hovered_item:
		current_hovered_item = null
		map_overlay.queue_redraw()

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if view_drag != Vector4():
			map_offset = Vector2(view_drag.z, view_drag.w) + (map_overlay.get_local_mouse_position() - Vector2(view_drag.x, view_drag.y)) / MetSys.ROOM_SIZE
			map.queue_redraw()
			map_overlay.queue_redraw()
		else:
			map_overlay.queue_redraw()
		
		var cursor := get_cursor_pos()
		room_under_cursor = MetSys.map_data.get_room_at(Vector3i(cursor.x, cursor.y, current_layer))
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and room_under_cursor and not room_under_cursor.assigned_map.is_empty():
				plugin.get_editor_interface().open_scene_from_path(MetSys.settings.map_root_folder.path_join(room_under_cursor.assigned_map))
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				view_drag.x = map_overlay.get_local_mouse_position().x
				view_drag.y = map_overlay.get_local_mouse_position().y
				view_drag.z = map_offset.x
				view_drag.w = map_offset.y
			else:
				view_drag = Vector4()

func _on_overlay_draw() -> void:
	if not plugin:
		return
	
	var mouse := get_cursor_pos()
	
	var font := get_theme_font(&"font", &"Label")
	if room_under_cursor and not room_under_cursor.assigned_map.is_empty():
		map_overlay.draw_string(font, Vector2(0, panel.size.y + font.get_height()), str(mouse, " ", room_under_cursor.assigned_map))
	else:
		map_overlay.draw_string(font, Vector2(0, panel.size.y + font.get_height()), str(mouse), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.RED if room_under_cursor else Color.WHITE)
	
	if not $Panel.get_global_rect().has_point(get_global_mouse_position()):
		map_overlay.draw_rect(Rect2(Vector2(mouse + map_offset) * MetSys.ROOM_SIZE, MetSys.ROOM_SIZE), Color.GREEN, false, 2)
	
	if get_tree().edited_scene_root.scene_file_path.begins_with(MetSys.settings.map_root_folder):
		var current_scene := get_tree().edited_scene_root.scene_file_path.trim_prefix(MetSys.settings.map_root_folder)
		
		for coords in MetSys.map_data.get_rooms_assigned_to(current_scene):
			if coords.z != current_layer:
				break
			
			map_overlay.draw_rect(Rect2(Vector2(coords.x + map_offset.x, coords.y + map_offset.y) * MetSys.ROOM_SIZE, MetSys.ROOM_SIZE), Color(Color.RED, 0.5))
	
	if current_hovered_item:
		if "coords" in current_hovered_item.data:
			var coords: Vector3i = current_hovered_item.data.coords
			if coords.z == current_layer:
				map_overlay.draw_rect(Rect2(Vector2(coords.x + map_offset.x, coords.y + map_offset.y) * MetSys.ROOM_SIZE, MetSys.ROOM_SIZE), Color(Color.RED, 0.5))
		else:
			for coords in MetSys.map_data.get_rooms_assigned_to(current_hovered_item.data.map):
				if coords.z != current_layer:
					break
				
				map_overlay.draw_rect(Rect2(Vector2(coords.x + map_offset.x, coords.y + map_offset.y) * MetSys.ROOM_SIZE, MetSys.ROOM_SIZE), Color(Color.RED, 0.5))

func _on_map_draw() -> void:
	if not plugin:
		return
	
	for x in range(-100, 100):
		for y in range(-100, 100):
			MetSys.draw_map_square(map, Vector2i(x, y) + map_offset, Vector3i(x, y, current_layer))

func get_cursor_pos() -> Vector2i:
	var pos := (map_overlay.get_local_mouse_position() - MetSys.ROOM_SIZE / 2).snapped(MetSys.ROOM_SIZE) / MetSys.ROOM_SIZE as Vector2i - map_offset
	return pos

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
