extends Node2D

@export var starting_map: String

@onready var player = $Player

var map: Node2D

func _ready() -> void:
	if FileAccess.file_exists("user://save_data.sav"):
		MetSys.set_save_data(FileAccess.open("user://save_data.sav", FileAccess.READ).get_var())
	
	goto_map(starting_map)
	MetSys.map_changed.connect(on_map_changed, CONNECT_DEFERRED)

func goto_map(map_name: String):
	var prev_map_position: Vector2i = MetSys.VECTOR2INF
	if map:
		prev_map_position = map.get_node(^"MapHandler").min_room
		map.queue_free()
		map = null
	
	map = load("res://SampleProject/Maps/%s.tscn" % map_name).instantiate()
	add_child(map)
	map.get_node(^"MapHandler").adjust_camera($Player/Camera2D)
	
	if prev_map_position != MetSys.VECTOR2INF:
		player.position -= Vector2(map.get_node(^"MapHandler").min_room - prev_map_position) * MetSys.settings.in_game_room_size

func _physics_process(delta: float) -> void:
	MetSys.set_player_position(player.position)

func on_map_changed(target_map: String):
	goto_map(target_map.get_file().get_basename())
