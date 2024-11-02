@tool
extends "res://addons/MetroidvaniaSystem/Database/CellPaintEditor.gd"

var border_property = &"borders"

func _editor_init() -> void:
	use_cursor = false
	super()

func _editor_input(event: InputEvent):
	if event is InputEventMouseMotion:
		var cell_data := get_cell_at_cursor()
		if cell_data:
			var rel := editor.map_overlay.get_local_mouse_position().posmodv(MetSys.CELL_SIZE)
			var border := get_square_border_idx(cell_data.borders, rel)
			
			var new_border := -1
			var borders: Array[int] = cell_data.borders
			
			for i in 4:
				if border == i and borders[i] > -1:
					new_border = border
					break
			
			if new_border != highlighted_border:
				highlighted_border = new_border
				redraw_overlay()
		else:
			highlighted_border = -1
	
	super(event)

func update_hovered_room():
	if highlighted_border == -1:
		highlighted_room.clear()
		return
	
	super()

func modify_cell(cell_data: MetroidvaniaSystem.MapData.CellData, mode: int) -> bool:
	if highlighted_border == -1:
		return false
	
	var old: Variant = cell_data.get(border_property).duplicate()
	var modified: bool
	if whole_room:
		for i in 4:
			modified = modify_border(cell_data, i, mode) or modified
	else:
		modified = modify_border(cell_data, highlighted_border, mode)
	
	if modified:
		undo_handle_cell_property(cell_data, border_property, old)
	
	return modified

func modify_border(cell_data: MetroidvaniaSystem.MapData.CellData, border: int, mode: int) -> bool:
	return false
