extends RefCounted

const SIMPLE_STORABLE_PROPERTIES: Array[StringName] = [&"discovered_rooms", &"registered_objects", &"stored_objects", &"room_markers"]

var discovered_rooms: Dictionary#[Vector3i, int]
var registered_objects: Dictionary#[String, bool]
var stored_objects: Dictionary#[String, bool]

var room_markers: Dictionary#[Vector3i, Array]
var room_overrides: Dictionary#[RoomData, RoomOverride]

func discover_room(room: Vector3i):
	if discovered_rooms.get(room, 0) < 1:
		discovered_rooms[room] = 1

func explore_room(room: Vector3i):
	if discovered_rooms.get(room, 0) < 2:
		discovered_rooms[room] = 2
		MetSys.map_updated.emit()

func is_room_discovered(room: Vector3i) -> int:
	return discovered_rooms.get(room, 0)

func register_storable_object(object: Object) -> bool:
	var id: String = MetSys.get_object_id(object)
	if not id in registered_objects:
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

func add_room_override(room: MetroidvaniaSystem.MapData.RoomData) -> MetroidvaniaSystem.MapData.RoomOverride:
	if not room in room_overrides:
		room_overrides[room] = MetroidvaniaSystem.MapData.RoomOverride.new(room)
	return room_overrides[room]

func remove_room_override(room: MetroidvaniaSystem.MapData.RoomData) -> bool:
	var override := room_overrides.get(room)
	if override:
		override._cleanup_assigned_map()
	room_overrides.erase(room)
	return override != null

func add_room_marker(coords: Vector3i, symbol: int):
	if not coords in room_markers:
		room_markers[coords] = []
	
	room_markers[coords].append(symbol)
	MetSys.map_updated.emit()

func remove_room_marker(coords: Vector3i, symbol: int):
	assert(coords in room_markers)
	var idx: int = room_markers[coords].find(symbol)
	assert(idx >= 0)
	room_markers[coords].remove_at(idx)
	if room_markers[coords].is_empty():
		room_markers.erase(coords)
	MetSys.map_updated.emit()

func get_data() -> Dictionary:
	var data: Dictionary
	
	for property in SIMPLE_STORABLE_PROPERTIES:
		data[property] = get(property)
	
	data[&"room_overrides"] = room_overrides.keys().map(func(room):
		var coords: Vector3i = MetSys.map_data.rooms.find_key(room)
		return room_overrides[room]._get_override_string(coords))
	
	return data

func set_data(data: Dictionary):
	if data.is_empty():
		return
	
	for property in SIMPLE_STORABLE_PROPERTIES:
		if property in data:
			set(property, data[property])
	
	for override_string in data.room_overrides:
		var override: MetroidvaniaSystem.MapData.RoomOverride = MetroidvaniaSystem.MapData.RoomOverride.load_from_line(override_string)
		room_overrides[override.original_room] = override
