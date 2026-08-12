class_name TaskBoard
extends RefCounted

## Deterministic global work queue. Tasks have stable string keys so rebuilding the
## board never invalidates a villager's reservation unless its target disappears.

var tasks: Dictionary = {}
var key_to_id: Dictionary = {}
var next_task_id := 1

func reset() -> void:
	tasks.clear()
	key_to_id.clear()
	next_task_id = 1

func upsert(key: String, definition: Dictionary) -> int:
	if key_to_id.has(key):
		var existing_id: int = int(key_to_id[key])
		var claims: Array = tasks[existing_id].get("claimed_by", []).duplicate()
		var updated := definition.duplicate(true)
		updated["id"] = existing_id
		updated["key"] = key
		updated["claimed_by"] = claims
		tasks[existing_id] = updated
		return existing_id
	var task_id := next_task_id
	next_task_id += 1
	var created := definition.duplicate(true)
	created["id"] = task_id
	created["key"] = key
	created["claimed_by"] = []
	tasks[task_id] = created
	key_to_id[key] = task_id
	return task_id

func prune(active_keys: Dictionary) -> void:
	var removed: Array[int] = []
	for task_id in tasks:
		if not active_keys.has(String(tasks[task_id].key)):
			removed.append(int(task_id))
	for task_id in removed:
		key_to_id.erase(String(tasks[task_id].key))
		tasks.erase(task_id)

func claim_best(villager_id: int, job_id: String, position: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_score := INF
	var ids: Array = tasks.keys()
	ids.sort()
	for task_id in ids:
		var task: Dictionary = tasks[task_id]
		if String(task.get("job_id", "")) != job_id:
			continue
		var claims: Array = task.get("claimed_by", [])
		if claims.size() >= int(task.get("max_claims", 1)):
			continue
		var dx := float(task.get("x", 0.0)) - position.x
		var dy := float(task.get("y", 0.0)) - position.y
		var score := dx * dx + dy * dy - float(task.get("priority", 0)) * 1000000.0 + float(task_id) * 0.000001
		if score < best_score:
			best_score = score
			best = task
	if not best.is_empty():
		var selected_id := int(best.id)
		tasks[selected_id].claimed_by.append(villager_id)
		best = tasks[selected_id]
	return best

func get_task(task_id: int) -> Dictionary:
	return tasks.get(task_id, {})

func release(villager_id: int, task_id: int) -> void:
	if not tasks.has(task_id):
		return
	var claims: Array = tasks[task_id].claimed_by
	claims.erase(villager_id)

func export_state() -> Dictionary:
	return {
		"next_task_id": next_task_id,
		"tasks": tasks.duplicate(true),
		"key_to_id": key_to_id.duplicate(true),
	}

func import_state(state: Dictionary) -> void:
	next_task_id = int(state.get("next_task_id", 1))
	tasks = state.get("tasks", {}).duplicate(true)
	key_to_id = state.get("key_to_id", {}).duplicate(true)
	# JSON object keys become strings; normalize task IDs back to integers.
	var normalized: Dictionary = {}
	for key in tasks:
		normalized[int(key)] = tasks[key]
	tasks = normalized

func debug_summary() -> Dictionary:
	var result := {"total": tasks.size(), "claimed": 0, "by_kind": {}}
	for task in tasks.values():
		result.claimed += task.get("claimed_by", []).size()
		var kind := String(task.get("kind", "unknown"))
		result.by_kind[kind] = int(result.by_kind.get(kind, 0)) + 1
	return result
