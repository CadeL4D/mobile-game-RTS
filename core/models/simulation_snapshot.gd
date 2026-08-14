class_name SimulationSnapshot
extends RefCounted

var tick: int = 0
var day: int = 1
var day_fraction: float = 0.25
var season: StringName = &"Spring"
var weather: StringName = &"clear"
var active_event: StringName = &""
var temperature_c: int = 18
var water_frozen: bool = false
var event_ticks_remaining: int = 0
var paused: bool = false
var speed: int = 1
var population: int = 0
var influence: int = 0
var max_influence: int = 0
var god_xp: int = 0
var resources: Dictionary = {}
var resource_caps: Dictionary = {}
var resource_rates: Dictionary = {}
var resource_nodes: Array[Dictionary] = []
var loose_items: Array[Dictionary] = []
var held_entity: Dictionary = {}
var magic_circles: Array[Dictionary] = []
var catjeet_trader: Dictionary = {}
var next_trade_arrival_tick: int = 0
var jobs: Dictionary = {}
var housing_capacity: int = 0
var animal_pen_capacity: int = 0
var clucker_coop_capacity: int = 0
var doggo_house_capacity: int = 0
var building_limit: int = 0
var build_range: int = 0
var ancillary_limit: int = 0
var task_summary: Dictionary = {}
var population_groups: Dictionary = {}
var villagers: Array[Dictionary] = []
var nomads: Array[Dictionary] = []
var animals: Array[Dictionary] = []
var golems: Array[Dictionary] = []
var monsters: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
var corruption_cells: Array = []
var terrain_effects: Array = []
var terrain_work: Array = []
var buildings: Array[Dictionary] = []
var goals: Dictionary = {}
var messages: Array[String] = []

func to_dictionary() -> Dictionary:
	return {
		"tick": tick,
		"day": day,
		"day_fraction": day_fraction,
		"season": String(season),
		"weather": String(weather),
		"active_event": String(active_event),
		"temperature_c": temperature_c,
		"water_frozen": water_frozen,
		"event_ticks_remaining": event_ticks_remaining,
		"paused": paused,
		"speed": speed,
		"population": population,
		"influence": influence,
		"max_influence": max_influence,
		"god_xp": god_xp,
		"resources": resources.duplicate(true),
		"resource_caps": resource_caps.duplicate(true),
		"resource_rates": resource_rates.duplicate(true),
		"resource_nodes": resource_nodes.duplicate(true),
		"loose_items": loose_items.duplicate(true),
		"held_entity": held_entity.duplicate(true),
		"magic_circles": magic_circles.duplicate(true),
		"catjeet_trader": catjeet_trader.duplicate(true),
		"next_trade_arrival_tick": next_trade_arrival_tick,
		"jobs": jobs.duplicate(true),
		"housing_capacity": housing_capacity,
		"animal_pen_capacity": animal_pen_capacity,
		"clucker_coop_capacity": clucker_coop_capacity,
		"doggo_house_capacity": doggo_house_capacity,
		"building_limit": building_limit,
		"build_range": build_range,
		"ancillary_limit": ancillary_limit,
		"task_summary": task_summary.duplicate(true),
		"population_groups": population_groups.duplicate(true),
		"villagers": villagers.duplicate(true),
		"nomads": nomads.duplicate(true),
		"animals": animals.duplicate(true),
		"golems": golems.duplicate(true),
		"monsters": monsters.duplicate(true),
		"ghosts": ghosts.duplicate(true),
		"corruption_cells": corruption_cells.duplicate(true),
		"terrain_effects": terrain_effects.duplicate(true),
		"terrain_work": terrain_work.duplicate(true),
		"buildings": buildings.duplicate(true),
		"goals": goals.duplicate(true),
		"messages": messages.duplicate(),
	}
