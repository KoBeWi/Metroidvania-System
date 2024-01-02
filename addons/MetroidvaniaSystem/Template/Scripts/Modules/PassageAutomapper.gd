## A MetSys module that handles discovering room connections.
##
## The module connects to [signal MetroidvaniaSystem.cell_changed]. Whenever cell changes, the module will check whether the player crossed a border that shoud've been a wall. If it was, a CellOverride will be created to display a passage at this border. This is useful for creating secret rooms with hidden entrances.
extends "res://addons/MetroidvaniaSystem/Template/Scripts/MetSysModule.gd"

var prev_cell: Vector3i

func _initialize():
	MetSys.cell_changed.connect(_on_cell_changed)

func _on_cell_changed(new_cell: Vector3i):
	var direction: int = -1
	match new_cell - prev_cell:
		Vector3i(1, 0, 0):
			direction = MetroidvaniaSystem.R
		Vector3i(-1, 0, 0):
			direction = MetroidvaniaSystem.L
		Vector3i(0, 1, 0):
			direction = MetroidvaniaSystem.D
		Vector3i(0, -1, 0):
			direction = MetroidvaniaSystem.U
	
	if direction == -1:
		prev_cell = new_cell
		return
	
	var cell_data := MetSys.map_data.get_cell_at(prev_cell)
	if cell_data and cell_data.borders[direction] == 0:
		var override := MetSys.get_cell_override(prev_cell)
		override.set_border(direction, 1)
	
	direction = (direction + 2) % 4
	
	cell_data = MetSys.map_data.get_cell_at(new_cell)
	if cell_data and cell_data.borders[direction] == 0:
		var override := MetSys.get_cell_override(new_cell)
		override.set_border(direction, 1)
	
	prev_cell = new_cell
