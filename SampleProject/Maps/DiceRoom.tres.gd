extends Area2D

var generating: bool

func _on_body_entered(body: Node2D) -> void:
	if generating:
		return
	generating = true
	%TileMap.set_layer_enabled(2, true)
	
	%DiceAnimator.play(&"Spin")
	var tween := create_tween()
	tween.tween_property(%DiceAnimator, ^"speed_scale", 4.0, 4.0)
	tween.tween_interval(randf_range(1.0, 2.0))
	tween.tween_property(%DiceAnimator, ^"speed_scale", 0.0, 2.0)
	
#	await tween.finished
	
	var builder := MetSys.get_map_builder()
	
	var start := builder.create_room(Vector3i(0, -7, 2))
	start.set_assigned_map("Procedural/Generated".path_join(generate_room("Junction.tscn")))
	start = builder.create_room(Vector3i(1, -7, 2)) # test
	start.set_assigned_map("Procedural/Generated".path_join(generate_room("Junction.tscn")))
	
	builder.update_map()
	generating = false
	%TileMap.set_layer_enabled(2, false)

func generate_room(from_map: String):
	from_map = from_map.get_basename()
	var new_map := from_map + "1.tscn"
	var files := DirAccess.get_files_at("res://SampleProject/Maps/Procedural/Generated")
	
	var i := 1
	while new_map in files:
		i += 1
		new_map = str(from_map, i, ".tscn")
	
	DirAccess.copy_absolute(
		MetSys.settings.map_root_folder.path_join("Procedural").path_join(from_map) + ".tscn",
		MetSys.settings.map_root_folder.path_join("Procedural/Generated").path_join(new_map))
	
	return new_map
