extends Node

const MetSysModule = preload("res://Template/MetSysModule.gd")

var player: Node2D
var map: Node2D

var modules: Array[MetSysModule]

signal room_loaded

func set_player(p_player: Node2D):
	player = p_player
	player.get_tree().physics_frame.connect(physics_tick, CONNECT_DEFERRED)

func add_module(module_script: Script):
	var module: MetSysModule = module_script.new(self)
	modules.append(module)

func physics_tick():
	MetSys.set_player_position(player.position)

func load_room(path: String):
	if not path.is_absolute_path():
		path = MetSys.get_full_room_path(path)
	
	if map:
		map.queue_free()
		await map.tree_exited
		map = null
	
	map = load(path).instantiate()
	add_child(map)
	
	MetSys.current_layer = MetSys.get_current_room_instance().get_layer()
	room_loaded.emit()
