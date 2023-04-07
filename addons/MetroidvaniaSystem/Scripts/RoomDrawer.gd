extends RefCounted

static func draw(canvas_item: CanvasItem, offset: Vector2i, coords: Vector3i, map_data: MetroidvaniaSystem.MapData, save_data: MetroidvaniaSystem.SaveData):
	var room_data := map_data.get_room_at(coords)
	if not room_data:
		return
	
	var discovered := 2
	if save_data:
		discovered = save_data.is_room_discovered(coords)
	
	if discovered == 0:
		return
	
	var theme := MetSys.settings.theme
	
	var ci := canvas_item.get_canvas_item()
	var display_flags: int = (int(discovered == 2) * 255) | MetSys.settings.unexplored_display
	
	# center
	if bool(display_flags & MetroidvaniaSystem.DISPLAY_CENTER):
		var room_color = room_data.color if room_data.color.a > 0 else theme.default_center_color
		theme.center_texture.draw(ci, offset * MetSys.ROOM_SIZE, room_color if discovered == 2 else theme.unexplored_room_fill_color)
	
	var borders: Array[int] = [-1, -1, -1, -1]
	for i in 4:
		var border: int = room_data.get_border(i)
		if not bool(display_flags & MetroidvaniaSystem.DISPLAY_OUTLINE) and border == 0:
			borders[i] = -1
		elif not bool(display_flags & MetroidvaniaSystem.DISPLAY_BORDERS):
			borders[i] = mini(border, 0)
		else:
			borders[i] = border
	
	# borders
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
		
		canvas_item.draw_set_transform(offset * MetSys.ROOM_SIZE + MetSys.ROOM_SIZE / 2, rotation, Vector2.ONE)
		match i:
			MetroidvaniaSystem.R, MetroidvaniaSystem.L:
				texture.draw(ci, -texture.get_size() / 2 + Vector2.RIGHT * (MetSys.ROOM_SIZE.x / 2 + forward_offset), color)
			MetroidvaniaSystem.D, MetroidvaniaSystem.U:
				texture.draw(ci, -texture.get_size() / 2 + Vector2.RIGHT * (MetSys.ROOM_SIZE.y / 2 + forward_offset), color)
	
	# outer corner
	for i in 4:
		var j := rotate(i)
		if borders[i] == -1 or borders[j] == -1:
			continue
		
		var texture: Texture2D = theme.outer_corner
		var corner_color = room_data.get_border_color(i).lerp(room_data.get_border_color(j), 0.5)
		
		canvas_item.draw_set_transform(offset * MetSys.ROOM_SIZE + MetSys.ROOM_SIZE / 2, PI * 0.5 * i, Vector2.ONE)
		
		var corner_offset := -texture.get_size()
		if theme.use_shared_borders:
			corner_offset /= 2
		
		match i:
			MetroidvaniaSystem.R, MetroidvaniaSystem.L:
				texture.draw(ci, Vector2(MetSys.ROOM_SIZE) / 2 + corner_offset, corner_color)
			MetroidvaniaSystem.D, MetroidvaniaSystem.U:
				texture.draw(ci, Vector2(MetSys.ROOM_SIZE.y, MetSys.ROOM_SIZE.x) / 2 + corner_offset, corner_color)
	
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
		
		canvas_item.draw_set_transform(offset * MetSys.ROOM_SIZE + MetSys.ROOM_SIZE / 2, PI * 0.5 * i, Vector2.ONE)
		
		var corner_offset := -texture.get_size()
		if theme.use_shared_borders:
			corner_offset /= 2
		
		match i:
			MetroidvaniaSystem.R, MetroidvaniaSystem.L:
				theme.inner_corner.draw(ci, Vector2(MetSys.ROOM_SIZE) / 2 + corner_offset, corner_color)
			MetroidvaniaSystem.D, MetroidvaniaSystem.U:
				theme.inner_corner.draw(ci, Vector2(MetSys.ROOM_SIZE.y, MetSys.ROOM_SIZE.x) / 2 + corner_offset, corner_color)
	
	canvas_item.draw_set_transform_matrix(Transform2D())
	
	if bool(display_flags & MetroidvaniaSystem.DISPLAY_SYMBOLS):
		var symbol: int = -1
		
		if save_data and coords in save_data.room_markers:
			symbol = save_data.room_markers[coords].back()
		
		if symbol == -1:
			symbol = room_data.symbol
		
		if symbol > - 1:
			pass
#			assert(symbol < settings.map_symbols.size())
#			canvas_item.draw_texture(settings.map_symbols[symbol], offset * ROOM_SIZE + ROOM_SIZE / 2 - Vector2i(settings.map_symbols[symbol].get_size()) / 2)

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
				2:
					texture_name = &"vertical_borders"
	else:
		match idx:
			-1:
				texture_name = &"separator"
			0:
				texture_name = &"wall"
			1:
				texture_name = &"passage"
			2:
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
