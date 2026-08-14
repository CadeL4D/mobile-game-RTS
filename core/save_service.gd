extends Node

signal save_completed(slot: StringName)
signal load_completed(slot: StringName)
signal save_failed(message: String)

const SCHEMA_VERSION := 5
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
		"content_version": "0.5.0-authoritative-inventory",
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

	# Validate temporary file before modifying target or rotating backups
	var test_envelope := _read_valid_envelope(temporary)
	if test_envelope.is_empty():
		save_failed.emit("Temporary save file failed verification.")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return false

	_rotate_backups(target)

	var absolute_target := ProjectSettings.globalize_path(target)
	var absolute_temporary := ProjectSettings.globalize_path(temporary)

	# POSIX can replace the destination atomically with rename. Windows cannot,
	# so try the atomic path first and then fall back to a recoverable replace;
	# .bak1 already contains the last verified target before this point.
	var error := DirAccess.rename_absolute(absolute_temporary, absolute_target)
	if error != OK and FileAccess.file_exists(target):
		var remove_error := DirAccess.remove_absolute(absolute_target)
		if remove_error == OK:
			error = DirAccess.rename_absolute(absolute_temporary, absolute_target)
	if error != OK:
		save_failed.emit("Save replacement failed after backup recovery: %s" % error)
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

func _read_valid_envelope(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var envelope = JSON.parse_string(file.get_as_text())
	if envelope is not Dictionary or not envelope.has("payload"):
		return {}
	var payload := String(envelope.payload)
	if payload.sha256_text() != String(envelope.get("checksum", "")):
		return {}
	return envelope

func _read_valid_state(path: String) -> Dictionary:
	var envelope := _read_valid_envelope(path)
	if envelope.is_empty():
		return {}
	var payload := String(envelope.payload)
	var state = JSON.parse_string(payload)
	if state is not Dictionary:
		return {}
	return _migrate_payload(int(envelope.get("schema_version", 1)), state)

func _migrate_payload(schema_version: int, state: Dictionary) -> Dictionary:
	if schema_version <= 1:
		state = {"simulation": state, "progression": {}, "campaigns": {}}
	if schema_version in [2, 3]:
		if not state.has("campaigns"):
			state["campaigns"] = {}
		if not state.has("progression"):
			state["progression"] = {}

	# Schema 3 -> Schema 4 Physical Logistics Migration
	if schema_version < 4 and state.has("simulation"):
		var sim: Dictionary = state.simulation
		if not sim.has("inventory") or (sim.inventory is Dictionary and sim.inventory.get("commodity_stacks", []).is_empty()):
			var commodity_stacks: Array[Dictionary] = []
			var next_sid := 1
			var res_totals: Dictionary = sim.get("resources", {})
			var placement := _find_migration_storage_placement(sim)
			var primary_container_id := int(placement.container_id)
			var placement_cell: Vector2i = placement.cell
			var unique_items: Array[Dictionary] = []
			var next_iid := 1

			for res_id in res_totals:
				var qty := int(res_totals[res_id])
				if qty <= 0 or String(res_id) in ["energy", "faith"]:
					continue
				var resource_definition := ContentRegistry.get_by_id(&"resources", StringName(res_id))
				if _is_unique_migration_resource(resource_definition, StringName(res_id)):
					for _item_index in qty:
						var durability := maxi(1, int(resource_definition.get("durability", 100)))
						unique_items.append({
							"id": next_iid,
							"item_id": String(res_id),
							"item_type": String(resource_definition.get("group", "item")),
							"durability": durability,
							"max_durability": durability,
							"slot": String(resource_definition.get("slot", "hand")),
							"custom_data": resource_definition.duplicate(true),
							"location_state": 1 if primary_container_id > 0 else 0,
							"cell_x": placement_cell.x,
							"cell_y": placement_cell.y,
							"container_id": primary_container_id,
							"carrier_id": 0
						})
						next_iid += 1
				else:
					var max_stack := maxi(1, int(resource_definition.get("max_stack", 100)))
					var remaining := qty
					while remaining > 0:
						var stack_quantity := mini(max_stack, remaining)
						commodity_stacks.append({
							"id": next_sid,
							"resource_id": String(res_id),
							"quantity": stack_quantity,
							"max_stack": max_stack,
							"location_state": 1 if primary_container_id > 0 else 0,
							"cell_x": placement_cell.x,
							"cell_y": placement_cell.y,
							"container_id": primary_container_id,
							"carrier_id": 0,
							"decay_ticks": -1
						})
						next_sid += 1
						remaining -= stack_quantity

			sim["inventory"] = {
				"next_stack_id": next_sid,
				"next_item_id": next_iid,
				"commodity_stacks": commodity_stacks,
				"unique_items": unique_items
			}

		if not sim.has("reservations"):
			sim["reservations"] = {"next_reservation_id": 1, "active_reservations": []}
		if not sim.has("task_system"):
			sim["task_system"] = {"next_task_id": 1, "tasks": [], "claimed": {}}
		if not sim.has("trade_system"):
			sim["trade_system"] = {"next_provisioner_id": 1, "provisioners": []}
		if not sim.has("corruption_system"):
			sim["corruption_system"] = {"corruption_cells": sim.get("corruption_cells", {}), "hostile_structures": [], "next_structure_id": 1}
		if not sim.has("spell_system"):
			sim["spell_system"] = {"faith": 0, "essence": 0, "energy": 0, "max_energy": 1000, "cullis_instability": 0}

	# Schema 4 stored the physical inventory and a second mutable resource
	# dictionary. Preserve only virtual pools; inventory is authoritative.
	if schema_version < 5 and state.has("simulation"):
		var sim_v5: Dictionary = state.simulation
		var legacy_resources: Dictionary = sim_v5.get("resources", {})
		if not sim_v5.has("nonphysical_resources"):
			sim_v5["nonphysical_resources"] = {
				"energy": int(legacy_resources.get("energy", 0)),
				"faith": int(legacy_resources.get("faith", 0)),
			}
		sim_v5.erase("resources")

	return state

func _find_migration_storage_placement(sim: Dictionary) -> Dictionary:
	for building_value in sim.get("buildings", []):
		if building_value is not Dictionary:
			continue
		var building: Dictionary = building_value
		if String(building.get("definition_id", "")) == "camp" and bool(building.get("completed", false)) and not bool(building.get("destroyed", false)):
			return {
				"container_id": int(building.get("id", 0)),
				"cell": Vector2i(int(building.get("x", 0)), int(building.get("y", 0)))
			}
	var blueprint: Dictionary = sim.get("blueprint", {})
	var starting_cell: Array = blueprint.get("starting_cell", [0, 0])
	return {
		"container_id": 0,
		"cell": Vector2i(int(starting_cell[0]), int(starting_cell[1]))
	}

func _is_unique_migration_resource(resource_definition: Dictionary, resource_id: StringName) -> bool:
	var group := String(resource_definition.get("group", ""))
	return group in ["tool", "weapon", "armor"] or resource_id in [&"suspicious_key", &"empty_eerie_vessel", &"filled_eerie_vessel"]

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
