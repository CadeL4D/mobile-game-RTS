extends Node

signal statistic_changed(counter: StringName, value: int)
signal achievement_completed(achievement_id: StringName, definition: Dictionary)
signal god_xp_changed(value: int)
signal chest_added(chest: Dictionary)
signal chest_opened(chest: Dictionary, perk: Dictionary)
signal tutorial_changed(tutorial_id: StringName)

var counters: Dictionary = {}
var completed: Dictionary = {}
var rules_by_counter: Dictionary = {}
var rules_by_achievement: Dictionary = {}
var god_xp := 0
var chest_inventory: Array[Dictionary] = []
var perk_inventory: Dictionary = {}
var next_chest_xp := 250
var next_chest_id := 1
var chest_rng := RandomNumberGenerator.new()
var completed_tutorials: Dictionary = {}
var tutorials_disabled := false

func _ready() -> void:
	chest_rng.seed = 0xC0D3C0DE
	if not ContentRegistry.content_loaded.is_connected(_on_content_loaded):
		ContentRegistry.content_loaded.connect(_on_content_loaded)
	_rebuild_rules()

func _on_content_loaded(_report: Dictionary) -> void:
	_rebuild_rules()

func _rebuild_rules() -> void:
	rules_by_counter.clear()
	rules_by_achievement.clear()
	for rule in ContentRegistry.get_all(&"achievement_rules"):
		var counter := String(rule.counter)
		if not rules_by_counter.has(counter):
			rules_by_counter[counter] = []
		rules_by_counter[counter].append(rule)
		rules_by_achievement[String(rule.achievement_id)] = rule

func _chest_interval() -> int:
	var definition := ContentRegistry.get_by_id(&"meta_progression", &"profile_meta_v1")
	return maxi(1, int(definition.get("chest_xp_interval", 250)))

func add_god_xp(amount: int) -> void:
	if amount <= 0:
		return
	god_xp += amount
	while god_xp >= next_chest_xp:
		grant_chest(1)
		next_chest_xp += _chest_interval()
	god_xp_changed.emit(god_xp)

func set_god_xp(value: int) -> void:
	god_xp = maxi(0, value)
	next_chest_xp = maxi(_chest_interval(), int(ceil(float(god_xp + 1) / float(_chest_interval()))) * _chest_interval())
	god_xp_changed.emit(god_xp)

func grant_chest(tier: int = 1) -> Dictionary:
	var safe_tier := clampi(tier, 1, 5)
	var chest := {
		"id": "profile_chest_%d" % next_chest_id,
		"tier": safe_tier,
		"name": "Tier %d Chest" % safe_tier,
	}
	next_chest_id += 1
	chest_inventory.append(chest)
	chest_added.emit(chest.duplicate(true))
	return chest

func open_chest(index: int) -> Dictionary:
	if index < 0 or index >= chest_inventory.size():
		return {}
	var perks: Array = ContentRegistry.get_all(&"perks")
	if perks.is_empty():
		return {}
	var chest: Dictionary = chest_inventory[index].duplicate(true)
	var perk: Dictionary = perks[chest_rng.randi_range(0, perks.size() - 1)]
	var perk_id := String(perk.id)
	perk_inventory[perk_id] = int(perk_inventory.get(perk_id, 0)) + 1
	chest_inventory.remove_at(index)
	chest_opened.emit(chest, perk)
	return perk

func get_modifier(stat_id: StringName) -> float:
	var total := 0.0
	for perk_id in perk_inventory:
		var perk := ContentRegistry.get_by_id(&"perks", StringName(perk_id))
		var modifier: Dictionary = perk.get("modifier", {})
		if String(modifier.get("stat", "")) == String(stat_id):
			total += float(modifier.get("amount", 0.0)) * int(perk_inventory[perk_id])
	return total

func get_goal_nodes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for achievement in ContentRegistry.get_all(&"achievements"):
		var achievement_id := String(achievement.id)
		var rule: Dictionary = rules_by_achievement.get(achievement_id, {})
		var progress := 1 if completed.has(achievement_id) else 0
		var target := 1
		if not rule.is_empty():
			progress = int(counters.get(String(rule.counter), 0))
			target = int(rule.target)
		result.append({
			"id": achievement_id,
			"name": String(achievement.name),
			"description": String(achievement.description),
			"progress": mini(progress, target),
			"target": target,
			"completed": completed.has(achievement_id),
			"bound": not rule.is_empty(),
		})
	return result

func complete_tutorial(tutorial_id: StringName) -> void:
	if tutorial_id.is_empty():
		return
	completed_tutorials[String(tutorial_id)] = true
	tutorial_changed.emit(tutorial_id)

func is_tutorial_completed(tutorial_id: StringName) -> bool:
	return tutorials_disabled or completed_tutorials.has(String(tutorial_id))

func skip_all_tutorials() -> void:
	tutorials_disabled = true
	tutorial_changed.emit(&"")

func reset_tutorials() -> void:
	completed_tutorials.clear()
	tutorials_disabled = false
	tutorial_changed.emit(&"")

func record(counter: StringName, amount: int = 1) -> void:
	var key := String(counter)
	counters[key] = int(counters.get(key, 0)) + amount
	statistic_changed.emit(counter, int(counters[key]))
	_evaluate_counter(key)

func set_counter(counter: StringName, value: int) -> void:
	var key := String(counter)
	counters[key] = maxi(0, value)
	statistic_changed.emit(counter, int(counters[key]))
	_evaluate_counter(key)

func _evaluate_counter(counter: String) -> void:
	for rule in rules_by_counter.get(counter, []):
		var achievement_id := String(rule.achievement_id)
		if completed.has(achievement_id) or int(counters.get(counter, 0)) < int(rule.target):
			continue
		completed[achievement_id] = {"completed": true, "completed_unix": int(Time.get_unix_time_from_system())}
		achievement_completed.emit(StringName(achievement_id), ContentRegistry.get_by_id(&"achievements", StringName(achievement_id)))

func get_progress(achievement_id: StringName) -> Dictionary:
	for rule in ContentRegistry.get_all(&"achievement_rules"):
		if String(rule.achievement_id) == String(achievement_id):
			return {"value": int(counters.get(String(rule.counter), 0)), "target": int(rule.target), "completed": completed.has(String(achievement_id))}
	return {"value": 1 if completed.has(String(achievement_id)) else 0, "target": 1, "completed": completed.has(String(achievement_id))}

func export_state() -> Dictionary:
	return {
		"counters": counters.duplicate(true),
		"completed": completed.duplicate(true),
		"god_xp": god_xp,
		"chest_inventory": chest_inventory.duplicate(true),
		"perk_inventory": perk_inventory.duplicate(true),
		"next_chest_xp": next_chest_xp,
		"next_chest_id": next_chest_id,
		"chest_rng_state": chest_rng.state,
		"completed_tutorials": completed_tutorials.duplicate(true),
		"tutorials_disabled": tutorials_disabled,
	}

func import_state(state: Dictionary) -> void:
	counters = state.get("counters", {}).duplicate(true)
	completed = state.get("completed", {}).duplicate(true)
	god_xp = int(state.get("god_xp", 0))
	chest_inventory.clear()
	for chest in state.get("chest_inventory", []):
		if chest is Dictionary:
			chest_inventory.append(chest.duplicate(true))
	perk_inventory = state.get("perk_inventory", {}).duplicate(true)
	next_chest_xp = int(state.get("next_chest_xp", _chest_interval()))
	next_chest_id = int(state.get("next_chest_id", chest_inventory.size() + 1))
	chest_rng.state = int(state.get("chest_rng_state", chest_rng.state))
	completed_tutorials = state.get("completed_tutorials", {}).duplicate(true)
	tutorials_disabled = bool(state.get("tutorials_disabled", false))
	god_xp_changed.emit(god_xp)

func reset_profile_progress() -> void:
	counters.clear()
	completed.clear()
	god_xp = 0
	chest_inventory.clear()
	perk_inventory.clear()
	next_chest_xp = _chest_interval()
	next_chest_id = 1
	chest_rng.seed = 0xC0D3C0DE
	completed_tutorials.clear()
	tutorials_disabled = false
	god_xp_changed.emit(god_xp)
