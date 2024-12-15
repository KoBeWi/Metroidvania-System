# Example script for drawing custom elements. Interesting part is how to use the arguments provided for callbas.
@tool
extends MetroidvaniaSystem.CustomElementManager

func _init() -> void:
	# Metroid-esque elevator shaft.
	register_element("elevator", draw_elevator)
	# Some text that displays on the map.
	register_element("label", draw_label)

func draw_elevator(canvas_item: RID, coords: Vector3i, pos: Vector2, size: Vector2, data: String):
	# For elevator to display, both top and bottom cell must be discovered.
	if not MetSys.is_cell_discovered(coords + Vector3i(0, -1, 0)) and not MetSys.is_cell_discovered(coords + Vector3i(0, size.y, 0)):
		return
	
	var elevator_texture := preload("res://SampleProject/Sprites/Elevator.png")
	# Draw the texture using the element's rect and default border color as modulate.
	elevator_texture.draw_rect(canvas_item, Rect2(
		pos + Vector2(MetSys.CELL_SIZE.x * 0.5 - elevator_texture.get_width() * 0.5, 0),
		Vector2(elevator_texture.get_width(), size.y)), true, MetSys.settings.theme.default_border_color)

func draw_label(canvas_item: RID, coords: Vector3i, pos: Vector2, size: Vector2, data: String):
	# The label is only visible if it's cell is discovered.
	if not MetSys.is_cell_discovered(coords):
		return
	# Draw the string.
	var font := ThemeDB.get_default_theme().default_font
	font.draw_string(canvas_item,
		pos + Vector2(-1, -0.5) * MetSys.CELL_SIZE, data, HORIZONTAL_ALIGNMENT_CENTER, MetSys.CELL_SIZE.x * 3)
