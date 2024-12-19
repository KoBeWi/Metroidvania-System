extends Node2D

var offset: Vector2
var exact: bool

func _ready() -> void:
	exact = MetSys.settings.theme.show_exact_player_location
	z_index = 5

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			process_mode = Node.PROCESS_MODE_INHERIT
		else:
			process_mode = Node.PROCESS_MODE_DISABLED

func _process(delta: float) -> void:
	var last_player_position_2d := Vector2(MetSys.last_player_position.x, MetSys.last_player_position.y)
	var player_position := last_player_position_2d * MetSys.CELL_SIZE + MetSys.CELL_SIZE / 2
	if exact:
		player_position += (MetSys.exact_player_position / MetSys.settings.in_game_cell_size).posmod(1) * MetSys.CELL_SIZE - MetSys.CELL_SIZE * 0.5
	
	position = player_position + offset
