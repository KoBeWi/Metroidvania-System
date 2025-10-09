@tool
extends "res://addons/MetroidvaniaSystem/Database/Editor/SubEditor.gd"#"uid://cyob148ixrqef"

var erase_mode: bool

var dragging_room_from: Vector2i
var dragging_room: Array[Vector3i]
var dragging_room_cells: Array[MetroidvaniaSystem.CellView]
var dragging_drawer: Node2D

func _ready() -> void:
	if is_part_of_edited_scene():
		return
	
	super()
	
	await editor.ready
	
	dragging_drawer = Node2D.new()
	editor.map_view_container.add_child(dragging_drawer)

func _editor_init() -> void:
	room_only_cursor = false

func _editor_enter():
	super()
	%Shortcuts.show()
	%ShortcutPick.hide()
	%ShortcutWhole.hide()
	%ShortcutDrag.show()

func _editor_exit():
	super()
	%Shortcuts.hide()
	%ShortcutWhole.show()
	%ShortcutDrag.hide()

func _update_theme():
	theme_cache.cursor_color = get_theme_color(&"cursor_color", &"MetSys")
	theme_cache.invalid_room_drop_position = get_theme_color(&"invalid_room_drop_position", &"MetSys")

func _editor_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.shift_pressed:
					var under := get_cell_at_cursor()
					if under:
						dragging_room_from = get_cursor_pos()
						dragging_room = MetSys.map_data.get_whole_room(get_coords(get_cursor_pos()))
						var begin := Vector3i.MAX
						for cell in dragging_room:
							begin = begin.min(cell)
						
						
						var diff2 := Vector3i(dragging_room_from.x, dragging_room_from.y, begin.z) - begin
						for cell in dragging_room:
							var view := MetroidvaniaSystem.CellView.new(dragging_drawer.get_canvas_item())
							dragging_room_cells.append(view)
							var diff := cell - begin - diff2
							view.offset = Vector2(diff.x, diff.y)
							view.coords = cell
							view.update()
						
						dragging_drawer.position = Vector2(dragging_room_from + editor.map_offset) * MetSys.CELL_SIZE
						set_dragging_room_visible(false)
						redraw_overlay()
				else:
					drag_from = get_cursor_pos()
			else:
				if drag_from != Vector2i.MAX:
					var rect := get_rect_between(drag_from, get_cursor_pos())
					update_rooms(rect)
					drag_from = Vector2i.MAX
				elif not dragging_room.is_empty():
					var drop_valid := get_cursor_pos() != dragging_room_from
					if drop_valid:
						for coords in dragging_room:
							var offset := get_cell_dragging_offset(coords)
							var offset3 := get_coords(offset)
							
							if not offset3 in dragging_room and MetSys.map_data.get_cell_at(offset3):
								drop_valid = false
					
					if drop_valid:
						for old_coords in dragging_room:
							var new_coords := get_coords(get_cell_dragging_offset(old_coords))
							MetSys.map_data.transfer_cell(old_coords, new_coords)
							editor.update_cell(new_coords)
							undo_handle_transfer(old_coords, new_coords)
					
					for coords in dragging_room:
						editor.update_cell(coords)
					
					set_dragging_room_visible(true)
					dragging_room.clear()
					dragging_room_cells.clear()
					undo_end_with_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				drag_from = get_cursor_pos()
				erase_mode = true
				theme_cache.cursor_color = get_theme_color(&"cursor_color_erase", &"MetSys")
				redraw_overlay()
			else:
				var rect := get_rect_between(drag_from, get_cursor_pos())
				erase_rooms(rect)
				erase_mode = false
				theme_cache.cursor_color = get_theme_color(&"cursor_color", &"MetSys")
				drag_from = Vector2i.MAX
	elif event is InputEventMouseMotion:
		if not dragging_room.is_empty():
			dragging_drawer.position = Vector2(get_cursor_pos() + editor.map_offset) * MetSys.CELL_SIZE

func _editor_draw(map_overlay: CanvasItem):
	super(map_overlay)
	
	if dragging_room.is_empty():
		return
	
	top_draw = func(map_overlay: CanvasItem):
		map_overlay.draw_set_transform_matrix(Transform2D())
		
		for coords in dragging_room:
			var offset := get_cell_dragging_offset(coords)
			var offset3 := get_coords(offset)
			
			if not offset3 in dragging_room and MetSys.map_data.get_cell_at(offset3):
				map_overlay.draw_rect(Rect2(Vector2(editor.map_offset + offset) * MetSys.CELL_SIZE, MetSys.CELL_SIZE), theme_cache.invalid_room_drop_position)

func update_rooms(rect: Rect2i):
	var map_data: MetroidvaniaSystem.MapData = MetSys.map_data
	var changed: bool
	
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var coords := Vector3i(x, y, editor.current_layer)
			
			var cell := map_data.get_cell_at(coords)
			if cell:
				var prev_borders = cell.borders.duplicate()
				
				if x != rect.end.x - 1:
					cell.borders[MetroidvaniaSystem.R] = -1
				if y != rect.end.y - 1:
					cell.borders[MetroidvaniaSystem.D] = -1
				if x != rect.position.x:
					cell.borders[MetroidvaniaSystem.L] = -1
				if y != rect.position.y:
					cell.borders[MetroidvaniaSystem.U] = -1
				
				changed = changed or cell.borders != prev_borders
				if not changed:
					continue
				
				if undo_handle_cell_property(cell, &"borders", prev_borders):
					var prev_assign: String = MetSys.map_data.cells[coords].scene
					if not prev_assign.is_empty():
						var prev_room := remove_assign(coords)
						undo_handle_scene_add(prev_room, prev_assign)
			else:
				cell = map_data.create_cell_at(coords)
				if x == rect.end.x - 1:
					cell.borders[MetroidvaniaSystem.R] = 0
				if y == rect.end.y - 1:
					cell.borders[MetroidvaniaSystem.D] = 0
				if x == rect.position.x:
					cell.borders[MetroidvaniaSystem.L] = 0
				if y == rect.position.y:
					cell.borders[MetroidvaniaSystem.U] = 0
				
				undo_handle_cell_spawn(coords, cell)
				changed = true
	
	if not changed:
		return
	
	editor.update_rect(rect)
	undo_handle_rect_redraw(rect)
	undo_end()

func erase_rooms(rect: Rect2i):
	var map_data: MetroidvaniaSystem.MapData = MetSys.map_data
	
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var coords := Vector3i(x, y, editor.current_layer)
			var cell_data := map_data.get_cell_at(coords)
			
			if not cell_data:
				continue
			
			undo_handle_cell_erase(coords, cell_data)
			
			if x == rect.end.x - 1:
				close_border(Vector2i(x + 1, y), 2)
			if y == rect.end.y - 1:
				close_border(Vector2i(x, y + 1), 3)
			if x == rect.position.x:
				close_border(Vector2i(x - 1, y), 0)
			if y == rect.position.y:
				close_border(Vector2i(x, y - 1), 1)
			
			map_data.erase_cell(coords)
	
	if not undo_active:
		return
	
	rect = rect.grow(1)
	editor.update_rect(rect)
	undo_handle_rect_redraw(rect)
	undo_end()

func remove_assign(coords: Vector3i) -> Array[Vector3i]:
	var ret: Array[Vector3i]
	
	var assigned_scene: String = MetSys.map_data.cells[coords].scene
	if assigned_scene.is_empty():
		return ret
	
	ret.assign(MetSys.map_data.assigned_scenes[assigned_scene].duplicate())
	
	for coords2 in ret:
		MetSys.map_data.cells[coords2].scene = ""
	MetSys.map_data.assigned_scenes.erase(assigned_scene)
	
	return ret

func close_border(pos: Vector2i, border: int):
	var coords := get_coords(pos)
	var cell: MetroidvaniaSystem.MapData.CellData = MetSys.map_data.get_cell_at(coords)
	if cell:
		var old: Variant = cell.borders.duplicate()
		cell.borders[border] = 0
		
		if undo_handle_cell_property(cell, &"borders", old):
			var prev_assign: String = MetSys.map_data.cells[coords].scene
			if not prev_assign.is_empty():
				var prev_room := remove_assign(coords)
				undo_handle_scene_add(prev_room, prev_assign, true)

func get_cell_dragging_offset(coords: Vector3i) -> Vector2i:
	return get_cursor_pos() + Vector2i(coords.x, coords.y) - dragging_room_from

func set_dragging_room_visible(vis: bool):
	for coords in dragging_room:
		var cell: MetroidvaniaSystem.CellView = editor.current_map_view._cache[coords]
		cell.visible = vis
