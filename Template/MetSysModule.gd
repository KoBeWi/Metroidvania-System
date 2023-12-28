extends RefCounted

const MetSysGame = preload("res://Template/MetSysGame.gd")

var game: MetSysGame

func _init(p_game: MetSysGame) -> void:
	game = p_game
	_initialize()

func _initialize():
	pass
