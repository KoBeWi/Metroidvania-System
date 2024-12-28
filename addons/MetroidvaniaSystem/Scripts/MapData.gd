const FWD = { MetroidvaniaSystem.R: Vector2i.RIGHT, MetroidvaniaSystem.D: Vector2i.DOWN, MetroidvaniaSystem.L: Vector2i.LEFT, MetroidvaniaSystem.U: Vector2i.UP }

class CellData:
	enum { DATA_EXITS, DATA_COLORS, DATA_SYMBOL, DATA_MAP, OVERRIDE_COORDS, OVERRIDE_CUSTOM }
	
	var color: Color = Color.TRANSPARENT
	var borders: Array[int] = [-1, -1, -1, -1]
	var border_colors: Array[Color] = [Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT, Color.TRANSPARENT]
	var symbol := -1
	var assigned_scene: String
	var override_map: String
	
	var loading: Variant
	
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
		
		assigned_scene = load_next_chunk()
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
		
		if MetSys.map_data.exporting_mode:
			data.append(MetSys.map_data.get_uid_room(assigned_scene))
		else:
			data.append(assigned_scene.trim_prefix(MetSys.settings.map_root_folder + "/"))
		
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
	
	func get_border(idx: int) -> int:
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
	
	func get_symbol() -> int:
		var override := get_override()
		if override and override.symbol != -2:
			return override.symbol
		return symbol
	
	func get_assigned_scene() -> String:
		var override := get_override()
		if override and override.assigned_scene != "/":
			return override.assigned_scene
		if not override_map.is_empty():
			return override_map
		return assigned_scene
	
	func get_override() -> CellOverride:
		if not MetSys.save_data:
			return null
		return MetSys.save_data.cell_overrides.get(self)
	
	func get_coords() -> Vector3i:
		return MetSys.map_data.cells.find_key(self)

## A runtime override for the cell's properties that allows to modify it's default appearance designed in the editor.
##
## CellOverride can be obtained from [method MetroidvaniaSystem.get_cell_override] or using the MapBuilder. It comes with a set of methods that allows customizing the cells. [signal MetroidvaniaSystem.map_updated] signal is automatically emitted after modifications, unless the cell comes from MapBuilder.
class CellOverride extends CellData:
	var original_room: CellData
	var custom_cell_coords := Vector3i.MAX
	var commit_queued: bool
	
	func _init(from: CellData) -> void:
		original_room = from
		borders = [-2, -2, -2, -2]
		symbol = -2
		assigned_scene = "/"
	
	static func load_from_line(line: String) -> CellOverride:
		var cell: CellData
		var coords_string := line.get_slice("|", CellData.OVERRIDE_COORDS)
		var coords := Vector3i(coords_string.get_slice(",", 0).to_int(), coords_string.get_slice(",", 1).to_int(), coords_string.get_slice(",", 2).to_int())
		
		var is_custom := line.get_slice("|", CellData.OVERRIDE_CUSTOM) == "true"
		if is_custom:
			cell = MetSys.map_data.create_cell_at(coords)
		else:
			cell = MetSys.map_data.get_cell_at(coords)
		
		var override := CellOverride.new(cell)
		if is_custom:
			override.custom_cell_coords = coords
		
		var fake_cell := CellData.new(line)
		override.borders = fake_cell.borders
		override.border_colors = fake_cell.border_colors
		override.color = fake_cell.color
		override.symbol = fake_cell.symbol
		override.set_assigned_scene(fake_cell.assigned_scene)
		
		return override
	
	## Sets a border of the cell. [param idx] is the direction index of the cell. Use [constant MetroidvaniaSystem.R], [constant MetroidvaniaSystem.D], [constant MetroidvaniaSystem.L], [constant MetroidvaniaSystem.U] constants here. The [param value] must be within the [member MapTheme.borders] array bounds + 2 (0 and 1 are the default wall and passage). Use the default to reset to the border assigned in the editor. Value of [code]-1[/code] will remove the border, but it's not recommended.
	func set_border(idx: int, value := -2):
		assert(idx >= 0 and idx < 4)
		if value == borders[idx]:
			return
		
		borders[idx] = value
		_queue_commit()
	
	## Sets the color of a cell's border. [param idx] is the direction index of the cell (see [method set_border]). If the default [param value] is used (or any color with [code]0[/code] alpha), the border will be reset to the default color.
	func set_border_color(idx: int, value := Color.TRANSPARENT):
		assert(idx >= 0 and idx < 4)
		if value == border_colors[idx]:
			return
		
		border_colors[idx] = value
		_queue_commit()
	
	## Sets the color of the cell's center texture.
	func set_color(value := Color.TRANSPARENT):
		if value == color:
			return
		
		color = value
		_queue_commit()
	
	## Sets the cell's assigned symbol. Value of [code]-1[/code] will remove the symbol. The markers assigned from [method MetroidvaniaSystem.set_custom_marker] still have a priority.
	func set_symbol(value := -2):
		assert(value >= -2 and value < MetSys.settings.theme.symbols.size())
		if value == symbol:
			return
		
		symbol = value
		_queue_commit()
	
	## Changes the scene assigned to the cell. Unlike other methods, this has effect on the whole room that contains this cell. Using the default value will reset it to the scene assigned in the editor.
	func set_assigned_scene(value := "/"):
		if value == assigned_scene:
			return
		
		if value == "/":
			_cleanup_assigned_scene()
		else:
			if custom_cell_coords != Vector3i.MAX:
				if not value in MetSys.map_data.assigned_scenes:
					MetSys.map_data.assigned_scenes[value] = []
				MetSys.map_data.assigned_scenes[value].append(custom_cell_coords)
			else:
				MetSys.map_data.scene_overrides[value] = original_room.assigned_scene
				
				for coords in MetSys.map_data.get_whole_room(original_room.get_coords()):
					var cell: CellData = MetSys.map_data.cells[coords]
					if not cell.override_map.is_empty():
						push_warning("Assigned map already overriden at: %s" % coords)
					cell.override_map = value
		
		assigned_scene = value
		MetSys.room_assign_updated.emit()
		_queue_commit()
	
	## Applies the values from this CellOverride to all cells that belong to the specified [param group_id]. You need to apply your customization [i]before[/i] calling this method.
	func apply_to_group(group_id: int):
		assert(group_id in MetSys.map_data.cell_groups)
		
		for coords in MetSys.map_data.cell_groups[group_id]:
			var override: CellOverride = MetSys.get_cell_override(coords)
			if override == self:
				continue
			
			override.borders = borders.duplicate()
			override.color = color
			override.border_colors = border_colors.duplicate()
			override.symbol = symbol
		
		_queue_commit()
	
	## Destroys the cell. This method can only be used on the overrides from the MapBuilder.
	func destroy() -> void:
		if custom_cell_coords == Vector3i.MAX:
			push_error("Only custom cell can be destroyed.")
			return
		
		var cell_coords := custom_cell_coords
		custom_cell_coords = Vector3i.MAX
		
		MetSys.remove_cell_override(cell_coords)
		MetSys.map_data.erase_cell(cell_coords)
		MetSys.map_data.cell_overrides.erase(cell_coords)
		MetSys.map_data.custom_cells.erase(self)
		
		if assigned_scene != "/":
			MetSys.map_data.assigned_scenes[assigned_scene].erase(cell_coords)
		
		if MetSys.save_data:
			MetSys.save_data.discovered_cells.erase(cell_coords)
	
	func _cleanup_assigned_scene() -> void:
		if assigned_scene == "/":
			return
		
		MetSys.map_data.scene_overrides.erase(assigned_scene)
		for coords in MetSys.map_data.get_whole_room(original_room.get_coords()):
			MetSys.map_data.cells[coords].override_map = ""
	
	func _get_override_string(coords: Vector3i) -> String:
		return str(get_string(), "|", coords.x, ",", coords.y, ",", coords.z, "|", custom_cell_coords != Vector3i.MAX)
	
	func _queue_commit():
		if commit_queued or custom_cell_coords != Vector3i.MAX:
			return
		commit_queued = true
		_commit.call_deferred()
	
	func _commit() -> void:
		commit_queued = false
		MetSys.map_updated.emit()

class CustomElement:
	var name: String
	var size: Vector2i
	var data: String

var cells: Dictionary#[Vector3i, CellData]
var custom_cells: Dictionary#[Vector3i, CellData]
var assigned_scenes: Dictionary#[String, Array[Vector3i]]
var cell_groups: Dictionary#[int, Array[Vector3i]]
var custom_elements: Dictionary#[Vector3i, CustomElement]

var layer_names: PackedStringArray
var cell_overrides: Dictionary#[Vector3i, CellOverride]
var scene_overrides: Dictionary#[String, String]

var exporting_mode: bool
signal saved

func load_data():
	var file := FileAccess.open(get_map_data_path(), FileAccess.READ)
	if not file:
		push_warning("Map data file does not exist.")
		return
	
	var data := file.get_as_text().split("\n")
	var i: int
	
	var current_section := 0 # groups, custom_elements, cells
	while i < data.size():
		var line := data[i].strip_edges()
		if line.begins_with("$ln"):
			layer_names = line.split(";").slice(1)
		elif line.begins_with("["):
			current_section = 2
			line = line.trim_prefix("[").trim_suffix("]")
			
			var coords: Vector3i
			coords.x = line.get_slice(",", 0).to_int()
			coords.y = line.get_slice(",", 1).to_int()
			coords.z = line.get_slice(",", 2).to_int()
			
			i += 1
			line = data[i].strip_edges()
			
			var cell_data := CellData.new(line)
			if not cell_data.assigned_scene.is_empty():
				assigned_scenes[cell_data.assigned_scene] = [coords]
			
			cells[coords] = cell_data
		elif current_section == 1 or current_section == 0 and line.contains("/"):
			current_section = 1
			var element_data := line.split("/")
			var element := CustomElement.new()
			element.name = element_data[1]
			element.size = Vector2i(element_data[2].get_slice("x", 0).to_int(), element_data[2].get_slice("x", 1).to_int())
			if element_data.size() == 4:
				element.data = element_data[3]
			else:
				element.data = ""
			
			var coords: Vector3i
			coords.x = element_data[0].get_slice(",", 0).to_int()
			coords.y = element_data[0].get_slice(",", 1).to_int()
			coords.z = element_data[0].get_slice(",", 2).to_int()
			custom_elements[coords] = element
		elif current_section == 0:
			var group_data := line.split(":")
			var group_id := group_data[0].to_int()
			var rooms_in_group: Array
			for j in range(1, group_data.size()):
				var coords: Vector3i
				coords.x = group_data[j].get_slice(",", 0).to_int()
				coords.y = group_data[j].get_slice(",", 1).to_int()
				coords.z = group_data[j].get_slice(",", 2).to_int()
				rooms_in_group.append(coords)
			
			cell_groups[group_id] = rooms_in_group
		
		i += 1
	
	for map in assigned_scenes.keys():
		var assigned_cells: Array[Vector3i]
		assigned_cells.assign(assigned_scenes[map])
		assigned_scenes[map] = get_whole_room(assigned_cells[0])

func save_data(backup := false):
	var file_path: String
	if backup:
		file_path = MetSys.settings.map_root_folder.path_join("MapData(Copy).txt")
	else:
		file_path = get_map_data_path()
	
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Could not open file '%s' for writing." % file_path)
		return
	
	if not layer_names.is_empty():
		var i := layer_names.size() - 1
		while i > -1:
			if not layer_names[i].is_empty():
				break
			i -= 1
		
		if i > -1:
			layer_names = layer_names.slice(0, i + 1)
	
	if not layer_names.is_empty():
		file.store_line("$ln;" + ";".join(layer_names))
	
	for group in cell_groups:
		if cell_groups[group].is_empty():
			continue
		
		var line: PackedStringArray
		line.append(str(group))
		for coords in cell_groups[group]:
			line.append("%s,%s,%s" % [coords.x, coords.y, coords.z])
		
		file.store_line(":".join(line))
	
	for coords in custom_elements:
		var line: PackedStringArray
		line.append("%s,%s,%s" % [coords.x, coords.y, coords.z])
		
		var element: CustomElement = custom_elements[coords]
		line.append(element.name)
		line.append("%sx%s" % [element.size.x, element.size.y])
		if not element.data.is_empty():
			line.append(element.data)
		
		file.store_line("/".join(line))
	
	for coords in cells:
		file.store_line("[%s,%s,%s]" % [coords.x, coords.y, coords.z])
		
		var cell_data := get_cell_at(coords)
		file.store_line(cell_data.get_string())
	
	file.close()
	saved.emit()

func get_cell_at(coords: Vector3i) -> CellData:
	return cells.get(coords)

func create_cell_at(coords: Vector3i) -> CellData:
	cells[coords] = CellData.new("")
	return cells[coords]

func insert_cell_at(coords: Vector3i, cell: CellData):
	cells[coords] = cell

func create_custom_cell(coords: Vector3i) -> CellOverride:
	assert(not coords in cells, "A cell already exists at this position")
	var cell := create_cell_at(coords)
	custom_cells[coords] = cell
	
	var override: CellOverride = MetSys.save_data.add_cell_override(cell)
	override.custom_cell_coords = coords
	return override

func get_whole_room(at: Vector3i) -> Array[Vector3i]:
	var room: Array[Vector3i]
	
	var to_check: Array[Vector2i] = [Vector2i(at.x, at.y)]
	var checked: Array[Vector2i]
	
	while not to_check.is_empty():
		var p: Vector2i = to_check.pop_back()
		checked.append(p)
		
		var coords := Vector3i(p.x, p.y, at.z)
		if coords in cells:
			room.append(coords)
			for i in 4:
				if cells[coords].borders[i] == -1:
					var p2: Vector2i = p + FWD[i]
					if not p2 in to_check and not p2 in checked:
						to_check.append(p2)
	
	return room

func get_cells_assigned_to(room: String) -> Array[Vector3i]:
	if room in scene_overrides:
		room = scene_overrides[room]
	
	if not room in assigned_scenes:
		if not room.begins_with(":"):
			room = ":" + ResourceUID.id_to_text(ResourceLoader.get_resource_uid(MetSys.settings.map_root_folder.path_join(room))).trim_prefix("uid://")
	
	var ret: Array[Vector3i]
	ret.assign(assigned_scenes.get(room, []))
	return ret

func get_cells_assigned_to_path(path: String) -> Array[Vector3i]:
	var room := path.trim_prefix(MetSys.settings.map_root_folder)
	
	if not assigned_scenes.has(room) and not room in scene_overrides:
		room = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path)).replace("uid://", ":")
	
	return get_cells_assigned_to(room)

func get_assigned_scene_at(coords: Vector3i) -> String:
	var cell := get_cell_at(coords)
	if cell:
		return get_uid_room(cell.get_assigned_scene())
	else:
		return ""

func erase_cell(coords: Vector3i):
	var assigned_scene: String = cells[coords].assigned_scene
	assigned_scenes.erase(assigned_scene)
	
	cells.erase(coords)
	
	for group in cell_groups.values():
		group.erase(coords)

func transfer_cell(from_coords: Vector3i, to_coords: Vector3i):
	var cell_data := get_cell_at(from_coords)
	
	var assigned_scene: String = cells[from_coords].assigned_scene
	if not assigned_scene.is_empty():
		assigned_scenes[assigned_scene].erase(from_coords)
		assigned_scenes[assigned_scene].append(to_coords)
	
	cells.erase(from_coords)
	cells[to_coords] = cell_data
	
	for group in cell_groups.values():
		if from_coords in group:
			group.erase(from_coords)
			group.append(to_coords)

func get_uid_room(uid: String) -> String:
	if not uid.begins_with(":"):
		return uid
	
	return ResourceUID.get_id_path(ResourceUID.text_to_id(uid.replace(":", "uid://"))).trim_prefix(MetSys.settings.map_root_folder)

func get_room_from_scene_path(path: String, safe := true) -> String:
	var room_name: String = path.trim_prefix(MetSys.settings.map_root_folder)
	if not room_name in assigned_scenes and not room_name in scene_overrides:
		room_name = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path)).replace("uid://", ":")
	
	room_name = scene_overrides.get(room_name, room_name)
	if safe:
		assert(room_name in assigned_scenes)
	return room_name

func get_map_data_path() -> String:
	return MetSys.settings.map_root_folder.path_join("MapData.txt")
