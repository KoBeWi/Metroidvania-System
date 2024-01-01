extends RefCounted

var data: Dictionary

func set_value(field: String, value: Variant):
	data[field] = value

func get_value(field: String, default = null) -> Variant:
	return data.get(field)

func store_resource(res: Resource, field := ""):
	var subdata: Dictionary
	
	for property in res.get_property_list():
		if not property["usage"] & PROPERTY_USAGE_STORAGE:
			continue
		
		var property_name: String = property["name"]
		
		if property_name == "resource_local_to_scene" or property_name == "resource_name" or property_name == "script":
			continue
		
		subdata[property_name] = res.get(property_name)
	
	if field.is_empty():
		data.merge(subdata)
	else:
		data[field] = subdata

func retrieve_resource(res: Resource, field := ""):
	var subdata := data
	if not field.is_empty():
		subdata = data.get(field, {})
	
	for property in res.get_property_list():
		if not property["usage"] & PROPERTY_USAGE_STORAGE:
			continue
		
		var property_name: String = property["name"]
		
		if not property_name in subdata:
			continue
		
		res.set(property_name, subdata[property_name])

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
