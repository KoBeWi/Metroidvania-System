extends RefCounted

var discovered_rooms: Dictionary
var room_symbols: Dictionary
var registered_objects: Dictionary
var stored_objects: Dictionary

func discover_room(room: Vector3i):
	if discovered_rooms.get(room, 0) < 1:
		discovered_rooms[room] = 1

func explore_room(room: Vector3i):
	if discovered_rooms.get(room, 0) < 2:
		discovered_rooms[room] = 2

func is_room_discovered(room: Vector3i) -> int:
	return discovered_rooms.get(room, 0)

func register_storable_object(object: Object) -> bool:
	var id: String = MetSys.get_object_id(object)
	if not object in registered_objects:
		registered_objects[id] = true
		return true
	return false

func store_object(object: Object):
	var id: String = MetSys.get_object_id(object)
	assert(id in registered_objects)
	assert(not id in stored_objects)
	registered_objects.erase(id)
	stored_objects[id] = true

func is_object_stored(object: Object) -> bool:
	var id: String = MetSys.get_object_id(object)
	return id in stored_objects

func add_room_symbol(coords: Vector3i, symbol: int):
	if not coords in room_symbols:
		room_symbols[coords] = []
	
	room_symbols[coords].append(symbol)
	MetSys.map_updated.emit()

func remove_room_symbol(coords: Vector3i, symbol: int):
	assert(coords in room_symbols)
	var idx: int = room_symbols[coords].find(symbol)
	assert(idx >= 0)
	room_symbols[coords].remove_at(idx)
	if room_symbols[coords].is_empty():
		room_symbols.erase(coords)
	MetSys.map_updated.emit()

func get_data() -> Dictionary:
	return {discovered_rooms = discovered_rooms}

func set_data(data: Dictionary):
	discovered_rooms = data.get("discovered_rooms", {})
