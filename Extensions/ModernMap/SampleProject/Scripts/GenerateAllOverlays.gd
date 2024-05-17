@tool
extends EditorScript

static var persist: EditorScript

func _run() -> void:
	persist = self
	
	var generator := preload("res://SampleProject/Scripts/GenerateOverlay.gd")
	for scene in MetSys.map_data.assigned_scenes:
		scene = MetSys.map_data.get_uid_room(scene)
		print("Generating %s..." % scene)
		EditorInterface.open_scene_from_path(MetSys.get_full_room_path(scene))
		
		await Engine.get_main_loop().process_frame
		await Engine.get_main_loop().process_frame
		
		var gen := generator.new()
		gen._run()
	
	persist = null
