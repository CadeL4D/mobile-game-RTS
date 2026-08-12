extends Node

var failures: Array[String] = []
var registry: Node
var sim: Node
var saves: Node

func _ready() -> void:
	registry = get_node("/root/ContentRegistry")
	sim = get_node_or_null("/root/SimulationHost")
	saves = get_node_or_null("/root/SaveService")
	if sim == null or saves == null:
		failures.append("Required simulation/save autoloads failed to initialize")
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	if sim == null or saves == null:
		_finish()
		return
	_test_content()
	_test_sprite_ledger()
	_test_generation_determinism()
	_test_pathfinding()
	_test_simulation_and_goal()
	_test_early_economy()
	_test_resource_rates()
	_test_survival_mode_rules()
	_test_spell_commands()
	_test_golems_and_tower_combat()
	_test_monster_combat_model()
	_test_ranger_doggo_equipment_combat()
	_test_medical_and_maintenance_services()
	_test_faith_ghost_resurrection()
	_test_weather_and_events()
	_test_population_and_animals()
	_test_roads_and_walls()
	_test_building_upgrades()
	_test_make_maintain_production()
	_test_decay_and_trash_chain()
	_test_marketplace_trade()
	_test_meta_progression()
	_test_regional_campaign()
	_test_map_packages()
	_test_save_round_trip()
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("TEST RESULT: PASS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("TEST RESULT: FAIL (%d failures)" % failures.size())
		get_tree().quit(1)

func _assert(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _place_sandbox_building(building_id: StringName) -> Dictionary:
	var definition: Dictionary = registry.get_by_id(&"buildings", building_id)
	var footprint_data: Array = definition.get("footprint", [5, 5])
	var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
	var center: Vector2i = sim.blueprint.starting_cell
	for radius in range(0, 57, 4):
		for offset in [Vector2i(radius, 0), Vector2i(-radius, 0), Vector2i(0, radius), Vector2i(0, -radius), Vector2i(radius, radius), Vector2i(-radius, radius), Vector2i(radius, -radius), Vector2i(-radius, -radius)]:
			var cell: Vector2i = center + offset
			if not sim.blueprint.is_buildable(cell, footprint) or sim._footprint_overlaps(cell, footprint):
				continue
			var count_before: int = sim.buildings.size()
			sim.submit(GameCommand.place_building(sim.tick, building_id, cell))
			for _index in 2:
				sim.advance_tick()
			if sim.buildings.size() > count_before:
				return sim.buildings.back()
	return {}

func _test_content() -> void:
	var report: Dictionary = registry.validation_report
	_assert(bool(report.get("valid", false)), "Content registry must validate: %s" % str(report.get("errors", [])))
	_assert(registry.get_all(&"modes").size() == 6, "Exactly six game modes are required")
	_assert(registry.get_all(&"regions").size() == 45, "Exactly 45 world regions are required")
	_assert(registry.get_all(&"jobs").size() == 25, "Exactly 25 workforce jobs are required")
	_assert(registry.get_all(&"buildings").size() >= 75, "Building catalog is unexpectedly incomplete")
	_assert(registry.get_all(&"spells").size() >= 30, "Spell catalog is unexpectedly incomplete")
	_assert(registry.get_all(&"achievements").size() == 113, "Official Steam achievement catalog must contain exactly 113 entries")
	_assert(registry.get_all(&"actors").size() >= 25, "Actor catalog is unexpectedly incomplete")
	_assert(registry.get_all(&"events").size() >= 12, "Event catalog is unexpectedly incomplete")
	_assert(registry.get_all(&"town_center_tiers").size() == 15, "Camp-to-Castle progression must contain 15 stages")
	_assert(registry.get_all(&"music_tracks").size() == 16, "Original soundtrack catalog must reserve 16 adaptive tracks")

func _test_sprite_ledger() -> void:
	var file := FileAccess.open("res://art/sprite_ledger.json", FileAccess.READ)
	_assert(file != null, "The exhaustive sprite-production ledger must exist")
	if file == null:
		return
	var ledger: Variant = JSON.parse_string(file.get_as_text())
	_assert(ledger is Dictionary and ledger.has("sprites"), "Sprite ledger must parse into a versioned sprite catalog")
	if ledger is not Dictionary or not ledger.has("sprites"):
		return
	_assert(String(ledger.get("projection", "")) == "orthographic_top_down_90" and int(ledger.get("logical_cell_pixels", 0)) == 8, "Sprite ledger must lock the strict top-down 8-pixel world contract")
	var by_id: Dictionary = {}
	for sprite in ledger.sprites:
		var sprite_id := String(sprite.get("id", ""))
		_assert(not sprite_id.is_empty() and not by_id.has(sprite_id), "Every sprite deliverable must have one unique stable id: %s" % sprite_id)
		by_id[sprite_id] = sprite
		if bool(sprite.get("shipping", false)):
			_assert(String(sprite.get("status", "")) in ["PENDING", "PROCEDURAL_PLACEHOLDER", "IN_REVIEW", "APPROVED"], "Shipping sprite %s must expose an explicit production status" % sprite_id)
	for building in registry.get_all(&"buildings"):
		if String(building.category) == "legacy":
			var legacy_id := "building.%s" % String(building.id)
			_assert(by_id.has(legacy_id) and String(by_id[legacy_id].get("status", "")) == "LEGACY_REMOVED", "Legacy visual %s must remain explicitly excluded" % legacy_id)
			continue
		for tier in range(1, int(building.get("tiers", 1)) + 1):
			var sprite_id := "building.%s.tier_%d" % [String(building.id), tier]
			_assert(by_id.has(sprite_id), "Missing building tier sprite deliverable %s" % sprite_id)
			if by_id.has(sprite_id):
				var states: Array = by_id[sprite_id].get("states", [])
				_assert("complete" in states and "construction_50" in states and "damaged_severe" in states and "destroyed" in states, "Building deliverable %s lacks mandatory lifecycle states" % sprite_id)
	for category_id in [&"actors", &"jobs", &"resources", &"spells", &"biomes", &"events"]:
		var family: String = {"actors": "actor", "jobs": "job_overlay", "resources": "resource", "spells": "spell", "biomes": "terrain", "events": "event"}[String(category_id)]
		for entry in registry.get_all(category_id):
			var sprite_id := "%s.%s" % [family, String(entry.id)]
			_assert(by_id.has(sprite_id), "Missing %s sprite deliverable %s" % [family, sprite_id])
	var world_view_script = preload("res://presentation/scripts/world_view.gd")
	var icon_factory = preload("res://presentation/scripts/pixel_icon_factory.gd").new()
	for building in registry.get_all(&"buildings"):
		if String(building.category) == "legacy": continue
		var icon: Texture2D = icon_factory.building(StringName(building.id), StringName(building.category), 24)
		_assert(icon != null and icon.get_width() == 24 and icon.get_height() == 24, "Building %s lacks a native 24-pixel menu icon" % building.id)
	for job in registry.get_all(&"jobs"):
		var icon: Texture2D = icon_factory.job(StringName(job.id), Color(job.color), 24)
		_assert(icon != null and icon.get_width() == 24, "Job %s lacks a native workforce icon" % job.id)
	for resource in registry.get_all(&"resources"):
		var icon: Texture2D = icon_factory.resource(StringName(resource.id), 20)
		_assert(icon != null and icon.get_width() == 20, "Resource %s lacks a native inventory icon" % resource.id)
	for event in registry.get_all(&"events"):
		_assert(world_view_script.EVENT_PIXEL_COLORS.has(StringName(event.id)), "Event %s lacks a native-pixel visual contract" % event.id)
		var icon: Texture2D = icon_factory.event(StringName(event.id), 24)
		_assert(icon != null and icon.get_width() == 24, "Event %s lacks a native warning icon" % event.id)
	for world_object_id in ["tree", "stump", "dead_tree", "rock", "iron_rock", "gold_rock", "crystal", "crop", "wild_food", "mushroom", "flower", "hole", "shallow_water", "deep_water", "fire", "ash", "rubble", "corruption", "corpse", "loot_marker"]:
		_assert(world_view_script.WORLD_OBJECT_PIXEL_COLORS.has(StringName(world_object_id)), "World object %s lacks a native-pixel renderer contract" % world_object_id)
	for ui_icon_id in ["hud_population", "hud_resources", "hud_influence", "hud_energy", "hud_faith", "hud_time_weather", "hud_speed", "hud_problems", "construction_categories", "harvest_tools", "terrain_tools", "road_tools", "wall_tools", "minimap", "data_maps", "selection", "validity", "health_work_bars", "thoughts_warnings", "goals_perks_chests", "trade_migration_courier", "editor_tools", "touch_gestures"]:
		var icon: Texture2D = icon_factory.ui(StringName(ui_icon_id), 24)
		_assert(icon != null and icon.get_width() == 24, "UI family %s lacks a native mobile icon" % ui_icon_id)
	for spell in registry.get_all(&"spells"):
		_assert(world_view_script.SPELL_PIXEL_COLORS.has(StringName(spell.id)), "Spell %s lacks a unique native-pixel color contract" % spell.id)
		var icon: Texture2D = icon_factory.spell(StringName(spell.id), StringName(spell.group), 24)
		_assert(icon != null and icon.get_width() == 24, "Spell %s lacks a native god-power icon" % spell.id)
	var effect_view = world_view_script.new()
	effect_view.add_spell_effect(&"lightning_bolt", Vector2i(4, 5), 2.5)
	_assert(effect_view.visual_effects.size() == 1 and int(effect_view.visual_effects[0].end_tick) > int(effect_view.visual_effects[0].started_tick), "Spell cast visuals must be presentation-only tick-timed effects")
	effect_view.free()
	_assert(ledger.sprites.size() >= 450, "Sprite ledger must remain exhaustive across all visual families")

func _test_generation_determinism() -> void:
	var generator := RegionGenerator.new()
	var a := generator.generate(424242, &"applemeadow", &"forest")
	var b := generator.generate(424242, &"applemeadow", &"forest")
	_assert(a.tiles == b.tiles, "Identical region seeds must produce identical terrain")
	_assert(a.resource_nodes == b.resource_nodes, "Identical region seeds must produce identical resources")
	_assert(bool(a.validation_report.get("valid", false)), "Generated region must pass survival validators: %s" % a.validation_report)

func _test_pathfinding() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(5150, &"applemeadow", &"forest")
	var finder = preload("res://core/simulation/grid_pathfinder.gd").new()
	finder.configure(blueprint)
	var start := blueprint.starting_cell
	var water_target := start + Vector2i(0, 28)
	var first: Array = finder.find_path(start, water_target)
	var second: Array = finder.find_path(start, water_target)
	_assert(not first.is_empty(), "Pathfinder must route to the nearest walkable shore beside a water target")
	_assert(first == second, "Pathfinding must be deterministic")
	for point in first:
		_assert(blueprint.get_tile(Vector2i(int(point[0]), int(point[1]))) != RegionGenerator.Tile.DEEP_WATER, "Worker paths must not cross deep water")

func _test_simulation_and_goal() -> void:
	ProgressionService.reset_profile_progress()
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(9898, &"applemeadow", &"forest")
	sim.start_region(blueprint, registry.get_by_id(&"modes", &"traditional"))
	_assert(sim.villagers.size() == 20, "Fresh settlement must start with 20 villagers")
	var xp_before: int = sim.god_xp
	var camp_cell := blueprint.starting_cell - Vector2i(6, 6)
	sim.submit(GameCommand.place_building(sim.tick, &"camp", camp_cell))
	sim.advance_tick()
	_assert(int(sim.task_board.debug_summary().get("total", 0)) >= 1, "Construction must create a global task-board entry")
	_assert(int(sim.task_board.debug_summary().get("claimed", 0)) >= 1, "Builders must reserve construction work")
	for _index in 99:
		sim.advance_tick()
	_assert(sim.buildings.size() == 1, "Camp placement should create one construction site")
	_assert(bool(sim.buildings[0].completed), "Builders should complete the first Camp")
	_assert(bool(sim.goals.build_first_camp.completed), "First Camp should complete the first goal")
	_assert(sim.god_xp == xp_before + 60, "First goal should award 60 God XP")
	_assert(ProgressionService.completed.has("you_already_lost"), "First Camp must unlock the matching offline achievement")
	var initial_hash: String = sim.compute_state_hash()
	_assert(not initial_hash.is_empty(), "Simulation state hash must exist")

func _test_early_economy() -> void:
	var center: Vector2i = sim.blueprint.starting_cell
	sim.resources.wood = 180
	sim.resources.rock = 180
	var food_before := int(sim.resources.raw_vegetables)
	var water_before := int(sim.resources.clean_water)
	sim.submit(GameCommand.place_building(sim.tick, &"housing", center + Vector2i(-18, -18)))
	sim.submit(GameCommand.place_building(sim.tick, &"farm", center + Vector2i(9, -18)))
	sim.submit(GameCommand.place_building(sim.tick, &"well", center + Vector2i(-18, 10)))
	for _index in 500:
		sim.advance_tick()
	_assert(sim.buildings.size() == 4, "Early economy scenario should place Camp, Housing, Farm, and Well")
	_assert(sim.buildings.all(func(building: Dictionary) -> bool: return bool(building.completed)), "Early economy buildings must complete without task deadlock")
	_assert(sim.housing_capacity == 8, "Completed base Housing must provide eight tested housing spaces")
	_assert(int(sim.jobs.farmers.max) == 4 and int(sim.jobs.farmers.current) == 4, "Completed Farm must expose and fill its farmer quota")
	_assert(int(sim.resources.raw_vegetables) > food_before, "Staffed Farm must produce vegetables")
	_assert(int(sim.resources.clean_water) > water_before, "Completed Well must produce clean water")
	_assert(int(sim.task_board.debug_summary().get("claimed", 0)) >= 1, "Farmers must reserve harvest work after construction")

func _test_resource_rates() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(9393, &"applemeadow", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(blueprint, sandbox)
	var farm: Dictionary = _place_sandbox_building(&"farm")
	_assert(not farm.is_empty(), "Resource-rate test Farm must find a valid generated footprint")
	sim.resources.raw_vegetables = 0
	sim.resource_rate_sample = sim.resources.duplicate(true)
	sim.resource_rate_sample_tick = sim.tick
	sim.next_resource_rate_tick = sim.tick + 100
	for _index in 200:
		sim.advance_tick()
	_assert(float(sim.resource_rates.get("raw_vegetables", 0.0)) > 0.0, "Resource histories must report deterministic positive production per day")
	var rate_state: Dictionary = sim.export_state()
	var rate_before := float(sim.resource_rates.get("raw_vegetables", 0.0))
	sim.import_state(rate_state)
	_assert(is_equal_approx(float(sim.resource_rates.get("raw_vegetables", 0.0)), rate_before), "Resource rates and sample windows must survive save/load")
	_test_simulation_and_goal()

func _test_survival_mode_rules() -> void:
	var generator := RegionGenerator.new()
	var hostile_blueprint := generator.generate(8128, &"applemeadow", &"forest")
	sim.start_region(hostile_blueprint, registry.get_by_id(&"modes", &"nightmare"))
	var corruption_before: int = sim.corruption_cells.size()
	for _index in 105:
		sim.advance_tick()
	_assert(sim.corruption_cells.size() >= corruption_before, "Hostile corruption must persist or spread in Nightmare")
	_assert(sim.monsters.size() >= 1, "Nightmare must spawn a hostile wave on the first day")
	var peaceful_blueprint := generator.generate(8128, &"applemeadow", &"forest")
	sim.start_region(peaceful_blueprint, registry.get_by_id(&"modes", &"peaceful"))
	var peaceful_corruption: int = sim.corruption_cells.size()
	for _index in 1300:
		sim.advance_tick()
	_assert(sim.monsters.is_empty(), "Peaceful mode must never spawn hostile waves")
	_assert(sim.corruption_cells.size() == peaceful_corruption, "Peaceful corruption must not spread")
	# Restore an economy scenario for the save round-trip test.
	_test_simulation_and_goal()

func _test_spell_commands() -> void:
	var center: Vector2i = sim.blueprint.starting_cell
	var influence_before: int = sim.influence
	sim.submit(GameCommand.cast_spell(sim.tick, &"conjure_material", center, {"resource_id": "wood"}))
	sim.advance_tick()
	_assert(sim.influence == influence_before - int(registry.get_by_id(&"spells", &"conjure_material").cost), "Spell commands must spend persistent influence")
	var harvest_node: Dictionary = sim.resource_nodes[0]
	var harvest_before: int = int(harvest_node.amount)
	sim.influence = sim.max_influence
	sim.submit(GameCommand.cast_spell(sim.tick, &"harvest", Vector2i(int(harvest_node.x), int(harvest_node.y))))
	sim.advance_tick()
	_assert(int(harvest_node.amount) < harvest_before, "Harvest spell must deplete resource nodes in its target radius")
	var influence_after_harvest: int = sim.influence
	sim.submit(GameCommand.cast_spell(sim.tick, &"comet", center))
	sim.advance_tick()
	_assert(sim.influence == influence_after_harvest, "Unaffordable spell commands must be rejected without making influence negative")

func _test_golems_and_tower_combat() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(7722, &"applemeadow", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(blueprint, sandbox)
	sim.resources.energy = 1000
	var combobulator: Dictionary = _place_sandbox_building(&"crystal_golem_combobulator")
	_assert(not combobulator.is_empty(), "Crystal Golem Combobulator must find a valid generated footprint")
	for _index in 260:
		sim.advance_tick()
	_assert(sim.golems.size() == 1 and String(sim.golems[0].definition_id) == "crystal_golem", "Powered Combobulators must deterministically charge and deploy their typed golem")
	_assert(int(combobulator.get("golem_count", 0)) == 1 and String(combobulator.get("operation_state", "")) == "at_capacity", "Combobulators must expose mobile-readable capacity and operation state")
	var crystal_golem: Dictionary = sim.golems[0]
	var health_before_degradation := int(crystal_golem.health)
	sim.resources.energy = 0
	for _index in 25:
		sim.advance_tick()
	_assert(int(crystal_golem.health) < health_before_degradation and String(crystal_golem.state) == "degrading", "Manufactured golems must degrade when their energy maintenance fails")
	var recombobulator: Dictionary = _place_sandbox_building(&"recombobulator_tower")
	_assert(not recombobulator.is_empty(), "Recombobulator Tower must find a valid generated footprint")
	crystal_golem.x = float(recombobulator.x) + float(recombobulator.width) * 0.5
	crystal_golem.y = float(recombobulator.y) + float(recombobulator.height) * 0.5 + 2.0
	sim.resources.energy = 50
	var damaged_health := int(crystal_golem.health)
	sim._update_towers()
	_assert(int(crystal_golem.health) > damaged_health and String(recombobulator.get("combat_state", "")) == "repairing", "Recombobulator Towers must consume energy to repair damaged friendly golems")
	var ballista: Dictionary = _place_sandbox_building(&"ballista_tower")
	_assert(not ballista.is_empty(), "Ballista Tower must find a valid generated footprint")
	var tower_center := Vector2(float(ballista.x) + float(ballista.width) * 0.5, float(ballista.y) + float(ballista.height) * 0.5)
	var target := {
		"id": 99001, "definition_id": "headless", "name": "Tower Target", "x": tower_center.x + 2.0, "y": tower_center.y,
		"target_x": tower_center.x, "target_y": tower_center.y, "health": 1000, "max_health": 1000, "damage": 0, "speed": 0.0,
		"state": "test", "task_id": 0, "task_kind": "", "task_progress": 0, "path": [], "path_index": 0, "path_goal_x": -1, "path_goal_y": -1, "stuck_ticks": 0,
	}
	sim.monsters.clear()
	sim.monsters.append(target)
	sim.resources.ballista_bolts = 1
	sim._update_towers()
	_assert(int(target.health) < 1000 and int(sim.resources.ballista_bolts) == 0 and int(ballista.get("ammo_shots", 0)) == 19, "Ballista Towers must load stacked bolts, consume one shot, and deal their typed damage")
	ballista.combat_cooldown = 0
	ballista.ammo_shots = 0
	sim.resources.ballista_bolts = 0
	sim._update_towers()
	_assert(String(ballista.get("combat_state", "")) == "no_ammo", "Ammunition towers must report a deterministic no-ammo state instead of firing")
	var summoned_blueprint := generator.generate(7723, &"applemeadow", &"forest")
	sim.start_region(summoned_blueprint, registry.get_by_id(&"modes", &"traditional"))
	sim.max_influence = 2000
	sim.influence = 2000
	var summon_cell := summoned_blueprint.starting_cell
	sim.submit(GameCommand.cast_spell(sim.tick, &"summon_labor_golem", summon_cell))
	sim.advance_tick()
	_assert(sim.golems.size() == 1 and bool(sim.golems[0].summoned) and sim.influence_reserved == 270, "Summon Labor Golem must create a persistent worker and reserve its influence maintenance")
	var summoned_snapshot: SimulationSnapshot = sim.get_snapshot()
	_assert(summoned_snapshot.golems.size() == 1, "Golems must be included in immutable presentation snapshots")
	var summoned_state: Dictionary = sim.export_state()
	_assert(sim.import_state(summoned_state) and sim.golems.size() == 1, "Golem state and maintenance reservations must survive deterministic save/load")
	sim.submit(GameCommand.cast_spell(sim.tick, &"dispel_golem", summon_cell))
	sim.advance_tick()
	_assert(sim.golems.is_empty() and sim.influence_reserved == 0, "Dispel Golem must remove the nearest golem and release maintenance influence")
	_assert(int(ProgressionService.counters.get("spells.dispelled.golem_or_building", 0)) >= 1, "Golem creation and dispel actions must feed official achievement counters")
	_test_simulation_and_goal()

func _test_monster_combat_model() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(8814, &"applemeadow", &"forest")
	sim.start_region(blueprint, registry.get_by_id(&"modes", &"sandbox"))
	var skeleton: Dictionary = sim._spawn_monster_actor(&"skeleton", Vector2(blueprint.starting_cell))
	var health_before_piercing := int(skeleton.health)
	var piercing_applied: int = sim._apply_damage_to_monster(skeleton, 100, &"piercing")
	var crushing_applied: int = sim._apply_damage_to_monster(skeleton, 100, &"crushing")
	_assert(piercing_applied == 65 and crushing_applied == 135 and int(skeleton.health) == health_before_piercing - 200, "Typed monster resistances must reduce piercing and amplify crushing damage deterministically")
	var spectre: Dictionary = sim._spawn_monster_actor(&"spectre", Vector2(blueprint.starting_cell))
	var spectre_regular: int = sim._apply_damage_to_monster(spectre, 100, &"regular")
	var spectre_magic: int = sim._apply_damage_to_monster(spectre, 100, &"magic")
	_assert(spectre_regular == 25 and spectre_magic == 120, "Spectres must strongly resist mundane damage while remaining vulnerable to magic")
	var phase_start := Vector2(float(spectre.x), float(spectre.y))
	sim._move_spectre_toward(spectre, phase_start + Vector2(4, 0), 0.5)
	_assert(String(spectre.state) == "phasing" and float(spectre.x) > phase_start.x, "Spectres must use direct wall-crossing movement rather than settlement path solids")
	var fire_elemental: Dictionary = sim._spawn_monster_actor(&"fire_elemental", Vector2(blueprint.starting_cell))
	var test_building := {"id": 78001, "health": 300, "max_health": 300, "status_effects": {}, "burning": false}
	sim._apply_monster_hit(fire_elemental, test_building, &"building")
	_assert(bool(test_building.burning) and int(test_building.status_effects.get("burning", 0)) > 0, "Fire Elemental hits must ignite buildings through the common status model")
	var burning_health := int(test_building.health)
	sim._update_actor_status_effects(test_building)
	_assert(int(test_building.health) < burning_health, "Burning status must apply deterministic ongoing damage")
	var zombie: Dictionary = sim._spawn_monster_actor(&"zombie", Vector2(blueprint.starting_cell))
	var victim: Dictionary = sim.villagers[0]
	var victim_start_health := int(victim.health)
	sim._apply_monster_hit(zombie, victim, &"villager")
	_assert(int(victim.health) < victim_start_health and int(victim.status_effects.get("infection", 0)) > 0, "Zombie attacks must damage and infect villagers")
	victim.health = 0
	var zombies_before: int = sim.monsters.filter(func(monster: Dictionary) -> bool: return String(monster.definition_id) == "zombie").size()
	sim._update_death_and_ghosts()
	var zombies_after: int = sim.monsters.filter(func(monster: Dictionary) -> bool: return String(monster.definition_id) == "zombie").size()
	_assert(zombies_after == zombies_before + 1, "Infected villager death must create a zombie exactly once")
	_test_simulation_and_goal()

func _test_ranger_doggo_equipment_combat() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(8815, &"applemeadow", &"forest")
	sim.start_region(blueprint, registry.get_by_id(&"modes", &"sandbox"))
	var ranger: Dictionary = sim.villagers[4]
	ranger.job = "rangers"
	sim.resources.bow = 1
	sim.resources.quiver = 2
	sim.resources.iron_body_armor = 1
	sim.resources.iron_helmet = 1
	sim.tick = 100
	sim._update_equipment()
	_assert(String(ranger.equipment.weapon.id) == "bow" and int(ranger.equipment.ammo.shots) == 40, "Adult Rangers must equip a stocked bow and its shot-carrying quiver")
	_assert(String(ranger.equipment.body.id) == "iron_body_armor" and String(ranger.equipment.helmet.id) == "iron_helmet", "Rangers must claim available body and helmet armor without duplicating inventory")
	_assert(int(sim.resources.bow) == 0 and int(sim.resources.quiver) == 1, "Equipping a Ranger must conserve stored equipment resources")
	var target: Dictionary = sim._spawn_monster_actor(&"headless", Vector2(float(ranger.x) + 4.0, float(ranger.y)))
	var target_health := int(target.health)
	sim._ranger_try_combat(ranger)
	_assert(int(target.health) < target_health and int(ranger.equipment.ammo.shots) == 39 and String(ranger.state) == "fighting", "A bow Ranger must fire at range, consume one quiver shot, and damage the target")
	var zombie: Dictionary = sim._spawn_monster_actor(&"zombie", Vector2(float(ranger.x), float(ranger.y)))
	var ranger_health := int(ranger.health)
	var body_durability := int(ranger.equipment.body.durability)
	sim._apply_monster_hit(zombie, ranger, &"villager")
	_assert(int(ranger.health) < ranger_health and int(ranger.equipment.body.durability) == body_durability - 1, "Armor must mitigate hostile damage and lose durability through the shared hit path")
	var doggo: Dictionary = {}
	for animal in sim.animals:
		if String(animal.definition_id) == "doggo":
			doggo = animal
			break
	_assert(not doggo.is_empty(), "Defender test requires a starting domesticated Doggo")
	var doggo_target: Dictionary = sim._spawn_monster_actor(&"small_slime", Vector2(float(doggo.x) + 1.0, float(doggo.y)))
	var doggo_target_health := int(doggo_target.health)
	doggo.attack_cooldown = 0
	sim._doggo_try_combat(doggo)
	_assert(int(doggo_target.health) < doggo_target_health and String(doggo.state) == "fighting", "Domesticated Doggos must defend the village with typed melee damage")
	sim._damage_equipped_item(ranger, "weapon", 9999)
	_assert(not ranger.equipment.has("weapon") and int(ProgressionService.counters.get("equipment.broken", 0)) >= 1, "Equipment at zero durability must break once and emit persistent progression statistics")
	_test_simulation_and_goal()

func _test_medical_and_maintenance_services() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(9155, &"applemeadow", &"forest")
	sim.start_region(blueprint, registry.get_by_id(&"modes", &"sandbox"))
	var maintenance: Dictionary = _place_sandbox_building(&"maintenance_building")
	var clinic: Dictionary = _place_sandbox_building(&"clinic")
	var housing: Dictionary = _place_sandbox_building(&"housing")
	_assert(not maintenance.is_empty() and not clinic.is_empty() and not housing.is_empty(), "Service scenario must place Maintenance, Clinic, and Housing workplaces")
	var maintainer: Dictionary = {}
	var medic: Dictionary = {}
	for villager in sim.villagers:
		if String(villager.job) == "maintainers" and maintainer.is_empty(): maintainer = villager
		if String(villager.job) == "medics" and medic.is_empty(): medic = villager
	_assert(not maintainer.is_empty() and not medic.is_empty(), "Completed service buildings must expose and fill Maintainer and Medic quotas")
	sim.resources.hammer = 1
	sim.tick = 100
	sim._update_equipment()
	_assert(String(maintainer.get("equipment", {}).get("tool", {}).get("id", "")) == "hammer", "Maintainers must claim an available Hammer as a durable work tool")
	maintainer.x = float(housing.x) + float(housing.width) * 0.5
	maintainer.y = float(housing.y) + float(housing.height) * 0.5
	housing.health = int(housing.max_health) - 120
	housing.repair_batch_remaining = 0
	sim.resources.wood = 2
	sim.resources.rock = 0
	var repair_materials_before := int(ProgressionService.counters.get("maintenance.repair_materials_consumed", 0))
	sim.submit(GameCommand.set_building_work(sim.tick, int(housing.id), &"prioritize_repair", true))
	for _index in 25: sim.advance_tick()
	_assert(int(housing.health) == int(housing.max_health), "Maintainers must finish a prioritized damaged building without leaving a partial-health deadlock")
	_assert(int(ProgressionService.counters.get("maintenance.repair_materials_consumed", 0)) == repair_materials_before + 1 and String(housing.service_state) == "repaired", "One repair material batch must be consumed exactly once and expose the completed service state")
	_assert(not bool(housing.repair_designated) and int(maintainer.equipment.tool.durability) < int(maintainer.equipment.tool.max_durability), "Repair completion must clear priority and consume Hammer durability")
	housing.health = int(housing.max_health) - 40
	housing.repair_batch_remaining = 0
	sim.resources.wood = 0
	sim.resources.rock = 0
	var stalled_health := int(housing.health)
	var stalled_material_count := int(ProgressionService.counters.get("maintenance.repair_materials_consumed", 0))
	for _index in 15: sim.advance_tick()
	_assert(int(housing.health) == stalled_health and String(housing.service_state) == "missing_repair_material" and int(ProgressionService.counters.get("maintenance.repair_materials_consumed", 0)) == stalled_material_count, "Repair work must wait visibly without consuming or creating material when every valid input is missing")
	sim.resources.wood = 1
	for _index in 15: sim.advance_tick()
	_assert(int(housing.health) == int(housing.max_health) and int(ProgressionService.counters.get("maintenance.repair_materials_consumed", 0)) == stalled_material_count + 1, "A stalled Maintainer must resume the same reservation and consume one valid material batch when supplies arrive")
	var patient: Dictionary = sim.villagers[12]
	patient.x = float(medic.x)
	patient.y = float(medic.y)
	patient.health = 650
	patient.status_effects = {"infection": 300}
	sim.resources.medkit = 1
	for _index in 30: sim.advance_tick()
	_assert(int(patient.health) >= 990 and not patient.status_effects.has("infection") and int(sim.resources.medkit) == 0, "Medics must prioritize a severe infected patient, consume one Medkit, heal, and cure infection")
	var waiting_patient: Dictionary = sim.villagers[13]
	waiting_patient.x = float(medic.x)
	waiting_patient.y = float(medic.y)
	waiting_patient.health = 800
	sim.resources.bandage = 0
	sim.resources.medkit = 0
	sim.resources.healing_potion = 0
	for _index in 25: sim.advance_tick()
	_assert(int(waiting_patient.health) == 800 and String(waiting_patient.get("medical_state", "")) == "awaiting_supplies", "Medics must expose a stable awaiting-supplies state without free healing")
	sim.resources.bandage = 1
	for _index in 25: sim.advance_tick()
	_assert(int(waiting_patient.health) == 1000 and int(sim.resources.bandage) == 0, "Waiting medical work must resume and consume the newly delivered Bandage")
	var housing_id := int(housing.id)
	sim.resources.wood = 0
	sim.resources.rock = 0
	sim.submit(GameCommand.set_building_work(sim.tick, housing_id, &"dismantle", true))
	for _index in 40: sim.advance_tick()
	_assert(sim._find_building(housing_id).is_empty(), "A confirmed Maintainer dismantle task must remove the footprint and release its reservation")
	_assert(int(sim.resources.get("wood", 0)) + int(sim.resources.get("rock", 0)) > 0, "Dismantling must salvage a bounded fraction of original construction materials")
	_assert(int(ProgressionService.counters.get("maintenance.buildings_dismantled", 0)) >= 1 and int(ProgressionService.counters.get("medical.treatments_completed", 0)) >= 2, "Maintenance and medicine actions must feed persistent service statistics")
	var clinic_id := int(clinic.id)
	sim.submit(GameCommand.set_building_work(sim.tick, clinic_id, &"dismantle", true))
	sim.advance_tick()
	sim.submit(GameCommand.set_building_work(sim.tick, clinic_id, &"dismantle", false))
	sim.advance_tick()
	_assert(not sim._find_building(clinic_id).is_empty() and not bool(clinic.dismantle_designated), "Canceling dismantle must preserve the building and remove the pending work designation")
	var service_state: Dictionary = sim.export_state()
	_assert(sim.import_state(service_state) and not sim._find_building(clinic_id).is_empty(), "Service designations, worker equipment, patient states, and task reservations must survive save/load")
	_test_simulation_and_goal()

func _test_faith_ghost_resurrection() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(9991, &"applemeadow", &"forest")
	var sandbox_rules: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(blueprint, sandbox_rules)
	var center := blueprint.starting_cell
	sim.submit(GameCommand.place_building(sim.tick, &"essence_altar", center + Vector2i(-12, -12)))
	sim.submit(GameCommand.place_building(sim.tick, &"essence_collector", center + Vector2i(6, -12)))
	sim.submit(GameCommand.place_building(sim.tick, &"reliquary", center + Vector2i(-4, 7)))
	for _index in 180:
		sim.advance_tick()
	_assert(int(sim.resources.get("essence", 0)) > 0 or int(sim.resources.get("energy", 0)) > 0, "Occultist prayer must generate essence and collector energy")
	_assert(int(sim.resources.get("energy", 0)) > 0, "Essence Collector must convert essence at three energy each")
	sim.resources.empty_eerie_vessel = 1
	var victim: Dictionary = sim.villagers[0]
	victim.health = 0
	for _index in 3:
		sim.advance_tick()
	_assert(sim.ghosts.size() == 1, "Villager death must create one ghost")
	_assert(bool(sim.ghosts[0].bound), "A completed Reliquary with an empty vessel must bind a nearby ghost")
	_assert(int(sim.resources.filled_eerie_vessel) == 1, "Binding a ghost must create one filled Eerie Vessel")
	var ghost_cell := Vector2i(roundi(float(sim.ghosts[0].x)), roundi(float(sim.ghosts[0].y)))
	sim.submit(GameCommand.cast_spell(sim.tick, &"resurrect", ghost_cell))
	sim.advance_tick()
	_assert(int(victim.health) > 0 and sim.ghosts.is_empty(), "Resurrect must restore the bound villager and consume the ghost")
	_assert(int(sim.resources.empty_eerie_vessel) == 1 and int(sim.resources.filled_eerie_vessel) == 0, "Resurrection must return the emptied Eerie Vessel")
	# Restore the deterministic camp scenario used by save tests.
	_test_simulation_and_goal()

func _test_weather_and_events() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(4040, &"applemeadow", &"forest")
	var rules: Dictionary = registry.get_by_id(&"modes", &"traditional").duplicate(true)
	rules.disasters = true
	rules.weather = true
	sim.start_region(blueprint, rules)
	sim.next_weather_tick = 1
	for _index in 2:
		sim.advance_tick()
	_assert(sim.next_weather_tick > sim.tick, "Weather scheduling must advance deterministically")
	var season_one: StringName = sim._season_for_day(1)
	var season_six: StringName = sim._season_for_day(6)
	_assert(season_one == &"Spring" and season_six == &"Summer", "Five-day seasons must advance from Spring to Summer")
	sim.next_event_tick = sim.tick + 1
	for _index in 2:
		sim.advance_tick()
	_assert(not sim.active_event.is_empty() and sim.event_ticks_remaining > 0, "Enabled disasters must schedule a persisted active event")
	var peaceful: Dictionary = registry.get_by_id(&"modes", &"peaceful").duplicate(true)
	peaceful.disasters = false
	peaceful.weather = false
	sim.start_region(blueprint, peaceful)
	sim.next_event_tick = 1
	for _index in 20:
		sim.advance_tick()
	_assert(sim.active_event.is_empty() and sim.weather == &"clear", "Disabled weather/disasters must remain clear and inactive")
	_test_simulation_and_goal()

func _test_population_and_animals() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(6161, &"applemeadow", &"forest")
	var sandbox_rules: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(blueprint, sandbox_rules)
	_assert(sim.animals.size() == 18, "Fresh regions must seed the first wild/domesticated animal population")
	var child_count := 0
	for villager in sim.villagers:
		if String(villager.age_stage) == "child":
			child_count += 1
	_assert(child_count == 3, "Fresh population must include child life stages")
	var center := blueprint.starting_cell
	sim.submit(GameCommand.place_building(sim.tick, &"housing", center + Vector2i(-18, -18)))
	sim.submit(GameCommand.place_building(sim.tick, &"housing", center + Vector2i(10, -18)))
	for _index in 3:
		sim.advance_tick()
	var population_before: int = sim.villagers.size()
	for villager in sim.villagers:
		if String(villager.sex) == "female" and String(villager.age_stage) == "adult":
			sim._birth_child(villager)
			break
	_assert(sim.villagers.size() == population_before + 1, "Pregnancy with spare housing must produce a child")
	var pen: Dictionary = _place_sandbox_building(&"animal_pen")
	var coop: Dictionary = _place_sandbox_building(&"clucker_coop")
	var lodge: Dictionary = _place_sandbox_building(&"ranger_lodge")
	var kitchen: Dictionary = _place_sandbox_building(&"kitchen")
	_assert(not pen.is_empty() and not coop.is_empty() and not lodge.is_empty() and not kitchen.is_empty(), "Animal husbandry test buildings must find valid generated footprints")
	_assert(sim.animal_pen_capacity == 6 and sim.clucker_coop_capacity == 8, "Completed pens and coops must expose their animal capacities")
	var clucker: Dictionary = sim.animals.filter(func(animal: Dictionary) -> bool: return String(animal.definition_id) == "clucker")[0]
	clucker.domesticated = true
	clucker.home_id = sim._assign_animal_home(clucker)
	var eggs_before := int(sim.resources.eggs)
	ProgressionService.set_counter(&"animals.eggs_laid", 63)
	sim.tick = int(clucker.id) % 400
	sim._update_animals()
	_assert(int(sim.resources.eggs) >= eggs_before + 1, "Cluckers must lay eggs into the resource economy")
	_assert(ProgressionService.completed.has("eggcellent"), "Sixty-four housed Clucker eggs must unlock Eggcellent")
	var male_clucker: Dictionary = {}
	for animal in sim.animals:
		if String(animal.definition_id) == "clucker" and int(animal.id) != int(clucker.id):
			male_clucker = animal
			break
	clucker.sex = "female"
	clucker.age_stage = "adult"
	male_clucker.sex = "male"
	male_clucker.age_stage = "adult"
	male_clucker.domesticated = true
	male_clucker.home_id = sim._assign_animal_home(male_clucker)
	clucker.pregnant_ticks = 100
	var animal_count_before_birth: int = sim.animals.size()
	sim.tick = 100
	sim._update_animals()
	_assert(sim.animals.size() == animal_count_before_birth + 1, "A housed breeding pair must produce a domesticated young animal")
	var wild_beefalo: Dictionary = sim.animals.filter(func(animal: Dictionary) -> bool: return String(animal.definition_id) == "beefalo" and not bool(animal.domesticated))[0]
	for job_id in sim.jobs:
		sim.jobs[job_id].desired = 0
	sim.jobs.rangers.desired = 1
	sim._assign_jobs()
	var ranger: Dictionary = sim.villagers.filter(func(villager: Dictionary) -> bool: return String(villager.job) == "rangers")[0]
	wild_beefalo.x = float(ranger.x)
	wild_beefalo.y = float(ranger.y)
	sim.submit(GameCommand.designate_animal_capture(sim.tick, int(wild_beefalo.id)))
	for _index in 70:
		sim.advance_tick()
	_assert(bool(wild_beefalo.get("domesticated", false)) and int(wild_beefalo.get("home_id", 0)) > 0, "A Ranger must capture a designated wild herd animal into an open pen")
	var meat_before := int(sim.resources.raw_meat)
	for job_id in sim.jobs:
		sim.jobs[job_id].desired = 0
	sim.jobs.cooks.desired = 1
	sim._assign_jobs()
	var cook: Dictionary = sim.villagers.filter(func(villager: Dictionary) -> bool: return String(villager.job) == "cooks")[0]
	wild_beefalo.x = float(cook.x)
	wild_beefalo.y = float(cook.y)
	sim.submit(GameCommand.designate_animal_slaughter(sim.tick, int(wild_beefalo.id)))
	for _index in 70:
		sim.advance_tick()
	_assert(sim._find_animal(int(wild_beefalo.id)).is_empty() and int(sim.resources.raw_meat) > meat_before, "A Cook and Kitchen must convert a designated herd animal into capped product yields")
	for job_id in sim.jobs:
		sim.jobs[job_id].desired = 0
	sim.jobs.rangers.desired = 1
	sim._assign_jobs()
	ranger = sim.villagers.filter(func(villager: Dictionary) -> bool: return String(villager.job) == "rangers")[0]
	ranger.hunger = 1000
	ranger.thirst = 1000
	ranger.energy = 1000
	var invalidated_animal: Dictionary = sim.animals.filter(func(animal: Dictionary) -> bool: return String(animal.definition_id) == "entler" and not bool(animal.domesticated))[0]
	invalidated_animal.x = float(ranger.x)
	invalidated_animal.y = float(ranger.y)
	sim._designate_animal_capture({"animal_entity_id": invalidated_animal.id, "enabled": true})
	sim._refresh_task_board()
	sim._update_villagers()
	_assert(int(ranger.get("task_id", 0)) > 0, "A Ranger must reserve an available animal-capture task")
	invalidated_animal.health = 0
	sim._refresh_task_board()
	sim._update_villagers()
	var recovery_summary: Dictionary = sim.task_board.debug_summary()
	_assert(int(ranger.get("task_id", 0)) == 0 and int(recovery_summary.by_kind.get("capture_animal", 0)) == 0, "Animal task reservations must release when their target disappears")
	var animal_state: Dictionary = sim.export_state()
	_assert(int(animal_state.get("animal_pen_capacity", 0)) == sim.animal_pen_capacity and int(sim.get_snapshot().clucker_coop_capacity) == sim.clucker_coop_capacity, "Animal housing must be represented in saves and snapshots")
	_test_simulation_and_goal()

func _test_roads_and_walls() -> void:
	ProgressionService.reset_profile_progress()
	ProgressionService.set_counter(&"roads.built.cut_stone_board_road", 127)
	ProgressionService.set_counter(&"walls.built.curtain_wall", 127)
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(8383, &"applemeadow", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(blueprint, sandbox)
	var road: Dictionary = _place_sandbox_building(&"cut_stone_board_road")
	var wall: Dictionary = _place_sandbox_building(&"curtain_wall")
	var gate: Dictionary = _place_sandbox_building(&"stone_gate")
	_assert(not road.is_empty() and not wall.is_empty() and not gate.is_empty(), "Road, wall, and gate segments must find valid generated footprints")
	var road_cell := Vector2i(int(road.x), int(road.y))
	var wall_cell := Vector2i(int(wall.x), int(wall.y))
	var gate_cell := Vector2i(int(gate.x), int(gate.y))
	_assert(is_equal_approx(sim.pathfinder.get_travel_weight(road_cell), 0.50) and is_equal_approx(sim._road_speed_multiplier(road_cell), 1.36), "Cut Stone roads must attract paths and increase travel speed")
	_assert(not sim.pathfinder.is_walkable(wall_cell), "Completed curtain walls must become solid navigation obstacles")
	_assert(sim.pathfinder.is_walkable(gate_cell) and sim.pathfinder.is_walkable(gate_cell + Vector2i.RIGHT), "Completed gates must remain traversable")
	_assert(ProgressionService.completed.has("all_roads_lead_to_home") and ProgressionService.completed.has("i_like_big_buttresses"), "Road and curtain-wall construction must feed their official achievement counters")
	wall.destroyed = true
	sim._refresh_navigation_buildings()
	_assert(sim.pathfinder.is_walkable(wall_cell), "Destroyed walls must release their navigation cells")
	ProgressionService.set_counter(&"walls.destroyed", 24)
	_assert(ProgressionService.completed.has("crumbling_defenses"), "Destroyed-wall statistics must unlock Crumbling Defenses")
	_test_simulation_and_goal()

func _test_building_upgrades() -> void:
	ProgressionService.reset_profile_progress()
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(42424, &"applemeadow", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(blueprint, sandbox)
	var camp_cell := blueprint.starting_cell - Vector2i(6, 6)
	sim.submit(GameCommand.place_building(sim.tick, &"camp", camp_cell))
	sim.advance_tick()
	_assert(sim.buildings.size() == 1 and bool(sim.buildings[0].completed), "Sandbox must instantly complete the initial Camp")
	_assert(sim.building_limit == 8 and sim.build_range == 32 and sim.ancillary_limit == 1, "Tier-one Camp must apply its documented settlement support")
	_assert(int(sim.jobs.builders.max) == 12 and int(sim.resource_caps.wood) == 220, "Tier-one Camp must provide builder slots and general storage")
	var camp_id := int(sim.buildings[0].id)
	var tier_two: Dictionary = sim.get_upgrade_preview(camp_id)
	_assert(String(tier_two.name) == "Large Camp" and int(tier_two.cost.wood) == 6 and int(tier_two.health) == 1945, "Camp upgrade preview must use the tier ledger rather than inferred scaling")
	for expected_tier in range(2, 16):
		sim.submit(GameCommand.upgrade_building(sim.tick, camp_id))
		sim.advance_tick()
		_assert(int(sim.buildings[0].tier) == expected_tier and bool(sim.buildings[0].completed), "Camp upgrade must complete deterministic tier %d" % expected_tier)
	_assert(String(sim.buildings[0].name) == "Large Castle" and int(sim.buildings[0].max_health) == 10580, "The fifteenth town-center tier must be the Large Castle with documented health")
	_assert(sim.building_limit == 86 and sim.build_range == 60 and sim.ancillary_limit == 15 and int(sim.jobs.builders.max) == 26, "Large Castle must apply late-game capacity, range, ancillary, and builder support")
	_assert(ProgressionService.completed.has("god_king"), "Completing the Large Castle must unlock the offline God King achievement")
	_assert(sim.get_upgrade_preview(camp_id).is_empty(), "A maximum-tier Large Castle must not expose another upgrade")
	# Restore the deterministic Camp scenario used by save tests.
	_test_simulation_and_goal()

func _test_make_maintain_production() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(80808, &"applemeadow", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(blueprint, sandbox)
	sim.animals.clear()
	sim.submit(GameCommand.place_building(sim.tick, &"lumber_mill", blueprint.starting_cell - Vector2i(5, 4)))
	sim.advance_tick()
	_assert(sim.buildings.size() == 1 and bool(sim.buildings[0].completed), "Production test workplace must complete instantly in Sandbox")
	var mill_id := int(sim.buildings[0].id)
	_assert(sim.get_recipes_for_building(mill_id).size() == 1, "Lumber Mill must expose its validated production recipe")
	sim.resources.wood = 20
	sim.resources.boards = 0
	sim.submit(GameCommand.set_recipe_policy(sim.tick, mill_id, &"boards", &"make", 3))
	for _index in 250:
		sim.advance_tick()
	_assert(int(sim.resources.boards) == 3 and int(sim.resources.wood) == 17, "Make policy must produce the requested batch and conserve inputs")
	_assert(String(sim.buildings[0].recipe_mode) == "paused" and int(sim.buildings[0].recipe_remaining) == 0, "Completed Make batches must pause without overproduction")
	sim.submit(GameCommand.set_recipe_policy(sim.tick, mill_id, &"boards", &"maintain", 5))
	for _index in 180:
		sim.advance_tick()
	_assert(int(sim.resources.boards) == 5, "Maintain policy must stop exactly at its inventory target")
	for _index in 200:
		sim.advance_tick()
	_assert(int(sim.resources.boards) == 5 and int(sim.resources.wood) == 15, "Maintain policy must remain idle once its target is stocked")
	sim.submit(GameCommand.set_recipe_policy(sim.tick, mill_id, &"boards", &"paused", 0))
	sim.advance_tick()
	sim.resources.boards = 0
	for _index in 120:
		sim.advance_tick()
	_assert(int(sim.resources.boards) == 0, "Paused recipe policy must suppress production")
	_test_simulation_and_goal()

func _test_decay_and_trash_chain() -> void:
	ProgressionService.reset_profile_progress()
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(60606, &"applemeadow", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(blueprint, sandbox)
	sim.animals.clear()
	sim.drop_resource(&"raw_meat", 4, blueprint.starting_cell, 10)
	for _index in 10:
		sim.advance_tick()
	_assert(sim.loose_items.size() == 1 and String(sim.loose_items[0].resource_id) == "organicy_trash", "Expired loose food must become its matching organic trash")
	_assert(int(ProgressionService.counters.get("trash.generated", 0)) == 4, "Decay must count every generated piece of trash")
	sim.submit(GameCommand.place_building(sim.tick, &"trash_can", blueprint.starting_cell - Vector2i(2, 2)))
	for _index in 12:
		sim.advance_tick()
	_assert(sim.loose_items.is_empty() and int(sim.resources.organicy_trash) == 4, "Staffed waste storage must collect loose trash into protected capacity")
	_assert(int(sim.resource_caps.organicy_trash) >= 32, "Trash Can must add dedicated capacity for every waste type")
	# Isolate automatic burner behavior from processor recovery.
	sim.start_region(blueprint, sandbox)
	sim.animals.clear()
	sim.submit(GameCommand.place_building(sim.tick, &"burner", blueprint.starting_cell - Vector2i(3, 3)))
	sim.advance_tick()
	sim.resources.trashy_trash = 2
	var essence_before := int(sim.resources.essence)
	for _index in 180:
		sim.advance_tick()
	_assert(int(sim.resources.trashy_trash) == 0 and int(sim.resources.essence) == essence_before + 2, "Burner must automatically destroy stored trash and generate essence")
	_assert(int(ProgressionService.counters.get("trash.burned", 0)) == 2, "Burner throughput must update achievement statistics")
	# Uncollected piles create their own hostile pressure.
	sim.start_region(blueprint, sandbox)
	sim.animals.clear()
	sim.drop_resource(&"trashy_trash", 6, blueprint.starting_cell, -1)
	for _index in 200:
		sim.advance_tick()
	_assert(sim.monsters.any(func(monster: Dictionary) -> bool: return String(monster.definition_id) == "trashy_slime"), "An unmanaged loose trash pile must be able to spawn a Trashy Slime")
	_test_simulation_and_goal()

func _test_marketplace_trade() -> void:
	ProgressionService.reset_profile_progress()
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(70707, &"applemeadow", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(blueprint, sandbox)
	sim.animals.clear()
	sim.submit(GameCommand.place_building(sim.tick, &"marketplace", blueprint.starting_cell - Vector2i(4, 4)))
	sim.advance_tick()
	_assert(sim.buildings.size() == 1 and bool(sim.buildings[0].completed), "Marketplace trade test requires an operational Marketplace")
	_assert(int(sim.jobs.provisioners.current) > 0, "A completed Marketplace must expose and fill its Provisioner quota")
	var marketplace_id := int(sim.buildings[0].id)
	sim._spawn_catjeet_trader()
	sim.catjeet_trader.inventory.wood = 100
	sim.catjeet_trader.inventory.rock = 100
	sim.catjeet_trader.inventory.suspicious_key = 16
	sim.catjeet_trader.gold_coins = 5000
	sim.catjeet_trader.laborers = 12
	sim.resources.gold_coins = 5000
	sim.resources.wood = 10
	var combined_gold_before := int(sim.resources.gold_coins) + int(sim.catjeet_trader.gold_coins)
	var combined_wood_before := int(sim.resources.wood) + int(sim.catjeet_trader.inventory.wood)
	sim.submit(GameCommand.trade_resource(sim.tick, marketplace_id, &"buy", &"wood", 8))
	sim.advance_tick()
	_assert(int(sim.resources.wood) == 18 and int(sim.catjeet_trader.inventory.wood) == 92, "Buying must atomically move stock from the caravan to village storage")
	sim.submit(GameCommand.trade_resource(sim.tick, marketplace_id, &"sell", &"wood", 4))
	sim.advance_tick()
	_assert(int(sim.resources.wood) == 14 and int(sim.catjeet_trader.inventory.wood) == 96, "Selling must atomically move stock from village storage to the caravan")
	_assert(int(sim.resources.gold_coins) + int(sim.catjeet_trader.gold_coins) == combined_gold_before, "Marketplace trades must conserve total gold")
	_assert(int(sim.resources.wood) + int(sim.catjeet_trader.inventory.wood) == combined_wood_before, "Marketplace trades must conserve total resources")
	sim.resources.rock = 0
	sim.submit(GameCommand.set_trade_rule(sim.tick, marketplace_id, &"rock", 16, 64, 8))
	for _index in 25:
		sim.advance_tick()
	_assert(int(sim.resources.rock) == 8, "Provisioner buy-below rules must purchase one deterministic batch when stock is low")
	var population_before: int = sim.villagers.size()
	sim.submit(GameCommand.hire_catjeet(sim.tick, marketplace_id, 1))
	sim.advance_tick()
	_assert(sim.villagers.size() == population_before + 1 and String(sim.villagers.back().species) == "catjeet", "Hiring must add a persistent Catjeet laborer to the village population")
	sim.submit(GameCommand.trade_resource(sim.tick, marketplace_id, &"buy", &"suspicious_key", 16))
	sim.advance_tick()
	_assert(ProgressionService.completed.has("whale"), "Buying sixteen Suspicious Keys must unlock the Whale achievement")
	sim.resources.god_dust = 24
	sim.submit(GameCommand.trade_resource(sim.tick, marketplace_id, &"sell", &"god_dust", 24))
	sim.advance_tick()
	_assert(ProgressionService.completed.has("the_dust_must_flow"), "Selling twenty-four God Dust must unlock its official trade achievement")
	sim.resources.filled_eerie_vessel = 1
	sim.submit(GameCommand.trade_resource(sim.tick, marketplace_id, &"sell", &"filled_eerie_vessel", 1))
	sim.advance_tick()
	_assert(ProgressionService.completed.has("the_soul_trade"), "Selling a filled Eerie Vessel must unlock The Soul Trade")
	var trade_hash: String = sim.compute_state_hash()
	var trade_state: Dictionary = sim.export_state()
	sim.catjeet_trader.clear()
	sim.import_state(trade_state)
	_assert(sim.compute_state_hash() == trade_hash and not sim.catjeet_trader.is_empty(), "Trade caravan inventory, rules, timers, population, and RNG must survive an exact state round trip")
	_test_simulation_and_goal()

func _test_meta_progression() -> void:
	ProgressionService.reset_profile_progress()
	var goals: Array[Dictionary] = ProgressionService.get_goal_nodes()
	var bound_goals := goals.filter(func(goal: Dictionary) -> bool: return bool(goal.bound))
	_assert(goals.size() == 113 and bound_goals.size() >= 29, "The profile Goal Web must expose every official goal and distinguish executable bindings (goals=%d, bound=%d)" % [goals.size(), bound_goals.size()])
	ProgressionService.add_god_xp(249)
	_assert(ProgressionService.chest_inventory.is_empty(), "God Chests must not unlock before the next profile XP milestone")
	ProgressionService.add_god_xp(1)
	_assert(ProgressionService.god_xp == 250 and ProgressionService.chest_inventory.size() == 1, "Profile God XP must unlock and retain milestone chests")
	var opened_perk: Dictionary = ProgressionService.open_chest(0)
	_assert(not opened_perk.is_empty() and int(ProgressionService.perk_inventory.get(String(opened_perk.id), 0)) == 1, "Opening a God Chest must deterministically award a persistent perk")
	ProgressionService.perk_inventory["owens_pace"] = 2
	ProgressionService.perk_inventory["alendrus_accommodation"] = 1
	ProgressionService.perk_inventory["divination_of_aidos"] = 1
	_assert(is_equal_approx(ProgressionService.get_modifier(&"movement_speed"), 0.10), "Stacked perks must add their typed modifiers")
	ProgressionService.complete_tutorial(&"choose_mode")
	var exported_meta: Dictionary = ProgressionService.export_state()
	var perk_count_before: int = ProgressionService.perk_inventory.size()
	WorldCampaignService.doom_mode(&"traditional")
	_assert(ProgressionService.god_xp == 250 and ProgressionService.perk_inventory.size() == perk_count_before, "Dooming a mode must preserve profile XP, chests, and perks")
	ProgressionService.reset_profile_progress()
	ProgressionService.import_state(exported_meta)
	_assert(ProgressionService.god_xp == 250 and ProgressionService.perk_inventory.size() == perk_count_before and ProgressionService.is_tutorial_completed(&"choose_mode"), "Meta progression and tutorial completion must survive an export/import round trip")
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(7373, &"applemeadow", &"forest")
	var perk_test_rules: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	perk_test_rules.unlimited_influence = false
	sim.start_region(blueprint, perk_test_rules)
	var housing: Dictionary = _place_sandbox_building(&"housing")
	_assert(not housing.is_empty() and sim.housing_capacity == 9, "Efficient Housing perks must modify completed housing capacity")
	for _index in 10:
		sim.advance_tick()
	_assert(sim.max_influence == 840, "Influence perks must modify influence contribution per villager")
	_test_simulation_and_goal()

func _test_regional_campaign() -> void:
	var campaigns := get_node("/root/WorldCampaignService")
	campaigns.mode_campaigns.erase("traditional")
	campaigns.set_active_mode(&"traditional")
	campaigns.establish_region(&"applemeadow", 20)
	var source: Dictionary = campaigns.get_region_state(&"applemeadow")
	source.resources = {"wood": 100, "rock": 40}
	_assert(not campaigns.queue_migration(&"applemeadow", &"valencia", 3), "Migration must reject non-adjacent regions")
	_assert(campaigns.queue_migration(&"applemeadow", &"coastbridge", 5), "Migration must accept an adjacent destination")
	_assert(campaigns.queue_courier(&"applemeadow", &"gateway", {"wood": 30}), "Couriers must reserve available cargo for an adjacent destination")
	_assert(int(source.population) == 15 and int(source.resources.wood) == 70, "Queued regional transfers must reserve population and cargo immediately")
	campaigns.advance_ticks(campaigns.TRANSFER_TICKS)
	var migrated: Dictionary = campaigns.get_region_state(&"coastbridge")
	var supplied: Dictionary = campaigns.get_region_state(&"gateway")
	_assert(String(migrated.status) == "active" and int(migrated.population) == 5, "Completed migration must establish and populate its destination")
	_assert(int(supplied.resources.get("wood", 0)) == 30, "Completed courier delivery must add its cargo to destination storage")
	_assert(campaigns._ensure_mode(&"traditional").transfers.is_empty(), "Completed regional transfers must leave no stale queue entries")
	campaigns.set_active_mode(&"peaceful")
	campaigns.establish_region(&"applemeadow", 12)
	_assert(int(campaigns.get_region_state(&"applemeadow").population) == 12, "Each game mode must own an independent regional campaign")
	campaigns.doom_mode(&"peaceful")
	_assert(String(campaigns.get_region_state(&"applemeadow", &"peaceful").status) == "unestablished", "Doom must reset settlement state for only the selected mode")
	_assert(int(campaigns._ensure_mode(&"peaceful").dooms) == 1, "Doom count must persist across the mode reset")
	_assert(int(campaigns.get_region_state(&"applemeadow", &"traditional").population) == 15, "Dooming one mode must not alter another mode's settlements")
	campaigns.set_active_mode(&"traditional")
	var generator := RegionGenerator.new()
	var apple := generator.generate(13579, &"applemeadow", &"forest")
	sim.start_region(apple, registry.get_by_id(&"modes", &"traditional"))
	sim.resources.wood = 123
	for _index in 4:
		sim.advance_tick()
	var stored_hash: String = sim.compute_state_hash()
	campaigns.store_active_region(&"applemeadow", sim.export_state())
	var gateway := generator.generate(24680, &"gateway", &"forest")
	sim.start_region(gateway, registry.get_by_id(&"modes", &"traditional"))
	AppController.current_mode = &"traditional"
	AppController.current_region = &"applemeadow"
	AppController.establish_selected_region()
	_assert(sim.compute_state_hash() == stored_hash and int(sim.resources.wood) == 123, "Revisiting an established region must restore its exact deterministic simulation")
	var synced_source: Dictionary = campaigns.get_region_state(&"applemeadow")
	synced_source.population = sim.villagers.size()
	synced_source.resources = sim.resources.duplicate(true)
	_assert(campaigns.queue_migration(&"applemeadow", &"coastbridge", 3), "Stored simulation migration must queue")
	_assert(campaigns.queue_courier(&"applemeadow", &"coastbridge", {"wood": 7}), "Stored simulation courier must queue")
	_assert(synced_source.simulation.villagers.size() == sim.villagers.size() - 3 and int(synced_source.simulation.resources.wood) == 116, "Outbound transfers must immediately synchronize the stored source simulation")
	campaigns.advance_ticks(campaigns.TRANSFER_TICKS)
	var synced_destination: Dictionary = campaigns.get_region_state(&"coastbridge")
	_assert(int(synced_destination.population) >= 8 and int(synced_destination.resources.wood) >= 7, "Regional arrivals must accumulate in an unvisited destination")
	var refund_source: Dictionary = campaigns.get_region_state(&"applemeadow")
	refund_source.population = 20
	refund_source.resources.wood = 80
	_assert(campaigns.queue_courier(&"applemeadow", &"gateway", {"wood": 20}), "Lost-destination test courier must queue")
	campaigns.mark_region_lost(&"gateway")
	campaigns.advance_ticks(campaigns.TRANSFER_TICKS)
	_assert(int(refund_source.resources.wood) == 80, "A failed delivery to a lost region must refund reserved cargo")

func _test_map_packages() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(7755, &"custom_region", &"forest")
	var path: String = MapPackageService.save_map(blueprint, "Automated Map", {"test": true})
	_assert(not path.is_empty() and FileAccess.file_exists(path), "Map editor must write a local .rtrmap package")
	var loaded: RegionBlueprint = MapPackageService.load_map(path)
	_assert(loaded != null, "Saved .rtrmap package must load")
	if loaded:
		var resources_match := loaded.resource_nodes.size() == blueprint.resource_nodes.size()
		if resources_match:
			for index in loaded.resource_nodes.size():
				var loaded_node: Dictionary = loaded.resource_nodes[index]
				var original_node: Dictionary = blueprint.resource_nodes[index]
				if String(loaded_node.id) != String(original_node.id) or int(loaded_node.x) != int(original_node.x) or int(loaded_node.y) != int(original_node.y) or int(loaded_node.amount) != int(original_node.amount):
					resources_match = false
					break
		_assert(loaded.tiles == blueprint.tiles and resources_match, "Map package round trip must preserve terrain and resources")
		_assert(bool(loaded.validation_report.get("valid", false)), "Loaded map packages must be revalidated")

func _test_save_round_trip() -> void:
	var before: String = sim.compute_state_hash()
	var before_state: Dictionary = sim.export_state()
	var campaign_before: Dictionary = WorldCampaignService.export_state()
	var achievement_count_before := ProgressionService.completed.size()
	_assert(saves.save_atomic(&"automated_test"), "Atomic save should succeed")
	sim.resources.wood = 999999
	WorldCampaignService.mode_campaigns.clear()
	ProgressionService.reset_profile_progress()
	_assert(saves.load_and_migrate(&"automated_test"), "Save should load")
	var after: String = sim.compute_state_hash()
	var difference := _first_difference(before_state, sim.export_state(), "state")
	_assert(before == after, "Save/load round trip must preserve deterministic state hash; first difference: %s" % difference)
	_assert(ProgressionService.completed.size() == achievement_count_before, "Save/load must preserve offline achievement progress")
	var campaign_difference := _first_difference(campaign_before, WorldCampaignService.export_state(), "campaigns")
	_assert(campaign_difference.is_empty(), "Save/load must preserve all mode-specific regional campaigns; first difference: %s" % campaign_difference)
	var migrated: Dictionary = saves._migrate_payload(1, {"tick": 7})
	_assert(migrated.has("simulation") and int(migrated.simulation.tick) == 7 and migrated.has("campaigns"), "Schema-1 saves must migrate into the current envelope")
	var schema_two: Dictionary = saves._migrate_payload(2, {"simulation": {"tick": 8}, "progression": {}})
	_assert(schema_two.has("campaigns") and int(schema_two.simulation.tick) == 8, "Schema-2 saves must gain an empty regional campaign payload")

func _first_difference(a: Variant, b: Variant, path: String) -> String:
	if (a is int or a is float) and (b is int or b is float):
		return "" if is_equal_approx(float(a), float(b)) else "%s value %s != %s" % [path, a, b]
	if typeof(a) != typeof(b):
		return "%s type %s != %s" % [path, type_string(typeof(a)), type_string(typeof(b))]
	if a is Dictionary:
		var normalized_a: Dictionary = {}
		var normalized_b: Dictionary = {}
		for key in a:
			normalized_a[String(key)] = a[key]
		for key in b:
			normalized_b[String(key)] = b[key]
		var a_keys: Array = normalized_a.keys()
		var b_keys: Array = normalized_b.keys()
		a_keys.sort_custom(func(x: Variant, y: Variant) -> bool: return String(x) < String(y))
		b_keys.sort_custom(func(x: Variant, y: Variant) -> bool: return String(x) < String(y))
		if a_keys != b_keys:
			return "%s keys %s != %s" % [path, a_keys, b_keys]
		for key in a_keys:
			var nested := _first_difference(normalized_a[key], normalized_b[key], "%s.%s" % [path, key])
			if not nested.is_empty():
				return nested
		return ""
	if a is Array:
		if a.size() != b.size():
			return "%s size %d != %d" % [path, a.size(), b.size()]
		for index in a.size():
			var nested := _first_difference(a[index], b[index], "%s[%d]" % [path, index])
			if not nested.is_empty():
				return nested
		return ""
	if a != b:
		return "%s value %s != %s" % [path, a, b]
	return ""
