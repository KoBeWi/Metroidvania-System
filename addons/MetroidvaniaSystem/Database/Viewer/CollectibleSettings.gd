@tool
extends Button

@onready var collectible_list: VBoxContainer = %CollectibleList

var initialized: bool

func _ready() -> void:
	if is_part_of_edited_scene():
		return
	
	MetSys.editor_plugin.presaved.connect(save_collectible_list)
	%Settings.show()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not initialized and is_visible_in_tree() and is_node_ready():
			for data in MetSys.settings._collectible_list:
				var collectible := add_collectible(false)
				collectible.set_data(data)
			
			initialized = true

func _pressed() -> void:
	%Settings.show()

func exit():
	%Settings.hide()

func add_collectible(with_undo: bool) -> Control:
	var collectible := preload("uid://w48b71tv2d4v").instantiate()
	collectible.delete_request.connect(delete_collectible.bind(collectible))
	
	var undo_redo := EditorInterface.get_editor_undo_redo()
	if with_undo:
		undo_redo.create_action(tr("Add Collectible"))
		undo_redo.add_do_method(collectible_list, &"add_child", collectible)
		undo_redo.add_do_reference(collectible)
		undo_redo.add_undo_method(collectible_list, &"remove_child", collectible)
		undo_redo.commit_action()
	else:
		collectible_list.add_child(collectible)
	return collectible

func delete_collectible(collectible: Node):
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action(tr("Remove Collectible"))
	undo_redo.add_do_method(collectible_list, &"remove_child", collectible)
	undo_redo.add_undo_method(collectible_list, &"add_child", collectible)
	undo_redo.add_undo_method(collectible_list, &"move_child", collectible, collectible.get_index())
	undo_redo.add_undo_reference(collectible)
	undo_redo.commit_action()

func save_collectible_list():
	if not initialized:
		return
	
	var list: Array[Dictionary]
	for collectible in %CollectibleList.get_children():
		if not collectible.is_queued_for_deletion():
			list.append(collectible.get_save_data())
	MetSys.settings._collectible_list = list
	ResourceSaver.save(MetSys.settings)
