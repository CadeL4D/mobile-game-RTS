class_name PhysicalInventory
extends RefCounted

## Manages authoritative physical commodity stacks and unique item instances
## with exact location state invariants, incremental cached totals, and container buffers.

enum LocationState {
	GROUND,
	CONTAINER,
	CARRIER,
	TRANSIT,
	DESTROYED
}

class CommodityStack:
	var id: int = 0
	var resource_id: StringName = &""
	var quantity: int = 0
	var max_stack: int = 100
	var location_state: LocationState = LocationState.GROUND
	var grid_cell: Vector2i = Vector2i.ZERO
	var container_id: int = 0
	var carrier_id: int = 0
	var decay_ticks: int = -1

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"resource_id": String(resource_id),
			"quantity": quantity,
			"max_stack": max_stack,
			"location_state": int(location_state),
			"cell_x": grid_cell.x,
			"cell_y": grid_cell.y,
			"container_id": container_id,
			"carrier_id": carrier_id,
			"decay_ticks": decay_ticks
		}

	static func from_dict(data: Dictionary) -> CommodityStack:
		var stack := CommodityStack.new()
		stack.id = int(data.get("id", 0))
		stack.resource_id = StringName(data.get("resource_id", ""))
		stack.quantity = int(data.get("quantity", 0))
		stack.max_stack = int(data.get("max_stack", 100))
		stack.location_state = data.get("location_state", LocationState.GROUND) as LocationState
		stack.grid_cell = Vector2i(int(data.get("cell_x", 0)), int(data.get("cell_y", 0)))
		stack.container_id = int(data.get("container_id", 0))
		stack.carrier_id = int(data.get("carrier_id", 0))
		stack.decay_ticks = int(data.get("decay_ticks", -1))
		return stack

class UniqueItemInstance:
	var id: int = 0
	var item_id: StringName = &""
	var item_type: StringName = &"tool" # tool, weapon, armor, key, vessel
	var durability: int = 100
	var max_durability: int = 100
	var slot: StringName = &"hand" # hand, body, helmet, shield
	var custom_data: Dictionary = {}
	var location_state: LocationState = LocationState.CONTAINER
	var grid_cell: Vector2i = Vector2i.ZERO
	var container_id: int = 0
	var carrier_id: int = 0

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"item_id": String(item_id),
			"item_type": String(item_type),
			"durability": durability,
			"max_durability": max_durability,
			"slot": String(slot),
			"custom_data": custom_data.duplicate(true),
			"location_state": int(location_state),
			"cell_x": grid_cell.x,
			"cell_y": grid_cell.y,
			"container_id": container_id,
			"carrier_id": carrier_id
		}

	static func from_dict(data: Dictionary) -> UniqueItemInstance:
		var item := UniqueItemInstance.new()
		item.id = int(data.get("id", 0))
		item.item_id = StringName(data.get("item_id", ""))
		item.item_type = StringName(data.get("item_type", "tool"))
		item.durability = int(data.get("durability", 100))
		item.max_durability = int(data.get("max_durability", 100))
		item.slot = StringName(data.get("slot", "hand"))
		item.custom_data = data.get("custom_data", {}).duplicate(true)
		item.location_state = data.get("location_state", LocationState.CONTAINER) as LocationState
		item.grid_cell = Vector2i(int(data.get("cell_x", 0)), int(data.get("cell_y", 0)))
		item.container_id = int(data.get("container_id", 0))
		item.carrier_id = int(data.get("carrier_id", 0))
		return item

var next_stack_id: int = 1
var next_item_id: int = 1

var commodity_stacks: Dictionary = {} # id (int) -> CommodityStack
var unique_items: Dictionary = {}     # id (int) -> UniqueItemInstance

# Spatial / Container lookup indexes
var stacks_by_cell: Dictionary = {}      # Vector2i -> Array[int] (stack ids)
var stacks_by_container: Dictionary = {} # container_id (int) -> Array[int]
var stacks_by_carrier: Dictionary = {}   # carrier_id (int) -> Array[int]
var stacks_in_transit: Array[int] = []

var items_by_cell: Dictionary = {}       # Vector2i -> Array[int] (item ids)
var items_by_container: Dictionary = {}  # container_id (int) -> Array[int] (item ids)
var items_by_carrier: Dictionary = {}    # carrier_id (int) -> Array[int]
var items_in_transit: Array[int] = []

# O(1) Incremental Cached Totals (resource_id -> quantity)
var total_owned: Dictionary = {}
var stored_totals: Dictionary = {}
var loose_totals: Dictionary = {}
var carried_totals: Dictionary = {}
var unique_total_owned: Dictionary = {}
var unique_stored_totals: Dictionary = {}
var unique_loose_totals: Dictionary = {}
var unique_carried_totals: Dictionary = {}

var reservation_service: RefCounted

func bind_reservation_service(service: RefCounted) -> void:
	reservation_service = service

func clear() -> void:
	next_stack_id = 1
	next_item_id = 1
	commodity_stacks.clear()
	unique_items.clear()
	stacks_by_cell.clear()
	stacks_by_container.clear()
	stacks_by_carrier.clear()
	stacks_in_transit.clear()
	items_by_cell.clear()
	items_by_container.clear()
	items_by_carrier.clear()
	items_in_transit.clear()
	total_owned.clear()
	stored_totals.clear()
	loose_totals.clear()
	carried_totals.clear()
	unique_total_owned.clear()
	unique_stored_totals.clear()
	unique_loose_totals.clear()
	unique_carried_totals.clear()

# --- Commodity Stack Lifecycle ---

func create_commodity_stack(
	resource_id: StringName,
	quantity: int,
	location_state: LocationState = LocationState.GROUND,
	grid_cell: Vector2i = Vector2i.ZERO,
	container_id: int = 0,
	carrier_id: int = 0,
	max_stack: int = 100
) -> CommodityStack:
	if resource_id.is_empty() or quantity <= 0 or max_stack <= 0 or quantity > max_stack or location_state == LocationState.DESTROYED:
		return null
	if location_state == LocationState.CONTAINER and container_id <= 0:
		return null
	if location_state == LocationState.CARRIER and carrier_id <= 0:
		return null
	var stack := CommodityStack.new()
	stack.id = next_stack_id
	next_stack_id += 1
	stack.resource_id = resource_id
	stack.quantity = quantity
	stack.max_stack = maxi(1, max_stack)
	stack.location_state = location_state
	stack.grid_cell = grid_cell
	stack.container_id = container_id if location_state == LocationState.CONTAINER else 0
	stack.carrier_id = carrier_id if location_state == LocationState.CARRIER else 0

	commodity_stacks[stack.id] = stack
	_index_stack_location(stack)
	_add_cached_totals(stack.resource_id, stack.quantity, stack.location_state)
	return stack

func add_commodity(
	resource_id: StringName,
	quantity: int,
	location_state: LocationState = LocationState.GROUND,
	grid_cell: Vector2i = Vector2i.ZERO,
	container_id: int = 0,
	carrier_id: int = 0,
	max_stack: int = 100
) -> Array[CommodityStack]:
	var created: Array[CommodityStack] = []
	if quantity <= 0 or max_stack <= 0:
		return created
	var remaining := quantity
	while remaining > 0:
		var stack := create_commodity_stack(
			resource_id,
			mini(remaining, max_stack),
			location_state,
			grid_cell,
			container_id,
			carrier_id,
			max_stack
		)
		if stack == null:
			break
		created.append(stack)
		remaining -= stack.quantity
	return created

func remove_commodity_stack(stack_id: int) -> bool:
	if not commodity_stacks.has(stack_id):
		return false
	if reservation_service != null:
		reservation_service.cancel_all_for_stack(stack_id)
	var stack: CommodityStack = commodity_stacks[stack_id]
	_unindex_stack_location(stack)
	_subtract_cached_totals(stack.resource_id, stack.quantity, stack.location_state)
	stack.location_state = LocationState.DESTROYED
	commodity_stacks.erase(stack_id)
	return true

func move_stack_to_container(stack_id: int, container_id: int, grid_cell: Vector2i = Vector2i.ZERO) -> bool:
	if container_id <= 0:
		return false
	return _move_stack(stack_id, LocationState.CONTAINER, grid_cell, container_id, 0)

func move_stack_to_carrier(stack_id: int, carrier_id: int) -> bool:
	if carrier_id <= 0:
		return false
	return _move_stack(stack_id, LocationState.CARRIER, Vector2i.ZERO, 0, carrier_id)

func move_stack_to_ground(stack_id: int, grid_cell: Vector2i) -> bool:
	return _move_stack(stack_id, LocationState.GROUND, grid_cell, 0, 0)

func move_stack_to_transit(stack_id: int) -> bool:
	return _move_stack(stack_id, LocationState.TRANSIT, Vector2i.ZERO, 0, 0)

func _move_stack(stack_id: int, next_state: LocationState, grid_cell: Vector2i, container_id: int, carrier_id: int) -> bool:
	if not commodity_stacks.has(stack_id):
		return false
	var stack: CommodityStack = commodity_stacks[stack_id]
	_unindex_stack_location(stack)
	_subtract_cached_totals(stack.resource_id, stack.quantity, stack.location_state)

	stack.location_state = next_state
	stack.grid_cell = grid_cell
	stack.container_id = container_id if next_state == LocationState.CONTAINER else 0
	stack.carrier_id = carrier_id if next_state == LocationState.CARRIER else 0

	_index_stack_location(stack)
	_add_cached_totals(stack.resource_id, stack.quantity, stack.location_state)
	return true

func split_stack(stack_id: int, amount_to_split: int) -> CommodityStack:
	if not commodity_stacks.has(stack_id) or amount_to_split <= 0:
		return null
	var original: CommodityStack = commodity_stacks[stack_id]
	if amount_to_split >= original.quantity:
		return null
	original.quantity -= amount_to_split
	_subtract_cached_totals(original.resource_id, amount_to_split, original.location_state)

	# New stack inherits original location and properties
	var new_stack := create_commodity_stack(
		original.resource_id,
		amount_to_split,
		original.location_state,
		original.grid_cell,
		original.container_id,
		original.carrier_id,
		original.max_stack
	)
	new_stack.decay_ticks = original.decay_ticks
	if reservation_service != null:
		reservation_service.transfer_reservation_on_split(original.id, new_stack.id, amount_to_split)
	return new_stack

func merge_stacks(source_stack_id: int, target_stack_id: int) -> int:
	if not commodity_stacks.has(source_stack_id) or not commodity_stacks.has(target_stack_id):
		return 0
	var source: CommodityStack = commodity_stacks[source_stack_id]
	var target: CommodityStack = commodity_stacks[target_stack_id]
	if source_stack_id == target_stack_id or source.resource_id != target.resource_id or not _stacks_share_location(source, target):
		return 0
	var space := target.max_stack - target.quantity
	if space <= 0:
		return 0
	var transfer_amount := mini(source.quantity, space)
	if reservation_service != null:
		reservation_service.transfer_reservation_on_split(source.id, target.id, transfer_amount)
	source.quantity -= transfer_amount
	target.quantity += transfer_amount

	if source.quantity <= 0:
		remove_commodity_stack(source_stack_id)
	return transfer_amount

func _stacks_share_location(a: CommodityStack, b: CommodityStack) -> bool:
	if a.location_state != b.location_state:
		return false
	match a.location_state:
		LocationState.GROUND:
			return a.grid_cell == b.grid_cell
		LocationState.CONTAINER:
			return a.container_id == b.container_id
		LocationState.CARRIER:
			return a.carrier_id == b.carrier_id
		LocationState.TRANSIT:
			return true
	return false

func consume_from_container(container_id: int, resource_id: StringName, quantity: int) -> bool:
	if container_id <= 0 or quantity <= 0:
		return false
	var available := get_container_quantity(container_id, resource_id)
	if available < quantity:
		return false
	var remaining := quantity
	var stack_ids: Array = stacks_by_container.get(container_id, []).duplicate()
	for stack_id in stack_ids:
		if remaining <= 0:
			break
		if not commodity_stacks.has(stack_id):
			continue
		var stack: CommodityStack = commodity_stacks[stack_id]
		if stack.resource_id != resource_id:
			continue
		var reserved: int = int(reservation_service.get_stack_reserved_quantity(stack_id)) if reservation_service != null else 0
		var consumed := mini(maxi(0, stack.quantity - reserved), remaining)
		if consumed <= 0:
			continue
		stack.quantity -= consumed
		_subtract_cached_totals(resource_id, consumed, stack.location_state)
		remaining -= consumed
		if stack.quantity <= 0:
			remove_commodity_stack(stack_id)
	return remaining == 0

func get_available(resource_id: StringName, container_id: int = 0) -> int:
	var available := 0
	for stack_id in commodity_stacks:
		var stack: CommodityStack = commodity_stacks[stack_id]
		if stack.resource_id != resource_id or (container_id > 0 and stack.container_id != container_id):
			continue
		var reserved: int = int(reservation_service.get_stack_reserved_quantity(stack_id)) if reservation_service != null else 0
		available += maxi(0, stack.quantity - reserved)
	for item_id in unique_items:
		var item: UniqueItemInstance = unique_items[item_id]
		if item.item_id == resource_id and (container_id <= 0 or item.container_id == container_id):
			available += 1
	return available

func consume_available(resource_id: StringName, quantity: int, container_id: int = 0) -> bool:
	if resource_id.is_empty() or quantity <= 0:
		return quantity == 0
	# Preflight first. A failed purchase/recipe/build must never consume a partial cost.
	if get_available(resource_id, container_id) < quantity:
		return false
	var remaining := quantity
	var stack_ids: Array = commodity_stacks.keys()
	stack_ids.sort()
	for stack_id in stack_ids:
		if remaining <= 0:
			break
		if not commodity_stacks.has(stack_id):
			continue
		var stack: CommodityStack = commodity_stacks[stack_id]
		if stack.resource_id != resource_id or (container_id > 0 and stack.container_id != container_id):
			continue
		var reserved: int = int(reservation_service.get_stack_reserved_quantity(stack_id)) if reservation_service != null else 0
		var consumed := mini(maxi(0, stack.quantity - reserved), remaining)
		if consumed <= 0:
			continue
		stack.quantity -= consumed
		_subtract_cached_totals(resource_id, consumed, stack.location_state)
		remaining -= consumed
		if stack.quantity <= 0:
			remove_commodity_stack(stack_id)
	if remaining > 0:
		var item_ids: Array = unique_items.keys()
		item_ids.sort()
		for item_id in item_ids:
			if remaining <= 0:
				break
			if not unique_items.has(item_id):
				continue
			var item: UniqueItemInstance = unique_items[item_id]
			if item.item_id != resource_id or (container_id > 0 and item.container_id != container_id):
				continue
			remove_unique_item(item_id)
			remaining -= 1
	return remaining == 0

func get_container_quantity(container_id: int, resource_id: StringName) -> int:
	var available := 0
	for stack_id in stacks_by_container.get(container_id, []):
		if commodity_stacks.has(stack_id):
			var stack: CommodityStack = commodity_stacks[stack_id]
			if stack.resource_id == resource_id:
				var reserved: int = int(reservation_service.get_stack_reserved_quantity(stack_id)) if reservation_service != null else 0
				available += maxi(0, stack.quantity - reserved)
	return available

# --- Unique Item Instance Lifecycle ---

func create_unique_item(
	item_id: StringName,
	item_type: StringName = &"tool",
	durability: int = 100,
	max_durability: int = 100,
	slot: StringName = &"hand",
	custom_data: Dictionary = {},
	location_state: LocationState = LocationState.CONTAINER,
	grid_cell: Vector2i = Vector2i.ZERO,
	container_id: int = 0,
	carrier_id: int = 0
) -> UniqueItemInstance:
	if item_id.is_empty() or max_durability <= 0 or location_state == LocationState.DESTROYED:
		return null
	if location_state == LocationState.CONTAINER and container_id <= 0:
		return null
	if location_state == LocationState.CARRIER and carrier_id <= 0:
		return null
	var item := UniqueItemInstance.new()
	item.id = next_item_id
	next_item_id += 1
	item.item_id = item_id
	item.item_type = item_type
	item.max_durability = maxi(1, max_durability)
	item.durability = clampi(durability, 0, item.max_durability)
	item.slot = slot
	item.custom_data = custom_data.duplicate(true)
	item.location_state = location_state
	item.grid_cell = grid_cell
	item.container_id = container_id if location_state == LocationState.CONTAINER else 0
	item.carrier_id = carrier_id if location_state == LocationState.CARRIER else 0

	unique_items[item.id] = item
	_index_item_location(item)
	_add_unique_cached_totals(item.item_id, 1, item.location_state)
	return item

func remove_unique_item(item_id_val: int) -> bool:
	if not unique_items.has(item_id_val):
		return false
	var item: UniqueItemInstance = unique_items[item_id_val]
	_unindex_item_location(item)
	_subtract_unique_cached_totals(item.item_id, 1, item.location_state)
	item.location_state = LocationState.DESTROYED
	unique_items.erase(item_id_val)
	return true

func move_item_to_container(item_id_val: int, container_id: int, grid_cell: Vector2i = Vector2i.ZERO) -> bool:
	if container_id <= 0:
		return false
	return _move_item(item_id_val, LocationState.CONTAINER, grid_cell, container_id, 0)

func move_item_to_carrier(item_id_val: int, carrier_id: int) -> bool:
	if carrier_id <= 0:
		return false
	return _move_item(item_id_val, LocationState.CARRIER, Vector2i.ZERO, 0, carrier_id)

func move_item_to_ground(item_id_val: int, grid_cell: Vector2i) -> bool:
	return _move_item(item_id_val, LocationState.GROUND, grid_cell, 0, 0)

func move_item_to_transit(item_id_val: int) -> bool:
	return _move_item(item_id_val, LocationState.TRANSIT, Vector2i.ZERO, 0, 0)

func _move_item(item_id_val: int, next_state: LocationState, grid_cell: Vector2i, container_id: int, carrier_id: int) -> bool:
	if not unique_items.has(item_id_val):
		return false
	var item: UniqueItemInstance = unique_items[item_id_val]
	_unindex_item_location(item)
	_subtract_unique_cached_totals(item.item_id, 1, item.location_state)
	item.location_state = next_state
	item.grid_cell = grid_cell
	item.container_id = container_id if next_state == LocationState.CONTAINER else 0
	item.carrier_id = carrier_id if next_state == LocationState.CARRIER else 0
	_index_item_location(item)
	_add_unique_cached_totals(item.item_id, 1, item.location_state)
	return true

# --- Indexing & Cache Accounting ---

func _index_stack_location(stack: CommodityStack) -> void:
	match stack.location_state:
		LocationState.GROUND:
			if not stacks_by_cell.has(stack.grid_cell):
				stacks_by_cell[stack.grid_cell] = []
			stacks_by_cell[stack.grid_cell].append(stack.id)
		LocationState.CONTAINER:
			if not stacks_by_container.has(stack.container_id):
				stacks_by_container[stack.container_id] = []
			stacks_by_container[stack.container_id].append(stack.id)
		LocationState.CARRIER:
			if not stacks_by_carrier.has(stack.carrier_id):
				stacks_by_carrier[stack.carrier_id] = []
			stacks_by_carrier[stack.carrier_id].append(stack.id)
		LocationState.TRANSIT:
			stacks_in_transit.append(stack.id)

func _unindex_stack_location(stack: CommodityStack) -> void:
	match stack.location_state:
		LocationState.GROUND:
			if stacks_by_cell.has(stack.grid_cell):
				stacks_by_cell[stack.grid_cell].erase(stack.id)
		LocationState.CONTAINER:
			if stacks_by_container.has(stack.container_id):
				stacks_by_container[stack.container_id].erase(stack.id)
		LocationState.CARRIER:
			if stacks_by_carrier.has(stack.carrier_id):
				stacks_by_carrier[stack.carrier_id].erase(stack.id)
		LocationState.TRANSIT:
			stacks_in_transit.erase(stack.id)

func _index_item_location(item: UniqueItemInstance) -> void:
	match item.location_state:
		LocationState.GROUND:
			if not items_by_cell.has(item.grid_cell):
				items_by_cell[item.grid_cell] = []
			items_by_cell[item.grid_cell].append(item.id)
		LocationState.CONTAINER:
			if not items_by_container.has(item.container_id):
				items_by_container[item.container_id] = []
			items_by_container[item.container_id].append(item.id)
		LocationState.CARRIER:
			if not items_by_carrier.has(item.carrier_id):
				items_by_carrier[item.carrier_id] = []
			items_by_carrier[item.carrier_id].append(item.id)
		LocationState.TRANSIT:
			items_in_transit.append(item.id)

func _unindex_item_location(item: UniqueItemInstance) -> void:
	match item.location_state:
		LocationState.GROUND:
			if items_by_cell.has(item.grid_cell):
				items_by_cell[item.grid_cell].erase(item.id)
		LocationState.CONTAINER:
			if items_by_container.has(item.container_id):
				items_by_container[item.container_id].erase(item.id)
		LocationState.CARRIER:
			if items_by_carrier.has(item.carrier_id):
				items_by_carrier[item.carrier_id].erase(item.id)
		LocationState.TRANSIT:
			items_in_transit.erase(item.id)

func _add_cached_totals(res_id: StringName, qty: int, state: LocationState) -> void:
	total_owned[res_id] = total_owned.get(res_id, 0) + qty
	match state:
		LocationState.CONTAINER:
			stored_totals[res_id] = stored_totals.get(res_id, 0) + qty
		LocationState.GROUND:
			loose_totals[res_id] = loose_totals.get(res_id, 0) + qty
		LocationState.CARRIER:
			carried_totals[res_id] = carried_totals.get(res_id, 0) + qty

func _subtract_cached_totals(res_id: StringName, qty: int, state: LocationState) -> void:
	total_owned[res_id] = maxi(0, total_owned.get(res_id, 0) - qty)
	match state:
		LocationState.CONTAINER:
			stored_totals[res_id] = maxi(0, stored_totals.get(res_id, 0) - qty)
		LocationState.GROUND:
			loose_totals[res_id] = maxi(0, loose_totals.get(res_id, 0) - qty)
		LocationState.CARRIER:
			carried_totals[res_id] = maxi(0, carried_totals.get(res_id, 0) - qty)

func get_total(resource_id: StringName) -> int:
	return total_owned.get(resource_id, 0) + unique_total_owned.get(resource_id, 0)

func get_stored(resource_id: StringName) -> int:
	return stored_totals.get(resource_id, 0) + unique_stored_totals.get(resource_id, 0)

func get_loose(resource_id: StringName) -> int:
	return loose_totals.get(resource_id, 0) + unique_loose_totals.get(resource_id, 0)

func get_carried(resource_id: StringName) -> int:
	return carried_totals.get(resource_id, 0) + unique_carried_totals.get(resource_id, 0)

func _add_unique_cached_totals(item_id: StringName, qty: int, state: LocationState) -> void:
	unique_total_owned[item_id] = unique_total_owned.get(item_id, 0) + qty
	match state:
		LocationState.CONTAINER:
			unique_stored_totals[item_id] = unique_stored_totals.get(item_id, 0) + qty
		LocationState.GROUND:
			unique_loose_totals[item_id] = unique_loose_totals.get(item_id, 0) + qty
		LocationState.CARRIER:
			unique_carried_totals[item_id] = unique_carried_totals.get(item_id, 0) + qty

func _subtract_unique_cached_totals(item_id: StringName, qty: int, state: LocationState) -> void:
	unique_total_owned[item_id] = maxi(0, unique_total_owned.get(item_id, 0) - qty)
	match state:
		LocationState.CONTAINER:
			unique_stored_totals[item_id] = maxi(0, unique_stored_totals.get(item_id, 0) - qty)
		LocationState.GROUND:
			unique_loose_totals[item_id] = maxi(0, unique_loose_totals.get(item_id, 0) - qty)
		LocationState.CARRIER:
			unique_carried_totals[item_id] = maxi(0, unique_carried_totals.get(item_id, 0) - qty)

# Full audit sweep to assert that cached totals match physical stack sums
func recompute_totals_audit() -> Dictionary:
	var audited: Dictionary = {"total": {}, "stored": {}, "loose": {}, "carried": {}}
	for stack_id in commodity_stacks:
		var stack: CommodityStack = commodity_stacks[stack_id]
		var res := stack.resource_id
		audited.total[res] = audited.total.get(res, 0) + stack.quantity
		match stack.location_state:
			LocationState.CONTAINER:
				audited.stored[res] = audited.stored.get(res, 0) + stack.quantity
			LocationState.GROUND:
				audited.loose[res] = audited.loose.get(res, 0) + stack.quantity
			LocationState.CARRIER:
				audited.carried[res] = audited.carried.get(res, 0) + stack.quantity
	for item_id_val in unique_items:
		var item: UniqueItemInstance = unique_items[item_id_val]
		var res := item.item_id
		audited.total[res] = audited.total.get(res, 0) + 1
		match item.location_state:
			LocationState.CONTAINER:
				audited.stored[res] = audited.stored.get(res, 0) + 1
			LocationState.GROUND:
				audited.loose[res] = audited.loose.get(res, 0) + 1
			LocationState.CARRIER:
				audited.carried[res] = audited.carried.get(res, 0) + 1
	return audited

func audit_totals_match() -> bool:
	var audited := recompute_totals_audit()
	var resource_ids: Dictionary = {}
	for totals in [audited.total, total_owned, unique_total_owned]:
		for resource_id in totals:
			resource_ids[resource_id] = true
	for resource_id in resource_ids:
		if int(audited.total.get(resource_id, 0)) != get_total(resource_id):
			return false
	return true

# --- Serialization (Schema 4) ---

func export_state() -> Dictionary:
	var stacks_data: Array[Dictionary] = []
	var stack_ids: Array = commodity_stacks.keys()
	stack_ids.sort()
	for stack_id in stack_ids:
		stacks_data.append(commodity_stacks[stack_id].to_dict())
	var items_data: Array[Dictionary] = []
	var item_ids: Array = unique_items.keys()
	item_ids.sort()
	for item_id in item_ids:
		items_data.append(unique_items[item_id].to_dict())
	return {
		"next_stack_id": next_stack_id,
		"next_item_id": next_item_id,
		"commodity_stacks": stacks_data,
		"unique_items": items_data
	}

func import_state(data: Dictionary) -> void:
	clear()
	next_stack_id = int(data.get("next_stack_id", 1))
	next_item_id = int(data.get("next_item_id", 1))
	for stack_dict in data.get("commodity_stacks", []):
		var stack := CommodityStack.from_dict(stack_dict)
		if stack.id <= 0 or stack.quantity <= 0 or stack.resource_id.is_empty() or stack.location_state == LocationState.DESTROYED:
			continue
		commodity_stacks[stack.id] = stack
		_index_stack_location(stack)
		_add_cached_totals(stack.resource_id, stack.quantity, stack.location_state)
	for item_dict in data.get("unique_items", []):
		var item := UniqueItemInstance.from_dict(item_dict)
		if item.id <= 0 or item.item_id.is_empty() or item.location_state == LocationState.DESTROYED:
			continue
		unique_items[item.id] = item
		_index_item_location(item)
		_add_unique_cached_totals(item.item_id, 1, item.location_state)
	next_stack_id = maxi(next_stack_id, _next_available_id(commodity_stacks))
	next_item_id = maxi(next_item_id, _next_available_id(unique_items))

func _next_available_id(records: Dictionary) -> int:
	var highest := 0
	for record_id in records:
		highest = maxi(highest, int(record_id))
	return highest + 1
