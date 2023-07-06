@tool
class_name MetroidvaniaSystem extends Node

const VECTOR2INF = Vector2i(999999, 99999999)
const VECTOR3INF = Vector3i(999999, 99999999, 99999999)
const DEFAULT_SYMBOL = -99
enum { DISPLAY_CENTER = 1, DISPLAY_OUTLINE = 2, DISPLAY_BORDERS = 4, DISPLAY_SYMBOLS = 8 }

const Settings = preload("res://addons/MetroidvaniaSystem/Scripts/Settings.gd")
const SaveData = preload("res://addons/MetroidvaniaSystem/Scripts/SaveData.gd")
const MapData = preload("res://addons/MetroidvaniaSystem/Scripts/MapData.gd")
const MapBuilder = preload("res://addons/MetroidvaniaSystem/Scripts/MapBuilder.gd")
const MapHandler = preload("res://addons/MetroidvaniaSystem/Scripts/MapHandler.gd")
const RoomDrawer = preload("res://addons/MetroidvaniaSystem/Scripts/RoomDrawer.gd")

enum { R, D, L, U }

## TODO: validator? do sprawdzania czy wszystkie pomieszczenia mają przypisaną mapę itp
## TODO: walidator motywów (czy rozmiary się zgadzają itp
## TODO: pos to map (do rysowania po mapie, x,y pomieszczenia, ratio wewnątrz np (32, 4, 0.1, 0.1))
## TODO: methoda add_custom_element(name, callable), potrzeba customowy skrypt dziedziczący jakiś typ, wstawić go w pole w MetSys i jest robiona instancja i wywoływane metody. Callback: element_callback(canvas_item, coords, top_left), np. add_custom_element(:"elevator", draw_elevator); func draw_elevator(...): canvas_item.draw_rect(top_left)
## TODO: w motywach pododawać player sceny, symbole i granice
## TODO: przerysowaywać scenę jak się zmieni assign
## TODO: dużo rzeczy w preview i edytorze się powtarza -> ujednolicić do MapView?
## TODO: wybór bordera z listy
## TODO: onion wyświetlanie hovered itemów (opcja)
## TODO: do szukania: wymyślić jakoś jak wyświetlać różne ikonki w zależności od danych
## TODO: summary: wypisywać ilość dla każdego rodzaju
## TODO: handler może się rejestrować dla aktualnej scene (owner.set_meta(&"handler")) // jest, tylko trzeba lepszą nazwę
## TODO: ujednolicić Editor i Viewer. Dać pasek z boku w obu, grubszy

@export var exported_settings: Resource

var settings: Settings
var ROOM_SIZE: Vector2

var map_data: MapData
var save_data: SaveData

var last_player_position := VECTOR3INF
var exact_player_position: Vector2
var player_location_instance: Node2D
var current_map: MapHandler

var current_layer: int:
	set(layer):
		if layer == current_layer:
			return
		
		current_layer = layer
		map_updated.emit()

signal map_updated
signal room_changed(new_room: Vector2i)
signal map_changed(new_map: String)

func _enter_tree() -> void:
	settings = exported_settings
	_update_theme()
	
	map_data = MapData.new()
	map_data.load_data()

func _update_theme():
	ROOM_SIZE = settings.theme.center_texture.get_size()
	map_updated.emit()

func _ready() -> void:
	set_physics_process(false)

func get_save_data() -> Dictionary:
	return save_data.get_data()

func set_save_data(data := {}):
	save_data = SaveData.new()
	save_data.set_data(data)

func reset_save_data():
	save_data = SaveData.new()

func set_player_position(position: Vector2):
	exact_player_position = position
	
	var player_pos := Vector2i((position / settings.in_game_room_size).floor()) + current_map.min_room
	var player_pos_3d := Vector3i(player_pos.x, player_pos.y, current_layer)
	if player_pos_3d != last_player_position:
		visit_room(Vector3i(player_pos.x, player_pos.y, current_layer))
		room_changed.emit(player_pos)
		last_player_position = player_pos_3d

func add_custom_marker(coords: Vector3i, symbol: int):
	assert(symbol >= 0 and symbol < mini(MetSys.settings.theme.symbols.size(), 63))
	save_data.add_custom_marker(coords, symbol)

func remove_custom_marker(coords: Vector3i, symbol: int):
	save_data.remove_custom_marker(coords, symbol)

func register_storable_object_with_marker(object: Object, stored_callback := Callable(), map_marker := DEFAULT_SYMBOL):
	if stored_callback.is_null():
		if object is Node:
			stored_callback = Callable(object, &"queue_free")
		elif not object is RefCounted:
			stored_callback = Callable(object, &"free")
	
	if save_data.is_object_stored(object):
		stored_callback.call()
	else:
		if map_marker == DEFAULT_SYMBOL:
			map_marker = settings.theme.uncollected_item_symbol
		
		if map_marker > -1:
			object.set_meta(&"map_marker", map_marker)
		
		if save_data.register_storable_object(object) and map_marker > -1:
			save_data.add_custom_marker(get_object_coords(object), map_marker)

func register_storable_object(object: Object, stored_callback := Callable()):
	register_storable_object_with_marker(object, stored_callback, -1)

func store_object(object: Object, map_marker := DEFAULT_SYMBOL):
	save_data.store_object(object)
	if object.has_meta(&"map_marker"):
		save_data.remove_custom_marker(get_object_coords(object), object.get_meta(&"map_marker"))
	
	if map_marker == DEFAULT_SYMBOL:
		map_marker = settings.theme.collected_item_symbol
	
	if map_marker > -1:
		save_data.add_custom_marker(get_object_coords(object), map_marker)

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

func get_object_coords(object: Object) -> Vector3i:
	if object.has_meta(&"object_coords"):
		return object.get_meta(&"object_coords")
	elif object.has_method(&"_get_object_coords"):
		var coords: Vector3i = object._get_object_coords()
		object.set_meta(&"object_coords", coords)
		return coords
	elif object is Node:
		var map_name: String = object.owner.scene_file_path.trim_prefix(settings.map_root_folder)
		map_name = MetSys.map_data.map_overrides.get(map_name, map_name)
		assert(map_name in map_data.assigned_maps)
		
		var coords: Vector3i = map_data.assigned_maps[map_name].front()
		for vec in map_data.assigned_maps[map_name]:
			coords.x = mini(coords.x, vec.x)
			coords.y = mini(coords.y, vec.y)
		
		if object is CanvasItem:
			var position: Vector2 = object.position / settings.in_game_room_size
			coords.x += int(position.x)
			coords.y += int(position.y)
		
		object.set_meta(&"object_coords", coords)
		return coords
	return Vector3i()

func visit_room(room: Vector3i):
	save_data.explore_room(room)
	
	var previous_map := map_data.get_assigned_map_at(Vector3i(last_player_position.x, last_player_position.y, current_layer))
	var new_map := map_data.get_assigned_map_at(room)
	if not new_map.is_empty() and not previous_map.is_empty() and new_map != previous_map:
		map_changed.emit(new_map)

func get_room_override(coords: Vector3i, auto_create := true) -> MapData.RoomOverride:
	var room := map_data.get_room_at(coords)
	assert(room, "Can't override non-existent room")
	
	var existing := room.get_override()
	if existing:
		return existing
	elif auto_create:
		return save_data.add_room_override(room)
	else:
		push_error("No override found at %s" % coords)
		return null

func remove_room_override(coords: Vector3i):
	var room = MetSys.map_data.get_room_at(coords)
	assert(room, "Can't remove override of non-existent room")
	if save_data.remove_room_override(room):
		map_updated.emit()

func get_current_coords() -> Vector3i:
	return Vector3i(last_player_position.x, last_player_position.y, current_layer)

func get_current_map() -> MapHandler:
	if is_instance_valid(current_map):
		return current_map
	return null

func draw_map_square(canvas_item: CanvasItem, offset: Vector2, coords: Vector3i, use_save_data := false):
	RoomDrawer.draw(canvas_item, offset, coords, map_data, save_data if use_save_data else null)

func draw_player_location(canvas_item: CanvasItem, offset: Vector2, exact := false):
	var last_player_position_2d := Vector2(last_player_position.x, last_player_position.y)
	var player_position := (last_player_position_2d + offset) * ROOM_SIZE + ROOM_SIZE / 2
	if exact:
		player_position += (exact_player_position / settings.in_game_room_size).posmod(1) * ROOM_SIZE - ROOM_SIZE * 0.5
	
	if not is_instance_valid(player_location_instance):
		player_location_instance = settings.theme.player_location_scene.instantiate()
	
	if player_location_instance.get_parent() != canvas_item:
		if player_location_instance.get_parent():
			player_location_instance.get_parent().remove_child(player_location_instance)
		canvas_item.add_child(player_location_instance)
	
	player_location_instance.position = player_position

func discover_room_group(group_id: int):
	assert(group_id in map_data.room_groups)
	
	for coords in map_data.room_groups[group_id]:
		save_data.discover_room(coords)
	
	map_updated.emit()

func get_map_builder() -> MapBuilder:
	return MapBuilder.new()
