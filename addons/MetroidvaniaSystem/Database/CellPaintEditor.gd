@tool
extends "res://addons/MetroidvaniaSystem/Database/SubEditor.gd"

enum { MODE_DRAW, MODE_ERASE, MODE_PICK }

var can_pick: bool
var super_use_cursor: bool
var whole_room: bool

func _editor_init() -> void:
	super_use_cursor = use_cursor

func _editor_enter():
	super()
	%Shortcuts.show()
	%ShortcutPick.visible = can_pick

func _editor_exit():
	super()
	%Shortcuts.hide()

func _editor_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if can_pick and not whole_room and event.is_command_or_control_pressed():
					paint(MODE_PICK)
				else:
					paint(MODE_DRAW)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				paint(MODE_ERASE)
	
	elif event is InputEventMouseMotion:
		if whole_room:
			update_hovered_room()
		
		if event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT):
			var erase := bool(event.button_mask & MOUSE_BUTTON_MASK_RIGHT)
			paint(MODE_ERASE if erase else MODE_DRAW)
	
	elif event is InputEventKey:
		if not event.echo and event.keycode == KEY_SHIFT:
			whole_room = event.pressed
			use_cursor = super_use_cursor and not whole_room
			if whole_room:
				update_hovered_room()
			else:
				highlighted_room.clear()
			
			redraw_overlay()

func update_hovered_room():
	var hr := highlighted_room
	highlighted_room = MetSys.map_data.get_whole_room(get_coords(get_cursor_pos()))
	if highlighted_room != hr:
		redraw_overlay()

func paint(mode: int):
	var coords_to_modify: Array[Vector3i]
	if whole_room:
		coords_to_modify = highlighted_room
	else:
		coords_to_modify.assign([get_coords(get_cursor_pos())])
	
	var modified: bool
	for coords in coords_to_modify:
		var cell_data := MetSys.map_data.get_cell_at(coords)
		if not cell_data:
			continue
		
		if modify_cell(cell_data, mode) or modify_coords(coords, mode):
			modified = true
	
	undo_end_with_redraw()
	
	if modified:
		if overlay_mode:
			redraw_overlay()
		else:
			redraw_map()

func modify_cell(cell_data: MetroidvaniaSystem.MapData.CellData, mode: int) -> bool:
	return false

func modify_coords(coords: Vector3i, mode: int) -> bool:
	return false
