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
	main = preload("res://addons/MetroidvaniaSystem/Database/Main.tscn").instantiate()
	main.plugin = self
	get_editor_interface().get_editor_main_screen().add_child(main)
	main.hide()

func _exit_tree() -> void:
	main.queue_free()

func _make_visible(visible: bool) -> void:
	main.visible = visible

func _save_external_data() -> void:
	MetSys.map_data.save_data()
	modified = false

func _get_unsaved_status(for_scene: String) -> String:
	if modified:
		return "MetSys map has been modified."
	return ""
