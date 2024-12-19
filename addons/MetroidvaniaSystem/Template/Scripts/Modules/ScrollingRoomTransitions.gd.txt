extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysModule.gd"

const SCROLL_TIME = 0.5

var player: Node2D
var prev_cell: Vector3i
var change_direction: Vector2

func _initialize():
	player = game.player
	assert(player)
	MetSys.room_changed.connect(_on_room_changed, CONNECT_DEFERRED)
	MetSys.cell_changed.connect(_on_cell_changed)

func _on_room_changed(target_room: String):
	if target_room == MetSys.get_current_room_name():
		# This can happen when teleporting to another room.
		return
	
	var camera: Camera2D = player.get_node(^"Camera2D")
	
	var prev_room_instance := MetSys.get_current_room_instance()
	if prev_room_instance:
		prev_room_instance.get_parent().remove_child(prev_room_instance)
	
	var prev_map := game.map
	game.map = null
	
	await game.load_room(target_room)
	
	if prev_room_instance:
		var offset := MetSys.get_current_room_instance().get_room_position_offset(prev_room_instance)
		player.position -= offset
		prev_room_instance.queue_free()
		
		if is_instance_valid(prev_map):
			game.get_tree().paused = true
			
			prev_map.position -= offset
			var screen_offset := -change_direction * Vector2(game.get_viewport().size)
			
			var tween := game.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.tween_property(camera, ^"offset", Vector2(), SCROLL_TIME).from(screen_offset)
			
			await tween.finished
			
			prev_map.queue_free()
			game.get_tree().paused = false

func _on_cell_changed(new_cell: Vector3i):
	var change := new_cell - prev_cell
	change_direction = Vector2(change.x, change.y)
	prev_cell = new_cell
