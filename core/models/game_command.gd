class_name GameCommand
extends RefCounted

enum Kind {
	SET_PAUSED,
	SET_SPEED,
	PLACE_BUILDING,
	SET_JOB_DESIRED,
	CANCEL_BUILDING,
	CAST_SPELL,
	UPGRADE_BUILDING,
	SET_RECIPE_POLICY,
	TRADE_RESOURCE,
	SET_TRADE_RULE,
	HIRE_CATJEET,
	DESIGNATE_ANIMAL_CAPTURE,
	DESIGNATE_ANIMAL_SLAUGHTER,
	SET_BUILDING_WORK,
	DESIGNATE_TERRAIN_WORK,
	SET_STORAGE_FILTER,
}

var kind: Kind
var target_tick: int
var payload: Dictionary

func _init(p_kind: Kind, p_target_tick: int, p_payload: Dictionary = {}) -> void:
	kind = p_kind
	target_tick = p_target_tick
	payload = p_payload.duplicate(true)

static func place_building(tick: int, building_id: StringName, cell: Vector2i) -> GameCommand:
	return GameCommand.new(Kind.PLACE_BUILDING, tick, {
		"building_id": String(building_id),
		"cell_x": cell.x,
		"cell_y": cell.y,
	})

static func set_job_desired(tick: int, job_id: StringName, amount: int) -> GameCommand:
	return GameCommand.new(Kind.SET_JOB_DESIRED, tick, {
		"job_id": String(job_id),
		"amount": amount,
	})

static func cast_spell(tick: int, spell_id: StringName, cell: Vector2i, payload: Dictionary = {}) -> GameCommand:
	var spell_payload := payload.duplicate(true)
	spell_payload["spell_id"] = String(spell_id)
	spell_payload["cell_x"] = cell.x
	spell_payload["cell_y"] = cell.y
	return GameCommand.new(Kind.CAST_SPELL, tick, spell_payload)

static func upgrade_building(tick: int, building_entity_id: int, branch: StringName = &"") -> GameCommand:
	return GameCommand.new(Kind.UPGRADE_BUILDING, tick, {"building_entity_id": building_entity_id, "branch": String(branch)})

static func set_recipe_policy(tick: int, building_entity_id: int, recipe_id: StringName, mode: StringName, target: int) -> GameCommand:
	return GameCommand.new(Kind.SET_RECIPE_POLICY, tick, {
		"building_entity_id": building_entity_id,
		"recipe_id": String(recipe_id),
		"mode": String(mode),
		"target": maxi(0, target),
	})

static func trade_resource(tick: int, marketplace_entity_id: int, direction: StringName, resource_id: StringName, amount: int) -> GameCommand:
	return GameCommand.new(Kind.TRADE_RESOURCE, tick, {
		"marketplace_entity_id": marketplace_entity_id,
		"direction": String(direction),
		"resource_id": String(resource_id),
		"amount": maxi(1, amount),
	})

static func set_trade_rule(tick: int, marketplace_entity_id: int, resource_id: StringName, buy_below: int, sell_above: int, batch: int = 8) -> GameCommand:
	return GameCommand.new(Kind.SET_TRADE_RULE, tick, {
		"marketplace_entity_id": marketplace_entity_id,
		"resource_id": String(resource_id),
		"buy_below": maxi(0, buy_below),
		"sell_above": maxi(0, sell_above),
		"batch": maxi(1, batch),
	})

static func hire_catjeet(tick: int, marketplace_entity_id: int, amount: int = 1) -> GameCommand:
	return GameCommand.new(Kind.HIRE_CATJEET, tick, {
		"marketplace_entity_id": marketplace_entity_id,
		"amount": maxi(1, amount),
	})

static func designate_animal_capture(tick: int, animal_entity_id: int, enabled: bool = true) -> GameCommand:
	return GameCommand.new(Kind.DESIGNATE_ANIMAL_CAPTURE, tick, {"animal_entity_id": animal_entity_id, "enabled": enabled})

static func designate_animal_slaughter(tick: int, animal_entity_id: int, enabled: bool = true) -> GameCommand:
	return GameCommand.new(Kind.DESIGNATE_ANIMAL_SLAUGHTER, tick, {"animal_entity_id": animal_entity_id, "enabled": enabled})

static func set_building_work(tick: int, building_entity_id: int, action: StringName, enabled: bool = true) -> GameCommand:
	return GameCommand.new(Kind.SET_BUILDING_WORK, tick, {
		"building_entity_id": building_entity_id,
		"action": String(action),
		"enabled": enabled,
	})

static func designate_terrain_work(tick: int, action: StringName, cell: Vector2i, enabled: bool = true) -> GameCommand:
	return GameCommand.new(Kind.DESIGNATE_TERRAIN_WORK, tick, {
		"action": String(action),
		"cell_x": cell.x,
		"cell_y": cell.y,
		"enabled": enabled,
	})

static func set_storage_filter(tick: int, building_entity_id: int, resource_id: StringName, enabled: bool) -> GameCommand:
	return GameCommand.new(Kind.SET_STORAGE_FILTER, tick, {
		"building_entity_id": building_entity_id,
		"resource_id": String(resource_id),
		"enabled": enabled,
	})
