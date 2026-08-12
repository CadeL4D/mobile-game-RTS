extends Control

const WORLD_VIEW := preload("res://presentation/scripts/world_view.gd")
const REGION_GRAPH_VIEW := preload("res://presentation/scripts/region_graph_view.gd")
const MAP_EDITOR_VIEW := preload("res://presentation/scripts/map_editor_view.gd")
const PIXEL_ICON_FACTORY := preload("res://presentation/scripts/pixel_icon_factory.gd")
const MAP_TEXTURE := preload("res://art/generated/world_map_v1.png")

var pixel_icons := PIXEL_ICON_FACTORY.new()

var world_view: WorldView
var ui_layer: CanvasLayer
var mode_screen: Control
var custom_screen: Control
var world_screen: Control
var map_editor_screen: Control
var map_editor_view
var map_editor_status: Label
var edited_blueprint: RegionBlueprint
var hud: Control
var jobs_drawer: Control
var build_drawer: Control
var build_catalog_box: VBoxContainer
var spells_drawer: Control
var spells_catalog_box: VBoxContainer
var regions_drawer: Control
var regions_catalog_box: VBoxContainer
var trade_drawer: Control
var trade_catalog_box: VBoxContainer
var trade_status_label: Label
var meta_drawer: Control
var meta_catalog_box: VBoxContainer
var meta_status_label: Label
var meta_view: StringName = &"goals"
var inspector_drawer: Control
var inspector_title: Label
var inspector_body: Label
var inspector_upgrade_button: Button
var inspector_recipe_button: Button
var inspector_make_button: Button
var inspector_maintain_button: Button
var inspector_production_pause_button: Button
var inspector_repair_button: Button
var inspector_dismantle_button: Button
var inspector_capture_button: Button
var inspector_slaughter_button: Button
var selected_entity_kind: StringName = &""
var selected_entity_id := 0
var dismantle_confirm_entity_id := 0
var selected_region_label: Label
var selected_region_detail: Label
var region_action_button: Button
var resource_label: Label
var population_label: Label
var time_label: Label
var influence_label: Label
var goal_label: Label
var event_icon: TextureRect
var goal_panel: Control
var toast_label: Label
var placement_label: Label
var pause_button: Button
var job_rows: Dictionary = {}
var tutorial_panel: Control
var tutorial_title: Label
var tutorial_body: Label
var active_tutorial_id: StringName = &""

var dark_panel := Color("1a1a1dcc")
var wood := Color("5b2d1b")
var copper := Color("b85f34")
var teal := Color("3f9d87")
var gold := Color("f4dc62")

func _ready() -> void:
	if "--run-tests" in OS.get_cmdline_user_args():
		var test_runner := preload("res://tests/run_all.gd").new()
		add_child(test_runner)
		return
	_build_theme()
	world_view = WORLD_VIEW.new()
	world_view.visible = false
	world_view.placement_changed.connect(_on_placement_changed)
	world_view.placement_rejected.connect(_show_toast)
	world_view.entity_selected.connect(_on_entity_selected)
	world_view.spell_changed.connect(_on_spell_changed)
	add_child(world_view)
	move_child(world_view, 0)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	mode_screen = _build_mode_screen()
	custom_screen = _build_custom_screen()
	world_screen = _build_world_screen()
	map_editor_screen = _build_map_editor_screen()
	hud = _build_hud()
	tutorial_panel = _build_tutorial_overlay()
	AppController.screen_changed.connect(_show_screen)
	AppController.mode_changed.connect(func(_mode_id: StringName) -> void:
		ProgressionService.complete_tutorial(&"choose_mode")
		_refresh_tutorial())
	AppController.region_selected.connect(func(_region_id: StringName) -> void:
		ProgressionService.complete_tutorial(&"choose_region")
		_refresh_tutorial())
	SimulationHost.snapshot_updated.connect(_on_snapshot)
	SimulationHost.sim_event.connect(_on_sim_event)
	ProgressionService.achievement_completed.connect(_on_achievement_completed)
	ProgressionService.chest_added.connect(func(_chest: Dictionary) -> void:
		_show_toast("A new God Chest is ready.")
		if meta_drawer.visible: _populate_meta_drawer(meta_view))
	ProgressionService.chest_opened.connect(func(_chest: Dictionary, perk: Dictionary) -> void:
		_show_toast("Perk gained: %s" % perk.get("name", "Perk"))
		if meta_drawer.visible: _populate_meta_drawer(meta_view))
	ProgressionService.tutorial_changed.connect(func(_tutorial_id: StringName) -> void: _refresh_tutorial())
	SaveService.save_completed.connect(func(_slot): _show_toast("Village saved."))
	SaveService.load_completed.connect(func(_slot): _show_toast("Village restored."))
	SaveService.save_failed.connect(_show_toast)
	WorldCampaignService.campaign_changed.connect(_refresh_selected_region)
	WorldCampaignService.transfer_completed.connect(func(transfer: Dictionary) -> void: _show_toast("%s arrived in %s." % [String(transfer.kind).capitalize(), String(transfer.destination).replace("_", " ").capitalize()]))
	WorldCampaignService.transfer_failed.connect(func(_transfer: Dictionary, _reason: String) -> void: _show_toast("Regional transfer failed; reserved cargo returned."))
	_show_screen(AppController.current_screen)
	if "--capture-ui" in OS.get_cmdline_user_args():
		call_deferred("_capture_ui")
	elif "--capture-play" in OS.get_cmdline_user_args():
		call_deferred("_capture_play")
	elif "--capture-village" in OS.get_cmdline_user_args():
		call_deferred("_capture_village")
	elif "--capture-world" in OS.get_cmdline_user_args():
		call_deferred("_capture_world")
	elif "--capture-build" in OS.get_cmdline_user_args():
		call_deferred("_capture_build")
	elif "--capture-threat" in OS.get_cmdline_user_args():
		call_deferred("_capture_threat")
	elif "--capture-custom" in OS.get_cmdline_user_args():
		call_deferred("_capture_custom")
	elif "--capture-spells" in OS.get_cmdline_user_args():
		call_deferred("_capture_spells")
	elif "--capture-editor" in OS.get_cmdline_user_args():
		call_deferred("_capture_editor")
	elif "--capture-goals" in OS.get_cmdline_user_args():
		call_deferred("_capture_goals")
	elif "--capture-roads" in OS.get_cmdline_user_args():
		call_deferred("_capture_roads")
	elif "--capture-golems" in OS.get_cmdline_user_args():
		call_deferred("_capture_golems")
	elif "--capture-defense" in OS.get_cmdline_user_args():
		call_deferred("_capture_defense")
	elif "--capture-services" in OS.get_cmdline_user_args():
		call_deferred("_capture_services")
	elif "--capture-sprite-audit" in OS.get_cmdline_user_args():
		call_deferred("_capture_sprite_audit")
	elif "--capture-visual-review" in OS.get_cmdline_user_args():
		call_deferred("_capture_visual_review")
	elif "--capture-tier-review" in OS.get_cmdline_user_args():
		call_deferred("_capture_tier_review")
	elif "--capture-biome-review" in OS.get_cmdline_user_args():
		call_deferred("_capture_biome_review")
	elif "--capture-season-review" in OS.get_cmdline_user_args():
		call_deferred("_capture_season_review")

func _capture_ui() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture("res://build/captures/mode_screen.png")

func _capture_play() -> void:
	AppController.select_mode(&"traditional")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture("res://build/captures/play_screen.png")

func _capture_world() -> void:
	AppController.select_mode(&"traditional")
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture("res://build/captures/world_screen.png")

func _capture_build() -> void:
	AppController.select_mode(&"traditional")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	world_view.cancel_placement()
	build_drawer.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture("res://build/captures/build_drawer.png")

func _capture_threat() -> void:
	AppController.select_mode(&"nightmare")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	world_view.cancel_placement()
	for _index in 105:
		SimulationHost.advance_tick()
	if not SimulationHost.monsters.is_empty():
		var monster: Dictionary = SimulationHost.monsters[0]
		world_view.camera.position = Vector2(float(monster.x), float(monster.y)) * world_view.TILE_PIXELS
		world_view.camera.zoom = Vector2(1.3, 1.3)
		world_view.camera.reset_smoothing()
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture("res://build/captures/threat_screen.png")

func _capture_custom() -> void:
	AppController.select_mode(&"custom")
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture("res://build/captures/custom_mode.png")

func _capture_spells() -> void:
	AppController.select_mode(&"traditional")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	world_view.cancel_placement()
	spells_drawer.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture("res://build/captures/spells_drawer.png")

func _capture_editor() -> void:
	AppController.open_map_editor()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture("res://build/captures/map_editor.png")

func _capture_goals() -> void:
	ProgressionService.reset_profile_progress()
	ProgressionService.set_counter(&"buildings.completed.camp", 1)
	ProgressionService.set_counter(&"animals.captured", 7)
	ProgressionService.set_counter(&"resources.harvested.wood", 96)
	ProgressionService.set_god_xp(60)
	AppController.select_mode(&"traditional")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	world_view.cancel_placement()
	meta_drawer.visible = true
	_populate_meta_drawer(&"goals")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture("res://build/captures/goals_drawer.png")

func _capture_roads() -> void:
	AppController.select_mode(&"sandbox")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	world_view.cancel_placement()
	var center: Vector2i = SimulationHost.blueprint.starting_cell
	for offset_x in range(-18, 19):
		var road_id := &"log_road" if offset_x < -6 else (&"cobble_log_road" if offset_x < 6 else &"cut_stone_board_road")
		SimulationHost.submit(GameCommand.place_building(SimulationHost.tick, road_id, center + Vector2i(offset_x, 8)))
	for offset_x in range(-18, 19):
		if offset_x in [-1, 0]:
			continue
		SimulationHost.submit(GameCommand.place_building(SimulationHost.tick, &"curtain_wall", center + Vector2i(offset_x, -9)))
	SimulationHost.submit(GameCommand.place_building(SimulationHost.tick, &"stone_gate", center + Vector2i(-1, -9)))
	for _index in 4:
		SimulationHost.advance_tick()
	world_view.camera.position = Vector2(center) * world_view.TILE_PIXELS
	world_view.camera.zoom = Vector2(1.25, 1.25)
	world_view.camera.reset_smoothing()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture("res://build/captures/roads_walls.png")

func _capture_golems() -> void:
	ProgressionService.skip_all_tutorials()
	AppController.select_mode(&"sandbox")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	world_view.cancel_placement()
	SimulationHost.resources.energy = 1000
	var combobulator: Dictionary = _capture_place_building(&"crystal_golem_combobulator")
	_capture_place_building(&"recombobulator_tower")
	for _index in 250:
		SimulationHost.advance_tick()
	if not SimulationHost.golems.is_empty():
		var golem: Dictionary = SimulationHost.golems[0]
		golem.health = int(golem.max_health) - 260
		var position := Vector2(float(golem.x), float(golem.y))
		SimulationHost.monsters.append({
			"id": 99100, "definition_id": "headless", "name": "Headless", "x": position.x + 3.0, "y": position.y,
			"target_x": position.x, "target_y": position.y, "health": 900, "max_health": 900, "damage": 4, "speed": 0.045,
			"state": "hunting", "task_id": 0, "task_kind": "", "task_progress": 0, "path": [], "path_index": 0, "path_goal_x": -1, "path_goal_y": -1, "stuck_ticks": 0,
		})
		for _index in 4:
			SimulationHost.advance_tick()
		world_view.selected_kind = &"golem"
		world_view.selected_entity_id = int(golem.id)
		_on_entity_selected(&"golem", int(golem.id))
		world_view.camera.position = position * world_view.TILE_PIXELS
	else:
		world_view.camera.position = Vector2(float(combobulator.get("x", SimulationHost.blueprint.starting_cell.x)), float(combobulator.get("y", SimulationHost.blueprint.starting_cell.y))) * world_view.TILE_PIXELS
	world_view.camera.zoom = Vector2(1.35, 1.35)
	world_view.camera.reset_smoothing()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	tutorial_panel.visible = false
	goal_panel.visible = false
	toast_label.visible = false
	_save_capture("res://build/captures/golem_system.png")

func _capture_defense() -> void:
	ProgressionService.skip_all_tutorials()
	AppController.select_mode(&"sandbox")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	world_view.cancel_placement()
	var lodge: Dictionary = _capture_place_building(&"ranger_lodge")
	var tower: Dictionary = _capture_place_building(&"bow_tower")
	SimulationHost.resources.bow = 1
	SimulationHost.resources.quiver = 3
	SimulationHost.resources.iron_body_armor = 1
	SimulationHost.resources.iron_helmet = 1
	var ranger: Dictionary = SimulationHost.villagers[4]
	ranger.job = "rangers"
	SimulationHost.tick = 500
	SimulationHost._update_equipment()
	_rangers_for_capture(ranger, tower)
	if not lodge.is_empty():
		var elemental: Dictionary = SimulationHost._spawn_monster_actor(&"fire_elemental", Vector2(float(lodge.x) + float(lodge.width) + 4.0, float(lodge.y) + float(lodge.height) * 0.5))
		SimulationHost._apply_monster_hit(elemental, lodge, &"building")
	SimulationHost._emit_snapshot()
	world_view.selected_kind = &"villager"
	world_view.selected_entity_id = int(ranger.id)
	_on_entity_selected(&"villager", int(ranger.id))
	world_view.camera.position = Vector2(float(ranger.x), float(ranger.y)) * world_view.TILE_PIXELS
	world_view.camera.zoom = Vector2(2.0, 2.0)
	world_view.camera.reset_smoothing()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	tutorial_panel.visible = false
	goal_panel.visible = false
	toast_label.visible = false
	toast_label.text = ""
	await get_tree().process_frame
	_save_capture("res://build/captures/defender_combat.png")

func _rangers_for_capture(ranger: Dictionary, tower: Dictionary) -> void:
	var spawn_position := Vector2(float(ranger.x) + 6.0, float(ranger.y))
	if not tower.is_empty():
		spawn_position = Vector2(float(tower.x) + float(tower.width) * 0.5 + 4.0, float(tower.y) + float(tower.height) * 0.5)
		ranger.x = spawn_position.x - 5.0
		ranger.y = spawn_position.y
	SimulationHost._spawn_monster_actor(&"skeleton", spawn_position)
	SimulationHost._ranger_try_combat(ranger)

func _capture_services() -> void:
	ProgressionService.skip_all_tutorials()
	AppController.select_mode(&"sandbox")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	world_view.cancel_placement()
	var maintenance := _capture_place_building(&"maintenance_building")
	var clinic := _capture_place_building(&"clinic")
	var housing := _capture_place_building(&"housing")
	SimulationHost.resources.hammer = 1
	SimulationHost.resources.wood = 4
	SimulationHost.resources.bandage = 0
	SimulationHost.resources.medkit = 0
	SimulationHost.resources.healing_potion = 0
	SimulationHost.tick = 600
	SimulationHost._update_equipment()
	var maintainer: Dictionary = {}
	var medic: Dictionary = {}
	for villager in SimulationHost.villagers:
		if String(villager.job) == "maintainers" and maintainer.is_empty():
			maintainer = villager
		elif String(villager.job) == "medics" and medic.is_empty():
			medic = villager
	if not housing.is_empty():
		housing.health = maxi(1, int(housing.max_health) - 620)
		housing.repair_batch_remaining = 0
		SimulationHost.submit(GameCommand.set_building_work(SimulationHost.tick, int(housing.id), &"prioritize_repair", true))
		if not maintainer.is_empty():
			maintainer.x = float(housing.x) + float(housing.width) * 0.5
			maintainer.y = float(housing.y) + float(housing.height) * 0.5
	if not clinic.is_empty() and not medic.is_empty():
		medic.x = float(clinic.x) + float(clinic.width) * 0.5
		medic.y = float(clinic.y) + float(clinic.height) * 0.5
		var patient: Dictionary = SimulationHost.villagers[12]
		patient.x = float(medic.x) + 1.5
		patient.y = float(medic.y)
		patient.health = 560
		patient.status_effects = {"infection": 260}
	for _index in 8:
		SimulationHost.advance_tick()
	SimulationHost._emit_snapshot()
	if not housing.is_empty():
		world_view.selected_kind = &"building"
		world_view.selected_entity_id = int(housing.id)
		_on_entity_selected(&"building", int(housing.id))
		world_view.camera.position = Vector2(float(housing.x), float(housing.y)) * world_view.TILE_PIXELS
	elif not maintenance.is_empty():
		world_view.camera.position = Vector2(float(maintenance.x), float(maintenance.y)) * world_view.TILE_PIXELS
	world_view.camera.zoom = Vector2(1.55, 1.55)
	world_view.camera.reset_smoothing()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	tutorial_panel.visible = false
	goal_panel.visible = false
	toast_label.visible = false
	for _warmup_frame in 8:
		await get_tree().process_frame
	_save_capture("res://build/captures/settlement_services.png")

func _capture_sprite_audit() -> void:
	ProgressionService.skip_all_tutorials()
	AppController.select_mode(&"sandbox")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	world_view.cancel_placement()
	SimulationHost.tick = 500
	SimulationHost.weather = &"clear"
	var audit_buildings: Array[StringName] = [
		&"camp", &"ancillary", &"clinic", &"maintenance_building", &"marketplace",
		&"lumber_shack", &"mining_facility", &"crystal_harvestry", &"farm", &"animal_pen",
		&"clucker_coop", &"kitchen", &"water_purifier", &"well", &"ranger_lodge",
		&"housing", &"doggo_house", &"lumber_mill", &"stone_cuttery", &"crystillery", &"forge",
		&"toolsmithy", &"armorsmithy", &"bowyer", &"wood_storage", &"crystal_storage",
		&"essence_altar", &"reliquary", &"large_fire_pit", &"crystal_golem_combobulator",
		&"processor", &"burner",
	]
	for building_id in audit_buildings:
		_capture_place_building(building_id)
	SimulationHost._emit_snapshot()
	world_view.camera.position = Vector2(SimulationHost.blueprint.starting_cell) * world_view.TILE_PIXELS
	world_view.camera.zoom = Vector2(0.95, 0.95)
	world_view.camera.reset_smoothing()
	selected_entity_kind = &""
	selected_entity_id = 0
	world_view.clear_selection()
	hud.visible = false
	for _warmup_frame in 10:
		await get_tree().process_frame
	_save_capture("res://build/captures/minimal_sprite_audit.png")

func _capture_visual_review() -> void:
	ProgressionService.skip_all_tutorials()
	AppController.select_mode(&"sandbox")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	world_view.cancel_placement()
	var review_buildings: Array[StringName] = [
		&"camp", &"clinic", &"maintenance_building", &"marketplace", &"lumber_shack", &"mining_facility",
		&"farm", &"animal_pen", &"housing", &"lumber_mill", &"forge", &"bowyer", &"essence_altar",
		&"large_fire_pit", &"bow_tower", &"crystal_golem_combobulator", &"processor", &"stone_wall",
	]
	for building_id in review_buildings:
		_capture_place_building(building_id)
	# Four construction stages and four physical damage states remain visible in every review frame.
	for index in mini(4, SimulationHost.buildings.size()):
		var building: Dictionary = SimulationHost.buildings[index]
		building.completed = false
		building.progress = int(float(building.build_time) * [0.12, 0.32, 0.57, 0.82][index])
	for index in range(4, mini(8, SimulationHost.buildings.size())):
		var building: Dictionary = SimulationHost.buildings[index]
		if index == 4:
			building.health = int(float(building.max_health) * 0.62)
		elif index == 5:
			building.health = int(float(building.max_health) * 0.24)
		elif index == 6:
			building.burning = true
		else:
			building.destroyed = true
	for building in SimulationHost.buildings:
		if String(building.definition_id) == "bow_tower": building.combat_state = "no_ammo"
		elif String(building.definition_id) == "crystal_golem_combobulator": building.operation_state = "no_energy"
	var center := Vector2(SimulationHost.blueprint.starting_cell)
	var job_ids: Array = ContentRegistry.get_all(&"jobs").map(func(job: Dictionary) -> String: return String(job.id))
	for index in SimulationHost.villagers.size():
		var villager: Dictionary = SimulationHost.villagers[index]
		villager.x = center.x - 10.0 + float(index % 10) * 2.2
		villager.y = center.y + 13.0 + float(index / 10) * 3.0
		villager.target_x = float(villager.x) + [-2.0, 2.0, 0.0, 0.0][index % 4]
		villager.target_y = float(villager.y) + [0.0, 0.0, -2.0, 2.0][index % 4]
		villager.job = job_ids[index % job_ids.size()]
		villager.state = ["traveling", "working", "repairing", "fighting", "eating"][index % 5]
	for index in SimulationHost.animals.size():
		var animal: Dictionary = SimulationHost.animals[index]
		animal.x = center.x - 11.0 + float(index % 9) * 2.8
		animal.y = center.y + 20.0 + float(index / 9) * 3.0
		animal.target_x = float(animal.x) + (-2.0 if index % 2 else 2.0)
		animal.target_y = float(animal.y)
	var monster_ids := [&"headless", &"small_slime", &"slime", &"blood_slime", &"trashy_slime", &"zombie", &"skeleton", &"spectre", &"fire_elemental", &"drone"]
	for index in monster_ids.size():
		var monster := SimulationHost._spawn_monster_actor(monster_ids[index], center + Vector2(-12.0 + index * 2.7, -20.0))
		monster.target_x = float(monster.x) + (-2.0 if index % 2 else 2.0)
	SimulationHost.paused = true
	world_view.camera.position = center * world_view.TILE_PIXELS
	world_view.camera.zoom = Vector2(1.0, 1.0)
	world_view.camera.reset_smoothing()
	hud.visible = false
	var capture_errors: Array[int] = []
	SimulationHost.tick = 500
	SimulationHost.weather = &"clear"
	SimulationHost.active_event = &""
	SimulationHost._emit_snapshot()
	for _frame in 4: await get_tree().process_frame
	capture_errors.append(_write_capture("res://build/captures/review_day_1x.png"))
	SimulationHost.tick = 1120
	SimulationHost.active_event = &"blood_moon"
	SimulationHost.event_ticks_remaining = 200
	SimulationHost._emit_snapshot()
	for _frame in 3: await get_tree().process_frame
	capture_errors.append(_write_capture("res://build/captures/review_night_blood_moon_1x.png"))
	SimulationHost.tick = 504
	SimulationHost.weather = &"rain"
	SimulationHost.active_event = &"lightning_storm"
	SimulationHost._emit_snapshot()
	for _frame in 3: await get_tree().process_frame
	capture_errors.append(_write_capture("res://build/captures/review_rain_lightning_1x.png"))
	SimulationHost.weather = &"clear"
	SimulationHost.active_event = &"blight"
	for y in range(-17, 18):
		for x in range(-25, 26):
			var distance := Vector2(float(x) / 1.35, float(y)).length()
			var organic_edge := 14.0 + sin(float(x) * 0.47) * 2.4 + cos(float(y) * 0.39) * 1.8
			if distance <= organic_edge and posmod(x * 17 + y * 23, 13) != 0:
				var cell := Vector2i(center) + Vector2i(x, y)
				SimulationHost.corruption_cells[SimulationHost._cell_key(cell)] = 1000
	SimulationHost._emit_snapshot()
	for _frame in 3: await get_tree().process_frame
	capture_errors.append(_write_capture("res://build/captures/review_corruption_blight_1x.png"))
	get_tree().quit(1 if capture_errors.any(func(error: int) -> bool: return error != OK) else 0)

func _capture_tier_review() -> void:
	ProgressionService.skip_all_tutorials()
	AppController.select_mode(&"sandbox")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	world_view.cancel_placement()
	SimulationHost.buildings.clear()
	SimulationHost.villagers.clear()
	SimulationHost.animals.clear()
	SimulationHost.monsters.clear()
	SimulationHost.golems.clear()
	var center := SimulationHost.blueprint.starting_cell
	for tier in range(1, 9):
		_capture_add_visual_building(&"camp", tier, center + Vector2i(-55 + (tier - 1) * 14, -36))
	for tier in range(9, 16):
		_capture_add_visual_building(&"camp", tier, center + Vector2i(-48 + (tier - 9) * 14, -21))
	for tier in range(1, 6):
		_capture_add_visual_building(&"ancillary", tier, center + Vector2i(-51 + (tier - 1) * 11, -5))
	for tier in range(1, 6):
		_capture_add_visual_building(&"crystal_storage", tier, center + Vector2i(7 + (tier - 1) * 8, -4))
	for tier in range(1, 8):
		_capture_add_visual_building(&"housing", tier, center + Vector2i(-51 + (tier - 1) * 9, 6))
	for tier in range(1, 4):
		_capture_add_visual_building(&"doggo_house", tier, center + Vector2i(17 + (tier - 1) * 7, 7))
	for tier in range(1, 5):
		_capture_add_visual_building(&"bow_tower", tier, center + Vector2i(-45 + (tier - 1) * 8, 17))
	for tier in range(1, 5):
		_capture_add_visual_building(&"crystal_golem_combobulator", tier, center + Vector2i(-9 + (tier - 1) * 9, 16))
	for tier in range(1, 4):
		_capture_add_visual_building(&"clinic", tier, center + Vector2i(31 + (tier - 1) * 8, 16))
	SimulationHost.tick = 500
	SimulationHost.weather = &"clear"
	SimulationHost.active_event = &""
	SimulationHost.paused = true
	SimulationHost._emit_snapshot()
	world_view.camera.position = Vector2(center) * world_view.TILE_PIXELS
	world_view.camera.zoom = Vector2(1.0, 1.0)
	world_view.camera.reset_smoothing()
	hud.visible = false
	for _frame in 8: await get_tree().process_frame
	_save_capture("res://build/captures/review_tiers_1x.png")

func _capture_add_visual_building(building_id: StringName, tier: int, cell: Vector2i) -> void:
	var definition := ContentRegistry.get_by_id(&"buildings", building_id)
	var footprint: Array = definition.get("footprint", [5, 5])
	var maximum_tier := int(definition.get("tiers", 1))
	SimulationHost.buildings.append({
		"id": 900000 + SimulationHost.buildings.size(), "definition_id": String(building_id),
		"name": String(definition.get("name", building_id)), "category": String(definition.get("category", "misc")),
		"x": cell.x, "y": cell.y, "width": int(footprint[0]), "height": int(footprint[1]),
		"tier": clampi(tier, 1, maximum_tier), "completed": true,
		"progress": int(definition.get("build_time", 100)), "build_time": int(definition.get("build_time", 100)),
		"health": int(definition.get("health", 1000)), "max_health": int(definition.get("health", 1000)),
		"destroyed": false, "burning": false, "service_state": "none", "operation_state": "operational",
		"combat_state": "ready", "review_tier_label": true,
	})

func _capture_biome_review() -> void:
	ProgressionService.skip_all_tutorials()
	AppController.select_mode(&"sandbox")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	world_view.cancel_placement()
	hud.visible = false
	var generator := RegionGenerator.new()
	var biome_ids := [&"forest", &"haven", &"desert", &"red_sands", &"marsh", &"dry_lands", &"island"]
	var capture_errors: Array[int] = []
	for biome_index in biome_ids.size():
		var biome_id: StringName = biome_ids[biome_index]
		var blueprint := generator.generate(81000 + biome_index * 1307, StringName("review_%s" % biome_id), biome_id)
		SimulationHost.start_region(blueprint, ContentRegistry.get_by_id(&"modes", &"sandbox"))
		world_view.cancel_placement()
		SimulationHost.buildings.clear()
		var center := blueprint.starting_cell
		_capture_add_visual_building(&"camp", 7, center + Vector2i(-27, -12))
		_capture_add_visual_building(&"housing", 4, center + Vector2i(-11, -11))
		_capture_add_visual_building(&"clinic", 3, center + Vector2i(0, -12))
		_capture_add_visual_building(&"bow_tower", 4, center + Vector2i(12, -8))
		_capture_add_visual_building(&"crystal_harvestry", 3, center + Vector2i(-26, 6))
		_capture_add_visual_building(&"farm", 3, center + Vector2i(-12, 8))
		_capture_add_visual_building(&"essence_altar", 3, center + Vector2i(2, 8))
		_capture_add_visual_building(&"crystal_golem_combobulator", 4, center + Vector2i(14, 6))
		for villager_index in mini(12, SimulationHost.villagers.size()):
			var villager: Dictionary = SimulationHost.villagers[villager_index]
			villager.x = center.x - 14.0 + float(villager_index % 6) * 4.5
			villager.y = center.y + 23.0 + float(villager_index / 6) * 4.0
			villager.target_x = float(villager.x) + [-2.0, 2.0, 0.0, 0.0][villager_index % 4]
			villager.target_y = float(villager.y) + [0.0, 0.0, -2.0, 2.0][villager_index % 4]
			villager.state = "traveling"
		for animal_index in SimulationHost.animals.size():
			var animal: Dictionary = SimulationHost.animals[animal_index]
			animal.x = center.x - 20.0 + float(animal_index % 9) * 5.0
			animal.y = center.y + 31.0 + float(animal_index / 9) * 4.0
			animal.target_x = float(animal.x) + (2.0 if animal_index % 2 == 0 else -2.0)
			animal.target_y = float(animal.y)
		SimulationHost.tick = 500
		SimulationHost.weather = &"clear"
		SimulationHost.active_event = &""
		SimulationHost.paused = true
		SimulationHost._emit_snapshot()
		world_view.camera.position = Vector2(center) * world_view.TILE_PIXELS
		world_view.camera.zoom = Vector2.ONE
		world_view.camera.reset_smoothing()
		for _frame in 5: await get_tree().process_frame
		capture_errors.append(_write_capture("res://build/captures/review_biome_%s_1x.png" % biome_id))
	get_tree().quit(1 if capture_errors.any(func(error: int) -> bool: return error != OK) else 0)

func _capture_season_review() -> void:
	ProgressionService.skip_all_tutorials()
	AppController.select_mode(&"sandbox")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	world_view.cancel_placement()
	hud.visible = false
	var generator := RegionGenerator.new()
	var blueprint := generator.generate(82421, &"review_seasons", &"forest")
	var sandbox_rules: Dictionary = ContentRegistry.get_by_id(&"modes", &"sandbox").duplicate(true)
	sandbox_rules["season_days"] = 1
	SimulationHost.start_region(blueprint, sandbox_rules)
	world_view.cancel_placement()
	SimulationHost.buildings.clear()
	var center := blueprint.starting_cell
	_capture_add_visual_building(&"camp", 7, center + Vector2i(-27, -12))
	_capture_add_visual_building(&"housing", 4, center + Vector2i(-11, -11))
	_capture_add_visual_building(&"clinic", 3, center + Vector2i(0, -12))
	_capture_add_visual_building(&"bow_tower", 4, center + Vector2i(12, -8))
	_capture_add_visual_building(&"crystal_harvestry", 3, center + Vector2i(-26, 6))
	_capture_add_visual_building(&"farm", 3, center + Vector2i(-12, 8))
	_capture_add_visual_building(&"essence_altar", 3, center + Vector2i(2, 8))
	_capture_add_visual_building(&"crystal_golem_combobulator", 4, center + Vector2i(14, 6))
	for villager_index in mini(12, SimulationHost.villagers.size()):
		var villager: Dictionary = SimulationHost.villagers[villager_index]
		villager.x = center.x - 14.0 + float(villager_index % 6) * 4.5
		villager.y = center.y + 23.0 + float(villager_index / 6) * 4.0
		villager.target_x = float(villager.x) + [-2.0, 2.0, 0.0, 0.0][villager_index % 4]
		villager.target_y = float(villager.y) + [0.0, 0.0, -2.0, 2.0][villager_index % 4]
		villager.state = "traveling"
	world_view.camera.position = Vector2(center) * world_view.TILE_PIXELS
	world_view.camera.zoom = Vector2.ONE
	world_view.camera.reset_smoothing()
	var season_ids := [&"Spring", &"Summer", &"Autumn", &"Winter"]
	var capture_errors: Array[int] = []
	for season_index in season_ids.size():
		SimulationHost.tick = season_index * SimulationHost.TICKS_PER_DAY + SimulationHost.TICKS_PER_DAY / 2
		SimulationHost.weather = &"clear"
		SimulationHost.active_event = &""
		SimulationHost.paused = true
		SimulationHost._emit_snapshot()
		for _frame in 6: await get_tree().process_frame
		capture_errors.append(_write_capture("res://build/captures/review_season_%s_1x.png" % String(season_ids[season_index]).to_lower()))
	get_tree().quit(1 if capture_errors.any(func(error: int) -> bool: return error != OK) else 0)

func _capture_place_building(building_id: StringName) -> Dictionary:
	var definition: Dictionary = ContentRegistry.get_by_id(&"buildings", building_id)
	var footprint_data: Array = definition.get("footprint", [5, 5])
	var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
	var center: Vector2i = SimulationHost.blueprint.starting_cell
	for radius in range(0, 48, 4):
		for offset_value in [Vector2i(radius, 0), Vector2i(-radius, 0), Vector2i(0, radius), Vector2i(0, -radius), Vector2i(radius, radius), Vector2i(-radius, radius), Vector2i(radius, -radius), Vector2i(-radius, -radius)]:
			var offset := Vector2i(offset_value)
			var cell: Vector2i = center + offset
			if not SimulationHost.blueprint.is_buildable(cell, footprint) or SimulationHost._footprint_overlaps(cell, footprint):
				continue
			var before: int = SimulationHost.buildings.size()
			SimulationHost.submit(GameCommand.place_building(SimulationHost.tick, building_id, cell))
			SimulationHost.advance_tick()
			if SimulationHost.buildings.size() > before:
				return SimulationHost.buildings.back()
	return {}

func _capture_village() -> void:
	AppController.select_mode(&"traditional")
	AppController.select_region(&"applemeadow")
	AppController.establish_selected_region()
	SimulationHost.resources.wood = 220
	SimulationHost.resources.rock = 220
	var center: Vector2i = SimulationHost.blueprint.starting_cell
	SimulationHost.submit(GameCommand.place_building(SimulationHost.tick, &"camp", center - Vector2i(6, 6)))
	for _index in 120:
		SimulationHost.advance_tick()
	SimulationHost.submit(GameCommand.place_building(SimulationHost.tick, &"housing", center + Vector2i(-18, -18)))
	SimulationHost.submit(GameCommand.place_building(SimulationHost.tick, &"farm", center + Vector2i(9, -18)))
	SimulationHost.submit(GameCommand.place_building(SimulationHost.tick, &"well", center + Vector2i(-18, 10)))
	SimulationHost.submit(GameCommand.place_building(SimulationHost.tick, &"lumber_shack", center + Vector2i(10, 10)))
	for _index in 2:
		SimulationHost.advance_tick()
	_capture_place_near(&"animal_pen", center, 18)
	for _index in 700:
		SimulationHost.advance_tick()
	world_view.cancel_placement()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture("res://build/captures/village_screen.png")

func _capture_place_near(building_id: StringName, center: Vector2i, minimum_radius: int = 0) -> bool:
	var definition := ContentRegistry.get_by_id(&"buildings", building_id)
	var footprint_data: Array = definition.get("footprint", [5, 5])
	var footprint := Vector2i(int(footprint_data[0]), int(footprint_data[1]))
	for radius in range(minimum_radius, 57, 4):
		for offset in [Vector2i(radius, 0), Vector2i(-radius, 0), Vector2i(0, radius), Vector2i(0, -radius), Vector2i(radius, radius), Vector2i(-radius, radius), Vector2i(radius, -radius), Vector2i(-radius, -radius)]:
			var cell: Vector2i = center + offset
			if not SimulationHost.blueprint.is_buildable(cell, footprint) or SimulationHost._footprint_overlaps(cell, footprint):
				continue
			SimulationHost.submit(GameCommand.place_building(SimulationHost.tick, building_id, cell))
			return true
	return false

func _save_capture(path: String) -> void:
	var error := _write_capture(path)
	get_tree().quit(error)

func _write_capture(path: String) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/captures"))
	var capture := get_viewport().get_texture().get_image()
	var error := capture.save_png(path)
	print("UI capture %s (%s), viewport=%s root_pos=%s root_size=%s mode_pos=%s mode_size=%s backdrop=%s/%s panel=%s/%s" % [path, error, get_viewport_rect().size, position, size, mode_screen.position, mode_screen.size, mode_screen.get_child(0).position, mode_screen.get_child(0).size, mode_screen.get_child(1).position, mode_screen.get_child(1).size])
	return error

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed:
		return
	if event.is_action_pressed("pause_game") and SimulationHost.active:
		SimulationHost.set_paused(not SimulationHost.paused)
	elif event.is_action_pressed("quick_save"):
		SaveService.save_atomic(&"quick")
	elif event.is_action_pressed("quick_load"):
		SaveService.load_and_migrate(&"quick")
	elif event.is_action_pressed("cancel_action") and world_view:
		world_view.cancel_placement()

func _build_theme() -> void:
	var game_theme := Theme.new()
	game_theme.default_font_size = 18
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = dark_panel
	panel_style.border_color = copper
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 7
	panel_style.corner_radius_top_right = 7
	panel_style.corner_radius_bottom_left = 7
	panel_style.corner_radius_bottom_right = 7
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	game_theme.set_stylebox("panel", "PanelContainer", panel_style)
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = wood
	button_style.border_color = teal
	button_style.set_border_width_all(2)
	button_style.corner_radius_top_left = 6
	button_style.corner_radius_top_right = 6
	button_style.corner_radius_bottom_left = 6
	button_style.corner_radius_bottom_right = 6
	button_style.content_margin_left = 14
	button_style.content_margin_right = 14
	button_style.content_margin_top = 9
	button_style.content_margin_bottom = 9
	game_theme.set_stylebox("normal", "Button", button_style)
	var hover := button_style.duplicate()
	hover.bg_color = copper.darkened(0.1)
	hover.border_color = Color("65d6b8")
	game_theme.set_stylebox("hover", "Button", hover)
	var pressed := button_style.duplicate()
	pressed.bg_color = Color("2b685b")
	game_theme.set_stylebox("pressed", "Button", pressed)
	game_theme.set_color("font_color", "Button", Color("fff4cf"))
	game_theme.set_color("font_hover_color", "Button", Color.WHITE)
	game_theme.set_color("font_color", "Label", Color("f4eee2"))
	theme = game_theme

func _build_mode_screen() -> Control:
	var screen := ColorRect.new()
	screen.color = Color("050709")
	screen.theme = theme
	ui_layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := TextureRect.new()
	backdrop.texture = MAP_TEXTURE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.34, 0.36, 0.40, 0.30)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	screen.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -340
	panel.offset_top = -294
	panel.offset_right = 340
	panel.offset_bottom = 294
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "RUINWARD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("7b7cff"))
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Select Game Mode"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 26)
	box.add_child(subtitle)
	var copy := Label.new()
	copy.text = "Each mode keeps independent campaign progress.\nTraditional is recommended for a new village."
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.modulate = Color("d7d3c8")
	box.add_child(copy)
	for mode in ContentRegistry.get_all(&"modes"):
		var button := Button.new()
		button.custom_minimum_size.y = 52
		button.text = mode.name + ("  • Recommended" if mode.get("recommended", false) else "")
		button.pressed.connect(func() -> void: AppController.select_mode(StringName(mode.id)))
		box.add_child(button)
	var editor_button := Button.new()
	editor_button.text = "Region Editor"
	editor_button.custom_minimum_size.y = 48
	editor_button.pressed.connect(AppController.open_map_editor)
	box.add_child(editor_button)
	return screen

func _build_custom_screen() -> Control:
	var screen := ColorRect.new()
	screen.color = Color("080b0d")
	screen.theme = theme
	ui_layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := TextureRect.new()
	backdrop.texture = MAP_TEXTURE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.25, 0.28, 0.30, 0.20)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -480
	panel.offset_top = 26
	panel.offset_right = 480
	panel.offset_bottom = 694
	screen.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var title := Label.new()
	title.text = "CUSTOM MODE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("7b7cff"))
	outer.add_child(title)
	var intro := Label.new()
	intro.text = "Tune the simulation before choosing a region. Each custom campaign keeps independent progress."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(intro)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	_add_custom_slider(left, "First Attack Day", &"first_attack_day", 0.0, 12.0, 1.0, 2.0)
	_add_custom_slider(left, "Monster Pressure", &"monster_rate", 0.0, 3.0, 0.1, 1.0)
	_add_custom_slider(left, "Corruption Spread", &"corruption_rate", 0.0, 3.0, 0.1, 1.0)
	_add_custom_slider(left, "Need Drain", &"needs_rate", 0.25, 3.0, 0.05, 1.0)
	_add_custom_slider(right, "Season Length (days)", &"season_days", 2.0, 20.0, 1.0, 5.0)
	_add_custom_slider(right, "Resource Abundance", &"resource_abundance", 0.25, 3.0, 0.05, 1.0)
	_add_custom_toggle(right, "Disasters", &"disasters", true)
	_add_custom_toggle(right, "Dynamic Weather", &"weather", true)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	outer.add_child(actions)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(180, 54)
	back.pressed.connect(func() -> void: AppController.set_screen(&"mode_select"))
	actions.add_child(back)
	var start := Button.new()
	start.text = "Choose Region"
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.custom_minimum_size.y = 54
	start.pressed.connect(AppController.confirm_custom_mode)
	actions.add_child(start)
	return screen

func _add_custom_slider(parent: VBoxContainer, label_text: String, rule_id: StringName, minimum: float, maximum: float, step: float, initial: float) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value_label := Label.new()
	value_label.text = _format_rule_value(initial, step)
	value_label.custom_minimum_size.x = 68
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size.y = 42
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = _format_rule_value(value, step)
		AppController.set_custom_rule(rule_id, int(value) if step >= 1.0 else value))
	box.add_child(slider)

func _add_custom_toggle(parent: VBoxContainer, label_text: String, rule_id: StringName, initial: bool) -> void:
	var toggle := CheckButton.new()
	toggle.text = label_text
	toggle.button_pressed = initial
	toggle.custom_minimum_size.y = 50
	toggle.toggled.connect(func(value: bool) -> void: AppController.set_custom_rule(rule_id, value))
	parent.add_child(toggle)

func _format_rule_value(value: float, step: float) -> String:
	return "%d" % roundi(value) if step >= 1.0 else "%.2f×" % value

func _build_world_screen() -> Control:
	var screen := Control.new()
	screen.theme = theme
	ui_layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var map := TextureRect.new()
	map.texture = MAP_TEXTURE
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	screen.add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var wash := ColorRect.new()
	wash.color = Color(0.01, 0.02, 0.04, 0.10)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var graph = REGION_GRAPH_VIEW.new()
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(graph)
	graph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	graph.configure(ContentRegistry.get_all(&"regions"))
	for region in ContentRegistry.get_all(&"regions"):
		var position_data: Array = region.position
		var node := Button.new()
		node.text = "◆" if region.id == "applemeadow" else "•"
		node.tooltip_text = region.name
		node.set_anchors_preset(Control.PRESET_TOP_LEFT)
		node.anchor_left = float(position_data[0])
		node.anchor_top = float(position_data[1])
		node.anchor_right = float(position_data[0])
		node.anchor_bottom = float(position_data[1])
		node.offset_left = -17
		node.offset_top = -17
		node.offset_right = 17
		node.offset_bottom = 17
		node.add_theme_font_size_override("font_size", 18)
		node.pressed.connect(func() -> void: _select_region(region))
		screen.add_child(node)
	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 250
	top.offset_right = -250
	top.offset_top = 18
	top.offset_bottom = 78
	screen.add_child(top)
	var title := Label.new()
	title.text = "World Map  •  Choose a Region"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	top.add_child(title)
	var inspector := PanelContainer.new()
	inspector.anchor_left = 1.0
	inspector.anchor_right = 1.0
	inspector.anchor_top = 1.0
	inspector.anchor_bottom = 1.0
	inspector.offset_left = -360
	inspector.offset_top = -270
	inspector.offset_right = -20
	inspector.offset_bottom = -20
	screen.add_child(inspector)
	var inspector_box := VBoxContainer.new()
	inspector_box.add_theme_constant_override("separation", 12)
	inspector.add_child(inspector_box)
	selected_region_label = Label.new()
	selected_region_label.text = "Applemeadow"
	selected_region_label.add_theme_font_size_override("font_size", 27)
	selected_region_label.add_theme_color_override("font_color", Color("6fffd2"))
	inspector_box.add_child(selected_region_label)
	selected_region_detail = Label.new()
	selected_region_detail.text = "Forest • Unestablished\nA balanced region with all five critical resources."
	selected_region_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_region_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_box.add_child(selected_region_detail)
	region_action_button = Button.new()
	region_action_button.text = "Establish Village"
	region_action_button.custom_minimum_size.y = 58
	region_action_button.pressed.connect(AppController.establish_selected_region)
	inspector_box.add_child(region_action_button)
	return screen

func _build_map_editor_screen() -> Control:
	var screen := Control.new()
	screen.theme = theme
	ui_layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("080c0f")
	screen.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title_panel := PanelContainer.new()
	title_panel.anchor_right = 1.0
	title_panel.offset_left = 8
	title_panel.offset_top = 8
	title_panel.offset_right = -8
	title_panel.offset_bottom = 66
	screen.add_child(title_panel)
	var title := Label.new()
	title.text = "REGION EDITOR  •  Local .rtrmap packages"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title_panel.add_child(title)
	var tools := PanelContainer.new()
	tools.offset_left = 8
	tools.offset_top = 76
	tools.offset_right = 270
	tools.anchor_bottom = 1.0
	tools.offset_bottom = -8
	screen.add_child(tools)
	var tool_scroll := ScrollContainer.new()
	tool_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tool_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tools.add_child(tool_scroll)
	var tool_box := VBoxContainer.new()
	tool_box.custom_minimum_size.x = 225
	tool_box.add_theme_constant_override("separation", 7)
	tool_scroll.add_child(tool_box)
	var terrain_heading := Label.new()
	terrain_heading.text = "TERRAIN BRUSH"
	terrain_heading.add_theme_color_override("font_color", Color("6fffd2"))
	tool_box.add_child(terrain_heading)
	var terrain_buttons := {
		"Water": RegionGenerator.Tile.DEEP_WATER, "Grass": RegionGenerator.Tile.GRASS,
		"Forest": RegionGenerator.Tile.FOREST_FLOOR, "Rock": RegionGenerator.Tile.ROCKY,
		"Crystal": RegionGenerator.Tile.CRYSTAL_GROUND, "Fertile": RegionGenerator.Tile.FERTILE,
		"Sand": RegionGenerator.Tile.SAND, "Marsh": RegionGenerator.Tile.MARSH,
		"Corruption": RegionGenerator.Tile.CORRUPTION,
	}
	for label_text in terrain_buttons:
		var tile_value: int = int(terrain_buttons[label_text])
		var button := Button.new()
		button.text = label_text
		button.custom_minimum_size.y = 42
		button.pressed.connect(func() -> void: map_editor_view.set_paint_tile(tile_value))
		tool_box.add_child(button)
	var brush_label := Label.new()
	brush_label.text = "Brush Radius: 3"
	tool_box.add_child(brush_label)
	var brush := HSlider.new()
	brush.min_value = 1
	brush.max_value = 12
	brush.step = 1
	brush.value = 3
	brush.value_changed.connect(func(value: float) -> void:
		brush_label.text = "Brush Radius: %d" % roundi(value)
		map_editor_view.set_brush_radius(roundi(value)))
	tool_box.add_child(brush)
	map_editor_status = Label.new()
	map_editor_status.text = "Generating editable Forest region…"
	map_editor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_editor_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tool_box.add_child(map_editor_status)
	var validate := Button.new()
	validate.text = "Validate"
	validate.pressed.connect(_validate_edited_map)
	tool_box.add_child(validate)
	var save := Button.new()
	save.text = "Save .rtrmap"
	save.pressed.connect(_save_edited_map)
	tool_box.add_child(save)
	var load := Button.new()
	load.text = "Load Latest"
	load.pressed.connect(_load_latest_map)
	tool_box.add_child(load)
	var play := Button.new()
	play.text = "Play Test"
	play.pressed.connect(_play_edited_map)
	tool_box.add_child(play)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func() -> void: AppController.set_screen(&"mode_select"))
	tool_box.add_child(back)
	map_editor_view = MAP_EDITOR_VIEW.new()
	map_editor_view.anchor_left = 0.0
	map_editor_view.anchor_top = 0.0
	map_editor_view.anchor_right = 1.0
	map_editor_view.anchor_bottom = 1.0
	map_editor_view.offset_left = 282
	map_editor_view.offset_top = 76
	map_editor_view.offset_right = -8
	map_editor_view.offset_bottom = -8
	screen.add_child(map_editor_view)
	call_deferred("_initialize_editor_blueprint")
	return screen

func _initialize_editor_blueprint() -> void:
	edited_blueprint = RegionGenerator.new().generate(24680, &"custom_region", &"forest")
	map_editor_view.set_blueprint(edited_blueprint)
	_validate_edited_map()

func _validate_edited_map() -> void:
	if edited_blueprint == null:
		return
	edited_blueprint.validation_report = RegionGenerator.new().validate(edited_blueprint)
	map_editor_status.text = "VALID MAP\n" if bool(edited_blueprint.validation_report.get("valid", false)) else "NEEDS WORK\n"
	map_editor_status.text += str(edited_blueprint.validation_report.get("nearby", {}))

func _save_edited_map() -> void:
	_validate_edited_map()
	var path := MapPackageService.save_map(edited_blueprint, "Custom Region", {"author": "Local Player"})
	map_editor_status.text = "Saved: %s" % path if not path.is_empty() else "Save failed."

func _load_latest_map() -> void:
	var path := MapPackageService.latest_map_path()
	if path.is_empty():
		map_editor_status.text = "No saved .rtrmap package found."
		return
	var loaded := MapPackageService.load_map(path)
	if loaded:
		edited_blueprint = loaded
		map_editor_view.set_blueprint(loaded)
		_validate_edited_map()

func _play_edited_map() -> void:
	_validate_edited_map()
	if not bool(edited_blueprint.validation_report.get("valid", false)):
		map_editor_status.text = "Fix validation errors before play testing."
		return
	AppController.play_blueprint(edited_blueprint, ContentRegistry.get_by_id(&"modes", &"sandbox"))

func _select_region(region: Dictionary) -> void:
	AppController.select_region(StringName(region.id))
	_refresh_selected_region()

func _refresh_selected_region() -> void:
	if selected_region_label == null or selected_region_detail == null:
		return
	var region: Dictionary = ContentRegistry.get_by_id(&"regions", AppController.current_region)
	if region.is_empty():
		return
	selected_region_label.text = region.name
	var state := WorldCampaignService.get_region_state(AppController.current_region, AppController.current_mode)
	var status := String(state.get("status", "unestablished"))
	selected_region_detail.text = "%s biome • %s\nPopulation %d\nStored wood %d • rock %d\nConnected regions support migration and courier routes." % [String(region.biome).capitalize(), status.capitalize(), int(state.get("population", 0)), int(state.get("resources", {}).get("wood", 0)), int(state.get("resources", {}).get("rock", 0))]
	if region_action_button:
		region_action_button.text = "Enter Village" if state.has("simulation") else ("Reclaim Region" if status == "lost" else "Establish Village")

func _build_hud() -> Control:
	var layer := Control.new()
	layer.theme = theme
	ui_layer.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_left = 8
	top.offset_top = 8
	top.offset_right = -8
	top.offset_bottom = 70
	layer.add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	top.add_child(row)
	_add_hud_pixel_icon(row, &"hud_population")
	population_label = _label("Pop 20 • Kids 3 • Homes 0", 17)
	row.add_child(population_label)
	_add_hud_pixel_icon(row, &"hud_resources")
	resource_label = _label("W32/200 R32/200 F96 H₂O96 C8", 16)
	resource_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(resource_label)
	_add_hud_pixel_icon(row, &"hud_influence")
	influence_label = _label("I 800/800 • XP 0", 16)
	row.add_child(influence_label)
	_add_hud_pixel_icon(row, &"hud_time_weather")
	time_label = _label("Spring D1 • Dawn • 18°C", 16)
	row.add_child(time_label)
	event_icon = TextureRect.new()
	event_icon.custom_minimum_size = Vector2(30, 30)
	event_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	event_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	event_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	event_icon.visible = false
	row.add_child(event_icon)
	pause_button = Button.new()
	pause_button.text = "Ⅱ"
	pause_button.custom_minimum_size = Vector2(52, 44)
	pause_button.pressed.connect(func() -> void: SimulationHost.set_paused(not SimulationHost.paused))
	row.add_child(pause_button)
	goal_panel = PanelContainer.new()
	goal_panel.offset_left = 10
	goal_panel.offset_top = 82
	goal_panel.offset_right = 350
	goal_panel.offset_bottom = 164
	layer.add_child(goal_panel)
	goal_label = Label.new()
	goal_label.text = "YOU ALREADY LOST\nBuild your first Camp.  •  God XP 60"
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_panel.add_child(goal_label)
	var bottom := PanelContainer.new()
	bottom.anchor_left = 0.0
	bottom.anchor_right = 1.0
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.offset_left = 8
	bottom.offset_top = -86
	bottom.offset_right = -8
	bottom.offset_bottom = -8
	layer.add_child(bottom)
	var build_scroll := ScrollContainer.new()
	build_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	build_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	build_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.add_child(build_scroll)
	var build_row := HBoxContainer.new()
	build_row.add_theme_constant_override("separation", 7)
	build_scroll.add_child(build_row)
	var jobs_button := Button.new()
	jobs_button.text = "Jobs"
	_set_pixel_button_icon(jobs_button, pixel_icons.ui(&"hud_population", 24))
	jobs_button.pressed.connect(func() -> void:
		jobs_drawer.visible = not jobs_drawer.visible
		if jobs_drawer.visible:
			build_drawer.visible = false
			spells_drawer.visible = false
			regions_drawer.visible = false
			trade_drawer.visible = false
			meta_drawer.visible = false
			inspector_drawer.visible = false)
	build_row.add_child(jobs_button)
	var goals_button := Button.new()
	goals_button.text = "Goals"
	_set_pixel_button_icon(goals_button, pixel_icons.ui(&"goals_perks_chests", 24))
	goals_button.pressed.connect(_toggle_meta_drawer)
	build_row.add_child(goals_button)
	var build_button := Button.new()
	build_button.text = "Build"
	_set_pixel_button_icon(build_button, pixel_icons.ui(&"construction_categories", 24))
	build_button.pressed.connect(_toggle_build_drawer)
	build_row.add_child(build_button)
	var spells_button := Button.new()
	spells_button.text = "Spells"
	_set_pixel_button_icon(spells_button, pixel_icons.spell(&"grab", &"utility", 24))
	spells_button.pressed.connect(_toggle_spells_drawer)
	build_row.add_child(spells_button)
	var regions_button := Button.new()
	regions_button.text = "Regions"
	_set_pixel_button_icon(regions_button, pixel_icons.ui(&"minimap", 24))
	regions_button.pressed.connect(_toggle_regions_drawer)
	build_row.add_child(regions_button)
	var trade_button := Button.new()
	trade_button.text = "Trade"
	_set_pixel_button_icon(trade_button, pixel_icons.ui(&"trade_migration_courier", 24))
	trade_button.pressed.connect(_toggle_trade_drawer)
	build_row.add_child(trade_button)
	var quick_buildings := ["camp", "housing", "farm", "well", "ancillary", "lumber_shack", "mining_facility", "bow_tower"]
	for id in quick_buildings:
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(id))
		var button := Button.new()
		button.text = String(definition.get("name", id))
		_set_pixel_button_icon(button, pixel_icons.building(StringName(id), StringName(definition.get("category", "misc")), 24))
		button.custom_minimum_size = Vector2(82, 56)
		button.pressed.connect(func() -> void: world_view.begin_placement(StringName(id)))
		build_row.add_child(button)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(world_view.cancel_placement)
	build_row.add_child(cancel)
	var world := Button.new()
	world.text = "World"
	_set_pixel_button_icon(world, pixel_icons.ui(&"minimap", 24))
	world.pressed.connect(AppController.return_to_world_map)
	build_row.add_child(world)
	var save := Button.new()
	save.text = "Save"
	_set_pixel_button_icon(save, pixel_icons.ui(&"editor_tools", 24))
	save.pressed.connect(func() -> void: SaveService.save_atomic(&"quick"))
	build_row.add_child(save)
	var load := Button.new()
	load.text = "Load"
	load.pressed.connect(func() -> void: SaveService.load_and_migrate(&"quick"))
	build_row.add_child(load)
	placement_label = Label.new()
	placement_label.anchor_left = 0.5
	placement_label.anchor_right = 0.5
	placement_label.anchor_top = 1.0
	placement_label.anchor_bottom = 1.0
	placement_label.offset_left = -220
	placement_label.offset_top = -125
	placement_label.offset_right = 220
	placement_label.offset_bottom = -93
	placement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placement_label.add_theme_color_override("font_color", Color("7affd9"))
	layer.add_child(placement_label)
	jobs_drawer = _build_jobs_drawer(layer)
	meta_drawer = _build_meta_drawer(layer)
	build_drawer = _build_construction_drawer(layer)
	spells_drawer = _build_spells_drawer(layer)
	regions_drawer = _build_regions_drawer(layer)
	trade_drawer = _build_trade_drawer(layer)
	inspector_drawer = _build_inspector_drawer(layer)
	toast_label = Label.new()
	toast_label.anchor_left = 0.5
	toast_label.anchor_right = 0.5
	toast_label.offset_left = -280
	toast_label.offset_top = 82
	toast_label.offset_right = 280
	toast_label.offset_bottom = 124
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_color", Color("ffe36e"))
	toast_label.visible = false
	layer.add_child(toast_label)
	return layer

func _build_tutorial_overlay() -> Control:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -330
	panel.offset_top = -224
	panel.offset_right = 330
	panel.offset_bottom = -100
	panel.visible = false
	ui_layer.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 5)
	panel.add_child(outer)
	tutorial_title = Label.new()
	tutorial_title.add_theme_font_size_override("font_size", 20)
	tutorial_title.add_theme_color_override("font_color", Color("f4dc62"))
	outer.add_child(tutorial_title)
	tutorial_body = Label.new()
	tutorial_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(tutorial_body)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(actions)
	var skip := Button.new()
	skip.text = "Skip Tutorials"
	skip.custom_minimum_size.y = 42
	skip.pressed.connect(ProgressionService.skip_all_tutorials)
	actions.add_child(skip)
	var next := Button.new()
	next.text = "Got It"
	next.custom_minimum_size = Vector2(100, 42)
	next.pressed.connect(func() -> void:
		ProgressionService.complete_tutorial(active_tutorial_id)
		_refresh_tutorial())
	actions.add_child(next)
	return panel

func _refresh_tutorial() -> void:
	if tutorial_panel == null or ProgressionService.tutorials_disabled:
		if tutorial_panel: tutorial_panel.visible = false
		if placement_label: placement_label.visible = true
		return
	var candidate: StringName = &""
	match String(AppController.current_screen):
		"mode_select": candidate = &"choose_mode"
		"world_map": candidate = &"choose_region"
		"play": candidate = _next_play_tutorial()
	if candidate.is_empty() or ProgressionService.is_tutorial_completed(candidate):
		active_tutorial_id = &""
		tutorial_panel.visible = false
		if placement_label: placement_label.visible = true
		return
	var definition := ContentRegistry.get_by_id(&"tutorials", candidate)
	if definition.is_empty():
		tutorial_panel.visible = false
		if placement_label: placement_label.visible = true
		return
	active_tutorial_id = candidate
	_layout_tutorial_panel(AppController.current_screen)
	tutorial_title.text = "GUIDE  •  %s" % definition.name
	tutorial_body.text = String(definition.get("description", ""))
	tutorial_panel.visible = true
	if placement_label:
		placement_label.visible = AppController.current_screen != &"play"

func _layout_tutorial_panel(screen: StringName) -> void:
	if screen == &"play":
		tutorial_panel.anchor_left = 0.5
		tutorial_panel.anchor_right = 0.5
		tutorial_panel.anchor_top = 1.0
		tutorial_panel.anchor_bottom = 1.0
		tutorial_panel.offset_left = -330
		tutorial_panel.offset_top = -224
		tutorial_panel.offset_right = 330
		tutorial_panel.offset_bottom = -100
	else:
		tutorial_panel.anchor_left = 0.0
		tutorial_panel.anchor_right = 0.0
		tutorial_panel.anchor_top = 0.0
		tutorial_panel.anchor_bottom = 0.0
		tutorial_panel.offset_left = 10
		tutorial_panel.offset_top = 96
		tutorial_panel.offset_right = 290
		tutorial_panel.offset_bottom = 304

func _next_play_tutorial() -> StringName:
	if not SimulationHost.active:
		return &""
	var has_camp := SimulationHost.buildings.any(func(building: Dictionary) -> bool: return String(building.definition_id) == "camp")
	var camp_completed := SimulationHost.buildings.any(func(building: Dictionary) -> bool: return String(building.definition_id) == "camp" and bool(building.completed))
	if not has_camp and not ProgressionService.is_tutorial_completed(&"place_camp"):
		return &"place_camp"
	if has_camp and not ProgressionService.is_tutorial_completed(&"camera_gestures"):
		return &"camera_gestures"
	if camp_completed and not ProgressionService.is_tutorial_completed(&"harvest_resources"):
		return &"harvest_resources"
	var has_workplace := SimulationHost.buildings.any(func(building: Dictionary) -> bool:
		if not bool(building.completed): return false
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
		return not definition.get("jobs", []).is_empty())
	if has_workplace and not ProgressionService.is_tutorial_completed(&"jobs"):
		return &"jobs"
	if SimulationHost.tick >= 300 and not ProgressionService.is_tutorial_completed(&"food_water"):
		return &"food_water"
	if SimulationHost.housing_capacity < SimulationHost.villagers.size() and not ProgressionService.is_tutorial_completed(&"housing"):
		return &"housing"
	var attack_day := int(SimulationHost.mode_rules.get("first_attack_day", 2))
	if SimulationHost.tick >= maxi(0, attack_day - 1) * SimulationHost.TICKS_PER_DAY and not ProgressionService.is_tutorial_completed(&"defense"):
		return &"defense"
	if camp_completed and not ProgressionService.is_tutorial_completed(&"god_powers"):
		return &"god_powers"
	if SimulationHost._has_completed_building(&"essence_altar") and not ProgressionService.is_tutorial_completed(&"faith_essence"):
		return &"faith_essence"
	if (SimulationHost._has_completed_building(&"migration_way_station") or SimulationHost._has_completed_building(&"courier_station")) and not ProgressionService.is_tutorial_completed(&"regions"):
		return &"regions"
	return &""

func _build_regions_drawer(parent: Control) -> Control:
	var drawer := PanelContainer.new()
	drawer.anchor_left = 1.0
	drawer.anchor_right = 1.0
	drawer.anchor_bottom = 1.0
	drawer.offset_left = -430
	drawer.offset_top = 82
	drawer.offset_right = -10
	drawer.offset_bottom = -96
	drawer.visible = false
	parent.add_child(drawer)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	drawer.add_child(outer)
	var heading := Label.new()
	heading.text = "REGIONAL NETWORK"
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("6fffd2"))
	outer.add_child(heading)
	var help := Label.new()
	help.text = "Migration requires a Way Station. Cargo requires a Courier Station. Travel takes 24 simulation seconds."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(help)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	regions_catalog_box = VBoxContainer.new()
	regions_catalog_box.custom_minimum_size.x = 380
	regions_catalog_box.add_theme_constant_override("separation", 8)
	scroll.add_child(regions_catalog_box)
	return drawer

func _populate_regions_drawer() -> void:
	if regions_catalog_box == null:
		return
	for child in regions_catalog_box.get_children():
		child.queue_free()
	if not SimulationHost.active or SimulationHost.blueprint == null:
		return
	var source_id := StringName(SimulationHost.blueprint.region_id)
	var source_definition := ContentRegistry.get_by_id(&"regions", source_id)
	var has_migration := AppController._active_region_has_building(&"migration_way_station")
	var has_courier := AppController._active_region_has_building(&"courier_station")
	var availability := Label.new()
	availability.text = "Way Station %s  •  Courier Station %s" % ["Ready" if has_migration else "Missing", "Ready" if has_courier else "Missing"]
	availability.add_theme_color_override("font_color", Color("f4dc62"))
	regions_catalog_box.add_child(availability)
	var campaign: Dictionary = WorldCampaignService._ensure_mode(AppController.current_mode)
	for transfer in campaign.transfers:
		if String(transfer.source) == String(source_id) or String(transfer.destination) == String(source_id):
			var transfer_label := Label.new()
			transfer_label.text = "In transit: %s → %s (%ds)" % [String(transfer.source).replace("_", " ").capitalize(), String(transfer.destination).replace("_", " ").capitalize(), ceili(float(transfer.ticks_remaining) / 10.0)]
			regions_catalog_box.add_child(transfer_label)
	for neighbor_id in source_definition.get("adjacent", []):
		var region := ContentRegistry.get_by_id(&"regions", StringName(neighbor_id))
		var state := WorldCampaignService.get_region_state(StringName(neighbor_id), AppController.current_mode)
		var panel := PanelContainer.new()
		regions_catalog_box.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		var title := Label.new()
		title.text = "%s  •  %s  •  Population %d" % [region.get("name", neighbor_id), String(state.get("status", "unestablished")).capitalize(), int(state.get("population", 0))]
		box.add_child(title)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		var migrate := Button.new()
		migrate.text = "Send 5 Migrants"
		migrate.disabled = not has_migration or SimulationHost.villagers.size() <= 5
		migrate.pressed.connect(func() -> void:
			if AppController.send_migrants(StringName(neighbor_id), 5):
				_show_toast("Five migrants departed for %s." % region.get("name", neighbor_id))
			else:
				_show_toast("Migration could not depart.")
			_populate_regions_drawer())
		row.add_child(migrate)
		var courier := Button.new()
		courier.text = "Send 16 Wood"
		courier.disabled = not has_courier or int(SimulationHost.resources.get("wood", 0)) < 16
		courier.pressed.connect(func() -> void:
			if AppController.send_courier(StringName(neighbor_id), {"wood": 16}):
				_show_toast("Courier departed for %s." % region.get("name", neighbor_id))
			else:
				_show_toast("Courier could not depart.")
			_populate_regions_drawer())
		row.add_child(courier)

func _toggle_regions_drawer() -> void:
	regions_drawer.visible = not regions_drawer.visible
	if regions_drawer.visible:
		build_drawer.visible = false
		jobs_drawer.visible = false
		spells_drawer.visible = false
		trade_drawer.visible = false
		meta_drawer.visible = false
		inspector_drawer.visible = false
		_populate_regions_drawer()

func _build_trade_drawer(parent: Control) -> Control:
	var drawer := PanelContainer.new()
	drawer.anchor_left = 1.0
	drawer.anchor_right = 1.0
	drawer.anchor_bottom = 1.0
	drawer.offset_left = -500
	drawer.offset_top = 82
	drawer.offset_right = -10
	drawer.offset_bottom = -96
	drawer.visible = false
	parent.add_child(drawer)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	drawer.add_child(outer)
	var heading := Label.new()
	heading.text = "CATJEET MARKETPLACE"
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("f4dc62"))
	outer.add_child(heading)
	trade_status_label = Label.new()
	trade_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(trade_status_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	trade_catalog_box = VBoxContainer.new()
	trade_catalog_box.custom_minimum_size.x = 450
	trade_catalog_box.add_theme_constant_override("separation", 7)
	scroll.add_child(trade_catalog_box)
	return drawer

func _operational_marketplace() -> Dictionary:
	for building in SimulationHost.buildings:
		if String(building.definition_id) == "marketplace" and bool(building.completed) and not bool(building.get("destroyed", false)):
			return building
	return {}

func _populate_trade_drawer() -> void:
	if trade_catalog_box == null:
		return
	for child in trade_catalog_box.get_children():
		child.queue_free()
	var marketplace := _operational_marketplace()
	if marketplace.is_empty():
		trade_status_label.text = "Build and staff a Marketplace to attract Catjeet caravans."
		return
	if int(SimulationHost.jobs.get("provisioners", {}).get("current", 0)) <= 0:
		trade_status_label.text = "Assign at least one Provisioner to operate this Marketplace."
		return
	if SimulationHost.catjeet_trader.is_empty():
		trade_status_label.text = "No caravan is present. Next arrival window opens in %d seconds." % maxi(0, ceili(float(SimulationHost.next_trade_arrival_tick - SimulationHost.tick) / 10.0))
		return
	var trader: Dictionary = SimulationHost.catjeet_trader
	trade_status_label.text = "%s • Village gold %d • Caravan gold %d • Leaves in %ds" % [String(trader.name), int(SimulationHost.resources.gold_coins), int(trader.gold_coins), maxi(0, ceili(float(int(trader.depart_tick) - SimulationHost.tick) / 10.0))]
	var hire := Button.new()
	hire.text = "Hire Catjeet Laborer • %d gold • %d available" % [int(trader.laborer_price), int(trader.laborers)]
	hire.custom_minimum_size.y = 50
	hire.disabled = int(trader.laborers) <= 0 or int(SimulationHost.resources.gold_coins) < int(trader.laborer_price)
	hire.pressed.connect(func() -> void:
		SimulationHost.submit(GameCommand.hire_catjeet(SimulationHost.tick, int(marketplace.id)))
		SimulationHost.advance_tick()
		_populate_trade_drawer())
	trade_catalog_box.add_child(hire)
	for good in ContentRegistry.get_all(&"trade_goods"):
		var resource_id := String(good.resource_id)
		var stock := int(trader.inventory.get(resource_id, 0))
		var owned := int(SimulationHost.resources.get(resource_id, 0))
		if stock <= 0 and owned <= 0:
			continue
		var panel := PanelContainer.new()
		trade_catalog_box.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		var title := Label.new()
		title.text = "%s • Village %d/%d • Caravan %d" % [good.name, owned, int(SimulationHost.resource_caps.get(resource_id, 0)), stock]
		box.add_child(title)
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 5)
		box.add_child(actions)
		var buy := Button.new()
		buy.text = "Buy 8 (%d)" % (int(good.buy_price) * 8)
		buy.disabled = stock < 8 or int(SimulationHost.resources.gold_coins) < int(good.buy_price) * 8 or owned + 8 > int(SimulationHost.resource_caps.get(resource_id, 0))
		buy.pressed.connect(func() -> void:
			SimulationHost.submit(GameCommand.trade_resource(SimulationHost.tick, int(marketplace.id), &"buy", StringName(resource_id), 8))
			SimulationHost.advance_tick()
			_populate_trade_drawer())
		actions.add_child(buy)
		var sell := Button.new()
		sell.text = "Sell 8 (+%d)" % (int(good.sell_price) * 8)
		sell.disabled = owned < 8 or int(trader.gold_coins) < int(good.sell_price) * 8
		sell.pressed.connect(func() -> void:
			SimulationHost.submit(GameCommand.trade_resource(SimulationHost.tick, int(marketplace.id), &"sell", StringName(resource_id), 8))
			SimulationHost.advance_tick()
			_populate_trade_drawer())
		actions.add_child(sell)
		var auto := Button.new()
		auto.text = "Auto 16–64"
		auto.tooltip_text = "Automatically buy below 16 and sell above 64 in batches of 8 while a caravan is present."
		auto.pressed.connect(func() -> void:
			SimulationHost.submit(GameCommand.set_trade_rule(SimulationHost.tick, int(marketplace.id), StringName(resource_id), 16, 64, 8))
			SimulationHost.advance_tick()
			_show_toast("Auto trade set for %s." % good.name))
		actions.add_child(auto)

func _toggle_trade_drawer() -> void:
	trade_drawer.visible = not trade_drawer.visible
	if trade_drawer.visible:
		build_drawer.visible = false
		jobs_drawer.visible = false
		spells_drawer.visible = false
		regions_drawer.visible = false
		meta_drawer.visible = false
		inspector_drawer.visible = false
		_populate_trade_drawer()

func _build_jobs_drawer(parent: Control) -> Control:
	var drawer := PanelContainer.new()
	drawer.offset_left = 10
	drawer.offset_top = 176
	drawer.offset_right = 360
	drawer.anchor_bottom = 1.0
	drawer.offset_bottom = -96
	drawer.visible = false
	parent.add_child(drawer)
	var scroll := ScrollContainer.new()
	drawer.add_child(scroll)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 315
	box.add_theme_constant_override("separation", 5)
	scroll.add_child(box)
	var title := Label.new()
	title.text = "WORKFORCE"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("6fffd2"))
	box.add_child(title)
	for job in ContentRegistry.get_all(&"jobs"):
		var row := HBoxContainer.new()
		var job_icon := TextureRect.new()
		job_icon.texture = pixel_icons.job(StringName(job.id), Color(job.color), 24)
		job_icon.custom_minimum_size = Vector2(30, 30)
		job_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		job_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		job_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(job_icon)
		var swatch := ColorRect.new()
		swatch.color = Color(job.color)
		swatch.custom_minimum_size = Vector2(5, 34)
		row.add_child(swatch)
		var name := Label.new()
		name.text = job.name
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		row.add_child(name)
		var minus := Button.new()
		minus.text = "−"
		minus.custom_minimum_size = Vector2(38, 34)
		minus.pressed.connect(func() -> void: _change_job(StringName(job.id), -1))
		row.add_child(minus)
		var count := Label.new()
		count.text = "0 / 0"
		count.custom_minimum_size.x = 70
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(count)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(38, 34)
		plus.pressed.connect(func() -> void: _change_job(StringName(job.id), 1))
		row.add_child(plus)
		box.add_child(row)
		job_rows[job.id] = count
	return drawer

func _build_meta_drawer(parent: Control) -> Control:
	var drawer := PanelContainer.new()
	drawer.offset_left = 10
	drawer.offset_top = 82
	drawer.offset_right = 430
	drawer.anchor_bottom = 1.0
	drawer.offset_bottom = -96
	drawer.visible = false
	parent.add_child(drawer)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	drawer.add_child(outer)
	var title := Label.new()
	title.text = "DIVINE PROGRESSION"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f4dc62"))
	outer.add_child(title)
	meta_status_label = Label.new()
	meta_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(meta_status_label)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	outer.add_child(tabs)
	for view_id in [&"goals", &"chests", &"perks", &"stats"]:
		var tab := Button.new()
		tab.text = String(view_id).capitalize()
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func() -> void: _populate_meta_drawer(view_id))
		tabs.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	meta_catalog_box = VBoxContainer.new()
	meta_catalog_box.custom_minimum_size.x = 380
	meta_catalog_box.add_theme_constant_override("separation", 6)
	scroll.add_child(meta_catalog_box)
	return drawer

func _toggle_meta_drawer() -> void:
	meta_drawer.visible = not meta_drawer.visible
	goal_panel.visible = not meta_drawer.visible
	if meta_drawer.visible:
		jobs_drawer.visible = false
		build_drawer.visible = false
		spells_drawer.visible = false
		regions_drawer.visible = false
		trade_drawer.visible = false
		inspector_drawer.visible = false
		_populate_meta_drawer(meta_view)

func _populate_meta_drawer(view_id: StringName) -> void:
	meta_view = view_id
	if goal_panel:
		goal_panel.visible = not meta_drawer.visible
	for child in meta_catalog_box.get_children():
		child.queue_free()
	var completed_count := ProgressionService.completed.size()
	meta_status_label.text = "%d / 113 goals complete  •  %d God XP\nNext chest at %d XP  •  %d unopened" % [completed_count, ProgressionService.god_xp, ProgressionService.next_chest_xp, ProgressionService.chest_inventory.size()]
	match String(view_id):
		"goals":
			for goal in ProgressionService.get_goal_nodes():
				var goal_button := Button.new()
				var marker := "✓" if bool(goal.completed) else ("○" if bool(goal.bound) else "◇")
				goal_button.text = "%s %s\n%d / %d" % [marker, String(goal.name), int(goal.progress), int(goal.target)]
				goal_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				goal_button.custom_minimum_size.y = 54
				goal_button.tooltip_text = String(goal.description) + ("" if bool(goal.bound) else "\nGameplay counter awaiting runtime parity binding.")
				goal_button.disabled = not bool(goal.bound) and not bool(goal.completed)
				meta_catalog_box.add_child(goal_button)
		"chests":
			if ProgressionService.chest_inventory.is_empty():
				var empty := Label.new()
				empty.text = "No unopened God Chests. Earn God XP or unlock a free chest slot on the Goal Web."
				empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				meta_catalog_box.add_child(empty)
			for index in ProgressionService.chest_inventory.size():
				var chest: Dictionary = ProgressionService.chest_inventory[index]
				var open_button := Button.new()
				open_button.text = "Open %s" % chest.get("name", "God Chest")
				open_button.custom_minimum_size.y = 56
				open_button.pressed.connect(func() -> void: ProgressionService.open_chest(index))
				meta_catalog_box.add_child(open_button)
		"perks":
			for perk in ContentRegistry.get_all(&"perks"):
				var count := int(ProgressionService.perk_inventory.get(String(perk.id), 0))
				var perk_label := Label.new()
				perk_label.text = "%s%s\n%s" % ["×%d  " % count if count > 0 else "", String(perk.name), String(perk.effect)]
				perk_label.modulate = Color.WHITE if count > 0 else Color(0.65, 0.65, 0.65, 1.0)
				perk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				meta_catalog_box.add_child(perk_label)
		"stats":
			var resources_heading := Label.new()
			resources_heading.text = "CURRENT REGION RESOURCE RATES"
			resources_heading.add_theme_color_override("font_color", Color("6fffd2"))
			meta_catalog_box.add_child(resources_heading)
			var snapshot := SimulationHost.get_snapshot()
			for resource_id in snapshot.resources:
				var amount := int(snapshot.resources.get(resource_id, 0))
				var rate := float(snapshot.resource_rates.get(resource_id, 0.0))
				if amount == 0 and is_zero_approx(rate):
					continue
				var resource_definition := ContentRegistry.get_by_id(&"resources", StringName(resource_id))
				var rate_label := Label.new()
				rate_label.text = "%s  %d / %d  •  %+.1f per day" % [resource_definition.get("name", String(resource_id).replace("_", " ").capitalize()), amount, int(snapshot.resource_caps.get(resource_id, 0)), rate]
				rate_label.add_theme_color_override("font_color", Color("70f0b8") if rate > 0.0 else (Color("ff8e82") if rate < 0.0 else Color.WHITE))
				meta_catalog_box.add_child(rate_label)
			var profile_heading := Label.new()
			profile_heading.text = "PROFILE STATISTICS"
			profile_heading.add_theme_color_override("font_color", Color("f4dc62"))
			meta_catalog_box.add_child(profile_heading)
			var counter_keys: Array = ProgressionService.counters.keys()
			counter_keys.sort()
			for counter_id in counter_keys:
				var counter_label := Label.new()
				counter_label.text = "%s  •  %d" % [String(counter_id).replace(".", " › ").replace("_", " ").capitalize(), int(ProgressionService.counters[counter_id])]
				counter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				meta_catalog_box.add_child(counter_label)

func _build_construction_drawer(parent: Control) -> Control:
	var drawer := PanelContainer.new()
	drawer.anchor_left = 1.0
	drawer.anchor_right = 1.0
	drawer.anchor_bottom = 1.0
	drawer.offset_left = -410
	drawer.offset_top = 82
	drawer.offset_right = -10
	drawer.offset_bottom = -96
	drawer.visible = false
	parent.add_child(drawer)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	drawer.add_child(outer)
	var heading := Label.new()
	heading.text = "CONSTRUCTION"
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("6fffd2"))
	outer.add_child(heading)
	var search := LineEdit.new()
	search.placeholder_text = "Search buildings"
	search.custom_minimum_size.y = 48
	search.text_changed.connect(_populate_build_catalog)
	outer.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	build_catalog_box = VBoxContainer.new()
	build_catalog_box.custom_minimum_size.x = 348
	build_catalog_box.add_theme_constant_override("separation", 6)
	scroll.add_child(build_catalog_box)
	_populate_build_catalog("")
	return drawer

func _populate_build_catalog(filter_text: String) -> void:
	if not build_catalog_box:
		return
	for child in build_catalog_box.get_children():
		child.queue_free()
	var query := filter_text.strip_edges().to_lower()
	var definitions: Array = ContentRegistry.get_all(&"buildings").duplicate()
	definitions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key := "%s:%s" % [a.get("category", "misc"), a.get("name", a.id)]
		var b_key := "%s:%s" % [b.get("category", "misc"), b.get("name", b.id)]
		return a_key < b_key)
	var previous_category := ""
	for definition in definitions:
		if String(definition.get("status", "")) == "legacy_removed":
			continue
		var name := String(definition.get("name", definition.id))
		var category := String(definition.get("category", "misc"))
		if not query.is_empty() and query not in name.to_lower() and query not in category.to_lower():
			continue
		if category != previous_category:
			var category_label := Label.new()
			category_label.text = category.replace("_", " ").to_upper()
			category_label.add_theme_color_override("font_color", Color("f4dc62"))
			category_label.add_theme_font_size_override("font_size", 16)
			build_catalog_box.add_child(category_label)
			previous_category = category
		var building_id := StringName(definition.id)
		var button := Button.new()
		button.icon = pixel_icons.building(building_id, StringName(category), 24)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.text = "%s  •  Tiers %d" % [name, int(definition.get("tiers", 1))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 50
		button.tooltip_text = "Cost: %s" % str(definition.get("cost", {}))
		button.pressed.connect(func() -> void:
			world_view.begin_placement(building_id)
			build_drawer.visible = false)
		build_catalog_box.add_child(button)

func _build_inspector_drawer(parent: Control) -> Control:
	var drawer := PanelContainer.new()
	drawer.anchor_left = 1.0
	drawer.anchor_right = 1.0
	drawer.anchor_bottom = 1.0
	drawer.offset_left = -360
	drawer.offset_top = 82
	drawer.offset_right = -10
	drawer.offset_bottom = -96
	drawer.visible = false
	parent.add_child(drawer)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	drawer.add_child(box)
	inspector_title = Label.new()
	inspector_title.add_theme_font_size_override("font_size", 25)
	inspector_title.add_theme_color_override("font_color", Color("6fffd2"))
	box.add_child(inspector_title)
	inspector_body = Label.new()
	inspector_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspector_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(inspector_body)
	inspector_upgrade_button = Button.new()
	inspector_upgrade_button.text = "Upgrade"
	inspector_upgrade_button.custom_minimum_size.y = 52
	inspector_upgrade_button.visible = false
	inspector_upgrade_button.pressed.connect(func() -> void:
		SimulationHost.submit(GameCommand.upgrade_building(SimulationHost.tick, selected_entity_id)))
	box.add_child(inspector_upgrade_button)
	inspector_recipe_button = Button.new()
	inspector_recipe_button.text = "Recipe"
	inspector_recipe_button.custom_minimum_size.y = 48
	inspector_recipe_button.visible = false
	inspector_recipe_button.pressed.connect(_cycle_selected_recipe)
	box.add_child(inspector_recipe_button)
	var production_actions := HBoxContainer.new()
	production_actions.add_theme_constant_override("separation", 6)
	box.add_child(production_actions)
	inspector_make_button = Button.new()
	inspector_make_button.text = "Make 8"
	inspector_make_button.visible = false
	inspector_make_button.pressed.connect(func() -> void: _set_selected_recipe_policy(&"make", 8))
	production_actions.add_child(inspector_make_button)
	inspector_maintain_button = Button.new()
	inspector_maintain_button.text = "Maintain 16"
	inspector_maintain_button.visible = false
	inspector_maintain_button.pressed.connect(func() -> void: _set_selected_recipe_policy(&"maintain", 16))
	production_actions.add_child(inspector_maintain_button)
	inspector_production_pause_button = Button.new()
	inspector_production_pause_button.text = "Pause"
	inspector_production_pause_button.visible = false
	inspector_production_pause_button.pressed.connect(func() -> void: _set_selected_recipe_policy(&"paused", 0))
	production_actions.add_child(inspector_production_pause_button)
	var service_actions := HBoxContainer.new()
	service_actions.add_theme_constant_override("separation", 6)
	box.add_child(service_actions)
	inspector_repair_button = Button.new()
	inspector_repair_button.text = "Prioritize Repair"
	inspector_repair_button.custom_minimum_size.y = 50
	inspector_repair_button.visible = false
	inspector_repair_button.pressed.connect(_toggle_selected_building_repair)
	service_actions.add_child(inspector_repair_button)
	inspector_dismantle_button = Button.new()
	inspector_dismantle_button.text = "Dismantle"
	inspector_dismantle_button.custom_minimum_size.y = 50
	inspector_dismantle_button.visible = false
	inspector_dismantle_button.pressed.connect(_request_selected_building_dismantle)
	service_actions.add_child(inspector_dismantle_button)
	inspector_capture_button = Button.new()
	inspector_capture_button.text = "Designate Ranger Capture"
	inspector_capture_button.custom_minimum_size.y = 50
	inspector_capture_button.visible = false
	inspector_capture_button.pressed.connect(_toggle_selected_animal_capture)
	box.add_child(inspector_capture_button)
	inspector_slaughter_button = Button.new()
	inspector_slaughter_button.text = "Designate Slaughter"
	inspector_slaughter_button.custom_minimum_size.y = 50
	inspector_slaughter_button.visible = false
	inspector_slaughter_button.pressed.connect(_toggle_selected_animal_slaughter)
	box.add_child(inspector_slaughter_button)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = 50
	close.pressed.connect(world_view.clear_selection)
	box.add_child(close)
	return drawer

func _build_spells_drawer(parent: Control) -> Control:
	var drawer := PanelContainer.new()
	drawer.anchor_left = 1.0
	drawer.anchor_right = 1.0
	drawer.anchor_bottom = 1.0
	drawer.offset_left = -410
	drawer.offset_top = 82
	drawer.offset_right = -10
	drawer.offset_bottom = -96
	drawer.visible = false
	parent.add_child(drawer)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	drawer.add_child(outer)
	var heading := Label.new()
	heading.text = "GOD POWERS"
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("7ddcff"))
	outer.add_child(heading)
	var search := LineEdit.new()
	search.placeholder_text = "Search powers"
	search.custom_minimum_size.y = 48
	search.text_changed.connect(_populate_spell_catalog)
	outer.add_child(search)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	spells_catalog_box = VBoxContainer.new()
	spells_catalog_box.custom_minimum_size.x = 348
	spells_catalog_box.add_theme_constant_override("separation", 6)
	scroll.add_child(spells_catalog_box)
	_populate_spell_catalog("")
	return drawer

func _populate_spell_catalog(filter_text: String) -> void:
	if not spells_catalog_box:
		return
	for child in spells_catalog_box.get_children():
		child.queue_free()
	var query := filter_text.strip_edges().to_lower()
	var definitions: Array = ContentRegistry.get_all(&"spells").duplicate()
	definitions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return "%s:%s" % [a.group, a.name] < "%s:%s" % [b.group, b.name])
	var previous_group := ""
	for definition in definitions:
		var name := String(definition.name)
		var group := String(definition.group)
		if not query.is_empty() and query not in name.to_lower() and query not in group.to_lower():
			continue
		if group != previous_group:
			var group_label := Label.new()
			group_label.text = group.to_upper()
			group_label.add_theme_color_override("font_color", Color("f4dc62"))
			spells_catalog_box.add_child(group_label)
			previous_group = group
		var spell_id := StringName(definition.id)
		var button := Button.new()
		button.icon = pixel_icons.spell(spell_id, StringName(group), 24)
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.text = "%s  •  %d Influence" % [name, int(definition.get("cost", 0))]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 50
		button.pressed.connect(func() -> void:
			world_view.begin_spell(spell_id)
			spells_drawer.visible = false)
		spells_catalog_box.add_child(button)

func _toggle_build_drawer() -> void:
	build_drawer.visible = not build_drawer.visible
	if build_drawer.visible:
		inspector_drawer.visible = false
		jobs_drawer.visible = false
		spells_drawer.visible = false
		regions_drawer.visible = false

func _toggle_spells_drawer() -> void:
	spells_drawer.visible = not spells_drawer.visible
	if spells_drawer.visible:
		inspector_drawer.visible = false
		jobs_drawer.visible = false
		build_drawer.visible = false
		regions_drawer.visible = false
		trade_drawer.visible = false
		meta_drawer.visible = false

func _on_entity_selected(kind: StringName, entity_id: int) -> void:
	if entity_id != selected_entity_id:
		dismantle_confirm_entity_id = 0
	selected_entity_kind = kind
	selected_entity_id = entity_id
	inspector_drawer.visible = not kind.is_empty() and entity_id > 0
	if inspector_drawer.visible:
		build_drawer.visible = false
		spells_drawer.visible = false
		regions_drawer.visible = false
		trade_drawer.visible = false
		meta_drawer.visible = false
		_update_inspector(SimulationHost.get_snapshot())

func _update_inspector(snapshot: SimulationSnapshot) -> void:
	if not inspector_drawer or not inspector_drawer.visible:
		return
	_hide_building_inspector_actions()
	if selected_entity_kind == &"building":
		for building in snapshot.buildings:
			if int(building.id) != selected_entity_id:
				continue
			inspector_title.text = String(building.name)
			var state := "Operating" if bool(building.completed) else "Construction %d%%" % roundi(float(building.progress) * 100.0 / maxf(1.0, float(building.build_time)))
			inspector_body.text = "Tier %d  •  %s\n%s\n\nHealth %d / %d\nFootprint %d × %d\nRecipe: %s" % [int(building.tier), String(building.category).replace("_", " ").capitalize(), state, int(building.health), int(building.max_health), int(building.width), int(building.height), String(building.get("active_recipe", "None")).capitalize()]
			var preview := SimulationHost.get_upgrade_preview(int(building.id))
			inspector_upgrade_button.visible = bool(building.completed) and not preview.is_empty()
			if inspector_upgrade_button.visible:
				inspector_upgrade_button.text = "Upgrade to %s\nCost: %s" % [preview.get("name", "Tier %d" % int(preview.tier)), str(preview.get("cost", {}))]
			var recipes := SimulationHost.get_recipes_for_building(int(building.id))
			var has_recipes := bool(building.completed) and not recipes.is_empty()
			inspector_recipe_button.visible = has_recipes
			inspector_make_button.visible = has_recipes
			inspector_maintain_button.visible = has_recipes
			inspector_production_pause_button.visible = has_recipes
			if has_recipes:
				var active_recipe := _active_recipe_definition(building, recipes)
				inspector_recipe_button.text = "Recipe: %s  •  Tap to change" % active_recipe.get("name", active_recipe.get("id", "Recipe"))
				var policy := String(building.get("recipe_mode", "maintain")).capitalize()
				var target := int(building.get("recipe_remaining", 0)) if policy == "Make" else int(building.get("recipe_target", 16))
				inspector_body.text += "\nProduction: %s %d\nInputs %s → Outputs %s" % [policy, target, str(active_recipe.get("inputs", {})), str(active_recipe.get("outputs", {}))]
			var definition := ContentRegistry.get_by_id(&"buildings", StringName(building.definition_id))
			if String(building.category) == "golems":
				var golem_definition: Dictionary = definition.get("golem", {})
				var charge_percent := roundi(float(building.get("operation_progress", 0)) * 100.0 / maxf(1.0, float(golem_definition.get("charge_ticks", 1))))
				inspector_body.text += "\n\nGolems %d / %d\nCore: %s\nCharge: %d%%" % [int(building.get("golem_count", 0)), int(building.get("golem_cap", int(building.tier))), String(building.get("operation_state", "idle")).replace("_", " ").capitalize(), clampi(charge_percent, 0, 100)]
			elif String(building.category) == "towers":
				var tower: Dictionary = definition.get("tower", {})
				var payload := "Energy %d/shot" % int(tower.get("energy_per_shot", 0)) if int(tower.get("energy_per_shot", 0)) > 0 else ("Ammo: %s (%d loaded)" % [String(tower.get("ammo", "none")).replace("_", " ").capitalize(), int(building.get("ammo_shots", 0))])
				inspector_body.text += "\n\nCombat: %s\nRange %d - %s\nDamage type: %s" % [String(building.get("combat_state", "idle")).replace("_", " ").capitalize(), int(tower.get("range", 0)), payload, String(tower.get("damage_type", "support")).replace("_", " ").capitalize()]
			inspector_repair_button.visible = bool(building.completed) and int(building.health) < int(building.max_health) and not bool(building.get("dismantle_designated", false))
			inspector_repair_button.text = "Use Normal Priority" if bool(building.get("repair_designated", false)) else "Prioritize Repair"
			inspector_dismantle_button.visible = not bool(building.get("destroyed", false))
			if bool(building.get("dismantle_designated", false)):
				inspector_dismantle_button.text = "Cancel Dismantling"
			elif dismantle_confirm_entity_id == int(building.id):
				inspector_dismantle_button.text = "Confirm Dismantle"
			else:
				inspector_dismantle_button.text = "Dismantle"
			var service_state := String(building.get("service_state", "none"))
			if service_state != "none":
				inspector_body.text += "\n\nMaintenance: %s" % service_state.replace("_", " ").capitalize()
			if bool(building.get("dismantle_designated", false)):
				var maintenance_service: Dictionary = ContentRegistry.get_by_id(&"buildings", &"maintenance_building").get("service", {})
				var dismantle_target := maxi(int(maintenance_service.get("dismantle_min_ticks", 60)), int(building.build_time) / int(maintenance_service.get("dismantle_build_time_divisor", 3)))
				inspector_body.text += " %d%%" % clampi(roundi(float(building.get("dismantle_progress", 0)) * 100.0 / float(dismantle_target)), 0, 100)
			return
	elif selected_entity_kind == &"villager":
		for villager in snapshot.villagers:
			if int(villager.id) != selected_entity_id:
				continue
			inspector_title.text = String(villager.name)
			inspector_body.text = "%s  •  %s\n\nHealth %d / 1000\nHunger %d\nThirst %d\nEnergy %d\nFaith %d\n\nTask: %s" % [String(villager.job).replace("_", " ").capitalize(), String(villager.state).capitalize(), int(villager.health), int(villager.hunger), int(villager.thirst), int(villager.energy), int(villager.faith), String(villager.get("task_kind", "None")).capitalize()]
			if not villager.get("status_effects", {}).is_empty():
				inspector_body.text += "\nConditions: %s" % str(villager.status_effects)
			if String(villager.get("medical_state", "")).length() > 0:
				inspector_body.text += "\nMedical: %s" % String(villager.medical_state).replace("_", " ").capitalize()
			var equipment: Dictionary = villager.get("equipment", {})
			if not equipment.is_empty():
				inspector_body.text += "\n\nEquipment"
				for slot in ["weapon", "tool", "ammo", "body", "helmet", "shield"]:
					var item: Dictionary = equipment.get(slot, {})
					if item.is_empty():
						continue
					var item_detail := "%d shots" % int(item.get("shots", 0)) if slot == "ammo" else "%d/%d" % [int(item.get("durability", 0)), int(item.get("max_durability", 0))]
					inspector_body.text += "\n%s: %s (%s)" % [slot.capitalize(), String(item.get("id", "")).replace("_", " ").capitalize(), item_detail]
			return
	elif selected_entity_kind == &"animal":
		for animal in snapshot.animals:
			if int(animal.id) != selected_entity_id:
				continue
			var animal_type := String(animal.definition_id)
			var domestic_state := "Domesticated" if bool(animal.get("domesticated", false)) else "Wild"
			var home_label := "None"
			for building in snapshot.buildings:
				if int(building.id) == int(animal.get("home_id", 0)):
					home_label = String(building.name)
					break
			var capacity_label := "%d pens  •  %d coops  •  %d Doggo homes" % [snapshot.animal_pen_capacity, snapshot.clucker_coop_capacity, snapshot.doggo_house_capacity]
			inspector_title.text = String(animal.get("name", animal_type.replace("_", " ").capitalize()))
			inspector_body.text = "%s  •  %s  •  %s\n%s\n\nHealth %d\nHunger %d\nThirst %d\nHome: %s\n%s" % [domestic_state, String(animal.get("age_stage", "adult")).capitalize(), String(animal.get("sex", "unknown")).capitalize(), String(animal.get("state", "wandering")).replace("_", " ").capitalize(), int(animal.health), int(animal.hunger), int(animal.thirst), home_label, capacity_label]
			if int(animal.get("pregnant_ticks", 0)) > 0:
				inspector_body.text += "\nPregnancy: %d%%" % clampi(100 - roundi(float(animal.pregnant_ticks) * 100.0 / float(SimulationHost.TICKS_PER_DAY * 2)), 0, 100)
			var doggo := animal_type in ["doggo", "doofy_doggo"]
			inspector_capture_button.visible = not bool(animal.get("domesticated", false)) and not doggo
			inspector_slaughter_button.visible = bool(animal.get("domesticated", false)) and not doggo
			inspector_capture_button.text = "Cancel Ranger Capture" if bool(animal.get("capture_designated", false)) else "Designate Ranger Capture"
			inspector_slaughter_button.text = "Cancel Slaughter" if bool(animal.get("slaughter_designated", false)) else "Designate Slaughter"
			return
	elif selected_entity_kind == &"golem":
		for golem in snapshot.golems:
			if int(golem.id) != selected_entity_id:
				continue
			var source_label := "Divine summon" if bool(golem.get("summoned", false)) else "Combobulator #%d" % int(golem.get("source_building_id", 0))
			inspector_title.text = String(golem.name)
			inspector_body.text = "%s\n%s\n\nHealth %d / %d\nDamage %d\nMaintenance %d influence\n\nRoles: %s" % [String(golem.state).replace("_", " ").capitalize(), source_label, int(golem.health), int(golem.max_health), int(golem.damage), int(golem.get("maintenance", 0)), str(ContentRegistry.get_by_id(&"actors", StringName(golem.definition_id)).get("roles", []))]
			return
	elif selected_entity_kind == &"monster":
		for monster in snapshot.monsters:
			if int(monster.id) != selected_entity_id:
				continue
			var actor := ContentRegistry.get_by_id(&"actors", StringName(monster.definition_id))
			var combat: Dictionary = actor.get("combat", {})
			inspector_title.text = String(monster.name)
			inspector_body.text = "%s\n\nHealth %d / %d\nDamage %d %s\nAttack recovery %d ticks\nSpeed %.3f\n\nResistances: %s" % [String(monster.state).replace("_", " ").capitalize(), int(monster.health), int(monster.max_health), int(monster.damage), String(monster.get("damage_type", "regular")).replace("_", " ").capitalize(), int(monster.get("attack_reload", 0)), float(monster.speed), str(combat.get("resistances", {}))]
			return

func _hide_building_inspector_actions() -> void:
	inspector_upgrade_button.visible = false
	inspector_recipe_button.visible = false
	inspector_make_button.visible = false
	inspector_maintain_button.visible = false
	inspector_production_pause_button.visible = false
	inspector_repair_button.visible = false
	inspector_dismantle_button.visible = false
	inspector_capture_button.visible = false
	inspector_slaughter_button.visible = false

func _selected_building() -> Dictionary:
	for building in SimulationHost.buildings:
		if int(building.id) == selected_entity_id:
			return building
	return {}

func _selected_animal() -> Dictionary:
	for animal in SimulationHost.animals:
		if int(animal.id) == selected_entity_id:
			return animal
	return {}

func _toggle_selected_building_repair() -> void:
	var building := _selected_building()
	if building.is_empty():
		return
	SimulationHost.submit(GameCommand.set_building_work(SimulationHost.tick, selected_entity_id, &"prioritize_repair", not bool(building.get("repair_designated", false))))

func _request_selected_building_dismantle() -> void:
	var building := _selected_building()
	if building.is_empty():
		return
	if bool(building.get("dismantle_designated", false)):
		SimulationHost.submit(GameCommand.set_building_work(SimulationHost.tick, selected_entity_id, &"dismantle", false))
		dismantle_confirm_entity_id = 0
		return
	if dismantle_confirm_entity_id != selected_entity_id:
		dismantle_confirm_entity_id = selected_entity_id
		inspector_dismantle_button.text = "Confirm Dismantle"
		_show_toast("Tap Confirm Dismantle to salvage this building.")
		return
	SimulationHost.submit(GameCommand.set_building_work(SimulationHost.tick, selected_entity_id, &"dismantle", true))
	dismantle_confirm_entity_id = 0

func _toggle_selected_animal_capture() -> void:
	var animal := _selected_animal()
	if animal.is_empty():
		return
	SimulationHost.submit(GameCommand.designate_animal_capture(SimulationHost.tick, selected_entity_id, not bool(animal.get("capture_designated", false))))

func _toggle_selected_animal_slaughter() -> void:
	var animal := _selected_animal()
	if animal.is_empty():
		return
	SimulationHost.submit(GameCommand.designate_animal_slaughter(SimulationHost.tick, selected_entity_id, not bool(animal.get("slaughter_designated", false))))

func _active_recipe_definition(building: Dictionary, recipes: Array[Dictionary]) -> Dictionary:
	for recipe in recipes:
		if String(recipe.id) == String(building.get("active_recipe", "")):
			return recipe
	return recipes[0] if not recipes.is_empty() else {}

func _cycle_selected_recipe() -> void:
	var building := _selected_building()
	var recipes := SimulationHost.get_recipes_for_building(selected_entity_id)
	if building.is_empty() or recipes.is_empty():
		return
	var current_index := -1
	for index in recipes.size():
		if String(recipes[index].id) == String(building.get("active_recipe", "")):
			current_index = index
			break
	var next_recipe: Dictionary = recipes[(current_index + 1) % recipes.size()]
	SimulationHost.submit(GameCommand.set_recipe_policy(SimulationHost.tick, selected_entity_id, StringName(next_recipe.id), &"maintain", 16))

func _set_selected_recipe_policy(policy: StringName, target: int) -> void:
	var building := _selected_building()
	var recipes := SimulationHost.get_recipes_for_building(selected_entity_id)
	if building.is_empty() or recipes.is_empty():
		return
	var recipe := _active_recipe_definition(building, recipes)
	SimulationHost.submit(GameCommand.set_recipe_policy(SimulationHost.tick, selected_entity_id, StringName(recipe.id), policy, target))

func _change_job(job_id: StringName, delta: int) -> void:
	var state: Dictionary = SimulationHost.jobs.get(String(job_id), {})
	SimulationHost.submit(GameCommand.set_job_desired(SimulationHost.tick, job_id, int(state.get("desired", 0)) + delta))

func _show_screen(screen: StringName) -> void:
	mode_screen.visible = screen == &"mode_select"
	custom_screen.visible = screen == &"custom_mode"
	world_screen.visible = screen == &"world_map"
	map_editor_screen.visible = screen == &"map_editor"
	hud.visible = screen == &"play"
	world_view.visible = screen == &"play"
	if screen == &"play":
		world_view.queue_redraw()
	elif screen == &"world_map":
		_refresh_selected_region()
	_refresh_tutorial()

func _on_snapshot(snapshot: SimulationSnapshot) -> void:
	if not hud:
		return
	population_label.text = "Pop %d • Kids %d • Homes %d/%d" % [snapshot.population, snapshot.population_groups.get("children", 0), mini(snapshot.population, snapshot.housing_capacity), snapshot.housing_capacity]
	resource_label.text = "W%d/%d R%d/%d F%d H₂O%d C%d" % [snapshot.resources.get("wood", 0), snapshot.resource_caps.get("wood", 0), snapshot.resources.get("rock", 0), snapshot.resource_caps.get("rock", 0), snapshot.resources.get("raw_vegetables", 0), snapshot.resources.get("clean_water", 0), snapshot.resources.get("crystal", 0)]
	influence_label.text = "I %d/%d • XP %d" % [snapshot.influence, snapshot.max_influence, snapshot.god_xp]
	if not snapshot.monsters.is_empty():
		influence_label.text += "  •  Threat %d" % snapshot.monsters.size()
	var phase := _day_phase(snapshot.day_fraction)
	time_label.text = "%s D%d • %s • %d°C • %s" % [snapshot.season, snapshot.day, phase, snapshot.temperature_c, String(snapshot.weather).capitalize()]
	if not snapshot.active_event.is_empty():
		time_label.text += " • %s" % String(snapshot.active_event).replace("_", " ").capitalize()
	event_icon.visible = not snapshot.active_event.is_empty()
	if event_icon.visible:
		event_icon.texture = pixel_icons.event(snapshot.active_event, 24)
		event_icon.tooltip_text = "%s: %d ticks remaining" % [String(snapshot.active_event).replace("_", " ").capitalize(), snapshot.event_ticks_remaining]
	pause_button.text = "▶" if snapshot.paused else "Ⅱ"
	var goal: Dictionary = snapshot.goals.get("build_first_camp", {})
	goal_label.text = ("✓ GOAL COMPLETE\n%s  •  +%d God XP" if goal.get("completed", false) else "YOU ALREADY LOST\n%s  •  God XP %d") % [goal.get("description", "Build your first Camp."), goal.get("xp", 60)]
	goal_label.add_theme_color_override("font_color", Color("70f0b8") if goal.get("completed", false) else Color("fff4cf"))
	for job_id in job_rows:
		var state: Dictionary = snapshot.jobs.get(job_id, {})
		job_rows[job_id].text = "%d / %d" % [state.get("current", 0), state.get("max", 0)]
	_update_inspector(snapshot)
	_refresh_tutorial()
	AudioDirector.set_music_intensity(clampf(float(snapshot.monsters.size()) / 24.0, 0.0, 1.0))
	AudioDirector.set_corruption_intensity(clampf(float(snapshot.corruption_cells.size()) / 1200.0, 0.0, 1.0))

func _day_phase(fraction: float) -> String:
	if fraction < 0.12: return "Dawn"
	if fraction < 0.30: return "Morning"
	if fraction < 0.52: return "Midday"
	if fraction < 0.68: return "Evening"
	if fraction < 0.78: return "Dusk"
	return "Night"

func _on_sim_event(event: SimEvent) -> void:
	if event.type == &"goal_completed":
		_show_toast("Goal complete!  +%d God XP" % event.data.get("xp", 0))
	elif event.type == &"building_placed":
		if String(event.data.get("definition_id", "")) == "camp":
			ProgressionService.complete_tutorial(&"place_camp")
		_refresh_tutorial()
	elif event.type == &"building_completed":
		var definition := ContentRegistry.get_by_id(&"buildings", StringName(event.data.get("definition_id", "")))
		_show_toast("%s completed." % definition.get("name", "Building"))
		_refresh_tutorial()
	elif event.type == &"building_repaired":
		_show_toast("Building fully repaired.")
	elif event.type == &"building_dismantled":
		_show_toast("Building dismantled; usable materials were salvaged.")
		if int(event.data.get("building_id", 0)) == selected_entity_id:
			world_view.clear_selection()
	elif event.type == &"patient_treated":
		_show_toast("Patient treated with %s." % String(event.data.get("medicine", "medicine")).replace("_", " ").capitalize())
	elif event.type == &"spell_cast":
		world_view.add_spell_effect(
			StringName(event.data.get("spell_id", "")),
			Vector2i(int(event.data.get("cell_x", 0)), int(event.data.get("cell_y", 0))),
			float(event.data.get("radius", 4.0)))
	elif event.type == &"event_started":
		_show_toast("Incoming event: %s" % String(event.data.get("event_id", "event")).replace("_", " ").capitalize())
	elif event.type == &"catjeet_arrived":
		_show_toast("A Catjeet caravan has arrived at the Marketplace.")
		if trade_drawer.visible:
			_populate_trade_drawer()
	elif event.type == &"catjeet_departed":
		_show_toast("The Catjeet caravan has departed.")
		if trade_drawer.visible:
			_populate_trade_drawer()
	elif event.type == &"trade_completed":
		var direction := String(event.data.get("direction", "trade")).capitalize()
		var resource_name := String(event.data.get("resource_id", "resource")).replace("_", " ").capitalize()
		_show_toast("%s %d %s." % [direction, int(event.data.get("amount", 0)), resource_name])

func _on_achievement_completed(_achievement_id: StringName, definition: Dictionary) -> void:
	AudioDirector.play_cue(&"achievement_completed")
	_show_toast("Achievement complete: %s" % definition.get("name", "Achievement"))

func _on_placement_changed(building_id: StringName) -> void:
	if building_id.is_empty():
		placement_label.text = "Drag to pan • Pinch or wheel to zoom"
	else:
		var definition := ContentRegistry.get_by_id(&"buildings", building_id)
		placement_label.text = "Placing %s • Tap terrain to confirm" % definition.get("name", building_id)

func _on_spell_changed(spell_id: StringName) -> void:
	if spell_id.is_empty():
		if world_view.pending_building_id.is_empty():
			placement_label.text = "Drag to pan • Pinch or wheel to zoom"
		return
	var definition := ContentRegistry.get_by_id(&"spells", spell_id)
	placement_label.text = "Targeting %s • Tap world to cast • Cost %d" % [definition.get("name", spell_id), int(definition.get("cost", 0))]

func _show_toast(message: String) -> void:
	if not toast_label:
		return
	toast_label.text = message
	toast_label.visible = true
	var tween := create_tween()
	toast_label.modulate.a = 1.0
	tween.tween_interval(2.0)
	tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void: toast_label.visible = false)

func _label(text: String, size: int) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return result

func _set_pixel_button_icon(button: Button, texture: Texture2D) -> void:
	button.icon = texture
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _add_hud_pixel_icon(row: HBoxContainer, icon_id: StringName) -> void:
	var icon := TextureRect.new()
	icon.texture = pixel_icons.ui(icon_id, 24)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
