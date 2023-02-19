@tool
extends EditorPlugin

const TARGET_PLUGIN = "MetroidvaniaSystem"

func _unhandled_key_input(event: InputEvent) -> void:
	if TARGET_PLUGIN.is_empty():
		return
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		if get_editor_interface().is_plugin_enabled(TARGET_PLUGIN):
			get_editor_interface().set_plugin_enabled(TARGET_PLUGIN, false)
			print(str("Plugin ", TARGET_PLUGIN, " disabled."))
		else:
			get_editor_interface().set_plugin_enabled(TARGET_PLUGIN, true)
			if get_editor_interface().is_plugin_enabled(TARGET_PLUGIN):
				print(str("Plugin ", TARGET_PLUGIN, " enabled."))
			else:
				print(str("Plugin ", TARGET_PLUGIN, " failed to load."))
