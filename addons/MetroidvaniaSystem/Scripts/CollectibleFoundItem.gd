@tool
extends PanelContainer

func set_element(element: String, icon: Texture2D, map: String, coords: Vector3i):
	%Label.text = element
	%Icon.texture = icon
	%Button.tooltip_text = "%s\nat: %s %s" % [element, coords, map.trim_prefix(MetSys.settings.map_root_folder)]
