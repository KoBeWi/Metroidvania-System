extends Area2D

@export var target_map: String

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") and not body.event:
		body.event = true
		body.velocity = Vector2()
		
		var tween := create_tween()
		tween.tween_property(body, ^"position", position, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		await tween.finished
		Game.get_singleton().goto_map(MetSys.get_full_room_path(target_map))
		get_tree().create_timer(0.05).timeout.connect(body.set.bind(&"event", false))
		
