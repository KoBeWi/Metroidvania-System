# Overrides room transitions to create confusing maps. Takes effect when player is inside the area. It has to be placed in the middle of room transition.
extends Area2D

## Target room for the loop.
@export_file("room_link") var loop_target
## How much the player should be moved after looping. You can't rely on automatic repositioning from transitions, this has to be set manually.
@export var loop_shift: Vector2
## Use Teleport when the loop goes out of map and Replace when it connects to another room.
@export_enum("Teleport", "Replace") var loop_mode: int

## Hack. See [method on_room_changed].
static var block_loop: bool
## If [code]true[/code], the room transition will be overridden.
var loop_active: bool

func _ready() -> void:
	if loop_mode == 0:
		MetSys.cell_changed.connect(on_cell_changed.unbind(1))
	else:
		MetSys.room_changed.connect(on_room_changed.unbind(1))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		loop_active = true
		if loop_mode == 1:
			# Game's loop property makes it load a different room than normally.
			Game.get_singleton().loop = loop_target

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		loop_active = false
		if loop_mode == 1 and not Game.get_singleton().map_changing:
			Game.get_singleton().loop = ""

func on_cell_changed():
	if loop_active:
		loop_active = false
		
		if loop_target != MetSys.get_current_room_id():
			# Load the target map.
			Game.get_singleton().load_room(loop_target)
		# Move the player to intended position.
		Game.get_singleton().player.position += loop_shift

func on_room_changed():
	if loop_active and not block_loop:
		loop_active = false
		# Prevents automatically shifting the player.
		MetSys.current_room.queue_free()
		MetSys.current_room = null
		
		Game.get_singleton().player.position += loop_shift
		# Ugly workaround for physics bug that causes area to detect at wrong position.
		block_loop = true
		get_tree().create_timer(0.05).timeout.connect(get_script().set.bind(&"block_loop", false))
