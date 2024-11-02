extends RefCounted

const CellView = MetroidvaniaSystem.CellView

var begin: Vector2i
var size: Vector2i
var layer: int
var queue_updates: bool
var threaded: bool ## TODO

var visible: bool:
	set(v):
		visible = v
		RenderingServer.canvas_item_set_visible(_canvas_item, visible)

var _canvas_item: RID
var _cache: Dictionary#[Vector3i, CellView]
var _update_queue: Array[CellView]

var _force_mapped: bool

func _init(parent_item: RID) -> void:
	_canvas_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_canvas_item, parent_item)
	recreate_cache.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		RenderingServer.free_rid(_canvas_item)

func recreate_cache():
	_cache.clear()
	
	for y in size.y:
		for x in size.x:
			var coords := Vector3i(begin.x + x, begin.y + y, layer)
			var cell := CellView.new(_canvas_item)
			cell._coords = coords
			cell.offset = Vector2(x, y)
			_cache[coords] = cell
	
	update_all()

func update_all():
	for cell: CellView in _cache.values():
		_update_cell(cell)

func update_cell(coords: Vector3i):
	var cell: CellView = _cache.get(coords)
	if cell:
		_update_cell(cell)
	else:
		push_error("MapView has no cell %s" % coords)

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

func _update_queued():
	for cell in _update_queue:
		cell.update()
	_update_queue.clear()

func _update_all_with_mapped():
	for cell: CellView in _cache.values():
		cell._force_mapped = _force_mapped
		cell.update()
