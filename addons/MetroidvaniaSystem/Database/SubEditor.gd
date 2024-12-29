@tool
extends Control

const EDITOR_SCRIPT = preload("res://addons/MetroidvaniaSystem/Database/MapEditor.gd")
var editor: EDITOR_SCRIPT
var theme_cache: Dictionary

var undo_active: bool
var had_undo_change: bool

var use_cursor := true
var room_only_cursor := true
var overlay_mode: bool
var update_neighbors: bool

var drag_from: Vector2i = Vector2i.MAX
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
	
	if drag_from == Vector2i.MAX:
		if use_cursor and editor.cursor_inside and (not room_only_cursor or get_cell_at_cursor()):
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

func redraw_overlay():
	editor.map_overlay.queue_redraw()

func redraw_overlay_if_needed():
	if editor.get_current_sub_editor().overlay_mode:
		redraw_overlay()

func undo_begin():
	editor.undo_redo.create_action("MetSys")
	undo_active = true

func undo_handle_cell_property(cell: Object, property: StringName, old_value: Variant) -> bool:
	var new_value: Variant = cell.get(property)
	if new_value == old_value:
		return false
	
	if not undo_active:
		undo_begin()
	
	editor.undo_redo.add_do_property(cell, property, new_value)
	editor.undo_redo.add_undo_property(cell, property, old_value)
	had_undo_change = true
	return true

func undo_handle_cell_spawn(coords: Vector3i, cell: Object):
	if not undo_active:
		undo_begin()
	
	editor.undo_redo.add_do_method(MetSys.map_data.insert_cell_at.bind(coords, cell))
	editor.undo_redo.add_undo_method(MetSys.map_data.erase_cell.bind(coords))
	had_undo_change = true

func undo_handle_cell_erase(coords: Vector3i, cell: Object):
	if not undo_active:
		undo_begin()
	
	editor.undo_redo.add_do_method(MetSys.map_data.erase_cell.bind(coords))
	editor.undo_redo.add_undo_method(MetSys.map_data.insert_cell_at.bind(coords, cell))
	for group_id in MetSys.map_data.cell_groups:
		if coords in MetSys.map_data.cell_groups[group_id]:
			undo_handle_group_remove(coords, group_id)
	
	had_undo_change = true

func undo_handle_transfer(from_coords: Vector3i, to_coords: Vector3i):
	if not undo_active:
		undo_begin()
	
	editor.undo_redo.add_do_method(MetSys.map_data.transfer_cell.bind(from_coords, to_coords))
	editor.undo_redo.add_undo_method(MetSys.map_data.transfer_cell.bind(to_coords, from_coords))
	undo_handle_cell_redraw(from_coords)
	undo_handle_cell_redraw(to_coords)
	
	had_undo_change = true

func undo_handle_group_add(coords: Vector3i, group_id: int):
	if not undo_active:
		undo_begin()
	
	editor.undo_redo.add_do_method(func(): MetSys.map_data.cell_groups[group_id].append(coords))
	editor.undo_redo.add_undo_method(func(): MetSys.map_data.cell_groups[group_id].erase(coords))
	had_undo_change = true

func undo_handle_group_remove(coords: Vector3i, group_id: int):
	if not undo_active:
		undo_begin()
	
	editor.undo_redo.add_do_method(func(): MetSys.map_data.cell_groups[group_id].erase(coords))
	editor.undo_redo.add_undo_method(func(): MetSys.map_data.cell_groups[group_id].append(coords))
	had_undo_change = true

func undo_handle_element_add(coords: Vector3i, element: MetroidvaniaSystem.MapData.CustomElement):
	if not undo_active:
		undo_begin()
	
	editor.undo_redo.add_do_method(func(): MetSys.map_data.custom_elements[coords] = element)
	editor.undo_redo.add_undo_method(func(): MetSys.map_data.custom_elements.erase(coords))
	editor.undo_redo.add_do_method(func(): editor.current_map_view.update_custom_element_at(coords))
	editor.undo_redo.add_undo_method(func(): editor.current_map_view.update_custom_element_at(coords))
	had_undo_change = true

func undo_handle_element_remove(coords: Vector3i, element: MetroidvaniaSystem.MapData.CustomElement):
	if not undo_active:
		undo_begin()
	
	editor.undo_redo.add_do_method(func(): MetSys.map_data.custom_elements.erase(coords))
	editor.undo_redo.add_undo_method(func(): MetSys.map_data.custom_elements[coords] = element)
	editor.undo_redo.add_do_method(func(): editor.current_map_view.update_custom_element_at(coords))
	editor.undo_redo.add_undo_method(func(): editor.current_map_view.update_custom_element_at(coords))
	had_undo_change = true

func undo_handle_scene_add(room: Array[Vector3i], old_scene: String, undo_only := false):
	if not undo_active:
		undo_begin()
	
	var new_scene := MetSys.map_data.get_cell_at(room[0]).assigned_scene
	
	if not undo_only:
		editor.undo_redo.add_do_method(switch_scene.bind(room, new_scene, old_scene))
	editor.undo_redo.add_undo_method(switch_scene.bind(room, old_scene, new_scene))
	had_undo_change = true

func undo_handle_scene_remove(room: Array[Vector3i], old_scene: String):
	if not undo_active:
		undo_begin()
	
	editor.undo_redo.add_do_method(switch_scene.bind(room, "", old_scene))
	editor.undo_redo.add_undo_method(switch_scene.bind(room, old_scene, ""))
	had_undo_change = true

func switch_scene(room: Array[Vector3i], new_scene: String, old_scene: String):
	for coords in room:
		var cell_data := MetSys.map_data.get_cell_at(coords)
		if not cell_data:
			continue
		
		cell_data.assigned_scene = new_scene
		
		if not new_scene.is_empty():
			if not new_scene in MetSys.map_data.assigned_scenes:
				MetSys.map_data.assigned_scenes[new_scene] = []
			MetSys.map_data.assigned_scenes[new_scene].append(coords)
	
	if not old_scene.is_empty():
		for coords in room:
			MetSys.map_data.assigned_scenes[old_scene].erase(coords)
		
		if MetSys.map_data.assigned_scenes[old_scene].is_empty():
			MetSys.map_data.assigned_scenes.erase(old_scene)
	
	MetSys.room_assign_updated.emit()

func undo_end():
	if not undo_active:
		return
	
	editor.undo_redo.commit_action(false)
	had_undo_change = false
	undo_active = false
	editor.update_name()

func undo_end_with_redraw():
	if had_undo_change:
		editor.undo_redo.add_do_method(redraw_overlay_if_needed)
		editor.undo_redo.add_undo_method(redraw_overlay_if_needed)
	undo_end()

func undo_handle_cell_redraw(coords: Vector3i):
	editor.undo_redo.add_do_method(editor.update_cell.bind(coords))
	editor.undo_redo.add_undo_method(editor.update_cell.bind(coords))

func undo_handle_rect_redraw(rect: Rect2i):
	editor.undo_redo.add_do_method(editor.update_rect.bind(rect))
	editor.undo_redo.add_undo_method(editor.update_rect.bind(rect))

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		theme_cache.highlighted_room = get_theme_color(&"highlighted_room", &"MetSys")
		theme_cache.border_highlight = get_theme_color(&"border_highlight", &"MetSys")
		theme_cache.cursor_color = get_theme_color(&"cursor_color", &"MetSys")
		_update_theme()

func can_drop_data(at_position: Vector2, data) -> bool:
	return false

func drop_data(at_position: Vector2, data) -> void:
	pass
