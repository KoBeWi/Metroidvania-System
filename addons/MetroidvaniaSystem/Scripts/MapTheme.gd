@tool
extends Resource
class_name MapTheme

const SQUARE_BORDERS = ["wall", "passage", "separator", "borders"]
const RECTANGLE_BORDERS = ["vertical_wall", "horizontal_wall", "vertical_passage", "horizontal_passage", "vertical_separator", "horizontal_separator", "vertical_borders", "horizontal_borders"]
const DEFAULT_CORNERS = ["inner_corner", "outer_corner"]
const SHARED_CORNERS = ["u_corner", "l_corner", "t_corner", "cross_corner"]

@export var center_texture: Texture2D:
	set(ct):
		center_texture = ct
		var new_rectangle := center_texture.get_width() != center_texture.get_height()
		if new_rectangle != rectangle:
			rectangle = new_rectangle
			notify_property_list_changed()

@export var empty_space_texture: Texture2D

@export var player_location_scene: PackedScene
@export var show_exact_player_location: bool
@export_flags("Center", "Outline", "Borders", "Symbol") var mapped_display := 3

@export var use_shared_borders: bool:
	set(usb):
		if usb != use_shared_borders:
			use_shared_borders = usb
			notify_property_list_changed()

@export_group("Colors")
@export var default_center_color: Color
@export var mapped_center_color: Color
@export var default_border_color: Color
@export var mapped_border_color: Color
@export var room_separator_color: Color

@export_group("Symbols")
@export var symbols: Array[Texture2D]
@export var uncollected_item_symbol := -1
@export var collected_item_symbol := -1

@export_group("Border Textures")
@export var wall: Texture2D
@export var passage: Texture2D
@export var separator: Texture2D
@export var borders: Array[Texture2D]

@export var vertical_wall: Texture2D
@export var horizontal_wall: Texture2D
@export var vertical_passage: Texture2D
@export var horizontal_passage: Texture2D
@export var vertical_separator: Texture2D
@export var horizontal_separator: Texture2D
@export var vertical_borders: Array[Texture2D]
@export var horizontal_borders: Array[Texture2D]

@export_group("Corner Textures")
@export var inner_corner: Texture2D
@export var outer_corner: Texture2D

@export var u_corner: Texture2D
@export var l_corner: Texture2D
@export var t_corner: Texture2D
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
