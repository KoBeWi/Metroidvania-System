@tool
extends Control

func _notification(what: int) -> void:
	if is_part_of_edited_scene():
		return
	
	if what == NOTIFICATION_THEME_CHANGED:
		%ValidationPanel.add_theme_stylebox_override(&"panel", get_theme_stylebox(&"panel", &"Tree"))

func edit_settings_pressed():
	EditorInterface.edit_resource(MetSys.settings)

func force_reload() -> void:
	MetSys.map_data = MetSys.MapData.new()
	MetSys.map_data.load_data()
	
	for group in MetSys.map_data.cell_groups.values():
		var i: int
		while i < group.size():
			if MetSys.map_data.get_cell_at(group[i]):
				i += 1
			else:
				group.remove_at(i)
	
	%"Map Editor".refresh()
	%"Map Viewer".refresh()
	owner.update_md_info()

func edit_database_theme() -> void:
	EditorInterface.edit_resource(owner.theme)

func reset_theme() -> void:
	%AllowReset.button_pressed = false
	
	var th: Theme = owner.theme
	th.set_color(&"cursor_color", &"MetSys", Color.GREEN)
	th.set_color(&"cursor_color_erase", &"MetSys", Color.RED)
	th.set_color(&"invalid_room_drop_position", &"MetSys", Color.RED)
	th.set_color(&"highlighted_room", &"MetSys", Color(Color.GREEN, 0.25))
	th.set_color(&"border_highlight", &"MetSys", Color(Color.GREEN, 0.5))
	th.set_color(&"group_color", &"MetSys", Color(Color.MEDIUM_PURPLE, 0.8))
	th.set_color(&"assigned_scene", &"MetSys", Color(Color.MEDIUM_SEA_GREEN, 0.8))
	th.set_color(&"active_custom_element", &"MetSys", Color(0.1, 0.1, 1, 0.8))
	th.set_color(&"inactive_custom_element", &"MetSys", Color(0, 0, 1, 0.4))
	th.set_color(&"custom_element_marker", &"MetSys", Color.YELLOW)
	th.set_color(&"current_scene_room", &"MetSys", Color(Color.RED, 0.5))
	th.set_color(&"room_assigned", &"MetSys", Color.WHITE)
	th.set_color(&"room_not_assigned", &"MetSys", Color.RED)
	th.set_color(&"marked_collectible_room", &"MetSys", Color(Color.BLUE_VIOLET, 0.75))
	th.set_color(&"foreign_marked_collectible_room", &"MetSys", Color(Color.RED, 0.25))
	th.set_color(&"hovered_room_preview_outline", &"MetSys", Color.YELLOW)
	th.set_color(&"hovered_room_preview_name", &"MetSys", Color.WHITE)
	ResourceSaver.save(th)

func toggle_allow_reset(button_pressed: bool) -> void:
	%ResetButton.disabled = not button_pressed

func refresh_custom_elements() -> void:
	var custom_script := MetSys.settings.custom_element_script
	MetSys.settings.custom_element_script = null
	MetSys.settings.custom_element_script = custom_script
	MetSys.settings.custom_elements_changed.emit()

func export_json() -> void:
	$FileDialog.popup_centered_ratio(0.6)

func json_file_selected(path: String) -> void:
	var map_data: Dictionary
	
	var cells: Dictionary
	map_data["cells"] = cells
	
	for cell in MetSys.map_data.cells:
		var cell_to_save: Dictionary
		cells["%s,%s,%s" % [cell.x, cell.y, cell.z]] = cell_to_save
		
		var cell_data := MetSys.map_data.get_cell_at(cell)
		cell_to_save["borders"] = cell_data.borders
		if cell_data.symbol > -1:
			cell_to_save["symbol"] = cell_data.symbol
		if cell_data.color.a > 0:
			cell_to_save["color"] = cell_data.color.to_html(false)
		if cell_data.border_colors.any(func(color: Color) -> bool: return color.a > 0):
			cell_to_save["border_colors"] = cell_data.border_colors.map(func(color: Color) -> String:
				return "000000" if color.a == 0 else color.to_html(false))
		if not cell_data.scene.is_empty():
			cell_to_save["scene"] = cell_data.scene
	
	var groups: Dictionary
	
	for group in MetSys.map_data.cell_groups:
		var group_cells: Array[Vector3i]
		group_cells.assign(MetSys.map_data.cell_groups[group])
		
		if group_cells.is_empty():
			continue
		
		var group_to_save: Array
		groups[group] = group_to_save
		
		for cell in group_cells:
			group_to_save.append("%s,%s,%s" % [cell.x, cell.y, cell.z])
	
	if not groups.is_empty():
		map_data["groups"] = groups
	
	var elements: Dictionary
	
	for element in MetSys.map_data.custom_elements:
		var element_to_save: Dictionary
		elements["%s,%s,%s" % [element.x, element.y, element.z]] = element_to_save
		
		var element_data := MetSys.map_data.custom_elements[element]
		element_to_save["name"] = element_data.name
		element_to_save["size"] = "%s,%s" % [element_data.size.x, element_data.size.y]
		if not element_data.data.is_empty():
			element_to_save["data"] = element_data.data
	
	if not elements.is_empty():
		map_data["custom_elements"] = elements
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(map_data, "\t"))
