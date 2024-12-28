@tool
extends "res://addons/MetroidvaniaSystem/Scripts/EditorMapView.gd"

@onready var grid: Control = %Grid
var viewer_layers: Dictionary

@export var mode_group: ButtonGroup

var mode: int
var preview_layer := -1

var preview_layers: Dictionary#[int, MapView]

var undo_redo: UndoRedo
var saved_version := 1

func _ready() -> void:
	if not plugin:
		return
	
	undo_redo = UndoRedo.new()
	%Shortcuts.hide()
	
	plugin.saved.connect(mark_saved)
	await super()
	
	viewer_layers = %"Map Viewer".layers
	
	mode_group.pressed.connect(mode_pressed)
	get_current_sub_editor()._editor_enter()
	MetSys.settings.theme_changed.connect(grid.queue_redraw)
	map_overlay.mouse_entered.connect(map_overlay.grab_focus)
	map_overlay.set_drag_forwarding(Callable(), _on_overlay_can_drop_data, _on_overlay_drop_data)

func refresh():
	preview_layers.clear()
	super()

func mode_pressed(button: BaseButton):
	get_current_sub_editor()._editor_exit()
	mode = button.get_index() - 1
	get_current_sub_editor()._editor_enter()
	
	map_overlay.queue_redraw()

func on_layer_changed(l: int):
	if preview_layer > -1 and current_layer == preview_layer:
		preview_layer_changed(preview_layer)
	
	super(l)
	
	if preview_layer > -1 and current_layer != preview_layer:
		preview_layer_changed(preview_layer)

func preview_layer_changed(value: float) -> void:
	if preview_layer > -1:
		var prev_preview_layer: MapView = preview_layers.get(preview_layer)
		if prev_preview_layer:
			prev_preview_layer.visible = false
	
	preview_layer = value
	if preview_layer == -1 or preview_layer == current_layer:
		return
	
	var new_preview_layer: MapView = preview_layers.get(preview_layer)
	if not new_preview_layer:
		var map_extents := MetSys.settings.map_extents
		new_preview_layer = MetSys.make_map_view(map, Vector2i(-map_extents, -map_extents), Vector2i(map_extents * 2, map_extents * 2), preview_layer)
		new_preview_layer.skip_empty = true
		RenderingServer.canvas_item_set_modulate(new_preview_layer._canvas_item, Color(1, 1, 1, 0.5))
		new_preview_layer.queue_updates = true
		preview_layers[preview_layer] = new_preview_layer
	
	new_preview_layer.visible = true

func get_current_sub_editor() -> Control:
	return mode_group.get_buttons()[mode]

func _on_overlay_input(event: InputEvent) -> void:
	super(event)
	get_current_sub_editor()._editor_input(event)
	
	if event is InputEventKey:
		if event.pressed and event.is_command_or_control_pressed():
			if event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed):
				if undo_redo.redo():
					update_name()
					print("MetSys redo")
				accept_event()
			elif event.keycode == KEY_Z:
				if undo_redo.undo():
					update_name()
					print("MetSys undo")
				accept_event()

func _on_overlay_draw() -> void:
	if not plugin:
		return
	
	map_overlay.draw_set_transform(Vector2(map_offset) * MetSys.CELL_SIZE)
	
	var sub := get_current_sub_editor()
	sub.top_draw = Callable()
	sub._editor_draw(map_overlay)
	
	if sub.top_draw.is_valid():
		sub.top_draw.call(map_overlay)

func _on_grid_draw() -> void:
	if not plugin:
		return
	
	if MetSys.settings.theme.empty_space_texture:
		return
	
	for x in ceili(grid.size.x / MetSys.CELL_SIZE.x):
		for y in ceili(grid.size.y / MetSys.CELL_SIZE.y):
			grid.draw_rect(Rect2(Vector2(x, y) * MetSys.CELL_SIZE, MetSys.CELL_SIZE), Color(Color.WHITE, 0.1), false)

func on_zoom_changed(new_zoom: float):
	super(new_zoom)
	var new_zoom_vector := Vector2.ONE * new_zoom
	grid.scale = new_zoom_vector

func update_name():
	if is_unsaved():
		name = "Map Editor(*)"
	else:
		name = "Map Editor"

func is_unsaved() -> bool:
	return undo_redo.get_version() != saved_version

func mark_saved():
	saved_version = undo_redo.get_version()
	update_name()

func update_cell(coords: Vector3i):
	current_map_view.update_cell(coords)
	var other: MapView = preview_layers.get(current_layer)
	if other:
		other.update_cell(coords)
	other = viewer_layers.get(current_layer)
	if other:
		other.update_cell(coords)

func update_rect(rect: Rect2i):
	current_map_view.update_rect(rect)
	var other: MapView = preview_layers.get(current_layer)
	if other:
		other.update_rect(rect)
	other = viewer_layers.get(current_layer)
	if other:
		other.update_rect(rect)

func _on_overlay_can_drop_data(at_pos: Vector2, data) -> bool:
	return get_current_sub_editor().can_drop_data(at_pos, data)

func _on_overlay_drop_data(at_pos: Vector2, data) -> void:
	get_current_sub_editor().drop_data(at_pos, data)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if undo_redo:
			undo_redo.free()
			undo_redo = null
