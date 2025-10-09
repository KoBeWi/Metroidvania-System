@tool
extends "res://addons/MetroidvaniaSystem/Database/Editor/CellPaintEditor.gd"#"uid://byyfy6e5ygtyx"

var symbol_group: ButtonGroup

func _editor_init() -> void:
	can_pick = true
	super()
	
	symbol_group = ButtonGroup.new()
	reload_symbols()
	MetSys.settings.theme_changed.connect(reload_symbols)
	MetSys.theme_modified.connect(func(changes: Array[StringName]):
		if &"symbols" in changes:
			reload_symbols())

func reload_symbols():
	for symbol in %SymbolContainer.get_children():
		symbol.free()
	
	for symbol in MetSys.settings.theme.symbols:
		add_symbol(symbol)

func _editor_enter():
	super()
	%Symbols.show()

func _editor_exit():
	super()
	%Symbols.hide()

func modify_cell(cell_data: MetroidvaniaSystem.MapData.CellData, mode: int) -> bool:
	if mode == MODE_PICK:
		if cell_data.symbol > -1:
			symbol_group.get_buttons()[cell_data.symbol].button_pressed = true
		return false
	
	var target_symbol := -1
	if mode == MODE_DRAW:
		target_symbol = symbol_group.get_pressed_button().get_index()
	
	if cell_data.symbol != target_symbol:
		var old := cell_data.symbol
		cell_data.symbol = target_symbol
		undo_handle_cell_property(cell_data, &"symbol", old)
		return true
	
	return false

func add_symbol(texture: Texture2D):
	var button := Button.new()
	button.icon = texture
	button.toggle_mode = true
	button.button_group = symbol_group
	button.add_theme_color_override(&"icon_pressed_color", Color.WHITE)
	
	if not symbol_group.get_pressed_button():
		button.button_pressed = true
	
	%SymbolContainer.add_child(button)
