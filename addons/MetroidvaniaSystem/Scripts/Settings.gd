@tool
extends Resource

@export var theme: MapTheme:
	set(t):
		theme = t
		if Engine.get_main_loop() and Engine.get_main_loop().root.has_node(^"MetSys"):
			MetSys._update_theme()

@export_dir var map_root_folder: String

@export_flags("Center", "Outline", "Borders", "Symbol") var unexplored_display := 3

@export var in_game_room_size := Vector2(1152, 648)
