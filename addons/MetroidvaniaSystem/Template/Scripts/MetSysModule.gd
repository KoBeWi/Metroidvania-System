## Module for extending MetSysGame.
##
## MetSysModule is a simple class that can be added to MetSysGame via [code]add_module()[/code] method. It does not provide any functionality other than having a convenient reference to the game node. It's just a lightweight object that you can easily add to the game scene. Once the module is installed, it will call [code]_initialize()[/code] method, which you can override to do setup. Check code of RoomTransitions and PassageAutomapper for example how to implement a module.
extends RefCounted

const MetSysGame = preload("res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd")

## Reference to the MetSysGame instance where this module was installed.
var game: MetSysGame

func _init(p_game: MetSysGame) -> void:
	game = p_game
	_initialize()

func _initialize():
	pass
