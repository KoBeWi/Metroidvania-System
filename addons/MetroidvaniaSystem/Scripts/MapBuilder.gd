extends RefCounted

var rooms: Array[MetroidvaniaSystem.MapData.RoomOverride]

func create_room(at: Vector3i) -> MetroidvaniaSystem.MapData.RoomOverride:
	var room: MetroidvaniaSystem.MapData.RoomOverride = MetSys.map_data.create_custom_room(at)
	rooms.append(room)
	return room

func update_map():
	MetSys.map_updated.emit()
