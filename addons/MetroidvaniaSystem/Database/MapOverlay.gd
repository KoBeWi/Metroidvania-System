@tool
extends Control

var cursor_inside: bool

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		cursor_inside = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		cursor_inside = false
		queue_redraw()
