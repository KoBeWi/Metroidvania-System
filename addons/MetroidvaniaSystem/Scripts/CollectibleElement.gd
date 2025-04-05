@tool
extends PanelContainer

const FoundElement = preload("uid://cdl44ebe6tc0h").FoundElement

var resource_picker: EditorResourcePicker

signal save_request

func _ready() -> void:
	if is_part_of_edited_scene():
		return
	
	resource_picker = EditorResourcePicker.new()
	%IconContainer.add_child(resource_picker)
	resource_picker.base_type = "Texture2D"
	resource_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_picker.resource_changed.connect(func(a): save_request.emit())

func get_data() -> FoundElement:
	var data := FoundElement.new()
	data.element = %LineEdit.text
	
	if resource_picker.edited_resource:
		data.icon = load(resource_picker.edited_resource.resource_path)
	return data

func get_save_data() -> Dictionary:
	var data: Dictionary
	data.element = %LineEdit.text
	
	if resource_picker.edited_resource:
		var path := resource_picker.edited_resource.resource_path
		path = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(path))
		data.icon = path
		
	return data

func set_data(data: Dictionary):
	%LineEdit.text = data.element
	if &"icon" in data:
		resource_picker.edited_resource = load(data.icon)

func delete() -> void:
	queue_free()
	save_request.emit()
