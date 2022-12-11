extends Resource

@export var default_room_fill_color = Color.BLUE
@export var unexplored_room_fill_color = Color.GRAY
@export var default_room_separator_color = Color.GRAY
@export var default_room_wall_color = Color.WHITE

@export var room_fill_texture: Texture2D
@export var room_separator_texture: Texture2D
@export var room_wall_texture: Texture2D ## wersja wertykalna/horyzontalna? (dla prostokątnych pomieszczeń
@export var border_outer_corner_texture: Texture2D
@export var border_inner_corner_texture: Texture2D

@export var player_location_symbol: Texture2D
@export var player_location_scene: PackedScene ## tylko jedno ma się pokazywać
@export var uncollected_item_symbol := -1
@export var collected_item_symbol := -1
@export var map_borders: Array[Texture2D] ## każda ściana może mieć teksturę
@export var map_symbols: Array[Texture2D] ## można przypisywać 1 symbol do pomieszczeń
