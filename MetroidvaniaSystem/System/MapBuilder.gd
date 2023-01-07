extends RefCounted

func create_room(at: Vector3i) -> MetroidvaniaSystem.MapData.RoomData:
	return MetSys.map_data.create_custom_room()

func update_map():
	MetSys.map_changed.emit()
