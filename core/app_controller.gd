extends Node

signal screen_changed(screen: StringName)
signal mode_changed(mode_id: StringName)
signal region_selected(region_id: StringName)

var current_screen: StringName = &"mode_select"
var current_mode: StringName = &"traditional"
var current_region: StringName = &"applemeadow"
var profile_name := "Audit Mobile"
var custom_rules := {
	"first_attack_day": 2,
	"monster_rate": 1.0,
	"season_days": 5,
	"corruption_rate": 1.0,
	"resource_abundance": 1.0,
	"needs_rate": 1.0,
	"disasters": true,
	"weather": true,
}

func select_mode(mode_id: StringName) -> void:
	_store_live_region()
	current_mode = mode_id
	WorldCampaignService.set_active_mode(mode_id)
	mode_changed.emit(mode_id)
	set_screen(&"custom_mode" if mode_id == &"custom" else &"world_map")

func set_custom_rule(rule_id: StringName, value: Variant) -> void:
	if custom_rules.has(String(rule_id)):
		custom_rules[String(rule_id)] = value

func confirm_custom_mode() -> void:
	current_mode = &"custom"
	mode_changed.emit(current_mode)
	set_screen(&"world_map")

func open_map_editor() -> void:
	set_screen(&"map_editor")

func play_blueprint(blueprint: RegionBlueprint, rules: Dictionary = {}) -> void:
	var effective_rules := rules.duplicate(true)
	if effective_rules.is_empty():
		effective_rules = ContentRegistry.get_by_id(&"modes", &"sandbox").duplicate(true)
	SimulationHost.start_region(blueprint, effective_rules)
	set_screen(&"play")

func select_region(region_id: StringName) -> void:
	current_region = region_id
	region_selected.emit(region_id)

func establish_selected_region() -> void:
	var region: Dictionary = ContentRegistry.get_by_id("regions", current_region)
	if region.is_empty():
		push_error("Unknown region: %s" % current_region)
		return
	_store_live_region()
	var regional_state: Dictionary = WorldCampaignService.get_region_state(current_region, current_mode)
	var stored_simulation: Dictionary = regional_state.get("simulation", {})
	if not stored_simulation.is_empty():
		WorldCampaignService.apply_pending_state_to_simulation(regional_state)
		SimulationHost.import_state(stored_simulation)
		WorldCampaignService.establish_region(current_region, SimulationHost.villagers.size())
		set_screen(&"play")
		return
	var seed: int = absi(hash(String(current_region) + ":" + String(current_mode)))
	var generator: RegionGenerator = RegionGenerator.new()
	var blueprint: RegionBlueprint = generator.generate(seed, current_region, StringName(region.get("biome", "forest")))
	var rules: Dictionary = ContentRegistry.get_by_id("modes", current_mode).duplicate(true)
	if current_mode == &"custom":
		for key in custom_rules:
			rules[key] = custom_rules[key]
	if rules.has("resource_abundance"):
		var abundance := float(rules.resource_abundance)
		for resource_node in blueprint.resource_nodes:
			resource_node.amount = maxi(1, roundi(int(resource_node.amount) * abundance))
	SimulationHost.start_region(blueprint, rules)
	if int(regional_state.get("population", 0)) > 0:
		regional_state["simulation"] = SimulationHost.export_state()
		WorldCampaignService.apply_pending_state_to_simulation(regional_state)
		SimulationHost.import_state(regional_state.simulation)
	WorldCampaignService.establish_region(current_region, SimulationHost.villagers.size())
	set_screen(&"play")

func return_to_world_map() -> void:
	_store_live_region()
	set_screen(&"world_map")

func send_migrants(destination_id: StringName, population: int) -> bool:
	if not _active_region_has_building(&"migration_way_station"):
		return false
	_store_live_region()
	var source_id := StringName(SimulationHost.blueprint.region_id)
	var result := WorldCampaignService.queue_migration(source_id, destination_id, population)
	if result:
		WorldCampaignService.apply_pending_state_to_simulation(WorldCampaignService.get_region_state(source_id))
		SimulationHost.import_state(WorldCampaignService.get_region_state(source_id).simulation)
	return result

func send_courier(destination_id: StringName, cargo: Dictionary) -> bool:
	if not _active_region_has_building(&"courier_station"):
		return false
	_store_live_region()
	var source_id := StringName(SimulationHost.blueprint.region_id)
	var result := WorldCampaignService.queue_courier(source_id, destination_id, cargo)
	if result:
		WorldCampaignService.apply_pending_state_to_simulation(WorldCampaignService.get_region_state(source_id))
		SimulationHost.import_state(WorldCampaignService.get_region_state(source_id).simulation)
	return result

func _active_region_has_building(building_id: StringName) -> bool:
	if not SimulationHost.active:
		return false
	return SimulationHost.buildings.any(func(building: Dictionary) -> bool:
		return String(building.definition_id) == String(building_id) and bool(building.completed) and not bool(building.get("destroyed", false)))

func _store_live_region() -> void:
	if not SimulationHost.active or SimulationHost.blueprint == null:
		return
	var live_region := StringName(SimulationHost.blueprint.region_id)
	if ContentRegistry.get_by_id(&"regions", live_region).is_empty():
		return
	WorldCampaignService.store_active_region(live_region, SimulationHost.export_state())

func set_screen(screen: StringName) -> void:
	current_screen = screen
	screen_changed.emit(screen)
