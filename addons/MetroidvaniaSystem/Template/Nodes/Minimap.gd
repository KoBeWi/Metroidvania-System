## A [Control] node that displays a part of the world map.
##
## Instantiate [code]Minimap.tscn[/code] in your GUI scene and it just works™, even in the editor. You can use it as a minimap or as a basis for a map screen.
@tool
extends Control

## If [code]true[/code], [member center] and [member layer] will be automatically updated when [signal MetroidvaniaSystem.cell_changed] is received.
@export var track_position := true

## If [code]true[/code], the minimap scrolls with pixel precision, instead of changing when cell changes. Only effective when the current theme uses [member MapTheme.show_exact_player_location] enabled.
@export var smooth_scroll := false:
	set(ss):
		smooth_scroll = ss
		update_configuration_warnings()

## If [code]true[/code], player location scene will be automatically displayed and updated in the minimap.
@export var display_player_location := false

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
		if drawer:
			drawer.queue_redraw()

## Layer displayed by the minimap.
@export var layer: int:
	set(value):
		layer = value
		if drawer:
			drawer.queue_redraw()

@onready var drawer: Node2D = $Drawer

var player_location: Node2D

func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		MetSys.settings.theme_changed.connect(update_configuration_warnings)
		return
	
	MetSys.map_updated.connect(drawer.queue_redraw)
	if track_position:
		MetSys.cell_changed.connect(_on_cell_changed)
	
	if display_player_location:
		player_location = MetSys.add_player_location(drawer)
	
	set_physics_process(smooth_scroll and MetSys.settings.theme.show_exact_player_location)

func _physics_process(delta: float) -> void:
	update_drawer_position()

func _on_cell_changed(new_cell: Vector3i):
	center = Vector2i(new_cell.x, new_cell.y)
	layer = new_cell.z
	
	if is_physics_processing():
		update_drawer_position()

func _get_configuration_warnings() -> PackedStringArray:
	var ret: PackedStringArray
	if area.x % 2 == 0 or area.y % 2 == 0:
		ret.append("Using even area dimensions is not recommended.")
	
	if smooth_scroll and not MetSys.settings.theme.show_exact_player_location:
		ret.append("Smooth Scroll is enabled, but the MapTheme doesn't show exact player location. The property will have no effect.")
	
	return ret

func _get_minimum_size() -> Vector2:
	return Vector2(area) * MetSys.CELL_SIZE

func update_drawer_position():
	var new_position := -(MetSys.exact_player_position / MetSys.settings.in_game_cell_size).posmod(1) * MetSys.CELL_SIZE + MetSys.CELL_SIZE * 0.5
	if new_position != drawer.position:
		drawer.position = new_position

func _draw_map() -> void:
	var draw_center := center
	var draw_area := area
	var draw_offset: Vector2
	
	if is_physics_processing():
		draw_area += Vector2i(2, 2)
		draw_offset = -Vector2i.ONE
	
	var offset := -draw_area / 2
	if player_location:
		player_location.visible = layer == MetSys.current_layer
		if player_location.visible:
			player_location.offset = (-Vector2(draw_center + offset) + draw_offset) * MetSys.CELL_SIZE
	
	for y in draw_area.y:
		for x in draw_area.x:
			MetSys.draw_cell(drawer, Vector2(x, y) + draw_offset, Vector3i(draw_center.x + offset.x + x, draw_center.y + offset.y + y, layer))
	
	if MetSys.settings.theme.use_shared_borders:
		MetSys.draw_shared_borders()
	
	MetSys.draw_custom_elements(drawer, Rect2i(draw_center + offset, draw_area), draw_offset, layer)
