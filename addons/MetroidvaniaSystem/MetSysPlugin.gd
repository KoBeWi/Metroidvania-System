@tool
extends EditorPlugin

const EXTENSION_PATH = "MetroidvaniaSystem/EditorExtension"

enum { TAB_EDITOR, TAB_OVERVIEW, TAB_MANAGE }

var main: Control
var theme_scanner: Timer
var prev_theme_state: Array

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
	
	get_singleton().settings.theme_changed.connect(func(): prev_theme_state.clear())

func _exit_tree() -> void:
	main.queue_free()

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
		return "MetSys map has been modified.\nDo you want to save?"
	return ""

func get_singleton():# -> MetroidvaniaSystem:
	return get_tree().root.get_node_or_null(^"MetSys")

func check_theme():
	var theme: MapTheme = get_singleton().settings.theme
	var changed := theme.check_for_changes(prev_theme_state)
	if not changed.is_empty():
		get_singleton().theme_modified.emit(changed)
