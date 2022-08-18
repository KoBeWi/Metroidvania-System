extends Control

@onready var map_overlay: Control = $MapOverlay
@onready var map: Control = %Map

const NULL_VECTOR2I = Vector2i(-9999999, -9999999)

var drag_from: Vector2i = NULL_VECTOR2I
var view_drag: Vector4
var map_offset := Vector2i(10, 10)
var erase_mode: bool

var current_layer: int

## TODO: modes: room mode - layout, color, symbol; edge mode - type, color

func get_cursor_pos() -> Vector2i:
	var room_size: Vector2 = MetroidvaniaSystem.ROOM_SIZE
	var pos := (map_overlay.get_local_mouse_position() - room_size / 2).snapped(room_size) / room_size as Vector2i
	return pos - map_offset

func get_rect_between(point1: Vector2, point2: Vector2) -> Rect2:
	var start: Vector2
	start.x = minf(point1.x, point2.x)
	start.y = minf(point1.y, point2.y)
	
	var end: Vector2
	end.x = maxf(point1.x, point2.x)
	end.y = maxf(point1.y, point2.y)
	
	return Rect2(start, Vector2.ONE).expand(end + Vector2.ONE)

func update_rooms(rect: Rect2i):
	var map_data: Dictionary = MetroidvaniaSystem.map_data
	
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var coords := Vector3i(x, y, current_layer)
			
			var room: Dictionary = map_data.get(coords, {})
			if room.is_empty():
				room.borders = [-1, -1, -1, -1]
				if x == rect.end.x - 1:
					room.borders[0] = 0
				if y == rect.end.y - 1:
					room.borders[1] = 0
				if x == rect.position.x:
					room.borders[2] = 0
				if y == rect.position.y:
					room.borders[3] = 0
				map_data[coords] = room
			else:
				if x != rect.end.x - 1:
					room.borders[0] = -1
				if y != rect.end.y - 1:
					room.borders[1] = -1
				if x != rect.position.x:
					room.borders[2] = -1
				if y != rect.position.y:
					room.borders[3] = -1
	
	map.update()

func erase_rooms(rect: Rect2i):
	var map_data: Dictionary = MetroidvaniaSystem.map_data
	
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var coords := Vector3i(x, y, current_layer)
			
			if x == rect.end.x - 1:
				close_border(Vector2i(x + 1, y), 2)
			if y == rect.end.y - 1:
				close_border(Vector2i(x, y + 1), 3)
			if x == rect.position.x:
				close_border(Vector2i(x - 1, y), 0)
			if y == rect.position.y:
				close_border(Vector2i(x, y - 1), 1)
			
			map_data.erase(coords)
	
	map.update()

func close_border(pos: Vector2i, border: int):
	var coords := Vector3i(pos.x, pos.y, current_layer)
	var room: Dictionary = MetroidvaniaSystem.map_data.get(coords, {})
	
	if not room.is_empty():
		room.borders[border] = 0

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if view_drag != Vector4():
			map_offset = (Vector2i(view_drag.z, view_drag.w) + Vector2i(map_overlay.get_local_mouse_position() - Vector2(view_drag.x, view_drag.y)) / MetroidvaniaSystem.ROOM_SIZE)
			map.update()
		else:
			map_overlay.update()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_from = get_cursor_pos()
			else:
				var rect := get_rect_between(drag_from, get_cursor_pos())
				rect.position -= map.position / Vector2(MetroidvaniaSystem.ROOM_SIZE)
				update_rooms(rect)
				drag_from = NULL_VECTOR2I
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				drag_from = get_cursor_pos()
				erase_mode = true
				update()
			else:
				var rect := get_rect_between(drag_from, get_cursor_pos())
				rect.position -= map.position / Vector2(MetroidvaniaSystem.ROOM_SIZE)
				erase_rooms(rect)
				erase_mode = false
				drag_from = NULL_VECTOR2I
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				view_drag.x = map_overlay.get_local_mouse_position().x
				view_drag.y = map_overlay.get_local_mouse_position().y
				view_drag.z = map_offset.x
				view_drag.w = map_offset.y
			else:
				view_drag = Vector4()

func _on_map_draw() -> void:
	for x in range(-100, 100):
		for y in range(-100, 100):
			MetroidvaniaSystem.draw_map_square(map, Vector2i(x, y) + map_offset, Vector3i(x, y, current_layer))

func _exit_tree() -> void:
	save_map_data()

func save_map_data():
	var file := File.new()
	file.open(MetroidvaniaSystem.map_root_folder.plus_file("MapData.txt"), File.WRITE)
	
	for coords in MetroidvaniaSystem.map_data:
		file.store_line("[%s,%s,%s]" % [coords.x, coords.y, coords.z])
		
		var room_data: Dictionary = MetroidvaniaSystem.map_data[coords]
		file.store_line("%s,%s,%s,%s" % [room_data.borders[0], room_data.borders[1], room_data.borders[2], room_data.borders[3]])

func _on_overlay_draw() -> void:
	var room_size: Vector2i = MetroidvaniaSystem.ROOM_SIZE
	
	if drag_from == NULL_VECTOR2I:
		map_overlay.draw_rect(Rect2((get_cursor_pos() + map_offset) * room_size, room_size), Color.GREEN, false, 2)
	else:
		var rect := get_rect_between(drag_from, get_cursor_pos())
		rect.position += Vector2(map_offset)
		rect.position *= room_size as Vector2
		rect.size *= room_size as Vector2
		map_overlay.draw_rect(rect, Color.RED if erase_mode else Color.GREEN, false, 2)
	
	map_overlay.draw_string(get_theme_font(&"font", &"Label"), Vector2(0, 20), str(get_cursor_pos()))
