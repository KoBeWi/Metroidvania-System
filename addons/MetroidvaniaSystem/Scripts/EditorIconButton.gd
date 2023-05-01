@tool
extends Button

@export var icon_name: String

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if get_tree().edited_scene_root and get_tree().edited_scene_root.is_ancestor_of(self):
			return
		
		icon = get_theme_icon(icon_name, &"EditorIcons")
