@tool
extends "res://addons/MetroidvaniaSystem/Scripts/EditorMapView.gd"

enum {MODE_LAYOUT = 1, MODE_ROOM_SYMBOL, MODE_ROOM_COLOR, MODE_ROOM_GROUP, MODE_BORDER_TYPE, MODE_BORDER_COLOR, MODE_MAP}

@export var mode_group: ButtonGroup

var theme_cache: Dictionary

var room_under_cursor: MetroidvaniaSystem.MapData.CellData
var current_hovered_item: Control
var extra_draw: Callable

func _ready() -> void:
	if not plugin:
		return
	super()
	
	plugin.scene_changed.connect(map_overlay.queue_redraw.unbind(1))
	MetSys.map_updated.connect(map.queue_redraw)

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		theme_cache.marked_collectible_room = get_theme_color(&"marked_collectible_room", &"MetSys")
		theme_cache.foreign_marked_collectible_room = get_theme_color(&"foreign_marked_collectible_room", &"MetSys")
		theme_cache.current_scene_room = get_theme_color(&"current_scene_room", &"MetSys")
		theme_cache.cursor_color = get_theme_color(&"cursor_color", &"MetSys")
		theme_cache.room_not_assigned = get_theme_color(&"room_not_assigned", &"MetSys")
		theme_cache.room_assigned = get_theme_color(&"room_assigned", &"MetSys")

func setup_new_layer(layer: MapView):
	layer._force_mapped = %MappedCheckbox.button_pressed
	layer._update_all_with_mapped.call_deferred()

func _on_item_hover(item: Control):
	item.mouse_exited.connect(_on_item_unhover.bind(item))
	current_hovered_item = item
	map_overlay.queue_redraw()

func _on_item_unhover(item: Control):
	item.mouse_exited.disconnect(_on_item_unhover)
	if item == current_hovered_item:
		current_hovered_item = null
		map_overlay.queue_redraw()

func _update_status_label():
	status_label.show()
	status_label.modulate = theme_cache.room_assigned
	if room_under_cursor and not room_under_cursor.assigned_scene.is_empty():
		status_label.text = str(get_cursor_pos(), " ", get_assigned_scene_display(room_under_cursor.assigned_scene))
	else:
		if room_under_cursor:
			status_label.modulate = theme_cache.room_not_assigned
		status_label.text = str(get_cursor_pos())

func _on_overlay_input(event: InputEvent) -> void:
	super(event)
	
	if event is InputEventMouseMotion:
		var cursor := get_cursor_pos()
		room_under_cursor = MetSys.map_data.get_cell_at(Vector3i(cursor.x, cursor.y, current_layer))
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and room_under_cursor and not room_under_cursor.assigned_scene.is_empty():
				EditorInterface.open_scene_from_path(MetSys.settings.map_root_folder.path_join(MetSys.map_data.get_uid_room(room_under_cursor.assigned_scene)))

func _on_overlay_draw() -> void:
	if not plugin:
		return
	
	var mouse := get_cursor_pos()
	
	if cursor_inside:
		map_overlay.draw_rect(Rect2(Vector2(mouse + map_offset) * MetSys.CELL_SIZE, MetSys.CELL_SIZE), theme_cache.cursor_color, false, 2)
	
	if get_tree().edited_scene_root and get_tree().edited_scene_root.scene_file_path.begins_with(MetSys.settings.map_root_folder):
		var current_scene := get_tree().edited_scene_root.scene_file_path
		
		for coords in MetSys.map_data.get_cells_assigned_to_path(current_scene):
			if coords.z != current_layer:
				break
			
			map_overlay.draw_rect(Rect2(Vector2(coords.x + map_offset.x, coords.y + map_offset.y) * MetSys.CELL_SIZE, MetSys.CELL_SIZE), theme_cache.current_scene_room)
	
	if current_hovered_item:
		var data: Dictionary = current_hovered_item.get_meta(&"data")
		if "coords" in data:
			var coords: Vector3i = data.coords
			map_overlay.draw_rect(Rect2(Vector2(coords.x + map_offset.x, coords.y + map_offset.y) * MetSys.CELL_SIZE, MetSys.CELL_SIZE), theme_cache.marked_collectible_room if coords.z == current_layer else theme_cache.foreign_marked_collectible_room)
		else:
			for coords in MetSys.map_data.get_cells_assigned_to(data.map):
				if coords.z != current_layer:
					break
				
				map_overlay.draw_rect(Rect2(Vector2(coords.x + map_offset.x, coords.y + map_offset.y) * MetSys.CELL_SIZE, MetSys.CELL_SIZE), theme_cache.marked_collectible_room)
				break
	
	if extra_draw.is_valid():
		extra_draw.call(map_overlay)

func toggle_mapped(toggled_on: bool) -> void:
	for map_view: MapView in layers.values():
		map_view._force_mapped = toggled_on
		map_view._update_all_with_mapped()
