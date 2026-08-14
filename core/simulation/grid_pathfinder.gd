class_name RegionPathfinder
extends RefCounted

var grid := AStarGrid2D.new()
var width := 0
var height := 0
var deep_water_cells: Array[Vector2i] = []
var deep_water_frozen := false

func configure(blueprint: RegionBlueprint) -> void:
	width = blueprint.width
	height = blueprint.height
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, width, height)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	deep_water_cells.clear()
	deep_water_frozen = false
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			if blueprint.get_tile(cell) == RegionGenerator.Tile.DEEP_WATER:
				var water_cell := cell
				deep_water_cells.append(water_cell)
				grid.set_point_solid(water_cell, true)
			else:
				# Height bands are traversable top surfaces, but uphill terrain is less
				# attractive until roads explicitly improve it. Cliffs are never encoded
				# as impassable decorative pixels.
				grid.set_point_weight_scale(cell, 1.0 + float(maxi(0, blueprint.get_elevation(cell) - 1)) * 0.18)

func find_path(from_cell: Vector2i, to_cell: Vector2i) -> Array:
	var start := _nearest_walkable(_clamp_cell(from_cell))
	var goal := _nearest_walkable(_clamp_cell(to_cell))
	if start.x < 0 or goal.x < 0:
		return []
	var ids := grid.get_id_path(start, goal, true)
	var result: Array = []
	for cell in ids:
		result.append([cell.x, cell.y])
	return result

func is_walkable(cell: Vector2i) -> bool:
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)

func set_deep_water_frozen(frozen: bool) -> void:
	if frozen == deep_water_frozen:
		return
	deep_water_frozen = frozen
	for cell in deep_water_cells:
		grid.set_point_solid(cell, not frozen)
		grid.set_point_weight_scale(cell, 1.45 if frozen else 1.0)

func nearest_walkable(origin: Vector2i) -> Vector2i:
	return _nearest_walkable(_clamp_cell(origin), maxi(width, height))

func set_dynamic_solid(cell: Vector2i, solid: bool) -> void:
	if grid.is_in_boundsv(cell):
		grid.set_point_solid(cell, solid)

func set_travel_weight(cell: Vector2i, weight: float) -> void:
	if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
		grid.set_point_weight_scale(cell, maxf(0.05, weight))

func get_travel_weight(cell: Vector2i) -> float:
	if not grid.is_in_boundsv(cell):
		return 1.0
	return grid.get_point_weight_scale(cell)

func _nearest_walkable(origin: Vector2i, maximum_radius: int = 8) -> Vector2i:
	if is_walkable(origin):
		return origin
	for radius in range(1, maximum_radius + 1):
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in [origin.x - radius, origin.x + radius]:
				if is_walkable(Vector2i(x, y)):
					return Vector2i(x, y)
		for x in range(origin.x - radius + 1, origin.x + radius):
			for y in [origin.y - radius, origin.y + radius]:
				if is_walkable(Vector2i(x, y)):
					return Vector2i(x, y)
	return Vector2i(-1, -1)

func _clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(clampi(cell.x, 0, width - 1), clampi(cell.y, 0, height - 1))
