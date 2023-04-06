@tool
extends Resource

@export var theme: MapTheme:
	set(t):
		theme = t
		if Engine.get_main_loop() and Engine.get_main_loop().root.has_node(^"MetSys"):
			MetSys.map_updated.emit()

@export_dir var map_root_folder: String

@export_flags("Center", "Outline", "Borders", "Symbol") var unexplored_display := 3

@export var uncollected_item_symbol := -1
@export var collected_item_symbol := -1
@export var map_borders: Array[Texture2D]
@export var map_symbols: Array[Texture2D]

@export var in_game_room_size := Vector2(1152, 648)

func _init() -> void:
	assert(collected_item_symbol < map_symbols.size())
	assert(uncollected_item_symbol < map_symbols.size())
