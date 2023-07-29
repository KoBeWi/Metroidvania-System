extends Node2D
class_name Game

@export var starting_map: String

@onready var player: CharacterBody2D = $Player

var map: Node2D

var collectibles: int:
	set(count):
		collectibles = count
		%CollectibleCount.text = str(count)

var generated_rooms: Array[Vector3i]
var events: Array[String]

func _ready() -> void:
	if FileAccess.file_exists("user://save_data.sav"):
		var save_data: Dictionary = FileAccess.open("user://save_data.sav", FileAccess.READ).get_var()
		MetSys.set_save_data(save_data)
		collectibles = save_data.collectible_count
		generated_rooms.assign(save_data.generated_rooms)
		events.assign(save_data.events)
		starting_map = save_data.current_room
	else:
		MetSys.set_save_data()
	
	goto_map(MetSys.get_full_room_path(starting_map))
	var start := map.get_node_or_null(^"SavePoint")
	if start:
		player.position = start.position
	MetSys.map_changed.connect(on_map_changed, CONNECT_DEFERRED)
	
	get_script().set_meta(&"singleton", self)

func goto_map(map_path: String):
	var prev_map_position: Vector2i = MetSys.VECTOR2INF
	if map:
		prev_map_position = MetSys.get_current_room_instance().min_room
		map.queue_free()
		map = null
	
	map = load(map_path).instantiate()
	add_child(map)
	MetSys.get_current_room_instance().adjust_camera_limits($Player/Camera2D)
	
	MetSys.current_layer = MetSys.get_current_room_instance().layer
	
	if prev_map_position != MetSys.VECTOR2INF:
		player.position -= Vector2(MetSys.get_current_room_instance().min_room - prev_map_position) * MetSys.settings.in_game_CELL_SIZE
		player.on_enter()

func _physics_process(delta: float) -> void:
	MetSys.set_player_position(player.position)

func on_map_changed(target_map: String):
	if target_map.is_absolute_path():
		goto_map(target_map)
	else:
		goto_map(MetSys.settings.map_root_folder.path_join(target_map))

static func get_singleton() -> Game:
	return (Game as Script).get_meta(&"singleton") as Game

func get_save_data() -> Dictionary:
	return {
		"collectible_count": collectibles,
		"generated_rooms": generated_rooms,
		"events": events,
		"current_room": MetSys.get_current_room_name(),
	}
