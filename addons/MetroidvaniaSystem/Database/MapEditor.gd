@tool
extends "res://addons/MetroidvaniaSystem/Scripts/MapView.gd"

@onready var ghost_map: Control = %GhostMap
@onready var grid: Control = %Grid

@export var mode_group: ButtonGroup

var mode: int
var preview_layer := -1

var undo_redo: UndoRedo
var saved_version := 1

func _ready() -> void:
	if not plugin:
		return
	
	undo_redo = UndoRedo.new()
	%Shortcuts.hide()
	
	plugin.saved.connect(mark_saved)
	await super()
	
	mode_group.pressed.connect(mode_pressed)
	get_current_sub_editor()._editor_enter()
	MetSys.settings.theme_changed.connect(grid.queue_redraw)
	map_overlay.mouse_entered.connect(map_overlay.grab_focus)

func mode_pressed(button: BaseButton):
	get_current_sub_editor()._editor_exit()
	mode = button.get_index() - 1
	get_current_sub_editor()._editor_enter()
	
	map_overlay.queue_redraw()

func on_layer_changed(l: int):
	super(l)
	ghost_map.queue_redraw()

func preview_layer_changed(value: float) -> void:
	preview_layer = value
	ghost_map.queue_redraw()

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

func _on_drag():
	ghost_map.queue_redraw()

func _on_overlay_draw() -> void:
	if not plugin:
		return
	
	super()
	map_overlay.draw_set_transform(Vector2(map_offset) * MetSys.CELL_SIZE)
	
	var sub := get_current_sub_editor()
	sub.top_draw = Callable()
	sub._editor_draw(map_overlay)
	
	if sub.top_draw.is_valid():
		sub.top_draw.call(map_overlay)

func _on_ghost_map_draw() -> void:
	if not plugin:
		return
	
	if preview_layer == -1 or preview_layer == current_layer:
		return
	
	for x in range(-100, 100):
		for y in range(-100, 100):
			MetSys.draw_cell(ghost_map, Vector2i(x, y) + map_offset, Vector3i(x, y, preview_layer), true, false)

func _on_grid_draw() -> void:
	if not plugin:
		return
	
	var empty_texture: Texture2D = MetSys.settings.theme.empty_space_texture
	for x in ceili(grid.size.x / MetSys.CELL_SIZE.x):
		for y in ceili(grid.size.y / MetSys.CELL_SIZE.y):
			if empty_texture:
				grid.draw_texture(empty_texture, Vector2(x, y) * MetSys.CELL_SIZE)
			else:
				grid.draw_rect(Rect2(Vector2(x, y) * MetSys.CELL_SIZE, MetSys.CELL_SIZE), Color(Color.WHITE, 0.1), false)

func on_zoom_changed(new_zoom: float):
	super(new_zoom)
	var new_zoom_vector := Vector2.ONE * new_zoom
	ghost_map.scale = new_zoom_vector
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if undo_redo:
			undo_redo.free()
			undo_redo = null
