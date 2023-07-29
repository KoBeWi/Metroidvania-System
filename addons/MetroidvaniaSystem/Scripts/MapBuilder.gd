extends RefCounted

var cells: Array[MetroidvaniaSystem.MapData.CellOverride]

func create_cell(at: Vector3i) -> MetroidvaniaSystem.MapData.CellOverride:
	var cell: MetroidvaniaSystem.MapData.CellOverride = MetSys.map_data.create_custom_cell(at)
	cells.append(cell)
	return cell

func update_map():
	MetSys.map_updated.emit()
