@tool
class_name MetroidvaniaSystem extends Node

const VECTOR2INF = Vector2i(999999, 99999999)
const DEFAULT_SYMBOL = -99
enum { DISPLAY_CENTER = 1, DISPLAY_OUTLINE = 2, DISPLAY_BORDERS = 4, DISPLAY_SYMBOLS = 8 }

const MapHandler = preload("res://MetroidvaniaSystem/System/MapHandler.gd")
const SaveData = preload("res://MetroidvaniaSystem/System/SaveData.gd")
const MapData = preload("res://MetroidvaniaSystem/System/MapData.gd")

## TODO: plugin - minimapa (dialog, z otwieraniem scen?), wyświetlacz krawędzie
## TODO: shared borders - że są pośrodku między pomieszczeniami
## TODO: przerobić room_data i groupy itp na klasę RoomData i cały kod wczytywania itp dać tam
## TODO: validator? do sprawdzania czy wszystkie pomieszczenia mają przypisaną mapę itp
## TODO: add_main_symbol() - dodaje symbol i zawsze ma index 0 / ???
## TODO: ujednolicić coords (nazwy zmiennych)
## TODO: layout - wyświetlać rozmiar rysowanego pomieszczenia
## TODO: metody do tworzenia pomieszczeń ze skryptu??
## TODO: drag żeby utworzyć drzwi po drugiej stronie

@export var theme: MapTheme
@export_dir var map_root_folder: String

@export_flags("Center", "Outline", "Borders", "Symbol") var unexplored_display := 3

@export var uncollected_item_symbol := -1
@export var collected_item_symbol := -1
@export var map_borders: Array[Texture2D] ## każda ściana może mieć teksturę
@export var map_symbols: Array[Texture2D] ## można przypisywać 1 symbol do pomieszczeń

@export var in_game_room_size := Vector2(1152, 648)

@onready var ROOM_SIZE: Vector2i = theme.room_fill_texture.get_size()

var map_data: MapData
var save_data := SaveData.new() ## po co to new?

var last_player_position := VECTOR2INF
var exact_player_position: Vector2
var player_location_instance: Node2D
var current_map: MapHandler

signal map_updated
signal room_changed(new_room: Vector2i)
signal map_changed(new_map: String)

func _init() -> void:
	assert(collected_item_symbol < map_symbols.size())
	assert(uncollected_item_symbol < map_symbols.size())

func _enter_tree() -> void:
	map_data = MapData.new()
	map_data.load_data()

func _ready() -> void:
	set_physics_process(false)

func get_save_data() -> Dictionary:
	return {} ## odkryte pokoje i umiejętności?

func set_save_data(data: Dictionary):
	pass ## do wczytywania

func reset_save_data():
	save_data = SaveData.new()

func set_player_position(position: Vector2):
	exact_player_position = position
	
	var player_pos := Vector2i((position / in_game_room_size).floor()) + current_map.min_room
	if player_pos != last_player_position:
		visit_room(Vector3i(player_pos.x, player_pos.y, 0))
		room_changed.emit(player_pos)
		last_player_position = player_pos

func register_storable_object(object: Object, stored_callback := Callable(), map_symbol := DEFAULT_SYMBOL):
	if stored_callback.is_null():
		if object is Node:
			stored_callback = Callable(object, &"queue_free")
		elif not object is RefCounted:
			stored_callback = Callable(object, &"free")
	
	if save_data.is_object_stored(object):
		stored_callback.call()
	else:
		if map_symbol == DEFAULT_SYMBOL:
			map_symbol = uncollected_item_symbol
		
		if save_data.register_storable_object(object) and map_symbol > -1:
			object.set_meta(&"map_symbol", map_symbol)
			save_data.add_room_symbol(get_object_coords(object), map_symbol)

func store_object(object: Object, map_symbol := DEFAULT_SYMBOL):
	save_data.store_object(object)
	if object.has_meta(&"map_symbol"):
		save_data.remove_room_symbol(get_object_coords(object), object.get_meta(&"map_symbol"))
	
	if map_symbol == DEFAULT_SYMBOL:
		map_symbol = collected_item_symbol
	
	if map_symbol > -1:
		save_data.add_room_symbol(get_object_coords(object), map_symbol)

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
		var map_name: String = object.owner.scene_file_path.trim_prefix(map_root_folder)
		assert(map_name in map_data.assigned_maps)
		var coords: Vector3i = map_data.assigned_maps[map_name].front()
		for vec in map_data.assigned_maps[map_name]:
			coords.x = mini(coords.x, vec.x)
			coords.y = mini(coords.y, vec.y)
		
		if object is CanvasItem:
			var position: Vector2 = object.position / in_game_room_size
			coords.x += int(position.x)
			coords.y += int(position.y)
		
		object.set_meta(&"object_coords", coords)
		return coords
	return Vector3i()

func visit_room(room: Vector3i):
	save_data.explore_room(room)
	
	var previous_map := map_data.get_assigned_map_at(Vector3i(last_player_position.x, last_player_position.y, 0))
	var new_map := map_data.get_assigned_map_at(room)
	if not new_map.is_empty() and not previous_map.is_empty() and new_map != previous_map:
		map_changed.emit(new_map)

func discover_secret_passage(gdzie):
	pass ## usuwa ścianę?
	## nazwa: override border
	## i druga taka metoda do symboli?

func draw_map_square(canvas_item: CanvasItem, offset: Vector2i, coords: Vector3i, use_save_data := false):
	var room_data := map_data.get_room_at(coords)
	if not room_data:
		return
	
	var discovered := 2
	if use_save_data:
		discovered = save_data.is_room_discovered(coords)
	
	if discovered == 0:
		return
	
	var ci := canvas_item.get_canvas_item()
	var display_flags := (int(discovered == 2) * 255) | unexplored_display
	
	if bool(display_flags & DISPLAY_CENTER):
		var room_color = room_data.color if room_data.color.a > 0 else theme.default_room_fill_color
		theme.room_fill_texture.draw(ci, offset * ROOM_SIZE, room_color if discovered == 2 else theme.unexplored_room_fill_color)
	
	var borders: Array[int] = [-1, -1, -1, -1]
	for i in 4:
		var border: int = room_data.borders[i]
		if not bool(display_flags & DISPLAY_OUTLINE) and border == 0:
			borders[i] = -1
		elif not bool(display_flags & DISPLAY_BORDERS):
			borders[i] = mini(border, 0)
		else:
			borders[i] = border
	
	for i in 4:
		var texture: Texture2D
		var color: Color
		
		if borders[i] == -1:
			texture = theme.room_separator_texture
			color = theme.default_room_separator_color
		else:
			var border: int = borders[i]
			assert(borders[i] < map_borders.size())
			
			if not bool(display_flags & DISPLAY_BORDERS):
				border = 0
			
			if border == 0:
				texture = theme.room_wall_texture
			elif border == 1:
				texture = theme.room_passage_texture
			else:
				texture = map_borders[border - 1]
			
			color = room_data.get_border_color(i)
		
		if not texture:
			continue
		
		canvas_item.draw_set_transform(offset * ROOM_SIZE + ROOM_SIZE / 2, PI * 0.5 * i, Vector2.ONE)
		texture.draw(ci, -ROOM_SIZE / 2, color)
	
	for i in 4:
		var j: int = (i + 1) % 4
		if borders[i] == -1 or borders[j] == -1:
			continue
		
		var corner_color = room_data.get_border_color(i).lerp(room_data.get_border_color(j), 0.5)
		
		canvas_item.draw_set_transform(offset * ROOM_SIZE + ROOM_SIZE / 2, PI * 0.5 * i, Vector2.ONE)
		theme.border_outer_corner_texture.draw(ci, -ROOM_SIZE / 2, corner_color)
	
	for i in 4:
		var j: int = (i + 1) % 4
		if borders[i] != -1 or borders[j] != -1:
			continue
		
		var neighbor: Vector2i = Vector2i(coords.x, coords.y) + map_data.FWD[i] + map_data.FWD[j]
		var neighbor_room := map_data.get_room_at(Vector3i(neighbor.x, neighbor.y, coords.z))
		if neighbor_room:
			if neighbor_room.borders[(i + 2) % 4] == -1 and neighbor_room.borders[(j + 2) % 4] == -1:
				continue
		
		var corner_color = room_data.get_border_color(i).lerp(room_data.get_border_color(j), 0.5)
		
		canvas_item.draw_set_transform(offset * ROOM_SIZE + ROOM_SIZE / 2, PI * 0.5 * i, Vector2.ONE)
		theme.border_inner_corner_texture.draw(ci, -ROOM_SIZE / 2, corner_color)
	
	canvas_item.draw_set_transform_matrix(Transform2D())
	
	if bool(display_flags & DISPLAY_SYMBOLS):
		var symbol: int = -1
		
		if coords in save_data.room_symbols:
			symbol = save_data.room_symbols[coords].back()
		
		if symbol == -1:
			symbol = room_data.symbol
		
		if symbol > - 1:
			assert(symbol < map_symbols.size())
			canvas_item.draw_texture(map_symbols[symbol], offset * ROOM_SIZE)

func draw_player_location(canvas_item: CanvasItem, offset: Vector2i, exact := false):
	var player_position: Vector2 = (last_player_position + offset) * ROOM_SIZE + ROOM_SIZE / 2
	if exact:
		player_position += (exact_player_position / in_game_room_size).posmod(1) * Vector2(ROOM_SIZE) - ROOM_SIZE * 0.5
	
	if not is_instance_valid(player_location_instance):
		player_location_instance = theme.player_location_scene.instantiate()
	
	if player_location_instance.get_parent() != canvas_item:
		if player_location_instance.get_parent():
			player_location_instance.get_parent().remove_child(player_location_instance)
		canvas_item.add_child(player_location_instance)
	
	player_location_instance.position = player_position

func discover_room_group(group_id: int):
	assert(group_id in map_data.room_groups)
	
	for room in map_data.room_groups[group_id]:
		save_data.discover_room(room)
	
	map_updated.emit()
