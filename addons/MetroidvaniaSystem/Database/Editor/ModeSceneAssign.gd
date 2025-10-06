@tool
extends "res://addons/MetroidvaniaSystem/Database/Editor/SubEditor.gd"#"uid://cyob148ixrqef"

@onready var file_dialog: EditorFileDialog = $FileDialog
@onready var create_dialog: ConfirmationDialog = $CreateDialog

@onready var scene_name: LineEdit = %SceneName
@onready var scene_extension: OptionButton = %SceneExtension
@onready var root_name: LineEdit = %RootName
@onready var error_label: Label = %ErrorLabel
@onready var ok_button := create_dialog.get_ok_button()

func _editor_init() -> void:
	use_cursor = false
	overlay_mode = true
	create_dialog.register_text_enter(scene_name)

func _update_theme():
	theme_cache.assigned_scene = get_theme_color(&"assigned_scene", &"MetSys")

func _editor_enter():
	super()
	%SceneAssign.show()

func _editor_exit():
	super()
	%SceneAssign.hide()

func _editor_input(event: InputEvent):
	if event is InputEventMouseMotion:
		var hr := highlighted_room
		highlighted_room = MetSys.map_data.get_whole_room(get_coords(get_cursor_pos()))
		if highlighted_room != hr:
			redraw_overlay()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not highlighted_room.is_empty():
					file_dialog.current_dir = MetSys.settings.get_scene_folder()
					file_dialog.popup_centered_ratio(0.6)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				var prev_scene := clear_scene(highlighted_room)
				if prev_scene.is_empty():
					return
				
				undo_handle_scene_remove(highlighted_room.duplicate(), prev_scene)
				undo_end_with_redraw()
				MetSys.room_assign_updated.emit()
				redraw_overlay()

func _editor_draw(map_overlay: CanvasItem):
	super(map_overlay)

	for coords in MetSys.map_data.assigned_scenes.values():
		if coords[0].z != editor.current_layer:
			continue
		
		for p in coords:
			map_overlay.draw_rect(Rect2(Vector2(p.x, p.y) * MetSys.CELL_SIZE, MetSys.CELL_SIZE), theme_cache.assigned_scene)

	if not highlighted_room.is_empty():
		map_overlay.draw_set_transform_matrix(Transform2D())
		map_overlay.draw_string(get_theme_font(&"font", &"Label"), Vector2(0, 40),
				editor.get_assigned_scene_display(MetSys.map_data.get_cell_at(highlighted_room.front()).scene))

func clear_scene(from: Array[Vector3i]) -> String:
	if from.is_empty():
		return ""
	
	var current_scene: String = MetSys.map_data.get_cell_at(from[0]).scene
	if current_scene.is_empty():
		return ""
	else:
		MetSys.map_data.assigned_scenes.erase(current_scene)
	
	for p in from:
		var cell_data := MetSys.map_data.get_cell_at(p)
		cell_data.scene = ""
	
	return current_scene

func on_map_selected(scene: String) -> void:
	MetSys.settings._last_scene_folder = scene.get_base_dir()
	
	scene = ResourceUID.path_to_uid(scene)
	var prev_scene := clear_scene(highlighted_room)
	
	var current_assigned: Array[Vector3i]
	current_assigned.assign(MetSys.map_data.assigned_scenes.get(scene, []))
	
	if not current_assigned.is_empty():
		var other_prev_scene := clear_scene(current_assigned)
		undo_handle_scene_remove(current_assigned, other_prev_scene)
	
	MetSys.map_data.assigned_scenes[scene] = []
	for coords in highlighted_room:
		var cell_data := MetSys.map_data.get_cell_at(coords)
		cell_data.scene = scene
		MetSys.map_data.assigned_scenes[scene].append(coords)
	
	undo_handle_scene_add(highlighted_room.duplicate(), prev_scene)
	undo_end_with_redraw()
	
	MetSys.room_assign_updated.emit()
	redraw_overlay()

func create_new_scene() -> void:
	file_dialog.hide()
	create_dialog.popup_centered()
	scene_name.grab_focus.call_deferred()
	
	scene_name.clear()
	validate_scene()

func validate_scene():
	var scene_name_text := scene_name.text
	
	if scene_name_text.is_empty():
		set_error(tr("Scene name can't be empty."))
		return
	elif not scene_name_text.is_valid_filename():
		set_error(tr("Scene name contains invalid characters."))
		return
	elif not root_name.text.is_empty() and not root_name.text.is_valid_identifier():
		set_error(tr("Root node invalid."))
		return
	
	if FileAccess.file_exists(get_scene_path()):
		set_error(tr("File already exists."))
		return
	
	set_error("")

func set_error(error: String):
	error_label.text = error
	ok_button.disabled = not error.is_empty()

func create_default_scene() -> Node:
	var root := Node2D.new()
	if root_name.text.is_empty():
		root.name = &"Map"
	else:
		root.name = root_name.text
	
	var instance: MetroidvaniaSystem.RoomInstance = load("uid://bsg0351mx3b4u").instantiate()
	root.add_child(instance)
	instance.owner = root
	
	return root

func create_scene_confirm() -> void:
	var root: Node
	if not MetSys.settings.scene_template.is_empty():
		var scene: PackedScene = load(MetSys.settings.scene_template)
		if scene:
			root = scene.instantiate()
			if root:
				root.scene_file_path = ""
				if not root_name.text.is_empty():
					root.name = root_name.text
			else:
				push_error("Failed to instantiate template scene.")
		else:
			push_error("Failed to load template scene.")
	
	if not root:
		root = create_default_scene()
	
	var scene := PackedScene.new()
	scene.pack(root)
	
	var scene_path := get_scene_path()
	ResourceSaver.save(scene, scene_path)
	root.queue_free()
	
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.open_scene_from_path(scene_path)
	on_map_selected(scene_path)

func get_scene_name() -> String:
	var neym := scene_name.text
	if not neym.ends_with("."):
		neym += "."
	return neym + scene_extension.get_item_text(scene_extension.selected)

func get_scene_path() -> String:
	return file_dialog.current_dir.path_join(get_scene_name())

func can_drop_data(at_position: Vector2, data) -> bool:
	if highlighted_room.is_empty():
		return false
	
	if data.get("type", "") != "files" or data["files"].size() != 1:
		return false
	
	var file: String = data["files"][0]
	if file.get_extension() != "tscn" and file.get_extension() != "scn":
		return false
	
	return true

func drop_data(at_position: Vector2, data) -> void:
	on_map_selected(data["files"][0])
