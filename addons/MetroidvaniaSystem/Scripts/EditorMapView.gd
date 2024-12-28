extends Control

@onready var map_view_container: Control = $MapView
@onready var map_overlay: Control = %OverlayLayer
@onready var map: Node2D = %Map
@onready var current_layer_spinbox: Control = %CurrentLayer
@onready var status_label: Label = %StatusLabel
@onready var zoom_slider: HSlider = %ZoomSlider
@onready var zoom_value_label: Label = %ZoomValue

var plugin: EditorPlugin

var view_drag: Vector4
var map_offset := Vector2i(10, 10)

var current_layer: int
var cursor_inside: bool

var layers: Dictionary#[int, MapView]
var current_map_view: MapView

func _enter_tree() -> void:
	if owner:
		plugin = owner.plugin

func _ready() -> void:
	$Sidebar.custom_minimum_size.x = 200 * EditorInterface.get_editor_scale()
	
	map_overlay.mouse_exited.connect(status_label.hide)
	map_overlay.gui_input.connect(_on_overlay_input)
	map_overlay.draw.connect(_on_overlay_draw)
	
	current_layer_spinbox.value_changed.connect(on_layer_changed)
	%RecenterButton.pressed.connect(on_recenter_view)
	zoom_slider.value_changed.connect(on_zoom_changed)
	
	map_view_container.mouse_entered.connect(set.bind(&"cursor_inside", true))
	map_view_container.mouse_exited.connect(set.bind(&"cursor_inside", false))
	
	status_label.hide()
	await get_tree().process_frame
	
	on_layer_changed(0)
	update_map_position()
	
	MetSys.settings.theme_changed.connect(refresh)
	MetSys.theme_modified.connect(refresh.unbind(1))

func refresh():
	update_map_position()
	layers.clear()
	on_layer_changed(current_layer)

func get_cursor_pos() -> Vector2i:
	var pos := (map_overlay.get_local_mouse_position() - MetSys.CELL_SIZE / 2).snapped(MetSys.CELL_SIZE) / MetSys.CELL_SIZE as Vector2i - map_offset
	return pos

func on_layer_changed(l: int):
	if current_map_view:
		current_map_view.visible = false
	
	current_layer = l
	
	var new_map_view: MapView = layers.get(current_layer)
	if not new_map_view:
		var map_extents := MetSys.settings.map_extents
		new_map_view = MetSys.make_map_view(map, Vector2i(-map_extents, -map_extents), Vector2i(map_extents * 2, map_extents * 2), current_layer)
		new_map_view.queue_updates = true
		setup_new_layer(new_map_view)
		layers[current_layer] = new_map_view
	
	current_map_view = new_map_view
	current_map_view.visible = true

func setup_new_layer(layer: MapView):
	pass

func on_recenter_view() -> void:
	map_offset = Vector2i(10, 10)
	update_map_position()

func on_zoom_changed(new_zoom: float):
	zoom_value_label.text = "x%0.1f" % new_zoom
	var new_zoom_vector := Vector2.ONE * new_zoom
	map.scale = new_zoom_vector
	map_overlay.scale = new_zoom_vector
	update_map_position()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if view_drag != Vector4():
			if event.position.x >= map_overlay.size.x:
				map_view_container.warp_mouse(Vector2(event.position.x - map_overlay.size.x, event.position.y))
				view_drag.x -= map_overlay.size.x
			elif event.position.x < 0:
				map_view_container.warp_mouse(Vector2(map_overlay.size.x + event.position.x, event.position.y))
				view_drag.x += map_overlay.size.x
			
			if event.position.y >= map_overlay.size.y:
				map_view_container.warp_mouse(Vector2(event.position.x, event.position.y - map_overlay.size.y))
				view_drag.y -= map_overlay.size.y
			elif event.position.y < 0:
				map_view_container.warp_mouse(Vector2(event.position.x, map_overlay.size.y + event.position.y))
				view_drag.y += map_overlay.size.y
			
			map_offset = Vector2(view_drag.z, view_drag.w) + (map_overlay.get_local_mouse_position() - Vector2(view_drag.x, view_drag.y)) / MetSys.CELL_SIZE
			update_map_position()
			map_overlay.queue_redraw()
		else:
			map_overlay.queue_redraw()
		
		_update_status_label()
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				view_drag.x = map_overlay.get_local_mouse_position().x
				view_drag.y = map_overlay.get_local_mouse_position().y
				view_drag.z = map_offset.x
				view_drag.w = map_offset.y
			else:
				view_drag = Vector4()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed and event.is_command_or_control_pressed():
				zoom_slider.value += zoom_slider.step * (-1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else 1)

func _update_status_label():
	status_label.show()
	status_label.text = str(get_cursor_pos())

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_Q:
			current_layer_spinbox._on_prev_pressed()
			accept_event()
		elif event.physical_keycode == KEY_E:
			current_layer_spinbox._on_next_pressed()
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if map_overlay:
			map_overlay.queue_redraw()

func _on_overlay_draw() -> void:
	pass

func update_map_position():
	map.position = Vector2(map_offset - Vector2i.ONE * MetSys.settings.map_extents) * MetSys.CELL_SIZE * map.scale

func get_assigned_scene_display(assigned_scene: String) -> String:
	if assigned_scene.begins_with(":"):
		var uid := assigned_scene.replace(":", "uid://")
		assigned_scene = "%s (%s)" % [ResourceUID.get_id_path(ResourceUID.text_to_id(uid)).trim_prefix(MetSys.settings.map_root_folder), uid]
	
	return assigned_scene
