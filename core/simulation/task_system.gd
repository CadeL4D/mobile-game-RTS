class_name TaskSystem
extends RefCounted

## Coordinates the global simulation task board, priority scoring,
## worker assignment, duplicate claim prevention, and failure recovery.

var next_task_id: int = 1
var active_tasks: Dictionary = {} # task_id (int) -> Dictionary
var claimed_tasks: Dictionary = {} # task_id (int) -> worker_id (int)
var tasks_by_dedupe_key: Dictionary = {} # String -> task_id (int)
var reservation_service: RefCounted

func bind_reservation_service(service: RefCounted) -> void:
	reservation_service = service

func clear() -> void:
	next_task_id = 1
	active_tasks.clear()
	claimed_tasks.clear()
	tasks_by_dedupe_key.clear()

func post_task(
	kind: StringName,
	target_pos: Vector2i,
	target_id: int = 0,
	priority: int = 0,
	data: Dictionary = {}
) -> Dictionary:
	var dedupe_key := String(data.get("dedupe_key", ""))
	if not dedupe_key.is_empty() and tasks_by_dedupe_key.has(dedupe_key):
		var existing_id := int(tasks_by_dedupe_key[dedupe_key])
		if active_tasks.has(existing_id):
			var existing: Dictionary = active_tasks[existing_id]
			existing.target_pos_x = target_pos.x
			existing.target_pos_y = target_pos.y
			existing.target_id = target_id
			existing.priority = priority
			existing.data = data.duplicate(true)
			return existing
		tasks_by_dedupe_key.erase(dedupe_key)
	var task_id := next_task_id
	next_task_id += 1
	var task := {
		"id": task_id,
		"kind": String(kind),
		"target_pos_x": target_pos.x,
		"target_pos_y": target_pos.y,
		"target_id": target_id,
		"priority": priority,
		"data": data.duplicate(true),
		"claimed_by": 0,
		"dedupe_key": dedupe_key
	}
	active_tasks[task_id] = task
	if not dedupe_key.is_empty():
		tasks_by_dedupe_key[dedupe_key] = task_id
	return task

func claim_best_task(
	worker: Dictionary,
	worker_pos: Vector2i,
	job_id: StringName,
	allowed_tasks: Array[StringName]
) -> Dictionary:
	var worker_id := int(worker.get("id", 0))
	var best_task: Dictionary = {}
	var best_score := -999999.0

	for task_id in active_tasks:
		if claimed_tasks.has(task_id):
			continue
		var task: Dictionary = active_tasks[task_id]
		var task_kind := StringName(task.get("kind", ""))
		if not allowed_tasks.has(task_kind):
			continue

		var tpos := Vector2i(int(task.get("target_pos_x", 0)), int(task.get("target_pos_y", 0)))
		var dist := Vector2(worker_pos).distance_to(Vector2(tpos))
		var priority := int(task.get("priority", 0))

		# Priority heavily weighs above distance
		var score := float(priority * 100) - dist
		if score > best_score:
			best_score = score
			best_task = task

	if not best_task.is_empty():
		var chosen_id: int = best_task.id
		best_task.claimed_by = worker_id
		claimed_tasks[chosen_id] = worker_id

	return best_task

func release_task(task_id: int, completed: bool = false) -> void:
	claimed_tasks.erase(task_id)
	if completed:
		_remove_dedupe_index(active_tasks.get(task_id, {}))
		active_tasks.erase(task_id)
	elif active_tasks.has(task_id):
		active_tasks[task_id].claimed_by = 0

func cancel_tasks_for_target(target_id: int) -> void:
	var to_remove: Array[int] = []
	for task_id in active_tasks:
		if int(active_tasks[task_id].get("target_id", 0)) == target_id:
			to_remove.append(task_id)
	for tid in to_remove:
		_remove_dedupe_index(active_tasks.get(tid, {}))
		claimed_tasks.erase(tid)
		active_tasks.erase(tid)

func cancel_tasks_for_worker(worker_id: int) -> void:
	var task_ids: Array = claimed_tasks.keys()
	for task_id in task_ids:
		if claimed_tasks[task_id] == worker_id:
			if active_tasks.has(task_id):
				active_tasks[task_id].claimed_by = 0
			claimed_tasks.erase(task_id)
	if reservation_service != null:
		reservation_service.cancel_all_for_requester(worker_id)

func _remove_dedupe_index(task: Dictionary) -> void:
	var dedupe_key := String(task.get("dedupe_key", ""))
	if not dedupe_key.is_empty() and int(tasks_by_dedupe_key.get(dedupe_key, 0)) == int(task.get("id", 0)):
		tasks_by_dedupe_key.erase(dedupe_key)

func export_state() -> Dictionary:
	var task_list: Array[Dictionary] = []
	for task_id in active_tasks:
		task_list.append(active_tasks[task_id].duplicate(true))
	return {
		"next_task_id": next_task_id,
		"tasks": task_list,
		"claimed": claimed_tasks.duplicate(true)
	}

func import_state(data: Dictionary) -> void:
	clear()
	next_task_id = int(data.get("next_task_id", 1))
	for task in data.get("tasks", []):
		var tid := int(task.get("id", 0))
		if tid <= 0:
			continue
		active_tasks[tid] = task.duplicate(true)
		var dedupe_key := String(task.get("dedupe_key", ""))
		if not dedupe_key.is_empty():
			tasks_by_dedupe_key[dedupe_key] = tid
		next_task_id = maxi(next_task_id, tid + 1)
	for tid_str in data.get("claimed", {}):
		var tid := int(tid_str)
		if active_tasks.has(tid):
			claimed_tasks[tid] = int(data.claimed[tid_str])
