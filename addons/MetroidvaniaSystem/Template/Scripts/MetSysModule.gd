extends RefCounted

const MetSysGame = preload("res://addons/MetroidvaniaSystem/Template/Scripts/MetSysGame.gd")

var game: MetSysGame

func _init(p_game: MetSysGame) -> void:
	game = p_game
	_initialize()

func _initialize():
	pass
