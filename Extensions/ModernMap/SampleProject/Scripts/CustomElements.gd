# Example script for drawing custom elements. Interesting part is how to use the arguments provided for callbas.
@tool
extends MetroidvaniaSystem.CustomElementManager

const FogOfMystery = preload("res://addons/MetroidvaniaSystem/Template/Scripts/Modules/FogOfMystery.gd")

func _init() -> void:
	# Metroid-esque elevator shaft.
	register_element("elevator", draw_elevator)
	# Some text that displays on the map.
	register_element("label", draw_label)
	# Room overlay displayer.
	register_element("overlay", draw_overlay)

func draw_elevator(canvas_item: CanvasItem, coords: Vector3i, pos: Vector2, size: Vector2, data: String):
	# For elevator to display, both top and bottom cell must be discovered.
	if not MetSys.is_cell_discovered(coords + Vector3i(0, -1, 0)) and not MetSys.is_cell_discovered(coords + Vector3i(0, size.y, 0)):
		return
	
	var elevator_texture := preload("res://SampleProject/Sprites/Elevator.png")
	# Draw the texture using the element's rect and default bolder color as modulate.
	canvas_item.draw_texture_rect(elevator_texture, Rect2(
		pos + Vector2.RIGHT * (MetSys.CELL_SIZE.x * 0.5 - elevator_texture.get_width() * 0.5),
		Vector2(elevator_texture.get_width(), size.y)), true, MetSys.settings.theme.default_border_color)

func draw_label(canvas_item: CanvasItem, coords: Vector3i, pos: Vector2, size: Vector2, data: String):
	# The label is only visible if it's cell is discovered.
	if not MetSys.is_cell_discovered(coords):
		return
	# Draw the string.
	canvas_item.draw_string(ThemeDB.get_default_theme().default_font,
		pos + Vector2(-1, -0.5) * MetSys.CELL_SIZE, data, HORIZONTAL_ALIGNMENT_CENTER, MetSys.CELL_SIZE.x * 3)

func draw_overlay(canvas_item: CanvasItem, coords: Vector3i, pos: Vector2, size: Vector2, data: String):
	FogOfMystery.draw_overlay(canvas_item, coords, pos, size)
