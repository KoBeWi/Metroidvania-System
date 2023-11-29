extends RefCounted

static var force_mapped: bool

static func draw(canvas_item: CanvasItem, offset: Vector2, coords: Vector3i, skip_empty: bool, map_data: MetroidvaniaSystem.MapData, save_data: MetroidvaniaSystem.MetSysSaveData):
	if MetSys.settings.custom_elements and not map_data.custom_elements.is_empty():
		setup_custom_elements(canvas_item, offset, coords)
	
	var cell_data := map_data.get_cell_at(coords)
	if not cell_data:
		if not skip_empty:
			draw_empty(canvas_item, offset)
		return
	
	var discovered := 2
	if save_data:
		discovered = save_data.is_cell_discovered(coords)
	elif force_mapped:
		discovered = 1
	
	if discovered == 0:
		if not skip_empty:
			draw_empty(canvas_item, offset)
		return
	
	var theme: MapTheme = MetSys.settings.theme
	
	var ci := canvas_item.get_canvas_item()
	var display_flags: int = (int(discovered == 2) * 255) | theme.mapped_display
	
	# center
	if bool(display_flags & MetroidvaniaSystem.DISPLAY_CENTER):
		var room_color := cell_data.get_color()
		theme.center_texture.draw(ci, offset * MetSys.CELL_SIZE, room_color if discovered == 2 else theme.mapped_center_color)
	
	# corners
	if theme.use_shared_borders:
		if not MetSys.has_meta(&"shared_borders_to_draw"):
			MetSys._add_meta(&"shared_borders_to_draw", {})#[Vector3i, Vector2]
			MetSys._add_meta(&"shared_borders_data", {"canvas_item": canvas_item, "display_flags": display_flags})
		
		var shared_borders_to_draw: Dictionary = MetSys.get_meta(&"shared_borders_to_draw")
		shared_borders_to_draw[coords] = offset
	else:
		draw_regular_borders(canvas_item, offset, coords, map_data, cell_data, display_flags, discovered)
	
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
			symbol = cell_data.get_symbol()
		
		if symbol > - 1:
			if symbol >= theme.symbols.size():
				push_error("Bad symbol '%s' at '%s'" % [symbol, coords])
			else:
				canvas_item.draw_texture(theme.symbols[symbol], offset * MetSys.CELL_SIZE + MetSys.CELL_SIZE * 0.5 - theme.symbols[symbol].get_size() / 2)

static func draw_regular_borders(canvas_item: CanvasItem, offset: Vector2, coords: Vector3i, map_data: MetroidvaniaSystem.MapData, cell_data: MetroidvaniaSystem.MapData.CellData, display_flags: int, discovered: int):
	var theme: MapTheme = MetSys.settings.theme
	var ci := canvas_item.get_canvas_item()
	
	# borders
	var borders: Array[int] = [-1, -1, -1, -1]
	
	var display_outlines := bool(display_flags & MetroidvaniaSystem.DISPLAY_OUTLINE)
	for i in 4:
		var border: int = cell_data.get_border(i)
		if not display_outlines and border == 0:
			borders[i] = -1
		elif not bool(display_flags & MetroidvaniaSystem.DISPLAY_BORDERS):
			borders[i] = mini(border, 0 if display_outlines else -1)
		else:
			borders[i] = border
	
	for i in 4:
		var texture: Texture2D
		var color: Color
		
		var rotation := PI * 0.5 * i
		if borders[i] == -1:
			if display_outlines:
				texture = get_border_texture(theme, -1, i)
				color = Color.WHITE
		else:
			var border: int = borders[i]
			
			if not bool(display_flags & MetroidvaniaSystem.DISPLAY_BORDERS):
				border = 0
			
			texture = get_border_texture(theme, border, i)
			if discovered == 2:
				color = cell_data.get_border_color(i)
			else:
				color = theme.mapped_border_color
		
		if not texture:
			continue
		
		canvas_item.draw_set_transform(offset * MetSys.CELL_SIZE + MetSys.CELL_SIZE * 0.5, rotation, Vector2.ONE)
		match i:
			MetroidvaniaSystem.R, MetroidvaniaSystem.L:
				texture.draw(ci, -texture.get_size() / 2 + Vector2.RIGHT * (MetSys.CELL_SIZE.x * 0.5 - texture.get_width() / 2), color)
			MetroidvaniaSystem.D, MetroidvaniaSystem.U:
				texture.draw(ci, -texture.get_size() / 2 + Vector2.RIGHT * (MetSys.CELL_SIZE.y * 0.5 - texture.get_width() / 2), color)
	
	if not display_outlines:
		return
	
	# outer corner
	for i in 4:
		var j := rotate(i)
		if borders[i] == -1 or borders[j] == -1:
			continue
		
		var texture: Texture2D = theme.outer_corner
		var corner_color: Color
		if discovered == 2:
			corner_color = get_shared_color(cell_data.get_border_color(i), cell_data.get_border_color(j), theme.default_border_color)
		else:
			corner_color = theme.mapped_border_color
		
		canvas_item.draw_set_transform(offset * MetSys.CELL_SIZE + MetSys.CELL_SIZE * 0.5, PI * 0.5 * i, Vector2.ONE)
		
		var corner_offset := -texture.get_size()
		if theme.use_shared_borders:
			corner_offset /= 2
		
		match i:
			MetroidvaniaSystem.R, MetroidvaniaSystem.L:
				texture.draw(ci, MetSys.CELL_SIZE * 0.5 + corner_offset, corner_color)
			MetroidvaniaSystem.D, MetroidvaniaSystem.U:
				texture.draw(ci, Vector2(MetSys.CELL_SIZE.y, MetSys.CELL_SIZE.x) * 0.5 + corner_offset, corner_color)
	
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
		var color1 := get_neighbor(map_data, coords, map_data.FWD[i]).get_border_color(rotate(i))
		var color2 := get_neighbor(map_data, coords, map_data.FWD[j]).get_border_color(rotate(j, -1))
		
		var corner_color := get_shared_color(color1, color2, theme.default_border_color)
		
		canvas_item.draw_set_transform(offset * MetSys.CELL_SIZE + MetSys.CELL_SIZE * 0.5, PI * 0.5 * i, Vector2.ONE)
		
		var corner_offset := -texture.get_size()
		if theme.use_shared_borders:
			corner_offset /= 2
		
		match i:
			MetroidvaniaSystem.R, MetroidvaniaSystem.L:
				theme.inner_corner.draw(ci, MetSys.CELL_SIZE * 0.5 + corner_offset, corner_color)
			MetroidvaniaSystem.D, MetroidvaniaSystem.U:
				theme.inner_corner.draw(ci, Vector2(MetSys.CELL_SIZE.y, MetSys.CELL_SIZE.x) * 0.5 + corner_offset, corner_color)

static func draw_shared_borders():
	assert(MetSys.settings.theme.use_shared_borders, "This function requires shared borders to be enabled.")
	if not MetSys.has_meta(&"shared_borders_to_draw"):
		return
	
	var theme: MapTheme = MetSys.settings.theme
	
	var shared_borders_to_draw: Dictionary = MetSys.get_meta(&"shared_borders_to_draw")
	var shared_borders_data: Dictionary = MetSys.get_meta(&"shared_borders_data")
	
	var shared_borders_colors: Dictionary#[Vector3i, Color]
	var shared_corners_data: Dictionary#[Vector3i, int]
	var shared_corners_colors: Dictionary#[Vector3i, Color]
	
	var display_flags: int = shared_borders_data["display_flags"]
	var canvas_item: CanvasItem = shared_borders_data["canvas_item"]
	var ci := canvas_item.get_canvas_item()
	
	var additional_corners: Dictionary#[Vector3i, Vector2]
	for coords in shared_borders_to_draw:
		for x in range (-1, 1):
			for y in range(-1, 1):
				var coords2: Vector3i = coords + Vector3i(x, y, 0)
				if not coords2 in shared_borders_to_draw:
					additional_corners[coords2] = shared_borders_to_draw[coords] + Vector2(x, y)
	
	shared_borders_to_draw.merge(additional_corners)
	for coords in shared_borders_to_draw:
		var corner_data := 0
		corner_data |= (1 << 0) * (get_corner_bit(coords, MetroidvaniaSystem.R) | get_corner_bit(coords + Vector3i(1, 0, 0), MetroidvaniaSystem.L))
		corner_data |= (1 << 1) * (get_corner_bit(coords, MetroidvaniaSystem.D) | get_corner_bit(coords + Vector3i(0, 1, 0), MetroidvaniaSystem.U))
		corner_data |= (1 << 2) * (get_corner_bit(coords + Vector3i(0, 1, 0), MetroidvaniaSystem.R) | get_corner_bit(coords + Vector3i(1, 1, 0), MetroidvaniaSystem.L))
		corner_data |= (1 << 3) * (get_corner_bit(coords + Vector3i(1, 0, 0), MetroidvaniaSystem.D) | get_corner_bit(coords + Vector3i(1, 1, 0), MetroidvaniaSystem.U))
		
		if theme.is_unicorner():
			corner_data = signi(corner_data) * 15
		
		var use_default: bool
		var color_blend: Array[Color]
		for i in 4:
			var color: Color
			if i < 2:
				color = get_shared_border_color(coords, i)
			else:
				color = get_shared_border_color(coords + Vector3i(1, 1, 0), i)
			
			if color == theme.default_border_color:
				use_default = true
			elif color.a > 0:
				color_blend.append(color)
		
		shared_corners_data[coords] = corner_data
		if not color_blend.is_empty():
			var ratio: float = 1.0 / color_blend.size()
			shared_corners_colors[coords] = color_blend.reduce(func(final: Color, current: Color) -> Color: return final.lerp(current, ratio))
		elif use_default:
			shared_corners_colors[coords] = theme.default_border_color
		
		var border_data: Array[int] = [-1, -1]
		var border_colors: Array[Color] = [Color(), Color()]
		for i in 2:
			var fwd := Vector3i(MetroidvaniaSystem.MapData.FWD[i].x, MetroidvaniaSystem.MapData.FWD[i].y, 0)
			border_data[i] = maxi(get_border_at(coords, i), get_border_at(coords + fwd, opposite(i)))
			border_colors[i] = get_shared_border_color(coords, i)
		
		shared_borders_data[coords] = border_data
		shared_borders_colors[coords] = border_colors
	
	# borders
	for coords in shared_borders_to_draw:
		var borders: Array[int] = shared_borders_data[coords]
		for i in 2:
			var texture: Texture2D
			var color: Color
			
			var rotation := PI * 0.5 * i
			if borders[i] == -1:
				texture = get_border_texture(theme, -1, i)
				color = Color.WHITE
			else:
				var border: int = borders[i]
				
				if not bool(display_flags & MetroidvaniaSystem.DISPLAY_BORDERS):
					border = 0
				
				texture = get_border_texture(theme, border, i)
				color = shared_borders_colors[coords][i]
			
			if not texture:
				continue
			
			canvas_item.draw_set_transform(shared_borders_to_draw[coords] * MetSys.CELL_SIZE + MetSys.CELL_SIZE * 0.5, rotation, Vector2.ONE)
			match i:
				MetroidvaniaSystem.R, MetroidvaniaSystem.L:
					texture.draw(ci, -texture.get_size() / 2 + Vector2.RIGHT * (MetSys.CELL_SIZE.x * 0.5), color)
				MetroidvaniaSystem.D, MetroidvaniaSystem.U:
					texture.draw(ci, -texture.get_size() / 2 + Vector2.RIGHT * (MetSys.CELL_SIZE.y * 0.5), color)
	
	# corners
	for coords in shared_borders_to_draw:
		var offset: Vector2 = shared_borders_to_draw[coords]
		var corner_data: int = shared_corners_data[coords]
		var corner_type = signi(corner_data & 1) + signi(corner_data & 2) + signi(corner_data & 4) + signi(corner_data & 8)
		
		var corner_texture: Texture2D
		var corner_rotation := -1
		match corner_type:
			1:
				corner_texture = theme.u_corner
				match corner_data:
					1:
						corner_rotation = 0
					2:
						corner_rotation = 3
					4:
						corner_rotation = 2
					8:
						corner_rotation = 1
			2:
				corner_texture = theme.l_corner
				match corner_data:
					3:
						corner_rotation = 3
					6:
						corner_rotation = 2
					9:
						corner_rotation = 0
					12:
						corner_rotation = 1
			3:
				corner_texture = theme.t_corner
				match corner_data:
					7:
						corner_rotation = 1
					11:
						corner_rotation = 2
					13:
						corner_rotation = 3
					14:
						corner_rotation = 0
			4:
				corner_texture = theme.cross_corner
				corner_rotation = 0
		
		if corner_rotation == -1 or not corner_texture:
			continue
		
		canvas_item.draw_set_transform(offset * MetSys.CELL_SIZE + MetSys.CELL_SIZE, PI * 0.5 * corner_rotation, Vector2.ONE)
		corner_texture.draw(canvas_item.get_canvas_item(), -corner_texture.get_size() / 2, shared_corners_colors[coords])
	
	MetSys.remove_meta(&"shared_borders_to_draw")
	MetSys.remove_meta(&"shared_borders_data")
	canvas_item.draw_set_transform_matrix(Transform2D())

static func setup_custom_elements(canvas_item: CanvasItem, offset: Vector2, coords: Vector3i):
		var custom_element_data: Dictionary
		if not MetSys.has_meta(&"custom_elements_data"):
			custom_element_data["canvas_item"] = canvas_item
			MetSys._add_meta(&"custom_elements_data", custom_element_data)

static func draw_custom_elements(canvas_item: CanvasItem, elements: Dictionary, base_offset: Vector2, rect: Rect2i, layer: int):
	var element_manager: MetroidvaniaSystem.CustomElementManager = MetSys.settings.custom_elements
	var already_drawn: Array[Dictionary]
	
	for y in rect.size.y:
		for x in rect.size.y:
			var pos := rect.position + Vector2i(x, y)
			for coords in elements:
				if coords.z != layer:
					continue
				
				var element: Dictionary = elements[coords]
				if element in already_drawn:
					continue
				
				var elerect := Rect2i(coords.x, coords.y, element["size"].x, element["size"].y)
				if elerect.has_point(pos):
					element_manager.draw_element(canvas_item, coords, element.name, (base_offset + Vector2(coords.x, coords.y) - Vector2(pos) + Vector2(x, y)) * MetSys.CELL_SIZE, Vector2(element.size) * MetSys.CELL_SIZE, element.data)
					already_drawn.append(element)

static func get_border_at(coords: Vector3i, idx: int) -> int:
	var cell_data = get_discovered_cell_at(coords)
	if not cell_data:
		return -1
	return cell_data.get_border(idx)

static func get_corner_bit(coords: Vector3i, idx: int) -> int:
	return int(get_border_at(coords, idx) > -1)

static func get_shared_border_color(coords: Vector3i, idx: int) -> Color:
	var fwd := Vector3i(MetroidvaniaSystem.MapData.FWD[idx].x, MetroidvaniaSystem.MapData.FWD[idx].y, 0)
	var color := Color.TRANSPARENT
	
	var cell_data = get_discovered_cell_at(coords)
	if cell_data:
		color = cell_data.get_border_color(idx)
	
	cell_data = get_discovered_cell_at(coords + fwd)
	if cell_data:
		if color.a > 0:
			color = get_shared_color(color, cell_data.get_border_color(opposite(idx)), MetSys.settings.theme.default_border_color)
		else:
			color = cell_data.get_border_color(opposite(idx))
	
	return color

static func get_discovered_cell_at(coords: Vector3i) -> MetroidvaniaSystem.MapData.CellData:
	var cell_data = MetSys.map_data.get_cell_at(coords)
	if cell_data and MetSys.is_cell_discovered(coords):
		return cell_data
	return null

static func get_shared_color(color1: Color, color2: Color, default: Color) -> Color:
	if color1 == default:
		return color2
	elif color2 == default:
		return color1
	return color1.lerp(color2, 0.5)

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

static func draw_empty(canvas_item: CanvasItem, offset: Vector2):
	var theme: MapTheme = MetSys.settings.theme
	if theme.empty_space_texture:
		var ci := canvas_item.get_canvas_item()
		theme.empty_space_texture.draw(ci, offset * MetSys.CELL_SIZE, Color.WHITE)

static func get_neighbor(map_data: MetroidvaniaSystem.MapData, coords: Vector3i, offset: Vector2i) -> MetroidvaniaSystem.MapData.CellData:
	var neighbor: Vector2i = Vector2i(coords.x, coords.y) + offset
	return map_data.get_cell_at(Vector3i(neighbor.x, neighbor.y, coords.z))

static func rotate(i: int, amount := 1) -> int:
	return (i + amount) % 4

static func opposite(i: int) -> int:
	return (i + 2) % 4
