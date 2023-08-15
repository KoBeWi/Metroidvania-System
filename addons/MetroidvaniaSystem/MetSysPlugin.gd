@tool
extends EditorPlugin

enum { TAB_EDITOR, TAB_OVERVIEW, TAB_MANAGE }

var main: Control
var modified: bool

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "MetSys"

func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/MetroidvaniaSystem/Icon.png")

func _enter_tree() -> void:
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

func _exit_tree() -> void:
	main.queue_free()
	remove_autoload_singleton("MetSys")

func _make_visible(visible: bool) -> void:
	main.visible = visible

func _save_external_data() -> void:
	get_singleton().map_data.save_data()
	modified = false

func _get_unsaved_status(for_scene: String) -> String:
	if modified:
		return "MetSys map has been modified."
	return ""

func get_singleton() -> MetroidvaniaSystem:
	return get_tree().root.get_node_or_null(^"MetSys")
