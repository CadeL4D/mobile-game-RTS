extends Node

signal region_started(blueprint: RegionBlueprint)
signal snapshot_updated(snapshot: SimulationSnapshot)
signal sim_event(event: SimEvent)

const TICK_RATE := 10.0
const TICK_SECONDS := 1.0 / TICK_RATE
const TICKS_PER_DAY := 1200
const DEFAULT_SETTLEMENT_RANGE := 16
const CORRUPTION_RECLAIM_PER_SOURCE := 2
const NATURAL_REGROWTH_INTERVAL := 600
const DRONE_BUILD_INTERVAL := 40
const MAX_HOSTILE_STRUCTURES := 96
const TASK_BOARD := preload("res://core/simulation/task_board.gd")
const GRID_PATHFINDER := preload("res://core/simulation/grid_pathfinder.gd")
const PHYSICAL_INVENTORY := preload("res://core/simulation/physical_inventory.gd")
const RESERVATION_SERVICE := preload("res://core/simulation/reservation_service.gd")
const LOGISTICS_SYSTEM := preload("res://core/simulation/logistics_system.gd")
const TASK_SYSTEM := preload("res://core/simulation/task_system.gd")
const PRODUCTION_SYSTEM := preload("res://core/simulation/production_system.gd")
const NEEDS_SYSTEM := preload("res://core/simulation/needs_system.gd")
const POPULATION_SYSTEM := preload("res://core/simulation/population_system.gd")
const ANIMAL_SYSTEM := preload("res://core/simulation/animal_system.gd")
const TRADE_SYSTEM := preload("res://core/simulation/trade_system.gd")
const COMBAT_SYSTEM := preload("res://core/simulation/combat_system.gd")
const CORRUPTION_SYSTEM := preload("res://core/simulation/corruption_system.gd")
const SPELL_SYSTEM := preload("res://core/simulation/spell_system.gd")

var inventory = PHYSICAL_INVENTORY.new()
var reservations = RESERVATION_SERVICE.new()
var logistics = LOGISTICS_SYSTEM.new()
var task_system = TASK_SYSTEM.new()
var production = PRODUCTION_SYSTEM.new()
var needs_system = NEEDS_SYSTEM.new()
var population_system = POPULATION_SYSTEM.new()
var animal_system = ANIMAL_SYSTEM.new()
var trade_system = TRADE_SYSTEM.new()
var combat_system = COMBAT_SYSTEM.new()
var corruption_system = CORRUPTION_SYSTEM.new()
var spell_system = SPELL_SYSTEM.new()

var blueprint: RegionBlueprint
var mode_rules: Dictionary = {}
var active := false
var paused := false
var speed := 1
var tick := 0
var accumulator := 0.0
var resources: Dictionary = {}
var resource_caps: Dictionary = {}
var resource_rates: Dictionary = {}
var resource_rate_sample: Dictionary = {}
var resource_rate_sample_tick := 0
var next_resource_rate_tick := 100
var resource_nodes: Array[Dictionary] = []
var loose_items: Array[Dictionary] = []
var held_entity: Dictionary = {}
var magic_circles: Array[Dictionary] = []
var catjeet_trader: Dictionary = {}
var next_trade_arrival_tick := 600
var jobs: Dictionary = {}
var villagers: Array[Dictionary] = []
var nomads: Array[Dictionary] = []
var next_nomad_tick := TICKS_PER_DAY * 2
var nomad_groups_spawned := 0
var animals: Array[Dictionary] = []
var golems: Array[Dictionary] = []
var monsters: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
var corruption_cells: Dictionary = {}
var terrain_effects: Dictionary = {}
var terrain_work: Dictionary = {}
var buildings: Array[Dictionary] = []
var hostile_structures: Array[Dictionary] = []
var housing_capacity := 0
var animal_pen_capacity := 0
var clucker_coop_capacity := 0
var doggo_house_capacity := 0
var building_limit := 0
var build_range := 0
var ancillary_limit := 0
var goals: Dictionary = {}
var messages: Array[String] = []
var god_xp := 0
var influence := 0
var max_influence := 0
var influence_reserved := 0
var weather: StringName = &"clear"
var active_event: StringName = &""
var event_ticks_remaining := 0
var next_weather_tick := 300
var next_event_tick := TICKS_PER_DAY * 3
var temperature_c := 18
var water_frozen := false
var next_entity_id := 1
var command_queue: Array[GameCommand] = []
var rng := RandomNumberGenerator.new()
var task_board = TASK_BOARD.new()
var pathfinder = GRID_PATHFINDER.new()
var hostile_pathfinder = GRID_PATHFINDER.new()

func _ready() -> void:
	inventory.bind_reservation_service(reservations)
	task_system.bind_reservation_service(reservations)

func _process(delta: float) -> void:
	if not active or paused or speed <= 0:
		return
	accumulator += minf(delta, 0.25) * speed
	var safety := 0
	while accumulator >= TICK_SECONDS and safety < 16:
		advance_tick()
		accumulator -= TICK_SECONDS
		safety += 1

func start_region(p_blueprint: RegionBlueprint, p_mode_rules: Dictionary) -> void:
	# Stateful extracted services must never carry records into another region,
	# profile, or mode. Stateless services are safe to reuse.
	reservations.clear()
	inventory.clear()
	task_system.clear()
	trade_system.clear()
	corruption_system.clear()
	spell_system.clear()
	blueprint = p_blueprint
	mode_rules = p_mode_rules.duplicate(true)
	active = true
	paused = false
	speed = 1
	tick = 0
	accumulator = 0.0
	next_entity_id = 1
	rng.seed = blueprint.seed
	pathfinder.configure(blueprint)
	hostile_pathfinder.configure(blueprint)
	resources = {
		"wood": 32,
		"rock": 32,
		"crystal": 8,
		"raw_vegetables": 96,
		"clean_water": 96,
		"boards": 0,
		"cut_stone": 0,
		"crylithium": 0,
		"iron_ingot": 0,
		"gold_coins": 0,
		"energy": 0,
		"faith": 0,
	}
	for resource_definition in ContentRegistry.get_all(&"resources"):
		if not resources.has(String(resource_definition.id)):
			resources[String(resource_definition.id)] = 0
	inventory.clear()
	reservations.clear()
	for res_key in resources:
		var qty := int(resources[res_key])
		if qty > 0 and _is_physical_resource(StringName(res_key)):
			# Starting supplies exist on the ground until the player builds a Camp.
			inventory.add_commodity(StringName(res_key), qty, PhysicalInventory.LocationState.GROUND, blueprint.starting_cell)
	max_influence = 999999 if bool(mode_rules.get("unlimited_influence", false)) else 800
	influence = max_influence
	influence_reserved = 0
	weather = &"clear"
	active_event = &""
	event_ticks_remaining = 0
	next_weather_tick = 300 + rng.randi_range(0, 300)
	next_event_tick = TICKS_PER_DAY * 3 + rng.randi_range(0, TICKS_PER_DAY)
	temperature_c = 18
	water_frozen = false
	resource_caps.clear()
	for resource in ContentRegistry.get_all(&"resources"):
		resource_caps[String(resource.id)] = 0 if String(resource.get("group", "")) == "trash" else 200
	resource_caps.energy = 1000
	resource_caps.faith = 1000
	resource_rates.clear()
	resource_rate_sample = resources.duplicate(true)
	resource_rate_sample_tick = 0
	next_resource_rate_tick = 100
	god_xp = ProgressionService.god_xp
	resource_nodes.clear()
	loose_items.clear()
	held_entity.clear()
	magic_circles.clear()
	catjeet_trader.clear()
	next_trade_arrival_tick = 600 + rng.randi_range(0, 300)
	next_nomad_tick = TICKS_PER_DAY * 2 + rng.randi_range(0, TICKS_PER_DAY)
	nomad_groups_spawned = 0
	for source_node in blueprint.resource_nodes:
		var resource_node: Dictionary = source_node.duplicate(true)
		resource_node["entity_id"] = _next_id()
		resource_node["initial_amount"] = int(resource_node.get("amount", 0))
		resource_nodes.append(resource_node)
	_seed_magic_circle_sites()
	corruption_cells.clear()
	terrain_effects.clear()
	terrain_work.clear()
	for y in blueprint.height:
		for x in blueprint.width:
			if blueprint.get_tile(Vector2i(x, y)) == RegionGenerator.Tile.CORRUPTION:
				corruption_cells[_cell_key(Vector2i(x, y))] = 1000
	jobs.clear()
	for job in ContentRegistry.get_all(&"jobs"):
		jobs[job.id] = {"desired": 0, "current": 0, "max": 0, "color": job.get("color", "#718096")}
	jobs.builders = {"desired": 12, "current": 12, "max": 12, "color": "#ffd166"}
	villagers.clear()
	for index in 20:
		var angle := TAU * float(index) / 20.0
		var radius := 5.0 + float(index % 4) * 1.7
		var age_stage := "child" if index < 3 else ("elder" if index >= 18 else "adult")
		villagers.append({
			"id": _next_id(),
			"name": "Villager %02d" % (index + 1),
			"species": "villager",
			"job": "builders" if index < 12 else "idle",
			"x": float(blueprint.starting_cell.x) + cos(angle) * radius,
			"y": float(blueprint.starting_cell.y) + sin(angle) * radius,
			"target_x": float(blueprint.starting_cell.x),
			"target_y": float(blueprint.starting_cell.y),
			"health": 1000,
			"hunger": 1000,
			"thirst": 1000,
			"energy": 1000,
			"faith": 500,
			"age_stage": age_stage,
			"age_days": 8 if age_stage == "child" else (120 if age_stage == "elder" else 30 + index),
			"sex": "female" if index % 2 == 0 else "male",
			"pregnant_ticks": 0,
			"partner_id": 0,
			"level": 1,
			"xp": 0,
			"task_id": 0,
			"task_kind": "",
			"task_progress": 0,
			"state": "idle",
			"home_id": 0,
			"status": [],
			"status_effects": {},
			"equipment": {},
			"attack_cooldown": 0,
			"path": [],
			"path_index": 0,
			"path_goal_x": -1,
			"path_goal_y": -1,
			"stuck_ticks": 0,
		})
	nomads.clear()
	buildings.clear()
	hostile_structures.clear()
	animals.clear()
	_spawn_starting_animals()
	golems.clear()
	monsters.clear()
	ghosts.clear()
	housing_capacity = 0
	animal_pen_capacity = 0
	clucker_coop_capacity = 0
	doggo_house_capacity = 0
	building_limit = 0
	build_range = 0
	ancillary_limit = 0
	task_board.reset()
	var first_goal_completed := ProgressionService.completed.has("you_already_lost")
	goals = {"build_first_camp": {"name": "You Already Lost", "description": "Build your first Camp.", "progress": 1 if first_goal_completed else 0, "target": 1, "completed": first_goal_completed, "xp": 60}}
	messages = ["Welcome to %s." % p_blueprint.region_id, "Place your Camp near wood, rock, food, crystal, and water."]
	command_queue.clear()
	region_started.emit(blueprint)
	_emit_snapshot()

func submit(command: GameCommand) -> bool:
	if not active:
		return false
	command_queue.append(command)
	command_queue.sort_custom(func(a: GameCommand, b: GameCommand) -> bool: return a.target_tick < b.target_tick)
	return true

func _seed_magic_circle_sites() -> void:
	var profile := ContentRegistry.get_by_id(&"loot_site_profiles", &"standard_magic_circles")
	if profile.is_empty() or blueprint == null:
		return
	var count := int(profile.get("site_count", 0))
	var key_sites := int(profile.get("key_sites", 0))
	var minimum_distance := float(profile.get("minimum_start_distance", 28))
	var occupied: Dictionary = {}
	for site_index in count:
		for attempt in 96:
			var hash := posmod(blueprint.seed * 92821 + site_index * site_index * 68917 + attempt * 104729 + site_index * attempt * 7919, 2147483629)
			var candidate := Vector2i(2 + posmod(hash, blueprint.width - 4), 2 + posmod(hash / 4099, blueprint.height - 4))
			var cell: Vector2i = pathfinder.nearest_walkable(candidate)
			var key := _cell_key(cell)
			if occupied.has(key) or Vector2(cell).distance_to(Vector2(blueprint.starting_cell)) < minimum_distance:
				continue
			occupied[key] = true
			magic_circles.append({
				"id": _next_id(), "x": cell.x, "y": cell.y,
				"payload": "suspicious_key" if site_index < key_sites else "lootbox",
				"variant": posmod(hash / 97, 4), "state": "sealed",
			})
			break

func _magic_circle_at(cell: Vector2i) -> Dictionary:
	for circle in magic_circles:
		if int(circle.get("x", -1)) == cell.x and int(circle.get("y", -1)) == cell.y:
			return circle
	return {}

func advance_tick() -> void:
	if not active:
		return
	_apply_due_commands()
	tick += 1
	if tick == 1 or tick % 10 == 0:
		_refresh_task_board()
	_update_villagers()
	_update_nomads()
	_update_population_life_cycle()
	_update_animals()
	_update_equipment()
	_update_buildings()
	_update_water_buildings()
	_update_natural_resources()
	_update_production()
	_update_golems()
	_update_catjeet_trade()
	_update_decay_and_trash()
	_update_held_hand()
	_update_needs()
	_update_combat_statuses()
	_update_death_and_ghosts()
	_update_corruption()
	_update_monsters()
	_update_hostile_structures()
	_update_towers()
	_update_god_structures()
	_update_influence()
	_update_weather_and_events()
	_update_terrain_effects()
	_update_resource_rates()
	WorldCampaignService.advance_ticks()
	if tick % TICKS_PER_DAY == 0:
		ProgressionService.record(&"days.survived")
	if tick % 5 == 0:
		_emit_snapshot()

func _apply_due_commands() -> void:
	while not command_queue.is_empty() and command_queue.front().target_tick <= tick:
		var command: GameCommand = command_queue.pop_front()
		match command.kind:
			GameCommand.Kind.SET_PAUSED:
				paused = bool(command.payload.get("paused", true))
			GameCommand.Kind.SET_SPEED:
				speed = clampi(int(command.payload.get("speed", 1)), 0, 4)
			GameCommand.Kind.PLACE_BUILDING:
				_place_building(command.payload)
			GameCommand.Kind.SET_JOB_DESIRED:
				_set_job_desired(command.payload)
			GameCommand.Kind.CAST_SPELL:
				_cast_spell(command.payload)
			GameCommand.Kind.UPGRADE_BUILDING:
				_upgrade_building(command.payload)
			GameCommand.Kind.SET_RECIPE_POLICY:
				_set_recipe_policy(command.payload)
			GameCommand.Kind.TRADE_RESOURCE:
				_trade_resource(command.payload)
			GameCommand.Kind.SET_TRADE_RULE:
				_set_trade_rule(command.payload)
			GameCommand.Kind.HIRE_CATJEET:
				_hire_catjeet(command.payload)
			GameCommand.Kind.DESIGNATE_ANIMAL_CAPTURE:
				_designate_animal_capture(command.payload)
			GameCommand.Kind.DESIGNATE_ANIMAL_SLAUGHTER:
				_designate_animal_slaughter(command.payload)
			GameCommand.Kind.SET_BUILDING_WORK:
				_set_building_work(command.payload)
			GameCommand.Kind.DESIGNATE_TERRAIN_WORK:
				_designate_terrain_work(command.payload)
			GameCommand.Kind.SET_STORAGE_FILTER:
				_set_storage_filter(command.payload)

func _place_building(payload: Dictionary) -> void:
	var building_id := StringName(payload.get("building_id", ""))
	var definition := ContentRegistry.get_by_id(&"buildings", building_id)
	if definition.is_empty():
		_emit_event(&"command_rejected", {"reason": "unknown_building", "building_id": building_id})
		return
	if not bool(definition.get("player_placeable", true)):
		_emit_event(&"command_rejected", {"reason": "hostile_structure", "building_id": building_id})
		return
	var cell := Vector2i(int(payload.get("cell_x", 0)), int(payload.get("cell_y", 0)))
	var footprint_data: Array = definition.get("footprint", [5, 5])
	var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
	if not bool(mode_rules.get("sandbox_tools", false)) and not _validate_settlement_placement(building_id, cell, footprint):
		return
	if not blueprint.is_buildable(cell, footprint) or _footprint_overlaps(cell, footprint):
		_emit_event(&"command_rejected", {"reason": "invalid_placement", "building_id": building_id})
		return
	var costs: Dictionary = definition.get("cost", {})
	if not bool(mode_rules.get("sandbox_tools", false)):
		for resource_id in costs:
			if int(resources.get(resource_id, 0)) < int(costs[resource_id]):
				_emit_event(&"command_rejected", {"reason": "missing_resources", "building_id": building_id, "resource": resource_id})
				return
		for resource_id in costs:
			consume_physical_resource(StringName(resource_id), int(costs[resource_id]))
	var building := {
		"id": _next_id(),
		"definition_id": String(building_id),
		"name": definition.get("name", String(building_id)),
		"category": definition.get("category", "misc"),
		"x": cell.x,
		"y": cell.y,
		"width": footprint.x,
		"height": footprint.y,
		"tier": 1,
		"progress": int(definition.get("build_time", 450)) if bool(mode_rules.get("instant_build", false)) else 0,
		"build_time": int(definition.get("build_time", 450)),
		"completed": false,
		"health": 1,
		"max_health": int(definition.get("health", 1000)),
		"operation_progress": 0,
		"active_recipe": "",
		"recipe_mode": "maintain",
		"recipe_target": 16,
		"recipe_remaining": 0,
		"trade_rules": {},
		"combat_cooldown": 0,
		"repair_designated": false,
		"dismantle_designated": false,
		"repair_batch_remaining": 0,
		"service_state": "none",
		"destroyed": false,
		"burning": false,
		"status_effects": {},
		# Presentation-facing ownership/state fields are part of the authoritative
		# save payload even before hostile construction and reclamation mutate them.
		# Stable defaults keep old saves and every building family visually safe.
		"ownership": "settlement",
		"visual_state": "normal",
		"abandoned": false,
		"corrupted": false,
		"reclaimed_ticks": 0,
		"operation_state": "idle",
		"combat_state": "idle",
		"stored_resources": {},
		"storage_caps": {},
		"water_cycle_progress": 0,
	}
	_configure_water_runtime(building, definition)
	_configure_storage_runtime(building, definition)
	buildings.append(building)
	_emit_event(&"building_placed", {"building_id": building.id, "definition_id": building_id})
	AudioDirector.play_cue(&"building_placed")

func _validate_settlement_placement(building_id: StringName, cell: Vector2i, footprint: Vector2i) -> bool:
	if building_id == &"camp" and buildings.any(func(building: Dictionary) -> bool: return String(building.definition_id) == "camp" and not bool(building.get("destroyed", false))):
		_emit_event(&"command_rejected", {"reason": "camp_already_exists", "building_id": building_id})
		return false
	var camp: Dictionary = {}
	for building in buildings:
		if String(building.definition_id) == "camp" and bool(building.completed) and not bool(building.get("destroyed", false)):
			camp = building
			break
	if camp.is_empty():
		if building_id != &"camp":
			_emit_event(&"command_rejected", {"reason": "camp_required", "building_id": building_id})
			return false
		return true
	var definition := ContentRegistry.get_by_id(&"buildings", building_id)
	if String(definition.get("category", "")) not in ["walls", "roads"]:
		var counted := 0
		for building in buildings:
			if bool(building.get("destroyed", false)):
				continue
			var placed_definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
			if String(placed_definition.get("category", "")) not in ["walls", "roads"]:
				counted += 1
		if counted >= building_limit:
			_emit_event(&"command_rejected", {"reason": "building_limit", "building_id": building_id, "limit": building_limit})
			return false
	if building_id == &"ancillary":
		var ancillary_count := buildings.filter(func(building: Dictionary) -> bool: return String(building.definition_id) == "ancillary" and not bool(building.get("destroyed", false))).size()
		if ancillary_count >= ancillary_limit:
			_emit_event(&"command_rejected", {"reason": "ancillary_limit", "building_id": building_id, "limit": ancillary_limit})
			return false
	if not is_within_settlement_range(cell, footprint):
		_emit_event(&"command_rejected", {"reason": "out_of_range", "building_id": building_id, "range": build_range})
		return false
	return true

func get_building_settlement_range(building: Dictionary) -> int:
	if not bool(building.get("completed", false)) or bool(building.get("destroyed", false)):
		return 0
	if String(building.get("category", "")) == "god_structure":
		return 0
	var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.get("definition_id", "")))
	var category := String(definition.get("category", ""))
	if category in ["walls", "roads", "hostile"]:
		return 0
	var tier := maxi(1, int(building.get("tier", 1)))
	if String(building.get("definition_id", "")) == "camp":
		return int(_town_center_tier(tier).get("range", build_range))
	var range_definition: Dictionary = definition.get("settlement_range", {})
	if not range_definition.is_empty():
		var result := int(range_definition.get("base", DEFAULT_SETTLEMENT_RANGE)) + int(range_definition.get("per_tier", 0)) * (tier - 1)
		return mini(result, int(range_definition.get("maximum", result)))
	# Most current non-wall buildings cast settlement/corruption coverage. Exact
	# per-family Update 2d radii are still being audited, so unverified families
	# share one explicit provisional fallback rather than silently casting nothing.
	return DEFAULT_SETTLEMENT_RANGE

func is_within_settlement_range(cell: Vector2i, footprint: Vector2i = Vector2i.ONE) -> bool:
	var placement_center := Vector2(cell) + Vector2(footprint) * 0.5
	for building in buildings:
		var range := get_building_settlement_range(building)
		if range <= 0:
			continue
		var source_center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
		if source_center.distance_to(placement_center) <= float(range):
			return true
	return false

func _settlement_range_sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building in buildings:
		var range := get_building_settlement_range(building)
		if range <= 0:
			continue
		result.append({
			"building_id": int(building.id),
			"center": Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5),
			"range": range,
		})
	return result

func _corruption_resistance_at(cell: Vector2i, sources: Array[Dictionary]) -> float:
	var resistance := 0.0
	var position := Vector2(cell) + Vector2(0.5, 0.5)
	for source in sources:
		var range := float(source.range)
		var distance := Vector2(source.center).distance_to(position)
		if distance <= range:
			resistance = maxf(resistance, range - distance + 1.0)
	return resistance

func _configure_water_runtime(building: Dictionary, definition: Dictionary) -> void:
	var water: Dictionary = definition.get("water", {})
	if water.is_empty():
		return
	var stored: Dictionary = building.get("stored_resources", {}).duplicate(true)
	var caps: Dictionary = building.get("storage_caps", {}).duplicate(true)
	var tier := maxi(1, int(building.get("tier", 1)))
	var clean_capacity := int(water.get("clean_capacity", 0)) + int(water.get("clean_capacity_per_tier", 0)) * tier
	var dirty_capacity := int(water.get("dirty_capacity", 0)) + int(water.get("dirty_capacity_per_tier", 0)) * tier
	if clean_capacity > 0:
		caps.clean_water = clean_capacity
		stored.clean_water = clampi(int(stored.get("clean_water", 0)), 0, clean_capacity)
	if dirty_capacity > 0:
		caps.dirty_water = dirty_capacity
		stored.dirty_water = clampi(int(stored.get("dirty_water", 0)), 0, dirty_capacity)
	building.stored_resources = stored
	building.storage_caps = caps
	building.water_cycle_progress = int(building.get("water_cycle_progress", 0))

func get_storage_profile_resources(building: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if building.is_empty():
		return result
	var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.get("definition_id", "")))
	var profile: Dictionary = definition.get("storage_profile", {})
	if profile.is_empty():
		return result
	for resource_id in profile.get("resources", []):
		var normalized := String(resource_id)
		if not normalized.is_empty() and normalized not in result:
			result.append(normalized)
	var accepted_groups: Array = profile.get("accepted_groups", [])
	if not accepted_groups.is_empty():
		for resource_definition in ContentRegistry.get_all(&"resources"):
			if String(resource_definition.get("group", "")) in accepted_groups:
				var candidate_id := String(resource_definition.get("id", ""))
				if not candidate_id.is_empty() and candidate_id not in result:
					result.append(candidate_id)
	var excluded: Array = profile.get("excluded_resources", [])
	for resource_id in excluded:
		result.erase(String(resource_id))
	result.sort()
	return result

func get_storage_profile_capacity(building: Dictionary) -> int:
	if building.is_empty():
		return 0
	var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.get("definition_id", "")))
	var profile: Dictionary = definition.get("storage_profile", {})
	var capacities: Array = profile.get("capacity_by_tier", [])
	if capacities.is_empty():
		return 0
	var tier_index := clampi(int(building.get("tier", 1)) - 1, 0, capacities.size() - 1)
	return maxi(0, int(capacities[tier_index]))

func _configure_storage_runtime(building: Dictionary, definition: Dictionary) -> void:
	if definition.get("storage_profile", {}).is_empty():
		return
	var filters: Dictionary = building.get("storage_filters", {}).duplicate(true)
	for resource_id in get_storage_profile_resources(building):
		if not filters.has(resource_id):
			filters[resource_id] = true
	building.storage_filters = filters
	_update_storage_operation_state(building)

func _update_storage_operation_state(building: Dictionary) -> void:
	if String(building.get("category", "")) != "storage":
		return
	var accepted := get_storage_profile_resources(building)
	var enabled_count := 0
	var filters: Dictionary = building.get("storage_filters", {})
	for resource_id in accepted:
		if bool(filters.get(resource_id, true)):
			enabled_count += 1
	building.operation_state = "storage_blocked" if enabled_count == 0 else ("storage_filtered" if enabled_count < accepted.size() else "storage_ready")

func _set_storage_filter(payload: Dictionary) -> void:
	var building := _find_building(int(payload.get("building_entity_id", 0)))
	var resource_id := String(payload.get("resource_id", ""))
	if building.is_empty() or resource_id not in get_storage_profile_resources(building):
		_emit_event(&"command_rejected", {"reason": "invalid_storage_filter", "resource_id": resource_id})
		return
	var filters: Dictionary = building.get("storage_filters", {}).duplicate(true)
	filters[resource_id] = bool(payload.get("enabled", true))
	building.storage_filters = filters
	_update_storage_operation_state(building)
	_recalculate_resource_caps()
	_emit_event(&"storage_filter_changed", {"building_id": int(building.id), "resource_id": resource_id, "enabled": bool(filters[resource_id])})

func _upgrade_building(payload: Dictionary) -> void:
	var building := _find_building(int(payload.get("building_entity_id", 0)))
	if building.is_empty() or not bool(building.completed) or bool(building.get("destroyed", false)):
		_emit_event(&"command_rejected", {"reason": "building_not_ready"})
		return
	var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
	var current_tier := int(building.tier)
	var maximum_tier := int(definition.get("tiers", 1))
	if current_tier >= maximum_tier:
		_emit_event(&"command_rejected", {"reason": "maximum_tier", "building_id": building.id})
		return
	var requested_branch := StringName(payload.get("branch", ""))
	if String(building.definition_id) == "housing":
		if current_tier == 2 and requested_branch not in [&"quality", &"occupancy"]:
			requested_branch = &"quality"
		elif current_tier >= 3:
			requested_branch = StringName(building.get("housing_branch", "quality"))
	var preview := get_upgrade_preview(int(building.id), requested_branch)
	var costs: Dictionary = preview.get("cost", {})
	if not bool(mode_rules.get("sandbox_tools", false)):
		for resource_id in costs:
			if int(resources.get(resource_id, 0)) < int(costs[resource_id]):
				_emit_event(&"command_rejected", {"reason": "missing_resources", "building_id": building.id, "resource": resource_id})
				return
		for resource_id in costs:
			consume_physical_resource(StringName(resource_id), int(costs[resource_id]))
	building.completed = false
	building.progress = int(preview.get("build_time", definition.get("build_time", 450))) if bool(mode_rules.get("instant_build", false)) else 0
	building.build_time = int(preview.get("build_time", definition.get("build_time", 450)))
	building.upgrade_target_tier = current_tier + 1
	building.upgrade_target_name = String(preview.get("name", building.name))
	building.upgrade_target_health = int(preview.get("health", building.max_health))
	if String(building.definition_id) == "housing" and not String(requested_branch).is_empty():
		building.upgrade_target_branch = String(requested_branch)
	building.upgrading = true
	_emit_event(&"building_upgrade_started", {"building_id": building.id, "tier": current_tier + 1})
	_recalculate_settlement_support()

func get_upgrade_preview(building_entity_id: int, requested_branch: StringName = &"") -> Dictionary:
	var building := _find_building(building_entity_id)
	if building.is_empty():
		return {}
	var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
	var target_tier := int(building.tier) + 1
	if target_tier > int(definition.get("tiers", 1)):
		return {}
	if String(building.definition_id) == "camp":
		var tier_definition := _town_center_tier(target_tier)
		return {
			"tier": target_tier, "name": tier_definition.get("name", "Town Center Tier %d" % target_tier),
			"cost": tier_definition.get("cost", {}).duplicate(true), "health": int(tier_definition.get("health", building.max_health)),
			"build_time": int(definition.get("build_time", 600)) + (target_tier - 2) * 40,
			"builders": int(tier_definition.get("builders", 12)), "range": int(tier_definition.get("range", 32)),
			"storage": int(tier_definition.get("storage", 20)), "building_limit": int(tier_definition.get("building_limit", 8)),
		}
	var scaled_cost: Dictionary = {}
	for resource_id in definition.get("cost", {}):
		scaled_cost[resource_id] = maxi(1, ceili(float(definition.cost[resource_id]) * (0.65 + float(target_tier - 1) * 0.35)))
	var target_name := "%s Tier %d" % [definition.get("name", building.name), target_tier]
	if String(building.definition_id) == "housing":
		var branch := String(requested_branch)
		if branch.is_empty() and target_tier >= 3:
			branch = String(building.get("housing_branch", "quality"))
		if target_tier == 2:
			target_name = "Standard Housing"
		elif branch == "occupancy":
			target_name = "Reinforced High Occupancy House" if target_tier >= 7 else "High Occupancy House Tier %d" % target_tier
		else:
			target_name = "Reinforced High Quality House" if target_tier >= 7 else "High Quality House Tier %d" % target_tier
	return {
		"tier": target_tier, "name": target_name,
		"cost": scaled_cost, "health": roundi(float(definition.get("health", building.max_health)) * (1.0 + float(target_tier - 1) * 0.28)),
		"build_time": roundi(float(definition.get("build_time", 450)) * (0.75 + float(target_tier) * 0.2)),
	}

func _town_center_tier(tier: int) -> Dictionary:
	for tier_definition in ContentRegistry.get_all(&"town_center_tiers"):
		if int(tier_definition.get("tier", 0)) == tier:
			return tier_definition
	return {}

func get_recipes_for_building(building_entity_id: int) -> Array[Dictionary]:
	var building := _find_building(building_entity_id)
	var result: Array[Dictionary] = []
	if building.is_empty():
		return result
	for recipe in ContentRegistry.get_all(&"recipes"):
		if String(recipe.get("building", "")) == String(building.definition_id):
			result.append(recipe)
	return result

func _set_recipe_policy(payload: Dictionary) -> void:
	var building := _find_building(int(payload.get("building_entity_id", 0)))
	if building.is_empty() or not bool(building.completed):
		_emit_event(&"command_rejected", {"reason": "building_not_ready"})
		return
	var recipe_id := String(payload.get("recipe_id", ""))
	var valid_recipe := false
	for recipe in get_recipes_for_building(int(building.id)):
		if String(recipe.id) == recipe_id:
			valid_recipe = true
			break
	var policy_mode := String(payload.get("mode", "maintain"))
	if not valid_recipe or policy_mode not in ["paused", "maintain", "make"]:
		_emit_event(&"command_rejected", {"reason": "invalid_recipe_policy", "building_id": building.id})
		return
	building.active_recipe = recipe_id
	building.recipe_mode = policy_mode
	building.recipe_target = maxi(0, int(payload.get("target", 0)))
	building.recipe_remaining = int(building.recipe_target) if policy_mode == "make" else 0
	building.operation_progress = 0
	_emit_event(&"recipe_policy_changed", {"building_id": building.id, "recipe_id": recipe_id, "mode": policy_mode, "target": building.recipe_target})

func _set_building_work(payload: Dictionary) -> void:
	var building := _find_building(int(payload.get("building_entity_id", 0)))
	if building.is_empty() or bool(building.get("destroyed", false)):
		_emit_event(&"command_rejected", {"reason": "building_unavailable"})
		return
	var action := String(payload.get("action", ""))
	var enabled := bool(payload.get("enabled", true))
	match action:
		"prioritize_repair":
			if not bool(building.get("completed", false)):
				_emit_event(&"command_rejected", {"reason": "building_not_ready", "building_id": building.id})
				return
			building.repair_designated = enabled
			if enabled:
				building.dismantle_designated = false
				building.service_state = "repair_requested"
		"dismantle":
			building.dismantle_designated = enabled
			building.repair_designated = false
			building.service_state = "dismantle_requested" if enabled else "none"
			if not enabled:
				building.dismantle_progress = 0
		_:
			_emit_event(&"command_rejected", {"reason": "unknown_building_work", "action": action})
			return
	_refresh_task_board()
	_emit_event(&"building_work_designated", {"building_id": building.id, "action": action, "enabled": enabled})

func _designate_terrain_work(payload: Dictionary) -> void:
	var action := StringName(payload.get("action", ""))
	var cell := Vector2i(int(payload.get("cell_x", -1)), int(payload.get("cell_y", -1)))
	var enabled := bool(payload.get("enabled", true))
	var key := _cell_key(cell)
	if not enabled:
		if terrain_work.has(key):
			terrain_work.erase(key)
			_refresh_task_board()
			_emit_event(&"terrain_work_canceled", {"action": action, "cell_x": cell.x, "cell_y": cell.y})
		return
	if not can_designate_terrain_work(action, cell):
		_emit_event(&"command_rejected", {"reason": "invalid_terrain_work", "action": action, "cell_x": cell.x, "cell_y": cell.y})
		return
	var target := _terrain_work_target(action)
	var existing: Dictionary = terrain_work.get(key, {})
	terrain_work[key] = {
		"action": String(action),
		"progress": int(existing.get("progress", 0)) if String(existing.get("action", "")) == String(action) else 0,
		"target": target,
		"state": "designated",
	}
	_refresh_task_board()
	_emit_event(&"terrain_work_designated", {"action": action, "cell_x": cell.x, "cell_y": cell.y, "target": target})

func can_designate_terrain_work(action: StringName, cell: Vector2i) -> bool:
	if blueprint == null or action not in [&"clear", &"dig", &"fill", &"restore"]:
		return false
	if cell.x < 1 or cell.y < 1 or cell.x >= blueprint.width - 1 or cell.y >= blueprint.height - 1:
		return false
	if not bool(mode_rules.get("sandbox_tools", false)) and not is_within_settlement_range(cell, Vector2i.ONE):
		return false
	for building in buildings:
		if not bool(building.get("destroyed", false)) and Rect2i(Vector2i(int(building.x), int(building.y)), Vector2i(int(building.width), int(building.height))).has_point(cell):
			return false
	for structure in hostile_structures:
		if not bool(structure.get("destroyed", false)) and Rect2i(Vector2i(int(structure.x), int(structure.y)), Vector2i(int(structure.width), int(structure.height))).has_point(cell):
			return false
	var effect: Dictionary = terrain_effects.get(_cell_key(cell), {})
	var effect_kind := String(effect.get("kind", ""))
	match String(action):
		"clear":
			return not _magic_circle_at(cell).is_empty() or not _find_resource_node_at_cell(cell).is_empty() or blueprint.get_tile(cell) in [RegionGenerator.Tile.FOREST_FLOOR, RegionGenerator.Tile.ROCKY, RegionGenerator.Tile.CRYSTAL_GROUND, RegionGenerator.Tile.FERTILE, RegionGenerator.Tile.MARSH]
		"dig":
			return blueprint.get_tile(cell) in [RegionGenerator.Tile.GRASS, RegionGenerator.Tile.FERTILE, RegionGenerator.Tile.SAND, RegionGenerator.Tile.MARSH] and effect_kind.is_empty()
		"fill":
			return effect_kind == "hole"
		"restore":
			return effect_kind in ["ash", "mud", "flood"]
	return false

func _terrain_work_target(action: StringName) -> int:
	var service := _maintenance_service()
	return maxi(1, int(service.get("%s_ticks" % String(action), {&"clear": 80, &"dig": 100, &"fill": 70, &"restore": 60}.get(action, 80))))

func _update_catjeet_trade() -> void:
	if not catjeet_trader.is_empty() and tick >= int(catjeet_trader.get("depart_tick", tick + 1)):
		_emit_event(&"catjeet_departed", {"trader_id": catjeet_trader.get("id", 0)})
		catjeet_trader.clear()
		next_trade_arrival_tick = tick + 600 + rng.randi_range(0, 600)
	if catjeet_trader.is_empty() and tick >= next_trade_arrival_tick and not _first_operational_marketplace().is_empty():
		_spawn_catjeet_trader()
	if catjeet_trader.is_empty() or tick % 20 != 0:
		return
	for marketplace in buildings:
		if String(marketplace.definition_id) != "marketplace" or not bool(marketplace.completed) or bool(marketplace.get("destroyed", false)):
			continue
		var rule_ids: Array = marketplace.get("trade_rules", {}).keys()
		rule_ids.sort()
		for resource_id in rule_ids:
			var rule: Dictionary = marketplace.trade_rules[resource_id]
			var current := int(resources.get(resource_id, 0))
			var batch := maxi(1, int(rule.get("batch", 8)))
			var buy_below := int(rule.get("buy_below", 0))
			var sell_above := int(rule.get("sell_above", 0))
			if buy_below > 0 and current < buy_below:
				_perform_trade(marketplace, &"buy", StringName(resource_id), mini(batch, buy_below - current), true)
			elif sell_above > 0 and current > sell_above:
				_perform_trade(marketplace, &"sell", StringName(resource_id), mini(batch, current - sell_above), true)

func _spawn_catjeet_trader() -> void:
	var inventory: Dictionary = {}
	for good in ContentRegistry.get_all(&"trade_goods"):
		inventory[String(good.resource_id)] = rng.randi_range(int(good.get("stock_min", 0)), int(good.get("stock_max", 0)))
	catjeet_trader = {
		"id": _next_id(), "name": "Catjeet Caravan", "inventory": inventory,
		"gold_coins": 2400, "laborers": rng.randi_range(1, 3), "laborer_price": 250,
		"arrived_tick": tick, "depart_tick": tick + 400,
	}
	_emit_event(&"catjeet_arrived", {"trader_id": catjeet_trader.id, "depart_tick": catjeet_trader.depart_tick})

func _first_operational_marketplace() -> Dictionary:
	if int(jobs.get("provisioners", {}).get("current", 0)) <= 0:
		return {}
	for building in buildings:
		if String(building.definition_id) == "marketplace" and bool(building.completed) and not bool(building.get("destroyed", false)):
			return building
	return {}

func _trade_resource(payload: Dictionary) -> void:
	var marketplace := _find_building(int(payload.get("marketplace_entity_id", 0)))
	var direction := StringName(payload.get("direction", ""))
	var resource_id := StringName(payload.get("resource_id", ""))
	var amount := maxi(1, int(payload.get("amount", 1)))
	if not _perform_trade(marketplace, direction, resource_id, amount, false):
		_emit_event(&"command_rejected", {"reason": "trade_unavailable", "resource_id": resource_id, "direction": direction, "amount": amount})

func _perform_trade(marketplace: Dictionary, direction: StringName, resource_id: StringName, amount: int, automatic: bool) -> bool:
	if marketplace.is_empty() or String(marketplace.get("definition_id", "")) != "marketplace" or not bool(marketplace.get("completed", false)) or bool(marketplace.get("destroyed", false)):
		return false
	if catjeet_trader.is_empty() or int(jobs.get("provisioners", {}).get("current", 0)) <= 0 or amount <= 0:
		return false
	var good := _trade_good_for_resource(resource_id)
	if good.is_empty():
		return false
	var stock := int(catjeet_trader.inventory.get(String(resource_id), 0))
	if direction == &"buy":
		var price := int(good.buy_price) * amount
		if stock < amount or int(resources.gold_coins) < price or int(resources.get(resource_id, 0)) + amount > int(resource_caps.get(resource_id, 0)):
			return false
		catjeet_trader.inventory[String(resource_id)] = stock - amount
		catjeet_trader.gold_coins = int(catjeet_trader.gold_coins) + price
		consume_physical_resource(&"gold_coins", price)
		add_physical_resource(resource_id, amount)
		if resource_id == &"suspicious_key":
			ProgressionService.record(&"trade.keys_bought", amount)
	elif direction == &"sell":
		var payout := int(good.sell_price) * amount
		if int(resources.get(resource_id, 0)) < amount or int(catjeet_trader.gold_coins) < payout:
			return false
		consume_physical_resource(resource_id, amount)
		add_physical_resource(&"gold_coins", payout)
		catjeet_trader.gold_coins = int(catjeet_trader.gold_coins) - payout
		catjeet_trader.inventory[String(resource_id)] = stock + amount
		if resource_id == &"god_dust":
			ProgressionService.record(&"trade.god_dust_sold", amount)
		elif resource_id == &"filled_eerie_vessel":
			ProgressionService.record(&"trade.filled_vessels_sold", amount)
	else:
		return false
	ProgressionService.record(&"trade.resources", amount)
	_emit_event(&"trade_completed", {"marketplace_id": marketplace.id, "direction": direction, "resource_id": resource_id, "amount": amount, "automatic": automatic})
	return true

func _is_physical_resource(resource_id: StringName) -> bool:
	return resource_id not in [&"energy", &"faith"]

func add_physical_resource(resource_id: StringName, amount: int, location_state: int = PhysicalInventory.LocationState.GROUND, grid_cell: Vector2i = Vector2i.ZERO, container_id: int = 0) -> void:
	if amount <= 0:
		return
	if not _is_physical_resource(resource_id):
		resources[String(resource_id)] = int(resources.get(String(resource_id), 0)) + amount
		return
	inventory.add_commodity(resource_id, amount, location_state as PhysicalInventory.LocationState, grid_cell, container_id)
	resources[String(resource_id)] = inventory.get_total(resource_id)

func consume_physical_resource(resource_id: StringName, amount: int, container_id: int = 0) -> bool:
	if amount <= 0:
		return true
	if not _is_physical_resource(resource_id):
		var current := int(resources.get(String(resource_id), 0))
		if current < amount:
			return false
		resources[String(resource_id)] = current - amount
		return true
	var consumed := inventory.consume_available(resource_id, amount, container_id)
	if consumed:
		resources[String(resource_id)] = inventory.get_total(resource_id)
	return consumed

func set_physical_resource(resource_id: StringName, amount: int, grid_cell: Vector2i = Vector2i.ZERO) -> bool:
	var target := maxi(0, amount)
	var current := int(resources.get(String(resource_id), 0))
	if not _is_physical_resource(resource_id):
		resources[String(resource_id)] = target
		return true
	if target > current:
		add_physical_resource(resource_id, target - current, PhysicalInventory.LocationState.GROUND, grid_cell)
		return true
	if target < current:
		return consume_physical_resource(resource_id, current - target)
	return true

func add_physical_resource_capped(resource_id: StringName, amount: int, grid_cell: Vector2i = Vector2i.ZERO) -> int:
	var accepted := mini(maxi(0, amount), maxi(0, int(resource_caps.get(String(resource_id), 200)) - int(resources.get(String(resource_id), 0))))
	if accepted > 0:
		add_physical_resource(resource_id, accepted, PhysicalInventory.LocationState.GROUND, grid_cell)
	return accepted

func sync_derived_resources() -> void:
	for resource_def in ContentRegistry.get_all(&"resources"):
		var res_name := String(resource_def.id)
		if _is_physical_resource(StringName(res_name)):
			resources[res_name] = inventory.get_total(StringName(res_name))

func _trade_good_for_resource(resource_id: StringName) -> Dictionary:
	for good in ContentRegistry.get_all(&"trade_goods"):
		if String(good.resource_id) == String(resource_id):
			return good
	return {}

func _set_trade_rule(payload: Dictionary) -> void:
	var marketplace := _find_building(int(payload.get("marketplace_entity_id", 0)))
	var resource_id := StringName(payload.get("resource_id", ""))
	if marketplace.is_empty() or String(marketplace.get("definition_id", "")) != "marketplace" or not bool(marketplace.get("completed", false)) or _trade_good_for_resource(resource_id).is_empty():
		_emit_event(&"command_rejected", {"reason": "invalid_trade_rule"})
		return
	var buy_below := maxi(0, int(payload.get("buy_below", 0)))
	var sell_above := maxi(0, int(payload.get("sell_above", 0)))
	if buy_below > 0 and sell_above > 0 and buy_below >= sell_above:
		_emit_event(&"command_rejected", {"reason": "overlapping_trade_rule"})
		return
	marketplace.trade_rules[String(resource_id)] = {"buy_below": buy_below, "sell_above": sell_above, "batch": maxi(1, int(payload.get("batch", 8)))}
	_emit_event(&"trade_rule_changed", {"marketplace_id": marketplace.id, "resource_id": resource_id, "buy_below": buy_below, "sell_above": sell_above})

func _hire_catjeet(payload: Dictionary) -> void:
	var marketplace := _find_building(int(payload.get("marketplace_entity_id", 0)))
	var amount := maxi(1, int(payload.get("amount", 1)))
	var unit_price := int(catjeet_trader.get("laborer_price", 250))
	if marketplace.is_empty() or String(marketplace.get("definition_id", "")) != "marketplace" or catjeet_trader.is_empty() or int(jobs.get("provisioners", {}).get("current", 0)) <= 0:
		_emit_event(&"command_rejected", {"reason": "catjeet_hiring_unavailable"})
		return
	if int(catjeet_trader.get("laborers", 0)) < amount or int(resources.gold_coins) < unit_price * amount:
		_emit_event(&"command_rejected", {"reason": "catjeet_hiring_unaffordable"})
		return
	consume_physical_resource(&"gold_coins", unit_price * amount)
	catjeet_trader.gold_coins = int(catjeet_trader.gold_coins) + unit_price * amount
	catjeet_trader.laborers = int(catjeet_trader.laborers) - amount
	for _index in amount:
		_add_catjeet_laborer(marketplace)
	ProgressionService.record(&"trade.catjeet_laborers_hired", amount)
	_emit_event(&"catjeet_hired", {"amount": amount, "marketplace_id": marketplace.id})

func _add_catjeet_laborer(marketplace: Dictionary) -> void:
	var entity_id := _next_id()
	villagers.append({
		"id": entity_id, "name": "Catjeet %02d" % entity_id, "species": "catjeet", "job": "idle",
		"x": float(marketplace.x) + float(marketplace.width) * 0.5, "y": float(marketplace.y) + float(marketplace.height) * 0.5,
		"target_x": float(marketplace.x), "target_y": float(marketplace.y), "health": 900, "hunger": 900, "thirst": 900, "energy": 900, "faith": 350,
		"age_stage": "adult", "age_days": 35, "sex": "female" if entity_id % 2 == 0 else "male", "pregnant_ticks": 0, "partner_id": 0,
		"level": 1, "xp": 0, "task_id": 0, "task_kind": "", "task_progress": 0, "state": "hired", "home_id": 0, "status": [], "status_effects": {}, "equipment": {}, "attack_cooldown": 0,
		"path": [], "path_index": 0, "path_goal_x": -1, "path_goal_y": -1, "stuck_ticks": 0,
	})

func _footprint_overlaps(cell: Vector2i, footprint: Vector2i) -> bool:
	var rect := Rect2i(cell, footprint)
	for building in buildings:
		if rect.intersects(Rect2i(Vector2i(building.x, building.y), Vector2i(building.width, building.height))):
			return true
	for structure in hostile_structures:
		if bool(structure.get("destroyed", false)):
			continue
		if rect.intersects(Rect2i(Vector2i(structure.x, structure.y), Vector2i(structure.width, structure.height))):
			return true
	return false

func _update_buildings() -> void:
	for building in buildings:
		if building.completed or bool(building.get("destroyed", false)):
			continue
		building.health = maxi(1, int(float(building.max_health) * float(building.progress) / float(building.build_time)))
		if building.progress >= building.build_time:
			building.progress = building.build_time
			building.health = building.max_health
			building.completed = true
			_complete_building(building)

func _complete_building(building: Dictionary) -> void:
	var was_upgrade := bool(building.get("upgrading", false))
	if was_upgrade:
		building.tier = int(building.get("upgrade_target_tier", building.tier))
		building.name = String(building.get("upgrade_target_name", building.name))
		building.max_health = int(building.get("upgrade_target_health", building.max_health))
		building.health = building.max_health
		if String(building.definition_id) == "housing" and building.has("upgrade_target_branch"):
			building.housing_branch = String(building.upgrade_target_branch)
		building.upgrading = false
	_configure_water_runtime(building, ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id)))
	_recalculate_settlement_support()
	AudioDirector.play_cue(&"building_completed")
	if not was_upgrade:
		ProgressionService.record(StringName("buildings.completed.%s" % String(building.definition_id)))
		if String(building.category) != "walls":
			ProgressionService.record(&"buildings.completed.non_wall")
		if String(building.category) == "towers":
			ProgressionService.record(&"buildings.completed.tower")
		elif String(building.category) == "storage":
			ProgressionService.record(&"buildings.completed.storage")
		elif String(building.category) == "roads":
			ProgressionService.record(StringName("roads.built.%s" % String(building.definition_id)))
		elif String(building.category) == "walls":
			ProgressionService.record(StringName("walls.built.%s" % String(building.definition_id)))
	if was_upgrade:
		ProgressionService.record(&"buildings.upgraded")
		ProgressionService.record(StringName("buildings.upgraded.%s" % String(building.definition_id)))
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
		if int(building.tier) >= int(definition.get("tiers", 1)):
			ProgressionService.record(StringName("buildings.max_upgraded.%s" % String(building.definition_id)))
			if String(building.category) == "towers":
				ProgressionService.record(&"buildings.max_upgraded.tower")
		if String(building.definition_id) == "camp" and int(building.tier) == 15:
			ProgressionService.record(&"town_center.large_castle")
		elif String(building.definition_id) == "housing":
			var housing_branch := String(building.get("housing_branch", ""))
			if int(building.tier) == 3 and not bool(building.get("branch_goal_recorded", false)):
				building.branch_goal_recorded = true
				ProgressionService.record(StringName("buildings.housing.%s" % ("high_occupancy" if housing_branch == "occupancy" else "high_quality")))
			if int(building.tier) >= 7 and not bool(building.get("reinforced_branch_goal_recorded", false)):
				building.reinforced_branch_goal_recorded = true
				ProgressionService.record(StringName("buildings.housing.%s" % ("reinforced_high_occupancy" if housing_branch == "occupancy" else "reinforced_high_quality")))
	_emit_event(&"building_completed", {"building_id": building.id, "definition_id": building.definition_id})
	messages.push_front("%s completed." % building.name)
	if messages.size() > 6:
		messages.resize(6)
	if building.definition_id == "camp" and not goals.build_first_camp.completed:
		goals.build_first_camp.progress = 1
		goals.build_first_camp.completed = true
		ProgressionService.add_god_xp(int(goals.build_first_camp.xp))
		god_xp = ProgressionService.god_xp
		_emit_event(&"goal_completed", {"goal_id": "build_first_camp", "xp": goals.build_first_camp.xp})
		AudioDirector.play_cue(&"goal_completed")
	_apply_navigation_building(building)

func _refresh_task_board() -> void:
	var active_keys: Dictionary = {}
	_refresh_automatic_slaughter_designations()
	for building in buildings:
		if bool(building.get("destroyed", false)):
			continue
		var center_x := float(building.x) + float(building.width) * 0.5
		var center_y := float(building.y) + float(building.height) * 0.5
		if bool(building.get("dismantle_designated", false)) and int(jobs.get("maintainers", {}).get("max", 0)) > 0:
			var dismantle_key := "dismantle:%d" % int(building.id)
			active_keys[dismantle_key] = true
			task_board.upsert(dismantle_key, {
				"kind": "dismantle", "job_id": "maintainers", "target_id": int(building.id),
				"x": center_x, "y": center_y, "max_claims": 1, "priority": 3,
			})
			continue
		if not bool(building.completed):
			var construction_key := "construct:%d" % int(building.id)
			active_keys[construction_key] = true
			task_board.upsert(construction_key, {
				"kind": "construct", "job_id": "builders", "target_id": int(building.id),
				"x": center_x, "y": center_y, "max_claims": 8,
			})
		elif int(building.health) < int(building.max_health) and int(jobs.get("maintainers", {}).get("max", 0)) > 0:
			var repair_key := "repair:%d" % int(building.id)
			active_keys[repair_key] = true
			task_board.upsert(repair_key, {
				"kind": "repair", "job_id": "maintainers", "target_id": int(building.id),
				"x": center_x, "y": center_y, "max_claims": 2 if bool(building.get("repair_designated", false)) else 1,
				"priority": 2 if bool(building.get("repair_designated", false)) else 0,
			})
		if bool(building.get("completed", false)):
			var operation_definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
			if _building_requires_workplace_attendance(operation_definition):
				var worker_slots := _building_worker_slots(building, operation_definition)
				for operation_job_id in operation_definition.get("jobs", []):
					if int(jobs.get(String(operation_job_id), {}).get("max", 0)) <= 0:
						continue
					var operation_key := "operate:%d:%s" % [int(building.id), String(operation_job_id)]
					active_keys[operation_key] = true
					task_board.upsert(operation_key, {
						"kind": "operate_building", "job_id": String(operation_job_id), "target_id": int(building.id),
						"x": center_x, "y": center_y, "max_claims": maxi(1, worker_slots), "priority": 2,
					})
	if int(jobs.get("maintainers", {}).get("max", 0)) > 0:
		var terrain_keys: Array = terrain_work.keys()
		terrain_keys.sort()
		for work_key_value in terrain_keys:
			var work_key := String(work_key_value)
			var work: Dictionary = terrain_work[work_key]
			var work_cell := _cell_from_key(work_key)
			var task_key := "terrain:%s" % work_key
			active_keys[task_key] = true
			task_board.upsert(task_key, {
				"kind": "terrain_work", "job_id": "maintainers", "terrain_key": work_key,
				"action": String(work.get("action", "")), "x": float(work_cell.x) + 0.5, "y": float(work_cell.y) + 0.5,
				"max_claims": 1, "priority": 1,
			})
	var harvest_jobs := {
		"wood": "lumberjacks",
		"rock": "miners",
		"crystal": "crystal_harvesters",
		"raw_vegetables": "farmers",
	}
	for resource_node in resource_nodes:
		var resource_id := String(resource_node.id)
		var job_id := String(harvest_jobs.get(resource_id, ""))
		if job_id.is_empty() or int(resource_node.amount) <= 0 or int(jobs.get(job_id, {}).get("max", 0)) <= 0:
			continue
		var harvest_key := "harvest:%d" % int(resource_node.entity_id)
		active_keys[harvest_key] = true
		task_board.upsert(harvest_key, {
			"kind": "harvest",
			"job_id": job_id,
			"target_id": int(resource_node.entity_id),
			"resource_id": resource_id,
			"x": float(resource_node.x) + 0.5,
			"y": float(resource_node.y) + 0.5,
			"max_claims": 1,
		})
	for animal in animals:
		if int(animal.health) <= 0:
			continue
		if bool(animal.get("capture_designated", false)) and not bool(animal.get("domesticated", false)) and int(jobs.get("rangers", {}).get("max", 0)) > 0:
			var capture_key := "capture:%d" % int(animal.id)
			active_keys[capture_key] = true
			task_board.upsert(capture_key, {
				"kind": "capture_animal", "job_id": "rangers", "target_id": int(animal.id),
				"x": float(animal.x), "y": float(animal.y), "max_claims": 1,
			})
		if bool(animal.get("slaughter_designated", false)) and bool(animal.get("domesticated", false)) and int(jobs.get("cooks", {}).get("max", 0)) > 0 and _has_completed_building(&"kitchen"):
			var slaughter_key := "slaughter:%d" % int(animal.id)
			active_keys[slaughter_key] = true
			task_board.upsert(slaughter_key, {
				"kind": "slaughter_animal", "job_id": "cooks", "target_id": int(animal.id),
				"x": float(animal.x), "y": float(animal.y), "max_claims": 1, "priority": 10,
			})
	if int(jobs.get("organizers", {}).get("max", 0)) > 0 and int(resources.get("suspicious_key", 0)) > 0:
		for item in loose_items:
			if String(item.get("resource_id", "")) != "lootbox":
				continue
			var box_cell := Vector2i(int(item.x), int(item.y))
			if not is_within_settlement_range(box_cell):
				continue
			var loot_key := "open_lootbox:%d" % int(item.get("id", item.get("entity_id", 0)))
			active_keys[loot_key] = true
			task_board.upsert(loot_key, {
				"kind": "open_lootbox", "job_id": "organizers", "target_id": int(item.get("id", item.get("entity_id", 0))),
				"x": float(item.x) + 0.5, "y": float(item.y) + 0.5, "max_claims": 1, "priority": 1,
			})
	if int(jobs.get("medics", {}).get("max", 0)) > 0:
		for patient in villagers:
			if int(patient.health) <= 0 or (int(patient.health) >= 1000 and patient.get("status_effects", {}).is_empty()):
				continue
			var triage_key := "triage:%d" % int(patient.id)
			active_keys[triage_key] = true
			var severity: int = 1000 - int(patient.health) + patient.get("status_effects", {}).size() * 500
			task_board.upsert(triage_key, {
				"kind": "triage", "job_id": "medics", "target_id": int(patient.id),
				"x": float(patient.x), "y": float(patient.y), "max_claims": 1, "priority": severity,
			})
	_refresh_water_tasks(active_keys)
	task_board.prune(active_keys)

func _refresh_water_tasks(active_keys: Dictionary) -> void:
	for building in buildings:
		if not bool(building.get("completed", false)) or bool(building.get("destroyed", false)):
			continue
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
		var water: Dictionary = definition.get("water", {})
		if water.is_empty():
			continue
		_configure_water_runtime(building, definition)
		var role := String(water.get("role", ""))
		if role == "purifier" and int(jobs.get("water_masters", {}).get("max", 0)) > 0:
			var dirty := int(building.stored_resources.get("dirty_water", 0))
			var dirty_cap := int(building.storage_caps.get("dirty_water", 0))
			if dirty < dirty_cap:
				var surface_cell := _nearest_surface_water_cell(building, int(water.get("surface_range", 24)))
				if surface_cell.x >= 0:
					var gather_key := "gather_surface_water:%d" % int(building.id)
					active_keys[gather_key] = true
					task_board.upsert(gather_key, {
						"kind": "gather_surface_water", "job_id": "water_masters", "target_id": int(building.id),
						"x": float(surface_cell.x) + 0.5, "y": float(surface_cell.y) + 0.5,
						"max_claims": mini(int(building.tier), dirty_cap - dirty), "priority": 1,
						"carry_amount": int(water.get("carry_amount", 4)),
					})
		elif role == "fountain":
			var clean := int(building.stored_resources.get("clean_water", 0))
			var clean_cap := int(building.storage_caps.get("clean_water", 0))
			if clean >= clean_cap:
				continue
			var source := _find_water_supply_source(building)
			if source.is_empty():
				continue
			var supplier_job := "water_masters" if int(jobs.get("water_masters", {}).get("max", 0)) > 0 else "organizers"
			if int(jobs.get(supplier_job, {}).get("max", 0)) <= 0:
				continue
			var supply_key := "supply_fountain:%d" % int(building.id)
			active_keys[supply_key] = true
			var source_position: Vector2 = source.position
			task_board.upsert(supply_key, {
				"kind": "transfer_water", "job_id": supplier_job, "target_id": int(building.id),
				"source_id": int(source.building_id), "x": source_position.x, "y": source_position.y,
				"max_claims": 1, "priority": 1, "carry_amount": mini(4, clean_cap - clean),
			})

func _update_villagers() -> void:
	for villager in villagers:
		if int(villager.health) <= 0:
			villager.state = "dead"
			_release_villager_task(villager)
			continue
		if String(villager.get("task_kind", "")) != "triage" and String(villager.get("medical_state", "")) in ["being_treated", "awaiting_supplies"]:
			_release_villager_task(villager)
			continue
		villager.attack_cooldown = maxi(0, int(villager.get("attack_cooldown", 0)) - 1)
		if String(villager.job) == "rangers" and _ranger_try_combat(villager):
			continue
		if _service_immediate_need(villager):
			continue
		if _continue_water_delivery(villager):
			continue
		var task_id := int(villager.get("task_id", 0))
		var task: Dictionary = task_board.get_task(task_id)
		if task.is_empty() or String(task.get("job_id", "")) != String(villager.job):
			_release_villager_task(villager)
			task = task_board.claim_best(int(villager.id), String(villager.job), Vector2(float(villager.x), float(villager.y)))
			if not task.is_empty():
				villager.task_id = int(task.id)
				villager.task_kind = String(task.kind)
				villager.task_progress = 0
		elif String(task.get("kind", "")) == "operate_building":
			var candidate := task_board.claim_best(int(villager.id), String(villager.job), Vector2(float(villager.x), float(villager.y)))
			if not candidate.is_empty() and int(candidate.get("id", 0)) != task_id and float(candidate.get("priority", 0)) > float(task.get("priority", 0)):
				_release_villager_task(villager)
				task = candidate
				villager.task_id = int(task.id)
				villager.task_kind = String(task.kind)
				villager.task_progress = 0
			elif not candidate.is_empty() and int(candidate.get("id", 0)) != task_id:
				task_board.release(int(villager.id), int(candidate.get("id", 0)))
		if task.is_empty():
			_wander_or_rest(villager)
			continue
		var target := Vector2(float(task.x), float(task.y))
		var task_kind := String(task.get("kind", ""))
		if task_kind == "triage":
			var patient_target := _find_villager(int(task.get("target_id", 0)))
			if not patient_target.is_empty():
				target = Vector2(float(patient_target.x), float(patient_target.y))
		elif task_kind in ["capture_animal", "slaughter_animal"]:
			var animal_target := _find_animal(int(task.get("target_id", 0)))
			if not animal_target.is_empty():
				target = Vector2(float(animal_target.x), float(animal_target.y))
		var movement_speed := 0.12 * (1.0 + ProgressionService.get_modifier(&"movement_speed"))
		if _move_villager_toward(villager, target, movement_speed):
			villager.state = "working"
			_work_task(villager, task)
		else:
			villager.state = "traveling"

func _update_equipment() -> void:
	if tick % 100 != 0:
		return
	for villager in villagers:
		if int(villager.health) <= 0 or String(villager.get("age_stage", "adult")) != "adult":
			continue
		var equipment: Dictionary = villager.get("equipment", {})
		if String(villager.job) == "rangers":
			if not equipment.has("weapon"):
				if int(resources.get("bow", 0)) > 0 and int(resources.get("quiver", 0)) > 0:
					equipment.weapon = _equipment_item(&"bow")
					equipment.ammo = _equipment_item(&"quiver")
					equipment.ammo.shots = int(ContentRegistry.get_by_id(&"resources", &"quiver").get("shots", 40))
					consume_physical_resource(&"bow", 1)
					consume_physical_resource(&"quiver", 1)
					ProgressionService.record(&"equipment.bows_equipped")
				elif int(resources.get("iron_sword", 0)) > 0:
					equipment.weapon = _equipment_item(&"iron_sword")
					consume_physical_resource(&"iron_sword", 1)
				elif int(resources.get("wood_sword", 0)) > 0:
					equipment.weapon = _equipment_item(&"wood_sword")
					consume_physical_resource(&"wood_sword", 1)
			_try_equip_armor(equipment, "body", ["iron_body_armor", "leather_body_armor"])
			_try_equip_armor(equipment, "helmet", ["iron_helmet", "leather_helmet"])
			if String(equipment.get("weapon", {}).get("id", "")) != "bow":
				_try_equip_armor(equipment, "shield", ["iron_shield", "wood_shield"])
		elif String(villager.job) == "maintainers":
			if not equipment.has("tool") and int(resources.get("hammer", 0)) > 0:
				equipment.tool = _equipment_item(&"hammer")
				consume_physical_resource(&"hammer", 1)
			if not equipment.has("terrain_tool") and int(resources.get("shovel", 0)) > 0:
				equipment.terrain_tool = _equipment_item(&"shovel")
				consume_physical_resource(&"shovel", 1)
		villager.equipment = equipment

func _equipment_item(resource_id: StringName) -> Dictionary:
	var definition := ContentRegistry.get_by_id(&"resources", resource_id)
	return {"id": String(resource_id), "durability": int(definition.get("durability", 100)), "max_durability": int(definition.get("durability", 100))}

func _try_equip_armor(equipment: Dictionary, slot: String, priorities: Array) -> void:
	if equipment.has(slot):
		return
	for resource_id in priorities:
		if int(resources.get(String(resource_id), 0)) <= 0:
			continue
		equipment[slot] = _equipment_item(StringName(resource_id))
		consume_physical_resource(StringName(resource_id), 1)
		return

func _ranger_try_combat(villager: Dictionary) -> bool:
	var position := Vector2(float(villager.x), float(villager.y))
	var target := _nearest_monster(position, 24.0)
	if target.is_empty():
		return false
	_release_villager_task(villager)
	var equipment: Dictionary = villager.get("equipment", {})
	var weapon: Dictionary = equipment.get("weapon", {})
	var weapon_definition := ContentRegistry.get_by_id(&"resources", StringName(weapon.get("id", "")))
	var attack_range := float(weapon_definition.get("range", 1.35))
	var damage := int(weapon_definition.get("damage", 10))
	var damage_type := StringName(weapon_definition.get("damage_type", "regular"))
	if String(weapon.get("id", "")) == "bow":
		var ammo: Dictionary = equipment.get("ammo", {})
		if int(ammo.get("shots", 0)) <= 0 and int(resources.get("quiver", 0)) > 0:
			consume_physical_resource(&"quiver", 1)
			ammo = _equipment_item(&"quiver")
			ammo.shots = int(ContentRegistry.get_by_id(&"resources", &"quiver").get("shots", 40))
			equipment.ammo = ammo
		if int(ammo.get("shots", 0)) <= 0:
			attack_range = 1.35
			damage = 8
			damage_type = &"regular"
		elif position.distance_to(Vector2(float(target.x), float(target.y))) <= attack_range and int(villager.attack_cooldown) <= 0:
			ammo.shots = int(ammo.shots) - 1
			equipment.ammo = ammo
	var target_position := Vector2(float(target.x), float(target.y))
	if position.distance_to(target_position) > attack_range:
		_move_villager_toward(villager, target_position, 0.13)
		villager.state = "intercepting"
		return true
	if int(villager.attack_cooldown) <= 0:
		_apply_damage_to_monster(target, damage, damage_type)
		villager.attack_cooldown = 12 if String(weapon.get("id", "")) == "bow" else 10
		villager.state = "fighting"
		_damage_equipped_item(villager, "weapon", 1)
		ProgressionService.record(&"combat.ranger_attacks")
		_emit_event(&"ranger_attacked", {"villager_id": villager.id, "target_id": target.id, "damage": damage, "damage_type": damage_type})
	return true

func _doggo_try_combat(doggo: Dictionary) -> bool:
	var position := Vector2(float(doggo.x), float(doggo.y))
	var target := _nearest_monster(position, 12.0)
	if target.is_empty():
		return false
	var target_position := Vector2(float(target.x), float(target.y))
	if position.distance_to(target_position) > 1.4:
		_move_villager_toward(doggo, target_position, 0.09)
		doggo.state = "defending"
		return true
	if int(doggo.attack_cooldown) <= 0:
		_apply_damage_to_monster(target, 24 if String(doggo.definition_id) == "doggo" else 18, &"piercing")
		doggo.attack_cooldown = 14
		doggo.state = "fighting"
		ProgressionService.record(&"combat.doggo_attacks")
	return true

func _doggo_try_loot(doggo: Dictionary) -> bool:
	if int(resources.get("suspicious_key", 0)) <= 0:
		doggo.erase("loot_target_id")
		return false
	var target := _find_loose_item(int(doggo.get("loot_target_id", 0)))
	if target.is_empty() or String(target.get("resource_id", "")) != "lootbox":
		target = {}
		var position := Vector2(float(doggo.x), float(doggo.y))
		var best_distance := 64.0 * 64.0
		for item in loose_items:
			if String(item.get("resource_id", "")) != "lootbox":
				continue
			var distance := position.distance_squared_to(Vector2(float(item.x) + 0.5, float(item.y) + 0.5))
			if distance < best_distance:
				best_distance = distance
				target = item
		if target.is_empty():
			return false
		doggo.loot_target_id = int(target.get("id", target.get("entity_id", 0)))
	var target_position := Vector2(float(target.x) + 0.5, float(target.y) + 0.5)
	if Vector2(float(doggo.x), float(doggo.y)).distance_to(target_position) > 1.1:
		_move_villager_toward(doggo, target_position, 0.075)
		doggo.state = "carrying_key_to_lootbox"
		return true
	if _open_lootbox(target, &"doggo", int(doggo.id)):
		doggo.state = "opened_lootbox"
		doggo.erase("loot_target_id")
		return true
	doggo.erase("loot_target_id")
	return false

func _nearest_monster(position: Vector2, radius: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := radius * radius
	for monster in monsters:
		if int(monster.health) <= 0 or int(monster.get("charmed_ticks", 0)) > 0:
			continue
		var distance := position.distance_squared_to(Vector2(float(monster.x), float(monster.y)))
		if distance <= best_distance:
			best_distance = distance
			best = monster
	return best

func _spawn_starting_animals() -> void:
	var types := ["beefalo", "entler", "rous", "clucker", "doggo"]
	for index in 18:
		var angle := TAU * float(index) / 18.0
		var radius := 32.0 + float(index % 5) * 6.0
		var animal_type: String = String(types[index % types.size()])
		animals.append({
			"id": _next_id(), "definition_id": animal_type, "name": String(animal_type).capitalize(),
			"x": float(blueprint.starting_cell.x) + cos(angle) * radius, "y": float(blueprint.starting_cell.y) + sin(angle) * radius,
			"target_x": float(blueprint.starting_cell.x), "target_y": float(blueprint.starting_cell.y),
			"health": 700 if animal_type == "beefalo" else 420, "hunger": 1000, "thirst": 1000, "energy": 1000,
			"age_days": 20 + index, "age_stage": "adult", "sex": "female" if index % 2 == 0 else "male",
			"domesticated": animal_type == "doggo", "pregnant_ticks": 0, "home_id": 0,
			"capture_designated": false, "slaughter_designated": false, "slaughtered": false,
			"state": "wandering", "path": [], "path_index": 0, "path_goal_x": -1, "path_goal_y": -1, "stuck_ticks": 0,
		})

func _update_population_life_cycle() -> void:
	if tick % TICKS_PER_DAY == 0:
		for villager in villagers:
			if int(villager.health) <= 0:
				continue
			villager.age_days = int(villager.age_days) + 1
			if String(villager.age_stage) == "child" and int(villager.age_days) >= 18:
				villager.age_stage = "adult"
				ProgressionService.record(&"population.children_grown")
			elif String(villager.age_stage) == "adult" and int(villager.age_days) >= 110:
				villager.age_stage = "elder"
			elif String(villager.age_stage) == "elder" and int(villager.age_days) >= 150 + int(villager.id) % 30:
				villager.health = 0
				ProgressionService.record(&"population.deaths_old_age")
	if tick % 100 != 0 or housing_capacity <= _villager_population_count():
		return
	for villager in villagers:
		if String(villager.age_stage) != "adult" or String(villager.sex) != "female" or int(villager.health) <= 0:
			continue
		if int(villager.pregnant_ticks) > 0:
			villager.pregnant_ticks = int(villager.pregnant_ticks) - 100
			if int(villager.pregnant_ticks) <= 0 and housing_capacity > _villager_population_count():
				_birth_child(villager)
		elif housing_capacity > _villager_population_count() and rng.randf() < 0.015 * (1.0 + ProgressionService.get_modifier(&"fertility")):
			villager.pregnant_ticks = TICKS_PER_DAY * 2
		break

func _update_nomads() -> void:
	var camp := _operational_town_center()
	if not camp.is_empty() and nomads.is_empty() and tick >= next_nomad_tick:
		_spawn_nomad_group(camp)
		next_nomad_tick = tick + rng.randi_range(TICKS_PER_DAY * 3, TICKS_PER_DAY * 5)
	var joined: Array[Dictionary] = []
	var lost: Array[Dictionary] = []
	var anchor := _settlement_anchor()
	for nomad in nomads:
		if int(nomad.get("health", 0)) <= 0:
			lost.append(nomad)
			continue
		if tick % 20 == int(nomad.id) % 20:
			nomad.hunger = maxi(0, int(nomad.hunger) - 1)
			nomad.thirst = maxi(0, int(nomad.thirst) - 1)
			if int(nomad.hunger) <= 0 or int(nomad.thirst) <= 0:
				nomad.health = maxi(0, int(nomad.health) - 2)
		if Vector2(float(nomad.x), float(nomad.y)).distance_to(anchor) <= 1.3:
			if housing_capacity > _villager_population_count():
				joined.append(nomad)
			else:
				nomad.state = "waiting_for_housing"
			continue
		nomad.state = "traveling_to_settlement"
		_move_villager_toward(nomad, anchor, float(nomad.get("speed", 0.066)))
	for nomad in joined:
		_admit_nomad(nomad, &"arrival")
	for nomad in lost:
		nomads.erase(nomad)
		ProgressionService.record(&"population.nomads_lost")
		_emit_event(&"nomad_lost", {"nomad_id": nomad.id})

func _operational_town_center() -> Dictionary:
	for building in buildings:
		if String(building.get("category", "")) == "town_center" and bool(building.get("completed", false)) and not bool(building.get("destroyed", false)):
			return building
	return {}

func _settlement_anchor() -> Vector2:
	var town_center := _operational_town_center()
	if not town_center.is_empty():
		return Vector2(float(town_center.x) + float(town_center.width) * 0.5, float(town_center.y) + float(town_center.height) * 0.5)
	return Vector2(blueprint.starting_cell) + Vector2(0.5, 0.5)

func _find_nomad_entry_cell(target: Vector2) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for x in range(2, blueprint.width - 2, 8):
		candidates.append(Vector2i(x, 2))
		candidates.append(Vector2i(x, blueprint.height - 3))
	for y in range(10, blueprint.height - 10, 8):
		candidates.append(Vector2i(2, y))
		candidates.append(Vector2i(blueprint.width - 3, y))
	var start := posmod(blueprint.seed + tick * 17, maxi(1, candidates.size()))
	for offset in candidates.size():
		var candidate := pathfinder.nearest_walkable(candidates[(start + offset) % candidates.size()])
		if candidate.x < 0:
			continue
		if not pathfinder.find_path(candidate, Vector2i(floori(target.x), floori(target.y))).is_empty():
			return candidate
	return pathfinder.nearest_walkable(blueprint.starting_cell)

func _spawn_nomad_group(camp: Dictionary = {}) -> int:
	if camp.is_empty():
		camp = _operational_town_center()
	if camp.is_empty():
		return 0
	var anchor := _settlement_anchor()
	var entry := _find_nomad_entry_cell(anchor)
	var amount := clampi(2 + rng.randi_range(0, 2) + roundi(ProgressionService.get_modifier(&"nomad_amount")), 1, 10)
	var group_index := nomad_groups_spawned
	nomad_groups_spawned += 1
	var catjeet_group := group_index % 3 == 2
	for index in amount:
		var entity_id := _next_id()
		var spawn_cell := pathfinder.nearest_walkable(entry + Vector2i(index % 3, index / 3))
		var species := "nephilim" if group_index % 8 == 7 and index == 0 else ("catjeet" if catjeet_group else "villager")
		var display_name := "Nephilim %02d" % entity_id if species == "nephilim" else ("Catjeet Nomad %02d" % entity_id if species == "catjeet" else "Nomad %02d" % entity_id)
		nomads.append({
			"id": entity_id, "name": display_name, "species": species, "population_state": "nomad", "job": "idle",
			"x": float(spawn_cell.x) + 0.5, "y": float(spawn_cell.y) + 0.5, "target_x": anchor.x, "target_y": anchor.y,
			"health": 1400 if species == "nephilim" else (900 if species == "catjeet" else 1000), "hunger": 850, "thirst": 850, "energy": 900 if species == "nephilim" else 800, "faith": 800 if species == "nephilim" else (350 if species == "catjeet" else 250),
			"age_stage": "adult", "age_days": 28 + entity_id % 55, "sex": "female" if entity_id % 2 == 0 else "male",
			"pregnant_ticks": 0, "partner_id": 0, "level": 1, "xp": 0, "task_id": 0, "task_kind": "", "task_progress": 0,
			"state": "traveling_to_settlement", "home_id": 0, "status": [], "status_effects": {}, "equipment": {}, "attack_cooldown": 0,
			"path": [], "path_index": 0, "path_goal_x": -1, "path_goal_y": -1, "stuck_ticks": 0, "speed": 0.075 if species == "nephilim" else 0.066,
		})
	ProgressionService.record(&"population.nomad_groups_arrived")
	_emit_event(&"nomads_arrived", {"count": amount, "cell_x": entry.x, "cell_y": entry.y, "species": "catjeet" if catjeet_group else "mixed" if group_index % 8 == 7 else "villager"})
	messages.append("%d %s are approaching the settlement." % [amount, "Catjeet nomads" if catjeet_group else "nomads"])
	if messages.size() > 8:
		messages.pop_front()
	AudioDirector.play_cue(&"warning")
	return amount

func _admit_nomad(nomad: Dictionary, source: StringName) -> bool:
	if nomad.is_empty() or nomad not in nomads:
		return false
	nomads.erase(nomad)
	nomad.population_state = "settled"
	nomad.state = "arrived"
	nomad.job = "idle"
	nomad.task_id = 0
	nomad.task_kind = ""
	nomad.task_progress = 0
	nomad.path = []
	nomad.path_index = 0
	nomad.path_goal_x = -1
	nomad.path_goal_y = -1
	villagers.append(nomad)
	ProgressionService.record(&"population.nomads_joined")
	if String(nomad.get("species", "villager")) == "catjeet":
		ProgressionService.record(&"population.nomads_joined.catjeet")
	_emit_event(&"nomad_joined", {"nomad_id": nomad.id, "source": source})
	_assign_jobs()
	return true

func _birth_child(parent: Dictionary) -> void:
	villagers.append({
		"id": _next_id(), "name": "Child %02d" % next_entity_id, "job": "idle",
		"x": float(parent.x), "y": float(parent.y), "target_x": float(parent.x), "target_y": float(parent.y),
		"health": 800, "hunger": 1000, "thirst": 1000, "energy": 1000, "faith": int(parent.faith),
		"age_stage": "child", "age_days": 0, "sex": "female" if next_entity_id % 2 == 0 else "male", "pregnant_ticks": 0, "partner_id": int(parent.id),
		"level": 1, "xp": 0, "task_id": 0, "task_kind": "", "task_progress": 0, "state": "child", "home_id": 0, "status": [], "status_effects": {}, "equipment": {}, "attack_cooldown": 0,
		"path": [], "path_index": 0, "path_goal_x": -1, "path_goal_y": -1, "stuck_ticks": 0,
	})
	ProgressionService.record(&"population.births")
	_recalculate_settlement_support()

func _update_animals() -> void:
	if tick % TICKS_PER_DAY == 0:
		for animal in animals:
			if int(animal.get("health", 0)) <= 0:
				continue
			animal.age_days = int(animal.get("age_days", 0)) + 1
			if String(animal.get("age_stage", "adult")) == "child" and int(animal.age_days) >= 12:
				animal.age_stage = "adult"
	for animal in animals:
		if int(animal.health) <= 0:
			if not bool(animal.get("death_recorded", false)):
				animal.death_recorded = true
				animal.state = "dead"
				ProgressionService.record(StringName("animals.deaths.%s" % String(animal.get("definition_id", "unknown"))))
				_emit_event(&"animal_died", {"animal_id": int(animal.get("id", 0)), "definition_id": String(animal.get("definition_id", "unknown"))})
			if String(animal.get("definition_id", "")) in ["doggo", "doofy_doggo"] and not bool(animal.get("ghost_created", false)):
				animal.ghost_created = true
				ghosts.append({
					"id": _next_id(), "source_kind": "animal", "source_animal_id": int(animal.id), "name": "%s's Ghost" % String(animal.get("name", "Doggo")),
					"x": float(animal.get("x", 0.0)), "y": float(animal.get("y", 0.0)), "bound": false, "age_ticks": 0,
					"animal_record": animal.duplicate(true),
				})
			continue
		animal.hunger = maxi(0, int(animal.hunger) - (1 if tick % 20 == 0 else 0))
		animal.thirst = maxi(0, int(animal.thirst) - (1 if tick % 15 == 0 else 0))
		if int(animal.hunger) <= 0 or int(animal.thirst) <= 0:
			animal.health = maxi(0, int(animal.health) - 1)
		animal.attack_cooldown = maxi(0, int(animal.get("attack_cooldown", 0)) - 1)
		if String(animal.definition_id) in ["doggo", "doofy_doggo"] and bool(animal.get("domesticated", false)):
			if _doggo_try_combat(animal) or _doggo_try_loot(animal):
				continue
		var home := _find_building(int(animal.get("home_id", 0)))
		if bool(animal.get("domesticated", false)) and (home.is_empty() or not bool(home.get("completed", false)) or bool(home.get("destroyed", false))):
			animal.home_id = _assign_animal_home(animal)
			home = _find_building(int(animal.home_id))
		if bool(animal.get("slaughter_designated", false)):
			continue
		if tick % 90 == int(animal.id) % 90:
			var roaming_center := Vector2(float(blueprint.starting_cell.x), float(blueprint.starting_cell.y))
			var roaming_radius := 48.0
			if not home.is_empty():
				roaming_center = Vector2(float(home.x) + float(home.width) * 0.5, float(home.y) + float(home.height) * 0.5)
				roaming_radius = 5.0
			animal.target_x = roaming_center.x + rng.randf_range(-roaming_radius, roaming_radius)
			animal.target_y = roaming_center.y + rng.randf_range(-roaming_radius, roaming_radius)
		_move_villager_toward(animal, Vector2(float(animal.target_x), float(animal.target_y)), 0.045)
		if String(animal.definition_id) == "clucker" and bool(animal.domesticated) and not home.is_empty() and tick % 400 == int(animal.id) % 400:
			add_physical_resource_capped(&"eggs", 1, Vector2i(roundi(animal.x), roundi(animal.y)))
			ProgressionService.record(&"animals.eggs_laid")
		elif String(animal.definition_id) == "doggo" and bool(animal.domesticated) and tick % 240 == int(animal.id) % 240:
			add_physical_resource_capped(&"wood", 1, Vector2i(roundi(animal.x), roundi(animal.y)))
			ProgressionService.record(&"animals.doggo_resources_stored")
	if tick % 100 == 0:
		_update_animal_breeding()
	for index in range(animals.size() - 1, -1, -1):
		if bool(animals[index].get("slaughtered", false)):
			animals.remove_at(index)

func _update_animal_breeding() -> void:
	var mothers: Array[Dictionary] = []
	for animal in animals:
		if int(animal.get("health", 0)) <= 0 or not bool(animal.get("domesticated", false)):
			continue
		if String(animal.get("age_stage", "adult")) != "adult" or String(animal.get("sex", "")) != "female":
			continue
		mothers.append(animal)
	for mother in mothers:
		var animal_type := StringName(mother.definition_id)
		if int(mother.get("pregnant_ticks", 0)) > 0:
			mother.pregnant_ticks = int(mother.pregnant_ticks) - 100
			if int(mother.pregnant_ticks) <= 0 and _animal_has_open_home(animal_type):
				_birth_animal(mother)
			continue
		if not _animal_has_open_home(animal_type) or not _has_domestic_male(animal_type):
			continue
		if rng.randf() < 0.012:
			mother.pregnant_ticks = TICKS_PER_DAY * 2

func _has_domestic_male(animal_type: StringName) -> bool:
	for animal in animals:
		if StringName(animal.get("definition_id", "")) == animal_type and bool(animal.get("domesticated", false)) and String(animal.get("age_stage", "adult")) == "adult" and String(animal.get("sex", "")) == "male" and int(animal.get("health", 0)) > 0:
			return true
	return false

func _birth_animal(parent: Dictionary) -> void:
	var animal_type := StringName(parent.definition_id)
	var child := {
		"id": _next_id(), "definition_id": String(animal_type), "name": "%s Young" % String(animal_type).replace("_", " ").capitalize(),
		"x": float(parent.x), "y": float(parent.y), "target_x": float(parent.x), "target_y": float(parent.y),
		"health": 350, "hunger": 1000, "thirst": 1000, "energy": 1000,
		"age_days": 0, "age_stage": "child", "sex": "female" if next_entity_id % 2 == 0 else "male",
		"domesticated": true, "pregnant_ticks": 0, "home_id": 0,
		"capture_designated": false, "slaughter_designated": false, "slaughtered": false,
		"state": "young", "path": [], "path_index": 0, "path_goal_x": -1, "path_goal_y": -1, "stuck_ticks": 0,
	}
	child.home_id = _assign_animal_home(child)
	animals.append(child)
	ProgressionService.record(&"animals.born")
	_emit_event(&"animal_born", {"animal_id": child.id, "definition_id": child.definition_id})

func _move_villager_toward(villager: Dictionary, target: Vector2, step: float, hostile_route: bool = false) -> bool:
	var position := Vector2(float(villager.x), float(villager.y))
	var movement_cell := Vector2i(floori(position.x), floori(position.y))
	step *= _road_speed_multiplier(movement_cell, hostile_route)
	step *= _terrain_effect_speed_multiplier(movement_cell)
	villager.target_x = target.x
	villager.target_y = target.y
	if position.distance_to(target) <= 0.95:
		villager.stuck_ticks = 0
		return true
	var goal_cell := Vector2i(floori(target.x), floori(target.y))
	if int(villager.get("path_goal_x", -1)) != goal_cell.x or int(villager.get("path_goal_y", -1)) != goal_cell.y or int(villager.get("path_index", 0)) >= villager.get("path", []).size():
		var route_finder = hostile_pathfinder if hostile_route else pathfinder
		villager.path = route_finder.find_path(Vector2i(floori(position.x), floori(position.y)), goal_cell)
		villager.path_index = 0
		villager.path_goal_x = goal_cell.x
		villager.path_goal_y = goal_cell.y
	var path: Array = villager.get("path", [])
	if path.is_empty():
		villager.stuck_ticks = int(villager.get("stuck_ticks", 0)) + 1
		if int(villager.stuck_ticks) > 100:
			_release_villager_task(villager)
		return false
	var path_index := clampi(int(villager.path_index), 0, path.size() - 1)
	var waypoint_data: Array = path[path_index]
	var waypoint := Vector2(float(waypoint_data[0]) + 0.5, float(waypoint_data[1]) + 0.5)
	if position.distance_to(waypoint) <= maxf(step * 1.5, 0.18) and path_index < path.size() - 1:
		path_index += 1
		villager.path_index = path_index
		waypoint_data = path[path_index]
		waypoint = Vector2(float(waypoint_data[0]) + 0.5, float(waypoint_data[1]) + 0.5)
	var direction := waypoint - position
	if direction.length_squared() > 0.0001:
		position += direction.normalized() * minf(step, direction.length())
	villager.x = position.x
	villager.y = position.y
	villager.stuck_ticks = 0
	return false

func _road_speed_multiplier(cell: Vector2i, hostile_actor: bool = false) -> float:
	for building in buildings:
		if not bool(building.get("completed", false)) or bool(building.get("destroyed", false)) or String(building.get("category", "")) != "roads":
			continue
		if Rect2i(Vector2i(int(building.x), int(building.y)), Vector2i(int(building.width), int(building.height))).has_point(cell):
			return {
				"path": 1.05, "log_road": 1.12, "cobble_log_road": 1.20,
				"cobble_board_road": 1.28, "cut_stone_board_road": 1.36,
			}.get(String(building.definition_id), 1.0)
	if hostile_actor:
		for structure in hostile_structures:
			if bool(structure.get("completed", false)) and not bool(structure.get("destroyed", false)) and String(structure.get("hostile_role", "")) == "road":
				if Rect2i(Vector2i(int(structure.x), int(structure.y)), Vector2i(int(structure.width), int(structure.height))).has_point(cell):
					var definition := ContentRegistry.get_by_id(&"buildings", StringName(structure.get("definition_id", "")))
					return float(definition.get("hostile", {}).get("speed_multiplier", 1.22))
	return 1.0

func _terrain_effect_speed_multiplier(cell: Vector2i) -> float:
	if water_frozen and blueprint != null and blueprint.get_tile(cell) == RegionGenerator.Tile.DEEP_WATER:
		return 0.78
	var effect: Dictionary = terrain_effects.get(_cell_key(cell), {})
	match String(effect.get("kind", "")):
		"mud": return 0.72
		"flood": return 0.52
		"fire": return 0.62
		"ash": return 0.90
		"hole": return 0.45
	return 1.0

func _apply_navigation_building(building: Dictionary) -> void:
	if not bool(building.get("completed", false)) or bool(building.get("destroyed", false)):
		return
	var category := String(building.get("category", ""))
	var definition_id := String(building.get("definition_id", ""))
	for y in range(int(building.y), int(building.y) + int(building.height)):
		for x in range(int(building.x), int(building.x) + int(building.width)):
			var cell := Vector2i(x, y)
			if (category == "walls" and not definition_id.ends_with("gate")) or (category == "god_structure" and String(building.get("god_role", "")) == "wall"):
				pathfinder.set_dynamic_solid(cell, true)
				hostile_pathfinder.set_dynamic_solid(cell, true)
			elif category == "roads":
				var weight: float = {
					"path": 0.95, "log_road": 0.82, "cobble_log_road": 0.70,
					"cobble_board_road": 0.60, "cut_stone_board_road": 0.50,
				}.get(definition_id, 1.0)
				pathfinder.set_travel_weight(cell, weight)
				hostile_pathfinder.set_travel_weight(cell, weight)

func _apply_navigation_hostile_structure(structure: Dictionary) -> void:
	if not bool(structure.get("completed", false)) or bool(structure.get("destroyed", false)):
		return
	var role := String(structure.get("hostile_role", ""))
	var definition := ContentRegistry.get_by_id(&"buildings", StringName(structure.get("definition_id", "")))
	var hostile: Dictionary = definition.get("hostile", {})
	for y in range(int(structure.y), int(structure.y) + int(structure.height)):
		for x in range(int(structure.x), int(structure.x) + int(structure.width)):
			var cell := Vector2i(x, y)
			if role == "wall":
				# Corrupted walls block villagers and friendly agents, while their own
				# faction can pass through the living structure.
				pathfinder.set_dynamic_solid(cell, true)
			elif role == "road":
				hostile_pathfinder.set_travel_weight(cell, float(hostile.get("path_weight", 0.72)))

func _refresh_navigation_buildings() -> void:
	pathfinder.configure(blueprint)
	hostile_pathfinder.configure(blueprint)
	for building in buildings:
		_apply_navigation_building(building)
	for structure in hostile_structures:
		_apply_navigation_hostile_structure(structure)
	if water_frozen:
		pathfinder.set_deep_water_frozen(true)
		hostile_pathfinder.set_deep_water_frozen(true)

func _work_task(villager: Dictionary, task: Dictionary) -> void:
	match String(task.kind):
		"operate_building":
			var workplace := _find_building(int(task.target_id))
			if workplace.is_empty() or bool(workplace.get("destroyed", false)) or not bool(workplace.get("completed", false)):
				_release_villager_task(villager)
				return
			var workplace_definition := ContentRegistry.get_by_id(&"buildings", StringName(workplace.definition_id))
			if String(villager.job) not in workplace_definition.get("jobs", []) or not _building_requires_workplace_attendance(workplace_definition):
				_release_villager_task(villager)
				return
			villager.task_progress = int(villager.get("task_progress", 0)) + 1
			villager.state = "operating_%s" % String(workplace.definition_id)
		"gather_surface_water":
			var purifier := _find_building(int(task.target_id))
			if purifier.is_empty() or bool(purifier.get("destroyed", false)) or not bool(purifier.get("completed", false)):
				_release_villager_task(villager)
				return
			var capacity := int(purifier.get("storage_caps", {}).get("dirty_water", 0))
			var stored := int(purifier.get("stored_resources", {}).get("dirty_water", 0))
			var amount := mini(int(task.get("carry_amount", 4)), capacity - stored)
			_release_villager_task(villager)
			if amount <= 0:
				return
			villager.carrying_water = {"resource_id": "dirty_water", "amount": amount, "destination_id": int(purifier.id)}
			villager.state = "carrying_dirty_water"
			ProgressionService.record(&"water.surface_collected", amount)
		"transfer_water":
			var fountain := _find_building(int(task.target_id))
			if fountain.is_empty() or bool(fountain.get("destroyed", false)) or not bool(fountain.get("completed", false)):
				_release_villager_task(villager)
				return
			var destination_capacity := int(fountain.get("storage_caps", {}).get("clean_water", 0))
			var destination_stored := int(fountain.get("stored_resources", {}).get("clean_water", 0))
			var requested := mini(int(task.get("carry_amount", 4)), destination_capacity - destination_stored)
			var source_id := int(task.get("source_id", 0))
			var carried := 0
			if source_id == 0:
				carried = mini(requested, int(resources.get("clean_water", 0)))
				consume_physical_resource(&"clean_water", carried)
			else:
				var source := _find_building(source_id)
				if not source.is_empty() and not bool(source.get("destroyed", false)):
					carried = mini(requested, int(source.get("stored_resources", {}).get("clean_water", 0)))
					source.stored_resources.clean_water = int(source.stored_resources.get("clean_water", 0)) - carried
			_release_villager_task(villager)
			if carried <= 0:
				return
			villager.carrying_water = {"resource_id": "clean_water", "amount": carried, "destination_id": int(fountain.id)}
			villager.state = "supplying_fountain"
		"construct":
			var building := _find_building(int(task.target_id))
			if building.is_empty() or bool(building.completed):
				_release_villager_task(villager)
				return
			building.progress = mini(int(building.build_time), int(building.progress) + 2)
		"repair":
			var repair_building := _find_building(int(task.target_id))
			if repair_building.is_empty() or bool(repair_building.get("destroyed", false)) or bool(repair_building.get("dismantle_designated", false)) or int(repair_building.health) >= int(repair_building.max_health):
				_release_villager_task(villager)
				return
			var maintenance_service := _maintenance_service()
			if int(repair_building.get("repair_batch_remaining", 0)) <= 0:
				var repair_material := _take_repair_material(repair_building)
				if repair_material.is_empty():
					repair_building.service_state = "missing_repair_material"
					villager.state = "waiting_for_material"
					return
				repair_building.repair_batch_remaining = int(maintenance_service.repair_batch_hp)
				repair_building.last_repair_material = repair_material
			var repair_amount := int(maintenance_service.repair_with_tool) if _villager_has_tool(villager, &"hammer") else int(maintenance_service.repair_without_tool)
			repair_amount = mini(repair_amount, mini(int(repair_building.repair_batch_remaining), int(repair_building.max_health) - int(repair_building.health)))
			repair_building.health = int(repair_building.health) + repair_amount
			repair_building.repair_batch_remaining = int(repair_building.repair_batch_remaining) - repair_amount
			repair_building.service_state = "repairing"
			villager.state = "repairing"
			if _villager_has_tool(villager, &"hammer"):
				_damage_equipped_item(villager, "tool", int(maintenance_service.tool_durability_per_tick))
			ProgressionService.record(&"maintenance.health_restored", repair_amount)
			if int(repair_building.health) >= int(repair_building.max_health):
				repair_building.repair_designated = false
				repair_building.service_state = "repaired"
				ProgressionService.record(&"maintenance.repairs_completed")
				_emit_event(&"building_repaired", {"building_id": repair_building.id})
				_release_villager_task(villager)
		"dismantle":
			var dismantle_building := _find_building(int(task.target_id))
			if dismantle_building.is_empty() or bool(dismantle_building.get("destroyed", false)) or not bool(dismantle_building.get("dismantle_designated", false)):
				_release_villager_task(villager)
				return
			var maintenance_service := _maintenance_service()
			var dismantle_amount := int(maintenance_service.dismantle_with_tool) if _villager_has_tool(villager, &"hammer") else int(maintenance_service.dismantle_without_tool)
			dismantle_building.dismantle_progress = int(dismantle_building.get("dismantle_progress", 0)) + dismantle_amount
			dismantle_building.service_state = "dismantling"
			villager.state = "dismantling"
			if _villager_has_tool(villager, &"hammer"):
				_damage_equipped_item(villager, "tool", int(maintenance_service.tool_durability_per_tick))
			var dismantle_target := maxi(int(maintenance_service.dismantle_min_ticks), int(dismantle_building.build_time) / int(maintenance_service.dismantle_build_time_divisor))
			if int(dismantle_building.dismantle_progress) >= dismantle_target:
				_finish_dismantle(dismantle_building)
				_release_villager_task(villager)
		"terrain_work":
			var terrain_key := String(task.get("terrain_key", ""))
			var work: Dictionary = terrain_work.get(terrain_key, {})
			if work.is_empty():
				_release_villager_task(villager)
				return
			var work_cell := _cell_from_key(terrain_key)
			var action := StringName(work.get("action", ""))
			if not can_designate_terrain_work(action, work_cell):
				terrain_work.erase(terrain_key)
				_release_villager_task(villager)
				return
			var maintenance_service := _maintenance_service()
			var work_amount := int(maintenance_service.get("terrain_with_shovel", 4)) if _villager_has_tool(villager, &"shovel") else int(maintenance_service.get("terrain_without_tool", 2))
			work.progress = int(work.get("progress", 0)) + work_amount
			work.state = "working"
			terrain_work[terrain_key] = work
			villager.state = {
				&"clear": "clearing",
				&"dig": "digging",
				&"fill": "filling",
				&"restore": "restoring",
			}.get(action, "maintaining_terrain")
			if _villager_has_tool(villager, &"shovel"):
				_damage_equipped_item(villager, "terrain_tool", int(maintenance_service.get("shovel_durability_per_tick", 1)))
			if int(work.progress) >= int(work.target):
				_finish_terrain_work(terrain_key, work_cell, action)
				_release_villager_task(villager)
		"triage":
			var patient := _find_villager(int(task.target_id))
			if patient.is_empty() or int(patient.health) <= 0 or (int(patient.health) >= 1000 and patient.get("status_effects", {}).is_empty()):
				_release_villager_task(villager)
				return
			var medicine := _medicine_for_patient(patient)
			if medicine.is_empty():
				patient.medical_state = "awaiting_supplies"
				villager.state = "waiting_for_medicine"
				return
			villager.task_progress = int(villager.task_progress) + 1
			villager.state = "treating_patient"
			patient.medical_state = "being_treated"
			var clinic_service: Dictionary = ContentRegistry.get_by_id(&"buildings", &"clinic").get("service", {})
			if int(villager.task_progress) >= int(clinic_service.get("treatment_ticks", 20)):
				_apply_medicine(patient, medicine)
				ProgressionService.record(&"medical.treatments_completed")
				_emit_event(&"patient_treated", {"patient_id": patient.id, "medic_id": villager.id, "medicine": medicine})
				_release_villager_task(villager)
		"harvest":
			var resource_node := _find_resource_node(int(task.target_id))
			if resource_node.is_empty() or int(resource_node.amount) <= 0:
				_release_villager_task(villager)
				return
			villager.task_progress = int(villager.task_progress) + 1
			if int(villager.task_progress) >= 20:
				var resource_id := String(resource_node.id)
				if int(resources.get(resource_id, 0)) < int(resource_caps.get(resource_id, 200)):
					resource_node.amount = int(resource_node.amount) - 1
					add_physical_resource(StringName(resource_id), 1, PhysicalInventory.LocationState.GROUND, Vector2i(roundi(villager.x), roundi(villager.y)))
					ProgressionService.record(StringName("resources.harvested.%s" % resource_id))
					ProgressionService.record(&"resources.harvested.any")
				villager.task_progress = 0
				if int(resource_node.amount) <= 0:
					_release_villager_task(villager)
		"capture_animal":
			var capture_animal := _find_animal(int(task.target_id))
			if capture_animal.is_empty() or bool(capture_animal.get("domesticated", false)) or not bool(capture_animal.get("capture_designated", false)):
				_release_villager_task(villager)
				return
			if not _animal_has_open_home(StringName(capture_animal.definition_id)):
				capture_animal.state = "waiting_for_housing"
				_release_villager_task(villager)
				return
			villager.task_progress = int(villager.task_progress) + 1
			if int(villager.task_progress) >= 30:
				capture_animal.domesticated = true
				capture_animal.capture_designated = false
				capture_animal.home_id = _assign_animal_home(capture_animal)
				capture_animal.state = "domesticated"
				ProgressionService.record(&"animals.captured")
				_emit_event(&"animal_captured", {"animal_id": capture_animal.id, "definition_id": capture_animal.definition_id})
				_release_villager_task(villager)
		"slaughter_animal":
			var slaughter_animal := _find_animal(int(task.target_id))
			if slaughter_animal.is_empty() or not bool(slaughter_animal.get("domesticated", false)) or not bool(slaughter_animal.get("slaughter_designated", false)):
				_release_villager_task(villager)
				return
			villager.task_progress = int(villager.task_progress) + 1
			if int(villager.task_progress) >= 20:
				_slaughter_animal(slaughter_animal)
				_release_villager_task(villager)
		"open_lootbox":
			var lootbox := _find_loose_item(int(task.target_id))
			if lootbox.is_empty() or String(lootbox.get("resource_id", "")) != "lootbox" or int(resources.get("suspicious_key", 0)) <= 0:
				_release_villager_task(villager)
				return
			villager.task_progress = int(villager.task_progress) + 1
			villager.state = "opening_lootbox"
			if int(villager.task_progress) >= 16:
				_open_lootbox(lootbox, &"organizer")
				_release_villager_task(villager)

func _continue_water_delivery(villager: Dictionary) -> bool:
	var carried: Dictionary = villager.get("carrying_water", {})
	if carried.is_empty():
		return false
	var destination := _find_building(int(carried.get("destination_id", 0)))
	if destination.is_empty() or bool(destination.get("destroyed", false)) or not bool(destination.get("completed", false)):
		drop_resource(StringName(carried.get("resource_id", "dirty_water")), int(carried.get("amount", 0)), Vector2i(floori(float(villager.x)), floori(float(villager.y))))
		villager.carrying_water = {}
		villager.state = "delivery_failed"
		return true
	var target := _water_building_center(destination)
	if not _move_villager_toward(villager, target, 0.12 * (1.0 + ProgressionService.get_modifier(&"movement_speed"))):
		villager.state = "delivering_water"
		return true
	var resource_id := String(carried.get("resource_id", "dirty_water"))
	var capacity := int(destination.get("storage_caps", {}).get(resource_id, 0))
	var current := int(destination.get("stored_resources", {}).get(resource_id, 0))
	var delivered := mini(int(carried.get("amount", 0)), maxi(0, capacity - current))
	if delivered > 0:
		destination.stored_resources[resource_id] = current + delivered
		ProgressionService.record(&"water.delivered", delivered)
		_emit_event(&"water_delivered", {"villager_id": villager.id, "building_id": destination.id, "resource_id": resource_id, "amount": delivered})
	var overflow := int(carried.get("amount", 0)) - delivered
	if overflow > 0:
		drop_resource(StringName(resource_id), overflow, Vector2i(floori(target.x), floori(target.y)))
	villager.carrying_water = {}
	villager.state = "water_delivered"
	return true

func _nearest_drinking_source(position: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for building in buildings:
		if not bool(building.get("completed", false)) or bool(building.get("destroyed", false)):
			continue
		var center := _water_building_center(building)
		if String(building.definition_id) == "camp" and int(resources.get("clean_water", 0)) > 0:
			var camp_distance := position.distance_squared_to(center)
			if camp_distance < best_distance:
				best_distance = camp_distance
				best = {"building": building, "global": true, "position": center}
			continue
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
		var water: Dictionary = definition.get("water", {})
		if not bool(water.get("drinkable", false)) or int(building.get("stored_resources", {}).get("clean_water", 0)) <= 0:
			continue
		var distance := position.distance_squared_to(center)
		if distance < best_distance:
			best_distance = distance
			best = {"building": building, "global": false, "position": center}
	return best

func _service_immediate_need(villager: Dictionary) -> bool:
	if String(villager.get("task_kind", "")) != "triage" and String(villager.get("medical_state", "")) in ["being_treated", "awaiting_supplies"]:
		return false
	if int(villager.energy) < 350 or String(villager.state) == "resting":
		_release_villager_task(villager)
		var rest_recovery := 5
		var home := _find_building(int(villager.get("home_id", 0)))
		if not home.is_empty() and bool(home.get("completed", false)) and not bool(home.get("destroyed", false)):
			var home_center := Vector2(float(home.x) + float(home.width) * 0.5, float(home.y) + float(home.height) * 0.5)
			if Vector2(float(villager.x), float(villager.y)).distance_to(home_center) > 1.25:
				_move_villager_toward(villager, home_center, 0.12 * (1.0 + ProgressionService.get_modifier(&"movement_speed")))
				villager.state = "seeking_rest"
				return true
			rest_recovery = 8
		villager.state = "resting"
		villager.energy = mini(1000, int(villager.energy) + rest_recovery)
		if int(villager.energy) >= 850:
			villager.state = "idle"
		return true
	if int(villager.thirst) < 700 and int(resources.get("water_bottle", 0)) > 0:
		_release_villager_task(villager)
		consume_physical_resource(&"water_bottle", 1)
		villager.thirst = mini(1000, int(villager.thirst) + 480)
		villager.state = "drinking_bottled_water"
		ProgressionService.record(&"water.bottles_consumed")
		return true
	if int(villager.thirst) < 700:
		var source := _nearest_drinking_source(Vector2(float(villager.x), float(villager.y)))
		if not source.is_empty():
			_release_villager_task(villager)
			var target: Vector2 = source.position
			if not _move_villager_toward(villager, target, 0.12 * (1.0 + ProgressionService.get_modifier(&"movement_speed"))):
				villager.state = "seeking_water"
				return true
			var water_building: Dictionary = source.building
			if bool(source.global):
				consume_physical_resource(&"clean_water", 1)
			else:
				water_building.stored_resources.clean_water = maxi(0, int(water_building.stored_resources.get("clean_water", 0)) - 1)
			villager.thirst = mini(1000, int(villager.thirst) + 320)
			villager.state = "drinking"
			ProgressionService.record(&"water.drinks")
			return true
	if int(villager.hunger) < 700:
		var food_id := "rations" if int(resources.get("rations", 0)) > 0 else "raw_vegetables"
		if int(resources.get(food_id, 0)) > 0:
			_release_villager_task(villager)
			consume_physical_resource(StringName(food_id), 1)
			villager.hunger = mini(1000, int(villager.hunger) + (420 if food_id == "rations" else 240))
			villager.state = "eating"
			return true
	return false

func _wander_or_rest(villager: Dictionary) -> void:
	if tick % 80 == int(villager.id) % 80:
		villager.target_x = float(blueprint.starting_cell.x) + rng.randf_range(-8.0, 8.0)
		villager.target_y = float(blueprint.starting_cell.y) + rng.randf_range(-8.0, 8.0)
	var target := Vector2(float(villager.target_x), float(villager.target_y))
	villager.state = "idle"
	_move_villager_toward(villager, target, 0.055 * (1.0 + ProgressionService.get_modifier(&"movement_speed")))

func _release_villager_task(villager: Dictionary) -> void:
	var task_id := int(villager.get("task_id", 0))
	if task_id > 0:
		task_board.release(int(villager.id), task_id)
	villager.task_id = 0
	villager.task_kind = ""
	villager.task_progress = 0
	villager.path = []
	villager.path_index = 0
	villager.path_goal_x = -1
	villager.path_goal_y = -1

func _find_building(entity_id: int) -> Dictionary:
	for building in buildings:
		if int(building.id) == entity_id:
			return building
	return {}

func _find_villager(entity_id: int) -> Dictionary:
	for villager in villagers:
		if int(villager.id) == entity_id:
			return villager
	return {}

func _find_resource_node(entity_id: int) -> Dictionary:
	for resource_node in resource_nodes:
		if int(resource_node.entity_id) == entity_id:
			return resource_node
	return {}

func _find_animal(entity_id: int) -> Dictionary:
	for animal in animals:
		if int(animal.id) == entity_id:
			return animal
	return {}

func _find_loose_item(entity_id: int) -> Dictionary:
	for item in loose_items:
		if int(item.get("id", item.get("entity_id", 0))) == entity_id:
			return item
	return {}

func _lootbox_at(cell: Vector2i) -> Dictionary:
	for item in loose_items:
		if String(item.get("resource_id", "")) == "lootbox" and Vector2i(int(item.get("x", -1)), int(item.get("y", -1))) == cell:
			return item
	return {}

func _building_at_cell(cell: Vector2i) -> Dictionary:
	for building in buildings:
		if not bool(building.get("destroyed", false)) and Rect2i(Vector2i(int(building.x), int(building.y)), Vector2i(int(building.width), int(building.height))).has_point(cell):
			return building
	for structure in hostile_structures:
		if not bool(structure.get("destroyed", false)) and Rect2i(Vector2i(int(structure.x), int(structure.y)), Vector2i(int(structure.width), int(structure.height))).has_point(cell):
			return structure
	return {}

func _open_lootbox(box: Dictionary, opener: StringName, opener_id: int = 0, consume_stored_key: bool = true) -> bool:
	if box.is_empty() or String(box.get("resource_id", "")) != "lootbox" or box not in loose_items:
		return false
	if consume_stored_key:
		if int(resources.get("suspicious_key", 0)) <= 0:
			return false
		consume_physical_resource(&"suspicious_key", 1)
	var table_id := StringName(box.get("loot_table", "standard_lootbox"))
	var loot_table := ContentRegistry.get_by_id(&"loot_tables", table_id)
	var outcomes: Array = loot_table.get("outcomes", [])
	if outcomes.is_empty():
		if consume_stored_key:
			add_physical_resource(&"suspicious_key", 1)
		return false
	var total_weight := 0
	for outcome in outcomes:
		total_weight += maxi(0, int(outcome.get("weight", 0)))
	if total_weight <= 0:
		if consume_stored_key:
			add_physical_resource(&"suspicious_key", 1)
		return false
	var rewards := {}
	var pure_trash_rolls := 0
	var rolls := maxi(1, int(loot_table.get("rolls", 1)))
	var quantity_multiplier := maxf(0.0, 1.0 + ProgressionService.get_modifier(&"loot_box_quantity"))
	for _roll in rolls:
		var choice := rng.randi_range(1, total_weight)
		var selected: Dictionary = outcomes[0]
		for outcome in outcomes:
			choice -= maxi(0, int(outcome.get("weight", 0)))
			if choice <= 0:
				selected = outcome
				break
		var resource_id := StringName(selected.get("resource_id", ""))
		var amount := maxi(1, roundi(float(selected.get("amount", 1)) * quantity_multiplier))
		rewards[String(resource_id)] = int(rewards.get(String(resource_id), 0)) + amount
		if bool(selected.get("pure_trash", false)):
			pure_trash_rolls += 1
	var box_cell := Vector2i(int(box.get("x", 0)), int(box.get("y", 0)))
	for resource_id in rewards:
		_grant_loot_resource(StringName(resource_id), int(rewards[resource_id]), box_cell)
	loose_items.erase(box)
	ProgressionService.record(&"loot.boxes_opened")
	if opener == &"doggo":
		ProgressionService.record(&"loot.boxes_opened_by_doggo")
	if pure_trash_rolls > 0:
		ProgressionService.record(&"loot.trash_outcomes")
	_emit_event(&"lootbox_opened", {
		"box_id": int(box.get("id", box.get("entity_id", 0))), "opener": String(opener), "opener_id": opener_id,
		"rewards": rewards.duplicate(true), "trash_reward": pure_trash_rolls > 0,
	})
	AudioDirector.play_cue(&"lootbox_open")
	return true

func _grant_loot_resource(resource_id: StringName, amount: int, cell: Vector2i) -> void:
	if amount <= 0:
		return
	var key := String(resource_id)
	var capacity := int(resource_caps.get(key, 200))
	var stored := mini(amount, maxi(0, capacity - int(resources.get(key, 0))))
	add_physical_resource(StringName(key), stored)
	if amount > stored:
		drop_resource(resource_id, amount - stored, cell)

func _force_move_lootbox(box: Dictionary) -> bool:
	if box.is_empty() or String(box.get("resource_id", "")) != "lootbox" or box not in loose_items:
		return false
	var origin := Vector2i(int(box.get("x", 0)), int(box.get("y", 0)))
	var destination := Vector2i(-1, -1)
	# The stable entity id selects the same search order after save/load. No RNG is
	# consumed, so merely inspecting a loot box cannot alter later economy rolls.
	var start_direction := posmod(int(box.get("id", box.get("entity_id", 0))), 8)
	var directions := [Vector2i.RIGHT, Vector2i(1, 1), Vector2i.DOWN, Vector2i(-1, 1), Vector2i.LEFT, Vector2i(-1, -1), Vector2i.UP, Vector2i(1, -1)]
	for radius in range(4, 13):
		for offset_index in directions.size():
			var direction: Vector2i = directions[(start_direction + offset_index) % directions.size()]
			var candidate := origin + direction * radius
			if not pathfinder.is_walkable(candidate) or not _lootbox_at(candidate).is_empty() or not _building_at_cell(candidate).is_empty():
				continue
			destination = candidate
			break
		if destination.x >= 0:
			break
	if destination.x < 0:
		return false
	box.x = destination.x
	box.y = destination.y
	box.moves = int(box.get("moves", 0)) + 1
	ProgressionService.record(&"loot.box_moves")
	_emit_event(&"lootbox_moved", {
		"box_id": int(box.get("id", box.get("entity_id", 0))), "from_x": origin.x, "from_y": origin.y,
		"cell_x": destination.x, "cell_y": destination.y, "moves": int(box.moves),
	})
	AudioDirector.play_cue(&"lootbox_move")
	return true

func _villager_has_tool(villager: Dictionary, tool_id: StringName) -> bool:
	var equipment: Dictionary = villager.get("equipment", {})
	return String(equipment.get("tool", {}).get("id", "")) == String(tool_id) or String(equipment.get("terrain_tool", {}).get("id", "")) == String(tool_id)

func _find_resource_node_at_cell(cell: Vector2i) -> Dictionary:
	for resource_node in resource_nodes:
		if int(resource_node.get("x", -1)) == cell.x and int(resource_node.get("y", -1)) == cell.y:
			return resource_node
	return {}

func _finish_terrain_work(work_key: String, cell: Vector2i, action: StringName) -> void:
	var changed_base_terrain := false
	match String(action):
		"clear":
			var circle := _magic_circle_at(cell)
			if not circle.is_empty():
				var payload := StringName(circle.get("payload", "suspicious_key"))
				var item_id := drop_resource(payload, 1, cell, -1)
				var revealed_item := _find_loose_item(item_id)
				if payload == &"lootbox" and not revealed_item.is_empty():
					revealed_item.loot_table = "standard_lootbox"
					revealed_item.moves = 0
					revealed_item.owned = false
				magic_circles.erase(circle)
				ProgressionService.record(&"loot.magic_circle_discoveries")
				_emit_event(&"magic_circle_revealed", {"circle_id": int(circle.id), "resource_id": payload, "item_id": item_id, "cell_x": cell.x, "cell_y": cell.y})
				AudioDirector.play_cue(&"magic_circle_reveal")
			else:
				var resource_node := _find_resource_node_at_cell(cell)
				if not resource_node.is_empty():
					var resource_id := StringName(resource_node.get("id", ""))
					var amount := maxi(0, int(resource_node.get("amount", 0)))
					var capacity := int(resource_caps.get(String(resource_id), 200))
					var stored := mini(amount, maxi(0, capacity - int(resources.get(String(resource_id), 0))))
					add_physical_resource(StringName(resource_id), stored)
					if amount - stored > 0:
						drop_resource(resource_id, amount - stored, cell)
					resource_nodes.erase(resource_node)
					for source_index in range(blueprint.resource_nodes.size() - 1, -1, -1):
						var source_node: Dictionary = blueprint.resource_nodes[source_index]
						if int(source_node.get("x", -1)) == cell.x and int(source_node.get("y", -1)) == cell.y:
							blueprint.resource_nodes.remove_at(source_index)
					terrain_effects.erase(work_key)
				blueprint.set_tile(cell, _base_ground_tile())
				changed_base_terrain = true
		"dig":
			terrain_effects[work_key] = {"kind": "hole", "intensity": 1000, "remaining_ticks": -1}
		"fill":
			if String(terrain_effects.get(work_key, {}).get("kind", "")) == "hole":
				terrain_effects.erase(work_key)
		"restore":
			if String(terrain_effects.get(work_key, {}).get("kind", "")) in ["ash", "mud", "flood"]:
				terrain_effects.erase(work_key)
	terrain_work.erase(work_key)
	if changed_base_terrain:
		_refresh_navigation_buildings()
	ProgressionService.record(StringName("maintenance.terrain.%s" % String(action)))
	_emit_event(&"terrain_changed", {"action": action, "cell_x": cell.x, "cell_y": cell.y, "base_changed": changed_base_terrain})

func _base_ground_tile() -> int:
	return RegionGenerator.Tile.SAND if blueprint.biome_id in [&"desert", &"red_sands"] else RegionGenerator.Tile.GRASS

func _maintenance_service() -> Dictionary:
	return ContentRegistry.get_by_id(&"buildings", &"maintenance_building").get("service", {})

func _take_repair_material(building: Dictionary) -> String:
	var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
	var candidates: Array = definition.get("cost", {}).keys()
	candidates.sort()
	for resource_id in candidates:
		if int(resources.get(String(resource_id), 0)) <= 0:
			continue
		consume_physical_resource(StringName(resource_id), 1)
		ProgressionService.record(&"maintenance.repair_materials_consumed")
		ProgressionService.record(StringName("maintenance.repair_materials_consumed.%s" % String(resource_id)))
		return String(resource_id)
	return ""

func _finish_dismantle(building: Dictionary) -> void:
	var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
	var completion_ratio := 1.0 if bool(building.get("completed", false)) else clampf(float(building.get("progress", 0)) / maxf(1.0, float(building.get("build_time", 1))), 0.0, 1.0)
	var salvage_ratio := float(_maintenance_service().get("salvage_ratio", 0.5))
	var salvaged: Dictionary = {}
	for resource_id in definition.get("cost", {}):
		var amount := floori(float(definition.cost[resource_id]) * salvage_ratio * completion_ratio)
		if amount <= 0:
			continue
		var capacity := int(resource_caps.get(String(resource_id), 200))
		var stored := mini(amount, maxi(0, capacity - int(resources.get(String(resource_id), 0))))
		add_physical_resource(StringName(resource_id), stored)
		var overflow := amount - stored
		if overflow > 0:
			loose_items.append({
				"entity_id": _next_id(), "resource_id": String(resource_id), "amount": overflow,
				"x": int(building.x) + int(building.width) / 2, "y": int(building.y) + int(building.height) / 2,
				"decay_ticks": _default_decay_ticks(ContentRegistry.get_by_id(&"resources", StringName(resource_id))),
			})
		salvaged[String(resource_id)] = amount
	var removed_id := int(building.id)
	var removed_definition := String(building.definition_id)
	buildings.erase(building)
	_recalculate_settlement_support()
	_refresh_navigation_buildings()
	ProgressionService.record(&"maintenance.buildings_dismantled")
	_emit_event(&"building_dismantled", {"building_id": removed_id, "definition_id": removed_definition, "salvaged": salvaged})

func _medicine_for_patient(patient: Dictionary) -> String:
	var statuses: Dictionary = patient.get("status_effects", {})
	if not statuses.is_empty():
		for medicine_id in ["medkit", "healing_potion", "bandage"]:
			if int(resources.get(medicine_id, 0)) <= 0:
				continue
			var medical: Dictionary = ContentRegistry.get_by_id(&"resources", StringName(medicine_id)).get("medical", {})
			var cures: Array = medical.get("cures", [])
			if "*" in cures:
				return medicine_id
			for status_id in statuses:
				if String(status_id) in cures:
					return medicine_id
		return ""
	var missing_health := 1000 - int(patient.health)
	var bandage_healing := int(ContentRegistry.get_by_id(&"resources", &"bandage").get("medical", {}).get("healing", 0))
	if missing_health <= bandage_healing and int(resources.get("bandage", 0)) > 0:
		return "bandage"
	if int(resources.get("medkit", 0)) > 0:
		return "medkit"
	if int(resources.get("healing_potion", 0)) > 0:
		return "healing_potion"
	if int(resources.get("bandage", 0)) > 0:
		return "bandage"
	return ""

func _apply_medicine(patient: Dictionary, medicine: String) -> void:
	if int(resources.get(medicine, 0)) <= 0:
		return
	consume_physical_resource(StringName(medicine), 1)
	var medical: Dictionary = ContentRegistry.get_by_id(&"resources", StringName(medicine)).get("medical", {})
	var healing := int(medical.get("healing", 0))
	patient.health = mini(1000, int(patient.health) + int(healing))
	var statuses: Dictionary = patient.get("status_effects", {})
	var cures: Array = medical.get("cures", [])
	if "*" in cures:
		statuses.clear()
	else:
		for status_id in cures:
			statuses.erase(String(status_id))
	patient.status_effects = statuses
	patient.medical_state = "recovered"

func _has_completed_building(definition_id: StringName) -> bool:
	for building in buildings:
		if StringName(building.definition_id) == definition_id and bool(building.completed) and not bool(building.get("destroyed", false)):
			return true
	return false

func _animal_home_definition(animal_type: StringName) -> StringName:
	match String(animal_type):
		"clucker": return &"clucker_coop"
		"doggo", "doofy_doggo": return &"doggo_house"
		_: return &"animal_pen"

func _animal_home_capacity(building: Dictionary) -> int:
	var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.get("definition_id", "")))
	match String(building.get("definition_id", "")):
		"animal_pen": return int(definition.get("animal_capacity", 0)) * int(building.get("tier", 1))
		"clucker_coop": return int(definition.get("clucker_capacity", 0)) * int(building.get("tier", 1))
		"doggo_house": return int(definition.get("doggo_capacity", 0)) * int(building.get("tier", 1))
	return 0

func _animal_home_occupancy(building_id: int) -> int:
	var occupancy := 0
	for animal in animals:
		if int(animal.get("health", 0)) > 0 and bool(animal.get("domesticated", false)) and int(animal.get("home_id", 0)) == building_id:
			occupancy += 1
	return occupancy

func _animal_has_open_home(animal_type: StringName) -> bool:
	var required_definition := _animal_home_definition(animal_type)
	for building in buildings:
		if StringName(building.definition_id) != required_definition or not bool(building.completed) or bool(building.get("destroyed", false)):
			continue
		if _animal_home_occupancy(int(building.id)) < _animal_home_capacity(building):
			return true
	return false

func _assign_animal_home(animal: Dictionary) -> int:
	var required_definition := _animal_home_definition(StringName(animal.get("definition_id", "")))
	for building in buildings:
		if StringName(building.definition_id) != required_definition or not bool(building.completed) or bool(building.get("destroyed", false)):
			continue
		if _animal_home_occupancy(int(building.id)) < _animal_home_capacity(building):
			return int(building.id)
	return 0

func _designate_animal_capture(payload: Dictionary) -> void:
	var animal := _find_animal(int(payload.get("animal_entity_id", 0)))
	if animal.is_empty() or int(animal.get("health", 0)) <= 0:
		_emit_event(&"command_rejected", {"reason": "unknown_animal"})
		return
	if bool(animal.get("domesticated", false)) or String(animal.get("definition_id", "")) in ["doggo", "doofy_doggo"]:
		_emit_event(&"command_rejected", {"reason": "animal_cannot_be_captured", "animal_id": animal.id})
		return
	var enabled := bool(payload.get("enabled", true))
	animal.capture_designated = enabled
	if enabled:
		animal.slaughter_designated = false
		animal.state = "capture_designated"
	else:
		animal.state = "wandering"
	_emit_event(&"animal_capture_designated", {"animal_id": animal.id, "enabled": enabled})

func _designate_animal_slaughter(payload: Dictionary) -> void:
	var animal := _find_animal(int(payload.get("animal_entity_id", 0)))
	if animal.is_empty() or int(animal.get("health", 0)) <= 0:
		_emit_event(&"command_rejected", {"reason": "unknown_animal"})
		return
	if not bool(animal.get("domesticated", false)) or String(animal.get("definition_id", "")) in ["doggo", "doofy_doggo"]:
		_emit_event(&"command_rejected", {"reason": "animal_cannot_be_slaughtered", "animal_id": animal.id})
		return
	var enabled := bool(payload.get("enabled", true))
	animal.slaughter_designated = enabled
	animal.auto_slaughter_designated = false
	if enabled:
		animal.capture_designated = false
		animal.state = "slaughter_designated"
	else:
		animal.state = "domesticated"
	_emit_event(&"animal_slaughter_designated", {"animal_id": animal.id, "enabled": enabled})

func _refresh_automatic_slaughter_designations() -> void:
	# The reference husbandry rule keeps a pen/coop at or below 75% by asking
	# Cooks to slaughter the oldest eligible adults. Manual designations remain
	# untouched and count toward the required reduction.
	for animal in animals:
		if bool(animal.get("auto_slaughter_designated", false)):
			animal.auto_slaughter_designated = false
			animal.slaughter_designated = false
	var homes: Array[Dictionary] = []
	for building in buildings:
		if bool(building.get("completed", false)) and not bool(building.get("destroyed", false)) and String(building.get("definition_id", "")) in ["animal_pen", "clucker_coop"]:
			homes.append(building)
	homes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("id", 0)) < int(b.get("id", 0)))
	for home in homes:
		var occupants: Array[Dictionary] = []
		var manually_designated := 0
		for animal in animals:
			if int(animal.get("health", 0)) <= 0 or not bool(animal.get("domesticated", false)) or int(animal.get("home_id", 0)) != int(home.id):
				continue
			occupants.append(animal)
			if bool(animal.get("slaughter_designated", false)):
				manually_designated += 1
		var target_occupancy := int(floor(float(_animal_home_capacity(home)) * 0.75))
		var automatic_needed := maxi(0, occupants.size() - target_occupancy - manually_designated)
		if automatic_needed <= 0:
			continue
		var candidates: Array[Dictionary] = occupants.filter(func(animal: Dictionary) -> bool:
			return not bool(animal.get("slaughter_designated", false)) \
				and String(animal.get("age_stage", "adult")) == "adult" \
				and int(animal.get("pregnant_ticks", 0)) <= 0 \
				and String(animal.get("definition_id", "")) not in ["doggo", "doofy_doggo"])
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var age_a := int(a.get("age_days", 0))
			var age_b := int(b.get("age_days", 0))
			return age_a > age_b if age_a != age_b else int(a.get("id", 0)) < int(b.get("id", 0)))
		for index in mini(automatic_needed, candidates.size()):
			candidates[index].slaughter_designated = true
			candidates[index].auto_slaughter_designated = true
			candidates[index].capture_designated = false
			candidates[index].state = "slaughter_designated"

func _slaughter_animal(animal: Dictionary) -> void:
	var yields: Dictionary = {
		"beefalo": {"raw_meat": 14, "leather": 4},
		"entler": {"raw_meat": 12, "wood": 8},
		"rous": {"raw_meat": 16},
		"clucker": {"raw_meat": 4, "feathers": 6},
	}.get(String(animal.definition_id), {"raw_meat": 4})
	for resource_id in yields:
		add_physical_resource_capped(StringName(resource_id), int(yields[resource_id]))
	animal.health = 0
	animal.slaughtered = true
	animal.slaughter_designated = false
	animal.state = "slaughtered"
	animals.erase(animal)
	ProgressionService.record(&"animals.slaughtered")
	_emit_event(&"animal_slaughtered", {"animal_id": animal.id, "definition_id": animal.definition_id, "yields": yields.duplicate(true)})

func drop_resource(resource_id: StringName, amount: int, cell: Vector2i, decay_ticks: int = -1) -> int:
	if amount <= 0 or ContentRegistry.get_by_id(&"resources", resource_id).is_empty():
		return 0
	var definition := ContentRegistry.get_by_id(&"resources", resource_id)
	var item := {
		"id": _next_id(), "resource_id": String(resource_id), "amount": amount,
		"x": cell.x, "y": cell.y, "decay_ticks": decay_ticks if decay_ticks >= 0 else _default_decay_ticks(definition),
		"owned": true,
	}
	loose_items.append(item)
	return int(item.id)

func _default_decay_ticks(definition: Dictionary) -> int:
	match String(definition.get("group", "raw")):
		"food": return TICKS_PER_DAY
		"water": return TICKS_PER_DAY * 2
		"raw": return TICKS_PER_DAY * 4
		"refined", "equipment", "weapon", "armor", "tool": return TICKS_PER_DAY * 8
		_: return -1

func _update_decay_and_trash() -> void:
	if tick % 10 != 0:
		return
	for item in loose_items:
		if int(item.get("decay_ticks", -1)) < 0:
			continue
		item.decay_ticks = int(item.decay_ticks) - 10
		if int(item.decay_ticks) > 0:
			continue
		var definition := ContentRegistry.get_by_id(&"resources", StringName(item.resource_id))
		var trash_id := String(definition.get("decays_to", "trashy_trash"))
		item.resource_id = trash_id
		item.decay_ticks = -1
		ProgressionService.record(&"trash.generated", int(item.amount))
	_collect_loose_trash()
	_spawn_trashy_slime_from_piles()

func _collect_loose_trash() -> void:
	if int(jobs.get("trashers", {}).get("current", 0)) <= 0:
		return
	var has_waste_storage := buildings.any(func(building: Dictionary) -> bool:
		return bool(building.completed) and not bool(building.get("destroyed", false)) and int(ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id)).get("trash_storage", 0)) > 0)
	if not has_waste_storage:
		return
	var trash_groups := ["trashy_trash", "woody_trash", "rocky_trash", "crystally_trash", "organicy_trash", "suspiciousy_trash"]
	for index in loose_items.size():
		var item: Dictionary = loose_items[index]
		if String(item.resource_id) not in trash_groups:
			continue
		var capacity := int(resource_caps.get(String(item.resource_id), 0))
		var available := capacity - int(resources.get(String(item.resource_id), 0))
		if available <= 0:
			return
		var moved := mini(available, int(item.amount))
		add_physical_resource(StringName(item.resource_id), moved, PhysicalInventory.LocationState.GROUND, Vector2i(int(item.x), int(item.y)))
		item.amount = int(item.amount) - moved
		ProgressionService.record(&"trash.collected", moved)
		if int(item.amount) <= 0:
			loose_items.remove_at(index)
		return

func _spawn_trashy_slime_from_piles() -> void:
	if tick % 200 != 0:
		return
	var loose_trash := 0
	var spawn_cell := blueprint.starting_cell
	for item in loose_items:
		if String(item.resource_id).ends_with("trash"):
			loose_trash += int(item.amount)
			spawn_cell = Vector2i(int(item.x), int(item.y))
	if loose_trash < 6:
		return
	monsters.append({
		"id": _next_id(), "definition_id": "trashy_slime", "name": "Trashy Slime",
		"x": float(spawn_cell.x) + 0.5, "y": float(spawn_cell.y) + 0.5, "target_x": float(spawn_cell.x), "target_y": float(spawn_cell.y),
		"health": 340, "max_health": 340, "damage": 5, "damage_type": "poison", "speed": 0.06, "attack_reload": 12, "attack_cooldown": 0, "state": "spawning",
		"task_id": 0, "task_kind": "", "task_progress": 0, "path": [], "path_index": 0,
		"path_goal_x": -1, "path_goal_y": -1, "stuck_ticks": 0,
	})
	ProgressionService.record(&"trash_slimes.spawned")

func _update_water_buildings() -> void:
	for building in buildings:
		if not bool(building.get("completed", false)) or bool(building.get("destroyed", false)):
			continue
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
		var water: Dictionary = definition.get("water", {})
		if water.is_empty():
			continue
		_configure_water_runtime(building, definition)
		var stored: Dictionary = building.stored_resources
		var caps: Dictionary = building.storage_caps
		var clean := int(stored.get("clean_water", 0))
		var clean_cap := int(caps.get("clean_water", 0))
		match String(water.get("role", "")):
			"source":
				if clean >= clean_cap:
					building.operation_state = "full_output"
					building.water_cycle_progress = 0
					continue
				building.operation_state = "filling"
				building.water_cycle_progress = int(building.water_cycle_progress) + 1
				if int(building.water_cycle_progress) >= int(water.get("generate_ticks", 45)):
					stored.clean_water = mini(clean_cap, clean + 1)
					building.water_cycle_progress = 0
					ProgressionService.record(&"water.generated.well")
			"rain_catcher":
				if clean >= clean_cap:
					building.operation_state = "full_output"
					building.water_cycle_progress = 0
					continue
				if weather != &"rain":
					building.operation_state = "waiting_for_rain"
					building.water_cycle_progress = 0
					continue
				building.operation_state = "collecting_rain"
				building.water_cycle_progress = int(building.water_cycle_progress) + 1
				if int(building.water_cycle_progress) >= int(water.get("generate_ticks", 15)):
					var rainfall := maxi(1, int(water.get("rain_yield", 1)))
					stored.clean_water = mini(clean_cap, clean + rainfall)
					building.water_cycle_progress = 0
					ProgressionService.record(&"water.generated.rain", rainfall)
			"purifier":
				var dirty := int(stored.get("dirty_water", 0))
				if clean >= clean_cap:
					building.operation_state = "full_output"
					building.water_cycle_progress = 0
					continue
				if not _building_has_workers(definition):
					building.operation_state = "missing_worker"
					building.water_cycle_progress = 0
					continue
				if dirty <= 0:
					building.operation_state = "missing_input"
					building.water_cycle_progress = 0
					continue
				building.operation_state = "purifying"
				building.water_cycle_progress = int(building.water_cycle_progress) + 1
				if int(building.water_cycle_progress) >= int(water.get("process_ticks", 30)):
					stored.dirty_water = dirty - 1
					stored.clean_water = clean + 1
					building.water_cycle_progress = 0
					ProgressionService.record(&"water.purified")
			"fountain":
				building.operation_state = "available" if clean > 0 else "missing_input"
		building.stored_resources = stored

func _water_building_center(building: Dictionary) -> Vector2:
	return Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)

func _nearest_surface_water_cell(building: Dictionary, maximum_range: int) -> Vector2i:
	var center := Vector2i(roundi(_water_building_center(building).x), roundi(_water_building_center(building).y))
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for y in range(maxi(1, center.y - maximum_range), mini(blueprint.height - 1, center.y + maximum_range + 1)):
		for x in range(maxi(1, center.x - maximum_range), mini(blueprint.width - 1, center.x + maximum_range + 1)):
			if blueprint.get_tile(Vector2i(x, y)) != RegionGenerator.Tile.DEEP_WATER:
				continue
			for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var shoreline: Vector2i = Vector2i(x, y) + Vector2i(direction)
				if not pathfinder.is_walkable(shoreline):
					continue
				var distance := center.distance_squared_to(shoreline)
				if distance <= maximum_range * maximum_range and distance < best_distance:
					best_distance = distance
					best = shoreline
	return best

func _find_water_supply_source(destination: Dictionary) -> Dictionary:
	var destination_center := _water_building_center(destination)
	var best: Dictionary = {}
	var best_distance := INF
	for source in buildings:
		if int(source.id) == int(destination.id) or not bool(source.get("completed", false)) or bool(source.get("destroyed", false)):
			continue
		var source_definition := ContentRegistry.get_by_id(&"buildings", StringName(source.definition_id))
		var source_water: Dictionary = source_definition.get("water", {})
		if String(source_water.get("role", "")) not in ["source", "rain_catcher", "purifier"]:
			continue
		if int(source.get("stored_resources", {}).get("clean_water", 0)) <= 0:
			continue
		var distance := destination_center.distance_squared_to(_water_building_center(source))
		if distance < best_distance:
			best_distance = distance
			best = {"building_id": int(source.id), "position": _water_building_center(source)}
	if int(resources.get("clean_water", 0)) > 0:
		for camp in buildings:
			if String(camp.definition_id) != "camp" or not bool(camp.get("completed", false)) or bool(camp.get("destroyed", false)):
				continue
			var camp_distance := destination_center.distance_squared_to(_water_building_center(camp))
			if camp_distance < best_distance:
				best = {"building_id": 0, "position": _water_building_center(camp)}
			break
	return best

func _update_production() -> void:
	for building in buildings:
		if not bool(building.completed) or bool(building.get("destroyed", false)):
			continue
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
		var requires_attendance := _building_requires_workplace_attendance(definition)
		var attending_workers := _building_attending_worker_count(building, definition) if requires_attendance else 0
		building.active_worker_count = attending_workers
		if String(building.category) == "golems":
			continue
		if requires_attendance and attending_workers <= 0:
			building.operation_state = "missing_worker"
			continue
		if String(building.definition_id) == "processor":
			building.operation_state = "processing"
			_update_trash_processor(building)
			continue
		if String(building.definition_id) == "burner":
			building.operation_state = "burning_trash"
			_update_trash_burner(building)
			continue
		if String(building.definition_id) == "essence_altar":
			building.operation_state = "praying"
			building.operation_progress = int(building.operation_progress) + 1
			if int(building.operation_progress) >= int(definition.get("prayer_ticks", 80)):
				add_physical_resource_capped(&"essence", 3, Vector2i(int(building.x), int(building.y)))
				add_physical_resource_capped(&"faith", 3)
				building.operation_progress = 0
				ProgressionService.record(&"faith.prayers_completed")
				ProgressionService.record(&"resources.generated.essence", 3)
			continue
		if String(building.definition_id) == "essence_collector":
			building.operation_progress = int(building.operation_progress) + 1
			if int(building.operation_progress) >= 30 and int(resources.get("essence", 0)) > 0 and int(resources.get("energy", 0)) < int(resource_caps.get("energy", 1000)):
				consume_physical_resource(&"essence", 1)
				var energy_before := int(resources.energy)
				add_physical_resource_capped(&"energy", int(definition.get("essence_energy_value", 3)))
				ProgressionService.record(&"resources.generated.energy", int(resources.energy) - energy_before)
				building.operation_progress = 0
			continue
		if String(building.definition_id) == "cullis_gate":
			_update_cullis_gate(building, definition)
			continue
		var passive_recipe: Dictionary = definition.get("passive_recipe", {})
		if not passive_recipe.is_empty():
			building.operation_state = "operating"
			building.operation_progress = int(building.operation_progress) + 1
			if int(building.operation_progress) >= int(passive_recipe.get("ticks", 100)):
				if _execute_recipe(passive_recipe):
					building.operation_progress = 0
			continue
		var available_recipes: Array[Dictionary] = []
		for recipe in ContentRegistry.get_all(&"recipes"):
			if String(recipe.get("building", "")) == String(building.definition_id):
				available_recipes.append(recipe)
		if available_recipes.is_empty():
			continue
		if String(building.active_recipe).is_empty():
			building.active_recipe = String(available_recipes[0].id)
			building.recipe_mode = "maintain"
			building.recipe_target = 16
			building.recipe_remaining = 0
		var selected_recipe: Dictionary = {}
		for recipe in available_recipes:
			if String(recipe.id) == String(building.active_recipe):
				selected_recipe = recipe
				break
		if selected_recipe.is_empty() or not _recipe_policy_requests_output(building, selected_recipe):
			building.operation_progress = 0
			building.operation_state = "paused" if String(building.get("recipe_mode", "maintain")) == "paused" else "target_met"
			continue
		building.operation_state = "producing"
		building.operation_progress = int(building.operation_progress) + 1
		if int(building.operation_progress) >= int(selected_recipe.get("ticks", 100)) and _execute_recipe(selected_recipe):
			building.operation_progress = 0
			if String(building.get("recipe_mode", "maintain")) == "make":
				building.recipe_remaining = maxi(0, int(building.get("recipe_remaining", 0)) - 1)
				if int(building.recipe_remaining) == 0:
					building.recipe_mode = "paused"

func _update_trash_processor(building: Dictionary) -> void:
	building.operation_progress = int(building.operation_progress) + 1
	if int(building.operation_progress) < 60:
		return
	var recovery := {
		"woody_trash": "wood", "rocky_trash": "rock", "crystally_trash": "crystal",
		"organicy_trash": "raw_vegetables", "suspiciousy_trash": "suspicious_key",
	}
	for trash_id in recovery:
		if int(resources.get(trash_id, 0)) <= 0:
			continue
		consume_physical_resource(StringName(trash_id), 1)
		# Named simulation RNG keeps recovery deterministic. Exact Update 2d odds remain a ledger verification item.
		var roll := rng.randi_range(0, 239)
		if roll < 39:
			var recovered := String(recovery[trash_id])
			add_physical_resource_capped(StringName(recovered), 1)
		if roll >= 39 and roll < 158 and int(resources.trashy_trash) < int(resource_caps.trashy_trash):
			add_physical_resource(&"trashy_trash", 1)
		ProgressionService.record(&"trash.processed")
		building.operation_progress = 0
		return
	building.operation_progress = 0

func _update_trash_burner(building: Dictionary) -> void:
	building.operation_progress = int(building.operation_progress) + 1
	if int(building.operation_progress) < 90:
		return
	var burn_order := ["trashy_cube", "trashy_trash", "woody_trash", "rocky_trash", "crystally_trash", "organicy_trash", "suspiciousy_trash"]
	for trash_id in burn_order:
		if int(resources.get(trash_id, 0)) <= 0:
			continue
		consume_physical_resource(StringName(trash_id), 1)
		var essence_yield := 4 if trash_id == "trashy_cube" else 1
		add_physical_resource_capped(&"essence", essence_yield)
		ProgressionService.record(&"trash.burned", 4 if trash_id == "trashy_cube" else 1)
		building.operation_progress = 0
		return
	building.operation_progress = 0

func _recipe_policy_requests_output(building: Dictionary, recipe: Dictionary) -> bool:
	var policy_mode := String(building.get("recipe_mode", "maintain"))
	if policy_mode == "paused":
		return false
	if policy_mode == "make":
		return int(building.get("recipe_remaining", 0)) > 0
	var target := int(building.get("recipe_target", 16))
	for resource_id in recipe.get("outputs", {}):
		if int(resources.get(resource_id, 0)) < target:
			return true
	return false

func _building_has_workers(definition: Dictionary) -> bool:
	var required_jobs: Array = definition.get("jobs", [])
	if required_jobs.is_empty():
		return true
	for job_id in required_jobs:
		if int(jobs.get(String(job_id), {}).get("current", 0)) > 0:
			return true
	return false

func _building_requires_workplace_attendance(definition: Dictionary) -> bool:
	if definition.is_empty() or definition.get("jobs", []).is_empty():
		return false
	if not definition.get("passive_recipe", {}).is_empty() or String(definition.get("id", "")) in ["essence_altar", "processor"]:
		return true
	var definition_id := String(definition.get("id", ""))
	for recipe in ContentRegistry.get_all(&"recipes"):
		if String(recipe.get("building", "")) == definition_id:
			return true
	return false

func _building_worker_slots(building: Dictionary, definition: Dictionary) -> int:
	var worker_slots := int(definition.get("worker_slots", 0))
	var slots_by_tier: Array = definition.get("worker_slots_by_tier", [])
	if not slots_by_tier.is_empty():
		worker_slots = int(slots_by_tier[clampi(int(building.get("tier", 1)) - 1, 0, slots_by_tier.size() - 1)])
	return maxi(0, worker_slots)

func _building_attending_worker_count(building: Dictionary, definition: Dictionary) -> int:
	var required_jobs: Array = definition.get("jobs", [])
	var bounds := Rect2(float(building.x), float(building.y), float(building.width), float(building.height)).grow(1.5)
	var attending := 0
	for villager in villagers:
		if int(villager.get("health", 0)) <= 0 or String(villager.get("job", "")) not in required_jobs:
			continue
		if String(villager.get("task_kind", "")) != "operate_building":
			continue
		var task := task_board.get_task(int(villager.get("task_id", 0)))
		if int(task.get("target_id", 0)) != int(building.id):
			continue
		if bounds.has_point(Vector2(float(villager.x), float(villager.y))) or String(villager.get("state", "")).begins_with("operating_") or String(villager.get("state", "")) == "working":
			attending += 1
	return attending

func _execute_recipe(recipe: Dictionary) -> bool:
	var inputs: Dictionary = recipe.get("inputs", {})
	var outputs: Dictionary = recipe.get("outputs", {})
	for resource_id in inputs:
		if int(resources.get(resource_id, 0)) < int(inputs[resource_id]):
			return false
	for resource_id in outputs:
		if int(resources.get(resource_id, 0)) + int(outputs[resource_id]) > int(resource_caps.get(resource_id, 200)):
			return false
	for resource_id in inputs:
		consume_physical_resource(StringName(resource_id), int(inputs[resource_id]))
	for resource_id in outputs:
		add_physical_resource(StringName(resource_id), int(outputs[resource_id]))
		var produced := int(outputs[resource_id])
		ProgressionService.record(StringName("resources.produced.%s" % String(resource_id)), produced)
		var resource_definition := ContentRegistry.get_by_id(&"resources", StringName(resource_id))
		var resource_group := String(resource_definition.get("group", ""))
		if resource_group in ["tool", "armor"]:
			ProgressionService.record(StringName("resources.produced.%s" % resource_group), produced)
		if resource_id in ["boards", "cut_stone"]:
			ProgressionService.record(&"resources.refined.boards_or_cut_stone", int(outputs[resource_id]))
	return true

func _recalculate_settlement_support() -> void:
	var previous_maxima: Dictionary = {}
	for job_id in jobs:
		previous_maxima[job_id] = int(jobs[job_id].max)
		jobs[job_id].max = 12 if String(job_id) == "builders" else 0
	housing_capacity = 0
	animal_pen_capacity = 0
	clucker_coop_capacity = 0
	doggo_house_capacity = 0
	building_limit = 0
	build_range = 0
	ancillary_limit = 0
	for building in buildings:
		if not bool(building.completed) or bool(building.get("destroyed", false)):
			continue
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
		var housing_value := int(definition.get("housing_capacity", 0))
		if String(building.definition_id) == "housing" and housing_value > 0:
			var housing_branch := String(building.get("housing_branch", "standard"))
			var per_tier := 5 if housing_branch == "occupancy" else (2 if housing_branch == "quality" else 3)
			housing_value += maxi(0, int(building.tier) - 1) * per_tier
		housing_capacity += housing_value
		if String(building.definition_id) == "housing":
			housing_capacity += roundi(ProgressionService.get_modifier(&"efficient_housing"))
		animal_pen_capacity += int(definition.get("animal_capacity", 0)) * int(building.tier)
		clucker_coop_capacity += int(definition.get("clucker_capacity", 0)) * int(building.tier)
		doggo_house_capacity += int(definition.get("doggo_capacity", 0)) * int(building.tier)
		if String(building.definition_id) == "camp":
			var town_tier := _town_center_tier(int(building.tier))
			jobs.builders.max = int(town_tier.get("builders", 12))
			building_limit = int(town_tier.get("building_limit", 8))
			build_range = int(town_tier.get("range", 32))
			ancillary_limit = int(town_tier.get("ancillary_limit", 1))
			continue
		for job_id in definition.get("jobs", []):
			if jobs.has(String(job_id)):
				var worker_slots := int(definition.get("worker_slots", 0))
				var slots_by_tier: Array = definition.get("worker_slots_by_tier", [])
				if not slots_by_tier.is_empty():
					worker_slots = int(slots_by_tier[clampi(int(building.tier) - 1, 0, slots_by_tier.size() - 1)])
				jobs[String(job_id)].max = int(jobs[String(job_id)].max) + worker_slots
	for job_id in jobs:
		var old_max := int(previous_maxima.get(job_id, 0))
		var new_max := int(jobs[job_id].max)
		if old_max == 0 and new_max > 0 and int(jobs[job_id].desired) == 0:
			jobs[job_id].desired = new_max
		jobs[job_id].desired = mini(int(jobs[job_id].desired), new_max)
	_recalculate_resource_caps()
	_assign_jobs()

func _recalculate_resource_caps() -> void:
	resource_caps.clear()
	for resource_definition in ContentRegistry.get_all(&"resources"):
		var resource_id := String(resource_definition.get("id", ""))
		var group := String(resource_definition.get("group", ""))
		resource_caps[resource_id] = 1000 if resource_id in ["energy", "faith"] else (0 if group == "trash" else 200)
	resource_caps.energy = 1000
	resource_caps.faith = 1000
	for building in buildings:
		if not bool(building.get("completed", false)) or bool(building.get("destroyed", false)):
			continue
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.get("definition_id", "")))
		for resource_id in definition.get("storage", {}):
			resource_caps[resource_id] = int(resource_caps.get(resource_id, 200)) + int(definition.storage[resource_id])
		for resource_id in definition.get("storage_per_tier", {}):
			resource_caps[resource_id] = int(resource_caps.get(resource_id, 200)) + int(definition.storage_per_tier[resource_id]) * maxi(0, int(building.get("tier", 1)) - 1)
		var trash_storage := int(definition.get("trash_storage", 0)) * int(building.get("tier", 1))
		if trash_storage > 0:
			for trash_id in ["trashy_trash", "woody_trash", "rocky_trash", "crystally_trash", "organicy_trash", "suspiciousy_trash", "trashy_cube"]:
				resource_caps[trash_id] = int(resource_caps.get(trash_id, 0)) + trash_storage
		_configure_storage_runtime(building, definition)
		var profile_capacity := get_storage_profile_capacity(building)
		if profile_capacity > 0:
			var filters: Dictionary = building.get("storage_filters", {})
			for resource_id in get_storage_profile_resources(building):
				if bool(filters.get(resource_id, true)):
					resource_caps[resource_id] = int(resource_caps.get(resource_id, 0)) + profile_capacity
		if String(building.get("definition_id", "")) == "camp":
			var town_tier := _town_center_tier(int(building.get("tier", 1)))
			for resource_id in resource_caps:
				if resource_id not in ["energy", "faith"]:
					resource_caps[resource_id] = int(resource_caps[resource_id]) + int(town_tier.get("storage", 20))

func _update_needs() -> void:
	if tick % 10 != 0:
		return
	var needs_rate := float(mode_rules.get("needs_rate", 1.0))
	if needs_rate <= 0.0:
		return
	for villager in villagers:
		villager.hunger = maxi(0, int(villager.hunger) - maxi(1, roundi(needs_rate)))
		villager.thirst = maxi(0, int(villager.thirst) - maxi(1, roundi(needs_rate * 2.0)))
		villager.energy = maxi(0, int(villager.energy) - maxi(1, roundi(needs_rate)))
		if int(villager.hunger) == 0 or int(villager.thirst) == 0:
			villager.health = maxi(0, int(villager.health) - 5)

func _update_resource_rates() -> void:
	if tick < next_resource_rate_tick:
		return
	var elapsed_ticks := maxi(1, tick - resource_rate_sample_tick)
	resource_rates.clear()
	for resource_id in resources:
		var change := int(resources.get(resource_id, 0)) - int(resource_rate_sample.get(resource_id, 0))
		resource_rates[resource_id] = float(change) * float(TICKS_PER_DAY) / float(elapsed_ticks)
	resource_rate_sample = resources.duplicate(true)
	resource_rate_sample_tick = tick
	next_resource_rate_tick = tick + 100

func _update_death_and_ghosts() -> void:
	for villager in villagers:
		if int(villager.health) > 0 or bool(villager.get("ghost_created", false)):
			continue
		villager.ghost_created = true
		villager.state = "dead"
		if int(villager.get("status_effects", {}).get("infection", 0)) > 0:
			_spawn_monster_actor(&"zombie", Vector2(float(villager.x), float(villager.y)))
			ProgressionService.record(&"population.infected_deaths")
		if int(villager.get("status_effects", {}).get("burning", 0)) > 0:
			ProgressionService.record(&"population.fire_deaths")
		if String(villager.get("species", "villager")) == "catjeet":
			ProgressionService.record(&"population.deaths.catjeet")
		ghosts.append({
			"id": _next_id(), "source_kind": "villager", "source_villager_id": int(villager.id), "name": "%s's Ghost" % String(villager.name),
			"x": float(villager.x), "y": float(villager.y), "bound": false, "age_ticks": 0,
			"villager_record": villager.duplicate(true),
		})
		ProgressionService.record(&"population.deaths")
	for ghost in ghosts:
		ghost.age_ticks = int(ghost.age_ticks) + 1
		if not bool(ghost.bound) and tick % 20 == int(ghost.id) % 20:
			ghost.x = float(ghost.x) + rng.randf_range(-0.6, 0.6)
			ghost.y = float(ghost.y) + rng.randf_range(-0.6, 0.6)
	_attempt_bind_ghosts()

func _attempt_bind_ghosts() -> void:
	if int(resources.get("empty_eerie_vessel", 0)) <= 0:
		return
	var reliquaries: Array[Dictionary] = []
	for building in buildings:
		if bool(building.completed) and not bool(building.get("destroyed", false)) and String(building.definition_id) == "reliquary":
			reliquaries.append(building)
	if reliquaries.is_empty():
		return
	for ghost in ghosts:
		if bool(ghost.bound):
			continue
		for reliquary in reliquaries:
			var center := Vector2(float(reliquary.x) + float(reliquary.width) * 0.5, float(reliquary.y) + float(reliquary.height) * 0.5)
			if center.distance_to(Vector2(float(ghost.x), float(ghost.y))) <= 40.0:
				ghost.bound = true
				ghost.x = center.x
				ghost.y = center.y
				consume_physical_resource(&"empty_eerie_vessel", 1)
				add_physical_resource(&"filled_eerie_vessel", 1)
				ProgressionService.record(&"ghosts.bound")
				break

func _update_corruption() -> void:
	if tick % 50 != 0 or corruption_cells.is_empty():
		return
	var resistance_sources := _settlement_range_sources()
	var reclaimed := _reclaim_resisted_corruption(resistance_sources)
	if reclaimed > 0:
		ProgressionService.record(&"corruption.reclaimed", reclaimed)
		_emit_event(&"corruption_reclaimed", {"count": reclaimed, "remaining": corruption_cells.size()})
	if corruption_cells.is_empty():
		return
	for corruption_key in corruption_cells.keys():
		corruption_cells[corruption_key] = mini(1000, int(corruption_cells.get(corruption_key, 1000)) + 25)
	_damage_corrupted_resources()
	var pressure := float(mode_rules.get("corruption_rate", mode_rules.get("monster_rate", 1.0)))
	if pressure <= 0.0:
		return
	var keys: Array = corruption_cells.keys()
	keys.sort()
	var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for _attempt in maxi(1, roundi(pressure)):
		var source := _cell_from_key(String(keys[rng.randi_range(0, keys.size() - 1)]))
		var candidate: Vector2i = source + directions[rng.randi_range(0, directions.size() - 1)]
		if candidate.x < 1 or candidate.y < 1 or candidate.x >= blueprint.width - 1 or candidate.y >= blueprint.height - 1:
			continue
		if blueprint.get_tile(candidate) == RegionGenerator.Tile.DEEP_WATER or Vector2(candidate - blueprint.starting_cell).length_squared() < 18.0 * 18.0:
			continue
		if _corruption_resistance_at(candidate, resistance_sources) > 0.0:
			continue
		corruption_cells[_cell_key(candidate)] = 250

func _damage_corrupted_resources() -> void:
	for resource_node in resource_nodes:
		var resource_id := String(resource_node.get("id", ""))
		if resource_id not in ["wood", "raw_vegetables"] or int(resource_node.get("amount", 0)) <= 0:
			continue
		var key := _cell_key(Vector2i(int(resource_node.x), int(resource_node.y)))
		if not corruption_cells.has(key):
			continue
		resource_node.amount = maxi(0, int(resource_node.amount) - 1)
		ProgressionService.record(StringName("resources.corruption_killed.%s" % resource_id))

func _reclaim_resisted_corruption(sources: Array[Dictionary]) -> int:
	if sources.is_empty() or corruption_cells.is_empty():
		return 0
	var candidates: Array[Dictionary] = []
	for key in corruption_cells.keys():
		var cell := _cell_from_key(String(key))
		var resistance := _corruption_resistance_at(cell, sources)
		if resistance > 0.0:
			candidates.append({"key": String(key), "resistance": resistance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.resistance), float(b.resistance)):
			return float(a.resistance) > float(b.resistance)
		return String(a.key) < String(b.key)
	)
	var reclaimed := mini(candidates.size(), maxi(1, sources.size() * CORRUPTION_RECLAIM_PER_SOURCE))
	for index in reclaimed:
		corruption_cells.erase(String(candidates[index].key))
	return reclaimed

func _update_natural_resources() -> void:
	if tick % NATURAL_REGROWTH_INTERVAL == 0:
		var season := _season_for_day(tick / TICKS_PER_DAY + 1)
		for resource_node in resource_nodes:
			var resource_id := String(resource_node.get("id", ""))
			if resource_id not in ["wood", "crystal", "raw_vegetables"]:
				continue
			if corruption_cells.has(_cell_key(Vector2i(int(resource_node.x), int(resource_node.y)))):
				continue
			var maximum := maxi(1, int(resource_node.get("initial_amount", resource_node.get("amount", 1))))
			if int(resource_node.get("amount", 0)) >= maximum:
				continue
			if season == &"Winter" and resource_id in ["wood", "raw_vegetables"]:
				continue
			resource_node.amount = mini(maximum, int(resource_node.get("amount", 0)) + 1)
			ProgressionService.record(StringName("resources.regrown.%s" % resource_id))
	_update_crystal_motivators()

func _update_crystal_motivators() -> void:
	for building in buildings:
		if not bool(building.get("completed", false)) or bool(building.get("destroyed", false)):
			continue
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.get("definition_id", "")))
		var growth: Dictionary = definition.get("growth", {})
		if String(growth.get("role", "")) != "crystal_motivator":
			continue
		var interval := maxi(1, int(growth.get("interval_ticks", 100)))
		if tick % interval != int(building.id) % interval:
			continue
		var tier := maxi(1, int(building.get("tier", 1)))
		var radius := int(growth.get("range", 8)) + int(growth.get("range_per_tier", 0)) * (tier - 1)
		var amount := maxi(1, int(growth.get("amount", 1)))
		var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
		var motivated := 0
		for resource_node in resource_nodes:
			if String(resource_node.get("id", "")) != "crystal" or center.distance_to(Vector2(float(resource_node.x) + 0.5, float(resource_node.y) + 0.5)) > float(radius):
				continue
			if corruption_cells.has(_cell_key(Vector2i(int(resource_node.x), int(resource_node.y)))):
				continue
			var maximum := maxi(1, int(resource_node.get("initial_amount", resource_node.get("amount", 1))))
			if int(resource_node.get("amount", 0)) >= maximum:
				continue
			resource_node.amount = mini(maximum, int(resource_node.get("amount", 0)) + amount)
			motivated += 1
		building.operation_state = "motivating" if motivated > 0 else "idle"
		if motivated > 0:
			ProgressionService.record(&"resources.motivated.crystal", motivated)
			_emit_event(&"land_motivated", {"building_id": building.id, "resource": "crystal", "nodes": motivated})

func _update_golems() -> void:
	_update_combobulators()
	for golem in golems:
		if int(golem.health) <= 0:
			continue
		golem.combat_cooldown = maxi(0, int(golem.get("combat_cooldown", 0)) - 1)
		if not bool(golem.get("summoned", false)):
			_update_golem_maintenance(golem)
		if int(golem.health) <= 0:
			continue
		if not bool(golem.get("powered", true)):
			continue
		if _golem_try_combat(golem):
			continue
		match String(golem.definition_id):
			"labor_golem":
				_golem_work_construction(golem)
			"wood_golem":
				_golem_work_resource(golem, "wood")
			"stone_golem":
				_golem_work_resource(golem, "rock")
			"crystal_golem":
				_golem_work_resource(golem, "crystal")
			"cube_e_golem":
				_golem_compress_trash(golem)
			_:
				golem.state = "guarding"
	var survivors: Array[Dictionary] = []
	for golem in golems:
		if int(golem.health) > 0:
			survivors.append(golem)
		else:
			_release_golem_maintenance(golem)
			ProgressionService.record(StringName("golems.lost.%s" % String(golem.definition_id)))
			_emit_event(&"golem_lost", {"golem_id": golem.id, "definition_id": golem.definition_id})
	golems = survivors

func _update_combobulators() -> void:
	for building in buildings:
		if not bool(building.completed) or bool(building.get("destroyed", false)) or String(building.category) != "golems":
			continue
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
		var golem_definition: Dictionary = definition.get("golem", {})
		if golem_definition.is_empty():
			building.operation_state = "invalid_definition"
			continue
		var active_count := 0
		for golem in golems:
			if int(golem.get("source_building_id", 0)) == int(building.id) and int(golem.health) > 0:
				active_count += 1
		var cap := int(golem_definition.get("cap_per_tier", 1)) * int(building.tier)
		building.golem_count = active_count
		building.golem_cap = cap
		if active_count >= cap:
			building.operation_progress = 0
			building.operation_state = "at_capacity"
			continue
		var energy_interval := maxi(1, int(golem_definition.get("energy_interval", 10)))
		if tick % energy_interval == int(building.id) % energy_interval:
			if int(resources.get("energy", 0)) <= 0:
				building.operation_state = "no_energy"
				continue
			consume_physical_resource(&"energy", 1)
		building.operation_progress = int(building.get("operation_progress", 0)) + 1
		building.operation_state = "charging"
		if int(building.operation_progress) < int(golem_definition.get("charge_ticks", 200)):
			continue
		var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
		_spawn_golem(StringName(golem_definition.type), center, int(building.id), golem_definition)
		building.operation_progress = 0
		building.operation_state = "deployed"

func _spawn_golem(golem_type: StringName, position: Vector2, source_building_id: int, stats: Dictionary = {}, summoned: bool = false, maintenance: int = 0) -> Dictionary:
	var actor := ContentRegistry.get_by_id(&"actors", golem_type)
	var max_health := int(stats.get("health", 1000 if golem_type != &"holy_golem" else 1600))
	var golem := {
		"id": _next_id(), "definition_id": String(golem_type), "name": actor.get("name", String(golem_type).replace("_", " ").capitalize()),
		"x": position.x, "y": position.y, "target_x": position.x, "target_y": position.y,
		"health": max_health, "max_health": max_health, "damage": int(stats.get("damage", 55 if golem_type != &"holy_golem" else 95)),
		"attack_reload": int(stats.get("attack_reload", 14)), "combat_cooldown": 0, "speed": float(stats.get("speed", 0.07)),
		"source_building_id": source_building_id, "summoned": summoned, "maintenance": maintenance, "powered": true,
		"state": "forming", "work_progress": 0, "task_id": 0, "task_kind": "", "task_progress": 0,
		"path": [], "path_index": 0, "path_goal_x": -1, "path_goal_y": -1, "stuck_ticks": 0,
	}
	golems.append(golem)
	ProgressionService.record(StringName("golems.created.%s" % String(golem_type)))
	_emit_event(&"golem_created", {"golem_id": golem.id, "definition_id": golem_type, "source_building_id": source_building_id})
	return golem

func _update_golem_maintenance(golem: Dictionary) -> void:
	if tick % 10 != int(golem.id) % 10:
		return
	var source := _find_building(int(golem.get("source_building_id", 0)))
	if source.is_empty() or bool(source.get("destroyed", false)):
		golem.health = maxi(0, int(golem.health) - 8)
		golem.state = "source_lost"
		golem.powered = false
		return
	if int(resources.get("energy", 0)) <= 0:
		golem.health = maxi(0, int(golem.health) - 3)
		golem.state = "degrading"
		golem.powered = false
		return
	consume_physical_resource(&"energy", 1)
	golem.powered = true

func _golem_try_combat(golem: Dictionary) -> bool:
	var actor := ContentRegistry.get_by_id(&"actors", StringName(golem.definition_id))
	if "combat" not in actor.get("roles", []):
		return false
	var position := Vector2(float(golem.x), float(golem.y))
	var target: Dictionary = {}
	var best_distance := 14.0 * 14.0
	for monster in monsters:
		if int(monster.health) <= 0 or int(monster.get("charmed_ticks", 0)) > 0:
			continue
		var distance := position.distance_squared_to(Vector2(float(monster.x), float(monster.y)))
		if distance <= best_distance:
			best_distance = distance
			target = monster
	if target.is_empty():
		return false
	var target_position := Vector2(float(target.x), float(target.y))
	if position.distance_to(target_position) > 1.4:
		_move_villager_toward(golem, target_position, float(golem.speed))
		golem.state = "intercepting"
		return true
	if int(golem.combat_cooldown) <= 0:
		_apply_damage_to_monster(target, int(golem.damage), &"crushing" if String(golem.definition_id) in ["stone_golem", "labor_golem"] else &"regular")
		golem.combat_cooldown = int(golem.attack_reload)
		golem.state = "attacking"
		_emit_event(&"golem_attacked", {"golem_id": golem.id, "target_id": target.id, "damage": golem.damage})
	return true

func _golem_work_construction(golem: Dictionary) -> void:
	var target: Dictionary = {}
	var position := Vector2(float(golem.x), float(golem.y))
	var best_distance := INF
	for building in buildings:
		if bool(building.completed) or bool(building.get("destroyed", false)):
			continue
		var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
		var distance := position.distance_squared_to(center)
		if distance < best_distance:
			best_distance = distance
			target = building
	if target.is_empty():
		golem.state = "available"
		return
	var target_position := Vector2(float(target.x) + float(target.width) * 0.5, float(target.y) + float(target.height) * 0.5)
	if _move_villager_toward(golem, target_position, float(golem.speed)):
		target.progress = mini(int(target.build_time), int(target.progress) + 3)
		golem.state = "building"
	else:
		golem.state = "traveling_to_build"

func _golem_work_resource(golem: Dictionary, resource_id: String) -> void:
	var target: Dictionary = {}
	var position := Vector2(float(golem.x), float(golem.y))
	var best_distance := INF
	for resource_node in resource_nodes:
		if String(resource_node.id) != resource_id or int(resource_node.amount) <= 0:
			continue
		var resource_position := Vector2(float(resource_node.x) + 0.5, float(resource_node.y) + 0.5)
		var distance := position.distance_squared_to(resource_position)
		if distance < best_distance:
			best_distance = distance
			target = resource_node
	if target.is_empty() or int(resources.get(resource_id, 0)) >= int(resource_caps.get(resource_id, 200)):
		golem.state = "available"
		return
	var target_position := Vector2(float(target.x) + 0.5, float(target.y) + 0.5)
	if not _move_villager_toward(golem, target_position, float(golem.speed)):
		golem.state = "traveling_to_harvest"
		return
	golem.work_progress = int(golem.get("work_progress", 0)) + 1
	golem.state = "harvesting"
	if int(golem.work_progress) >= 16:
		target.amount = int(target.amount) - 1
		add_physical_resource(StringName(resource_id), 1, PhysicalInventory.LocationState.GROUND, Vector2i(roundi(golem.x), roundi(golem.y)))
		golem.work_progress = 0
		ProgressionService.record(StringName("resources.harvested.%s" % resource_id))
		ProgressionService.record(&"resources.harvested.any")

func _golem_compress_trash(golem: Dictionary) -> void:
	var trash_order := ["trashy_trash", "woody_trash", "rocky_trash", "crystally_trash", "organicy_trash", "suspiciousy_trash"]
	var available := 0
	for trash_id in trash_order:
		available += int(resources.get(trash_id, 0))
	if available < 4 or int(resources.get("trashy_cube", 0)) >= int(resource_caps.get("trashy_cube", 0)):
		golem.state = "waiting_for_trash"
		golem.work_progress = 0
		return
	golem.state = "compressing_trash"
	golem.work_progress = int(golem.get("work_progress", 0)) + 1
	if int(golem.work_progress) < 80:
		return
	var remaining := 4
	for trash_id in trash_order:
		var used := mini(remaining, int(resources.get(trash_id, 0)))
		consume_physical_resource(StringName(trash_id), used)
		remaining -= used
		if remaining <= 0:
			break
	add_physical_resource(&"trashy_cube", 1)
	golem.work_progress = 0
	ProgressionService.record(&"trash.cubes_compressed")

func _release_golem_maintenance(golem: Dictionary) -> void:
	var maintenance := int(golem.get("maintenance", 0))
	if maintenance <= 0:
		return
	influence_reserved = maxi(0, influence_reserved - maintenance)
	golem.maintenance = 0

func _dispel_nearest_golem(cell: Vector2i, radius: float) -> bool:
	var best: Dictionary = {}
	var best_distance := radius
	for golem in golems:
		var distance := Vector2(float(golem.x), float(golem.y)).distance_to(Vector2(cell))
		if distance <= best_distance:
			best_distance = distance
			best = golem
	if best.is_empty():
		return false
	_release_golem_maintenance(best)
	golems.erase(best)
	ProgressionService.record(&"spells.dispelled.golem_or_building")
	_emit_event(&"golem_dispelled", {"golem_id": best.id, "definition_id": best.definition_id})
	return true

func _update_monsters() -> void:
	_spawn_monsters_if_due()
	for monster in monsters:
		if int(monster.health) <= 0:
			continue
		monster.attack_cooldown = maxi(0, int(monster.get("attack_cooldown", 0)) - 1)
		if int(monster.get("charmed_ticks", 0)) > 0:
			_update_charmed_monster(monster)
			continue
		if int(monster.get("cold_ticks", 0)) > 0:
			monster.cold_ticks = int(monster.cold_ticks) - 1
			monster.state = "chilled"
			# Cold Aura halves locomotion without changing the actor's saved base
			# speed. Alternating by stable entity ID keeps the result deterministic.
			if posmod(tick + int(monster.id), 2) == 0:
				continue
		if String(monster.get("definition_id", "")) == "drone" and _update_drone_construction(monster):
			continue
		var target := _monster_target(monster)
		if target.is_empty():
			continue
		var target_position := Vector2(float(target.x), float(target.y))
		var actor := ContentRegistry.get_by_id(&"actors", StringName(monster.definition_id))
		var reached := _move_spectre_toward(monster, target_position, float(monster.speed)) if bool(actor.get("crosses_walls", false)) else _move_villager_toward(monster, target_position, float(monster.speed), true)
		if reached:
			monster.state = "attacking"
			if int(monster.attack_cooldown) > 0:
				monster.state = "recovering"
				continue
			if String(target.kind) == "building":
				var building := _find_building(int(target.id))
				if not building.is_empty() and not bool(building.get("destroyed", false)):
					_apply_monster_hit(monster, building, &"building")
					if int(building.health) <= 0:
						building.destroyed = true
						if String(building.category) == "walls":
							ProgressionService.record(&"walls.destroyed")
						_recalculate_settlement_support()
						_refresh_navigation_buildings()
						_emit_event(&"building_destroyed", {"building_id": building.id, "definition_id": building.definition_id})
			elif String(target.kind) == "golem":
				for golem in golems:
					if int(golem.id) == int(target.id):
						_apply_monster_hit(monster, golem, &"golem")
						break
			elif String(target.kind) == "nomad":
				for nomad in nomads:
					if int(nomad.id) == int(target.id):
						_apply_monster_hit(monster, nomad, &"villager")
						break
			else:
				for villager in villagers:
					if int(villager.id) == int(target.id):
						_apply_monster_hit(monster, villager, &"villager")
						break
			monster.attack_cooldown = int(monster.get("attack_reload", 12))
		else:
			monster.state = "hunting"
	var survivors: Array[Dictionary] = []
	for monster in monsters:
		if int(monster.health) > 0:
			survivors.append(monster)
		else:
			ProgressionService.record(StringName("combat.killed.%s" % String(monster.definition_id)))
			if active_event == &"full_moon":
				ProgressionService.record(&"combat.killed.during_full_moon")
			if String(monster.get("definition_id", "")) == "skeleton" and String(monster.get("last_damage_type", "")) == "piercing":
				ProgressionService.record(&"combat.killed.skeleton_with_piercing")
			var death_cell := Vector2i(floori(float(monster.x)), floori(float(monster.y)))
			if blueprint.get_tile(death_cell) == RegionGenerator.Tile.DEEP_WATER:
				ProgressionService.record(&"combat.killed.in_water")
	monsters = survivors

func _update_charmed_monster(monster: Dictionary) -> void:
	monster.charmed_ticks = maxi(0, int(monster.get("charmed_ticks", 0)) - 1)
	var position := Vector2(float(monster.x), float(monster.y))
	var target: Dictionary = {}
	var best_distance := 18.0 * 18.0
	for candidate in monsters:
		if candidate == monster or int(candidate.get("health", 0)) <= 0 or int(candidate.get("charmed_ticks", 0)) > 0:
			continue
		var distance := position.distance_squared_to(Vector2(float(candidate.x), float(candidate.y)))
		if distance <= best_distance:
			best_distance = distance
			target = candidate
	if target.is_empty():
		monster.state = "charmed_guarding"
		return
	var target_position := Vector2(float(target.x), float(target.y))
	if position.distance_to(target_position) > 1.35:
		_move_villager_toward(monster, target_position, float(monster.speed), true)
		monster.state = "charmed_intercepting"
		return
	monster.state = "charmed_attacking"
	if int(monster.attack_cooldown) <= 0:
		_apply_damage_to_monster(target, int(monster.damage), StringName(monster.get("damage_type", "regular")))
		monster.attack_cooldown = int(monster.attack_reload)
		_emit_event(&"charmed_monster_attacked", {"attacker_id": monster.id, "target_id": target.id, "damage": monster.damage})

func _update_drone_construction(drone: Dictionary) -> bool:
	var drone_position := Vector2(float(drone.x), float(drone.y))
	var nearest_site: Dictionary = {}
	var nearest_distance := 20.0 * 20.0
	for structure in hostile_structures:
		if bool(structure.get("destroyed", false)) or bool(structure.get("completed", false)):
			continue
		var center := Vector2(float(structure.x) + float(structure.width) * 0.5, float(structure.y) + float(structure.height) * 0.5)
		var distance := drone_position.distance_squared_to(center)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_site = structure
	if not nearest_site.is_empty():
		var site_center := Vector2(float(nearest_site.x) + float(nearest_site.width) * 0.5, float(nearest_site.y) + float(nearest_site.height) * 0.5)
		if _move_spectre_toward(drone, site_center, float(drone.speed)):
			drone.state = "constructing"
			nearest_site.progress = mini(int(nearest_site.build_time), int(nearest_site.progress) + 8)
			nearest_site.health = maxi(1, roundi(float(nearest_site.max_health) * float(nearest_site.progress) / float(nearest_site.build_time)))
			if int(nearest_site.progress) >= int(nearest_site.build_time):
				nearest_site.completed = true
				nearest_site.health = int(nearest_site.max_health)
				nearest_site.operation_state = "active"
				ProgressionService.record(StringName("corruption.built.%s" % String(nearest_site.definition_id)))
				_refresh_navigation_buildings()
				_emit_event(&"hostile_structure_completed", {"structure_id": nearest_site.id, "definition_id": nearest_site.definition_id, "drone_id": drone.id})
		else:
			drone.state = "building_route"
		return true
	if tick % DRONE_BUILD_INTERVAL != int(drone.id) % DRONE_BUILD_INTERVAL or hostile_structures.size() >= MAX_HOSTILE_STRUCTURES:
		return false
	var structure_cycle: Array[StringName] = [&"corrupted_road", &"corrupted_road", &"corrupted_wall", &"corrupted_fire_pit", &"corrupted_road", &"corrupted_tower", &"corrupted_wall", &"corrupted_graveyard"]
	var structure_id: StringName = structure_cycle[posmod(int(tick / DRONE_BUILD_INTERVAL) + int(drone.id), structure_cycle.size())]
	var corruption_keys: Array = corruption_cells.keys()
	corruption_keys.sort()
	if corruption_keys.is_empty():
		return false
	var start_index := posmod(int(drone.id) * 17 + int(tick / DRONE_BUILD_INTERVAL) * 7, corruption_keys.size())
	for offset in mini(64, corruption_keys.size()):
		var candidate := _cell_from_key(String(corruption_keys[(start_index + offset) % corruption_keys.size()]))
		if drone_position.distance_to(Vector2(candidate) + Vector2(0.5, 0.5)) > 18.0:
			continue
		if _spawn_hostile_structure(structure_id, candidate, int(drone.id)).is_empty():
			continue
		drone.state = "constructing"
		return true
	return false

func _spawn_hostile_structure(structure_id: StringName, cell: Vector2i, drone_id: int = 0) -> Dictionary:
	var definition := ContentRegistry.get_by_id(&"buildings", structure_id)
	if definition.is_empty() or String(definition.get("category", "")) != "hostile":
		return {}
	var footprint_data: Array = definition.get("footprint", [1, 1])
	var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
	if not _hostile_footprint_valid(cell, footprint):
		return {}
	var build_time := int(definition.get("build_time", 100))
	var progress := maxi(1, roundi(float(build_time) * 0.20))
	var maximum_health := int(definition.get("health", 1000))
	var structure: Dictionary = {
		"id": _next_id(), "definition_id": String(structure_id), "name": definition.get("name", String(structure_id)),
		"category": "hostile", "x": cell.x, "y": cell.y, "width": footprint.x, "height": footprint.y,
		"tier": 1, "progress": progress, "build_time": build_time, "completed": false,
		"health": maxi(1, roundi(float(maximum_health) * 0.20)), "max_health": maximum_health,
		"ownership": "corruption", "visual_state": "corrupted", "corrupted": true,
		"destroyed": false, "burning": false, "status_effects": {}, "operation_state": "constructing",
		"hostile_role": String(definition.get("hostile", {}).get("role", "")), "combat_cooldown": 0,
		"construction_drone_id": drone_id,
	}
	hostile_structures.append(structure)
	_emit_event(&"hostile_structure_started", {"structure_id": structure.id, "definition_id": structure_id, "drone_id": drone_id})
	return structure

func _hostile_footprint_valid(cell: Vector2i, footprint: Vector2i) -> bool:
	if cell.x < 1 or cell.y < 1 or cell.x + footprint.x >= blueprint.width - 1 or cell.y + footprint.y >= blueprint.height - 1:
		return false
	if _footprint_overlaps(cell, footprint):
		return false
	for y in range(cell.y, cell.y + footprint.y):
		for x in range(cell.x, cell.x + footprint.x):
			if not corruption_cells.has(_cell_key(Vector2i(x, y))) or blueprint.get_tile(Vector2i(x, y)) == RegionGenerator.Tile.DEEP_WATER:
				return false
	return true

func _update_hostile_structures() -> void:
	for structure in hostile_structures:
		if not bool(structure.get("completed", false)) or bool(structure.get("destroyed", false)):
			continue
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(structure.definition_id))
		var hostile: Dictionary = definition.get("hostile", {})
		var center := Vector2(float(structure.x) + float(structure.width) * 0.5, float(structure.y) + float(structure.height) * 0.5)
		match String(hostile.get("role", "")):
			"tower":
				structure.combat_cooldown = maxi(0, int(structure.get("combat_cooldown", 0)) - 1)
				if int(structure.combat_cooldown) > 0:
					continue
				var target := _nearest_living_villager(center, float(hostile.get("range", 24)))
				if target.is_empty():
					structure.operation_state = "idle"
					continue
				target.health = maxi(0, int(target.health) - int(hostile.get("damage", 18)))
				structure.combat_cooldown = int(hostile.get("reload_ticks", 30))
				structure.operation_state = "firing"
				_emit_event(&"hostile_tower_fired", {"structure_id": structure.id, "target_id": target.id})
			"fire_pit":
				var interval := maxi(1, int(hostile.get("spread_interval_ticks", 100)))
				if tick % interval == int(structure.id) % interval:
					_spread_corruption_from_hostile(center)
			"graveyard":
				var interval := maxi(1, int(hostile.get("spawn_interval_ticks", 400)))
				if tick % interval == int(structure.id) % interval and monsters.size() < 600:
					var monster_id: StringName = &"zombie" if (tick / interval + int(structure.id)) % 2 == 0 else &"skeleton"
					_spawn_monster_actor(monster_id, center)
					ProgressionService.record(&"corruption.graveyard_spawns")

func _nearest_living_villager(center: Vector2, radius: float) -> Dictionary:
	var result: Dictionary = {}
	var best_distance := radius * radius
	for villager in villagers:
		if int(villager.health) <= 0:
			continue
		var distance := center.distance_squared_to(Vector2(float(villager.x), float(villager.y)))
		if distance <= best_distance:
			best_distance = distance
			result = villager
	return result

func _spread_corruption_from_hostile(center: Vector2) -> void:
	var resistance_sources := _settlement_range_sources()
	var center_cell := Vector2i(floori(center.x), floori(center.y))
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var candidate: Vector2i = center_cell + Vector2i(direction) * (2 + posmod(int(tick / 10) + direction.x * 3 + direction.y * 5, 3))
		if candidate.x < 1 or candidate.y < 1 or candidate.x >= blueprint.width - 1 or candidate.y >= blueprint.height - 1:
			continue
		if blueprint.get_tile(candidate) == RegionGenerator.Tile.DEEP_WATER or _corruption_resistance_at(candidate, resistance_sources) > 0.0:
			continue
		corruption_cells[_cell_key(candidate)] = maxi(250, int(corruption_cells.get(_cell_key(candidate), 0)))
		return

func _spawn_monsters_if_due() -> void:
	if tick % 100 != 0 or monsters.size() >= 600:
		return
	var first_attack_day := int(mode_rules.get("first_attack_day", 2))
	var pressure := float(mode_rules.get("monster_rate", 1.0))
	if first_attack_day < 0 or pressure <= 0.0 or tick < first_attack_day * TICKS_PER_DAY:
		return
	var corruption_keys: Array = corruption_cells.keys()
	if corruption_keys.is_empty():
		return
	corruption_keys.sort()
	var types := ["headless", "small_slime", "slime", "blood_slime", "zombie", "skeleton", "spectre", "fire_elemental", "drone"]
	var count := clampi(ceili(pressure), 1, 4)
	for spawn_index in count:
		var spawn_cell := _cell_from_key(String(corruption_keys[rng.randi_range(0, corruption_keys.size() - 1)]))
		var monster_type: String = String(types[(tick / 100 + spawn_index) % types.size()])
		_spawn_monster_actor(StringName(monster_type), Vector2(float(spawn_cell.x) + 0.5, float(spawn_cell.y) + 0.5))
	_emit_event(&"monster_wave", {"count": count})

func _spawn_monster_actor(monster_type: StringName, position: Vector2) -> Dictionary:
	var actor := ContentRegistry.get_by_id(&"actors", monster_type)
	var combat: Dictionary = actor.get("combat", {})
	var monster := {
		"id": _next_id(), "definition_id": String(monster_type), "name": actor.get("name", String(monster_type).replace("_", " ").capitalize()),
		"x": position.x, "y": position.y, "target_x": position.x, "target_y": position.y,
		"health": int(combat.get("health", 300)), "max_health": int(combat.get("health", 300)),
		"damage": int(combat.get("damage", 6)), "damage_type": String(combat.get("damage_type", "regular")),
		"attack_reload": int(combat.get("attack_reload", 12)), "attack_cooldown": 0, "speed": float(combat.get("speed", 0.065)),
		"state": "spawning", "task_id": 0, "task_kind": "", "task_progress": 0,
		"path": [], "path_index": 0, "path_goal_x": -1, "path_goal_y": -1, "stuck_ticks": 0,
	}
	monsters.append(monster)
	return monster

func _apply_monster_hit(monster: Dictionary, target: Dictionary, target_kind: StringName) -> int:
	var damage_type := StringName(monster.get("damage_type", "regular"))
	var damage := int(monster.get("damage", 0))
	if target_kind == &"villager":
		damage = maxi(1, damage - _villager_armor_value(target, damage_type))
	target.health = maxi(0, int(target.health) - damage)
	var actor := ContentRegistry.get_by_id(&"actors", StringName(monster.definition_id))
	var combat: Dictionary = actor.get("combat", {})
	var status_id := String(combat.get("status", ""))
	if not status_id.is_empty() and int(target.health) > 0:
		var status_effects: Dictionary = target.get("status_effects", {})
		status_effects[status_id] = maxi(int(status_effects.get(status_id, 0)), int(combat.get("status_ticks", 120)))
		target.status_effects = status_effects
		if status_id == "burning" and target_kind == &"building":
			target.burning = true
	_emit_event(&"combat_hit", {"attacker_id": monster.id, "target_id": target.id, "target_kind": target_kind, "damage": damage, "damage_type": damage_type})
	return damage

func _villager_armor_value(villager: Dictionary, damage_type: StringName) -> int:
	var equipment: Dictionary = villager.get("equipment", {})
	var armor := 0
	for slot in ["body", "helmet", "shield"]:
		var item: Dictionary = equipment.get(slot, {})
		if item.is_empty():
			continue
		var definition := ContentRegistry.get_by_id(&"resources", StringName(item.get("id", "")))
		armor += int(definition.get("defense", 0))
		_damage_equipped_item(villager, slot, 1)
	if damage_type in [&"magic", &"fire", &"poison"]:
		return armor / 2
	return armor

func _damage_equipped_item(villager: Dictionary, slot: String, amount: int) -> void:
	var equipment: Dictionary = villager.get("equipment", {})
	var item: Dictionary = equipment.get(slot, {})
	if item.is_empty():
		return
	item.durability = maxi(0, int(item.get("durability", 1)) - amount)
	if int(item.durability) <= 0:
		equipment.erase(slot)
		ProgressionService.record(&"equipment.broken")
		_emit_event(&"equipment_broken", {"villager_id": villager.id, "slot": slot, "resource_id": item.get("id", "")})
	else:
		equipment[slot] = item
	villager.equipment = equipment

func _update_combat_statuses() -> void:
	if tick % 10 != 0:
		return
	for villager in villagers:
		_update_actor_status_effects(villager)
	for golem in golems:
		_update_actor_status_effects(golem)
	for building in buildings:
		_update_actor_status_effects(building)
		if int(building.get("reclaimed_ticks", 0)) > 0:
			building.reclaimed_ticks = maxi(0, int(building.reclaimed_ticks) - 10)
		if bool(building.get("burning", false)) and int(building.get("status_effects", {}).get("burning", 0)) <= 0:
			building.burning = false
		if int(building.get("health", 1)) <= 0 and not bool(building.get("destroyed", false)):
			building.destroyed = true
			if String(building.get("category", "")) == "walls":
				ProgressionService.record(&"walls.destroyed")
			_recalculate_settlement_support()
			_refresh_navigation_buildings()
			_emit_event(&"building_destroyed", {"building_id": building.id, "definition_id": building.definition_id, "cause": "status"})

func _update_actor_status_effects(actor: Dictionary) -> void:
	var status_effects: Dictionary = actor.get("status_effects", {})
	if status_effects.is_empty():
		return
	var finished: Array[String] = []
	for status_id in status_effects:
		status_effects[status_id] = maxi(0, int(status_effects[status_id]) - 10)
		match String(status_id):
			"burning": actor.health = maxi(0, int(actor.health) - 8)
			"infection": actor.health = maxi(0, int(actor.health) - 2)
		if int(status_effects[status_id]) <= 0:
			finished.append(String(status_id))
	for status_id in finished:
		status_effects.erase(status_id)
	actor.status_effects = status_effects

func _move_spectre_toward(monster: Dictionary, target: Vector2, step: float) -> bool:
	var position := Vector2(float(monster.x), float(monster.y))
	monster.target_x = target.x
	monster.target_y = target.y
	if position.distance_to(target) <= 0.72:
		return true
	var direction := target - position
	if direction.length_squared() > 0.0001:
		position += direction.normalized() * minf(step, direction.length())
	monster.x = clampf(position.x, 0.5, float(blueprint.width) - 0.5)
	monster.y = clampf(position.y, 0.5, float(blueprint.height) - 0.5)
	monster.state = "phasing"
	return false

func _apply_damage_to_monster(monster: Dictionary, damage: int, damage_type: StringName) -> int:
	var actor := ContentRegistry.get_by_id(&"actors", StringName(monster.definition_id))
	var resistances: Dictionary = actor.get("combat", {}).get("resistances", {})
	var resistance := clampf(float(resistances.get(String(damage_type), 0.0)), -0.9, 0.95)
	var applied := maxi(1, roundi(float(damage) * (1.0 - resistance))) if damage > 0 else 0
	monster.health = int(monster.health) - applied
	if applied > 0:
		monster.last_damage_type = String(damage_type)
		if damage_type in [&"ice", &"magic_ice"]:
			monster.cold_ticks = maxi(int(monster.get("cold_ticks", 0)), 120)
	return applied

func _monster_target(monster: Dictionary) -> Dictionary:
	var position := Vector2(float(monster.x), float(monster.y))
	if int(monster.get("attracted_ticks", 0)) > 0:
		monster.attracted_ticks = int(monster.attracted_ticks) - 1
		var attracted_building := _find_building(int(monster.get("attracted_building_id", 0)))
		if not attracted_building.is_empty() and not bool(attracted_building.get("destroyed", false)):
			return {"kind": "building", "id": int(attracted_building.id), "x": float(attracted_building.x) + float(attracted_building.width) * 0.5, "y": float(attracted_building.y) + float(attracted_building.height) * 0.5}
	var best: Dictionary = {}
	var best_distance := INF
	for building in buildings:
		if bool(building.get("destroyed", false)):
			continue
		var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
		var distance := position.distance_squared_to(center)
		if distance < best_distance:
			best_distance = distance
			best = {"kind": "building", "id": int(building.id), "x": center.x, "y": center.y}
	if not best.is_empty():
		return best
	for villager in villagers:
		if int(villager.health) <= 0:
			continue
		var villager_position := Vector2(float(villager.x), float(villager.y))
		var distance := position.distance_squared_to(villager_position)
		if distance < best_distance:
			best_distance = distance
			best = {"kind": "villager", "id": int(villager.id), "x": villager_position.x, "y": villager_position.y}
	for nomad in nomads:
		if int(nomad.health) <= 0:
			continue
		var nomad_position := Vector2(float(nomad.x), float(nomad.y))
		var distance := position.distance_squared_to(nomad_position)
		if distance < best_distance:
			best_distance = distance
			best = {"kind": "nomad", "id": int(nomad.id), "x": nomad_position.x, "y": nomad_position.y}
	for golem in golems:
		if int(golem.health) <= 0:
			continue
		var golem_position := Vector2(float(golem.x), float(golem.y))
		var distance := position.distance_squared_to(golem_position)
		if distance < best_distance:
			best_distance = distance
			best = {"kind": "golem", "id": int(golem.id), "x": golem_position.x, "y": golem_position.y}
	return best

func _update_towers() -> void:
	for building in buildings:
		var category := String(building.get("category", ""))
		var is_god_tower := category == "god_structure" and String(building.get("god_role", "")) == "tower"
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
		var embedded_tower: Dictionary = definition.get("embedded_tower", {})
		var is_embedded_tower := not embedded_tower.is_empty() and int(building.get("tier", 1)) >= int(embedded_tower.get("minimum_tier", 1))
		if not bool(building.completed) or bool(building.get("destroyed", false)) or (category != "towers" and not is_god_tower and not is_embedded_tower):
			continue
		var tower: Dictionary = building.get("tower", {}) if is_god_tower else (embedded_tower if is_embedded_tower else definition.get("tower", {}))
		if tower.is_empty():
			building.combat_state = "invalid_definition"
			continue
		building.combat_cooldown = maxi(0, int(building.get("combat_cooldown", 0)) - 1)
		if int(building.combat_cooldown) > 0:
			building.combat_state = "reloading"
			continue
		var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
		var tier_scale := 1.0 if is_embedded_tower else 1.0 + float(int(building.tier) - 1) * 0.08
		var tower_range := float(tower.get("range", 24.0)) * tier_scale
		if String(tower.role) == "repair_golem":
			var repair_target := _nearest_damaged_golem(center, tower_range)
			if repair_target.is_empty():
				building.combat_state = "idle"
				continue
			if not _consume_tower_payload(building, tower):
				continue
			var repair_amount := roundi(float(tower.get("repair", 100)) * (1.0 + float(int(building.tier) - 1) * 0.25))
			repair_target.health = mini(int(repair_target.max_health), int(repair_target.health) + repair_amount)
			building.combat_cooldown = maxi(1, int(tower.reload_ticks) - (int(building.tier) - 1))
			building.combat_state = "repairing"
			_emit_event(&"golem_repaired", {"building_id": building.id, "golem_id": repair_target.id, "amount": repair_amount})
			continue
		var targets := _tower_targets(center, tower_range, tower)
		if targets.is_empty():
			if String(tower.role) != "attract":
				var structure_target := _nearest_hostile_structure(center, tower_range)
				if not structure_target.is_empty() and _consume_tower_payload(building, tower):
					var structure_damage := roundi(float(tower.get("damage", 0)) * (1.0 + float(int(building.tier) - 1) * 0.25))
					_apply_damage_to_hostile_structure(structure_target, structure_damage, StringName(tower.get("damage_type", "regular")))
					building.combat_cooldown = maxi(1, int(tower.reload_ticks) - (int(building.tier) - 1))
					building.combat_state = "firing"
					_emit_event(&"tower_fired", {"building_id": building.id, "target_id": structure_target.id, "target_kind": "hostile_structure", "damage_type": tower.get("damage_type", "regular"), "target_count": 1})
					continue
			building.combat_state = "idle"
			continue
		if not _consume_tower_payload(building, tower):
			continue
		var target_count := mini(int(tower.get("targets", 1)), targets.size())
		var damage := roundi(float(tower.get("damage", 0)) * (1.0 + float(int(building.tier) - 1) * 0.25))
		for target_index in target_count:
			var target: Dictionary = targets[target_index]
			if String(tower.role) == "attract":
				target.attracted_building_id = int(building.id)
				target.attracted_ticks = maxi(int(target.get("attracted_ticks", 0)), 80 + int(building.tier) * 20)
			else:
				_apply_damage_to_monster(target, damage, StringName(tower.get("damage_type", "regular")))
		building.combat_cooldown = maxi(1, int(tower.reload_ticks) - (int(building.tier) - 1))
		building.combat_state = "attracting" if String(tower.role) == "attract" else "firing"
		_emit_event(&"tower_fired", {"building_id": building.id, "target_id": targets[0].id, "damage_type": tower.get("damage_type", "regular"), "target_count": target_count})

func _update_god_structures() -> void:
	var navigation_changed := false
	for building in buildings:
		if String(building.get("category", "")) != "god_structure":
			continue
		if bool(building.get("destroyed", false)) or int(building.get("health", 0)) <= 0:
			var was_destroyed := bool(building.get("destroyed", false))
			building.destroyed = true
			building.health = 0
			_release_god_structure_maintenance(building)
			if not was_destroyed:
				navigation_changed = true
				_emit_event(&"god_structure_destroyed", {"building_id": building.id, "definition_id": building.definition_id})
			continue
		building.operation_state = "maintained"
	if navigation_changed:
		_refresh_navigation_buildings()

func _tower_targets(center: Vector2, tower_range: float, tower: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for monster in monsters:
		if int(monster.health) > 0 and int(monster.get("charmed_ticks", 0)) <= 0 and center.distance_to(Vector2(float(monster.x), float(monster.y))) <= tower_range:
			result.append(monster)
	var priorities: Array = tower.get("priority", [])
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority := priorities.find(String(a.definition_id))
		var b_priority := priorities.find(String(b.definition_id))
		if a_priority < 0: a_priority = 999
		if b_priority < 0: b_priority = 999
		if a_priority != b_priority: return a_priority < b_priority
		var a_distance := center.distance_squared_to(Vector2(float(a.x), float(a.y)))
		var b_distance := center.distance_squared_to(Vector2(float(b.x), float(b.y)))
		if not is_equal_approx(a_distance, b_distance): return a_distance < b_distance
		return int(a.id) < int(b.id))
	return result

func _nearest_hostile_structure(center: Vector2, radius: float) -> Dictionary:
	var result: Dictionary = {}
	var best_distance := radius * radius
	for structure in hostile_structures:
		if bool(structure.get("destroyed", false)) or not bool(structure.get("completed", false)):
			continue
		var structure_center := Vector2(float(structure.x) + float(structure.width) * 0.5, float(structure.y) + float(structure.height) * 0.5)
		var distance := center.distance_squared_to(structure_center)
		if distance <= best_distance:
			best_distance = distance
			result = structure
	return result

func _apply_damage_to_hostile_structure(structure: Dictionary, damage: int, damage_type: StringName) -> bool:
	if structure.is_empty() or bool(structure.get("destroyed", false)):
		return false
	structure.health = maxi(0, int(structure.health) - maxi(0, damage))
	if int(structure.health) > 0:
		return false
	structure.destroyed = true
	structure.operation_state = "destroyed"
	_refresh_navigation_buildings()
	ProgressionService.record(&"combat.destroyed.corrupted_buildings")
	_emit_event(&"hostile_structure_destroyed", {"structure_id": structure.id, "definition_id": structure.definition_id, "damage_type": damage_type})
	return true

func _consume_tower_payload(building: Dictionary, tower: Dictionary) -> bool:
	var energy_cost := int(tower.get("energy_per_shot", 0))
	var ammo_id := String(tower.get("ammo", ""))
	if not ammo_id.is_empty() and String(building.get("ammo_resource", "")) != ammo_id:
		building.ammo_resource = ammo_id
		building.ammo_shots = 0
	var required_shots := int(tower.get("ammo_per_shot", 1))
	var needs_ammo_stack := not ammo_id.is_empty() and int(building.get("ammo_shots", 0)) < required_shots
	# Validate the whole payload before consuming either energy or ammunition.
	if energy_cost > 0 and int(resources.get("energy", 0)) < energy_cost:
		building.combat_state = "no_energy"
		return false
	if needs_ammo_stack:
		if int(resources.get(ammo_id, 0)) <= 0:
			building.combat_state = "no_ammo"
			return false
	if energy_cost > 0:
		consume_physical_resource(&"energy", energy_cost)
	if needs_ammo_stack:
		consume_physical_resource(StringName(ammo_id), 1)
		var ammo_definition := ContentRegistry.get_by_id(&"resources", StringName(ammo_id))
		building.ammo_shots = int(building.get("ammo_shots", 0)) + int(ammo_definition.get("shots", 1))
	if ammo_id.is_empty():
		return true
	building.ammo_shots = int(building.ammo_shots) - required_shots
	return true

func _nearest_damaged_golem(center: Vector2, tower_range: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := tower_range * tower_range
	for golem in golems:
		if int(golem.health) <= 0 or int(golem.health) >= int(golem.max_health):
			continue
		var distance := center.distance_squared_to(Vector2(float(golem.x), float(golem.y)))
		if distance <= best_distance:
			best_distance = distance
			best = golem
	return best

func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]

func _cell_from_key(key: String) -> Vector2i:
	var parts := key.split(":")
	return Vector2i(int(parts[0]), int(parts[1]))

func _update_influence() -> void:
	if tick % 10 != 0 or bool(mode_rules.get("unlimited_influence", false)):
		return
	var population_count := _villager_population_count()
	max_influence = population_count * (40 + roundi(ProgressionService.get_modifier(&"influence_per_villager")))
	influence = mini(maxi(0, max_influence - influence_reserved), influence + maxi(1, population_count / 8))

func _villager_population_count() -> int:
	return villagers.size() + (1 if String(held_entity.get("kind", "")) == "villager" else 0)

func _update_weather_and_events() -> void:
	if bool(mode_rules.get("weather", true)) and tick >= next_weather_tick:
		var weather_choices := [&"clear", &"rain", &"clear", &"wind"]
		if _season_for_day(tick / TICKS_PER_DAY + 1) == &"Winter":
			weather_choices = [&"clear", &"snow", &"snow", &"wind"]
		weather = weather_choices[rng.randi_range(0, weather_choices.size() - 1)]
		next_weather_tick = tick + rng.randi_range(300, 800)
		_emit_event(&"weather_changed", {"weather": weather})
	var season := _season_for_day(tick / TICKS_PER_DAY + 1)
	var base_temperature: int = int({&"Spring": 16, &"Summer": 28, &"Autumn": 13, &"Winter": -4}.get(season, 16))
	var phase := float(tick % TICKS_PER_DAY) / float(TICKS_PER_DAY)
	temperature_c = int(base_temperature) + roundi(sin((phase - 0.25) * TAU) * 6.0)
	if weather == &"rain": temperature_c -= 3
	elif weather == &"snow": temperature_c -= 6
	_set_frozen_water_navigation(season == &"Winter")
	if event_ticks_remaining > 0:
		event_ticks_remaining -= 1
		_apply_active_event()
		if event_ticks_remaining <= 0:
			_emit_event(&"event_ended", {"event_id": active_event})
			active_event = &""
	elif bool(mode_rules.get("disasters", true)) and tick >= next_event_tick:
		var event_choices := [&"meteor_shower", &"lightning_storm", &"hail", &"earthquake", &"blight", &"comet"]
		active_event = event_choices[rng.randi_range(0, event_choices.size() - 1)]
		event_ticks_remaining = 180 if active_event in [&"earthquake", &"comet"] else 320
		next_event_tick = tick + rng.randi_range(TICKS_PER_DAY * 2, TICKS_PER_DAY * 5)
		ProgressionService.record(&"events.started")
		ProgressionService.record(StringName("events.started.%s" % String(active_event)))
		_emit_event(&"event_started", {"event_id": active_event, "duration": event_ticks_remaining})
		AudioDirector.play_cue(&"warning")
	_update_lunar_event()

func _set_frozen_water_navigation(frozen: bool, announce: bool = true) -> void:
	if frozen == water_frozen:
		return
	water_frozen = frozen
	pathfinder.set_deep_water_frozen(frozen)
	hostile_pathfinder.set_deep_water_frozen(frozen)
	var actor_groups: Array = [villagers, nomads, animals, golems, monsters]
	for group_index in actor_groups.size():
		var group: Array = actor_groups[group_index]
		for actor_value in group:
			var actor: Dictionary = actor_value
			actor.path = []
			actor.path_index = 0
			actor.path_goal_x = -1
			actor.path_goal_y = -1
			if not frozen:
				var actor_cell := Vector2i(floori(float(actor.get("x", 0.0))), floori(float(actor.get("y", 0.0))))
				if blueprint.get_tile(actor_cell) == RegionGenerator.Tile.DEEP_WATER:
					var route_finder = hostile_pathfinder if group_index == 4 else pathfinder
					var shore: Vector2i = route_finder.nearest_walkable(actor_cell)
					if shore.x >= 0:
						actor.x = float(shore.x) + 0.5
						actor.y = float(shore.y) + 0.5
						actor.target_x = actor.x
						actor.target_y = actor.y
						actor.state = "escaped_thaw"
	if not announce:
		return
	var event_id: StringName = &"water_frozen" if frozen else &"water_thawed"
	ProgressionService.record(StringName("terrain.%s" % String(event_id)))
	_emit_event(event_id, {"season": String(_season_for_day(tick / TICKS_PER_DAY + 1))})
	messages.append("Deep water has frozen into traversable ice." if frozen else "The ice has thawed; travelers returned to shore.")
	if messages.size() > 8:
		messages.pop_front()

func _update_terrain_effects() -> void:
	if tick % 10 != 0:
		return
	var remove_keys: Array[String] = []
	for effect_key_value in terrain_effects.keys():
		var effect_key := String(effect_key_value)
		var effect: Dictionary = terrain_effects[effect_key]
		var kind := String(effect.get("kind", ""))
		if kind == "hole":
			# Dug terrain is an authoritative world change. It remains until a
			# Maintainer completes a Fill designation rather than expiring like
			# weather aftermath.
			continue
		effect.remaining_ticks = int(effect.get("remaining_ticks", 0)) - 10
		if kind == "fire":
			var fire_cell := _cell_from_key(effect_key)
			_damage_terrain_fire_occupants(fire_cell, maxi(1, roundi(float(effect.get("intensity", 1000)) / 250.0)))
			if weather in [&"rain", &"snow"]:
				effect.kind = "ash"
				effect.intensity = maxi(280, int(effect.get("intensity", 1000)) / 2)
				effect.remaining_ticks = 900
			elif int(effect.remaining_ticks) <= 0:
				effect.kind = "ash"
				effect.intensity = maxi(320, int(effect.get("intensity", 1000)) / 2)
				effect.remaining_ticks = 1200
			elif tick % 50 == 0:
				_spread_terrain_fire(fire_cell, int(effect.get("intensity", 1000)))
		elif kind == "flood" and int(effect.remaining_ticks) <= 0:
			effect.kind = "mud"
			effect.intensity = maxi(300, int(effect.get("intensity", 700)) - 180)
			effect.remaining_ticks = 700
		elif kind in ["mud", "ash", "illuminated"] and int(effect.remaining_ticks) <= 0:
			remove_keys.append(effect_key)
		terrain_effects[effect_key] = effect
	for effect_key in remove_keys:
		terrain_effects.erase(effect_key)
	if weather == &"rain" and tick % 40 == 0:
		_seed_rain_surface_effects()

func _set_terrain_effect(cell: Vector2i, kind: StringName, intensity: int = 1000, remaining_ticks: int = 600) -> bool:
	if blueprint == null or cell.x < 0 or cell.y < 0 or cell.x >= blueprint.width or cell.y >= blueprint.height:
		return false
	var family := _terrain_family_for_effects(blueprint.get_tile(cell))
	if family == &"water" or family == &"void":
		return false
	var key := _cell_key(cell)
	var existing: Dictionary = terrain_effects.get(key, {})
	if String(existing.get("kind", "")) == "fire" and kind != &"fire":
		return false
	if String(existing.get("kind", "")) == "hole" and kind != &"hole":
		return false
	terrain_effects[key] = {
		"kind": String(kind),
		"intensity": clampi(maxi(intensity, int(existing.get("intensity", 0))), 1, 1000),
		"remaining_ticks": maxi(remaining_ticks, int(existing.get("remaining_ticks", 0))),
	}
	return true

func _ignite_terrain(center: Vector2i, radius: float, intensity: int = 1000) -> int:
	var ignited := 0
	var radius_i := ceili(radius)
	for y in range(center.y - radius_i, center.y + radius_i + 1):
		for x in range(center.x - radius_i, center.x + radius_i + 1):
			var cell := Vector2i(x, y)
			if Vector2(cell).distance_to(Vector2(center)) > radius:
				continue
			var tile := blueprint.get_tile(cell) if blueprint != null else -1
			var family := _terrain_family_for_effects(tile)
			if family not in [&"ground", &"forest"]:
				continue
			if _set_terrain_effect(cell, &"fire", intensity, 420 + posmod(x * 17 + y * 31, 180)):
				ignited += 1
	return ignited

func _spread_terrain_fire(cell: Vector2i, intensity: int) -> void:
	var spread_hash := posmod(cell.x * cell.x * 1741 + cell.y * cell.y * 3253 + cell.x * cell.y * 953 + tick * 47 + blueprint.seed * 71, 104729)
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var candidate: Vector2i = cell + directions[spread_hash % directions.size()]
	var tile := blueprint.get_tile(candidate)
	var family := _terrain_family_for_effects(tile)
	if family == &"forest" or (family == &"ground" and spread_hash % 5 == 0):
		_set_terrain_effect(candidate, &"fire", maxi(380, intensity - 120), 360 + spread_hash % 180)

func _damage_terrain_fire_occupants(cell: Vector2i, damage: int) -> void:
	for building in buildings:
		if bool(building.get("destroyed", false)):
			continue
		if Rect2i(Vector2i(int(building.x), int(building.y)), Vector2i(int(building.width), int(building.height))).has_point(cell):
			building.health = maxi(0, int(building.health) - damage)
			building.burning = true
			var statuses: Dictionary = building.get("status_effects", {})
			statuses.burning = maxi(int(statuses.get("burning", 0)), 120)
			building.status_effects = statuses
	for resource_node in resource_nodes:
		if int(resource_node.get("x", -1)) == cell.x and int(resource_node.get("y", -1)) == cell.y and String(resource_node.get("id", "")) in ["wood", "raw_vegetables"]:
			resource_node.amount = maxi(0, int(resource_node.get("amount", 0)) - damage)

func _seed_rain_surface_effects() -> void:
	var sample_epoch := tick / 40
	for sample_index in 32:
		var sample_hash := posmod(sample_epoch * sample_epoch * 3571 + sample_index * sample_index * 2377 + sample_epoch * sample_index * 1877 + blueprint.seed * 97, 104729)
		var cell := Vector2i(posmod(sample_hash, blueprint.width), posmod(sample_hash / 257, blueprint.height))
		var tile := blueprint.get_tile(cell)
		if _terrain_family_for_effects(tile) != &"ground":
			continue
		var water_neighbor := false
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			if _terrain_family_for_effects(blueprint.get_tile(cell + direction)) == &"water":
				water_neighbor = true
				break
		if water_neighbor:
			_set_terrain_effect(cell, &"flood", 760, 260)
		elif tile in [RegionGenerator.Tile.FERTILE, RegionGenerator.Tile.MARSH] or sample_hash % 5 == 0:
			_set_terrain_effect(cell, &"mud", 520, 520)

func _terrain_family_for_effects(tile: int) -> StringName:
	match tile:
		RegionGenerator.Tile.DEEP_WATER: return &"water"
		RegionGenerator.Tile.FOREST_FLOOR: return &"forest"
		RegionGenerator.Tile.GRASS, RegionGenerator.Tile.FERTILE, RegionGenerator.Tile.SAND, RegionGenerator.Tile.MARSH: return &"ground"
		RegionGenerator.Tile.ROCKY, RegionGenerator.Tile.CRYSTAL_GROUND, RegionGenerator.Tile.CORRUPTION: return &"solid"
	return &"void"

func _update_lunar_event() -> void:
	if not active_event.is_empty() or tick % TICKS_PER_DAY != int(TICKS_PER_DAY * 0.78):
		return
	var day := tick / TICKS_PER_DAY + 1
	if day % 16 == 0:
		active_event = &"eclipse"
		event_ticks_remaining = 180
	elif day % 8 == 0:
		active_event = &"blood_moon"
		event_ticks_remaining = 260
	elif day % 4 == 0:
		active_event = &"full_moon"
		event_ticks_remaining = 260
	if not active_event.is_empty():
		ProgressionService.record(StringName("events.entered.%s" % String(active_event)))
		_emit_event(&"event_started", {"event_id": active_event, "duration": event_ticks_remaining})

func _apply_active_event() -> void:
	match String(active_event):
		"blood_moon":
			if tick % 80 == 0:
				_spawn_monsters_if_due()
		"hail":
			if tick % 20 == 0:
				for villager in villagers:
					villager.health = maxi(0, int(villager.health) - 1)
		"earthquake":
			if tick % 10 == 0:
				_damage_random_building(7)
		"lightning_storm":
			if tick % 45 == 0:
				_damage_random_building(55)
		"meteor_shower":
			if tick % 60 == 0:
				_damage_random_building(90)
		"comet":
			if event_ticks_remaining == 90:
				_damage_random_building(600)
		"blight":
			if tick % 20 == 0:
				consume_physical_resource(&"raw_vegetables", 1)

func _damage_random_building(damage: int) -> void:
	var valid: Array[Dictionary] = []
	for building in buildings:
		if bool(building.completed) and not bool(building.get("destroyed", false)):
			valid.append(building)
	if valid.is_empty():
		return
	var target: Dictionary = valid[rng.randi_range(0, valid.size() - 1)]
	target.health = maxi(0, int(target.health) - damage)
	if int(target.health) <= 0:
		target.destroyed = true
		_recalculate_settlement_support()

func _update_cullis_gate(building: Dictionary, definition: Dictionary) -> void:
	var cullis: Dictionary = definition.get("cullis", {})
	var instability := maxi(0, int(building.get("cullis_instability", 0)) - int(cullis.get("cool_rate", 1)))
	building.cullis_instability = instability
	building.operation_progress = instability
	var lightning_threshold := int(cullis.get("lightning_threshold", 240))
	var overload_threshold := int(cullis.get("overload_threshold", 480))
	if instability <= 0:
		building.operation_state = "stable"
	elif instability >= overload_threshold * 3 / 4:
		building.operation_state = "critical"
	elif instability >= lightning_threshold:
		building.operation_state = "unstable"
	else:
		building.operation_state = "cooling"

func _use_grab_hand(payload: Dictionary, definition: Dictionary) -> void:
	var cell := Vector2i(int(payload.get("cell_x", 0)), int(payload.get("cell_y", 0)))
	if held_entity.is_empty():
		var cost := int(definition.get("cost", 0))
		if not bool(mode_rules.get("unlimited_influence", false)) and influence < cost:
			_emit_event(&"command_rejected", {"reason": "insufficient_influence", "spell_id": "grab"})
			return
		if not _pick_up_with_hand(cell):
			if blueprint != null and blueprint.get_tile(cell) == RegionGenerator.Tile.GRASS:
				if not bool(mode_rules.get("unlimited_influence", false)):
					influence -= cost
				ProgressionService.record(&"spells.hand_touched_grass")
				ProgressionService.record(&"spells.cast.grab")
				_emit_event(&"hand_touched_grass", {"cell_x": cell.x, "cell_y": cell.y})
				_emit_event(&"spell_cast", {"spell_id": "grab", "cell_x": cell.x, "cell_y": cell.y, "radius": 1.6})
				AudioDirector.play_cue(&"hand_pickup")
				return
			_emit_event(&"command_rejected", {"reason": "nothing_to_grab", "spell_id": "grab"})
			return
		if not bool(mode_rules.get("unlimited_influence", false)):
			influence -= cost
		ProgressionService.record(&"spells.cast.grab")
		_emit_event(&"spell_cast", {"spell_id": "grab", "cell_x": cell.x, "cell_y": cell.y, "radius": 1.6})
		AudioDirector.play_cue(&"hand_pickup")
		return
	if not _drop_from_hand(cell):
		_emit_event(&"command_rejected", {"reason": "invalid_hand_drop", "spell_id": "grab"})
		return
	_emit_event(&"spell_cast", {"spell_id": "grab", "cell_x": cell.x, "cell_y": cell.y, "radius": 1.6})

func _update_held_hand() -> void:
	if held_entity.is_empty() or tick % 10 != 0 or bool(mode_rules.get("unlimited_influence", false)):
		return
	var definition := ContentRegistry.get_by_id(&"spells", &"grab")
	var hold_cost := maxi(0, int(definition.get("hold_cost_per_10_ticks", 1)))
	if hold_cost <= 0:
		return
	if influence >= hold_cost:
		influence -= hold_cost
		return
	var held_kind := String(held_entity.get("kind", ""))
	var origin := Vector2i(roundi(float(held_entity.get("origin_x", blueprint.starting_cell.x))), roundi(float(held_entity.get("origin_y", blueprint.starting_cell.y))))
	var route_finder = hostile_pathfinder if held_kind == "monster" else pathfinder
	var release_cell: Vector2i = route_finder.nearest_walkable(origin)
	if release_cell.x < 0:
		release_cell = blueprint.starting_cell
	if held_kind == "villager":
		ProgressionService.record(&"spells.hand_mana_forced_villager_drops")
	_drop_from_hand(release_cell)
	_emit_event(&"hand_forced_drop", {"kind": held_kind, "cell_x": release_cell.x, "cell_y": release_cell.y, "reason": "insufficient_influence"})

func _pick_up_with_hand(cell: Vector2i) -> bool:
	var target_position := Vector2(cell) + Vector2(0.5, 0.5)
	var best: Dictionary = {}
	var best_distance := 1.8 * 1.8
	for villager in villagers:
		if int(villager.get("health", 0)) <= 0:
			continue
		var distance := target_position.distance_squared_to(Vector2(float(villager.x), float(villager.y)))
		if distance <= best_distance:
			best_distance = distance
			best = {"kind": "villager", "payload": villager}
	for nomad in nomads:
		if int(nomad.get("health", 0)) <= 0:
			continue
		var distance := target_position.distance_squared_to(Vector2(float(nomad.x), float(nomad.y)))
		if distance <= best_distance:
			best_distance = distance
			best = {"kind": "nomad", "payload": nomad}
	for animal in animals:
		if int(animal.get("health", 0)) <= 0:
			continue
		var distance := target_position.distance_squared_to(Vector2(float(animal.x), float(animal.y)))
		if distance <= best_distance:
			best_distance = distance
			best = {"kind": "animal", "payload": animal}
	for golem in golems:
		if int(golem.get("health", 0)) <= 0:
			continue
		var distance := target_position.distance_squared_to(Vector2(float(golem.x), float(golem.y)))
		if distance <= best_distance:
			best_distance = distance
			best = {"kind": "golem", "payload": golem}
	for monster in monsters:
		if int(monster.get("health", 0)) <= 0:
			continue
		var distance := target_position.distance_squared_to(Vector2(float(monster.x), float(monster.y)))
		if distance <= best_distance:
			best_distance = distance
			best = {"kind": "monster", "payload": monster}
	for loose_item in loose_items:
		if int(loose_item.get("amount", 0)) <= 0:
			continue
		var distance := target_position.distance_squared_to(Vector2(float(loose_item.x) + 0.5, float(loose_item.y) + 0.5))
		if distance <= best_distance:
			best_distance = distance
			best = {"kind": "resource", "payload": loose_item}
	if best.is_empty():
		return false
	var kind := String(best.kind)
	var entity: Dictionary = best.payload
	if kind == "resource" and String(entity.get("resource_id", "")) == "lootbox":
		return _force_move_lootbox(entity)
	if kind == "villager":
		_release_villager_task(entity)
		villagers.erase(entity)
	elif kind == "nomad":
		nomads.erase(entity)
	elif kind == "animal":
		animals.erase(entity)
	elif kind == "golem":
		golems.erase(entity)
	elif kind == "monster":
		monsters.erase(entity)
	else:
		loose_items.erase(entity)
	held_entity = {
		"kind": kind,
		"payload": entity.duplicate(true),
		"picked_tick": tick,
		"origin_x": float(entity.get("x", 0.0)),
		"origin_y": float(entity.get("y", 0.0)),
	}
	if kind == "villager":
		ProgressionService.record(&"spells.grabbed.villagers")
	_emit_event(&"hand_picked_up", {"kind": kind, "entity_id": int(entity.get("id", entity.get("entity_id", 0))), "cell_x": cell.x, "cell_y": cell.y})
	return true

func _drop_from_hand(cell: Vector2i) -> bool:
	if held_entity.is_empty() or blueprint == null:
		return false
	var gate := _cullis_gate_at(cell)
	if not gate.is_empty():
		_sacrifice_held_entity(gate)
		return true
	var kind := String(held_entity.get("kind", ""))
	var held_payload: Dictionary = held_entity.get("payload", {})
	if kind == "resource" and String(held_payload.get("resource_id", "")) == "suspicious_key":
		var lootbox := _lootbox_at(cell)
		if not lootbox.is_empty() and _open_lootbox(lootbox, &"hand", 0, false):
			var remaining_keys := maxi(0, int(held_payload.get("amount", 1)) - 1)
			if remaining_keys > 0:
				drop_resource(&"suspicious_key", remaining_keys, cell)
			held_entity.clear()
			_emit_event(&"hand_dropped", {"kind": "resource", "entity_id": int(held_payload.get("id", held_payload.get("entity_id", 0))), "cell_x": cell.x, "cell_y": cell.y})
			AudioDirector.play_cue(&"hand_drop")
			return true
	if kind == "resource":
		var receiving_building := _building_at_cell(cell)
		var resource_id := String(held_payload.get("resource_id", ""))
		if _building_accepts_hand_resource(receiving_building, resource_id):
			var amount := maxi(0, int(held_payload.get("amount", 0)))
			var capacity := int(resource_caps.get(resource_id, int(resources.get(resource_id, 0)) + amount))
			var accepted := mini(amount, maxi(0, capacity - int(resources.get(resource_id, 0))))
			if accepted <= 0:
				return false
			add_physical_resource(StringName(resource_id), accepted, PhysicalInventory.LocationState.GROUND, cell)
			var overflow := amount - accepted
			if overflow > 0:
				var overflow_cell: Vector2i = pathfinder.nearest_walkable(cell)
				if overflow_cell.x >= 0:
					drop_resource(StringName(resource_id), overflow, overflow_cell)
			ProgressionService.record(&"spells.hand.resources_delivered_to_buildings", accepted)
			held_entity.clear()
			_emit_event(&"hand_resource_delivered", {"building_id": int(receiving_building.get("id", 0)), "resource_id": resource_id, "amount": accepted, "cell_x": cell.x, "cell_y": cell.y})
			AudioDirector.play_cue(&"hand_drop")
			return true
	if kind == "monster" and String(held_payload.get("definition_id", "")) == "fire_elemental" and blueprint.get_tile(cell) == RegionGenerator.Tile.DEEP_WATER:
		var drowned: Dictionary = held_payload.duplicate(true)
		drowned.x = float(cell.x) + 0.5
		drowned.y = float(cell.y) + 0.5
		drowned.health = 0
		drowned.last_damage_type = "water"
		drowned.state = "drowned"
		monsters.append(drowned)
		held_entity.clear()
		ProgressionService.record(&"combat.drowned.fire_elemental")
		_emit_event(&"monster_drowned", {"monster_id": int(drowned.get("id", 0)), "definition_id": "fire_elemental", "cell_x": cell.x, "cell_y": cell.y})
		AudioDirector.play_cue(&"hand_drop")
		return true
	var route_finder = hostile_pathfinder if kind == "monster" else pathfinder
	if not route_finder.is_walkable(cell):
		return false
	var entity: Dictionary = held_entity.get("payload", {}).duplicate(true)
	entity.x = float(cell.x) + 0.5
	entity.y = float(cell.y) + 0.5
	entity.target_x = entity.x
	entity.target_y = entity.y
	if kind != "resource":
		entity.path = []
		entity.path_index = 0
		entity.path_goal_x = -1
		entity.path_goal_y = -1
		entity.stuck_ticks = 0
	match kind:
		"villager":
			entity.state = "recovering"
			villagers.append(entity)
			if corruption_cells.has(_cell_key(cell)) or not _nearest_monster(Vector2(cell) + Vector2(0.5, 0.5), 8.0).is_empty():
				ProgressionService.record(&"spells.hand_dangerous_villager_drops")
		"nomad":
			entity.state = "traveling_to_settlement"
			entity.population_state = "nomad"
			nomads.append(entity)
		"animal":
			entity.state = "wandering"
			animals.append(entity)
		"golem":
			entity.state = "moving"
			golems.append(entity)
		"monster":
			entity.state = "hunting"
			monsters.append(entity)
		"resource":
			entity.x = cell.x
			entity.y = cell.y
			loose_items.append(entity)
		_:
			return false
	var dropped_kind := kind
	var dropped_id := int(entity.get("id", entity.get("entity_id", 0)))
	held_entity.clear()
	_emit_event(&"hand_dropped", {"kind": dropped_kind, "entity_id": dropped_id, "cell_x": cell.x, "cell_y": cell.y})
	AudioDirector.play_cue(&"hand_drop")
	return true

func _building_accepts_hand_resource(building: Dictionary, resource_id: String) -> bool:
	if building.is_empty() or not bool(building.get("completed", false)) or bool(building.get("destroyed", false)) or not resources.has(resource_id):
		return false
	var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.get("definition_id", "")))
	if String(definition.get("category", "")) == "storage" or String(definition.get("id", "")) == "camp":
		return true
	if definition.get("storage", {}).has(resource_id) or definition.get("storage_per_tier", {}).has(resource_id):
		return true
	for recipe in ContentRegistry.get_all(&"recipes"):
		if String(recipe.get("building", "")) == String(building.get("definition_id", "")) and recipe.get("inputs", {}).has(resource_id):
			return true
	return false

func _cullis_gate_at(cell: Vector2i) -> Dictionary:
	for building in buildings:
		if String(building.get("definition_id", "")) != "cullis_gate" or not bool(building.get("completed", false)) or bool(building.get("destroyed", false)):
			continue
		if Rect2i(Vector2i(int(building.x), int(building.y)), Vector2i(int(building.width), int(building.height))).has_point(cell):
			return building
	return {}

func _cullis_essence_yield(kind: String, entity: Dictionary) -> int:
	var level := maxi(1, int(entity.get("level", 1)))
	match kind:
		"villager", "nomad":
			return (6 if String(entity.get("age_stage", "adult")) == "child" else 10) + (level - 1) * 2
		"monster":
			var monster_type := String(entity.get("definition_id", ""))
			var base := 8 if monster_type == "spectre" else (10 if monster_type == "fire_elemental" else 3)
			return base + (level - 1) * 2
		"animal":
			var animal_type := String(entity.get("definition_id", ""))
			return int({"doofy_doggo": 12, "doggo": 7, "beefalo": 6, "entler": 5, "rous": 4, "clucker": 3}.get(animal_type, 3))
		"golem":
			return maxi(4, int(entity.get("maintenance", 0)) / 60 + int(entity.get("max_health", entity.get("health", 400))) / 300)
		"resource":
			return maxi(1, ceili(float(entity.get("amount", 1)) / 8.0))
	return 1

func _sacrifice_held_entity(gate: Dictionary) -> void:
	var kind := String(held_entity.get("kind", ""))
	var entity: Dictionary = held_entity.get("payload", {})
	var definition := ContentRegistry.get_by_id(&"buildings", &"cullis_gate")
	var cullis: Dictionary = definition.get("cullis", {})
	var essence_yield := _cullis_essence_yield(kind, entity)
	add_physical_resource_capped(&"essence", essence_yield, Vector2i(int(gate.x), int(gate.y)))
	var previous_instability := int(gate.get("cullis_instability", 0))
	var instability_gain := int(cullis.get("instability_base", 45)) + essence_yield * int(cullis.get("instability_per_essence", 18))
	var instability := previous_instability + instability_gain
	gate.cullis_instability = instability
	gate.operation_progress = instability
	gate.operation_state = "critical"
	var subject_id := String(entity.get("definition_id", entity.get("species", entity.get("resource_id", kind))))
	ProgressionService.record(&"cullis.sacrifices")
	ProgressionService.record(StringName("cullis.sacrificed.%s" % subject_id))
	if kind in ["villager", "nomad"]:
		ProgressionService.record(StringName("cullis.sacrificed.%s" % String(entity.get("age_stage", "adult"))))
		if kind == "villager":
			_assign_jobs()
	elif kind == "golem" and bool(entity.get("summoned", false)):
		influence_reserved = maxi(0, influence_reserved - int(entity.get("maintenance", 0)))
	held_entity.clear()
	_emit_event(&"cullis_sacrifice", {"building_id": int(gate.id), "kind": kind, "subject_id": subject_id, "essence": essence_yield, "instability": instability})
	AudioDirector.play_cue(&"cullis_sacrifice")
	var lightning_threshold := int(cullis.get("lightning_threshold", 240))
	var strikes := instability / lightning_threshold - previous_instability / lightning_threshold
	if strikes > 0:
		gate.health = maxi(0, int(gate.health) - strikes * int(cullis.get("lightning_damage", 180)))
		_emit_event(&"cullis_lightning", {"building_id": int(gate.id), "strikes": strikes, "health": int(gate.health), "instability": instability})
		AudioDirector.play_cue(&"cullis_lightning")
	if instability >= int(cullis.get("overload_threshold", 480)) or int(gate.health) <= 0:
		_overload_cullis_gate(gate, cullis)

func _overload_cullis_gate(gate: Dictionary, cullis: Dictionary) -> void:
	var center := Vector2(float(gate.x) + float(gate.width) * 0.5, float(gate.y) + float(gate.height) * 0.5)
	var radius := float(cullis.get("explosion_radius", 8))
	var base_damage := int(cullis.get("explosion_damage", 650))
	gate.health = 0
	gate.destroyed = true
	gate.operation_state = "overloaded"
	for building in buildings:
		if building == gate or bool(building.get("destroyed", false)):
			continue
		var building_center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
		var distance := center.distance_to(building_center)
		if distance > radius:
			continue
		building.health = maxi(0, int(building.health) - roundi(float(base_damage) * (1.0 - distance / (radius + 1.0))))
	for actor_group in [villagers, nomads, animals, golems, monsters]:
		for actor in actor_group:
			var distance := center.distance_to(Vector2(float(actor.x), float(actor.y)))
			if distance <= radius:
				actor.health = maxi(0, int(actor.health) - roundi(float(base_damage) * (1.0 - distance / (radius + 1.0))))
	for offset in [Vector2i.ZERO, Vector2i(-2, 0), Vector2i(2, 1), Vector2i(0, -2), Vector2i(1, 3)]:
		_set_terrain_effect(Vector2i(floori(center.x), floori(center.y)) + offset, &"hole", 1000, -1)
	_recalculate_settlement_support()
	_refresh_navigation_buildings()
	ProgressionService.record(&"cullis.overloads")
	_emit_event(&"cullis_overloaded", {"building_id": int(gate.id), "cell_x": floori(center.x), "cell_y": floori(center.y), "radius": radius, "damage": base_damage})
	_emit_event(&"building_destroyed", {"building_id": int(gate.id), "definition_id": "cullis_gate", "cause": "cullis_overload"})
	AudioDirector.play_cue(&"cullis_overload")

func _cast_spell(payload: Dictionary) -> void:
	var spell_id := StringName(payload.get("spell_id", ""))
	var definition := ContentRegistry.get_by_id(&"spells", spell_id)
	if definition.is_empty():
		_emit_event(&"command_rejected", {"reason": "unknown_spell", "spell_id": spell_id})
		return
	if spell_id == &"grab":
		_use_grab_hand(payload, definition)
		return
	var cell := Vector2i(int(payload.get("cell_x", 0)), int(payload.get("cell_y", 0)))
	if spell_id in [&"god_wall", &"god_tower"] and not _god_structure_placement_valid(cell, definition):
		_emit_event(&"command_rejected", {"reason": "invalid_god_structure_placement", "spell_id": spell_id, "cell_x": cell.x, "cell_y": cell.y})
		return
	var cost := int(definition.get("cost", 0))
	if spell_id == &"god_wall":
		cost = maxi(0, roundi(float(cost) * (1.0 + ProgressionService.get_modifier(&"god_wall_cost"))))
	if not bool(mode_rules.get("unlimited_influence", false)) and influence < cost:
		_emit_event(&"command_rejected", {"reason": "insufficient_influence", "spell_id": spell_id})
		return
	var maintenance := int(definition.get("maintenance", 0)) if spell_id in [&"summon_labor_golem", &"summon_holy_golem", &"god_wall", &"god_tower"] else 0
	if not bool(mode_rules.get("unlimited_influence", false)) and maintenance > 0 and max_influence - influence_reserved < maintenance:
		_emit_event(&"command_rejected", {"reason": "insufficient_maintenance_capacity", "spell_id": spell_id})
		return
	if not bool(mode_rules.get("unlimited_influence", false)):
		influence -= cost
	var radius := float(definition.get("radius", _spell_radius(spell_id)))
	if spell_id == &"illuminate":
		radius += ProgressionService.get_modifier(&"illuminate_radius")
	if spell_id == &"lightning_bolt":
		var lightning_rod := _lightning_rod_for_target(cell)
		if not lightning_rod.is_empty():
			var requested_cell := cell
			cell = Vector2i(int(lightning_rod.x) + int(lightning_rod.width) / 2, int(lightning_rod.y) + int(lightning_rod.height) / 2)
			var rod_definition := ContentRegistry.get_by_id(&"buildings", &"lightning_rod")
			lightning_rod.lightning_cooldown_until_tick = tick + int(rod_definition.get("lightning_rod", {}).get("cooldown_ticks", 80))
			lightning_rod.operation_state = "conducting"
			ProgressionService.record(&"spells.lightning_bolt.misdirected_by_rod")
			_emit_event(&"lightning_bolt_misdirected", {"building_id": int(lightning_rod.id), "requested_x": requested_cell.x, "requested_y": requested_cell.y, "cell_x": cell.x, "cell_y": cell.y})
	match String(spell_id):
		"healing_aura", "regenerate", "divine_blessing":
			var blessed_women := 0
			for villager in villagers:
				if Vector2(float(villager.x), float(villager.y)).distance_to(Vector2(cell)) <= radius:
					villager.health = mini(1000, int(villager.health) + (500 if spell_id == &"healing_aura" else 240))
					villager.faith = mini(1000, int(villager.faith) + 80)
					if spell_id == &"divine_blessing" and String(villager.get("sex", "")) == "female":
						blessed_women += 1
			if blessed_women > 0:
				ProgressionService.record(&"spells.blessed.women", blessed_women)
		"harvest":
			for resource_node in resource_nodes:
				if Vector2(float(resource_node.x), float(resource_node.y)).distance_to(Vector2(cell)) <= radius and int(resource_node.amount) > 0:
					var amount := mini(12, int(resource_node.amount))
					resource_node.amount = int(resource_node.amount) - amount
					add_physical_resource_capped(StringName(resource_node.id), amount, cell)
		"mend":
			for building in buildings:
				var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
				if center.distance_to(Vector2(cell)) <= radius:
					building.health = mini(int(building.max_health), int(building.health) + 800)
					building["burning"] = false
					var building_statuses: Dictionary = building.get("status_effects", {})
					building_statuses.erase("burning")
					building.status_effects = building_statuses
		"banish":
			for monster in monsters:
				if Vector2(float(monster.x), float(monster.y)).distance_to(Vector2(cell)) <= radius:
					monster.health = 0
		"charm":
			_charm_monsters(cell, radius, int(definition.get("duration_ticks", 360)))
		"god_wall", "god_tower":
			_spawn_god_structure(spell_id, cell, definition, maintenance)
		"cold_aura":
			_apply_cold_aura(cell, radius, int(definition.get("damage", 180)), int(definition.get("duration_ticks", 240)))
		"earthquake":
			_cast_earthquake(cell, radius, definition)
		"lightning_bolt":
			_damage_monsters_in_radius(cell, radius, 650, &"electric")
			var lightning_result := _damage_villagers_in_radius(cell, radius, 650, &"electric", &"lightning_bolt")
			if int(lightning_result.kills) > 0:
				ProgressionService.record(&"spells.lightning_bolt.villager_kills", int(lightning_result.kills))
		"magic_bolts":
			_damage_monsters_in_radius(cell, radius, 280, &"magic")
		"meteor":
			_damage_monsters_in_radius(cell, radius, 1200, &"magic_fire")
			var meteor_result := _damage_villagers_in_radius(cell, radius, 720, &"magic_fire", &"meteor")
			if int(meteor_result.hits) > 0:
				ProgressionService.record(&"spells.meteor_or_comet.villager_hits", int(meteor_result.hits))
			_ignite_terrain(cell, radius * 0.72, 1000)
		"comet":
			_damage_monsters_in_radius(cell, radius, 2400, &"magic_ice")
			var comet_result := _damage_villagers_in_radius(cell, radius, 1100, &"magic_ice", &"comet")
			if int(comet_result.hits) > 0:
				ProgressionService.record(&"spells.meteor_or_comet.villager_hits", int(comet_result.hits))
			if _town_center_in_radius(cell, radius):
				ProgressionService.record(&"spells.comet.hit_town_center")
		"flame":
			_ignite_terrain(cell, radius, 920)
		"construct":
			for building in buildings:
				var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
				if not bool(building.completed) and center.distance_to(Vector2(cell)) <= radius:
					building.progress = building.build_time
		"conjure_material":
			var resource_id := String(payload.get("resource_id", "wood"))
			if resources.has(resource_id):
				add_physical_resource_capped(StringName(resource_id), 16, cell)
		"conjure_essence":
			add_physical_resource_capped(&"essence", 3, cell)
		"resurrect":
			_resurrect_nearest_ghost(cell, radius)
		"motivate_land":
			_motivate_land(cell, radius)
		"holy_wood", "holy_potatoes":
			_add_spell_resource_node(spell_id, cell)
		"dissolve":
			var dissolved_cells := 0
			for corruption_key in corruption_cells.keys():
				var corruption_cell := _cell_from_key(String(corruption_key))
				if Vector2(corruption_cell).distance_to(Vector2(cell)) <= radius:
					corruption_cells.erase(corruption_key)
					dissolved_cells += 1
			if dissolved_cells > 0:
				ProgressionService.record(&"spells.dissolved.corruption_cells", dissolved_cells)
			var dissolved_bodies := _dissolve_bodies(cell, radius)
			if dissolved_bodies > 0:
				ProgressionService.record(&"spells.dissolved.bodies", dissolved_bodies)
			_damage_hostile_structures_in_radius(cell, radius, 450, &"magic")
		"summon_labor_golem":
			if not bool(mode_rules.get("unlimited_influence", false)):
				influence_reserved += maintenance
			_spawn_golem(&"labor_golem", Vector2(cell) + Vector2(0.5, 0.5), 0, {"health": 850, "damage": 28, "attack_reload": 16, "speed": 0.085}, true, maintenance)
			ProgressionService.record(&"golems.summoned.labor_golem")
		"summon_holy_golem":
			if not bool(mode_rules.get("unlimited_influence", false)):
				influence_reserved += maintenance
			_spawn_golem(&"holy_golem", Vector2(cell) + Vector2(0.5, 0.5), 0, {"health": 1600, "damage": 95, "attack_reload": 12, "speed": 0.08}, true, maintenance)
			ProgressionService.record(&"golems.summoned.holy_golem")
		"dispel_golem":
			_dispel_nearest_golem(cell, radius)
		"dispel_god_structure":
			_dispel_nearest_god_structure(cell, radius)
		"illuminate":
			_illuminate_land(cell, radius, int(definition.get("duration_ticks", 900)))
			var day_phase := float(tick % TICKS_PER_DAY) / float(TICKS_PER_DAY)
			if day_phase < 0.20 or day_phase >= 0.75:
				ProgressionService.record(&"spells.illuminate_at_night")
		"recall":
			_recall_nomads(cell, radius)
		"storm":
			_cast_storm(cell, definition)
	_grow_magic_flowers(cell, clampi(1 + cost / 120, 1, 4))
	_make_villagers_react_to_divine_action(cell, maxf(radius + 6.0, 10.0), spell_id)
	ProgressionService.record(StringName("spells.cast.%s" % String(spell_id)))
	_emit_event(&"spell_cast", {"spell_id": spell_id, "cell_x": cell.x, "cell_y": cell.y, "radius": radius})

func _god_structure_placement_valid(cell: Vector2i, definition: Dictionary) -> bool:
	if blueprint == null:
		return false
	var footprint_data: Array = definition.get("footprint", [1, 1])
	var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
	return blueprint.is_buildable(cell, footprint) and not _footprint_overlaps(cell, footprint)

func _lightning_rod_for_target(target_cell: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	for building in buildings:
		if String(building.get("definition_id", "")) != "lightning_rod" or not bool(building.get("completed", false)) or bool(building.get("destroyed", false)):
			continue
		if tick < int(building.get("lightning_cooldown_until_tick", 0)):
			continue
		var definition := ContentRegistry.get_by_id(&"buildings", &"lightning_rod")
		var rod_range := float(definition.get("lightning_rod", {}).get("range", 28)) * (1.0 + float(int(building.get("tier", 1)) - 1) * 0.12)
		var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
		var distance := center.distance_to(Vector2(target_cell) + Vector2(0.5, 0.5))
		if distance <= rod_range and distance < best_distance:
			best_distance = distance
			best = building
	return best

func _spawn_god_structure(spell_id: StringName, cell: Vector2i, definition: Dictionary, maintenance: int) -> Dictionary:
	if not _god_structure_placement_valid(cell, definition):
		return {}
	var footprint_data: Array = definition.get("footprint", [1, 1])
	var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
	var maximum_health := int(definition.get("health", 1200))
	var maintenance_counted := not bool(mode_rules.get("unlimited_influence", false)) and maintenance > 0
	var structure: Dictionary = {
		"id": _next_id(), "definition_id": String(spell_id), "name": definition.get("name", String(spell_id).replace("_", " ").capitalize()),
		"category": "god_structure", "god_role": "tower" if spell_id == &"god_tower" else "wall",
		"x": cell.x, "y": cell.y, "width": footprint.x, "height": footprint.y,
		"tier": 1, "progress": 1, "build_time": 1, "completed": true,
		"health": maximum_health, "max_health": maximum_health, "operation_progress": 0,
		"combat_cooldown": 0, "combat_state": "idle", "operation_state": "maintained",
		"maintenance": maintenance, "maintenance_counted": maintenance_counted,
		"tower": definition.get("tower", {}).duplicate(true),
		"repair_designated": false, "dismantle_designated": false, "repair_batch_remaining": 0, "service_state": "none",
		"destroyed": false, "burning": false, "status_effects": {}, "ownership": "divine", "visual_state": "divine",
		"abandoned": false, "corrupted": false, "reclaimed_ticks": 0, "stored_resources": {}, "storage_caps": {},
	}
	if maintenance_counted:
		influence_reserved += maintenance
	buildings.append(structure)
	_refresh_navigation_buildings()
	ProgressionService.record(StringName("god_structures.summoned.%s" % String(spell_id)))
	_emit_event(&"god_structure_summoned", {"building_id": structure.id, "definition_id": spell_id, "cell_x": cell.x, "cell_y": cell.y, "maintenance": maintenance})
	return structure

func _release_god_structure_maintenance(structure: Dictionary) -> void:
	if not bool(structure.get("maintenance_counted", false)):
		return
	influence_reserved = maxi(0, influence_reserved - int(structure.get("maintenance", 0)))
	structure.maintenance_counted = false

func _dispel_nearest_god_structure(cell: Vector2i, radius: float) -> bool:
	var best: Dictionary = {}
	var best_distance := radius
	for building in buildings:
		if String(building.get("category", "")) != "god_structure" or bool(building.get("destroyed", false)):
			continue
		var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
		var distance := center.distance_to(Vector2(cell) + Vector2(0.5, 0.5))
		if distance <= best_distance:
			best_distance = distance
			best = building
	if best.is_empty():
		return false
	_release_god_structure_maintenance(best)
	buildings.erase(best)
	_refresh_navigation_buildings()
	ProgressionService.record(&"spells.dispelled.golem_or_building")
	_emit_event(&"god_structure_dispelled", {"building_id": best.id, "definition_id": best.definition_id})
	return true

func _charm_monsters(cell: Vector2i, radius: float, duration_ticks: int) -> int:
	var affected := 0
	for monster in monsters:
		if int(monster.get("health", 0)) <= 0 or Vector2(float(monster.x), float(monster.y)).distance_to(Vector2(cell) + Vector2(0.5, 0.5)) > radius:
			continue
		monster.charmed_ticks = maxi(int(monster.get("charmed_ticks", 0)), duration_ticks)
		monster.attracted_ticks = 0
		monster.erase("attracted_building_id")
		monster.path = []
		monster.path_index = 0
		monster.path_goal_x = -1
		monster.path_goal_y = -1
		monster.state = "charmed_guarding"
		affected += 1
	if affected > 0:
		ProgressionService.record(&"spells.charmed.monsters", affected)
		_emit_event(&"monsters_charmed", {"count": affected, "cell_x": cell.x, "cell_y": cell.y, "duration": duration_ticks})
	return affected

func _apply_cold_aura(cell: Vector2i, radius: float, damage: int, duration_ticks: int) -> int:
	var affected := 0
	for monster in monsters:
		if int(monster.get("health", 0)) <= 0 or Vector2(float(monster.x), float(monster.y)).distance_to(Vector2(cell) + Vector2(0.5, 0.5)) > radius:
			continue
		_apply_damage_to_monster(monster, damage, &"magic_ice")
		monster.cold_ticks = maxi(int(monster.get("cold_ticks", 0)), duration_ticks)
		monster.state = "chilled"
		affected += 1
	if affected > 0:
		ProgressionService.record(&"spells.chilled.monsters", affected)
		_emit_event(&"monsters_chilled", {"count": affected, "cell_x": cell.x, "cell_y": cell.y, "duration": duration_ticks})
	return affected

func _cast_earthquake(cell: Vector2i, radius: float, definition: Dictionary) -> void:
	var monster_damage := int(definition.get("monster_damage", 850))
	var building_damage := int(definition.get("building_damage", 260))
	_damage_monsters_in_radius(cell, radius, monster_damage, &"crushing")
	var destroyed_any := false
	for building in buildings:
		if bool(building.get("destroyed", false)):
			continue
		var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
		var distance := center.distance_to(Vector2(cell) + Vector2(0.5, 0.5))
		if distance > radius:
			continue
		var applied := maxi(1, roundi(float(building_damage) * (1.0 - distance / (radius + 1.0))))
		building.health = maxi(0, int(building.health) - applied)
		if int(building.health) <= 0:
			building.destroyed = true
			destroyed_any = true
	var hole_count := maxi(1, int(definition.get("hole_count", 7)))
	for index in hole_count:
		var angle := TAU * float(index) / float(hole_count) + float(posmod(blueprint.seed + tick, 97)) / 97.0
		var distance := radius * (0.25 + 0.65 * float((index * 37) % hole_count) / float(maxi(1, hole_count - 1)))
		var hole_cell := cell + Vector2i(roundi(cos(angle) * distance), roundi(sin(angle) * distance))
		_set_terrain_effect(hole_cell, &"hole", 1000, -1)
	if destroyed_any:
		_recalculate_settlement_support()
		_refresh_navigation_buildings()
	ProgressionService.record(&"spells.earthquake.cells", hole_count)
	if active_event == &"blood_moon":
		ProgressionService.record(&"events.earthquake_during_blood_moon")
	_emit_event(&"spell_earthquake", {"cell_x": cell.x, "cell_y": cell.y, "radius": radius, "holes": hole_count})

func _damage_villagers_in_radius(cell: Vector2i, radius: float, damage: int, damage_type: StringName, source_spell: StringName) -> Dictionary:
	var hits := 0
	var kills := 0
	var center := Vector2(cell) + Vector2(0.5, 0.5)
	for villager in villagers:
		if int(villager.get("health", 0)) <= 0 or Vector2(float(villager.x), float(villager.y)).distance_to(center) > radius:
			continue
		hits += 1
		var was_alive := int(villager.health) > 0
		villager.health = maxi(0, int(villager.health) - damage)
		villager.last_damage_type = String(damage_type)
		villager.last_damage_source = String(source_spell)
		var status_effects: Dictionary = villager.get("status_effects", {})
		if damage_type in [&"electric", &"magic_electric"]:
			status_effects.electrified = maxi(int(status_effects.get("electrified", 0)), 90)
			villager.status_effects = status_effects
		elif damage_type in [&"magic_fire", &"fire"]:
			status_effects.burning = maxi(int(status_effects.get("burning", 0)), 120)
			villager.status_effects = status_effects
		if was_alive and int(villager.health) <= 0:
			kills += 1
		_emit_event(&"villager_hit_by_spell", {"villager_id": int(villager.get("id", 0)), "spell_id": source_spell, "damage": damage, "damage_type": damage_type, "killed": int(villager.health) <= 0})
	return {"hits": hits, "kills": kills}

func _town_center_in_radius(cell: Vector2i, radius: float) -> bool:
	var center := Vector2(cell) + Vector2(0.5, 0.5)
	for building in buildings:
		if String(building.get("definition_id", "")) != "camp" or bool(building.get("destroyed", false)):
			continue
		var building_center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
		if building_center.distance_to(center) <= radius:
			return true
	return false

func _dissolve_bodies(cell: Vector2i, radius: float) -> int:
	var dissolved := 0
	var center := Vector2(cell) + Vector2(0.5, 0.5)
	for index in range(villagers.size() - 1, -1, -1):
		var villager: Dictionary = villagers[index]
		if int(villager.get("health", 0)) > 0 or Vector2(float(villager.x), float(villager.y)).distance_to(center) > radius:
			continue
		villagers.remove_at(index)
		dissolved += 1
	if dissolved > 0:
		_assign_jobs()
		_recalculate_settlement_support()
		_emit_event(&"bodies_dissolved", {"count": dissolved, "cell_x": cell.x, "cell_y": cell.y, "radius": radius})
	return dissolved

func _grow_magic_flowers(cell: Vector2i, requested: int) -> int:
	if blueprint == null or requested <= 0:
		return 0
	var generated := 0
	for attempt in range(requested * 5):
		if generated >= requested:
			break
		var hash := posmod((cell.x + attempt * 11) * 92821 + (cell.y - attempt * 7) * 68917 + tick * 131 + blueprint.seed * 17, 104729)
		var angle := TAU * float(hash % 360) / 360.0
		var distance := 2.0 + float((hash / 17) % 7)
		var flower_cell := cell + Vector2i(roundi(cos(angle) * distance), roundi(sin(angle) * distance))
		if flower_cell.x < 1 or flower_cell.y < 1 or flower_cell.x >= blueprint.width - 1 or flower_cell.y >= blueprint.height - 1:
			continue
		if blueprint.get_tile(flower_cell) not in [RegionGenerator.Tile.GRASS, RegionGenerator.Tile.FERTILE, RegionGenerator.Tile.MARSH]:
			continue
		var occupied := false
		for node in resource_nodes:
			if String(node.get("id", "")) == "flower" and int(node.get("x", -1)) == flower_cell.x and int(node.get("y", -1)) == flower_cell.y:
				occupied = true
				break
		if occupied:
			continue
		resource_nodes.append({"entity_id": _next_id(), "id": "flower", "x": flower_cell.x, "y": flower_cell.y, "amount": 1, "initial_amount": 1, "variant": hash % 4, "magical": true})
		generated += 1
	if generated > 0:
		ProgressionService.record(&"world.magic_flowers_generated", generated)
		_emit_event(&"magic_flowers_grown", {"count": generated, "cell_x": cell.x, "cell_y": cell.y})
	return generated

func _make_villagers_react_to_divine_action(cell: Vector2i, radius: float, spell_id: StringName) -> int:
	var reactions := 0
	var center := Vector2(cell) + Vector2(0.5, 0.5)
	for villager in villagers:
		if int(villager.get("health", 0)) <= 0 or Vector2(float(villager.x), float(villager.y)).distance_to(center) > radius:
			continue
		villager.divine_reaction_until_tick = tick + 45
		villager.last_divine_action = String(spell_id)
		reactions += 1
	if reactions > 0:
		ProgressionService.record(&"population.divine_reactions", reactions)
		_emit_event(&"villagers_reacted_to_divine_action", {"count": reactions, "spell_id": spell_id, "cell_x": cell.x, "cell_y": cell.y})
	return reactions

func _illuminate_land(cell: Vector2i, radius: float, duration_ticks: int) -> int:
	var lit_cells := 0
	var radius_i := ceili(radius)
	for y in range(cell.y - radius_i, cell.y + radius_i + 1):
		for x in range(cell.x - radius_i, cell.x + radius_i + 1):
			var light_cell := Vector2i(x, y)
			if Vector2(light_cell).distance_to(Vector2(cell)) > radius:
				continue
			if _set_terrain_effect(light_cell, &"illuminated", 720, duration_ticks):
				lit_cells += 1
	ProgressionService.record(&"spells.illuminated.cells", lit_cells)
	_emit_event(&"land_illuminated", {"cell_x": cell.x, "cell_y": cell.y, "radius": radius, "cells": lit_cells, "duration": duration_ticks})
	return lit_cells

func _recall_nomads(cell: Vector2i, radius: float) -> int:
	var recalled := 0
	var rescued_villagers := 0
	var anchor := _settlement_anchor()
	var targets: Array[Dictionary] = []
	for nomad in nomads:
		if int(nomad.get("health", 0)) <= 0:
			continue
		if Vector2(float(nomad.x), float(nomad.y)).distance_to(Vector2(cell) + Vector2(0.5, 0.5)) > radius:
			continue
		targets.append(nomad)
	for nomad in targets:
		var offset := Vector2i((recalled % 5) - 2, (recalled / 5) - 2)
		var destination := pathfinder.nearest_walkable(Vector2i(floori(anchor.x), floori(anchor.y)) + offset)
		nomad.x = float(destination.x) + 0.5
		nomad.y = float(destination.y) + 0.5
		nomad.target_x = nomad.x
		nomad.target_y = nomad.y
		if _admit_nomad(nomad, &"recall"):
			nomad.state = "recalled"
			recalled += 1
	if recalled > 0:
		ProgressionService.record(&"spells.recalled.nomads", recalled)
		_emit_event(&"nomads_recalled", {"count": recalled, "cell_x": cell.x, "cell_y": cell.y})
	for villager in villagers:
		if int(villager.get("health", 0)) <= 0 or Vector2(float(villager.x), float(villager.y)).distance_to(Vector2(cell) + Vector2(0.5, 0.5)) > radius:
			continue
		var was_injured_and_fleeing := int(villager.get("health", 1000)) < 1000 and String(villager.get("state", "")) in ["fleeing", "panicking"]
		var destination := pathfinder.nearest_walkable(Vector2i(floori(anchor.x), floori(anchor.y)) + Vector2i((rescued_villagers % 5) - 2, (rescued_villagers / 5) + 2))
		villager.x = float(destination.x) + 0.5
		villager.y = float(destination.y) + 0.5
		villager.target_x = villager.x
		villager.target_y = villager.y
		villager.path = []
		villager.path_index = 0
		villager.path_goal_x = -1
		villager.path_goal_y = -1
		villager.state = "recalled"
		rescued_villagers += 1
		if was_injured_and_fleeing:
			ProgressionService.record(&"spells.recalled.injured_fleeing")
	if rescued_villagers > 0:
		_emit_event(&"villagers_recalled", {"count": rescued_villagers, "cell_x": cell.x, "cell_y": cell.y})
	return recalled

func _cast_storm(cell: Vector2i, definition: Dictionary) -> void:
	weather = StringName(definition.get("weather", "rain"))
	active_event = StringName(definition.get("event", "lightning_storm"))
	event_ticks_remaining = maxi(event_ticks_remaining, int(definition.get("duration_ticks", 320)))
	next_weather_tick = maxi(next_weather_tick, tick + event_ticks_remaining)
	next_event_tick = maxi(next_event_tick, tick + event_ticks_remaining + TICKS_PER_DAY)
	# The first strike lands at the commanded point so Storm has an immediate,
	# deterministic gameplay consequence before the scheduled storm pulses.
	_damage_monsters_in_radius(cell, 3.5, 360, &"magic_electric")
	ProgressionService.record(&"events.started")
	ProgressionService.record(&"events.started.lightning_storm")
	_emit_event(&"event_started", {"event_id": active_event, "duration": event_ticks_remaining, "source": "spell"})

func _damage_monsters_in_radius(cell: Vector2i, radius: float, damage: int, damage_type: StringName = &"magic") -> void:
	for monster in monsters:
		if Vector2(float(monster.x), float(monster.y)).distance_to(Vector2(cell)) <= radius:
			_apply_damage_to_monster(monster, damage, damage_type)
	_damage_hostile_structures_in_radius(cell, radius, damage, damage_type)

func _damage_hostile_structures_in_radius(cell: Vector2i, radius: float, damage: int, damage_type: StringName = &"magic") -> int:
	var destroyed_count := 0
	for structure in hostile_structures:
		if bool(structure.get("destroyed", false)):
			continue
		var center := Vector2(float(structure.x) + float(structure.width) * 0.5, float(structure.y) + float(structure.height) * 0.5)
		if center.distance_to(Vector2(cell) + Vector2(0.5, 0.5)) > radius:
			continue
		if _apply_damage_to_hostile_structure(structure, damage, damage_type):
			destroyed_count += 1
	return destroyed_count

func _add_spell_resource_node(spell_id: StringName, cell: Vector2i) -> void:
	var resource_id := "wood" if spell_id == &"holy_wood" else "raw_vegetables"
	resource_nodes.append({"entity_id": _next_id(), "id": resource_id, "x": cell.x, "y": cell.y, "amount": 32, "initial_amount": 32, "magical": true})
	if spell_id == &"holy_potatoes":
		ProgressionService.record(&"resources.grown.holy_potatoes", 32)

func _motivate_land(cell: Vector2i, radius: float) -> void:
	var restored := 0
	for resource_node in resource_nodes:
		var resource_id := String(resource_node.get("id", ""))
		if resource_id not in ["wood", "crystal", "raw_vegetables"]:
			continue
		if Vector2(float(resource_node.x) + 0.5, float(resource_node.y) + 0.5).distance_to(Vector2(cell) + Vector2(0.5, 0.5)) > radius:
			continue
		var maximum := maxi(1, int(resource_node.get("initial_amount", resource_node.get("amount", 1))))
		var before := int(resource_node.get("amount", 0))
		var boost := maxi(4, ceili(float(maximum) * 0.5))
		resource_node.amount = mini(maximum, before + boost)
		restored += int(resource_node.amount) - before
	if restored > 0:
		ProgressionService.record(&"resources.motivated.land", restored)

func _resurrect_nearest_ghost(cell: Vector2i, radius: float) -> void:
	var best: Dictionary = {}
	var best_distance := radius
	for ghost in ghosts:
		if not bool(ghost.bound):
			continue
		var distance := Vector2(float(ghost.x), float(ghost.y)).distance_to(Vector2(cell))
		if distance <= best_distance:
			best_distance = distance
			best = ghost
	if best.is_empty() or int(resources.get("filled_eerie_vessel", 0)) <= 0:
		return
	var resurrected := false
	if String(best.get("source_kind", "villager")) == "animal":
		var source_animal_id := int(best.get("source_animal_id", 0))
		for animal in animals:
			if int(animal.get("id", 0)) != source_animal_id:
				continue
			animal.health = maxi(350, int(animal.get("max_health", 700)) * 2 / 3)
			animal.hunger = maxi(500, int(animal.get("hunger", 0)))
			animal.thirst = maxi(500, int(animal.get("thirst", 0)))
			animal.energy = 500
			animal.state = "resurrected"
			animal.ghost_created = false
			animal.death_recorded = false
			if String(animal.get("definition_id", "")) in ["doggo", "doofy_doggo"]:
				ProgressionService.record(&"animals.resurrected.doggo")
			resurrected = true
			break
	else:
		var source_id := int(best.get("source_villager_id", 0))
		for villager in villagers:
			if int(villager.id) == source_id:
				villager.health = 650
				villager.hunger = maxi(500, int(villager.hunger))
				villager.thirst = maxi(500, int(villager.thirst))
				villager.energy = 500
				villager.state = "resurrected"
				villager.ghost_created = false
				resurrected = true
				break
	if not resurrected:
		return
	consume_physical_resource(&"filled_eerie_vessel", 1)
	add_physical_resource(&"empty_eerie_vessel", 1)
	ghosts.erase(best)
	if String(best.get("source_kind", "villager")) != "animal":
		ProgressionService.record(&"population.resurrected")

func _spell_radius(spell_id: StringName) -> float:
	return {
		"grab": 1.8,
		"lightning_bolt": 2.5, "magic_bolts": 4.0, "meteor": 5.5, "comet": 9.0,
		"healing_aura": 8.0, "regenerate": 5.0, "divine_blessing": 6.0,
		"harvest": 7.0, "mend": 7.0, "banish": 6.0, "dissolve": 6.0, "construct": 5.0,
		"charm": 5.0, "cold_aura": 6.0, "earthquake": 7.0, "illuminate": 8.0, "recall": 7.0
	}.get(String(spell_id), 4.0)

func _set_job_desired(payload: Dictionary) -> void:
	var job_id := String(payload.get("job_id", ""))
	if not jobs.has(job_id):
		return
	jobs[job_id].desired = clampi(int(payload.get("amount", 0)), 0, int(jobs[job_id].max))
	_assign_jobs()

func _assign_jobs() -> void:
	for job_id in jobs:
		jobs[job_id].current = 0
	var cursor := 0
	for job_id in jobs:
		var amount: int = mini(int(jobs[job_id].desired), villagers.size() - cursor)
		for index in range(cursor, cursor + amount):
			villagers[index].job = job_id
		jobs[job_id].current = amount
		cursor += amount
	for index in range(cursor, villagers.size()):
		villagers[index].job = "idle"
	_assign_ranger_homes()

func _ranger_lodge_capacity(building: Dictionary) -> int:
	if String(building.get("definition_id", "")) != "ranger_lodge" or not bool(building.get("completed", false)) or bool(building.get("destroyed", false)):
		return 0
	var definition := ContentRegistry.get_by_id(&"buildings", &"ranger_lodge")
	var capacities: Array = definition.get("ranger_housing_by_tier", [])
	if capacities.is_empty():
		return 0
	return int(capacities[clampi(int(building.get("tier", 1)) - 1, 0, capacities.size() - 1)])

func _ranger_lodge_occupancy(building_id: int) -> int:
	var occupancy := 0
	for villager in villagers:
		if int(villager.get("health", 0)) > 0 and String(villager.get("job", "")) == "rangers" and int(villager.get("home_id", 0)) == building_id:
			occupancy += 1
	return occupancy

func _assign_ranger_homes() -> void:
	for villager in villagers:
		if String(villager.get("job", "")) == "rangers":
			continue
		var previous_home := _find_building(int(villager.get("home_id", 0)))
		if not previous_home.is_empty() and String(previous_home.get("definition_id", "")) == "ranger_lodge":
			villager.home_id = 0
	for villager in villagers:
		if int(villager.get("health", 0)) <= 0 or String(villager.get("job", "")) != "rangers":
			continue
		var current_home := _find_building(int(villager.get("home_id", 0)))
		if _ranger_lodge_capacity(current_home) > 0 and _ranger_lodge_occupancy(int(current_home.id)) <= _ranger_lodge_capacity(current_home):
			continue
		villager.home_id = 0
		var best: Dictionary = {}
		var best_distance := INF
		var position := Vector2(float(villager.x), float(villager.y))
		for building in buildings:
			var capacity := _ranger_lodge_capacity(building)
			if capacity <= 0 or _ranger_lodge_occupancy(int(building.id)) >= capacity:
				continue
			var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
			var distance := position.distance_squared_to(center)
			if distance < best_distance:
				best_distance = distance
				best = building
		if not best.is_empty():
			villager.home_id = int(best.id)

func set_paused(value: bool) -> void:
	paused = value
	_emit_snapshot()

func set_speed(value: int) -> void:
	speed = clampi(value, 0, 4)
	paused = speed == 0
	_emit_snapshot()

func get_snapshot() -> SimulationSnapshot:
	var snapshot := SimulationSnapshot.new()
	snapshot.tick = tick
	snapshot.day = tick / TICKS_PER_DAY + 1
	snapshot.day_fraction = float(tick % TICKS_PER_DAY) / float(TICKS_PER_DAY)
	snapshot.season = _season_for_day(snapshot.day)
	snapshot.weather = weather
	snapshot.active_event = active_event
	snapshot.temperature_c = temperature_c
	snapshot.water_frozen = water_frozen
	snapshot.event_ticks_remaining = event_ticks_remaining
	snapshot.paused = paused
	snapshot.speed = speed
	snapshot.population = _villager_population_count()
	snapshot.max_influence = max_influence
	snapshot.influence = influence
	snapshot.god_xp = god_xp
	snapshot.resources = resources.duplicate(true)
	snapshot.resource_caps = resource_caps.duplicate(true)
	snapshot.resource_rates = resource_rates.duplicate(true)
	snapshot.resource_nodes = resource_nodes.duplicate(true)
	snapshot.loose_items = loose_items.duplicate(true)
	snapshot.held_entity = held_entity.duplicate(true)
	snapshot.magic_circles = magic_circles.duplicate(true)
	snapshot.catjeet_trader = catjeet_trader.duplicate(true)
	snapshot.next_trade_arrival_tick = next_trade_arrival_tick
	snapshot.jobs = jobs.duplicate(true)
	snapshot.housing_capacity = housing_capacity
	snapshot.animal_pen_capacity = animal_pen_capacity
	snapshot.clucker_coop_capacity = clucker_coop_capacity
	snapshot.doggo_house_capacity = doggo_house_capacity
	snapshot.building_limit = building_limit
	snapshot.build_range = build_range
	snapshot.ancillary_limit = ancillary_limit
	snapshot.task_summary = task_board.debug_summary()
	var population_groups := {"children": 0, "adults": 0, "elders": 0, "nomads": nomads.size(), "animals": animals.size(), "golems": golems.size(), "ghosts": ghosts.size()}
	for villager in villagers:
		var key := String(villager.get("age_stage", "adult")) + "s"
		population_groups[key] = int(population_groups.get(key, 0)) + 1
	if String(held_entity.get("kind", "")) == "villager":
		var held_key := String(held_entity.get("payload", {}).get("age_stage", "adult")) + "s"
		population_groups[held_key] = int(population_groups.get(held_key, 0)) + 1
	elif String(held_entity.get("kind", "")) == "nomad":
		population_groups.nomads = int(population_groups.nomads) + 1
	elif String(held_entity.get("kind", "")) == "animal":
		population_groups.animals = int(population_groups.animals) + 1
	elif String(held_entity.get("kind", "")) == "golem":
		population_groups.golems = int(population_groups.golems) + 1
	snapshot.population_groups = population_groups
	snapshot.villagers = villagers.duplicate(true)
	snapshot.nomads = nomads.duplicate(true)
	snapshot.animals = animals.duplicate(true)
	snapshot.golems = golems.duplicate(true)
	snapshot.monsters = monsters.duplicate(true)
	snapshot.ghosts = ghosts.duplicate(true)
	var corruption_positions: Array = []
	for corruption_key in corruption_cells:
		var cell := _cell_from_key(String(corruption_key))
		corruption_positions.append([cell.x, cell.y, clampf(float(corruption_cells.get(corruption_key, 1000)) / 1000.0, 0.0, 1.0)])
	snapshot.corruption_cells = corruption_positions
	var terrain_effect_positions: Array = []
	for terrain_key in terrain_effects:
		var terrain_cell := _cell_from_key(String(terrain_key))
		var terrain_effect: Dictionary = terrain_effects[terrain_key]
		terrain_effect_positions.append([terrain_cell.x, terrain_cell.y, String(terrain_effect.get("kind", "")), clampf(float(terrain_effect.get("intensity", 1000)) / 1000.0, 0.0, 1.0)])
	snapshot.terrain_effects = terrain_effect_positions
	var terrain_work_positions: Array = []
	for work_key in terrain_work:
		var work_cell := _cell_from_key(String(work_key))
		var work: Dictionary = terrain_work[work_key]
		terrain_work_positions.append([
			work_cell.x, work_cell.y, String(work.get("action", "")),
			clampf(float(work.get("progress", 0)) / maxf(1.0, float(work.get("target", 1))), 0.0, 1.0),
			String(work.get("state", "designated")),
		])
	snapshot.terrain_work = terrain_work_positions
	var visible_buildings: Array[Dictionary] = []
	for building in buildings:
		visible_buildings.append(building.duplicate(true))
	for structure in hostile_structures:
		visible_buildings.append(structure.duplicate(true))
	snapshot.buildings = visible_buildings
	snapshot.goals = goals.duplicate(true)
	snapshot.messages = messages.duplicate()
	return snapshot

func _season_for_day(day: int) -> StringName:
	var season_length := maxi(1, int(mode_rules.get("season_days", 5)))
	var season_index := ((day - 1) / season_length) % 4
	return [&"Spring", &"Summer", &"Autumn", &"Winter"][season_index]

func _emit_snapshot() -> void:
	snapshot_updated.emit(get_snapshot())

func _emit_event(type: StringName, data: Dictionary = {}) -> void:
	sim_event.emit(SimEvent.new(tick, type, data))

func _next_id() -> int:
	var result := next_entity_id
	next_entity_id += 1
	return result

func export_state() -> Dictionary:
	return {
		"tick": tick,
		"mode_rules": mode_rules.duplicate(true),
		"region_id": String(blueprint.region_id) if blueprint else "",
		"biome_id": String(blueprint.biome_id) if blueprint else "",
		"seed": blueprint.seed if blueprint else 0,
		"blueprint": blueprint.to_dictionary() if blueprint else {},
		"paused": paused,
		"speed": speed,
		# Physical totals are derived from `inventory`; only nonphysical pools are
		# serialized separately so two save fields can never disagree.
		"nonphysical_resources": {
			"energy": int(resources.get("energy", 0)),
			"faith": int(resources.get("faith", 0)),
		},
		"resource_caps": resource_caps.duplicate(true),
		"resource_rates": resource_rates.duplicate(true),
		"resource_rate_sample": resource_rate_sample.duplicate(true),
		"resource_rate_sample_tick": resource_rate_sample_tick,
		"next_resource_rate_tick": next_resource_rate_tick,
		"resource_nodes": resource_nodes.duplicate(true),
		"loose_items": loose_items.duplicate(true),
		"held_entity": held_entity.duplicate(true),
		"magic_circles": magic_circles.duplicate(true),
		"catjeet_trader": catjeet_trader.duplicate(true),
		"next_trade_arrival_tick": next_trade_arrival_tick,
		"jobs": jobs.duplicate(true),
		"villagers": villagers.duplicate(true),
		"nomads": nomads.duplicate(true),
		"next_nomad_tick": next_nomad_tick,
		"nomad_groups_spawned": nomad_groups_spawned,
		"animals": animals.duplicate(true),
		"golems": golems.duplicate(true),
		"monsters": monsters.duplicate(true),
		"ghosts": ghosts.duplicate(true),
		"corruption_cells": corruption_cells.duplicate(true),
		"terrain_effects": terrain_effects.duplicate(true),
		"terrain_work": terrain_work.duplicate(true),
		"buildings": buildings.duplicate(true),
		"hostile_structures": hostile_structures.duplicate(true),
		"housing_capacity": housing_capacity,
		"animal_pen_capacity": animal_pen_capacity,
		"clucker_coop_capacity": clucker_coop_capacity,
		"doggo_house_capacity": doggo_house_capacity,
		"building_limit": building_limit,
		"build_range": build_range,
		"ancillary_limit": ancillary_limit,
		"task_board": task_board.export_state(),
		"goals": goals.duplicate(true),
		"messages": messages.duplicate(),
		"god_xp": god_xp,
		"influence": influence,
		"max_influence": max_influence,
		"influence_reserved": influence_reserved,
		"weather": String(weather),
		"active_event": String(active_event),
		"event_ticks_remaining": event_ticks_remaining,
		"next_weather_tick": next_weather_tick,
		"next_event_tick": next_event_tick,
		"temperature_c": temperature_c,
		"water_frozen": water_frozen,
		"next_entity_id": next_entity_id,
		"inventory": inventory.export_state(),
		"reservations": reservations.export_state(),
		"task_system": task_system.export_state(),
		"trade_system": trade_system.export_state(),
		"corruption_system": corruption_system.export_state(),
		"spell_system": spell_system.export_state(),
		# JSON numbers are parsed through IEEE-754 and cannot preserve every
		# 64-bit RNG state. Store it as decimal text so save/load replay hashes
		# remain exact for every seed.
		"rng_state": str(rng.state),
	}

func import_state(state: Dictionary) -> bool:
	var restored_blueprint: RegionBlueprint
	if state.get("blueprint", {}) is Dictionary and not state.get("blueprint", {}).is_empty():
		restored_blueprint = RegionBlueprint.from_dictionary(state.blueprint)
	else:
		var generator := RegionGenerator.new()
		restored_blueprint = generator.generate(int(state.get("seed", 1)), StringName(state.get("region_id", "applemeadow")), StringName(state.get("biome_id", "forest")))
	start_region(restored_blueprint, state.get("mode_rules", {}))
	tick = int(state.get("tick", 0))
	paused = bool(state.get("paused", false))
	speed = int(state.get("speed", 1))
	var restored_nonphysical: Dictionary = state.get("nonphysical_resources", state.get("resources", {})).duplicate(true)
	resources.energy = int(restored_nonphysical.get("energy", 0))
	resources.faith = int(restored_nonphysical.get("faith", 0))
	resource_caps = state.get("resource_caps", {}).duplicate(true)
	resource_rates = state.get("resource_rates", {}).duplicate(true)
	resource_rate_sample = state.get("resource_rate_sample", resources).duplicate(true)
	resource_rate_sample_tick = int(state.get("resource_rate_sample_tick", tick))
	next_resource_rate_tick = int(state.get("next_resource_rate_tick", tick + 100))
	resource_nodes.clear()
	for resource_node in state.get("resource_nodes", []):
		if resource_node is Dictionary:
			var restored_node: Dictionary = resource_node.duplicate(true)
			if not restored_node.has("initial_amount"):
				restored_node.initial_amount = maxi(int(restored_node.get("amount", 0)), _default_resource_node_capacity(String(restored_node.get("id", ""))))
			resource_nodes.append(restored_node)
	loose_items.clear()
	for item in state.get("loose_items", []):
		if item is Dictionary:
			loose_items.append(item.duplicate(true))
	held_entity = state.get("held_entity", {}).duplicate(true)
	if state.has("magic_circles"):
		magic_circles.clear()
		for circle in state.get("magic_circles", []):
			if circle is Dictionary:
				magic_circles.append(circle.duplicate(true))
	catjeet_trader = state.get("catjeet_trader", {}).duplicate(true)
	next_trade_arrival_tick = int(state.get("next_trade_arrival_tick", tick + 600))
	jobs = state.get("jobs", {}).duplicate(true)
	villagers.clear()
	for villager in state.get("villagers", []):
		if villager is Dictionary:
			villagers.append(villager.duplicate(true))
	nomads.clear()
	for nomad in state.get("nomads", []):
		if nomad is Dictionary:
			nomads.append(nomad.duplicate(true))
	next_nomad_tick = int(state.get("next_nomad_tick", tick + TICKS_PER_DAY * 2))
	nomad_groups_spawned = int(state.get("nomad_groups_spawned", 0))
	animals.clear()
	for animal in state.get("animals", []):
		if animal is Dictionary:
			animals.append(animal.duplicate(true))
	golems.clear()
	for golem in state.get("golems", []):
		if golem is Dictionary:
			golems.append(golem.duplicate(true))
	monsters.clear()
	for monster in state.get("monsters", []):
		if monster is Dictionary:
			monsters.append(monster.duplicate(true))
	ghosts.clear()
	for ghost in state.get("ghosts", []):
		if ghost is Dictionary:
			ghosts.append(ghost.duplicate(true))
	corruption_cells = state.get("corruption_cells", {}).duplicate(true)
	terrain_effects = state.get("terrain_effects", {}).duplicate(true)
	terrain_work = state.get("terrain_work", {}).duplicate(true)
	buildings.clear()
	for building in state.get("buildings", []):
		if building is Dictionary:
			var restored_building: Dictionary = building.duplicate(true)
			var restored_definition := ContentRegistry.get_by_id(&"buildings", StringName(restored_building.get("definition_id", "")))
			_configure_water_runtime(restored_building, restored_definition)
			_configure_storage_runtime(restored_building, restored_definition)
			buildings.append(restored_building)
	_recalculate_resource_caps()
	hostile_structures.clear()
	for structure in state.get("hostile_structures", []):
		if structure is Dictionary:
			hostile_structures.append(structure.duplicate(true))
	_refresh_navigation_buildings()
	housing_capacity = int(state.get("housing_capacity", 0))
	animal_pen_capacity = int(state.get("animal_pen_capacity", 0))
	clucker_coop_capacity = int(state.get("clucker_coop_capacity", 0))
	doggo_house_capacity = int(state.get("doggo_house_capacity", 0))
	building_limit = int(state.get("building_limit", 0))
	build_range = int(state.get("build_range", 0))
	ancillary_limit = int(state.get("ancillary_limit", 0))
	task_board.import_state(state.get("task_board", {}))
	goals = state.get("goals", {}).duplicate(true)
	messages.clear()
	for message in state.get("messages", []):
		messages.append(String(message))
	var restored_god_xp := int(state.get("god_xp", 0))
	if restored_god_xp > ProgressionService.god_xp:
		ProgressionService.set_god_xp(restored_god_xp)
	god_xp = ProgressionService.god_xp
	influence = int(state.get("influence", villagers.size() * 40))
	max_influence = int(state.get("max_influence", villagers.size() * 40))
	influence_reserved = int(state.get("influence_reserved", 0))
	weather = StringName(state.get("weather", "clear"))
	active_event = StringName(state.get("active_event", ""))
	event_ticks_remaining = int(state.get("event_ticks_remaining", 0))
	next_weather_tick = int(state.get("next_weather_tick", tick + 300))
	next_event_tick = int(state.get("next_event_tick", tick + TICKS_PER_DAY * 3))
	temperature_c = int(state.get("temperature_c", 18))
	_set_frozen_water_navigation(bool(state.get("water_frozen", _season_for_day(tick / TICKS_PER_DAY + 1) == &"Winter")), false)
	next_entity_id = int(state.get("next_entity_id", 1))
	if state.has("inventory") and state.inventory is Dictionary:
		inventory.import_state(state.inventory)
	else:
		# Compatibility for direct legacy imports that did not pass through
		# SaveService's migration chain.
		for resource_id in restored_nonphysical:
			var typed_id := StringName(resource_id)
			if _is_physical_resource(typed_id):
				inventory.add_commodity(typed_id, int(restored_nonphysical[resource_id]), PhysicalInventory.LocationState.GROUND, blueprint.starting_cell)
	sync_derived_resources()
	if state.has("reservations") and state.reservations is Dictionary:
		reservations.import_state(state.reservations)
	if state.has("task_system") and state.task_system is Dictionary:
		task_system.import_state(state.task_system)
	if state.has("trade_system") and state.trade_system is Dictionary:
		trade_system.import_state(state.trade_system)
	if state.has("corruption_system") and state.corruption_system is Dictionary:
		corruption_system.import_state(state.corruption_system)
	if state.has("spell_system") and state.spell_system is Dictionary:
		spell_system.import_state(state.spell_system)
	rng.state = int(state.get("rng_state", rng.state))
	_emit_snapshot()
	return true

func _default_resource_node_capacity(resource_id: String) -> int:
	return int({"wood": 20, "rock": 18, "crystal": 16, "raw_vegetables": 12}.get(resource_id, 12))

func compute_state_hash() -> String:
	return JSON.stringify(_canonicalize(export_state())).sha256_text()

func _canonicalize(value: Variant) -> Variant:
	if value is int or value is float:
		return float(value)
	if value is Dictionary:
		var sorted := {}
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key in keys:
			sorted[str(key)] = _canonicalize(value[key])
		return sorted
	if value is Array:
		var normalized: Array = []
		for item in value:
			normalized.append(_canonicalize(item))
		return normalized
	return value
