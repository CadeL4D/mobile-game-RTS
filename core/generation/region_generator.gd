class_name RegionGenerator
extends RefCounted

const WIDTH := 256
const HEIGHT := 256
const MAX_ATTEMPTS := 64

enum Tile {
	DEEP_WATER,
	GRASS,
	FOREST_FLOOR,
	ROCKY,
	CRYSTAL_GROUND,
	FERTILE,
	SAND,
	MARSH,
	CORRUPTION,
}

func generate(seed: int, region_id: StringName, biome_id: StringName) -> RegionBlueprint:
	for attempt in MAX_ATTEMPTS:
		var blueprint := _generate_once(seed + attempt * 7919, region_id, biome_id)
		var report := validate(blueprint)
		blueprint.validation_report = report
		if report.get("valid", false):
			return blueprint
	var fallback := _generate_once(seed, region_id, biome_id)
	_force_safe_start(fallback)
	fallback.validation_report = validate(fallback)
	fallback.validation_report["used_fallback"] = true
	return fallback

func _generate_once(seed: int, region_id: StringName, biome_id: StringName) -> RegionBlueprint:
	var result := RegionBlueprint.new(seed, region_id, biome_id, WIDTH, HEIGHT)
	var elevation := FastNoiseLite.new()
	elevation.seed = seed
	elevation.frequency = 0.018
	elevation.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var detail := FastNoiseLite.new()
	detail.seed = seed ^ 0x5f3759df
	detail.frequency = 0.071
	detail.fractal_octaves = 3
	var resources := FastNoiseLite.new()
	resources.seed = seed ^ 0x1b873593
	resources.frequency = 0.13
	for y in HEIGHT:
		for x in WIDTH:
			var nx := (float(x) / float(WIDTH - 1) - 0.5) * 2.0
			var ny := (float(y) / float(HEIGHT - 1) - 0.5) * 2.0
			var island_falloff := pow(max(abs(nx) * 0.86, abs(ny)), 2.35)
			var e := elevation.get_noise_2d(x, y) * 0.48 + detail.get_noise_2d(x, y) * 0.13 - island_falloff + 0.32
			var tile := Tile.GRASS
			var water_threshold := 0.08 if biome_id == &"island" else -0.08
			if e < water_threshold:
				tile = Tile.DEEP_WATER
			elif biome_id in [&"desert", &"red_sands"]:
				tile = Tile.SAND if e < 0.58 else Tile.ROCKY
			elif biome_id == &"marsh":
				tile = Tile.MARSH if e < 0.31 else Tile.GRASS
			elif biome_id == &"dry_lands":
				tile = Tile.SAND if e < 0.28 else Tile.GRASS
			else:
				tile = Tile.FOREST_FLOOR if e > 0.27 and detail.get_noise_2d(x + 440, y) > -0.16 else Tile.GRASS
			if tile != Tile.DEEP_WATER:
				var r := resources.get_noise_2d(x, y)
				if r > 0.66:
					tile = Tile.ROCKY
				elif r < -0.70:
					tile = Tile.CRYSTAL_GROUND
				elif detail.get_noise_2d(x - 200, y + 310) > 0.64:
					tile = Tile.FERTILE
			result.tiles[y * WIDTH + x] = tile
	result.starting_cell = _find_start(result)
	_clear_starting_area(result)
	_populate_resource_nodes(result)
	_ensure_survival_resources(result)
	_seed_corruption(result)
	return result

func _find_start(blueprint: RegionBlueprint) -> Vector2i:
	var center := Vector2i(blueprint.width / 2, blueprint.height / 2)
	if blueprint.get_tile(center) != Tile.DEEP_WATER:
		return center
	for radius in range(8, 97, 8):
		for index in 24:
			var angle := TAU * float(index) / 24.0
			var cell := center + Vector2i(roundi(cos(angle) * radius), roundi(sin(angle) * radius))
			if blueprint.get_tile(cell) != Tile.DEEP_WATER:
				return cell
	return center

func _clear_starting_area(blueprint: RegionBlueprint) -> void:
	# Keep the first camp viable without stamping a conspicuous square into the
	# biome. The inner area is guaranteed; the outer edge is a deterministic,
	# softly broken clearing that blends back into the generated ground.
	var safe_tile := Tile.GRASS
	if blueprint.biome_id in [&"desert", &"red_sands", &"dry_lands"]:
		safe_tile = Tile.SAND
	elif blueprint.biome_id == &"marsh":
		safe_tile = Tile.MARSH
	for y in range(blueprint.starting_cell.y - 31, blueprint.starting_cell.y + 32):
		for x in range(blueprint.starting_cell.x - 31, blueprint.starting_cell.x + 32):
			var offset := Vector2i(x, y) - blueprint.starting_cell
			var guaranteed := Vector2(offset).length() <= 26.0
			var edge_hash := posmod(x * 92821 + y * 68917 + blueprint.seed * 31, 17)
			var broken_radius := 28.0 + (float(edge_hash) - 8.0) * 0.32
			if guaranteed or Vector2(offset).length() <= broken_radius:
				blueprint.set_tile(Vector2i(x, y), safe_tile)

func _force_safe_start(blueprint: RegionBlueprint) -> void:
	blueprint.starting_cell = Vector2i(blueprint.width / 2, blueprint.height / 2)
	_clear_starting_area(blueprint)
	_populate_resource_nodes(blueprint)
	_ensure_survival_resources(blueprint)

func _ensure_survival_resources(blueprint: RegionBlueprint) -> void:
	# The reference always gives the player a viable first settlement. Guaranteeing
	# a composed resource ring avoids wasting full-map generation attempts.
	var center := blueprint.starting_cell
	var guaranteed := [
		{"id": "wood", "offset": Vector2i(-26, -14), "tile": Tile.FOREST_FLOOR, "amount": 40},
		{"id": "rock", "offset": Vector2i(25, -13), "tile": Tile.ROCKY, "amount": 40},
		{"id": "crystal", "offset": Vector2i(24, 18), "tile": Tile.CRYSTAL_GROUND, "amount": 24},
		{"id": "raw_vegetables", "offset": Vector2i(-25, 18), "tile": Tile.FERTILE, "amount": 32},
	]
	for entry in guaranteed:
		var cell: Vector2i = center + Vector2i(entry.offset)
		for y in range(cell.y - 4, cell.y + 5):
			for x in range(cell.x - 4, cell.x + 5):
				var offset := Vector2i(x, y) - cell
				var edge_hash := posmod(x * 3571 + y * 2377 + blueprint.seed * 13 + int(entry.tile) * 97, 19)
				var broken_radius := 3.1 + (float(edge_hash) - 9.0) * 0.11
				if Vector2(offset).length() <= broken_radius:
					blueprint.set_tile(Vector2i(x, y), int(entry.tile))
		blueprint.resource_nodes.append({"id": entry.id, "x": cell.x, "y": cell.y, "amount": entry.amount})
	var water_center := center + Vector2i(0, 28)
	for y in range(water_center.y - 5, water_center.y + 6):
		for x in range(water_center.x - 7, water_center.x + 8):
			var offset := Vector2i(x, y) - water_center
			var ellipse_distance := sqrt(pow(float(offset.x) / 6.0, 2.0) + pow(float(offset.y) / 4.0, 2.0))
			var edge_hash := posmod(x * 1877 + y * 3163 + blueprint.seed * 29, 17)
			if ellipse_distance <= 1.0 + (float(edge_hash) - 8.0) * 0.025:
				blueprint.set_tile(Vector2i(x, y), Tile.DEEP_WATER)

func _seed_corruption(blueprint: RegionBlueprint) -> void:
	var angle := float(posmod(blueprint.seed, 6283)) / 1000.0
	var center := blueprint.starting_cell + Vector2i(roundi(cos(angle) * 88.0), roundi(sin(angle) * 88.0))
	center.x = clampi(center.x, 18, blueprint.width - 19)
	center.y = clampi(center.y, 18, blueprint.height - 19)
	for radius in range(0, 42):
		if blueprint.get_tile(center) != Tile.DEEP_WATER:
			break
		center = blueprint.starting_cell + Vector2i(roundi(cos(angle + radius * 0.31) * (72.0 + radius)), roundi(sin(angle + radius * 0.31) * (72.0 + radius)))
		center.x = clampi(center.x, 18, blueprint.width - 19)
		center.y = clampi(center.y, 18, blueprint.height - 19)
	for y in range(center.y - 14, center.y + 15):
		for x in range(center.x - 14, center.x + 15):
			var cell := Vector2i(x, y)
			var distance := Vector2(cell - center).length()
			var ragged := float((x * 37 + y * 19 + blueprint.seed) & 7) * 0.42
			if distance <= 11.5 + ragged and blueprint.get_tile(cell) != Tile.DEEP_WATER:
				blueprint.set_tile(cell, Tile.CORRUPTION)

func _populate_resource_nodes(blueprint: RegionBlueprint) -> void:
	blueprint.resource_nodes.clear()
	for y in range(2, HEIGHT - 2):
		for x in range(2, WIDTH - 2):
			var tile := blueprint.get_tile(Vector2i(x, y))
			var resource_id := ""
			if tile == Tile.FOREST_FLOOR:
				resource_id = "wood"
			elif tile == Tile.ROCKY:
				resource_id = "rock"
			elif tile == Tile.CRYSTAL_GROUND:
				resource_id = "crystal"
			elif tile == Tile.FERTILE:
				resource_id = "raw_vegetables"
			var scatter_hash := posmod(x * x * 1741 + y * y * 3253 + x * y * 953 + blueprint.seed * 37 + tile * 101, 104729)
			if not resource_id.is_empty() and scatter_hash % 17 == 0:
				blueprint.resource_nodes.append({"id": resource_id, "x": x, "y": y, "amount": 12, "variant": scatter_hash % 4})

func validate(blueprint: RegionBlueprint) -> Dictionary:
	var counts := {"wood": 0, "rock": 0, "crystal": 0, "raw_vegetables": 0, "water": 0}
	var radius_sq := 70 * 70
	for node in blueprint.resource_nodes:
		var dx: int = int(node.x) - blueprint.starting_cell.x
		var dy: int = int(node.y) - blueprint.starting_cell.y
		if dx * dx + dy * dy <= radius_sq:
			counts[node.id] = counts.get(node.id, 0) + int(node.amount)
	for y in range(max(0, blueprint.starting_cell.y - 70), min(HEIGHT, blueprint.starting_cell.y + 71)):
		for x in range(max(0, blueprint.starting_cell.x - 70), min(WIDTH, blueprint.starting_cell.x + 71)):
			if blueprint.get_tile(Vector2i(x, y)) == Tile.DEEP_WATER:
				counts.water += 1
	var buildable: bool = blueprint.is_buildable(blueprint.starting_cell - Vector2i(6, 6), Vector2i(13, 13))
	var valid: bool = buildable and int(counts.wood) >= 24 and int(counts.rock) >= 24 and int(counts.crystal) >= 12 and int(counts.raw_vegetables) >= 12 and int(counts.water) >= 8
	return {"valid": valid, "buildable_start": buildable, "nearby": counts}
