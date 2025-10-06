@tool
extends "res://addons/MetroidvaniaSystem/Database/Editor/BorderPaintEditor.gd"#"uid://c1rtahqsg11b4"

func _editor_init():
	can_pick = true
	update_neighbors = true
	border_property = &"border_colors"
	super()

func _editor_enter():
	super()
	%Colors.show()

func _editor_exit():
	super()
	%Colors.hide()

func modify_border(cell_data: MetroidvaniaSystem.MapData.CellData, border: int, mode: int) -> bool:
	if cell_data.borders[border] == -1:
		return false
	
	if mode == MODE_PICK:
		if cell_data.border_colors[border].a > 0:
			%CurrentColor.color = cell_data.border_colors[border]
	else:
		var target_color := Color.TRANSPARENT
		if mode == MODE_DRAW:
			target_color = %CurrentColor.color
		
		if cell_data.border_colors[border] != target_color:
			cell_data.border_colors[border] = target_color
			return true
	
	return false
