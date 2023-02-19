const FWD = { MetroidvaniaSystem.R: Vector2i.RIGHT, MetroidvaniaSystem.D: Vector2i.DOWN, MetroidvaniaSystem.L: Vector2i.LEFT, MetroidvaniaSystem.U: Vector2i.UP }

class RoomData:
	var borders: Array[int] = [-1, -1, -1, -1]
	var color: Color = Color.TRANSPARENT
	var border_colors: Array[Color] = [Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT]
	var symbol := -1
	var assigned_map: String
	
	var loading
	
	func _init(line: String) -> void:
		if line.is_empty():
			return
		loading = [line, -1]
		
		var chunk := load_next_chunk()
		for i in 4:
			borders[i] = chunk.get_slice(",", i).to_int()
		
		chunk = load_next_chunk()
		if not chunk.is_empty():
			var color_slice := chunk.get_slice(",", 0)
			if not color_slice.is_empty():
				color = Color(color_slice)
			
			for i in 4:
				color_slice = chunk.get_slice(",", i + 1)
				if not color_slice.is_empty():
					border_colors[i] = Color(color_slice)
		
		chunk = load_next_chunk()
		if not chunk.is_empty():
			symbol = chunk.to_int()
		
		assigned_map = load_next_chunk()
		loading = null
	
	func get_string() -> String:
		var data: PackedStringArray
		data.append("%s,%s,%s,%s" % borders)
		
		var colors: Array[Color]
		colors.assign([color] + Array(border_colors))
		if colors.any(func(col: Color): return col.a > 0):
			data.append("%s,%s,%s,%s,%s" % colors.map(func(col: Color): return col.to_html(false) if col.a > 0 else ""))
		else:
			data.append("")
		
		if symbol > -1:
			data.append(str(symbol))
		else:
			data.append("")
		data.append(assigned_map.trim_prefix(MetSys.map_root_folder).trim_prefix("/"))
		return "|".join(data)
	
	func load_next_chunk() -> String:
		loading[1] += 1
		return loading[0].get_slice("|", loading[1])
	
	func get_border(idx: int) -> int: # TODO: reszta
		var override = MetSys.save_data.room_overrides.get(self)
		if override and override.borders[idx] != -2:
			return override.borders[idx]
		return borders[idx]
	
	func get_border_color(idx: int) -> Color:
		if border_colors[idx].a > 0:
			return border_colors[idx]
		return MetSys.theme.default_border_color

class RoomOverride extends RoomData:
	# TODO: metody pomocnicze
	func _init() -> void:
		borders = [-2, -2, -2, -2]
		symbol = -2
		assigned_map = "/"
	
	func commit():
		MetSys.map_updated.emit()

var rooms: Dictionary#[Vector3i, RoomData]
var custom_rooms: Dictionary#[Vector3i, RoomData]
var assigned_maps: Dictionary#[String, Array[Vector3i]]
var room_groups: Dictionary#[int, Array[Vector3i]]

var room_overrides: Dictionary#[Vector3i, RoomOverride]

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
			
			var room_data := RoomData.new(line)
			if not room_data.assigned_map.is_empty():
				assigned_maps[room_data.assigned_map] = [coords]
			
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
		var assigned_rooms: Array[Vector3i]
		assigned_rooms.assign(assigned_maps[map])
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
		file.store_line(room_data.get_string())

func get_room_at(coords: Vector3i) -> RoomData:
	return rooms.get(coords)

func create_room_at(coords: Vector3i) -> RoomData:
	rooms[coords] = RoomData.new("")
	return rooms[coords]

func create_custom_room(coords: Vector3i) -> RoomData:
	assert(not coords in rooms, "A room already exists at this position")
	var room := create_room_at(coords)
	custom_rooms[coords] = room
	return room

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
