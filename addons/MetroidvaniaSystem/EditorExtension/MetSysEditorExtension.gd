@tool
extends EditorPlugin

var button: Button
var current_instance: MetroidvaniaSystem.RoomInstance
var preview_list: Array[Control]
var hovered_preview: Control

func _enter_tree() -> void:
	button = Button.new()
	button.text = "Refresh Adjacent Previews"
	button.pressed.connect(_refresh)
	button.hide()
	
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, button)

func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, button)

func _make_visible(visible: bool) -> void:
	button.visible = visible

func _handles(object: Object) -> bool:
	return object is MetroidvaniaSystem.RoomInstance

func _edit(object: Object) -> void:
	if is_instance_valid(current_instance):
		current_instance.previews_updated.disconnect(update_preview_list_after_frame)
	
	current_instance = object
	
	if current_instance:
		update_preview_list()
		current_instance.previews_updated.connect(update_preview_list_after_frame)
	else:
		preview_list.clear()
		
		if is_instance_valid(hovered_preview):
			hovered_preview.set_hovered(false)
			hovered_preview = null

func _refresh():
	assert(current_instance)
	current_instance._update_neighbor_previews()

func update_preview_list():
	preview_list.assign(get_tree().get_nodes_in_group(&"_MetSys_RoomPreview_"))

func update_preview_list_after_frame():
	await get_tree().process_frame
	update_preview_list()

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		var new_hover: Control
		
		for preview in preview_list:
			if Rect2(Vector2(), preview.size).has_point(preview.get_local_mouse_position()):
				new_hover = preview
		
		if new_hover != hovered_preview:
			if is_instance_valid(hovered_preview):
				hovered_preview.set_hovered(false)
			
			if new_hover:
				new_hover.set_hovered(true)
			hovered_preview = new_hover
	
	elif event is InputEventMouseButton:
		if hovered_preview and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			EditorInterface.open_scene_from_path(MetSys.get_full_room_path(hovered_preview.tooltip_text))
			return true
	
	return false
