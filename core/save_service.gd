extends Node

signal save_completed(slot: StringName)
signal load_completed(slot: StringName)
signal save_failed(message: String)

const SCHEMA_VERSION := 3
const BACKUP_COUNT := 8
var save_dir := "user://saves"

func _ready() -> void:
	if "--run-tests" in OS.get_cmdline_user_args():
		save_dir = "res://build/test_user/saves"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))

func save_atomic(slot: StringName = &"quick") -> bool:
	if not SimulationHost.active:
		save_failed.emit("No active region to save.")
		return false
	var payload_state := {
		"simulation": SimulationHost.export_state(),
		"progression": ProgressionService.export_state(),
		"campaigns": WorldCampaignService.export_state(),
	}
	var payload := JSON.stringify(payload_state)
	var envelope := {
		"schema_version": SCHEMA_VERSION,
		"content_version": "0.3.0-regional-campaign",
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"checksum": payload.sha256_text(),
		"payload": payload,
	}
	var target := _slot_path(slot)
	var temporary := target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		save_failed.emit("Unable to open temporary save.")
		return false
	file.store_string(JSON.stringify(envelope))
	file.flush()
	file.close()
	_rotate_backups(target)
	var absolute_target := ProjectSettings.globalize_path(target)
	var absolute_temporary := ProjectSettings.globalize_path(temporary)
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(absolute_target)
	var error := DirAccess.rename_absolute(absolute_temporary, absolute_target)
	if error != OK:
		save_failed.emit("Atomic save replacement failed: %s" % error)
		return false
	save_completed.emit(slot)
	return true

func load_and_migrate(slot: StringName = &"quick") -> bool:
	var candidates: Array[String] = [_slot_path(slot)]
	for index in range(1, BACKUP_COUNT + 1):
		candidates.append(_slot_path(slot) + ".bak%d" % index)
	for path in candidates:
		var restored := _read_valid_state(path)
		if not restored.is_empty():
			ProgressionService.import_state(restored.get("progression", {}))
			SimulationHost.import_state(restored.get("simulation", {}))
			WorldCampaignService.import_state(restored.get("campaigns", {}))
			load_completed.emit(slot)
			return true
	save_failed.emit("No valid save or backup found for %s." % slot)
	return false

func _read_valid_state(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var envelope = JSON.parse_string(file.get_as_text())
	if envelope is not Dictionary or not envelope.has("payload"):
		return {}
	var payload := String(envelope.payload)
	if payload.sha256_text() != String(envelope.get("checksum", "")):
		return {}
	var state = JSON.parse_string(payload)
	if state is not Dictionary:
		return {}
	return _migrate_payload(int(envelope.get("schema_version", 1)), state)

func _migrate_payload(schema_version: int, state: Dictionary) -> Dictionary:
	if schema_version <= 1:
		return {"simulation": state, "progression": {}, "campaigns": {}}
	if schema_version in [2, 3] and state.has("simulation"):
		if not state.has("campaigns"):
			state["campaigns"] = {}
		return state
	return {}

func _rotate_backups(target: String) -> void:
	for index in range(BACKUP_COUNT, 0, -1):
		var source := target if index == 1 else target + ".bak%d" % (index - 1)
		var destination := target + ".bak%d" % index
		if FileAccess.file_exists(source):
			if FileAccess.file_exists(destination):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
			DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))

func _slot_path(slot: StringName) -> String:
	return "%s/%s.json" % [save_dir, String(slot).validate_filename()]
