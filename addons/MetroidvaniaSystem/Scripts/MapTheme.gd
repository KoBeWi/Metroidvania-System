@tool
## Resource that defines the cell appearance.
##
## MapTheme is assigned in MetSys Settings and defines the cell appearance when using [MapView]. It has a few subtypes: shape can be either square or rectangular and borders can be either shared or not. Some properties are only available for certain theme subtypes. Check the Map Theme section in README for some more detailed information.
extends Resource
class_name MapTheme

const SQUARE_BORDERS = ["wall", "passage", "separator", "borders"]
const RECTANGLE_BORDERS = ["vertical_wall", "horizontal_wall", "vertical_passage", "horizontal_passage", "vertical_separator", "horizontal_separator", "vertical_borders", "horizontal_borders"]
const DEFAULT_CORNERS = ["inner_corner", "outer_corner"]
const SHARED_CORNERS = ["u_corner", "l_corner", "t_corner", "cross_corner"]

enum SeparatorMode {
	## Separator is drawn when there is no border, only on bottom and right side.
	EMPTY_SINGLE,
	## Separator is drawn when there is no border, on all sides.
	EMPTY_DOUBLE,
	## Separator is drawn under any border except wall, only on bottom and right side.
	FULL_SINGLE,
	## Separator is drawn under any border except wall, on all sides.
	FULL_DOUBLE
}

## The cell's center texture. The size of all other textures depends on this one. It can be square or rectangular and the shape affects some properties. The texture should be grayscale (preferrably white).
@export var center_texture: Texture2D:
	set(ct):
		center_texture = ct
		var new_rectangle := center_texture.get_width() != center_texture.get_height()
		if new_rectangle != rectangle:
			rectangle = new_rectangle
			notify_property_list_changed()

## The texture drawn in empty space. Optional.
@export var empty_space_texture: Texture2D

## The scene that appears at player location after using [method MetroidvaniaSystem.add_player_location]. Must have a [Node2D] root. Optional, but [method MetroidvaniaSystem.add_player_location] can't be used if the scene is not provided.
@export var player_location_scene: PackedScene
## If [code]true[/code], the player location is displayed accurately inside the cell. If [code]false[/code], the location marker always appears at the center of the cell.
@export var show_exact_player_location: bool
## Determines how mapped (unexplored) cells are displayed. Use Preview Mapped option in Map Viewer to preview this style.
@export_flags("Center", "Outline", "Borders", "Symbol") var mapped_display := 3

## Determines how separators are displayed. See [enum SeparatorMode]. Not supported in shared border mode.
@export var separator_mode: SeparatorMode = SeparatorMode.FULL_SINGLE
## If [code]true[/code], cell borders are drawn between the cells instead of inside them. This setting has a major effect on the theme.
@export var use_shared_borders: bool:
	set(usb):
		if usb != use_shared_borders:
			use_shared_borders = usb
			notify_property_list_changed()

@export_group("Colors")
## Default modulation of the center texture.
@export var default_center_color: Color
## Modulation of the center texture when the cell is only mapped. Usually this color is gray.
@export var mapped_center_color: Color
## Default modulation of the cell's border textures.
@export var default_border_color: Color
## Modulation of the cell's border textures when the cell is only mapped.
@export var mapped_border_color: Color

@export_group("Symbols")
## The list of symbols that can be assigned to cells, either from editor, using [method MetroidvaniaSystem.add_custom_marker] or from storable objects.
@export var symbols: Array[Texture2D]
## The symbol for discovered, but not collected item (or any other object). See [method MetroidvaniaSystem.add_storable_object_with_marker]. Must be within [member symbols] indicies. [code]-1[/code] means no symbol will be assigned automatically.
@export var uncollected_item_symbol := -1
## The symbol for collected item (or any other object). See [method MetroidvaniaSystem.store_object]. Must be within [member symbols] indicies. [code]-1[/code] means no symbol will be assigned automatically.
@export var collected_item_symbol := -1

@export_group("Border Textures")
## The texture used for wall borders. Must be oriented vertically facing towards east. Height should match [member center_texture].
@export var wall: Texture2D
## The texture used for passage borders. Same rules as [member wall].
@export var passage: Texture2D
## The texture used for separator, i.e. fake border that draws between cells with no border. Same rules as [member wall]. Optional.
@export var separator: Texture2D
## A set of alternative borders that can be assigned to the cell (either walls or passages). Same rules as [member wall].
@export var borders: Array[Texture2D]

## Same as [member wall], but only available when the [member center_texture] is a rectangle.
@export var vertical_wall: Texture2D
## Same as [member wall], but only available when the [member center_texture] is a rectangle. It should still be oriented horizontally and height should match center texture's width.
@export var horizontal_wall: Texture2D
## Same as [member passage], but only available when the [member center_texture] is a rectangle.
@export var vertical_passage: Texture2D
## Same as [member passage], but only available when the [member center_texture] is a rectangle. It should still be oriented horizontally and height should match center texture's width.
@export var horizontal_passage: Texture2D
## Same as [member separator], but only available when the [member center_texture] is a rectangle.
@export var vertical_separator: Texture2D
## Same as [member separator], but only available when the [member center_texture] is a rectangle. It should still be oriented horizontally and height should match center texture's width.
@export var horizontal_separator: Texture2D
## Same as [member borders], but only available when the [member center_texture] is a rectangle.
@export var vertical_borders: Array[Texture2D]
## Same as [member borders], but only available when the [member center_texture] is a rectangle. It should still be oriented horizontally and height should match center texture's width.
@export var horizontal_borders: Array[Texture2D]

@export_group("Corner Textures")
## The texture that draws at room's outer corners. It draws above borders.
@export var outer_corner: Texture2D
## The texture that draws at room's inner corners. Only appears in concave rooms. It draws above borders.
@export var inner_corner: Texture2D

## Only available when [member use_shared_borders] is enabled. Corner of a single border that divides U-shaped room.
@export var u_corner: Texture2D
## Only available when [member use_shared_borders] is enabled. Corner of 2 perpendicular borders.
@export var l_corner: Texture2D
## Only available when [member use_shared_borders] is enabled. Corner of 3 borders connecting at one point.
@export var t_corner: Texture2D
## Only available when [member use_shared_borders] is enabled. Corner of 4 borders.
@export var cross_corner: Texture2D

var rectangle: bool

func _validate_property(property: Dictionary) -> void:
	if rectangle:
		if property.name in SQUARE_BORDERS:
			property.usage = 0
			return
	else:
		if property.name in RECTANGLE_BORDERS:
			property.usage = 0
			return
	
	if use_shared_borders:
		if property.name in DEFAULT_CORNERS:
			property.usage = 0
			return
	else:
		if property.name in SHARED_CORNERS:
			property.usage = 0
			return

func is_unicorner() -> bool:
	if use_shared_borders:
		return l_corner == u_corner and t_corner == u_corner and cross_corner == u_corner
	else:
		return inner_corner == outer_corner

func is_nocorner():
	if use_shared_borders:
		return l_corner == null and is_unicorner()
	else:
		return inner_corner == null and outer_corner == null

func check_for_changes(prev_state: Array) -> Array[String]:
	var new_state: Array
	var changed: Array[String]
	
	var properties := get_property_list()
	for property in properties:
		new_state.append(get(property.name))
		if changed:
			continue
		
		var idx := new_state.size() - 1
		if idx >= prev_state.size():
			continue
		
		if new_state[idx] != prev_state[idx]:
			changed.append(property.name)
	
	if not changed.is_empty() or prev_state.size() != new_state.size():
		prev_state.assign(new_state)
	
	return changed
