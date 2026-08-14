extends Node

signal content_loaded(report: Dictionary)

const DATA_FILES := [
	"res://content/data/modes_biomes_spells.json",
	"res://content/data/resources.json",
	"res://content/data/jobs.json",
	"res://content/data/buildings.json",
	"res://content/data/regions.json",
	"res://content/data/achievements.json",
	"res://content/data/achievement_rules.json",
	"res://content/data/actors_events_meta.json",
	"res://content/data/audio_catalog.json",
	"res://content/data/trade_catalog.json",
	"res://content/data/loot_catalog.json",
	"res://content/data/meta_progression.json",
	"res://content/data/parity_ledger.json",
]

var content: Dictionary = {}
var indexes: Dictionary = {}
var validation_report: Dictionary = {}

func _ready() -> void:
	load_and_validate()

func load_and_validate() -> Dictionary:
	content.clear()
	indexes.clear()
	var parse_errors: Array[String] = []
	for path in DATA_FILES:
		if not FileAccess.file_exists(path):
			parse_errors.append("Missing content file: %s" % path)
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		if error != OK:
			parse_errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
			continue
		var root = json.data
		if root is not Dictionary:
			parse_errors.append("Root must be an object: %s" % path)
			continue
		for category in root:
			if root[category] is Array:
				if not content.has(category):
					content[category] = []
				content[category].append_array(root[category])
	_rebuild_indexes()
	validation_report = _validate(parse_errors)
	content_loaded.emit(validation_report)
	if validation_report.valid:
		print("ContentRegistry: loaded %d categories, %d entries" % [content.size(), validation_report.total_entries])
	else:
		push_error("Content validation failed: %s" % validation_report.errors)
	return validation_report

func _rebuild_indexes() -> void:
	for category in content:
		var category_index := {}
		for entry in content[category]:
			if entry is Dictionary and entry.has("id"):
				category_index[StringName(entry.id)] = entry
		indexes[category] = category_index

func _validate(parse_errors: Array[String]) -> Dictionary:
	var errors := parse_errors.duplicate()
	var warnings: Array[String] = []
	var total := 0
	for category in content:
		var seen := {}
		for entry in content[category]:
			total += 1
			if entry is not Dictionary or not entry.has("id") or String(entry.id).is_empty():
				errors.append("Entry in %s has no stable id" % category)
				continue
			if seen.has(entry.id):
				errors.append("Duplicate %s id: %s" % [category, entry.id])
			seen[entry.id] = true
	var expectations := {"modes": 6, "jobs": 25, "regions": 45, "achievements": 113, "town_center_tiers": 15}
	for category in expectations:
		var actual: int = content.get(category, []).size()
		if actual != expectations[category]:
			errors.append("Expected %d %s, found %d" % [expectations[category], category, actual])
	var resource_groups := {}
	for resource_definition in content.get("resources", []):
		resource_groups[String(resource_definition.get("group", ""))] = true
	for building in content.get("buildings", []):
		for job_id in building.get("jobs", []):
			if not indexes.get("jobs", {}).has(StringName(job_id)):
				errors.append("Building %s references missing job %s" % [building.id, job_id])
		var settlement_range: Dictionary = building.get("settlement_range", {})
		if not settlement_range.is_empty():
			var base_range := int(settlement_range.get("base", 0))
			var per_tier_range := int(settlement_range.get("per_tier", 0))
			var maximum_range := int(settlement_range.get("maximum", base_range + per_tier_range * maxi(0, int(building.get("tiers", 1)) - 1)))
			if base_range <= 0 or per_tier_range < 0 or maximum_range < base_range:
				errors.append("Building %s has an invalid settlement range definition" % building.id)
		var storage_profile: Dictionary = building.get("storage_profile", {})
		if not storage_profile.is_empty():
			var capacities: Array = storage_profile.get("capacity_by_tier", [])
			if capacities.size() != int(building.get("tiers", 1)) or capacities.any(func(value: Variant) -> bool: return int(value) <= 0):
				errors.append("Building %s storage profile must provide one positive capacity per tier" % building.id)
			for resource_id in storage_profile.get("resources", []):
				if not indexes.get("resources", {}).has(StringName(resource_id)):
					errors.append("Building %s storage profile references missing resource %s" % [building.id, resource_id])
			for resource_id in storage_profile.get("excluded_resources", []):
				if not indexes.get("resources", {}).has(StringName(resource_id)):
					errors.append("Building %s storage profile excludes missing resource %s" % [building.id, resource_id])
			for group_id in storage_profile.get("accepted_groups", []):
				if not resource_groups.has(String(group_id)):
					errors.append("Building %s storage profile references unknown resource group %s" % [building.id, group_id])
			if storage_profile.get("resources", []).is_empty() and storage_profile.get("accepted_groups", []).is_empty():
				errors.append("Building %s storage profile does not accept any resources" % building.id)
		var growth: Dictionary = building.get("growth", {})
		if not growth.is_empty():
			if String(growth.get("role", "")) != "crystal_motivator":
				errors.append("Building %s has an unknown natural-growth role" % building.id)
			for growth_field in ["range", "interval_ticks", "amount"]:
				if int(growth.get(growth_field, 0)) <= 0:
					errors.append("Building %s growth definition lacks positive %s" % [building.id, growth_field])
		if String(building.get("category", "")) == "hostile":
			var hostile: Dictionary = building.get("hostile", {})
			if bool(building.get("player_placeable", true)):
				errors.append("Hostile structure %s must not appear in the player build catalog" % building.id)
			if String(hostile.get("role", "")) not in ["road", "wall", "tower", "fire_pit", "graveyard"]:
				errors.append("Hostile structure %s has an invalid role" % building.id)
		var tower: Dictionary = building.get("tower", {})
		if String(building.get("category", "")) == "towers":
			if tower.is_empty() or not tower.has("role") or not tower.has("range") or not tower.has("reload_ticks"):
				errors.append("Tower %s lacks a complete combat definition" % building.id)
			var tower_ammo := String(tower.get("ammo", ""))
			if not tower_ammo.is_empty() and not indexes.get("resources", {}).has(StringName(tower_ammo)):
				errors.append("Tower %s references missing ammunition %s" % [building.id, tower_ammo])
		var golem: Dictionary = building.get("golem", {})
		if String(building.get("category", "")) == "golems":
			if golem.is_empty() or not golem.has("type") or not golem.has("charge_ticks"):
				errors.append("Combobulator %s lacks a complete golem definition" % building.id)
			elif not indexes.get("actors", {}).has(StringName(golem.type)):
				errors.append("Combobulator %s references missing golem actor %s" % [building.id, golem.type])
		var service: Dictionary = building.get("service", {})
		if String(building.id) == "clinic":
			if String(service.get("role", "")) != "medical" or int(service.get("treatment_ticks", 0)) <= 0:
				errors.append("Clinic lacks a complete medical service definition")
		elif String(building.id) == "maintenance_building":
			var required_maintenance_fields := ["repair_batch_hp", "repair_without_tool", "repair_with_tool", "dismantle_without_tool", "dismantle_with_tool", "dismantle_min_ticks", "dismantle_build_time_divisor", "tool_durability_per_tick", "salvage_ratio"]
			if String(service.get("role", "")) != "maintenance":
				errors.append("Maintenance Building lacks its maintenance service role")
			for field_id in required_maintenance_fields:
				if not service.has(field_id) or float(service.get(field_id, 0.0)) <= 0.0:
					errors.append("Maintenance Building service lacks positive %s" % field_id)
		var water: Dictionary = building.get("water", {})
		if not water.is_empty():
			var water_role := String(water.get("role", ""))
			if water_role not in ["source", "rain_catcher", "purifier", "fountain"]:
				errors.append("Water building %s has unknown role %s" % [building.id, water_role])
			var clean_capacity := int(water.get("clean_capacity", 0)) + int(water.get("clean_capacity_per_tier", 0))
			if clean_capacity <= 0:
				errors.append("Water building %s lacks positive clean-water capacity" % building.id)
			if water_role in ["source", "rain_catcher"] and int(water.get("generate_ticks", 0)) <= 0:
				errors.append("Water source %s lacks positive generation time" % building.id)
			if water_role == "purifier":
				for field_id in ["surface_range", "dirty_capacity_per_tier", "process_ticks", "carry_amount"]:
					if int(water.get(field_id, 0)) <= 0:
						errors.append("Water Purifier lacks positive %s" % field_id)
				if "water_masters" not in building.get("jobs", []):
					errors.append("Water Purifier must expose Water Master jobs")
			if water_role == "fountain" and (not bool(water.get("drinkable", false)) or int(water.get("service_range", 0)) <= 0):
				errors.append("Fountain %s lacks drink access or service range" % building.id)
		var cullis: Dictionary = building.get("cullis", {})
		if String(building.id) == "cullis_gate":
			if String(cullis.get("role", "")) != "sacrifice_gate":
				errors.append("Cullis Gate lacks its sacrifice-gate role")
			for field_id in ["cool_rate", "lightning_threshold", "overload_threshold", "lightning_damage", "explosion_damage", "explosion_radius", "instability_base", "instability_per_essence"]:
				if int(cullis.get(field_id, 0)) <= 0:
					errors.append("Cullis Gate lacks positive %s" % field_id)
			if int(cullis.get("overload_threshold", 0)) <= int(cullis.get("lightning_threshold", 0)):
				errors.append("Cullis Gate overload threshold must exceed its lightning threshold")
	for actor in content.get("actors", []):
		if String(actor.get("kind", "")) != "monster":
			continue
		var combat: Dictionary = actor.get("combat", {})
		if combat.is_empty() or not combat.has("health") or not combat.has("damage") or not combat.has("damage_type") or not combat.has("attack_reload") or not combat.has("speed"):
			errors.append("Monster %s lacks a complete combat definition" % actor.id)
		elif not indexes.get("damage_types", {}).has(StringName(combat.damage_type)):
			errors.append("Monster %s references missing damage type %s" % [actor.id, combat.damage_type])
	for recipe in content.get("recipes", []):
		if not indexes.get("buildings", {}).has(StringName(recipe.get("building", ""))):
			errors.append("Recipe %s references missing building %s" % [recipe.id, recipe.get("building", "")])
		for resource_id in recipe.get("inputs", {}).keys() + recipe.get("outputs", {}).keys():
			if not indexes.get("resources", {}).has(StringName(resource_id)):
				errors.append("Recipe %s references missing resource %s" % [recipe.id, resource_id])
	for resource in content.get("resources", []):
		if String(resource.get("group", "")) == "weapon" and resource.has("damage_type") and not indexes.get("damage_types", {}).has(StringName(resource.damage_type)):
			errors.append("Weapon %s references missing damage type %s" % [resource.id, resource.damage_type])
		if String(resource.id) in ["bandage", "medkit", "healing_potion"]:
			var medical: Dictionary = resource.get("medical", {})
			if int(medical.get("healing", 0)) <= 0 or not medical.has("cures"):
				errors.append("Medical resource %s lacks healing or cure data" % resource.id)
	for trade_good in content.get("trade_goods", []):
		if not indexes.get("resources", {}).has(StringName(trade_good.get("resource_id", ""))):
			errors.append("Trade good %s references missing resource %s" % [trade_good.id, trade_good.get("resource_id", "")])
	for loot_table in content.get("loot_tables", []):
		if int(loot_table.get("rolls", 0)) <= 0 or loot_table.get("outcomes", []).is_empty():
			errors.append("Loot table %s lacks rolls or outcomes" % loot_table.id)
		for outcome in loot_table.get("outcomes", []):
			if not indexes.get("resources", {}).has(StringName(outcome.get("resource_id", ""))):
				errors.append("Loot table %s references missing resource %s" % [loot_table.id, outcome.get("resource_id", "")])
			if int(outcome.get("amount", 0)) <= 0 or int(outcome.get("weight", 0)) <= 0:
				errors.append("Loot table %s has a non-positive amount or weight" % loot_table.id)
	for loot_profile in content.get("loot_site_profiles", []):
		if int(loot_profile.get("site_count", 0)) <= 0 or int(loot_profile.get("key_sites", -1)) < 0 or int(loot_profile.get("key_sites", 0)) > int(loot_profile.get("site_count", 0)):
			errors.append("Loot site profile %s has invalid site/key counts" % loot_profile.id)
	for region in content.get("regions", []):
		for neighbor_id in region.get("adjacent", []):
			if not indexes.get("regions", {}).has(StringName(neighbor_id)):
				errors.append("Region %s references missing neighbor %s" % [region.id, neighbor_id])
	for rule in content.get("achievement_rules", []):
		if not indexes.get("achievements", {}).has(StringName(rule.get("achievement_id", ""))):
			errors.append("Achievement rule %s references missing achievement %s" % [rule.id, rule.get("achievement_id", "")])
	for ledger in content.get("parity", []):
		if ledger.get("status", "") == "VERIFY_RUNTIME":
			warnings.append("Runtime verification pending: %s" % ledger.id)
	return {"valid": errors.is_empty(), "errors": errors, "warnings": warnings, "total_entries": total}

func get_all(category: StringName) -> Array:
	return content.get(String(category), [])

func get_by_id(category: StringName, id: StringName) -> Dictionary:
	return indexes.get(String(category), {}).get(id, {})

func get_buildings_in_category(category_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for building in get_all(&"buildings"):
		if building.get("category", "") == String(category_id) and building.get("status", "current") != "legacy_removed":
			result.append(building)
	return result
