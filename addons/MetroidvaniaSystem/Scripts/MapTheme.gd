extends Resource
class_name MapTheme

@export var use_shared_borders: bool

@export var default_room_fill_color: Color
@export var unexplored_room_fill_color: Color
@export var room_separator_color: Color
@export var default_border_color: Color
@export var unexplored_border_color: Color

@export var room_fill_texture: Texture2D
@export var room_separator_texture: Texture2D
@export var room_wall_texture: Texture2D ## wersja wertykalna/horyzontalna? (dla prostokątnych pomieszczeń
@export var room_passage_texture: Texture2D
@export var border_outer_corner_texture: Texture2D
@export var border_inner_corner_texture: Texture2D

@export var player_location_scene: PackedScene
