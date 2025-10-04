extends CustomRunner

## The shortcut that will trigger the plugin.
func _init() -> void:
	SHORTCUT = KEY_F7

## If true, pressing the shortcut will invoke CustomRunner for that scene.
func _can_play_scene(scene: Node) -> bool:
	# Check if the current scene is a MetSys room scene.
	var room_instance := scene.get_node_or_null(^"RoomInstance")
	if room_instance:
		var scene_uid := ResourceUID.path_to_uid(room_instance.scene_file_path)
		if scene_uid == "uid://bsg0351mx3b4u":
			return true
	return false

## Add variables that will be passed to the game.
## Variable "scene", containing currently opened scene's path, is added automatically.
func _gather_variables(scene: Node):
	add_variable("mouse_pos", scene.get_local_mouse_position())
	# The room name as referenced by MetSys.
	add_variable("room", ResourceUID.path_to_uid(scene.scene_file_path))

## Return the path of the "game" scene of your project (i.e. main gameplay scene).
## If you return empty string, the current scene will play instead.
func _get_game_scene(for_scene: Node) -> String:
	return "res://SampleProject/CustomRunnerIntegration/CustomStart.tscn"
