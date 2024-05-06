## Module for extending MetSysGame.
##
## MetSysModule is a simple class that can be added to MetSysGame via [code]add_module()[/code] method. It does not provide any functionality other than having a convenient reference to the game node. It's just a lightweight object that you can easily add to the game scene. Once the module is installed, it will call [code]_initialize()[/code] method, which you can override to do setup. Check code of RoomTransitions and PassageAutomapper for example how to implement a module.
## [br][br]Modules data can be saved via SaveManager's store_game() method. When loading such data, make sure it happens after the modules are added.
extends RefCounted

const MetSysGame = preload("res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd")

## Reference to the MetSysGame instance where this module was installed.
var game: MetSysGame

func _init(p_game: MetSysGame) -> void:
	game = p_game
	_initialize()

func _initialize():
	pass

## Called when MetSysGame data is saved via SaveManager.store_game(). Use it to return the data you want saved for this module.
func _get_save_data() -> Dictionary:
	return {}

## Called when MetSysGame data is restored via SaveManager.retrieve_game(). [param data] will contain your stored save data (note that it's merged with other modules).
func _set_save_data(data: Dictionary):
	pass
