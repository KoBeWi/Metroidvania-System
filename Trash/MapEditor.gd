extends Control

export var highlight_color = Color.navyblue

var new_room

func _process(delta):
	get_room()
	update()

func _draw():
	if new_room:
		draw_rect(Rect2(new_room, cursor_pos() - new_room + MetroidvaniaSettings.ROOM_SIZE), ColorN("white", 0.8))
	else:
		draw_rect(Rect2(cursor_pos(), MetroidvaniaSettings.ROOM_SIZE), ColorN("white", abs(sin(OS.get_ticks_msec() * 0.005))))

func _input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == BUTTON_LEFT:
				var room = get_room()
				if room:
					room.toggle_hole(cursor_pos() / MetroidvaniaSettings.ROOM_SIZE - room.room_data.position)
				elif !new_room:
					new_room = cursor_pos()
		else:
			if event.button_index == BUTTON_LEFT:
				if new_room:
					var room = load(MetroidvaniaSettings.filename.get_base_dir() + "/EditorRoom.tscn").instance()
					room.room_data.position = new_room/MetroidvaniaSettings.ROOM_SIZE
					room.room_data.size = (cursor_pos() - new_room)/MetroidvaniaSettings.ROOM_SIZE + Vector2(1, 1)
					add_child(room)
					
					new_room = null

func get_room():
	var at = cursor_pos() / MetroidvaniaSettings.ROOM_SIZE
	
	for room in get_children():
		if Rect2(room.room_data.position, room.room_data.size).has_point(at):
			room.highlighted = true
			return room

func cursor_pos():
	return (get_local_mouse_position() - MetroidvaniaSettings.ROOM_SIZE/2).snapped(MetroidvaniaSettings.ROOM_SIZE)
