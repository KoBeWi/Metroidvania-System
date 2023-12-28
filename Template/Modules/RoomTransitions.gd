extends "res://Template/MetSysModule.gd"

@export var tile_size := Vector2(32, 32)

var player: Node2D

var prev_cell: Vector3i
var direction: Vector3i

func _initialize():
	player = game.player
	MetSys.cell_changed.connect(on_cell_changed)
	MetSys.room_changed.connect(on_room_changed, CONNECT_DEFERRED)

func on_cell_changed(new_cell: Vector3i):
	direction = new_cell - prev_cell
	prev_cell = new_cell

func on_room_changed(target_room: String):
	var prev_room_instance := MetSys.get_current_room_instance()
	if prev_room_instance:
		prev_room_instance.get_parent().remove_child(prev_room_instance)
	
	await game.load_room(target_room)
	
	if prev_room_instance:
		player.position -= MetSys.get_current_room_instance().get_room_position_offset(prev_room_instance)
		prev_room_instance.queue_free()
