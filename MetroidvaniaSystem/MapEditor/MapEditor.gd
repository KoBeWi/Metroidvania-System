extends Control

enum {MODE_LAYOUT = 1, MODE_ROOM_SYMBOL, MODE_ROOM_COLOR, MODE_ROOM_GROUP, MODE_BORDER_TYPE, MODE_BORDER_COLOR, MODE_MAP}

@onready var map_overlay: Control = $MapOverlay
@onready var map: Control = %Map

const NULL_VECTOR2I = Vector2i(-9999999, -9999999)

var drag_from: Vector2i = NULL_VECTOR2I
var view_drag: Vector4
var map_offset := Vector2i(10, 10)

var mode: int = MODE_LAYOUT
var current_layer: int

func _ready() -> void:
	%RoomLayout.button_group.pressed.connect(mode_pressed)
	get_current_sub_editor()._editor_enter()

func mode_pressed(button: BaseButton):
	get_current_sub_editor()._editor_exit()
	mode = button.get_index()
	get_current_sub_editor()._editor_enter()
	
	map_overlay.queue_redraw() ## TODO: naprawić kursor

func layer_changed(l: int):
	current_layer = l
	map.queue_redraw()
	map_overlay.queue_redraw()

func get_current_sub_editor() -> Control:
	return %Modes.get_child(mode)

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if view_drag != Vector4():
			map_offset = (Vector2i(view_drag.z, view_drag.w) + Vector2i(map_overlay.get_local_mouse_position() - Vector2(view_drag.x, view_drag.y)) / MetSys.ROOM_SIZE)
			map.queue_redraw()
		else:
			map_overlay.queue_redraw()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				view_drag.x = map_overlay.get_local_mouse_position().x
				view_drag.y = map_overlay.get_local_mouse_position().y
				view_drag.z = map_offset.x
				view_drag.w = map_offset.y
			else:
				view_drag = Vector4()
	
	get_current_sub_editor()._editor_input(event)

func _on_overlay_draw() -> void:
	var room_size: Vector2 = MetSys.ROOM_SIZE
	map_overlay.draw_set_transform(Vector2(map_offset) * room_size)
	
	get_current_sub_editor()._editor_draw(map_overlay)
	
	map_overlay.draw_set_transform_matrix(Transform2D())
	map_overlay.draw_string(get_theme_font(&"font", &"Label"), Vector2(0, 20), str(get_current_sub_editor().get_cursor_pos()))

func _on_map_draw() -> void:
	for x in range(-100, 100):
		for y in range(-100, 100):
			MetSys.draw_map_square(map, Vector2i(x, y) + map_offset, Vector3i(x, y, current_layer))

func _exit_tree() -> void:
	save_map_data()

func save_map_data():
	var file := FileAccess.open(MetSys.map_root_folder.path_join("MapData.txt"), FileAccess.WRITE)
	
	for group in MetSys.room_groups:
		if MetSys.room_groups[group].is_empty():
			continue
		
		var line: PackedStringArray
		line.append(str(group))
		for coords in MetSys.room_groups[group]:
			line.append("%s,%s,%s" % [coords.x, coords.y, coords.z])
		
		file.store_line(":".join(line))
	
	for coords in MetSys.map_data:
		file.store_line("[%s,%s,%s]" % [coords.x, coords.y, coords.z])
		
		var room_data: Dictionary = MetSys.map_data[coords]
		file.store_line("%s,%s,%s,%s|%s" % [room_data.borders[0], room_data.borders[1], room_data.borders[2], room_data.borders[3], room_data.get("assigned_map", "")])
