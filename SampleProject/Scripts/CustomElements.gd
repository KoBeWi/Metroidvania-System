@tool
extends MetroidvaniaSystem.CustomElementManager

func _init() -> void:
	register_element("elevator", draw_elevator)

func draw_elevator(canvas_item: CanvasItem, coords: Vector3i, pos: Vector2, size: Vector2, data: String):
	var elevator_texture := preload("res://SampleProject/Sprites/Elevator.png")
	canvas_item.draw_texture_rect(elevator_texture, Rect2(
		pos + Vector2.RIGHT * (MetSys.CELL_SIZE.x * 0.5 - elevator_texture.get_width() * 0.5),
		Vector2(elevator_texture.get_width(), size.y)), true, MetSys.settings.theme.default_border_color)
	
	if not data.is_empty():
		canvas_item.draw_string(ThemeDB.get_default_theme().default_font, pos + Vector2(MetSys.CELL_SIZE.x, size.y * 0.5), data)
