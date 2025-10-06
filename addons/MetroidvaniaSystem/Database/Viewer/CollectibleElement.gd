@tool
extends PanelContainer

const FoundElement = preload("uid://cdl44ebe6tc0h").FoundElement

@onready var line_edit: LineEdit = %LineEdit

var resource_picker: EditorResourcePicker
var previous_resource: Resource
var previous_name: String

signal delete_request

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED and not is_part_of_edited_scene():
		resource_picker = %ResourcePicker

func _on_resource_selected(new_resource: Resource):
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action(tr("Set Collectible Icon"))
	undo_redo.add_do_property(resource_picker, &"edited_resource", new_resource)
	undo_redo.add_do_property(self, &"previous_resource", new_resource)
	undo_redo.add_undo_property(resource_picker, &"edited_resource", previous_resource)
	undo_redo.add_undo_property(self, &"previous_resource", previous_resource)
	undo_redo.commit_action()

func _on_name_changed():
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action(tr("Rename Collectible"), UndoRedo.MERGE_ALL)
	undo_redo.add_do_method(self, &"_set_text_if_different", line_edit.text)
	undo_redo.add_do_property(self, &"previous_name", line_edit.text)
	undo_redo.add_undo_property(line_edit, &"text", previous_name)
	undo_redo.add_undo_property(self, &"previous_name", previous_name)
	undo_redo.commit_action()

func _set_text_if_different(to_text: String):
	if to_text != line_edit.text:
		line_edit.text = to_text

func get_data() -> FoundElement:
	var data := FoundElement.new()
	data.element = line_edit.text
	
	if resource_picker.edited_resource:
		data.icon = load(resource_picker.edited_resource.resource_path)
	return data

func get_save_data() -> Dictionary:
	var data: Dictionary
	data.element = line_edit.text
	
	if resource_picker.edited_resource:
		var path := resource_picker.edited_resource.resource_path
		path = ResourceUID.path_to_uid(path)
		data.icon = path
	
	return data

func set_data(data: Dictionary):
	line_edit.text = data.element
	previous_name = data.element
	
	if &"icon" in data:
		resource_picker.edited_resource = load(data.icon)
		previous_resource = resource_picker.edited_resource

func delete() -> void:
	delete_request.emit()
