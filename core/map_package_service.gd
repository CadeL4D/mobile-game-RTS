extends Node

signal map_saved(path: String)
signal map_loaded(blueprint: RegionBlueprint)
signal map_failed(message: String)

const PACKAGE_VERSION := 1
var map_dir := "user://maps"

func _ready() -> void:
	if "--run-tests" in OS.get_cmdline_user_args():
		map_dir = "res://build/test_user/maps"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(map_dir))

func save_map(blueprint: RegionBlueprint, name: String, metadata: Dictionary = {}) -> String:
	var safe_name := name.strip_edges().validate_filename()
	if safe_name.is_empty():
		safe_name = "untitled_region"
	var payload := {
		"package_version": PACKAGE_VERSION,
		"content_version": "0.2.0",
		"name": name,
		"saved_unix": int(Time.get_unix_time_from_system()),
		"metadata": metadata.duplicate(true),
		"blueprint": blueprint.to_dictionary(),
	}
	var path := "%s/%s.rtrmap" % [map_dir, safe_name]
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		map_failed.emit("Unable to write map package.")
		return ""
	file.store_string(JSON.stringify(payload))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if error != OK:
		map_failed.emit("Unable to finalize map package: %s" % error)
		return ""
	map_saved.emit(path)
	return path

func load_map(path: String) -> RegionBlueprint:
	if not FileAccess.file_exists(path):
		map_failed.emit("Map package does not exist.")
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary or int(parsed.get("package_version", 0)) > PACKAGE_VERSION or parsed.get("blueprint", {}) is not Dictionary:
		map_failed.emit("Unsupported or invalid map package.")
		return null
	var blueprint := RegionBlueprint.from_dictionary(parsed.blueprint)
	blueprint.validation_report = RegionGenerator.new().validate(blueprint)
	map_loaded.emit(blueprint)
	return blueprint

func latest_map_path() -> String:
	var directory := DirAccess.open(map_dir)
	if directory == null:
		return ""
	var newest_path := ""
	var newest_time := 0
	for filename in directory.get_files():
		if not filename.ends_with(".rtrmap"):
			continue
		var path := "%s/%s" % [map_dir, filename]
		var modified := FileAccess.get_modified_time(path)
		if modified >= newest_time:
			newest_time = modified
			newest_path = path
	return newest_path
