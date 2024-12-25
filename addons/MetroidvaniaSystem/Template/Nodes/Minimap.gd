## A [Control] node that displays a part of the world map.
##
## Instantiate [code]Minimap.tscn[/code] in your GUI scene and it just works™, even in the editor. You can use it as a minimap or as a basis for a map screen.
@tool
extends Control

## If [code]true[/code], [member center] and [member layer] will be automatically updated when [signal MetroidvaniaSystem.cell_changed] is received. Enabling this property will make some other properties ineffective.
@export var track_position := true:
	set(tp):
		track_position = tp
		notify_property_list_changed()

## If [code]true[/code], the minimap scrolls with pixel precision, instead of changing when cell changes. Only effective when the current theme uses [member MapTheme.show_exact_player_location] enabled. [member track_position] must be enabled.
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
		if _drawer:
			_drawer.queue_redraw()

## Layer displayed by the minimap.
@export var layer: int:
	set(value):
		layer = value
		if _drawer:
			_drawer.queue_redraw()

@onready var _drawer: Node2D = $Drawer
var _map_view: MapView
var _player_location: Node2D

func _ready() -> void:
	var actual_size := area
	if smooth_scroll:
		actual_size += Vector2i(2, 2)
	
	_map_view = MetSys.make_map_view(_drawer, center - actual_size / 2, actual_size, layer)
	
	if Engine.is_editor_hint():
		set_physics_process(false)
		MetSys.settings.theme_changed.connect(update_configuration_warnings)
		return
	
	
	MetSys.map_updated.connect(_map_view.update_all)
	if track_position:
		MetSys.cell_changed.connect(_on_cell_changed)
		set_physics_process(smooth_scroll and MetSys.settings.theme.show_exact_player_location)
	
	if display_player_location:
		_player_location = MetSys.add_player_location(_drawer)

func _physics_process(delta: float) -> void:
	update_drawer_position()

func _on_cell_changed(new_cell: Vector3i):
	var new_center := Vector2i(new_cell.x, new_cell.y)
	_map_view.move(new_center - center, new_cell.z)
	center = new_center
	update_drawer_position()

func update_drawer_position():
	if smooth_scroll:
		var new_position := -(MetSys.exact_player_position / MetSys.settings.in_game_cell_size).posmod(1) * MetSys.CELL_SIZE + MetSys.CELL_SIZE * 0.5
		if new_position != _drawer.position:
			if smooth_scroll:
				_drawer.position = new_position - MetSys.CELL_SIZE
			else:
				_drawer.position = new_position
	
	if _player_location:
		if layer == MetSys.current_layer:
			_player_location.show()
			_player_location.offset = -Vector2(center) * MetSys.CELL_SIZE + MetSys.CELL_SIZE * Vector2(area / 2)
			if smooth_scroll:
				_player_location.offset += MetSys.CELL_SIZE
		else:
			_player_location.hide()

func _get_minimum_size() -> Vector2:
	return Vector2(area) * MetSys.CELL_SIZE

func _get_configuration_warnings() -> PackedStringArray:
	var ret: PackedStringArray
	if area.x % 2 == 0 or area.y % 2 == 0:
		ret.append("Using even area dimensions is not recommended.")
	
	if smooth_scroll and not MetSys.settings.theme.show_exact_player_location:
		ret.append("Smooth Scroll is enabled, but the MapTheme doesn't show exact player location. The property will have no effect.")
	
	return ret

func _validate_property(property: Dictionary) -> void:
	var pname: String = property["name"]
	if track_position:
		if pname == "center" or pname == "layer":
			property.usage |= PROPERTY_USAGE_READ_ONLY
	else:
		if pname == "smooth_scroll":
			property.usage |= PROPERTY_USAGE_READ_ONLY
