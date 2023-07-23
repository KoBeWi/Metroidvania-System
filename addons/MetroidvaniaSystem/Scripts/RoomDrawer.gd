extends RefCounted

static func draw(canvas_item: CanvasItem, offset: Vector2, coords: Vector3i, skip_empty: bool, map_data: MetroidvaniaSystem.MapData, save_data: MetroidvaniaSystem.SaveData):
	var room_data := map_data.get_room_at(coords)
	if not room_data:
		if not skip_empty:
			draw_empty(canvas_item, offset)
		return
	
	var discovered := 2
	if save_data:
		discovered = save_data.is_room_discovered(coords)
	
	if discovered == 0:
		if not skip_empty:
			draw_empty(canvas_item, offset)
		return
	
	var theme: MapTheme = MetSys.settings.theme
	
	var ci := canvas_item.get_canvas_item()
	var display_flags: int = (int(discovered == 2) * 255) | MetSys.settings.unexplored_display
	
	# center
	if bool(display_flags & MetroidvaniaSystem.DISPLAY_CENTER):
		var room_color := room_data.get_color()
		theme.center_texture.draw(ci, offset * MetSys.ROOM_SIZE, room_color if discovered == 2 else theme.unexplored_center_color)
	
	# borders
	var borders: Array[int] = [-1, -1, -1, -1]
	
	for i in 4:
		var border: int = room_data.get_border(i)
		if not bool(display_flags & MetroidvaniaSystem.DISPLAY_OUTLINE) and border == 0:
			borders[i] = -1
		elif not bool(display_flags & MetroidvaniaSystem.DISPLAY_BORDERS):
			borders[i] = mini(border, 0)
		else:
			borders[i] = border
		
	for i in 4:
		var texture: Texture2D
		var color: Color
		
		var rotation := PI * 0.5 * i
		if borders[i] == -1:
			texture = get_border_texture(theme, -1, i)
			color = theme.room_separator_color
		else:
			var border: int = borders[i]
			
			if not bool(display_flags & MetroidvaniaSystem.DISPLAY_BORDERS):
				border = 0
			
			texture = get_border_texture(theme, border, i)
			color = room_data.get_border_color(i)
		
		if not texture:
			continue
		
		var forward_offset := -texture.get_width() / 2
		if theme.use_shared_borders:
			forward_offset = 0
		
		canvas_item.draw_set_transform(offset * MetSys.ROOM_SIZE + MetSys.ROOM_SIZE * 0.5, rotation, Vector2.ONE)
		match i:
			MetroidvaniaSystem.R, MetroidvaniaSystem.L:
				texture.draw(ci, -texture.get_size() / 2 + Vector2.RIGHT * (MetSys.ROOM_SIZE.x * 0.5 + forward_offset), color)
			MetroidvaniaSystem.D, MetroidvaniaSystem.U:
				texture.draw(ci, -texture.get_size() / 2 + Vector2.RIGHT * (MetSys.ROOM_SIZE.y * 0.5 + forward_offset), color)
	
	# corners
	if theme.use_shared_borders:
		if not MetSys.has_meta(&"shared_corners_to_draw"):
			MetSys.set_meta(&"shared_corners_to_draw", {})#[Vector3i, Vector2]
			MetSys.set_meta(&"shared_corner_data", {})#[Vector3i, int]
		
		var shared_corners_to_draw: Dictionary = MetSys.get_meta(&"shared_corners_to_draw")
		var shared_corner_data: Dictionary = MetSys.get_meta(&"shared_corner_data")
		shared_corner_data["canvas_item"] = canvas_item
		
		shared_corners_to_draw[coords] = offset
		for i in 4:
			var coords2 := coords
			match i:
				1:
					coords2 += Vector3i(-1, 0, 0)
				2:
					coords2 += Vector3i(-1, -1, 0)
				3:
					coords2 += Vector3i(0, -1, 0)
			
			if not coords2 in shared_corner_data:
				shared_corner_data[coords2] = 0
			
			shared_corner_data[coords2] |= (1 << i) * int(room_data.get_border(i) > -1)
	else:
		draw_regular_corners(canvas_item, offset, coords, map_data, room_data, borders)
	
	canvas_item.draw_set_transform_matrix(Transform2D())
	
	if bool(display_flags & MetroidvaniaSystem.DISPLAY_SYMBOLS):
		var symbol: int = -1
		
		if save_data and coords in save_data.custom_markers:
			var custom: int = save_data.custom_markers[coords]
			for i in range(63, -1, -1):
				if custom & 1 << i:
					symbol = i
					break
		
		if symbol == -1:
			symbol = room_data.get_symbol()
		
		if symbol > - 1:
			assert(symbol < theme.symbols.size(), "Bad symbol '%s' at '%s'" % [symbol, coords])
			canvas_item.draw_texture(theme.symbols[symbol], offset * MetSys.ROOM_SIZE + MetSys.ROOM_SIZE * 0.5 - theme.symbols[symbol].get_size() / 2)

static func draw_regular_corners(canvas_item: CanvasItem, offset: Vector2, coords: Vector3i, map_data: MetroidvaniaSystem.MapData, room_data: MetroidvaniaSystem.MapData.RoomData, borders: Array[int]):
	var theme: MapTheme = MetSys.settings.theme
	var ci := canvas_item.get_canvas_item()
	
	# outer corner
	for i in 4:
		var j := rotate(i)
		if borders[i] == -1 or borders[j] == -1:
			continue
		
		var texture: Texture2D = theme.outer_corner
		var corner_color = room_data.get_border_color(i).lerp(room_data.get_border_color(j), 0.5)
		
		canvas_item.draw_set_transform(offset * MetSys.ROOM_SIZE + MetSys.ROOM_SIZE * 0.5, PI * 0.5 * i, Vector2.ONE)
		
		var corner_offset := -texture.get_size()
		if theme.use_shared_borders:
			corner_offset /= 2
		
		match i:
			MetroidvaniaSystem.R, MetroidvaniaSystem.L:
				texture.draw(ci, MetSys.ROOM_SIZE * 0.5 + corner_offset, corner_color)
			MetroidvaniaSystem.D, MetroidvaniaSystem.U:
				texture.draw(ci, Vector2(MetSys.ROOM_SIZE.y, MetSys.ROOM_SIZE.x) * 0.5 + corner_offset, corner_color)
	
	# inner corner
	for i in 4:
		var j := rotate(i)
		if borders[i] != -1 or borders[j] != -1:
			continue
		
		var neighbor_room := get_neighbor(map_data, coords, map_data.FWD[i] + map_data.FWD[j])
		if neighbor_room:
			if neighbor_room.borders[opposite(i)] == -1 and neighbor_room.borders[opposite(j)] == -1:
				continue
		
		var texture: Texture2D = theme.inner_corner
		var corner_color = room_data.get_border_color(i).lerp(room_data.get_border_color(j), 0.5)
		
		canvas_item.draw_set_transform(offset * MetSys.ROOM_SIZE + MetSys.ROOM_SIZE * 0.5, PI * 0.5 * i, Vector2.ONE)
		
		var corner_offset := -texture.get_size()
		if theme.use_shared_borders:
			corner_offset /= 2
		
		match i:
			MetroidvaniaSystem.R, MetroidvaniaSystem.L:
				theme.inner_corner.draw(ci, MetSys.ROOM_SIZE * 0.5 + corner_offset, corner_color)
			MetroidvaniaSystem.D, MetroidvaniaSystem.U:
				theme.inner_corner.draw(ci, Vector2(MetSys.ROOM_SIZE.y, MetSys.ROOM_SIZE.x) * 0.5 + corner_offset, corner_color)

static func draw_shared_corners():
	assert(MetSys.settings.theme.use_shared_borders, "This function requires shared borders to be enabled.")
	assert(MetSys.has_meta(&"shared_corners_to_draw"), "No shared borders to draw. Did you draw rooms?")
	var theme: MapTheme = MetSys.settings.theme
	
	var shared_corners_to_draw: Dictionary = MetSys.get_meta(&"shared_corners_to_draw")
	var shared_corner_data: Dictionary = MetSys.get_meta(&"shared_corner_data")
	var canvas_item: CanvasItem = shared_corner_data["canvas_item"]
	
	for coords in shared_corners_to_draw:
		var offset: Vector2 = shared_corners_to_draw[coords]
		var corner_data: int = shared_corner_data[coords]
		var corner_type = signi(corner_data & 1) + signi(corner_data & 2) + signi(corner_data & 4) + signi(corner_data & 8)
		
		var corner_texture: Texture2D
		var corner_rotation := -1
		match corner_type:
			2:
				corner_texture = theme.corner
				match corner_data:
					3:
						corner_rotation = 3
					6:
						corner_rotation = 0
					9:
						corner_rotation = 2
					12:
						corner_rotation = 1
			3:
				corner_texture = theme.t_corner
				match corner_data:
					7:
						corner_rotation = 3
					11:
						corner_rotation = 2
					13:
						corner_rotation = 1
					14:
						corner_rotation = 0
			4:
				corner_texture = theme.cross_corner
				corner_rotation = 0
		
		if corner_rotation == -1 or not corner_texture:
			continue
		
		canvas_item.draw_set_transform(offset * MetSys.ROOM_SIZE + MetSys.ROOM_SIZE, PI * 0.5 * corner_rotation, Vector2.ONE)
		corner_texture.draw(canvas_item.get_canvas_item(), -corner_texture.get_size() / 2)
	
	MetSys.remove_meta(&"shared_corners_to_draw")
	MetSys.remove_meta(&"shared_corner_data")

static func draw_empty(canvas_item: CanvasItem, offset: Vector2):
	var theme: MapTheme = MetSys.settings.theme
	if theme.empty_space_texture:
		var ci := canvas_item.get_canvas_item()
		theme.empty_space_texture.draw(ci, offset * MetSys.ROOM_SIZE, Color.WHITE)

static func get_border_texture(theme: MapTheme, idx: int, direction: int) -> Texture2D:
	var texture_name: StringName
	
	if theme.rectangle:
		if direction == MetroidvaniaSystem.R or direction == MetroidvaniaSystem.L:
			match idx:
				-1:
					texture_name = &"vertical_separator"
				0:
					texture_name = &"vertical_wall"
				1:
					texture_name = &"vertical_passage"
				2:
					texture_name = &"vertical_borders"
		else:
			match idx:
				-1:
					texture_name = &"horizontal_separator"
				0:
					texture_name = &"horizontal_wall"
				1:
					texture_name = &"horizontal_passage"
				_:
					texture_name = &"vertical_borders"
	else:
		match idx:
			-1:
				texture_name = &"separator"
			0:
				texture_name = &"wall"
			1:
				texture_name = &"passage"
			_:
				texture_name = &"borders"
	
	if idx >= 2:
		return theme.get(texture_name)[idx - 2]
	else:
		return theme.get(texture_name)

static func get_neighbor(map_data: MetroidvaniaSystem.MapData, coords: Vector3i, offset: Vector2i) -> MetroidvaniaSystem.MapData.RoomData:
	var neighbor: Vector2i = Vector2i(coords.x, coords.y) + offset
	return map_data.get_room_at(Vector3i(neighbor.x, neighbor.y, coords.z))

static func rotate(i: int) -> int:
	return (i + 1) % 4

static func opposite(i: int) -> int:
	return (i + 2) % 4
