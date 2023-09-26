@tool
extends Resource

@export var theme: MapTheme:
	set(t):
		if t == theme:
			return
		
		theme = t
		theme_changed.emit()

@export_dir var map_root_folder: String = "res://"

@export var in_game_cell_size := Vector2(1152, 648)
@export var collectible_list: Array[Dictionary]
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
