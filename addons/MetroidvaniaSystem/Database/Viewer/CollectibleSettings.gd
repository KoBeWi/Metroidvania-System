@tool
extends Button

func _ready() -> void:
	if is_part_of_edited_scene():
		return
	
	await get_tree().process_frame
	_pressed()
	
	for data in MetSys.settings._collectible_list:
		var collectible := add_collectible()
		collectible.set_data(data)

func _pressed() -> void:
	for button in button_group.get_buttons():
		button.exit()
	
	%Settings.show()

func exit():
	%Settings.hide()

func add_collectible() -> Control:
	var collectible := preload("uid://w48b71tv2d4v").instantiate()
	%CollectibleList.add_child(collectible)
	collectible.save_request.connect(save_collectible_list)
	return collectible

func save_collectible_list():
	var list: Array[Dictionary]
	for collectible in %CollectibleList.get_children():
		if not collectible.is_queued_for_deletion():
			list.append(collectible.get_save_data())
	MetSys.settings._collectible_list = list
	ResourceSaver.save(MetSys.settings)
