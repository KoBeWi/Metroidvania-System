@tool
## A class that registers and draws custom elements.
##
## Custom elements are map elements that are too complex to be handled as regular cells. Example elements include location name labels, Metroid-like elevator shafts or room contents inside cells. Internally they are represented as rectangles with an origin point and a [String] extra data.
## [br][br]To use custom elements, create a new script that inherits this one and assign it to [code]custom_element_script[/code] property in MetSys Settings. Register your elements by calling [method register_elements] inside [method Object._init] then press Refresh Custom Elements button in the Manage tab of MetSys Database. This will create an instance of your script and the elements will be available in Custom Elements edit mode of the editor.
extends RefCounted

var _custom_elements: Dictionary#[String, Callable]

## Registers a new element. The [param name] will appear in the editor (capitalized) and [param draw_callback] will be used to draw your element. The callback is called automatically when the element needs to be drawn.
## [br][br]The callback signature is [code]method(canvas_item: RID, coords: Vector3i, pos: Vector2, size: Vector2, data: String)[/code]. [code]canvas_item[/code] is the [CanvasItem] that you should use to draw the elements, [code]coords[/code] are the coordinates of the origin point of the element, [code]pos[/code] is the position of the element's origin in pixels, [code]size[/code] is the size of the element's rectangle in pixels, [code]data[/code] is the data [String] that was assigned to the element.
## [br][br]Note that, since the [code]canvas_item[/code] is provided as [RID], you'll need to draw elements using methods that take RID (mainly in [RenderingServer]).
## [br][br]Example draw callback that draws a label if the cell was discovered:
## [codeblock]
## func draw_label(canvas_item: CanvasItem, coords: Vector3i, pos: Vector2, size: Vector2, data: String):
##     if not MetSys.is_cell_discovered(coords):
##         return
##     
##     var font := ThemeDB.get_default_theme().default_font
##     font.draw_string(canvas_item,
##         pos + Vector2(-1, -0.5) * MetSys.CELL_SIZE, data, HORIZONTAL_ALIGNMENT_CENTER, MetSys.CELL_SIZE.x * 3)
func register_element(name: String, draw_callback: Callable):
	_custom_elements[name.replace("/", "_")] = draw_callback

func draw_element(canvas_item: RID, coords: Vector3i, name: String, pos: Vector2, size: Vector2, data: String):
	var callback: Callable = _custom_elements[name]
	callback.call(canvas_item, coords, pos, size, data)
