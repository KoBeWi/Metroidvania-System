@tool
extends EditorPlugin

enum { TAB_EDITOR, TAB_OVERVIEW, TAB_MANAGE }

var main: Control
var modified: bool:
	set(m):
		if m == modified:
			return
		
		modified = m
		dirty_toggled.emit(modified)

var theme_scanner: Timer
var prev_theme_state: Array

signal dirty_toggled

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "MetSys"

func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/MetroidvaniaSystem/Icon.png")

func _enter_tree() -> void:
	theme_scanner = Timer.new()
	theme_scanner.wait_time = 0.6
	add_child(theme_scanner)
	theme_scanner.timeout.connect(check_theme)
	
	await get_tree().process_frame
	if not get_singleton():
		add_autoload_singleton("MetSys", "res://addons/MetroidvaniaSystem/Nodes/Singleton.tscn")
		ProjectSettings.save()
		OS.set_restart_on_exit(true, ["-e"])
		get_tree().quit()
		return
	
	main = preload("res://addons/MetroidvaniaSystem/Database/Main.tscn").instantiate()
	main.plugin = self
	get_editor_interface().get_editor_main_screen().add_child(main)
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
	get_singleton().map_data.save_data()
	modified = false

func _get_unsaved_status(for_scene: String) -> String:
	if modified and for_scene.is_empty():
		return "MetSys map has been modified."
	return ""

func get_singleton() -> MetroidvaniaSystem:
	return get_tree().root.get_node_or_null(^"MetSys")

func check_theme():
	var theme := get_singleton().settings.theme
	var changed := theme.check_for_changes(prev_theme_state)
	if not changed.is_empty():
		get_singleton().theme_modified.emit(changed)
