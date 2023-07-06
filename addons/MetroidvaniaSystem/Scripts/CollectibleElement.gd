@tool
extends PanelContainer

var resource_picker: EditorResourcePicker

signal save_request

func _ready() -> void:
	if get_tree().edited_scene_root and get_tree().edited_scene_root.is_ancestor_of(self):
		return
	
	resource_picker = EditorResourcePicker.new()
	%IconContainer.add_child(resource_picker)
	resource_picker.base_type = "Texture2D"
	resource_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_picker.resource_changed.connect(func(a): save_request.emit())

func get_data() -> Dictionary:
	var data := {element = %LineEdit.text}
	if resource_picker.edited_resource:
		data.icon = resource_picker.edited_resource.resource_path
	return data

func get_data2() -> Dictionary:
	var data := get_data()
	if "icon" in data:
		data.icon = load(data.icon)
	return data

func set_data(data: Dictionary):
	%LineEdit.text = data.element
	if "icon" in data:
		resource_picker.edited_resource = load(data.icon)

func delete() -> void:
	queue_free()
	save_request.emit()
