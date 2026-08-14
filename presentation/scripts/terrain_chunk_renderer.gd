class_name TerrainChunkRenderer
extends RefCounted

const TILE_PIXELS := 8
const MATERIAL_PIXELS := 6
const ACCENT_BLOCK_X := 13
const ACCENT_BLOCK_Y := 11
const MIN_CANOPY_COMPONENT_CELLS := 96

func render(payload: Dictionary) -> Dictionary:
	var origin := Vector2i(int(payload.get("origin_x", 0)), int(payload.get("origin_y", 0)))
	var size := Vector2i(int(payload.get("size_x", 32)), int(payload.get("size_y", 32)))
	var width := int(payload.get("world_width", 256))
	var height := int(payload.get("world_height", 256))
	var tiles: PackedByteArray = payload.get("tiles", PackedByteArray())
	var elevations: PackedByteArray = payload.get("elevations", PackedByteArray())
	var biome := StringName(payload.get("biome", "forest"))
	var season := StringName(payload.get("season", "Spring"))
	var seed := int(payload.get("seed", 1))
	# The simulation may retain tiny forest-floor pockets for resources and path
	# costs, but rendering each pocket as a crown creates the exact collection of
	# individual trees this art direction forbids. Only connected canopy masses
	# survive visually; small components dissolve into the surrounding meadow.
	tiles = _build_visual_material_map(tiles, width, height)
	# Six uniform material samples per cell describe the broad ownership field. Native
	# accents are applied after the nearest-neighbour expansion, retaining the
	# locked 8 px world grid while keeping asynchronous mobile generation bounded.
	var image := Image.create(size.x * MATERIAL_PIXELS, size.y * MATERIAL_PIXELS, false, Image.FORMAT_RGBA8)
	var native_scale := float(TILE_PIXELS) / float(MATERIAL_PIXELS)
	var material_origin := origin * MATERIAL_PIXELS
	# All low-frequency fields are generated in native code. Their offsets are in
	# the shared world-material coordinate system, so independently rendered chunks
	# sample the same infinite fields at their borders without normalizing per chunk.
	var warp_x_map := _make_noise_map(image.get_size(), material_origin, seed ^ 0x193a, native_scale / 104.0)
	var warp_y_map := _make_noise_map(image.get_size(), material_origin, seed ^ 0x27c1, native_scale / 111.0)
	var relief_map := _make_noise_map(image.get_size(), material_origin, seed ^ 0x24a7c15d, native_scale / 224.0)
	var patch_map := _make_noise_map(image.get_size(), material_origin, seed ^ 0x1f123bb5, native_scale / 88.0)
	var detail_map := _make_noise_map(image.get_size(), material_origin, seed ^ 0x68bc21eb, native_scale / 29.0)
	# A low-frequency cellular field gives the forest and bedrock broad, quiet
	# interlocking regions. Unlike circular sprite stamps, every region continues
	# through its neighbours and across chunk seams as one material mass.
	var structure_map := _make_cellular_noise_map(image.get_size(), material_origin, seed ^ 0x5d71c3, native_scale / 74.0)
	for py in image.get_height():
		var world_material_y := origin.y * MATERIAL_PIXELS + py
		var world_py := floori((float(world_material_y) + 0.5) * native_scale)
		for px in image.get_width():
			var world_material_x := origin.x * MATERIAL_PIXELS + px
			var world_px := floori((float(world_material_x) + 0.5) * native_scale)
			var warp_x := warp_x_map.get_pixel(px, py).r * 2.0 - 1.0
			var warp_y := warp_y_map.get_pixel(px, py).r * 2.0 - 1.0
			var relief := relief_map.get_pixel(px, py).r * 2.0 - 1.0
			var patch := patch_map.get_pixel(px, py).r * 2.0 - 1.0
			var detail := detail_map.get_pixel(px, py).r * 2.0 - 1.0
			var structure := structure_map.get_pixel(px, py).r * 2.0 - 1.0
			var ownership := _sample_ownership(tiles, width, height, world_px, world_py, warp_x, warp_y)
			var color := _material_pixel(
				int(ownership.best_tile), int(ownership.second_tile),
				float(ownership.best_weight), float(ownership.second_weight),
				biome, season, seed, world_px, world_py, relief, patch, detail, structure
			)
			var cell_elevation := _elevation_at(elevations, width, height, floori(float(world_px) / TILE_PIXELS), floori(float(world_py) / TILE_PIXELS), int(ownership.best_tile))
			if cell_elevation >= 3:
				color = color.lightened(0.055)
			elif cell_elevation == 2:
				color = color.lightened(0.025)
			image.set_pixel(px, py, color)
	image.resize(size.x * TILE_PIXELS, size.y * TILE_PIXELS, Image.INTERPOLATE_NEAREST)
	_apply_native_accents(image, tiles, width, height, biome, season, seed, origin)
	_apply_material_boundary_accents(image, tiles, width, height, biome, season, seed, origin, size)
	_apply_elevation_contours(image, tiles, elevations, width, height, biome, season, seed, origin, size)
	return {
		"image": image,
		"chunk_x": int(payload.get("chunk_x", 0)),
		"chunk_y": int(payload.get("chunk_y", 0)),
		"generation": int(payload.get("generation", 0)),
		"revision": int(payload.get("revision", 0)),
	}

func _build_visual_material_map(source: PackedByteArray, width: int, height: int) -> PackedByteArray:
	if source.size() != width * height:
		return source
	var result := source.duplicate()
	var visited := PackedByteArray()
	visited.resize(source.size())
	visited.fill(0)
	# Cardinal connectivity prevents a one-cell diagonal touch from making a
	# detached crown inherit the size of a distant forest mass.
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for start_index in source.size():
		if visited[start_index] != 0 or int(source[start_index]) != 2:
			continue
		var component := PackedInt32Array()
		var frontier := PackedInt32Array([start_index])
		visited[start_index] = 1
		var cursor := 0
		while cursor < frontier.size():
			var index := int(frontier[cursor])
			cursor += 1
			component.append(index)
			var x: int = index % width
			var y: int = index / width
			for direction in directions:
				var neighbor_x := x + direction.x
				var neighbor_y := y + direction.y
				if neighbor_x < 0 or neighbor_y < 0 or neighbor_x >= width or neighbor_y >= height:
					continue
				var neighbor_index := neighbor_y * width + neighbor_x
				if visited[neighbor_index] != 0 or int(source[neighbor_index]) != 2:
					continue
				visited[neighbor_index] = 1
				frontier.append(neighbor_index)
		if component.size() >= MIN_CANOPY_COMPONENT_CELLS:
			continue
		for index in component:
			result[int(index)] = 1
	return result

func _material_pixel(tile: int, second_tile: int, weight: float, second_weight: float, biome: StringName, season: StringName, seed: int, world_px: int, world_py: int, relief: float, patch: float, detail: float, structure: float) -> Color:
	var cell_x := floori(float(world_px) / float(TILE_PIXELS))
	var cell_y := floori(float(world_py) / float(TILE_PIXELS))
	var family := _family(tile)
	var base := _tile_color(tile, biome, season, seed, cell_x, cell_y)
	var outside := _tile_color(second_tile, biome, season, seed, cell_x, cell_y)
	var margin := weight - second_weight
	var micro := float(_hash_2d(world_px / 3, world_py / 3, seed ^ 0x43d9b51)) / 52364.0 - 1.0
	var material_field := relief * 0.68 + patch * 0.32
	# Ownership is smoothly warped across cell centers. The outer band borrows the
	# neighboring material before the inner highlight and body colors take over,
	# so terrain masses interlock instead of appearing as outlined decals.
	if family in [&"forest", &"rock", &"water", &"crystal", &"corruption"] and second_tile != tile:
		var outer := outside
		var inner := base.lerp(outside, 0.24)
		var body := base.lerp(outside, 0.08)
		match family:
			&"forest":
				var edge_shadow := _forest_ramp(season)[0]
				outer = outside.lerp(edge_shadow, 0.30)
				inner = outside.lerp(base, 0.45).lerp(edge_shadow, 0.14)
				body = base.lerp(outside, 0.17)
			&"rock":
				# A warm gravel/talus band separates exposed stone from living ground.
				# This avoids the pasted-on grey-island edge seen in the prior pass.
				var talus := Color("716b5d")
				outer = outside.lerp(talus, 0.28).darkened(0.025)
				inner = outside.lerp(base, 0.48).lerp(talus, 0.14).lightened(0.025)
				body = base.lerp(outside, 0.19)
			&"water":
				if season == &"Winter":
					outer = outside.lerp(Color("aebfbc"), 0.18).darkened(0.06)
					inner = Color("a8c5c8").lerp(outside, 0.22)
					body = base.lerp(outside, 0.11).lightened(0.055)
				else:
					outer = outside.darkened(0.10).lerp(base, 0.08)
					inner = base.lightened(0.14).lerp(outside, 0.20)
					body = base.lerp(outside, 0.08).lightened(0.04)
			&"crystal":
				outer = outside.darkened(0.06).lerp(base, 0.20)
				inner = base.lerp(outside, 0.27).lightened(0.075)
				body = base.lerp(outside, 0.11)
			&"corruption":
				outer = outside.darkened(0.14).lerp(base, 0.18)
				inner = base.lerp(outside, 0.30)
				body = base.lerp(outside, 0.12)
		if weight < 0.55 or margin < 0.075:
			base = outer
		elif weight < 0.73 or margin < 0.18:
			base = inner
		elif weight < 0.88:
			base = body
	elif family == &"ground" and second_tile != tile and margin < 0.20:
		var dither_threshold: float = [0.055, 0.14, 0.095, 0.025][posmod(world_px / 2 + world_py / 2 * 3, 4)]
		if margin < dither_threshold:
			base = outside
	match family:
		&"forest":
			if weight > 0.78:
				var ramp := _forest_ramp(season)
				# Cellular regions only bias the broad crown volume. Continuous fields and
				# a smooth ramp prevent those regions becoming flat colored islands.
				var canopy_value := clampf(structure * 0.18 + patch * 0.47 + relief * 0.27 + detail * 0.08, -1.0, 1.0)
				base = ramp[1].lerp(ramp[2], 0.28)
				if canopy_value > 0.0:
					base = base.lerp(ramp[2], minf(0.54, canopy_value * 0.72))
					if canopy_value > 0.52:
						base = base.lerp(ramp[3], (canopy_value - 0.52) * 0.44)
				else:
					base = base.lerp(ramp[0], minf(0.48, -canopy_value * 0.60))
				var directional_light := clampf(relief * 0.48 - detail * 0.14, -1.0, 1.0)
				if directional_light > 0.20:
					base = base.lightened(directional_light * 0.052)
				elif directional_light < -0.25:
					base = base.darkened(-directional_light * 0.058)
				if micro > 0.72:
					base = base.lerp(ramp[3], 0.10)
				elif micro < -0.74:
					base = base.lerp(ramp[0], 0.11)
		&"rock":
			if weight > 0.84:
				# Bedrock is made from broad shelves, not a repeated crack lattice. Sparse
				# fissures are added later as accents while this layer establishes large
				# planes that can carry moss and talus around their perimeter.
				var shelf_value := structure * 0.66 + relief * 0.27 + patch * 0.07
				if shelf_value > 0.42:
					base = base.lightened(0.105)
				elif shelf_value > 0.02:
					base = base.lightened(0.038)
				elif shelf_value < -0.44:
					base = base.darkened(0.115)
				else:
					base = base.darkened(0.032)
				if detail > 0.54:
					base = base.lightened(0.025)
				elif micro < -0.66:
					base = base.darkened(0.026)
		&"water":
			if weight > 0.82 and material_field < -0.24:
				base = base.darkened(0.085)
			elif weight > 0.82 and material_field > 0.38:
				base = base.lightened(0.045)
			var ripple_hash := _hash_2d(world_px / 23, world_py / 13, seed ^ 0x311a)
			var ripple_y := 3 + posmod(ripple_hash / 11, 7)
			var ripple_start := 2 + posmod(ripple_hash, 10)
			var ripple_length := 4 + posmod(ripple_hash / 7, 7)
			if ripple_hash % 4 != 0 and posmod(world_py, 13) == ripple_y and posmod(world_px, 23) >= ripple_start and posmod(world_px, 23) < ripple_start + ripple_length:
				base = base.lightened(0.24)
		&"crystal":
			if material_field > 0.30:
				base = base.lightened(0.11)
			elif material_field < -0.28:
				base = base.darkened(0.13)
			if _hash_2d(world_px, world_py, seed) % 97 == 0:
				base = Color("7edce0")
		&"corruption":
			if material_field > 0.35:
				base = Color("76115f")
			elif material_field < -0.38:
				base = Color("2b0625")
		&"ground":
			# Broad soil/moisture variation now supports the fine vegetation without
			# turning into circular noise islands or competing with buildings.
			if material_field > 0.28:
				base = base.lightened(0.045)
			elif material_field < -0.28:
				base = base.darkened(0.045)
			if micro > 0.48:
				base = base.lightened(0.028)
			elif micro < -0.50:
				base = base.darkened(0.026)
	return Color(base.r, base.g, base.b, 1.0)

func _sample_ownership(tiles: PackedByteArray, width: int, height: int, world_px: int, world_py: int, warp_x_value: float, warp_y_value: float) -> Dictionary:
	# Low-frequency domain warping keeps boundaries organic without changing which
	# simulation cells own the terrain at useful gameplay scale.
	var warp_x := warp_x_value * 0.18
	var warp_y := warp_y_value * 0.18
	var grid := Vector2((float(world_px) + 0.5) / float(TILE_PIXELS) - 0.5 + warp_x, (float(world_py) + 0.5) / float(TILE_PIXELS) - 0.5 + warp_y)
	var x0 := floori(grid.x)
	var y0 := floori(grid.y)
	var fx := grid.x - floorf(grid.x)
	var fy := grid.y - floorf(grid.y)
	var weights: Array[float] = []
	weights.resize(9)
	weights.fill(0.0)
	for dy in 2:
		for dx in 2:
			var sample_weight := (fx if dx == 1 else 1.0 - fx) * (fy if dy == 1 else 1.0 - fy)
			var sampled_tile := _tile_at(tiles, width, height, x0 + dx, y0 + dy)
			weights[sampled_tile] += sample_weight
	var best_tile := 0
	var second_tile := 0
	var best_weight := -1.0
	var second_weight := -1.0
	for tile_id in weights.size():
		var tile_weight: float = weights[tile_id]
		if tile_weight > best_weight:
			second_weight = best_weight
			second_tile = best_tile
			best_weight = tile_weight
			best_tile = tile_id
		elif tile_weight > second_weight:
			second_weight = tile_weight
			second_tile = tile_id
	return {"best_tile": best_tile, "second_tile": second_tile, "best_weight": best_weight, "second_weight": second_weight}

func _make_noise_map(size: Vector2i, material_origin: Vector2i, seed: int, frequency: float) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = posmod(seed, 2147483647)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	noise.frequency = frequency
	noise.offset = Vector3(float(material_origin.x), float(material_origin.y), 0.0)
	# Per-chunk normalization would make identical border coordinates disagree.
	# Raw noise is converted to grayscale consistently by Noise.get_image.
	return noise.get_image(size.x, size.y, false, false, false)

func _make_cellular_noise_map(size: Vector2i, material_origin: Vector2i, seed: int, frequency: float) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = posmod(seed, 2147483647)
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = frequency
	noise.cellular_jitter = 0.82
	noise.offset = Vector3(float(material_origin.x), float(material_origin.y), 0.0)
	return noise.get_image(size.x, size.y, false, false, false)

func _apply_native_accents(image: Image, tiles: PackedByteArray, width: int, height: int, biome: StringName, season: StringName, seed: int, chunk_origin: Vector2i) -> void:
	var native_origin := chunk_origin * TILE_PIXELS
	var native_end := native_origin + image.get_size()
	var first_block_x := floori(float(native_origin.x) / float(ACCENT_BLOCK_X)) * ACCENT_BLOCK_X - ACCENT_BLOCK_X
	var first_block_y := floori(float(native_origin.y) / float(ACCENT_BLOCK_Y)) * ACCENT_BLOCK_Y - ACCENT_BLOCK_Y
	for block_y in range(first_block_y, native_end.y + ACCENT_BLOCK_Y, ACCENT_BLOCK_Y):
		for block_x in range(first_block_x, native_end.x + ACCENT_BLOCK_X, ACCENT_BLOCK_X):
			var motif_hash := _hash_2d(block_x / ACCENT_BLOCK_X, block_y / ACCENT_BLOCK_Y, seed ^ 0x557d)
			var point := Vector2i(block_x + 1 + posmod(motif_hash, ACCENT_BLOCK_X - 2), block_y + 1 + posmod(motif_hash / 11, ACCENT_BLOCK_Y - 2))
			var cell := Vector2i(floori(float(point.x) / TILE_PIXELS), floori(float(point.y) / TILE_PIXELS))
			var tile := _tile_at(tiles, width, height, cell.x, cell.y)
			var family := _family(tile)
			var sample := _tile_color(tile, biome, season, seed, cell.x, cell.y)
			match family:
				&"ground":
					var neighboring: StringName = &""
					for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
						var neighbor_family := _family(_tile_at(tiles, width, height, cell.x + direction.x, cell.y + direction.y))
						if neighbor_family in [&"forest", &"rock", &"water", &"crystal"]:
							neighboring = neighbor_family
							break
					if neighboring == &"forest" and motif_hash % 3 != 1:
						var understory := sample.lerp(Color("285c2d"), 0.46)
						_paint_accent_cluster(image, native_origin, point, tiles, width, height, family, understory, [Vector2i(-3, 1), Vector2i(-2, 0), Vector2i.ZERO, Vector2i(2, 1), Vector2i(3, 0), Vector2i(0, -2)])
					elif neighboring == &"rock" and motif_hash % 3 != 0:
						var gravel := sample.lerp(Color("858177"), 0.58)
						_paint_accent_cluster(image, native_origin, point, tiles, width, height, family, gravel, [Vector2i(-3, 1), Vector2i(-2, 0), Vector2i.ZERO, Vector2i(2, 0), Vector2i(3, 1), Vector2i(0, -2)])
						if motif_hash % 5 == 1:
							_paint_accent_cluster(image, native_origin, point + Vector2i(2, -2), tiles, width, height, family, Color("4e6a42"), [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1)])
					elif neighboring == &"water" and motif_hash % 4 == 0:
						_paint_accent_cluster(image, native_origin, point, tiles, width, height, family, sample.darkened(0.08).lerp(Color("294c4b"), 0.10), [Vector2i(-2, 0), Vector2i.ZERO, Vector2i(2, 1)])
					elif motif_hash % 3 == 0:
						var grass_color := sample.darkened(0.13) if motif_hash % 2 == 0 else sample.lightened(0.10)
						var grass_shape: Array[Vector2i] = []
						if motif_hash % 4:
							grass_shape.append_array([Vector2i(0, -2), Vector2i.ZERO, Vector2i(-1, 1), Vector2i(1, 1)])
						else:
							grass_shape.append_array([Vector2i(-2, 0), Vector2i.ZERO, Vector2i(2, 1)])
						_paint_accent_cluster(image, native_origin, point, tiles, width, height, family, grass_color, grass_shape)
					if season == &"Spring" and motif_hash % 89 == 0:
						_paint_accent_cluster(image, native_origin, point + Vector2i(3, -2), tiles, width, height, family, Color("d8b94e") if motif_hash % 2 else Color("c96ca8"), [Vector2i.ZERO, Vector2i(1, 0)])
				&"forest":
					# Overlapping multi-tone patches describe crown volumes while the
					# continuous material below keeps them fused into one woodland mass.
					var foliage_cluster := _hash_2d(floori(float(block_x) / 41.0), floori(float(block_y) / 33.0), seed ^ 0x36e91)
					var foliage_density: int = int([5, 6, 7, 8][posmod(foliage_cluster, 4)])
					if motif_hash % 12 < foliage_density:
						_paint_foliage_patch(image, native_origin, point, tiles, width, height, _forest_ramp(season), motif_hash)
				&"rock":
					if motif_hash % 23 == 0:
						_paint_accent_cluster(image, native_origin, point, tiles, width, height, family, sample.darkened(0.22), [Vector2i(-3, -2), Vector2i(-2, -1), Vector2i(-1, -1), Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 1), Vector2i(2, 2)])
					elif motif_hash % 4 == 0:
						_paint_accent_cluster(image, native_origin, point, tiles, width, height, family, sample.lightened(0.14), [Vector2i(-4, 0), Vector2i(-3, 0), Vector2i(-2, 0), Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 1), Vector2i(3, 1)])
				&"water":
					if motif_hash % 7 == 0:
						_paint_accent_cluster(image, native_origin, point, tiles, width, height, family, sample.lightened(0.17), [Vector2i(-2, 0), Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0)])
				&"crystal":
					if motif_hash % 17 == 0:
						_paint_accent_cluster(image, native_origin, point, tiles, width, height, family, Color("74d1d5"), [Vector2i.ZERO, Vector2i(0, -1)])

func _paint_accent_cluster(image: Image, native_origin: Vector2i, point: Vector2i, tiles: PackedByteArray, width: int, height: int, family: StringName, color: Color, offsets: Array[Vector2i]) -> void:
	for offset in offsets:
		var target := point + offset
		var local := target - native_origin
		if local.x < 0 or local.y < 0 or local.x >= image.get_width() or local.y >= image.get_height():
			continue
		var target_cell := Vector2i(floori(float(target.x) / TILE_PIXELS), floori(float(target.y) / TILE_PIXELS))
		if _family(_tile_at(tiles, width, height, target_cell.x, target_cell.y)) == family:
			image.set_pixelv(local, color)

func _paint_foliage_patch(image: Image, native_origin: Vector2i, point: Vector2i, tiles: PackedByteArray, width: int, height: int, ramp: Array[Color], patch_hash: int) -> void:
	var radius_x := 6 + posmod(patch_hash / 7, 3)
	var radius_y := 5 + posmod(patch_hash / 17, 3)
	var highlight_center := Vector2(-0.30 + float(posmod(patch_hash / 19, 5)) * 0.045, -0.28 + float(posmod(patch_hash / 23, 5)) * 0.035)
	var shadow_center := Vector2(0.25 + float(posmod(patch_hash / 29, 5)) * 0.035, 0.24 + float(posmod(patch_hash / 37, 5)) * 0.045)
	for y in range(-radius_y, radius_y + 1):
		for x in range(-radius_x, radius_x + 1):
			var normalized := pow(float(x) / float(radius_x), 2.0) + pow(float(y) / float(radius_y), 2.0)
			var pixel_hash := _hash_2d(point.x + x, point.y + y, patch_hash ^ 0x2d17)
			if normalized > 1.0 + float(posmod(pixel_hash, 7) - 3) * 0.045 or pixel_hash % 19 == 0:
				continue
			var target := point + Vector2i(x, y)
			var local := target - native_origin
			if local.x < 0 or local.y < 0 or local.x >= image.get_width() or local.y >= image.get_height():
				continue
			var target_cell := Vector2i(floori(float(target.x) / TILE_PIXELS), floori(float(target.y) / TILE_PIXELS))
			if _family(_tile_at(tiles, width, height, target_cell.x, target_cell.y)) != &"forest":
				continue
			var normalized_point := Vector2(float(x) / float(radius_x), float(y) / float(radius_y))
			var highlight_distance := normalized_point.distance_squared_to(highlight_center)
			var shadow_distance := normalized_point.distance_squared_to(shadow_center)
			var color: Color
			if highlight_distance < 0.19 + float(posmod(pixel_hash, 3)) * 0.018 and pixel_hash % 4 != 0:
				color = ramp[2].lerp(ramp[3], 0.11 + float(posmod(patch_hash / 41, 4)) * 0.035)
			elif shadow_distance < 0.22 + float(posmod(pixel_hash, 3)) * 0.020 and pixel_hash % 3 != 0:
				color = ramp[1].lerp(ramp[0], 0.17 + float(posmod(patch_hash / 43, 4)) * 0.035)
			elif pixel_hash % 23 == 0:
				color = ramp[2].lightened(0.055)
			elif pixel_hash % 17 == 0:
				color = ramp[1].darkened(0.06)
			else:
				continue
			image.set_pixelv(local, color)

func _apply_material_boundary_accents(image: Image, tiles: PackedByteArray, width: int, height: int, biome: StringName, season: StringName, seed: int, chunk_origin: Vector2i, chunk_size: Vector2i) -> void:
	var native_origin := chunk_origin * TILE_PIXELS
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for y in range(chunk_origin.y, chunk_origin.y + chunk_size.y):
		for x in range(chunk_origin.x, chunk_origin.x + chunk_size.x):
			if _family(_tile_at(tiles, width, height, x, y)) != &"rock":
				continue
			for direction_index in directions.size():
				var direction := directions[direction_index]
				var neighbor_family := _family(_tile_at(tiles, width, height, x + direction.x, y + direction.y))
				if neighbor_family not in [&"ground", &"forest"]:
					continue
				var edge_hash := _hash_2d(x * 11 + direction.x * 3, y * 13 + direction.y * 5, seed ^ 0x4a19)
				var rock_center := Vector2i(x * TILE_PIXELS + TILE_PIXELS / 2, y * TILE_PIXELS + TILE_PIXELS / 2)
				var edge_point := rock_center + direction * (TILE_PIXELS / 2 - 1)
				var tangent := Vector2i(-direction.y, direction.x)
				if edge_hash % 3 != 0:
					var lip_point := edge_point - direction + tangent * (posmod(edge_hash / 7, 3) - 1)
					_paint_accent_cluster(image, native_origin, lip_point, tiles, width, height, &"rock", Color("556754") if neighbor_family == &"forest" else Color("70766a"), [tangent * -2, tangent * -1, Vector2i.ZERO, tangent, tangent * 2])
				if neighbor_family == &"ground" and edge_hash % 4 != 0:
					var talus_point := edge_point + direction * 3 + tangent * (posmod(edge_hash / 17, 5) - 2)
					var talus_color := _tile_color(_tile_at(tiles, width, height, x, y), biome, season, seed, x, y).lerp(Color("716451"), 0.36)
					_paint_accent_cluster(image, native_origin, talus_point, tiles, width, height, &"ground", talus_color, [tangent * -3, tangent * -1, Vector2i.ZERO, tangent + direction, tangent * 2, direction * 2])

func _apply_elevation_contours(image: Image, tiles: PackedByteArray, elevations: PackedByteArray, width: int, height: int, biome: StringName, season: StringName, seed: int, chunk_origin: Vector2i, chunk_size: Vector2i) -> void:
	if elevations.size() != width * height:
		return
	var native_origin := chunk_origin * TILE_PIXELS
	for y in range(chunk_origin.y, chunk_origin.y + chunk_size.y):
		for x in range(chunk_origin.x, chunk_origin.x + chunk_size.x):
			var cell := Vector2i(x, y)
			var tile := _tile_at(tiles, width, height, x, y)
			var elevation := _elevation_at(elevations, width, height, x, y, tile)
			if elevation <= 0 or _family(tile) == &"water":
				continue
			var base := _tile_color(tile, biome, season, seed, x, y)
			if elevation >= 3:
				base = base.lightened(0.055)
			elif elevation == 2:
				base = base.lightened(0.025)
			for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var neighbor: Vector2i = cell + direction
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= width or neighbor.y >= height:
					continue
				var neighbor_tile := _tile_at(tiles, width, height, neighbor.x, neighbor.y)
				if _family(neighbor_tile) == &"water":
					continue
				var neighbor_elevation := _elevation_at(elevations, width, height, neighbor.x, neighbor.y, neighbor_tile)
				if elevation <= neighbor_elevation:
					continue
				var height_difference := elevation - neighbor_elevation
				# Open soil uses only broad value bands. Explicit top-surface rims are
				# reserved for geology/crystal shelves (or a rare two-band drop), keeping
				# the logical-cell staircase invisible across meadows and forest canopy.
				if height_difference < 2 and _family(tile) not in [&"rock", &"crystal"] and _family(neighbor_tile) not in [&"rock", &"crystal"]:
					continue
				_paint_elevation_edge(image, native_origin, cell, direction, height_difference, base, seed)

func _paint_elevation_edge(image: Image, native_origin: Vector2i, cell: Vector2i, direction: Vector2i, height_difference: int, base: Color, seed: int) -> void:
	var cell_origin := cell * TILE_PIXELS
	var groove := base.darkened(0.17 if height_difference == 1 else 0.27)
	var lip := base.lightened(0.09 if height_difference == 1 else 0.15)
	var segment_hash := _hash_2d(cell.x * 17 + direction.x * 5, cell.y * 19 + direction.y * 7, seed ^ 0x61a7)
	if segment_hash % 5 == 0:
		return
	var segment_start := 1 + posmod(segment_hash / 11, 3)
	var segment_length := 2 + posmod(segment_hash / 37, 3)
	for edge_index in range(segment_start, mini(TILE_PIXELS - 1, segment_start + segment_length)):
		var edge_hash := _hash_2d(cell.x * 11 + direction.x * 3 + edge_index, cell.y * 13 + direction.y * 5, seed ^ 0x61a7)
		if edge_hash % 11 == 0:
			continue
		var edge_global: Vector2i
		var inner_global: Vector2i
		if direction == Vector2i.UP:
			edge_global = cell_origin + Vector2i(edge_index, 0)
			inner_global = edge_global + Vector2i.DOWN
		elif direction == Vector2i.DOWN:
			edge_global = cell_origin + Vector2i(edge_index, TILE_PIXELS - 1)
			inner_global = edge_global + Vector2i.UP
		elif direction == Vector2i.LEFT:
			edge_global = cell_origin + Vector2i(0, edge_index)
			inner_global = edge_global + Vector2i.RIGHT
		else:
			edge_global = cell_origin + Vector2i(TILE_PIXELS - 1, edge_index)
			inner_global = edge_global + Vector2i.LEFT
		var edge_local := edge_global - native_origin
		var inner_local := inner_global - native_origin
		if edge_local.x >= 0 and edge_local.y >= 0 and edge_local.x < image.get_width() and edge_local.y < image.get_height():
			image.set_pixelv(edge_local, groove)
		if edge_hash % 3 != 0 and inner_local.x >= 0 and inner_local.y >= 0 and inner_local.x < image.get_width() and inner_local.y < image.get_height():
			image.set_pixelv(inner_local, lip)

func _tile_color(tile: int, biome: StringName, season: StringName, seed: int, x: int, y: int) -> Color:
	var palette: Array = {
		&"forest": [Color("507b25"), Color("10451f"), Color("747772"), Color("258e91"), Color("799328"), Color("95703a"), Color("315c4a"), Color("075b82")],
		&"haven": [Color("37852e"), Color("22752d"), Color("8a8d83"), Color("36b9bc"), Color("a0ba2b"), Color("b59a4c"), Color("3b7160"), Color("0b6182")],
		&"desert": [Color("82792e"), Color("5f6424"), Color("7b6b54"), Color("21a1ad"), Color("849127"), Color("ad823f"), Color("506453"), Color("0b5670")],
		&"red_sands": [Color("65551f"), Color("484d1a"), Color("744a3e"), Color("249aa7"), Color("7e8c1e"), Color("963d20"), Color("4d5947"), Color("0b4d66")],
		&"marsh": [Color("2c5138"), Color("173f2c"), Color("565f59"), Color("2a888b"), Color("597f29"), Color("74653b"), Color("204a42"), Color("0b3d4b")],
		&"dry_lands": [Color("6c6629"), Color("4a521e"), Color("6e6452"), Color("238a9a"), Color("8a9424"), Color("966d30"), Color("485e4a"), Color("0c4a5e")],
		&"island": [Color("3a821f"), Color("196322"), Color("797f78"), Color("21a9bd"), Color("90ad20"), Color("b9a05a"), Color("326b5d"), Color("075c85")],
	}.get(biome, [Color("3d7a18"), Color("15591a"), Color("6b6e64"), Color("0c8da1"), Color("85a915"), Color("a17631"), Color("315c4a"), Color("07456b")])
	var result: Color
	match tile:
		0: result = palette[7]
		2: result = palette[1]
		3: result = palette[2]
		4: result = Color(palette[0]).lerp(Color(palette[3]), 0.22).darkened(0.14)
		6: result = palette[4]
		5: result = palette[5]
		7: result = palette[6]
		8: result = Color("470a3a")
		_: result = palette[0]
	if tile != 8:
		match season:
			&"Spring":
				if tile in [1, 2, 6, 7]: result = result.lerp(Color("55a13a"), 0.055)
			&"Summer":
				if tile in [1, 5, 6, 7]: result = result.lerp(Color("a17a31"), 0.18)
				elif tile == 2: result = result.lerp(Color("6f7227"), 0.08)
			&"Autumn":
				if tile in [1, 2, 6, 7]: result = result.lerp(Color("98542d"), 0.24)
			&"Winter":
				if tile == 0:
					result = result.lerp(Color("789ba2"), 0.38)
				else:
					var snow := _value_noise(Vector2(float(x), float(y)) / 17.0, seed ^ 0x51f15e)
					var snow_strength := 0.66 if snow > 0.12 else (0.42 if snow > -0.16 else 0.16)
					result = result.lerp(Color("c8d1cb"), snow_strength)
	return result

func _forest_ramp(season: StringName) -> Array[Color]:
	match season:
		&"Spring": return [Color("082f19"), Color("1f6929"), Color("4b9636"), Color("75b24a")]
		&"Summer": return [Color("0b2d19"), Color("205522"), Color("477c2b"), Color("72933d")]
		&"Autumn": return [Color("27391f"), Color("75522a"), Color("a86d2f"), Color("c18a3c")]
		&"Winter": return [Color("244737"), Color("6d8975"), Color("aebcae"), Color("d2d9d1")]
		_: return [Color("072d17"), Color("1d6225"), Color("428d31"), Color("6aae42")]

func _tile_at(tiles: PackedByteArray, width: int, height: int, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height or tiles.size() != width * height:
		return 0
	return int(tiles[y * width + x])

func _elevation_at(elevations: PackedByteArray, width: int, height: int, x: int, y: int, tile: int = 1) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return 0
	if elevations.size() != width * height:
		return 0 if tile == 0 else (2 if tile == 3 else 1)
	return int(elevations[y * width + x])

func _family(tile: int) -> StringName:
	match tile:
		2: return &"forest"
		3: return &"rock"
		0: return &"water"
		4: return &"crystal"
		8: return &"corruption"
		1, 5, 6, 7: return &"ground"
		_: return &"void"

func _hash_2d(x: int, y: int, seed: int) -> int:
	# Squared coordinates produce visible concentric rings once interpolated. Mix
	# signed linear coordinates first, then avalanche their bits so value-noise
	# fields remain deterministic without betraying the underlying equation.
	var value := posmod(x * 374761393 + y * 668265263 + seed * 144269, 2147483647)
	value = (value ^ (value >> 13)) * 1274126177
	return posmod(value ^ (value >> 16), 104729)

func _value_noise(point: Vector2, seed: int) -> float:
	var cell := Vector2i(floori(point.x), floori(point.y))
	var local := Vector2(point.x - floorf(point.x), point.y - floorf(point.y))
	local = Vector2(local.x * local.x * (3.0 - 2.0 * local.x), local.y * local.y * (3.0 - 2.0 * local.y))
	var a := float(_hash_2d(cell.x, cell.y, seed)) / 104728.0
	var b := float(_hash_2d(cell.x + 1, cell.y, seed)) / 104728.0
	var c := float(_hash_2d(cell.x, cell.y + 1, seed)) / 104728.0
	var d := float(_hash_2d(cell.x + 1, cell.y + 1, seed)) / 104728.0
	return lerpf(lerpf(a, b, local.x), lerpf(c, d, local.x), local.y) * 2.0 - 1.0
