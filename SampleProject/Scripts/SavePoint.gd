extends Area2D

func on_body_entered(body: Node2D) -> void:
	FileAccess.open("user://save_data.sav", FileAccess.WRITE).store_var(MetSys.get_save_data())
	
func _draw() -> void:
	$CollisionShape2D.shape.draw(get_canvas_item(), Color.BLUE)
