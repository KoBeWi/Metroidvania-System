const FWD = { MetroidvaniaSystem.R: Vector2i.RIGHT, MetroidvaniaSystem.D: Vector2i.DOWN, MetroidvaniaSystem.L: Vector2i.LEFT, MetroidvaniaSystem.U: Vector2i.UP }

class RoomData:
	enum { DATA_EXITS, DATA_COLORS, DATA_SYMBOL, DATA_MAP, OVERRIDE_COORDS, OVERRIDE_CUSTOM }
	
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
		data.append(assigned_map.trim_prefix(MetSys.settings.map_root_folder).trim_prefix("/"))
		return "|".join(data)
	
	func load_next_chunk() -> String:
		loading[1] += 1
		return loading[0].get_slice("|", loading[1])
	
	func get_color() -> Color:
		var c: Color
		var override := get_override()
		if override and override.color.a > 0:
			c = override.color
		else:
			c = color
		
		if c.a > 0:
			return c
		return MetSys.settings.theme.default_center_color
	
	func get_border(idx: int) -> int: # TODO: reszta
		var override := get_override()
		if override and override.borders[idx] != -2:
			return override.borders[idx]
		return borders[idx]
	
	func get_border_color(idx: int) -> Color:
		var c: Color
		var override := get_override()
		if override and override.border_colors[idx].a > 0:
			c = override.border_colors[idx]
		else:
			c = border_colors[idx]
		
		if c.a > 0:
			return c
		return MetSys.settings.theme.default_border_color
	
	func get_assigned_map() -> String:
		var override := get_override()
		if override and override.assigned_map != "/":
			return override.assigned_map
		return assigned_map
	
	func get_override() -> RoomOverride:
		if not MetSys.save_data:
			return null
		return MetSys.save_data.room_overrides.get(self)

class RoomOverride extends RoomData:
	# TODO: metody pomocnicze
	var original_room: RoomData
	var custom_room_coords := MetroidvaniaSystem.VECTOR3INF
	
	func _init(from: RoomData) -> void:
		original_room = from
		borders = [-2, -2, -2, -2]
		symbol = -2
		assigned_map = "/"
	
	static func load_from_line(line: String) -> RoomOverride:
		var room: RoomData
		var coords_string := line.get_slice("|", RoomData.OVERRIDE_COORDS)
		var coords := Vector3i(coords_string.get_slice(",", 0).to_int(), coords_string.get_slice(",", 1).to_int(), coords_string.get_slice(",", 2).to_int())
		
		var is_custom := line.get_slice("|", RoomData.OVERRIDE_CUSTOM) == "true"
		if is_custom:
			room = MetSys.map_data.create_room_at(coords)
		else:
			room = MetSys.map_data.get_room_at(coords)
		
		var override := RoomOverride.new(room)
		if is_custom:
			override.custom_room_coords = coords
		
		var fake_room := RoomData.new(line)
		override.borders = fake_room.borders
		override.border_colors = fake_room.border_colors
		override.color = fake_room.color
		override.symbol = fake_room.symbol
		override.set_assigned_map(fake_room.assigned_map)
		
		return override
	
	func set_assigned_map(map := "/"):
		if map == "/":
			MetSys.map_data.map_overrides.erase(map)
		else:
			if custom_room_coords != MetroidvaniaSystem.VECTOR3INF:
				if not map in MetSys.map_data.assigned_maps:
					MetSys.map_data.assigned_maps[map] = []
				MetSys.map_data.assigned_maps[map].append(custom_room_coords)
			else:
				MetSys.map_data.map_overrides[map] = original_room.assigned_map
		
		# TODO: na wszystkie pomieszczenia
		assigned_map = map
	
	func destroy():
		if custom_room_coords == MetroidvaniaSystem.VECTOR3INF:
			push_error("Only custom room can be destroyed.")
			return
		
		MetSys.remove_room_override(custom_room_coords)
		MetSys.map_data.erase_room(custom_room_coords)
		MetSys.map_data.room_overrides.erase(custom_room_coords)
		MetSys.map_data.custom_rooms.erase(self)
	
	func get_override_string(coords: Vector3i) -> String:
		return str(get_string(), "|", coords.x, ",", coords.y, ",", coords.z, "|", custom_room_coords != MetroidvaniaSystem.VECTOR3INF)
	
	func commit():
		MetSys.map_updated.emit()

var rooms: Dictionary#[Vector3i, RoomData]
var custom_rooms: Dictionary#[Vector3i, RoomData]
var assigned_maps: Dictionary#[String, Array[Vector3i]]
var room_groups: Dictionary#[int, Array[Vector3i]]

var room_overrides: Dictionary#[Vector3i, RoomOverride]
var map_overrides: Dictionary#[String, String]

func load_data():
	var file := FileAccess.open(MetSys.settings.map_root_folder.path_join("MapData.txt"), FileAccess.READ)
	
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
	var file := FileAccess.open(MetSys.settings.map_root_folder.path_join("MapData.txt"), FileAccess.WRITE)
	
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

func create_custom_room(coords: Vector3i) -> RoomOverride:
	assert(not coords in rooms, "A room already exists at this position")
	var room := create_room_at(coords)
	custom_rooms[coords] = room
	
	var override: RoomOverride = MetSys.save_data.add_room_override(room)
	override.custom_room_coords = coords
	return override

func get_whole_room(at: Vector3i) -> Array[Vector3i]:
	var room: Array[Vector3i]
	
	var to_check: Array[Vector2i] = [Vector2i(at.x, at.y)]
	var checked: Array[Vector2i]
	
	while not to_check.is_empty():
		var p: Vector2i = to_check.pop_back()
		checked.append(p)
		
		var coords := Vector3i(p.x, p.y, at.z)
		if coords in rooms:
			room.append(coords)
			for i in 4:
				if rooms[coords].borders[i] == -1:
					var p2: Vector2i = p + FWD[i]
					if not p2 in to_check and not p2 in checked:
						to_check.append(p2)
	
	return room

func get_rooms_assigned_to(map: String) -> Array[Vector3i]:
	if map in map_overrides:
		map = map_overrides[map]
	
	var ret: Array[Vector3i]
	ret.assign(assigned_maps.get(map, []))
	return ret

func get_assigned_map_at(coords: Vector3i) -> String:
	var room := get_room_at(coords)
	if room:
		return room.get_assigned_map()
	else:
		return ""

func erase_room(coords: Vector3i):
	var assigned_map: String = rooms[coords].assigned_map
	MetSys.map_data.assigned_maps[assigned_map] = []
	
	rooms.erase(coords)
	
	for group in room_groups.values():
		group.erase(coords)
