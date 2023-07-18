@tool
extends Resource
class_name MapTheme

const DYNAMIC_PROPERTIES = [&"vertical_wall", &"horizontal_wall", &"vertical_passage", &"horizontal_passage",
	&"horizontal_borders", &"vertical_borders", &"vertical_separator", &"horizontal_separator",
	&"wall", &"passage", &"borders", &"separator", &"inner_corner", &"outer_corner", &"t_corner", &"cross_corner"]

@export var default_center_color: Color
@export var unexplored_center_color: Color
@export var default_border_color: Color
@export var unexplored_border_color: Color
@export var room_separator_color: Color

@export var player_location_scene: PackedScene

@export var symbols: Array[Texture2D]
@export var uncollected_item_symbol := -1
@export var collected_item_symbol := -1

@export var center_texture: Texture2D:
	set(ct):
		center_texture = ct
		rectangle = center_texture.get_width() != center_texture.get_height()
		notify_property_list_changed()

@export var use_shared_borders: bool:
	set(usb):
		use_shared_borders = usb
		notify_property_list_changed()

var data: Dictionary
var rectangle: bool

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary]
	
	properties.append({name = &"Border Textures", type = TYPE_NIL, usage = PROPERTY_USAGE_GROUP})
	
	if rectangle:
		properties.append(_get_texture_property(&"vertical_wall"))
		properties.append(_get_texture_property(&"horizontal_wall"))
		properties.append(_get_texture_property(&"vertical_passage"))
		properties.append(_get_texture_property(&"horizontal_passage"))
		properties.append(_get_texture_property(&"vertical_separator"))
		properties.append(_get_texture_property(&"horizontal_separator"))
		properties.append(_get_texture_array_property(&"vertical_borders"))
		properties.append(_get_texture_array_property(&"horizontal_borders"))
	else:
		properties.append(_get_texture_property(&"wall"))
		properties.append(_get_texture_property(&"passage"))
		properties.append(_get_texture_property(&"separator"))
		properties.append(_get_texture_array_property(&"borders"))
	
	properties.append({name = &"Corner Textures", type = TYPE_NIL, usage = PROPERTY_USAGE_GROUP})
	
	properties.append(_get_texture_property(&"inner_corner"))
	properties.append(_get_texture_property(&"outer_corner"))
	
	if use_shared_borders:
		properties.append(_get_texture_property(&"t_corner"))
		properties.append(_get_texture_property(&"cross_corner"))
	
	return properties

func _set(property: StringName, value) -> bool:
	if property in DYNAMIC_PROPERTIES:
		data[property] = value
		return true
	return false

func _get(property: StringName):
	if property in DYNAMIC_PROPERTIES:
		return data.get(property)
	return null

func _get_texture_property(property: StringName) -> Dictionary:
	return {name = property, type = TYPE_OBJECT, hint = PROPERTY_HINT_RESOURCE_TYPE, hint_string = "Texture2D"}

func _get_texture_array_property(property: StringName) -> Dictionary:
	return {name = property, type = TYPE_ARRAY, hint = PROPERTY_HINT_ARRAY_TYPE, hint_string = str(TYPE_OBJECT, "/" , PROPERTY_HINT_RESOURCE_TYPE, ":Texture2D")}
