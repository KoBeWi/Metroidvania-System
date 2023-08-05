@tool
extends MetroidvaniaSystem.CustomElementManager

func _init() -> void:
	register_element("elevator", draw_elevator)
	register_element("label", draw_label)

func draw_elevator(canvas_item: CanvasItem, coords: Vector3i, pos: Vector2, size: Vector2, data: String):
	if not MetSys.is_cell_discovered(coords + Vector3i(0, -1, 0)) and not MetSys.is_cell_discovered(coords + Vector3i(0, size.y, 0)):
		return
	
	var elevator_texture := preload("res://SampleProject/Sprites/Elevator.png")
	canvas_item.draw_texture_rect(elevator_texture, Rect2(
		pos + Vector2.RIGHT * (MetSys.CELL_SIZE.x * 0.5 - elevator_texture.get_width() * 0.5),
		Vector2(elevator_texture.get_width(), size.y)), true, MetSys.settings.theme.default_border_color)

func draw_label(canvas_item: CanvasItem, coords: Vector3i, pos: Vector2, size: Vector2, data: String):
	if not MetSys.is_cell_discovered(coords):
		return
	
	canvas_item.draw_string(ThemeDB.get_default_theme().default_font,
		pos + Vector2(-1, -0.5) * MetSys.CELL_SIZE, data, HORIZONTAL_ALIGNMENT_CENTER, MetSys.CELL_SIZE.x * 3)
