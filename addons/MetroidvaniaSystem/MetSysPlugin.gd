@tool
extends EditorPlugin

var main: CanvasItem

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "MetSys"

func _get_plugin_icon() -> Texture2D:
	return preload("res://addons/MetroidvaniaSystem/Icon.png")

func _enter_tree() -> void:
	main = preload("res://addons/MetroidvaniaSystem/Main.tscn").instantiate()
	get_editor_interface().get_editor_main_screen().add_child(main)
	main.hide()

func _exit_tree() -> void:
	main.queue_free()

func _make_visible(visible: bool) -> void:
	main.visible = visible

func _save_external_data() -> void:
	MetSys.map_data.save_data()
