@tool
extends "res://addons/MetroidvaniaSystem/Database/Editor/CellPaintEditor.gd"#"uid://byyfy6e5ygtyx"

func _editor_init() -> void:
	super()
	can_pick = true

func _editor_enter():
	super()
	%Colors.show()

func _editor_exit():
	super()
	%Colors.hide()

func modify_cell(cell_data: MetroidvaniaSystem.MapData.CellData, mode: int) -> bool:
	if mode == MODE_PICK:
		if cell_data.color.a > 0:
			%CurrentColor.color = cell_data.color
	else:
		var target_color := Color.TRANSPARENT
		if mode == MODE_DRAW:
			target_color = %CurrentColor.color
		
		if cell_data.color != target_color:
			var old := cell_data.color
			cell_data.color = target_color
			undo_handle_cell_property(cell_data, &"color", old)
			return true
	
	return false
