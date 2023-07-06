@tool
extends Control

enum {MODE_LAYOUT = 1, MODE_ROOM_SYMBOL, MODE_ROOM_COLOR, MODE_ROOM_GROUP, MODE_BORDER_TYPE, MODE_BORDER_COLOR, MODE_MAP}

@onready var map_overlay: Control = $MapOverlay
@onready var map: Control = %Map

@export var mode_group: ButtonGroup

const NULL_VECTOR2I = Vector2i(-9999999, -9999999)
var plugin: EditorPlugin
var theme_cache: Dictionary

var drag_from: Vector2i = NULL_VECTOR2I
var view_drag: Vector4
var map_offset := Vector2i(10, 10)

var current_layer: int
var room_under_cursor: MetroidvaniaSystem.MapData.RoomData
var current_hovered_item: Control

func _enter_tree() -> void:
	if owner:
		plugin = owner.plugin

func _ready() -> void:
	if not plugin:
		return
	
	plugin.scene_changed.connect(map_overlay.queue_redraw.unbind(1))
	MetSys.map_updated.connect(map.queue_redraw)

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		theme_cache.marked_collectible_room = get_theme_color(&"marked_collectible_room", &"MetSys")
		theme_cache.current_scene_room = get_theme_color(&"current_scene_room", &"MetSys")
		theme_cache.cursor_color = get_theme_color(&"cursor_color", &"MetSys")
		theme_cache.map_not_assigned = get_theme_color(&"map_not_assigned", &"MetSys")
		theme_cache.map_assigned = get_theme_color(&"map_assigned", &"MetSys")

func layer_changed(l: int):
	current_layer = l
	map.queue_redraw()
	map_overlay.queue_redraw()

func _on_item_hover(item: Control):
	item.mouse_exited.connect(_on_item_unhover.bind(item))
	current_hovered_item = item
	map_overlay.queue_redraw()

func _on_item_unhover(item: Control):
	item.mouse_exited.disconnect(_on_item_unhover)
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
		map_overlay.draw_string(font, Vector2(0, font.get_height()), str(mouse, " ", room_under_cursor.assigned_map))
	else:
		map_overlay.draw_string(font, Vector2(0, font.get_height()), str(mouse), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, theme_cache.map_not_assigned if room_under_cursor else theme_cache.map_assigned)
	
	if map_overlay.cursor_inside:
		map_overlay.draw_rect(Rect2(Vector2(mouse + map_offset) * MetSys.ROOM_SIZE, MetSys.ROOM_SIZE), theme_cache.cursor_color, false, 2)
	
	if get_tree().edited_scene_root.scene_file_path.begins_with(MetSys.settings.map_root_folder):
		var current_scene := get_tree().edited_scene_root.scene_file_path.trim_prefix(MetSys.settings.map_root_folder)
		
		for coords in MetSys.map_data.get_rooms_assigned_to(current_scene):
			if coords.z != current_layer:
				break
			
			map_overlay.draw_rect(Rect2(Vector2(coords.x + map_offset.x, coords.y + map_offset.y) * MetSys.ROOM_SIZE, MetSys.ROOM_SIZE), theme_cache.current_scene_room)
	
	if current_hovered_item:
		var data: Dictionary = current_hovered_item.get_meta(&"data")
		if "coords" in data:
			var coords: Vector3i = data.coords
			if coords.z == current_layer:
				map_overlay.draw_rect(Rect2(Vector2(coords.x + map_offset.x, coords.y + map_offset.y) * MetSys.ROOM_SIZE, MetSys.ROOM_SIZE), theme_cache.marked_collectible_room)
		else:
			for coords in MetSys.map_data.get_rooms_assigned_to(data.map):
				if coords.z != current_layer:
					break
				
				map_overlay.draw_rect(Rect2(Vector2(coords.x + map_offset.x, coords.y + map_offset.y) * MetSys.ROOM_SIZE, MetSys.ROOM_SIZE), theme_cache.marked_collectible_room)

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

func recenter_view() -> void:
	map_offset = Vector2i(10, 10)
	map_overlay.queue_redraw()
	map.queue_redraw()
