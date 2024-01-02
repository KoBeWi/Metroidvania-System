## A [Control] node that displays a part of the world map.
##
## Instantiate [code]Minimap.tscn[/code] in your GUI scene and it just works™, even in the editor. You can use it as a minimap or as a basis for a map screen.
@tool
extends Control

## If [code]true[/code], [member center] and [member layer] will be automatically updated when [signal MetroidvaniaSystem.cell_changed] is received.
@export var track_position := true

## Size of the minimap in cells. Avoid even numbers if you want to display the player position in the middle.
@export var area: Vector2i = Vector2i(3, 3):
	set(value):
		area = value
		update_configuration_warnings()
		update_minimum_size()

## Center coordinates shown on the minimap. Corresponds to the position on the world map.
@export var center: Vector2i:
	set(value):
		center = value
		queue_redraw()

## Layer displayed by the minimap.
@export var layer: int:
	set(value):
		layer = value
		queue_redraw()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	MetSys.map_updated.connect(queue_redraw)
	if track_position:
		MetSys.cell_changed.connect(_on_cell_changed)

func _on_cell_changed(new_cell: Vector3i):
	center = Vector2i(new_cell.x, new_cell.y)
	layer = new_cell.z

func _get_configuration_warnings() -> PackedStringArray:
	var ret: PackedStringArray
	if area.x % 2 == 0 or area.y % 2 == 0:
		ret.append("Using even area dimensions is not recommended.")
	
	return ret

func _get_minimum_size() -> Vector2:
	return Vector2(area) * MetSys.CELL_SIZE

func _draw() -> void:
	var offset := -area / 2
	
	for y in area.y:
		for x in area.x:
			MetSys.draw_cell(self, Vector2i(x, y), Vector3i(center.x + offset.x + x, center.y + offset.y + y, layer))
	
	if MetSys.settings.theme.use_shared_borders:
		MetSys.draw_shared_borders()
	
	MetSys.draw_custom_elements(self, Rect2i(center + offset, area), Vector2(), layer)
