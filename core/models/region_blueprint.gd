class_name RegionBlueprint
extends RefCounted

const VERSION := 2

var seed: int
var region_id: StringName
var biome_id: StringName
var width: int
var height: int
var tiles: PackedByteArray
var elevations: PackedByteArray
var resource_nodes: Array[Dictionary] = []
var starting_cell := Vector2i.ZERO
var validation_report: Dictionary = {}

func _init(p_seed: int = 1, p_region_id: StringName = &"applemeadow", p_biome_id: StringName = &"forest", p_width: int = 256, p_height: int = 256) -> void:
	seed = p_seed
	region_id = p_region_id
	biome_id = p_biome_id
	width = p_width
	height = p_height
	tiles.resize(width * height)
	elevations.resize(width * height)
	elevations.fill(1)

func get_tile(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return 0
	return tiles[cell.y * width + cell.x]

func set_tile(cell: Vector2i, value: int) -> void:
	if cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height:
		var index := cell.y * width + cell.x
		var previous := int(tiles[index])
		tiles[index] = value
		if value == 0:
			elevations[index] = 0
		elif previous == 0 and int(elevations[index]) == 0:
			elevations[index] = 1

func get_elevation(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height or elevations.size() != width * height:
		return 0
	return int(elevations[cell.y * width + cell.x])

func set_elevation(cell: Vector2i, value: int) -> void:
	if cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height:
		elevations[cell.y * width + cell.x] = clampi(value, 0, 3)

func is_buildable(cell: Vector2i, footprint: Vector2i = Vector2i.ONE) -> bool:
	var foundation_elevation := get_elevation(cell)
	if foundation_elevation <= 0:
		return false
	for y in range(cell.y, cell.y + footprint.y):
		for x in range(cell.x, cell.x + footprint.x):
			var candidate := Vector2i(x, y)
			if get_tile(candidate) not in [1, 6, 7] or get_elevation(candidate) != foundation_elevation:
				return false
	return true

func to_dictionary() -> Dictionary:
	var tile_values: Array = []
	tile_values.resize(tiles.size())
	for index in tiles.size():
		tile_values[index] = int(tiles[index])
	var elevation_values: Array = []
	elevation_values.resize(elevations.size())
	for index in elevations.size():
		elevation_values[index] = int(elevations[index])
	return {
		"version": VERSION,
		"seed": seed,
		"region_id": String(region_id),
		"biome_id": String(biome_id),
		"width": width,
		"height": height,
		"tiles": tile_values,
		"elevations": elevation_values,
		"resource_nodes": resource_nodes.duplicate(true),
		"starting_cell": [starting_cell.x, starting_cell.y],
		"validation_report": validation_report.duplicate(true),
	}

static func from_dictionary(data: Dictionary) -> RegionBlueprint:
	var restored := RegionBlueprint.new(int(data.get("seed", 1)), StringName(data.get("region_id", "applemeadow")), StringName(data.get("biome_id", "forest")), int(data.get("width", 256)), int(data.get("height", 256)))
	var tile_values: Array = data.get("tiles", [])
	if tile_values.size() == restored.width * restored.height:
		for index in tile_values.size():
			restored.tiles[index] = int(tile_values[index])
	var elevation_values: Array = data.get("elevations", [])
	if elevation_values.size() == restored.width * restored.height:
		for index in elevation_values.size():
			restored.elevations[index] = clampi(int(elevation_values[index]), 0, 3)
	else:
		# Version-one saves predate explicit topography. Derive a conservative
		# migration that preserves placement and water traversal.
		for index in restored.tiles.size():
			var tile := int(restored.tiles[index])
			restored.elevations[index] = 0 if tile == 0 else (2 if tile == 3 else 1)
	restored.resource_nodes.clear()
	for resource_node in data.get("resource_nodes", []):
		if resource_node is Dictionary:
			restored.resource_nodes.append(resource_node.duplicate(true))
	var start: Array = data.get("starting_cell", [restored.width / 2, restored.height / 2])
	restored.starting_cell = Vector2i(int(start[0]), int(start[1]))
	restored.validation_report = data.get("validation_report", {}).duplicate(true)
	return restored
