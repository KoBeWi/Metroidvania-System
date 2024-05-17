@tool
extends EditorScript

const DETAILS = 2

func _run() -> void:
	var instance: MetroidvaniaSystem.RoomInstance = get_scene().get_node_or_null(^"RoomInstance")
	var tilemap: TileMap = get_scene().get_node_or_null(^"TileMap")
	
	if not instance or not tilemap:
		return
	
	var tile_size := tilemap.tile_set.tile_size
	var size: Vector2i = Vector2i(instance.get_size()) / tile_size * DETAILS
	var tiles_per_cell := Vector2i(MetSys.settings.in_game_cell_size) / tile_size * DETAILS
	var used_room_cells := instance.get_local_cells()
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	
	var tmcells := tilemap.get_used_cells(0)
	var tmcells2 := tilemap.get_used_cells(1)
	
	for y in size.y:
		for x in size.x:
			if not Vector2i(x, y) / tiles_per_cell in used_room_cells:
				continue
			
			if not check_cell(Vector2i(x, y), tmcells):
				var v: float
				if check_cell(Vector2i(x + 1, y), tmcells) or check_cell(Vector2i(x - 1, y), tmcells) or check_cell(Vector2i(x, y + 1), tmcells) or check_cell(Vector2i(x, y - 1), tmcells):
					v = 1.0
				elif check_cell(Vector2i(x, y), tmcells2):
					v = 0.3 + absf(sin(x % 10 * 0.1 * TAU) * 0.1)
				else:
					v = 0.5 + absf(sin(y % 10 * 0.1 * TAU) * 0.1)
				
				image.set_pixel(x, y, Color.from_hsv(0, 0, v))
	
	var room_name := get_scene().scene_file_path.trim_prefix(MetSys.settings.map_root_folder)
	image.save_png(preload("res://addons/MetroidvaniaSystem/Template/Scripts/Modules/FogOfMystery.gd").OVERLAYS_PATH.path_join(room_name) + ".png")

func check_cell(vec: Vector2i, cells: Array[Vector2i]) -> bool:
	if DETAILS == 1:
		return vec in cells
	else:
		vec /= DETAILS
		return vec in cells
