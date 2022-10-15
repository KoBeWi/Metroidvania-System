@tool
extends Node

enum { R, D, L, U }
const FWD = {R: Vector2i.RIGHT, D: Vector2i.DOWN, L: Vector2i.LEFT, U: Vector2i.UP}
const VECTOR2INF = Vector2i(999999, 99999999)

const MAP_HANDLER = preload("res://MetroidvaniaSystem/System/MapHandler.gd")

## TODO: plugin - minimapa (dialog, z otwieraniem scen?), wyświetlacz krawędzie
## TODO: przypisania scen do pomieszczeń i na tej podstawie krawędzie
## TODO: mapowanie: discovered level. 0 = nieodkryty, 1 = mapa (discovered), 2 = odkryty (explored)
## TODO: mapowanie: jak tylko mapowany, to opcje: wyświetlaj krawędzie, wyświetlaj symbole itp, kolor nieodkrytego
## TODO: shared borders - że są pośrodku między pomieszczeniami
## TODO: room groups - do map (itemów)
## TODO: sposób wyświetlania ścian w nieodkrytych (mapowanych) pomieszczeniach: brak, bez przejść, wszystko
## TODO: map root, żeby nie były takie długie nazwy / albo ID używać
## TODO: zmienić na MetSys??

@export_dir var map_root_folder: String

@export var show_collected_items_on_map: bool ## zamiast tego sprawdzać, czy jest tekstura
@export var show_uncollected_items_on_map: bool
@export var display_exact_player_position: bool

@export var default_room_fill_color = Color.BLUE
@export var default_room_separator_color = Color.GRAY
@export var default_room_wall_color = Color.WHITE

@export var room_fill_texture: Texture2D
@export var room_separator_texture: Texture2D
@export var room_wall_texture: Texture2D ## wersja wertykalna/horyzontalna? (dla prostokątnych pomieszczeń
@export var room_passage_texture: Texture2D
@export var border_outer_corner_texture: Texture2D
@export var border_inner_corner_texture: Texture2D

@export var player_location_symbol: Texture2D
@export var player_location_scene: PackedScene ## tylko jedno ma się pokazywać
@export var collected_item_symbol: Texture2D
@export var uncollected_item_symbol: Texture2D
@export var map_borders: Array[Texture2D] ## każda ściana może mieć teksturę
@export var map_symbols: Array[Texture2D] ## można przypisywać 1 symbol do pomieszczeń

@export var in_game_room_size := Vector2(1152, 648)

@onready var ROOM_SIZE: Vector2i = room_fill_texture.get_size()

var map_data: Dictionary
var assigned_maps: Dictionary

var last_player_position := VECTOR2INF
var current_map: MAP_HANDLER

signal map_changed(new_map: String)

func _enter_tree() -> void:
	reload_data()

func _ready() -> void:
	set_physics_process(false)

func reload_data():
	var file := FileAccess.open(map_root_folder.path_join("MapData.txt"), FileAccess.READ)
	
	var data := file.get_as_text().split("\n")
	var i: int
	
	while i < data.size():
		var line := data[i]
		if line.begins_with("["):
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
		
		i += 1
	
	for map in assigned_maps.keys():
		var rooms: Array[Vector3i] = assigned_maps[map]
		assigned_maps[map] = _get_whole_room(rooms[0])

func get_save_data() -> Dictionary:
	return {} ## odkryte pokoje i umiejętności?

func set_save_data(data: Dictionary):
	pass ## do wczytywania

func set_player_position(position: Vector2):
	var player_pos := Vector2i((position / in_game_room_size).floor()) + current_map.min_room
	if player_pos != last_player_position:
		visit_room(Vector3i(player_pos.x, player_pos.y, 0)) ## TODO
	
	last_player_position = player_pos
	## tutaj mapuje to na koordynaty mapy i automatycznie odkrywa, zmienia scenę (albo wysyła sygnał) itp

## format mapy: automatyczne wykrywanie całych pomieszczeń na podstawie ścian
## przypisywanie scen do map

func register_storable_object(object: Object, stored_callback := Callable()):
	if stored_callback.is_null():
		if object is Node:
			stored_callback = Callable(object, &"queue_free")
	
	## stuff

func mark_object_on_map(object: Object):
	pass

func store_object(object: Object):
	pass ## zapisuje, że jest

func visit_room(room: Vector3i):
	var previous_map: String = map_data.get(Vector3i(last_player_position.x, last_player_position.y, 0), {}).get("assigned_map", "")
	var current_map: String = map_data.get(room, {}).get("assigned_map", "")
	if not current_map.is_empty() and not previous_map.is_empty() and current_map != previous_map:
		map_changed.emit(map_data[room].assigned_map)
	## tu odkrywanie i sygnał teleportacji

## w edytorze map: można rysować prostokąty, trochę jak w trackmanii się łączą (że kwadraty obok siebie mają ściany, ale jak się przeciągnie prostokąt między nimi to są 1 pomieszczenie)
## można klikać ściany, żeby edytować

func discover_secret_passage(gdzie):
	pass ## usuwa ścianę?

func draw_map_square(canvas_item: CanvasItem, offset: Vector2i, room: Vector3i):
	var room_data: Dictionary = map_data.get(room, {})
	if room_data.is_empty():
		return
	
	var ci := canvas_item.get_canvas_item()
	
	canvas_item.draw_set_transform_matrix(Transform2D())
	room_fill_texture.draw(ci, offset * ROOM_SIZE, default_room_fill_color)
	
	var borders: Array[int] = room_data["borders"]
	for i in 4:
		var texture: Texture2D
		var color: Color
		
		if borders[i] == -1:
			texture = room_separator_texture
			color = default_room_separator_color
		else:
			assert(borders[i] < map_borders.size())
			texture = map_borders[borders[i]]
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
					var p2: Vector2i = p + MetroidvaniaSystem.FWD[i]
					if not p2 in to_check and not p2 in checked:
						to_check.append(p2)
	
	return room
