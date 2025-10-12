@tool
extends EditorPlugin

var button: Button
var current_instance: MetroidvaniaSystem.RoomInstance
var preview_list: Array[Control]
var hovered_preview: Control

var inspector_plugin: EditorInspectorPlugin
var export_plugin: EditorExportPlugin

func _enter_tree() -> void:
	button = Button.new()
	button.text = "Refresh Adjacent Previews"
	button.pressed.connect(_refresh)
	button.hide()
	
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, button)
	
	inspector_plugin = RoomLinkPlugin.new()
	add_inspector_plugin(inspector_plugin)
	
	export_plugin = MetSysExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, button)
	remove_inspector_plugin(inspector_plugin)
	remove_export_plugin(export_plugin)

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
	preview_list.clear()
	current_instance._update_neighbor_previews()

func update_preview_list():
	preview_list.assign(get_tree().get_nodes_in_group(&"_MetSys_RoomPreview_"))

func update_preview_list_after_frame():
	preview_list.clear()
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
			var zoom := EditorInterface.get_editor_viewport_2d().global_canvas_transform.get_scale().x
			var pos: Vector2
			
			var editor = EditorInterface.get_base_control().find_child("@CanvasItemEditorViewport*", true, false)
			var scroll = editor.find_child("@HScrollBar*", true, false)
			pos.x = scroll.value
			scroll = editor.find_child("@VScrollBar*", true, false)
			pos.y = scroll.value
			
			pos -= hovered_preview.offset * MetSys.settings.in_game_cell_size
			
			EditorInterface.open_scene_from_path(hovered_preview.scene)
			await get_tree().process_frame
			
			var zoomer = editor.find_child("@EditorZoomWidget*", true, false)
			zoomer.set_zoom(zoom)
			zoomer.zoom_changed.emit(zoom)
			
			scroll = editor.find_child("@HScrollBar*", true, false)
			scroll.value = pos.x
			scroll = editor.find_child("@VScrollBar*", true, false)
			scroll.value = pos.y
			
			var instance := EditorInterface.get_edited_scene_root().find_child("RoomInstance")
			
			var sel := EditorInterface.get_selection()
			sel.clear()
			sel.add_node(instance)
			
			return true
	
	return false

class RoomLinkPlugin extends EditorInspectorPlugin:
	func is_valid_property(type: int, hint: int, hint_string: String) -> bool:
		return type == TYPE_STRING and hint == PROPERTY_HINT_FILE and hint_string == "room_link"
	
	func _can_handle(object: Object) -> bool:
		for property in object.get_property_list():
			if is_valid_property(property["type"], property["hint"], property["hint_string"]):
				return true
		return false
	
	func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
		if not is_valid_property(type, hint_type, hint_string):
			return false
		
		var property := EditorPropertyRoomLink.new()
		property.set_object_and_property(object, name)
		add_property_editor(name, property)
		
		return true
	
	class EditorPropertyRoomLink extends EditorProperty:
		var room_label: Button
		var pick_button: Button
		var file_dialog: EditorFileDialog
		
		func _init() -> void:
			var hbox := HBoxContainer.new()
			add_child(hbox)
			
			room_label = Button.new()
			room_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			room_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(room_label)
			room_label.pressed.connect(_on_label_pressed, CONNECT_DEFERRED)
			room_label.set_drag_forwarding(Callable(), _can_drop_fw, _drop_fw)
			
			pick_button = Button.new()
			hbox.add_child(pick_button)
			pick_button.pressed.connect(_browse_file)
		
		func _notification(what: int) -> void:
			if what == NOTIFICATION_THEME_CHANGED:
				pick_button.icon = get_theme_icon(&"FileBrowse", &"EditorIcons")
		
		func _update_property() -> void:
			var value: String = get_edited_object().get(get_edited_property())
			if ResourceLoader.exists(value):
				room_label.text = ResourceUID.uid_to_path(value).get_file()
				room_label.tooltip_text = room_label.text
				room_label.icon = get_theme_icon(&"ExternalLink", &"EditorIcons")
				room_label.disabled = false
			else:
				room_label.tooltip_text = ""
				room_label.icon = null
				if value.is_empty():
					room_label.text = "Pick Scene..."
					room_label.disabled = false
				else:
					room_label.text = "<Invalid>"
					room_label.disabled = true
		
		func _browse_file():
			if not file_dialog:
				file_dialog = EditorFileDialog.new()
				file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
				file_dialog.add_filter("*.tscn,*.scn", "Scene File")
				add_child(file_dialog)
				file_dialog.file_selected.connect(_assign_scene)
			
			file_dialog.current_dir = MetSys.settings.get_scene_folder()
			file_dialog.popup_file_dialog()
		
		func _assign_scene(scene: String):
			emit_changed(get_edited_property(), ResourceUID.path_to_uid(scene))
			update_property()
			
			MetSys.settings._last_scene_folder = scene.get_base_dir()
		
		func _on_label_pressed():
			if room_label.tooltip_text.is_empty():
				_browse_file()
			else:
				EditorInterface.open_scene_from_path(get_edited_object().get(get_edited_property()))
		
		func _can_drop_fw(at_position: Vector2, data: Variant) -> bool:
			if data.get("type", "") != "files":
				return false
			
			var files: PackedStringArray = data.get("files", PackedStringArray())
			if files.size() != 1:
				return false
			
			var ext := files[0].get_extension()
			return ext == "tscn" or ext == "scn"
		
		func _drop_fw(at_position: Vector2, data: Variant) -> void:
			_assign_scene(data["files"][0])

class MetSysExportPlugin extends EditorExportPlugin:
	var map_data_path: String
	
	func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
		map_data_path = MetSys.map_data.get_map_data_path()
		var data := FileAccess.get_file_as_bytes(map_data_path)
		assert(not data.is_empty(), "Could not export map data file.")
		add_file(map_data_path, data, false)
	
	func _export_file(path: String, type: String, features: PackedStringArray) -> void:
		if path == map_data_path:
			skip()
