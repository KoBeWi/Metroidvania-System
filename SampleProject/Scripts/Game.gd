# This is the main script of the game. It manages the current map and some other stuff.
extends Node2D
class_name Game

# The game starts in this map. Note that it's scene name only, just like MetSys refers to rooms.
@export var starting_map: String
# Player node, bruh.
@onready var player: CharacterBody2D = $Player

# The current map scene instance.
var map: Node2D

# Number of collected collectibles. Setting it also updates the counter.
var collectibles: int:
	set(count):
		collectibles = count
		%CollectibleCount.text = "%d/6" % count

# The coordinates of generated rooms. MetSys does not keep this list, so it needs to be done manually.
var generated_rooms: Array[Vector3i]
# The typical array of game events. It's supplementary to the storable objects.
var events: Array[String]

func _ready() -> void:
	# Make sure MetSys is in initial state.
	# Does not matter in this project, but normally this ensures that the game works correctly when you exit to menu and start again.
	MetSys.reset_state()
	
	if FileAccess.file_exists("user://save_data.sav"):
		# If save data exists, load it.
		var save_data: Dictionary = FileAccess.open("user://save_data.sav", FileAccess.READ).get_var()
		# Send the data to MetSys (it has extra keys, but it doesn't matter).
		MetSys.set_save_data(save_data)
		# Load various data stored in the dictionary.
		collectibles = save_data.collectible_count
		generated_rooms.assign(save_data.generated_rooms)
		events.assign(save_data.events)
		starting_map = save_data.current_room
		player.abilities.assign(save_data.abilities)
	else:
		# If no data exists, set empty one.
		MetSys.set_save_data()
	
	# Go to the starting point.
	goto_map(MetSys.get_full_room_path(starting_map))
	# Find the save point and teleport the player to it, to start at the save point.
	var start := map.get_node_or_null(^"SavePoint")
	if start:
		player.position = start.position
	
	# Connect the room_changed signal to handle room transitions.
	MetSys.room_changed.connect(on_room_changed, CONNECT_DEFERRED)
	# Reset position tracking (feature specific to this project).
	reset_map_starting_coords.call_deferred()
	# A trick for static object reference (before static vars were a thing).
	get_script().set_meta(&"singleton", self)

# Loads a room scene and removes the current one if exists.
func goto_map(map_path: String):
	var prev_map: Node2D
	if map:
		# If some map is already loaded (which is true anytime other than the beginning), keep a reference to the old instance and queue free it.
		prev_map = MetSys.get_current_room_instance()
		map.queue_free()
		map = null
	
	# Load the new map scene.
	map = load(map_path).instantiate()
	add_child(map)
	# Adjust the camera.
	MetSys.get_current_room_instance().adjust_camera_limits($Player/Camera2D)
	# Set the current layer to the room's layer.
	MetSys.current_layer = MetSys.get_current_room_instance().get_layer()
	
	# If previous map has existed, teleport the player based on map position difference.
	if prev_map:
		player.position -= MetSys.get_current_room_instance().get_room_position_offset(prev_map)
		player.on_enter()

func _physics_process(delta: float) -> void:
	# Notify MetSys about the player's current position.
	MetSys.set_player_position(player.position)

func on_room_changed(target_map: String):
	# Randomly generated rooms use absolute paths, so this needs to be checked.
	if target_map.is_absolute_path():
		goto_map(target_map)
	else:
		# If target_map is only the scene name (default behavior of assigned scenes), get the full path.
		goto_map(MetSys.get_full_room_path(target_map))

# Returns this node from anywhere.
static func get_singleton() -> Game:
	return (Game as Script).get_meta(&"singleton") as Game

# Project-specific save data Dictionary. It's merged with the MetSys one.
func get_save_data() -> Dictionary:
	return {
		"collectible_count": collectibles,
		"generated_rooms": generated_rooms,
		"events": events,
		"current_room": MetSys.get_current_room_name(),
		"abilities": player.abilities,
	}

func reset_map_starting_coords():
	$UI/MapWindow.reset_starting_coords()
