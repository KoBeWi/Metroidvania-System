@tool
extends "res://addons/MetroidvaniaSystem/Database/Editor/CellPaintEditor.gd"#"uid://byyfy6e5ygtyx"

var drawing: int

func _editor_init() -> void:
	super()
	room_only_cursor = true
	overlay_mode = true
	%CurrentGroup.value_changed.connect(redraw_overlay.unbind(1))

func _update_theme():
	theme_cache.group_color = get_theme_color(&"group_color", &"MetSys")

func _editor_enter():
	super()
	%Groups.show()

func _editor_exit():
	super()
	%Groups.hide()

func _editor_draw(map_overlay: CanvasItem):
	super(map_overlay)
	
	var cell_groups := MetSys.map_data.cell_groups
	for p in cell_groups.get(%CurrentGroup.value as int, []):
		if p.z == editor.current_layer:
			map_overlay.draw_rect(Rect2(Vector2(p.x, p.y) * MetSys.CELL_SIZE, MetSys.CELL_SIZE), theme_cache.group_color)

func modify_coords(coords: Vector3i, mode: int) -> bool:
	var current_group: int = %CurrentGroup.value
	
	var cell_groups := MetSys.map_data.cell_groups
	if mode == MODE_DRAW:
		if not current_group in cell_groups:
			cell_groups[current_group] = []
		
		if not coords in cell_groups[current_group]:
			cell_groups[current_group].append(coords)
			undo_handle_group_add(coords, current_group)
			return true
	else:
		if coords in cell_groups[current_group]:
			cell_groups[current_group].erase(coords)
			undo_handle_group_remove(coords, current_group)
			return true
	
	return false
