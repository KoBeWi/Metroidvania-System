# A save point object. Colliding with it saves the game.
extends Area2D

@onready var start_time := Time.get_ticks_msec()

func _ready() -> void:
	body_entered.connect(on_body_entered)

# Player enter save point. Note that in a legit code this should check whether body is really a player.
func on_body_entered(body: Node2D) -> void:
	if Time.get_ticks_msec() - start_time < 1000:
		return # Small hack to prevent saving at the game start.
	# Make Game save the data.
	Game.get_singleton().save_game()

func _draw() -> void:
	# Draws the circle.
	$CollisionShape2D.shape.draw(get_canvas_item(), Color.BLUE)
