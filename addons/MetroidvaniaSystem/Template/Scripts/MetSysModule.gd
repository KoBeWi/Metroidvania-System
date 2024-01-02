## Module for extending MetSysGame.
##
## MetSysModule is a simple class that can be added to MetSysGame via [code]add_module()[/code] method. It does not provide any functionality other than having a convenient reference to the game node. It's just a lightweight object that you can easily add to the game scene.
extends RefCounted

const MetSysGame = preload("res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd")

var game: MetSysGame

func _init(p_game: MetSysGame) -> void:
	game = p_game
	_initialize()

func _initialize():
	pass
