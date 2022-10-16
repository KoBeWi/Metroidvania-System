extends RefCounted

var discovered_rooms: Dictionary

func discover_room(room: Vector3i):
	discovered_rooms[room] = 1

func explore_room(room: Vector3i):
	discovered_rooms[room] = 2

func is_room_discovered(room: Vector3i) -> bool:
	return discovered_rooms.get(room, 0)

func get_data() -> Dictionary:
	return {discovered_rooms = discovered_rooms}

func set_data(data: Dictionary):
	discovered_rooms = data.get("discovered_rooms", {})
