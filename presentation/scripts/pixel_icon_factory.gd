class_name PixelIconFactory
extends RefCounted

## Native-resolution UI sprites that share the world's sparse two-to-four-tone
## pixel language. They are drawn at their final size and never antialiased.

const INK := Color("172126")
const PAPER := Color("d8c79a")
const WOOD := Color("81502f")
const WOOD_LIGHT := Color("bd7a43")
const STONE := Color("879198")
const STONE_LIGHT := Color("c1c7c5")
const GREEN := Color("70b85d")
const GREEN_LIGHT := Color("a7dc72")
const WATER := Color("3e9ec1")
const FIRE := Color("e15a2f")
const GOLD := Color("e1c45a")
const CRYSTAL := Color("66d3d1")
const MAGIC := Color("9d7ddd")
const HOLY := Color("f0e59b")
const DANGER := Color("c94b4b")

var _cache: Dictionary = {}

func building(building_id: StringName, category: StringName, size := 24) -> Texture2D:
	return _make(&"building", building_id, category, size)

func spell(spell_id: StringName, group: StringName, size := 24) -> Texture2D:
	return _make(&"spell", spell_id, group, size)

func resource(resource_id: StringName, size := 20) -> Texture2D:
	return _make(&"resource", resource_id, &"", size)

func event(event_id: StringName, size := 24) -> Texture2D:
	return _make(&"event", event_id, &"", size)

func ui(ui_id: StringName, size := 24) -> Texture2D:
	return _make(&"ui", ui_id, &"", size)

func job(job_id: StringName, color: Color, size := 24) -> Texture2D:
	var key := "job:%s:%s:%d" % [job_id, color.to_html(), size]
	if _cache.has(key): return _cache[key]
	var image := _new_image(size)
	_draw_job(image, String(job_id), color)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

func _make(kind: StringName, content_id: StringName, family: StringName, size: int) -> Texture2D:
	var key := "%s:%s:%s:%d" % [kind, content_id, family, size]
	if _cache.has(key): return _cache[key]
	var image := _new_image(size)
	match kind:
		&"building": _draw_building(image, String(content_id), String(family))
		&"spell": _draw_spell(image, String(content_id), String(family))
		&"resource": _draw_resource(image, String(content_id))
		&"event": _draw_event(image, String(content_id))
		&"ui": _draw_ui(image, String(content_id))
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

func _new_image(size: int) -> Image:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return image

func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	image.fill_rect(Rect2i(x, y, w, h), color)

func _pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)

func _yard(image: Image) -> void:
	# Broken rope and four stakes leave the interior transparent.
	for point in [Vector2i(3, 3), Vector2i(19, 3), Vector2i(3, 18), Vector2i(19, 18)]:
		_rect(image, point.x, point.y, 2, 4, WOOD_LIGHT)
	_rect(image, 6, 4, 5, 1, PAPER); _rect(image, 13, 4, 5, 1, PAPER)
	_rect(image, 6, 20, 4, 1, PAPER); _rect(image, 14, 20, 4, 1, PAPER)

func _roof(image: Image, color := WOOD) -> void:
	_rect(image, 6, 7, 12, 10, INK)
	_rect(image, 7, 6, 10, 10, color)
	_rect(image, 9, 6, 2, 10, color.lightened(0.18))
	_rect(image, 7, 16, 4, 2, INK)

func _draw_building(image: Image, building_id: String, category: String) -> void:
	_yard(image)
	if building_id.contains("road") or category == "roads":
		var road_color := PAPER if building_id == "path" else (WOOD_LIGHT if building_id == "log_road" else STONE_LIGHT)
		_rect(image, 0, 8, 24, 8, WOOD.darkened(0.25))
		_rect(image, 0, 10, 24, 3, road_color)
		for x in range(2, 24, 6): _rect(image, x, 10, 2, 3, STONE if building_id != "log_road" else WOOD)
		return
	if building_id.contains("wall") or building_id.contains("gate") or category == "walls":
		var wall_color := CRYSTAL if building_id.contains("crylithium") else (Color("6f755b") if building_id.contains("trashy") else (WOOD_LIGHT if building_id.contains("wood") else STONE))
		_rect(image, 1, 9, 22, 7, INK)
		for x in range(2, 22, 5): _rect(image, x, 8, 4, 7, wall_color)
		if building_id.contains("gate"): _rect(image, 10, 10, 4, 6, WOOD)
		return
	if building_id.contains("tower") or category == "towers":
		_rect(image, 7, 7, 10, 10, INK); _rect(image, 8, 8, 8, 8, STONE)
		_draw_building_emblem(image, building_id)
		return
	if category == "town_center":
		_rect(image, 5, 9, 14, 9, INK); _rect(image, 6, 8, 12, 9, Color("915b48"))
		_rect(image, 8, 8, 2, 9, Color("c58a62")); _rect(image, 17, 4, 2, 11, WOOD)
		_rect(image, 19, 4, 3, 2, GOLD)
		return
	if category == "housing":
		_roof(image, Color("6f4631")); _rect(image, 15, 4, 2, 5, STONE)
		return
	match category:
		"civics":
			_roof(image); _rect(image, 10, 9, 5, 4, PAPER)
			_rect(image, 12, 7, 1, 8, DANGER if building_id == "clinic" else GOLD)
		"harvesting":
			_rect(image, 6, 14, 12, 3, WOOD)
			if building_id.contains("crystal"): _rect(image, 10, 7, 4, 8, CRYSTAL)
			else:
				_rect(image, 7, 8, 3, 7, WOOD_LIGHT); _rect(image, 13, 6, 2, 9, STONE_LIGHT)
		"food_water":
			if building_id.contains("well") or building_id.contains("water") or building_id.contains("fountain") or building_id.contains("catcher"):
				_rect(image, 6, 8, 12, 10, INK); _rect(image, 8, 10, 8, 6, WATER)
			else:
				for x in [7, 11, 15]: _rect(image, x, 8, 2, 9, GREEN)
				_rect(image, 6, 13, 12, 2, WOOD)
		"refining", "manufacturing":
			_rect(image, 6, 14, 12, 3, WOOD); _rect(image, 8, 8, 8, 6, STONE)
			_rect(image, 10, 6, 3, 5, FIRE if building_id == "forge" else WOOD_LIGHT)
			_rect(image, 15, 5, 2, 9, CRYSTAL if building_id == "crystillery" else INK)
		"storage":
			_rect(image, 6, 10, 5, 7, INK); _rect(image, 7, 9, 4, 7, WOOD_LIGHT)
			_rect(image, 13, 8, 5, 9, INK); _rect(image, 14, 7, 4, 9, WOOD)
		"magic":
			_rect(image, 7, 14, 10, 3, STONE); _rect(image, 10, 8, 4, 7, MAGIC)
			_rect(image, 11, 5, 2, 4, HOLY)
		"lighting":
			_rect(image, 8, 14, 8, 3, STONE); _rect(image, 10, 9, 4, 6, FIRE)
			_rect(image, 11, 6, 2, 5, GOLD)
		"golems":
			_rect(image, 6, 14, 12, 3, STONE); _rect(image, 8, 8, 8, 7, INK)
			_rect(image, 10, 9, 4, 4, CRYSTAL); _rect(image, 4, 10, 5, 2, WOOD_LIGHT)
		"trash":
			_rect(image, 6, 9, 12, 9, INK); _rect(image, 7, 10, 10, 7, Color("5e6d4d"))
			_rect(image, 9, 7, 6, 3, STONE)
		_:
			_roof(image)
	_draw_building_emblem(image, building_id)

func _draw_building_emblem(image: Image, building_id: String) -> void:
	# A content-specific 1x motif makes siblings recognizable without adding noise.
	match building_id:
		"ancillary":
			_rect(image, 4, 9, 5, 5, GOLD); _rect(image, 16, 10, 4, 4, GOLD)
		"clinic":
			_rect(image, 10, 5, 4, 14, HOLY); _rect(image, 5, 10, 14, 4, HOLY); _rect(image, 11, 6, 2, 12, DANGER)
		"courier_station":
			_rect(image, 7, 8, 9, 8, PAPER); _rect(image, 16, 10, 5, 2, GOLD); _rect(image, 19, 8, 2, 6, GOLD)
		"maintenance_building":
			_rect(image, 5, 6, 4, 9, STONE_LIGHT); _rect(image, 8, 13, 11, 3, WOOD_LIGHT)
		"marketplace":
			for x in range(5, 20, 5): _rect(image, x, 6, 4, 4, GOLD if x % 10 == 5 else DANGER)
			_rect(image, 5, 10, 14, 2, INK)
		"migration_way_station":
			_rect(image, 6, 7, 3, 11, STONE_LIGHT); _rect(image, 15, 7, 3, 11, STONE_LIGHT); _rect(image, 8, 6, 8, 3, STONE_LIGHT)
		"way_maker_shack":
			_rect(image, 4, 14, 6, 3, STONE_LIGHT); _rect(image, 9, 10, 6, 3, STONE_LIGHT); _rect(image, 14, 6, 6, 3, STONE_LIGHT)
		"lumber_shack", "lumber_mill", "wood_storage":
			_rect(image, 4, 8, 16, 4, WOOD_LIGHT); _rect(image, 7, 13, 13, 3, WOOD)
		"mining_facility", "stone_cuttery", "rock_storage":
			_rect(image, 5, 8, 9, 4, STONE_LIGHT); _rect(image, 11, 12, 8, 5, STONE)
		"crystal_harvestry", "crystillery", "crystal_storage":
			_rect(image, 10, 5, 4, 14, CRYSTAL); _rect(image, 7, 10, 10, 7, CRYSTAL.darkened(0.18)); _rect(image, 11, 6, 2, 8, HOLY)
		"farm":
			for x in [6, 10, 14, 18]: _rect(image, x, 7, 2, 11, GREEN_LIGHT)
		"animal_pen":
			_rect(image, 6, 10, 12, 7, WOOD_LIGHT); _rect(image, 7, 7, 3, 5, PAPER); _rect(image, 14, 7, 3, 5, PAPER)
		"clucker_coop":
			_rect(image, 7, 9, 10, 8, WOOD_LIGHT); _rect(image, 9, 11, 6, 4, HOLY); _pixel(image, 15, 10, DANGER)
		"kitchen":
			_rect(image, 6, 13, 12, 3, STONE); _rect(image, 9, 8, 6, 6, FIRE); _rect(image, 11, 6, 2, 4, GOLD)
		"bottler":
			_rect(image, 10, 6, 4, 4, CRYSTAL); _rect(image, 8, 10, 8, 8, WATER); _rect(image, 10, 8, 4, 2, HOLY)
		"water_purifier":
			_rect(image, 5, 7, 14, 3, STONE); _rect(image, 7, 11, 10, 7, WATER); _rect(image, 9, 12, 6, 2, HOLY)
		"well":
			_rect(image, 5, 7, 14, 12, STONE); _rect(image, 8, 10, 8, 6, WATER)
		"rain_catcher":
			_rect(image, 4, 6, 16, 3, WATER); _rect(image, 7, 9, 10, 4, STONE); _rect(image, 10, 13, 4, 6, WATER)
		"small_fountain", "large_fountain":
			_rect(image, 5, 13, 14, 5, STONE); _rect(image, 8, 11, 8, 5, WATER); _rect(image, 11, 5, 2, 8, WATER)
			if building_id == "large_fountain": _rect(image, 6, 7, 2, 7, WATER); _rect(image, 16, 7, 2, 7, WATER)
		"ranger_lodge":
			_rect(image, 6, 5, 2, 14, GREEN_LIGHT); _rect(image, 7, 5, 8, 2, GREEN_LIGHT); _rect(image, 7, 17, 8, 2, GREEN_LIGHT); _rect(image, 14, 7, 2, 10, GREEN_LIGHT)
		"outpost":
			_rect(image, 8, 5, 3, 14, WOOD_LIGHT); _rect(image, 11, 5, 8, 5, DANGER)
		"doggo_house":
			_rect(image, 7, 10, 10, 8, WOOD); _rect(image, 9, 7, 6, 4, WOOD_LIGHT); _rect(image, 11, 13, 3, 5, INK)
		"forge":
			_rect(image, 6, 13, 12, 4, STONE); _rect(image, 8, 8, 8, 6, FIRE); _rect(image, 11, 5, 3, 5, GOLD)
		"toolsmithy":
			_rect(image, 5, 6, 5, 7, STONE_LIGHT); _rect(image, 8, 11, 11, 3, WOOD_LIGHT)
		"armorsmithy":
			_rect(image, 7, 6, 10, 12, STONE_LIGHT); _rect(image, 10, 9, 4, 7, INK)
		"bowyer":
			_rect(image, 6, 5, 2, 14, WOOD_LIGHT); _rect(image, 8, 5, 7, 2, PAPER); _rect(image, 8, 17, 7, 2, PAPER); _rect(image, 14, 7, 2, 10, PAPER)
		"tumbler":
			_rect(image, 5, 10, 14, 7, STONE); _rect(image, 9, 7, 7, 7, STONE_LIGHT)
		"mineral_storage":
			_rect(image, 5, 10, 7, 7, STONE); _rect(image, 13, 8, 6, 9, GOLD)
		"food_storage":
			_rect(image, 6, 9, 12, 8, GREEN); _rect(image, 10, 6, 4, 5, GREEN_LIGHT)
		"gold_storage":
			_rect(image, 6, 13, 12, 4, GOLD); _rect(image, 8, 9, 8, 4, GOLD.lightened(0.2))
		"ammo_storage":
			_rect(image, 5, 13, 14, 4, STONE); _rect(image, 6, 8, 12, 3, PAPER)
		"equipment_storage":
			_rect(image, 7, 7, 10, 11, STONE_LIGHT); _rect(image, 10, 10, 4, 7, INK)
		"miscellaneous_storage":
			_rect(image, 6, 8, 5, 9, PAPER); _rect(image, 13, 10, 5, 7, GREEN)
		"key_shack":
			_rect(image, 6, 9, 10, 5, GOLD); _rect(image, 14, 11, 5, 2, GOLD); _rect(image, 6, 7, 5, 9, INK)
		"essence_altar":
			_rect(image, 6, 14, 12, 4, STONE); _rect(image, 10, 7, 4, 8, MAGIC); _rect(image, 11, 4, 2, 5, HOLY)
		"essence_collector":
			_rect(image, 6, 7, 3, 11, CRYSTAL); _rect(image, 15, 7, 3, 11, CRYSTAL); _rect(image, 9, 13, 6, 4, MAGIC)
		"reliquary":
			_rect(image, 7, 7, 10, 11, STONE); _rect(image, 9, 9, 6, 7, MAGIC); _rect(image, 11, 10, 2, 4, HOLY)
		"cullis_gate":
			_rect(image, 5, 6, 3, 13, CRYSTAL); _rect(image, 16, 6, 3, 13, CRYSTAL); _rect(image, 8, 5, 8, 3, MAGIC)
		"fire_pit", "large_fire_pit", "crylithium_fire_pit":
			_rect(image, 6, 14, 12, 4, STONE); _rect(image, 9, 8, 6, 7, FIRE); _rect(image, 11, 5, 3, 6, CRYSTAL if building_id.contains("crylithium") else GOLD)
		"crystal_motivator":
			_rect(image, 6, 15, 12, 3, STONE); _rect(image, 10, 6, 4, 10, CRYSTAL); _rect(image, 11, 4, 2, 5, GREEN_LIGHT)
		"wood_golem_combobulator": _draw_material_core(image, WOOD_LIGHT)
		"stone_golem_combobulator": _draw_material_core(image, STONE_LIGHT)
		"crystal_golem_combobulator": _draw_material_core(image, CRYSTAL)
		"cube_e_golem_combobulator": _draw_material_core(image, Color("75815b"))
		"trash_can":
			_rect(image, 7, 8, 10, 10, Color("69715e")); _rect(image, 6, 6, 12, 3, STONE)
		"landfill":
			_rect(image, 4, 12, 16, 6, Color("69715e")); _rect(image, 7, 9, 4, 4, WOOD); _rect(image, 13, 8, 5, 5, GREEN)
		"processor":
			_rect(image, 6, 8, 12, 10, STONE); _rect(image, 9, 10, 6, 6, Color("69715e")); _pixel(image, 12, 11, GOLD)
		"burner":
			_rect(image, 6, 13, 12, 5, STONE); _rect(image, 9, 7, 6, 7, FIRE); _rect(image, 11, 4, 2, 5, GOLD)
		"trashy_cube_pile":
			_rect(image, 5, 11, 7, 7, Color("69715e")); _rect(image, 12, 8, 7, 10, Color("7b6651"))
		"attract_tower": _draw_tower_mark(image, MAGIC, 0)
		"ballista_tower": _draw_tower_mark(image, WOOD_LIGHT, 1)
		"banish_tower": _draw_tower_mark(image, HOLY, 2)
		"bow_tower": _draw_tower_mark(image, GREEN_LIGHT, 1)
		"bullet_tower": _draw_tower_mark(image, STONE_LIGHT, 3)
		"elemental_bolt_tower": _draw_tower_mark(image, FIRE, 4)
		"phantom_dart_tower": _draw_tower_mark(image, MAGIC, 1)
		"recombobulator_tower": _draw_tower_mark(image, CRYSTAL, 0)
		"sling_tower": _draw_tower_mark(image, PAPER, 3)
		"spray_tower": _draw_tower_mark(image, WATER, 5)
		"static_tower": _draw_tower_mark(image, GOLD, 4)

func _draw_material_core(image: Image, color: Color) -> void:
	_rect(image, 6, 14, 12, 4, STONE); _rect(image, 7, 7, 10, 8, INK)
	_rect(image, 9, 9, 6, 5, color); _rect(image, 11, 5, 2, 4, CRYSTAL)

func _draw_tower_mark(image: Image, color: Color, shape: int) -> void:
	match shape:
		0:
			_rect(image, 5, 10, 14, 4, color); _rect(image, 10, 5, 4, 14, color)
		1:
			_rect(image, 3, 11, 18, 2, color); _rect(image, 17, 7, 2, 10, color)
		2:
			_rect(image, 6, 6, 12, 12, color); _rect(image, 9, 9, 6, 6, INK)
		3:
			_rect(image, 8, 8, 8, 8, color); _rect(image, 10, 10, 4, 4, INK)
		4:
			_rect(image, 11, 4, 3, 8, color); _rect(image, 8, 10, 6, 4, color); _rect(image, 7, 13, 3, 8, color)
		5:
			for x in [6, 11, 16]: _rect(image, x, 7, 2, 11, color)

func _draw_job(image: Image, job_id: String, color: Color) -> void:
	_rect(image, 8, 4, 8, 5, INK); _rect(image, 9, 5, 6, 4, Color("d2a06f"))
	_rect(image, 7, 10, 10, 9, INK); _rect(image, 8, 10, 8, 8, color)
	var tool := PAPER
	if job_id in ["miners", "stone_cutters", "tumblers"]: tool = STONE_LIGHT
	elif job_id in ["crystal_harvesters", "crystallers", "occultists"]: tool = CRYSTAL
	elif job_id in ["smelters", "toolsmiths", "armorsmiths"]: tool = FIRE
	elif job_id in ["farmers", "rangers"]: tool = GREEN_LIGHT
	elif job_id in ["water_masters", "bottlers"]: tool = WATER
	_rect(image, 4, 7, 2, 13, WOOD_LIGHT)
	if job_id in ["builders", "maintainers", "miners", "lumberjacks", "farmers"]:
		_rect(image, 2, 6, 7, 3, tool)
	elif job_id in ["medics", "occultists"]:
		_rect(image, 2, 10, 7, 2, tool); _rect(image, 4, 8, 2, 7, tool)
	elif job_id in ["rangers", "fletchers"]:
		_rect(image, 2, 6, 2, 12, tool); _pixel(image, 1, 8, tool); _pixel(image, 1, 15, tool)
	else:
		_rect(image, 2, 8, 6, 6, tool)

func _draw_spell(image: Image, spell_id: String, group: String) -> void:
	var color := MAGIC
	match group:
		"aid": color = GREEN_LIGHT
		"defensive": color = CRYSTAL
		"offensive", "offensive_control": color = DANGER
		"utility": color = GOLD
	_rect(image, 10, 2, 4, 20, color); _rect(image, 2, 10, 20, 4, color)
	_rect(image, 6, 6, 12, 12, color.darkened(0.18)); _rect(image, 9, 9, 6, 6, HOLY)
	if spell_id.contains("lightning"):
		_rect(image, 12, 3, 4, 7, HOLY); _rect(image, 8, 9, 6, 4, HOLY); _rect(image, 7, 12, 4, 9, HOLY)
	elif spell_id.contains("meteor") or spell_id == "comet":
		_rect(image, 4, 4, 11, 3, FIRE); _rect(image, 8, 8, 10, 10, FIRE); _rect(image, 10, 10, 6, 6, GOLD)
	elif spell_id.contains("wall"):
		_rect(image, 3, 9, 18, 8, STONE); _rect(image, 5, 7, 4, 4, STONE_LIGHT); _rect(image, 15, 7, 4, 4, STONE_LIGHT)
	elif spell_id.contains("golem"):
		_rect(image, 6, 7, 12, 11, INK); _rect(image, 8, 8, 8, 8, color); _rect(image, 10, 10, 2, 2, HOLY)
	elif spell_id in ["healing_aura", "regenerate", "resurrect"]:
		_rect(image, 10, 4, 4, 16, GREEN_LIGHT); _rect(image, 4, 10, 16, 4, GREEN_LIGHT)

func _draw_resource(image: Image, resource_id: String) -> void:
	var id := resource_id.to_lower()
	var color := PAPER
	if "wood" in id or "board" in id: color = WOOD_LIGHT
	elif "rock" in id or "stone" in id or "ore" in id: color = STONE_LIGHT
	elif "crystal" in id or "crylithium" in id or "essence" in id: color = CRYSTAL
	elif "water" in id: color = WATER
	elif "food" in id or "vegetable" in id or "herb" in id: color = GREEN_LIGHT
	elif "meat" in id or "blood" in id: color = DANGER
	elif "gold" in id or "coin" in id: color = GOLD
	var cx := image.get_width() / 2
	var cy := image.get_height() / 2
	if "water" in id:
		_rect(image, cx - 3, cy - 6, 6, 11, color); _rect(image, cx - 5, cy, 10, 5, color)
	elif "wood" in id or "board" in id:
		_rect(image, cx - 7, cy - 5, 14, 4, INK); _rect(image, cx - 6, cy - 6, 12, 4, color)
		_rect(image, cx - 5, cy + 2, 12, 4, color.darkened(0.16))
	else:
		_rect(image, cx - 5, cy - 5, 10, 10, INK); _rect(image, cx - 4, cy - 6, 8, 10, color)
		_rect(image, cx - 2, cy - 7, 4, 3, color.lightened(0.25))

func _draw_event(image: Image, event_id: String) -> void:
	match event_id:
		"nomads":
			_rect(image, 4, 12, 16, 3, WOOD_LIGHT); _rect(image, 6, 7, 4, 5, PAPER); _rect(image, 14, 7, 4, 5, PAPER)
			_rect(image, 7, 15, 2, 5, INK); _rect(image, 15, 15, 2, 5, INK)
		"full_moon", "blood_moon", "eclipse":
			var moon_color := DANGER if event_id == "blood_moon" else (INK if event_id == "eclipse" else STONE_LIGHT)
			_rect(image, 6, 6, 12, 12, moon_color); _rect(image, 8, 4, 8, 16, moon_color); _rect(image, 4, 8, 16, 8, moon_color)
			if event_id == "eclipse": _rect(image, 14, 5, 5, 5, GOLD)
		"meteor_shower", "comet":
			var trail := CRYSTAL if event_id == "comet" else FIRE
			_rect(image, 3, 5, 12, 3, trail); _rect(image, 7, 9, 10, 3, trail); _rect(image, 13, 12, 7, 7, GOLD if event_id == "meteor_shower" else HOLY)
		"lightning_storm":
			_rect(image, 11, 3, 4, 7, HOLY); _rect(image, 7, 9, 7, 4, HOLY); _rect(image, 6, 12, 4, 9, GOLD)
		"hail", "snow":
			for point in [Vector2i(5, 7), Vector2i(12, 5), Vector2i(18, 9), Vector2i(8, 16), Vector2i(16, 18)]:
				_rect(image, point.x, point.y, 3, 3, HOLY if event_id == "snow" else CRYSTAL)
		"earthquake":
			_rect(image, 4, 5, 3, 6, WOOD_LIGHT); _rect(image, 6, 10, 5, 3, WOOD_LIGHT); _rect(image, 9, 12, 3, 7, WOOD_LIGHT)
			_rect(image, 15, 4, 3, 7, STONE_LIGHT); _rect(image, 12, 10, 5, 3, STONE_LIGHT); _rect(image, 12, 12, 3, 8, STONE_LIGHT)
		"blight":
			_rect(image, 11, 5, 3, 14, GREEN); _rect(image, 5, 8, 7, 4, GREEN); _rect(image, 13, 12, 7, 4, Color("758443"))
		"rain":
			for x in [5, 10, 15, 20]: _rect(image, x, 5 + (x % 3), 2, 10, WATER)

func _draw_ui(image: Image, ui_id: String) -> void:
	match ui_id:
		"hud_population":
			_rect(image, 5, 6, 6, 6, PAPER); _rect(image, 13, 5, 6, 7, Color("d09b6d"))
			_rect(image, 3, 13, 9, 7, GREEN); _rect(image, 12, 13, 9, 7, CRYSTAL)
		"hud_resources":
			_rect(image, 3, 13, 9, 4, WOOD_LIGHT); _rect(image, 11, 10, 7, 7, STONE_LIGHT); _rect(image, 17, 6, 3, 10, CRYSTAL)
		"hud_influence":
			_rect(image, 10, 3, 4, 18, GOLD); _rect(image, 3, 10, 18, 4, GOLD); _rect(image, 8, 8, 8, 8, HOLY)
		"hud_energy":
			_rect(image, 11, 3, 4, 8, CRYSTAL); _rect(image, 7, 10, 7, 4, CRYSTAL); _rect(image, 6, 13, 4, 8, CRYSTAL)
		"hud_faith":
			_rect(image, 10, 4, 4, 16, HOLY); _rect(image, 5, 9, 14, 4, HOLY)
		"hud_time_weather":
			_rect(image, 6, 6, 12, 12, GOLD); _rect(image, 8, 8, 8, 8, INK); _rect(image, 11, 8, 2, 5, PAPER); _rect(image, 12, 12, 4, 2, PAPER)
		"hud_speed":
			_rect(image, 5, 5, 4, 14, GREEN_LIGHT); _rect(image, 11, 5, 4, 14, GREEN_LIGHT); _rect(image, 17, 5, 3, 14, GREEN_LIGHT)
		"hud_problems":
			_rect(image, 10, 4, 4, 12, DANGER); _rect(image, 10, 18, 4, 3, DANGER); _rect(image, 7, 7, 10, 3, DANGER.darkened(0.2))
		"construction_categories":
			_rect(image, 4, 13, 16, 6, STONE); _rect(image, 6, 9, 4, 5, WOOD_LIGHT); _rect(image, 14, 6, 4, 8, WOOD_LIGHT)
		"harvest_tools":
			_rect(image, 5, 5, 4, 9, STONE_LIGHT); _rect(image, 8, 12, 11, 3, WOOD_LIGHT)
		"terrain_tools":
			_rect(image, 4, 15, 16, 4, GREEN); _rect(image, 7, 10, 10, 5, STONE); _rect(image, 10, 5, 4, 6, WATER)
		"road_tools":
			_rect(image, 2, 9, 20, 7, STONE); _rect(image, 5, 11, 4, 2, STONE_LIGHT); _rect(image, 14, 11, 4, 2, STONE_LIGHT)
		"wall_tools":
			for x in [3, 8, 13, 18]: _rect(image, x, 8, 4, 10, STONE)
		"minimap":
			_rect(image, 3, 4, 18, 16, PAPER); _rect(image, 5, 6, 6, 6, GREEN); _rect(image, 13, 5, 6, 8, WATER); _rect(image, 8, 14, 9, 4, STONE)
		"data_maps":
			_rect(image, 4, 5, 4, 15, GREEN); _rect(image, 10, 9, 4, 11, GOLD); _rect(image, 16, 3, 4, 17, DANGER)
		"selection":
			_rect(image, 3, 3, 7, 2, CRYSTAL); _rect(image, 3, 3, 2, 7, CRYSTAL); _rect(image, 14, 3, 7, 2, CRYSTAL); _rect(image, 19, 3, 2, 7, CRYSTAL)
			_rect(image, 3, 19, 7, 2, CRYSTAL); _rect(image, 3, 14, 2, 7, CRYSTAL); _rect(image, 14, 19, 7, 2, CRYSTAL); _rect(image, 19, 14, 2, 7, CRYSTAL)
		"validity":
			_rect(image, 4, 11, 5, 4, GREEN_LIGHT); _rect(image, 8, 14, 4, 5, GREEN_LIGHT); _rect(image, 11, 7, 9, 4, GREEN_LIGHT)
		"health_work_bars":
			_rect(image, 3, 6, 18, 5, INK); _rect(image, 4, 7, 11, 3, GREEN_LIGHT); _rect(image, 3, 14, 18, 5, INK); _rect(image, 4, 15, 7, 3, GOLD)
		"thoughts_warnings":
			_rect(image, 4, 5, 14, 11, PAPER); _rect(image, 7, 16, 5, 4, PAPER); _rect(image, 11, 7, 3, 6, DANGER); _rect(image, 11, 14, 3, 2, DANGER)
		"goals_perks_chests":
			_rect(image, 4, 9, 16, 10, WOOD); _rect(image, 4, 7, 16, 5, GOLD); _rect(image, 10, 10, 4, 7, HOLY)
		"trade_migration_courier":
			_rect(image, 4, 9, 8, 7, PAPER); _rect(image, 12, 11, 8, 3, GOLD); _rect(image, 17, 8, 3, 9, GOLD)
		"editor_tools":
			_rect(image, 6, 4, 4, 16, STONE_LIGHT); _rect(image, 9, 7, 10, 4, WOOD_LIGHT); _rect(image, 14, 10, 3, 10, WOOD_LIGHT)
		"touch_gestures":
			_rect(image, 9, 5, 5, 13, PAPER); _rect(image, 5, 9, 5, 8, PAPER); _rect(image, 13, 8, 5, 9, PAPER); _rect(image, 7, 16, 11, 5, PAPER)
