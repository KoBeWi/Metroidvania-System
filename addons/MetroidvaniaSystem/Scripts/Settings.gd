@tool
extends Resource

## The theme used for drawing map cells.
@export var theme: MapTheme:
	set(t):
		if t == theme:
			return
		
		theme = t
		theme_changed.emit()

## The root directory where room scenes are located. All scenes used for MetSys editor should be within this folder or its subfolders. The name should end with [code]/[/code].
@export_dir var map_root_folder: String = "res://":
	set(mrf):
		if mrf.ends_with("/"):
			map_root_folder = mrf
		else:
			map_root_folder = mrf + "/"

## The size of a map cell within an in-game room, i.e. this is the real game size of your map cells. Usually equal to the screen size.
@export var in_game_cell_size := Vector2(1152, 648)
@export var collectible_list: Array[Dictionary]
## The script that determines the custom elements available in the Custom Elements map editor mode. It should inherit [code]CustomElementManager.gd[/code], refer to that class' documentation on how to use it.
@export var custom_element_script: Script:
	set(elements):
		if elements == custom_element_script:
			return
		
		custom_element_script = elements
		if elements:
			custom_elements = elements.new()
		else:
			custom_elements = null
		
		custom_elements_changed.emit()

var custom_elements: MetroidvaniaSystem.CustomElementManager

signal theme_changed
signal custom_elements_changed

func _validate_property(property: Dictionary) -> void:
	if property.name == "collectible_list":
		property.usage &= ~PROPERTY_USAGE_EDITOR
