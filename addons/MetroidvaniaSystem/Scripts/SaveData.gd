extends RefCounted

const SIMPLE_STORABLE_PROPERTIES: Array[StringName] = [&"discovered_cells", &"registered_objects", &"stored_objects", &"custom_markers"]

var discovered_cells: Dictionary#[Vector3i, int]
var registered_objects: Dictionary#[String, bool]
var stored_objects: Dictionary#[String, bool]

var custom_markers: Dictionary#[Vector3i, int]
var cell_overrides: Dictionary#[CellData, CellOverride]

func discover_cell(coords: Vector3i):
	if discovered_cells.get(coords, 0) < 1:
		discovered_cells[coords] = 1

func explore_cell(coords: Vector3i):
	if discovered_cells.get(coords, 0) < 2:
		if MetSys.settings.discover_whole_rooms:
			for cell in MetSys.map_data.get_whole_room(coords):
				discovered_cells[cell] = 2
		else:
			discovered_cells[coords] = 2
		MetSys.map_updated.emit()

func is_cell_discovered(coords: Vector3i) -> int:
	return discovered_cells.get(coords, 0)

func register_storable_object(object: Object) -> bool:
	var id: String = MetSys.get_object_id(object)
	if not id in registered_objects:
		registered_objects[id] = true
		return true
	return false

func store_object(object: Object):
	var id: String = MetSys.get_object_id(object)
	assert(id in registered_objects)
	assert(not id in stored_objects)
	registered_objects.erase(id)
	stored_objects[id] = true

func is_object_stored(object: Object) -> bool:
	var id: String = MetSys.get_object_id(object)
	return id in stored_objects

func add_cell_override(room: MetroidvaniaSystem.MapData.CellData) -> MetroidvaniaSystem.MapData.CellOverride:
	if not room in cell_overrides:
		cell_overrides[room] = MetroidvaniaSystem.MapData.CellOverride.new(room)
	return cell_overrides[room]

func remove_cell_override(room: MetroidvaniaSystem.MapData.CellData) -> bool:
	var override := cell_overrides.get(room)
	if override:
		if override.custom_cell_coords != Vector3i.MAX:
			push_error("Can't delete override of a custom cell. Use destroy() instead.")
			return false
		override._cleanup_assigned_scene()
	
	cell_overrides.erase(room)
	return override != null

func add_custom_marker(coords: Vector3i, symbol: int):
	if not coords in custom_markers:
		custom_markers[coords] = 0
	
	custom_markers[coords] |= 1 << symbol
	MetSys.map_updated.emit()

func remove_custom_marker(coords: Vector3i, symbol: int):
	if not coords in custom_markers:
		return
	
	custom_markers[coords] &= ~(1 << symbol)
	if custom_markers[coords] == 0:
		custom_markers.erase(coords)
	MetSys.map_updated.emit()

func get_data() -> Dictionary:
	var data: Dictionary
	
	for property in SIMPLE_STORABLE_PROPERTIES:
		data[property] = get(property)
	
	data[&"cell_overrides"] = cell_overrides.keys().map(func(room):
		var coords: Vector3i = MetSys.map_data.cells.find_key(room)
		return cell_overrides[room]._get_override_string(coords))
	
	return data

func set_data(data: Dictionary):
	if data.is_empty():
		return
	
	for property in SIMPLE_STORABLE_PROPERTIES:
		set(property, data[property])
	
	for override_string in data.cell_overrides:
		var override: MetroidvaniaSystem.MapData.CellOverride = MetroidvaniaSystem.MapData.CellOverride.load_from_line(override_string)
		cell_overrides[override.original_room] = override
