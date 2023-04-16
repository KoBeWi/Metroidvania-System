extends Control

const EDITOR_SCRIPT = preload("res://addons/MetroidvaniaSystem/Database/MapEditor.gd")
var editor: EDITOR_SCRIPT
var plugin: EditorPlugin

var use_cursor := true
var room_only_cursor := true
var cursor_color := Color.GREEN

var drag_from: Vector2i = EDITOR_SCRIPT.NULL_VECTOR2I
var highlighted_room: Array[Vector3i]
var highlighted_border := -1

var top_draw: Callable

func _enter_tree() -> void:
	plugin = owner.plugin

func _ready() -> void:
	if not plugin:
		return
	
	editor = owner

func _editor_enter():
	pass

func _editor_exit():
	pass

func _editor_input(event: InputEvent):
	pass

func _editor_draw(map_overlay: CanvasItem):
	var room_size: Vector2 = MetSys.ROOM_SIZE
	
	for p in highlighted_room:
		map_overlay.draw_rect(Rect2(Vector2(p.x, p.y) * room_size, room_size), Color(1, 1, 0, 0.25))
	
	if drag_from == EDITOR_SCRIPT.NULL_VECTOR2I:
		if use_cursor and (not room_only_cursor or get_room_at_cursor()) and map_overlay.get_local_mouse_position().x >= 0 and map_overlay.get_local_mouse_position().y >= 0:
			map_overlay.draw_rect(Rect2(get_cursor_pos() as Vector2 * room_size, room_size), Color.GREEN, false, 2)
	else:
		var rect := get_rect_between(drag_from, get_cursor_pos())
		top_draw = func(map_overlay: CanvasItem): map_overlay.draw_string(get_theme_font(&"font", &"Label"), Vector2(0, 40), "%d x %d" % [rect.size.x, rect.size.y])
		
		rect.position *= room_size as Vector2
		rect.size *= room_size as Vector2
		map_overlay.draw_rect(rect, cursor_color, false, 2)
	
	if highlighted_border > -1:
		match highlighted_border:
			MetSys.R:
				map_overlay.draw_rect(Rect2(get_cursor_pos() as Vector2 * room_size + Vector2(room_size.x * 0.667, 0), room_size * Vector2(0.333, 1)), Color(0, 1, 0, 0.5))
			MetSys.D:
				map_overlay.draw_rect(Rect2(get_cursor_pos() as Vector2 * room_size + Vector2(0, room_size.y * 0.667), room_size * Vector2(1, 0.333)), Color(0, 1, 0, 0.5))
			MetSys.L:
				map_overlay.draw_rect(Rect2(get_cursor_pos() as Vector2 * room_size, room_size * Vector2(0.333, 1)), Color(0, 1, 0, 0.5))
			MetSys.U:
				map_overlay.draw_rect(Rect2(get_cursor_pos() as Vector2 * room_size, room_size * Vector2(1, 0.333)), Color(0, 1, 0, 0.5))

func get_cursor_pos() -> Vector2i:
	var room_size: Vector2 = MetSys.ROOM_SIZE
	var pos := (editor.map_overlay.get_local_mouse_position() - room_size / 2).snapped(room_size) / room_size as Vector2i
	return pos - editor.map_offset

func get_coords(p: Vector2i, layer := editor.current_layer) -> Vector3i:
	return Vector3i(p.x, p.y, layer)

func get_rect_between(point1: Vector2, point2: Vector2) -> Rect2:
	var start: Vector2
	start.x = minf(point1.x, point2.x)
	start.y = minf(point1.y, point2.y)
	
	var end: Vector2
	end.x = maxf(point1.x, point2.x)
	end.y = maxf(point1.y, point2.y)
	
	return Rect2(start, Vector2.ONE).expand(end + Vector2.ONE)

func get_square_border_idx(rel: Vector2) -> int:
	if rel.x < MetSys.ROOM_SIZE.x / 3:
		return MetSys.L
	
	if rel.x > MetSys.ROOM_SIZE.x - MetSys.ROOM_SIZE.x / 3:
		return MetSys.R
	
	if rel.y < MetSys.ROOM_SIZE.y / 3:
		return MetSys.U
	
	if rel.y > MetSys.ROOM_SIZE.y - MetSys.ROOM_SIZE.y / 3:
		return MetSys.D
	
	return -1

func get_room_at_cursor() -> MetroidvaniaSystem.MapData.RoomData:
	return MetSys.map_data.get_room_at(get_coords(get_cursor_pos()))