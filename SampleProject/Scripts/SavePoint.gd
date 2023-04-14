extends Area2D

@onready var start_time := Time.get_ticks_msec()

func on_body_entered(body: Node2D) -> void:
	if Time.get_ticks_msec() - start_time < 1000:
		return # Small hack to prevent saving at the game start.
	
	var save_data := {collectible_count = Game.get_singleton().collectibles}
	save_data.merge(MetSys.get_save_data())
	
	FileAccess.open("user://save_data.sav", FileAccess.WRITE).store_var(save_data)
	
func _draw() -> void:
	$CollisionShape2D.shape.draw(get_canvas_item(), Color.BLUE)
