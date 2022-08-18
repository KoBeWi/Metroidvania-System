extends Control

var highlighted = false
var post_highlighted = false

var room_data = Room.new()

func _ready():
#	room_data.holes.resize(room_data.size.x * room_data.size.y)
	rect_position = room_data.position * MetroidvaniaSettings.ROOM_SIZE

func toggle_hole(pos):
	if pos in room_data.holes:
		room_data.holes.erase(pos)
	else:
		room_data.holes.append(pos)
	
	update()

func _process(delta):
	if post_highlighted:
		post_highlighted = false
		update()
	elif highlighted:
		post_highlighted = true
		highlighted = false

func _draw():
	for x in room_data.size.x: for y in room_data.size.y:
		if Vector2(x, y) in room_data.holes: continue
		
		draw_set_transform(Vector2(), 0, Vector2(1, 1))
		draw_texture(MetroidvaniaSettings.room_fill_texture, Vector2(x, y) * MetroidvaniaSettings.ROOM_SIZE, MetroidvaniaSettings.room_fill_color if !highlighted else get_parent().highlight_color)
		if MetroidvaniaSettings.room_separator_texture: draw_texture(MetroidvaniaSettings.room_separator_texture, Vector2(x, y) * MetroidvaniaSettings.ROOM_SIZE, MetroidvaniaSettings.room_separator_color)
		
		if y == 0:
			draw_texture(MetroidvaniaSettings.room_wall_texture, Vector2(x, y) * MetroidvaniaSettings.ROOM_SIZE, MetroidvaniaSettings.room_wall_color)
		
		if x == 0:
			draw_set_transform(Vector2(x, y+1) * MetroidvaniaSettings.ROOM_SIZE, -PI/2, Vector2(1, 1))
			draw_texture(MetroidvaniaSettings.room_wall_texture, Vector2(), MetroidvaniaSettings.room_wall_color)
		
		if x == room_data.size.x-1:
			draw_set_transform(Vector2(x+1, y) * MetroidvaniaSettings.ROOM_SIZE, PI/2, Vector2(1, 1))
			draw_texture(MetroidvaniaSettings.room_wall_texture, Vector2(), MetroidvaniaSettings.room_wall_color)
		
		if y == room_data.size.y-1:
			draw_set_transform(Vector2(x+1, y+1) * MetroidvaniaSettings.ROOM_SIZE, PI, Vector2(1, 1))
			draw_texture(MetroidvaniaSettings.room_wall_texture, Vector2(), MetroidvaniaSettings.room_wall_color)
	
	highlighted = true
