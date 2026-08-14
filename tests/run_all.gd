extends Node

const TERRAIN_CHUNK_RENDERER := preload("res://presentation/scripts/terrain_chunk_renderer.gd")
const PHYSICAL_INVENTORY := preload("res://core/simulation/physical_inventory.gd")
const RESERVATION_SERVICE := preload("res://core/simulation/reservation_service.gd")
const PRODUCTION_SYSTEM_CLASS := preload("res://core/simulation/production_system.gd")
const TASK_SYSTEM_CLASS := preload("res://core/simulation/task_system.gd")
const ANIMAL_SYSTEM_CLASS := preload("res://core/simulation/animal_system.gd")
const COMBAT_SYSTEM_CLASS := preload("res://core/simulation/combat_system.gd")
const SPELL_SYSTEM_CLASS := preload("res://core/simulation/spell_system.gd")
const SIMULATION_HOST_CLASS := preload("res://core/simulation/simulation_host.gd")

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
	if "--ci-smoke" in OS.get_cmdline_user_args():
		_test_content()
		_test_generation_determinism()
		_test_pathfinding()
		_test_simulation_and_goal()
		_test_physical_inventory_and_reservations()
		_test_extracted_subsystem_contracts()
		_test_physical_logistics_live_loop()
		_test_save_round_trip()
		_finish()
		return
	if "--terrain-work-only" in OS.get_cmdline_user_args():
		_test_terrain_work_designations()
		_finish()
		return
	if "--chunk-renderer-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_chunked_terrain_renderer()
		_finish()
		return
	if "--cullis-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_grab_and_cullis_gate()
		_finish()
		return
	if "--loot-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_lootbox_loop()
		_finish()
		return
	if "--spells-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_remaining_spell_mechanics()
		_finish()
		return
	if "--nomads-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_nomad_arrivals_and_recall()
		_finish()
		return
	if "--meta-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_meta_progression()
		_test_official_achievement_mechanics()
		_finish()
		return
	if "--achievement-mechanics-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_official_achievement_mechanics()
		_finish()
		return
	if "--ranger-buildings-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_ranger_lodge_and_outpost()
		_finish()
		return
	if "--storage-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_storage_profiles_and_filters()
		_finish()
		return
	if "--workplaces-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_staffed_workplace_attendance()
		_finish()
		return
	if "--services-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_medical_and_maintenance_services()
		_finish()
		return
	if "--production-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_make_maintain_production()
		_finish()
		return
	if "--population-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_population_and_animals()
		_finish()
		return
	if "--rates-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_resource_rates()
		_finish()
		return
	if "--decay-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_decay_and_trash_chain()
		_finish()
		return
	if "--campaign-only" in OS.get_cmdline_user_args():
		_test_content()
		_test_regional_campaign()
		_finish()
		return
	_test_content()
	_test_sprite_ledger()
	_test_generation_determinism()
	_test_chunked_terrain_renderer()
	_test_pathfinding()
	_test_simulation_and_goal()
	_test_early_economy()
	_test_water_network()
	_test_natural_resource_lifecycle()
	_test_resource_rates()
	_test_storage_profiles_and_filters()
	_test_staffed_workplace_attendance()
	_test_survival_mode_rules()
	_test_settlement_range_and_corruption()
	_test_hostile_corruption_infrastructure()
	_test_spell_commands()
	_test_remaining_spell_mechanics()
	_test_grab_and_cullis_gate()
	_test_lootbox_loop()
	_test_golems_and_tower_combat()
	_test_monster_combat_model()
	_test_ranger_doggo_equipment_combat()
	_test_ranger_lodge_and_outpost()
	_test_medical_and_maintenance_services()
	_test_faith_ghost_resurrection()
	_test_weather_and_events()
	_test_terrain_aftermath_states()
	_test_terrain_work_designations()
	_test_population_and_animals()
	_test_nomad_arrivals_and_recall()
	_test_roads_and_walls()
	_test_building_upgrades()
	_test_make_maintain_production()
	_test_decay_and_trash_chain()
	_test_marketplace_trade()
	_test_meta_progression()
	_test_official_achievement_mechanics()
	_test_regional_campaign()
	_test_map_packages()
	_test_physical_inventory_and_reservations()
	_test_extracted_subsystem_contracts()
	_test_physical_logistics_live_loop()
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

func _find_valid_god_structure_cell(definition: Dictionary, origin: Vector2i) -> Vector2i:
	for radius in range(0, 65, 4):
		for offset in [Vector2i(radius, 0), Vector2i(-radius, 0), Vector2i(0, radius), Vector2i(0, -radius), Vector2i(radius, radius), Vector2i(-radius, radius), Vector2i(radius, -radius), Vector2i(-radius, -radius)]:
			var cell: Vector2i = origin + offset
			if sim._god_structure_placement_valid(cell, definition):
				return cell
	return Vector2i(-1, -1)

func _test_content() -> void:
	var report: Dictionary = registry.validation_report
	_assert(bool(report.get("valid", false)), "Content registry must validate: %s" % str(report.get("errors", [])))
	_assert(registry.get_all(&"modes").size() == 6, "Exactly six game modes are required")
	_assert(registry.get_all(&"regions").size() == 45, "Exactly 45 world regions are required")
	_assert(registry.get_all(&"jobs").size() == 25, "Exactly 25 workforce jobs are required")
	_assert(registry.get_all(&"buildings").size() >= 75, "Building catalog is unexpectedly incomplete")
	_assert(registry.get_all(&"spells").size() >= 30, "Spell catalog is unexpectedly incomplete")
	_assert(registry.get_all(&"achievements").size() == 113, "Official Steam achievement catalog must contain exactly 113 entries")
	_assert(registry.get_all(&"achievement_rules").size() == 113, "Every official Steam achievement must have one honest executable binding")
	_assert(registry.get_all(&"actors").size() >= 25, "Actor catalog is unexpectedly incomplete")
	_assert(registry.get_all(&"events").size() >= 12, "Event catalog is unexpectedly incomplete")
	_assert(int(registry.get_by_id(&"buildings", &"small_fountain").get("water", {}).get("clean_capacity", 0)) == 48, "Small Fountain content must retain its documented 48-unit capacity")
	_assert(int(registry.get_by_id(&"buildings", &"large_fountain").get("water", {}).get("clean_capacity", 0)) == 96, "Large Fountain content must retain its documented 96-unit capacity")
	_assert(String(registry.get_by_id(&"buildings", &"water_purifier").get("water", {}).get("role", "")) == "purifier", "Water Purifier must retain its validated data-driven water role")
	_assert(int(registry.get_by_id(&"buildings", &"fire_pit").get("settlement_range", {}).get("base", 0)) == 12, "Fire Pit must retain its documented 12-cell settlement range")
	_assert(int(registry.get_by_id(&"buildings", &"large_fire_pit").get("settlement_range", {}).get("base", 0)) == 16, "Large Fire Pit must retain its documented 16-cell settlement range")
	_assert(int(registry.get_by_id(&"buildings", &"ancillary").get("settlement_range", {}).get("maximum", 0)) == 28, "Established Ancillary must retain its documented 28-cell range")
	_assert(String(registry.get_by_id(&"buildings", &"crystal_motivator").get("growth", {}).get("role", "")) == "crystal_motivator", "Crystal Motivator must expose its validated data-driven growth role")
	var cullis: Dictionary = registry.get_by_id(&"buildings", &"cullis_gate").get("cullis", {})
	_assert(String(cullis.get("role", "")) == "sacrifice_gate" and int(cullis.get("overload_threshold", 0)) > int(cullis.get("lightning_threshold", 0)), "Cullis Gate must expose a validated sacrifice, cooling, lightning, and overload contract")
	var loot_table: Dictionary = registry.get_by_id(&"loot_tables", &"standard_lootbox")
	var loot_profile: Dictionary = registry.get_by_id(&"loot_site_profiles", &"standard_magic_circles")
	_assert(int(loot_table.get("rolls", 0)) > 0 and not loot_table.get("outcomes", []).is_empty(), "Loot boxes must expose a validated, data-driven weighted reward table")
	_assert(int(loot_profile.get("site_count", 0)) == 6 and int(loot_profile.get("key_sites", 0)) == 3, "Each region must seed the current six magic-circle sites with three physical keys")
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
				_assert("complete" in states and "construction_50" in states and "damaged_severe" in states and "frozen" in states and "electrified" in states and "corrupted" in states and "reclaimed" in states and "abandoned" in states and "repairing" in states and "dismantling" in states and "destroyed" in states, "Building deliverable %s lacks mandatory lifecycle states" % sprite_id)
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
	_assert(a.elevations == b.elevations, "Identical region seeds must produce identical elevation bands")
	_assert(a.resource_nodes == b.resource_nodes, "Identical region seeds must produce identical resources")
	_assert(bool(a.validation_report.get("valid", false)), "Generated region must pass survival validators: %s" % a.validation_report)
	var round_trip := RegionBlueprint.from_dictionary(a.to_dictionary())
	_assert(round_trip.elevations == a.elevations and round_trip.get_elevation(a.starting_cell) == 1, "Version-two region blueprints must preserve elevation bands and the flat starting clearing")
	var legacy_data := a.to_dictionary()
	legacy_data.erase("elevations")
	legacy_data.version = 1
	var migrated := RegionBlueprint.from_dictionary(legacy_data)
	_assert(migrated.get_elevation(a.starting_cell) == 1 and migrated.get_elevation(a.starting_cell + Vector2i(0, 28)) == 0, "Version-one blueprints must derive conservative land/water elevations")
	var foundation := RegionBlueprint.new(7, &"foundation_test", &"forest", 4, 4)
	foundation.tiles.fill(RegionGenerator.Tile.GRASS)
	foundation.elevations.fill(1)
	foundation.set_elevation(Vector2i(2, 2), 2)
	_assert(not foundation.is_buildable(Vector2i(1, 1), Vector2i(2, 2)), "A building foundation must not span two elevation bands")

func _test_chunked_terrain_renderer() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(731991, &"terrain_chunk_test", &"forest")
	var base_payload := {
		"tiles": blueprint.tiles.duplicate(),
		"elevations": blueprint.elevations.duplicate(),
		"world_width": blueprint.width, "world_height": blueprint.height,
		"origin_x": 80, "origin_y": 96, "size_x": 8, "size_y": 8,
		"chunk_x": 10, "chunk_y": 12,
		"seed": blueprint.seed, "biome": String(blueprint.biome_id), "season": "Spring",
		"generation": 3, "revision": 7,
	}
	var renderer := TERRAIN_CHUNK_RENDERER.new()
	var first: Dictionary = renderer.render(base_payload)
	var repeated: Dictionary = TERRAIN_CHUNK_RENDERER.new().render(base_payload.duplicate(true))
	var first_image: Image = first.get("image")
	var repeated_image: Image = repeated.get("image")
	_assert(first_image != null and first_image.get_size() == Vector2i(64, 64), "Terrain chunks must render at the locked 8 pixels per logical cell")
	_assert(first_image != null and repeated_image != null and first_image.get_data() == repeated_image.get_data(), "Terrain chunk rendering must be deterministic for identical immutable payloads")
	# Render two adjacent chunks and the same area as one image. Every boundary
	# pixel must match, proving that global material fields cannot expose a seam.
	var right_payload := base_payload.duplicate(true)
	right_payload.origin_x = 88
	right_payload.chunk_x = 11
	var combined_payload := base_payload.duplicate(true)
	combined_payload.size_x = 16
	var right_image: Image = TERRAIN_CHUNK_RENDERER.new().render(right_payload).image
	var combined_image: Image = TERRAIN_CHUNK_RENDERER.new().render(combined_payload).image
	var seam_matches := true
	for y in first_image.get_height():
		for x in first_image.get_width():
			if first_image.get_pixel(x, y) != combined_image.get_pixel(x, y) or right_image.get_pixel(x, y) != combined_image.get_pixel(x + first_image.get_width(), y):
				seam_matches = false
				break
		if not seam_matches:
			break
	_assert(seam_matches, "Adjacent terrain chunks must match an equivalent combined render on both sides of their seam")
	var mutated_payload := base_payload.duplicate(true)
	var mutated_tiles: PackedByteArray = mutated_payload.tiles.duplicate()
	var changed_index := 99 * blueprint.width + 83
	mutated_tiles[changed_index] = RegionGenerator.Tile.ROCKY if mutated_tiles[changed_index] != RegionGenerator.Tile.ROCKY else RegionGenerator.Tile.GRASS
	mutated_payload.tiles = mutated_tiles
	var mutated_image: Image = TERRAIN_CHUNK_RENDERER.new().render(mutated_payload).image
	_assert(mutated_image.get_data() != first_image.get_data(), "A terrain mutation inside a chunk must change its rendered image")
	var elevation_payload := base_payload.duplicate(true)
	var mutated_elevations: PackedByteArray = elevation_payload.elevations.duplicate()
	mutated_elevations[changed_index] = 3 if int(mutated_elevations[changed_index]) != 3 else 1
	elevation_payload.elevations = mutated_elevations
	var elevation_image: Image = TERRAIN_CHUNK_RENDERER.new().render(elevation_payload).image
	_assert(elevation_image.get_data() != first_image.get_data(), "An elevation mutation inside a chunk must change its tint and contour image")
	# Small disconnected forest components are simulation-valid resource pockets,
	# but must not render as individual tree crowns in the continuous-canopy style.
	var visual_width := 24
	var visual_height := 24
	var visual_source := PackedByteArray()
	visual_source.resize(visual_width * visual_height)
	visual_source.fill(RegionGenerator.Tile.GRASS)
	for y in range(2, 5):
		for x in range(2, 5):
			visual_source[y * visual_width + x] = RegionGenerator.Tile.FOREST_FLOOR
	for y in range(10, 21):
		for x in range(10, 21):
			visual_source[y * visual_width + x] = RegionGenerator.Tile.FOREST_FLOOR
	var visual_result: PackedByteArray = renderer._build_visual_material_map(visual_source, visual_width, visual_height)
	_assert(int(visual_result[3 * visual_width + 3]) == RegionGenerator.Tile.GRASS, "Tree-sized forest components must dissolve into meadow instead of rendering as individual crowns")
	_assert(int(visual_result[15 * visual_width + 15]) == RegionGenerator.Tile.FOREST_FLOOR, "Broad connected forest masses must retain the continuous canopy material")

func _test_pathfinding() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(5150, &"applemeadow", &"forest")
	var finder = preload("res://core/simulation/grid_pathfinder.gd").new()
	finder.configure(blueprint)
	var start := blueprint.starting_cell
	var water_target := start + Vector2i(0, 28)
	var highland_cell := Vector2i(-1, -1)
	for y in blueprint.height:
		for x in blueprint.width:
			var candidate := Vector2i(x, y)
			if blueprint.get_tile(candidate) != RegionGenerator.Tile.DEEP_WATER and blueprint.get_elevation(candidate) >= 2:
				highland_cell = candidate
				break
		if highland_cell.x >= 0:
			break
	_assert(highland_cell.x >= 0 and finder.get_travel_weight(highland_cell) > 1.0, "Generated highlands must carry a deterministic uphill path weight")
	var first: Array = finder.find_path(start, water_target)
	var second: Array = finder.find_path(start, water_target)
	_assert(not first.is_empty(), "Pathfinder must route to the nearest walkable shore beside a water target")
	_assert(first == second, "Pathfinding must be deterministic")
	for point in first:
		_assert(blueprint.get_tile(Vector2i(int(point[0]), int(point[1]))) != RegionGenerator.Tile.DEEP_WATER, "Worker paths must not cross deep water")
	finder.set_deep_water_frozen(true)
	var ice_path: Array = finder.find_path(start, water_target)
	_assert(not ice_path.is_empty() and ice_path.any(func(point: Array) -> bool: return blueprint.get_tile(Vector2i(int(point[0]), int(point[1]))) == RegionGenerator.Tile.DEEP_WATER), "Frozen deep water must become a deterministic, higher-cost traversable ice route")
	_assert(is_equal_approx(finder.get_travel_weight(water_target), 1.45), "Frozen deep water must carry its tested pathfinding penalty")
	finder.set_deep_water_frozen(false)
	_assert(not finder.is_walkable(water_target), "Thawing must restore deep water as an impassable navigation cell")

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
	sim.set_physical_resource(&"wood", 180, sim.blueprint.starting_cell)
	sim.set_physical_resource(&"rock", 180, sim.blueprint.starting_cell)
	var food_before := int(sim.resources.raw_vegetables)
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
	var early_well: Dictionary = sim.buildings.filter(func(building: Dictionary) -> bool: return String(building.definition_id) == "well")[0]
	_assert(int(early_well.stored_resources.clean_water) > 0, "Completed Well must produce clean water in its local reservoir")
	_assert(int(sim.task_board.debug_summary().get("claimed", 0)) >= 1, "Farmers must reserve harvest work after construction")

func _test_storage_profiles_and_filters() -> void:
	ProgressionService.reset_profile_progress()
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(62626, &"applemeadow", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sandbox.needs_rate = 0.0
	sim.start_region(blueprint, sandbox)
	sim.animals.clear()

	var typed_storage_ids := ["wood_storage", "rock_storage", "crystal_storage", "mineral_storage", "food_storage", "gold_storage", "ammo_storage", "equipment_storage", "miscellaneous_storage", "key_shack"]
	for storage_id in typed_storage_ids:
		var definition: Dictionary = registry.get_by_id(&"buildings", StringName(storage_id))
		_assert(not definition.get("storage_profile", {}).is_empty(), "%s must define a typed storage profile" % storage_id)
		var probe := {"definition_id": storage_id, "tier": 1}
		_assert(not sim.get_storage_profile_resources(probe).is_empty(), "%s storage profile must resolve at least one accepted resource" % storage_id)
		_assert(sim.get_storage_profile_capacity(probe) > 0, "%s storage profile must define positive tier capacity" % storage_id)

	var base_bow_cap := int(sim.resource_caps.bow)
	var base_axe_cap := int(sim.resource_caps.axe)
	var base_food_cap := int(sim.resource_caps.raw_vegetables)
	var equipment := _place_sandbox_building(&"equipment_storage")
	_assert(not equipment.is_empty(), "Sandbox must place Equipment Storage for filter testing")
	_assert(int(sim.resource_caps.bow) == base_bow_cap + 10 and int(sim.resource_caps.axe) == base_axe_cap + 10, "Tier-one Equipment Storage must add its exact 10 capacity to weapons and tools")
	_assert(int(sim.resource_caps.raw_vegetables) == base_food_cap, "Equipment Storage must not increase food capacity")
	equipment.tier = 5
	sim._recalculate_settlement_support()
	_assert(int(sim.resource_caps.bow) == base_bow_cap + 26, "Tier-five Equipment Storage must expose the wiki-supported 26 capacity")

	sim.submit(GameCommand.set_storage_filter(sim.tick, int(equipment.id), &"bow", false))
	sim.advance_tick()
	_assert(not bool(equipment.storage_filters.bow) and int(sim.resource_caps.bow) == base_bow_cap, "Blocking bows must remove only that storage capacity")
	_assert(int(sim.resource_caps.axe) == base_axe_cap + 26 and String(equipment.operation_state) == "storage_filtered", "Other equipment filters must remain active when one resource is blocked")
	for resource_id in sim.get_storage_profile_resources(equipment):
		sim.submit(GameCommand.set_storage_filter(sim.tick, int(equipment.id), StringName(resource_id), false))
	sim.advance_tick()
	_assert(String(equipment.operation_state) == "storage_blocked" and int(sim.resource_caps.axe) == base_axe_cap, "Disabling every filter must block the storage and remove its capacity")
	sim.submit(GameCommand.set_storage_filter(sim.tick, int(equipment.id), &"axe", true))
	sim.advance_tick()
	var equipment_id := int(equipment.id)
	var saved_axe_cap := int(sim.resource_caps.axe)
	var state: Dictionary = sim.export_state()
	_assert(sim.import_state(state), "Storage-filter state must reload successfully")
	var restored_equipment: Dictionary = sim._find_building(equipment_id)
	_assert(bool(restored_equipment.storage_filters.axe) and not bool(restored_equipment.storage_filters.bow), "Save/load must preserve individual storage filters")
	_assert(int(sim.resource_caps.axe) == saved_axe_cap, "Save/load must rebuild the filtered resource capacities exactly")

	var ancillary := _place_sandbox_building(&"ancillary")
	ancillary.tier = 5
	sim._recalculate_settlement_support()
	_assert(int(sim.resource_caps.raw_vegetables) == base_food_cap + 64, "Tier-five Ancillary must contribute its wiki-supported 64 general-storage capacity")
	_assert(int(sim.resource_caps.energy) == 1000, "Ancillary storage must exclude nonphysical energy capacity")
	_assert(int(sim.resource_caps.trashy_trash) == 0, "Ancillary storage must exclude trash resources")

func _test_staffed_workplace_attendance() -> void:
	ProgressionService.reset_profile_progress()
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(63636, &"applemeadow", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sandbox.needs_rate = 0.0
	sim.start_region(blueprint, sandbox)
	sim.animals.clear()
	var kitchen := _place_sandbox_building(&"kitchen")
	_assert(not kitchen.is_empty() and int(sim.jobs.cooks.current) > 0, "Completed Kitchen must assign Cook workers")
	sim.set_physical_resource(&"raw_vegetables", 100, sim.blueprint.starting_cell)
	sim.set_physical_resource(&"rations", 0, sim.blueprint.starting_cell)
	for villager in sim.villagers:
		if String(villager.job) == "cooks":
			sim._release_villager_task(villager)
			var walkable_start: Vector2i = sim.pathfinder.nearest_walkable(Vector2i(int(kitchen.x) + int(kitchen.width) + 7, int(kitchen.y) + int(kitchen.height) + 5))
			villager.x = float(walkable_start.x) + 0.5
			villager.y = float(walkable_start.y) + 0.5
	sim._refresh_task_board()
	sim._update_production()
	_assert(int(sim.resources.rations) == 0 and String(kitchen.operation_state) == "missing_worker", "A staffed production building must not operate while its assigned workers are away")
	var attended := false
	for _index in 320:
		sim.advance_tick()
		if int(kitchen.get("active_worker_count", 0)) > 0:
			attended = true
		if int(sim.resources.rations) > 0:
			break
	_assert(attended, "A Cook must reserve the Kitchen workplace and physically travel on site")
	_assert(int(sim.resources.rations) > 0, "Kitchen production must resume after a Cook reaches the workplace")
	var assigned_cooks: Array = sim.villagers.filter(func(villager: Dictionary) -> bool: return String(villager.job) == "cooks" and String(villager.get("task_kind", "")) == "operate_building")
	_assert(not assigned_cooks.is_empty() and String(assigned_cooks[0].state).begins_with("operating_"), "An attending Cook must expose a visible workplace task and operating state")
	kitchen.destroyed = true
	sim._refresh_task_board()
	for _index in 2:
		sim.advance_tick()
	_assert(assigned_cooks.is_empty() or int(assigned_cooks[0].get("task_id", 0)) == 0, "Destroying a workplace must invalidate and release its worker reservations")

func _test_water_network() -> void:
	ProgressionService.reset_profile_progress()
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(81818, &"applemeadow", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sandbox.needs_rate = 0.0
	sim.start_region(blueprint, sandbox)
	sim.animals.clear()
	sim.set_physical_resource(&"clean_water", 0, sim.blueprint.starting_cell)
	sim.set_physical_resource(&"water_bottle", 0, sim.blueprint.starting_cell)
	var well := _place_sandbox_building(&"well")
	_assert(not well.is_empty() and int(well.storage_caps.clean_water) == 32, "Well must expose a saved 32-unit local clean-water reservoir")
	for _index in 46:
		sim.advance_tick()
	_assert(int(well.stored_resources.clean_water) == 1 and int(sim.resources.clean_water) == 0, "Well production must fill its local reservoir instead of teleporting water into global inventory")
	for villager in sim.villagers:
		villager.thirst = 1000
	var drinker: Dictionary = sim.villagers[0]
	var well_center: Vector2 = sim._water_building_center(well)
	drinker.x = well_center.x
	drinker.y = well_center.y
	drinker.thirst = 600
	sim.advance_tick()
	_assert(int(drinker.thirst) >= 900 and int(well.stored_resources.clean_water) == 0, "A thirsty villager at a Well must consume local water and recover thirst")
	drinker.x = float(blueprint.starting_cell.x + 20)
	drinker.y = float(blueprint.starting_cell.y)
	drinker.thirst = 600
	sim.set_physical_resource(&"water_bottle", 1, sim.blueprint.starting_cell)
	sim.advance_tick()
	_assert(int(drinker.thirst) >= 1000 and int(sim.resources.water_bottle) == 0 and String(drinker.state) == "drinking_bottled_water", "Bottled water must remain the portable no-travel drinking option")

	var catcher := _place_sandbox_building(&"rain_catcher")
	sim.weather = &"clear"
	for _index in 30:
		sim.advance_tick()
	_assert(int(catcher.stored_resources.clean_water) == 0 and String(catcher.operation_state) == "waiting_for_rain", "Rain Catcher must remain empty during clear weather")
	sim.weather = &"rain"
	for _index in 30:
		sim.advance_tick()
	_assert(int(catcher.stored_resources.clean_water) == 2 and int(ProgressionService.counters.get("water.generated.rain", 0)) == 2, "Rain Catcher must accumulate deterministic local water only while raining")

	sim.start_region(blueprint, sandbox)
	sim.animals.clear()
	sim.set_physical_resource(&"clean_water", 0, sim.blueprint.starting_cell)
	var purifier_cell := blueprint.starting_cell - Vector2i(4, 3)
	sim.submit(GameCommand.place_building(sim.tick, &"water_purifier", purifier_cell))
	sim.advance_tick()
	var purifier: Dictionary = sim.buildings.back()
	_assert(String(purifier.definition_id) == "water_purifier" and int(sim.jobs.water_masters.current) > 0, "Completed Water Purifier must activate Water Masters")
	for villager in sim.villagers:
		villager.thirst = 1000
	for _index in 700:
		sim.advance_tick()
	_assert(int(ProgressionService.counters.get("water.surface_collected", 0)) > 0, "Water Masters must claim surface-water work and collect dirty buckets from a reachable pond")
	_assert(int(ProgressionService.counters.get("water.purified", 0)) > 0 and int(purifier.stored_resources.clean_water) > 0, "Purifier must consume delivered dirty water and create locally stored clean water")

	var fountain := _place_sandbox_building(&"small_fountain")
	_assert(int(fountain.storage_caps.clean_water) == 48, "Small Fountain must expose its documented 48-unit local capacity")
	for _index in 420:
		sim.advance_tick()
	_assert(int(fountain.stored_resources.clean_water) > 0 and int(ProgressionService.counters.get("water.delivered", 0)) > 0, "Water Masters or Organizers must physically deliver clean water from a source to a Fountain")
	var saved_water := int(fountain.stored_resources.clean_water)
	var fountain_id := int(fountain.id)
	var state: Dictionary = sim.export_state()
	_assert(sim.import_state(state), "Water-network state must reload successfully")
	_assert(int(sim._find_building(fountain_id).stored_resources.clean_water) == saved_water, "Save/load must preserve per-building water reservoirs exactly")
	_test_simulation_and_goal()

func _test_natural_resource_lifecycle() -> void:
	var blueprint := RegionBlueprint.new(7713, &"applemeadow", &"forest", 72, 72)
	blueprint.starting_cell = Vector2i(36, 36)
	for y in blueprint.height:
		for x in blueprint.width:
			blueprint.set_tile(Vector2i(x, y), RegionGenerator.Tile.GRASS)
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(blueprint, sandbox)
	sim.resource_nodes.clear()
	var lifecycle_nodes: Array[Dictionary] = [
		{"entity_id": 7001, "id": "wood", "x": 32, "y": 32, "amount": 0, "initial_amount": 10, "variant": 0},
		{"entity_id": 7002, "id": "rock", "x": 34, "y": 32, "amount": 0, "initial_amount": 10, "variant": 1},
		{"entity_id": 7003, "id": "crystal", "x": 36, "y": 32, "amount": 0, "initial_amount": 10, "variant": 2},
		{"entity_id": 7004, "id": "raw_vegetables", "x": 38, "y": 32, "amount": 0, "initial_amount": 10, "variant": 3},
	]
	for lifecycle_node in lifecycle_nodes:
		sim.resource_nodes.append(lifecycle_node)
	sim.tick = sim.NATURAL_REGROWTH_INTERVAL - 1
	sim.advance_tick()
	_assert(int(sim.resource_nodes[0].amount) == 1 and int(sim.resource_nodes[2].amount) == 1 and int(sim.resource_nodes[3].amount) == 1, "Trees, crystals, and wild food must naturally begin regrowing")
	_assert(int(sim.resource_nodes[1].amount) == 0, "Harvested rock must remain nonrenewable under natural regrowth")
	for index in [0, 2, 3]:
		sim.resource_nodes[index].amount = 0
	sim.submit(GameCommand.cast_spell(sim.tick, &"motivate_land", Vector2i(35, 32)))
	sim.advance_tick()
	_assert(int(sim.resource_nodes[0].amount) >= 5 and int(sim.resource_nodes[2].amount) >= 5 and int(sim.resource_nodes[3].amount) >= 5, "Motivate Land must restore depleted trees, crystals, and wild food in its radius")
	_assert(int(sim.resource_nodes[1].amount) == 0, "Motivate Land must not restore rock")
	var motivator: Dictionary = _place_sandbox_building(&"crystal_motivator")
	_assert(not motivator.is_empty(), "Crystal Motivator lifecycle test must place its building")
	sim.resource_nodes[2].x = int(motivator.x) + 2
	sim.resource_nodes[2].y = int(motivator.y) + 2
	sim.resource_nodes[2].amount = 0
	sim.tick = int(motivator.id) - 1
	sim.advance_tick()
	_assert(int(sim.resource_nodes[2].amount) == 1 and String(motivator.operation_state) == "motivating", "Crystal Motivator must visibly restore nearby depleted crystals")
	# Corruption owns the resource lifecycle as well as the ground presentation:
	# living vegetation withers, permanent rock survives, and no renewable node
	# may heal while its cell remains infected.
	var corrupted_node_indices: Array[int] = [0, 1, 2, 3]
	for index in corrupted_node_indices:
		var infected_node: Dictionary = sim.resource_nodes[index]
		sim.corruption_cells[sim._cell_key(Vector2i(int(infected_node.x), int(infected_node.y)))] = 1000
	sim.resource_nodes[0].amount = 3
	sim.resource_nodes[1].amount = 3
	sim.resource_nodes[2].amount = 0
	sim.resource_nodes[3].amount = 3
	sim._damage_corrupted_resources()
	_assert(int(sim.resource_nodes[0].amount) == 2 and int(sim.resource_nodes[3].amount) == 2, "Corruption must visibly wither trees and wild food over time")
	_assert(int(sim.resource_nodes[1].amount) == 3, "Corruption must not consume permanent rock deposits")
	sim.tick = sim.NATURAL_REGROWTH_INTERVAL
	sim._update_natural_resources()
	_assert(int(sim.resource_nodes[0].amount) == 2 and int(sim.resource_nodes[2].amount) == 0 and int(sim.resource_nodes[3].amount) == 2, "Corrupted renewable resources must not naturally regrow")
	sim.tick = int(motivator.id)
	sim._update_crystal_motivators()
	_assert(int(sim.resource_nodes[2].amount) == 0, "Crystal Motivators must not restore deposits under corruption")
	var state: Dictionary = sim.export_state()
	sim.import_state(state)
	_assert(int(sim.resource_nodes[0].initial_amount) == 10 and int(sim.resource_nodes[2].initial_amount) == 10, "Natural-resource capacity and depletion stages must survive save/load")
	_test_simulation_and_goal()

func _test_resource_rates() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(9393, &"applemeadow", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(blueprint, sandbox)
	var farm: Dictionary = _place_sandbox_building(&"farm")
	_assert(not farm.is_empty(), "Resource-rate test Farm must find a valid generated footprint")
	sim.set_physical_resource(&"raw_vegetables", 0, sim.blueprint.starting_cell)
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

func _test_settlement_range_and_corruption() -> void:
	ProgressionService.reset_profile_progress()
	var blueprint := RegionBlueprint.new(5511, &"applemeadow", &"forest", 96, 72)
	blueprint.starting_cell = Vector2i(20, 36)
	for y in blueprint.height:
		for x in blueprint.width:
			blueprint.set_tile(Vector2i(x, y), RegionGenerator.Tile.GRASS)
	for y in range(47, 50):
		for x in range(49, 52):
			blueprint.set_tile(Vector2i(x, y), RegionGenerator.Tile.CORRUPTION)
	var rules: Dictionary = registry.get_by_id(&"modes", &"traditional").duplicate(true)
	rules.instant_build = true
	rules.corruption_rate = 0.0
	rules.first_attack_day = 999
	sim.start_region(blueprint, rules)
	for resource_id in sim.resources:
		sim.set_physical_resource(StringName(resource_id), 1000, sim.blueprint.starting_cell)
	sim.submit(GameCommand.place_building(sim.tick, &"camp", Vector2i(14, 30)))
	sim.advance_tick()
	_assert(sim.buildings.size() == 1 and bool(sim.buildings[0].completed), "Range test Camp must complete immediately")
	var chained_site := Vector2i(58, 33)
	_assert(not sim.is_within_settlement_range(chained_site, Vector2i(7, 7)), "A site beyond the Camp radius must initially be out of range")
	sim.submit(GameCommand.place_building(sim.tick, &"fire_pit", Vector2i(49, 35)))
	sim.advance_tick()
	_assert(sim.buildings.size() == 2 and sim.get_building_settlement_range(sim.buildings[1]) == 12, "Completed Fire Pit must cast its documented 12-cell range")
	_assert(sim.is_within_settlement_range(chained_site, Vector2i(7, 7)), "A completed Fire Pit must extend the connected settlement footprint beyond the Camp")
	sim.submit(GameCommand.place_building(sim.tick, &"housing", chained_site))
	sim.advance_tick()
	_assert(sim.buildings.size() == 3 and String(sim.buildings[2].definition_id) == "housing", "Extended settlement range must permit a chained building placement")
	var ancillary_tier_one := {"definition_id": "ancillary", "tier": 1, "completed": true, "destroyed": false}
	var ancillary_tier_five := {"definition_id": "ancillary", "tier": 5, "completed": true, "destroyed": false}
	_assert(sim.get_building_settlement_range(ancillary_tier_one) == 20 and sim.get_building_settlement_range(ancillary_tier_five) == 28, "Ancillary range must progress deterministically from 20 to 28")
	var wall := {"definition_id": "wood_wall", "tier": 1, "completed": true, "destroyed": false}
	_assert(sim.get_building_settlement_range(wall) == 0, "Walls must not cast settlement or corruption-resistance range")
	var corruption_before: int = sim.corruption_cells.size()
	ProgressionService.set_counter(&"corruption.reclaimed", 255)
	for _index in 155:
		sim.advance_tick()
	_assert(sim.corruption_cells.size() < corruption_before, "Completed non-wall buildings must steadily reclaim corruption inside their resistance coverage")
	_assert(int(ProgressionService.counters.get("corruption.reclaimed", 0)) > 0, "Reclaimed corruption must feed persistent progression statistics")
	_assert(ProgressionService.completed.has("take_it_back"), "Reclaiming 256 corruption cells must complete the official Take it Back achievement")
	_test_simulation_and_goal()

func _test_hostile_corruption_infrastructure() -> void:
	ProgressionService.reset_profile_progress()
	var blueprint := RegionBlueprint.new(9551, &"applemeadow", &"forest", 96, 72)
	blueprint.starting_cell = Vector2i(18, 36)
	for y in blueprint.height:
		for x in blueprint.width:
			blueprint.set_tile(Vector2i(x, y), RegionGenerator.Tile.GRASS)
	for y in range(12, 61):
		for x in range(42, 90):
			blueprint.set_tile(Vector2i(x, y), RegionGenerator.Tile.CORRUPTION)
	var rules: Dictionary = registry.get_by_id(&"modes", &"nightmare").duplicate(true)
	rules.first_attack_day = 999
	rules.corruption_rate = 0.0
	sim.start_region(blueprint, rules)
	_assert(not bool(registry.get_by_id(&"buildings", &"corrupted_tower").get("player_placeable", true)), "Corrupted structures must be validated content but hidden from the player build catalog")
	var weak_key: String = String(sim._cell_key(Vector2i(44, 20)))
	sim.corruption_cells[weak_key] = 250
	var snapshot: SimulationSnapshot = sim.get_snapshot()
	var weak_entry: Array = snapshot.corruption_cells.filter(func(entry: Array) -> bool: return int(entry[0]) == 44 and int(entry[1]) == 20)
	_assert(weak_entry.size() == 1 and float(weak_entry[0][2]) <= 0.26, "Snapshots must preserve corruption strength for visual threat shading")
	var drone: Dictionary = sim._spawn_monster_actor(&"drone", Vector2(53.5, 36.5))
	drone.id = sim.DRONE_BUILD_INTERVAL
	sim.tick = sim.DRONE_BUILD_INTERVAL - 1
	sim.advance_tick()
	_assert(sim.hostile_structures.size() == 1 and String(sim.hostile_structures[0].ownership) == "corruption", "Drones must begin a typed hostile construction site on corrupted ground")
	var structure: Dictionary = sim.hostile_structures[0]
	for _index in 100:
		drone.x = float(structure.x) + float(structure.width) * 0.5
		drone.y = float(structure.y) + float(structure.height) * 0.5
		sim._update_drone_construction(drone)
		if bool(structure.completed):
			break
	_assert(bool(structure.completed), "Drones must complete hostile roads, walls, towers, fire pits, and graveyards through visible construction progress")
	var saved: Dictionary = sim.export_state()
	_assert(sim.import_state(saved) and sim.hostile_structures.size() == 1 and bool(sim.hostile_structures[0].completed), "Hostile infrastructure and corruption strength must survive save/load")
	var corrupted_wall_cell := Vector2i(82, 20)
	var corrupted_road_cell := Vector2i(79, 20)
	var corrupted_wall: Dictionary = sim._spawn_hostile_structure(&"corrupted_wall", corrupted_wall_cell)
	var corrupted_road: Dictionary = sim._spawn_hostile_structure(&"corrupted_road", corrupted_road_cell)
	_assert(not corrupted_wall.is_empty() and not corrupted_road.is_empty(), "Faction-navigation scenario must place separate corrupted road and wall segments")
	for faction_structure in [corrupted_wall, corrupted_road]:
		faction_structure.completed = true
		faction_structure.progress = int(faction_structure.build_time)
		faction_structure.health = int(faction_structure.max_health)
		faction_structure.operation_state = "active"
	sim._refresh_navigation_buildings()
	_assert(not sim.pathfinder.is_walkable(corrupted_wall_cell) and sim.hostile_pathfinder.is_walkable(corrupted_wall_cell), "Completed corrupted walls must block friendly routes but remain traversable to their own faction")
	_assert(sim.pathfinder.get_travel_weight(corrupted_road_cell) > 0.72 and is_equal_approx(sim.hostile_pathfinder.get_travel_weight(corrupted_road_cell), 0.72), "Corrupted roads must attract only hostile route planning")
	_assert(is_equal_approx(sim._road_speed_multiplier(corrupted_road_cell), 1.0) and is_equal_approx(sim._road_speed_multiplier(corrupted_road_cell, true), 1.22), "Corrupted-road movement bonuses must apply only to hostile actors")
	var faction_state: Dictionary = sim.export_state()
	_assert(sim.import_state(faction_state) and not sim.pathfinder.is_walkable(corrupted_wall_cell) and sim.hostile_pathfinder.is_walkable(corrupted_wall_cell), "Save/load must rebuild both faction navigation graphs from hostile structures")
	ProgressionService.set_counter(&"combat.destroyed.corrupted_buildings", 5)
	var target_cell := Vector2i(int(sim.hostile_structures[0].x), int(sim.hostile_structures[0].y))
	_assert(sim._damage_hostile_structures_in_radius(target_cell, 12.0, 99999, &"magic") == 1, "Divine damage must destroy hostile structures")
	_assert(ProgressionService.completed.has("fight_the_corruption"), "Destroying six corrupted structures must complete Fight The Corruption")
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
	var mend_building: Dictionary = sim.buildings[0]
	_assert(String(mend_building.get("ownership", "")) == "settlement" and String(mend_building.get("visual_state", "")) == "normal" and mend_building.get("status_effects", null) is Dictionary, "Every authoritative building must initialize the persisted visual/status contract")
	mend_building.health = maxi(1, int(mend_building.max_health) - 900)
	mend_building.burning = true
	mend_building.status_effects = {"burning": 240}
	var damaged_building_health := int(mend_building.health)
	var mend_cell := Vector2i(int(mend_building.x + mend_building.width / 2), int(mend_building.y + mend_building.height / 2))
	sim.influence = sim.max_influence
	sim.submit(GameCommand.cast_spell(sim.tick, &"mend", mend_cell))
	sim.advance_tick()
	_assert(int(mend_building.health) > damaged_building_health and not bool(mend_building.burning) and not mend_building.status_effects.has("burning"), "Mend must repair and fully extinguish the authoritative burning status rather than hiding its visual flag")

func _test_remaining_spell_mechanics() -> void:
	var generator := RegionGenerator.new()
	var spell_blueprint := generator.generate(73129, &"spell_mechanics_test", &"forest")
	var sandbox_rules: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(spell_blueprint, sandbox_rules)
	var center: Vector2i = spell_blueprint.starting_cell + Vector2i(10, 6)
	spell_blueprint.set_tile(center, RegionGenerator.Tile.GRASS)
	var charmed: Dictionary = sim._spawn_monster_actor(&"skeleton", Vector2(center) + Vector2(0.5, 0.5))
	var enemy: Dictionary = sim._spawn_monster_actor(&"zombie", Vector2(center + Vector2i(7, 0)) + Vector2(0.5, 0.5))
	sim.submit(GameCommand.cast_spell(sim.tick, &"charm", center))
	sim.advance_tick()
	_assert(int(charmed.get("charmed_ticks", 0)) > 0 and int(enemy.get("charmed_ticks", 0)) == 0, "Charm must convert only monsters inside its authoritative radius")
	_assert(sim._nearest_monster(Vector2(charmed.x, charmed.y), 20.0) == enemy, "Rangers, Doggos, golems, and towers must not target a charmed defender")
	enemy.x = float(charmed.x) + 1.0
	enemy.y = float(charmed.y)
	var enemy_before_charmed_hit := int(enemy.health)
	charmed.attack_cooldown = 0
	sim._update_monsters()
	_assert(int(enemy.health) < enemy_before_charmed_hit and String(charmed.state) == "charmed_attacking", "Charmed monsters must attack nearby uncharmed monsters instead of the settlement")
	var chilled: Dictionary = sim._spawn_monster_actor(&"fire_elemental", Vector2(center + Vector2i(0, 3)) + Vector2(0.5, 0.5))
	var chilled_health := int(chilled.health)
	sim.submit(GameCommand.cast_spell(sim.tick, &"cold_aura", center + Vector2i(0, 3)))
	sim.advance_tick()
	_assert(int(chilled.health) < chilled_health and int(chilled.get("cold_ticks", 0)) > 0, "Cold Aura must apply ice damage and a persisted movement-slow duration")
	var camp: Dictionary = _place_sandbox_building(&"camp")
	_assert(not camp.is_empty(), "Earthquake validation requires a completed settlement building")
	if not camp.is_empty():
		var camp_cell := Vector2i(int(camp.x) + int(camp.width) / 2, int(camp.y) + int(camp.height) / 2)
		var camp_health := int(camp.health)
		sim.submit(GameCommand.cast_spell(sim.tick, &"earthquake", camp_cell))
		sim.advance_tick()
		_assert(int(camp.health) < camp_health, "Earthquake must damage settlement structures inside its radius")
		_assert(sim.terrain_effects.values().any(func(effect: Dictionary) -> bool: return String(effect.get("kind", "")) == "hole"), "Earthquake must leave persistent, maintainable holes rather than a presentation-only shake")
	var illuminate_cell := center + Vector2i(14, 8)
	spell_blueprint.set_tile(illuminate_cell, RegionGenerator.Tile.GRASS)
	sim.submit(GameCommand.cast_spell(sim.tick, &"illuminate", illuminate_cell))
	sim.advance_tick()
	_assert(sim.terrain_effects.values().any(func(effect: Dictionary) -> bool: return String(effect.get("kind", "")) == "illuminated"), "Illuminate must create a timed, saved terrain-light field")
	sim._spawn_nomad_group(camp)
	var nomad: Dictionary = sim.nomads[0]
	nomad.x = float(center.x) + 0.5
	nomad.y = float(center.y) + 0.5
	ProgressionService.set_counter(&"spells.recalled.nomads", 31)
	sim.submit(GameCommand.cast_spell(sim.tick, &"recall", center))
	sim.advance_tick()
	var recalled_distance := Vector2(float(nomad.x), float(nomad.y)).distance_to(sim._settlement_anchor())
	_assert(String(nomad.get("population_state", "")) == "settled" and nomad in sim.villagers and nomad not in sim.nomads and recalled_distance < 8.0, "Recall must move targeted nomads into the established settlement population")
	_assert(int(ProgressionService.counters.get("spells.recalled.nomads", 0)) >= 32 and ProgressionService.completed.has("impatient"), "Recall must feed the official 32-nomad Impatient achievement")
	var storm_cell := center + Vector2i(20, 0)
	spell_blueprint.set_tile(storm_cell, RegionGenerator.Tile.GRASS)
	var storm_target: Dictionary = sim._spawn_monster_actor(&"drone", Vector2(storm_cell) + Vector2(0.5, 0.5))
	var storm_health := int(storm_target.health)
	sim.submit(GameCommand.cast_spell(sim.tick, &"storm", storm_cell))
	sim.advance_tick()
	_assert(sim.weather == &"rain" and sim.active_event == &"lightning_storm" and sim.event_ticks_remaining > 0, "Storm must authoritatively start persisted rain and a timed lightning-storm event")
	_assert(int(storm_target.health) < storm_health, "Storm must land an immediate deterministic lightning strike at its target")
	var persistence_cell := spell_blueprint.starting_cell + Vector2i(-20, -16)
	var persistence_monster: Dictionary = sim._spawn_monster_actor(&"slime", Vector2(persistence_cell) + Vector2(0.5, 0.5))
	sim._charm_monsters(persistence_cell, 2.0, 177)
	var spell_state: Dictionary = sim.export_state()
	var persistence_id := int(persistence_monster.id)
	var charmed_ticks_before := int(persistence_monster.get("charmed_ticks", 0))
	var illuminated_before: int = sim.terrain_effects.values().filter(func(effect: Dictionary) -> bool: return String(effect.get("kind", "")) == "illuminated").size()
	_assert(sim.import_state(spell_state), "Completed divine-power states must load successfully")
	_assert(sim.monsters.any(func(monster: Dictionary) -> bool: return int(monster.get("id", 0)) == persistence_id and int(monster.get("charmed_ticks", 0)) == charmed_ticks_before), "Charm duration must survive exact save/load")
	_assert(sim.terrain_effects.values().filter(func(effect: Dictionary) -> bool: return String(effect.get("kind", "")) == "illuminated").size() == illuminated_before, "Illuminate fields must survive exact save/load")
	# Maintained God structures are intentionally tested with normal influence
	# rules even inside this isolated Sandbox scenario.
	sim.mode_rules.unlimited_influence = false
	sim.max_influence = 6000
	sim.influence = 6000
	sim.influence_reserved = 0
	var wall_definition: Dictionary = registry.get_by_id(&"spells", &"god_wall")
	var tower_definition: Dictionary = registry.get_by_id(&"spells", &"god_tower")
	var wall_cell := _find_valid_god_structure_cell(wall_definition, spell_blueprint.starting_cell + Vector2i(-24, 18))
	_assert(wall_cell.x >= 0, "God Wall validation requires one clear buildable cell")
	sim.submit(GameCommand.cast_spell(sim.tick, &"god_wall", wall_cell))
	sim.advance_tick()
	var god_wall: Dictionary = sim.buildings.filter(func(building: Dictionary) -> bool: return String(building.get("definition_id", "")) == "god_wall")[0] if sim.buildings.any(func(building: Dictionary) -> bool: return String(building.get("definition_id", "")) == "god_wall") else {}
	_assert(not god_wall.is_empty() and sim.influence_reserved == int(wall_definition.maintenance), "God Wall must reserve influence and exist as an authoritative structure")
	_assert(not sim.pathfinder.is_walkable(wall_cell), "God Wall must block friendly and hostile pathfinding at its physical cell")
	var tower_cell := _find_valid_god_structure_cell(tower_definition, spell_blueprint.starting_cell + Vector2i(24, 18))
	_assert(tower_cell.x >= 0, "God Tower validation requires one clear five-cell footprint")
	sim.submit(GameCommand.cast_spell(sim.tick, &"god_tower", tower_cell))
	sim.advance_tick()
	var god_tower: Dictionary = sim.buildings.filter(func(building: Dictionary) -> bool: return String(building.get("definition_id", "")) == "god_tower")[0] if sim.buildings.any(func(building: Dictionary) -> bool: return String(building.get("definition_id", "")) == "god_tower") else {}
	var expected_reserved := int(wall_definition.maintenance) + int(tower_definition.maintenance)
	_assert(not god_tower.is_empty() and sim.influence_reserved == expected_reserved, "God Tower must reserve influence independently from its one-time cast cost")
	var god_state: Dictionary = sim.export_state()
	var wall_id := int(god_wall.get("id", 0))
	var tower_id := int(god_tower.get("id", 0))
	_assert(sim.import_state(god_state) and sim.influence_reserved == expected_reserved and not sim.pathfinder.is_walkable(wall_cell), "Maintained God structures and their navigation/maintenance state must survive save/load")
	god_wall = sim._find_building(wall_id)
	god_tower = sim._find_building(tower_id)
	sim.monsters.clear()
	var tower_center := Vector2(float(god_tower.x) + float(god_tower.width) * 0.5, float(god_tower.y) + float(god_tower.height) * 0.5)
	var divine_target: Dictionary = sim._spawn_monster_actor(&"zombie", tower_center + Vector2(6.0, 0.0))
	var divine_target_health := int(divine_target.health)
	god_tower.combat_cooldown = 0
	sim._update_towers()
	_assert(int(divine_target.health) < divine_target_health and String(god_tower.combat_state) == "firing", "God Tower must acquire and damage hostile actors without ammunition or energy payloads")
	var influence_before_invalid: int = sim.influence
	var invalid_cell := Vector2i(-1, -1)
	for y in spell_blueprint.height:
		for x in spell_blueprint.width:
			if spell_blueprint.get_tile(Vector2i(x, y)) == RegionGenerator.Tile.DEEP_WATER:
				invalid_cell = Vector2i(x, y)
				break
		if invalid_cell.x >= 0:
			break
	_assert(invalid_cell.x >= 0, "God-structure placement test requires a deep-water cell")
	sim.submit(GameCommand.cast_spell(sim.tick, &"god_wall", invalid_cell))
	sim.advance_tick()
	_assert(sim.influence == influence_before_invalid and sim.influence_reserved == expected_reserved, "Invalid God-structure placement must reject before spending or reserving influence")
	var dispels_before := int(ProgressionService.counters.get("spells.dispelled.golem_or_building", 0))
	sim.submit(GameCommand.cast_spell(sim.tick, &"dispel_god_structure", wall_cell))
	sim.advance_tick()
	_assert(sim._find_building(wall_id).is_empty() and sim.influence_reserved == int(tower_definition.maintenance) and sim.pathfinder.is_walkable(wall_cell), "Dispel God Structure must remove the wall, release maintenance, and reopen navigation")
	var tower_target_cell := Vector2i(int(god_tower.x) + int(god_tower.width) / 2, int(god_tower.y) + int(god_tower.height) / 2)
	sim.submit(GameCommand.cast_spell(sim.tick, &"dispel_god_structure", tower_target_cell))
	sim.advance_tick()
	_assert(sim._find_building(tower_id).is_empty() and sim.influence_reserved == 0, "Dispel God Structure must release the tower's full reserved influence")
	_assert(int(ProgressionService.counters.get("spells.dispelled.golem_or_building", 0)) >= dispels_before + 2, "God-structure dispels must feed the shared official dispel achievement counter")
	_test_simulation_and_goal()

func _test_nomad_arrivals_and_recall() -> void:
	var generator := RegionGenerator.new()
	var nomad_blueprint := generator.generate(84921, &"nomad_test", &"forest")
	var rules: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(nomad_blueprint, rules)
	var camp: Dictionary = _place_sandbox_building(&"camp")
	var housing: Dictionary = {}
	for _index in 4:
		housing = _place_sandbox_building(&"housing")
	_assert(not camp.is_empty() and not housing.is_empty() and sim.housing_capacity > sim.villagers.size(), "Nomad arrival scenario requires an operational settlement with spare housing")
	var residents_before: int = sim.villagers.size()
	var spawned: int = sim._spawn_nomad_group(camp)
	_assert(spawned >= 2 and sim.nomads.size() == spawned, "A deterministic nomad event must create a visible approaching group")
	_assert(int(sim.get_snapshot().population_groups.get("nomads", 0)) == spawned and sim.get_snapshot().nomads.size() == spawned, "Snapshots and the mobile HUD must expose approaching nomads separately from residents")
	var entry_position := Vector2(float(sim.nomads[0].x), float(sim.nomads[0].y))
	sim._update_nomads()
	_assert(entry_position.distance_to(sim._settlement_anchor()) > 8.0 and not sim.nomads[0].get("path", []).is_empty(), "Nomads must enter away from the town center and own deterministic travel state")
	var nomad_state: Dictionary = sim.export_state()
	var saved_nomad_ids: Array = sim.nomads.map(func(nomad: Dictionary) -> int: return int(nomad.id))
	_assert(sim.import_state(nomad_state) and sim.nomads.map(func(nomad: Dictionary) -> int: return int(nomad.id)) == saved_nomad_ids, "Nomad groups and their next-arrival schedule must survive exact save/load")
	var arriving: Dictionary = sim.nomads[0]
	var anchor: Vector2 = sim._settlement_anchor()
	arriving.x = anchor.x
	arriving.y = anchor.y
	sim._update_nomads()
	_assert(sim.villagers.size() == residents_before + 1 and arriving not in sim.nomads and String(arriving.get("population_state", "")) == "settled", "A housed nomad reaching the town center must join the resident workforce")
	_assert(int(ProgressionService.counters.get("population.nomads_joined", 0)) >= 1, "Natural nomad admission must feed Immigrant Song progress")
	# Recall must operate on the real approaching-nomad collection, not a test-only
	# flag attached to an existing resident.
	var recall_cell := nomad_blueprint.starting_cell + Vector2i(18, 10)
	for index in sim.nomads.size():
		sim.nomads[index].x = float(recall_cell.x) + 0.5 + float(index % 3)
		sim.nomads[index].y = float(recall_cell.y) + 0.5 + float(index / 3)
	ProgressionService.set_counter(&"spells.recalled.nomads", 31)
	sim.submit(GameCommand.cast_spell(sim.tick, &"recall", recall_cell))
	sim.advance_tick()
	_assert(sim.nomads.is_empty() and sim.villagers.size() == residents_before + spawned, "Recall must admit every approaching nomad inside its radius into the authoritative resident list")
	_assert(ProgressionService.completed.has("impatient"), "Recalling the 32nd nomad must complete the official Impatient achievement")
	# With no spare homes, naturally arriving nomads remain visibly camped rather
	# than silently disappearing or bypassing population capacity.
	sim._spawn_nomad_group(camp)
	sim.housing_capacity = sim.villagers.size()
	var waiting: Dictionary = sim.nomads[0]
	waiting.x = anchor.x
	waiting.y = anchor.y
	sim._update_nomads()
	_assert(waiting in sim.nomads and String(waiting.state) == "waiting_for_housing", "Nomads must wait at the settlement when housing is full")
	_test_simulation_and_goal()

func _test_grab_and_cullis_gate() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(26841, &"cullis_test", &"forest")
	sim.start_region(blueprint, registry.get_by_id(&"modes", &"sandbox"))
	var gate: Dictionary = _place_sandbox_building(&"cullis_gate")
	_assert(not gate.is_empty() and bool(gate.get("completed", false)), "Cullis Gate scenario requires a completed, authoritative sacrifice building")
	if gate.is_empty():
		_test_simulation_and_goal()
		return
	var gate_id := int(gate.id)
	var gate_cell := Vector2i(int(gate.x) + int(gate.width) / 2, int(gate.y) + int(gate.height) / 2)
	# The Hand keeps population accounting stable while the authoritative actor is
	# removed from every task/combat update, and the held payload is saveable.
	var adult: Dictionary = sim.villagers.filter(func(villager: Dictionary) -> bool: return String(villager.age_stage) == "adult")[0]
	var adult_id := int(adult.id)
	var pickup_cell: Vector2i = sim.pathfinder.nearest_walkable(blueprint.starting_cell + Vector2i(18, 10))
	adult.x = float(pickup_cell.x) + 0.5
	adult.y = float(pickup_cell.y) + 0.5
	var population_before: int = sim.get_snapshot().population
	sim.submit(GameCommand.cast_spell(sim.tick, &"grab", pickup_cell))
	sim.advance_tick()
	_assert(String(sim.held_entity.get("kind", "")) == "villager" and int(sim.held_entity.get("payload", {}).get("id", 0)) == adult_id, "Divine Hand must lift the tapped villager into authoritative held state")
	_assert(sim.get_snapshot().population == population_before and sim._find_villager(adult_id).is_empty(), "A held villager must remain in population totals without continuing simulation work")
	var held_hash: String = sim.compute_state_hash()
	var held_state: Dictionary = sim.export_state()
	_assert(sim.import_state(held_state) and sim.compute_state_hash() == held_hash and int(sim.held_entity.get("payload", {}).get("id", 0)) == adult_id, "Held actors must survive deterministic save/load without duplication or state drift")
	var safe_drop: Vector2i = sim.pathfinder.nearest_walkable(blueprint.starting_cell + Vector2i(13, 14))
	sim.submit(GameCommand.cast_spell(sim.tick, &"grab", safe_drop))
	sim.advance_tick()
	_assert(sim.held_entity.is_empty() and not sim._find_villager(adult_id).is_empty(), "A second Hand target must release the actor on valid friendly terrain")
	gate = sim._find_building(gate_id)
	# Doofy Doggo is deliberately authored because it is not part of the normal
	# starting herd. Its sacrifice binds the current official War Crimes goal.
	var doofy_cell: Vector2i = sim.pathfinder.nearest_walkable(blueprint.starting_cell + Vector2i(-20, 12))
	var doofy := {
		"id": sim._next_id(), "definition_id": "doofy_doggo", "name": "Doofy Doggo",
		"x": float(doofy_cell.x) + 0.5, "y": float(doofy_cell.y) + 0.5, "target_x": float(doofy_cell.x) + 0.5, "target_y": float(doofy_cell.y) + 0.5,
		"health": 420, "hunger": 1000, "thirst": 1000, "energy": 1000, "age_days": 20, "age_stage": "adult", "sex": "male",
		"domesticated": true, "pregnant_ticks": 0, "home_id": 0, "capture_designated": false, "slaughter_designated": false, "slaughtered": false,
		"state": "wandering", "path": [], "path_index": 0, "path_goal_x": -1, "path_goal_y": -1, "stuck_ticks": 0,
	}
	sim.animals.append(doofy)
	var doofy_counter_before := int(ProgressionService.counters.get("cullis.sacrificed.doofy_doggo", 0))
	sim.submit(GameCommand.cast_spell(sim.tick, &"grab", doofy_cell))
	sim.advance_tick()
	sim.submit(GameCommand.cast_spell(sim.tick, &"grab", gate_cell))
	sim.advance_tick()
	gate = sim._find_building(gate_id)
	_assert(sim.held_entity.is_empty() and int(sim.resources.get("essence", 0)) >= 12, "Dropping a held Doofy Doggo into the gate must destroy it and release typed essence")
	_assert(int(ProgressionService.counters.get("cullis.sacrificed.doofy_doggo", 0)) == doofy_counter_before + 1 and ProgressionService.completed.has("war_crimes"), "Doofy Doggo sacrifice must complete the official War Crimes achievement exactly once")
	_assert(int(gate.get("cullis_instability", 0)) >= int(registry.get_by_id(&"buildings", &"cullis_gate").cullis.lightning_threshold) and int(gate.health) < int(gate.max_health), "A high-value rapid sacrifice must build instability and cause real lightning damage")
	var child: Dictionary = sim.villagers.filter(func(villager: Dictionary) -> bool: return String(villager.age_stage) == "child")[0]
	var child_cell: Vector2i = sim.pathfinder.nearest_walkable(blueprint.starting_cell + Vector2i(19, -13))
	child.x = float(child_cell.x) + 0.5
	child.y = float(child_cell.y) + 0.5
	var child_counter_before := int(ProgressionService.counters.get("cullis.sacrificed.child", 0))
	sim.submit(GameCommand.cast_spell(sim.tick, &"grab", child_cell))
	sim.advance_tick()
	sim.submit(GameCommand.cast_spell(sim.tick, &"grab", gate_cell))
	sim.advance_tick()
	_assert(int(ProgressionService.counters.get("cullis.sacrificed.child", 0)) == child_counter_before + 1 and ProgressionService.completed.has("omg"), "Child sacrifice must complete the official OMG achievement exactly once")
	# One rapidly-following Spectre crosses the provisional overload threshold and
	# proves the destructive quake is simulation state, not presentation theater.
	var spectre_cell: Vector2i = sim.hostile_pathfinder.nearest_walkable(blueprint.starting_cell + Vector2i(-18, -15))
	var spectre: Dictionary = sim._spawn_monster_actor(&"spectre", Vector2(spectre_cell) + Vector2(0.5, 0.5))
	sim.submit(GameCommand.cast_spell(sim.tick, &"grab", spectre_cell))
	sim.advance_tick()
	sim.submit(GameCommand.cast_spell(sim.tick, &"grab", gate_cell))
	sim.advance_tick()
	gate = sim._find_building(gate_id)
	_assert(bool(gate.get("destroyed", false)) and String(gate.get("operation_state", "")) == "overloaded", "Rapid Cullis use must overload and destroy the gate")
	_assert(int(ProgressionService.counters.get("cullis.overloads", 0)) >= 1 and sim.terrain_effects.values().any(func(effect: Dictionary) -> bool: return String(effect.get("kind", "")) == "hole"), "Cullis overload must create persistent quake aftermath and statistics")
	_assert(spectre.is_empty() or sim.monsters.all(func(monster: Dictionary) -> bool: return int(monster.id) != int(spectre.id)), "A Cullis-sacrificed Spectre must not survive in the hostile actor collection")
	_test_simulation_and_goal()

func _test_lootbox_loop() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(90173, &"loot_test", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox")
	sim.start_region(blueprint, sandbox)
	_assert(sim.magic_circles.size() == 6, "A fresh deterministic region must contain six sealed magic-circle sites")
	var site_signature: Array[String] = []
	for circle in sim.magic_circles:
		site_signature.append("%d:%d:%s" % [int(circle.x), int(circle.y), String(circle.payload)])
	sim.start_region(blueprint, sandbox)
	var repeated_signature: Array[String] = []
	for circle in sim.magic_circles:
		repeated_signature.append("%d:%d:%s" % [int(circle.x), int(circle.y), String(circle.payload)])
	_assert(site_signature == repeated_signature, "Magic-circle positions and payloads must regenerate identically from the same region blueprint")
	# Keep actors away from the excavation sites so the Hand selection test is
	# unambiguous and exercises the physical item rather than a nearby villager.
	for villager in sim.villagers:
		villager.x = float(blueprint.starting_cell.x) + 0.5
		villager.y = float(blueprint.starting_cell.y) + 0.5
	for animal in sim.animals:
		animal.x = float(blueprint.starting_cell.x) + 0.5
		animal.y = float(blueprint.starting_cell.y) + 0.5
	var key_circle: Dictionary = sim.magic_circles.filter(func(circle: Dictionary) -> bool: return String(circle.payload) == "suspicious_key")[0]
	var box_circle: Dictionary = sim.magic_circles.filter(func(circle: Dictionary) -> bool: return String(circle.payload) == "lootbox")[0]
	var discovery_before := int(ProgressionService.counters.get("loot.magic_circle_discoveries", 0))
	var key_cell := Vector2i(int(key_circle.x), int(key_circle.y))
	var box_cell := Vector2i(int(box_circle.x), int(box_circle.y))
	sim._finish_terrain_work("%d:%d" % [key_cell.x, key_cell.y], key_cell, &"clear")
	sim._finish_terrain_work("%d:%d" % [box_cell.x, box_cell.y], box_cell, &"clear")
	_assert(sim.magic_circles.size() == 4 and int(ProgressionService.counters.get("loot.magic_circle_discoveries", 0)) == discovery_before + 2, "Clearing circles must reveal physical key/box payloads and advance Buried Treasure progress")
	var key_item: Dictionary = sim.loose_items.filter(func(item: Dictionary) -> bool: return String(item.resource_id) == "suspicious_key")[0]
	var box: Dictionary = sim.loose_items.filter(func(item: Dictionary) -> bool: return String(item.resource_id) == "lootbox")[0]
	var box_id := int(box.id)
	var move_before := int(ProgressionService.counters.get("loot.box_moves", 0))
	var old_box_cell := Vector2i(int(box.x), int(box.y))
	_assert(sim._pick_up_with_hand(old_box_cell) and sim.held_entity.is_empty(), "Poking a loot box with the Hand must relocate it instead of treating it like carried cargo")
	box = sim._find_loose_item(box_id)
	_assert(Vector2i(int(box.x), int(box.y)) != old_box_cell and int(ProgressionService.counters.get("loot.box_moves", 0)) == move_before + 1, "A Hand-poked loot box must move visibly and advance Stop Poking Me progress")
	var opened_before := int(ProgressionService.counters.get("loot.boxes_opened", 0))
	_assert(sim._pick_up_with_hand(Vector2i(int(key_item.x), int(key_item.y))) and String(sim.held_entity.get("payload", {}).get("resource_id", "")) == "suspicious_key", "The Hand must lift a revealed physical suspicious key")
	_assert(sim._drop_from_hand(Vector2i(int(box.x), int(box.y))) and sim.held_entity.is_empty(), "Dropping a held key on a loot box must consume it and open the box")
	_assert(sim._find_loose_item(box_id).is_empty() and int(ProgressionService.counters.get("loot.boxes_opened", 0)) == opened_before + 1, "A Hand-opened loot box must disappear exactly once and grant deterministic rewards")
	var state_hash: String = sim.compute_state_hash()
	var saved_state: Dictionary = sim.export_state()
	_assert(sim.import_state(saved_state) and sim.compute_state_hash() == state_hash and sim.magic_circles.size() == 4, "Discovered and undiscovered magic circles, loot, and reward RNG must survive deterministic save/load")
	# Organizer automation is proven through its generated task and normal work
	# branch, including consumption of a stored key.
	var camp: Dictionary = _place_sandbox_building(&"camp")
	var ancillary: Dictionary = _place_sandbox_building(&"ancillary")
	_assert(not camp.is_empty() and not ancillary.is_empty() and int(sim.jobs.get("organizers", {}).get("max", 0)) > 0, "Organizer loot automation requires a completed Camp and Ancillary workplace")
	var organizer_box_cell: Vector2i = sim.pathfinder.nearest_walkable(Vector2i(int(camp.x), int(camp.y)) + Vector2i(8, 3))
	var organizer_box_id: int = sim.drop_resource(&"lootbox", 1, organizer_box_cell)
	var organizer_box: Dictionary = sim._find_loose_item(organizer_box_id)
	organizer_box.loot_table = "standard_lootbox"
	sim.set_physical_resource(&"suspicious_key", 1, sim.blueprint.starting_cell)
	sim._refresh_task_board()
	var organizer_tasks: Array = sim.task_board.tasks.values().filter(func(task: Dictionary) -> bool: return String(task.get("kind", "")) == "open_lootbox" and int(task.get("target_id", 0)) == organizer_box_id)
	_assert(not organizer_tasks.is_empty(), "Organizers must receive an automatic open-lootbox task for keyed boxes inside settlement range")
	if not organizer_tasks.is_empty():
		var organizer: Dictionary = sim.villagers[0]
		organizer.task_progress = 0
		for _step in 16:
			sim._work_task(organizer, organizer_tasks[0])
	_assert(sim._find_loose_item(organizer_box_id).is_empty() and int(sim.resources.get("suspicious_key", 0)) == 0, "Organizer work must consume one stored key and open its reserved loot box")
	# Doggos independently carry a settlement key to a nearby box.
	var doggo: Dictionary = sim.animals.filter(func(animal: Dictionary) -> bool: return String(animal.definition_id) == "doggo")[0]
	var doggo_box_cell := Vector2i(floori(float(doggo.x)), floori(float(doggo.y)))
	var doggo_box_id: int = sim.drop_resource(&"lootbox", 1, doggo_box_cell)
	var doggo_box: Dictionary = sim._find_loose_item(doggo_box_id)
	doggo_box.loot_table = "standard_lootbox"
	sim.set_physical_resource(&"suspicious_key", 1, sim.blueprint.starting_cell)
	var doggo_before := int(ProgressionService.counters.get("loot.boxes_opened_by_doggo", 0))
	_assert(sim._doggo_try_loot(doggo), "A Doggo with access to a key must autonomously interact with a nearby loot box")
	_assert(sim._find_loose_item(doggo_box_id).is_empty() and int(ProgressionService.counters.get("loot.boxes_opened_by_doggo", 0)) == doggo_before + 1 and ProgressionService.completed.has("attaboy"), "Doggo opening must consume the key and complete the official Attaboy achievement")
	# Force the catalog's documented trash branch to prove its official goal hook,
	# then restore the immutable production definition before leaving the test.
	var loot_table: Dictionary = registry.get_by_id(&"loot_tables", &"standard_lootbox")
	var original_outcomes: Array = loot_table.outcomes.duplicate(true)
	loot_table.outcomes = [{"resource_id": "trashy_trash", "amount": 2, "weight": 1, "pure_trash": true}]
	var trash_box_id: int = sim.drop_resource(&"lootbox", 1, doggo_box_cell + Vector2i(2, 0))
	var trash_box: Dictionary = sim._find_loose_item(trash_box_id)
	trash_box.loot_table = "standard_lootbox"
	sim.set_physical_resource(&"suspicious_key", 1, sim.blueprint.starting_cell)
	var trash_before := int(ProgressionService.counters.get("loot.trash_outcomes", 0))
	_assert(sim._open_lootbox(trash_box, &"organizer"), "The weighted loot table's trash outcome must remain openable")
	loot_table.outcomes = original_outcomes
	_assert(int(ProgressionService.counters.get("loot.trash_outcomes", 0)) == trash_before + 1 and ProgressionService.completed.has("i_want_my_key_back"), "Receiving trash from a box must complete the official I Want My Key Back achievement")
	_test_simulation_and_goal()

func _test_golems_and_tower_combat() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(7722, &"applemeadow", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(blueprint, sandbox)
	sim.set_physical_resource(&"energy", 1000)
	var combobulator: Dictionary = _place_sandbox_building(&"crystal_golem_combobulator")
	_assert(not combobulator.is_empty(), "Crystal Golem Combobulator must find a valid generated footprint")
	for _index in 260:
		sim.advance_tick()
	_assert(sim.golems.size() == 1 and String(sim.golems[0].definition_id) == "crystal_golem", "Powered Combobulators must deterministically charge and deploy their typed golem")
	_assert(int(combobulator.get("golem_count", 0)) == 1 and String(combobulator.get("operation_state", "")) == "at_capacity", "Combobulators must expose mobile-readable capacity and operation state")
	var crystal_golem: Dictionary = sim.golems[0]
	var health_before_degradation := int(crystal_golem.health)
	sim.set_physical_resource(&"energy", 0)
	for _index in 25:
		sim.advance_tick()
	_assert(int(crystal_golem.health) < health_before_degradation and String(crystal_golem.state) == "degrading", "Manufactured golems must degrade when their energy maintenance fails")
	var recombobulator: Dictionary = _place_sandbox_building(&"recombobulator_tower")
	_assert(not recombobulator.is_empty(), "Recombobulator Tower must find a valid generated footprint")
	crystal_golem.x = float(recombobulator.x) + float(recombobulator.width) * 0.5
	crystal_golem.y = float(recombobulator.y) + float(recombobulator.height) * 0.5 + 2.0
	sim.set_physical_resource(&"energy", 50)
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
	sim.set_physical_resource(&"ballista_bolts", 1, sim.blueprint.starting_cell)
	sim._update_towers()
	_assert(int(target.health) < 1000 and int(sim.resources.ballista_bolts) == 0 and int(ballista.get("ammo_shots", 0)) == 19, "Ballista Towers must load stacked bolts, consume one shot, and deal their typed damage")
	ballista.combat_cooldown = 0
	ballista.ammo_shots = 0
	sim.set_physical_resource(&"ballista_bolts", 0, sim.blueprint.starting_cell)
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

func _test_ranger_lodge_and_outpost() -> void:
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(7274, &"applemeadow", &"forest")
	var sandbox: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(blueprint, sandbox)
	var outpost: Dictionary = _place_sandbox_building(&"outpost")
	_assert(not outpost.is_empty(), "Outpost must place in the sandbox reference scenario")
	outpost.tier = 3
	sim._recalculate_settlement_support()
	_assert(int(sim.jobs.rangers.max) == 0, "Current Rangers must not staff Outposts")
	_assert(sim.get_building_settlement_range({"definition_id":"outpost", "tier":1, "completed":true, "destroyed":false}) == 18 and sim.get_building_settlement_range(outpost) == 24, "Outpost upgrades must expand connected settlement influence")
	var lodge: Dictionary = _place_sandbox_building(&"ranger_lodge")
	_assert(not lodge.is_empty(), "Ranger Lodge must place in the sandbox reference scenario")
	lodge.tier = 1
	sim._recalculate_settlement_support()
	_assert(int(sim.jobs.rangers.max) == 6, "Tier-one Ranger Lodge must expose six Ranger slots")
	var housed_rangers: int = sim.villagers.filter(func(villager: Dictionary) -> bool: return String(villager.job) == "rangers" and int(villager.home_id) == int(lodge.id)).size()
	_assert(housed_rangers == 6, "Assigned Rangers must treat their staffed lodge as their home")
	var outpost_center := Vector2(float(outpost.x) + float(outpost.width) * 0.5, float(outpost.y) + float(outpost.height) * 0.5)
	var target: Dictionary = sim._spawn_monster_actor(&"headless", outpost_center + Vector2(2, 0))
	var target_health := int(target.health)
	sim.set_physical_resource(&"ballista_bolts", 1, sim.blueprint.starting_cell)
	sim._update_towers()
	_assert(int(target.health) < target_health and int(sim.resources.ballista_bolts) == 0 and int(outpost.get("ammo_shots", 0)) == 19, "A final-tier Outpost must fire its small bow emplacement using stacked Bowyer bolts")
	outpost.destroyed = true
	lodge.tier = 3
	lodge.combat_cooldown = 0
	sim._recalculate_settlement_support()
	_assert(int(sim.jobs.rangers.max) == 16 and sim.get_building_settlement_range(lodge) == 24, "Established Ranger Lodge must expose sixteen slots and its documented fixed range")
	target.x = float(lodge.x) + float(lodge.width) * 0.5 + 2.0
	target.y = float(lodge.y) + float(lodge.height) * 0.5
	target_health = int(target.health)
	sim.set_physical_resource(&"ballista_bolts", 1, sim.blueprint.starting_cell)
	sim._update_towers()
	_assert(int(target.health) < target_health and int(lodge.get("ammo_shots", 0)) == 19, "Established Ranger Lodge must activate its own small bow emplacement")
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
	sim.set_physical_resource(&"bow", 1, sim.blueprint.starting_cell)
	sim.set_physical_resource(&"quiver", 2, sim.blueprint.starting_cell)
	sim.set_physical_resource(&"iron_body_armor", 1, sim.blueprint.starting_cell)
	sim.set_physical_resource(&"iron_helmet", 1, sim.blueprint.starting_cell)
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
	sim.set_physical_resource(&"hammer", 1, sim.blueprint.starting_cell)
	sim.tick = 100
	sim._update_equipment()
	_assert(String(maintainer.get("equipment", {}).get("tool", {}).get("id", "")) == "hammer", "Maintainers must claim an available Hammer as a durable work tool")
	maintainer.x = float(housing.x) + float(housing.width) * 0.5
	maintainer.y = float(housing.y) + float(housing.height) * 0.5
	housing.health = int(housing.max_health) - 120
	housing.repair_batch_remaining = 0
	sim.set_physical_resource(&"wood", 2, sim.blueprint.starting_cell)
	sim.set_physical_resource(&"rock", 0, sim.blueprint.starting_cell)
	var repair_materials_before := int(ProgressionService.counters.get("maintenance.repair_materials_consumed", 0))
	sim.submit(GameCommand.set_building_work(sim.tick, int(housing.id), &"prioritize_repair", true))
	for _index in 25: sim.advance_tick()
	_assert(int(housing.health) == int(housing.max_health), "Maintainers must finish a prioritized damaged building without leaving a partial-health deadlock")
	_assert(int(ProgressionService.counters.get("maintenance.repair_materials_consumed", 0)) == repair_materials_before + 1 and String(housing.service_state) == "repaired", "One repair material batch must be consumed exactly once and expose the completed service state")
	_assert(not bool(housing.repair_designated) and int(maintainer.equipment.tool.durability) < int(maintainer.equipment.tool.max_durability), "Repair completion must clear priority and consume Hammer durability")
	housing.health = int(housing.max_health) - 40
	housing.repair_batch_remaining = 0
	sim.set_physical_resource(&"wood", 0, sim.blueprint.starting_cell)
	sim.set_physical_resource(&"rock", 0, sim.blueprint.starting_cell)
	var stalled_health := int(housing.health)
	var stalled_material_count := int(ProgressionService.counters.get("maintenance.repair_materials_consumed", 0))
	for _index in 15: sim.advance_tick()
	_assert(int(housing.health) == stalled_health and String(housing.service_state) == "missing_repair_material" and int(ProgressionService.counters.get("maintenance.repair_materials_consumed", 0)) == stalled_material_count, "Repair work must wait visibly without consuming or creating material when every valid input is missing")
	sim.set_physical_resource(&"wood", 1, sim.blueprint.starting_cell)
	for _index in 15: sim.advance_tick()
	_assert(int(housing.health) == int(housing.max_health) and int(ProgressionService.counters.get("maintenance.repair_materials_consumed", 0)) == stalled_material_count + 1, "A stalled Maintainer must resume the same reservation and consume one valid material batch when supplies arrive")
	var patient: Dictionary = sim.villagers[12]
	patient.x = float(medic.x)
	patient.y = float(medic.y)
	patient.health = 650
	patient.status_effects = {"infection": 300}
	sim.set_physical_resource(&"medkit", 1, sim.blueprint.starting_cell)
	for _index in 30: sim.advance_tick()
	_assert(int(patient.health) >= 990 and not patient.status_effects.has("infection") and int(sim.resources.medkit) == 0, "Medics must prioritize a severe infected patient, consume one Medkit, heal, and cure infection")
	var waiting_patient: Dictionary = sim.villagers[13]
	waiting_patient.x = float(medic.x)
	waiting_patient.y = float(medic.y)
	waiting_patient.health = 800
	sim.set_physical_resource(&"bandage", 0, sim.blueprint.starting_cell)
	sim.set_physical_resource(&"medkit", 0, sim.blueprint.starting_cell)
	sim.set_physical_resource(&"healing_potion", 0, sim.blueprint.starting_cell)
	for _index in 25: sim.advance_tick()
	_assert(int(waiting_patient.health) == 800 and String(waiting_patient.get("medical_state", "")) == "awaiting_supplies", "Medics must expose a stable awaiting-supplies state without free healing")
	sim.set_physical_resource(&"bandage", 1, sim.blueprint.starting_cell)
	for _index in 25: sim.advance_tick()
	_assert(int(waiting_patient.health) == 1000 and int(sim.resources.bandage) == 0, "Waiting medical work must resume and consume the newly delivered Bandage")
	var housing_id := int(housing.id)
	sim.set_physical_resource(&"wood", 0, sim.blueprint.starting_cell)
	sim.set_physical_resource(&"rock", 0, sim.blueprint.starting_cell)
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
	sim.set_physical_resource(&"empty_eerie_vessel", 1, sim.blueprint.starting_cell)
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
	var pond_cell := blueprint.starting_cell + Vector2i(0, 28)
	_assert(blueprint.get_tile(pond_cell) == RegionGenerator.Tile.DEEP_WATER, "Certified weather scenario must retain its deterministic pond cell")
	sim.next_weather_tick = 999999
	sim.tick = 15 * sim.TICKS_PER_DAY
	sim._update_weather_and_events()
	_assert(sim.water_frozen and sim.pathfinder.is_walkable(pond_cell), "Winter must freeze deep water into traversable ice")
	_assert(sim.get_snapshot().water_frozen, "Snapshots must expose the authoritative frozen-water state")
	var frozen_state: Dictionary = sim.export_state()
	_assert(sim.import_state(frozen_state) and sim.water_frozen and sim.pathfinder.is_walkable(pond_cell), "Save/load must restore frozen-water navigation without waiting for another weather tick")
	sim.villagers[0].x = float(pond_cell.x) + 0.5
	sim.villagers[0].y = float(pond_cell.y) + 0.5
	sim.tick = 0
	sim._update_weather_and_events()
	var thawed_cell := Vector2i(floori(float(sim.villagers[0].x)), floori(float(sim.villagers[0].y)))
	_assert(not sim.water_frozen and not sim.pathfinder.is_walkable(pond_cell), "Spring thaw must make deep water impassable again")
	_assert(blueprint.get_tile(thawed_cell) != RegionGenerator.Tile.DEEP_WATER and String(sim.villagers[0].state) == "escaped_thaw", "Actors standing on ice must be returned safely to shore when it thaws")
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

func _test_terrain_aftermath_states() -> void:
	var generator := RegionGenerator.new()
	var aftermath_blueprint := generator.generate(48721, &"aftermath_test", &"forest")
	var effect_cell := aftermath_blueprint.starting_cell + Vector2i(9, 4)
	aftermath_blueprint.set_tile(effect_cell, RegionGenerator.Tile.GRASS)
	var sandbox_rules: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(aftermath_blueprint, sandbox_rules)
	_assert(sim._set_terrain_effect(effect_cell, &"mud", 640, 500), "Mud must be placeable on buildable ground")
	_assert(sim._terrain_effect_speed_multiplier(effect_cell) < 1.0, "Mud must authoritatively slow ground movement")
	sim.submit(GameCommand.cast_spell(sim.tick, &"flame", effect_cell + Vector2i(3, 0)))
	sim.advance_tick()
	_assert(sim.terrain_effects.values().any(func(effect: Dictionary) -> bool: return String(effect.get("kind", "")) == "fire"), "Flame must create persistent burning terrain rather than presentation-only particles")
	var fire_key := ""
	for effect_key in sim.terrain_effects:
		if String(sim.terrain_effects[effect_key].get("kind", "")) == "fire":
			fire_key = String(effect_key)
			break
	_assert(not fire_key.is_empty(), "A burning terrain cell must have a stable saved key")
	if not fire_key.is_empty():
		sim.terrain_effects[fire_key].remaining_ticks = 10
		sim.weather = &"rain"
		sim.tick = 10
		sim._update_terrain_effects()
		_assert(String(sim.terrain_effects[fire_key].kind) == "ash", "Rain must extinguish terrain fire into persistent ash")
	var flood_cell := effect_cell + Vector2i(0, 3)
	aftermath_blueprint.set_tile(flood_cell, RegionGenerator.Tile.GRASS)
	_assert(sim._set_terrain_effect(flood_cell, &"flood", 760, 10), "Floodwater must occupy non-water low ground")
	sim.weather = &"clear"
	sim.tick = 20
	sim._update_terrain_effects()
	_assert(String(sim.terrain_effects[sim._cell_key(flood_cell)].kind) == "mud", "Receding floodwater must leave mud")
	var snapshot: SimulationSnapshot = sim.get_snapshot()
	_assert(snapshot.terrain_effects.size() == sim.terrain_effects.size(), "Snapshots must expose every authoritative terrain aftermath cell")
	var saved: Dictionary = sim.export_state()
	var expected_effects: Dictionary = sim.terrain_effects.duplicate(true)
	_assert(sim.import_state(saved) and sim.terrain_effects == expected_effects, "Mud, flood, fire, and ash states must survive exact save/load")
	_test_simulation_and_goal()

func _test_terrain_work_designations() -> void:
	var generator := RegionGenerator.new()
	var terrain_blueprint := generator.generate(52831, &"terrain_work_test", &"forest")
	var sandbox_rules: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sim.start_region(terrain_blueprint, sandbox_rules)
	var maintenance := _place_sandbox_building(&"maintenance_building")
	_assert(not maintenance.is_empty(), "Terrain work requires an operational Maintenance Building")
	var maintainer: Dictionary = {}
	for villager in sim.villagers:
		if String(villager.job) == "maintainers":
			maintainer = villager
			break
	_assert(not maintainer.is_empty(), "Maintenance Buildings must expose a Maintainer for terrain work")
	if maintainer.is_empty():
		_test_simulation_and_goal()
		return
	maintainer.equipment.terrain_tool = sim._equipment_item(&"shovel")
	maintainer.equipment.terrain_tool.durability = 500
	maintainer.equipment.terrain_tool.max_durability = 500
	var clear_cell := terrain_blueprint.starting_cell + Vector2i(18, 13)
	terrain_blueprint.set_tile(clear_cell, RegionGenerator.Tile.FOREST_FLOOR)
	var source_node := {"id": "wood", "x": clear_cell.x, "y": clear_cell.y, "amount": 13, "initial_amount": 13, "variant": 2, "entity_id": 990001}
	sim.resource_nodes.append(source_node.duplicate(true))
	terrain_blueprint.resource_nodes.append(source_node.duplicate(true))
	for worker in sim.villagers:
		if String(worker.job) == "maintainers":
			worker.x = float(clear_cell.x) + 0.5
			worker.y = float(clear_cell.y) + 0.5
	var wood_before := int(sim.resources.get("wood", 0))
	sim.submit(GameCommand.designate_terrain_work(sim.tick, &"clear", clear_cell))
	for _index in 60:
		sim.advance_tick()
		if not sim.terrain_work.has(sim._cell_key(clear_cell)):
			break
	_assert(sim._find_resource_node_at_cell(clear_cell).is_empty() and terrain_blueprint.get_tile(clear_cell) == RegionGenerator.Tile.GRASS, "Clear work must remove the resource and restore biome ground")
	_assert(int(sim.resources.get("wood", 0)) >= wood_before + 13 and int(ProgressionService.counters.get("maintenance.terrain.clear", 0)) >= 1, "Clear work must conserve recoverable resources and record progression")
	var dig_cell := clear_cell + Vector2i(2, 0)
	terrain_blueprint.set_tile(dig_cell, RegionGenerator.Tile.GRASS)
	for worker in sim.villagers:
		if String(worker.job) == "maintainers":
			worker.x = float(dig_cell.x) + 0.5
			worker.y = float(dig_cell.y) + 0.5
	sim.submit(GameCommand.designate_terrain_work(sim.tick, &"dig", dig_cell))
	sim.advance_tick()
	var digging_snapshot: SimulationSnapshot = sim.get_snapshot()
	_assert(not digging_snapshot.terrain_work.is_empty(), "Snapshots must expose designated terrain work and progress")
	var pending_cell := dig_cell + Vector2i(2, 0)
	terrain_blueprint.set_tile(pending_cell, RegionGenerator.Tile.GRASS)
	sim.submit(GameCommand.designate_terrain_work(sim.tick, &"dig", pending_cell))
	sim.advance_tick()
	var pending_state: Dictionary = sim.export_state()
	var pending_work: Dictionary = sim.terrain_work.duplicate(true)
	_assert(sim.import_state(pending_state) and sim.terrain_work == pending_work, "Pending terrain designations and progress must survive exact save/load")
	sim.submit(GameCommand.designate_terrain_work(sim.tick, &"dig", pending_cell, false))
	sim.advance_tick()
	_assert(not sim.terrain_work.has(sim._cell_key(pending_cell)), "Canceling a saved competing terrain task must release its reservation")
	maintainer = sim.villagers.filter(func(villager: Dictionary) -> bool: return String(villager.job) == "maintainers")[0]
	for worker in sim.villagers:
		if String(worker.job) == "maintainers":
			worker.x = float(dig_cell.x) + 0.5
			worker.y = float(dig_cell.y) + 0.5
	for _index in 90:
		sim.advance_tick()
		if String(sim.terrain_effects.get(sim._cell_key(dig_cell), {}).get("kind", "")) == "hole":
			break
	_assert(String(sim.terrain_effects.get(sim._cell_key(dig_cell), {}).get("kind", "")) == "hole", "Dig work must create a persistent authoritative hole")
	var hole_key: String = sim._cell_key(dig_cell)
	var hole_state: Dictionary = sim.export_state()
	for _index in 100: sim.advance_tick()
	_assert(String(sim.terrain_effects.get(hole_key, {}).get("kind", "")) == "hole", "Dug holes must not expire with weather aftermath timers")
	_assert(sim.import_state(hole_state) and String(sim.terrain_effects.get(hole_key, {}).get("kind", "")) == "hole", "Dug holes must survive save/load")
	maintainer = sim.villagers.filter(func(villager: Dictionary) -> bool: return String(villager.job) == "maintainers")[0]
	for worker in sim.villagers:
		if String(worker.job) == "maintainers":
			worker.x = float(dig_cell.x) + 0.5
			worker.y = float(dig_cell.y) + 0.5
	sim.submit(GameCommand.designate_terrain_work(sim.tick, &"fill", dig_cell))
	for _index in 80:
		sim.advance_tick()
		if not sim.terrain_effects.has(hole_key): break
	_assert(not sim.terrain_effects.has(hole_key), "Fill work must remove a dug hole")
	var restore_cell := dig_cell + Vector2i(0, 2)
	terrain_blueprint.set_tile(restore_cell, RegionGenerator.Tile.GRASS)
	sim._set_terrain_effect(restore_cell, &"ash", 700, 1200)
	for worker in sim.villagers:
		if String(worker.job) == "maintainers":
			worker.x = float(restore_cell.x) + 0.5
			worker.y = float(restore_cell.y) + 0.5
	sim.submit(GameCommand.designate_terrain_work(sim.tick, &"restore", restore_cell))
	for _index in 80:
		sim.advance_tick()
		if not sim.terrain_effects.has(sim._cell_key(restore_cell)): break
	_assert(not sim.terrain_effects.has(sim._cell_key(restore_cell)), "Restore work must clear ash, mud, or flood aftermath")
	var cancel_cell := restore_cell + Vector2i(2, 0)
	terrain_blueprint.set_tile(cancel_cell, RegionGenerator.Tile.GRASS)
	sim.submit(GameCommand.designate_terrain_work(sim.tick, &"dig", cancel_cell))
	sim.advance_tick()
	sim.submit(GameCommand.designate_terrain_work(sim.tick, &"dig", cancel_cell, false))
	sim.advance_tick()
	_assert(not sim.terrain_work.has(sim._cell_key(cancel_cell)) and not sim.terrain_effects.has(sim._cell_key(cancel_cell)), "Canceling terrain work must preserve the terrain and release the task")
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
	var temporary_clucker_ids: Array[int] = []
	while sim._animal_home_occupancy(int(coop.id)) < 7:
		var extra_clucker: Dictionary = male_clucker.duplicate(true)
		extra_clucker.id = sim._next_id()
		extra_clucker.name = "Capacity Test Clucker"
		extra_clucker.home_id = int(coop.id)
		extra_clucker.domesticated = true
		extra_clucker.health = 1000
		extra_clucker.age_stage = "adult"
		extra_clucker.age_days = 50 + temporary_clucker_ids.size()
		extra_clucker.pregnant_ticks = 0
		extra_clucker.slaughter_designated = false
		extra_clucker.auto_slaughter_designated = false
		temporary_clucker_ids.append(int(extra_clucker.id))
		sim.animals.append(extra_clucker)
	sim._refresh_automatic_slaughter_designations()
	var automatic_slaughter_count := 0
	for animal in sim.animals:
		if int(animal.get("home_id", 0)) == int(coop.id) and bool(animal.get("auto_slaughter_designated", false)):
			automatic_slaughter_count += 1
	_assert(automatic_slaughter_count == 1, "A Coop above 75 percent occupancy must automatically designate only the excess adult for slaughter")
	for index in range(sim.animals.size() - 1, -1, -1):
		if int(sim.animals[index].get("id", 0)) in temporary_clucker_ids:
			sim.animals.remove_at(index)
	sim._refresh_automatic_slaughter_designations()
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
	var eggs_before_clucker_slaughter := int(sim.resources.eggs)
	var slaughtered_clucker: Dictionary = sim.animals.filter(func(animal: Dictionary) -> bool:
		return String(animal.get("definition_id", "")) == "clucker" and int(animal.get("health", 0)) > 0)[0]
	sim._slaughter_animal(slaughtered_clucker)
	_assert(int(sim.resources.eggs) == eggs_before_clucker_slaughter, "Clucker slaughter must yield meat and feathers, never eggs")
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
	_assert(is_equal_approx(sim.pathfinder.get_travel_weight(road_cell), 0.50) and is_equal_approx(sim.hostile_pathfinder.get_travel_weight(road_cell), 0.50) and is_equal_approx(sim._road_speed_multiplier(road_cell), 1.36), "Cut Stone roads must attract both factions' routes while increasing ground movement speed")
	_assert(not sim.pathfinder.is_walkable(wall_cell), "Completed curtain walls must become solid navigation obstacles")
	_assert(not sim.hostile_pathfinder.is_walkable(wall_cell), "Completed settlement walls must also block hostile route planning so monsters attack or route around them")
	_assert(sim.pathfinder.is_walkable(gate_cell) and sim.pathfinder.is_walkable(gate_cell + Vector2i.RIGHT), "Completed gates must remain traversable")
	_assert(ProgressionService.completed.has("all_roads_lead_to_home") and ProgressionService.completed.has("i_like_big_buttresses"), "Road and curtain-wall construction must feed their official achievement counters")
	wall.destroyed = true
	sim._refresh_navigation_buildings()
	_assert(sim.pathfinder.is_walkable(wall_cell) and sim.hostile_pathfinder.is_walkable(wall_cell), "Destroyed walls must release both faction navigation graphs")
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
	sim.set_physical_resource(&"wood", 20, sim.blueprint.starting_cell)
	sim.set_physical_resource(&"boards", 0, sim.blueprint.starting_cell)
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
	sim.set_physical_resource(&"boards", 0, sim.blueprint.starting_cell)
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
	sim.set_physical_resource(&"trashy_trash", 2, sim.blueprint.starting_cell)
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
	sim.set_physical_resource(&"gold_coins", 5000, sim.blueprint.starting_cell)
	sim.set_physical_resource(&"wood", 10, sim.blueprint.starting_cell)
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
	sim.set_physical_resource(&"rock", 0, sim.blueprint.starting_cell)
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
	sim.set_physical_resource(&"god_dust", 24, sim.blueprint.starting_cell)
	sim.submit(GameCommand.trade_resource(sim.tick, marketplace_id, &"sell", &"god_dust", 24))
	sim.advance_tick()
	_assert(ProgressionService.completed.has("the_dust_must_flow"), "Selling twenty-four God Dust must unlock its official trade achievement")
	sim.set_physical_resource(&"filled_eerie_vessel", 1, sim.blueprint.starting_cell)
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
	_assert(goals.size() == 113 and bound_goals.size() == 113, "The profile Goal Web must expose all 113 official goals with executable bindings (goals=%d, bound=%d)" % [goals.size(), bound_goals.size()])
	ProgressionService.record(&"resources.produced.gold_coins", 3072)
	ProgressionService.record(&"events.entered.full_moon")
	ProgressionService.record(&"god_structures.summoned.god_tower", 12)
	ProgressionService.record(&"spells.charmed.monsters", 24)
	_assert(ProgressionService.completed.has("rise_to_riches") and ProgressionService.completed.has("chill") and ProgressionService.completed.has("holy_defense") and ProgressionService.completed.has("charming_deity"), "Production, lunar, God-structure, and divine-combat counters must unlock their official bound goals")
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

func _test_official_achievement_mechanics() -> void:
	ProgressionService.reset_profile_progress()
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(91247, &"achievement_mechanics", &"forest")
	var rules: Dictionary = registry.get_by_id(&"modes", &"sandbox").duplicate(true)
	rules.unlimited_influence = true
	sim.start_region(blueprint, rules)
	var center: Vector2i = blueprint.starting_cell
	var grass_cell := Vector2i(-1, -1)
	var water_cell := Vector2i(-1, -1)
	for y in blueprint.height:
		for x in blueprint.width:
			var candidate := Vector2i(x, y)
			if grass_cell.x < 0 and blueprint.get_tile(candidate) == RegionGenerator.Tile.GRASS and candidate.distance_to(center) > 45.0:
				grass_cell = candidate
			if water_cell.x < 0 and blueprint.get_tile(candidate) == RegionGenerator.Tile.DEEP_WATER:
				water_cell = candidate
			if grass_cell.x >= 0 and water_cell.x >= 0:
				break
		if grass_cell.x >= 0 and water_cell.x >= 0:
			break
	_assert(grass_cell.x >= 0 and water_cell.x >= 0, "Achievement mechanics fixture must expose isolated grass and deep water")
	var grab_definition: Dictionary = registry.get_by_id(&"spells", &"grab")
	for _index in 16:
		sim._use_grab_hand({"cell_x": grass_cell.x, "cell_y": grass_cell.y}, grab_definition)
	_assert(ProgressionService.completed.has("touch_grass"), "Using the Hand on grass sixteen times must complete Touch Grass without inventing a pickup")

	var ranger: Dictionary = sim.villagers[0]
	ranger.job = "rangers"
	ranger.age_stage = "adult"
	for equip_index in 32:
		ranger.equipment = {}
		sim.add_physical_resource(&"bow", 1, PHYSICAL_INVENTORY.LocationState.GROUND, sim.blueprint.starting_cell)
		sim.add_physical_resource(&"quiver", 1, PHYSICAL_INVENTORY.LocationState.GROUND, sim.blueprint.starting_cell)
		sim.tick = (equip_index + 1) * 100
		sim._update_equipment()
	_assert(ProgressionService.completed.has("lord_of_the_arrows"), "Thirty-two real bow equips must complete Lord of The Arrows (counter=%d, job=%s, age=%s)" % [int(ProgressionService.counters.get("equipment.bows_equipped", 0)), String(ranger.get("job", "")), String(ranger.get("age_stage", ""))])

	# Reactions are a visible actor state and a persistent counter, not an inferred
	# count based only on the number of spells cast.
	for _index in 32:
		sim._make_villagers_react_to_divine_action(center, 80.0, &"illuminate")
	_assert(ProgressionService.completed.has("god_or_magician") and int(sim.villagers[0].get("divine_reaction_until_tick", 0)) > sim.tick, "Nearby living villagers must visibly react to divine actions and complete God or Magician")

	for index in 6:
		sim.villagers.append({
			"id": 91000 + index, "name": "Catjeet casualty %d" % index, "species": "catjeet", "job": "idle",
			"x": float(center.x + 12), "y": float(center.y), "health": 0, "ghost_created": false,
			"age_stage": "adult", "status_effects": {"infection": 120 if index < 5 else 0}, "state": "fallen",
		})
	sim._update_death_and_ghosts()
	_assert(ProgressionService.completed.has("28_seconds_later") and ProgressionService.completed.has("catjeetastrophic"), "Infected conversions and Catjeet deaths must feed their exact official counters")

	for index in 12:
		sim.animals.append({
			"id": 92000 + index, "definition_id": "doggo", "name": "Doggo casualty %d" % index,
			"x": float(center.x + index % 4), "y": float(center.y + 8 + index / 4), "target_x": float(center.x), "target_y": float(center.y),
			"health": 0, "max_health": 700, "hunger": 1000, "thirst": 1000, "energy": 1000,
			"age_days": 30, "age_stage": "adult", "sex": "female" if index % 2 == 0 else "male", "domesticated": true,
			"pregnant_ticks": 0, "home_id": 0, "capture_designated": false, "slaughter_designated": false, "slaughtered": false,
			"state": "fallen", "death_recorded": false, "ghost_created": false, "attack_cooldown": 0,
			"path": [], "path_index": 0, "path_goal_x": -1, "path_goal_y": -1, "stuck_ticks": 0,
		})
	sim._update_animals()
	_assert(ProgressionService.completed.has("animal_rights_violations"), "Twelve independently recorded Doggo deaths must complete Animal Rights Violations")

	sim.active_event = &"blood_moon"
	sim._cast_earthquake(center + Vector2i(24, 0), 4.0, registry.get_by_id(&"spells", &"earthquake"))
	_assert(ProgressionService.completed.has("ragnarok"), "An earthquake cast during a blood moon must complete Ragnarok")

	var dangerous_villager: Dictionary = sim.villagers[1].duplicate(true)
	dangerous_villager.id = 93001
	dangerous_villager.health = 1000
	sim.held_entity = {"kind": "villager", "payload": dangerous_villager, "origin_x": grass_cell.x, "origin_y": grass_cell.y}
	sim.corruption_cells[sim._cell_key(grass_cell)] = 1000
	_assert(sim._drop_from_hand(grass_cell), "The Hand must be able to drop a villager into an otherwise walkable corrupted cell")
	_assert(ProgressionService.completed.has("dude_wth_man"), "Dropping a villager into active corruption must complete Dude, WTH Man")

	var forced_villager: Dictionary = sim.villagers[2].duplicate(true)
	forced_villager.id = 93002
	forced_villager.health = 1000
	sim.held_entity = {"kind": "villager", "payload": forced_villager, "origin_x": grass_cell.x, "origin_y": grass_cell.y}
	sim.mode_rules.unlimited_influence = false
	sim.influence = 0
	sim.tick = 1000
	sim._update_held_hand()
	sim.mode_rules.unlimited_influence = true
	_assert(sim.held_entity.is_empty() and ProgressionService.completed.has("whoops_sorry"), "An exhausted Hand must release its villager and complete Whoops, Sorry")

	var storage := _place_sandbox_building(&"wood_storage")
	_assert(not storage.is_empty(), "Hand-delivery fixture must place a completed storage building")
	if not storage.is_empty():
		sim.set_physical_resource(&"wood", 0, sim.blueprint.starting_cell)
		sim.held_entity = {"kind": "resource", "payload": {"id": 93003, "resource_id": "wood", "amount": 64}, "origin_x": grass_cell.x, "origin_y": grass_cell.y}
		var storage_cell := Vector2i(int(storage.x), int(storage.y))
		_assert(sim._drop_from_hand(storage_cell) and int(sim.resources.wood) >= 64 and ProgressionService.completed.has("fine_ill_do_it_myself"), "Dropping physical resources into a compatible building must store them and complete Fine, I'll Do It Myself")

	var fire_elemental := {"id": 93004, "definition_id": "fire_elemental", "name": "Drowning Elemental", "health": 1000, "x": grass_cell.x, "y": grass_cell.y, "state": "held"}
	sim.held_entity = {"kind": "monster", "payload": fire_elemental, "origin_x": grass_cell.x, "origin_y": grass_cell.y}
	_assert(sim._drop_from_hand(water_cell) and ProgressionService.completed.has("take_that"), "Dropping a Fire Elemental into deep water must resolve as drowning and complete Take That")

	var flowers_before := int(ProgressionService.counters.get("world.magic_flowers_generated", 0))
	for y in range(12, blueprint.height - 12, 16):
		for x in range(12, blueprint.width - 12, 16):
			if int(ProgressionService.counters.get("world.magic_flowers_generated", 0)) - flowers_before >= 256:
				break
			sim._grow_magic_flowers(Vector2i(x, y), 4)
		if int(ProgressionService.counters.get("world.magic_flowers_generated", 0)) - flowers_before >= 256:
			break
	_assert(ProgressionService.completed.has("rosebud"), "Magic use must create persistent visible flower nodes and complete Rosebud at 256")

	for index in 128:
		sim.villagers.append({"id": 94000 + index, "name": "Body %d" % index, "job": "idle", "x": float(center.x), "y": float(center.y), "health": 0, "ghost_created": true, "state": "dead"})
	var dissolved: int = sim._dissolve_bodies(center, 5.0)
	ProgressionService.record(&"spells.dissolved.bodies", dissolved)
	_assert(dissolved >= 128 and ProgressionService.completed.has("popcorn"), "Dissolve must remove physical bodies and complete Popcorn after 128")

	# A castle/camp strike and friendly collateral are both consequences of the
	# actual Comet cast, while lightning only completes its goal on a lethal hit.
	var camp := _place_sandbox_building(&"camp")
	_assert(not camp.is_empty(), "Spell-collateral fixture must place a town center")
	if not camp.is_empty():
		var camp_center := Vector2i(int(camp.x) + int(camp.width) / 2, int(camp.y) + int(camp.height) / 2)
		sim.villagers.append({"id": 95001, "name": "Comet witness", "species": "villager", "job": "idle", "x": float(camp_center.x) + 0.5, "y": float(camp_center.y) + 0.5, "health": 1000, "state": "idle", "status_effects": {}})
		sim._cast_spell({"spell_id": "comet", "cell_x": camp_center.x, "cell_y": camp_center.y})
		_assert(ProgressionService.completed.has("midgar") and ProgressionService.completed.has("bad_aim"), "A Comet striking the town center and a villager must complete Midgar and Bad Aim from one real impact")
	var lightning_target := {"id": 95002, "name": "Lightning target", "species": "villager", "job": "idle", "x": float(grass_cell.x) + 0.5, "y": float(grass_cell.y) + 0.5, "health": 100, "state": "idle", "status_effects": {}}
	sim.villagers.append(lightning_target)
	sim._cast_spell({"spell_id": "lightning_bolt", "cell_x": grass_cell.x, "cell_y": grass_cell.y})
	_assert(ProgressionService.completed.has("grandmaster_sparkles"), "A lethal Lightning Bolt hit on a villager must complete Grandmaster Sparkles")

	for index in 16:
		var catjeet_nomad: Dictionary = sim.villagers[0].duplicate(true)
		catjeet_nomad.id = 96000 + index
		catjeet_nomad.name = "Catjeet Nomad %d" % index
		catjeet_nomad.species = "catjeet"
		catjeet_nomad.population_state = "nomad"
		catjeet_nomad.job = "idle"
		catjeet_nomad.health = 900
		catjeet_nomad.x = float(center.x)
		catjeet_nomad.y = float(center.y)
		catjeet_nomad.path = []
		sim.nomads.append(catjeet_nomad)
		sim._admit_nomad(catjeet_nomad, &"test")
	_assert(ProgressionService.completed.has("strays"), "Sixteen actual Catjeet nomads joining the resident workforce must complete Strays")
	var cullis := _place_sandbox_building(&"cullis_gate")
	_assert(not cullis.is_empty(), "Nephilim sacrifice fixture must place an operational Cullis Gate")
	if not cullis.is_empty():
		sim.held_entity = {"kind": "nomad", "payload": {"id": 97001, "name": "Nephilim", "species": "nephilim", "age_stage": "adult", "level": 1}, "origin_x": grass_cell.x, "origin_y": grass_cell.y}
		_assert(sim._drop_from_hand(Vector2i(int(cullis.x), int(cullis.y))) and ProgressionService.completed.has("a_worthy_sacrifice"), "A real Nephilim dropped into a Cullis Gate must complete A Worthy Sacrifice")
	var housing_template := _place_sandbox_building(&"housing")
	_assert(not housing_template.is_empty(), "Housing branch fixture must place a completed base house")
	if not housing_template.is_empty():
		for branch in ["quality", "occupancy"]:
			var branch_count := 12 if branch == "quality" else 6
			for index in branch_count:
				var branch_house: Dictionary = housing_template.duplicate(true)
				branch_house.id = 98000 + (0 if branch == "quality" else 100) + index
				branch_house.tier = 2
				branch_house.completed = true
				branch_house.upgrading = true
				branch_house.upgrade_target_tier = 3
				branch_house.upgrade_target_name = "High %s House" % branch.capitalize()
				branch_house.upgrade_target_health = int(branch_house.max_health) + 200
				branch_house.upgrade_target_branch = branch
				sim.buildings.append(branch_house)
				sim._complete_building(branch_house)
				if index < 6:
					branch_house.completed = true
					branch_house.upgrading = true
					branch_house.upgrade_target_tier = 7
					branch_house.upgrade_target_name = "Reinforced High %s House" % branch.capitalize()
					branch_house.upgrade_target_health = int(branch_house.max_health) + 800
					sim._complete_building(branch_house)
		_assert(ProgressionService.completed.has("gods_village") and ProgressionService.completed.has("sardines"), "Distinct High Quality and High Occupancy house branches must complete their official goals")
		_assert(ProgressionService.completed.has("first_world_problems") and ProgressionService.completed.has("acropolis"), "Both reinforced housing branches must remain distinct through their final tier and official goals")
		for index in 4:
			var ice_ballista: Dictionary = housing_template.duplicate(true)
			ice_ballista.id = 99000 + index
			ice_ballista.definition_id = "ice_ballista_tower"
			ice_ballista.name = "Ice Ballista"
			ice_ballista.category = "towers"
			ice_ballista.tier = 1
			ice_ballista.completed = true
			ice_ballista.upgrading = false
			ice_ballista.width = 6
			ice_ballista.height = 6
			ice_ballista.x = center.x + 30 + index * 7
			ice_ballista.y = center.y + 30
			sim.buildings.append(ice_ballista)
			sim._complete_building(ice_ballista)
		_assert(ProgressionService.completed.has("let_it_snow_arrows"), "Completing four real Ice Ballista structures must complete Let It Snow Arrows")

		var lightning_rod: Dictionary = housing_template.duplicate(true)
		lightning_rod.id = 99100
		lightning_rod.definition_id = "lightning_rod"
		lightning_rod.name = "Lightning Rod"
		lightning_rod.category = "magic"
		lightning_rod.tier = 1
		lightning_rod.completed = true
		lightning_rod.destroyed = false
		lightning_rod.width = 5
		lightning_rod.height = 5
		lightning_rod.x = grass_cell.x + 3
		lightning_rod.y = grass_cell.y
		lightning_rod.lightning_cooldown_until_tick = 0
		sim.buildings.append(lightning_rod)
		sim.tick += 1
		sim._cast_spell({"spell_id": "lightning_bolt", "cell_x": grass_cell.x, "cell_y": grass_cell.y})
		_assert(ProgressionService.completed.has("obvious_in_hindsight") and String(lightning_rod.get("operation_state", "")) == "conducting", "An operational Lightning Rod must physically redirect Lightning Bolt and complete Obvious in Hindsight")

	var animal_ghosts: Array[Dictionary] = []
	for ghost in sim.ghosts:
		if String(ghost.get("source_kind", "")) == "animal":
			animal_ghosts.append(ghost)
			if animal_ghosts.size() == 4:
				break
	_assert(animal_ghosts.size() == 4, "Four Doggo deaths must leave four persistent animal ghosts")
	sim.set_physical_resource(&"filled_eerie_vessel", maxi(4, int(sim.resources.get("filled_eerie_vessel", 0))), sim.blueprint.starting_cell)
	for ghost in animal_ghosts:
		ghost.bound = true
		sim._resurrect_nearest_ghost(Vector2i(roundi(float(ghost.x)), roundi(float(ghost.y))), 2.0)
	_assert(ProgressionService.completed.has("was_i_a_good_boy"), "Binding and resurrecting four Doggo ghosts must complete Was I a Good Boy")
	_assert(ProgressionService.get_goal_nodes().filter(func(goal: Dictionary) -> bool: return bool(goal.bound)).size() == 113, "All 113 official goals must now be backed by executable gameplay rules")

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
	_assert(campaigns.queue_courier(&"applemeadow", &"gateway", {"rock": 12}), "Courier logistics must accept any stored physical resource selected by the mobile drawer")
	_assert(int(source.population) == 15 and int(source.resources.wood) == 70 and int(source.resources.rock) == 28, "Queued regional transfers must reserve population and selected cargo immediately")
	campaigns.advance_ticks(campaigns.TRANSFER_TICKS)
	var migrated: Dictionary = campaigns.get_region_state(&"coastbridge")
	var supplied: Dictionary = campaigns.get_region_state(&"gateway")
	_assert(String(migrated.status) == "active" and int(migrated.population) == 5, "Completed migration must establish and populate its destination")
	_assert(int(supplied.resources.get("wood", 0)) == 30 and int(supplied.resources.get("rock", 0)) == 12, "Completed courier deliveries must add every selected cargo type to destination storage")
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
	sim.set_physical_resource(&"wood", 123, sim.blueprint.starting_cell)
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
	sim.set_physical_resource(&"wood", 999999, sim.blueprint.starting_cell)
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
	var schema_three: Dictionary = saves._migrate_payload(3, {"simulation": {
		"tick": 9,
		"resources": {"wood": 40, "rock": 30, "iron_sword": 2, "energy": 100},
		"buildings": [{"id": 42, "definition_id": "camp", "completed": true, "destroyed": false, "x": 12, "y": 14}],
		"blueprint": {"starting_cell": [8, 9]}
	}, "progression": {}, "campaigns": {}})
	_assert(schema_three.simulation.has("inventory") and schema_three.simulation.inventory.commodity_stacks.size() == 2, "Schema-3 saves must migrate into Schema-4 physical commodity stacks")
	_assert(schema_three.simulation.inventory.unique_items.size() == 2, "Schema-3 equipment counts must migrate into unique item instances")
	_assert(schema_three.simulation.inventory.commodity_stacks.all(func(stack: Dictionary) -> bool: return int(stack.container_id) == 42), "Schema-3 physical stacks must migrate into an existing completed Camp")
	_assert(not schema_three.simulation.inventory.commodity_stacks.any(func(stack: Dictionary) -> bool: return String(stack.resource_id) == "energy"), "Nonphysical energy must not migrate into commodity stacks")
	var schema_four: Dictionary = saves._migrate_payload(4, {"simulation": {
		"resources": {"wood": 999, "energy": 17, "faith": 23},
		"inventory": {"next_stack_id": 1, "next_item_id": 1, "commodity_stacks": [], "unique_items": []}
	}, "progression": {}, "campaigns": {}})
	_assert(not schema_four.simulation.has("resources") and schema_four.simulation.nonphysical_resources == {"energy": 17, "faith": 23}, "Schema-4 saves must discard the duplicate physical total dictionary while preserving virtual pools")

func _test_physical_inventory_and_reservations() -> void:
	var inv = PHYSICAL_INVENTORY.new()
	var res_svc = RESERVATION_SERVICE.new()
	inv.bind_reservation_service(res_svc)

	# Test 1: Stack creation and cached totals
	var stack1 = inv.create_commodity_stack(&"wood", 50, PHYSICAL_INVENTORY.LocationState.GROUND, Vector2i(10, 10))
	_assert(stack1 != null and stack1.id == 1, "Stack creation must return valid CommodityStack")
	_assert(inv.get_total(&"wood") == 50 and inv.get_loose(&"wood") == 50, "Cached totals must incrementally track loose wood")

	# Test 2: Moving stack to container
	inv.move_stack_to_container(stack1.id, 5, Vector2i(12, 12))
	_assert(inv.get_stored(&"wood") == 50 and inv.get_loose(&"wood") == 0, "Moving stack to container must update stored totals")

	# Test 3: Multi-worker partial reservations
	var token1 = res_svc.create_reservation(stack1.id, 20, 101, 5, &"construction", 10, inv)
	var token2 = res_svc.create_reservation(stack1.id, 15, 102, 5, &"recipe_input", 10, inv)
	_assert(token1 != null and token2 != null, "Multiple partial reservations on the same stack must succeed")
	_assert(res_svc.get_stack_reserved_quantity(stack1.id) == 35, "Total reserved quantity must be the sum of active tokens")
	_assert(res_svc.get_stack_available_quantity(stack1.id, inv) == 15, "Available quantity must reflect total minus active reservations")

	# Test 4: Stack splitting and token transfer
	var split_stack = inv.split_stack(stack1.id, 20)
	_assert(split_stack != null and split_stack.quantity == 20 and stack1.quantity == 30, "Stack split must preserve total physical quantity")
	_assert(res_svc.validate_conservation(inv), "Reservation transfer on stack split must satisfy conservation invariants")

	# Test 5: Cancellation hooks
	res_svc.cancel_all_for_requester(101)
	_assert(res_svc.get_stack_reserved_quantity(stack1.id) + res_svc.get_stack_reserved_quantity(split_stack.id) == 15, "Cancelling reservations for a requester must release reserved amounts")

	# Test 6: Unique Item Instances (tools with durability)
	var sword = inv.create_unique_item(&"iron_sword", &"weapon", 360, 360, &"hand", {"damage": 55}, PHYSICAL_INVENTORY.LocationState.CONTAINER, Vector2i(12, 12), 5)
	_assert(sword != null and sword.durability == 360 and sword.item_type == &"weapon", "Unique item instances must track durability and custom properties")
	_assert(inv.get_total(&"iron_sword") == 1 and inv.move_item_to_carrier(sword.id, 101) and inv.get_carried(&"iron_sword") == 1, "Unique item movement must update exact location indexes and cached totals")

	# Test 7: Incremental totals audit verification
	var audited := inv.recompute_totals_audit()
	_assert(int(audited.total.get(&"wood", 0)) == inv.get_total(&"wood"), "Incremental cached totals must match exact physical stack sums")
	_assert(inv.audit_totals_match(), "Commodity and unique-item caches must match a full physical inventory audit")

	# Test 8: Removing a stack automatically cancels its reservation tokens.
	var disposable = inv.create_commodity_stack(&"rock", 10, PHYSICAL_INVENTORY.LocationState.GROUND, Vector2i(3, 3))
	var disposable_token = res_svc.create_reservation(disposable.id, 5, 303, 0, &"hauling", 20, inv)
	_assert(disposable_token != null and inv.remove_commodity_stack(disposable.id) and res_svc.get_stack_reserved_quantity(disposable.id) == 0, "Destroying a stack must release every reservation tied to it")

	# Test 9: Merging may not teleport goods between physical locations.
	var ground_stack = inv.create_commodity_stack(&"wood", 5, PHYSICAL_INVENTORY.LocationState.GROUND, Vector2i(1, 1))
	var stored_stack = inv.create_commodity_stack(&"wood", 5, PHYSICAL_INVENTORY.LocationState.CONTAINER, Vector2i(2, 2), 5)
	_assert(inv.merge_stacks(ground_stack.id, stored_stack.id) == 0 and inv.audit_totals_match(), "Stack merging must reject different physical locations without corrupting caches")

	# Test 10: Oversized quantities must split into valid bounded stacks.
	_assert(inv.create_commodity_stack(&"crystal", 101, PHYSICAL_INVENTORY.LocationState.GROUND, Vector2i.ZERO, 0, 0, 100) == null, "A single commodity stack may never exceed its declared maximum")
	var split_created = inv.add_commodity(&"crystal", 250, PHYSICAL_INVENTORY.LocationState.GROUND, Vector2i(4, 4), 0, 0, 100)
	_assert(split_created.size() == 3 and split_created.all(func(stack) -> bool: return stack.quantity <= stack.max_stack) and inv.get_total(&"crystal") == 250, "Bulk additions must split into bounded physical stacks without loss")

	# Test 11: Aggregate consumption must be all-or-nothing and respect reservations.
	var atomic_inventory = PHYSICAL_INVENTORY.new()
	var atomic_reservations = RESERVATION_SERVICE.new()
	atomic_inventory.bind_reservation_service(atomic_reservations)
	var atomic_stack = atomic_inventory.create_commodity_stack(&"rock", 8, PHYSICAL_INVENTORY.LocationState.GROUND, Vector2i(1, 1))
	atomic_reservations.create_reservation(atomic_stack.id, 3, 404, 0, &"construction", 1, atomic_inventory)
	_assert(not atomic_inventory.consume_available(&"rock", 6) and atomic_inventory.get_total(&"rock") == 8, "An insufficient unreserved aggregate consume must not remove a partial cost")
	_assert(atomic_inventory.consume_available(&"rock", 5) and atomic_inventory.get_total(&"rock") == 3, "Aggregate consumption must consume exactly the unreserved requested amount")
	var migrated_tool = atomic_inventory.create_unique_item(&"iron_sword", &"weapon", 100, 100, &"hand", {}, PHYSICAL_INVENTORY.LocationState.CONTAINER, Vector2i.ZERO, 12)
	_assert(migrated_tool != null and atomic_inventory.consume_available(&"iron_sword", 1) and atomic_inventory.get_total(&"iron_sword") == 0, "Authoritative consumption must support unique item instances migrated from older saves")

func _test_extracted_subsystem_contracts() -> void:
	var inv = PHYSICAL_INVENTORY.new()
	var reservation_service = RESERVATION_SERVICE.new()
	inv.bind_reservation_service(reservation_service)

	# Production consumes the actual plural `outputs` recipe schema atomically.
	var production = PRODUCTION_SYSTEM_CLASS.new()
	var lumber_mill := {"id": 77, "definition_id": "lumber_mill", "x": 10, "y": 10}
	var boards_recipe: Dictionary = registry.get_by_id(&"recipes", &"boards")
	inv.create_commodity_stack(&"wood", 1, PHYSICAL_INVENTORY.LocationState.CONTAINER, Vector2i(10, 10), 77)
	_assert(production.consume_recipe_inputs(boards_recipe, 77, inv), "Production must consume complete physical input batches")
	production.produce_recipe_outputs(boards_recipe, lumber_mill, inv)
	_assert(inv.get_stored(&"wood") == 0 and inv.get_stored(&"boards") == 1, "Production must create outputs from the catalog's plural outputs dictionary")

	var failed_inventory = PHYSICAL_INVENTORY.new()
	failed_inventory.create_commodity_stack(&"wood", 5, PHYSICAL_INVENTORY.LocationState.CONTAINER, Vector2i.ZERO, 88)
	var impossible_recipe := {"inputs": {"wood": 5, "rock": 1}, "outputs": {"boards": 1}}
	_assert(not production.consume_recipe_inputs(impossible_recipe, 88, failed_inventory) and failed_inventory.get_stored(&"wood") == 5, "A missing recipe input must not partially consume an otherwise valid batch")

	# Task deduplication prevents per-tick service code from flooding the board.
	var tasks = TASK_SYSTEM_CLASS.new()
	tasks.bind_reservation_service(reservation_service)
	tasks.post_task(&"triage", Vector2i(2, 2), 9, 200, {"dedupe_key": "triage:9"})
	tasks.post_task(&"triage", Vector2i(3, 3), 9, 250, {"dedupe_key": "triage:9"})
	_assert(tasks.active_tasks.size() == 1 and int(tasks.active_tasks.values()[0].priority) == 250, "Repeated service updates must refresh rather than duplicate the same task")

	# Empty coops cannot create eggs, while living housed Cluckers can.
	var animals_system = ANIMAL_SYSTEM_CLASS.new()
	var coop := {"id": 90, "definition_id": "clucker_coop", "completed": true, "destroyed": false, "x": 4, "y": 4}
	animals_system.process_animals([], [coop], tasks, inv, 120)
	_assert(inv.get_total(&"eggs") == 0, "An empty Clucker Coop must never produce an egg")
	var cluckers: Array[Dictionary] = [
		{"id": 901, "species": "clucker", "captured": true, "pen_id": 90, "dead": false},
		{"id": 902, "species": "clucker", "captured": true, "pen_id": 90, "dead": false}
	]
	animals_system.process_animals(cluckers, [coop], tasks, inv, 240)
	_assert(inv.get_stored(&"eggs") == 1, "Living Cluckers housed in a Coop must produce physical eggs")

	# Doggos consume the actual key, never an arbitrary first carried item.
	var axe = inv.create_unique_item(&"axe", &"tool", 300, 300, &"hand", {}, PHYSICAL_INVENTORY.LocationState.CARRIER, Vector2i.ZERO, 0, 700)
	var key = inv.create_unique_item(&"suspicious_key", &"loot", 1, 1, &"hand", {}, PHYSICAL_INVENTORY.LocationState.CARRIER, Vector2i.ZERO, 0, 700)
	var lootbox = inv.create_commodity_stack(&"lootbox", 1, PHYSICAL_INVENTORY.LocationState.GROUND, Vector2i(5, 5))
	animals_system.process_doggos([{"id": 700, "x": 5, "y": 5, "dead": false}], inv, reservation_service, null, [], 1)
	_assert(inv.unique_items.has(axe.id) and not inv.unique_items.has(key.id) and not inv.commodity_stacks.has(lootbox.id), "Doggo loot handling must consume the suspicious key and preserve unrelated equipment")

	# Towers only spend ammo after acquiring a target; magical towers also require energy.
	var combat = COMBAT_SYSTEM_CLASS.new()
	var spell_energy = SPELL_SYSTEM_CLASS.new()
	var bow_tower := {"id": 100, "definition_id": "bow_tower", "completed": true, "destroyed": false, "x": 0, "y": 0}
	inv.create_commodity_stack(&"ballista_bolts", 2, PHYSICAL_INVENTORY.LocationState.CONTAINER, Vector2i.ZERO, 100)
	_assert(combat.update_towers([bow_tower], [], inv, 10, spell_energy).is_empty() and inv.get_container_quantity(100, &"ballista_bolts") == 2, "An idle tower must not consume ammunition")
	var monster := {"id": 500, "definition_id": "zombie", "x": 1, "y": 1, "health": 500, "dead": false}
	_assert(combat.update_towers([bow_tower], [monster], inv, 20, spell_energy).size() == 1 and inv.get_container_quantity(100, &"ballista_bolts") == 1, "A targeted physical tower must consume its configured ammunition once")

	var elemental_tower := {"id": 101, "definition_id": "elemental_bolt_tower", "completed": true, "destroyed": false, "x": 0, "y": 0}
	_assert(combat.update_towers([elemental_tower], [monster], inv, 16, spell_energy).is_empty(), "A magical tower without energy must not fire")
	spell_energy.energy = 10
	_assert(combat.update_towers([elemental_tower], [monster], inv, 32, spell_energy).size() == 1 and spell_energy.energy == 8, "A magical tower must consume its configured energy after acquiring a target")
	_assert(spell_energy.can_cast_spell(&"grab", 40), "Spell lookup must resolve the real spells content category")

func _test_physical_logistics_live_loop() -> void:
	var fresh = SIMULATION_HOST_CLASS.new()
	fresh.start_region(sim.blueprint, registry.get_by_id(&"modes", &"traditional"))
	_assert(fresh.inventory.commodity_stacks.values().all(func(stack) -> bool: return stack.location_state == PHYSICAL_INVENTORY.LocationState.GROUND and stack.container_id == 0), "Starting supplies must be loose at the starting cell until a real Camp exists")
	var fresh_state: Dictionary = fresh.export_state()
	_assert(not fresh_state.has("resources") and fresh_state.has("inventory") and fresh_state.has("nonphysical_resources"), "Saves must serialize physical inventory once and keep only nonphysical pools separately")
	fresh.free()

	sim.add_physical_resource(&"boards", 20, PHYSICAL_INVENTORY.LocationState.GROUND, sim.blueprint.starting_cell)
	_assert(sim.inventory.get_total(&"boards") >= 20 and int(sim.resources.get("boards", 0)) >= 20, "SimulationHost add_physical_resource must update physical inventory and derived resources")
	var before_failed_consume := int(sim.resources.get("boards", 0))
	_assert(not sim.consume_physical_resource(&"boards", before_failed_consume + 1) and int(sim.resources.get("boards", 0)) == before_failed_consume, "Live insufficient consumption must be atomic")
	var consumed: bool = sim.consume_physical_resource(&"boards", 5)
	_assert(consumed and int(sim.resources.get("boards", 0)) >= 15, "SimulationHost consume_physical_resource must consume physical stacks and update resources")
	_assert(sim.inventory.audit_totals_match(), "Live SimulationHost inventory must maintain exact physical consistency")

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
