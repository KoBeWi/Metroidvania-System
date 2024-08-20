extends RefCounted

const CellData = MetroidvaniaSystem.MapData.CellData

var use_save_data: bool = true
var skip_empty: bool

var visible: bool:
	set(v):
		visible = v
		RenderingServer.canvas_item_set_visible(_canvas_item, visible)

var offset: Vector2:
	set(v):
		offset = v
		RenderingServer.canvas_item_set_transform(_canvas_item, Transform2D(0, offset * MetSys.CELL_SIZE))

var _canvas_item: RID
var _coords: Vector3i
var _theme: MapTheme
	
var _force_mapped: bool

func _init(parent_item: RID) -> void:
	_canvas_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_canvas_item, parent_item)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		RenderingServer.free_rid(_canvas_item)

func update():
	RenderingServer.canvas_item_clear(_canvas_item)
	_draw()

func _draw():
	_theme = MetSys.settings.theme
	
	var save_data: MetroidvaniaSystem.MetSysSaveData
	if use_save_data:
		save_data = MetSys.save_data
	
	var cell_data: CellData = MetSys.map_data.get_cell_at(_coords)
	if not cell_data:
		if not skip_empty:
			draw_empty()
		return
	
	var discovered := 2
	if save_data:
		discovered = save_data.is_cell_discovered(_coords)
	elif _force_mapped:
		discovered = 1
	
	if discovered == 0:
		if not skip_empty:
			draw_empty()
		return
	
	var display_flags: int = (int(discovered == 2) * 255) | _theme.mapped_display
	
	# center
	if bool(display_flags & MetroidvaniaSystem.DISPLAY_CENTER):
		_draw_texture(_theme.center_texture, cell_data.get_color() if discovered == 2 else _theme.mapped_center_color)
	
	# corners
	_draw_regular_borders(cell_data, display_flags, discovered)
	
	if bool(display_flags & MetroidvaniaSystem.DISPLAY_SYMBOLS):
		var symbol: int = -1
		
		if save_data and _coords in save_data.custom_markers:
			var custom: int = save_data.custom_markers[_coords]
			for i in range(63, -1, -1):
				if custom & 1 << i:
					symbol = i
					break
		
		if symbol == -1:
			symbol = cell_data.get_symbol()
		
		if symbol > - 1:
			if symbol >= _theme.symbols.size():
				push_error("Bad symbol '%s' at '%s'" % [symbol, _coords])
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

func draw_empty():
	if _theme.empty_space_texture:
		_draw_texture(_theme.empty_space_texture)

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
	
	if not display_outlines:
		return
	
	# outer corner
	for i in 4:
		var j := _rotate(i)
		if borders[i] == -1 or borders[j] == -1:
			continue
		
		var texture: Texture2D = _theme.outer_corner
		var corner_color: Color
		if discovered == 2:
			corner_color = _get_shared_color(cell_data.get_border_color(i), cell_data.get_border_color(j), _theme.default_border_color)
		else:
			corner_color = _theme.mapped_border_color
		
		_draw_corner(i, texture, corner_color)
	
	# inner corner
	for i in 4:
		var j := _rotate(i)
		if borders[i] != -1 or borders[j] != -1:
			continue
		
		var neighbor_room := _get_neighbor(map_data, _coords, map_data.FWD[i] + map_data.FWD[j])
		if neighbor_room:
			if neighbor_room.borders[_opposite(i)] == -1 and neighbor_room.borders[_opposite(j)] == -1:
				continue
		
		var texture: Texture2D = _theme.inner_corner
		var color1 := _get_neighbor(map_data, _coords, map_data.FWD[i]).get_border_color(_rotate(i))
		var color2 := _get_neighbor(map_data, _coords, map_data.FWD[j]).get_border_color(_rotate(j, -1))
		
		var corner_color := _get_shared_color(color1, color2, _theme.default_border_color)
		_draw_corner(i, _theme.inner_corner, corner_color)

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
	
	_draw_texture(texture, color, pos, i)

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

func _get_shared_color(color1: Color, color2: Color, default: Color) -> Color:
	if color1 == default:
		return color2
	elif color2 == default:
		return color1
	return color1.lerp(color2, 0.5)

func _get_neighbor(map_data: MetroidvaniaSystem.MapData, coords: Vector3i, offset: Vector2i) -> MetroidvaniaSystem.MapData.CellData:
	var neighbor: Vector2i = Vector2i(coords.x, coords.y) + offset
	return map_data.get_cell_at(Vector3i(neighbor.x, neighbor.y, coords.z))
