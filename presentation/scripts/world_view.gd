class_name WorldView
extends Node2D

signal placement_changed(building_id: StringName)
signal placement_rejected(reason: String)
signal entity_selected(kind: StringName, entity_id: int)
signal spell_changed(spell_id: StringName)

const TILE_PIXELS := 8.0
const MIN_ZOOM := 0.32
const MAX_ZOOM := 2.4
const SPELL_PIXEL_COLORS := {
	&"grab": Color("f0d17b"), &"divine_blessing": Color("f4e48b"), &"harvest": Color("9bc34a"),
	&"healing_aura": Color("62dda4"), &"holy_potatoes": Color("d6c254"), &"holy_wood": Color("70b55e"),
	&"mend": Color("69c8b5"), &"motivate_land": Color("8dc458"), &"regenerate": Color("6fe4a9"),
	&"resurrect": Color("b695df"), &"charm": Color("e58ab9"), &"god_tower": Color("e5d778"),
	&"god_wall": Color("d8cc81"), &"summon_holy_golem": Color("f4eab5"), &"banish": Color("a983df"),
	&"cold_aura": Color("70cfe6"), &"earthquake": Color("b68b5a"), &"flame": Color("ed6b2e"),
	&"lightning_bolt": Color("f0e75a"), &"magic_bolts": Color("8d77e9"), &"meteor": Color("e75531"),
	&"comet": Color("63c5e2"), &"conjure_essence": Color("7dd7df"), &"conjure_material": Color("d1ad67"),
	&"construct": Color("dfb760"), &"dispel_god_structure": Color("9f91b9"), &"dispel_golem": Color("9386ad"),
	&"dissolve": Color("b26bba"), &"illuminate": Color("f5e98a"), &"recall": Color("7ebad8"),
	&"storm": Color("6c93bb"), &"summon_labor_golem": Color("dfb96c"),
}
const EVENT_PIXEL_COLORS := {
	&"nomads": Color("d3ad63"), &"full_moon": Color("a9c9de"), &"blood_moon": Color("c44646"),
	&"eclipse": Color("5b5873"), &"meteor_shower": Color("e96a3d"), &"lightning_storm": Color("eee57b"),
	&"hail": Color("b8dce8"), &"earthquake": Color("aa8056"), &"blight": Color("81964b"),
	&"comet": Color("62cddd"), &"rain": Color("599dc3"), &"snow": Color("e0edf1"),
}
const WORLD_OBJECT_PIXEL_COLORS := {
	&"tree": Color("2f7138"), &"stump": Color("79502f"), &"dead_tree": Color("65543d"),
	&"rock": Color("858a87"), &"iron_rock": Color("9b8172"), &"gold_rock": Color("c49c42"),
	&"crystal": Color("43c8d2"), &"crop": Color("8eb64c"), &"wild_food": Color("c8b64a"),
	&"mushroom": Color("d6c3a1"), &"flower": Color("d882b1"), &"hole": Color("3d291c"),
	&"shallow_water": Color("3b94b8"), &"deep_water": Color("1b5f87"), &"fire": Color("ed6a2c"),
	&"ash": Color("5d5b59"), &"rubble": Color("79756e"), &"corruption": Color("782660"),
	&"corpse": Color("8e7a62"), &"loot_marker": Color("d4b34e"),
}

var terrain_sprite: Sprite2D
var camera: Camera2D
var pending_building_id: StringName = &""
var pending_spell_id: StringName = &""
var pointer_cell := Vector2i.ZERO
var dragging := false
var drag_distance := 0.0
var touch_points: Dictionary = {}
var last_pinch_distance := 0.0
var latest_snapshot: SimulationSnapshot
var current_blueprint: RegionBlueprint
var terrain_season: StringName = &"Spring"
var season_pattern_noise := FastNoiseLite.new()
var selected_kind: StringName = &""
var selected_entity_id := 0
var brush_cells_this_gesture: Dictionary = {}
var visual_effects: Array[Dictionary] = []

func _ready() -> void:
	terrain_sprite = Sprite2D.new()
	terrain_sprite.centered = false
	terrain_sprite.z_index = -100
	terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terrain_sprite.scale = Vector2.ONE
	add_child(terrain_sprite)
	camera = Camera2D.new()
	camera.enabled = false
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	add_child(camera)
	SimulationHost.region_started.connect(_on_region_started)
	SimulationHost.snapshot_updated.connect(_on_snapshot_updated)
	SimulationHost.sim_event.connect(_on_sim_event)
	set_process_unhandled_input(true)

func _on_region_started(blueprint: RegionBlueprint) -> void:
	current_blueprint = blueprint
	terrain_season = &"Spring"
	season_pattern_noise.seed = blueprint.seed ^ 0x51f15e
	season_pattern_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	season_pattern_noise.frequency = 0.032
	camera.enabled = true
	terrain_sprite.texture = _create_terrain_texture(blueprint, terrain_season)
	camera.position = Vector2(blueprint.starting_cell) * TILE_PIXELS
	camera.zoom = Vector2(0.78, 0.78)
	pending_building_id = &"camp"
	pointer_cell = blueprint.starting_cell - Vector2i(6, 6)
	placement_changed.emit(pending_building_id)
	queue_redraw()

func _on_snapshot_updated(snapshot: SimulationSnapshot) -> void:
	latest_snapshot = snapshot
	if current_blueprint != null and snapshot.season != terrain_season:
		terrain_season = snapshot.season
		terrain_sprite.texture = _create_terrain_texture(current_blueprint, terrain_season)
	queue_redraw()

func _on_sim_event(event: SimEvent) -> void:
	if event.type == &"command_rejected":
		placement_rejected.emit(String(event.data.get("reason", "Action rejected")))
	if event.type == &"building_placed":
		if pending_building_id == &"camp":
			pending_building_id = &""
			placement_changed.emit(pending_building_id)
	queue_redraw()

func begin_placement(building_id: StringName) -> void:
	pending_spell_id = &""
	spell_changed.emit(pending_spell_id)
	pending_building_id = building_id
	placement_changed.emit(building_id)
	queue_redraw()

func cancel_placement() -> void:
	pending_building_id = &""
	pending_spell_id = &""
	placement_changed.emit(pending_building_id)
	spell_changed.emit(pending_spell_id)
	queue_redraw()

func begin_spell(spell_id: StringName) -> void:
	pending_building_id = &""
	placement_changed.emit(pending_building_id)
	pending_spell_id = spell_id
	spell_changed.emit(spell_id)
	queue_redraw()

func add_spell_effect(spell_id: StringName, cell: Vector2i, radius: float) -> void:
	visual_effects.append({
		"spell_id": String(spell_id), "cell_x": cell.x, "cell_y": cell.y,
		"radius": radius, "started_tick": SimulationHost.tick, "end_tick": SimulationHost.tick + 26,
	})
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or current_blueprint == null:
		return
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMagnifyGesture:
		_zoom_at(event.position, event.factor)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_zoom_at(event.position, 1.12)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_zoom_at(event.position, 0.89)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_placement()
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		pointer_cell = _screen_to_cell(event.position)
		if event.pressed:
			dragging = true
			drag_distance = 0.0
			brush_cells_this_gesture.clear()
		else:
			dragging = false
			if drag_distance < 12.0:
				if not pending_building_id.is_empty():
					_attempt_placement(pointer_cell)
				elif not pending_spell_id.is_empty():
					_attempt_spell(pointer_cell)
				else:
					_select_at_cell(pointer_cell)
		get_viewport().set_input_as_handled()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	pointer_cell = _screen_to_cell(event.position)
	if dragging:
		drag_distance += event.relative.length()
		if _is_brush_placement():
			_attempt_brush_placement(pointer_cell)
		elif pending_building_id.is_empty():
			camera.position -= event.relative / camera.zoom.x
	queue_redraw()

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if touch_points.is_empty():
			brush_cells_this_gesture.clear()
		touch_points[event.index] = {"position": event.position, "start": event.position, "travel": 0.0}
	else:
		var touch: Dictionary = touch_points.get(event.index, {})
		if touch_points.size() == 1 and float(touch.get("travel", 0.0)) < 18.0:
			if not pending_building_id.is_empty():
				_attempt_placement(_screen_to_cell(event.position))
			elif not pending_spell_id.is_empty():
				_attempt_spell(_screen_to_cell(event.position))
			else:
				_select_at_cell(_screen_to_cell(event.position))
		touch_points.erase(event.index)
		last_pinch_distance = 0.0
	get_viewport().set_input_as_handled()

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not touch_points.has(event.index):
		return
	touch_points[event.index].position = event.position
	touch_points[event.index].travel = float(touch_points[event.index].travel) + event.relative.length()
	pointer_cell = _screen_to_cell(event.position)
	if touch_points.size() == 1:
		if _is_brush_placement():
			_attempt_brush_placement(pointer_cell)
		elif pending_building_id.is_empty():
			camera.position -= event.relative / camera.zoom.x
	elif touch_points.size() >= 2:
		var positions: Array = []
		for value in touch_points.values():
			positions.append(value.position)
		var distance: float = Vector2(positions[0]).distance_to(Vector2(positions[1]))
		if last_pinch_distance > 0.0:
			_zoom_at((Vector2(positions[0]) + Vector2(positions[1])) * 0.5, distance / last_pinch_distance)
		last_pinch_distance = distance
	queue_redraw()
	get_viewport().set_input_as_handled()

func _zoom_at(screen_position: Vector2, factor: float) -> void:
	var before := _screen_to_world(screen_position)
	var next_zoom := clampf(camera.zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(next_zoom, next_zoom)
	var after := _screen_to_world(screen_position)
	camera.position += before - after

func _screen_to_world(screen_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_position

func _screen_to_cell(screen_position: Vector2) -> Vector2i:
	return Vector2i(floor(_screen_to_world(screen_position).x / TILE_PIXELS), floor(_screen_to_world(screen_position).y / TILE_PIXELS))

func _attempt_placement(cell: Vector2i) -> void:
	if pending_building_id.is_empty():
		return
	var definition := ContentRegistry.get_by_id(&"buildings", pending_building_id)
	var footprint_data: Array = definition.get("footprint", [1, 1])
	var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
	if not _is_valid_placement(cell, footprint):
		AudioDirector.play_cue(&"invalid_action")
		placement_rejected.emit("That building cannot be placed there.")
		return
	SimulationHost.submit(GameCommand.place_building(SimulationHost.tick, pending_building_id, cell))

func _is_brush_placement() -> bool:
	if pending_building_id.is_empty():
		return false
	var definition := ContentRegistry.get_by_id(&"buildings", pending_building_id)
	return String(definition.get("category", "")) in ["roads", "walls"]

func _attempt_brush_placement(cell: Vector2i) -> void:
	var key := "%d:%d" % [cell.x, cell.y]
	if brush_cells_this_gesture.has(key):
		return
	var definition := ContentRegistry.get_by_id(&"buildings", pending_building_id)
	var footprint_data: Array = definition.get("footprint", [1, 1])
	var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
	if not _is_valid_placement(cell, footprint):
		return
	brush_cells_this_gesture[key] = true
	_attempt_placement(cell)

func _attempt_spell(cell: Vector2i) -> void:
	if pending_spell_id.is_empty():
		return
	SimulationHost.submit(GameCommand.cast_spell(SimulationHost.tick, pending_spell_id, cell))

func _select_at_cell(cell: Vector2i) -> void:
	if not latest_snapshot:
		return
	for index in range(latest_snapshot.buildings.size() - 1, -1, -1):
		var building: Dictionary = latest_snapshot.buildings[index]
		if Rect2i(Vector2i(building.x, building.y), Vector2i(building.width, building.height)).has_point(cell):
			selected_kind = &"building"
			selected_entity_id = int(building.id)
			entity_selected.emit(selected_kind, selected_entity_id)
			queue_redraw()
			return
	for villager in latest_snapshot.villagers:
		if Vector2(float(villager.x), float(villager.y)).distance_to(Vector2(cell) + Vector2(0.5, 0.5)) <= 1.35:
			selected_kind = &"villager"
			selected_entity_id = int(villager.id)
			entity_selected.emit(selected_kind, selected_entity_id)
			queue_redraw()
			return
	for golem in latest_snapshot.golems:
		if Vector2(float(golem.x), float(golem.y)).distance_to(Vector2(cell) + Vector2(0.5, 0.5)) <= 1.6:
			selected_kind = &"golem"
			selected_entity_id = int(golem.id)
			entity_selected.emit(selected_kind, selected_entity_id)
			queue_redraw()
			return
	for animal in latest_snapshot.animals:
		if Vector2(float(animal.x), float(animal.y)).distance_to(Vector2(cell) + Vector2(0.5, 0.5)) <= 1.5:
			selected_kind = &"animal"
			selected_entity_id = int(animal.id)
			entity_selected.emit(selected_kind, selected_entity_id)
			queue_redraw()
			return
	for monster in latest_snapshot.monsters:
		if Vector2(float(monster.x), float(monster.y)).distance_to(Vector2(cell) + Vector2(0.5, 0.5)) <= 1.6:
			selected_kind = &"monster"
			selected_entity_id = int(monster.id)
			entity_selected.emit(selected_kind, selected_entity_id)
			queue_redraw()
			return
	clear_selection()

func clear_selection() -> void:
	selected_kind = &""
	selected_entity_id = 0
	entity_selected.emit(selected_kind, selected_entity_id)
	queue_redraw()

func _is_valid_placement(cell: Vector2i, footprint: Vector2i) -> bool:
	if current_blueprint == null or not current_blueprint.is_buildable(cell, footprint):
		return false
	if latest_snapshot:
		var rect := Rect2i(cell, footprint)
		for building in latest_snapshot.buildings:
			if rect.intersects(Rect2i(Vector2i(building.x, building.y), Vector2i(building.width, building.height))):
				return false
	return true

func _create_terrain_texture(blueprint: RegionBlueprint, season: StringName = &"Spring") -> ImageTexture:
	var image := Image.create(blueprint.width * int(TILE_PIXELS), blueprint.height * int(TILE_PIXELS), false, Image.FORMAT_RGBA8)
	for y in blueprint.height:
		for x in blueprint.width:
			var tile := blueprint.tiles[y * blueprint.width + x]
			_paint_terrain_cell(image, blueprint, x, y, tile, season)
	# Edge bands are a second pass so connected terrain reads as a continuous
	# material mass rather than a collection of independently decorated cells.
	for y in blueprint.height:
		for x in blueprint.width:
			var tile := blueprint.tiles[y * blueprint.width + x]
			_paint_terrain_edges(image, blueprint, x, y, tile, season)
	return ImageTexture.create_from_image(image)

func _paint_terrain_cell(image: Image, blueprint: RegionBlueprint, x: int, y: int, tile: int, season: StringName = &"Spring") -> void:
	var cell_pixels := int(TILE_PIXELS)
	var origin := Vector2i(x * cell_pixels, y * cell_pixels)
	var base := _tile_color(tile, blueprint.biome_id, x, y, season)
	var family := _terrain_family(tile)
	if family in [&"forest", &"rock", &"water"]:
		var material_depth := _connected_material_depth(blueprint, x, y, family, 3)
		match family:
			&"forest":
				base = base.lightened(0.10) if material_depth == 1 else (base.darkened(0.08) if material_depth >= 3 else base)
			&"rock":
				base = base.darkened(0.07) if material_depth == 1 else (base.lightened(0.11) if material_depth == 2 else base.darkened(0.03))
			&"water":
				base = base.lightened(0.15) if material_depth == 1 else (base.darkened(0.10) if material_depth >= 3 else base)
	image.fill_rect(Rect2i(origin, Vector2i(cell_pixels, cell_pixels)), base)
	var seed := posmod(x * 92821 + y * 68917 + tile * 31337, 104729)
	var decor_seed := posmod(seed + x * x * 3301 + y * y * 2213 + x * y * 997, 104729)
	var dark := base.darkened(0.13)
	var light := base.lightened(0.10)
	# Fine material texture uses world-pixel coordinates. It therefore continues
	# across hidden logical cells and cannot expose the simulation grid.
	for py in cell_pixels:
		for px in cell_pixels:
			var global_x := origin.x + px
			var global_y := origin.y + py
			var pixel_seed := posmod(global_x * 1103515245 + global_y * 12345 + global_x * global_y * 97 + tile * 7919, 104729)
			match family:
				&"forest":
					if pixel_seed % 17 == 0:
						image.set_pixelv(origin + Vector2i(px, py), dark)
					elif pixel_seed % 31 == 0:
						image.set_pixelv(origin + Vector2i(px, py), light)
				&"rock":
					if posmod(global_x + global_y * 3, 19) == 0 and pixel_seed % 5 < 2:
						image.set_pixelv(origin + Vector2i(px, py), light)
					elif pixel_seed % 53 == 0:
						image.set_pixelv(origin + Vector2i(px, py), dark)
				&"water":
					if posmod(global_y, 6) == 0 and pixel_seed % 23 == 0:
						image.set_pixelv(origin + Vector2i(px, py), light)
				&"ground":
					if pixel_seed % 89 == 0:
						image.set_pixelv(origin + Vector2i(px, py), dark)
				&"crystal":
					if pixel_seed % 47 == 0:
						image.set_pixelv(origin + Vector2i(px, py), light)
	match tile:
		RegionGenerator.Tile.DEEP_WATER:
			if decor_seed % 5 == 0:
				var ripple_y := 2 + posmod(decor_seed, 4)
				var ripple_x := posmod(decor_seed / 7, 3)
				image.fill_rect(Rect2i(origin + Vector2i(ripple_x, ripple_y), Vector2i(4, 1)), light)
		RegionGenerator.Tile.ROCKY:
			if decor_seed % 11 == 0:
				var boulder := origin + Vector2i(1 + decor_seed % 4, 1 + posmod(decor_seed / 11, 4))
				image.fill_rect(Rect2i(boulder, Vector2i(3, 3)), dark)
				image.set_pixelv(boulder + Vector2i(1, 0), light)
		RegionGenerator.Tile.CRYSTAL_GROUND:
			if decor_seed % 4 == 0:
				var crystal_x := 1 + decor_seed % 5
				var crystal_y := 2 + posmod(decor_seed / 7, 3)
				image.fill_rect(Rect2i(origin + Vector2i(crystal_x, crystal_y), Vector2i(2, 4)), light)
				image.set_pixelv(origin + Vector2i(crystal_x + 1, crystal_y), Color("b8fff1"))
		RegionGenerator.Tile.SAND:
			if decor_seed % 5 == 0:
				image.fill_rect(Rect2i(origin + Vector2i(1 + decor_seed % 4, 2 + posmod(decor_seed / 5, 4)), Vector2i(3, 1)), dark)
		RegionGenerator.Tile.MARSH:
			if decor_seed % 4 == 0:
				image.fill_rect(Rect2i(origin + Vector2i(1 + decor_seed % 3, 5), Vector2i(4, 1)), dark)
			if decor_seed % 9 == 0:
				image.fill_rect(Rect2i(origin + Vector2i(5, 2), Vector2i(1, 3)), light)
		RegionGenerator.Tile.CORRUPTION:
			if decor_seed % 3 == 0:
				image.fill_rect(Rect2i(origin + Vector2i(1, 3), Vector2i(5, 2)), Color("6c145b"))
		_:
			if family == &"ground" and decor_seed % 13 == 0:
				var tuft_x := 1 + posmod(decor_seed, 5)
				var tuft_y := 2 + posmod(decor_seed / 11, 4)
				image.fill_rect(Rect2i(origin + Vector2i(tuft_x, tuft_y), Vector2i(1, 3)), dark)
				image.set_pixelv(origin + Vector2i(tuft_x - 1, tuft_y + 1), dark)
				image.set_pixelv(origin + Vector2i(tuft_x + 1, tuft_y + 1), dark)
	if season == &"Spring" and tile in [RegionGenerator.Tile.GRASS, RegionGenerator.Tile.FOREST_FLOOR, RegionGenerator.Tile.FERTILE] and decor_seed % 37 == 0:
		image.set_pixelv(origin + Vector2i(1 + decor_seed % 6, 1 + posmod(decor_seed / 9, 6)), Color("e6ca55") if decor_seed % 2 else Color("d775b2"))
	elif season == &"Autumn" and tile in [RegionGenerator.Tile.GRASS, RegionGenerator.Tile.FOREST_FLOOR, RegionGenerator.Tile.FERTILE] and decor_seed % 23 == 0:
		image.set_pixelv(origin + Vector2i(1 + decor_seed % 6, 1 + posmod(decor_seed / 7, 6)), Color("b8682f"))
	elif season == &"Winter" and tile not in [RegionGenerator.Tile.DEEP_WATER, RegionGenerator.Tile.CORRUPTION] and decor_seed % 13 == 0:
		image.fill_rect(Rect2i(origin + Vector2i(1 + decor_seed % 5, 1 + posmod(decor_seed / 11, 6)), Vector2i(2, 1)), Color("e7ece5"))

func _paint_terrain_edges(image: Image, blueprint: RegionBlueprint, x: int, y: int, tile: int, season: StringName) -> void:
	var family := _terrain_family(tile)
	var cell_pixels := int(TILE_PIXELS)
	var origin := Vector2i(x * cell_pixels, y * cell_pixels)
	var neighbors := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for side in 4:
		var neighbor_cell: Vector2i = Vector2i(x, y) + Vector2i(neighbors[side])
		var neighbor_tile := -1
		if neighbor_cell.x >= 0 and neighbor_cell.y >= 0 and neighbor_cell.x < blueprint.width and neighbor_cell.y < blueprint.height:
			neighbor_tile = blueprint.get_tile(neighbor_cell)
		var neighbor_family := _terrain_family(neighbor_tile)
		if family in [&"forest", &"rock", &"water", &"crystal", &"corruption"] and neighbor_family != family:
			var outside := Color("090d10") if neighbor_tile < 0 else _tile_color(neighbor_tile, blueprint.biome_id, neighbor_cell.x, neighbor_cell.y, season)
			_paint_connected_material_side(image, origin, side, family, tile, outside, x, y, blueprint.biome_id, season)
		elif family == &"ground" and neighbor_family == &"ground" and neighbor_tile != tile:
			var neighbor_color := _tile_color(neighbor_tile, blueprint.biome_id, neighbor_cell.x, neighbor_cell.y, season)
			_paint_ground_blend_side(image, origin, side, neighbor_color, x, y)
	# A missing diagonal enclosed by two connected cardinals is a concave notch,
	# not a square corner. Small corner cuts make joined masses mesh naturally.
	if family in [&"forest", &"rock", &"water"]:
		var corner_specs := [
			[Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)],
			[Vector2i(1, -1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(cell_pixels - 1, 0)],
			[Vector2i(1, 1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(cell_pixels - 1, cell_pixels - 1)],
			[Vector2i(-1, 1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, cell_pixels - 1)],
		]
		for spec in corner_specs:
			var diagonal: Vector2i = Vector2i(x, y) + Vector2i(spec[0])
			var cardinal_a: Vector2i = Vector2i(x, y) + Vector2i(spec[1])
			var cardinal_b: Vector2i = Vector2i(x, y) + Vector2i(spec[2])
			if _cell_family(blueprint, cardinal_a) == family and _cell_family(blueprint, cardinal_b) == family and _cell_family(blueprint, diagonal) != family:
				var corner: Vector2i = origin + Vector2i(spec[3])
				image.set_pixelv(corner, _edge_colors(tile, blueprint.biome_id, x, y, season)[0])

func _paint_connected_material_side(image: Image, origin: Vector2i, side: int, family: StringName, tile: int, outside: Color, x: int, y: int, biome: StringName, season: StringName) -> void:
	var profiles := [
		[2, 1, 1, 0, 0, 1, 1, 2], [1, 1, 0, 0, 1, 2, 2, 1],
		[2, 2, 1, 0, 1, 1, 0, 1], [0, 1, 2, 2, 1, 0, 1, 2],
	]
	var variant := posmod(x * 17 + y * 31 + side * 7 + String(family).hash(), profiles.size())
	var profile: Array = profiles[variant]
	var colors := _edge_colors(tile, biome, x, y, season)
	var outer: Color = colors[0]
	var inner: Color = colors[1]
	var middle: Color = colors[2]
	for along in int(TILE_PIXELS):
		var cut: int = int(profile[along])
		if side in [1, 2]:
			cut = int(profile[int(TILE_PIXELS) - 1 - along])
		for depth in mini(int(TILE_PIXELS), cut + 3):
			var color := outside if depth < cut else (outer if depth == cut else (inner if depth == cut + 1 else middle))
			image.set_pixelv(origin + _side_pixel(side, along, depth), color)

func _paint_ground_blend_side(image: Image, origin: Vector2i, side: int, neighbor_color: Color, x: int, y: int) -> void:
	for along in int(TILE_PIXELS):
		var seed := posmod(x * 97 + y * 193 + side * 43 + along * along * 17, 101)
		if seed % 3 != 0:
			image.set_pixelv(origin + _side_pixel(side, along, 0), neighbor_color)
		if seed % 11 == 0:
			image.set_pixelv(origin + _side_pixel(side, along, 1), neighbor_color.darkened(0.05))

func _side_pixel(side: int, along: int, depth: int) -> Vector2i:
	var last := int(TILE_PIXELS) - 1
	match side:
		0: return Vector2i(along, depth)
		1: return Vector2i(last - depth, along)
		2: return Vector2i(along, last - depth)
		_: return Vector2i(depth, along)

func _terrain_family(tile: int) -> StringName:
	match tile:
		RegionGenerator.Tile.FOREST_FLOOR: return &"forest"
		RegionGenerator.Tile.ROCKY: return &"rock"
		RegionGenerator.Tile.DEEP_WATER: return &"water"
		RegionGenerator.Tile.CRYSTAL_GROUND: return &"crystal"
		RegionGenerator.Tile.CORRUPTION: return &"corruption"
		RegionGenerator.Tile.GRASS, RegionGenerator.Tile.FERTILE, RegionGenerator.Tile.SAND, RegionGenerator.Tile.MARSH: return &"ground"
		_: return &"void"

func _cell_family(blueprint: RegionBlueprint, cell: Vector2i) -> StringName:
	if cell.x < 0 or cell.y < 0 or cell.x >= blueprint.width or cell.y >= blueprint.height:
		return &"void"
	return _terrain_family(blueprint.get_tile(cell))

func _connected_material_depth(blueprint: RegionBlueprint, x: int, y: int, family: StringName, maximum: int) -> int:
	for radius in range(1, maximum + 1):
		for offset in range(-radius, radius + 1):
			if _cell_family(blueprint, Vector2i(x + offset, y - radius)) != family or _cell_family(blueprint, Vector2i(x + offset, y + radius)) != family:
				return radius
		for offset in range(-radius + 1, radius):
			if _cell_family(blueprint, Vector2i(x - radius, y + offset)) != family or _cell_family(blueprint, Vector2i(x + radius, y + offset)) != family:
				return radius
	return maximum + 1

func _edge_colors(tile: int, biome: StringName, x: int, y: int, season: StringName) -> Array[Color]:
	var base := _tile_color(tile, biome, x, y, season)
	match _terrain_family(tile):
		&"forest": return [base.darkened(0.62), base.lightened(0.24), base.darkened(0.08)]
		&"rock": return [base.darkened(0.48), base.lightened(0.24), base.darkened(0.08)]
		&"water": return [base.darkened(0.38), base.lightened(0.34), base.lightened(0.12)]
		&"crystal": return [base.darkened(0.44), base.lightened(0.30), base.darkened(0.06)]
		&"corruption": return [Color("24051f"), Color("9b2f7e"), Color("5c104a")]
		_: return [base.darkened(0.30), base.lightened(0.15), base]

func _tile_color(tile: int, biome: StringName, x: int, y: int, season: StringName = &"") -> Color:
	var palette: Array = {
		&"forest": [Color("3d7a18"), Color("15591a"), Color("6b6e64"), Color("0c8da1"), Color("85a915"), Color("a17631"), Color("315c4a"), Color("07456b")],
		&"haven": [Color("37852e"), Color("22752d"), Color("8a8d83"), Color("36b9bc"), Color("a0ba2b"), Color("b59a4c"), Color("3b7160"), Color("0b6182")],
		&"desert": [Color("82792e"), Color("5f6424"), Color("7b6b54"), Color("21a1ad"), Color("849127"), Color("ad823f"), Color("506453"), Color("0b5670")],
		&"red_sands": [Color("65551f"), Color("484d1a"), Color("744a3e"), Color("249aa7"), Color("7e8c1e"), Color("963d20"), Color("4d5947"), Color("0b4d66")],
		&"marsh": [Color("2c5138"), Color("173f2c"), Color("565f59"), Color("2a888b"), Color("597f29"), Color("74653b"), Color("204a42"), Color("0b3d4b")],
		&"dry_lands": [Color("6c6629"), Color("4a521e"), Color("6e6452"), Color("238a9a"), Color("8a9424"), Color("966d30"), Color("485e4a"), Color("0c4a5e")],
		&"island": [Color("3a821f"), Color("196322"), Color("797f78"), Color("21a9bd"), Color("90ad20"), Color("b9a05a"), Color("326b5d"), Color("075c85")],
	}.get(biome, [])
	if palette.is_empty():
		palette = [Color("3d7a18"), Color("15591a"), Color("6b6e64"), Color("0c8da1"), Color("85a915"), Color("a17631"), Color("315c4a"), Color("07456b")]
	var result: Color
	match tile:
		RegionGenerator.Tile.DEEP_WATER: result = palette[7]
		RegionGenerator.Tile.FOREST_FLOOR: result = palette[1]
		RegionGenerator.Tile.ROCKY: result = palette[2]
		RegionGenerator.Tile.CRYSTAL_GROUND: result = palette[3]
		RegionGenerator.Tile.FERTILE: result = palette[4]
		RegionGenerator.Tile.SAND: result = palette[5]
		RegionGenerator.Tile.MARSH: result = palette[6]
		RegionGenerator.Tile.CORRUPTION: result = Color("470a3a")
		_: result = palette[0]
	var active_season := terrain_season if season.is_empty() else season
	if tile != RegionGenerator.Tile.CORRUPTION:
		match active_season:
			&"Summer":
				if tile not in [RegionGenerator.Tile.DEEP_WATER, RegionGenerator.Tile.CRYSTAL_GROUND]:
					result = result.lerp(Color("a17a31"), 0.10)
			&"Autumn":
				if tile in [RegionGenerator.Tile.GRASS, RegionGenerator.Tile.FOREST_FLOOR, RegionGenerator.Tile.FERTILE, RegionGenerator.Tile.MARSH]:
					result = result.lerp(Color("98542d"), 0.28)
			&"Winter":
				if tile == RegionGenerator.Tile.DEEP_WATER:
					result = result.lerp(Color("789ba2"), 0.38)
				else:
					var snow_field := season_pattern_noise.get_noise_2d(x, y)
					var snow_strength := 0.72 if snow_field > 0.10 else (0.48 if snow_field > -0.14 else 0.24)
					result = result.lerp(Color("c8d1cb"), snow_strength)
	return Color(result.r, result.g, result.b, 1.0)

func _draw() -> void:
	if current_blueprint == null:
		return
	_draw_resource_nodes(latest_snapshot.resource_nodes if latest_snapshot else current_blueprint.resource_nodes)
	if latest_snapshot:
		_draw_loose_items(latest_snapshot.loose_items)
	if latest_snapshot:
		_draw_corruption(latest_snapshot.corruption_cells)
		for building in latest_snapshot.buildings:
			_draw_building(building)
			if bool(building.get("review_tier_label", false)):
				_draw_review_tier_number(Vector2(float(building.x), float(building.y)) * TILE_PIXELS + Vector2(3, 3), int(building.get("tier", 1)))
			if selected_kind == &"building" and int(building.id) == selected_entity_id:
				var selected_rect := Rect2(Vector2(building.x, building.y) * TILE_PIXELS, Vector2(building.width, building.height) * TILE_PIXELS)
				draw_rect(selected_rect.grow(3.0), Color("72ffcf"), false, 3.0)
		for villager in latest_snapshot.villagers:
			_draw_villager(villager)
			if selected_kind == &"villager" and int(villager.id) == selected_entity_id:
				draw_arc(Vector2(float(villager.x), float(villager.y)) * TILE_PIXELS, 7.0, 0.0, TAU, 24, Color("72ffcf"), 2.0)
		for golem in latest_snapshot.golems:
			_draw_golem(golem)
			if selected_kind == &"golem" and int(golem.id) == selected_entity_id:
				draw_arc(Vector2(float(golem.x), float(golem.y)) * TILE_PIXELS, 9.0, 0.0, TAU, 24, Color("72ffcf"), 2.0)
		for animal in latest_snapshot.animals:
			_draw_animal(animal)
			if selected_kind == &"animal" and int(animal.id) == selected_entity_id:
				draw_arc(Vector2(float(animal.x), float(animal.y)) * TILE_PIXELS, 8.0, 0.0, TAU, 24, Color("72ffcf"), 2.0)
		for monster in latest_snapshot.monsters:
			_draw_monster(monster)
			if selected_kind == &"monster" and int(monster.id) == selected_entity_id:
				draw_arc(Vector2(float(monster.x), float(monster.y)) * TILE_PIXELS, 9.0, 0.0, TAU, 24, Color("ffcf6b"), 2.0)
		for ghost in latest_snapshot.ghosts:
			_draw_ghost(ghost)
		_draw_spell_effects(latest_snapshot.tick)
		_draw_weather(latest_snapshot)
		_draw_night_tint(latest_snapshot.day_fraction)
		_draw_event_atmosphere(latest_snapshot)
	if not pending_building_id.is_empty():
		_draw_placement_ghost()
	elif not pending_spell_id.is_empty():
		_draw_spell_target()

func _draw_resource_nodes(nodes: Array) -> void:
	for node in nodes:
		if int(node.get("amount", 0)) <= 0:
			continue
		var center := Vector2(float(node.x) + 0.5, float(node.y) + 0.5) * TILE_PIXELS
		match node.id:
			"wood": _draw_world_object(center, &"tree", int(node.get("variant", 0)))
			"rock": _draw_world_object(center, &"rock", int(node.get("variant", 0)))
			"iron_ore": _draw_world_object(center, &"iron_rock", int(node.get("variant", 0)))
			"gold_ore": _draw_world_object(center, &"gold_rock", int(node.get("variant", 0)))
			"crystal": _draw_world_object(center, &"crystal", int(node.get("variant", 0)))
			"raw_vegetables": _draw_world_object(center, &"wild_food", int(node.get("variant", 0)))

func _draw_world_object(center: Vector2, object_id: StringName, variant := 0) -> void:
	var color: Color = WORLD_OBJECT_PIXEL_COLORS.get(object_id, Color.WHITE)
	match object_id:
		&"tree":
			draw_rect(Rect2(center + Vector2(-1, 1), Vector2(3, 6)), Color("593a22"), true)
			draw_rect(Rect2(center + Vector2(-5, -5), Vector2(8, 7)), color.darkened(0.42), true)
			draw_rect(Rect2(center + Vector2(-2, -7), Vector2(7, 8)), color.darkened(0.18), true)
			draw_rect(Rect2(center + Vector2(1 + variant % 2, -5), Vector2(3, 3)), color, true)
		&"stump":
			draw_rect(Rect2(center + Vector2(-4, -2), Vector2(8, 5)), Color("4d3322"), true)
			draw_rect(Rect2(center + Vector2(-3, -3), Vector2(6, 4)), color, true)
			draw_rect(Rect2(center + Vector2(-1, -2), Vector2(3, 2)), color.lightened(0.22), true)
		&"dead_tree":
			draw_rect(Rect2(center + Vector2(-1, -6), Vector2(3, 13)), color, true)
			draw_rect(Rect2(center + Vector2(-6, -4), Vector2(6, 2)), color, true)
			draw_rect(Rect2(center + Vector2(2, -1), Vector2(5, 2)), color.darkened(0.18), true)
		&"rock", &"iron_rock", &"gold_rock":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 4), center + Vector2(-4, -2), center + Vector2(0, -6), center + Vector2(5, -3), center + Vector2(6, 4)]), Color("555b5b"))
			draw_rect(Rect2(center + Vector2(-3, -3), Vector2(7, 5)), color, true)
			draw_rect(Rect2(center + Vector2(-1, -4), Vector2(4, 2)), color.lightened(0.24), true)
		&"crystal":
			_draw_crystal(center - Vector2(2, 0), color, 7); _draw_crystal(center + Vector2(4, 2), color.darkened(0.18), 5)
		&"crop":
			for x in [-4, 0, 4]:
				draw_rect(Rect2(center + Vector2(x, -4), Vector2(2, 9)), color.darkened(0.12), true)
				draw_rect(Rect2(center + Vector2(x - 2, -2), Vector2(5, 2)), color, true)
		&"wild_food":
			draw_rect(Rect2(center + Vector2(-1, -4), Vector2(2, 8)), Color("577b31"), true)
			draw_rect(Rect2(center + Vector2(-4, -2), Vector2(8, 3)), Color("7fa13d"), true)
			draw_rect(Rect2(center + Vector2(-2, 2), Vector2(5, 4)), color, true)
		&"mushroom":
			draw_rect(Rect2(center + Vector2(-1, -1), Vector2(3, 5)), color.darkened(0.25), true)
			draw_rect(Rect2(center + Vector2(-5, -5), Vector2(10, 5)), color, true)
			draw_rect(Rect2(center + Vector2(-2, -4), Vector2(3, 2)), Color("c45d52"), true)
		&"flower":
			draw_rect(Rect2(center + Vector2(0, -1), Vector2(1, 6)), Color("47733d"), true)
			for offset in [Vector2(-2, -3), Vector2(1, -4), Vector2(2, -1), Vector2(-2, 0)]:
				draw_rect(Rect2(center + offset, Vector2(3, 3)), color, true)
		&"hole":
			draw_rect(Rect2(center + Vector2(-6, -3), Vector2(12, 7)), Color("6d5037"), true)
			draw_rect(Rect2(center + Vector2(-4, -2), Vector2(8, 5)), color, true)
		&"shallow_water", &"deep_water":
			draw_rect(Rect2(center + Vector2(-7, -5), Vector2(14, 10)), color, true)
			draw_rect(Rect2(center + Vector2(-5, -3), Vector2(8, 1)), color.lightened(0.25), true)
		&"fire":
			draw_rect(Rect2(center + Vector2(-4, 2), Vector2(8, 3)), Color("64321e"), true)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-4, 2), center + Vector2(-1, -6), center + Vector2(1, -1), center + Vector2(4, -7), center + Vector2(5, 3)]), color)
			draw_rect(Rect2(center + Vector2(-1, -2), Vector2(3, 5)), Color("f6d957"), true)
		&"ash":
			draw_rect(Rect2(center + Vector2(-6, -2), Vector2(12, 5)), color.darkened(0.22), true)
			draw_rect(Rect2(center + Vector2(-3, -3), Vector2(7, 3)), color, true)
		&"rubble":
			for offset in [Vector2(-6, 0), Vector2(-2, -4), Vector2(3, -2), Vector2(1, 3)]:
				draw_rect(Rect2(center + offset, Vector2(5, 4)), color.darkened(float(int(offset.x) % 3) * 0.08), true)
		&"corruption":
			draw_rect(Rect2(center + Vector2(-6, -4), Vector2(12, 9)), color.darkened(0.28), true)
			draw_rect(Rect2(center + Vector2(-3, -6), Vector2(4, 10)), color, true)
			draw_rect(Rect2(center + Vector2(3, -2), Vector2(5, 4)), color.lightened(0.16), true)
		&"corpse":
			draw_rect(Rect2(center + Vector2(-6, 0), Vector2(12, 4)), Color("4d3c30"), true)
			draw_rect(Rect2(center + Vector2(-4, -2), Vector2(8, 5)), color, true)
			draw_rect(Rect2(center + Vector2(3, -3), Vector2(4, 4)), color.lightened(0.18), true)
		&"loot_marker":
			draw_rect(Rect2(center + Vector2(-5, -4), Vector2(10, 9)), Color("4d3020"), true)
			draw_rect(Rect2(center + Vector2(-4, -5), Vector2(8, 8)), Color("8b552c"), true)
			draw_rect(Rect2(center + Vector2(-1, -2), Vector2(3, 3)), color, true)

func _draw_loose_items(items: Array) -> void:
	for item in items:
		var center := Vector2(float(item.x) + 0.5, float(item.y) + 0.5) * TILE_PIXELS
		_draw_resource_glyph(center, String(item.resource_id), mini(3, maxi(1, int(item.get("amount", 1)))))

func _draw_resource_glyph(center: Vector2, resource_id: String, stack_size: int = 1) -> void:
	var definition := ContentRegistry.get_by_id(&"resources", StringName(resource_id))
	var group := String(definition.get("group", "misc"))
	var color: Color = {
		"raw": Color("9a7047"), "refined": Color("b19a78"), "food": Color("9cb94f"), "water": Color("58aabd"),
		"recovery": Color("dfd2ad"), "ammunition": Color("9f8e73"), "weapon": Color("a6a8a4"),
		"armor": Color("898d92"), "tool": Color("aa814f"), "magic": Color("7fc7d8"), "currency": Color("d3ae43"),
		"waste": Color("5b514d"), "trash": Color("5b514d"), "loot": Color("c39553"),
	}.get(group, Color("b39b6b"))
	if resource_id in ["wood", "boards"]:
		color = Color("9b6031")
	elif resource_id in ["rock", "cut_stone", "stone_balls"]:
		color = Color("898984")
	elif resource_id in ["crystal", "crylithium", "essence", "energy"]:
		color = Color("57cbd5")
	elif resource_id.contains("gold"):
		color = Color("d4ab3e")
	elif resource_id.contains("iron"):
		color = Color("9ba0a3")
	elif resource_id.ends_with("trash") or resource_id == "trashy_cube":
		color = Color("5e5250")
	for index in stack_size:
		var offset := Vector2(index * 2 - stack_size + 1, -index)
		draw_rect(Rect2(center + offset - Vector2(3, 2), Vector2(6, 5)), Color("1d1815"), true)
		match group:
			"water", "recovery", "magic":
				draw_rect(Rect2(center + offset - Vector2(1, 3), Vector2(3, 6)), color, true)
				draw_rect(Rect2(center + offset - Vector2(0, 4), Vector2(1, 2)), color.lightened(0.25), true)
			"weapon", "tool":
				draw_line(center + offset + Vector2(-2, 2), center + offset + Vector2(3, -3), color, 2.0)
			"armor":
				draw_colored_polygon(PackedVector2Array([center + offset + Vector2(-3, -2), center + offset + Vector2(3, -2), center + offset + Vector2(2, 3), center + offset + Vector2(0, 4), center + offset + Vector2(-2, 3)]), color)
			_:
				draw_rect(Rect2(center + offset - Vector2(2, 1), Vector2(4, 3)), color, true)

func _draw_building(building: Dictionary) -> void:
	var rect := Rect2(Vector2(building.x, building.y) * TILE_PIXELS, Vector2(building.width, building.height) * TILE_PIXELS)
	if bool(building.get("destroyed", false)):
		_draw_destroyed_building(building, rect)
		return
	var complete: bool = building.completed
	var progress := float(building.progress) / maxf(1.0, float(building.build_time))
	if String(building.category) == "roads":
		_draw_road(building, rect, complete, progress)
		_draw_building_status(building, rect)
		return
	if String(building.category) == "walls":
		_draw_wall(building, rect, complete, progress)
		_draw_building_status(building, rect)
		return
	if String(building.category) == "towers":
		_draw_tower(building, rect, complete, progress)
		_draw_building_status(building, rect)
		return
	var category_color: Color = {
		"town_center": Color("6d3b23"), "civics": Color("376f63"), "housing": Color("815b3a"),
		"food_water": Color("65751f"), "harvesting": Color("4c6b36"), "towers": Color("5b536d"),
		"magic": Color("513066"), "storage": Color("7c633c"), "refining": Color("6f5545"),
		"manufacturing": Color("695348"), "lighting": Color("75562f"), "golems": Color("4f6266"),
		"trash": Color("544a43")
	}.get(building.category, Color("6a5a4c"))
	if complete:
		_draw_minimal_building(building, rect, category_color)
	else:
		_draw_minimal_construction(building, rect, category_color, progress)
	_draw_building_status(building, rect)

func _draw_building_status(building: Dictionary, rect: Rect2) -> void:
	var health_ratio := float(building.get("health", 1)) / maxf(1.0, float(building.get("max_health", 1)))
	if health_ratio < 0.70:
		_draw_damage_clusters(building, rect, health_ratio)
	if bool(building.get("burning", false)):
		var fire_center := rect.get_center() + Vector2(rect.size.x * 0.18, -rect.size.y * 0.1)
		_draw_pixel_fire(fire_center, int(building.get("id", 0)))
	var operation_state := String(building.get("operation_state", building.get("combat_state", "")))
	if operation_state in ["no_energy", "no_ammo", "missing_input", "full_output", "paused"]:
		_draw_operation_badge(rect.position + Vector2(rect.size.x - 9, 8), operation_state)
	var service_state := String(building.get("service_state", "none"))
	if service_state in ["repair_requested", "repairing", "repaired"]:
		draw_line(rect.position + Vector2(3, 3), rect.position + Vector2(11, 11), Color("6fffd2"), 3.0)
		draw_circle(rect.position + Vector2(3, 3), 3.0, Color("6fffd2"))
	elif service_state in ["dismantle_requested", "dismantling"]:
		draw_line(rect.position + Vector2(2, 2), rect.end - Vector2(2, 2), Color("ffad5b"), 2.5)
		draw_line(Vector2(rect.end.x - 2, rect.position.y + 2), Vector2(rect.position.x + 2, rect.end.y - 2), Color("ffad5b"), 2.5)
		var target := maxi(60, int(building.get("build_time", 180)) / 3)
		var ratio := clampf(float(building.get("dismantle_progress", 0)) / float(target), 0.0, 1.0)
		draw_rect(Rect2(rect.position + Vector2(2, rect.size.y - 4), Vector2((rect.size.x - 4) * ratio, 2)), Color("ffcf6b"), true)

func _draw_minimal_construction(building: Dictionary, rect: Rect2, accent: Color, progress: float) -> void:
	# Construction is an open work site. The terrain remains visible through the
	# footprint; stakes, rope, supplies, and the emerging structure show progress.
	var rope := Color("c3aa72")
	var timber := Color("8b5b32")
	for x in range(int(rect.position.x + 6), int(rect.end.x - 5), 11):
		draw_rect(Rect2(Vector2(x, rect.position.y + 3), Vector2(6, 1)), rope, true)
		draw_rect(Rect2(Vector2(x + 2, rect.end.y - 4), Vector2(6, 1)), rope.darkened(0.12), true)
	for y in range(int(rect.position.y + 7), int(rect.end.y - 5), 11):
		draw_rect(Rect2(Vector2(rect.position.x + 3, y), Vector2(1, 6)), rope, true)
		draw_rect(Rect2(Vector2(rect.end.x - 4, y + 2), Vector2(1, 6)), rope.darkened(0.12), true)
	for corner in [rect.position + Vector2(2, 2), Vector2(rect.end.x - 5, rect.position.y + 2), Vector2(rect.position.x + 2, rect.end.y - 5), rect.end - Vector2(5, 5)]:
		draw_rect(Rect2(corner, Vector2(3, 5)), timber, true)
	# Sparse worn patches and delivered bundles avoid the old solid brown card.
	draw_rect(Rect2(rect.position + Vector2(8, rect.size.y * 0.55), Vector2(9, 3)), Color(0.32, 0.23, 0.15, 0.55), true)
	_draw_crates(rect.position + Vector2(rect.size.x - 18, rect.size.y - 13), 2, accent.lightened(0.14))
	if progress >= 0.25:
		for x in range(int(rect.position.x + 7), int(rect.end.x - 6), 12):
			draw_rect(Rect2(Vector2(x, rect.position.y + 7), Vector2(3, maxf(7.0, rect.size.y * 0.28))), timber, true)
	if progress >= 0.50:
		draw_rect(Rect2(rect.position + Vector2(6, 7), Vector2(rect.size.x - 12, 3)), timber.lightened(0.12), true)
		draw_rect(Rect2(rect.position + Vector2(7, rect.size.y * 0.48), Vector2(rect.size.x * 0.44, 3)), timber, true)
	if progress >= 0.75:
		var partial := Rect2(rect.position + Vector2(6, 6), Vector2(maxf(5.0, (rect.size.x - 12) * 0.62), maxf(5.0, (rect.size.y - 12) * 0.35)))
		_draw_top_roof(partial, accent.darkened(0.12))
	draw_rect(Rect2(rect.position + Vector2(3, rect.size.y - 2), Vector2((rect.size.x - 6) * progress, 2)), Color("f4c95d"), true)

func _draw_damage_clusters(building: Dictionary, rect: Rect2, health_ratio: float) -> void:
	var count := 1 if health_ratio >= 0.35 else 3
	var building_id := int(building.get("id", 0))
	for index in count:
		var gap_size := Vector2(5 + index * 2, 4 + index)
		var max_x := maxi(1, int(rect.size.x - gap_size.x - 8))
		var max_y := maxi(1, int(rect.size.y - gap_size.y - 8))
		var offset := Vector2(4 + posmod(building_id * 7 + index * 13, max_x), 4 + posmod(building_id * 11 + index * 17, max_y))
		var cell := Vector2i((rect.position + offset) / TILE_PIXELS)
		var terrain_color := _tile_color(current_blueprint.get_tile(cell), current_blueprint.biome_id, cell.x, cell.y)
		draw_rect(Rect2(rect.position + offset, gap_size), terrain_color.darkened(0.08), true)
		draw_rect(Rect2(rect.position + offset + Vector2(1, gap_size.y), Vector2(gap_size.x + 2, 2)), Color("66584b"), true)
	if health_ratio < 0.35:
		for index in 4:
			var rubble := rect.position + Vector2(5 + posmod(building_id + index * 19, maxi(2, int(rect.size.x - 10))), rect.size.y - 6 - (index % 2) * 3)
			draw_rect(Rect2(rubble, Vector2(4, 3)), Color("756c61").darkened(index * 0.05), true)

func _draw_destroyed_building(building: Dictionary, rect: Rect2) -> void:
	var building_id := int(building.get("id", 0))
	for index in 9:
		var x := 4 + posmod(building_id * 5 + index * 17, maxi(2, int(rect.size.x - 10)))
		var y := 4 + posmod(building_id * 3 + index * 11, maxi(2, int(rect.size.y - 10)))
		var color := Color("716b64") if index % 3 else Color("4f4035")
		draw_rect(Rect2(rect.position + Vector2(x, y), Vector2(4 + index % 3, 3 + index % 2)), color, true)
	for index in 3:
		var beam_start := rect.position + Vector2(5 + index * 7, 7 + index * 5)
		draw_line(beam_start, beam_start + Vector2(11, 5 if index % 2 else -4), Color("5e3f28"), 2.0)
	draw_rect(Rect2(rect.get_center() - Vector2(8, 3), Vector2(16, 6)), Color(0.16, 0.13, 0.12, 0.38), true)

func _draw_pixel_fire(center: Vector2, seed: int) -> void:
	var flicker := posmod(int(SimulationHost.tick / 2) + seed, 2)
	draw_rect(Rect2(center + Vector2(-5, 2), Vector2(11, 3)), Color(0.29, 0.12, 0.05, 0.70), true)
	draw_rect(Rect2(center + Vector2(-4, -4 + flicker), Vector2(4, 8 - flicker)), Color("e54f1d"), true)
	draw_rect(Rect2(center + Vector2(1, -7 - flicker), Vector2(4, 11 + flicker)), Color("f47d24"), true)
	draw_rect(Rect2(center + Vector2(-1, -2), Vector2(3, 6)), Color("f7d65b"), true)

func _draw_operation_badge(center: Vector2, state: String) -> void:
	var color := Color("e4c157") if state in ["no_energy", "no_ammo"] else Color("de795e")
	draw_rect(Rect2(center - Vector2(5, 5), Vector2(10, 10)), Color("201b1d"), true)
	draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 8)), color.darkened(0.25), true)
	if state == "no_energy":
		draw_rect(Rect2(center + Vector2(0, -3), Vector2(2, 4)), color, true)
		draw_rect(Rect2(center + Vector2(-2, 0), Vector2(3, 2)), color, true)
		draw_rect(Rect2(center + Vector2(-3, 1), Vector2(2, 4)), color, true)
	elif state == "no_ammo":
		draw_rect(Rect2(center + Vector2(-3, -1), Vector2(6, 3)), color, true)
		draw_rect(Rect2(center + Vector2(2, -3), Vector2(2, 6)), color, true)
	else:
		draw_rect(Rect2(center + Vector2(-1, -3), Vector2(2, 5)), color, true)
		draw_rect(Rect2(center + Vector2(-1, 3), Vector2(2, 2)), color, true)

func _draw_review_tier_number(origin: Vector2, tier: int) -> void:
	var patterns := {
		"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
		"2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
		"4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
		"6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
		"8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
	}
	var text := str(tier)
	draw_rect(Rect2(origin - Vector2.ONE, Vector2(text.length() * 4 + 2, 7)), Color(0.05, 0.04, 0.04, 0.90), true)
	for digit_index in text.length():
		var rows: Array = patterns.get(text.substr(digit_index, 1), [])
		for y in rows.size():
			for x in 3:
				if String(rows[y]).substr(x, 1) == "1":
					draw_rect(Rect2(origin + Vector2(digit_index * 4 + x, y), Vector2.ONE), Color("f4dc62"), true)

func _draw_minimal_building(building: Dictionary, rect: Rect2, accent: Color) -> void:
	var definition_id := String(building.definition_id)
	var tier := int(building.get("tier", 1))
	if definition_id == "camp":
		_draw_town_center(rect, tier)
		return
	if definition_id in ["housing", "doggo_house"]:
		_draw_housing_top(rect, tier, definition_id == "doggo_house")
		return
	_draw_open_yard(rect, accent, tier)
	match definition_id:
		"ancillary":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.48, rect.size.y * 0.34)), Color("806044"))
			_draw_crates(rect.position + Vector2(rect.size.x * 0.62, 7), 3, Color("af814b"))
			_draw_table(rect.position + Vector2(8, rect.size.y * 0.58), Vector2(rect.size.x - 16, 7), Color("856039"))
		"clinic":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 13)), Color("b7aa88"))
			_draw_cot(Rect2(rect.position + Vector2(rect.size.x * 0.54, 23), Vector2(12, rect.size.y - 31)))
			_draw_herbs(rect.position + Vector2(8, 24))
			_draw_basin(rect.position + Vector2(11, rect.size.y - 13), Color("64a9b7"))
			_draw_cross(rect.position + Vector2(rect.size.x - 10, 8), Color("b9414b"))
		"courier_station":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.44, 14)), Color("806044"))
			_draw_crates(rect.position + Vector2(rect.size.x * 0.58, 7), 4, Color("ba8a4f"))
			_draw_arrow(rect.get_center() + Vector2(0, 8), Color("e0c36b"))
		"maintenance_building":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 14)), Color("73563f"))
			_draw_table(rect.position + Vector2(8, 23), Vector2(rect.size.x - 16, 8), Color("8c6339"))
			_draw_tool_pair(rect.get_center() + Vector2(0, 8))
			_draw_logs(rect.position + Vector2(8, rect.size.y - 13), 3, Color("9b6332"))
		"marketplace":
			var stall_width := floorf((rect.size.x - 12) / 3.0)
			for index in 3:
				var stall := Rect2(rect.position + Vector2(4 + index * stall_width, 5), Vector2(stall_width - 2, 15))
				_draw_top_roof(stall, [Color("b85b43"), Color("d2b15d"), Color("5c8b75")][index])
			_draw_crates(rect.position + Vector2(8, rect.size.y - 15), 4, Color("b1814b"))
		"migration_way_station":
			_draw_arch(rect.get_center() + Vector2(0, -6), Color("9b846a"))
			_draw_bedroll(rect.position + Vector2(7, rect.size.y - 15), Color("9b6a4f"))
			_draw_bedroll(rect.position + Vector2(rect.size.x - 17, rect.size.y - 15), Color("547a79"))
		"way_maker_shack":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.50, 13)), Color("76553a"))
			_draw_road_samples(rect.position + Vector2(rect.size.x * 0.58, 7))
			_draw_tool_pair(rect.get_center() + Vector2(0, 10))
		"lumber_shack":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.45, rect.size.y * 0.45)), Color("6d4a31"))
			_draw_logs(rect.position + Vector2(rect.size.x * 0.55, 7), 5, Color("9c6030"))
			_draw_logs(rect.position + Vector2(8, rect.size.y - 16), 4, Color("8e572b"))
		"mining_facility":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.45, 14)), Color("66584d"))
			_draw_rock_pile(rect.position + Vector2(rect.size.x * 0.62, 9), Color("88847c"))
			_draw_cart(rect.get_center() + Vector2(0, 10), Color("8e6035"))
		"crystal_harvestry":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.48, 14)), Color("4f6667"))
			for offset in [Vector2(rect.size.x * 0.68, 12), Vector2(12, rect.size.y * 0.65), Vector2(rect.size.x * 0.62, rect.size.y * 0.68)]:
				_draw_crystal(rect.position + offset, Color("56cddd"))
		"farm":
			_draw_crop_rows(rect)
		"animal_pen":
			_draw_trough(Rect2(rect.position + Vector2(7, 8), Vector2(rect.size.x - 14, 6)))
			_draw_hay(rect.position + Vector2(10, rect.size.y - 13))
			_draw_hay(rect.position + Vector2(rect.size.x - 15, rect.size.y - 13))
		"clucker_coop":
			_draw_top_roof(Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x * 0.48, rect.size.y * 0.42)), Color("8b613a"))
			for offset in [Vector2(rect.size.x * 0.66, 11), Vector2(rect.size.x * 0.75, 18), Vector2(rect.size.x * 0.60, 25)]:
				draw_rect(Rect2(rect.position + offset, Vector2(3, 3)), Color("dfd19c"), true)
		"kitchen":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 14)), Color("714832"))
			_draw_hearth(rect.position + Vector2(11, rect.size.y * 0.58))
			_draw_table(rect.position + Vector2(rect.size.x * 0.45, rect.size.y * 0.52), Vector2(rect.size.x * 0.38, 8), Color("8a6038"))
		"bottler":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 13)), Color("5e6154"))
			for index in 4:
				_draw_bottle(rect.position + Vector2(8 + index * 7, 24), Color("60afbe"))
			_draw_basin(rect.position + Vector2(rect.size.x - 14, rect.size.y - 14), Color("4597ad"))
		"water_purifier":
			_draw_basin(rect.position + Vector2(13, 15), Color("46788a"), 9)
			_draw_basin(rect.position + Vector2(rect.size.x - 16, rect.size.y - 17), Color("69bed0"), 9)
			draw_rect(Rect2(rect.get_center() - Vector2(1, 8), Vector2(3, 17)), Color("948873"), true)
		"well":
			_draw_basin(rect.get_center(), Color("4097b1"), mini(11, int(rect.size.x * 0.28)))
		"rain_catcher":
			draw_rect(Rect2(rect.position + Vector2(7, 7), rect.size - Vector2(14, 17)), Color("172a2f"), true)
			draw_rect(Rect2(rect.position + Vector2(9, 9), rect.size - Vector2(18, 21)), Color("4d9eb5"), true)
		"small_fountain", "large_fountain":
			var radius := 10 if definition_id == "small_fountain" else 16
			_draw_basin(rect.get_center(), Color("64b7ca"), radius)
			draw_rect(Rect2(rect.get_center() - Vector2(2, 2), Vector2(4, 4)), Color("d5d0bd"), true)
		"ranger_lodge":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.50, rect.size.y * 0.42)), Color("53633d"))
			_draw_target(rect.position + Vector2(rect.size.x - 13, 14))
			_draw_bow(rect.position + Vector2(rect.size.x * 0.62, rect.size.y * 0.65), Color("b48148"))
		"outpost":
			_draw_top_roof(Rect2(rect.get_center() - Vector2(10, 10), Vector2(20, 20)), Color("695442"))
			draw_rect(Rect2(rect.position + Vector2(rect.size.x - 10, 6), Vector2(2, 18)), Color("8b693d"), true)
			draw_colored_polygon(PackedVector2Array([rect.position + Vector2(rect.size.x - 8, 6), rect.position + Vector2(rect.size.x - 1, 9), rect.position + Vector2(rect.size.x - 8, 13)]), Color("c4594c"))
		"lumber_mill":
			_draw_machine_house(rect, Color("7a5233"))
			_draw_logs(rect.position + Vector2(8, rect.size.y - 14), 5, Color("a46b34"))
			draw_rect(Rect2(rect.get_center() + Vector2(4, -1), Vector2(2, 16)), Color("d0c0a1"), true)
		"stone_cuttery":
			_draw_machine_house(rect, Color("70665c"))
			_draw_rock_pile(rect.position + Vector2(11, rect.size.y - 13), Color("97938c"))
			draw_rect(Rect2(rect.get_center() + Vector2(4, -7), Vector2(3, 16)), Color("c2bdb4"), true)
		"crystillery":
			_draw_machine_house(rect, Color("50666d"))
			_draw_crystal(rect.position + Vector2(12, rect.size.y - 16), Color("59d5e7"), 8)
			_draw_basin(rect.position + Vector2(rect.size.x - 14, rect.size.y - 13), Color("3c8999"), 7)
		"forge":
			_draw_machine_house(rect, Color("65443a"))
			_draw_hearth(rect.position + Vector2(12, rect.size.y - 14))
			_draw_anvil(rect.position + Vector2(rect.size.x - 16, rect.size.y - 14))
		"toolsmithy":
			_draw_manufacturing_yard(rect, Color("735240"))
			_draw_tool_pair(rect.get_center() + Vector2(0, 9))
		"armorsmithy":
			_draw_manufacturing_yard(rect, Color("69534a"))
			_draw_shield(rect.get_center() + Vector2(0, 9), Color("a5a59d"))
		"bowyer":
			_draw_manufacturing_yard(rect, Color("725238"))
			_draw_bow(rect.get_center() + Vector2(0, 10), Color("c28a48"))
		"tumbler":
			_draw_manufacturing_yard(rect, Color("665d55"))
			_draw_drum(rect.get_center() + Vector2(0, 10), Color("90877a"))
		"wood_storage", "rock_storage", "crystal_storage", "mineral_storage", "food_storage", "gold_storage", "ammo_storage", "equipment_storage", "miscellaneous_storage":
			_draw_storage_yard(rect, definition_id)
		"key_shack":
			_draw_top_roof(Rect2(rect.position + Vector2(5, 5), rect.size - Vector2(10, 15)), Color("66513b"))
			_draw_key(rect.get_center() + Vector2(0, 7), Color("d3b457"))
		"essence_altar":
			_draw_magic_circle(rect.get_center(), Color("8dd9d0"), 15)
			draw_rect(Rect2(rect.get_center() - Vector2(3, 3), Vector2(6, 6)), Color("e6f4dc"), true)
		"essence_collector":
			_draw_magic_circle(rect.get_center(), Color("72c9dc"), 13)
			for offset in [Vector2(-10, 0), Vector2(10, 0), Vector2(0, -10)]:
				_draw_bottle(rect.get_center() + offset, Color("62bfd2"))
		"reliquary":
			_draw_cot(Rect2(rect.get_center() - Vector2(7, 14), Vector2(14, 28)), Color("756381"))
			_draw_bottle(rect.position + Vector2(10, rect.size.y - 12), Color("a087d5"))
			_draw_bottle(rect.position + Vector2(rect.size.x - 12, rect.size.y - 12), Color("81d0df"))
		"cullis_gate":
			_draw_arch(rect.get_center(), Color("6f5b78"))
			_draw_magic_circle(rect.get_center(), Color("a178d2"), 10)
		"fire_pit", "large_fire_pit", "crylithium_fire_pit":
			var fire_radius := 7 if definition_id == "fire_pit" else 12
			_draw_fire_pit(rect.get_center(), fire_radius, definition_id == "crylithium_fire_pit")
		"crystal_motivator":
			_draw_magic_circle(rect.get_center(), Color("5bcbd6"), 14)
			_draw_crystal(rect.get_center() - Vector2(0, 3), Color("65e1e8"), 10)
		"wood_golem_combobulator", "stone_golem_combobulator", "crystal_golem_combobulator", "cube_e_golem_combobulator":
			_draw_combobulator(rect, definition_id)
		"trash_can":
			_draw_bin(rect.get_center(), Color("625851"))
		"landfill":
			for offset in [Vector2(12, 14), Vector2(rect.size.x * 0.55, 11), Vector2(rect.size.x * 0.38, rect.size.y * 0.60), Vector2(rect.size.x * 0.70, rect.size.y * 0.65)]:
				_draw_trash(rect.position + offset)
		"processor":
			_draw_machine_house(rect, Color("534f4b"))
			_draw_gear(rect.get_center() + Vector2(0, 10), Color("9b9388"))
		"burner":
			_draw_machine_house(rect, Color("55463e"))
			_draw_hearth(rect.get_center() + Vector2(0, 10))
		"trashy_cube_pile":
			for offset in [Vector2(10, 12), Vector2(19, 8), Vector2(28, 14), Vector2(15, 23), Vector2(25, 25)]:
				draw_rect(Rect2(rect.position + offset, Vector2(7, 7)), Color("655a58").lightened(float(int(offset.x + offset.y) % 3) * 0.08), true)
		_:
			_draw_top_roof(Rect2(rect.position + Vector2(5, 5), rect.size - Vector2(10, 15)), accent)
	if tier >= 2:
		_draw_tier_progression(rect, String(building.category), tier, accent)

func _draw_open_yard(rect: Rect2, accent: Color, tier: int) -> void:
	var ground := Color("4b402d").lerp(accent.darkened(0.45), 0.25)
	ground.a = 0.28
	draw_rect(rect.grow(-3.0), ground, true)
	var border := Color("765334") if tier < 3 else Color("85817a")
	for x in range(int(rect.position.x + 3), int(rect.end.x - 4), 7):
		draw_rect(Rect2(Vector2(x, rect.position.y + 2), Vector2(4, 1)), border, true)
		if x < rect.get_center().x - 7 or x > rect.get_center().x + 4:
			draw_rect(Rect2(Vector2(x, rect.end.y - 3), Vector2(4, 1)), border, true)
	for y in range(int(rect.position.y + 3), int(rect.end.y - 4), 7):
		draw_rect(Rect2(Vector2(rect.position.x + 2, y), Vector2(1, 4)), border, true)
		draw_rect(Rect2(Vector2(rect.end.x - 3, y), Vector2(1, 4)), border, true)
	for point in [rect.position + Vector2(1, 1), Vector2(rect.end.x - 3, rect.position.y + 1), Vector2(rect.position.x + 1, rect.end.y - 3), rect.end - Vector2(3, 3)]:
		draw_rect(Rect2(point, Vector2(2, 2)), border.lightened(0.12), true)
	var wear_seed := int(rect.position.x * 5.0 + rect.position.y * 3.0)
	for index in 4:
		var wear_x := int(rect.position.x + 5 + posmod(wear_seed + index * 11, maxi(1, int(rect.size.x) - 10)))
		var wear_y := int(rect.position.y + 6 + posmod(wear_seed / 3 + index * 7, maxi(1, int(rect.size.y) - 12)))
		draw_rect(Rect2(Vector2(wear_x, wear_y), Vector2(2, 1)), Color(0.18, 0.13, 0.08, 0.36), true)

func _draw_top_roof(rect: Rect2, color: Color) -> void:
	draw_rect(rect.grow(1.0), Color("201913"), true)
	draw_rect(rect, color, true)
	for y in range(int(rect.position.y + 3), int(rect.end.y - 1), 4):
		draw_rect(Rect2(Vector2(rect.position.x + 1, y), Vector2(rect.size.x - 2, 1)), color.darkened(0.18), true)
	draw_rect(Rect2(Vector2(rect.position.x + rect.size.x * 0.5 - 1, rect.position.y), Vector2(2, rect.size.y)), color.lightened(0.09), true)

func _draw_town_center(rect: Rect2, tier: int) -> void:
	_draw_open_yard(rect, Color("745137"), mini(4, 1 + tier / 4))
	if tier <= 3:
		var tent_color := Color("bd7042").lightened(float(tier - 1) * 0.07)
		var tent_centers := [rect.position + Vector2(rect.size.x * 0.27, rect.size.y * 0.30), rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.34), rect.position + Vector2(rect.size.x * 0.35, rect.size.y * 0.72), rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.72)]
		for index in mini(tier + 1, tent_centers.size()):
			var center: Vector2 = tent_centers[index]
			draw_colored_polygon(PackedVector2Array([center + Vector2(-7, 5), center + Vector2(0, -6), center + Vector2(7, 5)]), tent_color)
			draw_rect(Rect2(center + Vector2(-1, -5), Vector2(2, 10)), Color("492b1c"), true)
		_draw_fire_pit(rect.get_center() + Vector2(9, 10), 6, false)
		if tier >= 2:
			_draw_crates(rect.position + Vector2(rect.size.x * 0.47, 8), tier, Color("a8753f"))
		if tier >= 3:
			for x in range(int(rect.position.x + 7), int(rect.end.x - 7), 12):
				draw_rect(Rect2(Vector2(x, rect.position.y + 5), Vector2(5, 2)), Color("80542f"), true)
	elif tier <= 7:
		var main_roof := Rect2(rect.position + Vector2(7, 7), Vector2(rect.size.x * (0.47 + float(tier - 4) * 0.035), rect.size.y * 0.40))
		_draw_top_roof(main_roof, Color("7b5135"))
		if tier >= 5:
			_draw_top_roof(Rect2(rect.position + Vector2(8, rect.size.y * 0.56), Vector2(rect.size.x * 0.35, rect.size.y * 0.25)), Color("6d4a35"))
		if tier >= 6:
			_draw_top_roof(Rect2(rect.position + Vector2(rect.size.x * 0.55, rect.size.y * 0.57), Vector2(rect.size.x * 0.27, rect.size.y * 0.22)), Color("70503a"))
		_draw_crates(rect.position + Vector2(rect.size.x * 0.70, 10), mini(5, tier - 2), Color("ae7a43"))
		_draw_fire_pit(rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.68), 6, false)
		if tier >= 7:
			draw_rect(rect.grow(-5.0), Color("98938a"), false, 3.0)
			for corner in [rect.position + Vector2(4, 4), Vector2(rect.end.x - 10, rect.position.y + 4), Vector2(rect.position.x + 4, rect.end.y - 10), rect.end - Vector2(10, 10)]:
				draw_rect(Rect2(corner, Vector2(6, 6)), Color("77736d"), true)
	elif tier <= 10:
		var keep := Rect2(rect.position + Vector2(9, 9), rect.size - Vector2(18, 21))
		draw_rect(keep.grow(2), Color("353230"), true)
		draw_rect(keep, Color("77746d"), true)
		_draw_top_roof(keep.grow(-6), Color("5e4c43"))
		if tier >= 9:
			for corner in [keep.position - Vector2(3, 3), Vector2(keep.end.x - 9, keep.position.y - 3), Vector2(keep.position.x - 3, keep.end.y - 9), keep.end - Vector2(9, 9)]:
				draw_rect(Rect2(corner, Vector2(9, 9)), Color("67645f"), true)
		if tier >= 10:
			for x in range(int(keep.position.x + 2), int(keep.end.x - 2), 7):
				draw_rect(Rect2(Vector2(x, keep.position.y - 2), Vector2(4, 3)), Color("aaa49a"), true)
			draw_rect(Rect2(keep.get_center() - Vector2(2, 13), Vector2(4, 8)), Color("9a7842"), true)
	else:
		var castle := rect.grow(-7)
		draw_rect(castle.grow(2), Color("2b2928"), false, 3.0)
		var wall_width := 3.0 + float(mini(3, tier - 10))
		draw_rect(castle, Color("858179"), false, wall_width)
		for corner in [castle.position, Vector2(castle.end.x - 12, castle.position.y), Vector2(castle.position.x, castle.end.y - 12), castle.end - Vector2(12, 12)]:
			var tower_size := 10 + mini(4, tier - 11)
			draw_rect(Rect2(corner, Vector2(tower_size, tower_size)), Color("67645f"), true)
		var keep_size := 20 + (tier - 11) * 3
		_draw_top_roof(Rect2(castle.get_center() - Vector2(keep_size, keep_size) * 0.5, Vector2(keep_size, keep_size)), Color("55443e"))
		if tier >= 12:
			draw_rect(Rect2(castle.position + Vector2(16, 16), Vector2(castle.size.x - 32, castle.size.y - 32)), Color("958f84"), false, 2.0)
		if tier >= 13:
			_draw_crates(castle.position + Vector2(16, castle.size.y - 25), 5, Color("9b6e3d"))
		if tier >= 14:
			for x in range(int(castle.position.x + 3), int(castle.end.x - 2), 7):
				draw_rect(Rect2(Vector2(x, castle.position.y - 2), Vector2(4, 3)), Color("aaa49a"), true)
		if tier >= 15:
			draw_rect(Rect2(castle.get_center() + Vector2(-2, -25), Vector2(3, 19)), Color("4e3a29"), true)
			draw_colored_polygon(PackedVector2Array([castle.get_center() + Vector2(1, -25), castle.get_center() + Vector2(13, -21), castle.get_center() + Vector2(1, -17)]), Color("c9a64a"))

func _draw_housing_top(rect: Rect2, tier: int, doggo: bool) -> void:
	_draw_open_yard(rect, Color("72523b"), tier)
	if doggo:
		var kennel_count := mini(4, tier + 1)
		for index in kennel_count:
			var center := rect.position + Vector2(9 + (index % 2) * 17, 12 + (index / 2) * 18)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-6, 5), center + Vector2(0, -5), center + Vector2(6, 5)]), Color("8d5c38"))
			draw_rect(Rect2(center + Vector2(-2, 1), Vector2(4, 5)), Color("241812"), true)
		return
	var main_roof := Rect2(rect.position + Vector2(6, 6), rect.size - Vector2(12, 17))
	_draw_top_roof(main_roof, Color("755443").lightened(float(mini(tier, 4) - 1) * 0.05))
	if tier >= 2:
		_draw_top_roof(Rect2(rect.position + Vector2(rect.size.x - 22, rect.size.y - 24), Vector2(15, 14)), Color("665047"))
	if tier >= 3:
		draw_rect(main_roof, Color("8d8982"), false, 2.0)
	if tier >= 4:
		_draw_top_roof(Rect2(rect.position + Vector2(7, rect.size.y - 25), Vector2(15, 14)), Color("6f5342"))
	if tier >= 5:
		draw_rect(Rect2(main_roof.position + Vector2(5, 4), Vector2(3, 7)), Color("9a9184"), true)
		draw_rect(Rect2(main_roof.position + Vector2(4, 3), Vector2(5, 3)), Color("4a4038"), true)
		_draw_bedroll(rect.position + Vector2(10, rect.size.y - 13), Color("71877e"))
	if tier >= 6:
		for corner in [main_roof.position - Vector2(2, 2), Vector2(main_roof.end.x - 5, main_roof.position.y - 2), Vector2(main_roof.position.x - 2, main_roof.end.y - 5), main_roof.end - Vector2(5, 5)]:
			draw_rect(Rect2(corner, Vector2(7, 7)), Color("7c7972"), true)
	if tier >= 7:
		draw_rect(main_roof.grow(-3), Color("a4a19a"), false, 2.0)
		for x in range(int(main_roof.position.x + 5), int(main_roof.end.x - 4), 10):
			draw_rect(Rect2(Vector2(x, main_roof.position.y + 2), Vector2(3, main_roof.size.y - 4)), Color("5f6670"), true)
	draw_rect(Rect2(Vector2(rect.get_center().x - 3, rect.end.y - 11), Vector2(6, 9)), Color("251914"), true)

func _draw_tier_progression(rect: Rect2, category: String, tier: int, accent: Color) -> void:
	# Upgrades alter the physical plan: added work cover/capacity, masonry,
	# machinery and late power infrastructure. No tier is conveyed by hue alone.
	if tier >= 2:
		var annex_size := Vector2(clampf(rect.size.x * 0.26, 10.0, 18.0), clampf(rect.size.y * 0.20, 8.0, 14.0))
		var annex := Rect2(rect.end - annex_size - Vector2(5, 6), annex_size)
		_draw_top_roof(annex, accent.lightened(0.08))
		_draw_crates(rect.position + Vector2(6, rect.size.y - 13), mini(3, tier), accent.lightened(0.18))
	if tier >= 3:
		var stone := Color("8d8981")
		for corner in [rect.position + Vector2(3, 3), Vector2(rect.end.x - 8, rect.position.y + 3), Vector2(rect.position.x + 3, rect.end.y - 8), rect.end - Vector2(8, 8)]:
			draw_rect(Rect2(corner, Vector2(5, 5)), stone, true)
		draw_rect(rect.grow(-3.0), stone.darkened(0.05), false, 2.0)
	if tier >= 4:
		var power_color := Color("67d3d5") if category in ["magic", "golems", "storage"] else Color("b8a16a")
		_draw_gear(rect.position + Vector2(rect.size.x - 13, 14), power_color)
		draw_rect(Rect2(rect.position + Vector2(8, 5), Vector2(rect.size.x - 16, 2)), Color("696f72"), true)
	if tier >= 5:
		var second_annex := Rect2(rect.position + Vector2(5, rect.size.y * 0.56), Vector2(clampf(rect.size.x * 0.28, 11.0, 19.0), clampf(rect.size.y * 0.20, 8.0, 14.0)))
		_draw_top_roof(second_annex, accent.darkened(0.08))
		for offset in [Vector2(8, 8), Vector2(rect.size.x - 11, rect.size.y - 11)]:
			_draw_crystal(rect.position + offset, Color("70dce0"), 5)

func _draw_logs(origin: Vector2, count: int, color: Color) -> void:
	for index in count:
		var y := origin.y + index * 4
		draw_rect(Rect2(Vector2(origin.x, y), Vector2(15, 3)), color, true)
		draw_rect(Rect2(Vector2(origin.x + 1, y + 1), Vector2(2, 1)), color.lightened(0.22), true)

func _draw_crates(origin: Vector2, count: int, color: Color) -> void:
	for index in count:
		var pos := origin + Vector2((index % 2) * 8, (index / 2) * 8)
		draw_rect(Rect2(pos, Vector2(7, 7)), Color("2b2118"), true)
		draw_rect(Rect2(pos + Vector2.ONE, Vector2(5, 5)), color, true)
		draw_rect(Rect2(pos + Vector2(3, 1), Vector2(1, 5)), color.darkened(0.22), true)

func _draw_table(origin: Vector2, size: Vector2, color: Color) -> void:
	draw_rect(Rect2(origin, size), Color("241b15"), true)
	draw_rect(Rect2(origin + Vector2.ONE, size - Vector2(2, 3)), color, true)
	draw_rect(Rect2(origin + Vector2(2, size.y - 2), Vector2(2, 4)), color.darkened(0.25), true)
	draw_rect(Rect2(origin + Vector2(size.x - 4, size.y - 2), Vector2(2, 4)), color.darkened(0.25), true)

func _draw_cot(rect: Rect2, blanket: Color = Color("b4a989")) -> void:
	draw_rect(rect.grow(1), Color("2b211a"), true)
	draw_rect(rect, blanket, true)
	draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, 5)), blanket.lightened(0.24), true)
	draw_rect(Rect2(Vector2(rect.position.x + 1, rect.end.y - 7), Vector2(rect.size.x - 2, 6)), Color("566d5b"), true)

func _draw_herbs(origin: Vector2) -> void:
	for index in 3:
		var color: Color = [Color("668445"), Color("819a4f"), Color("78608b")][index]
		draw_rect(Rect2(origin + Vector2(index * 6, 0), Vector2(4, 7)), color, true)
		draw_rect(Rect2(origin + Vector2(index * 6 + 1, -2), Vector2(2, 3)), Color("4e693a"), true)

func _draw_cross(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(center - Vector2(1, 4), Vector2(3, 9)), color, true)
	draw_rect(Rect2(center - Vector2(4, 1), Vector2(9, 3)), color, true)

func _draw_basin(center: Vector2, water: Color, radius: int = 7) -> void:
	draw_circle(center, radius, Color("272421"))
	draw_circle(center, radius - 2, Color("8b8577"))
	draw_circle(center, maxi(1, radius - 4), water)

func _draw_arrow(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(center - Vector2(8, 1), Vector2(13, 3)), color, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(4, -5), center + Vector2(10, 0), center + Vector2(4, 6)]), color)

func _draw_tool_pair(center: Vector2) -> void:
	draw_line(center + Vector2(-8, 7), center + Vector2(7, -8), Color("b78348"), 2.0)
	draw_rect(Rect2(center + Vector2(3, -10), Vector2(8, 4)), Color("9ca0a0"), true)
	draw_line(center + Vector2(-7, -8), center + Vector2(8, 7), Color("b78348"), 2.0)
	draw_rect(Rect2(center + Vector2(-10, -10), Vector2(5, 5)), Color("8e9395"), true)

func _draw_bedroll(origin: Vector2, color: Color) -> void:
	draw_rect(Rect2(origin, Vector2(11, 7)), Color("2b211b"), true)
	draw_rect(Rect2(origin + Vector2.ONE, Vector2(9, 5)), color, true)
	draw_rect(Rect2(origin + Vector2(3, 1), Vector2(2, 5)), color.lightened(0.18), true)

func _draw_arch(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-12, -12), Vector2(5, 25)), color, true)
	draw_rect(Rect2(center + Vector2(7, -12), Vector2(5, 25)), color, true)
	draw_rect(Rect2(center + Vector2(-9, -14), Vector2(18, 5)), color.lightened(0.12), true)

func _draw_road_samples(origin: Vector2) -> void:
	for index in 3:
		draw_rect(Rect2(origin + Vector2(0, index * 7), Vector2(18, 5)), [Color("795c3c"), Color("817b6f"), Color("aaa094")][index], true)

func _draw_rock_pile(center: Vector2, color: Color) -> void:
	for offset in [Vector2(-7, 2), Vector2(0, -4), Vector2(7, 3), Vector2(1, 5)]:
		draw_rect(Rect2(center + offset, Vector2(7, 6)), Color("272522"), true)
		draw_rect(Rect2(center + offset + Vector2.ONE, Vector2(5, 4)), color.lightened(float(int(offset.x + offset.y) % 3) * 0.04), true)

func _draw_cart(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(center - Vector2(9, 5), Vector2(18, 10)), Color("2b2118"), true)
	draw_rect(Rect2(center - Vector2(7, 3), Vector2(14, 6)), color, true)
	draw_circle(center + Vector2(-6, 6), 3, Color("3a2a20"))
	draw_circle(center + Vector2(6, 6), 3, Color("3a2a20"))

func _draw_crystal(center: Vector2, color: Color, size: int = 6) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -size), center + Vector2(size / 2.0, 1), center + Vector2(0, size), center + Vector2(-size / 2.0, 1)]), color)
	draw_rect(Rect2(center + Vector2(-1, -size + 2), Vector2(2, size)), color.lightened(0.28), true)

func _draw_crop_rows(rect: Rect2) -> void:
	for row in 4:
		var y := rect.position.y + 9 + row * maxf(6, (rect.size.y - 18) / 4.0)
		draw_rect(Rect2(Vector2(rect.position.x + 6, y), Vector2(rect.size.x - 12, 3)), Color("3a2f20"), true)
		for x in range(int(rect.position.x + 8), int(rect.end.x - 7), 7):
			draw_rect(Rect2(Vector2(x, y - 2), Vector2(3, 4)), Color("779c3e") if row % 2 == 0 else Color("a0a842"), true)

func _draw_trough(rect: Rect2) -> void:
	draw_rect(rect.grow(1), Color("2a2018"), true)
	draw_rect(rect, Color("82603b"), true)
	draw_rect(rect.grow(-2), Color("557f85"), true)

func _draw_hay(center: Vector2) -> void:
	draw_rect(Rect2(center - Vector2(5, 4), Vector2(10, 8)), Color("2d2518"), true)
	draw_rect(Rect2(center - Vector2(4, 3), Vector2(8, 6)), Color("c5a846"), true)
	draw_rect(Rect2(center + Vector2(-1, -3), Vector2(2, 6)), Color("856b2f"), true)

func _draw_hearth(center: Vector2) -> void:
	draw_rect(Rect2(center - Vector2(7, 6), Vector2(14, 12)), Color("39302a"), true)
	draw_rect(Rect2(center - Vector2(4, 3), Vector2(8, 6)), Color("b84928"), true)
	draw_rect(Rect2(center - Vector2(2, 2), Vector2(4, 4)), Color("f2a83c"), true)

func _draw_bottle(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(center - Vector2(2, 3), Vector2(5, 7)), Color("15292c"), true)
	draw_rect(Rect2(center - Vector2(1, 1), Vector2(3, 4)), color, true)
	draw_rect(Rect2(center + Vector2(0, -4), Vector2(2, 2)), color.lightened(0.22), true)

func _draw_target(center: Vector2) -> void:
	draw_circle(center, 8, Color("d8caa3"))
	draw_circle(center, 5, Color("a75445"))
	draw_circle(center, 2, Color("e7cf74"))

func _draw_bow(center: Vector2, color: Color) -> void:
	draw_arc(center, 10, -PI * 0.5, PI * 0.5, 10, color, 2.0)
	draw_rect(Rect2(center + Vector2(-1, -10), Vector2(1, 20)), Color("dfd6b0"), true)

func _draw_machine_house(rect: Rect2, roof_color: Color) -> void:
	_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 14)), roof_color)
	_draw_table(rect.position + Vector2(rect.size.x * 0.34, rect.size.y * 0.47), Vector2(rect.size.x * 0.50, 8), roof_color.lightened(0.08))

func _draw_anvil(center: Vector2) -> void:
	draw_rect(Rect2(center - Vector2(7, 3), Vector2(14, 5)), Color("9b9b96"), true)
	draw_rect(Rect2(center - Vector2(2, 1), Vector2(5, 8)), Color("696b69"), true)

func _draw_manufacturing_yard(rect: Rect2, roof_color: Color) -> void:
	_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 14)), roof_color)
	_draw_table(rect.position + Vector2(8, rect.size.y * 0.48), Vector2(rect.size.x - 16, 8), Color("80603f"))

func _draw_shield(center: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(-7, -8), center + Vector2(7, -8), center + Vector2(5, 4), center + Vector2(0, 10), center + Vector2(-5, 4)]), color)
	draw_rect(Rect2(center + Vector2(-1, -7), Vector2(2, 13)), color.lightened(0.24), true)

func _draw_drum(center: Vector2, color: Color) -> void:
	draw_circle(center, 10, Color("2d2924"))
	draw_circle(center, 8, color)
	draw_circle(center, 3, color.darkened(0.25))
	draw_rect(Rect2(center + Vector2(-10, -1), Vector2(20, 2)), color.lightened(0.16), true)

func _draw_storage_yard(rect: Rect2, definition_id: String) -> void:
	var color: Color = {
		"wood_storage": Color("98602f"), "rock_storage": Color("85827b"), "crystal_storage": Color("58c6d8"),
		"mineral_storage": Color("9a856c"), "food_storage": Color("91a44e"), "gold_storage": Color("d1a83d"),
		"ammo_storage": Color("ac8a59"), "equipment_storage": Color("8b8e91"), "miscellaneous_storage": Color("806d63"),
	}.get(definition_id, Color("8d754f"))
	_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.42, 13)), color.darkened(0.35))
	for index in 6:
		var pos := rect.position + Vector2(rect.size.x * 0.53 + (index % 2) * 9, 7 + (index / 2) * 9)
		draw_rect(Rect2(pos, Vector2(7, 7)), Color("211c18"), true)
		draw_rect(Rect2(pos + Vector2.ONE, Vector2(5, 5)), color.lightened(float(index % 3) * 0.06), true)

func _draw_key(center: Vector2, color: Color) -> void:
	draw_circle(center + Vector2(-5, 0), 5, color)
	draw_circle(center + Vector2(-5, 0), 2, Color("3a2e20"))
	draw_rect(Rect2(center + Vector2(0, -1), Vector2(12, 3)), color, true)
	draw_rect(Rect2(center + Vector2(8, 1), Vector2(3, 5)), color, true)

func _draw_magic_circle(center: Vector2, color: Color, radius: int) -> void:
	draw_arc(center, radius, 0, TAU, 20, color.darkened(0.25), 2.0)
	draw_arc(center, maxi(3, radius - 5), 0, TAU, 16, color, 1.0)
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_rect(Rect2(center + direction * radius - Vector2.ONE, Vector2(3, 3)), color.lightened(0.25), true)

func _draw_fire_pit(center: Vector2, radius: int, crylithium: bool) -> void:
	draw_circle(center, radius, Color("36302b"))
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_rect(Rect2(center + direction * (radius - 2) - Vector2(2, 2), Vector2(4, 4)), Color("85817a"), true)
	var flame := Color("55d7df") if crylithium else Color("e85e28")
	draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 8)), flame, true)
	draw_rect(Rect2(center - Vector2(2, 3), Vector2(4, 5)), flame.lightened(0.30), true)

func _draw_combobulator(rect: Rect2, definition_id: String) -> void:
	var core: Color = {
		"wood_golem_combobulator": Color("9e6532"), "stone_golem_combobulator": Color("8d8a83"),
		"crystal_golem_combobulator": Color("56d2df"), "cube_e_golem_combobulator": Color("77645b"),
	}.get(definition_id, Color("8b7d6f"))
	_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 13)), Color("4d4a46"))
	_draw_magic_circle(rect.get_center() + Vector2(0, 8), core, 13)
	draw_rect(Rect2(rect.get_center() + Vector2(-5, 3), Vector2(10, 10)), core.darkened(0.25), true)
	draw_rect(Rect2(rect.get_center() + Vector2(-3, 5), Vector2(6, 6)), core.lightened(0.20), true)

func _draw_bin(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(center - Vector2(7, 8), Vector2(14, 16)), Color("26221f"), true)
	draw_rect(Rect2(center - Vector2(5, 6), Vector2(10, 13)), color, true)
	draw_rect(Rect2(center - Vector2(7, 9), Vector2(14, 3)), color.lightened(0.16), true)

func _draw_trash(center: Vector2) -> void:
	for offset in [Vector2(-5, 1), Vector2(0, -4), Vector2(5, 2), Vector2(1, 5)]:
		draw_rect(Rect2(center + offset, Vector2(5, 4)), [Color("62564b"), Color("70543e"), Color("4e625a")][posmod(int(offset.x + offset.y), 3)], true)

func _draw_gear(center: Vector2, color: Color) -> void:
	draw_circle(center, 9, color.darkened(0.28))
	draw_circle(center, 6, color)
	draw_circle(center, 2, Color("35302b"))
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_rect(Rect2(center + direction * 9 - Vector2(2, 2), Vector2(4, 4)), color, true)

func _draw_tower(building: Dictionary, rect: Rect2, complete: bool, progress: float) -> void:
	var tower_id := String(building.definition_id)
	var tier := int(building.get("tier", 1))
	var accent: Color = {
		"attract_tower": Color("ca6ee8"), "ballista_tower": Color("c9995a"), "banish_tower": Color("aa7df0"),
		"bow_tower": Color("9bc36a"), "bullet_tower": Color("bab6aa"), "elemental_bolt_tower": Color("56d8ff"),
		"phantom_dart_tower": Color("9d92f3"), "recombobulator_tower": Color("65efcf"), "sling_tower": Color("d2a667"),
		"spray_tower": Color("d9895b"), "static_tower": Color("ffe36c"),
	}.get(tower_id, Color("b8a4d0"))
	if not complete:
		_draw_minimal_construction(building, rect, accent, progress)
		if progress >= 0.5:
			draw_rect(Rect2(rect.get_center() - Vector2(4, 4), Vector2(8, 8)), accent.darkened(0.30), true)
		return
	var center := rect.get_center()
	_draw_open_yard(rect, Color("554f5b"), tier)
	draw_circle(center + Vector2(0, 2), minf(rect.size.x, rect.size.y) * 0.40, Color("332e38"))
	draw_circle(center, minf(rect.size.x, rect.size.y) * 0.29, Color("5f5866") if tier >= 2 else Color("76583b"))
	draw_circle(center, minf(rect.size.x, rect.size.y) * 0.14, accent.darkened(0.22))
	if tier >= 2:
		draw_arc(center, minf(rect.size.x, rect.size.y) * 0.35, 0.0, TAU, 20, Color("96928a"), 3.0)
	if tier >= 3:
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			var post: Vector2 = center + Vector2(direction) * (minf(rect.size.x, rect.size.y) * 0.35)
			draw_rect(Rect2(post - Vector2(3, 3), Vector2(6, 6)), Color("777b7c"), true)
	if tier >= 4:
		for direction in [Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]:
			var node: Vector2 = center + Vector2(direction) * (minf(rect.size.x, rect.size.y) * 0.38)
			_draw_crystal(node, accent.lightened(0.22), 4)
	match tower_id:
		"attract_tower":
			for radius in [5.0, 9.0, 13.0]: draw_arc(center, radius, -0.4, PI * 1.45, 18, accent, 2.0)
		"ballista_tower":
			draw_line(center - Vector2(13, 0), center + Vector2(15, 0), accent, 4.0)
			draw_line(center - Vector2(9, 8), center + Vector2(8, 8), accent.darkened(0.2), 3.0)
		"banish_tower", "elemental_bolt_tower":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -13), center + Vector2(8, 1), center + Vector2(0, 12), center + Vector2(-8, 1)]), accent)
		"bow_tower":
			draw_arc(center - Vector2(3, 0), 12.0, -PI * 0.45, PI * 0.45, 16, accent, 3.0)
			draw_line(center - Vector2(2, 11), center + Vector2(10, 0), accent.lightened(0.2), 2.0)
		"bullet_tower", "sling_tower":
			draw_circle(center, 7.0, accent)
			draw_line(center, center + Vector2(13, -7), accent.darkened(0.22), 4.0)
		"phantom_dart_tower":
			for y_offset in [-7.0, 0.0, 7.0]: draw_line(center + Vector2(-10, y_offset), center + Vector2(11, y_offset - 3), accent, 2.0)
		"recombobulator_tower":
			draw_rect(Rect2(center - Vector2(4, 13), Vector2(8, 26)), accent, true)
			draw_rect(Rect2(center - Vector2(13, 4), Vector2(26, 8)), accent, true)
			draw_circle(center, 4.0, Color("eafff8"))
		"spray_tower":
			for y_offset in [-7.0, 0.0, 7.0]: draw_line(center, center + Vector2(14, y_offset), accent, 3.0)
		"static_tower":
			draw_polyline(PackedVector2Array([center + Vector2(-10, -5), center + Vector2(-3, -2), center + Vector2(-6, 5), center + Vector2(3, 1), center + Vector2(1, 9), center + Vector2(11, 4)]), accent, 3.0)
func _draw_road(building: Dictionary, rect: Rect2, complete: bool, progress: float) -> void:
	var material_color: Color = {
		"path": Color("6c5738"), "log_road": Color("8a5a2d"), "cobble_log_road": Color("7b7160"),
		"cobble_board_road": Color("968066"), "cut_stone_board_road": Color("b0a18d"),
	}.get(String(building.definition_id), Color("75654d"))
	var center := rect.get_center()
	if complete:
		draw_rect(rect, material_color.darkened(0.20), true)
		draw_circle(center, 2.7, material_color)
		var cell := Vector2i(int(building.x), int(building.y))
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if _completed_segment_at(cell + direction, "roads"):
				draw_line(center, center + Vector2(direction) * TILE_PIXELS * 0.6, material_color, 4.0)
	else:
		draw_rect(Rect2(rect.position + Vector2(1, 3), Vector2(6, 1)), Color("c5ab70"), true)
		var laid_width := maxi(1, int(6.0 * progress))
		draw_rect(Rect2(rect.position + Vector2(1, 4), Vector2(laid_width, 3)), material_color, true)

func _draw_wall(building: Dictionary, rect: Rect2, complete: bool, progress: float) -> void:
	var wall_color: Color = {
		"wood_wall": Color("7d4d27"), "wood_gate": Color("93613a"),
		"stone_wall": Color("87847d"), "stone_gate": Color("9c9890"), "curtain_wall": Color("b3aa9b"),
		"crylithium_wall": Color("42b8c6"), "crylithium_curtain_wall": Color("62d9de"), "trashy_cube_wall": Color("51474f"),
	}.get(String(building.definition_id), Color("81766b"))
	if not complete:
		wall_color = wall_color.darkened(0.45)
	var is_gate := String(building.definition_id).ends_with("gate")
	if is_gate:
		if complete:
			draw_rect(rect.grow(-1.0), Color("201914"), true)
			draw_line(rect.position + Vector2(2, rect.size.y - 2), rect.end - Vector2(2, rect.size.y - 2), wall_color, 4.0)
			draw_line(rect.position + Vector2(rect.size.x * 0.5, 1), rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 1), wall_color.lightened(0.18), 2.0)
		else:
			draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(2, 6)), Color("8a5c35"), true)
			draw_rect(Rect2(rect.end - Vector2(4, 6), Vector2(2, 6)), Color("8a5c35"), true)
			draw_line(rect.position + Vector2(3, 3), rect.end - Vector2(3, 4), Color("c5ab70"), 1.0)
	else:
		var center := rect.get_center()
		if complete:
			draw_rect(Rect2(center - Vector2(3, 3), Vector2(6, 6)), wall_color, true)
			var cell := Vector2i(int(building.x), int(building.y))
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if _completed_segment_at(cell + direction, "walls"):
					draw_line(center, center + Vector2(direction) * TILE_PIXELS * 0.65, wall_color, 4.0)
		else:
			draw_rect(Rect2(center - Vector2(1, 3), Vector2(2, 6)), Color("8a5c35"), true)
			draw_rect(Rect2(center + Vector2(-3, -1), Vector2(6, 1)), Color("c5ab70"), true)
	if not complete:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * progress, 2)), Color("f4c95d"), true)

func _completed_segment_at(cell: Vector2i, category: String) -> bool:
	if latest_snapshot == null:
		return false
	for candidate in latest_snapshot.buildings:
		if String(candidate.category) == category and bool(candidate.completed) and not bool(candidate.get("destroyed", false)) and Rect2i(Vector2i(int(candidate.x), int(candidate.y)), Vector2i(int(candidate.width), int(candidate.height))).has_point(cell):
			return true
	return false

func _draw_camp(rect: Rect2, complete: bool, progress: float) -> void:
	draw_rect(rect.grow(-4), Color("315226"), true)
	var tent_color := Color("c98245") if complete else Color("7c6b57")
	var centers := [rect.position + Vector2(22, 28), rect.position + Vector2(rect.size.x - 25, 30), rect.position + Vector2(35, rect.size.y - 26)]
	for center in centers:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-10, 8), center + Vector2(0, -9), center + Vector2(11, 8)]), tent_color)
		draw_line(center + Vector2(0, -9), center + Vector2(0, 8), Color("3b2416"), 2.0)
	var fire := rect.get_center() + Vector2(10, 10)
	draw_circle(fire, 6.0, Color("5b2a16"))
	if complete:
		draw_circle(fire, 4.0, Color("ff8c1a"))
		draw_circle(fire - Vector2(0, 2), 2.0, Color("ffe066"))
	for x in range(int(rect.position.x + 8), int(rect.end.x - 6), 14):
		draw_rect(Rect2(Vector2(x, rect.position.y + 3), Vector2(8, 4)), Color("8b5a2b"), true)

func _draw_villager(villager: Dictionary) -> void:
	var center := (Vector2(float(villager.x), float(villager.y)) * TILE_PIXELS).round()
	var color := Color("5a78a6")
	if villager.job != "idle" and latest_snapshot.jobs.has(villager.job):
		color = Color(latest_snapshot.jobs[villager.job].color)
	var state := String(villager.state)
	if state == "dead" or int(villager.get("health", 1)) <= 0:
		_draw_world_object(center, &"corpse", int(villager.get("id", 0)) % 4)
		return
	var facing := _actor_direction(villager)
	var forward: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][facing]
	var side := Vector2(-forward.y, forward.x)
	if state in ["resting", "sleeping"]:
		draw_rect(Rect2(center + Vector2(-6, 2), Vector2(13, 2)), Color(0.04, 0.03, 0.04, 0.55), true)
		draw_rect(Rect2(center + Vector2(-5, -2), Vector2(10, 5)), Color("24202a"), true)
		draw_rect(Rect2(center + Vector2(-4, -1), Vector2(7, 3)), color, true)
		draw_rect(Rect2(center + Vector2(3, -2), Vector2(4, 4)), Color("d8a06d"), true)
		return
	var moving := state in ["walking", "traveling", "working", "repairing", "dismantling", "fighting", "treating_patient", "intercepting"]
	var step := posmod(int(SimulationHost.tick / 3) + int(villager.id), 2) if moving else 0
	draw_rect(Rect2(center + Vector2(-4, 3), Vector2(9, 2)), Color(0.05, 0.04, 0.04, 0.60), true)
	draw_rect(Rect2(center - Vector2(3, 3), Vector2(6, 6)), Color("24202a"), true)
	draw_rect(Rect2(center - Vector2(2, 2), Vector2(4, 5)), color, true)
	var head_center := center + forward * 5.0
	draw_rect(Rect2(head_center - Vector2(2, 2), Vector2(4, 4)), Color("d8a06d"), true)
	draw_rect(Rect2(head_center - forward * 2.0 - side * 2.0, Vector2(4, 1) if absf(forward.y) > 0.5 else Vector2(1, 4)), Color("3b2b2a"), true)
	draw_rect(Rect2(head_center + forward * 1.0 - Vector2(1, 1), Vector2(2, 2)), Color("f2c18a"), true)
	var back := center - forward * 4.0
	draw_rect(Rect2(back + side * (2.0 + step) - Vector2(1, 1), Vector2(2, 3)), color.darkened(0.22), true)
	draw_rect(Rect2(back - side * (2.0 + step) - Vector2(1, 1), Vector2(2, 3)), color.darkened(0.22), true)
	_draw_job_marker(center, String(villager.job))
	var equipment: Dictionary = villager.get("equipment", {})
	var weapon_id := String(equipment.get("weapon", {}).get("id", ""))
	var hand := center + side * 5.0 + forward
	if weapon_id == "bow":
		draw_line(hand - forward * 5.0, hand + forward * 5.0, Color("c69b58"), 2.0)
		draw_line(hand - forward * 5.0, hand + side * 3.0, Color("e9d9ad"), 1.0)
		draw_line(hand + forward * 5.0, hand + side * 3.0, Color("e9d9ad"), 1.0)
	elif weapon_id.ends_with("sword"):
		draw_line(hand, hand + forward * 7.0 + side * 2.0, Color("d9dde1") if weapon_id == "iron_sword" else Color("a67845"), 2.0)
	if equipment.has("helmet"):
		draw_rect(Rect2(head_center - Vector2(3, 3), Vector2(6, 2)), Color("8f969d") if String(equipment.helmet.id) == "iron_helmet" else Color("9b6d43"), true)
	if equipment.has("shield"):
		draw_rect(Rect2(center - side * 6.0 - Vector2(2, 2), Vector2(5, 5)), Color("969aa0") if String(equipment.shield.id) == "iron_shield" else Color("86552f"), true)
	var status_effects: Dictionary = villager.get("status_effects", {})
	if int(status_effects.get("infection", 0)) > 0:
		draw_circle(center + Vector2(0, -13), 2.0, Color("91bd4b"))
	if state == "fighting":
		draw_line(head_center + side * 3.0, head_center + side * 6.0 + forward * 2.0, Color("ffdc73"), 1.0)
	elif state == "treating_patient":
		_draw_cross(center + Vector2(0, -13), Color("ff75ad"))
	elif state in ["repairing", "dismantling"]:
		draw_line(hand, hand + forward * 7.0, Color("ffd45f"), 2.0)
		draw_rect(Rect2(hand + forward * 7.0 - side * 2.0 - Vector2(1, 1), Vector2(5, 3)), Color("93999e"), true)
	elif state == "drinking":
		_draw_bottle(head_center + side * 3.0, Color("64b7ca"))
	elif state == "eating":
		draw_rect(Rect2(head_center + side * 3.0 - Vector2(1, 1), Vector2(3, 3)), Color("d3bd51"), true)

func _actor_direction(actor: Dictionary) -> int:
	var delta := Vector2(float(actor.get("target_x", actor.get("x", 0.0))) - float(actor.get("x", 0.0)), float(actor.get("target_y", actor.get("y", 0.0))) - float(actor.get("y", 0.0)))
	if delta.length_squared() < 0.04:
		return int(actor.get("id", 0)) % 4
	if absf(delta.x) > absf(delta.y):
		return 1 if delta.x > 0.0 else 3
	return 2 if delta.y > 0.0 else 0

func _draw_job_marker(center: Vector2, job_id: String) -> void:
	var marker := center + Vector2(4, -7)
	match job_id:
		"builders", "maintainers", "toolsmiths":
			draw_line(marker + Vector2(-2, 3), marker + Vector2(2, -2), Color("c58a4b"), 1.0)
			draw_rect(Rect2(marker + Vector2(0, -3), Vector2(4, 2)), Color("a8aaac"), true)
		"organizers", "courier_suppliers":
			draw_rect(Rect2(marker + Vector2(-2, -2), Vector2(5, 5)), Color("b4864d"), true)
			draw_rect(Rect2(marker + Vector2(0, -2), Vector2(1, 5)), Color("6f4b2c"), true)
		"lumberjacks":
			draw_line(marker + Vector2(-2, 3), marker + Vector2(2, -3), Color("a66d37"), 1.0)
			draw_rect(Rect2(marker + Vector2(0, -3), Vector2(4, 2)), Color("afb1af"), true)
		"miners", "stone_cutters":
			draw_line(marker + Vector2(-2, 3), marker + Vector2(1, -3), Color("a66d37"), 1.0)
			draw_rect(Rect2(marker + Vector2(-2, -3), Vector2(6, 1)), Color("afb1af"), true)
		"crystal_harvesters", "crystallers":
			draw_colored_polygon(PackedVector2Array([marker + Vector2(0, -4), marker + Vector2(3, 1), marker + Vector2(0, 4), marker + Vector2(-3, 1)]), Color("58d7df"))
		"farmers":
			draw_rect(Rect2(marker + Vector2(-1, -1), Vector2(2, 5)), Color("7d5a31"), true)
			draw_rect(Rect2(marker + Vector2(-4, -3), Vector2(4, 3)), Color("7aa444"), true)
			draw_rect(Rect2(marker + Vector2(1, -4), Vector2(4, 4)), Color("8cb64d"), true)
		"water_masters", "bottlers":
			draw_rect(Rect2(marker + Vector2(-2, -2), Vector2(5, 6)), Color("4fa9be"), true)
			draw_rect(Rect2(marker + Vector2(-1, -4), Vector2(3, 2)), Color("88d8e1"), true)
		"carpenters", "way_makers":
			draw_rect(Rect2(marker + Vector2(-3, -2), Vector2(7, 2)), Color("aa743c"), true)
			for tooth in 3:
				draw_rect(Rect2(marker + Vector2(-2 + tooth * 2, 0), Vector2(1, 2)), Color("d1d1c8"), true)
		"smelters":
			draw_rect(Rect2(marker + Vector2(-3, -2), Vector2(6, 5)), Color("913d2b"), true)
			draw_rect(Rect2(marker + Vector2(-1, -4), Vector2(3, 5)), Color("f19a36"), true)
		"armorsmiths":
			draw_colored_polygon(PackedVector2Array([marker + Vector2(-3, -3), marker + Vector2(3, -3), marker + Vector2(2, 2), marker, marker + Vector2(-2, 2)]), Color("a8aaac"))
		"fletchers", "rangers":
			draw_arc(marker, 4, -PI * 0.5, PI * 0.5, 5, Color("bc8548"), 1.0)
			draw_rect(Rect2(marker + Vector2(0, -4), Vector2(1, 8)), Color("ded4aa"), true)
		"tumblers":
			draw_rect(Rect2(marker + Vector2(-3, -3), Vector2(6, 6)), Color("858580"), true)
			draw_rect(Rect2(marker + Vector2(-1, -1), Vector2(2, 2)), Color("575a58"), true)
		"cooks":
			draw_rect(Rect2(marker + Vector2(-3, -1), Vector2(7, 4)), Color("d9d2ba"), true)
			draw_rect(Rect2(marker + Vector2(-2, -4), Vector2(5, 3)), Color("eee8d5"), true)
		"medics":
			_draw_cross(marker, Color("ef6673"))
		"provisioners":
			draw_rect(Rect2(marker + Vector2(-3, -3), Vector2(6, 6)), Color("d2ad42"), true)
			draw_rect(Rect2(marker + Vector2(-1, -2), Vector2(2, 4)), Color("7c6127"), true)
		"trashers":
			draw_rect(Rect2(marker + Vector2(-3, -3), Vector2(6, 7)), Color("625753"), true)
			draw_rect(Rect2(marker + Vector2(-4, -4), Vector2(8, 2)), Color("887771"), true)
		"occultists":
			draw_colored_polygon(PackedVector2Array([marker + Vector2(0, -4), marker + Vector2(4, 2), marker + Vector2(0, 4), marker + Vector2(-4, 2)]), Color("9d72c7"))
		_:
			pass

func _draw_monster(monster: Dictionary) -> void:
	var center := (Vector2(float(monster.x), float(monster.y)) * TILE_PIXELS).round()
	var monster_id := String(monster.definition_id)
	var facing := _actor_direction(monster)
	var forward: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][facing]
	var side := Vector2(-forward.y, forward.x)
	var head_center := center + forward * 5.0
	var color: Color = {
		"headless": Color("773443"), "small_slime": Color("557d22"), "slime": Color("406419"),
		"blood_slime": Color("a51f3d"), "trashy_slime": Color("695b50"), "zombie": Color("6e7b55"),
		"skeleton": Color("d4cab0"), "spectre": Color(0.58, 0.72, 1.0, 0.72), "fire_elemental": Color("f0652f"), "drone": Color("7d3f91")
	}.get(monster_id, Color("963855"))
	draw_rect(Rect2(center + Vector2(-5, 4), Vector2(11, 2)), Color(0.04, 0.03, 0.04, 0.65), true)
	match monster_id:
		"small_slime", "slime", "blood_slime", "trashy_slime":
			var width := 8 if monster_id == "small_slime" else 12
			draw_rect(Rect2(center + Vector2(-width / 2.0, -4), Vector2(width, 8)), color, true)
			draw_rect(Rect2(center + Vector2(-width / 2.0 + 2, -6), Vector2(width - 4, 3)), color.lightened(0.12), true)
			var eye_line := center + forward * 2.0
			draw_rect(Rect2(eye_line + side * 2.0 - Vector2(1, 1), Vector2(2, 2)), Color("171318"), true)
			draw_rect(Rect2(eye_line - side * 2.0 - Vector2(1, 1), Vector2(2, 2)), Color("171318"), true)
		"skeleton":
			draw_rect(Rect2(head_center - Vector2(3, 3), Vector2(6, 5)), color, true)
			draw_line(center - forward * 3.0, center + forward * 2.0, color, 2.0)
			draw_line(center, center + side * 6.0 - forward * 2.0, color, 1.0)
			draw_line(center, center - side * 6.0 - forward * 2.0, color, 1.0)
		"spectre":
			draw_rect(Rect2(center + Vector2(-4, -8), Vector2(8, 7)), color, true)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -1), center + Vector2(-2, 6), center + Vector2(0, 3), center + Vector2(3, 7), center + Vector2(4, -1)]), color)
		"fire_elemental":
			draw_rect(Rect2(center + Vector2(-4, -3), Vector2(8, 8)), color, true)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -2), center + Vector2(-2, -9), center + Vector2(0, -4), center + Vector2(3, -10), center + Vector2(4, -2)]), color.lightened(0.15))
			draw_rect(Rect2(center + Vector2(-1, -3), Vector2(3, 5)), Color("ffd25a"), true)
		"drone":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -8), center + Vector2(7, 0), center + Vector2(0, 7), center + Vector2(-7, 0)]), color)
			draw_rect(Rect2(center + Vector2(-2, -2), Vector2(4, 4)), Color("d36fce"), true)
		_:
			draw_rect(Rect2(center + Vector2(-3, -4), Vector2(6, 9)), color, true)
			if monster_id != "headless":
				draw_rect(Rect2(head_center - Vector2(2, 2), Vector2(4, 4)), color.lightened(0.14), true)
			draw_rect(Rect2(center + side * 4.0 - Vector2(1, 2), Vector2(2, 7)), color.darkened(0.12), true)
			draw_rect(Rect2(center - side * 4.0 - Vector2(1, 2), Vector2(2, 7)), color.darkened(0.12), true)
	var ratio := float(monster.health) / maxf(1.0, float(monster.max_health))
	draw_rect(Rect2(center + Vector2(-6, -12), Vector2(12, 2)), Color("321214"), true)
	draw_rect(Rect2(center + Vector2(-6, -12), Vector2(12.0 * ratio, 2)), Color("e64e53"), true)
	if String(monster.state) == "recovering":
		draw_rect(Rect2(center + Vector2(-5, 7), Vector2(10, 1)), Color("f7c96b"), true)

func _draw_golem(golem: Dictionary) -> void:
	var center := (Vector2(float(golem.x), float(golem.y)) * TILE_PIXELS).round()
	var golem_type := String(golem.definition_id)
	var color: Color = {
		"labor_golem": Color("d5b36d"), "holy_golem": Color("f2eab4"),
		"wood_golem": Color("80532f"), "stone_golem": Color("858985"),
		"crystal_golem": Color("41d9ed"), "cube_e_golem": Color("9a7250"),
	}.get(golem_type, Color("9d8d76"))
	var facing := _actor_direction(golem)
	var forward: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][facing]
	var side := Vector2(-forward.y, forward.x)
	var moving := String(golem.get("state", "")) in ["intercepting", "traveling_to_build", "traveling_to_harvest", "attacking"]
	var step := posmod(int(SimulationHost.tick / 4) + int(golem.get("id", 0)), 2) if moving else 0
	draw_rect(Rect2(center + Vector2(-7, 5), Vector2(15, 3)), Color(0.03, 0.03, 0.03, 0.65), true)
	var block := 3 if golem_type == "cube_e_golem" else 4
	draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), color.darkened(0.18), true)
	draw_rect(Rect2(center + forward * 5.0 - Vector2(4, 3), Vector2(8, 6)), color.lightened(0.16), true)
	draw_rect(Rect2(center + side * 8.0 - Vector2(floori(block * 0.5), 4), Vector2(block, 9)), color, true)
	draw_rect(Rect2(center - side * 8.0 - Vector2(floori(block * 0.5), 4), Vector2(block, 9)), color, true)
	var back := center - forward * 6.0
	draw_rect(Rect2(back + side * (3.0 + step) - Vector2(2, 2), Vector2(4, 5)), color.darkened(0.10), true)
	draw_rect(Rect2(back - side * (3.0 + step) - Vector2(2, 2), Vector2(4, 5)), color.darkened(0.10), true)
	var core_color := Color("75f1ff") if golem_type in ["holy_golem", "crystal_golem"] else Color("ffcf6b")
	draw_rect(Rect2(center - Vector2(2, 3), Vector2(4, 4)), core_color, true)
	var ratio := float(golem.health) / maxf(1.0, float(golem.max_health))
	draw_rect(Rect2(center + Vector2(-7, -13), Vector2(14, 2)), Color("172029"), true)
	draw_rect(Rect2(center + Vector2(-7, -13), Vector2(14.0 * ratio, 2)), Color("70f0b8"), true)
	if String(golem.get("state", "")) == "attacking":
		draw_line(center + side * 7.0, center + side * 10.0 + forward * 5.0, Color("ffcf6b"), 2.0)

func _draw_animal(animal: Dictionary) -> void:
	var center := (Vector2(float(animal.x), float(animal.y)) * TILE_PIXELS).round()
	var animal_id := String(animal.definition_id)
	var color: Color = {
		"beefalo": Color("8d5a35"), "entler": Color("7b7136"), "rous": Color("8c6a78"),
		"clucker": Color("e2d4a4"), "doggo": Color("c69255"), "doofy_doggo": Color("bb7e50")
	}.get(animal_id, Color("9b825f"))
	if bool(animal.get("slaughtered", false)) or int(animal.get("health", 1)) <= 0:
		_draw_world_object(center, &"corpse", int(animal.get("id", 0)) % 4)
		return
	var facing := _actor_direction(animal)
	var forward: Vector2 = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][facing]
	var side := Vector2(-forward.y, forward.x)
	var head_center := center + forward * 5.0
	var back_center := center - forward * 5.0
	var moving := String(animal.get("state", "")) in ["wandering", "unhoused", "fighting", "defending"]
	var step := posmod(int(SimulationHost.tick / 4) + int(animal.get("id", 0)), 2) if moving else 0
	draw_rect(Rect2(center + Vector2(-5, 4), Vector2(11, 2)), Color(0.03, 0.03, 0.03, 0.55), true)
	match animal_id:
		"beefalo":
			draw_rect(Rect2(center + Vector2(-6, -4), Vector2(11, 9)), color, true)
			draw_rect(Rect2(head_center - Vector2(3, 3), Vector2(6, 6)), color.lightened(0.10), true)
			draw_line(head_center + side * 2.0, head_center + side * 5.0 - forward * 2.0, Color("d5c190"), 1.0)
			draw_line(head_center - side * 2.0, head_center - side * 5.0 - forward * 2.0, Color("d5c190"), 1.0)
		"entler":
			draw_rect(Rect2(center + Vector2(-5, -3), Vector2(10, 7)), color, true)
			draw_rect(Rect2(head_center - Vector2(3, 3), Vector2(5, 5)), color.lightened(0.12), true)
			draw_line(head_center + side * 2.0, head_center + side * 5.0 - forward * 4.0, Color("b9a66b"), 1.0)
			draw_line(head_center - side * 2.0, head_center - side * 5.0 - forward * 4.0, Color("b9a66b"), 1.0)
		"clucker":
			draw_rect(Rect2(center + Vector2(-3, -3), Vector2(6, 7)), color, true)
			draw_rect(Rect2(head_center - Vector2(2, 2), Vector2(4, 4)), color.lightened(0.12), true)
			draw_rect(Rect2(head_center + forward * 2.0 - Vector2(1, 1), Vector2(2, 2)), Color("d8a140"), true)
		"doggo", "doofy_doggo":
			draw_rect(Rect2(center + Vector2(-5, -3), Vector2(9, 7)), color, true)
			draw_rect(Rect2(head_center - Vector2(3, 3), Vector2(5, 5)), color.lightened(0.10), true)
			draw_rect(Rect2(head_center + side * 2.0 - forward * 2.0 - Vector2(1, 1), Vector2(2, 3)), color.darkened(0.15), true)
			draw_rect(Rect2(head_center - side * 2.0 - forward * 2.0 - Vector2(1, 1), Vector2(2, 3)), color.darkened(0.15), true)
			draw_line(back_center, back_center - forward * 4.0 + side * 3.0, color, 2.0)
		_:
			draw_rect(Rect2(center + Vector2(-4, -3), Vector2(8, 7)), color, true)
			draw_rect(Rect2(head_center - Vector2(2, 2), Vector2(4, 5)), color.lightened(0.12), true)
	# Two-frame feet reinforce travel direction without increasing the silhouette.
	if animal_id != "clucker":
		draw_rect(Rect2(center - forward * 3.0 + side * (3.0 + step) - Vector2(1, 1), Vector2(2, 3)), color.darkened(0.22), true)
		draw_rect(Rect2(center - forward * 3.0 - side * (3.0 + step) - Vector2(1, 1), Vector2(2, 3)), color.darkened(0.22), true)
	if bool(animal.get("domesticated", false)):
		draw_rect(Rect2(center + Vector2(-5, 7), Vector2(10, 1)), Color("70f0b8"), true)
	if String(animal.get("state", "")) == "fighting":
		draw_line(center + Vector2(3, -4), center + Vector2(8, -8), Color("ffdc73"), 2.0)

func _draw_ghost(ghost: Dictionary) -> void:
	var center := (Vector2(float(ghost.x), float(ghost.y)) * TILE_PIXELS).round()
	var color := Color(0.55, 0.93, 1.0, 0.80) if not bool(ghost.bound) else Color(0.73, 0.55, 1.0, 0.9)
	draw_rect(Rect2(center + Vector2(-5, -7), Vector2(10, 11)), Color(color.r, color.g, color.b, 0.16), true)
	draw_rect(Rect2(center + Vector2(-3, -6), Vector2(6, 7)), color, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-3, 1), center + Vector2(-2, 7), center + Vector2(0, 4), center + Vector2(3, 8), center + Vector2(3, 1)]), color)

func _draw_corruption(cells: Array) -> void:
	var occupied: Dictionary = {}
	for position_data in cells:
		occupied["%d:%d" % [int(position_data[0]), int(position_data[1])]] = true
	for position_data in cells:
		var cell := Vector2i(int(position_data[0]), int(position_data[1]))
		var rect := Rect2(Vector2(cell) * TILE_PIXELS, Vector2.ONE * TILE_PIXELS)
		var pulse := 0.025 * sin(float(cell.x * 5 + cell.y * 3 + SimulationHost.tick) * 0.07)
		var base := Color(0.30 + pulse, 0.025, 0.23 + pulse, 0.84)
		draw_rect(rect, base, true)
		if posmod(cell.x * 13 + cell.y * 7, 5) == 0:
			draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(3, 3)), Color(0.48, 0.05, 0.38, 0.72), true)
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if occupied.has("%d:%d" % [cell.x + direction.x, cell.y + direction.y]):
				continue
			if direction == Vector2i.LEFT: draw_rect(Rect2(rect.position, Vector2(1, TILE_PIXELS)), Color("7e3269"), true)
			elif direction == Vector2i.RIGHT: draw_rect(Rect2(rect.position + Vector2(TILE_PIXELS - 1, 0), Vector2(1, TILE_PIXELS)), Color("7e3269"), true)
			elif direction == Vector2i.UP: draw_rect(Rect2(rect.position, Vector2(TILE_PIXELS, 1)), Color("7e3269"), true)
			else: draw_rect(Rect2(rect.position + Vector2(0, TILE_PIXELS - 1), Vector2(TILE_PIXELS, 1)), Color("7e3269"), true)

func _draw_weather(snapshot: SimulationSnapshot) -> void:
	if snapshot.weather not in [&"rain", &"snow"] and snapshot.active_event not in [&"hail", &"meteor_shower", &"lightning_storm"]:
		return
	var visible_size := get_viewport_rect().size / camera.zoom
	var visible_rect := Rect2(camera.position - visible_size * 0.5, visible_size)
	for index in 360:
		var seed := index * 7919 + snapshot.tick * (3 if snapshot.weather == &"rain" else 1)
		var x := visible_rect.position.x + float(posmod(seed * 31, maxi(1, int(visible_rect.size.x))))
		var y := visible_rect.position.y + float(posmod(seed * 17, maxi(1, int(visible_rect.size.y))))
		if snapshot.weather == &"snow":
			draw_circle(Vector2(x, y), 1.8, Color(0.92, 0.97, 1.0, 0.72))
		elif snapshot.weather == &"rain":
			draw_line(Vector2(x, y), Vector2(x - 3, y + 9), Color(0.42, 0.72, 0.94, 0.55), 1.0)
		if snapshot.active_event == &"hail":
			draw_circle(Vector2(x, y), 2.2, Color(0.75, 0.91, 1.0, 0.82))
		elif snapshot.active_event == &"meteor_shower":
			draw_line(Vector2(x, y), Vector2(x + 9, y + 5), Color(0.96, 0.42, 0.18, 0.75), 2.0)
		elif snapshot.active_event == &"lightning_storm":
			if index < 8 and snapshot.tick % 18 < 3:
				draw_line(Vector2(x, y - 40), Vector2(x - 8, y), Color(1.0, 0.95, 0.5, 0.88), 2.0)

func _draw_event_atmosphere(snapshot: SimulationSnapshot) -> void:
	if snapshot.active_event.is_empty():
		return
	var world_size := Vector2(current_blueprint.width, current_blueprint.height) * TILE_PIXELS
	match snapshot.active_event:
		&"full_moon":
			draw_rect(Rect2(Vector2.ZERO, world_size), Color(0.18, 0.32, 0.48, 0.12), true)
		&"blood_moon":
			draw_rect(Rect2(Vector2.ZERO, world_size), Color(0.42, 0.02, 0.03, 0.15), true)
		&"eclipse":
			draw_rect(Rect2(Vector2.ZERO, world_size), Color(0.02, 0.02, 0.07, 0.50), true)
		&"earthquake":
			for index in 48:
				var x := float(posmod(index * 607 + snapshot.tick / 4, int(world_size.x)))
				var y := float(posmod(index * 349 + snapshot.tick / 7, int(world_size.y)))
				draw_line(Vector2(x, y), Vector2(x + 9, y + 5), Color(0.16, 0.10, 0.06, 0.72), 2.0)
				draw_line(Vector2(x + 9, y + 5), Vector2(x + 5, y + 11), Color(0.16, 0.10, 0.06, 0.55), 1.0)
		&"blight":
			draw_rect(Rect2(Vector2.ZERO, world_size), Color(0.20, 0.28, 0.04, 0.12), true)
			var visible_size := get_viewport_rect().size / camera.zoom
			var visible_rect := Rect2(camera.position - visible_size * 0.5, visible_size)
			for index in 90:
				var x := visible_rect.position.x + float(posmod(index * 421 + snapshot.tick, maxi(1, int(visible_rect.size.x))))
				var y := visible_rect.position.y + float(posmod(index * 239 - snapshot.tick, maxi(1, int(visible_rect.size.y))))
				draw_rect(Rect2(Vector2(x, y), Vector2(2, 2)), Color(0.55, 0.65, 0.18, 0.62), true)
		&"comet":
			var travel := float(posmod(snapshot.tick * 13, int(world_size.x + 400.0))) - 200.0
			var head := Vector2(travel, world_size.y * 0.32)
			draw_line(head - Vector2(120, 70), head, Color(0.32, 0.78, 0.91, 0.76), 6.0)
			draw_rect(Rect2(head - Vector2(7, 7), Vector2(14, 14)), Color("d9f6ef"), true)

func _draw_night_tint(day_fraction: float) -> void:
	var night_strength := 0.0
	if day_fraction < 0.18:
		night_strength = 0.44 * (1.0 - day_fraction / 0.18)
	elif day_fraction > 0.76:
		night_strength = 0.44 * ((day_fraction - 0.76) / 0.24)
	if night_strength > 0.01:
		draw_rect(Rect2(Vector2.ZERO, Vector2(current_blueprint.width, current_blueprint.height) * TILE_PIXELS), Color(0.02, 0.04, 0.13, night_strength), true)

func _draw_placement_ghost() -> void:
	var definition := ContentRegistry.get_by_id(&"buildings", pending_building_id)
	var footprint_data: Array = definition.get("footprint", [1, 1])
	var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
	var valid := _is_valid_placement(pointer_cell, footprint)
	var color := Color(0.18, 1.0, 0.62, 0.42) if valid else Color(1.0, 0.18, 0.18, 0.48)
	var rect := Rect2(Vector2(pointer_cell) * TILE_PIXELS, Vector2(footprint) * TILE_PIXELS)
	draw_rect(rect, color, true)
	draw_rect(rect, color.lightened(0.3), false, 3.0)

func _draw_spell_target() -> void:
	var radius := SimulationHost._spell_radius(pending_spell_id) * TILE_PIXELS
	var center := (Vector2(pointer_cell) + Vector2(0.5, 0.5)) * TILE_PIXELS
	var color := _spell_color(pending_spell_id)
	draw_circle(center, radius, Color(color.r, color.g, color.b, 0.12))
	draw_arc(center, radius, 0.0, TAU, 32, color, 2.0)
	_draw_spell_glyph(center, pending_spell_id, color)

func _draw_spell_effects(current_tick: int) -> void:
	var retained: Array[Dictionary] = []
	for effect in visual_effects:
		if int(effect.end_tick) < current_tick:
			continue
		retained.append(effect)
		var spell_id := StringName(effect.spell_id)
		var center := (Vector2(float(effect.cell_x), float(effect.cell_y)) + Vector2(0.5, 0.5)) * TILE_PIXELS
		var radius := float(effect.radius) * TILE_PIXELS
		var age := current_tick - int(effect.started_tick)
		var life := clampf(float(int(effect.end_tick) - current_tick) / maxf(1.0, float(int(effect.end_tick) - int(effect.started_tick))), 0.0, 1.0)
		var color := _spell_color(spell_id)
		match String(spell_id):
			"lightning_bolt":
				var points := PackedVector2Array([center + Vector2(-4, -radius), center + Vector2(3, -radius * 0.55), center + Vector2(-2, -radius * 0.20), center + Vector2(4, radius * 0.18), center + Vector2(0, radius * 0.60)])
				draw_polyline(points, color, 3.0)
				draw_rect(Rect2(center - Vector2(5, 2), Vector2(10, 4)), Color("f4f5d5"), true)
			"meteor", "comet":
				var impact_size := 12 if spell_id == &"meteor" else 18
				draw_line(center + Vector2(-radius * 0.6, -radius * 0.6), center, color.darkened(0.18), 5.0)
				draw_rect(Rect2(center - Vector2(impact_size / 2.0, impact_size / 2.0), Vector2(impact_size, impact_size)), color, true)
				draw_rect(Rect2(center - Vector2(impact_size * 0.2, impact_size * 0.2), Vector2(impact_size * 0.4, impact_size * 0.4)), color.lightened(0.30), true)
			"earthquake":
				for offset in [-10.0, 0.0, 11.0]:
					draw_polyline(PackedVector2Array([center + Vector2(-radius, offset - 4), center + Vector2(-radius * 0.35, offset + 2), center + Vector2(0, offset - 3), center + Vector2(radius * 0.55, offset + 3), center + Vector2(radius, offset)]), color, 2.0)
			"flame":
				for index in 7:
					var offset := Vector2(posmod(index * 11 + age * 3, int(radius * 1.6 + 1)) - radius * 0.8, posmod(index * 7, int(radius * 1.2 + 1)) - radius * 0.6)
					draw_rect(Rect2(center + offset, Vector2(4, 6)), color.lightened(float(index % 3) * 0.10), true)
			"storm":
				for index in 12:
					var offset := Vector2(posmod(index * 19 + age * 2, int(radius * 2.0 + 1)) - radius, posmod(index * 13 + age * 5, int(radius * 2.0 + 1)) - radius)
					draw_line(center + offset, center + offset + Vector2(-3, 9), color, 1.0)
			"magic_bolts":
				for index in 6:
					var angle := TAU * float(index) / 6.0 + age * 0.18
					var point := center + Vector2(cos(angle), sin(angle)) * minf(radius, 12.0 + age)
					draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), color, true)
			"banish", "dissolve", "dispel_god_structure", "dispel_golem":
				draw_arc(center, radius * (1.0 - life * 0.45), 0, TAU, 24, color, 3.0)
				draw_line(center - Vector2(radius * 0.55, radius * 0.55), center + Vector2(radius * 0.55, radius * 0.55), color, 2.0)
				draw_line(center + Vector2(radius * 0.55, -radius * 0.55), center + Vector2(-radius * 0.55, radius * 0.55), color, 2.0)
			"god_wall":
				for x in range(int(center.x - radius), int(center.x + radius), 7):
					draw_rect(Rect2(Vector2(x, center.y - 3), Vector2(5, 7)), color, true)
			"god_tower":
				draw_rect(Rect2(center - Vector2(7, 7), Vector2(14, 14)), color.darkened(0.24), true)
				draw_rect(Rect2(center - Vector2(3, 11), Vector2(6, 22)), color, true)
			"summon_labor_golem", "summon_holy_golem", "resurrect":
				draw_arc(center, radius * 0.55, -PI * 0.5, PI * 1.5, 20, color, 2.0)
				for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
					draw_rect(Rect2(center + direction * radius * 0.55 - Vector2(2, 2), Vector2(4, 4)), color.lightened(0.24), true)
			_:
				draw_arc(center, radius * (0.72 + 0.12 * sin(age * 0.4)), 0, TAU, 24, Color(color.r, color.g, color.b, life), 2.0)
				for index in 8:
					var angle := TAU * float(index) / 8.0
					var point := center + Vector2(cos(angle), sin(angle)) * radius * 0.55
					draw_rect(Rect2(point - Vector2.ONE, Vector2(3, 3)), Color(color.r, color.g, color.b, life), true)
	visual_effects = retained

func _spell_color(spell_id: StringName) -> Color:
	return SPELL_PIXEL_COLORS.get(spell_id, Color("77dbea"))

func _draw_spell_glyph(center: Vector2, spell_id: StringName, color: Color) -> void:
	match String(spell_id):
		"healing_aura", "regenerate", "mend", "resurrect":
			_draw_cross(center, color)
		"lightning_bolt":
			draw_polyline(PackedVector2Array([center + Vector2(-2, -8), center + Vector2(3, -2), center + Vector2(-1, 1), center + Vector2(4, 8)]), color, 2.0)
		"flame", "meteor":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 6), center + Vector2(-2, -7), center + Vector2(1, -2), center + Vector2(4, -8), center + Vector2(6, 6)]), color)
		"cold_aura", "comet", "storm":
			draw_rect(Rect2(center + Vector2(-1, -8), Vector2(3, 16)), color, true)
			draw_rect(Rect2(center + Vector2(-8, -1), Vector2(16, 3)), color, true)
			draw_line(center + Vector2(-6, -6), center + Vector2(6, 6), color, 1.0)
			draw_line(center + Vector2(6, -6), center + Vector2(-6, 6), color, 1.0)
		"harvest", "holy_potatoes", "holy_wood", "motivate_land":
			draw_rect(Rect2(center + Vector2(-1, -2), Vector2(2, 10)), Color("7e5c32"), true)
			draw_rect(Rect2(center + Vector2(-7, -7), Vector2(7, 6)), color, true)
			draw_rect(Rect2(center + Vector2(1, -8), Vector2(7, 7)), color.lightened(0.12), true)
		"banish", "dissolve", "dispel_god_structure", "dispel_golem":
			draw_line(center - Vector2(7, 7), center + Vector2(7, 7), color, 2.0)
			draw_line(center + Vector2(7, -7), center - Vector2(7, -7), color, 2.0)
		_:
			draw_rect(Rect2(center - Vector2(1, 7), Vector2(3, 15)), color, true)
			draw_rect(Rect2(center - Vector2(7, 1), Vector2(15, 3)), color, true)
