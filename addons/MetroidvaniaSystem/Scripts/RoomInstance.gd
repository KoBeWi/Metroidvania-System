@tool
## A node representing MetSys room.
##
## RoomInstance is a node that allows for integration between scenes and MetSys database. In editor it will provide drawing for room bounds and in game it provides some helper methods for interacting with the map data. [code]RoomInstance.tscn[/code] scene is provided for convenience. You should add it to every scene used as MetSys room. It's recommended to put the node at [code](0, 0)[/code] global coordinates.
extends Node2D

var GRID_COLOR: Color
var GRID_PASSAGE_COLOR: Color

var cells: Array[Vector3i]
var initialized: bool
var room_name: String

var min_cell := Vector2i.MAX
var max_cell := Vector2i.MIN
var layer: int

signal previews_updated

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		MetSys.current_room = self
	else:
		if not owner:
			return
		
		if owner.get_meta(&"fake_map", false):
			queue_free()
			return
		
		if initialized:
			_update_neighbor_previews.call_deferred()
	
	if initialized:
		return
	initialized = true
	
	if Engine.is_editor_hint():
		MetSys.room_assign_updated.connect(_update_assigned_scene)
		var theme: Theme = load("res://addons/MetroidvaniaSystem/Database/DatabaseTheme.tres")
		GRID_COLOR = theme.get_color(&"scene_cell_border", &"MetSys")
		GRID_PASSAGE_COLOR = theme.get_color(&"scene_room_exit", &"MetSys")
	
	_update_assigned_scene()
	
	if Engine.is_editor_hint():
		_update_neighbor_previews()

func _exit_tree() -> void:
	if MetSys.current_room == self:
		MetSys.current_room = null

func _update_assigned_scene():
	queue_redraw()
	
	var owner_node := owner if owner != null else self
	cells = MetSys.map_data.get_cells_assigned_to_path(owner_node.scene_file_path)
	if cells.is_empty():
		return
	
	room_name = MetSys.map_data.get_room_from_scene_path(owner_node.scene_file_path, false)
	
	layer = cells[0].z
	for p in cells:
		min_cell.x = mini(min_cell.x, p.x)
		min_cell.y = mini(min_cell.y, p.y)
		max_cell.x = maxi(max_cell.x, p.x)
		max_cell.y = maxi(max_cell.y, p.y)

func _update_neighbor_previews():
	get_tree().call_group(&"_MetSys_RoomPreview_", &"queue_free")
	
	for coords in cells:
		var cell_data: MetroidvaniaSystem.MapData.CellData = MetSys.map_data.get_cell_at(coords)
		assert(cell_data)
		for i in 4:
			var fwd: Vector2i = MetroidvaniaSystem.MapData.FWD[i]
			
			if cell_data.borders[i] > 0:
				var next_coords := coords + Vector3i(fwd.x, fwd.y, 0)
				var scene: String = MetSys.map_data.get_assigned_scene_at(next_coords)
				
				if scene.is_empty() or scene == room_name:
					continue
				
				var next_cells: Array[Vector3i] = MetSys.map_data.get_whole_room(next_coords)
				var next_min_cell := Vector2i.MAX
				
				for p in next_cells:
					next_min_cell.x = mini(next_min_cell.x, p.x)
					next_min_cell.y = mini(next_min_cell.y, p.y)
				
				var preview: Control = load("res://addons/MetroidvaniaSystem/Nodes/RoomPreview.tscn").instantiate()
				preview.position = Vector2i(next_coords.x, next_coords.y) - min_cell
				preview.position *= MetSys.settings.in_game_cell_size
				preview.tooltip_text = scene
				preview.offset = Vector2(next_coords.x, next_coords.y) - Vector2(min_cell)
				preview.offset -= Vector2(next_coords.x, next_coords.y) - Vector2(next_min_cell)
				add_child(preview)
				
				var temp_map: Node2D = load(MetSys.get_full_room_path(scene)).instantiate()
				temp_map.modulate.a = 0.5
				temp_map.set_meta(&"fake_map", true)
				
				preview.add_room(temp_map, i, next_min_cell - Vector2i(next_coords.x, next_coords.y))
	
	previews_updated.emit()

## Adjusts the limits of the given [param camera] to be within this room's rectangular bounds.
func adjust_camera_limits(camera: Camera2D):
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = get_size().x
	camera.limit_bottom = get_size().y

## Returns the full size of this room, based on the cells and [code]in_game_cell_size[/code] defined in MetSys Settings.
func get_size() -> Vector2:
	return Vector2(max_cell - min_cell + Vector2i.ONE) * MetSys.settings.in_game_cell_size

## Returns this rooms cells in local coordinates, i.e. with [code](0, 0)[/code] being the top-left cell.
func get_local_cells() -> Array[Vector2i]:
	var ret: Array[Vector2i]
	ret.assign(cells.map(func(coords: Vector3i) -> Vector2i:
		return Vector2i(coords.x - min_cell.x, coords.y - min_cell.y)))
	return ret

## Returns the top-left cell's flat coordinates within the room's rectangle.
func get_base_coords() -> Vector2i:
	return min_cell

## Returns the bottom-right cell's flat coordinates within the room's rectangle.
func get_end_coords() -> Vector2i:
	return max_cell

## Returns the room's layer.
func get_layer() -> int:
	return layer

## Returns the position difference between this RoomInstance and another one, based on their base coords and the in-game cell size. Useful for positioning the player after room transition.
func get_room_position_offset(other: Node2D) -> Vector2:
	return Vector2(get_base_coords() - other.get_base_coords()) * MetSys.settings.in_game_cell_size

## Returns the names of rooms connected to the current room instance. The rooms are determined based on border passages and adjacent cells. Useful for preloading adjacent rooms.
func get_neighbor_rooms() -> Array[String]:
	var ret: Array[String]
	
	for coords in cells:
		var cell_data: MetroidvaniaSystem.MapData.CellData = MetSys.map_data.get_cell_at(coords)
		assert(cell_data)
		for i in 4:
			var fwd: Vector2i = MetroidvaniaSystem.MapData.FWD[i]
			
			if cell_data.borders[i] > 0:
				var scene: String = MetSys.map_data.get_assigned_scene_at(coords + Vector3i(fwd.x, fwd.y, 0))
				if not scene.is_empty() and scene != room_name and not scene in ret:
					ret.append(scene)
	
	return ret

func _draw() -> void:
	if not Engine.is_editor_hint() or cells.is_empty():
		return
	
	for p in cells:
		var coords := Vector2(p.x - min_cell.x, p.y - min_cell.y)
		for i in 4:
			var width := 1
			var color := GRID_COLOR
			if MetSys.map_data.cells[p].get_border(i) > 0:
				width = 2
				color = GRID_PASSAGE_COLOR
			
			match i:
				MetroidvaniaSystem.R:
					draw_rect(Rect2((coords + Vector2.RIGHT) * MetSys.settings.in_game_cell_size + Vector2(-width, 0), Vector2(width, MetSys.settings.in_game_cell_size.y)), color)
				MetroidvaniaSystem.D:
					draw_rect(Rect2((coords + Vector2.DOWN) * MetSys.settings.in_game_cell_size + Vector2(0, -width), Vector2(MetSys.settings.in_game_cell_size.x, width)), color)
				MetroidvaniaSystem.L:
					draw_rect(Rect2(coords * MetSys.settings.in_game_cell_size, Vector2(width, MetSys.settings.in_game_cell_size.y)), color)
				MetroidvaniaSystem.U:
					draw_rect(Rect2(coords * MetSys.settings.in_game_cell_size, Vector2(MetSys.settings.in_game_cell_size.x, width)), color)
