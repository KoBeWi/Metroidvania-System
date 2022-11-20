@tool
extends Node

enum { R, D, L, U }
const FWD = {R: Vector2i.RIGHT, D: Vector2i.DOWN, L: Vector2i.LEFT, U: Vector2i.UP}
const VECTOR2INF = Vector2i(999999, 99999999)
const DEFAULT_SYMBOL = -99
enum { DISPLAY_CENTER = 1, DISPLAY_OUTLINE = 2, DISPLAY_BORDERS = 4, DISPLAY_SYMBOLS = 8 }

const MAP_HANDLER = preload("res://MetroidvaniaSystem/System/MapHandler.gd")
const SAVE_DATA = preload("res://MetroidvaniaSystem/System/SaveData.gd")

## TODO: plugin - minimapa (dialog, z otwieraniem scen?), wyświetlacz krawędzie
## TODO: shared borders - że są pośrodku między pomieszczeniami
## TODO: przerobić room_data i groupy itp na klasę RoomData i cały kod wczytywania itp dać tam
## TODO: validator? do sprawdzania czy wszystkie pomieszczenia mają przypisaną mapę itp
## TODO: add_main_symbol() - dodaje symbol i zawsze ma index 0

@export_dir var map_root_folder: String

@export var default_room_fill_color = Color.BLUE
@export var unexplored_room_fill_color = Color.GRAY
@export var default_room_separator_color = Color.GRAY
@export var default_room_wall_color = Color.WHITE

@export var room_fill_texture: Texture2D
@export var room_separator_texture: Texture2D
@export var room_wall_texture: Texture2D ## wersja wertykalna/horyzontalna? (dla prostokątnych pomieszczeń
@export var border_outer_corner_texture: Texture2D
@export var border_inner_corner_texture: Texture2D

@export_flags("Center", "Outline", "Borders", "Symbol") var unexplored_display := 3

@export var player_location_symbol: Texture2D
@export var player_location_scene: PackedScene ## tylko jedno ma się pokazywać
@export var uncollected_item_symbol := -1
@export var collected_item_symbol := -1
@export var map_borders: Array[Texture2D] ## każda ściana może mieć teksturę
@export var map_symbols: Array[Texture2D] ## można przypisywać 1 symbol do pomieszczeń

@export var in_game_room_size := Vector2(1152, 648)

@onready var ROOM_SIZE: Vector2i = room_fill_texture.get_size()

var map_data: Dictionary
var assigned_maps: Dictionary
var room_groups: Dictionary

var last_player_position := VECTOR2INF
var exact_player_position: Vector2
var current_map: MAP_HANDLER

var save_data := SAVE_DATA.new()

signal map_updated
signal room_changed(new_room: Vector2i)
signal map_changed(new_map: String)

func _init() -> void:
	assert(collected_item_symbol < map_symbols.size())
	assert(uncollected_item_symbol < map_symbols.size())

func _enter_tree() -> void:
	reload_data()

func _ready() -> void:
	set_physics_process(false)

func reload_data():
	var file := FileAccess.open(map_root_folder.path_join("MapData.txt"), FileAccess.READ)
	
	var data := file.get_as_text().split("\n")
	var i: int
	
	var is_in_groups := true
	while i < data.size():
		var line := data[i]
		if line.begins_with("["):
			is_in_groups = false
			line = line.trim_prefix("[").trim_suffix("]")
			
			var coords: Vector3i
			coords.x = line.get_slice(",", 0).to_int()
			coords.y = line.get_slice(",", 1).to_int()
			coords.z = line.get_slice(",", 2).to_int()
			
			i += 1
			line = data[i]
			
			var room_data := {borders = [-1, -1, -1, -1]}
			for j in 4:
				room_data.borders[j] = line.get_slice(",", j).to_int()
			
			var assigned_map := line.get_slice("|", 1)
			if not assigned_map.is_empty():
				assigned_maps[assigned_map] = [coords]
				room_data.assigned_map = assigned_map
			
			map_data[coords] = room_data
		elif is_in_groups:
			var group_data := data[i].split(":")
			var group_id := group_data[0].to_int()
			var rooms: Array
			for j in range(1, group_data.size()):
				var coords: Vector3i
				coords.x = group_data[j].get_slice(",", 0).to_int()
				coords.y = group_data[j].get_slice(",", 1).to_int()
				coords.z = group_data[j].get_slice(",", 2).to_int()
				rooms.append(coords)
			
			room_groups[group_id] = rooms
		
		i += 1
	
	for map in assigned_maps.keys():
		var rooms: Array[Vector3i] = assigned_maps[map]
		assigned_maps[map] = _get_whole_room(rooms[0])

func get_save_data() -> Dictionary:
	return {} ## odkryte pokoje i umiejętności?

func set_save_data(data: Dictionary):
	pass ## do wczytywania

func set_player_position(position: Vector2):
	exact_player_position = position
	
	var player_pos := Vector2i((position / in_game_room_size).floor()) + current_map.min_room
	if player_pos != last_player_position:
		visit_room(Vector3i(player_pos.x, player_pos.y, 0))
		room_changed.emit(player_pos)
		last_player_position = player_pos

func register_storable_object(object: Object, map_symbol := DEFAULT_SYMBOL, stored_callback := Callable()):
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
		var map_name: String = object.owner.scene_file_path.trim_prefix(MetSys.map_root_folder)
		assert(map_name in assigned_maps)
		var coords: Vector3i = assigned_maps[map_name].front()
		for vec in assigned_maps[map_name]:
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
	
	var previous_map: String = map_data.get(Vector3i(last_player_position.x, last_player_position.y, 0), {}).get("assigned_map", "")
	var current_map: String = map_data.get(room, {}).get("assigned_map", "")
	if not current_map.is_empty() and not previous_map.is_empty() and current_map != previous_map:
		map_changed.emit(map_data[room].assigned_map)
	## tu odkrywanie i sygnał teleportacji

## w edytorze map: można rysować prostokąty, trochę jak w trackmanii się łączą (że kwadraty obok siebie mają ściany, ale jak się przeciągnie prostokąt między nimi to są 1 pomieszczenie)
## można klikać ściany, żeby edytować

func discover_secret_passage(gdzie):
	pass ## usuwa ścianę?

func draw_map_square(canvas_item: CanvasItem, offset: Vector2i, room: Vector3i, use_save_data := false):
	var room_data: Dictionary = map_data.get(room, {})
	if room_data.is_empty():
		return
	
	var discovered := 2
	if use_save_data:
		discovered = save_data.is_room_discovered(room)
	
	if discovered == 0:
		return
	
	var ci := canvas_item.get_canvas_item()
	var display_flags := (int(discovered == 2) * 255) | unexplored_display
	
	if bool(display_flags & DISPLAY_CENTER):
		room_fill_texture.draw(ci, offset * ROOM_SIZE, default_room_fill_color if discovered == 2 else unexplored_room_fill_color)
	
	var borders: Array[int] = room_data["borders"]
	for i in 4:
		var border: int = room_data["borders"][i]
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
			texture = room_separator_texture
			color = default_room_separator_color
		else:
			var border: int = borders[i]
			assert(borders[i] < map_borders.size())
			
			if not bool(display_flags & DISPLAY_BORDERS):
				border = 0
			
			texture = map_borders[border]
			color = default_room_wall_color
		
		if not texture:
			continue
		
		canvas_item.draw_set_transform(offset * ROOM_SIZE + ROOM_SIZE / 2, PI * 0.5 * i, Vector2.ONE)
		texture.draw(ci, -ROOM_SIZE / 2, color)
	
	for i in 4:
		var j: int = (i + 1) % 4
		if borders[i] == -1 or borders[j] == -1:
			continue
		
		canvas_item.draw_set_transform(offset * ROOM_SIZE + ROOM_SIZE / 2, PI * 0.5 * i, Vector2.ONE)
		border_outer_corner_texture.draw(ci, -ROOM_SIZE / 2)
	
	canvas_item.draw_set_transform_matrix(Transform2D())
	
	if bool(display_flags & DISPLAY_SYMBOLS) and room in save_data.room_symbols:
		var symbol: int = save_data.room_symbols[room].back()
		assert(symbol < map_symbols.size())
		canvas_item.draw_texture(map_symbols[symbol], offset * ROOM_SIZE)

func draw_player_location(canvas_item: CanvasItem, offset: Vector2i, exact := false):
	var player_position: Vector2 = (last_player_position + offset) * ROOM_SIZE
	if exact:
		player_position += (exact_player_position / in_game_room_size).posmod(1) * Vector2(ROOM_SIZE) - player_location_symbol.get_size() * 0.5
	
	canvas_item.draw_texture(player_location_symbol, player_position)

func _get_whole_room(at: Vector3i) -> Array[Vector3i]:
	var room: Array[Vector3i]
	
	var to_check: Array[Vector2i] = [Vector2i(at.x, at.y)]
	var checked: Array[Vector2i]
	
	while not to_check.is_empty():
		var p: Vector2i = to_check.pop_back()
		checked.append(p)
		
		var coord := Vector3i(p.x, p.y, at.z)
		if coord in map_data:
			room.append(coord)
			for i in 4:
				if map_data[coord].borders[i] == -1:
					var p2: Vector2i = p + FWD[i]
					if not p2 in to_check and not p2 in checked:
						to_check.append(p2)
	
	return room

func discover_room_group(group_id: int):
	assert(group_id in room_groups)
	
	for room in room_groups[group_id]:
		save_data.discover_room(room)
	
	MetSys.map_updated.emit()

func reset_save_data():
	save_data = SAVE_DATA.new()
