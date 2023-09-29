@tool
extends PanelContainer

signal hovered
signal unhovered

var data: Dictionary

func set_element(element: Dictionary):
	data = element
	%Label.text = data.element
	%Icon.texture = data.get("icon")
	data.map = data.map.trim_prefix(MetSys.settings.map_root_folder)
	
	var room := MetSys.map_data.get_cells_assigned_to(data.map)
	if "position" in data and not room.is_empty():
		var top_left := Vector2i.MAX
		for coords in room:
			top_left.x = mini(coords.x, top_left.x)
			top_left.y = mini(coords.y, top_left.y)
		
		var pos := top_left + Vector2i(data.position / MetSys.settings.in_game_cell_size)
		data.coords = Vector3i(pos.x, pos.y, room[0].z)
		%Button.tooltip_text = "%s\nat: %s %s" % [data.element, data.map, data.coords]
	else:
		%Button.tooltip_text = "%s\nat: %s" % [data.element, data.map]

func on_hover() -> void:
	hovered.emit()

func on_unhover() -> void:
	unhovered.emit()
