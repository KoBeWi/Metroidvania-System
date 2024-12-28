@tool
## The class behind the MetSys singleton. It provides almost all of the public API of the addon.
##
## MetroidvaniaSystem class has various methods for interacting with various MetSys sub-systems at runtime. All methods and members with a description are "public", while anything that doesn't have a description is supposed to be used only internally. There are a couple of sub-classes that you can use; you can access their documentation from the methods that return them.
class_name MetroidvaniaSystem extends Node

const DEFAULT_SYMBOL = -99
enum { DISPLAY_CENTER = 1, DISPLAY_OUTLINE = 2, DISPLAY_BORDERS = 4, DISPLAY_SYMBOLS = 8 }

const MetSysSettings = preload("res://addons/MetroidvaniaSystem/Scripts/Settings.gd")
const MetSysSaveData = preload("res://addons/MetroidvaniaSystem/Scripts/SaveData.gd")
const MapData = preload("res://addons/MetroidvaniaSystem/Scripts/MapData.gd")
const CellView = preload("res://addons/MetroidvaniaSystem/Scripts/CellView.gd")
const MapBuilder = preload("res://addons/MetroidvaniaSystem/Scripts/MapBuilder.gd")
const RoomInstance = preload("res://addons/MetroidvaniaSystem/Scripts/RoomInstance.gd")
const CustomElementManager = preload("res://addons/MetroidvaniaSystem/Scripts/CustomElementManager.gd")

enum { R, ## Right border.
		D, ## Bottom border.
		L, ## Left border.
		U, ## Top border.
	}

var settings: MetSysSettings
## The size of a map cell. Automatically set to the size of [member MapTheme.center_texture]. Read only.
var CELL_SIZE: Vector2

var map_data: MapData
var save_data: MetSysSaveData

var last_player_position := Vector3i.MAX
var exact_player_position: Vector2
var current_room: RoomInstance

## The current layer, for the purpose of visiting with [method set_player_position] among other things. MetSys does not modify it automatically in any way. Changing it emits [signal cell_changed] signal.
var current_layer: int:
	set(layer):
		if layer == current_layer:
			return
		
		current_layer = layer
		cell_changed.emit(Vector3i(last_player_position.x, last_player_position.y, current_layer))

## Emitted when the player crosses a cell boundary and visits another cell as a result of [method set_player_position]. The new cell coordinates are provided as an argument.
signal cell_changed(new_cell: Vector3i)
## Emitted when the player enters a new room, i.e. using [method set_player_position] results in a cell that has a different assigned scene. The new scene is provided as an argument, you can use it to easily make room transitions.
signal room_changed(new_room: String)

## Emitted when a map cell was added, deleted or modified. This includes cell overrides and MapBuilder updates.
signal map_updated
signal room_assign_updated
signal theme_modified(changes: Array[String])

func _enter_tree() -> void:
	var settings_path := "res://MetSysSettings.tres"
	
	if ProjectSettings.has_setting("addons/metroidvania_system/settings_file"):
		settings_path = ProjectSettings.get_setting("addons/metroidvania_system/settings_file")
	elif ProjectSettings.has_setting("metroidvania_system/settings_file"):
		# Compatibility. Will be removed.
		var legacy_settings_path: String = ProjectSettings.get_setting("metroidvania_system/settings_file")
		if legacy_settings_path != settings_path:
			push_warning("Detected MetSys settings path under \"metroidvania_system/settings_file\" project setting. Migrating it to the new setting: \"addons/metroidvania_system/settings_file\".")
		
		settings_path = legacy_settings_path
		ProjectSettings.set_setting("addons/metroidvania_system/settings_file", settings_path)
	else:
		ProjectSettings.set_setting("addons/metroidvania_system/settings_file", settings_path)
	
	ProjectSettings.add_property_info({"name": "addons/metroidvania_system/settings_file", "type": TYPE_STRING, "hint": PROPERTY_HINT_FILE, "hint_string": "*.tres"})
	
	if ResourceLoader.exists(settings_path):
		settings = load(settings_path)
	else:
		settings = MetSysSettings.new()
		settings.theme = load("res://addons/MetroidvaniaSystem/Themes/Exquisite/Theme.tres")
		ResourceSaver.save(settings, settings_path)
	
	settings.theme_changed.connect(_update_theme)
	_update_theme()
	
	map_data = MapData.new()
	map_data.load_data()

func _update_theme():
	CELL_SIZE = settings.theme.center_texture.get_size()
	map_updated.emit()

## Loads map data from the provided map root directory. Can be used to support multiple separate world maps (for custom campaigns etc.). 
func load_map_data(folder: String):
	settings.map_root_folder = folder
	map_data = MapData.new()
	map_data.load_data()
	map_updated.emit()

## Resets the state of MetSys singleton to initial one. This means clearing save data, player position, current room and layer.
## [br][br]You should call it every time you start a new game session. This does [i]not[/i] initialize the save data. In fact, it sets it to [code]null[/code], which means that you need to call [method set_save_data] to initialize save data.
func reset_state():
	save_data = null
	last_player_position = Vector3i.MAX
	exact_player_position = Vector2()
	current_room = null
	current_layer = 0

## Returns index of a layer with the given name. Returns [code]-1[/code] and error if layer name does not exist.
func get_layer_by_name(layer: String) -> int:
	var index := map_data.layer_names.find(layer)
	if index == -1:
		push_error("Layer \"%s\" does not exist." % layer)
	return index

## Returns a [Dictionary] containing the MetSys' runtime data, like discovered cells or stored objects. You need to serialize it yourself, e.g. using [method FileAccess.store_var].
func get_save_data() -> Dictionary:
	return save_data.get_data()

## Initializes and loads a save data. Pass it the data from [method get_save_data] to restore the saved state of MetSys. Calling this method with the default parameter will clear the data, allowing to start new game session.
## [br][br]Note that this only resets the save data. You still need to call [method reset_state] [i]before[/i] this method to make sure the singleton is clean.
func set_save_data(data := {}):
	save_data = MetSysSaveData.new()
	save_data.set_data(data)

func visit_cell(coords: Vector3i):
	save_data.explore_cell(coords)
	
	var previous_map := map_data.get_assigned_scene_at(Vector3i(last_player_position.x, last_player_position.y, current_layer))
	var new_map := map_data.get_assigned_scene_at(coords)
	if not new_map.is_empty() and not previous_map.is_empty() and new_map != previous_map:
		room_changed.emit(map_data.get_uid_room(new_map))

## Returns [code]true[/code] if the call was discovered, either mapped (if [param include_mapped] is [code]true[/code]) or explored.
func is_cell_discovered(coords: Vector3i, include_mapped := true) -> bool:
	if not save_data:
		return true
	
	var discovered := save_data.is_cell_discovered(coords)
	return discovered == 2 or include_mapped and discovered == 1

## Returns the ratio of explored cells vs all cells. Cells created with MapBuilder are also included.
func get_explored_ratio(layer := -1):
	var all: float
	var discovered: float
	
	for coords in map_data.cells:
		if layer != -1 and coords.z != layer:
			continue
		
		all += 1
		discovered += int(is_cell_discovered(coords, false))
	
	return discovered / all

## Sets the position of the player to be tracked by MetSys. Automatically explores cells when crossing cell boundary and emits [signal cell_changed] and [signal room_changed] signals.
## [br][br][param position] should be position in the room's coordinates, i.e. with [code](0, 0)[/code] being the top-left corner of the scene assigned to the room (which in most cases simply equals to global position of the player).
func set_player_position(position: Vector2):
	exact_player_position = position
	if not current_room:
		return
	
	var player_pos := Vector2i((position / settings.in_game_cell_size).floor()) + current_room.min_cell
	var player_pos_3d := Vector3i(player_pos.x, player_pos.y, current_layer)
	if player_pos_3d != last_player_position:
		visit_cell(Vector3i(player_pos.x, player_pos.y, current_layer))
		last_player_position = player_pos_3d
		cell_changed.emit(player_pos_3d)

## Discovers (maps) the cell at the given [param coords]. Fails if the cell does not exist.
func discover_cell(coords: Vector3i):
	assert(coords in map_data.cells)
	
	save_data.discover_cell(coords)
	map_updated.emit()

## Discovers (maps) all cells that belong to the specified group. The group ID must exist (i.e. have at least a single cell with it assigned).
func discover_cell_group(group_id: int):
	assert(group_id in map_data.cell_groups)
	
	for coords in map_data.cell_groups[group_id]:
		save_data.discover_cell(coords)
	
	map_updated.emit()

## Assigns a custom symbol to the given cell that will override the symbol set in the editor. You can assign any number of symbols and the one with the highest ID will be displayed. [param symbol_id] must be within the symbols defined in [member MapTheme.symbols].
func add_custom_marker(coords: Vector3i, symbol_id: int):
	assert(symbol_id >= 0 and symbol_id < mini(settings.theme.symbols.size(), 63))
	save_data.add_custom_marker(coords, symbol_id)

## Removes a custom symbol assigned in [method add_custom_marker]. Does nothing if the given [param symbol_id] was not assigned to the cell.
func remove_custom_marker(coords: Vector3i, symbol_id: int):
	save_data.remove_custom_marker(coords, symbol_id)

## Registers a storable object, i.e. object whose state is supposed to be saved, and automatically leaves a marker on the map. Useful for collectibles.
## [br][br][param object] is the object that needs storing, [param stored_callback] is the callback that will be automatically called by this method when the object was already stored (defaults to [method Node.queue_free] for nodes). [param map_marker] is the ID of the symbol that will be added to the cell. If no symbol is provided, [member MapTheme.uncollected_item_symbol] will be used.
## [br][br][b]Note:[/b] [method get_object_id] is used to determine object's ID. You can make the same object appear in multiple places if you assign them custom ID (e.g. to make a collectible that changes its location after an event). [method get_object_coords] is used to determine where the marker should appear.
func register_storable_object_with_marker(object: Object, stored_callback := Callable(), map_marker := DEFAULT_SYMBOL) -> bool:
	if stored_callback.is_null():
		if object is Node:
			stored_callback = object.queue_free
		elif not object is RefCounted:
			stored_callback = Callable(object, &"free")
	
	if save_data.is_object_stored(object):
		stored_callback.call()
		return true
	
	if map_marker == DEFAULT_SYMBOL:
		map_marker = settings.theme.uncollected_item_symbol
		object.set_meta(&"map_marker", map_marker)
	elif map_marker > -1:
		object.set_meta(&"map_marker", map_marker)
	
	if save_data.register_storable_object(object) and map_marker > -1:
		save_data.add_custom_marker(get_object_coords(object), map_marker)
	
	return false

## Same as [method register_storable_object_with_marker], but doesn't assign any marker. Useful for things like buttons, breakable walls etc.
func register_storable_object(object: Object, stored_callback := Callable()) -> bool:
	return register_storable_object_with_marker(object, stored_callback, -1)

## Stores the given object. Using [method register_storable_object] aftewards will call its callback. Note that this method simply registers the object as stored, it does not free it nor anything. [param map_marker] is the ID of the symbol that will be added to the cell. If no symbol is provided, [member MapTheme.collected_item_symbol] will be used.
## [br][br][b]Note:[/b] The marker will be ignored if the object was not registered with a marker.
func store_object(object: Object, map_marker := DEFAULT_SYMBOL):
	save_data.store_object(object)
	if object.has_meta(&"map_marker"):
		save_data.remove_custom_marker(get_object_coords(object), object.get_meta(&"map_marker"))
	else:
		map_marker = -1
	
	if map_marker == DEFAULT_SYMBOL:
		map_marker = settings.theme.collected_item_symbol
	
	if map_marker > -1:
		save_data.add_custom_marker(get_object_coords(object), map_marker)

## Returns the game-unique ID of an object. It's used to identify instances of objects in the game's world. It can be used manually when storable objects are insufficient for whatever reason.
## [br][br]The ID is first determined from [code]object_id[/code] metadata (see [method Object.set_meta]), then using [code]_get_object_id()[/code] method and finally using a heuristic based on the current scene and node's path in scene. If the [param object] is not a [Node] and no custom ID is provided, this method returns empty string.
func get_object_id(object: Object) -> String:
	if object.has_meta(&"object_id"):
		return object.get_meta(&"object_id")
	elif object.has_method(&"_get_object_id"):
		var id: String = object._get_object_id()
		object.set_meta(&"object_id", id)
		return id
	elif object is Node:
		var id := str(object.owner.scene_file_path.get_file().get_basename(), "/", object.get_parent().name if object.get_parent() != object.owner else ".", "/", object.name)
		object.set_meta(&"object_id", id)
		return id
	return ""

## Returns the map coordinates of an object on the scene. It can be used e.g. to place custom markers for non-storable objects.
## [br][br]Similar to [method get_object_id], the method will first use [code]object_coords[/code] metadata and [code]_get_object_coords()[/code] method. If the [param object] is a [Node], the top-left coordinate of the current scene's location on map will be used. If the object is a [CanvasItem], it will return a precise coordinate based on the object's position on the scene.
func get_object_coords(object: Object) -> Vector3i:
	if object.has_meta(&"object_coords"):
		return object.get_meta(&"object_coords")
	elif object.has_method(&"_get_object_coords"):
		var coords: Vector3i = object._get_object_coords()
		object.set_meta(&"object_coords", coords)
		return coords
	elif object is Node:
		var room_name: String = map_data.get_room_from_scene_path(object.owner.scene_file_path)
		
		var coords: Vector3i = map_data.assigned_scenes[room_name].front()
		for vec in map_data.assigned_scenes[room_name]:
			coords.x = mini(coords.x, vec.x)
			coords.y = mini(coords.y, vec.y)
		
		if object is CanvasItem:
			var position: Vector2 = object.position / settings.in_game_cell_size
			coords.x += int(position.x)
			coords.y += int(position.y)
		
		object.set_meta(&"object_coords", coords)
		return coords
	return Vector3i.MAX

## Translates map coordinates to 2D pixel coordinates. Can be used for custom drawing on the map.
## [br][br][param relative] allows to specify precise position inside the cell, with [code](0.5, 0.5)[/code] being the cell's center. [param base_offset] is an additional offset in pixels.
func get_cell_position(coords: Vector2i, relative := Vector2(0.5, 0.5), base_offset := Vector2()) -> Vector2:
	return base_offset + (Vector2(coords) + relative) * CELL_SIZE

## Returns a cell override at position [param coords]. If it doesn't exist, it will be created (unless [param auto_create] is [code]false[/code]). A cell must exist at the given [param coords].
## [br][br]Cell overrides allow to modify any cell's data at runtime. They are included with the data returned in [method get_save_data]. Creating an override and doing any modifications with emit [signal map_updated]. The signal emitted with modifications is deferred, i.e. multiple modifications will do only a single emission, at the end of the current frame.
## [br][br]Click this method's return value for more info.
func get_cell_override(coords: Vector3i, auto_create := true) -> MapData.CellOverride:
	var cell := map_data.get_cell_at(coords)
	assert(cell, "Can't override non-existent cell")
	
	var existing := cell.get_override()
	if existing:
		return existing
	elif auto_create:
		return save_data.add_cell_override(cell)
	else:
		push_error("No override found at %s" % coords)
		return null

## Returns an override for the first cell assigned to the given [param group_id]. The group ID must exist (i.e. have at least a single cell with it assigned).
## [br][br]Useful for applying override to a group.
func get_cell_override_from_group(group_id: int, auto_create := true) -> MapData.CellOverride:
	assert(group_id in map_data.cell_groups)
	return get_cell_override(map_data.cell_groups[group_id].front(), auto_create)

## Removes an override created with [method get_cell_override], reverting the cell to its original appearance, and emits [signal map_updated] signal. Does nothing if the override didn't exist.
## [br][br][b]Note:[/b] If the override was created with MapBuilder, use the [code]destroy()[/code] method instead.
func remove_cell_override(coords: Vector3i):
	var cell = map_data.get_cell_at(coords)
	assert(cell, "Can't remove override of non-existent cell")
	if save_data.remove_cell_override(cell):
		map_updated.emit()

## Returns a MapBuilder object. It can be used to create custom cells at runtime (for procedural maps etc.). The created cells can be customized with overrides, which are created automatically.
## [br][br]Click this method's return value for more info.
func get_map_builder() -> MapBuilder:
	return MapBuilder.new()

## Creates a [MapView] object that displays the specified area of the map. It's a low-level system to use if you find Minimap.tscn insufficient.
func make_map_view(parent_item: CanvasItem, begin: Vector2i, size: Vector2i, layer: int) -> MapView:
	var mv := MapView.new(parent_item.get_canvas_item())
	mv.begin = begin
	mv.size = size
	mv.layer = layer
	return mv

## Creates an instance of [member MapTheme.player_location_scene] and adds it as a child of the specified [param canvas_item]. The location scene will be moved to the player's location, respecting [member MapTheme.show_exact_player_location]. [param offset] is the offset in pixels for drawing the location. Use it if your map doesn't use [code](0, 0)[/code] as origin point.
## [br][br][b]Note:[/b] The scene automatically disables processing if it's not visible, so you don't need to worry about having animations and such. They will not run in the background.
func add_player_location(canvas_item: CanvasItem, offset := Vector2()) -> Node2D:
	var location_instance: Node2D = settings.theme.player_location_scene.instantiate()
	location_instance.set_script(load("res://addons/MetroidvaniaSystem/Scripts/PlayerLocationInstance.gd"))
	location_instance.offset = offset
	canvas_item.add_child(location_instance)
	return location_instance

## Returns the current cell coordinates of the player, as determined from [method set_player_position].
func get_current_coords() -> Vector3i:
	return Vector3i(last_player_position.x, last_player_position.y, current_layer)

## Same as [method get_current_coords], but does not include layer.
func get_current_flat_coords() -> Vector2i:
	return Vector2i(last_player_position.x, last_player_position.y)

## Returns the currently active RoomInstance object.
## [br][br]Click this method's return value for more info.
func get_current_room_instance() -> RoomInstance:
	if is_instance_valid(current_room):
		return current_room
	return null

## Returns the name of the current room, or empty string if there is no active RoomInstance. Use together with [method get_full_room_path] to get the full path.
func get_current_room_name() -> String:
	if current_room:
		return current_room.room_name
	else:
		return ""

## Returns the full path to the provided [param room_name] scene. This method assumes that the scene is inside the base map folder.
func get_full_room_path(room_name: String) -> String:
	return settings.map_root_folder.path_join(room_name)
