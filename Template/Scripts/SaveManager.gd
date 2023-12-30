extends RefCounted

var data: Dictionary

func set_value(value_name: String, value_value: Variant):
	data[value_name] = value_value

func get_value(value_name: String, default = null) -> Variant:
	return data.get(value_name)

func save_as_text(path: String):
	data.merge(MetSys.get_save_data())
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to write save file \"%s\"! Error %d." % [path, FileAccess.get_open_error()])
		return
	
	file.store_string(var_to_str(data))

func load_from_text(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to load save file \"%s\"! Error %d." % [path, FileAccess.get_open_error()])
		return
	
	data = str_to_var(file.get_as_text())
	MetSys.set_save_data(data)

func save_as_binary(path: String):
	FileAccess.open(path, FileAccess.WRITE).store_var(data)

func load_from_binary(path: String):
	pass
