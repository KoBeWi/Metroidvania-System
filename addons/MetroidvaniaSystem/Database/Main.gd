@tool
extends VBoxContainer

@onready var editor: Control = %"Map Editor"
@onready var viewer: Control = %"Map Viewer"
@onready var changes_detected: ConfirmationDialog = $ChangesDetected
@onready var tabs = $TabContainer

var backup_button: Button

var plugin_version: String
var header_text: String

var modtime: int
var md5: String

func _init() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://addons/MetroidvaniaSystem/plugin.cfg")
	plugin_version = cfg.get_value("plugin", "version", "??")

func _ready() -> void:
	if is_part_of_edited_scene():
		return
	
	changes_detected.get_ok_button().tooltip_text = "Discards local map data and loads the external one instead.\nIf you made any local changes to the map, they will be lost."
	changes_detected.get_cancel_button().tooltip_text = "Saves local map data to the file, overwriting whatever is stored on disk. If you are using version control (e.g. git), this allows you to manually merge changes."
	backup_button = changes_detected.add_button("Save Copy and Reload", true)
	
	changes_detected.get_cancel_button().pressed.connect(_on_changes_detected_cancelled)
	backup_button.pressed.connect(_on_changes_detected_third)
	
	modtime = FileAccess.get_modified_time(MetSys.map_data.get_map_data_path())
	md5 = FileAccess.get_md5(MetSys.map_data.get_map_data_path())
	MetSys.editor_plugin.saved.connect(update_md_info, CONNECT_DEFERRED)
	
	MetSys.settings.map_data_file_changed.connect(%Manage.force_reload)

func _notification(what: int) -> void:
	if is_part_of_edited_scene():
		return
	
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		var new_modtime := FileAccess.get_modified_time(MetSys.map_data.get_map_data_path())
		if new_modtime != modtime:
			modtime = new_modtime
			var new_md5 := FileAccess.get_md5(MetSys.map_data.get_map_data_path())
			if new_md5 != md5:
				md5 = new_md5
				backup_button.tooltip_text = tr("Save local map data into a backup file called \"%s.bak\", then reloads map data. You can use the backup file to manually merge changes.") % MetSys.settings.map_data_file.get_file()
				changes_detected.popup_centered()
	elif what == NOTIFICATION_TRANSLATION_CHANGED:
		if header_text.is_empty():
			header_text = $Label.text
		
		$Label.text = tr(header_text) % plugin_version

func _on_changes_detected_confirmed() -> void:
	reload_map()

func _on_changes_detected_cancelled() -> void:
	MetSys.map_data.save_data()

func update_md_info():
	modtime = FileAccess.get_modified_time(MetSys.map_data.get_map_data_path())
	md5 = FileAccess.get_md5(MetSys.map_data.get_map_data_path())

func _on_changes_detected_third() -> void:
	changes_detected.hide()
	MetSys.map_data.save_data(true)
	reload_map()

func reload_map():
	%Manage.force_reload()
	%"Map Editor".refresh()
	%"Map Viewer".refresh()

func POT_hack():
	tr("Save Copy and Reload")
