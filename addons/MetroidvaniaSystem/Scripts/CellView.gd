extends RefCounted

const CellData = MetroidvaniaSystem.MapData.CellData

var use_save_data: bool = true

var coords: Vector3i
var visible: bool = true:
	set(v):
		visible = v
		if _canvas_item.is_valid():
			RenderingServer.canvas_item_set_visible(_canvas_item, visible)

var offset: Vector2:
	set(v):
		offset = v
		if _canvas_item.is_valid():
			RenderingServer.canvas_item_set_transform(_canvas_item, Transform2D(0, offset * MetSys.CELL_SIZE))

var _this: RefCounted # hack
var _parent_item: RID
var _canvas_item: RID
var _shared_border_item: RID
var _shared_corner_item: RID

var _left_cell: MetroidvaniaSystem.CellView
var _top_cell: MetroidvaniaSystem.CellView
var _top_left_cell: MetroidvaniaSystem.CellView
	
var _theme: MapTheme
var _force_mapped: bool

func _init(parent_item: RID) -> void:
	_this = self # hack
	unreference() # hack
	
	_parent_item = parent_item
	_theme = MetSys.settings.theme

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _this._canvas_item.is_valid():
			_this.delete_rids()

func create_rids():
	_canvas_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_canvas_item, _parent_item)
	
	RenderingServer.canvas_item_set_visible(_canvas_item, visible)
	RenderingServer.canvas_item_set_transform(_canvas_item, Transform2D(0, offset * MetSys.CELL_SIZE))
	
	if _theme.use_shared_borders:
		_shared_border_item = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_z_index(_shared_border_item, 1)
		RenderingServer.canvas_item_set_parent(_shared_border_item, _canvas_item)
		
		_shared_corner_item = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_z_index(_shared_corner_item, 2)
		RenderingServer.canvas_item_set_parent(_shared_corner_item, _canvas_item)

func delete_rids():
	RenderingServer.free_rid(_canvas_item)
	_canvas_item = RID()
	if _shared_border_item.is_valid():
		RenderingServer.free_rid(_shared_border_item)
		RenderingServer.free_rid(_shared_corner_item)
		_shared_border_item = RID()
		_shared_corner_item = RID()

func update():
	if _canvas_item.is_valid():
		RenderingServer.canvas_item_clear(_canvas_item)
		if _shared_border_item.is_valid():
			RenderingServer.canvas_item_clear(_shared_border_item)
			RenderingServer.canvas_item_clear(_shared_corner_item)
	_draw()

func _draw():
	var cell_data: CellData = MetSys.map_data.get_cell_at(coords)
	if not cell_data:
		if _canvas_item.is_valid():
			delete_rids()
		return
	elif not _canvas_item.is_valid():
		create_rids()
	
	var save_data: MetroidvaniaSystem.MetSysSaveData
	if use_save_data:
		save_data = MetSys.save_data
	
	var discovered := _get_discovered_status(coords)
	if discovered == 0:
		return
	
	var display_flags: int = (int(discovered == 2) * 255) | _theme.mapped_display
	
	if bool(display_flags & MetroidvaniaSystem.DISPLAY_CENTER):
		_draw_texture(_theme.center_texture, cell_data.get_color() if discovered == 2 else _theme.mapped_center_color)
	
	if _theme.use_shared_borders:
		_draw_shared_borders(cell_data, display_flags, discovered)
	else:
		_draw_regular_borders(cell_data, display_flags, discovered)
	
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
			if symbol >= _theme.symbols.size():
				push_error("Bad symbol '%s' at '%s'" % [symbol, coords])
			else:
				_draw_texture(_theme.symbols[symbol], Color.WHITE, -_theme.symbols[symbol].get_size() * 0.5 + MetSys.CELL_SIZE * 0.5)

func _draw_texture(texture: Texture2D, color := Color.WHITE, offset := Vector2(), direction := 0):
	match direction:
		MetroidvaniaSystem.R:
			RenderingServer.canvas_item_add_texture_rect(_canvas_item, Rect2(offset, texture.get_size()), texture.get_rid(), false, color)
		MetroidvaniaSystem.D:
			RenderingServer.canvas_item_add_texture_rect(_canvas_item, Rect2(offset, texture.get_size() * Vector2(-1, 1)), texture.get_rid(), false, color, true)
		MetroidvaniaSystem.L:
			RenderingServer.canvas_item_add_texture_rect(_canvas_item, Rect2(offset, texture.get_size() * Vector2(-1, -1)), texture.get_rid(), false, color)
		MetroidvaniaSystem.U:
			RenderingServer.canvas_item_add_texture_rect(_canvas_item, Rect2(offset, texture.get_size() * Vector2(1, -1)), texture.get_rid(), false, color, true)

func _draw_regular_borders(cell_data: CellData, display_flags: int, discovered: int):
	var map_data: MetroidvaniaSystem.MapData = MetSys.map_data
	
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
	
	if display_outlines and _get_border_texture(_theme, -1, 0):
		var separators := 2
		if _theme.separator_mode == MapTheme.SeparatorMode.EMPTY_DOUBLE or _theme.separator_mode == MapTheme.SeparatorMode.FULL_DOUBLE:
			separators = 4
		
		var full := _theme.separator_mode == MapTheme.SeparatorMode.FULL_DOUBLE or _theme.separator_mode == MapTheme.SeparatorMode.FULL_SINGLE
		for i in separators:
			if borders[i] == 0 or (not full and borders[i] != -1):
				continue
			
			var texture := _get_border_texture(_theme, -1, i)
			if not texture:
				continue
			
			_draw_border(i, texture, Color.WHITE)
	
	for i in 4:
		var texture: Texture2D
		var color: Color
		
		if borders[i] > -1:
			var border: int = borders[i]
			
			if not bool(display_flags & MetroidvaniaSystem.DISPLAY_BORDERS):
				border = 0
			
			texture = _get_border_texture(_theme, border, i)
			if discovered == 2:
				color = cell_data.get_border_color(i)
			else:
				color = _theme.mapped_border_color
		
		if not texture:
			continue
		
		_draw_border(i, texture, color)
	
	if not display_outlines or _theme.is_nocorner():
		return
	
	# outer corner
	for i in 4:
		var j := _rotate(i)
		if borders[i] == -1 or borders[j] == -1:
			continue
		
		var texture: Texture2D = _theme.outer_corner
		var corner_color: Color
		if discovered == 2:
			corner_color = _get_shared_color(cell_data.get_border_color(i), cell_data.get_border_color(j))
		else:
			corner_color = _theme.mapped_border_color
		
		_draw_corner(i, texture, corner_color)
	
	# inner corner
	for i in 4:
		var j := _rotate(i)
		if borders[i] != -1 or borders[j] != -1:
			continue
		
		var neighbor_room := _get_neighbor(map_data, coords, map_data.FWD[i] + map_data.FWD[j])
		if neighbor_room:
			if neighbor_room.borders[_opposite(i)] == -1 and neighbor_room.borders[_opposite(j)] == -1:
				continue
		
		var texture: Texture2D = _theme.inner_corner
		var color1 := _get_neighbor(map_data, coords, map_data.FWD[i]).get_border_color(_rotate(i))
		var color2 := _get_neighbor(map_data, coords, map_data.FWD[j]).get_border_color(_rotate(j, -1))
		
		var corner_color := _get_shared_color(color1, color2)
		_draw_corner(i, _theme.inner_corner, corner_color)

func _draw_shared_borders(cell_data: CellData, display_flags: int, discovered: int):
	var _original_item := _canvas_item
	_canvas_item = _shared_border_item
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
	
	if display_outlines and _get_border_texture(_theme, -1, 0):
		var separators := 2
		if _theme.separator_mode == MapTheme.SeparatorMode.EMPTY_DOUBLE or _theme.separator_mode == MapTheme.SeparatorMode.FULL_DOUBLE:
			separators = 4
		
		var full := _theme.separator_mode == MapTheme.SeparatorMode.FULL_DOUBLE or _theme.separator_mode == MapTheme.SeparatorMode.FULL_SINGLE
		for i in separators:
			if borders[i] == 0 or (not full and borders[i] != -1):
				continue
			
			var texture := _get_border_texture(_theme, -1, i)
			if not texture:
				continue
			
			_draw_border(i, texture, Color.WHITE)
	
	var left_edge := not _left_cell or not _left_cell._should_draw()
	var top_edge := not _top_cell or not _top_cell._should_draw()
	var top_left_edge := not _top_left_cell or not _top_left_cell._should_draw()
	
	for i in 4:
		if not left_edge and i == MetSys.L:
			continue
		if not top_edge and i == MetSys.U:
			continue
		
		var texture: Texture2D
		var color: Color
		
		if borders[i] > -1:
			var border: int = borders[i]
			if not bool(display_flags & MetroidvaniaSystem.DISPLAY_BORDERS):
				border = 0
			
			var fwd := Vector3i(MetroidvaniaSystem.MapData.FWD[i].x, MetroidvaniaSystem.MapData.FWD[i].y, 0)
			var other_cell: CellData = MetSys.map_data.get_cell_at(coords + fwd)
			var other_status: int
			if other_cell:
				other_status = _get_discovered_status(coords + fwd)
			
			if other_cell and other_status > 0:
				var other_border := other_cell.get_border(_opposite(i))
				if not display_outlines and other_border == 0:
					other_border = -1
				elif other_status == 1 and not bool(_theme.mapped_display & MetroidvaniaSystem.DISPLAY_BORDERS):
					other_border = mini(other_border, 0 if display_outlines else -1)
				
				border = maxi(border, other_border)
			
			texture = _get_border_texture(_theme, border, i)
			color = _get_shared_border_color(i)
		
		if not texture:
			continue
		
		_draw_border(i, texture, color)
	
	# corners
	if not _theme.is_nocorner():
		_canvas_item = _shared_corner_item
		_draw_shared_corner(Vector2())
		if left_edge:
			_draw_shared_corner(Vector2(-1, 0))
		if top_edge:
			_draw_shared_corner(Vector2(0, -1))
		if top_left_edge:
			_draw_shared_corner(Vector2(-1, -1))
	
	_canvas_item = _original_item

func _get_border_texture(_theme: MapTheme, idx: int, direction: int) -> Texture2D:
	var texture_name: StringName
	
	if _theme.rectangle:
		if direction == MetroidvaniaSystem.R or direction == MetroidvaniaSystem.L:
			match idx:
				-1:
					texture_name = &"vertical_separator"
				0:
					texture_name = &"vertical_wall"
				1:
					texture_name = &"vertical_passage"
				_:
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
					texture_name = &"horizontal_borders"
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
		return _theme.get(texture_name)[idx - 2]
	else:
		return _theme.get(texture_name)

func _get_corner_bit(coords: Vector3i, idx: int) -> int:
	return int(_get_border_at(coords, idx) > -1)

func _get_border_at(coords: Vector3i, idx: int) -> int:
	var cell_data = _get_discovered_cell_at(coords)
	if not cell_data:
		return -1
	return cell_data.get_border(idx)

func _get_shared_border_color(idx: int, source_coords := coords) -> Color:
	var fwd := Vector3i(MetroidvaniaSystem.MapData.FWD[idx].x, MetroidvaniaSystem.MapData.FWD[idx].y, 0)
	var color := Color.TRANSPARENT
	var mapped_color: Color = MetSys.settings.theme.mapped_border_color
	
	var cell_data: CellData = MetSys.map_data.get_cell_at(source_coords)
	if cell_data and cell_data.get_border(idx) > -1:
		var status := _get_discovered_status(source_coords)
		if status == 1:
			color = mapped_color
		elif status == 2:
			color = cell_data.get_border_color(idx)
	
	idx = _opposite(idx)
	cell_data = MetSys.map_data.get_cell_at(source_coords + fwd)
	if cell_data and cell_data.get_border(idx) > -1:
		var other_color := Color.TRANSPARENT
		var status := _get_discovered_status(source_coords + fwd)
		if status == 1:
			other_color = mapped_color
		elif status == 2:
			other_color = cell_data.get_border_color(idx)
		
		if color.a > 0 and other_color.a > 0:
			color = _get_shared_color(color, other_color)
		elif other_color.a > 0:
			color = other_color
	
	return color

func _get_discovered_cell_at(coords: Vector3i) -> CellData:
	var cell_data: CellData = MetSys.map_data.get_cell_at(coords)
	if cell_data and (_force_mapped or MetSys.is_cell_discovered(coords)):
		return cell_data
	return null

func _get_discovered_status(coords: Vector3i) -> int:
	var save_data: MetroidvaniaSystem.MetSysSaveData
	if use_save_data:
		save_data = MetSys.save_data
	
	if save_data:
		return save_data.is_cell_discovered(coords)
	elif _force_mapped:
		return 1
	else:
		return 2

func _draw_border(i: int, texture: Texture2D, color: Color):
	var pos: Vector2
	match i:
		MetroidvaniaSystem.R:
			pos.x = MetSys.CELL_SIZE.x - texture.get_width()
		MetroidvaniaSystem.D:
			pos.y = MetSys.CELL_SIZE.y - texture.get_width()
	
	match i:
		MetroidvaniaSystem.R, MetroidvaniaSystem.L:
			pos.y = MetSys.CELL_SIZE.y * 0.5 - texture.get_height() * 0.5
		MetroidvaniaSystem.D, MetroidvaniaSystem.U:
			pos.x = MetSys.CELL_SIZE.x * 0.5 - texture.get_height() * 0.5
	
	if _theme.use_shared_borders:
		match i:
			MetroidvaniaSystem.R:
				pos.x += texture.get_width() / 2
			MetroidvaniaSystem.D:
				pos.y += texture.get_width() / 2
			MetroidvaniaSystem.L:
				pos.x -= texture.get_width() / 2
			MetroidvaniaSystem.U:
				pos.y -= texture.get_width() / 2
	
	_draw_texture(texture, color, pos, i)

func _draw_shared_corner(corner_offset: Vector2):
	var corner_coords := coords + Vector3i(corner_offset.x, corner_offset.y, 0)
	
	var corner_data: int
	corner_data |= (1 << 0) * (_get_corner_bit(corner_coords, MetroidvaniaSystem.R) | _get_corner_bit(corner_coords + Vector3i(1, 0, 0), MetroidvaniaSystem.L))
	corner_data |= (1 << 1) * (_get_corner_bit(corner_coords, MetroidvaniaSystem.D) | _get_corner_bit(corner_coords + Vector3i(0, 1, 0), MetroidvaniaSystem.U))
	corner_data |= (1 << 2) * (_get_corner_bit(corner_coords + Vector3i(0, 1, 0), MetroidvaniaSystem.R) | _get_corner_bit(corner_coords + Vector3i(1, 1, 0), MetroidvaniaSystem.L))
	corner_data |= (1 << 3) * (_get_corner_bit(corner_coords + Vector3i(1, 0, 0), MetroidvaniaSystem.D) | _get_corner_bit(corner_coords + Vector3i(1, 1, 0), MetroidvaniaSystem.U))
	
	var color := Color.TRANSPARENT
	color = _get_corner_blend(color, MetroidvaniaSystem.R, corner_coords)
	color = _get_corner_blend(color, MetroidvaniaSystem.D, corner_coords)
	color = _get_corner_blend(color, MetroidvaniaSystem.L, corner_coords + Vector3i(1, 1, 0))
	color = _get_corner_blend(color, MetroidvaniaSystem.U, corner_coords + Vector3i(1, 1, 0))
	
	if _theme.is_unicorner():
		corner_data = signi(corner_data) * 15
	
	var corner_type := signi(corner_data & 1) + signi(corner_data & 2) + signi(corner_data & 4) + signi(corner_data & 8)
	var corner_texture: Texture2D
	var corner_rotation := -1
	match corner_type:
		1:
			corner_texture = _theme.u_corner
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
			corner_texture = _theme.l_corner
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
			corner_texture = _theme.t_corner
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
			corner_texture = _theme.cross_corner
			corner_rotation = 0
	
	if corner_rotation == -1 or not corner_texture:
		return
	
	_draw_texture(corner_texture, color, MetSys.CELL_SIZE - corner_texture.get_size() / 2 + corner_offset * MetSys.CELL_SIZE, corner_rotation)

func _draw_corner(i: int, texture: Texture2D, color: Color):
	match i:
		MetroidvaniaSystem.R:
			_draw_texture(texture, color, MetSys.CELL_SIZE - texture.get_size(), i)
		MetroidvaniaSystem.D:
			_draw_texture(texture, color, Vector2.DOWN * (MetSys.CELL_SIZE.y - texture.get_height()), i)
		MetroidvaniaSystem.L:
			_draw_texture(texture, color, Vector2(), i)
		MetroidvaniaSystem.U:
			_draw_texture(texture, color, Vector2.RIGHT * (MetSys.CELL_SIZE.x - texture.get_width()), i)

func _rotate(i: int, amount := 1) -> int:
	return (i + amount) % 4

func _opposite(i: int) -> int:
	return (i + 2) % 4

func _get_shared_color(color1: Color, color2: Color) -> Color:
	var color1_priority := 2
	if color1 == _theme.default_border_color:
		color1_priority = 1
	elif color1 == _theme.mapped_border_color:
		color1_priority = 0
	
	var color2_priority := 2
	if color2 == _theme.default_border_color:
		color2_priority = 1
	elif color2 == _theme.mapped_border_color:
		color2_priority = 0
	
	if color1_priority > color2_priority:
		return color1
	elif color2_priority > color1_priority:
		return color2
	
	return color1.lerp(color2, 0.5)

func _get_corner_blend(base_color: Color, idx: int, pos: Vector3i) -> Color:
	var blend_color := _get_shared_border_color(idx, pos)
	if blend_color.a > 0:
		if base_color.a > 0:
			return _get_shared_color(base_color, blend_color)
		else:
			return blend_color
	return base_color

func _get_neighbor(map_data: MetroidvaniaSystem.MapData, coords: Vector3i, offset: Vector2i) -> CellData:
	var neighbor: Vector2i = Vector2i(coords.x, coords.y) + offset
	return map_data.get_cell_at(Vector3i(neighbor.x, neighbor.y, coords.z))

func _should_draw() -> bool:
	var cell_data: CellData = MetSys.map_data.get_cell_at(coords)
	if not cell_data:
		return false
	
	return _get_discovered_status(coords) > 0
