@tool
extends Button

const FoundElement = preload("uid://cdl44ebe6tc0h").FoundElement

@onready var scan_progress: ProgressBar = %ScanProgress
@onready var show_on_map: CheckButton = %ShowOnMap
@onready var summary: VBoxContainer = %Summary
@onready var scan_button: Button = %ScanButton
@onready var finder: Control = %Finder

var thread: Thread
var found_elements: Array[FoundElement]

func _ready() -> void:
	scan_progress.hide()
	show_on_map.hide()
	exit()

func _pressed() -> void:
	for button in button_group.get_buttons():
		button.exit()
	
	finder.show()

func exit():
	finder.hide()

func start_scan() -> void:
	summary.hide()
	scan_button.disabled = true
	
	var collectible_list: Array[FoundElement]
	collectible_list.assign(%CollectibleList.get_children().map(func(item: Node) -> FoundElement: return item.get_data()))
	
	found_elements.clear()
	for item in summary.get_children():
		item.free()
	
	thread = Thread.new()
	thread.start(scan_maps.bind(collectible_list))
	set_process(true)

func _process(delta: float) -> void:
	if not thread:
		set_process(false)
		return
	
	if thread.is_alive():
		return
	
	thread.wait_to_finish()
	thread = null
	
	scan_progress.hide()
	show_on_map.show()
	summary.show()
	scan_button.disabled = false
	
	for item in %CollectibleList.get_children():
		var data: FoundElement = item.get_data()
		var count := 0
		var count_label := setup_header(data)
		
		for found in found_elements:
			if found.element != data.element:
				continue
			
			count += 1
			setup_found(found)
		
		count_label.text = str(count)
		summary.add_child(HSeparator.new())

func scan_maps(element_list: Array[FoundElement]):
	Thread.set_thread_safety_checks_enabled(false)
	
	var scenes: Array[String]
	scenes.assign(MetSys.map_data.assigned_scenes.keys())
	#var folders: Array[String] # TODO?
	#folders.append(MetSys.settings.map_data_file)
	#
	#while not folders.is_empty():
		#var folder := folders.pop_back()
		#folders.append_array(Array(DirAccess.get_directories_at(folder)).map(func(subfolder: String) -> String: return folder.path_join(subfolder)))
		#maps.append_array(Array(DirAccess.get_files_at(folder)).map(func(file: String) -> String: return folder.path_join(file)))
	
	scan_progress.max_value = scenes.size()
	scan_progress.value = 0
	scan_progress.show()
	show_on_map.hide()
	
	for scene in scenes:
		var lines := FileAccess.open(scene, FileAccess.READ).get_as_text().split("\n")
		
		var current_element: FoundElement
		for line in lines:
			if current_element:
				if line.begins_with("["):
					found_elements.append(current_element)
					current_element = null
				elif line.begins_with("position ="):
					current_element.position = str_to_var(line.get_slice("=", 1))
				else:
					continue
			
			for element in element_list:
				if line.begins_with("[node name=\"%s" % element.element):
					current_element = element.make_result()
					current_element.scene = scene
					break
		
		if current_element:
			found_elements.append(current_element)
		
		scan_progress.value += 1

func setup_header(data: FoundElement) -> Label:
	var hbox := HBoxContainer.new()
	summary.add_child(hbox)
	
	var tex := TextureRect.new()
	hbox.add_child(tex)
	tex.texture = data.icon
	
	var label := Label.new()
	hbox.add_child(label)
	label.text = data.element
	
	label = Label.new()
	hbox.add_child(label)
	
	return label

func setup_found(data: FoundElement):
	var label := Label.new()
	summary.add_child(label)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.set_meta(&"data", data)
	
	
	var room := MetSys.map_data.get_cells_assigned_to(data.scene)
	var room_name := ResourceUID.uid_to_path(data.scene).get_file()
	
	if data.position.is_finite() and not room.is_empty():
		var top_left := Vector2i.MAX
		for coords in room:
			top_left.x = mini(coords.x, top_left.x)
			top_left.y = mini(coords.y, top_left.y)
		
		var pos := top_left + Vector2i(data.position / MetSys.settings.in_game_cell_size)
		data.coords = Vector3i(pos.x, pos.y, room[0].z)
		label.text = "%s %s" % [room_name, data.coords]
	else:
		label.text = "%s" % room_name
	
	label.mouse_entered.connect(owner._on_item_hover.bind(label))

func toggle_display_on_map(toggled_on: bool) -> void:
	if toggled_on:
		owner.extra_draw = draw_collectibles_on_map
	else:
		owner.extra_draw = Callable()
	owner.map_overlay.queue_redraw()

func draw_collectibles_on_map(canvas_item: CanvasItem):
	for element in found_elements:
		var icon: Texture2D = element.icon
		if not icon:
			continue
		
		var target_size := icon.get_size() * (minf(MetSys.CELL_SIZE.x, MetSys.CELL_SIZE.y) / minf(icon.get_width(), icon.get_height()) * 0.9)
		if element.coords != Vector3i.MAX:
			var coords := element.coords
			if coords.z != owner.current_layer:
				continue
			
			var pos := Vector2(coords.x + owner.map_offset.x, coords.y + owner.map_offset.y) * MetSys.CELL_SIZE
			canvas_item.draw_texture_rect(icon, Rect2(pos + MetSys.CELL_SIZE * 0.5 - target_size * 0.5, target_size), false)
		else:
			for coords in MetSys.map_data.get_cells_assigned_to(element.map):
				if coords.z != owner.current_layer:
					break
				
				var pos := Vector2(coords.x + owner.map_offset.x, coords.y + owner.map_offset.y) * MetSys.CELL_SIZE
				canvas_item.draw_texture_rect(icon, Rect2(pos + MetSys.CELL_SIZE * 0.5 - target_size * 0.5, target_size), false)
				break
