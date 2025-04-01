@tool
extends EditorPlugin

const EXTENSION_PATH = "MetroidvaniaSystem/EditorExtension"

enum { TAB_EDITOR, TAB_OVERVIEW, TAB_MANAGE }
enum { TOOL_PRINT_ID, TOOL_COPY_ID }

var main: Control
var theme_scanner: Timer
var prev_theme_state: Array
var translation_list: Array[Translation]

signal saved

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "MetSys"

func _get_plugin_icon() -> Texture2D:
	return load("res://addons/MetroidvaniaSystem/Icon.png")

func _enable_plugin() -> void:
	EditorInterface.set_plugin_enabled(EXTENSION_PATH, true)

func _disable_plugin() -> void:
	EditorInterface.set_plugin_enabled(EXTENSION_PATH, false)

func _enter_tree() -> void:
	theme_scanner = Timer.new()
	theme_scanner.wait_time = 0.6
	add_child(theme_scanner)
	theme_scanner.timeout.connect(check_theme)
	
	for file in DirAccess.get_files_at("res://addons/MetroidvaniaSystem/Translations"):
		if file.get_extension() == "po":
			translation_list.append(load("res://addons/MetroidvaniaSystem/Translations".path_join(file)))
	
	var editor_translation := TranslationServer.get_or_add_domain(&"godot.editor")
	for translation in translation_list:
		editor_translation.add_translation(translation)
	
	await get_tree().process_frame
	if not get_singleton():
		if FileAccess.file_exists("user://MetSysFail"):
			var dialog := ConfirmationDialog.new()
			dialog.title = "Error!"
			dialog.dialog_text = "MetSys restart failed, the singleton still can't be loaded. Make sure the \"MetroidvaniaSystem.gd\" script has no errors.\n\nCommon cause of errors are:\n- Using Godot version older than 4.2.\n- Name conflicts with one of the classes.\n\nThe plugin will be now disabled. Fix the errors and try again."
			EditorInterface.get_base_control().add_child(dialog)
			dialog.popup_centered()
			EditorInterface.set_plugin_enabled("MetroidvaniaSystem", false)
			
			DirAccess.remove_absolute("user://MetSysFail")
			return
		
		FileAccess.open("user://MetSysFail", FileAccess.WRITE)
		
		add_autoload_singleton("MetSys", "res://addons/MetroidvaniaSystem/Nodes/Singleton.tscn")
		ProjectSettings.save()
		OS.set_restart_on_exit(true, ["-e"])
		get_tree().quit()
		return
	else:
		if FileAccess.file_exists("user://MetSysFail"):
			DirAccess.remove_absolute("user://MetSysFail")
			EditorInterface.set_plugin_enabled(EXTENSION_PATH, true)
	
	main = load("res://addons/MetroidvaniaSystem/Database/Main.tscn").instantiate()
	main.plugin = self
	EditorInterface.get_editor_main_screen().add_child(main)
	main.hide()
	
	var metsys_tools := PopupMenu.new()
	metsys_tools.add_item("Print Object ID")
	metsys_tools.set_item_tooltip(-1, "Runs get_object_id() for the selected Node and prints the result.")
	metsys_tools.add_item("Copy Object ID to Clipboard")
	metsys_tools.set_item_tooltip(-1, "Runs get_object_id() for the selected Node and copies the result to clipboard.")
	
	add_tool_submenu_item("MetSys", metsys_tools)
	metsys_tools.index_pressed.connect(on_tool_option)
	
	EditorInterface.get_command_palette().add_command("Print Object ID", "met_sys/print_object_id", on_tool_option.bind(0))
	EditorInterface.get_command_palette().add_command("Copy Object ID to Clipboard", "met_sys/copy_object_id_to_clipboard", on_tool_option.bind(1))
	
	get_singleton().settings.theme_changed.connect(func(): prev_theme_state.clear())

func _exit_tree() -> void:
	var editor_translation := TranslationServer.get_or_add_domain(&"godot.editor")
	for translation in translation_list:
		editor_translation.remove_translation(translation)
	
	main.queue_free()
	remove_tool_menu_item("MetSys")
	
	EditorInterface.get_command_palette().remove_command("met_sys/print_object_id")
	EditorInterface.get_command_palette().remove_command("met_sys/copy_object_id_to_clipboard")

func _make_visible(visible: bool) -> void:
	main.visible = visible
	if visible:
		theme_scanner.start()
	else:
		theme_scanner.stop()

func _save_external_data() -> void:
	if not is_inside_tree():
		return
	
	get_singleton().map_data.save_data()
	saved.emit()

func _get_unsaved_status(for_scene: String) -> String:
	if for_scene.is_empty() and main.tabs.get_child(0).is_unsaved():
		return tr("MetSys map has been modified.\nDo you want to save?")
	return ""

func get_singleton():# -> MetroidvaniaSystem:
	return get_tree().root.get_node_or_null(^"MetSys")

func check_theme():
	var theme: MapTheme = get_singleton().settings.theme
	var changed := theme.check_for_changes(prev_theme_state)
	if not changed.is_empty():
		get_singleton().theme_modified.emit(changed)

func on_tool_option(idx: int):
	match idx:
		TOOL_PRINT_ID, TOOL_COPY_ID:
			var currrent_scene := EditorInterface.get_edited_scene_root()
			if not currrent_scene:
				push_error(tr("No scene open to check Node."))
				return
			
			var selection := EditorInterface.get_selection().get_selected_nodes()
			if selection.size() != 1:
				push_error(tr("You need to select a single Node."))
				return
			
			var id: String = get_singleton().get_object_id(selection[0])
			if id.is_empty():
				push_warning(tr("Could not determine ID."))
			else:
				if idx == TOOL_PRINT_ID:
					print(tr("ID of the selected Node is \"%s\".") % id)
				else:
					print(tr("ID \"%s\" copied to clipboard.") % id)
					DisplayServer.clipboard_set(id)

func POT_hack():
	tr("Error!")
	tr("MetSys restart failed, the singleton still can't be loaded. Make sure the \"MetroidvaniaSystem.gd\" script has no errors.\n\nCommon cause of errors are:\n- Using Godot version older than 4.4.\n- Name conflicts with one of the classes.\n\nThe plugin will be now disabled. Fix the errors and try again.")
	tr("Runs get_object_id() for the selected Node and prints the result.")
	tr("Runs get_object_id() for the selected Node and copies the result to clipboard.")
