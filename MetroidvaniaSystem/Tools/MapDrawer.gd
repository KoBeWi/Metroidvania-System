@tool
extends Node2D

func _ready() -> void:
	MetroidvaniaSystem.reload_data()

func _draw() -> void:
	var rooms: Array[Vector3i] = MetroidvaniaSystem.assigned_maps.get(owner.scene_file_path, [])
	
	var min_room: Vector2i = Vector2i(99999, 99999)
	for p in rooms:
		min_room.x = mini(min_room.x, p.x)
		min_room.y = mini(min_room.y, p.y)
	
	for p in rooms:
		var coord := Vector2(p.x - min_room.x, p.y - min_room.y)
		draw_rect(Rect2(coord * MetroidvaniaSystem.in_game_room_size, MetroidvaniaSystem.in_game_room_size), Color.WHITE, false, 2)
