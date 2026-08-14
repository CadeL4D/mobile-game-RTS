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
	elevation.frequency = 0.010
	elevation.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var detail := FastNoiseLite.new()
	detail.seed = seed ^ 0x5f3759df
	detail.frequency = 0.034
	detail.fractal_octaves = 3
	var geology := FastNoiseLite.new()
	geology.seed = seed ^ 0x1b873593
	geology.frequency = 0.021
	geology.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var canopy := FastNoiseLite.new()
	canopy.seed = seed ^ 0x6c8e9cf5
	canopy.frequency = 0.017
	canopy.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	for y in HEIGHT:
		for x in WIDTH:
			var nx := (float(x) / float(WIDTH - 1) - 0.5) * 2.0
			var ny := (float(y) / float(HEIGHT - 1) - 0.5) * 2.0
			var island_falloff := pow(max(abs(nx) * 0.86, abs(ny)), 2.35)
			var e := elevation.get_noise_2d(x, y) * 0.52 + detail.get_noise_2d(x, y) * 0.08 - island_falloff + 0.32
			var rock_field := geology.get_noise_2d(x, y)
			var forest_field := canopy.get_noise_2d(x, y) + detail.get_noise_2d(x + 440, y) * 0.18
			var tile := Tile.GRASS
			var water_threshold := 0.08 if biome_id == &"island" else -0.08
			if e < water_threshold:
				tile = Tile.DEEP_WATER
			elif biome_id in [&"desert", &"red_sands"]:
				tile = Tile.ROCKY if e > 0.60 or rock_field > 0.48 else Tile.SAND
			elif biome_id == &"marsh":
				tile = Tile.MARSH if e < 0.31 else Tile.GRASS
			elif biome_id == &"dry_lands":
				tile = Tile.SAND if e < 0.28 else Tile.GRASS
			else:
				# Canopy is governed by a low-frequency field so it forms broad,
				# readable forests instead of chains of one-cell noise islands.
				tile = Tile.FOREST_FLOOR if e > 0.05 and forest_field > 0.09 else Tile.GRASS
			if tile != Tile.DEEP_WATER:
				if rock_field > 0.54 or e > 0.69:
					tile = Tile.ROCKY
				elif rock_field < -0.64:
					tile = Tile.CRYSTAL_GROUND
				elif detail.get_noise_2d(x - 200, y + 310) > 0.60:
					tile = Tile.FERTILE
			var terrain_index := y * WIDTH + x
			result.tiles[terrain_index] = tile
			result.elevations[terrain_index] = 0 if tile == Tile.DEEP_WATER else (3 if e > 0.62 else (2 if e > 0.34 else 1))
	_cleanup_landforms(result, 2)
	result.starting_cell = _find_start(result)
	_clear_starting_area(result)
	_compose_starting_landmarks(result)
	# Authored landmarks are added after the main terrain cleanup. One restrained
	# majority pass removes accidental one-cell cliff teeth where the clearing and
	# shelf overlap, while leaving their broad silhouettes intact.
	_cleanup_landforms(result, 1)
	_populate_resource_nodes(result)
	_ensure_survival_resources(result)
	_seed_corruption(result)
	return result

func _cleanup_landforms(blueprint: RegionBlueprint, passes: int) -> void:
	# Remove single-cell whiskers and pinholes while preserving the large masses
	# selected above. This is a composition pass, not a visual blur.
	for pass_index in passes:
		var source := blueprint.tiles.duplicate()
		for y in range(1, blueprint.height - 1):
			for x in range(1, blueprint.width - 1):
				var counts: Dictionary = {}
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						var neighbor_tile: int = int(source[(y + oy) * blueprint.width + x + ox])
						counts[neighbor_tile] = int(counts.get(neighbor_tile, 0)) + 1
				var current: int = int(source[y * blueprint.width + x])
				var winner := current
				var winner_count := int(counts.get(current, 0))
				for candidate in counts:
					var candidate_count := int(counts[candidate])
					if candidate_count > winner_count:
						winner = int(candidate)
						winner_count = candidate_count
				if winner_count >= 6:
					blueprint.set_tile(Vector2i(x, y), winner)

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
				var cell := Vector2i(x, y)
				blueprint.set_tile(cell, safe_tile)
				blueprint.set_elevation(cell, 1)

func _compose_starting_landmarks(blueprint: RegionBlueprint) -> void:
	# Give the first playable view a deliberate large-scale landmark. Natural
	# geology belongs in connected shelves; harvestable boulders are then
	# scattered over it by the normal resource pass.
	var center := blueprint.starting_cell + Vector2i(73, -30)
	for y in range(center.y - 26, center.y + 27):
		for x in range(center.x - 34, center.x + 35):
			var offset := Vector2i(x, y) - center
			var ellipse := sqrt(pow(float(offset.x) / 31.0, 2.0) + pow(float(offset.y) / 22.0, 2.0))
			# Boundary noise is intentionally sub-cell in amplitude. The former 12%
			# radius jitter produced long, comb-like rocky fingers at an otherwise
			# horizontal shelf edge once magnified to world pixels.
			var coast_break := float(posmod(x * 1877 + y * 3163 + blueprint.seed * 43, 31) - 15) * 0.0023
			var lobe := sin(float(offset.y) * 0.27) * 0.055 + cos(float(offset.x) * 0.19) * 0.040
			if ellipse <= 1.0 + coast_break + lobe and blueprint.get_tile(Vector2i(x, y)) != Tile.DEEP_WATER:
				var cell := Vector2i(x, y)
				blueprint.set_tile(cell, Tile.ROCKY)
				blueprint.set_elevation(cell, 2)
	# Two grass pockets break the plate into authored-looking nested shelves.
	for pocket in [
		{"offset": Vector2i(-8, -2), "rx": 8.0, "ry": 5.0},
		{"offset": Vector2i(12, 7), "rx": 6.0, "ry": 4.0},
	]:
		var pocket_center: Vector2i = center + Vector2i(pocket.offset)
		for y in range(pocket_center.y - 6, pocket_center.y + 7):
			for x in range(pocket_center.x - 10, pocket_center.x + 11):
				var offset := Vector2i(x, y) - pocket_center
				if pow(float(offset.x) / float(pocket.rx), 2.0) + pow(float(offset.y) / float(pocket.ry), 2.0) <= 1.0:
					var cell := Vector2i(x, y)
					blueprint.set_tile(cell, Tile.GRASS)
					blueprint.set_elevation(cell, 2)

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
				var cell := Vector2i(x, y)
				blueprint.set_tile(cell, Tile.DEEP_WATER)
				blueprint.set_elevation(cell, 0)

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
			# Broad rocky shelves are geology first and harvest nodes second. A lower
			# boulder density exposes the connected plate art and produces intentional
			# talus clusters instead of an equal-sized pebble carpet.
			var scatter_modulus := 17
			var node_amount := 12
			if tile == Tile.FOREST_FLOOR:
				# Fewer resource crowns let the continuous forest material carry the
				# canopy. A larger per-node reserve preserves average wood abundance.
				scatter_modulus = 29
				node_amount = 20
			if tile == Tile.ROCKY:
				scatter_modulus = 47
				node_amount = 18
			elif tile == Tile.CRYSTAL_GROUND:
				scatter_modulus = 31
				node_amount = 16
			elif tile == Tile.FERTILE:
				scatter_modulus = 21
			if not resource_id.is_empty() and scatter_hash % scatter_modulus == 0:
				blueprint.resource_nodes.append({"id": resource_id, "x": x, "y": y, "amount": node_amount, "variant": scatter_hash % 4})

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
