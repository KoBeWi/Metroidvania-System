## Loads and saves game data.
##
## Save Manager can save and load game data, i.e. MetSys save data and other game-specific values. The class internally stores the data in a [Dictionary], which is then serialized either in text or binary format. The manager does not support [Object]-based data (although it has special methods for handling [Resource]s).
## [br][br]To use the manager, first create an instance of this script using [method GDScript.new] (it's recommended to preload the script into a constant). Use [method set_value] to store data you want included and then either [method save_as_text] or [method save_as_binary] to save it in the specified file. MetSys save data is included automatically. Load the data using [method load_from_text] or [method load_from_binary] and then [method get_value] to retrieve the saved values.
## [br][br]The manager has special methods for saving and loading custom [Resource]s in a safe way. Use [method store_resource] to store a resource (by converting it to a [Dictionary]) and [method retrieve_resource] to load the data back.
## [codeblock]
## var manager = SaveManager.new()
## manager.set_data("lives", player.lives)
## manager.set_data("gold", player.gold)
## manager.save_as_text("user://save.sav")
## [/codeblock]
extends RefCounted

var data: Dictionary

## Stores the value in the internal [Dictionary]. Call it to set the data you want saved. Only supports non-[Object] values.
func set_value(field: String, value: Variant):
	data[field] = value

## Retrieves the value from the internal [Dictionary]. Works the same as [method Dictionary.get]. You need to load the data before calling this.
func get_value(field: String, default = null) -> Variant:
	return data.get(field, default)

## Stores save data of a MetSys game object or other object with get_save_data() method. Allows for easier storing of game data, especially when you have game modules with save data. Only one such object can be stored in the save file.
func store_game(game):
	data["_MetSysGame_"] = game.get_save_data()

## Retrieves save data of a MetSys game object or other object with set_save_data() method.
func retrieve_game(game):
	var game_data: Dictionary = data.get("_MetSysGame_", {})
	game.set_save_data(game_data)

## Stores a [Resource] by dumping its properties into a [Dictionary]. [param field] can be optionally provided to store the data in a nested [Dictionary]. If it's not provided, the resource's data will be mixed with the main data.
## [br][br]Just like with [method set_value], the resource's properties can't have [Object] values.
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

## Loads the data back into the resource. Requires an instance created beforehand. [param field] must be the same as used with [method store_resource].
## [codeblock]
## var manager = SaveManager.new()
## manager.load_from_text("save.sav")
## var res = SomeCustomResource.new()
## manager.retrieve_resource(res)
## [/codeblock]
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

## Stores the data as text using [method @GlobalScope.var_to_str] and [method FileAccess.store_string].
func save_as_text(path: String):
	var file := _setup_save(path)
	if not file:
		return
	file.store_string(var_to_str(data))

## Loads a text saved data. The data can be then retrieved using [method get_value].
func load_from_text(path: String):
	var file := _setup_load(path)
	if not file:
		return
	
	var loaded_data = str_to_var(file.get_as_text())
	if not loaded_data is Dictionary:
		push_error("Failed to load text data from file \"%s\"." % path)
		return
	
	data = loaded_data
	MetSys.set_save_data(data)

## Stores the data as binary using [method FileAccess.store_var].
func save_as_binary(path: String):
	var file := _setup_save(path)
	if not file:
		return
	file.store_var(data)

## Loads a binary saved data. The data can be then retrieved using [method get_value].
func load_from_binary(path: String):
	var file := _setup_load(path)
	if not file:
		return
	
	var loaded_data = file.get_var()
	if not loaded_data is Dictionary:
		push_error("Failed to load binary data from file \"%s\"." % path)
		return
	
	data = loaded_data
	MetSys.set_save_data(data)

## Stores the data as text using [method @GlobalScope.var_to_str], returning the resulting [String]. Use it if you can't use the file methods for some reason.
func save_as_string() -> String:
	data.merge(MetSys.get_save_data())
	return var_to_str(data)

## Loads a text saved data from the provided [String] (it must have been created with [method save_as_string]). The data can be then retrieved using [method get_value].
func load_from_string(string: String):
	var loaded_data = str_to_var(string)
	if not loaded_data is Dictionary:
		push_error("Failed to load data from string.")
		return
	
	data = loaded_data
	MetSys.set_save_data(data)

func _setup_save(path: String) -> FileAccess:
	data.merge(MetSys.get_save_data())
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to write save file \"%s\"! Error %d." % [path, FileAccess.get_open_error()])
	return file

func _setup_load(path: String) -> FileAccess:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to load save file \"%s\"! Error %d." % [path, FileAccess.get_open_error()])
	return file
