extends Node

signal region_started(blueprint: RegionBlueprint)
signal snapshot_updated(snapshot: SimulationSnapshot)
signal sim_event(event: SimEvent)

const TICK_RATE := 10.0
const TICK_SECONDS := 1.0 / TICK_RATE
const TICKS_PER_DAY := 1200
const TASK_BOARD := preload("res://core/simulation/task_board.gd")
const GRID_PATHFINDER := preload("res://core/simulation/grid_pathfinder.gd")

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
var catjeet_trader: Dictionary = {}
var next_trade_arrival_tick := 600
var jobs: Dictionary = {}
var villagers: Array[Dictionary] = []
var animals: Array[Dictionary] = []
var golems: Array[Dictionary] = []
var monsters: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
var corruption_cells: Dictionary = {}
var buildings: Array[Dictionary] = []
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
var next_entity_id := 1
var command_queue: Array[GameCommand] = []
var rng := RandomNumberGenerator.new()
var task_board = TASK_BOARD.new()
var pathfinder = GRID_PATHFINDER.new()

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
	max_influence = 999999 if bool(mode_rules.get("unlimited_influence", false)) else 800
	influence = max_influence
	influence_reserved = 0
	weather = &"clear"
	active_event = &""
	event_ticks_remaining = 0
	next_weather_tick = 300 + rng.randi_range(0, 300)
	next_event_tick = TICKS_PER_DAY * 3 + rng.randi_range(0, TICKS_PER_DAY)
	temperature_c = 18
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
	catjeet_trader.clear()
	next_trade_arrival_tick = 600 + rng.randi_range(0, 300)
	for source_node in blueprint.resource_nodes:
		var resource_node: Dictionary = source_node.duplicate(true)
		resource_node["entity_id"] = _next_id()
		resource_node["initial_amount"] = int(resource_node.get("amount", 0))
		resource_nodes.append(resource_node)
	corruption_cells.clear()
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
	buildings.clear()
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

func advance_tick() -> void:
	if not active:
		return
	_apply_due_commands()
	tick += 1
	if tick == 1 or tick % 10 == 0:
		_refresh_task_board()
	_update_villagers()
	_update_population_life_cycle()
	_update_animals()
	_update_equipment()
	_update_buildings()
	_update_production()
	_update_golems()
	_update_catjeet_trade()
	_update_decay_and_trash()
	_update_needs()
	_update_combat_statuses()
	_update_death_and_ghosts()
	_update_corruption()
	_update_monsters()
	_update_towers()
	_update_influence()
	_update_weather_and_events()
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

func _place_building(payload: Dictionary) -> void:
	var building_id := StringName(payload.get("building_id", ""))
	var definition := ContentRegistry.get_by_id(&"buildings", building_id)
	if definition.is_empty():
		_emit_event(&"command_rejected", {"reason": "unknown_building", "building_id": building_id})
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
			resources[resource_id] = int(resources.get(resource_id, 0)) - int(costs[resource_id])
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
	}
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
	var camp_center := Vector2(float(camp.x) + float(camp.width) * 0.5, float(camp.y) + float(camp.height) * 0.5)
	var placement_center := Vector2(cell) + Vector2(footprint) * 0.5
	if camp_center.distance_to(placement_center) > float(build_range):
		_emit_event(&"command_rejected", {"reason": "out_of_range", "building_id": building_id, "range": build_range})
		return false
	return true

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
	var preview := get_upgrade_preview(int(building.id))
	var costs: Dictionary = preview.get("cost", {})
	if not bool(mode_rules.get("sandbox_tools", false)):
		for resource_id in costs:
			if int(resources.get(resource_id, 0)) < int(costs[resource_id]):
				_emit_event(&"command_rejected", {"reason": "missing_resources", "building_id": building.id, "resource": resource_id})
				return
		for resource_id in costs:
			resources[resource_id] = int(resources.get(resource_id, 0)) - int(costs[resource_id])
	building.completed = false
	building.progress = int(preview.get("build_time", definition.get("build_time", 450))) if bool(mode_rules.get("instant_build", false)) else 0
	building.build_time = int(preview.get("build_time", definition.get("build_time", 450)))
	building.upgrade_target_tier = current_tier + 1
	building.upgrade_target_name = String(preview.get("name", building.name))
	building.upgrade_target_health = int(preview.get("health", building.max_health))
	building.upgrading = true
	_emit_event(&"building_upgrade_started", {"building_id": building.id, "tier": current_tier + 1})
	_recalculate_settlement_support()

func get_upgrade_preview(building_entity_id: int) -> Dictionary:
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
	return {
		"tier": target_tier, "name": "%s Tier %d" % [definition.get("name", building.name), target_tier],
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
		resources.gold_coins = int(resources.gold_coins) - price
		resources[String(resource_id)] = int(resources.get(resource_id, 0)) + amount
		if resource_id == &"suspicious_key":
			ProgressionService.record(&"trade.keys_bought", amount)
	elif direction == &"sell":
		var payout := int(good.sell_price) * amount
		if int(resources.get(resource_id, 0)) < amount or int(catjeet_trader.gold_coins) < payout:
			return false
		resources[String(resource_id)] = int(resources.get(resource_id, 0)) - amount
		resources.gold_coins = int(resources.gold_coins) + payout
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
	resources.gold_coins = int(resources.gold_coins) - unit_price * amount
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
		building.upgrading = false
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
		if String(building.definition_id) == "camp" and int(building.tier) == 15:
			ProgressionService.record(&"town_center.large_castle")
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
				"x": float(animal.x), "y": float(animal.y), "max_claims": 1,
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
	task_board.prune(active_keys)

func _update_villagers() -> void:
	for villager in villagers:
		if int(villager.health) <= 0:
			villager.state = "dead"
			_release_villager_task(villager)
			continue
		villager.attack_cooldown = maxi(0, int(villager.get("attack_cooldown", 0)) - 1)
		if String(villager.job) == "rangers" and _ranger_try_combat(villager):
			continue
		if _service_immediate_need(villager):
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
		if task.is_empty():
			_wander_or_rest(villager)
			continue
		var target := Vector2(float(task.x), float(task.y))
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
					resources.bow = int(resources.bow) - 1
					resources.quiver = int(resources.quiver) - 1
				elif int(resources.get("iron_sword", 0)) > 0:
					equipment.weapon = _equipment_item(&"iron_sword")
					resources.iron_sword = int(resources.iron_sword) - 1
				elif int(resources.get("wood_sword", 0)) > 0:
					equipment.weapon = _equipment_item(&"wood_sword")
					resources.wood_sword = int(resources.wood_sword) - 1
			_try_equip_armor(equipment, "body", ["iron_body_armor", "leather_body_armor"])
			_try_equip_armor(equipment, "helmet", ["iron_helmet", "leather_helmet"])
			if String(equipment.get("weapon", {}).get("id", "")) != "bow":
				_try_equip_armor(equipment, "shield", ["iron_shield", "wood_shield"])
		elif String(villager.job) == "maintainers" and not equipment.has("tool") and int(resources.get("hammer", 0)) > 0:
			equipment.tool = _equipment_item(&"hammer")
			resources.hammer = int(resources.hammer) - 1
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
		resources[String(resource_id)] = int(resources[String(resource_id)]) - 1
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
			resources.quiver = int(resources.quiver) - 1
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

func _nearest_monster(position: Vector2, radius: float) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := radius * radius
	for monster in monsters:
		if int(monster.health) <= 0:
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
	if tick % 100 != 0 or housing_capacity <= villagers.size():
		return
	for villager in villagers:
		if String(villager.age_stage) != "adult" or String(villager.sex) != "female" or int(villager.health) <= 0:
			continue
		if int(villager.pregnant_ticks) > 0:
			villager.pregnant_ticks = int(villager.pregnant_ticks) - 100
			if int(villager.pregnant_ticks) <= 0 and housing_capacity > villagers.size():
				_birth_child(villager)
		elif housing_capacity > villagers.size() and rng.randf() < 0.015 * (1.0 + ProgressionService.get_modifier(&"fertility")):
			villager.pregnant_ticks = TICKS_PER_DAY * 2
		break

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
			continue
		animal.hunger = maxi(0, int(animal.hunger) - (1 if tick % 20 == 0 else 0))
		animal.thirst = maxi(0, int(animal.thirst) - (1 if tick % 15 == 0 else 0))
		if int(animal.hunger) <= 0 or int(animal.thirst) <= 0:
			animal.health = maxi(0, int(animal.health) - 1)
		animal.attack_cooldown = maxi(0, int(animal.get("attack_cooldown", 0)) - 1)
		if String(animal.definition_id) in ["doggo", "doofy_doggo"] and bool(animal.get("domesticated", false)) and _doggo_try_combat(animal):
			continue
		var home := _find_building(int(animal.get("home_id", 0)))
		if bool(animal.get("domesticated", false)) and (home.is_empty() or not bool(home.get("completed", false)) or bool(home.get("destroyed", false))):
			animal.home_id = _assign_animal_home(animal)
			home = _find_building(int(animal.home_id))
			if home.is_empty():
				animal.state = "unhoused"
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
			resources.eggs = mini(int(resource_caps.get("eggs", 200)), int(resources.get("eggs", 0)) + 1)
			ProgressionService.record(&"animals.eggs_laid")
		elif String(animal.definition_id) == "doggo" and bool(animal.domesticated) and tick % 240 == int(animal.id) % 240:
			resources.wood = mini(int(resource_caps.wood), int(resources.wood) + 1)
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

func _move_villager_toward(villager: Dictionary, target: Vector2, step: float) -> bool:
	var position := Vector2(float(villager.x), float(villager.y))
	step *= _road_speed_multiplier(Vector2i(floori(position.x), floori(position.y)))
	villager.target_x = target.x
	villager.target_y = target.y
	if position.distance_to(target) <= 0.72:
		villager.stuck_ticks = 0
		return true
	var goal_cell := Vector2i(floori(target.x), floori(target.y))
	if int(villager.get("path_goal_x", -1)) != goal_cell.x or int(villager.get("path_goal_y", -1)) != goal_cell.y or int(villager.get("path_index", 0)) >= villager.get("path", []).size():
		villager.path = pathfinder.find_path(Vector2i(floori(position.x), floori(position.y)), goal_cell)
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

func _road_speed_multiplier(cell: Vector2i) -> float:
	for building in buildings:
		if not bool(building.get("completed", false)) or bool(building.get("destroyed", false)) or String(building.get("category", "")) != "roads":
			continue
		if Rect2i(Vector2i(int(building.x), int(building.y)), Vector2i(int(building.width), int(building.height))).has_point(cell):
			return {
				"path": 1.05, "log_road": 1.12, "cobble_log_road": 1.20,
				"cobble_board_road": 1.28, "cut_stone_board_road": 1.36,
			}.get(String(building.definition_id), 1.0)
	return 1.0

func _apply_navigation_building(building: Dictionary) -> void:
	if not bool(building.get("completed", false)) or bool(building.get("destroyed", false)):
		return
	var category := String(building.get("category", ""))
	var definition_id := String(building.get("definition_id", ""))
	for y in range(int(building.y), int(building.y) + int(building.height)):
		for x in range(int(building.x), int(building.x) + int(building.width)):
			var cell := Vector2i(x, y)
			if category == "walls" and not definition_id.ends_with("gate"):
				pathfinder.set_dynamic_solid(cell, true)
			elif category == "roads":
				var weight: float = {
					"path": 0.95, "log_road": 0.82, "cobble_log_road": 0.70,
					"cobble_board_road": 0.60, "cut_stone_board_road": 0.50,
				}.get(definition_id, 1.0)
				pathfinder.set_travel_weight(cell, weight)

func _refresh_navigation_buildings() -> void:
	pathfinder.configure(blueprint)
	for building in buildings:
		_apply_navigation_building(building)

func _work_task(villager: Dictionary, task: Dictionary) -> void:
	match String(task.kind):
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
					resources[resource_id] = int(resources.get(resource_id, 0)) + 1
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
			if int(villager.task_progress) >= 30:
				_slaughter_animal(slaughter_animal)
				_release_villager_task(villager)

func _service_immediate_need(villager: Dictionary) -> bool:
	if int(villager.energy) < 350 or String(villager.state) == "resting":
		_release_villager_task(villager)
		villager.state = "resting"
		villager.energy = mini(1000, int(villager.energy) + 5)
		if int(villager.energy) >= 850:
			villager.state = "idle"
		return true
	if int(villager.thirst) < 700 and int(resources.get("clean_water", 0)) > 0:
		_release_villager_task(villager)
		resources.clean_water = int(resources.clean_water) - 1
		villager.thirst = mini(1000, int(villager.thirst) + 320)
		villager.state = "drinking"
		return true
	if int(villager.hunger) < 700:
		var food_id := "rations" if int(resources.get("rations", 0)) > 0 else "raw_vegetables"
		if int(resources.get(food_id, 0)) > 0:
			_release_villager_task(villager)
			resources[food_id] = int(resources[food_id]) - 1
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

func _villager_has_tool(villager: Dictionary, tool_id: StringName) -> bool:
	return String(villager.get("equipment", {}).get("tool", {}).get("id", "")) == String(tool_id)

func _maintenance_service() -> Dictionary:
	return ContentRegistry.get_by_id(&"buildings", &"maintenance_building").get("service", {})

func _take_repair_material(building: Dictionary) -> String:
	var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
	var candidates: Array = definition.get("cost", {}).keys()
	candidates.sort()
	for resource_id in candidates:
		if int(resources.get(String(resource_id), 0)) <= 0:
			continue
		resources[String(resource_id)] = int(resources[String(resource_id)]) - 1
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
		resources[String(resource_id)] = int(resources.get(String(resource_id), 0)) + stored
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
	resources[medicine] = int(resources[medicine]) - 1
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
	if enabled:
		animal.capture_designated = false
		animal.state = "slaughter_designated"
	else:
		animal.state = "domesticated"
	_emit_event(&"animal_slaughter_designated", {"animal_id": animal.id, "enabled": enabled})

func _slaughter_animal(animal: Dictionary) -> void:
	var yields: Dictionary = {
		"beefalo": {"raw_meat": 14, "leather": 4},
		"entler": {"raw_meat": 12, "wood": 8},
		"rous": {"raw_meat": 16},
		"clucker": {"raw_meat": 4, "feathers": 6, "eggs": 2},
	}.get(String(animal.definition_id), {"raw_meat": 4})
	for resource_id in yields:
		resources[resource_id] = mini(int(resource_caps.get(resource_id, 200)), int(resources.get(resource_id, 0)) + int(yields[resource_id]))
	animal.health = 0
	animal.slaughtered = true
	animal.slaughter_designated = false
	animal.state = "slaughtered"
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
		resources[String(item.resource_id)] = int(resources.get(String(item.resource_id), 0)) + moved
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

func _update_production() -> void:
	for building in buildings:
		if not bool(building.completed) or bool(building.get("destroyed", false)):
			continue
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
		if String(building.category) == "golems":
			continue
		if String(building.definition_id) == "processor" and _building_has_workers(definition):
			_update_trash_processor(building)
			continue
		if String(building.definition_id) == "burner":
			_update_trash_burner(building)
			continue
		if String(building.definition_id) == "essence_altar" and _building_has_workers(definition):
			building.operation_progress = int(building.operation_progress) + 1
			if int(building.operation_progress) >= int(definition.get("prayer_ticks", 80)):
				resources.essence = int(resources.get("essence", 0)) + 3
				resources.faith = int(resources.get("faith", 0)) + 3
				building.operation_progress = 0
				ProgressionService.record(&"faith.prayers_completed")
			continue
		if String(building.definition_id) == "essence_collector":
			building.operation_progress = int(building.operation_progress) + 1
			if int(building.operation_progress) >= 30 and int(resources.get("essence", 0)) > 0 and int(resources.get("energy", 0)) < int(resource_caps.get("energy", 1000)):
				resources.essence = int(resources.essence) - 1
				resources.energy = mini(int(resource_caps.energy), int(resources.energy) + int(definition.get("essence_energy_value", 3)))
				building.operation_progress = 0
			continue
		var passive_recipe: Dictionary = definition.get("passive_recipe", {})
		if not passive_recipe.is_empty() and _building_has_workers(definition):
			building.operation_progress = int(building.operation_progress) + 1
			if int(building.operation_progress) >= int(passive_recipe.get("ticks", 100)):
				if _execute_recipe(passive_recipe):
					building.operation_progress = 0
			continue
		var available_recipes: Array[Dictionary] = []
		for recipe in ContentRegistry.get_all(&"recipes"):
			if String(recipe.get("building", "")) == String(building.definition_id):
				available_recipes.append(recipe)
		if available_recipes.is_empty() or not _building_has_workers(definition):
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
			continue
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
		resources[trash_id] = int(resources[trash_id]) - 1
		# Named simulation RNG keeps recovery deterministic. Exact Update 2d odds remain a ledger verification item.
		var roll := rng.randi_range(0, 239)
		if roll < 39:
			var recovered := String(recovery[trash_id])
			resources[recovered] = mini(int(resource_caps.get(recovered, 200)), int(resources.get(recovered, 0)) + 1)
		if roll >= 39 and roll < 158 and int(resources.trashy_trash) < int(resource_caps.trashy_trash):
			resources.trashy_trash = int(resources.trashy_trash) + 1
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
		resources[trash_id] = int(resources[trash_id]) - 1
		var essence_yield := 4 if trash_id == "trashy_cube" else 1
		resources.essence = mini(int(resource_caps.get("essence", 200)), int(resources.get("essence", 0)) + essence_yield)
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
		resources[resource_id] = int(resources.get(resource_id, 0)) - int(inputs[resource_id])
	for resource_id in outputs:
		resources[resource_id] = int(resources.get(resource_id, 0)) + int(outputs[resource_id])
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
	for resource_id in resource_caps:
		var resource_definition := ContentRegistry.get_by_id(&"resources", StringName(resource_id))
		resource_caps[resource_id] = 1000 if resource_id in ["energy", "faith"] else (0 if String(resource_definition.get("group", "")) == "trash" else 200)
	for building in buildings:
		if not bool(building.completed) or bool(building.get("destroyed", false)):
			continue
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
		housing_capacity += int(definition.get("housing_capacity", 0))
		if String(building.definition_id) == "housing":
			housing_capacity += roundi(ProgressionService.get_modifier(&"efficient_housing"))
		animal_pen_capacity += int(definition.get("animal_capacity", 0)) * int(building.tier)
		clucker_coop_capacity += int(definition.get("clucker_capacity", 0)) * int(building.tier)
		doggo_house_capacity += int(definition.get("doggo_capacity", 0)) * int(building.tier)
		for resource_id in definition.get("storage", {}):
			resource_caps[resource_id] = int(resource_caps.get(resource_id, 200)) + int(definition.storage[resource_id])
		var trash_storage := int(definition.get("trash_storage", 0)) * int(building.tier)
		if trash_storage > 0:
			for trash_id in ["trashy_trash", "woody_trash", "rocky_trash", "crystally_trash", "organicy_trash", "suspiciousy_trash", "trashy_cube"]:
				resource_caps[trash_id] = int(resource_caps.get(trash_id, 0)) + trash_storage
		if String(building.definition_id) == "camp":
			var town_tier := _town_center_tier(int(building.tier))
			jobs.builders.max = int(town_tier.get("builders", 12))
			building_limit = int(town_tier.get("building_limit", 8))
			build_range = int(town_tier.get("range", 32))
			ancillary_limit = int(town_tier.get("ancillary_limit", 1))
			for resource_id in resource_caps:
				if resource_id not in ["energy", "faith"]:
					resource_caps[resource_id] = int(resource_caps[resource_id]) + int(town_tier.get("storage", 20))
			continue
		for job_id in definition.get("jobs", []):
			if jobs.has(String(job_id)):
				jobs[String(job_id)].max = int(jobs[String(job_id)].max) + int(definition.get("worker_slots", 0))
	for job_id in jobs:
		var old_max := int(previous_maxima.get(job_id, 0))
		var new_max := int(jobs[job_id].max)
		if old_max == 0 and new_max > 0 and int(jobs[job_id].desired) == 0:
			jobs[job_id].desired = new_max
		jobs[job_id].desired = mini(int(jobs[job_id].desired), new_max)
	_assign_jobs()

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
		ghosts.append({
			"id": _next_id(), "source_villager_id": int(villager.id), "name": "%s's Ghost" % String(villager.name),
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
				resources.empty_eerie_vessel = int(resources.empty_eerie_vessel) - 1
				resources.filled_eerie_vessel = int(resources.filled_eerie_vessel) + 1
				ProgressionService.record(&"ghosts.bound")
				break

func _update_corruption() -> void:
	if tick % 50 != 0 or corruption_cells.is_empty():
		return
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
		corruption_cells[_cell_key(candidate)] = 1000

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
			resources.energy = int(resources.energy) - 1
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
	resources.energy = int(resources.energy) - 1
	golem.powered = true

func _golem_try_combat(golem: Dictionary) -> bool:
	var actor := ContentRegistry.get_by_id(&"actors", StringName(golem.definition_id))
	if "combat" not in actor.get("roles", []):
		return false
	var position := Vector2(float(golem.x), float(golem.y))
	var target: Dictionary = {}
	var best_distance := 14.0 * 14.0
	for monster in monsters:
		if int(monster.health) <= 0:
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
		resources[resource_id] = int(resources.get(resource_id, 0)) + 1
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
		resources[trash_id] = int(resources.get(trash_id, 0)) - used
		remaining -= used
		if remaining <= 0:
			break
	resources.trashy_cube = int(resources.get("trashy_cube", 0)) + 1
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
		var target := _monster_target(monster)
		if target.is_empty():
			continue
		var target_position := Vector2(float(target.x), float(target.y))
		var actor := ContentRegistry.get_by_id(&"actors", StringName(monster.definition_id))
		var reached := _move_spectre_toward(monster, target_position, float(monster.speed)) if bool(actor.get("crosses_walls", false)) else _move_villager_toward(monster, target_position, float(monster.speed))
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
	monsters = survivors

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
		if not bool(building.completed) or bool(building.get("destroyed", false)) or String(building.category) != "towers":
			continue
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
		var tower: Dictionary = definition.get("tower", {})
		if tower.is_empty():
			building.combat_state = "invalid_definition"
			continue
		building.combat_cooldown = maxi(0, int(building.get("combat_cooldown", 0)) - 1)
		if int(building.combat_cooldown) > 0:
			building.combat_state = "reloading"
			continue
		var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
		var tier_scale := 1.0 + float(int(building.tier) - 1) * 0.08
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

func _tower_targets(center: Vector2, tower_range: float, tower: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for monster in monsters:
		if int(monster.health) > 0 and center.distance_to(Vector2(float(monster.x), float(monster.y))) <= tower_range:
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

func _consume_tower_payload(building: Dictionary, tower: Dictionary) -> bool:
	var energy_cost := int(tower.get("energy_per_shot", 0))
	if energy_cost > 0:
		if int(resources.get("energy", 0)) < energy_cost:
			building.combat_state = "no_energy"
			return false
		resources.energy = int(resources.energy) - energy_cost
	var ammo_id := String(tower.get("ammo", ""))
	if ammo_id.is_empty():
		return true
	if String(building.get("ammo_resource", "")) != ammo_id:
		building.ammo_resource = ammo_id
		building.ammo_shots = 0
	var required_shots := int(tower.get("ammo_per_shot", 1))
	if int(building.get("ammo_shots", 0)) < required_shots:
		if int(resources.get(ammo_id, 0)) <= 0:
			building.combat_state = "no_ammo"
			return false
		resources[ammo_id] = int(resources[ammo_id]) - 1
		var ammo_definition := ContentRegistry.get_by_id(&"resources", StringName(ammo_id))
		building.ammo_shots = int(building.get("ammo_shots", 0)) + int(ammo_definition.get("shots", 1))
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
	max_influence = villagers.size() * (40 + roundi(ProgressionService.get_modifier(&"influence_per_villager")))
	influence = mini(maxi(0, max_influence - influence_reserved), influence + maxi(1, villagers.size() / 8))

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
				resources.raw_vegetables = maxi(0, int(resources.raw_vegetables) - 1)

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

func _cast_spell(payload: Dictionary) -> void:
	var spell_id := StringName(payload.get("spell_id", ""))
	var definition := ContentRegistry.get_by_id(&"spells", spell_id)
	if definition.is_empty():
		_emit_event(&"command_rejected", {"reason": "unknown_spell", "spell_id": spell_id})
		return
	var cost := int(definition.get("cost", 0))
	if not bool(mode_rules.get("unlimited_influence", false)) and influence < cost:
		_emit_event(&"command_rejected", {"reason": "insufficient_influence", "spell_id": spell_id})
		return
	var maintenance := int(definition.get("maintenance", 0)) if spell_id in [&"summon_labor_golem", &"summon_holy_golem"] else 0
	if not bool(mode_rules.get("unlimited_influence", false)) and maintenance > 0 and max_influence - influence_reserved < maintenance:
		_emit_event(&"command_rejected", {"reason": "insufficient_maintenance_capacity", "spell_id": spell_id})
		return
	if not bool(mode_rules.get("unlimited_influence", false)):
		influence -= cost
	var cell := Vector2i(int(payload.get("cell_x", 0)), int(payload.get("cell_y", 0)))
	var radius := _spell_radius(spell_id)
	match String(spell_id):
		"healing_aura", "regenerate", "divine_blessing":
			for villager in villagers:
				if Vector2(float(villager.x), float(villager.y)).distance_to(Vector2(cell)) <= radius:
					villager.health = mini(1000, int(villager.health) + (500 if spell_id == &"healing_aura" else 240))
					villager.faith = mini(1000, int(villager.faith) + 80)
		"harvest":
			for resource_node in resource_nodes:
				if Vector2(float(resource_node.x), float(resource_node.y)).distance_to(Vector2(cell)) <= radius and int(resource_node.amount) > 0:
					var amount := mini(12, int(resource_node.amount))
					resource_node.amount = int(resource_node.amount) - amount
					resources[resource_node.id] = mini(int(resource_caps.get(resource_node.id, 200)), int(resources.get(resource_node.id, 0)) + amount)
		"mend":
			for building in buildings:
				var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
				if center.distance_to(Vector2(cell)) <= radius:
					building.health = mini(int(building.max_health), int(building.health) + 800)
					building["burning"] = false
		"banish":
			for monster in monsters:
				if Vector2(float(monster.x), float(monster.y)).distance_to(Vector2(cell)) <= radius:
					monster.health = 0
		"lightning_bolt":
			_damage_monsters_in_radius(cell, radius, 650, &"electric")
		"magic_bolts":
			_damage_monsters_in_radius(cell, radius, 280, &"magic")
		"meteor":
			_damage_monsters_in_radius(cell, radius, 1200, &"magic_fire")
		"comet":
			_damage_monsters_in_radius(cell, radius, 2400, &"magic_ice")
		"construct":
			for building in buildings:
				var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5)
				if not bool(building.completed) and center.distance_to(Vector2(cell)) <= radius:
					building.progress = building.build_time
		"conjure_material":
			var resource_id := String(payload.get("resource_id", "wood"))
			if resources.has(resource_id):
				resources[resource_id] = mini(int(resource_caps.get(resource_id, 200)), int(resources.get(resource_id, 0)) + 16)
		"conjure_essence":
			resources.essence = int(resources.get("essence", 0)) + 3
		"resurrect":
			_resurrect_nearest_ghost(cell, radius)
		"motivate_land", "holy_wood", "holy_potatoes":
			_add_spell_resource_node(spell_id, cell)
		"dissolve":
			for corruption_key in corruption_cells.keys():
				var corruption_cell := _cell_from_key(String(corruption_key))
				if Vector2(corruption_cell).distance_to(Vector2(cell)) <= radius:
					corruption_cells.erase(corruption_key)
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
	ProgressionService.record(StringName("spells.cast.%s" % String(spell_id)))
	_emit_event(&"spell_cast", {"spell_id": spell_id, "cell_x": cell.x, "cell_y": cell.y, "radius": radius})

func _damage_monsters_in_radius(cell: Vector2i, radius: float, damage: int, damage_type: StringName = &"magic") -> void:
	for monster in monsters:
		if Vector2(float(monster.x), float(monster.y)).distance_to(Vector2(cell)) <= radius:
			_apply_damage_to_monster(monster, damage, damage_type)

func _add_spell_resource_node(spell_id: StringName, cell: Vector2i) -> void:
	var resource_id := "wood" if spell_id == &"holy_wood" else "raw_vegetables"
	resource_nodes.append({"entity_id": _next_id(), "id": resource_id, "x": cell.x, "y": cell.y, "amount": 32, "initial_amount": 32, "magical": true})

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
	var source_id := int(best.source_villager_id)
	for villager in villagers:
		if int(villager.id) == source_id:
			villager.health = 650
			villager.hunger = maxi(500, int(villager.hunger))
			villager.thirst = maxi(500, int(villager.thirst))
			villager.energy = 500
			villager.state = "resurrected"
			villager.ghost_created = false
			break
	resources.filled_eerie_vessel = int(resources.filled_eerie_vessel) - 1
	resources.empty_eerie_vessel = int(resources.get("empty_eerie_vessel", 0)) + 1
	ghosts.erase(best)
	ProgressionService.record(&"population.resurrected")

func _spell_radius(spell_id: StringName) -> float:
	return {
		"lightning_bolt": 2.5, "magic_bolts": 4.0, "meteor": 5.5, "comet": 9.0,
		"healing_aura": 8.0, "regenerate": 5.0, "divine_blessing": 6.0,
		"harvest": 7.0, "mend": 7.0, "banish": 6.0, "dissolve": 6.0, "construct": 5.0
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
	snapshot.event_ticks_remaining = event_ticks_remaining
	snapshot.paused = paused
	snapshot.speed = speed
	snapshot.population = villagers.size()
	snapshot.max_influence = max_influence
	snapshot.influence = influence
	snapshot.god_xp = god_xp
	snapshot.resources = resources.duplicate(true)
	snapshot.resource_caps = resource_caps.duplicate(true)
	snapshot.resource_rates = resource_rates.duplicate(true)
	snapshot.resource_nodes = resource_nodes.duplicate(true)
	snapshot.loose_items = loose_items.duplicate(true)
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
	var population_groups := {"children": 0, "adults": 0, "elders": 0, "animals": animals.size(), "golems": golems.size(), "ghosts": ghosts.size()}
	for villager in villagers:
		var key := String(villager.get("age_stage", "adult")) + "s"
		population_groups[key] = int(population_groups.get(key, 0)) + 1
	snapshot.population_groups = population_groups
	snapshot.villagers = villagers.duplicate(true)
	snapshot.animals = animals.duplicate(true)
	snapshot.golems = golems.duplicate(true)
	snapshot.monsters = monsters.duplicate(true)
	snapshot.ghosts = ghosts.duplicate(true)
	var corruption_positions: Array = []
	for corruption_key in corruption_cells:
		var cell := _cell_from_key(String(corruption_key))
		corruption_positions.append([cell.x, cell.y])
	snapshot.corruption_cells = corruption_positions
	snapshot.buildings = buildings.duplicate(true)
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
		"resources": resources.duplicate(true),
		"resource_caps": resource_caps.duplicate(true),
		"resource_rates": resource_rates.duplicate(true),
		"resource_rate_sample": resource_rate_sample.duplicate(true),
		"resource_rate_sample_tick": resource_rate_sample_tick,
		"next_resource_rate_tick": next_resource_rate_tick,
		"resource_nodes": resource_nodes.duplicate(true),
		"loose_items": loose_items.duplicate(true),
		"catjeet_trader": catjeet_trader.duplicate(true),
		"next_trade_arrival_tick": next_trade_arrival_tick,
		"jobs": jobs.duplicate(true),
		"villagers": villagers.duplicate(true),
		"animals": animals.duplicate(true),
		"golems": golems.duplicate(true),
		"monsters": monsters.duplicate(true),
		"ghosts": ghosts.duplicate(true),
		"corruption_cells": corruption_cells.duplicate(true),
		"buildings": buildings.duplicate(true),
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
		"next_entity_id": next_entity_id,
		"rng_state": rng.state,
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
	resources = state.get("resources", {}).duplicate(true)
	resource_caps = state.get("resource_caps", {}).duplicate(true)
	resource_rates = state.get("resource_rates", {}).duplicate(true)
	resource_rate_sample = state.get("resource_rate_sample", resources).duplicate(true)
	resource_rate_sample_tick = int(state.get("resource_rate_sample_tick", tick))
	next_resource_rate_tick = int(state.get("next_resource_rate_tick", tick + 100))
	resource_nodes.clear()
	for resource_node in state.get("resource_nodes", []):
		if resource_node is Dictionary:
			resource_nodes.append(resource_node.duplicate(true))
	loose_items.clear()
	for item in state.get("loose_items", []):
		if item is Dictionary:
			loose_items.append(item.duplicate(true))
	catjeet_trader = state.get("catjeet_trader", {}).duplicate(true)
	next_trade_arrival_tick = int(state.get("next_trade_arrival_tick", tick + 600))
	jobs = state.get("jobs", {}).duplicate(true)
	villagers.clear()
	for villager in state.get("villagers", []):
		if villager is Dictionary:
			villagers.append(villager.duplicate(true))
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
	buildings.clear()
	for building in state.get("buildings", []):
		if building is Dictionary:
			buildings.append(building.duplicate(true))
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
	next_entity_id = int(state.get("next_entity_id", 1))
	rng.state = int(state.get("rng_state", rng.state))
	_emit_snapshot()
	return true

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
