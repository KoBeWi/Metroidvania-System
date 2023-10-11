## A class for creating custom cells at runtime.
##
## MapBuilder is obtained with [method MetroidvaniaSystem.get_map_builder] and can be used for procedural map generation or other use-cases where cells that weren't created in the editor need to be used.
## [br][br]A cell can be created with [method create_cell] (the position can't already have another cell). The method will return a CellOverride that you can use to customize the cell's appearance. Once you finished creating your cells, use [method update_map].
## [br][br]Note that, while cells created with this class are part of [method MetroidvaniaSystem.get_save_data]'s dump, you can't differentiate them from regular cell overrides. You need to keep this information yourself.
extends RefCounted

## The cells created with this MapBuilder.
var cells: Array[MetroidvaniaSystem.MapData.CellOverride]

## Creates a new cell on the world map and returns a CellOverride that can be used to customize the cell. You can destroy created cells using their [code]destroy()[/code] method.
func create_cell(at: Vector3i) -> MetroidvaniaSystem.MapData.CellOverride:
	var cell: MetroidvaniaSystem.MapData.CellOverride = MetSys.map_data.create_custom_cell(at)
	cells.append(cell)
	return cell

## Requests the world map update. This simply emits [signal MetroidvaniaSystem.map_updated]. The signal is not emitted automatically when customizing the cells, unlike regular overrides. Updating the map in batches is more efficient.
func update_map():
	MetSys.map_updated.emit()
