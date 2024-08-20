extends RefCounted

const CellView = MetroidvaniaSystem.CellView

var begin: Vector2i
var size: Vector2i
var layer: int
var threaded: bool ## TODO

var visible: bool:
	set(v):
		visible = v
		RenderingServer.canvas_item_set_visible(_canvas_item, visible)

var _canvas_item: RID
var _cache: Dictionary#[Vector3i, CellView]

var _force_mapped: bool

func _init(parent_item: RID) -> void:
	_canvas_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_canvas_item, parent_item)
	recreate_cache.call_deferred()

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
		cell.update()

func update_cell(coords: Vector3i):
	var cell: CellView = _cache.get(coords)
	if cell:
		cell.update()
	else:
		push_error("MapView has no cell %s" % coords)

func update_rect(rect: Rect2i):
	for y in rect.size.y:
		for x in rect.size.x:
			update_cell(Vector3i(rect.position.x + x, rect.position.y + y, layer))

func _update_all_with_mapped():
	for cell: CellView in _cache.values():
		cell._force_mapped = _force_mapped
		cell.update()
