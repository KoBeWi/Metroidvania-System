## Displays a portion of the map on a [CanvasItem].
##
## [MapView] is a low-level interface for displaying map data. It's very optimized, capable of drawing large maps and update them partially. This is an advanced feature, for basic needs consider using Minimap.tscn.
class_name MapView extends RefCounted

const CellView = MetroidvaniaSystem.CellView
const CustomElement = MetroidvaniaSystem.MapData.CustomElement
const _SURROUND = [Vector3i(-1, -1, 0), Vector3i(0, -1, 0), Vector3i(1, -1, 0), Vector3i(-1, 0, 0), Vector3i(1, 0, 0), Vector3i(-1, 1, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0)]

## Coordinates of the top-left corner of the displayed area. Changing this value will internally call [method move] and only update edge cells whenever possible.
var begin: Vector2i:
	set(b):
		if _begin == Vector2i.MAX:
			_begin = b
		elif b != _begin:
			move(b - begin)
	get:
		return _begin

## Size of the displayed area, in cells. Changing this value after the map is initialized will not work properly until you call [method recreate_cache].
var size: Vector2i

## The currently displayed layer. Changing this value will update all displayed cells.
var layer: int:
	set(l):
		if _layer < 0:
			_layer = l
		elif l != layer:
			move(Vector2i(), l)
			_layer = l
	get:
		return _layer

var _begin: Vector2i = Vector2i.MAX
var _layer: int = -1

## If [code]true[/code], empty and undiscovered cells will not appear on map. Has no effect if [MapTheme.empty_space_texture] is not defined, as the cells won't display anyway.
var skip_empty: bool

## If [code]true[/code], cells won't be updated immediately when calling update methods. Instead the update will be queued and done in a batch at the end of the frame. It's especially useful to avoid duplicate updates.
var queue_updates: bool
#var threaded: bool

## Whether the map should be visible or not. You can also set visibility of the parent [CanvasItem].
var visible: bool:
	set(v):
		visible = v
		RenderingServer.canvas_item_set_visible(_canvas_item, visible)

var _canvas_item: RID
var _cache: Dictionary#[Vector3i, CellView]
var _custom_elements_cache: Dictionary#[Vector3i, CustomElementInstance]
var _update_queue: Array[RefCounted]

var _force_mapped: bool

func _init(parent_item: RID) -> void:
	_canvas_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_canvas_item, parent_item)
	recreate_cache.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		RenderingServer.free_rid(_canvas_item)

## Discards all cached cells and initializes the whole map again. This method can update cell coordinates and map size, but it's rarely needed to be called manually.
func recreate_cache():
	_cache.clear()
	_custom_elements_cache.clear()
	var shared_borders: bool = MetSys.settings.theme.use_shared_borders
	
	var prev_row: Array[CellView]
	for y in size.y:
		var current_row: Array[CellView]
		current_row.resize(size.x)
		
		for x in size.x:
			var coords := Vector3i(begin.x + x, begin.y + y, layer)
			var cell := CellView.new(_canvas_item)
			cell.coords = coords
			cell.offset = Vector2(x, y)
			_cache[coords] = cell
			current_row[x] = cell
			
			if shared_borders:
				if x > 0:
					cell._left_cell = current_row[x - 1]
				if y > 0:
					cell._top_cell = prev_row[x]
				if x > 0 and y > 0:
					cell._top_left_cell = prev_row[x - 1]
		
		prev_row = current_row
	
	var rect := Rect2i(begin, size)
	var element_manager: MetroidvaniaSystem.CustomElementManager = MetSys.settings.custom_elements
	var element_list: Dictionary = MetSys.map_data.custom_elements
	
	for coords in element_list:
		if coords.z != layer:
			continue
		
		var element: CustomElement = element_list[coords]
		var element_rect := Rect2i(coords.x, coords.y, element["size"].x, element["size"].y)
		if not element_rect.intersects(rect):
			continue
		
		_make_custom_element_instance(coords, element)
	
	var was_queue := queue_updates
	queue_updates = false
	update_all()
	queue_updates = was_queue

## Moves the [member begin] by the given offset. If the new map area intersects with the previous one, only the newly displayed cells will be redrawn. However if you change the layer, all cells will be updated.
func move(offset: Vector2i, new_layer := layer):
	_begin += offset
	
	if new_layer != layer:
		_layer = new_layer
		recreate_cache()
		return
	elif offset == Vector2i():
		return
	
	var shared_borders: bool = MetSys.settings.theme.use_shared_borders
	var new_cache: Dictionary#[Vector3i, CellView]
	for y in size.y:
		for x in size.x:
			var coords := Vector3i(begin.x + x, begin.y + y, layer)
			var cell: CellView = _cache.get(coords)
			if not cell:
				cell = CellView.new(_canvas_item)
				cell.coords = coords
				cell.update()
			
			cell.offset = Vector2(x, y)
			new_cache[coords] = cell
			
			if shared_borders:
				if x > 0:
					cell._left_cell = new_cache[coords + Vector3i(-1, 0, 0)]
				else:
					cell._left_cell = null
				
				if y > 0:
					cell._top_cell = new_cache[coords + Vector3i(0, -1, 0)]
				else:
					cell._top_cell = null
				
				if x > 0 and y > 0:
					cell._top_left_cell = new_cache[coords + Vector3i(-1, -1, 0)]
				else:
					cell._top_left_cell = null
	
	var rect := Rect2i(_begin, size)
	var element_manager: MetroidvaniaSystem.CustomElementManager = MetSys.settings.custom_elements
	var element_list: Dictionary = MetSys.map_data.custom_elements
	
	var element_offset: Vector2 = Vector2(offset) * MetSys.CELL_SIZE
	for coords in _custom_elements_cache.keys():
		var element: CustomElementInstance = _custom_elements_cache[coords]
		var element_rect := Rect2i(coords.x, coords.y, element.base_element.size.x, element.base_element.size.y)
		
		if element_rect.intersects(rect):
			element.offset -= element_offset
			element.update()
		else:
			_custom_elements_cache.erase(coords)
	
	for coords in element_list:
		if coords.z != layer:
			continue
		
		if coords in _custom_elements_cache:
			continue
		
		var element: CustomElement = element_list[coords]
		var element_rect := Rect2i(coords.x, coords.y, element["size"].x, element["size"].y)
		if not element_rect.intersects(rect):
			continue
		
		_make_custom_element_instance(coords, element).update()
	
	_cache = new_cache

## Same as [method move], but moves to absolute coordinates instead of by offset.
func move_to(coords: Vector3i):
	move(Vector2i(coords.x, coords.y) - _begin, coords.z)

func _make_custom_element_instance(coords: Vector3i, element: CustomElement) -> CustomElementInstance:
	var element_instance := CustomElementInstance.new(_canvas_item)
	element_instance.coords = coords
	element_instance.offset = Vector2(-begin + Vector2i(coords.x, coords.y)) * MetSys.CELL_SIZE
	element_instance.base_element = element
	_custom_elements_cache[coords] = element_instance
	return element_instance

## Updates all currently visible cells. This will only refresh their state (symbols, colors etc.), while keeping the current coordinates. It's recommended to call this when [signal MetroidvaniaSystem.map_updated] is received (the [MapView] does not do it automatically).
func update_all():
	for cell: CellView in _cache.values():
		_update_cell(cell)
	for element: CustomElementInstance in _custom_elements_cache.values():
		_update_element(element)
	
	RenderingServer.canvas_item_clear(_canvas_item)
	if skip_empty:
		return
	
	var empty_texture: Texture2D = MetSys.settings.theme.empty_space_texture
	
	if empty_texture:
		var texture_rid := empty_texture.get_rid()
		var texture_size := empty_texture.get_size()
		for y in size.y:
			for x in size.x:
				RenderingServer.canvas_item_add_texture_rect(_canvas_item, Rect2(Vector2(x, y) * MetSys.CELL_SIZE, texture_size), texture_rid)

## Updates a specific cell. Prints error if no cell with the given [param coords] is visible. See also [method update_all].
func update_cell(coords: Vector3i):
	var exists: bool
	
	var cell: CellView = _cache.get(coords)
	if cell:
		_update_cell(cell)
		if MetSys.settings.theme.use_shared_borders:
			for delta in _SURROUND:
				var cell2: CellView = _cache.get(coords + delta)
				if cell2:
					_update_cell(cell2)
		
		exists = true
	
	var custom_element = _custom_elements_cache.get(coords)
	if custom_element:
		_update_element(custom_element)
		exists = true
	
	if not exists:
		push_error("MapView has no cell nor custom element at %s" % coords)

## Updates all cells inside the given rect. Prints errors if the rect goes outside bounds of the [MapView]. See also [method update_all].
func update_rect(rect: Rect2i):
	for y in rect.size.y:
		for x in rect.size.x:
			update_cell(Vector3i(rect.position.x + x, rect.position.y + y, layer))

func _update_cell(cell: CellView):
	if not queue_updates:
		cell.update()
		return
	
	if _update_queue.is_empty():
		_update_queued.call_deferred()
	
	if not cell in _update_queue:
		_update_queue.append(cell)

func _update_element(element: CustomElementInstance):
	if not queue_updates:
		element.update()
		return
	
	if _update_queue.is_empty():
		_update_queued.call_deferred()
	
	if not element in _update_queue:
		_update_queue.append(element)

func _update_queued():
	for cell in _update_queue:
		cell.update()
	_update_queue.clear()

func _update_all_with_mapped():
	for cell: CellView in _cache.values():
		cell._force_mapped = _force_mapped
		cell.update()

class CustomElementInstance:
	var canvas_item: RID
	var coords: Vector3i
	var offset: Vector2
	var base_element: CustomElement
	
	func _init(parent_item: RID) -> void:
		canvas_item = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(canvas_item, parent_item)
		RenderingServer.canvas_item_set_z_index(canvas_item, 3)
	
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			RenderingServer.free_rid(canvas_item)
			canvas_item = RID()
	
	func update():
		RenderingServer.canvas_item_clear(canvas_item)
		
		var size := base_element.size
		var element_rect := Rect2i(coords.x, coords.y, size.x, size.y)
		MetSys.settings.custom_elements.draw_element(canvas_item, coords, base_element.name, offset, Vector2(element_rect.size) * MetSys.CELL_SIZE, base_element.data)
