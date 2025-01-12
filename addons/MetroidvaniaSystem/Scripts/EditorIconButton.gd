@tool
extends Button

@export var icon_name: String

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and not is_part_of_edited_scene():
		icon = get_theme_icon(icon_name, &"EditorIcons")
