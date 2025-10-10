@tool
extends Resource

## The theme used for drawing map cells.
@export var theme: MapTheme:
	set(t):
		if t == theme:
			return
		
		theme = t
		theme_changed.emit()

@export_custom(PROPERTY_HINT_SAVE_FILE, "") var map_data_file: String = "res://MapData.txt":
	set(mdf):
		if map_data_file == mdf:
			return
		map_data_file = mdf
		map_data_file_changed.emit()

## Size of the map drawn in the editor, in both directions. Cells beyond this value on any side will not be drawn. Adjust this to your needs, but keep in mind that big values will cause editor slowdowns.
@export_range(50, 1000) var map_extents: int = 100

## Scene template file used when creating new scenes from editor's Assign Scene mode. If empty, a default scene with RoomInstance will be created.
@export_file("*.tscn", "*.scn") var scene_template: String

## The size of a map cell within an in-game room, i.e. this is the real game size of your map cells. Usually equal to the screen size.
@export var in_game_cell_size := Vector2(1152, 648)

## If [code]true[/code], when the player visits a new room, all its cells will be discovered at once.
@export var discover_whole_rooms := false

## If [code]true[/code], MetSys will cache a reverse map of cell groups, which allows for fast checking of assigned groups for a cell. This can take a while to initialize and takes memory, especially with bigger maps. You can disable it if you don't plan to use [method MetroidvaniaSystem.get_cell_groups].
@export var cache_group_reverse_lookup := true

## The script that determines the custom elements available in the Custom Elements map editor mode. It should inherit [code]CustomElementManager.gd[/code], refer to that class' documentation on how to use it.
@export var custom_element_script: Script:
	set(elements):
		if elements == custom_element_script:
			return
		
		custom_element_script = elements
		if elements:
			custom_elements = elements.new()
		else:
			custom_elements = null
		
		custom_elements_changed.emit()

@export_storage var _last_scene_folder: String
@export_storage var _collectible_list: Array[Dictionary]

var custom_elements: MetroidvaniaSystem.CustomElementManager
var _legacy_map_root: String

signal theme_changed
signal map_data_file_changed
signal custom_elements_changed

func get_scene_folder() -> String:
	if _last_scene_folder.is_empty():
		return MetSys.settings.map_data_file.get_base_dir()
	else:
		return MetSys.settings._last_scene_folder

# Compatibility

func _set(property: StringName, value: Variant) -> bool:
	if property == &"collectible_list":
		_collectible_list = value
		return true
	elif property == &"map_root_folder":
		var folder := value as String
		_legacy_map_root = folder
		map_data_file = folder.path_join("MapData.txt")
		return true
	
	return false
