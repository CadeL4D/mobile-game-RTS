class_name WorldView
extends Node2D

signal placement_changed(building_id: StringName)
signal placement_rejected(reason: String)
signal entity_selected(kind: StringName, entity_id: int)
signal spell_changed(spell_id: StringName)
signal terrain_action_changed(action: StringName)

const TILE_PIXELS := 8.0
const MIN_ZOOM := 0.32
const MAX_ZOOM := 2.4
const TERRAIN_TILE_KIND_COUNT := 9
const TERRAIN_MASK_PIXELS_PER_CELL := 4
const TERRAIN_TEXTURE_CACHE_LIMIT := 3
const TERRAIN_CHUNK_CELLS := 32
const TERRAIN_CHUNK_RENDERER := preload("res://presentation/scripts/terrain_chunk_renderer.gd")
const CORRUPTION_OVERLAY_SHADER := preload("res://presentation/shaders/corruption_overlay.gdshader")
const TERRAIN_EFFECT_OVERLAY_SHADER := preload("res://presentation/shaders/terrain_effect_overlay.gdshader")
const RESOURCE_LOD_OVERLAY_SHADER := preload("res://presentation/shaders/resource_lod_overlay.gdshader")
const TERRAIN_MASK_CHANNEL_COLORS := [Color(1.0, 0.0, 0.0), Color(0.0, 1.0, 0.0), Color(0.0, 0.0, 1.0)]
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
var corruption_overlay_sprite: Sprite2D
var terrain_effect_overlay_sprite: Sprite2D
var resource_lod_overlay_sprite: Sprite2D
var camera: Camera2D
var pending_building_id: StringName = &""
var pending_spell_id: StringName = &""
var pending_terrain_action: StringName = &""
var pointer_cell := Vector2i.ZERO
var last_drawn_camera_state := Vector3.INF
var debug_draw_count := 0

var dragging := false
var drag_distance := 0.0
var touch_points: Dictionary = {}
var last_pinch_distance := 0.0
var last_tap_msec: int = 0
var last_tap_cell: Vector2i = Vector2i(-999, -999)
var latest_snapshot: SimulationSnapshot
var current_blueprint: RegionBlueprint
var terrain_season: StringName = &"Spring"
var season_pattern_noise := FastNoiseLite.new()
var terrain_relief_noise := FastNoiseLite.new()
var terrain_patch_noise := FastNoiseLite.new()
var terrain_detail_noise := FastNoiseLite.new()
var terrain_texture_cache: Dictionary = {}
var terrain_texture_cache_order: Array[String] = []
var terrain_preview_image: Image
var terrain_chunk_sprites: Dictionary = {}
var terrain_chunk_queue: Array[Dictionary] = []
var terrain_chunk_queued_revisions: Dictionary = {}
var terrain_chunk_active: Dictionary = {}
var terrain_chunk_revisions: Dictionary = {}
var terrain_chunk_generation := 0
var terrain_chunk_task_sequence := 0
var terrain_tile_snapshot := PackedByteArray()
var terrain_elevation_snapshot := PackedByteArray()
var terrain_chunk_priority_cell := Vector2i(-999, -999)
var terrain_chunk_started_usec := 0
var terrain_preview_ready_ms := 0.0
var terrain_first_chunk_ready_ms := -1.0
var terrain_all_chunks_ready_ms := -1.0
var terrain_water_accents: Array[Dictionary] = []
var selected_kind: StringName = &""
var selected_entity_id := 0
var brush_cells_this_gesture: Dictionary = {}
var visual_effects: Array[Dictionary] = []
var corruption_overlay_hash := 0
var terrain_effect_overlay_hash := 0
var resource_lod_overlay_hash := 0
var draw_profile_usec: Dictionary = {}

func _ready() -> void:
	terrain_sprite = Sprite2D.new()
	terrain_sprite.centered = false
	terrain_sprite.z_index = -100
	terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terrain_sprite.scale = Vector2.ONE
	add_child(terrain_sprite)
	corruption_overlay_sprite = _create_surface_overlay_sprite(CORRUPTION_OVERLAY_SHADER, -82)
	corruption_overlay_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	terrain_effect_overlay_sprite = _create_surface_overlay_sprite(TERRAIN_EFFECT_OVERLAY_SHADER, -76)
	terrain_effect_overlay_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resource_lod_overlay_sprite = _create_surface_overlay_sprite(RESOURCE_LOD_OVERLAY_SHADER, -68)
	camera = Camera2D.new()
	camera.enabled = false
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 10.0
	add_child(camera)
	SimulationHost.region_started.connect(_on_region_started)
	SimulationHost.snapshot_updated.connect(_on_snapshot_updated)
	SimulationHost.sim_event.connect(_on_sim_event)
	set_process_unhandled_input(true)
	set_process(true)

func _exit_tree() -> void:
	# Threads only read immutable payloads, but they must be joined before the
	# WorldView and their isolated renderer instances are released.
	for task_data in terrain_chunk_active.values():
		var thread: Thread = task_data.thread
		if thread.is_started():
			thread.wait_to_finish()
	terrain_chunk_active.clear()

func _process(_delta: float) -> void:
	# The camera keeps gliding after input ends because of position smoothing, and
	# culling is computed per draw, so a moved camera has to force a redraw. Beyond
	# that the world is redrawn only when its contents change, rather than every
	# frame against an unchanged snapshot.
	if camera != null:
		var camera_state := Vector3(camera.position.x, camera.position.y, camera.zoom.x)
		if camera_state != last_drawn_camera_state:
			last_drawn_camera_state = camera_state
			queue_redraw()
	_poll_terrain_chunk_workers()
	var priority_cell := Vector2i(floori(camera.position.x / (TILE_PIXELS * TERRAIN_CHUNK_CELLS)), floori(camera.position.y / (TILE_PIXELS * TERRAIN_CHUNK_CELLS))) if camera != null else Vector2i.ZERO
	if priority_cell != terrain_chunk_priority_cell and not terrain_chunk_queue.is_empty():
		terrain_chunk_priority_cell = priority_cell
		_sort_terrain_chunk_queue(priority_cell)
	_start_terrain_chunk_workers()

func _on_region_started(blueprint: RegionBlueprint) -> void:
	current_blueprint = blueprint
	corruption_overlay_hash = 0
	terrain_effect_overlay_hash = 0
	resource_lod_overlay_hash = 0
	corruption_overlay_sprite.visible = false
	terrain_effect_overlay_sprite.visible = false
	resource_lod_overlay_sprite.visible = false
	terrain_season = &"Spring"
	season_pattern_noise.seed = blueprint.seed ^ 0x51f15e
	season_pattern_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	season_pattern_noise.frequency = 0.032
	terrain_relief_noise.seed = blueprint.seed ^ 0x24a7c15d
	terrain_relief_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Noise images use ownership pixels. Scale their frequencies so experiments at
	# different mask resolutions preserve the same world-space feature sizes.
	var terrain_noise_scale := TILE_PIXELS / float(TERRAIN_MASK_PIXELS_PER_CELL)
	terrain_relief_noise.frequency = 0.0042 * terrain_noise_scale
	terrain_patch_noise.seed = blueprint.seed ^ 0x1f123bb5
	terrain_patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_patch_noise.frequency = 0.0125 * terrain_noise_scale
	terrain_detail_noise.seed = blueprint.seed ^ 0x68bc21eb
	terrain_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	terrain_detail_noise.frequency = 0.038 * terrain_noise_scale
	camera.enabled = true
	camera.position = Vector2(blueprint.starting_cell) * TILE_PIXELS
	camera.zoom = Vector2(0.78, 0.78)
	_prepare_terrain_water_accents(blueprint)
	_restart_terrain_chunk_generation()
	pending_building_id = &"camp"
	pointer_cell = blueprint.starting_cell - Vector2i(6, 6)
	placement_changed.emit(pending_building_id)
	queue_redraw()

func _on_snapshot_updated(snapshot: SimulationSnapshot) -> void:
	latest_snapshot = snapshot
	_update_corruption_overlay(snapshot.corruption_cells)
	_update_terrain_effect_overlay(snapshot.terrain_effects)
	_update_resource_lod_overlay(snapshot.resource_nodes)
	if current_blueprint != null and snapshot.season != terrain_season:
		terrain_season = snapshot.season
		_restart_terrain_chunk_generation()
	queue_redraw()

func _create_surface_overlay_sprite(shader: Shader, layer: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.z_index = layer
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * TILE_PIXELS
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	sprite.material = shader_material
	add_child(sprite)
	return sprite

func _update_corruption_overlay(cells: Array) -> void:
	if current_blueprint == null:
		return
	var next_hash := hash(cells)
	# Close zoom deliberately hides this cached wide-view mask in _draw().  Do not
	# mistake that presentation choice for stale data and rebuild an unchanged mask
	# every snapshot.
	if next_hash == corruption_overlay_hash and (cells.is_empty() or corruption_overlay_sprite.texture != null):
		return
	corruption_overlay_hash = next_hash
	if cells.is_empty():
		corruption_overlay_sprite.visible = false
		return
	var mask := Image.create(current_blueprint.width, current_blueprint.height, false, Image.FORMAT_R8)
	mask.fill(Color.BLACK)
	for cell_data in cells:
		if cell_data is not Array or cell_data.size() < 2:
			continue
		var x := int(cell_data[0])
		var y := int(cell_data[1])
		if x < 0 or y < 0 or x >= current_blueprint.width or y >= current_blueprint.height:
			continue
		var strength := clampf(float(cell_data[2]) if cell_data.size() >= 3 else 1.0, 0.0, 1.0)
		mask.set_pixel(x, y, Color(strength, 0.0, 0.0, 1.0))
	corruption_overlay_sprite.texture = ImageTexture.create_from_image(mask)
	(corruption_overlay_sprite.material as ShaderMaterial).set_shader_parameter("source_size", Vector2(current_blueprint.width, current_blueprint.height))
	corruption_overlay_sprite.visible = true

func _update_terrain_effect_overlay(effects: Array) -> void:
	if current_blueprint == null:
		return
	var cached_effects: Array = effects.filter(func(effect_data: Variant) -> bool:
		return effect_data is Array and effect_data.size() >= 4 and String(effect_data[2]) in ["mud", "flood", "ash", "fire"])
	var next_hash := hash(cached_effects)
	if next_hash == terrain_effect_overlay_hash and (cached_effects.is_empty() or terrain_effect_overlay_sprite.texture != null):
		return
	terrain_effect_overlay_hash = next_hash
	if cached_effects.is_empty():
		terrain_effect_overlay_sprite.visible = false
		return
	var mask := Image.create(current_blueprint.width, current_blueprint.height, false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	for effect_data in cached_effects:
		var x := int(effect_data[0])
		var y := int(effect_data[1])
		if x < 0 or y < 0 or x >= current_blueprint.width or y >= current_blueprint.height:
			continue
		var intensity := clampf(float(effect_data[3]), 0.0, 1.0)
		var channels := Color(0.0, 0.0, 0.0, 1.0)
		match String(effect_data[2]):
			"mud": channels.r = intensity
			"flood": channels.g = intensity
			"ash": channels.b = intensity
			"fire":
				channels.r = intensity
				channels.g = intensity * 0.50
		mask.set_pixel(x, y, channels)
	terrain_effect_overlay_sprite.texture = ImageTexture.create_from_image(mask)
	(terrain_effect_overlay_sprite.material as ShaderMaterial).set_shader_parameter("source_size", Vector2(current_blueprint.width, current_blueprint.height))
	terrain_effect_overlay_sprite.visible = true

func _update_resource_lod_overlay(nodes: Array) -> void:
	if current_blueprint == null:
		return
	var next_hash := hash(nodes)
	if next_hash == resource_lod_overlay_hash and resource_lod_overlay_sprite.texture != null:
		return
	resource_lod_overlay_hash = next_hash
	var mask := Image.create(current_blueprint.width, current_blueprint.height, false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	for node in nodes:
		var x := int(node.get("x", -1))
		var y := int(node.get("y", -1))
		var amount := int(node.get("amount", 0))
		if amount <= 0 or x < 0 or y < 0 or x >= current_blueprint.width or y >= current_blueprint.height:
			continue
		var initial_amount := maxi(1, int(node.get("initial_amount", amount)))
		var strength := clampf(float(amount) / float(initial_amount), 0.18, 1.0)
		var channels := Color.TRANSPARENT
		match String(node.get("id", "")):
			"wood": channels.r = strength
			# Common stone is the connected rocky terrain material. Only ore seams
			# need a resource glyph at wide zoom.
			"iron_ore", "gold_ore": channels.g = strength
			"crystal": channels.b = strength
			"raw_vegetables": channels.a = strength
		mask.set_pixel(x, y, channels)
	resource_lod_overlay_sprite.texture = ImageTexture.create_from_image(mask)
	(resource_lod_overlay_sprite.material as ShaderMaterial).set_shader_parameter("source_size", Vector2(current_blueprint.width, current_blueprint.height))

func _on_sim_event(event: SimEvent) -> void:
	if event.type == &"command_rejected":
		placement_rejected.emit(String(event.data.get("reason", "Action rejected")))
	if event.type == &"building_placed":
		if pending_building_id == &"camp":
			pending_building_id = &""
			placement_changed.emit(pending_building_id)
	if event.type == &"terrain_changed":
		if bool(event.data.get("base_changed", false)) and current_blueprint != null:
			_prepare_terrain_water_accents(current_blueprint)
			_mark_terrain_cell_dirty(Vector2i(int(event.data.get("cell_x", 0)), int(event.data.get("cell_y", 0))))
	queue_redraw()

func _restart_terrain_chunk_generation() -> void:
	if current_blueprint == null:
		return
	terrain_chunk_generation += 1
	terrain_chunk_started_usec = Time.get_ticks_usec()
	terrain_first_chunk_ready_ms = -1.0
	terrain_all_chunks_ready_ms = -1.0
	terrain_chunk_queue.clear()
	terrain_chunk_queued_revisions.clear()
	terrain_chunk_revisions.clear()
	terrain_tile_snapshot = current_blueprint.tiles.duplicate()
	terrain_elevation_snapshot = current_blueprint.elevations.duplicate()
	for sprite in terrain_chunk_sprites.values():
		if is_instance_valid(sprite):
			sprite.queue_free()
	terrain_chunk_sprites.clear()
	var preview_started := Time.get_ticks_usec()
	terrain_preview_image = _create_terrain_preview_image(current_blueprint, terrain_season)
	terrain_sprite.texture = ImageTexture.create_from_image(terrain_preview_image)
	# The preview is intentionally one texel per logical cell. Linear sampling keeps
	# that temporary fallback calm at fractional mobile zooms; completed 8 px/cell
	# chunks remain nearest-filtered and retain their exact pixel-art edges.
	terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	terrain_sprite.scale = Vector2.ONE * TILE_PIXELS
	terrain_preview_ready_ms = float(Time.get_ticks_usec() - preview_started) / 1000.0
	var chunk_columns := ceili(float(current_blueprint.width) / float(TERRAIN_CHUNK_CELLS))
	var chunk_rows := ceili(float(current_blueprint.height) / float(TERRAIN_CHUNK_CELLS))
	for chunk_y in chunk_rows:
		for chunk_x in chunk_columns:
			var coord := Vector2i(chunk_x, chunk_y)
			terrain_chunk_revisions[_terrain_chunk_key(coord)] = 1
			_enqueue_terrain_chunk(coord, 1)
	terrain_chunk_priority_cell = Vector2i(current_blueprint.starting_cell.x / TERRAIN_CHUNK_CELLS, current_blueprint.starting_cell.y / TERRAIN_CHUNK_CELLS)
	_sort_terrain_chunk_queue(terrain_chunk_priority_cell)
	_start_terrain_chunk_workers()

func _create_terrain_preview_image(blueprint: RegionBlueprint, season: StringName) -> Image:
	var image := Image.create(blueprint.width, blueprint.height, false, Image.FORMAT_RGBA8)
	for y in blueprint.height:
		for x in blueprint.width:
			var cell := Vector2i(x, y)
			var color := _tile_color(blueprint.get_tile(cell), blueprint.biome_id, x, y, season)
			var elevation := blueprint.get_elevation(cell)
			if elevation >= 3:
				color = color.lightened(0.055)
			elif elevation == 2:
				color = color.lightened(0.025)
			image.set_pixel(x, y, color)
	return image

func _mark_terrain_cell_dirty(cell: Vector2i) -> void:
	if current_blueprint == null:
		return
	terrain_tile_snapshot = current_blueprint.tiles.duplicate()
	terrain_elevation_snapshot = current_blueprint.elevations.duplicate()
	if terrain_preview_image != null and not terrain_preview_image.is_empty():
		terrain_preview_image.set_pixel(cell.x, cell.y, _tile_color(current_blueprint.get_tile(cell), current_blueprint.biome_id, cell.x, cell.y, terrain_season))
		if terrain_sprite.texture is ImageTexture:
			(terrain_sprite.texture as ImageTexture).update(terrain_preview_image)
	# A changed boundary can alter the edge treatment in any of the eight adjacent
	# cells, so queue every chunk touched by the surrounding 3x3 neighborhood.
	var affected: Dictionary = {}
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			if x < 0 or y < 0 or x >= current_blueprint.width or y >= current_blueprint.height:
				continue
			var coord := Vector2i(x / TERRAIN_CHUNK_CELLS, y / TERRAIN_CHUNK_CELLS)
			affected[_terrain_chunk_key(coord)] = coord
	for coord_value in affected.values():
		var coord: Vector2i = coord_value
		var key := _terrain_chunk_key(coord)
		var revision := int(terrain_chunk_revisions.get(key, 0)) + 1
		terrain_chunk_revisions[key] = revision
		_enqueue_terrain_chunk(coord, revision)
	_sort_terrain_chunk_queue(Vector2i(cell.x / TERRAIN_CHUNK_CELLS, cell.y / TERRAIN_CHUNK_CELLS))

func _enqueue_terrain_chunk(coord: Vector2i, revision: int) -> void:
	var key := _terrain_chunk_key(coord)
	if int(terrain_chunk_queued_revisions.get(key, -1)) >= revision:
		return
	terrain_chunk_queued_revisions[key] = revision
	terrain_chunk_queue.append({"coord": coord, "revision": revision, "generation": terrain_chunk_generation})

func _sort_terrain_chunk_queue(priority: Vector2i) -> void:
	terrain_chunk_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var coord_a: Vector2i = a.coord
		var coord_b: Vector2i = b.coord
		var distance_a := coord_a.distance_squared_to(priority)
		var distance_b := coord_b.distance_squared_to(priority)
		if not is_equal_approx(distance_a, distance_b):
			return distance_a < distance_b
		return coord_a.y < coord_b.y or (coord_a.y == coord_b.y and coord_a.x < coord_b.x))

func _terrain_chunk_worker_limit() -> int:
	return 2 if OS.has_feature("mobile") else mini(4, maxi(1, OS.get_processor_count() - 1))

func _start_terrain_chunk_workers() -> void:
	while terrain_chunk_active.size() < _terrain_chunk_worker_limit() and not terrain_chunk_queue.is_empty():
		var queued: Dictionary = terrain_chunk_queue.pop_front()
		var coord: Vector2i = queued.coord
		var key := _terrain_chunk_key(coord)
		var revision := int(queued.revision)
		if int(queued.generation) != terrain_chunk_generation or int(terrain_chunk_revisions.get(key, 0)) != revision:
			continue
		terrain_chunk_queued_revisions.erase(key)
		var origin := coord * TERRAIN_CHUNK_CELLS
		var size := Vector2i(mini(TERRAIN_CHUNK_CELLS, current_blueprint.width - origin.x), mini(TERRAIN_CHUNK_CELLS, current_blueprint.height - origin.y))
		var payload := {
			"tiles": terrain_tile_snapshot,
			"elevations": terrain_elevation_snapshot,
			"world_width": current_blueprint.width, "world_height": current_blueprint.height,
			"origin_x": origin.x, "origin_y": origin.y, "size_x": size.x, "size_y": size.y,
			"chunk_x": coord.x, "chunk_y": coord.y,
			"seed": current_blueprint.seed, "biome": String(current_blueprint.biome_id), "season": String(terrain_season),
			"generation": terrain_chunk_generation, "revision": revision,
		}
		var renderer := TERRAIN_CHUNK_RENDERER.new()
		var thread := Thread.new()
		var start_error := thread.start(renderer.render.bind(payload))
		if start_error != OK:
			_enqueue_terrain_chunk(coord, revision)
			break
		terrain_chunk_task_sequence += 1
		terrain_chunk_active[terrain_chunk_task_sequence] = {"thread": thread, "renderer": renderer, "coord": coord, "revision": revision, "generation": terrain_chunk_generation}

func _poll_terrain_chunk_workers() -> void:
	if terrain_chunk_active.is_empty():
		return
	var completed_ids: Array[int] = []
	for task_id_value in terrain_chunk_active.keys():
		var task_id := int(task_id_value)
		var task: Dictionary = terrain_chunk_active[task_id]
		var thread: Thread = task.thread
		if thread.is_alive():
			continue
		var result: Variant = thread.wait_to_finish()
		completed_ids.append(task_id)
		if result is not Dictionary:
			continue
		var coord := Vector2i(int(result.get("chunk_x", -1)), int(result.get("chunk_y", -1)))
		var key := _terrain_chunk_key(coord)
		if int(result.get("generation", -1)) != terrain_chunk_generation or int(result.get("revision", -1)) != int(terrain_chunk_revisions.get(key, 0)):
			continue
		var image: Image = result.get("image")
		if image == null or image.is_empty():
			continue
		var sprite: Sprite2D = terrain_chunk_sprites.get(key)
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.centered = false
			sprite.z_index = -99
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = Vector2(coord * TERRAIN_CHUNK_CELLS) * TILE_PIXELS
			add_child(sprite)
			terrain_chunk_sprites[key] = sprite
		sprite.texture = ImageTexture.create_from_image(image)
		if terrain_first_chunk_ready_ms < 0.0:
			terrain_first_chunk_ready_ms = float(Time.get_ticks_usec() - terrain_chunk_started_usec) / 1000.0
	for task_id in completed_ids:
		terrain_chunk_active.erase(task_id)
	if terrain_chunk_queue.is_empty() and terrain_chunk_active.is_empty() and terrain_all_chunks_ready_ms < 0.0:
		terrain_all_chunks_ready_ms = float(Time.get_ticks_usec() - terrain_chunk_started_usec) / 1000.0
	# Only when a chunk actually landed. This used to run on every poll, so for the
	# whole streaming period — many seconds on a phone — the entire world was
	# redrawn every frame whether or not anything had changed.
	if not completed_ids.is_empty():
		queue_redraw()

func is_terrain_chunking_complete() -> bool:
	return terrain_chunk_queue.is_empty() and terrain_chunk_active.is_empty()

func get_terrain_chunk_stats() -> Dictionary:
	return {
		"generation": terrain_chunk_generation,
		"preview_ms": terrain_preview_ready_ms,
		"first_chunk_ms": terrain_first_chunk_ready_ms,
		"all_chunks_ms": terrain_all_chunks_ready_ms,
		"ready_chunks": terrain_chunk_sprites.size(),
		"queued_chunks": terrain_chunk_queue.size(),
		"active_workers": terrain_chunk_active.size(),
	}

func _terrain_chunk_key(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x, coord.y]

func begin_placement(building_id: StringName) -> void:
	pending_spell_id = &""
	spell_changed.emit(pending_spell_id)
	pending_terrain_action = &""
	terrain_action_changed.emit(pending_terrain_action)
	pending_building_id = building_id
	placement_changed.emit(building_id)
	queue_redraw()

func cancel_placement() -> void:
	pending_building_id = &""
	pending_spell_id = &""
	pending_terrain_action = &""
	placement_changed.emit(pending_building_id)
	spell_changed.emit(pending_spell_id)
	terrain_action_changed.emit(pending_terrain_action)
	queue_redraw()

func begin_spell(spell_id: StringName) -> void:
	pending_building_id = &""
	placement_changed.emit(pending_building_id)
	pending_terrain_action = &""
	terrain_action_changed.emit(pending_terrain_action)
	pending_spell_id = spell_id
	spell_changed.emit(spell_id)
	queue_redraw()

func begin_terrain_work(action: StringName) -> void:
	if action not in [&"clear", &"dig", &"fill", &"restore"]:
		return
	pending_building_id = &""
	pending_spell_id = &""
	placement_changed.emit(pending_building_id)
	spell_changed.emit(pending_spell_id)
	pending_terrain_action = action
	terrain_action_changed.emit(action)
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
				elif not pending_terrain_action.is_empty():
					_attempt_terrain_work(pointer_cell)
				else:
					_select_at_cell(pointer_cell)
		get_viewport().set_input_as_handled()

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	pointer_cell = _screen_to_cell(event.position)
	if dragging:
		drag_distance += event.relative.length()
		if _is_brush_action():
			_attempt_brush_action(pointer_cell)
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
		if touch_points.size() == 1 and touch_commits_action(float(touch.get("travel", 0.0))):
			var target_cell := _screen_to_cell(event.position)
			var now_msec := Time.get_ticks_msec()
			var is_double_tap := (now_msec - last_tap_msec < 300) and (target_cell == last_tap_cell)
			last_tap_msec = now_msec
			last_tap_cell = target_cell

			if is_double_tap and pending_building_id.is_empty() and pending_spell_id.is_empty() and pending_terrain_action.is_empty():
				# Double tap: Center camera and select entity
				camera.position = Vector2(target_cell.x * TILE_PIXELS + TILE_PIXELS * 0.5, target_cell.y * TILE_PIXELS + TILE_PIXELS * 0.5)
				_select_at_cell(target_cell)
			elif not pending_building_id.is_empty():
				_attempt_placement(target_cell)
			elif not pending_spell_id.is_empty():
				_attempt_spell(target_cell)
			elif not pending_terrain_action.is_empty():
				_attempt_terrain_work(target_cell)
			else:
				_select_at_cell(target_cell)
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
		if _is_brush_action():
			_attempt_brush_action(pointer_cell)
		elif pending_building_id.is_empty():
			camera.position -= event.relative / camera.zoom.x
	elif touch_points.size() >= 2:
		if _is_brush_action():
			# 2-finger panning while painting with brush
			if event.index == 0:
				_attempt_brush_action(pointer_cell)
			else:
				camera.position -= event.relative / camera.zoom.x
		else:
			var positions: Array = []
			for value in touch_points.values():
				positions.append(value.position)
			var distance: float = Vector2(positions[0]).distance_to(Vector2(positions[1]))
			if last_pinch_distance > 0.0:
				_zoom_at((Vector2(positions[0]) + Vector2(positions[1])) * 0.5, distance / last_pinch_distance)
			last_pinch_distance = distance
			if not pending_building_id.is_empty() or not pending_spell_id.is_empty():
				# One finger aims while a placement is armed, so two fingers have to
				# be able to reach the rest of the map without disarming it. Each
				# finger reports its own travel, hence the half step.
				camera.position -= event.relative / camera.zoom.x * 0.5
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

const TAP_TRAVEL_SLOP := 18.0

func touch_commits_action(travel: float) -> bool:
	# A touch screen has no hover, so an armed building or spell is aimed by
	# dragging the ghost and committed where the finger lifts, however far it
	# travelled. Judging those gestures by tap slop alone discarded them and left
	# the target unmovable, making the tutorial's "move the ghost, then tap to
	# place it" impossible on a phone. Brush actions already paint during the drag,
	# and a plain selection tap still has to stay put.
	if travel < TAP_TRAVEL_SLOP:
		return true
	var aiming := not pending_building_id.is_empty() or not pending_spell_id.is_empty()
	return aiming and not _is_brush_action()

func _is_brush_action() -> bool:
	return _is_brush_placement() or not pending_terrain_action.is_empty()

func _attempt_brush_action(cell: Vector2i) -> void:
	if not pending_terrain_action.is_empty():
		_attempt_terrain_work(cell)
	else:
		_attempt_brush_placement(cell)

func _attempt_terrain_work(cell: Vector2i) -> void:
	if pending_terrain_action.is_empty():
		return
	var key := "%d:%d" % [cell.x, cell.y]
	if brush_cells_this_gesture.has(key):
		return
	if not SimulationHost.can_designate_terrain_work(pending_terrain_action, cell):
		AudioDirector.play_cue(&"invalid_action")
		if brush_cells_this_gesture.is_empty():
			placement_rejected.emit("That terrain cannot be %s here." % String(pending_terrain_action))
		return
	brush_cells_this_gesture[key] = true
	SimulationHost.submit(GameCommand.designate_terrain_work(SimulationHost.tick, pending_terrain_action, cell))

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
	for nomad in latest_snapshot.nomads:
		if Vector2(float(nomad.x), float(nomad.y)).distance_to(Vector2(cell) + Vector2(0.5, 0.5)) <= 1.35:
			selected_kind = &"nomad"
			selected_entity_id = int(nomad.id)
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
	if not bool(SimulationHost.mode_rules.get("sandbox_tools", false)) and not pending_building_id.is_empty():
		if pending_building_id == &"camp":
			if latest_snapshot:
				for building in latest_snapshot.buildings:
					if String(building.get("definition_id", "")) == "camp" and not bool(building.get("destroyed", false)):
						return false
		elif not SimulationHost.is_within_settlement_range(cell, footprint):
			return false
	if latest_snapshot:
		var rect := Rect2i(cell, footprint)
		for building in latest_snapshot.buildings:
			if rect.intersects(Rect2i(Vector2i(building.x, building.y), Vector2i(building.width, building.height))):
				return false
	return true

func _get_terrain_texture(blueprint: RegionBlueprint, season: StringName) -> ImageTexture:
	var cache_key := "%d:%s" % [blueprint.get_instance_id(), String(season)]
	if terrain_texture_cache.has(cache_key):
		terrain_texture_cache_order.erase(cache_key)
		terrain_texture_cache_order.append(cache_key)
		return terrain_texture_cache[cache_key]
	var texture := _create_terrain_texture(blueprint, season)
	terrain_texture_cache[cache_key] = texture
	terrain_texture_cache_order.append(cache_key)
	while terrain_texture_cache_order.size() > TERRAIN_TEXTURE_CACHE_LIMIT:
		var expired_key: String = terrain_texture_cache_order.pop_front()
		terrain_texture_cache.erase(expired_key)
	return texture

func _prepare_terrain_water_accents(blueprint: RegionBlueprint) -> void:
	terrain_water_accents.clear()
	for y in range(1, blueprint.height - 1):
		for x in range(1, blueprint.width - 1):
			var cell := Vector2i(x, y)
			if _terrain_family(blueprint.get_tile(cell)) != &"water":
				continue
			var accent_hash := posmod(x * x * 1741 + y * y * 3253 + x * y * 953 + blueprint.seed * 71, 104729)
			if accent_hash % 89 != 0:
				continue
			var shoreline := false
			for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				if _cell_family(blueprint, cell + direction) != &"water":
					shoreline = true
					break
			terrain_water_accents.append({
				"position": (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_PIXELS,
				"phase": accent_hash % 6,
				"length": 3 + accent_hash % 5,
				"shoreline": shoreline,
			})
			if terrain_water_accents.size() >= 520:
				return

func _draw_animated_terrain() -> void:
	var visible_cells := _visible_cell_rect(4.0)
	var water_phase := posmod(int(SimulationHost.tick / 3), 6)
	var ripple_color := Color(0.42, 0.79, 0.86, 0.48)
	if terrain_season == &"Winter":
		ripple_color = Color(0.70, 0.87, 0.89, 0.42)
	for accent in terrain_water_accents:
		if not visible_cells.has_point(Vector2(accent.position) / TILE_PIXELS):
			continue
		var local_phase := posmod(water_phase + int(accent.phase), 6)
		if local_phase > 2:
			continue
		var center: Vector2 = accent.position
		var length := int(accent.length) - (1 if local_phase == 2 else 0)
		var offset := Vector2(float(local_phase - 1), float(local_phase % 2))
		var color := ripple_color.darkened(0.08) if bool(accent.shoreline) else ripple_color
		draw_rect(Rect2(center + offset - Vector2(float(length) * 0.5, 0.0), Vector2(length, 1)), color, true)

func _create_terrain_texture(blueprint: RegionBlueprint, season: StringName = &"Spring") -> ImageTexture:
	# Material ownership and large tonal fields are composed at half resolution;
	# sparse native-pixel accents are added after the nearest-neighbor upscale.
	# This hybrid keeps organic connected masses without paying for nine full-size
	# cubic masks and dozens of millions of lookups during every region load.
	var render_width := blueprint.width * TERRAIN_MASK_PIXELS_PER_CELL
	var render_height := blueprint.height * TERRAIN_MASK_PIXELS_PER_CELL
	# Three RGB masks encode nine one-hot material channels. This preserves the
	# exact bilinear ownership field while replacing nine source-image passes and
	# nine per-pixel reads with one source pass and three reads.
	var masks: Array[Image] = []
	for _mask_index in 3:
		var mask := Image.create(blueprint.width, blueprint.height, false, Image.FORMAT_RGB8)
		mask.fill(Color.BLACK)
		masks.append(mask)
	for y in blueprint.height:
		for x in blueprint.width:
			var tile_id: int = int(blueprint.tiles[y * blueprint.width + x])
			masks[tile_id / 3].set_pixel(x, y, TERRAIN_MASK_CHANNEL_COLORS[tile_id % 3])
	for mask in masks:
		# Bilinear expansion cannot overshoot a one-hot ownership channel. Cubic
		# ringing created long stone/forest whiskers at high-contrast borders.
		mask.resize(render_width, render_height, Image.INTERPOLATE_BILINEAR)
	# FastNoiseLite generates these maps in native code. Sampling three cached
	# images is substantially cheaper than three GDScript-to-noise calls for each
	# of the million ownership pixels.
	var relief_map := terrain_relief_noise.get_image(render_width, render_height, false, false, true)
	var patch_map := terrain_patch_noise.get_image(render_width, render_height, false, false, true)
	var detail_map := terrain_detail_noise.get_image(render_width, render_height, false, false, true)
	var image := Image.create(render_width, render_height, false, Image.FORMAT_RGBA8)
	var native_scale := int(TILE_PIXELS) / TERRAIN_MASK_PIXELS_PER_CELL
	for py in render_height:
		var cell_y: int = mini(blueprint.height - 1, int(py / TERRAIN_MASK_PIXELS_PER_CELL))
		for px in render_width:
			var cell_x: int = mini(blueprint.width - 1, int(px / TERRAIN_MASK_PIXELS_PER_CELL))
			var packed_a := masks[0].get_pixel(px, py)
			var packed_b := masks[1].get_pixel(px, py)
			var packed_c := masks[2].get_pixel(px, py)
			var best_tile := 0
			var second_tile := 0
			var best_weight := -1.0
			var second_weight := -1.0
			for tile_id in TERRAIN_TILE_KIND_COUNT:
				var packed: Color = packed_a if tile_id < 3 else (packed_b if tile_id < 6 else packed_c)
				var weight: float = packed.r if tile_id % 3 == 0 else (packed.g if tile_id % 3 == 1 else packed.b)
				if weight > best_weight:
					second_weight = best_weight
					second_tile = best_tile
					best_weight = weight
					best_tile = tile_id
				elif weight > second_weight:
					second_weight = weight
					second_tile = tile_id
			var relief := relief_map.get_pixel(px, py).r * 2.0 - 1.0
			var patch := patch_map.get_pixel(px, py).r * 2.0 - 1.0
			var detail := detail_map.get_pixel(px, py).r * 2.0 - 1.0
			var color := _connected_terrain_pixel(best_tile, second_tile, best_weight, second_weight, blueprint.biome_id, cell_x, cell_y, px * native_scale, py * native_scale, season, relief, patch, detail)
			image.set_pixel(px, py, color)
	if TERRAIN_MASK_PIXELS_PER_CELL != int(TILE_PIXELS):
		image.resize(blueprint.width * int(TILE_PIXELS), blueprint.height * int(TILE_PIXELS), Image.INTERPOLATE_NEAREST)
	_apply_native_terrain_accents(image, blueprint, season)
	return ImageTexture.create_from_image(image)

func _connected_terrain_pixel(tile: int, second_tile: int, weight: float, second_weight: float, biome: StringName, cell_x: int, cell_y: int, pixel_x: int, pixel_y: int, season: StringName, relief: float, patch: float, detail: float) -> Color:
	var base := _tile_color(tile, biome, cell_x, cell_y, season)
	var family := _terrain_family(tile)
	var margin := weight - second_weight
	var pixel_hash := posmod(pixel_x * pixel_x * 1741 + pixel_y * pixel_y * 3253 + pixel_x * pixel_y * 953 + tile * 7919, 104729)
	if family in [&"forest", &"rock", &"water", &"crystal", &"corruption"]:
		var edge_colors := _connected_edge_colors(base, family)
		if family == &"water" and second_tile != tile:
			var bank := _tile_color(second_tile, biome, cell_x, cell_y, season)
			# The former high-value cyan ring made every pond look cut out. A wet
			# material bank, muted shallow mix, and restrained inner glint retain
			# pixel separation while allowing sand, grass, marsh, and stone to tint
			# their own shoreline.
			if season == &"Winter":
				edge_colors[0] = bank.lerp(Color("aebfbc"), 0.22).darkened(0.08)
				edge_colors[1] = Color("a8c5c8").lerp(bank, 0.16)
				edge_colors[2] = Color("789fa7").lerp(base, 0.28)
			else:
				edge_colors[0] = bank.darkened(0.14).lerp(base, 0.10)
				edge_colors[1] = base.lightened(0.20).lerp(bank, 0.12)
				edge_colors[2] = base.lightened(0.085)
		elif second_tile != tile:
			var outside := _tile_color(second_tile, biome, cell_x, cell_y, season)
			# Forest, stone, and crystal shelves still need a readable material
			# boundary, but a near-black outline makes them look like cut-out decals.
			# Three mixed ramps let the neighboring soil enter the outer pixels before
			# the material's own shadow/highlight language takes over.
			match family:
				&"forest":
					edge_colors[0] = outside.lerp(base.darkened(0.16), 0.24)
					edge_colors[1] = base.lerp(outside, 0.34).lightened(0.06)
					edge_colors[2] = base.lerp(outside, 0.13)
				&"rock":
					edge_colors[0] = outside.darkened(0.07).lerp(base, 0.22)
					edge_colors[1] = base.lerp(outside, 0.25).lightened(0.08)
					edge_colors[2] = base.lerp(outside, 0.10)
				&"crystal":
					edge_colors[0] = outside.darkened(0.10).lerp(base, 0.26)
					edge_colors[1] = base.lerp(outside, 0.22).lightened(0.12)
					edge_colors[2] = base.lerp(outside, 0.09)
				&"corruption":
					edge_colors[0] = outside.darkened(0.18).lerp(base, 0.22)
					edge_colors[1] = base.lerp(outside, 0.26)
					edge_colors[2] = base.lerp(outside, 0.10)
		if weight < 0.57 or margin < 0.08:
			base = edge_colors[0]
		elif weight < 0.72 or margin < 0.18:
			base = edge_colors[1]
		elif weight < 0.87:
			base = edge_colors[2]
	elif margin < 0.20 and second_tile != tile:
		# Ordered pixel intermixing blends soft ground types without a gradient or
		# a visible square seam.
		var threshold: float = [0.08, 0.17, 0.12, 0.03][posmod(pixel_x + pixel_y * 3, 4)]
		if margin < threshold:
			base = _tile_color(second_tile, biome, cell_x, cell_y, season)
	match family:
		&"forest":
			if weight > 0.87:
				# Two scales of noise form overlapping crown lobes. Palette steps,
				# rather than gradients, retain a handmade canopy at native scale.
				var crown_field := relief * 0.70 + patch * 0.30
				var crown_high := Color("3c8a2c")
				var crown_mid := Color("24742a")
				var crown_shadow := Color("0a3b1b")
				var crown_rim := Color("66a73a")
				match season:
					&"Spring":
						crown_high = Color("53a33a")
						crown_mid = Color("2e812f")
						crown_shadow = Color("0b421f")
						crown_rim = Color("78b948")
					&"Summer":
						crown_high = Color("477f2b")
						crown_mid = Color("286627")
						crown_shadow = Color("10381e")
						crown_rim = Color("69963b")
					&"Autumn":
						crown_high = Color("a86d2f")
						crown_mid = Color("75522a")
						crown_shadow = Color("27391f")
						crown_rim = Color("c18a3c")
					&"Winter":
						crown_high = Color("aebcae")
						crown_mid = Color("6d8975")
						crown_shadow = Color("244737")
						crown_rim = Color("d2d9d1")
				if crown_field > 0.28:
					base = base.lerp(crown_high, 0.76)
				elif crown_field < -0.27:
					base = base.lerp(crown_shadow, 0.78)
				elif crown_field > 0.06:
					base = base.lerp(crown_mid, 0.62)
				if absf(crown_field - 0.28) < 0.028:
					base = crown_rim
				elif absf(crown_field + 0.27) < 0.026:
					base = crown_shadow.darkened(0.12)
				if detail > 0.42 and pixel_hash % 3 != 0:
					base = base.lightened(0.13)
				elif detail < -0.46 and pixel_hash % 4 != 0:
					base = base.darkened(0.13)
				if pixel_hash % 1187 == 0:
					base = Color("b84b33")
			elif weight > 0.70 and pixel_hash % 23 == 0:
				base = base.lightened(0.13)
		&"rock":
			if weight > 0.87:
				# Broad stone plates use restrained value steps. Thin noise contours
				# become cracks, avoiding the old equal-sized pebble carpet.
				var plate_field := relief * 0.76 + patch * 0.24
				if plate_field > 0.32:
					base = base.lightened(0.20)
				elif plate_field < -0.30:
					base = base.darkened(0.18)
				elif plate_field > 0.05:
					base = base.lightened(0.075)
				if absf(plate_field - 0.32) < 0.020 or absf(plate_field + 0.30) < 0.018 or absf(plate_field - 0.05) < 0.014:
					base = base.darkened(0.36)
				elif detail > 0.58 and pixel_hash % 7 < 2:
					base = base.lightened(0.11)
			elif weight > 0.66:
				# Sparse talus is restricted to the shelf edge.
				if pixel_hash % 19 == 0:
					base = base.lightened(0.16)
				elif pixel_hash % 29 == 0:
					base = base.darkened(0.15)
		&"water":
			if weight > 0.87:
				var basin_field := relief * 0.72 + patch * 0.28
				if basin_field < -0.18:
					base = base.darkened(0.12)
				elif basin_field > 0.32:
					base = base.lightened(0.07)
				# Each large block may contain one broken horizontal ripple. The
				# block-local shape creates a line cluster rather than uniform dots.
				var ripple_block_x := floori(float(pixel_x) / 23.0)
				var ripple_block_y := floori(float(pixel_y) / 13.0)
				var ripple_hash := posmod(ripple_block_x * 92821 + ripple_block_y * 68917 + tile * 97, 104729)
				var ripple_x := posmod(pixel_x, 23)
				var ripple_y := posmod(pixel_y, 13)
				var ripple_start := 2 + posmod(ripple_hash, 10)
				var ripple_length := 4 + posmod(ripple_hash / 7, 7)
				if ripple_hash % 4 != 0 and ripple_y == 3 + posmod(ripple_hash / 11, 7) and ripple_x >= ripple_start and ripple_x < ripple_start + ripple_length:
					base = base.lightened(0.26 if ripple_x not in [ripple_start, ripple_start + ripple_length - 1] else 0.16)
			elif weight > 0.68 and pixel_hash % 37 == 0:
				base = base.lightened(0.20)
		&"crystal":
			if weight > 0.87:
				var mineral_field := relief * 0.65 + patch * 0.35
				if mineral_field > 0.30:
					base = base.lightened(0.10)
				elif mineral_field < -0.28:
					base = base.darkened(0.12)
				if pixel_hash % 97 == 0:
					base = Color("7edce0")
		&"corruption":
			if weight > 0.82:
				var vein_field := relief * 0.62 + detail * 0.38
				if vein_field > 0.38:
					base = Color("76115f")
				elif vein_field < -0.40:
					base = Color("2b0625")
				if absf(vein_field - 0.18) < 0.012:
					base = Color("a12c7f")
				elif pixel_hash % 541 == 0:
					base = Color("d157a3")
		&"ground":
			# Large quiet tonal fields establish ground volume. Detail is grouped into
			# deterministic tuft/flower/sand/reed motifs instead of a dot screen.
			var ground_field := relief * 0.66 + patch * 0.34
			if ground_field > 0.31:
				base = base.lightened(0.095)
			elif ground_field < -0.30:
				base = base.darkened(0.085)
			elif ground_field > 0.06:
				base = base.lightened(0.040)
	return base

func _apply_native_terrain_accents(image: Image, blueprint: RegionBlueprint, season: StringName) -> void:
	# Accent blocks are deliberately incommensurate with the 8px simulation cell.
	# Their sparse one-pixel motifs break doubled macro pixels without revealing a
	# tile grid or coating quiet terrain in uniformly distributed noise.
	var width := image.get_width()
	var height := image.get_height()
	for block_y in range(0, height, 17):
		for block_x in range(0, width, 19):
			var block_hash := posmod(block_x * 16127 + block_y * 31337 + blueprint.seed * 43, 104729)
			var point := Vector2i(block_x + 3 + posmod(block_hash, 12), block_y + 3 + posmod(block_hash / 11, 10))
			if point.x < 8 or point.y < 8 or point.x >= width - 10 or point.y >= height - 10:
				continue
			var cell := Vector2i(point.x / int(TILE_PIXELS), point.y / int(TILE_PIXELS))
			var tile := blueprint.get_tile(cell)
			var family := _terrain_family(tile)
			var sample := image.get_pixelv(point)
			match family:
				&"ground":
					var touches_water := false
					var neighboring_material: StringName = &""
					for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
						var neighbor_family := _cell_family(blueprint, cell + direction)
						if neighbor_family == &"water":
							touches_water = true
						elif neighboring_material.is_empty() and neighbor_family in [&"forest", &"rock", &"crystal"]:
							neighboring_material = neighbor_family
					if touches_water and block_hash % 3 == 0:
						var wet_edge := sample.lerp(Color("c3cfca"), 0.32) if season == &"Winter" else sample.darkened(0.12).lerp(Color("294c4b"), 0.12)
						for offset in [Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(2, 1)]:
							var wet_point: Vector2i = point + Vector2i(offset)
							var wet_cell := Vector2i(wet_point.x / int(TILE_PIXELS), wet_point.y / int(TILE_PIXELS))
							if _terrain_family(blueprint.get_tile(wet_cell)) == &"ground":
								image.set_pixelv(wet_point, wet_edge)
					# Material fragments extend into the neighboring soil as a sparse
					# ecotone. This makes forests, shelves, and crystal beds interlock
					# with the biome instead of ending at an otherwise empty contour.
					if neighboring_material == &"forest" and block_hash % 2 == 0:
						var forest_litter := sample.lerp(Color("1f632b"), 0.42)
						for offset in [Vector2i(-3, 1), Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(2, 0), Vector2i(3, 1)]:
							var litter_point: Vector2i = point + Vector2i(offset)
							var litter_cell := Vector2i(litter_point.x / int(TILE_PIXELS), litter_point.y / int(TILE_PIXELS))
							if _terrain_family(blueprint.get_tile(litter_cell)) == &"ground":
								image.set_pixelv(litter_point, forest_litter.lightened(0.08 if offset.y < 0 else 0.0))
					elif neighboring_material == &"rock" and block_hash % 3 == 0:
						var scree := sample.lerp(Color("858985"), 0.54)
						for offset in [Vector2i(-3, 1), Vector2i(-1, -1), Vector2i.ZERO, Vector2i(2, 1), Vector2i(3, 0)]:
							var scree_point: Vector2i = point + Vector2i(offset)
							var scree_cell := Vector2i(scree_point.x / int(TILE_PIXELS), scree_point.y / int(TILE_PIXELS))
							if _terrain_family(blueprint.get_tile(scree_cell)) == &"ground":
								image.set_pixelv(scree_point, scree.darkened(0.10 if offset.y > 0 else 0.0))
					elif neighboring_material == &"crystal" and block_hash % 7 == 0:
						for offset in [Vector2i(-2, 1), Vector2i.ZERO, Vector2i(1, -1), Vector2i(3, 1)]:
							var shard_point: Vector2i = point + Vector2i(offset)
							var shard_cell := Vector2i(shard_point.x / int(TILE_PIXELS), shard_point.y / int(TILE_PIXELS))
							if _terrain_family(blueprint.get_tile(shard_cell)) == &"ground":
								image.set_pixelv(shard_point, sample.lerp(Color("63c7ca"), 0.50))
					if tile == RegionGenerator.Tile.SAND:
						if touches_water and block_hash % 11 == 0:
							image.set_pixelv(point + Vector2i(-1, -1), sample.lightened(0.18))
							image.set_pixelv(point + Vector2i(1, 0), sample.lightened(0.10))
						elif block_hash % 5 == 0:
							var streak_length := 4 + posmod(block_hash / 7, 5)
							for offset in streak_length:
								if offset % 3 != 1:
									image.set_pixelv(point + Vector2i(offset - 2, 0), sample.darkened(0.075))
					elif tile == RegionGenerator.Tile.MARSH:
						if block_hash % 12 == 0:
							var reed := sample.darkened(0.17)
							for offset in [Vector2i(0, -3), Vector2i(0, -2), Vector2i(0, -1), Vector2i(-2, -1), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(2, 1)]:
								image.set_pixelv(point + offset, reed)
						elif block_hash % 29 == 0:
							image.set_pixelv(point, sample.lerp(Color("39706b"), 0.50))
					else:
						if block_hash % 5 == 0:
							var tuft := sample.darkened(0.15)
							for offset in [Vector2i(0, -2), Vector2i(0, -1), Vector2i(-2, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(2, 1)]:
								image.set_pixelv(point + offset, tuft)
					if season == &"Spring" and block_hash % 17 == 0:
						var flower_a := Color("e0bf50")
						var flower_b := Color("d67bab")
						image.set_pixelv(point, flower_a)
						image.set_pixelv(point + Vector2i(2, 1), flower_b)
						image.set_pixelv(point + Vector2i(-1, 2), flower_a.darkened(0.08))
					elif season == &"Summer" and block_hash % 19 == 0:
						var dry_grass := sample.lerp(Color("a98b3f"), 0.62)
						for offset in [Vector2i(-2, 1), Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 1)]:
							image.set_pixelv(point + offset, dry_grass)
					elif season == &"Autumn" and block_hash % 17 == 0:
						image.set_pixelv(point, Color("ad6232"))
						image.set_pixelv(point + Vector2i(2, 1), Color("8f4b2d"))
						image.set_pixelv(point + Vector2i(-2, 1), Color("c18a3c"))
				&"forest":
					var forest_shore := false
					for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
						if _cell_family(blueprint, cell + direction) == &"water":
							forest_shore = true
							break
					if forest_shore and block_hash % 7 == 0:
						var root := sample.darkened(0.24)
						image.set_pixelv(point + Vector2i(-2, 0), root)
						image.set_pixelv(point + Vector2i(-1, 1), root)
						image.set_pixelv(point + Vector2i(1, 1), root)
					if block_hash % 3 == 0:
						var leaf := sample.lightened(0.10) if block_hash % 2 == 0 else sample.darkened(0.10)
						for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 1), Vector2i(2, 1)]:
							image.set_pixelv(point + offset, leaf)
				&"rock":
					var rock_shore := false
					for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
						if _cell_family(blueprint, cell + direction) == &"water":
							rock_shore = true
							break
					if rock_shore and block_hash % 4 == 0:
						var wet_stone := sample.darkened(0.20).lerp(Color("294a50"), 0.18)
						image.set_pixelv(point + Vector2i(-2, 0), wet_stone)
						image.set_pixelv(point + Vector2i(-1, 0), wet_stone)
						image.set_pixelv(point + Vector2i(1, 1), wet_stone)
					elif block_hash % 9 == 0:
						var crack := sample.darkened(0.24)
						for offset in [Vector2i(-2, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 2)]:
							image.set_pixelv(point + offset, crack)
					elif block_hash % 23 == 0:
						image.set_pixelv(point, sample.lightened(0.18))
						image.set_pixelv(point + Vector2i(1, 0), sample.lightened(0.10))
				&"water":
					var shoreline := false
					var shore_tile := -1
					for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
						if _cell_family(blueprint, cell + direction) != &"water":
							shoreline = true
							shore_tile = blueprint.get_tile(cell + direction)
							break
					if shoreline and block_hash % 9 == 0:
						var reed_target := Color("7b8149")
						if season == &"Winter":
							reed_target = Color("879b91")
						elif shore_tile == RegionGenerator.Tile.SAND:
							reed_target = Color("b6a66d")
						elif shore_tile == RegionGenerator.Tile.ROCKY:
							reed_target = Color("687577")
						elif shore_tile == RegionGenerator.Tile.MARSH:
							reed_target = Color("54753d")
						var reed := sample.lerp(reed_target, 0.58)
						var reed_shadow := reed.darkened(0.20)
						for offset in [Vector2i(-2, 1), Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, -1), Vector2i(2, 1)]:
							var reed_point: Vector2i = point + Vector2i(offset)
							var reed_cell: Vector2i = Vector2i(reed_point.x / int(TILE_PIXELS), reed_point.y / int(TILE_PIXELS))
							if _cell_family(blueprint, reed_cell) == &"water":
								image.set_pixelv(reed_point, reed if offset.y <= 0 else reed_shadow)
					elif block_hash % 5 == 0:
						var ripple_length := 4 + posmod(block_hash / 5, 7)
						for offset in ripple_length:
							var ripple_point := point + Vector2i(offset - 2, 0)
							var ripple_cell := Vector2i(ripple_point.x / int(TILE_PIXELS), ripple_point.y / int(TILE_PIXELS))
							if _terrain_family(blueprint.get_tile(ripple_cell)) == &"water":
								image.set_pixelv(ripple_point, sample.lightened(0.22 if offset not in [0, ripple_length - 1] else 0.13))
				&"crystal":
					if block_hash % 7 == 0:
						image.set_pixelv(point, Color("75d4d8"))
						image.set_pixelv(point + Vector2i(0, -1), Color("a1edf0"))
				&"corruption":
					if block_hash % 5 == 0:
						image.set_pixelv(point, Color("a83282"))
						image.set_pixelv(point + Vector2i(1, 1), Color("6e145b"))
			if season == &"Winter" and family not in [&"water", &"corruption"] and block_hash % 7 == 0 and season_pattern_noise.get_noise_2d(cell.x, cell.y) > -0.18:
				var snow := Color("d8ded8")
				for offset in [Vector2i(-2, 0), Vector2i(-1, 0), Vector2i.ZERO, Vector2i(2, 1)]:
					var snow_point: Vector2i = point + offset
					var snow_cell: Vector2i = Vector2i(snow_point.x / int(TILE_PIXELS), snow_point.y / int(TILE_PIXELS))
					if _terrain_family(blueprint.get_tile(snow_cell)) == family:
						image.set_pixelv(snow_point, snow if offset.y == 0 else snow.darkened(0.08))

func _connected_edge_colors(base: Color, family: StringName) -> Array[Color]:
	match family:
		&"forest": return [Color("07351b"), base.lightened(0.13), base.lightened(0.025)]
		&"rock": return [base.darkened(0.07), base, base.darkened(0.015)]
		&"water": return [base.darkened(0.24), base.lightened(0.20), base.lightened(0.085)]
		&"crystal": return [base.darkened(0.42), base.lightened(0.28), base.darkened(0.05)]
		&"corruption": return [Color("23051f"), Color("9b2f7e"), Color("5c104a")]
		_: return [base.darkened(0.30), base.lightened(0.15), base]

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
		&"forest": [Color("507b25"), Color("10451f"), Color("747772"), Color("258e91"), Color("799328"), Color("95703a"), Color("315c4a"), Color("075b82")],
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
		# Crystal deposits sit in dark mineral soil; the harvestable crystal
		# sprites carry the cyan signal instead of turning the whole patch blue.
		RegionGenerator.Tile.CRYSTAL_GROUND: result = Color(palette[0]).lerp(Color(palette[3]), 0.22).darkened(0.14)
		RegionGenerator.Tile.FERTILE: result = palette[4]
		RegionGenerator.Tile.SAND: result = palette[5]
		RegionGenerator.Tile.MARSH: result = palette[6]
		RegionGenerator.Tile.CORRUPTION: result = Color("470a3a")
		_: result = palette[0]
	var active_season := terrain_season if season.is_empty() else season
	if tile != RegionGenerator.Tile.CORRUPTION:
		match active_season:
			&"Spring":
				if tile in [RegionGenerator.Tile.GRASS, RegionGenerator.Tile.FOREST_FLOOR, RegionGenerator.Tile.FERTILE, RegionGenerator.Tile.MARSH]:
					result = result.lerp(Color("55a13a"), 0.055)
			&"Summer":
				if tile in [RegionGenerator.Tile.GRASS, RegionGenerator.Tile.FERTILE, RegionGenerator.Tile.MARSH, RegionGenerator.Tile.SAND]:
					result = result.lerp(Color("a17a31"), 0.18)
				elif tile == RegionGenerator.Tile.FOREST_FLOOR:
					result = result.lerp(Color("6f7227"), 0.08)
			&"Autumn":
				if tile in [RegionGenerator.Tile.GRASS, RegionGenerator.Tile.FOREST_FLOOR, RegionGenerator.Tile.FERTILE, RegionGenerator.Tile.MARSH]:
					result = result.lerp(Color("98542d"), 0.24)
			&"Winter":
				if tile == RegionGenerator.Tile.DEEP_WATER:
					result = result.lerp(Color("789ba2"), 0.38)
				else:
					var snow_field := season_pattern_noise.get_noise_2d(x, y)
					var snow_strength := 0.66 if snow_field > 0.12 else (0.42 if snow_field > -0.16 else 0.16)
					result = result.lerp(Color("c8d1cb"), snow_strength)
	return Color(result.r, result.g, result.b, 1.0)

func _draw() -> void:
	debug_draw_count += 1
	if current_blueprint == null:
		return
	var profile_started := Time.get_ticks_usec()
	var visible_cells := _visible_cell_rect(10.0)
	var use_surface_lod := camera != null and camera.zoom.x < 0.94
	resource_lod_overlay_sprite.visible = use_surface_lod and resource_lod_overlay_sprite.texture != null
	corruption_overlay_sprite.visible = use_surface_lod and corruption_overlay_sprite.texture != null
	terrain_effect_overlay_sprite.visible = use_surface_lod and terrain_effect_overlay_sprite.texture != null
	_draw_animated_terrain()
	if latest_snapshot:
		_draw_terrain_effects(latest_snapshot.terrain_effects, false, visible_cells, not use_surface_lod)
	draw_profile_usec["terrain_dynamic"] = Time.get_ticks_usec() - profile_started
	var range_started := Time.get_ticks_usec()
	_draw_selected_settlement_range()
	draw_profile_usec["range"] = Time.get_ticks_usec() - range_started
	var corrupted_cells: Dictionary = {}
	if latest_snapshot:
		for position_data in latest_snapshot.corruption_cells:
			if visible_cells.has_point(Vector2(float(position_data[0]), float(position_data[1]))):
				corrupted_cells["%d:%d" % [int(position_data[0]), int(position_data[1])]] = _corruption_strength(position_data)
		if not use_surface_lod:
			_draw_corruption(latest_snapshot.corruption_cells, corrupted_cells)
	var resources_started := Time.get_ticks_usec()
	if latest_snapshot:
		_draw_settlement_wear_network(latest_snapshot.buildings, visible_cells)
	_draw_resource_nodes(latest_snapshot.resource_nodes if latest_snapshot else current_blueprint.resource_nodes, corrupted_cells, visible_cells)
	if latest_snapshot:
		_draw_terrain_effects(latest_snapshot.terrain_effects, true, visible_cells)
		_draw_terrain_work_designations(latest_snapshot.terrain_work, visible_cells)
	draw_profile_usec["resources_effects"] = Time.get_ticks_usec() - resources_started
	var entities_started := Time.get_ticks_usec()
	if latest_snapshot:
		_draw_magic_circle_sites(latest_snapshot.magic_circles, visible_cells)
		_draw_loose_items(latest_snapshot.loose_items)
	if latest_snapshot:
		for building in latest_snapshot.buildings:
			if not visible_cells.intersects(Rect2(Vector2(float(building.x), float(building.y)), Vector2(float(building.width), float(building.height)))):
				continue
			_draw_building(building)
			if bool(building.get("review_tier_label", false)):
				_draw_review_tier_number(Vector2(float(building.x), float(building.y)) * TILE_PIXELS + Vector2(3, 3), int(building.get("tier", 1)))
			elif int(building.get("review_state_label", 0)) > 0:
				_draw_review_tier_number(Vector2(float(building.x), float(building.y)) * TILE_PIXELS + Vector2(3, 3), int(building.review_state_label))
			if selected_kind == &"building" and int(building.id) == selected_entity_id:
				var selected_rect := Rect2(Vector2(building.x, building.y) * TILE_PIXELS, Vector2(building.width, building.height) * TILE_PIXELS)
				draw_rect(selected_rect.grow(3.0), Color("72ffcf"), false, 3.0)
		for villager in latest_snapshot.villagers:
			if not visible_cells.has_point(Vector2(float(villager.x), float(villager.y))):
				continue
			_draw_villager(villager)
			if selected_kind == &"villager" and int(villager.id) == selected_entity_id:
				draw_arc(Vector2(float(villager.x), float(villager.y)) * TILE_PIXELS, 7.0, 0.0, TAU, 24, Color("72ffcf"), 2.0)
		for nomad in latest_snapshot.nomads:
			if not visible_cells.has_point(Vector2(float(nomad.x), float(nomad.y))):
				continue
			_draw_villager(nomad)
			var nomad_center := Vector2(float(nomad.x), float(nomad.y)) * TILE_PIXELS
			draw_arc(nomad_center, 8.0, -PI * 0.82, -PI * 0.18, 8, Color("d3ad63"), 2.0)
			if selected_kind == &"nomad" and int(nomad.id) == selected_entity_id:
				draw_arc(nomad_center, 9.0, 0.0, TAU, 24, Color("ffd98a"), 2.0)
		for golem in latest_snapshot.golems:
			if not visible_cells.has_point(Vector2(float(golem.x), float(golem.y))):
				continue
			_draw_golem(golem)
			if selected_kind == &"golem" and int(golem.id) == selected_entity_id:
				draw_arc(Vector2(float(golem.x), float(golem.y)) * TILE_PIXELS, 9.0, 0.0, TAU, 24, Color("72ffcf"), 2.0)
		for animal in latest_snapshot.animals:
			if not visible_cells.has_point(Vector2(float(animal.x), float(animal.y))):
				continue
			_draw_animal(animal)
			if selected_kind == &"animal" and int(animal.id) == selected_entity_id:
				draw_arc(Vector2(float(animal.x), float(animal.y)) * TILE_PIXELS, 8.0, 0.0, TAU, 24, Color("72ffcf"), 2.0)
		for monster in latest_snapshot.monsters:
			if not visible_cells.has_point(Vector2(float(monster.x), float(monster.y))):
				continue
			_draw_monster(monster)
			if selected_kind == &"monster" and int(monster.id) == selected_entity_id:
				draw_arc(Vector2(float(monster.x), float(monster.y)) * TILE_PIXELS, 9.0, 0.0, TAU, 24, Color("ffcf6b"), 2.0)
		for ghost in latest_snapshot.ghosts:
			if not visible_cells.has_point(Vector2(float(ghost.x), float(ghost.y))):
				continue
			_draw_ghost(ghost)
		_draw_held_entity(latest_snapshot.held_entity)
		_draw_spell_effects(latest_snapshot.tick)
		_draw_weather(latest_snapshot)
		_draw_night_tint(latest_snapshot.day_fraction)
		_draw_event_atmosphere(latest_snapshot)
	draw_profile_usec["entities_weather"] = Time.get_ticks_usec() - entities_started
	if not pending_building_id.is_empty():
		_draw_placement_ghost()
	elif not pending_spell_id.is_empty():
		_draw_spell_target()
	elif not pending_terrain_action.is_empty():
		_draw_terrain_work_preview()
	draw_profile_usec["total"] = Time.get_ticks_usec() - profile_started

func _draw_held_entity(held: Dictionary) -> void:
	if held.is_empty():
		return
	var kind := String(held.get("kind", ""))
	var entity: Dictionary = held.get("payload", {}).duplicate(true)
	var center := (Vector2(pointer_cell) + Vector2(0.5, 0.5)) * TILE_PIXELS
	entity.x = float(pointer_cell.x) + 0.5
	entity.y = float(pointer_cell.y) + 0.5
	draw_circle(center, 12.0, Color(0.98, 0.82, 0.44, 0.11))
	draw_arc(center, 12.0, 0.0, TAU, 20, Color(0.98, 0.85, 0.53, 0.88), 2.0)
	match kind:
		"villager": _draw_villager(entity)
		"nomad": _draw_villager(entity)
		"animal": _draw_animal(entity)
		"golem": _draw_golem(entity)
		"monster": _draw_monster(entity)
		"resource":
			entity.x = pointer_cell.x
			entity.y = pointer_cell.y
			_draw_loose_items([entity])
	# Three separated native-pixel fingers read as a grip without covering the
	# held payload or abandoning the minimal sprite language.
	draw_rect(Rect2(center + Vector2(-7, -14), Vector2(4, 7)), Color("ffe8a6"), true)
	draw_rect(Rect2(center + Vector2(-1, -16), Vector2(4, 8)), Color("fff2c2"), true)
	draw_rect(Rect2(center + Vector2(5, -14), Vector2(3, 7)), Color("ffe8a6"), true)

func _visible_cell_rect(padding: float = 0.0) -> Rect2:
	if camera == null:
		return Rect2(Vector2.ZERO, Vector2(current_blueprint.width, current_blueprint.height) if current_blueprint != null else Vector2.ZERO)
	var viewport_world_size := get_viewport_rect().size / maxf(camera.zoom.x, 0.001) / TILE_PIXELS
	return Rect2(Vector2(camera.position) / TILE_PIXELS - viewport_world_size * 0.5, viewport_world_size).grow(padding)

func _draw_terrain_effects(effects: Array, flames_only: bool = false, visible_cells: Rect2 = Rect2(), include_cached_surfaces: bool = false) -> void:
	var occupied_by_kind: Dictionary = {}
	for effect_data in effects:
		if effect_data is not Array or effect_data.size() < 4:
			continue
		var kind := String(effect_data[2])
		if flames_only and kind != "fire":
			continue
		if not flames_only and not include_cached_surfaces and kind != "hole":
			continue
		if not occupied_by_kind.has(kind):
			occupied_by_kind[kind] = {}
		occupied_by_kind[kind]["%d:%d" % [int(effect_data[0]), int(effect_data[1])]] = true
	for effect_data in effects:
		if effect_data is not Array or effect_data.size() < 4:
			continue
		var cell := Vector2i(int(effect_data[0]), int(effect_data[1]))
		if visible_cells.has_area() and not visible_cells.has_point(Vector2(cell)):
			continue
		var kind := String(effect_data[2])
		if not flames_only and not include_cached_surfaces and kind != "hole":
			continue
		if flames_only and kind != "fire":
			continue
		var intensity := clampf(float(effect_data[3]), 0.0, 1.0)
		var occupied: Dictionary = occupied_by_kind.get(kind, {})
		var center := (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_PIXELS
		var effect_hash := posmod(cell.x * cell.x * 1741 + cell.y * cell.y * 3253 + cell.x * cell.y * 953 + (current_blueprint.seed if current_blueprint else 0) * 113, 104729)
		if not flames_only:
			var fringe_color: Color = {
				"mud": Color(0.25, 0.15, 0.08, 0.10 + intensity * 0.05),
				"flood": Color(0.16, 0.45, 0.54, 0.09 + intensity * 0.06),
				"ash": Color(0.18, 0.18, 0.17, 0.09 + intensity * 0.05),
				"fire": Color(0.21, 0.085, 0.045, 0.11 + intensity * 0.06),
				"hole": Color(0.30, 0.19, 0.095, 0.18 + intensity * 0.08),
				"illuminated": Color(0.96, 0.84, 0.34, 0.08 + intensity * 0.06),
			}.get(kind, Color.TRANSPARENT)
			_draw_surface_effect_fringe(cell, occupied, fringe_color, effect_hash)
		match kind:
			"illuminated":
				if flames_only: continue
				# Sparse ground glints read as divine light without painting an
				# opaque disc over the terrain or obscuring units on small screens.
				if effect_hash % 7 == 0:
					var glint := 2.0 + float(effect_hash % 3)
					draw_line(center + Vector2(-glint, 0), center + Vector2(glint, 0), Color(1.0, 0.90, 0.45, 0.52), 1.0)
					draw_line(center + Vector2(0, -glint), center + Vector2(0, glint), Color(1.0, 0.96, 0.65, 0.44), 1.0)
			"hole":
				if flames_only: continue
				# A small, fully top-down depression: broken soil lip, darker compact
				# interior and a few bright freshly turned clods. No side facade.
				var skew := float(effect_hash % 3 - 1)
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-5, -2), center + Vector2(-2 + skew, -5),
					center + Vector2(4, -4), center + Vector2(6, 0),
					center + Vector2(3 - skew, 5), center + Vector2(-4, 4),
				]), Color(0.40, 0.27, 0.13, 0.92))
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-3, -1), center + Vector2(-1 + skew, -3),
					center + Vector2(3, -2), center + Vector2(4, 1),
					center + Vector2(2, 3), center + Vector2(-3, 2),
				]), Color(0.095, 0.065, 0.045, 0.96))
				draw_line(center + Vector2(-4, 3), center + Vector2(-1, 4), Color(0.58, 0.39, 0.18, 0.85), 1.0)
				if effect_hash % 2 == 0:
					draw_rect(Rect2(center + Vector2(4, -3), Vector2(2, 2)), Color(0.48, 0.32, 0.15, 0.88), true)
			"mud":
				if flames_only: continue
				_draw_corruption_mask_cell(cell, occupied, 2, Color(0.22, 0.13, 0.075, 0.22 + intensity * 0.30))
				if effect_hash % 5 == 0:
					draw_line(center + Vector2(-3, 1), center + Vector2(3, 0), Color(0.38, 0.25, 0.14, 0.44), 1.0)
				if effect_hash % 11 == 0:
					draw_rect(Rect2(center + Vector2(-2, -1), Vector2(4, 2)), Color(0.10, 0.09, 0.07, 0.24), true)
			"flood":
				if flames_only: continue
				_draw_corruption_mask_cell(cell, occupied, 1, Color(0.12, 0.39, 0.50, 0.25 + intensity * 0.30))
				if effect_hash % 3 == 0:
					var ripple_length := 3 + effect_hash % 4
					draw_line(center + Vector2(-float(ripple_length) * 0.5, -1), center + Vector2(float(ripple_length) * 0.5, -1), Color(0.48, 0.76, 0.80, 0.42), 1.0)
			"ash":
				if flames_only: continue
				_draw_corruption_mask_cell(cell, occupied, 2, Color(0.17, 0.17, 0.16, 0.22 + intensity * 0.34))
				var ash_block := Vector2i(floori(float(cell.x) / 5.0), floori(float(cell.y) / 4.0))
				var ash_hash := posmod(ash_block.x * ash_block.x * 2903 + ash_block.y * ash_block.y * 4513 + ash_block.x * ash_block.y * 1877 + current_blueprint.seed * 127, 104729)
				var ash_anchor := Vector2i(ash_block.x * 5 + posmod(ash_hash, 5), ash_block.y * 4 + posmod(ash_hash / 13, 4))
				if cell == ash_anchor:
					var side := -1.0 if ash_hash % 2 == 0 else 1.0
					draw_colored_polygon(PackedVector2Array([
						center + Vector2(-5 * side, 2), center + Vector2(-2 * side, -3), center + Vector2(3 * side, -2),
						center + Vector2(6 * side, 2), center + Vector2(1 * side, 4),
					]), Color(0.10, 0.095, 0.09, 0.48))
					draw_line(center + Vector2(-4 * side, 2), center + Vector2(4 * side, -2), Color(0.07, 0.065, 0.06, 0.70), 1.0)
			"fire":
				if not flames_only:
					_draw_corruption_mask_cell(cell, occupied, 2, Color(0.15, 0.075, 0.045, 0.30 + intensity * 0.28))
					continue
				var fire_block := Vector2i(floori(float(cell.x) / 4.0), floori(float(cell.y) / 3.0))
				var fire_hash := posmod(fire_block.x * fire_block.x * 2903 + fire_block.y * fire_block.y * 4513 + fire_block.x * fire_block.y * 1877 + current_blueprint.seed * 139, 104729)
				var fire_anchor := Vector2i(fire_block.x * 4 + posmod(fire_hash, 4), fire_block.y * 3 + posmod(fire_hash / 11, 3))
				if cell != fire_anchor:
					continue
				var phase := posmod(int(SimulationHost.tick / 2) + fire_hash, 4)
				var flame_height := 5 + phase
				var flame_offset := Vector2(float(posmod(fire_hash / 17, 3) - 1), float(posmod(fire_hash / 29, 3) - 1))
				center += flame_offset
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-4, 3), center + Vector2(-2, -flame_height), center + Vector2(0, -2),
					center + Vector2(2, -flame_height - 2), center + Vector2(5, 3),
				]), Color(0.88, 0.24, 0.075, 0.90))
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-2, 3), center + Vector2(0, -flame_height + 1), center + Vector2(2, 0), center + Vector2(3, 3),
				]), Color(1.0, 0.72, 0.15, 0.94))
				draw_rect(Rect2(center + Vector2(-1, 0), Vector2(2, 4)), Color(1.0, 0.92, 0.45, 0.92), true)

func _draw_surface_effect_fringe(cell: Vector2i, occupied: Dictionary, color: Color, effect_hash: int) -> void:
	if color.a <= 0.0:
		return
	var center := (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_PIXELS
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for direction_i in directions:
		if occupied.has("%d:%d" % [cell.x + direction_i.x, cell.y + direction_i.y]):
			continue
		var local_hash := posmod(effect_hash + direction_i.x * 7919 + direction_i.y * 3571, 104729)
		if local_hash % 4 == 0:
			continue
		var direction := Vector2(direction_i)
		var tangent := Vector2(-direction.y, direction.x)
		var edge := center + direction * (TILE_PIXELS * 0.5 - 0.5)
		var reach := 2.0 + float(local_hash % 4)
		var half_width := 2.0 + float(posmod(local_hash / 7, 3))
		draw_colored_polygon(PackedVector2Array([
			edge - tangent * half_width - direction,
			edge + tangent * half_width - direction,
			edge + direction * reach + tangent * (1.0 + float(local_hash % 2)),
			edge + direction * (reach + 1.0) - tangent * 1.0,
		]), color)

func _draw_terrain_work_designations(work_items: Array, visible_cells: Rect2 = Rect2()) -> void:
	var colors := {
		"clear": Color("e6bf67"),
		"dig": Color("d98655"),
		"fill": Color("76bfe2"),
		"restore": Color("74d4a1"),
	}
	for item in work_items:
		if item is not Array or item.size() < 5:
			continue
		var cell := Vector2i(int(item[0]), int(item[1]))
		if visible_cells.has_area() and not visible_cells.has_point(Vector2(cell)):
			continue
		var action := String(item[2])
		var progress := clampf(float(item[3]), 0.0, 1.0)
		var color: Color = colors.get(action, Color.WHITE)
		var rect := Rect2(Vector2(cell) * TILE_PIXELS + Vector2(0.5, 0.5), Vector2(TILE_PIXELS - 1.0, TILE_PIXELS - 1.0))
		var center := rect.get_center()
		draw_circle(center, 6.2, Color(0.035, 0.045, 0.035, 0.70))
		draw_arc(center, 6.2, 0.0, TAU, 16, color.darkened(0.18), 2.0)
		draw_rect(rect, Color(color.r, color.g, color.b, 0.14), true)
		var corner := 2.5
		for corner_data in [[rect.position, Vector2.ONE], [Vector2(rect.end.x, rect.position.y), Vector2(-1, 1)], [rect.end, -Vector2.ONE], [Vector2(rect.position.x, rect.end.y), Vector2(1, -1)]]:
			var origin: Vector2 = corner_data[0]
			var direction: Vector2 = corner_data[1]
			draw_line(origin, origin + Vector2(direction.x * corner, 0), color, 1.0)
			draw_line(origin, origin + Vector2(0, direction.y * corner), color, 1.0)
		match action:
			"clear":
				draw_line(center + Vector2(-3, -3), center + Vector2(3, 3), color.lightened(0.22), 1.5)
				draw_line(center + Vector2(3, -3), center + Vector2(-3, 3), color.lightened(0.22), 1.5)
			"dig":
				draw_colored_polygon(PackedVector2Array([center + Vector2(-3, -2), center + Vector2(3, -2), center + Vector2(0, 3)]), color.lightened(0.18))
			"fill":
				draw_line(center + Vector2(-3, 0), center + Vector2(3, 0), color.lightened(0.22), 2.0)
				draw_line(center + Vector2(0, -3), center + Vector2(0, 3), color.lightened(0.22), 2.0)
			"restore":
				draw_arc(center, 3.2, 0.25, TAU - 0.65, 10, color.lightened(0.24), 1.5)
				draw_colored_polygon(PackedVector2Array([center + Vector2(1, -4), center + Vector2(4, -3), center + Vector2(2, -1)]), color.lightened(0.24))
		if progress > 0.0:
			draw_rect(Rect2(center + Vector2(-6, 7), Vector2(12, 2)), Color(0.02, 0.025, 0.02, 0.82), true)
			draw_rect(Rect2(center + Vector2(-5, 7), Vector2(10 * progress, 1)), color.lightened(0.18), true)

func _draw_terrain_work_preview() -> void:
	var valid := SimulationHost.can_designate_terrain_work(pending_terrain_action, pointer_cell)
	var color := Color("72f0b5") if valid else Color("f06459")
	var rect := Rect2(Vector2(pointer_cell) * TILE_PIXELS, Vector2.ONE * TILE_PIXELS)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.18), true)
	draw_rect(rect.grow(1.0), color, false, 1.5)

func _draw_resource_nodes(nodes: Array, corrupted_cells: Dictionary = {}, visible_cells: Rect2 = Rect2()) -> void:
	if camera != null and camera.zoom.x < 0.94:
		return
	# Wood remains individually addressable to the simulation, but living crowns
	# are the connected forest material rendered by terrain chunks. Resource nodes
	# only enter this object pass after harvesting exposes a stump.
	for node in nodes:
		var amount := int(node.get("amount", 0))
		var initial_amount := maxi(1, int(node.get("initial_amount", amount)))
		var fullness := clampf(float(amount) / float(initial_amount), 0.0, 1.0)
		var resource_cell := Vector2i(int(node.x), int(node.y))
		if visible_cells.has_area() and not visible_cells.has_point(Vector2(resource_cell)):
			continue
		var center := Vector2(float(node.x) + 0.5, float(node.y) + 0.5) * TILE_PIXELS
		var material_depth := 4
		if current_blueprint != null and String(node.id) in ["wood", "rock", "iron_ore", "gold_ore", "crystal"]:
			var material_family: StringName = &"forest" if String(node.id) == "wood" else (&"crystal" if String(node.id) == "crystal" else &"rock")
			material_depth = _connected_material_depth(current_blueprint, resource_cell.x, resource_cell.y, material_family, 3)
			center = _embedded_resource_center(resource_cell, center, material_family, material_depth)
		var corrupted := corrupted_cells.has("%d:%d" % [int(node.x), int(node.y)])
		if camera != null and camera.zoom.x < 0.94:
			var lod_object: StringName = {
				"wood": &"stump" if amount <= 0 else &"tree",
				"rock": &"rubble" if amount <= 0 else &"rock",
				"iron_ore": &"rubble" if amount <= 0 else &"iron_rock",
				"gold_ore": &"rubble" if amount <= 0 else &"gold_rock",
				"crystal": &"crystal",
				"raw_vegetables": &"wild_food",
			}.get(String(node.id), &"rubble")
			_draw_world_object_lod(center, lod_object, int(node.get("variant", 0)), fullness, corrupted)
			continue
		match node.id:
			"wood":
				# Living wood is represented by the continuous forest material. Only a
				# depleted node becomes an individually readable top-down stump.
				if amount <= 0:
					_draw_world_object(center, &"stump", int(node.get("variant", 0)), fullness, corrupted, material_depth)
			"rock":
				# Live common stone is already the connected rocky formation; rendering
				# each node as a boulder breaks that mass into pebbles. Depletion exposes
				# only a small rubble scar.
				if amount <= 0:
					_draw_world_object(center, &"rubble", int(node.get("variant", 0)), fullness, corrupted, material_depth)
			"iron_ore": _draw_world_object(center, &"rubble" if amount <= 0 else &"iron_rock", int(node.get("variant", 0)), fullness, corrupted, material_depth)
			"gold_ore": _draw_world_object(center, &"rubble" if amount <= 0 else &"gold_rock", int(node.get("variant", 0)), fullness, corrupted, material_depth)
			"crystal": _draw_world_object(center, &"crystal", int(node.get("variant", 0)), fullness, corrupted, material_depth)
			"raw_vegetables": _draw_world_object(center, &"wild_food", int(node.get("variant", 0)), fullness, corrupted)
			"flower": _draw_world_object(center, &"flower", int(node.get("variant", 0)), fullness, corrupted)
		if int(node.get("review_stage_label", 0)) > 0:
			_draw_review_tier_number(center + Vector2(-3, -12), int(node.review_stage_label))

func _tree_canopy_palette(corrupted: bool = false) -> Array[Color]:
	if corrupted:
		return [Color("261326"), Color("4d2742"), Color("6c3559"), Color("925078")]
	match terrain_season:
		&"Spring": return [Color("104b22"), Color("2c7b31"), Color("45a13c"), Color("67b94b")]
		&"Summer": return [Color("123d20"), Color("2b682a"), Color("467f32"), Color("68973d")]
		&"Autumn": return [Color("39401f"), Color("76502a"), Color("a86a2f"), Color("c28a3e")]
		&"Winter": return [Color("274638"), Color("6d8574"), Color("aab8aa"), Color("d4dbd3")]
		_: return [Color("10491f"), Color("246e2b"), Color("348632"), Color("43a13a")]

func _draw_world_object_lod(center: Vector2, object_id: StringName, variant: int, fullness: float, corrupted: bool) -> void:
	# Wide mobile views already carry forest/stone/crystal material in the cached
	# terrain. Resource LOD supplies a sparse silhouette with three to five draw
	# calls instead of the full inspection-scale cluster for every visible node.
	match object_id:
		&"tree":
			var shadow := Color("153f1e") if not corrupted else Color("382033")
			var middle := Color("2d792e") if not corrupted else Color("5d294d")
			var high := Color("5aa23d") if not corrupted else Color("8a456b")
			var spread := 5.0 + float(variant % 3)
			draw_rect(Rect2(center + Vector2(-1, 0), Vector2(2, 5)), Color("56371f"), true)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-spread, 1), center + Vector2(-spread + 2, -4), center + Vector2(-1, -7), center + Vector2(spread - 1, -4), center + Vector2(spread, 1), center + Vector2(1, 4), center + Vector2(-3, 3)]), shadow)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -1), center + Vector2(-1, -6), center + Vector2(4, -4), center + Vector2(5, 0), center + Vector2(0, 2)]), middle)
			draw_rect(Rect2(center + Vector2(-1, -5), Vector2(4, 2)), high, true)
		&"rock", &"iron_rock", &"gold_rock":
			var base := Color("777c7a")
			if object_id == &"iron_rock": base = Color("92786d")
			elif object_id == &"gold_rock": base = Color("ae8936")
			if corrupted: base = base.lerp(Color("6b3457"), 0.30)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-6, 2), center + Vector2(-4, -3), center + Vector2(0, -5), center + Vector2(6, -1), center + Vector2(4, 4), center + Vector2(-2, 5)]), base.darkened(0.24))
			draw_colored_polygon(PackedVector2Array([center + Vector2(-4, 0), center + Vector2(-2, -3), center + Vector2(3, -3), center + Vector2(5, 0), center + Vector2(2, 2), center + Vector2(-3, 3)]), base)
			draw_line(center + Vector2(-2, -2), center + Vector2(2, -3), base.lightened(0.28), 1.0)
		&"crystal":
			var crystal := Color("45bdc9") if not corrupted else Color("a34391")
			draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 3), center + Vector2(-2, -7), center + Vector2(0, 1), center + Vector2(3, -9), center + Vector2(6, 3)]), crystal.darkened(0.28))
			draw_colored_polygon(PackedVector2Array([center + Vector2(-2, 1), center + Vector2(0, -5), center + Vector2(2, 1)]), crystal.lightened(0.34))
		&"wild_food":
			var leaf := Color("668d32") if not corrupted else Color("6e5433")
			draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 2), center + Vector2(-2, -3), center, center + Vector2(2, -4), center + Vector2(5, 2)]), leaf)
			if fullness > 0.25:
				draw_rect(Rect2(center + Vector2(-1, -1), Vector2(2, 2)), Color("d2ad43") if not corrupted else Color("765444"), true)
		&"stump", &"rubble":
			var remnant := Color("68452a") if object_id == &"stump" else Color("6f706c")
			draw_colored_polygon(PackedVector2Array([center + Vector2(-4, 2), center + Vector2(-2, -2), center + Vector2(3, -2), center + Vector2(5, 2), center + Vector2(0, 4)]), remnant.darkened(0.16))
			draw_line(center + Vector2(-2, -1), center + Vector2(2, -1), remnant.lightened(0.24), 1.0)
func _embedded_resource_center(cell: Vector2i, center: Vector2, family: StringName, depth: int) -> Vector2:
	if current_blueprint == null or depth > 2:
		return center
	var inward := Vector2.ZERO
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		if _cell_family(current_blueprint, cell + direction) == family:
			inward += Vector2(direction)
	if inward.length_squared() <= 0.01:
		return center
	return center + inward.normalized() * (4.0 if depth == 1 else 2.0)

func _draw_world_object(center: Vector2, object_id: StringName, variant := 0, fullness: float = 1.0, corrupted: bool = false, material_depth: int = 4, tree_links: int = 0) -> void:
	var color: Color = WORLD_OBJECT_PIXEL_COLORS.get(object_id, Color.WHITE)
	if corrupted and object_id in [&"rock", &"iron_rock", &"gold_rock", &"rubble"]:
		color = color.lerp(Color("774060"), 0.24)
	elif corrupted and object_id == &"crystal":
		color = Color("b34aa0")
	elif corrupted and object_id == &"stump":
		color = Color("49303e")
	match object_id:
		&"tree":
			# Strict top-down canopy. Trunks are hidden beneath living crowns, and linked
			# nodes overlap the shared bridges drawn in _draw_tree_canopy_connections.
			# Isolated nodes become subdued undergrowth patches, not lollipop trees.
			var depletion_stage := 0 if fullness > 0.66 else (1 if fullness > 0.33 else 2)
			var crown_scale: int = maxi(-2, int([0, 1, 2, 1][posmod(variant, 4)]) - depletion_stage)
			var palette := _tree_canopy_palette(corrupted)
			var shadow: Color = palette[0]
			var middle: Color = palette[1]
			var high: Color = palette[2]
			var bright: Color = palette[3]
			if material_depth <= 1 and not corrupted:
				middle = shadow.lerp(middle, 0.72)
				high = middle.lerp(high, 0.62)
				bright = high.lightened(0.075)
			var connected := tree_links > 0
			var horizontal_radius: int = (14 if connected else 7) + crown_scale
			var vertical_radius: int = (12 if connected else 6) + crown_scale
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-horizontal_radius, 1), center + Vector2(-horizontal_radius + 1, -4),
				center + Vector2(-horizontal_radius + 5, -vertical_radius + 2), center + Vector2(-6, -vertical_radius),
				center + Vector2(-1, -vertical_radius - 1), center + Vector2(6, -vertical_radius + 1),
				center + Vector2(horizontal_radius - 3, -vertical_radius + 4), center + Vector2(horizontal_radius, -3),
				center + Vector2(horizontal_radius + 1, 3), center + Vector2(horizontal_radius - 4, vertical_radius - 3),
				center + Vector2(6, vertical_radius), center + Vector2(0, vertical_radius + 1),
				center + Vector2(-7, vertical_radius - 1), center + Vector2(-horizontal_radius + 3, vertical_radius - 4),
				center + Vector2(-horizontal_radius - 1, 4),
			]), shadow)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-horizontal_radius + 2, 1), center + Vector2(-horizontal_radius + 3, -3),
				center + Vector2(-3, -vertical_radius + 1), center + Vector2(1, -vertical_radius),
				center + Vector2(horizontal_radius - 3, -3), center + Vector2(horizontal_radius - 2, 1),
				center + Vector2(2, vertical_radius - 2), center + Vector2(-3, vertical_radius - 1),
				center + Vector2(-horizontal_radius + 2, 3),
			]), middle)
			if connected:
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(-1, -6), center + Vector2(4, -vertical_radius + 1), center + Vector2(horizontal_radius - 4, -6),
					center + Vector2(horizontal_radius - 2, -1), center + Vector2(horizontal_radius - 5, 5),
					center + Vector2(5, vertical_radius - 3), center + Vector2(0, 3),
				]), high)
				draw_rect(Rect2(center + Vector2(-2 + posmod(variant, 5), -6), Vector2(4, 2)), bright.darkened(0.08), true)
			elif fullness > 0.70:
				# One muted inner plane is enough to signal harvestable foliage without
				# turning a lone resource node into a freestanding tree icon.
				draw_rect(Rect2(center + Vector2(-2 + posmod(variant, 3), -2), Vector2(4, 2)), middle.lightened(0.055), true)
			if corrupted:
				# Exposed veins and sparse luminous fruiting bodies connect the sick
				# canopy to the ground tendrils without turning the whole crown neon.
				draw_line(center + Vector2(-4, 1), center + Vector2(1, -4), Color("b05283"), 1.0)
				draw_line(center + Vector2(1, -4), center + Vector2(5, -1), Color("7b355f"), 1.0)
				draw_rect(Rect2(center + Vector2(-4 + posmod(variant, 2) * 7, -5), Vector2(2, 2)), Color("d16aa3"), true)
		&"stump":
			draw_rect(Rect2(center + Vector2(-4, -2), Vector2(8, 5)), Color("4d3322"), true)
			draw_rect(Rect2(center + Vector2(-3, -3), Vector2(6, 4)), color, true)
			draw_rect(Rect2(center + Vector2(-1, -2), Vector2(3, 2)), color.lightened(0.22), true)
		&"dead_tree":
			draw_rect(Rect2(center + Vector2(-1, -6), Vector2(3, 13)), color, true)
			draw_rect(Rect2(center + Vector2(-6, -4), Vector2(6, 2)), color, true)
			draw_rect(Rect2(center + Vector2(2, -1), Vector2(5, 2)), color.darkened(0.18), true)
		&"rock", &"iron_rock", &"gold_rock":
			_draw_rock_outcrop(center, color, variant, object_id, fullness, material_depth)
		&"crystal":
			if fullness <= 0.0:
				draw_rect(Rect2(center + Vector2(-3, 2), Vector2(6, 2)), color.darkened(0.48), true)
				draw_rect(Rect2(center + Vector2(1, 0), Vector2(2, 3)), color.darkened(0.22), true)
			elif fullness < 0.45:
				_draw_crystal(center, color.darkened(0.10), 5)
			else:
				_draw_crystal(center - Vector2(2, 0), color, 7)
				_draw_crystal(center + Vector2(4, 2), color.darkened(0.18), 5 if fullness > 0.72 else 3)
			if corrupted:
				draw_line(center + Vector2(-5, 5), center + Vector2(5, 5), Color("5d234f"), 1.0)
				draw_rect(Rect2(center + Vector2(-1, -5), Vector2(2, 2)), Color("e07ac2"), true)
		&"crop":
			for x in [-4, 0, 4]:
				draw_rect(Rect2(center + Vector2(x, -4), Vector2(2, 9)), color.darkened(0.12), true)
				draw_rect(Rect2(center + Vector2(x - 2, -2), Vector2(5, 2)), color, true)
		&"wild_food":
			var stem_color := Color("443d32") if corrupted else Color("577b31")
			var leaf_color := Color("674050") if corrupted else Color("7fa13d")
			var fruit_color := Color("8d416c") if corrupted else color
			if fullness <= 0.0:
				draw_rect(Rect2(center + Vector2(-3, 2), Vector2(6, 2)), stem_color.darkened(0.15), true)
				draw_rect(Rect2(center + Vector2(-1, -1), Vector2(1, 4)), stem_color, true)
			else:
				var food_width := 5 if fullness < 0.5 else 8
				draw_rect(Rect2(center + Vector2(-1, -4), Vector2(2, 8)), stem_color, true)
				draw_rect(Rect2(center + Vector2(-food_width * 0.5, -2), Vector2(food_width, 3)), leaf_color, true)
				draw_rect(Rect2(center + Vector2(-2, 2), Vector2(5 if fullness > 0.5 else 3, 4)), fruit_color.darkened((1.0 - fullness) * 0.18), true)
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

func _draw_rock_outcrop(center: Vector2, color: Color, variant: int, object_id: StringName, fullness: float = 1.0, material_depth: int = 4) -> void:
	if material_depth <= 1 and object_id == &"rock":
		color = color.darkened(0.055)
	if fullness < 0.30:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 3), center + Vector2(-4, -1), center + Vector2(-1, -3), center + Vector2(1, 1), center + Vector2(-1, 4)]), color.darkened(0.16))
		draw_colored_polygon(PackedVector2Array([center + Vector2(1, 4), center + Vector2(2, 0), center + Vector2(5, -1), center + Vector2(6, 3), center + Vector2(4, 5)]), color.darkened(0.24))
		return
	# The broad talus apron shares the shelf palette and anchors the harvestable
	# outcrop into its connected geology before the raised facets are drawn.
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-10, 4), center + Vector2(-8, -3), center + Vector2(-3, -7),
		center + Vector2(5, -6), center + Vector2(10, -1), center + Vector2(9, 5),
		center + Vector2(3, 8), center + Vector2(-5, 7),
	]), color.darkened(0.18))
	for chip in [Vector2(-10, 5), Vector2(-7, -4), Vector2(8, 4), Vector2(5, -7)]:
		draw_rect(Rect2(center + chip, Vector2(3, 2)), color.darkened(0.10 if chip.y > 0 else 0.02), true)
	var shapes := [
		[Vector2(-5, 3), Vector2(-5, -1), Vector2(-2, -5), Vector2(4, -4), Vector2(6, 0), Vector2(4, 4), Vector2(-2, 5)],
		[Vector2(-7, 4), Vector2(-6, -3), Vector2(-1, -6), Vector2(6, -4), Vector2(7, 2), Vector2(3, 6), Vector2(-4, 6)],
		[Vector2(-8, 5), Vector2(-7, -2), Vector2(-3, -7), Vector2(5, -6), Vector2(8, -1), Vector2(6, 6), Vector2(-3, 7)],
		[Vector2(-6, 4), Vector2(-6, -2), Vector2(-2, -6), Vector2(5, -5), Vector2(7, 1), Vector2(3, 6), Vector2(-4, 5)],
	]
	var shape: Array = shapes[posmod(variant, shapes.size())]
	var shadow_points := PackedVector2Array()
	var body_points := PackedVector2Array()
	for point in shape:
		shadow_points.append(center + Vector2(point) + Vector2(0, 2))
		body_points.append(center + Vector2(point))
	draw_colored_polygon(shadow_points, Color(0.12, 0.14, 0.13, 0.72))
	draw_colored_polygon(body_points, color.darkened(0.08 + (1.0 - fullness) * 0.12))
	var top := PackedVector2Array([
		center + Vector2(-3, -1), center + Vector2(-1, -4), center + Vector2(3, -4),
		center + Vector2(5, -2), center + Vector2(2, 0), center + Vector2(-2, 1),
	])
	draw_colored_polygon(top, color.lightened(0.19))
	draw_line(center + Vector2(-1, 1), center + Vector2(3, 4), color.darkened(0.27), 1.0)
	if posmod(variant, 4) == 3:
		# A subordinate fragment makes one variant read as an outcrop cluster, not
		# simply a recolored copy of the same boulder.
		draw_colored_polygon(PackedVector2Array([center + Vector2(-8, 4), center + Vector2(-7, 0), center + Vector2(-4, -1), center + Vector2(-2, 2), center + Vector2(-4, 5)]), color.darkened(0.14))
	if object_id != &"rock":
		var ore := Color("aeb5b4") if object_id == &"iron_rock" else Color("d3a93f")
		draw_line(center + Vector2(-2, -2), center + Vector2(3, 1), ore, 2.0)

func _draw_loose_items(items: Array) -> void:
	for item in items:
		var center := Vector2(float(item.x) + 0.5, float(item.y) + 0.5) * TILE_PIXELS
		match String(item.resource_id):
			"suspicious_key":
				_draw_key(center, Color("e3c35b"))
				draw_rect(Rect2(center + Vector2(-7, 5), Vector2(15, 2)), Color(0.05, 0.04, 0.03, 0.42), true)
			"lootbox":
				_draw_lootbox(center, int(item.get("moves", 0)))
			_:
				_draw_resource_glyph(center, String(item.resource_id), mini(3, maxi(1, int(item.get("amount", 1)))))

func _draw_magic_circle_sites(circles: Array, visible_cells: Rect2) -> void:
	var pulse_tick := float(latest_snapshot.tick if latest_snapshot != null else 0)
	for circle in circles:
		var cell := Vector2(int(circle.get("x", -1)), int(circle.get("y", -1)))
		if not visible_cells.grow(4.0).has_point(cell):
			continue
		var center := (cell + Vector2(0.5, 0.5)) * TILE_PIXELS
		var phase := pulse_tick * 0.055 + float(int(circle.get("id", 0)) % 17)
		var glow := 0.74 + sin(phase) * 0.12
		var ink := Color(0.31, 0.18, 0.37, glow)
		var rune := Color(0.69, 0.43, 0.77, glow)
		draw_circle(center, 22.0, Color(0.07, 0.035, 0.08, 0.34))
		draw_arc(center, 20.0, 0.0, TAU, 28, ink, 2.0)
		draw_arc(center, 15.0, 0.0, TAU, 24, rune, 1.0)
		var points := PackedVector2Array()
		for index in 6:
			var angle := phase * 0.06 + TAU * float(index) / 6.0 - PI * 0.5
			points.append(center + Vector2(cos(angle), sin(angle)) * 13.0)
		for index in 6:
			draw_line(points[index], points[(index + 2) % 6], ink.lightened(0.16), 1.0)
		for index in 8:
			var angle := TAU * float(index) / 8.0
			var rune_center := center + Vector2(cos(angle), sin(angle)) * 20.0
			draw_rect(Rect2(rune_center - Vector2.ONE, Vector2(3, 3)), rune.lightened(0.15 if index % 2 == 0 else 0.0), true)
		draw_circle(center, 2.5, Color("d89ae7"))

func _draw_lootbox(center: Vector2, moves: int) -> void:
	# A compact orthographic chest: shadow, reinforced walnut lid, brass bands,
	# and an oversized lock remain distinct at the normal mobile zoom.
	draw_rect(Rect2(center + Vector2(-9, 6), Vector2(19, 4)), Color(0.04, 0.03, 0.025, 0.48), true)
	draw_rect(Rect2(center + Vector2(-10, -7), Vector2(20, 15)), Color("241810"), true)
	draw_rect(Rect2(center + Vector2(-8, -6), Vector2(16, 6)), Color("80502c"), true)
	draw_rect(Rect2(center + Vector2(-8, 1), Vector2(16, 5)), Color("604021"), true)
	draw_line(center + Vector2(-7, -3), center + Vector2(7, -3), Color("a56c36"), 1.0)
	for offset_x in [-6, 5]:
		draw_rect(Rect2(center + Vector2(offset_x, -7), Vector2(2, 14)), Color("b5924c"), true)
		draw_rect(Rect2(center + Vector2(offset_x, -5), Vector2(1, 10)), Color("e1c46a"), true)
	draw_rect(Rect2(center + Vector2(-3, -1), Vector2(6, 7)), Color("d0a94e"), true)
	draw_rect(Rect2(center + Vector2(-1, 1), Vector2(2, 3)), Color("37281b"), true)
	if moves > 0:
		draw_rect(Rect2(center + Vector2(7, -9), Vector2(3, 3)), Color("c96e49"), true)

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
	_draw_building_grounding(building, rect)
	if bool(building.get("destroyed", false)):
		_draw_destroyed_building(building, rect)
		return
	var complete: bool = building.completed
	var progress := float(building.progress) / maxf(1.0, float(building.build_time))
	if String(building.category) == "hostile":
		_draw_hostile_structure(building, rect, complete, progress)
		return
	if String(building.category) == "god_structure":
		_draw_god_structure(building, rect)
		_draw_building_status(building, rect)
		return
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

func _draw_settlement_wear_network(buildings: Array, visible_cells: Rect2) -> void:
	var sites: Array[Dictionary] = []
	for building in buildings:
		var category := String(building.get("category", ""))
		if not bool(building.get("completed", false)) or bool(building.get("destroyed", false)) or category in ["roads", "walls", "towers", "hostile", "god_structure"]:
			continue
		sites.append(building)
	sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("id", 0)) < int(b.get("id", 0)))
	for index in range(1, sites.size()):
		var site := sites[index]
		var site_center := Vector2(float(site.x) + float(site.width) * 0.5, float(site.y) + float(site.height))
		var nearest: Dictionary = {}
		var nearest_distance := INF
		for previous_index in index:
			var candidate := sites[previous_index]
			var candidate_center := Vector2(float(candidate.x) + float(candidate.width) * 0.5, float(candidate.y) + float(candidate.height))
			var candidate_distance := site_center.distance_squared_to(candidate_center)
			if candidate_distance < nearest_distance:
				nearest_distance = candidate_distance
				nearest = candidate
		if nearest.is_empty() or nearest_distance > 80.0 * 80.0:
			continue
		var nearest_center := Vector2(float(nearest.x) + float(nearest.width) * 0.5, float(nearest.y) + float(nearest.height))
		var path_bounds := Rect2(site_center, Vector2.ZERO).expand(nearest_center).grow(5.0)
		if not visible_cells.intersects(path_bounds):
			continue
		var start := site_center * TILE_PIXELS
		var finish := nearest_center * TILE_PIXELS
		var direction := (finish - start).normalized()
		var perpendicular := Vector2(-direction.y, direction.x)
		var seed := int(site.get("id", 0)) * 92821 + int(nearest.get("id", 0)) * 68917
		var bend := perpendicular * float(posmod(seed, 25) - 12)
		var path := PackedVector2Array([start, start.lerp(finish, 0.34) + bend, start.lerp(finish, 0.69) - bend * 0.38, finish])
		var soil := Color(0.31, 0.23, 0.13, 0.13)
		if current_blueprint != null and current_blueprint.biome_id in [&"desert", &"red_sands", &"dry_lands"]:
			soil = Color(0.37, 0.27, 0.14, 0.13)
		elif current_blueprint != null and current_blueprint.biome_id == &"marsh":
			soil = Color(0.13, 0.20, 0.16, 0.16)
		draw_polyline(path, soil, 6.0, false)
		draw_polyline(path, Color(soil.r + 0.035, soil.g + 0.025, soil.b + 0.015, soil.a + 0.06), 2.0, false)
		for dash_index in 5:
			var t := 0.12 + float(dash_index) * 0.18
			var point := start.lerp(finish, t) + bend * sin(t * PI) * 0.72
			draw_rect(Rect2(point.floor() + Vector2(posmod(seed + dash_index * 7, 3) - 1, 0), Vector2(3 + posmod(seed + dash_index * 11, 4), 1)), Color(soil.r, soil.g, soil.b, soil.a + 0.08), true)

func _draw_building_grounding(building: Dictionary, rect: Rect2) -> void:
	var category := String(building.get("category", ""))
	if category in ["roads", "walls", "towers", "hostile", "god_structure"]:
		return
	var seed := int(building.get("id", 0)) * 31 + String(building.get("definition_id", "")).hash()
	var wear := Color(0.32, 0.23, 0.12, 0.15)
	if current_blueprint != null and current_blueprint.biome_id in [&"desert", &"red_sands", &"dry_lands"]:
		wear = Color(0.38, 0.29, 0.15, 0.13)
	elif current_blueprint != null and current_blueprint.biome_id == &"marsh":
		wear = Color(0.16, 0.23, 0.17, 0.17)
	# Ground contact is directional: traffic leaves through the entrance and
	# working buildings accumulate a side yard. A full perimeter apron produced
	# identical circular halos and has deliberately been removed.
	var entrance_x := rect.position.x + rect.size.x * (0.43 + float(posmod(seed, 13)) / 100.0)
	var path_length := 6.0 + float(posmod(seed / 19, 5))
	var path_bend := float(posmod(seed / 23, 5) - 2)
	var path_color := Color(wear.r, wear.g, wear.b, wear.a * 1.22)
	draw_colored_polygon(PackedVector2Array([
		Vector2(entrance_x - 2, rect.end.y - 2),
		Vector2(entrance_x + 3, rect.end.y - 2),
		Vector2(entrance_x + path_bend + 2, rect.end.y + path_length - 1),
		Vector2(entrance_x + path_bend, rect.end.y + path_length + 1),
		Vector2(entrance_x + path_bend - 3, rect.end.y + path_length - 2),
	]), path_color)
	var workyard_categories := ["town_center", "food_water", "harvesting", "storage", "refining", "manufacturing", "golems", "trash"]
	if category not in workyard_categories:
		return
	var side := -1.0 if posmod(seed / 7, 2) == 0 else 1.0
	var yard_width := 5.0 + float(posmod(seed / 29, 4))
	var yard_top := rect.position.y + 3.0 + float(posmod(seed / 31, maxi(3, roundi(rect.size.y * 0.35))))
	var yard_height := minf(rect.size.y * 0.52, 8.0 + float(posmod(seed / 37, 5)))
	var edge_x := rect.position.x if side < 0.0 else rect.end.x
	var outer_x := edge_x + side * yard_width
	var yard_points := PackedVector2Array([
		Vector2(edge_x - side, yard_top),
		Vector2(outer_x, yard_top + float(posmod(seed / 41, 3))),
		Vector2(outer_x - side * float(posmod(seed / 43, 3)), yard_top + yard_height),
		Vector2(edge_x - side, yard_top + yard_height - 1.0),
	])
	draw_colored_polygon(yard_points, Color(wear.r, wear.g, wear.b, wear.a * 0.86))
	# A few tiny supply/debris marks make the patch functional and keep its edge
	# broken. They live only in the selected workyard, never around the building.
	for mark_index in 3:
		var mark_seed := posmod(seed + mark_index * 7919, 104729)
		var mark_x := lerpf(edge_x, outer_x, 0.35 + float(posmod(mark_seed, 5)) * 0.10)
		var mark_y := yard_top + 2.0 + float(posmod(mark_seed / 31, maxi(2, roundi(yard_height - 3.0))))
		draw_rect(Rect2(Vector2(mark_x, mark_y), Vector2(1 + mark_seed % 3, 1)), Color(wear.r, wear.g, wear.b, minf(0.28, wear.a + 0.07)), true)

func _draw_hostile_structure(building: Dictionary, rect: Rect2, complete: bool, progress: float) -> void:
	var role := String(building.get("hostile_role", ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id)).get("hostile", {}).get("role", "")))
	var seed := int(building.get("id", 0))
	var center := rect.get_center()
	var root_dark := Color("241020")
	var flesh := Color("5a244d")
	var vein := Color("9e3a7b")
	var glow := Color("dc68ad")
	if not complete:
		# Enemy construction grows inward from an irregular infected root bed. The
		# partial silhouette is intentionally unlike the settlement timber frame.
		for index in 5:
			var angle := TAU * float(index) / 5.0 + float(seed % 7) * 0.09
			var edge := center + Vector2(cos(angle), sin(angle)) * minf(rect.size.x, rect.size.y) * 0.44
			draw_line(edge, edge.lerp(center, clampf(0.25 + progress * 0.65, 0.25, 0.90)), root_dark, 2.0 + float(index % 2))
		var core_radius := maxf(2.0, minf(rect.size.x, rect.size.y) * 0.32 * progress)
		draw_circle(center, core_radius, flesh)
		draw_arc(center, core_radius + 2.0, -PI * 0.8, PI * (0.2 + progress * 1.5), 12, vein, 2.0)
		return
	match role:
		"road":
			var road_cell := Vector2i(int(building.x), int(building.y))
			var road_connections: Array[Vector2i] = []
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if _completed_hostile_segment_at(road_cell + direction, "road"):
					road_connections.append(direction)
			draw_rect(Rect2(center - Vector2(3, 3), Vector2(6, 6)), root_dark, true)
			for direction in road_connections:
				draw_rect(_segment_arm_rect(rect, direction, 6), root_dark, true)
			draw_rect(Rect2(center - Vector2(1, 1), Vector2(3, 3)), flesh, true)
			for direction in road_connections:
				draw_rect(_segment_arm_rect(rect, direction, 2), flesh, true)
			if posmod(seed, 5) == 0:
				draw_rect(Rect2(center - Vector2(1, 1), Vector2(2, 2)), glow, true)
			if posmod(seed, 7) == 0:
				var branch := Vector2(0, -4) if Vector2i.LEFT in road_connections or Vector2i.RIGHT in road_connections else Vector2(4, 0)
				draw_line(center, center + branch, vein.darkened(0.12), 1.0)
		"wall":
			var wall_cell := Vector2i(int(building.x), int(building.y))
			var wall_connections: Array[Vector2i] = []
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if _completed_hostile_segment_at(wall_cell + direction, "wall"):
					wall_connections.append(direction)
			draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 8)), root_dark, true)
			for direction in wall_connections:
				draw_rect(_segment_arm_rect(rect, direction, 8), root_dark, true)
			draw_rect(Rect2(center - Vector2(2, 3), Vector2(5, 6)), flesh, true)
			for direction in wall_connections:
				draw_rect(_segment_arm_rect(rect, direction, 5), flesh, true)
			draw_rect(Rect2(center + Vector2(-1, -4), Vector2(2, 3)), vein, true)
			if posmod(seed, 6) == 0:
				draw_rect(Rect2(center + Vector2(-1, -3), Vector2(2, 2)), glow, true)
			elif posmod(seed, 3) == 0:
				draw_rect(Rect2(center + Vector2(-1, -5), Vector2(2, 2)), flesh.lightened(0.12), true)
		"tower":
			draw_circle(center + Vector2(0, 3), minf(rect.size.x, rect.size.y) * 0.40, root_dark)
			for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				draw_line(center + direction * 5.0, center + direction * minf(rect.size.x, rect.size.y) * 0.44, flesh, 5.0)
			draw_circle(center, 10.0, flesh)
			draw_circle(center, 6.0, Color("2a1027"))
			draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 1), center + Vector2(0, -6), center + Vector2(6, 1), center + Vector2(0, 5)]), glow)
			draw_rect(Rect2(center + Vector2(-1, -3), Vector2(2, 6)), Color("f3b3d7"), true)
			if String(building.get("operation_state", "")) == "firing":
				draw_arc(center, 15.0 + float(posmod(int(SimulationHost.tick / 2), 3)), 0.0, TAU, 16, Color(glow.r, glow.g, glow.b, 0.70), 2.0)
		"fire_pit":
			draw_circle(center, minf(rect.size.x, rect.size.y) * 0.43, root_dark)
			for index in 6:
				var angle := TAU * float(index) / 6.0
				var stone := center + Vector2(cos(angle), sin(angle)) * 8.0
				draw_rect(Rect2(stone - Vector2(2, 2), Vector2(4, 4)), flesh.lightened(float(index % 2) * 0.08), true)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-5, 5), center + Vector2(-2, -7), center + Vector2(1, -2), center + Vector2(4, -9), center + Vector2(6, 5)]), vein)
			draw_rect(Rect2(center + Vector2(-1, -3), Vector2(3, 7)), glow, true)
		"graveyard":
			draw_colored_polygon(PackedVector2Array([rect.position + Vector2(5, 16), rect.position + Vector2(18, 5), rect.end - Vector2(8, rect.size.y - 9), rect.end - Vector2(4, 12), rect.position + Vector2(16, rect.size.y - 3), rect.position + Vector2(3, rect.size.y - 14)]), Color(0.16, 0.035, 0.14, 0.78))
			for index in 7:
				var marker := rect.position + Vector2(9 + posmod(seed + index * 17, maxi(4, int(rect.size.x - 18))), 10 + posmod(seed * 3 + index * 13, maxi(4, int(rect.size.y - 19))))
				draw_rect(Rect2(marker + Vector2(-2, -4), Vector2(5, 8)), flesh.darkened(float(index % 3) * 0.06), true)
				draw_rect(Rect2(marker + Vector2(-4, -2), Vector2(9, 3)), vein, true)
			draw_circle(center, 7.0, Color("2b1028"))
			draw_circle(center, 3.0, glow)
	if role not in ["road", "wall"]:
		_draw_corrupted_building_overlay(building, rect)

func _completed_hostile_segment_at(cell: Vector2i, role: String) -> bool:
	if latest_snapshot == null:
		return false
	for candidate in latest_snapshot.buildings:
		if String(candidate.get("category", "")) != "hostile" or String(candidate.get("hostile_role", "")) != role:
			continue
		if bool(candidate.get("completed", false)) and not bool(candidate.get("destroyed", false)) and Rect2i(Vector2i(int(candidate.x), int(candidate.y)), Vector2i(int(candidate.width), int(candidate.height))).has_point(cell):
			return true
	return false

func _draw_building_status(building: Dictionary, rect: Rect2) -> void:
	var visual_state := String(building.get("visual_state", "normal"))
	var ownership := String(building.get("ownership", "settlement"))
	var status_effects: Dictionary = building.get("status_effects", {})
	var corrupted := bool(building.get("corrupted", false)) or ownership == "corruption" or visual_state == "corrupted"
	var abandoned := bool(building.get("abandoned", false)) or visual_state == "abandoned"
	var reclaimed := int(building.get("reclaimed_ticks", 0)) > 0 or visual_state == "reclaimed"
	var frozen := visual_state == "frozen" or status_effects.has("frozen") or status_effects.has("ice") or status_effects.has("magic_ice")
	var electrified := visual_state == "electrified" or status_effects.has("electrified") or status_effects.has("electric") or status_effects.has("magic_electric")
	if corrupted:
		_draw_corrupted_building_overlay(building, rect)
	if abandoned:
		_draw_abandoned_building_overlay(building, rect)
	var health_ratio := float(building.get("health", 1)) / maxf(1.0, float(building.get("max_health", 1)))
	if health_ratio < 0.70:
		_draw_damage_clusters(building, rect, health_ratio)
	var operation_state := String(building.get("operation_state", ""))
	if String(building.get("category", "")) == "towers" or operation_state.is_empty():
		operation_state = String(building.get("combat_state", operation_state))
	if operation_state in ["operational", "charging", "deployed", "firing", "attracting", "repairing", "reloading", "filling", "collecting_rain", "purifying", "available", "motivating"] and not abandoned and not corrupted:
		_draw_building_activity(building, rect, operation_state)
	if frozen:
		_draw_frost_overlay(building, rect)
	if electrified:
		_draw_electric_overlay(building, rect)
	if reclaimed:
		_draw_reclaimed_overlay(building, rect)
	if bool(building.get("burning", false)):
		var fire_center := rect.get_center() + Vector2(rect.size.x * 0.18, -rect.size.y * 0.1)
		_draw_pixel_fire(fire_center, int(building.get("id", 0)))
	if operation_state in ["no_energy", "no_ammo", "missing_input", "full_output", "paused", "missing_worker", "at_capacity", "invalid_definition"]:
		_draw_operation_badge(rect.position + Vector2(rect.size.x - 9, 8), operation_state)
	var service_state := String(building.get("service_state", "none"))
	if service_state in ["repair_requested", "repairing", "repaired"]:
		draw_line(rect.position + Vector2(3, 3), rect.position + Vector2(11, 11), Color("6fffd2"), 3.0)
		draw_circle(rect.position + Vector2(3, 3), 3.0, Color("6fffd2"))
	elif service_state == "missing_repair_material":
		_draw_operation_badge(rect.position + Vector2(rect.size.x - 9, 8), "missing_input")
	elif service_state in ["dismantle_requested", "dismantling"]:
		var target := maxi(60, int(building.get("build_time", 180)) / 3)
		var ratio := clampf(float(building.get("dismantle_progress", 0)) / float(target), 0.0, 1.0)
		_draw_dismantle_overlay(building, rect, ratio)
		draw_rect(Rect2(rect.position + Vector2(2, rect.size.y - 4), Vector2((rect.size.x - 4) * ratio, 2)), Color("ffcf6b"), true)

func _draw_building_activity(building: Dictionary, rect: Rect2, state: String) -> void:
	var building_id := int(building.get("id", 0))
	var phase := posmod(int(SimulationHost.tick / 3) + building_id, 4)
	var category := String(building.get("category", "misc"))
	if state in ["filling", "collecting_rain", "purifying", "available"]:
		var water_color := Color("66c8d2")
		var basin := rect.get_center() + Vector2(0, rect.size.y * 0.16)
		draw_arc(basin, 4.0 + float(phase % 2), 0.0, TAU, 8, water_color, 1.0)
		if state in ["filling", "collecting_rain", "purifying"]:
			var drop := basin + Vector2(float(phase - 2) * 2.0, -9.0 + float(phase) * 2.0)
			draw_rect(Rect2(drop, Vector2(2, 3)), water_color.lightened(0.18), true)
		return
	if category in ["magic", "golems", "lighting", "towers"]:
		var pulse_color := Color("79e8e1") if category != "towers" else Color("e6c971")
		var radius := 7.0 + float(phase)
		draw_arc(rect.get_center(), radius, -PI * 0.8, PI * 0.35, 10, Color(pulse_color.r, pulse_color.g, pulse_color.b, 0.74), 2.0)
		if state in ["firing", "attracting", "deployed"]:
			draw_circle(rect.get_center(), 2.0 + float(phase % 2), pulse_color)
	elif category in ["refining", "manufacturing", "trash"]:
		var vent := rect.position + Vector2(rect.size.x * 0.72, 8 - phase)
		draw_rect(Rect2(vent, Vector2(4 + phase, 3)), Color(0.66, 0.64, 0.59, 0.36 - float(phase) * 0.04), true)
		for spark in 2:
			var spark_point := rect.get_center() + Vector2(5 + spark * 4, -2 + posmod(phase + spark * 2, 5))
			draw_rect(Rect2(spark_point, Vector2(2, 2)), Color("f1a348"), true)
	elif category in ["food_water", "harvesting", "civics", "storage"]:
		var track_x := rect.get_center().x - 6 + phase * 4
		draw_rect(Rect2(Vector2(track_x, rect.end.y - 7), Vector2(4, 3)), Color("e0c36b"), true)
		draw_rect(Rect2(Vector2(track_x + 1, rect.end.y - 8), Vector2(2, 1)), Color("f5df91"), true)

func _draw_frost_overlay(building: Dictionary, rect: Rect2) -> void:
	var frost := Color(0.62, 0.89, 0.95, 0.24)
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(2, 6), rect.position + Vector2(rect.size.x * 0.62, 2),
		Vector2(rect.end.x - 2, rect.position.y + rect.size.y * 0.36), rect.end - Vector2(5, 2),
		Vector2(rect.position.x + rect.size.x * 0.28, rect.end.y - 3),
	]), frost)
	var seed := int(building.get("id", 0))
	for index in 7:
		var point := rect.position + Vector2(3 + posmod(seed + index * 13, maxi(2, int(rect.size.x - 7))), 3 + posmod(seed * 3 + index * 19, maxi(2, int(rect.size.y - 7))))
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -3), point + Vector2(2, 0), point + Vector2(0, 3), point + Vector2(-2, 0)]), Color("b9f0f2"))

func _draw_electric_overlay(building: Dictionary, rect: Rect2) -> void:
	var phase := posmod(int(SimulationHost.tick / 2) + int(building.get("id", 0)), 4)
	var electric := Color("f4e66d")
	for index in 3:
		var start := rect.position + Vector2(4 + index * maxf(6.0, (rect.size.x - 8) / 3.0), 4 + posmod(phase + index * 3, maxi(3, int(rect.size.y - 10))))
		var points := PackedVector2Array([start, start + Vector2(4, 3), start + Vector2(1, 7), start + Vector2(7, 10), start + Vector2(4, 15)])
		draw_polyline(points, electric, 2.0)
		draw_rect(Rect2(points[points.size() - 1] - Vector2.ONE, Vector2(3, 3)), Color("fff8bd"), true)

func _draw_corrupted_building_overlay(building: Dictionary, rect: Rect2) -> void:
	var seed := int(building.get("id", 0))
	var corruption_dark := Color(0.14, 0.02, 0.12, 0.48)
	var corruption_bright := Color("a83786")
	for index in 5:
		var edge := rect.position + Vector2(posmod(seed + index * 17, maxi(2, int(rect.size.x))), posmod(seed * 5 + index * 23, maxi(2, int(rect.size.y))))
		var toward_center := edge.lerp(rect.get_center(), 0.58 + float(index % 2) * 0.15)
		draw_line(edge, toward_center, corruption_dark, 4.0 if index % 2 == 0 else 2.0)
		draw_circle(toward_center, 2.0 + float(index % 3), corruption_bright.darkened(float(index % 2) * 0.18))
	for index in 7:
		var spore := rect.position + Vector2(3 + posmod(seed * 3 + index * 11, maxi(2, int(rect.size.x - 7))), 3 + posmod(seed + index * 19, maxi(2, int(rect.size.y - 7))))
		draw_rect(Rect2(spore, Vector2(2, 2)), corruption_bright.lightened(float(index % 3) * 0.08), true)

func _draw_abandoned_building_overlay(building: Dictionary, rect: Rect2) -> void:
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(1, 4), Vector2(rect.end.x - 5, rect.position.y + 2),
		rect.end - Vector2(2, 5), Vector2(rect.position.x + 5, rect.end.y - 2),
	]), Color(0.19, 0.18, 0.17, 0.44))
	var entrance := Vector2(rect.get_center().x, rect.end.y - 7)
	draw_line(entrance + Vector2(-6, -2), entrance + Vector2(6, 2), Color("493628"), 3.0)
	draw_line(entrance + Vector2(-5, 3), entrance + Vector2(5, -3), Color("624631"), 2.0)
	draw_line(rect.position + Vector2(8, 10), rect.get_center() + Vector2(7, -2), Color(0.13, 0.11, 0.10, 0.72), 2.0)
	draw_line(rect.position + Vector2(rect.size.x - 9, 7), rect.get_center() + Vector2(-5, 7), Color(0.13, 0.11, 0.10, 0.62), 1.0)
	for index in 5:
		var weed := rect.position + Vector2(4 + posmod(int(building.get("id", 0)) + index * 13, maxi(2, int(rect.size.x - 8))), rect.size.y - 3 - index % 3)
		draw_line(weed, weed + Vector2(-2 + index % 3, -5 - index % 2), Color("60773b"), 2.0)

func _draw_reclaimed_overlay(building: Dictionary, rect: Rect2) -> void:
	var phase := posmod(int(SimulationHost.tick / 3) + int(building.get("id", 0)), 5)
	var reclaim_color := Color("7ce6b2")
	for corner in [rect.position + Vector2(4, 4), Vector2(rect.end.x - 5, rect.position.y + 4), Vector2(rect.position.x + 4, rect.end.y - 5), rect.end - Vector2(5, 5)]:
		draw_circle(corner, 2.0 + float((phase + int(corner.x)) % 2), reclaim_color)
	var sweep_y := rect.position.y + 4 + posmod(phase * 7, maxi(3, int(rect.size.y - 8)))
	draw_line(Vector2(rect.position.x + 4, sweep_y), Vector2(rect.end.x - 4, sweep_y), Color(reclaim_color.r, reclaim_color.g, reclaim_color.b, 0.42), 1.0)

func _draw_dismantle_overlay(building: Dictionary, rect: Rect2, ratio: float) -> void:
	var building_id := int(building.get("id", 0))
	var gap_count := 1 + floori(ratio * 13.0)
	for index in gap_count:
		var gap_size := Vector2(4 + index % 3, 3 + (index + 1) % 3)
		var offset := Vector2(4 + posmod(building_id + index * 17, maxi(2, int(rect.size.x - gap_size.x - 8))), 4 + posmod(building_id * 3 + index * 13, maxi(2, int(rect.size.y - gap_size.y - 8))))
		var cell := Vector2i((rect.position + offset) / TILE_PIXELS)
		var terrain_color := _tile_color(current_blueprint.get_tile(cell), current_blueprint.biome_id, cell.x, cell.y)
		draw_rect(Rect2(rect.position + offset, gap_size), terrain_color.darkened(0.05), true)
	for index in 1 + floori(ratio * 6.0):
		var salvage := rect.position + Vector2(5 + index * 7, rect.size.y - 9 - index % 2 * 3)
		draw_rect(Rect2(salvage, Vector2(6, 3)), Color("8d5b32"), true)
		draw_rect(Rect2(salvage + Vector2(1, 0), Vector2(4, 1)), Color("b37a43"), true)
	if ratio > 0.05:
		var scaffold := Color("d18b45")
		for x in range(int(rect.position.x + 3), int(rect.end.x - 3), 8):
			draw_rect(Rect2(Vector2(x, rect.position.y + 1), Vector2(4, 1)), scaffold, true)
		for y in range(int(rect.position.y + 4), int(rect.end.y - 4), 9):
			draw_rect(Rect2(Vector2(rect.end.x - 2, y), Vector2(1, 5)), scaffold.darkened(0.12), true)

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
	var hostile := String(building.get("ownership", "settlement")) == "corruption" or String(building.get("category", "")) == "hostile"
	for index in 9:
		var x := 4 + posmod(building_id * 5 + index * 17, maxi(2, int(rect.size.x - 10)))
		var y := 4 + posmod(building_id * 3 + index * 11, maxi(2, int(rect.size.y - 10)))
		var color := (Color("633050") if index % 3 else Color("291322")) if hostile else (Color("716b64") if index % 3 else Color("4f4035"))
		draw_rect(Rect2(rect.position + Vector2(x, y), Vector2(4 + index % 3, 3 + index % 2)), color, true)
	for index in 3:
		var beam_start := rect.position + Vector2(5 + index * 7, 7 + index * 5)
		draw_line(beam_start, beam_start + Vector2(11, 5 if index % 2 else -4), Color("5f2451") if hostile else Color("5e3f28"), 2.0)
	draw_rect(Rect2(rect.get_center() - Vector2(8, 3), Vector2(16, 6)), Color(0.15, 0.025, 0.13, 0.44) if hostile else Color(0.16, 0.13, 0.12, 0.38), true)

func _draw_pixel_fire(center: Vector2, seed: int) -> void:
	var flicker := posmod(int(SimulationHost.tick / 2) + seed, 2)
	draw_rect(Rect2(center + Vector2(-5, 2), Vector2(11, 3)), Color(0.29, 0.12, 0.05, 0.70), true)
	draw_rect(Rect2(center + Vector2(-4, -4 + flicker), Vector2(4, 8 - flicker)), Color("e54f1d"), true)
	draw_rect(Rect2(center + Vector2(1, -7 - flicker), Vector2(4, 11 + flicker)), Color("f47d24"), true)
	draw_rect(Rect2(center + Vector2(-1, -2), Vector2(3, 6)), Color("f7d65b"), true)

func _draw_operation_badge(center: Vector2, state: String) -> void:
	var color := Color("e4c157") if state in ["no_energy", "no_ammo", "at_capacity"] else Color("de795e")
	if state == "full_output": color = Color("e6a84e")
	elif state == "paused": color = Color("9aa1a6")
	elif state == "invalid_definition": color = Color("d15a82")
	draw_rect(Rect2(center - Vector2(5, 5), Vector2(10, 10)), Color("201b1d"), true)
	draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 8)), color.darkened(0.25), true)
	if state == "no_energy":
		draw_rect(Rect2(center + Vector2(0, -3), Vector2(2, 4)), color, true)
		draw_rect(Rect2(center + Vector2(-2, 0), Vector2(3, 2)), color, true)
		draw_rect(Rect2(center + Vector2(-3, 1), Vector2(2, 4)), color, true)
	elif state == "no_ammo":
		draw_rect(Rect2(center + Vector2(-3, -1), Vector2(6, 3)), color, true)
		draw_rect(Rect2(center + Vector2(2, -3), Vector2(2, 6)), color, true)
	elif state == "paused":
		draw_rect(Rect2(center + Vector2(-3, -3), Vector2(2, 7)), color, true)
		draw_rect(Rect2(center + Vector2(1, -3), Vector2(2, 7)), color, true)
	elif state in ["full_output", "at_capacity"]:
		draw_rect(Rect2(center + Vector2(-3, 0), Vector2(7, 3)), color, true)
		draw_rect(Rect2(center + Vector2(-2, -3), Vector2(5, 3)), color.lightened(0.16), true)
	elif state == "missing_worker":
		draw_circle(center + Vector2(0, -2), 2.0, color)
		draw_rect(Rect2(center + Vector2(-2, 1), Vector2(5, 3)), color, true)
	elif state == "invalid_definition":
		draw_line(center + Vector2(-3, -3), center + Vector2(3, 3), color, 2.0)
		draw_line(center + Vector2(3, -3), center + Vector2(-3, 3), color, 2.0)
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
		_draw_housing_top(rect, tier, definition_id == "doggo_house", String(building.get("housing_branch", "standard")))
		return
	_draw_open_yard(rect, accent, tier, definition_id)
	match definition_id:
		"ancillary":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.64, 24)), Color("806044"))
			_draw_crates(rect.position + Vector2(rect.size.x * 0.66, 7), 3, Color("af814b"))
			_draw_table(rect.position + Vector2(7, rect.size.y * 0.57), Vector2(rect.size.x * 0.58, 8), Color("856039"))
			# Dispatch ledger and pigeon/message rack make this read as logistics,
			# rather than another storage shack.
			draw_rect(Rect2(rect.position + Vector2(12, rect.size.y * 0.57 + 1), Vector2(9, 5)), Color("d6c58d"), true)
			draw_rect(Rect2(rect.position + Vector2(rect.size.x - 15, 26), Vector2(10, 14)), Color("49382b"), true)
			for slot in [Vector2(0, 0), Vector2(5, 0), Vector2(0, 6), Vector2(5, 6)]:
				draw_rect(Rect2(rect.position + Vector2(rect.size.x - 14, 27) + slot, Vector2(3, 4)), Color("b18a50"), true)
		"clinic":
			_draw_canvas_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 27)), Color("c7bfa6"), Color("7c947f"))
			_draw_cot(Rect2(rect.position + Vector2(6, 30), Vector2(11, 22)), Color("d2c59f"))
			_draw_cot(Rect2(rect.position + Vector2(22, 30), Vector2(11, 22)), Color("aaa189"))
			_draw_herbs(rect.position + Vector2(rect.size.x - 11, 33))
			_draw_basin(rect.position + Vector2(rect.size.x - 10, rect.size.y - 11), Color("64a9b7"), 6)
			_draw_cross(rect.get_center() + Vector2(0, -rect.size.y * 0.34), Color("b9414b"))
		"courier_station":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.62, 24)), Color("806044"))
			_draw_crates(rect.position + Vector2(rect.size.x * 0.62, 6), 4, Color("ba8a4f"))
			_draw_cart(rect.position + Vector2(rect.size.x * 0.66, rect.size.y - 13), Color("966238"))
			draw_rect(Rect2(rect.position + Vector2(6, rect.size.y - 12), Vector2(17, 4)), Color("66462d"), true)
			_draw_arrow(rect.position + Vector2(14, rect.size.y - 10), Color("e0c36b"))
		"maintenance_building":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.60, 27)), Color("70513a"))
			_draw_table(rect.position + Vector2(rect.size.x * 0.57, 7), Vector2(rect.size.x * 0.32, 9), Color("93643a"))
			_draw_tool_rack(rect.position + Vector2(rect.size.x * 0.58, 21), Vector2(rect.size.x * 0.30, 14))
			_draw_logs(rect.position + Vector2(7, rect.size.y - 16), 3, Color("9b6332"))
			_draw_rock_pile(rect.position + Vector2(rect.size.x - 13, rect.size.y - 12), Color("898782"))
		"marketplace":
			var stall_width := floorf((rect.size.x - 10) / 3.0)
			for index in 3:
				var stall := Rect2(rect.position + Vector2(3 + index * stall_width, 4), Vector2(stall_width - 1, 20))
				_draw_market_awning(stall, [Color("b85b43"), Color("d2b15d"), Color("5c8b75")][index])
			_draw_table(rect.position + Vector2(8, 31), Vector2(rect.size.x - 16, 7), Color("85603a"))
			_draw_crates(rect.position + Vector2(7, rect.size.y - 17), 4, Color("b1814b"))
			_draw_basket(rect.position + Vector2(rect.size.x - 12, rect.size.y - 12), Color("9e853f"))
		"migration_way_station":
			_draw_canvas_roof(Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x - 10, 23)), Color("a18c66"), Color("6d4d35"))
			_draw_arch(rect.get_center() + Vector2(0, 5), Color("9b846a"))
			_draw_bedroll(rect.position + Vector2(6, rect.size.y - 13), Color("9b6a4f"))
			_draw_bedroll(rect.position + Vector2(rect.size.x - 17, rect.size.y - 13), Color("547a79"))
			draw_rect(Rect2(rect.position + Vector2(7, 26), Vector2(9, 6)), Color("d0bd82"), true)
			draw_rect(Rect2(rect.position + Vector2(10, 32), Vector2(2, 7)), Color("65472e"), true)
		"way_maker_shack":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.62, 24)), Color("76553a"))
			_draw_road_samples(rect.position + Vector2(rect.size.x * 0.58, 6))
			_draw_tool_pair(rect.position + Vector2(15, rect.size.y - 15))
			_draw_logs(rect.position + Vector2(rect.size.x - 13, rect.size.y - 12), 3, Color("9b6433"))
		"lumber_shack":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.62, rect.size.y * 0.60)), Color("68452e"))
			_draw_logs(rect.position + Vector2(rect.size.x * 0.55, 6), 5, Color("a36a34"))
			_draw_logs(rect.position + Vector2(rect.size.x * 0.48, rect.size.y - 13), 3, Color("8e572b"))
			_draw_stump_workbench(rect.position + Vector2(12, rect.size.y - 11))
			_draw_axe(rect.position + Vector2(rect.size.x * 0.39, rect.size.y * 0.72))
		"mining_facility":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.60, 26)), Color("62564c"))
			_draw_rock_pile(rect.position + Vector2(rect.size.x * 0.68, 14), Color("8c8a84"))
			_draw_mine_track(Rect2(rect.position + Vector2(rect.size.x * 0.46, 28), Vector2(13, rect.size.y - 34)))
			_draw_cart(rect.position + Vector2(rect.size.x * 0.70, rect.size.y * 0.67), Color("8e6035"))
			_draw_pickaxe(rect.position + Vector2(15, rect.size.y - 14))
		"crystal_harvestry":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.60, 24)), Color("4f6667"))
			for offset in [Vector2(rect.size.x * 0.68, 12), Vector2(12, rect.size.y * 0.65), Vector2(rect.size.x * 0.62, rect.size.y * 0.68)]:
				_draw_crystal(rect.position + offset, Color("56cddd"))
		"farm":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(25, 24)), Color("806039"))
			_draw_crop_rows(Rect2(rect.position + Vector2(31, 5), Vector2(rect.size.x - 35, rect.size.y - 10)))
			_draw_crop_rows(Rect2(rect.position + Vector2(5, 28), Vector2(19, rect.size.y - 34)))
			_draw_basin(rect.position + Vector2(14, 24), Color("5b99a2"), 6)
			_draw_sack_stack(rect.position + Vector2(rect.size.x - 8, rect.size.y - 9), Color("b39a61"))
		"animal_pen":
			_draw_canvas_roof(Rect2(rect.position + Vector2(5, 5), Vector2(28, 21)), Color("ad8c50"), Color("765e37"))
			draw_rect(Rect2(rect.position + Vector2(7, 24), Vector2(24, 3)), Color("755331"), true)
			for x in [9, 19, 29]: draw_rect(Rect2(rect.position + Vector2(x, 8), Vector2(2, 18)), Color("5c412a"), true)
			_draw_trough(Rect2(rect.position + Vector2(rect.size.x - 31, 8), Vector2(23, 7)))
			_draw_hay(rect.position + Vector2(12, rect.size.y - 13))
			_draw_hay(rect.position + Vector2(rect.size.x - 14, rect.size.y - 13))
			_draw_water_puddle(rect.get_center() + Vector2(8, 8))
			_draw_animal_tracks(rect.get_center() + Vector2(-8, 9))
			_draw_animal_tracks(rect.position + Vector2(rect.size.x - 14, 28))
		"clucker_coop":
			_draw_top_roof(Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x * 0.60, rect.size.y * 0.50)), Color("8b613a"))
			for offset in [Vector2(rect.size.x * 0.66, 11), Vector2(rect.size.x * 0.75, 18), Vector2(rect.size.x * 0.60, 25)]:
				draw_rect(Rect2(rect.position + offset, Vector2(3, 3)), Color("dfd19c"), true)
		"kitchen":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 23)), Color("714832"))
			_draw_hearth(rect.position + Vector2(11, rect.size.y * 0.58))
			_draw_table(rect.position + Vector2(rect.size.x * 0.45, rect.size.y * 0.52), Vector2(rect.size.x * 0.38, 8), Color("8a6038"))
		"bottler":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 22)), Color("545b54"))
			_draw_water_tub(rect.position + Vector2(rect.size.x * 0.5, 26))
			for index in 3:
				_draw_bottle(rect.position + Vector2(8 + index * 7, rect.size.y - 10), Color("66bdc9"))
			draw_line(rect.position + Vector2(5, 21), rect.position + Vector2(rect.size.x - 5, 21), Color("a7a18e"), 2.0)
		"water_purifier":
			_draw_filter_tank(rect.position + Vector2(16, 17), Color("466f79"), false)
			_draw_filter_tank(rect.position + Vector2(rect.size.x - 17, rect.size.y - 17), Color("69b5c1"), true)
			_draw_pipe_path(PackedVector2Array([rect.position + Vector2(25, 17), rect.get_center(), rect.position + Vector2(rect.size.x - 25, rect.size.y - 17)]), Color("8e918b"))
			_draw_gravel_filter(Rect2(rect.position + Vector2(rect.size.x * 0.39, 7), Vector2(rect.size.x * 0.24, rect.size.y - 14)))
		"well":
			_draw_well(rect)
		"rain_catcher":
			_draw_rain_catcher(rect)
		"small_fountain", "large_fountain":
			var radius := 10 if definition_id == "small_fountain" else 16
			_draw_fountain(rect.get_center(), radius, definition_id == "large_fountain")
		"ranger_lodge":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.64, rect.size.y * 0.56)), Color("485b37"))
			_draw_target(rect.position + Vector2(rect.size.x - 14, 15))
			_draw_bow_rack(Rect2(rect.position + Vector2(rect.size.x * 0.57, 29), Vector2(rect.size.x * 0.34, 14)))
			_draw_animal_tracks(rect.position + Vector2(13, rect.size.y - 13))
			_draw_bedroll(rect.position + Vector2(27, rect.size.y - 14), Color("6b7c65"))
			if tier >= 3:
				_draw_small_bow_emplacement(rect.position + Vector2(rect.size.x - 15, rect.size.y - 15))
		"outpost":
			_draw_outpost(rect, tier)
		"lumber_mill":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.54, 28)), Color("765035"))
			_draw_saw_bed(Rect2(rect.position + Vector2(rect.size.x * 0.58, 7), Vector2(rect.size.x * 0.34, 25)))
			_draw_logs(rect.position + Vector2(7, rect.size.y - 17), 4, Color("a46b34"))
			_draw_board_stack(rect.position + Vector2(rect.size.x * 0.55, rect.size.y - 16), 4)
		"stone_cuttery":
			_draw_machine_house(rect, Color("70665c"))
			_draw_rock_pile(rect.position + Vector2(11, rect.size.y - 13), Color("97938c"))
			draw_rect(Rect2(rect.get_center() + Vector2(4, -7), Vector2(3, 16)), Color("c2bdb4"), true)
		"crystillery":
			_draw_machine_house(rect, Color("50666d"))
			_draw_crystal(rect.position + Vector2(12, rect.size.y - 16), Color("59d5e7"), 8)
			_draw_basin(rect.position + Vector2(rect.size.x - 14, rect.size.y - 13), Color("3c8999"), 7)
		"forge":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.66, 28)), Color("5a4139"))
			_draw_brick_furnace(rect.position + Vector2(rect.size.x - 15, 15))
			_draw_anvil(rect.position + Vector2(rect.size.x * 0.43, rect.size.y - 15))
			_draw_water_tub(rect.position + Vector2(13, rect.size.y - 14))
			_draw_ingot_stack(rect.position + Vector2(rect.size.x - 12, rect.size.y - 12))
		"toolsmithy":
			_draw_manufacturing_yard(rect, Color("735240"))
			_draw_tool_pair(rect.get_center() + Vector2(0, 9))
		"armorsmithy":
			_draw_manufacturing_yard(rect, Color("69534a"))
			_draw_shield(rect.get_center() + Vector2(0, 9), Color("a5a59d"))
		"bowyer":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 24)), Color("725238"))
			_draw_bow_rack(Rect2(rect.position + Vector2(7, 29), Vector2(rect.size.x - 14, 12)))
			_draw_arrow_bundle(rect.position + Vector2(12, rect.size.y - 9), Color("c9a468"))
			_draw_arrow_bundle(rect.position + Vector2(rect.size.x - 12, rect.size.y - 9), Color("8daf70"))
		"tumbler":
			_draw_manufacturing_yard(rect, Color("665d55"))
			_draw_drum(rect.get_center() + Vector2(0, 10), Color("90877a"))
		"wood_storage", "rock_storage", "crystal_storage", "mineral_storage", "food_storage", "gold_storage", "ammo_storage", "equipment_storage", "miscellaneous_storage":
			_draw_storage_yard(rect, definition_id, building)
		"key_shack":
			_draw_top_roof(Rect2(rect.position + Vector2(5, 5), rect.size - Vector2(10, 15)), Color("66513b"))
			_draw_key(rect.get_center() + Vector2(0, 7), Color("d3b457"))
			_draw_storage_filter_marker(rect, building)
		"essence_altar":
			var altar_radius := mini(23, int(minf(rect.size.x, rect.size.y) * 0.43))
			_draw_altar_dais(rect.get_center(), Color("83d7d4"), altar_radius)
			_draw_crystal(rect.get_center() - Vector2(0, 2), Color("a8f7ef"), 9)
			for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				_draw_bottle(rect.get_center() + direction * float(altar_radius - 4), Color("62bfd2"))
		"essence_collector":
			_draw_magic_circle(rect.get_center(), Color("72c9dc"), 13)
			for offset in [Vector2(-10, 0), Vector2(10, 0), Vector2(0, -10)]:
				_draw_bottle(rect.get_center() + offset, Color("62bfd2"))
		"reliquary":
			_draw_reliquary(rect)
		"cullis_gate":
			_draw_cullis_gate(rect, building)
		"fire_pit", "large_fire_pit", "crylithium_fire_pit":
			var fire_radius := 7 if definition_id == "fire_pit" else 12
			_draw_fire_pit(rect.get_center(), fire_radius, definition_id == "crylithium_fire_pit")
		"crystal_motivator":
			_draw_magic_circle(rect.get_center(), Color("5bcbd6"), 14)
			_draw_crystal(rect.get_center() - Vector2(0, 3), Color("65e1e8"), 10)
		"lightning_rod":
			var rod_center := rect.get_center()
			draw_circle(rod_center + Vector2(2, 3), 10.0, Color(0.06, 0.06, 0.07, 0.62))
			draw_circle(rod_center, 9.0, Color("555b62"))
			draw_circle(rod_center, 6.0, Color("8e969d"))
			draw_rect(Rect2(rod_center - Vector2(2, 13), Vector2(4, 25)), Color("59636b"), true)
			draw_rect(Rect2(rod_center - Vector2(1, 15), Vector2(2, 28)), Color("d2d8dc"), true)
			for coil_radius in [4.0, 7.0, 10.0]:
				draw_arc(rod_center, coil_radius, -0.75, PI + 0.75, 14, Color("67cfe0"), 1.0)
			if String(building.get("operation_state", "")) == "conducting":
				draw_polyline(PackedVector2Array([rod_center + Vector2(0, -16), rod_center + Vector2(-4, -21), rod_center + Vector2(2, -25), rod_center + Vector2(-1, -30)]), Color("fff38a"), 2.0)
		"wood_golem_combobulator", "stone_golem_combobulator", "crystal_golem_combobulator", "cube_e_golem_combobulator":
			_draw_combobulator(rect, definition_id)
		"trash_can":
			_draw_bin(rect.get_center(), Color("625851"))
		"landfill":
			_draw_landfill(rect)
		"processor":
			_draw_trash_processor(rect)
		"burner":
			_draw_trash_burner(rect)
		"trashy_cube_pile":
			for offset in [Vector2(10, 12), Vector2(19, 8), Vector2(28, 14), Vector2(15, 23), Vector2(25, 25)]:
				draw_rect(Rect2(rect.position + offset, Vector2(7, 7)), Color("655a58").lightened(float(int(offset.x + offset.y) % 3) * 0.08), true)
		_:
			_draw_top_roof(Rect2(rect.position + Vector2(5, 5), rect.size - Vector2(10, 15)), accent)
	if tier >= 2:
		_draw_tier_progression(rect, String(building.category), tier, accent)

func _draw_open_yard(rect: Rect2, accent: Color, tier: int, yard_style: String = "") -> void:
	var ground := Color("745c3d").lerp(accent.darkened(0.34), 0.16)
	var yard := rect.grow(-3.0)
	# Work sites blend into the biome through several worn, irregular patches.
	# There is deliberately no opaque rectangular footprint card.
	var center := yard.get_center()
	var ground_alpha := Color(ground.r, ground.g, ground.b, 0.48)
	draw_colored_polygon(PackedVector2Array([
		Vector2(yard.position.x + 4, yard.position.y + 8), Vector2(center.x - 7, yard.position.y + 3),
		Vector2(yard.end.x - 5, yard.position.y + 6), Vector2(yard.end.x - 2, center.y - 4),
		Vector2(yard.end.x - 6, yard.end.y - 4), Vector2(center.x + 5, yard.end.y - 1),
		Vector2(yard.position.x + 3, yard.end.y - 6), Vector2(yard.position.x + 1, center.y + 3),
	]), ground_alpha)
	var inner_ground := Color(ground.darkened(0.06), 0.24)
	draw_colored_polygon(PackedVector2Array([
		yard.position + Vector2(9, 8), Vector2(yard.end.x - 11, yard.position.y + 6),
		yard.end - Vector2(7, 10), Vector2(yard.position.x + 6, yard.end.y - 8),
	]), inner_ground)
	var wear_seed := int(rect.position.x * 5.0 + rect.position.y * 3.0)
	for index in 24:
		var wear_x := int(yard.position.x + 3 + posmod(wear_seed + index * 17, maxi(1, int(yard.size.x) - 7)))
		var wear_y := int(yard.position.y + 3 + posmod(wear_seed / 3 + index * 29, maxi(1, int(yard.size.y) - 7)))
		var wear_base := ground.darkened(0.18) if index % 3 else ground.lightened(0.10)
		var wear_color := Color(wear_base.r, wear_base.g, wear_base.b, 0.54)
		draw_rect(Rect2(Vector2(wear_x, wear_y), Vector2(2 + index % 4, 1 + index % 2)), wear_color, true)
	# Dithered edge chips make the work area interlock with the biome rather than
	# terminating at the footprint polygon. They remain sparse enough to preserve
	# a clear construction footprint on a phone display.
	for index in 20:
		var side := index % 4
		var edge_point := Vector2.ZERO
		if side == 0:
			edge_point = Vector2(yard.position.x + 3 + posmod(wear_seed + index * 11, maxi(2, int(yard.size.x - 6))), yard.position.y + posmod(index, 4))
		elif side == 1:
			edge_point = Vector2(yard.end.x - posmod(index, 4) - 2, yard.position.y + 3 + posmod(wear_seed + index * 13, maxi(2, int(yard.size.y - 6))))
		elif side == 2:
			edge_point = Vector2(yard.position.x + 3 + posmod(wear_seed + index * 7, maxi(2, int(yard.size.x - 6))), yard.end.y - posmod(index, 4) - 2)
		else:
			edge_point = Vector2(yard.position.x + posmod(index, 4), yard.position.y + 3 + posmod(wear_seed + index * 19, maxi(2, int(yard.size.y - 6))))
		var edge_base := ground.darkened(0.12) if index % 3 else ground.lightened(0.06)
		draw_rect(Rect2(edge_point, Vector2(1 + index % 3, 1 + (index + 1) % 2)), Color(edge_base.r, edge_base.g, edge_base.b, 0.38), true)
	var border := Color("765334") if tier < 3 else Color("85817a")
	var fenced_yards := ["farm", "animal_pen", "clucker_coop", "ranger_lodge", "housing", "doggo_house"]
	var arcane_yards := ["essence_altar", "essence_collector", "reliquary", "cullis_gate", "crystal_motivator", "lightning_rod", "wood_golem_combobulator", "stone_golem_combobulator", "crystal_golem_combobulator", "cube_e_golem_combobulator"]
	var storage_yards := ["wood_storage", "rock_storage", "crystal_storage", "mineral_storage", "food_storage", "gold_storage", "ammo_storage", "equipment_storage", "miscellaneous_storage"]
	if yard_style in fenced_yards or yard_style == "camp":
		# Rails only appear where a real enclosure is part of the building's function.
		for x in range(int(rect.position.x + 3), int(rect.end.x - 4), 7):
			draw_rect(Rect2(Vector2(x, rect.position.y + 2), Vector2(5, 2)), border, true)
			if x < rect.get_center().x - 9 or x > rect.get_center().x + 6:
				draw_rect(Rect2(Vector2(x, rect.end.y - 4), Vector2(5, 2)), border, true)
		for y in range(int(rect.position.y + 3), int(rect.end.y - 4), 7):
			draw_rect(Rect2(Vector2(rect.position.x + 2, y), Vector2(2, 5)), border, true)
			draw_rect(Rect2(Vector2(rect.end.x - 4, y), Vector2(2, 5)), border, true)
		for point in [rect.position + Vector2(1, 1), Vector2(rect.end.x - 4, rect.position.y + 1), Vector2(rect.position.x + 1, rect.end.y - 4), rect.end - Vector2(4, 4)]:
			draw_rect(Rect2(point, Vector2(3, 3)), border.lightened(0.12), true)
	elif yard_style in arcane_yards or yard_style.ends_with("_tower"):
		# Arcane work sites use embedded corner stones rather than a generic fence.
		for point in [rect.position + Vector2(4, 4), Vector2(rect.end.x - 7, rect.position.y + 4), Vector2(rect.position.x + 4, rect.end.y - 7), rect.end - Vector2(7, 7)]:
			draw_rect(Rect2(point, Vector2(5, 5)), Color("343034"), true)
			draw_rect(Rect2(point + Vector2.ONE, Vector2(3, 3)), accent.lightened(0.08), true)
	elif yard_style in storage_yards:
		# Storage lots need bumpers and loading gaps, not four identical rails.
		draw_rect(Rect2(rect.position + Vector2(3, 2), Vector2(rect.size.x - 6, 2)), border.darkened(0.12), true)
		draw_rect(Rect2(rect.position + Vector2(2, 3), Vector2(2, rect.size.y - 8)), border, true)
		draw_rect(Rect2(Vector2(rect.end.x - 4, rect.position.y + 3), Vector2(2, rect.size.y - 8)), border, true)
	else:
		# Civic and industrial yards keep only corner survey stones. This stops the
		# whole catalog from reading as the same fenced rectangle with a new icon.
		for point in [rect.position + Vector2(2, 2), Vector2(rect.end.x - 5, rect.position.y + 2), Vector2(rect.position.x + 2, rect.end.y - 5), rect.end - Vector2(5, 5)]:
			draw_rect(Rect2(point, Vector2(3, 3)), border.darkened(0.08), true)
	# A worn entrance connects the otherwise enclosed footprint to the world.
	var entrance_color := ground.lightened(0.08)
	entrance_color.a = 0.48
	draw_rect(Rect2(Vector2(rect.get_center().x - 6, rect.end.y - 5), Vector2(12, 7)), entrance_color, true)
	draw_rect(Rect2(Vector2(rect.get_center().x - 4, rect.get_center().y), Vector2(8, rect.size.y * 0.42)), Color(ground.r, ground.g, ground.b, 0.24), true)
	for x in range(int(rect.get_center().x - 5), int(rect.get_center().x + 6), 4):
		draw_rect(Rect2(Vector2(x, rect.end.y - 3), Vector2(2, 1)), ground.darkened(0.16), true)

func _draw_top_roof(rect: Rect2, color: Color) -> void:
	var chamfer := minf(3.0, minf(rect.size.x, rect.size.y) * 0.16)
	var roof_points := PackedVector2Array([
		rect.position + Vector2(chamfer, 0), Vector2(rect.end.x - chamfer, rect.position.y),
		Vector2(rect.end.x, rect.position.y + chamfer), rect.end - Vector2(0, chamfer),
		rect.end - Vector2(chamfer, 0), Vector2(rect.position.x + chamfer, rect.end.y),
		Vector2(rect.position.x, rect.end.y - chamfer), rect.position + Vector2(0, chamfer),
	])
	var wall_points := PackedVector2Array()
	var shadow_points := PackedVector2Array()
	for point in roof_points:
		wall_points.append(point + Vector2(0, 3))
		shadow_points.append(point + Vector2(2, 4))
	# Compact contact shadow and a three-pixel wall/eave skirt give the building
	# weight while retaining the strict overhead projection.
	draw_colored_polygon(shadow_points, Color(0.07, 0.045, 0.035, 0.82))
	draw_colored_polygon(wall_points, color.darkened(0.48))
	draw_colored_polygon(roof_points, Color("211812"))
	var inner := rect.grow(-2.0)
	var inner_chamfer := maxf(1.0, chamfer - 1.0)
	draw_colored_polygon(PackedVector2Array([
		inner.position + Vector2(inner_chamfer, 0), Vector2(inner.end.x - inner_chamfer, inner.position.y),
		Vector2(inner.end.x, inner.position.y + inner_chamfer), inner.end - Vector2(0, inner_chamfer),
		inner.end - Vector2(inner_chamfer, 0), Vector2(inner.position.x + inner_chamfer, inner.end.y),
		Vector2(inner.position.x, inner.end.y - inner_chamfer), inner.position + Vector2(0, inner_chamfer),
	]), color.darkened(0.02))
	var seed := absi(int(rect.position.x * 11.0 + rect.position.y * 17.0 + rect.size.x * 7.0))
	# Broken shingle clusters keep the roof handmade. Full-width stripes were too
	# clean and made every workshop read like the same vector icon.
	for row_y in range(int(rect.position.y + 4), int(rect.end.y - 2), 4):
		var row_index := int((row_y - rect.position.y) / 4.0)
		var start_x := int(rect.position.x + 3 + posmod(seed + row_index * 5, 3))
		while start_x < int(rect.end.x - 4):
			var segment := 4 + posmod(seed + start_x + row_index * 7, 5)
			var segment_width := minf(float(segment), rect.end.x - 3.0 - float(start_x))
			if segment_width > 1.0:
				draw_rect(Rect2(Vector2(start_x, row_y), Vector2(segment_width, 1)), color.darkened(0.20 + float(row_index % 2) * 0.04), true)
			start_x += segment + 2 + posmod(seed + start_x, 3)
	# The ridge follows the long roof axis. Its one-pixel highlight and dark mate
	# remain readable at native scale without implying an angled camera.
	if rect.size.x >= rect.size.y:
		var ridge_y := floorf(rect.get_center().y)
		draw_rect(Rect2(Vector2(rect.position.x + 3, ridge_y), Vector2(rect.size.x - 6, 2)), color.darkened(0.30), true)
		draw_rect(Rect2(Vector2(rect.position.x + 4, ridge_y), Vector2(rect.size.x - 8, 1)), color.lightened(0.16), true)
	else:
		var ridge_x := floorf(rect.get_center().x)
		draw_rect(Rect2(Vector2(ridge_x, rect.position.y + 3), Vector2(2, rect.size.y - 6)), color.darkened(0.30), true)
		draw_rect(Rect2(Vector2(ridge_x, rect.position.y + 4), Vector2(1, rect.size.y - 8)), color.lightened(0.16), true)
	# Uneven flashing, replaced shingles, and moss break the footprint without
	# introducing noise at the scale of villagers.
	draw_rect(Rect2(Vector2(rect.position.x + 3, rect.position.y + 2), Vector2(maxf(4.0, rect.size.x * 0.34), 1)), color.lightened(0.20), true)
	draw_rect(Rect2(Vector2(rect.end.x - 11, rect.end.y - 3), Vector2(6, 2)), color.darkened(0.32), true)
	if rect.size.x >= 22:
		var patch_x := rect.position.x + 5 + posmod(seed, maxi(3, int(rect.size.x - 15)))
		draw_rect(Rect2(Vector2(patch_x, rect.position.y + 5), Vector2(5, 3)), color.lightened(0.08), true)
		draw_rect(Rect2(Vector2(patch_x + 1, rect.position.y + 6), Vector2(3, 1)), color.darkened(0.12), true)
	if posmod(seed, 3) == 0 and rect.size.y >= 16:
		draw_rect(Rect2(Vector2(rect.position.x + 2, rect.end.y - 6), Vector2(2, 4)), Color("536038"), true)
		draw_rect(Rect2(Vector2(rect.position.x + 4, rect.end.y - 4), Vector2(3, 2)), Color("687343"), true)
	# Narrow overhead threshold and rain-darkened eave; no front-facing doorway.
	draw_rect(Rect2(Vector2(rect.get_center().x - 4, rect.end.y + 1), Vector2(8, 4)), Color(0.16, 0.11, 0.08, 0.72), true)
	draw_rect(Rect2(Vector2(rect.get_center().x - 3, rect.end.y + 1), Vector2(6, 2)), Color("9a6938"), true)

func _draw_town_center(rect: Rect2, tier: int) -> void:
	_draw_open_yard(rect, Color("745137"), mini(4, 1 + tier / 4), "camp")
	if tier <= 3:
		var tent_color := Color("bd7042").lightened(float(tier - 1) * 0.07)
		var tent_centers := [rect.position + Vector2(rect.size.x * 0.27, rect.size.y * 0.30), rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.34), rect.position + Vector2(rect.size.x * 0.35, rect.size.y * 0.72), rect.position + Vector2(rect.size.x * 0.72, rect.size.y * 0.72)]
		for index in mini(tier + 1, tent_centers.size()):
			var center: Vector2 = tent_centers[index]
			var tent_shadow := PackedVector2Array([center + Vector2(0, -8), center + Vector2(8, -2), center + Vector2(7, 7), center + Vector2(0, 9), center + Vector2(-7, 7), center + Vector2(-8, -2)])
			for point_index in tent_shadow.size():
				tent_shadow[point_index] += Vector2(2, 2)
			draw_colored_polygon(tent_shadow, Color(0.10, 0.06, 0.04, 0.65))
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -8), center + Vector2(8, -2), center + Vector2(7, 7), center + Vector2(0, 9), center + Vector2(-7, 7), center + Vector2(-8, -2)]), tent_color.darkened(0.18))
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -7), center + Vector2(6, -1), center + Vector2(5, 6), center, center + Vector2(-5, 6), center + Vector2(-6, -1)]), tent_color)
			draw_line(center + Vector2(0, -7), center + Vector2(0, 8), tent_color.lightened(0.22), 2.0)
			draw_rect(Rect2(center + Vector2(-2, 5), Vector2(4, 4)), Color("342019"), true)
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
		var keep_court := rect.grow(-7)
		draw_colored_polygon(PackedVector2Array([
			keep_court.position + Vector2(5, 4), Vector2(keep_court.end.x - 6, keep_court.position.y + 3),
			keep_court.end - Vector2(4, 6), Vector2(keep_court.position.x + 4, keep_court.end.y - 5),
		]), Color(0.39, 0.35, 0.29, 0.34))
		draw_rect(keep_court.grow(2), Color("353230"), false, 4.0)
		draw_rect(keep_court, Color("858179"), false, 3.0)
		var core_size := Vector2(48 + (tier - 8) * 4, 42 + (tier - 8) * 4)
		var core := Rect2(Vector2(keep_court.get_center().x - core_size.x * 0.5, keep_court.position.y + 10), core_size)
		_draw_top_roof(core, Color("5e4c43"))
		# A service wing appears immediately; the second and the fortified gatehouse
		# distinguish Large and Established Keep without enlarging one flat roof.
		_draw_top_roof(Rect2(keep_court.position + Vector2(8, keep_court.size.y - 29), Vector2(21, 19)), Color("6a5040"))
		if tier >= 9:
			_draw_top_roof(Rect2(Vector2(keep_court.end.x - 29, keep_court.end.y - 29), Vector2(21, 19)), Color("6a5040"))
			for corner in [keep_court.position - Vector2(2, 2), Vector2(keep_court.end.x - 9, keep_court.position.y - 2), Vector2(keep_court.position.x - 2, keep_court.end.y - 9), keep_court.end - Vector2(9, 9)]:
				draw_rect(Rect2(corner, Vector2(9, 9)), Color("67645f"), true)
		if tier >= 10:
			for x in range(int(keep_court.position.x + 3), int(keep_court.end.x - 3), 7):
				draw_rect(Rect2(Vector2(x, keep_court.position.y - 2), Vector2(4, 3)), Color("aaa49a"), true)
			var keep_gate := Rect2(Vector2(keep_court.get_center().x - 9, keep_court.end.y - 15), Vector2(18, 14))
			draw_rect(keep_gate.grow(2), Color("373331"), true)
			draw_rect(keep_gate, Color("77736d"), true)
			draw_rect(Rect2(Vector2(keep_gate.get_center().x - 3, keep_gate.position.y + 4), Vector2(6, 10)), Color("271d18"), true)
	else:
		var castle := rect.grow(-7)
		var courtyard := Color(0.38, 0.34, 0.28, 0.32)
		draw_colored_polygon(PackedVector2Array([
			castle.position + Vector2(7, 5), Vector2(castle.end.x - 8, castle.position.y + 4),
			castle.end - Vector2(5, 8), Vector2(castle.position.x + 5, castle.end.y - 6),
		]), courtyard)
		draw_rect(castle.grow(2), Color("2b2928"), false, 4.0)
		var wall_width := 3.0 + float(mini(3, tier - 10))
		draw_rect(castle, Color("858179"), false, wall_width)
		var tower_size := 12 + mini(5, tier - 11)
		for corner in [castle.position - Vector2(2, 2), Vector2(castle.end.x - tower_size + 2, castle.position.y - 2), Vector2(castle.position.x - 2, castle.end.y - tower_size + 2), castle.end - Vector2(tower_size - 2, tower_size - 2)]:
			draw_rect(Rect2(corner + Vector2(2, 3), Vector2(tower_size, tower_size)), Color(0.08, 0.07, 0.06, 0.62), true)
			draw_rect(Rect2(corner, Vector2(tower_size, tower_size)), Color("67645f"), true)
			draw_rect(Rect2(corner + Vector2(3, 3), Vector2(tower_size - 6, tower_size - 6)), Color("8c8880"), true)
		# Stronghold and castle tiers stay densely occupied through several roof
		# masses instead of collapsing into either an empty yard or one giant slab.
		var keep_size := 48 + (tier - 11) * 2
		var keep_rect := Rect2(castle.get_center() - Vector2(keep_size, keep_size) * 0.5 + Vector2(0, -4), Vector2(keep_size, keep_size))
		_draw_top_roof(keep_rect, Color("55443e"))
		# Gatehouse and packed service wings make the late center read as a
		# working fortified complex, not a tiny roof in an empty square.
		var gatehouse := Rect2(Vector2(castle.get_center().x - 10, castle.end.y - 15), Vector2(20, 14))
		draw_rect(gatehouse.grow(2), Color("373331"), true)
		draw_rect(gatehouse, Color("77736d"), true)
		draw_rect(Rect2(Vector2(gatehouse.get_center().x - 3, gatehouse.position.y + 5), Vector2(6, gatehouse.size.y - 3)), Color("271d18"), true)
		var wing_height := 25 + mini(5, tier - 11)
		_draw_top_roof(Rect2(castle.position + Vector2(9, 17), Vector2(19, wing_height)), Color("685247"))
		_draw_top_roof(Rect2(Vector2(castle.end.x - 28, castle.position.y + 17), Vector2(19, wing_height)), Color("685247"))
		if tier >= 12:
			_draw_crates(castle.position + Vector2(14, castle.size.y - 27), 3, Color("9b6e3d"))
			_draw_crates(Vector2(castle.end.x - 27, castle.end.y - 27), 3, Color("9b6e3d"))
		if tier >= 13:
			draw_rect(Rect2(castle.position + Vector2(12, 12), castle.size - Vector2(24, 24)), Color("a29c91"), false, 2.0)
			for point in [castle.position + Vector2(15, castle.size.y - 31), Vector2(castle.end.x - 29, castle.end.y - 31)]:
				draw_rect(Rect2(point, Vector2(8, 6)), Color("6e6a64"), true)
		if tier >= 14:
			for x in range(int(castle.position.x + 3), int(castle.end.x - 2), 7):
				draw_rect(Rect2(Vector2(x, castle.position.y - 2), Vector2(4, 3)), Color("aaa49a"), true)
			for y in range(int(castle.position.y + 10), int(castle.end.y - 10), 9):
				draw_rect(Rect2(Vector2(castle.position.x - 2, y), Vector2(3, 5)), Color("aaa49a"), true)
				draw_rect(Rect2(Vector2(castle.end.x - 1, y), Vector2(3, 5)), Color("aaa49a"), true)
		if tier >= 15:
			for flag_offset in [Vector2(-keep_size * 0.32, -keep_size * 0.42), Vector2(keep_size * 0.32, -keep_size * 0.42)]:
				var mast: Vector2 = keep_rect.get_center() + Vector2(flag_offset)
				draw_rect(Rect2(mast, Vector2(2, 14)), Color("4e3a29"), true)
				draw_colored_polygon(PackedVector2Array([mast + Vector2(2, 0), mast + Vector2(11, 4), mast + Vector2(2, 8)]), Color("c9a64a"))

func _draw_housing_top(rect: Rect2, tier: int, doggo: bool, housing_branch: String = "standard") -> void:
	_draw_open_yard(rect, Color("72523b"), tier, "doggo_house" if doggo else "housing")
	if doggo:
		var kennel_count := mini(4, tier + 1)
		for index in kennel_count:
			var center := rect.position + Vector2(9 + (index % 2) * 17, 12 + (index / 2) * 18)
			draw_colored_polygon(PackedVector2Array([center + Vector2(-6, 5), center + Vector2(0, -5), center + Vector2(6, 5)]), Color("8d5c38"))
			draw_rect(Rect2(center + Vector2(-2, 1), Vector2(4, 5)), Color("241812"), true)
		return
	var main_roof := Rect2(rect.position + Vector2(6, 6), rect.size - Vector2(12, 17))
	var roof_color := Color("755443").lightened(float(mini(tier, 4) - 1) * 0.05)
	if housing_branch == "quality":
		roof_color = roof_color.lerp(Color("765c52"), 0.34)
	elif housing_branch == "occupancy":
		roof_color = roof_color.lerp(Color("765039"), 0.24)
	_draw_top_roof(main_roof, roof_color)
	# Chimney, porch and a small lived-in garden break the roof-card silhouette.
	draw_rect(Rect2(main_roof.position + Vector2(main_roof.size.x * 0.70, 5), Vector2(7, 7)), Color("403a36"), true)
	draw_rect(Rect2(main_roof.position + Vector2(main_roof.size.x * 0.70 + 1, 4), Vector2(5, 5)), Color("89847c"), true)
	var porch := Rect2(Vector2(rect.get_center().x - 8, main_roof.end.y - 3), Vector2(16, 10))
	draw_rect(porch.grow(1), Color("2e2118"), true)
	for x in range(int(porch.position.x + 1), int(porch.end.x - 1), 4):
		draw_rect(Rect2(Vector2(x, porch.position.y + 1), Vector2(3, porch.size.y - 2)), Color("93653a"), true)
	for flower_offset in [Vector2(7, rect.size.y - 9), Vector2(12, rect.size.y - 7), Vector2(rect.size.x - 11, rect.size.y - 8)]:
		draw_rect(Rect2(rect.position + flower_offset, Vector2(2, 3)), Color("568242"), true)
		draw_rect(Rect2(rect.position + flower_offset - Vector2(1, 2), Vector2(4, 2)), Color("c56f75"), true)
	if tier >= 2:
		_draw_top_roof(Rect2(rect.position + Vector2(rect.size.x - 22, rect.size.y - 24), Vector2(15, 14)), Color("665047"))
	if tier >= 3:
		draw_rect(main_roof, Color("8d8982"), false, 2.0)
	if tier >= 4:
		_draw_top_roof(Rect2(rect.position + Vector2(7, rect.size.y - 25), Vector2(15, 14)), Color("6f5342"))
		if housing_branch == "occupancy":
			_draw_top_roof(Rect2(rect.position + Vector2(rect.size.x - 24, 7), Vector2(17, 13)), Color("704c36"))
		else:
			var courtyard := Rect2(rect.position + Vector2(7, rect.size.y - 18), Vector2(16, 9))
			draw_rect(courtyard, Color("4d7140"), true)
			draw_rect(courtyard.grow(1), Color("a39a83"), false, 1.0)
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
	draw_rect(Rect2(Vector2(rect.get_center().x - 3, rect.end.y - 12), Vector2(6, 8)), Color("251914"), true)

func _draw_tier_progression(rect: Rect2, category: String, tier: int, accent: Color) -> void:
	# Upgrades add category-specific capacity. The former universal annex/gear/
	# crystal recipe made unrelated structures converge on one silhouette.
	var industrial := category in ["refining", "manufacturing", "trash"]
	var civic := category in ["civics", "housing"]
	var rural := category in ["food_water", "harvesting"]
	var arcane := category in ["magic", "golems", "lighting"]
	var storage := category == "storage"
	if tier >= 2:
		if industrial:
			var machine_pad := Rect2(rect.end - Vector2(22, 20), Vector2(17, 15))
			draw_rect(machine_pad.grow(2), Color(0.12, 0.10, 0.09, 0.58), true)
			draw_rect(machine_pad, Color("716c64"), true)
			_draw_gear(machine_pad.get_center(), accent.lightened(0.22))
			_draw_pipe_path(PackedVector2Array([machine_pad.position + Vector2(2, 3), machine_pad.get_center(), Vector2(machine_pad.end.x - 1, machine_pad.end.y - 3)]), Color("9a9385"))
		elif civic:
			var civic_annex := Rect2(rect.end - Vector2(23, 19), Vector2(18, 13))
			_draw_canvas_roof(civic_annex, accent.lightened(0.18), accent.darkened(0.24))
			_draw_crates(rect.position + Vector2(6, rect.size.y - 13), mini(3, tier), accent.lightened(0.18))
		elif rural:
			var lean_to := Rect2(rect.end - Vector2(23, 20), Vector2(18, 14))
			_draw_top_roof(lean_to, accent.lightened(0.05))
			_draw_logs(rect.position + Vector2(7, rect.size.y - 13), mini(4, tier + 1), Color("916039"))
		elif arcane:
			var pylon := rect.end - Vector2(12, 13)
			_draw_magic_circle(pylon, accent.lightened(0.24), 7)
			_draw_crystal(pylon - Vector2(0, 2), Color("74e2e4"), 6)
		elif storage:
			_draw_crates(rect.position + Vector2(6, rect.size.y - 15), mini(5, tier + 1), accent.lightened(0.18))
			_draw_crates(rect.end - Vector2(19, 16), mini(4, tier), accent.darkened(0.04))
		else:
			_draw_crates(rect.end - Vector2(20, 16), mini(4, tier + 1), accent.lightened(0.12))
	if tier >= 3:
		# Broken masonry pads reinforce occupied corners without drawing a hard
		# rectangular outline around the entire lot.
		var stone := Color("8d8981")
		var pad_points := [
			rect.position + Vector2(3, 4), rect.position + Vector2(10, 2),
			Vector2(rect.end.x - 8, rect.position.y + 3), Vector2(rect.end.x - 6, rect.position.y + 10),
			Vector2(rect.position.x + 4, rect.end.y - 8), rect.end - Vector2(9, 6),
		]
		for index in pad_points.size():
			var point: Vector2 = pad_points[index]
			var size := Vector2(5 + index % 3, 4 + (index + 1) % 3)
			draw_rect(Rect2(point + Vector2(1, 2), size), Color(0.12, 0.10, 0.09, 0.54), true)
			draw_rect(Rect2(point, size), stone.darkened(float(index % 3) * 0.06), true)
			draw_rect(Rect2(point + Vector2.ONE, Vector2(maxf(2.0, size.x - 2), 1)), stone.lightened(0.13), true)
	if tier >= 4:
		if arcane:
			for offset in [Vector2(8, 8), Vector2(rect.size.x - 11, rect.size.y - 11)]:
				_draw_crystal(rect.position + offset, Color("70dce0"), 6)
		elif industrial:
			_draw_brick_furnace(rect.position + Vector2(rect.size.x - 14, 14))
			_draw_ingot_stack(rect.position + Vector2(rect.size.x - 12, rect.size.y - 11))
		elif civic:
			draw_rect(Rect2(rect.position + Vector2(7, 5), Vector2(rect.size.x - 14, 3)), Color("77746d"), true)
			for x in range(int(rect.position.x + 9), int(rect.end.x - 9), 9):
				draw_rect(Rect2(Vector2(x, rect.position.y + 3), Vector2(4, 4)), Color("a09a8f"), true)
		elif rural:
			_draw_water_tub(rect.end - Vector2(14, 13))
			_draw_sack_stack(rect.position + Vector2(11, rect.size.y - 10), Color("b39a61"))
		elif storage:
			draw_rect(Rect2(rect.position + Vector2(5, 5), Vector2(rect.size.x - 10, 3)), Color("686d6e"), true)
			_draw_cart(rect.position + Vector2(rect.size.x - 14, rect.size.y - 12), Color("8e6035"))
	if tier >= 5:
		if arcane:
			for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				draw_circle(rect.get_center() + direction * minf(rect.size.x, rect.size.y) * 0.34, 3.0, Color("6be0dc"))
		elif industrial:
			var second_machine := Rect2(rect.position + Vector2(5, rect.size.y * 0.57), Vector2(18, 13))
			draw_rect(second_machine, Color("5d5b57"), true)
			_draw_gear(second_machine.get_center(), Color("c2a35e"))
		elif civic or rural:
			var late_annex := Rect2(rect.position + Vector2(5, rect.size.y * 0.57), Vector2(18, 13))
			_draw_top_roof(late_annex, accent.darkened(0.08))
		elif storage:
			_draw_crates(rect.get_center() + Vector2(-8, 4), 7, accent.lightened(0.12))

func _draw_canvas_roof(rect: Rect2, canvas: Color, trim: Color) -> void:
	var center := rect.get_center()
	var points := PackedVector2Array([
		Vector2(center.x, rect.position.y), Vector2(rect.end.x, rect.position.y + 4),
		Vector2(rect.end.x - 2, rect.end.y), Vector2(center.x, rect.end.y - 3),
		Vector2(rect.position.x + 2, rect.end.y), Vector2(rect.position.x, rect.position.y + 4),
	])
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(2, 4))
	draw_colored_polygon(shadow, Color(0.07, 0.045, 0.035, 0.76))
	draw_colored_polygon(points, trim.darkened(0.46))
	draw_colored_polygon(PackedVector2Array([
		Vector2(center.x, rect.position.y + 2), Vector2(rect.end.x - 3, rect.position.y + 5),
		Vector2(center.x, rect.end.y - 5), Vector2(rect.position.x + 3, rect.position.y + 5),
	]), canvas.darkened(0.03))
	draw_line(Vector2(center.x, rect.position.y + 1), Vector2(center.x, rect.end.y - 4), canvas.lightened(0.22), 2.0)
	var seed := absi(int(rect.position.x * 7.0 + rect.position.y * 13.0))
	for row_y in range(int(rect.position.y + 7), int(rect.end.y - 5), 5):
		var start_x := rect.position.x + 4 + posmod(seed + row_y, 4)
		draw_rect(Rect2(Vector2(start_x, row_y), Vector2(maxf(3.0, rect.size.x * 0.24), 1)), canvas.darkened(0.16), true)
		var right_width := maxf(3.0, rect.size.x * 0.18)
		draw_rect(Rect2(Vector2(rect.end.x - right_width - 4, row_y + 1), Vector2(right_width, 1)), canvas.lightened(0.10), true)
	# Mended canvas squares and perimeter lashings communicate a working shelter,
	# not a pristine geometric icon.
	if rect.size.x >= 20:
		var patch := Rect2(rect.position + Vector2(5 + posmod(seed, maxi(2, int(rect.size.x - 15))), 7), Vector2(6, 5))
		draw_rect(patch, canvas.darkened(0.13), true)
		draw_rect(patch.grow(-1), canvas.lightened(0.07), false, 1.0)
	for corner in [rect.position + Vector2(1, 3), Vector2(rect.end.x - 3, rect.position.y + 3), Vector2(rect.position.x + 2, rect.end.y - 3), rect.end - Vector2(4, 3)]:
		draw_rect(Rect2(corner, Vector2(3, 5)), trim, true)
	draw_rect(Rect2(Vector2(center.x - 4, rect.end.y - 2), Vector2(8, 5)), Color(0.17, 0.12, 0.08, 0.72), true)

func _draw_market_awning(rect: Rect2, cloth: Color) -> void:
	_draw_canvas_roof(rect, cloth, Color("65472d"))
	for x in range(int(rect.position.x + 4), int(rect.end.x - 3), 6):
		draw_rect(Rect2(Vector2(x, rect.position.y + 4), Vector2(3, rect.size.y - 8)), cloth.lightened(0.18), true)
	draw_rect(Rect2(Vector2(rect.position.x + 3, rect.end.y - 4), Vector2(rect.size.x - 6, 3)), Color("684629"), true)

func _draw_tool_rack(origin: Vector2, size: Vector2) -> void:
	draw_rect(Rect2(origin + Vector2(0, 1), size), Color(0.12, 0.08, 0.05, 0.55), true)
	draw_rect(Rect2(origin, Vector2(size.x, 3)), Color("885f36"), true)
	for index in 3:
		var x := origin.x + 4 + index * maxf(5.0, (size.x - 8) / 3.0)
		draw_line(Vector2(x, origin.y + 4), Vector2(x + (2 if index % 2 else -2), origin.y + size.y - 1), Color("b27c43"), 2.0)
		draw_rect(Rect2(Vector2(x - 2, origin.y + 3), Vector2(5, 3)), Color("a5aaab"), true)

func _draw_basket(center: Vector2, fill: Color) -> void:
	draw_rect(Rect2(center - Vector2(6, 4), Vector2(12, 8)), Color("4d321d"), true)
	draw_rect(Rect2(center - Vector2(5, 3), Vector2(10, 6)), Color("a4773e"), true)
	for offset in [-3, 0, 3]:
		draw_rect(Rect2(center + Vector2(offset, -2), Vector2(2, 4)), fill.lightened(float(offset + 3) * 0.025), true)

func _draw_stump_workbench(center: Vector2) -> void:
	draw_circle(center, 7, Color("4b301d"))
	draw_circle(center, 5, Color("9a6031"))
	draw_circle(center, 2, Color("c28a4b"))
	draw_line(center + Vector2(-5, 0), center + Vector2(5, 1), Color("634022"), 1.0)

func _draw_axe(center: Vector2) -> void:
	draw_line(center + Vector2(-5, 6), center + Vector2(5, -6), Color("9b6937"), 2.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(2, -7), center + Vector2(9, -8), center + Vector2(7, -2), center + Vector2(3, -2)]), Color("a8adae"))

func _draw_pickaxe(center: Vector2) -> void:
	draw_line(center + Vector2(-5, 7), center + Vector2(4, -6), Color("956238"), 2.0)
	draw_polyline(PackedVector2Array([center + Vector2(-4, -7), center + Vector2(3, -9), center + Vector2(9, -5)]), Color("a4a8a8"), 2.0)

func _draw_mine_track(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(1, 0), Vector2(2, rect.size.y)), Color("5a4230"), true)
	draw_rect(Rect2(Vector2(rect.end.x - 3, rect.position.y), Vector2(2, rect.size.y)), Color("5a4230"), true)
	for y in range(int(rect.position.y + 2), int(rect.end.y - 1), 6):
		draw_rect(Rect2(Vector2(rect.position.x, y), Vector2(rect.size.x, 2)), Color("8b6339"), true)
	draw_rect(Rect2(rect.position + Vector2(3, 0), Vector2(1, rect.size.y)), Color("a8aaab"), true)
	draw_rect(Rect2(Vector2(rect.end.x - 4, rect.position.y), Vector2(1, rect.size.y)), Color("a8aaab"), true)

func _draw_sack_stack(center: Vector2, color: Color) -> void:
	for offset in [Vector2(-5, 0), Vector2(2, 1), Vector2(-1, -5)]:
		draw_rect(Rect2(center + offset, Vector2(7, 6)), Color("49331f"), true)
		draw_rect(Rect2(center + offset + Vector2(1, 1), Vector2(5, 4)), color, true)

func _draw_water_puddle(center: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(-7, 0), center + Vector2(-4, -4), center + Vector2(3, -5), center + Vector2(7, -1), center + Vector2(5, 4), center + Vector2(-3, 5)]), Color("376d78"))
	draw_rect(Rect2(center + Vector2(-3, -2), Vector2(5, 1)), Color("63a3ab"), true)

func _draw_saw_bed(rect: Rect2) -> void:
	draw_rect(rect.grow(1), Color("2b2017"), true)
	draw_rect(rect, Color("8b633a"), true)
	for y in range(int(rect.position.y + 2), int(rect.end.y - 1), 5):
		draw_rect(Rect2(Vector2(rect.position.x + 2, y), Vector2(rect.size.x - 4, 2)), Color("b27b3e"), true)
	var saw_x := rect.get_center().x
	draw_rect(Rect2(Vector2(saw_x - 1, rect.position.y + 2), Vector2(3, rect.size.y - 4)), Color("c4c3ba"), true)
	for y in range(int(rect.position.y + 4), int(rect.end.y - 4), 4):
		draw_rect(Rect2(Vector2(saw_x + 2, y), Vector2(2, 2)), Color("8f918d"), true)

func _draw_board_stack(origin: Vector2, count: int) -> void:
	for index in count:
		var y := origin.y + index * 4
		draw_rect(Rect2(Vector2(origin.x + index % 2, y), Vector2(21, 3)), Color("3c2819"), true)
		draw_rect(Rect2(Vector2(origin.x + 1 + index % 2, y), Vector2(19, 2)), Color("b27b43"), true)

func _draw_brick_furnace(center: Vector2) -> void:
	draw_rect(Rect2(center - Vector2(9, 10), Vector2(18, 20)), Color("322925"), true)
	draw_rect(Rect2(center - Vector2(7, 8), Vector2(14, 16)), Color("78635a"), true)
	for y in [-6, -1, 4]:
		draw_rect(Rect2(center + Vector2(-6, y), Vector2(12, 1)), Color("a58e80"), true)
	draw_rect(Rect2(center - Vector2(4, 3), Vector2(8, 8)), Color("421d16"), true)
	draw_rect(Rect2(center - Vector2(2, 1), Vector2(4, 5)), Color("ec742c"), true)
	draw_rect(Rect2(center + Vector2(3, -13), Vector2(5, 7)), Color("55504c"), true)

func _draw_water_tub(center: Vector2) -> void:
	draw_rect(Rect2(center - Vector2(8, 5), Vector2(16, 10)), Color("392b20"), true)
	draw_rect(Rect2(center - Vector2(6, 3), Vector2(12, 6)), Color("4f8994"), true)
	draw_rect(Rect2(center + Vector2(-4, -2), Vector2(7, 1)), Color("7bb8bf"), true)

func _draw_ingot_stack(center: Vector2) -> void:
	for offset in [Vector2(-5, 1), Vector2(1, 1), Vector2(-2, -3)]:
		draw_colored_polygon(PackedVector2Array([center + offset + Vector2(-3, 2), center + offset + Vector2(-2, -2), center + offset + Vector2(3, -2), center + offset + Vector2(4, 2)]), Color("a6a6a0"))

func _draw_bow_rack(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), Color("69472c"), true)
	draw_rect(Rect2(Vector2(rect.end.x - 3, rect.position.y), Vector2(3, rect.size.y)), Color("69472c"), true)
	draw_rect(Rect2(rect.position + Vector2(1, 2), Vector2(rect.size.x - 2, 2)), Color("8e6137"), true)
	for index in 3:
		var center := rect.position + Vector2(8 + index * maxf(7.0, (rect.size.x - 16) / 2.0), rect.size.y * 0.58)
		draw_arc(center, 5, -PI * 0.48, PI * 0.48, 8, Color("c18a4c"), 1.0)
		draw_line(center + Vector2(0, -5), center + Vector2(0, 5), Color("ded2aa"), 1.0)

func _draw_arrow_bundle(center: Vector2, color: Color) -> void:
	for index in 3:
		draw_line(center + Vector2(index * 2 - 2, 5), center + Vector2(index * 2 - 2, -7), Color("ae793e"), 1.0)
		draw_colored_polygon(PackedVector2Array([center + Vector2(index * 2 - 4, -6), center + Vector2(index * 2 - 2, -10), center + Vector2(index * 2, -6)]), color)
	draw_rect(Rect2(center + Vector2(-4, 0), Vector2(8, 2)), Color("6b4328"), true)

func _draw_altar_dais(center: Vector2, color: Color, radius: int) -> void:
	draw_circle(center + Vector2(2, 3), radius + 2, Color(0.05, 0.04, 0.07, 0.65))
	draw_circle(center, radius, Color("343a3b"))
	draw_circle(center, radius - 3, Color("777b78"))
	draw_circle(center, radius - 7, Color("263d40"))
	draw_arc(center, radius - 5, 0, TAU, 24, color, 2.0)
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		var node: Vector2 = center + Vector2(direction) * float(radius - 3)
		draw_rect(Rect2(node - Vector2(3, 3), Vector2(6, 6)), Color("4f5553"), true)
		draw_rect(Rect2(node - Vector2(1, 1), Vector2(3, 3)), color.lightened(0.20), true)

func _draw_filter_tank(center: Vector2, water: Color, clean: bool) -> void:
	draw_circle(center + Vector2(2, 2), 11, Color(0.05, 0.06, 0.06, 0.58))
	draw_circle(center, 10, Color("4b4d49"))
	draw_circle(center, 8, Color("99988e"))
	draw_circle(center, 6, water)
	if clean:
		draw_rect(Rect2(center + Vector2(-4, -2), Vector2(7, 1)), water.lightened(0.28), true)
	else:
		for offset in [Vector2(-3, -2), Vector2(2, 1), Vector2(-1, 3)]:
			draw_rect(Rect2(center + offset, Vector2(2, 2)), Color("74694f"), true)

func _draw_pipe_path(points: PackedVector2Array, color: Color) -> void:
	draw_polyline(points, Color(0.08, 0.07, 0.06, 0.70), 5.0)
	draw_polyline(points, color, 3.0)
	for point in points:
		draw_rect(Rect2(point - Vector2(2, 2), Vector2(5, 5)), color.lightened(0.12), true)

func _draw_gravel_filter(rect: Rect2) -> void:
	draw_rect(rect.grow(1), Color("302a24"), true)
	draw_rect(rect, Color("756c5c"), true)
	for y in range(int(rect.position.y + 3), int(rect.end.y - 2), 6):
		for x in range(int(rect.position.x + 3), int(rect.end.x - 2), 5):
			draw_rect(Rect2(Vector2(x, y), Vector2(2, 2)), Color("aaa18f").darkened(float((x + y) % 3) * 0.06), true)

func _draw_well(rect: Rect2) -> void:
	var center := rect.get_center()
	draw_circle(center + Vector2(2, 3), 14, Color(0.07, 0.06, 0.05, 0.62))
	draw_circle(center, 13, Color("3b3936"))
	draw_circle(center, 11, Color("989389"))
	draw_circle(center, 7, Color("245a68"))
	draw_rect(Rect2(center + Vector2(-12, -15), Vector2(4, 14)), Color("75502e"), true)
	draw_rect(Rect2(center + Vector2(8, -15), Vector2(4, 14)), Color("75502e"), true)
	_draw_canvas_roof(Rect2(center + Vector2(-14, -19), Vector2(28, 10)), Color("87613c"), Color("5f4129"))
	draw_line(center + Vector2(-7, -5), center + Vector2(7, -5), Color("b08046"), 2.0)
	draw_rect(Rect2(center + Vector2(-1, -5), Vector2(2, 10)), Color("a68b62"), true)

func _draw_rain_catcher(rect: Rect2) -> void:
	var basin := rect.grow(-6.0)
	draw_rect(basin.grow(1), Color("252b2b"), true)
	draw_rect(basin, Color("4c8792"), true)
	for x in range(int(basin.position.x + 2), int(basin.end.x - 1), 7):
		draw_rect(Rect2(Vector2(x, basin.position.y + 1), Vector2(3, basin.size.y - 2)), Color("67aebb"), true)
	# Four canvas vanes funnel rain into the visible central reservoir.
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		var inner: Vector2 = rect.get_center() + Vector2(direction) * 7.0
		var outer: Vector2 = rect.get_center() + Vector2(direction) * 18.0
		draw_line(inner, outer, Color("9e8c65"), 5.0)
		draw_line(inner, outer, Color("c3b889"), 3.0)
	draw_circle(rect.get_center(), 6, Color("276f7e"))
	draw_circle(rect.get_center(), 3, Color("6bc0cf"))

func _draw_fountain(center: Vector2, radius: int, large: bool) -> void:
	draw_circle(center + Vector2(2, 3), radius + 2, Color(0.06, 0.06, 0.05, 0.58))
	draw_circle(center, radius + 1, Color("3c3b38"))
	draw_circle(center, radius - 1, Color("aaa59a"))
	draw_circle(center, radius - 4, Color("4d9dac"))
	draw_circle(center, maxi(3, radius - 8), Color("79766f"))
	if large:
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			var spout: Vector2 = center + Vector2(direction) * float(radius - 5)
			draw_rect(Rect2(spout - Vector2(2, 2), Vector2(4, 4)), Color("d1ccc0"), true)
			draw_line(spout, center + direction * 3.0, Color("9edce2"), 1.0)
	draw_rect(Rect2(center - Vector2(3, 4), Vector2(6, 8)), Color("d0cbc0"), true)
	draw_rect(Rect2(center - Vector2(5, 5), Vector2(10, 3)), Color("8e8a82"), true)

func _draw_animal_tracks(center: Vector2) -> void:
	for index in 3:
		var point := center + Vector2(index * 7 - 7, (index % 2) * 4)
		draw_circle(point, 2, Color("413524"))
		for toe in [Vector2(-2, -3), Vector2(1, -4), Vector2(3, -2)]:
			draw_rect(Rect2(point + toe, Vector2(2, 2)), Color("413524"), true)

func _draw_outpost(rect: Rect2, tier: int) -> void:
	# Broken palisade, central watch platform and equipment caches remain
	# legible from a true overhead camera.
	for x in range(int(rect.position.x + 4), int(rect.end.x - 3), 6):
		draw_rect(Rect2(Vector2(x, rect.position.y + 3), Vector2(4, 6)), Color("795231"), true)
		draw_rect(Rect2(Vector2(x, rect.end.y - 8), Vector2(4, 6)), Color("795231"), true)
	for y in range(int(rect.position.y + 9), int(rect.end.y - 8), 6):
		draw_rect(Rect2(Vector2(rect.position.x + 3, y), Vector2(6, 4)), Color("795231"), true)
		draw_rect(Rect2(Vector2(rect.end.x - 8, y), Vector2(6, 4)), Color("795231"), true)
	var platform_size := 22.0 + float(mini(tier, 3)) * 2.0
	var platform := Rect2(rect.get_center() - Vector2.ONE * platform_size * 0.5, Vector2.ONE * platform_size)
	draw_rect(Rect2(platform.position + Vector2(0, 1), platform.size + Vector2(4, 4)), Color(0.06, 0.05, 0.04, 0.60), true)
	_draw_top_roof(platform, Color("5f4b3b").lightened(float(tier - 1) * 0.06))
	if tier >= 3:
		_draw_small_bow_emplacement(rect.position + Vector2(rect.size.x - 14, rect.size.y - 14))
	else:
		_draw_target(rect.position + Vector2(rect.size.x - 14, rect.size.y - 14))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 12, 7), Vector2(2, 20)), Color("76502e"), true)
	draw_colored_polygon(PackedVector2Array([rect.position + Vector2(rect.size.x - 10, 7), rect.position + Vector2(rect.size.x - 2, 11), rect.position + Vector2(rect.size.x - 10, 15)]), Color("bd5d4f"))

func _draw_small_bow_emplacement(center: Vector2) -> void:
	# A compact overhead mechanism: braced deck, central stock and symmetrical
	# bow limbs. It reads as mounted equipment without inventing a side facade.
	draw_rect(Rect2(center - Vector2(7, 7), Vector2(14, 14)), Color("2b241d"), true)
	draw_rect(Rect2(center - Vector2(5, 5), Vector2(10, 10)), Color("8a6942"), true)
	draw_line(center + Vector2(-6, -4), center + Vector2(-6, 4), Color("c09a58"), 2.0)
	draw_line(center + Vector2(6, -4), center + Vector2(6, 4), Color("c09a58"), 2.0)
	draw_line(center + Vector2(-6, -4), center + Vector2(6, 0), Color("d8be77"), 1.0)
	draw_line(center + Vector2(-6, 4), center + Vector2(6, 0), Color("d8be77"), 1.0)
	draw_rect(Rect2(center + Vector2(-1, -7), Vector2(2, 14)), Color("4b3525"), true)
	draw_rect(Rect2(center + Vector2(-1, -6), Vector2(1, 10)), Color("d3c48c"), true)

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
	if rect.size.x < 8 or rect.size.y < 7:
		return
	var soil := rect.grow(-1)
	draw_rect(soil, Color("4a3824"), true)
	# Tall beds use vertical crop lanes; broad beds use horizontal lanes. This
	# fills irregular farm footprints while keeping individual plants legible.
	if soil.size.y > soil.size.x * 1.15:
		var column_count := 2 if soil.size.x < 15 else 3
		for column in column_count:
			var x := soil.position.x + 3 + column * maxf(5.0, (soil.size.x - 6) / float(column_count))
			draw_rect(Rect2(Vector2(x - 1, soil.position.y + 2), Vector2(3, soil.size.y - 4)), Color("2f281d"), true)
			for y in range(int(soil.position.y + 4), int(soil.end.y - 3), 6):
				var plant_color := Color("82a747") if (column + y) % 2 == 0 else Color("b0ad43")
				draw_rect(Rect2(Vector2(x - 2, y), Vector2(5, 3)), plant_color.darkened(0.18), true)
				draw_rect(Rect2(Vector2(x - 1, y - 2), Vector2(3, 4)), plant_color, true)
	else:
		var row_count := maxi(1, mini(4, int(soil.size.y / 6.0)))
		for row in row_count:
			var y := soil.position.y + 3 + row * maxf(5.0, (soil.size.y - 5) / float(row_count))
			draw_rect(Rect2(Vector2(soil.position.x + 2, y), Vector2(soil.size.x - 4, 3)), Color("2f281d"), true)
			for x in range(int(soil.position.x + 4), int(soil.end.x - 3), 6):
				var plant_color := Color("779c3e") if (row + x) % 2 == 0 else Color("a0a842")
				draw_rect(Rect2(Vector2(x, y - 2), Vector2(3, 5)), plant_color, true)

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
	_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 25)), roof_color)
	_draw_table(rect.position + Vector2(7, 32), Vector2(rect.size.x - 14, 10), roof_color.lightened(0.08))
	# Common drive train is visible from overhead; the caller adds the material-
	# specific cutter, crystal basin, or other functional centerpiece.
	draw_circle(rect.position + Vector2(rect.size.x - 11, rect.size.y - 10), 7, Color("302d29"))
	draw_circle(rect.position + Vector2(rect.size.x - 11, rect.size.y - 10), 4, Color("8a8174"))
	draw_circle(rect.position + Vector2(rect.size.x - 11, rect.size.y - 10), 1, Color("3c3935"))
	draw_rect(Rect2(rect.position + Vector2(6, rect.size.y - 11), Vector2(15, 5)), roof_color.darkened(0.28), true)

func _draw_anvil(center: Vector2) -> void:
	draw_rect(Rect2(center - Vector2(7, 3), Vector2(14, 5)), Color("9b9b96"), true)
	draw_rect(Rect2(center - Vector2(2, 1), Vector2(5, 8)), Color("696b69"), true)

func _draw_manufacturing_yard(rect: Rect2, roof_color: Color) -> void:
	_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 25)), roof_color)
	_draw_table(rect.position + Vector2(6, 32), Vector2(rect.size.x - 12, 10), Color("80603f"))
	_draw_tool_rack(rect.position + Vector2(6, rect.size.y - 11), Vector2(15, 9))
	_draw_water_tub(rect.position + Vector2(rect.size.x - 10, rect.size.y - 9))

func _draw_shield(center: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(-7, -8), center + Vector2(7, -8), center + Vector2(5, 4), center + Vector2(0, 10), center + Vector2(-5, 4)]), color)
	draw_rect(Rect2(center + Vector2(-1, -7), Vector2(2, 13)), color.lightened(0.24), true)

func _draw_drum(center: Vector2, color: Color) -> void:
	draw_circle(center, 10, Color("2d2924"))
	draw_circle(center, 8, color)
	draw_circle(center, 3, color.darkened(0.25))
	draw_rect(Rect2(center + Vector2(-10, -1), Vector2(20, 2)), color.lightened(0.16), true)

func _draw_storage_yard(rect: Rect2, definition_id: String, building: Dictionary) -> void:
	match definition_id:
		"wood_storage":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(24, 20)), Color("5b3c29"))
			_draw_logs(rect.position + Vector2(31, 5), 5, Color("a36832"))
			_draw_board_stack(rect.position + Vector2(5, rect.size.y - 17), 3)
			for point in [rect.position + Vector2(27, rect.size.y - 12), rect.position + Vector2(rect.size.x - 8, rect.size.y - 12)]:
				draw_circle(point, 5, Color("4b301e")); draw_circle(point, 3, Color("ba7840"))
		"rock_storage":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 20)), Color("54514c"))
			_draw_storage_bay(Rect2(rect.position + Vector2(5, 23), Vector2(17, 18)), Color("6b6965"))
			_draw_storage_bay(Rect2(rect.position + Vector2(26, 23), Vector2(17, 18)), Color("777571"))
			_draw_rock_pile(rect.position + Vector2(13, 31), Color("99958e"))
			_draw_rock_pile(rect.position + Vector2(34, 31), Color("7f817f"))
		"crystal_storage":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(25, 21)), Color("314f56"))
			_draw_storage_bay(Rect2(rect.position + Vector2(27, 5), Vector2(16, 35)), Color("27565d"))
			for point in [rect.position + Vector2(13, 31), rect.position + Vector2(33, 13), rect.position + Vector2(35, 31)]:
				_draw_crystal(point, Color("61d5df"), 7)
			draw_line(rect.position + Vector2(5, rect.size.y - 7), rect.position + Vector2(rect.size.x - 5, rect.size.y - 7), Color("5acbd3"), 2.0)
		"mineral_storage":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(26, 21)), Color("61564d"))
			_draw_storage_bay(Rect2(rect.position + Vector2(28, 5), Vector2(15, 17)), Color("6d6259"))
			_draw_rock_pile(rect.position + Vector2(35, 13), Color("8c7770"))
			_draw_ingot_stack(rect.position + Vector2(13, 31))
			_draw_ingot_stack(rect.position + Vector2(33, 32))
			draw_rect(Rect2(rect.position + Vector2(6, rect.size.y - 10), Vector2(15, 5)), Color("a9854c"), true)
		"food_storage":
			_draw_canvas_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 22)), Color("9d9152"), Color("6f5230"))
			_draw_sack_stack(rect.position + Vector2(12, 31), Color("b9a46d"))
			_draw_crates(rect.position + Vector2(25, 25), 4, Color("8d6937"))
			_draw_basket(rect.position + Vector2(rect.size.x - 10, rect.size.y - 10), Color("86a244"))
		"gold_storage":
			var vault := Rect2(rect.position + Vector2(6, 5), rect.size - Vector2(12, 15))
			draw_rect(vault.grow(2), Color("2c2926"), true)
			draw_rect(vault, Color("77736c"), true)
			draw_rect(vault.grow(-4), Color("3d3935"), true)
			draw_circle(vault.get_center(), 7, Color("a98a45"))
			draw_circle(vault.get_center(), 3, Color("36312b"))
			_draw_ingot_stack(rect.position + Vector2(10, rect.size.y - 8))
			_draw_ingot_stack(rect.position + Vector2(rect.size.x - 10, rect.size.y - 8))
		"ammo_storage":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 22)), Color("634b34"))
			_draw_arrow_bundle(rect.position + Vector2(10, 31), Color("c29e5e"))
			_draw_arrow_bundle(rect.position + Vector2(21, 31), Color("8da26b"))
			for point in [rect.position + Vector2(33, 28), rect.position + Vector2(40, 34), rect.position + Vector2(31, 38)]:
				draw_circle(point, 5, Color("3b3834")); draw_circle(point, 3, Color("92908a"))
		"equipment_storage":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(25, 21)), Color("4c4d4e"))
			_draw_tool_rack(rect.position + Vector2(27, 6), Vector2(16, 17))
			_draw_shield(rect.position + Vector2(14, 33), Color("989b9b"))
			_draw_bow(rect.position + Vector2(33, 34), Color("a8753d"))
		"miscellaneous_storage":
			_draw_canvas_roof(Rect2(rect.position + Vector2(4, 4), Vector2(28, 22)), Color("75675d"), Color("5b432d"))
			_draw_crates(rect.position + Vector2(29, 6), 4, Color("89633c"))
			_draw_sack_stack(rect.position + Vector2(12, 32), Color("998775"))
			_draw_basket(rect.position + Vector2(34, 34), Color("6c8365"))
		_:
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 22)), Color("665a4d"))
	_draw_storage_filter_marker(rect, building)

func _draw_storage_filter_marker(rect: Rect2, building: Dictionary) -> void:
	var filters: Dictionary = building.get("storage_filters", {})
	if filters.is_empty():
		return
	var enabled_count := 0
	for resource_id in filters:
		if bool(filters[resource_id]):
			enabled_count += 1
	var marker := Rect2(rect.end - Vector2(18, 11), Vector2(14, 7))
	draw_rect(marker.grow(2), Color("241d18"), true)
	draw_rect(marker, Color("554b3e"), true)
	var enabled_slots := ceili(float(enabled_count) * 3.0 / float(maxi(1, filters.size())))
	for slot in 3:
		var slot_color := Color("69c886") if slot < enabled_slots else Color("a55248")
		draw_rect(Rect2(marker.position + Vector2(2 + slot * 4, 2), Vector2(3, 3)), slot_color, true)

func _draw_storage_bay(rect: Rect2, color: Color) -> void:
	draw_rect(rect.grow(1), Color("2a211a"), true)
	draw_rect(rect, Color(color.r, color.g, color.b, 0.55), true)
	for x in range(int(rect.position.x + 2), int(rect.end.x - 1), 5):
		draw_rect(Rect2(Vector2(x, rect.position.y + 1), Vector2(2, rect.size.y - 2)), color.darkened(0.18), true)

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

func _draw_reliquary(rect: Rect2) -> void:
	_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 16)), Color("504658"))
	var shrine := Rect2(rect.get_center() + Vector2(-9, -2), Vector2(18, 27))
	draw_rect(shrine.grow(2), Color("29242d"), true)
	draw_rect(shrine, Color("6b6073"), true)
	draw_rect(shrine.grow(-4), Color("27242c"), true)
	draw_rect(Rect2(shrine.get_center() - Vector2(4, 9), Vector2(8, 18)), Color("9285a0"), true)
	for x in [rect.position.x + 10, rect.end.x - 11]:
		for y in [rect.position.y + 27, rect.end.y - 11]:
			_draw_bottle(Vector2(x, y), Color("8bcbd2") if y < rect.get_center().y else Color("a58bd0"))
	_draw_magic_circle(shrine.get_center(), Color("9e83c9"), 8)

func _draw_cullis_gate(rect: Rect2, building: Dictionary) -> void:
	var center := rect.get_center()
	var state := String(building.get("operation_state", "stable"))
	var definition := ContentRegistry.get_by_id(&"buildings", &"cullis_gate")
	var overload_threshold := maxf(1.0, float(definition.get("cullis", {}).get("overload_threshold", 480)))
	var heat := clampf(float(building.get("cullis_instability", 0)) / overload_threshold, 0.0, 1.0)
	var pulse := float(posmod(SimulationHost.tick + int(building.get("id", 0)) * 7, 18)) / 17.0
	var gate_rect := Rect2(center - Vector2(11, 17), Vector2(22, 34))
	draw_rect(gate_rect.grow(3), Color(0.08, 0.05, 0.10, 0.66), true)
	draw_rect(gate_rect, Color("55495f").lerp(Color("89485f"), heat * 0.65), true)
	draw_rect(gate_rect.grow(-5), Color("24162c").lerp(Color("5a1028"), heat * 0.72), true)
	for y in range(int(gate_rect.position.y + 4), int(gate_rect.end.y - 3), 6):
		draw_rect(Rect2(Vector2(gate_rect.position.x + 2, y), Vector2(gate_rect.size.x - 4, 2)), Color("816c91").lerp(Color("d05b83"), heat), true)
	for side_x in [gate_rect.position.x - 5, gate_rect.end.x + 1]:
		draw_rect(Rect2(Vector2(side_x, gate_rect.position.y + 2), Vector2(5, gate_rect.size.y - 4)), Color("77717a"), true)
		_draw_crystal(Vector2(side_x + 2, gate_rect.position.y + 1), Color("a37ad0").lerp(Color("ff6a9f"), heat), 6)
	var rift_color := Color("a178d2").lerp(Color("ff426f"), heat)
	_draw_magic_circle(center, rift_color, 11 + (1 if pulse > 0.65 and heat > 0.35 else 0))
	# Broken radial strokes create an animated top-down void while preserving the
	# footprint silhouette and advertise instability without a floating badge.
	draw_circle(center, 6.0 + heat * 2.0, Color(0.045, 0.01, 0.065, 0.94))
	for index in 6:
		var angle := TAU * float(index) / 6.0 + pulse * 0.18
		var inner := center + Vector2.from_angle(angle) * (3.0 + heat * 2.0)
		var outer := center + Vector2.from_angle(angle + 0.12) * (7.0 + heat * 4.0)
		draw_line(inner, outer, Color(rift_color.r, rift_color.g, rift_color.b, 0.58 + heat * 0.34), 1.0)
	if state in ["unstable", "critical"] and posmod(SimulationHost.tick + int(building.get("id", 0)), 8) < 3:
		draw_line(center + Vector2(-13, -14), center + Vector2(-5, -5), Color("fff2a0"), 2.0)
		draw_line(center + Vector2(13, -12), center + Vector2(5, -3), Color("bfeeff"), 1.0)

func _draw_conveyor(rect: Rect2, color: Color) -> void:
	draw_rect(rect.grow(1), Color("24211f"), true)
	draw_rect(rect, color.darkened(0.18), true)
	for x in range(int(rect.position.x + 2), int(rect.end.x - 1), 6):
		draw_rect(Rect2(Vector2(x, rect.position.y + 2), Vector2(3, rect.size.y - 4)), color.lightened(0.12), true)
	draw_circle(rect.position + Vector2(2, rect.size.y * 0.5), 3, Color("3a3734"))
	draw_circle(Vector2(rect.end.x - 2, rect.get_center().y), 3, Color("3a3734"))

func _draw_landfill(rect: Rect2) -> void:
	var stain := Color(0.24, 0.20, 0.17, 0.42)
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(6, 11), rect.position + Vector2(rect.size.x * 0.40, 5),
		rect.position + Vector2(rect.size.x - 8, 12), rect.end - Vector2(4, rect.size.y * 0.42),
		rect.end - Vector2(12, 7), rect.position + Vector2(rect.size.x * 0.44, rect.size.y - 3),
		rect.position + Vector2(5, rect.size.y - 12),
	]), stain)
	for x in range(int(rect.position.x + 4), int(rect.end.x - 3), 8):
		draw_rect(Rect2(Vector2(x, rect.position.y + 3), Vector2(5, 3)), Color("705238"), true)
	for offset in [Vector2(13, 18), Vector2(rect.size.x * 0.52, 13), Vector2(rect.size.x * 0.35, rect.size.y * 0.57), Vector2(rect.size.x * 0.72, rect.size.y * 0.64), Vector2(rect.size.x * 0.18, rect.size.y * 0.76)]:
		_draw_trash(rect.position + offset)
	_draw_cart(rect.position + Vector2(rect.size.x - 17, rect.size.y - 14), Color("72543b"))
	for index in 7:
		var point := rect.position + Vector2(8 + posmod(index * 19, maxi(2, int(rect.size.x - 16))), 10 + posmod(index * 31, maxi(2, int(rect.size.y - 20))))
		draw_rect(Rect2(point, Vector2(3 + index % 3, 2 + index % 2)), [Color("6e5b4d"), Color("4f665e"), Color("77645d")][index % 3], true)

func _draw_trash_processor(rect: Rect2) -> void:
	_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 16)), Color("474542"))
	_draw_conveyor(Rect2(rect.position + Vector2(5, 25), Vector2(rect.size.x - 24, 12)), Color("716961"))
	_draw_bin(rect.position + Vector2(rect.size.x - 11, 31), Color("625a55"))
	_draw_gear(rect.position + Vector2(rect.size.x * 0.50, rect.size.y - 12), Color("a09a90"))
	for point in [rect.position + Vector2(8, rect.size.y - 9), rect.position + Vector2(15, rect.size.y - 12)]:
		draw_rect(Rect2(point, Vector2(6, 6)), Color("776a64"), true)

func _draw_trash_burner(rect: Rect2) -> void:
	_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x * 0.47, 18)), Color("493b35"))
	_draw_conveyor(Rect2(rect.position + Vector2(5, 27), Vector2(rect.size.x * 0.45, 11)), Color("62574f"))
	var furnace_center := rect.position + Vector2(rect.size.x * 0.70, rect.size.y * 0.55)
	_draw_brick_furnace(furnace_center)
	draw_rect(Rect2(furnace_center + Vector2(4, -20), Vector2(7, 11)), Color("4f4b49"), true)
	draw_rect(Rect2(furnace_center + Vector2(5, -21), Vector2(5, 3)), Color("77736f"), true)
	_draw_bin(rect.position + Vector2(12, rect.size.y - 11), Color("5d5551"))

func _draw_combobulator(rect: Rect2, definition_id: String) -> void:
	var core: Color = {
		"wood_golem_combobulator": Color("9e6532"), "stone_golem_combobulator": Color("8d8a83"),
		"crystal_golem_combobulator": Color("56d2df"), "cube_e_golem_combobulator": Color("77645b"),
	}.get(definition_id, Color("8b7d6f"))
	var chamber := rect.get_center() + Vector2(0, 6)
	match definition_id:
		"wood_golem_combobulator":
			_draw_canvas_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 15)), Color("735235"), Color("50331f"))
			for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				var brace: Vector2 = chamber + Vector2(direction) * 14.0
				draw_rect(Rect2(brace - Vector2(3, 5), Vector2(6, 10)), Color("8d5b30"), true)
			_draw_logs(rect.position + Vector2(6, rect.size.y - 15), 3, Color("a66b35"))
		"stone_golem_combobulator":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 14)), Color("555553"))
			draw_circle(chamber, 17, Color("3b3b39"))
			draw_circle(chamber, 14, Color("8b8983"))
			for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				var block: Vector2 = chamber + Vector2(direction) * 14.0
				draw_rect(Rect2(block - Vector2(4, 4), Vector2(8, 8)), Color("a19e96"), true)
			_draw_rock_pile(rect.position + Vector2(11, rect.size.y - 11), Color("898781"))
		"crystal_golem_combobulator":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 14)), Color("354e53"))
			_draw_magic_circle(chamber, core, 16)
			for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				_draw_crystal(chamber + Vector2(direction) * 15.0, core.lightened(0.16), 6)
			draw_line(rect.position + Vector2(6, rect.size.y - 6), rect.position + Vector2(rect.size.x - 6, rect.size.y - 6), Color("55cdd6"), 2.0)
		"cube_e_golem_combobulator":
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 14)), Color("4c4642"))
			_draw_conveyor(Rect2(rect.position + Vector2(6, 24), Vector2(rect.size.x - 12, 12)), Color("6d625b"))
			for offset in [Vector2(10, rect.size.y - 12), Vector2(rect.size.x - 17, rect.size.y - 13), Vector2(rect.size.x * 0.5 - 3, rect.size.y - 17)]:
				draw_rect(Rect2(rect.position + offset, Vector2(7, 7)), Color("736762"), true)
				draw_rect(Rect2(rect.position + offset + Vector2(2, 2), Vector2(3, 3)), Color("94857e"), true)
		_:
			_draw_top_roof(Rect2(rect.position + Vector2(4, 4), Vector2(rect.size.x - 8, 14)), Color("4d4a46"))
	_draw_magic_circle(chamber, core, 11)
	draw_rect(Rect2(chamber - Vector2(5, 5), Vector2(10, 10)), core.darkened(0.28), true)
	draw_rect(Rect2(chamber - Vector2(3, 3), Vector2(6, 6)), core.lightened(0.20), true)

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

func _draw_god_structure(building: Dictionary, rect: Rect2) -> void:
	var role := String(building.get("god_role", "wall"))
	var center := rect.get_center()
	var phase := posmod(int(SimulationHost.tick / 2) + int(building.get("id", 0)), 16)
	var outer := Color("f4d96d")
	var inner := Color("9ceeff")
	var core := Color("fff8c9")
	if role == "wall":
		# The one-cell wall is an overhead sigil plate, not an upright facade:
		# bright cardinal braces surround a cool, passability-blocking core.
		draw_rect(Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 2)), Color(0.09, 0.16, 0.22, 0.90), true)
		draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size - Vector2(4, 4)), inner, true)
		draw_rect(Rect2(center - Vector2(1, 1), Vector2(3, 3)), core, true)
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			draw_line(center + direction * 2.0, center + direction * 3.5, outer, 1.0)
		if phase < 5:
			draw_rect(Rect2(center + Vector2(-1, -1), Vector2(2, 2)), Color("ffffff"), true)
		return
	var radius := minf(rect.size.x, rect.size.y) * 0.40
	var points := PackedVector2Array()
	for index in 8:
		var angle := TAU * float(index) / 8.0 + PI / 8.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(2, 2))
	draw_colored_polygon(shadow, Color(0.03, 0.06, 0.10, 0.74))
	draw_colored_polygon(points, Color("40587a"))
	var inner_points := PackedVector2Array()
	for point in points:
		inner_points.append(center + (point - center) * 0.72)
	draw_colored_polygon(inner_points, Color("203653"))
	# Four flush runic arms and a rotating central reticle communicate active
	# targeting while preserving a completely orthographic silhouette.
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_line(center + direction * 4.0, center + direction * (radius - 3.0), outer, 3.0)
		draw_rect(Rect2(center + direction * (radius - 2.0) - Vector2(2, 2), Vector2(4, 4)), inner, true)
	var reticle_angle := TAU * float(phase) / 16.0
	var reticle_direction := Vector2(cos(reticle_angle), sin(reticle_angle))
	draw_line(center - reticle_direction * 8.0, center + reticle_direction * 8.0, Color(outer.r, outer.g, outer.b, 0.86), 2.0)
	draw_circle(center, 6.0, inner)
	draw_circle(center, 3.0, core)
	if String(building.get("combat_state", "idle")) == "firing":
		draw_arc(center, radius + 3.0, 0.0, TAU, 20, Color(1.0, 0.94, 0.58, 0.84), 2.0)

func _draw_tower(building: Dictionary, rect: Rect2, complete: bool, progress: float) -> void:
	var tower_id := String(building.definition_id)
	var tier := int(building.get("tier", 1))
	var accent: Color = {
		"attract_tower": Color("ca6ee8"), "ballista_tower": Color("c9995a"), "ice_ballista_tower": Color("79ddea"), "banish_tower": Color("aa7df0"),
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
	_draw_open_yard(rect, Color("554f5b"), tier, tower_id)
	var physical_towers := ["ballista_tower", "ice_ballista_tower", "bow_tower", "bullet_tower", "sling_tower", "spray_tower"]
	if tower_id in physical_towers:
		var platform_color := Color("76543a") if tower_id in ["ballista_tower", "ice_ballista_tower", "bow_tower"] else Color("77736c")
		var platform := PackedVector2Array([
			center + Vector2(-15, -11), center + Vector2(-10, -16), center + Vector2(10, -16), center + Vector2(15, -11),
			center + Vector2(15, 11), center + Vector2(10, 16), center + Vector2(-10, 16), center + Vector2(-15, 11),
		])
		var platform_shadow := PackedVector2Array()
		for point in platform: platform_shadow.append(point + Vector2(2, 3))
		draw_colored_polygon(platform_shadow, Color("2a2523"))
		draw_colored_polygon(platform, platform_color.darkened(0.34))
		var inner_platform := PackedVector2Array()
		for point in platform: inner_platform.append(center + (point - center) * 0.78)
		draw_colored_polygon(inner_platform, platform_color)
		draw_rect(Rect2(center + Vector2(-2, -13), Vector2(4, 26)), platform_color.lightened(0.14), true)
		draw_rect(Rect2(center + Vector2(-13, -2), Vector2(26, 4)), platform_color.darkened(0.12), true)
	else:
		draw_circle(center + Vector2(0, 2), minf(rect.size.x, rect.size.y) * 0.40, Color("332e38"))
		draw_circle(center, minf(rect.size.x, rect.size.y) * 0.29, Color("5f5866") if tier >= 2 else Color("62566a"))
		draw_arc(center, minf(rect.size.x, rect.size.y) * 0.21, 0.0, TAU, 20, accent.darkened(0.35), 3.0)
	draw_circle(center, minf(rect.size.x, rect.size.y) * 0.10, accent.darkened(0.22))
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
		"ballista_tower", "ice_ballista_tower":
			draw_line(center - Vector2(13, 0), center + Vector2(15, 0), accent, 4.0)
			draw_line(center - Vector2(9, 8), center + Vector2(8, 8), accent.darkened(0.2), 3.0)
			if tower_id == "ice_ballista_tower":
				for crystal_offset in [Vector2(-10, -8), Vector2(10, -8), Vector2(0, 11)]:
					_draw_crystal(center + crystal_offset, Color("8cecf2"), 4)
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
	var road_id := String(building.definition_id)
	var material_color: Color = {
		"path": Color("75603d"), "log_road": Color("9a6532"), "cobble_log_road": Color("82796a"),
		"cobble_board_road": Color("9a856b"), "cut_stone_board_road": Color("b9ad9b"),
	}.get(road_id, Color("75654d"))
	var center := rect.get_center()
	if complete:
		var cell := Vector2i(int(building.x), int(building.y))
		var connections: Array[Vector2i] = []
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if _completed_segment_at(cell + direction, "roads"):
				connections.append(direction)
		var shadow := material_color.darkened(0.42)
		draw_rect(Rect2(center - Vector2(5, 5), Vector2(10, 10)), shadow, true)
		for direction in connections:
			draw_rect(_segment_arm_rect(rect, direction, 10), shadow, true)
		draw_rect(Rect2(center - Vector2(4, 4), Vector2(8, 8)), material_color, true)
		for direction in connections:
			draw_rect(_segment_arm_rect(rect, direction, 8), material_color, true)
		var horizontal := Vector2i.LEFT in connections or Vector2i.RIGHT in connections
		var vertical := Vector2i.UP in connections or Vector2i.DOWN in connections
		match road_id:
			"path":
				for offset in [Vector2(-2, -1), Vector2(1, 2), Vector2(2, -2)]:
					draw_rect(Rect2(center + offset, Vector2(2, 1)), material_color.darkened(0.22), true)
			"log_road":
				if horizontal:
					for x in range(int(rect.position.x), int(rect.end.x), 3): draw_rect(Rect2(Vector2(x, rect.position.y + 1), Vector2(2, 6)), material_color.lightened(0.10), true)
				if vertical:
					for y in range(int(rect.position.y), int(rect.end.y), 3): draw_rect(Rect2(Vector2(rect.position.x + 1, y), Vector2(6, 2)), material_color.lightened(0.10), true)
			"cobble_log_road":
				for offset in [Vector2(-3, -3), Vector2(0, -2), Vector2(-2, 1), Vector2(1, 2)]:
					draw_rect(Rect2(center + offset, Vector2(3, 3)), Color("a09a8e").darkened(float(int(offset.x + offset.y) & 1) * 0.10), true)
				draw_rect(Rect2(Vector2(rect.position.x, center.y - 3), Vector2(rect.size.x, 1)), Color("68452a"), true)
			"cobble_board_road":
				draw_rect(Rect2(center - Vector2(3, 1), Vector2(6, 2)), Color("b2814c"), true)
				for offset in [Vector2(-3, -3), Vector2(0, -3), Vector2(-3, 2), Vector2(0, 2)]:
					draw_rect(Rect2(center + offset, Vector2(3, 2)), Color("a8a094"), true)
			"cut_stone_board_road":
				for offset in [Vector2(-3, -3), Vector2(0, -3), Vector2(-3, 0), Vector2(0, 0)]:
					draw_rect(Rect2(center + offset, Vector2(3, 3)), Color("c6beb0").darkened(float(int(offset.x - offset.y) & 1) * 0.08), true)
				draw_rect(Rect2(Vector2(rect.position.x + 1, center.y - 1), Vector2(6, 1)), Color("83613f"), true)
	else:
		draw_rect(Rect2(rect.position + Vector2(1, 3), Vector2(6, 1)), Color("c5ab70"), true)
		var laid_width := maxi(1, int(6.0 * progress))
		draw_rect(Rect2(rect.position + Vector2(1, 4), Vector2(laid_width, 3)), material_color, true)

func _draw_wall(building: Dictionary, rect: Rect2, complete: bool, progress: float) -> void:
	var wall_id := String(building.definition_id)
	var wall_color: Color = {
		"wood_wall": Color("84532d"), "wood_gate": Color("9b673d"),
		"stone_wall": Color("8d8a83"), "stone_gate": Color("a09d95"), "curtain_wall": Color("b7afa2"),
		"crylithium_wall": Color("47beca"), "crylithium_curtain_wall": Color("65dbe0"), "trashy_cube_wall": Color("5b5057"),
	}.get(wall_id, Color("81766b"))
	if not complete:
		wall_color = wall_color.darkened(0.45)
	var is_gate := wall_id.ends_with("gate")
	if is_gate:
		if complete:
			draw_rect(rect.grow(1), Color("27201b"), true)
			draw_rect(Rect2(rect.position + Vector2(0, 1), Vector2(3, 6)), wall_color.darkened(0.22), true)
			draw_rect(Rect2(rect.position + Vector2(5, 1), Vector2(3, 6)), wall_color.darkened(0.22), true)
			draw_rect(Rect2(rect.position + Vector2(2, 1), Vector2(2, 6)), wall_color, true)
			draw_rect(Rect2(rect.position + Vector2(4, 1), Vector2(2, 6)), wall_color.lightened(0.12), true)
			draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(2, 2)), Color("d2b45c"), true)
		else:
			draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(2, 6)), Color("8a5c35"), true)
			draw_rect(Rect2(rect.end - Vector2(4, 6), Vector2(2, 6)), Color("8a5c35"), true)
			draw_line(rect.position + Vector2(3, 3), rect.end - Vector2(3, 4), Color("c5ab70"), 1.0)
	else:
		var center := rect.get_center()
		if complete:
			var cell := Vector2i(int(building.x), int(building.y))
			var connections: Array[Vector2i] = []
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if _completed_segment_at(cell + direction, "walls"):
					connections.append(direction)
			var thickness := 10 if wall_id in ["curtain_wall", "crylithium_curtain_wall"] else 8
			var outline := Color("292724") if wall_id != "trashy_cube_wall" else Color("292329")
			draw_rect(Rect2(center - Vector2(thickness * 0.5, thickness * 0.5), Vector2(thickness, thickness)), outline, true)
			for direction in connections: draw_rect(_segment_arm_rect(rect, direction, thickness), outline, true)
			var inner_width := maxi(3, thickness - 2)
			draw_rect(Rect2(center - Vector2(inner_width * 0.5, inner_width * 0.5), Vector2(inner_width, inner_width)), wall_color, true)
			for direction in connections: draw_rect(_segment_arm_rect(rect, direction, inner_width), wall_color, true)
			match wall_id:
				"wood_wall":
					draw_rect(Rect2(center - Vector2(1, 3), Vector2(2, 6)), wall_color.lightened(0.18), true)
					draw_rect(Rect2(center - Vector2(3, 1), Vector2(6, 2)), wall_color.darkened(0.16), true)
				"stone_wall", "curtain_wall":
					for offset in [Vector2(-2, -2), Vector2(1, -2), Vector2(-1, 1)]: draw_rect(Rect2(center + offset, Vector2(2, 2)), wall_color.lightened(0.12), true)
					if wall_id == "curtain_wall":
						for offset in [Vector2(-4, -4), Vector2(2, -4), Vector2(-4, 2), Vector2(2, 2)]: draw_rect(Rect2(center + offset, Vector2(3, 3)), Color("d0c8bb"), true)
				"crylithium_wall", "crylithium_curtain_wall":
					draw_rect(Rect2(center - Vector2(1, 4), Vector2(2, 8)), Color("9af1ec"), true)
					if wall_id == "crylithium_curtain_wall": _draw_crystal(center, Color("a7f5ef"), 4)
				"trashy_cube_wall":
					for offset in [Vector2(-3, -3), Vector2(0, -3), Vector2(-3, 0), Vector2(0, 0)]:
						draw_rect(Rect2(center + offset, Vector2(3, 3)), [Color("6c5e61"), Color("594e55"), Color("756562")][posmod(int(offset.x + offset.y), 3)], true)
		else:
			draw_rect(Rect2(center - Vector2(1, 3), Vector2(2, 6)), Color("8a5c35"), true)
			draw_rect(Rect2(center + Vector2(-3, -1), Vector2(6, 1)), Color("c5ab70"), true)
	if not complete:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * progress, 2)), Color("f4c95d"), true)

func _segment_arm_rect(rect: Rect2, direction: Vector2i, width: int) -> Rect2:
	var center := rect.get_center()
	var half := float(width) * 0.5
	if direction == Vector2i.LEFT:
		return Rect2(Vector2(rect.position.x, center.y - half), Vector2(center.x - rect.position.x, width))
	if direction == Vector2i.RIGHT:
		return Rect2(Vector2(center.x, center.y - half), Vector2(rect.end.x - center.x, width))
	if direction == Vector2i.UP:
		return Rect2(Vector2(center.x - half, rect.position.y), Vector2(width, center.y - rect.position.y))
	return Rect2(Vector2(center.x - half, center.y), Vector2(width, rect.end.y - center.y))

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
	var species := String(villager.get("species", "villager"))
	if species == "catjeet":
		color = Color("b97843")
	elif species == "nephilim":
		color = Color("d4d7e8")
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
	var moving := state in ["walking", "traveling", "working", "repairing", "dismantling", "fighting", "treating_patient", "intercepting", "seeking_water", "carrying_dirty_water", "supplying_fountain", "delivering_water"]
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
	if species == "catjeet":
		var ear_color := Color("8f512f")
		draw_colored_polygon(PackedVector2Array([head_center - side * 2.0 - forward * 1.0, head_center - side * 4.0 - forward * 3.0, head_center - side * 1.0 - forward * 3.0]), ear_color)
		draw_colored_polygon(PackedVector2Array([head_center + side * 2.0 - forward * 1.0, head_center + side * 4.0 - forward * 3.0, head_center + side * 1.0 - forward * 3.0]), ear_color)
		draw_line(back - side * 2.0, back - side * 6.0 - forward * 3.0, Color("a56639"), 2.0)
	elif species == "nephilim":
		var wing_color := Color(0.67, 0.86, 0.95, 0.82)
		draw_colored_polygon(PackedVector2Array([center - side * 2.0, center - side * 8.0 - forward * 4.0, center - side * 7.0 + forward * 3.0]), wing_color)
		draw_colored_polygon(PackedVector2Array([center + side * 2.0, center + side * 8.0 - forward * 4.0, center + side * 7.0 + forward * 3.0]), wing_color)
		draw_arc(head_center - forward * 3.0, 3.0, 0.0, TAU, 8, Color("ffe98f"), 1.0)
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
	var carried_water: Dictionary = villager.get("carrying_water", {})
	if int(carried_water.get("amount", 0)) > 0:
		var bucket_center := center - side * 6.0 + forward * 1.5
		draw_rect(Rect2(bucket_center - Vector2(3, 2), Vector2(6, 5)), Color("5c4935"), true)
		draw_rect(Rect2(bucket_center - Vector2(2, 1), Vector2(4, 3)), Color("4f9fb5") if String(carried_water.get("resource_id", "")) == "clean_water" else Color("557f78"), true)
		draw_arc(bucket_center - Vector2(0, 2), 3.0, PI, TAU, 6, Color("a98a5a"), 1.0)
	var status_effects: Dictionary = villager.get("status_effects", {})
	if int(status_effects.get("infection", 0)) > 0:
		draw_circle(center + Vector2(0, -13), 2.0, Color("91bd4b"))
	if int(villager.get("divine_reaction_until_tick", 0)) > SimulationHost.tick:
		var reaction_center := center + Vector2(0, -14)
		draw_line(reaction_center + Vector2(-3, 0), reaction_center + Vector2(3, 0), Color("f4dd68"), 1.0)
		draw_line(reaction_center + Vector2(0, -3), reaction_center + Vector2(0, 3), Color("f4dd68"), 1.0)
		draw_rect(Rect2(reaction_center - Vector2.ONE, Vector2(2, 2)), Color("fff2a1"), true)
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
	if int(monster.get("charmed_ticks", 0)) > 0:
		draw_arc(center, 9.0, 0.0, TAU, 12, Color(0.96, 0.72, 0.92, 0.88), 1.0)
		draw_rect(Rect2(center + Vector2(-1, -16), Vector2(3, 3)), Color("ff9be3"), true)
	elif int(monster.get("cold_ticks", 0)) > 0:
		draw_arc(center, 8.0, 0.0, TAU, 12, Color(0.48, 0.88, 1.0, 0.82), 1.0)
		draw_line(center + Vector2(-4, 8), center + Vector2(4, 8), Color("8eeeff"), 1.0)

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
	var animal_ghost := String(ghost.get("source_kind", "villager")) == "animal"
	draw_rect(Rect2(center + Vector2(-5, -7), Vector2(10, 11)), Color(color.r, color.g, color.b, 0.16), true)
	draw_rect(Rect2(center + Vector2(-3, -6), Vector2(6, 7)), color, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-3, 1), center + Vector2(-2, 7), center + Vector2(0, 4), center + Vector2(3, 8), center + Vector2(3, 1)]), color)
	if animal_ghost:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-3, -5), center + Vector2(-6, -10), center + Vector2(-1, -8)]), color)
		draw_colored_polygon(PackedVector2Array([center + Vector2(3, -5), center + Vector2(6, -10), center + Vector2(1, -8)]), color)
		draw_rect(Rect2(center + Vector2(-2, -4), Vector2(1, 1)), Color("18334a"), true)
		draw_rect(Rect2(center + Vector2(2, -4), Vector2(1, 1)), Color("18334a"), true)

func _draw_corruption(cells: Array, occupied: Dictionary = {}) -> void:
	if occupied.is_empty():
		for position_data in cells:
			occupied["%d:%d" % [int(position_data[0]), int(position_data[1])]] = _corruption_strength(position_data)
	# Corruption is a living connected ground material, not one opaque square per
	# simulation cell. Two non-overlapping masks create a dark under-root and an
	# irregular translucent bloom without repeatedly alpha-stacking neighboring
	# circles into a flat opaque slab.
	for position_data in cells:
		var cell := Vector2i(int(position_data[0]), int(position_data[1]))
		_draw_corruption_fringe(cell, occupied, _corruption_strength(position_data))
	for position_data in cells:
		var cell := Vector2i(int(position_data[0]), int(position_data[1]))
		var strength := _corruption_strength(position_data)
		_draw_corruption_mask_cell(cell, occupied, 1, Color(0.095, 0.008, 0.075, 0.16 + strength * 0.18))
	for position_data in cells:
		var cell := Vector2i(int(position_data[0]), int(position_data[1]))
		var strength := _corruption_strength(position_data)
		var center := (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_PIXELS
		var pulse := 0.020 * strength * sin(float(cell.x * 5 + cell.y * 3 + SimulationHost.tick) * 0.055)
		var bloom := Color(0.20 + strength * 0.085 + pulse, 0.018, 0.16 + strength * 0.065 + pulse, 0.26 + strength * 0.32)
		_draw_corruption_mask_cell(cell, occupied, 2, bloom)
		var terrain_seed := current_blueprint.seed if current_blueprint != null else 0
		var cell_hash := posmod(cell.x * cell.x * 1741 + cell.y * cell.y * 3253 + cell.x * cell.y * 953 + terrain_seed * 71, 104729)
		if cell_hash % 17 == 0:
			var vein := Color(0.58, 0.09, 0.45, 0.28 + strength * 0.30)
			var turn := Vector2(2, -1) if cell_hash % 2 == 0 else Vector2(-2, 1)
			draw_line(center - turn, center + turn, vein, 1.0)
		elif cell_hash % 29 == 0:
			draw_rect(Rect2(center + Vector2(-2, -1), Vector2(3, 2)), Color(0.15, 0.01, 0.12, 0.42), true)
		if cell_hash % 53 == 0:
			draw_circle(center + Vector2(1, -2), 1.0, Color(0.78, 0.23, 0.61, 0.58))
		# Old, strong corruption forms local scars and dead growth clusters. They
		# break the large-area tint into readable ecological landmarks while leaving
		# young frontier cells comparatively transparent.
		var scar_block := Vector2i(floori(float(cell.x) / 17.0), floori(float(cell.y) / 13.0))
		var scar_hash := posmod(scar_block.x * scar_block.x * 2903 + scar_block.y * scar_block.y * 4513 + scar_block.x * scar_block.y * 1877 + terrain_seed * 89, 104729)
		var scar_anchor := Vector2i(scar_block.x * 17 + 2 + posmod(scar_hash, 13), scar_block.y * 13 + 2 + posmod(scar_hash / 17, 9))
		if strength > 0.58 and cell == scar_anchor and scar_hash % 4 != 0:
			var scar_side := -1.0 if scar_hash % 2 == 0 else 1.0
			var scar_lift := float(posmod(scar_hash / 11, 4) - 2)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-10 * scar_side, 2 + scar_lift), center + Vector2(-6 * scar_side, -4), center + Vector2(1 * scar_side, -6 - scar_lift),
				center + Vector2(10 * scar_side, -2), center + Vector2(8 * scar_side, 5 + scar_lift), center + Vector2(1, 7), center + Vector2(-6 * scar_side, 6),
			]), Color(0.10, 0.040, 0.085, 0.27 + strength * 0.12))
			draw_line(center + Vector2(-8 * scar_side, 1), center + Vector2(7 * scar_side, -3 - scar_lift), Color(0.42, 0.12, 0.32, 0.44), 1.0)
			draw_line(center + Vector2(-3 * scar_side, 5), center + Vector2(3 * scar_side, -5), Color(0.22, 0.065, 0.18, 0.58), 1.0)
		var dead_block := Vector2i(floori(float(cell.x) / 29.0), floori(float(cell.y) / 23.0))
		var dead_hash := posmod(dead_block.x * 4363 + dead_block.y * dead_block.y * 6353 + dead_block.x * dead_block.y * 2371 + terrain_seed * 101, 104729)
		var dead_anchor := Vector2i(dead_block.x * 29 + 4 + posmod(dead_hash, 21), dead_block.y * 23 + 4 + posmod(dead_hash / 19, 15))
		if strength > 0.72 and cell == dead_anchor and dead_hash % 3 != 0:
			var dead_wood := Color(0.22, 0.13, 0.18, 0.86)
			draw_line(center + Vector2(0, 5), center + Vector2(0, -7), dead_wood, 2.0)
			draw_line(center + Vector2(0, -3), center + Vector2(-5, -6), dead_wood, 1.0)
			draw_line(center + Vector2(0, -1), center + Vector2(5, -4), dead_wood, 1.0)
		# Sparse exposed rim pixels make the outer silhouette legible without
		# reconstructing a square outline around every logical cell.
		var rim := Color(0.58, 0.15, 0.47, 0.20 + strength * 0.26)
		if not _corruption_has(occupied, cell + Vector2i.UP) and cell_hash % 3 != 0:
			draw_line(center + Vector2(-2, -5), center + Vector2(2, -5), rim, 1.0)
		if not _corruption_has(occupied, cell + Vector2i.LEFT) and cell_hash % 4 == 0:
			draw_line(center + Vector2(-5, -2), center + Vector2(-5, 2), rim.darkened(0.12), 1.0)

func _corruption_has(occupied: Dictionary, cell: Vector2i) -> bool:
	return occupied.has("%d:%d" % [cell.x, cell.y])

func _corruption_strength(position_data: Variant) -> float:
	if position_data is Array and position_data.size() > 2:
		return clampf(float(position_data[2]), 0.0, 1.0)
	return 1.0

func _draw_corruption_fringe(cell: Vector2i, occupied: Dictionary, strength: float = 1.0) -> void:
	var center := (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_PIXELS
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for direction_i in directions:
		if _corruption_has(occupied, cell + direction_i):
			continue
		var direction := Vector2(direction_i)
		var tangent := Vector2(-direction.y, direction.x)
		var fringe_hash := posmod(cell.x * 73856093 + cell.y * 19349663 + direction_i.x * 83492791 + direction_i.y * 2971215073, 104729)
		var edge := center + direction * (TILE_PIXELS * 0.5 - 0.5)
		var reach := float(5 + fringe_hash % 5)
		var half_width := float(3 + (fringe_hash / 7) % 3)
		var skew := float((fringe_hash / 13) % 3 - 1)
		# A broad, faint stain softens the simulation-cell boundary. A narrower
		# root then carries the material farther into healthy terrain, keeping the
		# edge organic while remaining crisp at the native pixel scale.
		draw_circle(edge + direction * 2.0, 6.0 + float(fringe_hash % 3), Color(0.22, 0.015, 0.17, 0.035 + strength * 0.04))
		draw_colored_polygon(PackedVector2Array([
			edge - tangent * half_width - direction,
			edge + tangent * half_width - direction,
			edge + direction * reach + tangent * (2.0 + skew),
			edge + direction * (reach + 2.0) - tangent * 2.0,
		]), Color(0.24, 0.018, 0.19, 0.06 + strength * 0.08))
		if fringe_hash % 2 == 0:
			draw_line(edge + tangent * skew, edge + direction * (reach + 4.0) + tangent * skew, Color(0.48, 0.06, 0.37, 0.10 + strength * 0.15), 1.0)
		if fringe_hash % 4 == 0:
			draw_line(edge - tangent * 2.0, edge + direction * (reach * 0.72) - tangent * 3.0, Color(0.19, 0.012, 0.15, 0.28), 1.0)
		if fringe_hash % 7 == 0:
			draw_rect(Rect2(edge + direction * (reach + 4.0) - Vector2(1, 1), Vector2(2, 2)), Color(0.70, 0.16, 0.52, 0.38), true)

func _draw_corruption_mask_cell(cell: Vector2i, occupied: Dictionary, inset: int, color: Color) -> void:
	var origin := Vector2(cell) * TILE_PIXELS
	var inner := int(TILE_PIXELS) - inset * 2
	var up := _corruption_has(occupied, cell + Vector2i.UP)
	var right := _corruption_has(occupied, cell + Vector2i.RIGHT)
	var down := _corruption_has(occupied, cell + Vector2i.DOWN)
	var left := _corruption_has(occupied, cell + Vector2i.LEFT)
	draw_rect(Rect2(origin + Vector2(inset, inset), Vector2(inner, inner)), color, true)
	if up: draw_rect(Rect2(origin + Vector2(inset, 0), Vector2(inner, inset)), color, true)
	if right: draw_rect(Rect2(origin + Vector2(int(TILE_PIXELS) - inset, inset), Vector2(inset, inner)), color, true)
	if down: draw_rect(Rect2(origin + Vector2(inset, int(TILE_PIXELS) - inset), Vector2(inner, inset)), color, true)
	if left: draw_rect(Rect2(origin + Vector2(0, inset), Vector2(inset, inner)), color, true)
	if _corruption_has(occupied, cell + Vector2i(-1, -1)) or (up and left):
		draw_rect(Rect2(origin, Vector2(inset, inset)), color, true)
	if _corruption_has(occupied, cell + Vector2i(1, -1)) or (up and right):
		draw_rect(Rect2(origin + Vector2(int(TILE_PIXELS) - inset, 0), Vector2(inset, inset)), color, true)
	if _corruption_has(occupied, cell + Vector2i(1, 1)) or (down and right):
		draw_rect(Rect2(origin + Vector2(int(TILE_PIXELS) - inset, int(TILE_PIXELS) - inset), Vector2(inset, inset)), color, true)
	if _corruption_has(occupied, cell + Vector2i(-1, 1)) or (down and left):
		draw_rect(Rect2(origin + Vector2(0, int(TILE_PIXELS) - inset), Vector2(inset, inset)), color, true)

func _draw_selected_settlement_range() -> void:
	if latest_snapshot == null or selected_kind != &"building" or selected_entity_id <= 0:
		return
	for building in latest_snapshot.buildings:
		if int(building.id) != selected_entity_id:
			continue
		var range := SimulationHost.get_building_settlement_range(building)
		if range <= 0:
			return
		var center := Vector2(float(building.x) + float(building.width) * 0.5, float(building.y) + float(building.height) * 0.5) * TILE_PIXELS
		var radius := float(range) * TILE_PIXELS
		draw_circle(center, radius, Color(0.18, 0.88, 0.58, 0.055))
		draw_arc(center, radius, 0.0, TAU, maxi(32, range * 2), Color(0.38, 1.0, 0.72, 0.58), 2.0)
		return

func _draw_weather(snapshot: SimulationSnapshot) -> void:
	if snapshot.weather not in [&"rain", &"snow"] and snapshot.active_event not in [&"hail", &"meteor_shower", &"lightning_storm"]:
		return
	var visible_size := get_viewport_rect().size / camera.zoom
	var visible_rect := Rect2(camera.position - visible_size * 0.5, visible_size)
	var reduced_motion := bool(SettingsService.values.get("reduce_motion", false))
	var weather_sample_count := 90 if reduced_motion else 360
	var motion_tick := 0 if reduced_motion else snapshot.tick
	for index in weather_sample_count:
		var seed := index * 7919 + motion_tick * (3 if snapshot.weather == &"rain" else 1)
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
			if index < (2 if reduced_motion else 8) and (reduced_motion or snapshot.tick % 18 < 3):
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
	if night_strength <= 0.01 or current_blueprint == null:
		return
	var world_rect := Rect2(Vector2.ZERO, Vector2(current_blueprint.width, current_blueprint.height) * TILE_PIXELS)
	draw_rect(world_rect, Color(0.02, 0.04, 0.13, night_strength), true)
	if latest_snapshot == null:
		return
	var visible_cells := _visible_cell_rect(6.0)
	var flicker := sin(float(latest_snapshot.tick) * 0.15) * 0.08
	for building in latest_snapshot.buildings:
		if not bool(building.get("completed", true)) or bool(building.get("destroyed", false)):
			continue
		var bx := float(building.get("x", 0))
		var by := float(building.get("y", 0))
		var bw := float(building.get("width", 1))
		var bh := float(building.get("height", 1))
		if not visible_cells.intersects(Rect2(bx, by, bw, bh)):
			continue
		var center := Vector2(bx + bw * 0.5, by + bh * 0.5) * TILE_PIXELS
		var def_id := String(building.get("definition_id", ""))
		match def_id:
			"fire_pit":
				var radius := 36.0 + flicker * 4.0
				draw_circle(center, radius, Color(0.95, 0.55, 0.18, 0.12 * night_strength))
				draw_circle(center, radius * 0.6, Color(1.0, 0.75, 0.28, 0.20 * night_strength))
				draw_circle(center, radius * 0.28, Color(1.0, 0.92, 0.65, 0.32 * night_strength))
			"crylithium_fire_pit":
				var radius := 48.0 + flicker * 3.0
				draw_circle(center, radius, Color(0.20, 0.75, 0.95, 0.14 * night_strength))
				draw_circle(center, radius * 0.6, Color(0.45, 0.90, 1.0, 0.22 * night_strength))
				draw_circle(center, radius * 0.3, Color(0.80, 0.98, 1.0, 0.35 * night_strength))
			"crystal_motivator":
				var radius := 40.0 + sin(float(latest_snapshot.tick) * 0.08) * 4.0
				draw_circle(center, radius, Color(0.30, 0.85, 0.82, 0.10 * night_strength))
				draw_circle(center, radius * 0.5, Color(0.55, 0.95, 0.92, 0.18 * night_strength))
			"camp", "village", "town", "castle", "large_castle":
				var radius := 44.0 + flicker * 2.0
				draw_circle(center, radius, Color(0.92, 0.68, 0.24, 0.10 * night_strength))
				draw_circle(center, radius * 0.55, Color(1.0, 0.82, 0.40, 0.18 * night_strength))
			"forge", "crystillery":
				var radius := 32.0 + flicker * 3.0
				draw_circle(center, radius, Color(0.95, 0.48, 0.15, 0.11 * night_strength))
				draw_circle(center, radius * 0.5, Color(1.0, 0.72, 0.30, 0.18 * night_strength))
			"reliquary":
				var radius := 36.0 + sin(float(latest_snapshot.tick) * 0.1) * 3.0
				draw_circle(center, radius, Color(0.68, 0.45, 0.95, 0.12 * night_strength))
				draw_circle(center, radius * 0.5, Color(0.85, 0.65, 1.0, 0.20 * night_strength))
			"cullis_gate":
				var radius := 40.0 + sin(float(latest_snapshot.tick) * 0.2) * 5.0
				draw_circle(center, radius, Color(0.35, 0.60, 0.98, 0.13 * night_strength))
				draw_circle(center, radius * 0.5, Color(0.60, 0.82, 1.0, 0.22 * night_strength))
			"god_tower":
				var radius := 42.0 + sin(float(latest_snapshot.tick) * 0.12) * 3.0
				draw_circle(center, radius, Color(0.95, 0.90, 0.45, 0.12 * night_strength))
				draw_circle(center, radius * 0.5, Color(1.0, 0.96, 0.70, 0.22 * night_strength))

func _draw_placement_ghost() -> void:
	var definition := ContentRegistry.get_by_id(&"buildings", pending_building_id)
	var footprint_data: Array = definition.get("footprint", [1, 1])
	var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
	var valid := _is_valid_placement(pointer_cell, footprint)
	var color := Color(0.18, 1.0, 0.62, 0.42) if valid else Color(1.0, 0.18, 0.18, 0.48)
	var rect := Rect2(Vector2(pointer_cell) * TILE_PIXELS, Vector2(footprint) * TILE_PIXELS)
	var preview_range := SimulationHost.get_building_settlement_range({"definition_id": String(pending_building_id), "tier": 1, "completed": true, "destroyed": false})
	if preview_range > 0:
		var preview_center := rect.get_center()
		draw_circle(preview_center, float(preview_range) * TILE_PIXELS, Color(0.18, 0.88, 0.58, 0.045))
		draw_arc(preview_center, float(preview_range) * TILE_PIXELS, 0.0, TAU, maxi(32, preview_range * 2), Color(0.45, 1.0, 0.74, 0.48), 2.0)
	draw_rect(rect, color, true)
	draw_rect(rect, color.lightened(0.3), false, 3.0)

func _draw_spell_target() -> void:
	# The held payload already owns a high-contrast grip ring. Drawing the normal
	# Hand target glyph over it hid small creatures at native scale.
	if pending_spell_id == &"grab" and latest_snapshot != null and not latest_snapshot.held_entity.is_empty():
		return
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
		var age := 0 if bool(SettingsService.values.get("reduce_motion", false)) else current_tick - int(effect.started_tick)
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
