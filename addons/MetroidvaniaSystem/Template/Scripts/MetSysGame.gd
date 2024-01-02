## Class designed for use in main game scenes.
##
## MetSysGame is responsible for map management and player tracking. You can extend it by adding MetSysModules.
extends Node

const MetSysModule = preload("res://addons/MetroidvaniaSystem/Template/Scripts/MetSysModule.gd")

var player: Node2D
var map: Node2D

var modules: Array[MetSysModule]

## Emitted when [method load_room] has loaded a room. You can use it when you want to call some methods after loading a room (e.g. positioning the player).
signal room_loaded

## Sets the node to be tracked by this class. When player was assigned, [method MetroidvaniaSystem.set_player_position] will be called automatically at the end of every physics frame, updating the player position.
func set_player(p_player: Node2D):
	player = p_player
	player.get_tree().physics_frame.connect(_physics_tick, CONNECT_DEFERRED)

## Adds a module. [param module_name] refers to a file located in [code]Template/Scripts/Modules[/code]. The script must extend [code]MetSysModule.gd[/code].
func add_module(module_name: String):
	module_name = "res://addons/MetroidvaniaSystem/Template/Scripts/Modules/".path_join(module_name)
	var module: MetSysModule = load(module_name).new(self)
	modules.append(module)

func _physics_tick():
	MetSys.set_player_position(player.position)

## Loads a map and adds as a child of this node. If a map already exists, it will be removed before the new one is loaded. This method is asynchronous, so you should call it with [code]await[/code] if you want to do something after the map is loaded. Alternatively, you can use [signal room_loaded].
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
