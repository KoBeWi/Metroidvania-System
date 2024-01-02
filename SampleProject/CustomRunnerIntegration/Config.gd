extends CustomRunner

## The shortcut that will trigger the plugin.
func _init() -> void:
	SHORTCUT = KEY_F7

## If true, pressing the shortcut will invoke CustomRunner for that scene.
func _can_play_scene(scene: Node) -> bool:
	return scene is Node2D and scene.name == &"Map"

## Add variables that will be passed to the game.
## Variable "scene", containing currently opened scene's path, is added automatically.
func _gather_variables(scene: Node):
	add_variable("mouse_pos", scene.get_local_mouse_position())
	add_variable("room", scene.scene_file_path.trim_prefix(MetSys.settings.map_root_folder))

## Return the path of the "game" scene of your project (i.e. main gameplay scene).
## If you return empty string, the current scene will play instead.
func _get_game_scene(for_scene: Node) -> String:
	return "res://SampleProject/CustomRunnerIntegration/CustomStart.tscn"
