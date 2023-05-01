@tool
extends PanelContainer

func _ready() -> void:
	if get_tree().edited_scene_root and get_tree().edited_scene_root.is_ancestor_of(self):
		return
	
	var resource_picker := EditorResourcePicker.new()
	$VBoxContainer/HBoxContainer.add_child(resource_picker)
	resource_picker.base_type = "Texture2D"
	resource_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func get_element() -> String:
	return %LineEdit.text
