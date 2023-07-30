@tool
extends RefCounted

var custom_elements: Dictionary

func register_element(name: String, draw_callback: Callable):
	custom_elements[name.replace("/", "_")] = draw_callback

func draw_element(canvas_item: CanvasItem, coords: Vector3i, name: String, pos: Vector2, size: Vector2, data: String):
	var callback: Callable = custom_elements[name]
	callback.call(canvas_item, coords, pos, size, data)
