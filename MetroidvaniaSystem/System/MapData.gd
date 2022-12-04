enum { R, D, L, U }
const FWD = {R: Vector2i.RIGHT, D: Vector2i.DOWN, L: Vector2i.LEFT, U: Vector2i.UP}

class RoomData:
	var borders: Array[int] = [-1, -1, -1, -1]
	var symbol := -1
	var assigned_map: String

var NULL_ROOM := RoomData.new()

var rooms: Dictionary#[Vector3i, RoomData]
var assigned_maps: Dictionary#[String, Array[Vector3i]]
var room_groups: Dictionary#[int, Array[Vector3i]]

func load_data():
	var file := FileAccess.open(MetSys.map_root_folder.path_join("MapData.txt"), FileAccess.READ)
	
	var data := file.get_as_text().split("\n")
	var i: int
	
	var is_in_groups := true
	while i < data.size():
		var line := data[i]
		if line.begins_with("["):
			is_in_groups = false
			line = line.trim_prefix("[").trim_suffix("]")
			
			var coords: Vector3i
			coords.x = line.get_slice(",", 0).to_int()
			coords.y = line.get_slice(",", 1).to_int()
			coords.z = line.get_slice(",", 2).to_int()
			
			i += 1
			line = data[i]
			
			var room_data := RoomData.new()
			for j in 4:
				room_data.borders[j] = line.get_slice(",", j).to_int()
			
			var assigned_map := line.get_slice("|", 1)
			if not assigned_map.is_empty():
				assigned_maps[assigned_map] = [coords]
				room_data.assigned_map = assigned_map
			
			rooms[coords] = room_data
		elif is_in_groups:
			var group_data := data[i].split(":")
			var group_id := group_data[0].to_int()
			var rooms_in_group: Array
			for j in range(1, group_data.size()):
				var coords: Vector3i
				coords.x = group_data[j].get_slice(",", 0).to_int()
				coords.y = group_data[j].get_slice(",", 1).to_int()
				coords.z = group_data[j].get_slice(",", 2).to_int()
				rooms_in_group.append(coords)
			
			room_groups[group_id] = rooms_in_group
		
		i += 1
	
	for map in assigned_maps.keys():
		var assigned_rooms: Array[Vector3i] = assigned_maps[map]
		assigned_maps[map] = get_whole_room(assigned_rooms[0])

func save_data():
	var file := FileAccess.open(MetSys.map_root_folder.path_join("MapData.txt"), FileAccess.WRITE)
	
	for group in room_groups:
		if room_groups[group].is_empty():
			continue
		
		var line: PackedStringArray
		line.append(str(group))
		for coords in room_groups[group]:
			line.append("%s,%s,%s" % [coords.x, coords.y, coords.z])
		
		file.store_line(":".join(line))
	
	for coords in rooms:
		file.store_line("[%s,%s,%s]" % [coords.x, coords.y, coords.z])
		
		var room_data := get_room_at(coords)
		file.store_line("%s,%s,%s,%s|%s" % [
			room_data.borders[0], room_data.borders[1], room_data.borders[2], room_data.borders[3],
			room_data.assigned_map.trim_prefix(MetSys.map_root_folder).trim_prefix("/")])

func get_room_at(coords: Vector3i) -> RoomData:
	return rooms.get(coords)

func create_room_at(coords: Vector3i) -> RoomData:
	rooms[coords] = RoomData.new()
	return rooms[coords]

func get_whole_room(at: Vector3i) -> Array[Vector3i]:
	var room: Array[Vector3i]
	
	var to_check: Array[Vector2i] = [Vector2i(at.x, at.y)]
	var checked: Array[Vector2i]
	
	while not to_check.is_empty():
		var p: Vector2i = to_check.pop_back()
		checked.append(p)
		
		var coord := Vector3i(p.x, p.y, at.z)
		if coord in rooms:
			room.append(coord)
			for i in 4:
				if rooms[coord].borders[i] == -1:
					var p2: Vector2i = p + FWD[i]
					if not p2 in to_check and not p2 in checked:
						to_check.append(p2)
	
	return room

func get_rooms_assigned_to(map: String) -> Array[Vector3i]:
	return assigned_maps.get(map, [])

func get_assigned_map_at(coords: Vector3i) -> String:
	var room := get_room_at(coords)
	if room:
		return room.assigned_map
	else:
		return ""
