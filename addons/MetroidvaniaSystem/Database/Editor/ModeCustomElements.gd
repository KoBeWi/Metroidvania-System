@tool
extends "res://addons/MetroidvaniaSystem/Database/Editor/SubEditor.gd"#"uid://cyob148ixrqef"

const CustomElement = MetroidvaniaSystem.MapData.CustomElement

var current_element: String

func _editor_init() -> void:
	room_only_cursor = false
	overlay_mode = true
	MetSys.settings.custom_elements_changed.connect(reload_custom_elements)
	
	reload_custom_elements()

func _update_theme():
	theme_cache.active_custom_element = get_theme_color(&"active_custom_element", &"MetSys")
	theme_cache.inactive_custom_element = get_theme_color(&"inactive_custom_element", &"MetSys")
	theme_cache.custom_element_marker = get_theme_color(&"custom_element_marker", &"MetSys")

func reload_custom_elements():
	for element in %CustomElementContainer.get_children():
		element.queue_free()
	current_element = ""
	
	if not MetSys.settings.custom_elements or MetSys.settings.custom_elements._custom_elements.is_empty():
		%NoElements.show()
		return
	else:
		%NoElements.hide()
	
	var element_group := ButtonGroup.new()
	
	for element in MetSys.settings.custom_elements._custom_elements:
		var button := CheckBox.new()
		button.text = str(element).capitalize()
		button.button_group = element_group
		button.pressed.connect(set_current_element.bind(element))
		%CustomElementContainer.add_child(button)
		
		if not element_group.get_pressed_button():
			button.button_pressed = true
			set_current_element(element)

func _editor_enter():
	%CustomElements.show()

func _editor_exit():
	%CustomElements.hide()

func set_current_element(element: String):
	current_element = element
	redraw_overlay()

func _editor_draw(map_overlay: CanvasItem):
	super(map_overlay)
	
	var custom_elements := MetSys.map_data.custom_elements
	for coords in custom_elements:
		if coords.z != editor.current_layer:
			continue
		
		var element_color: Color
		var element: CustomElement = custom_elements[coords]
		if element.name == current_element:
			element_color = theme_cache.active_custom_element
		else:
			element_color = theme_cache.inactive_custom_element
		
		map_overlay.draw_rect(Rect2(Vector2(coords.x, coords.y) * MetSys.CELL_SIZE, Vector2(element.size) * MetSys.CELL_SIZE), element_color)
		
		var square := minf(MetSys.CELL_SIZE.x, MetSys.CELL_SIZE.y)
		map_overlay.draw_rect(Rect2((Vector2(coords.x, coords.y) + Vector2(0.5, 0.5)) * MetSys.CELL_SIZE - Vector2.ONE * square * 0.5, Vector2.ONE * square).grow(-square * 0.2), theme_cache.custom_element_marker)

func _editor_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_from = get_cursor_pos()
			else:
				var rect := get_rect_between(drag_from, get_cursor_pos())
				add_element(rect)
				undo_end_with_redraw()
				drag_from = Vector2i.MAX
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				var coords := Vector3i(get_cursor_pos().x, get_cursor_pos().y, editor.current_layer)
				if coords in MetSys.map_data.custom_elements:
					undo_handle_element_remove(coords, MetSys.map_data.custom_elements[coords])
					MetSys.map_data.custom_elements.erase(coords)
					editor.current_map_view._update_element_at(coords)
					undo_end_with_redraw()

func add_element(rect: Rect2i):
	var element := CustomElement.new()
	element.name = current_element
	element.size = rect.size
	element.data = %CustomData.text
	
	var coords := Vector3i(rect.position.x, rect.position.y, editor.current_layer)
	MetSys.map_data.custom_elements[coords] = element
	
	undo_handle_element_add(coords, element)
	editor.current_map_view._update_element_at(coords)
