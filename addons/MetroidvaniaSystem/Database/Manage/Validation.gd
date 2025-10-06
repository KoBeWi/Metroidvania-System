@tool
extends PanelContainer

enum { SUCCESS, WARNING, ERROR, INFO }

var warning_color: Color
var error_color: Color
var success_color: Color

var has_error: bool

func _ready() -> void:
	if not is_part_of_edited_scene():
		hide()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		warning_color = get_theme_color(&"warning_color", &"Editor")
		error_color = get_theme_color(&"error_color", &"Editor")
		success_color = get_theme_color(&"success_color", &"Editor")

func validate_map_data() -> void:
	dismiss()
	has_error = false
	
	var map_theme: MapTheme = MetSys.settings.theme
	
	var unused_symbols: Array[int]
	unused_symbols.assign(range(map_theme.symbols.size()))
	unused_symbols.erase(map_theme.uncollected_item_symbol)
	unused_symbols.erase(map_theme.collected_item_symbol)
	
	for coords in MetSys.map_data.cells:
		var cell_data: MetroidvaniaSystem.MapData.CellData = MetSys.map_data.cells[coords]
		
		if MetSys.map_data.get_assigned_scene_at(coords).is_empty():
			add_label(tr("No assigned map at: %s") % coords, WARNING)
		
		var symbol := cell_data.get_symbol()
		if symbol >= map_theme.symbols.size():
			add_label(tr("Invalid symbol (%d) at: %s") % [symbol, coords], ERROR)
		else:
			unused_symbols.erase(symbol)
		
		for i in 4:
			var border := cell_data.get_border(i)
			if map_theme.rectangle and border >= map_theme.vertical_borders.size() + 2:
				add_label(tr("Invalid border (%d) at: %s") % [border, coords], ERROR)
			elif not map_theme.rectangle and border >= map_theme.borders.size() + 2:
				add_label(tr("Invalid border (%d) at: %s") % [border, coords], ERROR)
			elif cell_data.get_border(i) != 0:
				var next: Vector3i = coords + Vector3i(MetroidvaniaSystem.MapData.FWD[i].x, MetroidvaniaSystem.MapData.FWD[i].y, 0)
				if not MetSys.map_data.get_cell_at(next):
					add_label(tr("Passage to nowhere at: %s") % coords, WARNING)
	
	for symbol in unused_symbols:
		add_label(tr("Potentially unused symbol: %d") % symbol, WARNING)
	
	if not has_error:
		add_label(tr("Map data is valid."), SUCCESS)

func validate_map_theme() -> void:
	dismiss()
	has_error = false
	
	var map_theme: MapTheme = MetSys.settings.theme
	
	if map_theme.center_texture:
		add_label(tr("Cell Shape: %s") % (tr("Rectangle") if map_theme.rectangle else tr("Square")), INFO)
		add_label(tr("Base Cell Size: %s") % Vector2i(map_theme.center_texture.get_size()), INFO)
	else:
		add_label(tr("Theme is missing center texture. Map can't be drawn."), ERROR)
		return
	
	if map_theme.is_unicorner():
		add_label(tr("Uses unified corners."), INFO)
	
	if map_theme.empty_space_texture and map_theme.empty_space_texture.get_size() != map_theme.center_texture.get_size():
		add_label(tr("Size mismatch between empty texture (%s) and center texture.") % map_theme.empty_space_texture.get_size(), ERROR)
	
	if map_theme.rectangle:
		if map_theme.vertical_borders.size() != map_theme.horizontal_borders.size():
			add_label(tr("Number of horizontal and vertical borders do not match."), ERROR)
		
		check_vertical_border_texture(map_theme.vertical_wall, tr("Vertical wall texture"))
		check_vertical_border_texture(map_theme.vertical_passage, tr("Vertical passage texture"))
		
		for i in map_theme.vertical_borders.size():
			var texture: Texture2D = map_theme.vertical_borders[i]
			check_vertical_border_texture(texture, tr("Vertical border texture at index %d") % i)
		
		check_horizontal_border_texture(map_theme.horizontal_wall, tr("Horizontal wall texture"))
		check_horizontal_border_texture(map_theme.horizontal_passage, tr("Horizontal passage texture"))
		
		for i in map_theme.horizontal_borders.size():
			var texture: Texture2D = map_theme.horizontal_borders[i]
			check_horizontal_border_texture(texture, tr("Horizontal border texture at index %d") % i)
	else:
		check_vertical_border_texture(map_theme.wall, tr("Wall texture"))
		check_vertical_border_texture(map_theme.passage, tr("Passage texture"))
		
		for i in map_theme.borders.size():
			var texture: Texture2D = map_theme.borders[i]
			check_vertical_border_texture(texture, tr("Border texture at index %d") % i)
	
	if map_theme.uncollected_item_symbol >= map_theme.symbols.size():
		add_label(tr("Uncollected item symbol index is greater than number of available symbols."), ERROR)
	
	if map_theme.collected_item_symbol >= map_theme.symbols.size():
		add_label(tr("Collected item symbol index is greater than number of available symbols."), ERROR)
	
	for i in map_theme.symbols.size():
		check_symbol_texture(map_theme.symbols[i], tr("Symbol %d texture") % i)
	if map_theme.use_shared_borders:
		check_corner_texture(map_theme.u_corner, tr("U corner texture"))
		check_corner_texture(map_theme.l_corner, tr("L corner texture"))
		check_corner_texture(map_theme.t_corner, tr("T corner texture"))
		check_corner_texture(map_theme.cross_corner, tr("Cross corner texture"))
	else:
		check_corner_texture(map_theme.inner_corner, tr("Inner corner texture"))
		check_corner_texture(map_theme.outer_corner, tr("Outer corner texture"))
	
	if map_theme.player_location_scene:
		var test := map_theme.player_location_scene.instantiate()
		test.queue_free()
		if not test is Node2D:
			add_label(tr("Player location scene is not a Node2D."), ERROR)
	else:
		add_label(tr("Missing player location scene. Player location can't be displayed using built-in methods."), WARNING)
	
	if not has_error:
		add_label(tr("Theme is valid."), SUCCESS)

func check_vertical_border_texture(texture: Texture2D, texture_name: String):
	if texture:
		var map_theme: MapTheme = MetSys.settings.theme
		if texture.get_height() != map_theme.center_texture.get_height():
			add_label(tr("%s has invalid height (%d). It should be vertical, oriented towards the right side and match the height of the center texture.") % [texture_name, texture.get_height()], ERROR)
		elif texture.get_width() > map_theme.center_texture.get_width() / 2:
			add_label(tr("%s is wider than half of the center texture. It may cause overlaps.") % texture_name, WARNING)
	else:
		add_label(tr("%s is empty.") % texture_name, ERROR)

func check_horizontal_border_texture(texture: Texture2D, texture_name: String):
	if texture:
		var map_theme: MapTheme = MetSys.settings.theme
		if texture.get_height() != map_theme.center_texture.get_width():
			add_label(tr("%s has invalid height (%d). It should be vertical, oriented towards the right side and height should match the width of the center texture.") % [texture_name, texture.get_height()], ERROR)
		elif texture.get_width() > map_theme.center_texture.get_height() / 2:
			add_label(tr("%s is wider than half of the height of the center texture. It may cause overlaps.") % texture_name, WARNING)
	else:
		add_label(tr("%s is empty.") % texture_name, ERROR)

func check_symbol_texture(texture: Texture2D, texture_name: String):
	if texture:
		var map_theme: MapTheme = MetSys.settings.theme
		if texture.get_width() > map_theme.center_texture.get_width() or texture.get_height() > map_theme.center_texture.get_height():
			add_label(tr("%s is bigger than center texture. It will stick out of cells.") % texture_name, WARNING)
	else:
		add_label(tr("%s is empty.") % texture_name, ERROR)

func check_corner_texture(texture: Texture2D, texture_name: String):
	if texture:
		var map_theme: MapTheme = MetSys.settings.theme
		if texture.get_width() > map_theme.center_texture.get_width() / 2 or texture.get_height() > map_theme.center_texture.get_height() / 2:
			add_label(tr("%s is bigger than half of the center texture. It may cause overlaps.") % texture_name, WARNING)
	else:
		add_label(tr("%s is empty.") % texture_name, ERROR)

func add_label(text: String, type: int):
	show()
	
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.text = "• " + text
	
	match type:
		SUCCESS:
			label.modulate = success_color
		WARNING:
			label.modulate = warning_color
		ERROR:
			label.modulate = error_color
			has_error = true
	
	%Output.add_child(label)

func dismiss() -> void:
	if not visible:
		return
	
	for node in %Output.get_children():
		node.queue_free()
	hide()
