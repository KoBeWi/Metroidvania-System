## A MetSys module for gradually discovering rooms.
##
## The module integrates with "overlay" custom element. When player moves within a room, portions of the room surrounding the player will be discovered. The discovered data is stored in your save file.
@tool
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysModule.gd"

## Path to overlays directory. Every room needs a corresponding overlay to display properly. You can use GenerateOverlay.gd from Sample Project to generate it or make a custom one.
const OVERLAYS_PATH = "res://SampleProject/Sprites/Overlays"
## Radius in which the player discovers the room's area. This is expressed in in-game cell size, not map size.
const DISCOVER_RADIUS = 120.0

static var fom

var base_overlays: Dictionary#[String, Texture2D]
var discover_cache: Dictionary#[String, Texture2D]
var overlay_cache: Dictionary#[String, Texture2D]

var discover_render: SubViewport
var discover_clear: TextureRect
var empty_texture: ImageTexture
var discover: Sprite2D
var compositor: SubViewport
var compositor_base: TextureRect
var player_pos_ratio: Vector2

var current_room: String
var last_player_pos := Vector2.INF
var blocked: bool

func _initialize():
	fom = self
	
	if Engine.is_editor_hint():
		return
	
	game.room_loaded.connect(on_new_room)
	MetSys.room_changed.connect(pre_new_room)
	MetSys.get_tree().physics_frame.connect(tick)
	
	discover_render = SubViewport.new()
	discover_render.render_target_update_mode = SubViewport.UPDATE_DISABLED
	discover_render.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	game.add_child(discover_render)
	
	var empty_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	empty_image.fill(Color.BLACK)
	empty_texture = ImageTexture.create_from_image(empty_image)
	
	discover_clear = TextureRect.new()
	discover_clear.texture = empty_texture
	discover_clear.set_anchors_preset(Control.PRESET_FULL_RECT)
	discover_render.add_child(discover_clear)
	
	var grad := preload("res://addons/MetroidvaniaSystem/Template/Scripts/Modules/FogDiscoverGradient.tres")
	grad.width = DISCOVER_RADIUS * 2
	grad.height = DISCOVER_RADIUS * 2
	
	discover = Sprite2D.new()
	discover.texture = grad
	discover_render.add_child(discover)
	
	compositor = SubViewport.new()
	compositor.transparent_bg = true
	game.add_child(compositor)
	
	compositor_base = TextureRect.new()
	compositor_base.material = preload("res://addons/MetroidvaniaSystem/Template/Scripts/Modules/FogMaterial.tres")
	compositor_base.material.set_shader_parameter(&"mask", discover_render.get_texture())
	compositor_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	compositor.add_child(compositor_base)
	
	player_pos_ratio = MetSys.CELL_SIZE / MetSys.settings.in_game_cell_size

func pre_new_room(room: String):
	if not current_room.is_empty():
		var image := compositor.get_texture().get_image()
		overlay_cache[current_room] = ImageTexture.create_from_image(image)
		image = discover_render.get_texture().get_image()
		discover_cache[current_room] = ImageTexture.create_from_image(image)
	
	blocked = true
	discover.hide()
	current_room = MetSys.map_data.get_uid_room(room)

func on_new_room():
	var prev_room := current_room
	if not blocked:
		await MetSys.room_changed
	
	current_room = MetSys.map_data.get_assigned_scene_at(MetSys.get_current_coords())
	if current_room.is_empty() or current_room == prev_room:
		current_room = MetSys.get_current_room_name()
	current_room = MetSys.map_data.get_uid_room(current_room)
	
	compositor_base.texture = get_base_overlay_texture(current_room)
	compositor.size = compositor_base.texture.get_size()
	
	var room := MetSys.get_current_room_instance()
	discover_render.size = MetSys.CELL_SIZE * (Vector2(room.get_end_coords() - room.get_base_coords()) + Vector2(1, 1))
	
	discover_clear.texture = discover_cache.get(current_room, empty_texture)
	discover_clear.show()
	discover_render.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	discover_clear.hide()
	
	discover.show()
	MetSys.map_updated.emit()
	
	await MetSys.get_tree().process_frame
	blocked = false
	tick()

func tick():
	if not game.can_process() or blocked:
		return
	
	var player_pos := MetSys.exact_player_position
	if player_pos != last_player_pos:
		discover.position = player_pos * player_pos_ratio
		last_player_pos = player_pos
		discover_render.render_target_update_mode = SubViewport.UPDATE_ONCE

func get_base_overlay_texture(room: String) -> Texture2D:
	room = MetSys.map_data.get_uid_room(room)
	var overlay_path := OVERLAYS_PATH.path_join(room + ".png")
	
	if not ResourceLoader.exists(overlay_path):
		push_error("Missing overlay for room \"%s\" expected at path \"%s\"." % [room, overlay_path])
		return null
	
	var texture: Texture2D = base_overlays.get_or_add(room, load(overlay_path))
	return texture

func get_drawable_overlay_texture(room: String) -> Texture2D:
	room = MetSys.map_data.get_uid_room(room)
	if Engine.is_editor_hint():
		return get_base_overlay_texture(room)
	elif room == current_room:
		compositor.get_texture().get_image().save_png("res://.godot/dump.png")
		return compositor.get_texture()
	else:
		return overlay_cache.get(room)

func _get_save_data() -> Dictionary:
	var data: Dictionary
	for room in discover_cache:
		var texture: Texture2D = discover_cache[room]
		data[room] = texture.get_image().save_png_to_buffer()
	return data

func _set_save_data(data: Dictionary):
	var overlays_to_cache: PackedStringArray
	
	for room in data:
		var image_data: PackedByteArray = data[room]
		var image := Image.new()
		image.load_png_from_buffer(image_data)
		discover_cache[room] = ImageTexture.create_from_image(image)
		overlays_to_cache.append(room)
	
	if not overlays_to_cache.is_empty():
		cache_overlays_from_discovers(overlays_to_cache)

func cache_overlays_from_discovers(overlays_to_cache: PackedStringArray):
	var sub_compositor: SubViewport = compositor.duplicate()
	sub_compositor.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game.add_child(sub_compositor)
	
	var sub_compositor_base: TextureRect = sub_compositor.get_child(0)
	sub_compositor_base.material = sub_compositor_base.material.duplicate()
	
	for room in overlays_to_cache:
		sub_compositor_base.material.set_shader_parameter(&"mask", discover_cache[room])
		sub_compositor_base.texture = get_base_overlay_texture(room)
		sub_compositor.size = sub_compositor_base.texture.get_size()
		
		await RenderingServer.frame_post_draw
		
		overlay_cache[room] = ImageTexture.create_from_image(sub_compositor.get_texture().get_image())
	
	MetSys.map_updated.emit()
	sub_compositor.queue_free()

static func draw_overlay(canvas_item: RID, coords: Vector3i, pos: Vector2, size: Vector2):
	if not MetSys.is_cell_discovered(coords):
		return
	
	if Engine.is_editor_hint() and not fom:
		fom = load("res://addons/MetroidvaniaSystem/Template/Scripts/Modules/FogOfMystery.gd").new(null)
	
	var room := MetSys.map_data.get_assigned_scene_at(coords)
	var overlay: Texture2D = fom.get_drawable_overlay_texture(room)
	if overlay:
		overlay.draw_rect(canvas_item, Rect2(pos, size), false)
