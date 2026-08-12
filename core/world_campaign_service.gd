extends Node

signal campaign_changed
signal transfer_completed(transfer: Dictionary)
signal transfer_failed(transfer: Dictionary, reason: String)

const TRANSFER_TICKS := 240

var active_mode: StringName = &"traditional"
var mode_campaigns: Dictionary = {}

func _ready() -> void:
	_initialize_all_modes()

func _initialize_all_modes() -> void:
	for mode in ContentRegistry.get_all(&"modes"):
		_ensure_mode(StringName(mode.id))

func _ensure_mode(mode_id: StringName) -> Dictionary:
	var key := String(mode_id)
	if mode_campaigns.has(key):
		return mode_campaigns[key]
	var regions: Dictionary = {}
	for definition in ContentRegistry.get_all(&"regions"):
		regions[String(definition.id)] = {
			"status": "unestablished", "population": 0, "resources": {}, "last_tick": 0,
			"corruption_pressure": 0, "village_name": String(definition.name), "visits": 0,
		}
	mode_campaigns[key] = {"regions": regions, "transfers": [], "global_corruption": 0, "dooms": 0}
	return mode_campaigns[key]

func set_active_mode(mode_id: StringName) -> void:
	active_mode = mode_id
	_ensure_mode(mode_id)
	campaign_changed.emit()

func establish_region(region_id: StringName, population: int = 20) -> void:
	var campaign := _ensure_mode(active_mode)
	var state: Dictionary = campaign.regions.get(String(region_id), {})
	if state.is_empty():
		return
	state.status = "active"
	state.population = maxi(int(state.population), population)
	state.visits = int(state.visits) + 1
	campaign_changed.emit()

func store_active_region(region_id: StringName, simulation_state: Dictionary) -> void:
	var campaign := _ensure_mode(active_mode)
	var state: Dictionary = campaign.regions.get(String(region_id), {})
	if state.is_empty():
		return
	state.status = "active"
	state.population = simulation_state.get("villagers", []).size()
	state.resources = simulation_state.get("resources", {}).duplicate(true)
	state.last_tick = int(simulation_state.get("tick", 0))
	state["simulation"] = simulation_state.duplicate(true)
	campaign_changed.emit()

func mark_region_lost(region_id: StringName) -> void:
	var state := get_region_state(region_id)
	if state.is_empty():
		return
	state.status = "lost"
	state.population = 0
	ProgressionService.record(&"regions.lost")
	campaign_changed.emit()

func reclaim_region(region_id: StringName) -> void:
	var state := get_region_state(region_id)
	if state.is_empty():
		return
	state.status = "reclaimed"
	ProgressionService.record(&"regions.reclaimed")
	campaign_changed.emit()

func get_region_state(region_id: StringName, mode_id: StringName = active_mode) -> Dictionary:
	return _ensure_mode(mode_id).regions.get(String(region_id), {})

func queue_migration(source_id: StringName, destination_id: StringName, population: int) -> bool:
	if population <= 0 or not _are_adjacent(source_id, destination_id):
		return false
	var source := get_region_state(source_id)
	if source.is_empty() or int(source.population) <= population or String(source.status) not in ["active", "reclaimed"]:
		return false
	var transfer := {"id": _next_transfer_id(), "kind": "migration", "source": String(source_id), "destination": String(destination_id), "population": population, "resources": {}, "ticks_remaining": TRANSFER_TICKS}
	source.population = int(source.population) - population
	_apply_population_to_stored_simulation(source)
	_ensure_mode(active_mode).transfers.append(transfer)
	ProgressionService.record(&"migration.sent", population)
	campaign_changed.emit()
	return true

func queue_courier(source_id: StringName, destination_id: StringName, cargo: Dictionary) -> bool:
	if cargo.is_empty() or not _are_adjacent(source_id, destination_id):
		return false
	var source := get_region_state(source_id)
	if source.is_empty() or String(source.status) not in ["active", "reclaimed"]:
		return false
	for resource_id in cargo:
		if int(cargo[resource_id]) <= 0 or int(source.resources.get(resource_id, 0)) < int(cargo[resource_id]):
			return false
	for resource_id in cargo:
		source.resources[resource_id] = int(source.resources.get(resource_id, 0)) - int(cargo[resource_id])
	_apply_resources_to_stored_simulation(source)
	var transfer := {"id": _next_transfer_id(), "kind": "courier", "source": String(source_id), "destination": String(destination_id), "population": 0, "resources": cargo.duplicate(true), "ticks_remaining": TRANSFER_TICKS}
	_ensure_mode(active_mode).transfers.append(transfer)
	ProgressionService.record(&"couriers.resources_sent", _sum_dictionary(cargo))
	campaign_changed.emit()
	return true

func advance_ticks(amount: int = 1) -> void:
	var campaign := _ensure_mode(active_mode)
	var remaining: Array = []
	for transfer in campaign.transfers:
		transfer.ticks_remaining = int(transfer.ticks_remaining) - amount
		if int(transfer.ticks_remaining) > 0:
			remaining.append(transfer)
			continue
		_complete_transfer(transfer)
	campaign.transfers = remaining

func _complete_transfer(transfer: Dictionary) -> void:
	var destination := get_region_state(StringName(transfer.destination))
	if destination.is_empty() or String(destination.status) == "lost":
		_refund_transfer(transfer)
		transfer_failed.emit(transfer, "destination_lost")
		campaign_changed.emit()
		return
	if String(transfer.kind) == "migration":
		destination.population = int(destination.population) + int(transfer.population)
		_apply_population_to_stored_simulation(destination)
		if String(destination.status) == "unestablished":
			destination.status = "active"
		ProgressionService.record(&"migration.arrived", int(transfer.population))
	else:
		for resource_id in transfer.resources:
			destination.resources[resource_id] = int(destination.resources.get(resource_id, 0)) + int(transfer.resources[resource_id])
		ProgressionService.record(&"couriers.resources_received", _sum_dictionary(transfer.resources))
		_apply_resources_to_stored_simulation(destination)
	transfer_completed.emit(transfer)
	campaign_changed.emit()

func _refund_transfer(transfer: Dictionary) -> void:
	var source := get_region_state(StringName(transfer.source))
	if source.is_empty() or String(source.status) == "lost":
		return
	if String(transfer.kind) == "migration":
		source.population = int(source.population) + int(transfer.population)
		_apply_population_to_stored_simulation(source)
		return
	for resource_id in transfer.resources:
		source.resources[resource_id] = int(source.resources.get(resource_id, 0)) + int(transfer.resources[resource_id])
	_apply_resources_to_stored_simulation(source)

func apply_pending_state_to_simulation(region_state: Dictionary) -> void:
	_apply_population_to_stored_simulation(region_state)
	_apply_resources_to_stored_simulation(region_state)

func _apply_resources_to_stored_simulation(region_state: Dictionary) -> void:
	if not region_state.has("simulation"):
		return
	var merged: Dictionary = region_state.simulation.get("resources", {}).duplicate(true)
	for resource_id in region_state.get("resources", {}):
		merged[resource_id] = int(region_state.resources[resource_id])
	region_state.simulation.resources = merged

func _apply_population_to_stored_simulation(region_state: Dictionary) -> void:
	if not region_state.has("simulation"):
		return
	var desired := maxi(0, int(region_state.get("population", 0)))
	var stored_villagers: Array = region_state.simulation.get("villagers", [])
	if stored_villagers.size() > desired:
		stored_villagers.resize(desired)
	elif stored_villagers.size() < desired:
		var blueprint_data: Dictionary = region_state.simulation.get("blueprint", {})
		var start_data: Array = blueprint_data.get("starting_cell", [128, 128])
		var next_id := int(region_state.simulation.get("next_entity_id", 1))
		while stored_villagers.size() < desired:
			stored_villagers.append({
				"id": next_id, "name": "Migrant %02d" % (stored_villagers.size() + 1), "job": "idle",
				"x": float(start_data[0]), "y": float(start_data[1]), "target_x": float(start_data[0]), "target_y": float(start_data[1]),
				"health": 1000, "hunger": 900, "thirst": 900, "energy": 900, "faith": 500,
				"age_stage": "adult", "age_days": 30, "sex": "female" if next_id % 2 == 0 else "male",
				"pregnant_ticks": 0, "partner_id": 0, "level": 1, "xp": 0, "task_id": 0, "task_kind": "", "task_progress": 0,
				"state": "arrived", "home_id": 0, "status": [], "path": [], "path_index": 0, "path_goal_x": -1, "path_goal_y": -1, "stuck_ticks": 0,
			})
			next_id += 1
		region_state.simulation.next_entity_id = next_id
	region_state.simulation.villagers = stored_villagers

func doom_mode(mode_id: StringName = active_mode) -> void:
	var campaign := _ensure_mode(mode_id)
	var doom_count := int(campaign.dooms) + 1
	mode_campaigns.erase(String(mode_id))
	campaign = _ensure_mode(mode_id)
	campaign.dooms = doom_count
	ProgressionService.record(&"worlds.doomed")
	campaign_changed.emit()

func _are_adjacent(source_id: StringName, destination_id: StringName) -> bool:
	var source_definition := ContentRegistry.get_by_id(&"regions", source_id)
	return String(destination_id) in source_definition.get("adjacent", [])

func _next_transfer_id() -> int:
	var highest := 0
	for campaign in mode_campaigns.values():
		for transfer in campaign.transfers:
			highest = maxi(highest, int(transfer.id))
	return highest + 1

func _sum_dictionary(values: Dictionary) -> int:
	var total := 0
	for value in values.values():
		total += int(value)
	return total

func export_state() -> Dictionary:
	return {"active_mode": String(active_mode), "mode_campaigns": mode_campaigns.duplicate(true)}

func import_state(state: Dictionary) -> void:
	active_mode = StringName(state.get("active_mode", "traditional"))
	mode_campaigns = state.get("mode_campaigns", {}).duplicate(true)
	_initialize_all_modes()
