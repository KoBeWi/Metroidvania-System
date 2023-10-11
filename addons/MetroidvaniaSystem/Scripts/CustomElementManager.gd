@tool
## A class that registers and draws custom elements.
##
## Custom elements are map elements that are too complex to be handled as regular cells. Example elements include location name labels, Metroid-like elevator shafts or room contents inside cell. Internally they are represented as rectangles with an origin point and a [String] extra data.
## [br][br]To use custom elements, create a new script that inherits this one and assign it to [code]custom_element_script[/code] property in MetSys Settings. Register your elements by calling [method register_elements] inside [method Object._init] then press Refresh Custom Elements button in the Manage tab of MetSys Database. This will create an instance of your script and the elements will be available in Custom Elements edit mode of the editor. You need to call [method MetroidvaniaSystem.draw_custom_elements] to draw the elements on your map.
extends RefCounted

var custom_elements: Dictionary

## Registers a new element. The [param name] will appear in the editor (capitalized) and [param draw_callback] will be used to draw your element. The callback is called automatically when the element needs to be drawn.
## [br][br]The callback signature is [code]method(canvas_item: CanvasItem, coords: Vector3i, pos: Vector2, size: Vector2, data: String)[/code]. [code]canvas_item[/code] is the [CanvasItem] that you should use to draw the elements, [code]coords[/code] are the coordinates of the origin point of the element, [code]pos[/code] is the position of the element's origin in pixels, [code]size[/code] is the size of the element's rectangle in pixels, [code]data[/code] is the data [String] that was assigned to the element.
## [br][br]Example draw callback that draws a label if the cell was discovered:
## [codeblock]
## func draw_label(canvas_item: CanvasItem, coords: Vector3i, pos: Vector2, size: Vector2, data: String):
##     if not MetSys.is_cell_discovered(coords):
##         return
##
##     canvas_item.draw_string(ThemeDB.get_default_theme().default_font,
##     pos + Vector2(-1, -0.5) * MetSys.CELL_SIZE, data, HORIZONTAL_ALIGNMENT_CENTER, MetSys.CELL_SIZE.x * 3)
func register_element(name: String, draw_callback: Callable):
	custom_elements[name.replace("/", "_")] = draw_callback

func draw_element(canvas_item: CanvasItem, coords: Vector3i, name: String, pos: Vector2, size: Vector2, data: String):
	var callback: Callable = custom_elements[name]
	callback.call(canvas_item, coords, pos, size, data)
