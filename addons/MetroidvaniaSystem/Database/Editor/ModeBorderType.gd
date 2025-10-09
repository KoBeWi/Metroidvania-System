@tool
extends "res://addons/MetroidvaniaSystem/Database/Editor/BorderPaintEditor.gd"#"uid://c1rtahqsg11b4"

var border_group: ButtonGroup

func _editor_init() -> void:
	use_cursor = false
	can_pick = true
	super()
	border_group = ButtonGroup.new()
	
	reload_borders()
	MetSys.settings.theme_changed.connect(reload_borders)
	MetSys.theme_modified.connect(func(changes: Array[StringName]):
		if &"borders" in changes or &"vertical_borders" or &"vertical_borders" in changes:
			reload_borders())

func reload_borders():
	for symbol in %BorderContainer.get_children():
		symbol.free()
	
	if MetSys.settings.theme.rectangle:
		add_border(MetSys.settings.theme.vertical_wall)
		add_border(MetSys.settings.theme.vertical_passage)
		
		for border in MetSys.settings.theme.vertical_borders:
			add_border(border)
	else:
		add_border(MetSys.settings.theme.wall)
		add_border(MetSys.settings.theme.passage)
		
		for border in MetSys.settings.theme.borders:
			add_border(border)

func _editor_enter():
	super()
	%Borders.show()

func _editor_exit():
	super()
	%Borders.hide()

func modify_border(cell_data: MetroidvaniaSystem.MapData.CellData, border: int, mode: int) -> bool:
	if cell_data.borders[border] == -1:
		return false
	
	if mode == MODE_PICK:
		border_group.get_buttons()[cell_data.borders[border]].button_pressed = true
	else:
		var target_border := 0
		if mode == MODE_DRAW:
			target_border = border_group.get_pressed_button().get_index()
		
		if cell_data.borders[border] != target_border:
			cell_data.borders[border] = target_border
			return true
	
	return false

func add_border(texture: Texture2D):
	var button := Button.new()
	button.icon = texture
	button.toggle_mode = true
	button.button_group = border_group
	button.custom_minimum_size.x = MetSys.CELL_SIZE.x
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.add_theme_color_override(&"icon_pressed_color", Color.WHITE)
	
	if not border_group.get_pressed_button():
		button.button_pressed = true
	
	%BorderContainer.add_child(button)
