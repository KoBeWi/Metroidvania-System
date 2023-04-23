extends Node2D
class_name Game

@export var starting_map: String

@onready var player: CharacterBody2D = $Player

var map: Node2D

var collectibles: int:
	set(count):
		collectibles = count
		%CollectibleCount.text = str(count)

func _ready() -> void:
	if FileAccess.file_exists("user://save_data.sav"):
		var save_data: Dictionary = FileAccess.open("user://save_data.sav", FileAccess.READ).get_var()
		MetSys.set_save_data(save_data)
		collectibles = save_data.collectible_count
	
	goto_map(starting_map)
	var start := map.get_node_or_null(^"StartPoint")
	if start:
		player.position = start.position
	MetSys.map_changed.connect(on_map_changed, CONNECT_DEFERRED)
	
	get_script().set_meta(&"singleton", self)

func goto_map(map_path: String):
	var prev_map_position: Vector2i = MetSys.VECTOR2INF
	if map:
		prev_map_position = map.get_node(^"MapHandler").min_room
		map.queue_free()
		map = null
	
	map = load(map_path).instantiate()
	add_child(map)
	map.get_node(^"MapHandler").adjust_camera_limits($Player/Camera2D)
	
	MetSys.current_layer = map.get_node(^"MapHandler").layer
	
	if prev_map_position != MetSys.VECTOR2INF:
		player.position -= Vector2(map.get_node(^"MapHandler").min_room - prev_map_position) * MetSys.settings.in_game_room_size
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
