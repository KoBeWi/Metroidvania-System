@tool
extends Node2D
## TODO: chyba powinno się usuwać (MetSys.current_room = null

var GRID_COLOR: Color
var GRID_PASSAGE_COLOR: Color

var cells: Array[Vector3i]
var initialized: bool
var room_name: String

var min_cell := Vector2i(999999, 999999)
var max_cell := Vector2i(-999999, -999999)
var layer: int

func _enter_tree() -> void:
	if initialized:
		return
	initialized = true
	
	if Engine.is_editor_hint():
		MetSys.room_assign_updated.connect(_update_assigned_scene)
		var theme: Theme = load("res://addons/MetroidvaniaSystem/Database/DatabaseTheme.tres")
		GRID_COLOR = theme.get_color(&"scene_cell_border", &"MetSys")
		GRID_PASSAGE_COLOR = theme.get_color(&"scene_room_exit", &"MetSys")
	else:
		MetSys.current_room = self
	
	_update_assigned_scene()

func _update_assigned_scene():
	queue_redraw()
	
	var owner_node := owner if owner != null else self
	room_name = owner_node.scene_file_path.trim_prefix(MetSys.settings.map_root_folder)
	cells = MetSys.map_data.get_cells_assigned_to(room_name)
	if cells.is_empty():
		return
	
	layer = cells[0].z
	for p in cells:
		min_cell.x = mini(min_cell.x, p.x)
		min_cell.y = mini(min_cell.y, p.y)
		max_cell.x = maxi(max_cell.x, p.x)
		max_cell.y = maxi(max_cell.y, p.y)

func adjust_camera_limits(camera: Camera2D):
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = get_size().x
	camera.limit_bottom = get_size().y

func get_size() -> Vector2:
	return Vector2(max_cell - min_cell + Vector2i.ONE) * MetSys.settings.in_game_cell_size

func get_local_cells() -> Array[Vector2i]:
	var ret: Array[Vector2i]
	ret.assign(cells.map(func(coords: Vector3i) -> Vector2i:
		return Vector2i(coords.x - min_cell.x, coords.y - min_cell.y)))
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
