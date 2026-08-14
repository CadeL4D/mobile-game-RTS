class_name CorruptionSystem
extends RefCounted

## Coordinates corruption cell expansion, hostile drone AI,
## and construction of hostile infrastructure (roads, walls, fire pits, graveyards).

var corruption_cells: Dictionary = {} # "x:y" (String) -> float (strength)
var hostile_structures: Array[Dictionary] = []
var next_structure_id: int = 1

func clear() -> void:
	corruption_cells.clear()
	hostile_structures.clear()
	next_structure_id = 1

func add_corruption_cell(cell: Vector2i, strength: float = 1.0) -> void:
	corruption_cells["%d:%d" % [cell.x, cell.y]] = clampf(strength, 0.0, 1.0)

func is_cell_corrupted(cell: Vector2i) -> bool:
	return corruption_cells.has("%d:%d" % [cell.x, cell.y])

func update_drones(
	drones: Array,
	settlement_buildings: Array,
	current_tick: int
) -> void:
	# Hostile drones build corrupted walls and roads
	if current_tick % 240 == 0:
		for drone in drones:
			if bool(drone.get("dead", false)):
				continue
			var dpos := Vector2i(int(drone.get("x", 0)), int(drone.get("y", 0)))
			if not is_cell_corrupted(dpos):
				add_corruption_cell(dpos, 0.8)

func export_state() -> Dictionary:
	return {
		"corruption_cells": corruption_cells.duplicate(true),
		"hostile_structures": hostile_structures.duplicate(true),
		"next_structure_id": next_structure_id
	}

func import_state(data: Dictionary) -> void:
	clear()
	corruption_cells = data.get("corruption_cells", {}).duplicate(true)
	hostile_structures.clear()
	for s in data.get("hostile_structures", []):
		if s is Dictionary:
			hostile_structures.append(s.duplicate(true))
	next_structure_id = int(data.get("next_structure_id", 1))
