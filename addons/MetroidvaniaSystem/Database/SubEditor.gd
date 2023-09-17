@tool
extends Control

const EDITOR_SCRIPT = preload("res://addons/MetroidvaniaSystem/Database/MapEditor.gd")
var editor: EDITOR_SCRIPT
var theme_cache: Dictionary

var use_cursor := true
var room_only_cursor := true

var drag_from: Vector2i = EDITOR_SCRIPT.NULL_VECTOR2I
var highlighted_room: Array[Vector3i]
var highlighted_border := -1

var top_draw: Callable

func _ready() -> void:
	if not owner.plugin:
		return
	
	editor = owner
	_editor_init.call_deferred()

func _editor_init():
	pass

func _update_theme():
	pass

func _editor_enter():
	pass

func _editor_exit():
	pass

func _editor_input(event: InputEvent):
	pass

func _editor_draw(map_overlay: CanvasItem):
	if highlighted_border == -1:
		for p in highlighted_room:
			map_overlay.draw_rect(Rect2(Vector2(p.x, p.y) * MetSys.CELL_SIZE, MetSys.CELL_SIZE), theme_cache.highlighted_room)
	
	if drag_from == EDITOR_SCRIPT.NULL_VECTOR2I:
		if use_cursor and map_overlay.cursor_inside and (not room_only_cursor or get_cell_at_cursor()):
			map_overlay.draw_rect(Rect2(get_cursor_pos() as Vector2 * MetSys.CELL_SIZE, MetSys.CELL_SIZE), theme_cache.cursor_color, false, 2)
	else:
		var rect := get_rect_between(drag_from, get_cursor_pos())
		top_draw = func(map_overlay: CanvasItem): map_overlay.draw_string(get_theme_font(&"font", &"Label"), Vector2(get_cursor_pos()) * MetSys.CELL_SIZE + MetSys.CELL_SIZE * Vector2.UP * 0.5, "%d x %d" % [rect.size.x, rect.size.y])
		
		rect.position *= MetSys.CELL_SIZE
		rect.size *= MetSys.CELL_SIZE
		map_overlay.draw_rect(rect, theme_cache.cursor_color, false, 2)
	
	if highlighted_border > -1:
		if highlighted_room.is_empty():
			draw_border_highlight(map_overlay, get_cursor_pos(), highlighted_border)
		else:
			for p in highlighted_room:
				var cell_data := MetSys.map_data.get_cell_at(p)
				for i in 4:
					if cell_data.borders[i] > -1:
						draw_border_highlight(map_overlay, Vector2(p.x, p.y), i)

func draw_border_highlight(map_overlay: CanvasItem, pos: Vector2, border: int):
		match border:
			MetSys.R:
				map_overlay.draw_rect(Rect2(pos * MetSys.CELL_SIZE + Vector2(MetSys.CELL_SIZE.x * 0.667, 0), MetSys.CELL_SIZE * Vector2(0.333, 1)), theme_cache.border_highlight)
			MetSys.D:
				map_overlay.draw_rect(Rect2(pos * MetSys.CELL_SIZE + Vector2(0, MetSys.CELL_SIZE.y * 0.667), MetSys.CELL_SIZE * Vector2(1, 0.333)), theme_cache.border_highlight)
			MetSys.L:
				map_overlay.draw_rect(Rect2(pos * MetSys.CELL_SIZE, MetSys.CELL_SIZE * Vector2(0.333, 1)), theme_cache.border_highlight)
			MetSys.U:
				map_overlay.draw_rect(Rect2(pos * MetSys.CELL_SIZE, MetSys.CELL_SIZE * Vector2(1, 0.333)), theme_cache.border_highlight)

func get_cursor_pos() -> Vector2i:
	return editor.get_cursor_pos()

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

func get_square_border_idx(borders: Array[int], rel: Vector2) -> int:
	if borders[MetSys.L] > -1 and rel.x < MetSys.CELL_SIZE.x / 3:
		return MetSys.L
	
	if borders[MetSys.R] > -1 and rel.x > MetSys.CELL_SIZE.x - MetSys.CELL_SIZE.x / 3:
		return MetSys.R
	
	if borders[MetSys.U] > -1 and rel.y < MetSys.CELL_SIZE.y / 3:
		return MetSys.U
	
	if borders[MetSys.D] > -1 and rel.y > MetSys.CELL_SIZE.y - MetSys.CELL_SIZE.y / 3:
		return MetSys.D
	
	return -1

func get_cell_at_cursor() -> MetroidvaniaSystem.MapData.CellData:
	return MetSys.map_data.get_cell_at(get_coords(get_cursor_pos()))

func mark_modified():
	editor.plugin.modified = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		theme_cache.highlighted_room = get_theme_color(&"highlighted_room", &"MetSys")
		theme_cache.border_highlight = get_theme_color(&"border_highlight", &"MetSys")
		theme_cache.cursor_color = get_theme_color(&"cursor_color", &"MetSys")
		_update_theme()
