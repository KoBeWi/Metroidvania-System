@tool
extends Resource

@export var theme: MapTheme:
	set(t):
		if t == theme:
			return
		
		theme = t
		theme_changed.emit()

@export_dir var map_root_folder: String

@export_flags("Center", "Outline", "Borders", "Symbol") var unexplored_display := 3

@export var in_game_CELL_SIZE := Vector2(1152, 648)
@export var collectible_list: Array[Dictionary]

signal theme_changed
