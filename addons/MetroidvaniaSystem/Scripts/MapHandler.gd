@tool
extends Node2D

const GRID_COLOR = Color(1, 1, 1, 0.333)
const GRID_PASSAGE_COLOR = Color(1, 0, 1, 0.666)

var rooms: Array[Vector3i]
var initialized: bool

var min_room := Vector2i(999999, 999999)
var max_room := Vector2i(-999999, -999999)
var layer: int

func _enter_tree() -> void:
	if initialized:
		return
	initialized = true
	
	if Engine.is_editor_hint():
		pass
	else:
		MetSys.current_map = self
	
	var owner_node := owner if owner != null else self
	rooms = MetSys.map_data.get_rooms_assigned_to(owner_node.scene_file_path.trim_prefix(MetSys.settings.map_root_folder))
	if rooms.is_empty():
		return
	
	layer = rooms[0].z
	for p in rooms:
		min_room.x = mini(min_room.x, p.x)
		min_room.y = mini(min_room.y, p.y)
		max_room.x = maxi(max_room.x, p.x)
		max_room.y = maxi(max_room.y, p.y)

func adjust_camera_limits(camera: Camera2D):
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = (max_room.x - min_room.x + 1) * MetSys.settings.in_game_room_size.x
	camera.limit_bottom = (max_room.y - min_room.y + 1) * MetSys.settings.in_game_room_size.y

func _draw() -> void:
	if not Engine.is_editor_hint() or rooms.is_empty():
		return
	
	for p in rooms:
		var coords := Vector2(p.x - min_room.x, p.y - min_room.y)
		for i in 4:
			var width := 1
			var color := GRID_COLOR
			if MetSys.map_data.rooms[p].get_border(i) > 0:
				width = 2
				color = GRID_PASSAGE_COLOR
			
			match i:
				MetroidvaniaSystem.R:
					draw_rect(Rect2((coords + Vector2.RIGHT) * MetSys.settings.in_game_room_size + Vector2(-width, 0), Vector2(width, MetSys.settings.in_game_room_size.y)), color)
				MetroidvaniaSystem.D:
					draw_rect(Rect2((coords + Vector2.DOWN) * MetSys.settings.in_game_room_size + Vector2(0, -width), Vector2(MetSys.settings.in_game_room_size.x, width)), color)
				MetroidvaniaSystem.L:
					draw_rect(Rect2(coords * MetSys.settings.in_game_room_size, Vector2(width, MetSys.settings.in_game_room_size.y)), color)
				MetroidvaniaSystem.U:
					draw_rect(Rect2(coords * MetSys.settings.in_game_room_size, Vector2(MetSys.settings.in_game_room_size.x, width)), color)
