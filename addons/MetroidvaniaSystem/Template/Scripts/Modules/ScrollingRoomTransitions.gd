## A MetSysModule that handles room transitions, with a scrolling effect.
##
## This module is the same as RoomTransitions, but includes a scrolling effect (similar to Zelda or Metroid). When the player moves to another room, both previous and next rooms will be visible and the camera will scroll to the new room.
##[br][br]Note that this effect works best when rooms have unified size. If you move e.g. from wide horizontal room to wide vertical room, the camera will shift in both axes, resulting in space out of map bounds being visible. This can be masked by fading the surroundings to black, like in Metroid games. The module in its base form does not allow to implement it easily.
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysModule.gd"

## Time of the scroll effect. Lower means faster scrolling.
var SCROLL_TIME = 0.5
var _SCREEN_SIZE: Vector2i

var _player: Node2D
var _prev_cell: Vector3i
#var _change_direction: Vector2

func _initialize():
	_SCREEN_SIZE = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)
	
	_player = game.player
	assert(_player)
	MetSys.room_changed.connect(_on_room_changed, CONNECT_DEFERRED)
	MetSys.cell_changed.connect(_on_cell_changed)

func _on_room_changed(target_room: String):
	if target_room == MetSys.get_current_room_id():
		# This can happen when teleporting to another room.
		return
	
	var camera: Camera2D = _player.get_node(^"Camera2D")
	var original_player_position := _player.get_viewport().canvas_transform * _player.position
	
	var prev_room_instance := MetSys.get_current_room_instance()
	if prev_room_instance:
		prev_room_instance.get_parent().remove_child(prev_room_instance)
	
	var prev_map := game.map
	game.map = null
	
	await game.load_room(target_room)
	
	if prev_room_instance:
		var offset := MetSys.get_current_room_instance().get_room_position_offset(prev_room_instance)
		var screen_delta := game.player.get_global_transform_with_canvas().origin
		
		_player.position -= offset
		prev_room_instance.queue_free()
		
		if is_instance_valid(prev_map):
			game.get_tree().paused = true
			
			await game.get_tree().process_frame
			screen_delta = game.player.get_global_transform_with_canvas().origin - screen_delta
			
			prev_map.position -= offset
			
			var tween := game.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tween.tween_property(camera, ^"offset", screen_delta, 0)
			if is_zero_approx(screen_delta.x) or is_zero_approx(screen_delta.y):
				tween.tween_property(camera, ^"offset", Vector2(), SCROLL_TIME)
			else:
				var total := 1.0 / (screen_delta.x + screen_delta.y)
				tween.tween_property(camera, ^"offset:x", 0.0, screen_delta.x * total * SCROLL_TIME)
				tween.tween_property(camera, ^"offset:y", 0.0, screen_delta.y * total * SCROLL_TIME)
			
			await tween.finished
			
			prev_map.queue_free()
			game.get_tree().paused = false

func _on_cell_changed(new_cell: Vector3i):
	#var change := new_cell - _prev_cell
	#change_direction = Vector2(change.x, change.y)
	_prev_cell = new_cell
