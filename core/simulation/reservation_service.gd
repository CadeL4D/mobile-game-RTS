class_name ReservationService
extends RefCounted

## Manages discrete multi-worker partial reservation tokens on physical commodity stacks
## with automatic token transfers, cancellation hooks, and conservation validation.

class ReservationToken:
	var reservation_id: int = 0
	var stack_id: int = 0
	var quantity: int = 0
	var requester_id: int = 0
	var destination_id: int = 0
	var purpose: StringName = &"hauling"
	var state: StringName = &"active" # active, completed, cancelled
	var created_tick: int = 0

	func to_dict() -> Dictionary:
		return {
			"reservation_id": reservation_id,
			"stack_id": stack_id,
			"quantity": quantity,
			"requester_id": requester_id,
			"destination_id": destination_id,
			"purpose": String(purpose),
			"state": String(state),
			"created_tick": created_tick
		}

	static func from_dict(data: Dictionary) -> ReservationToken:
		var token := ReservationToken.new()
		token.reservation_id = int(data.get("reservation_id", 0))
		token.stack_id = int(data.get("stack_id", 0))
		token.quantity = int(data.get("quantity", 0))
		token.requester_id = int(data.get("requester_id", 0))
		token.destination_id = int(data.get("destination_id", 0))
		token.purpose = StringName(data.get("purpose", "hauling"))
		token.state = StringName(data.get("state", "active"))
		token.created_tick = int(data.get("created_tick", 0))
		return token

var next_reservation_id: int = 1
var active_reservations: Dictionary = {} # reservation_id (int) -> ReservationToken

# Secondary indexes for O(1) lookups
var reservations_by_stack: Dictionary = {}     # stack_id (int) -> Array[int] (token ids)
var reservations_by_requester: Dictionary = {} # requester_id (int) -> Array[int]
var reservations_by_dest: Dictionary = {}      # destination_id (int) -> Array[int]
var reserved_quantity_by_stack: Dictionary = {} # stack_id (int) -> quantity (int)

func clear() -> void:
	next_reservation_id = 1
	active_reservations.clear()
	reservations_by_stack.clear()
	reservations_by_requester.clear()
	reservations_by_dest.clear()
	reserved_quantity_by_stack.clear()

func create_reservation(
	stack_id: int,
	quantity: int,
	requester_id: int,
	destination_id: int = 0,
	purpose: StringName = &"hauling",
	current_tick: int = 0,
	inventory: RefCounted = null
) -> ReservationToken:
	if quantity <= 0 or requester_id <= 0 or inventory == null:
		return null
	var available := get_stack_available_quantity(stack_id, inventory)
	if quantity > available:
		return null

	var token := ReservationToken.new()
	token.reservation_id = next_reservation_id
	next_reservation_id += 1
	token.stack_id = stack_id
	token.quantity = quantity
	token.requester_id = requester_id
	token.destination_id = destination_id
	token.purpose = purpose
	token.state = &"active"
	token.created_tick = current_tick

	active_reservations[token.reservation_id] = token
	_index_token(token)
	return token

func get_stack_reserved_quantity(stack_id: int) -> int:
	return int(reserved_quantity_by_stack.get(stack_id, 0))

func get_stack_available_quantity(stack_id: int, inventory: RefCounted) -> int:
	if not inventory.commodity_stacks.has(stack_id):
		return 0
	var stack = inventory.commodity_stacks[stack_id]
	return maxi(0, stack.quantity - get_stack_reserved_quantity(stack_id))

func transfer_reservation_on_split(old_stack_id: int, new_stack_id: int, split_quantity: int) -> void:
	if not reservations_by_stack.has(old_stack_id):
		return
	var token_ids: Array = reservations_by_stack[old_stack_id].duplicate()
	var remaining_split := split_quantity
	for token_id in token_ids:
		if remaining_split <= 0:
			break
		if not active_reservations.has(token_id):
			continue
		var token: ReservationToken = active_reservations[token_id]
		if token.quantity <= remaining_split:
			# Move entire token to new stack
			_unindex_token_stack(token)
			_subtract_reserved(old_stack_id, token.quantity)
			token.stack_id = new_stack_id
			_index_token_stack(token)
			_add_reserved(new_stack_id, token.quantity)
			remaining_split -= token.quantity
		else:
			# Split token
			var new_token := ReservationToken.new()
			new_token.reservation_id = next_reservation_id
			next_reservation_id += 1
			new_token.stack_id = new_stack_id
			new_token.quantity = remaining_split
			new_token.requester_id = token.requester_id
			new_token.destination_id = token.destination_id
			new_token.purpose = token.purpose
			new_token.state = &"active"
			new_token.created_tick = token.created_tick

			token.quantity -= remaining_split
			_subtract_reserved(old_stack_id, remaining_split)
			active_reservations[new_token.reservation_id] = new_token
			_index_token(new_token)
			remaining_split = 0

func complete_reservation(reservation_id: int) -> bool:
	if not active_reservations.has(reservation_id):
		return false
	var token: ReservationToken = active_reservations[reservation_id]
	token.state = &"completed"
	_subtract_reserved(token.stack_id, token.quantity)
	_unindex_token(token)
	active_reservations.erase(reservation_id)
	return true

func cancel_reservation(reservation_id: int) -> bool:
	if not active_reservations.has(reservation_id):
		return false
	var token: ReservationToken = active_reservations[reservation_id]
	token.state = &"cancelled"
	_subtract_reserved(token.stack_id, token.quantity)
	_unindex_token(token)
	active_reservations.erase(reservation_id)
	return true

func cancel_all_for_requester(requester_id: int) -> int:
	if not reservations_by_requester.has(requester_id):
		return 0
	var count := 0
	var token_ids: Array = reservations_by_requester[requester_id].duplicate()
	for token_id in token_ids:
		if cancel_reservation(token_id):
			count += 1
	return count

func cancel_all_for_stack(stack_id: int) -> int:
	if not reservations_by_stack.has(stack_id):
		return 0
	var count := 0
	var token_ids: Array = reservations_by_stack[stack_id].duplicate()
	for token_id in token_ids:
		if cancel_reservation(token_id):
			count += 1
	return count

func cancel_all_for_destination(destination_id: int) -> int:
	if not reservations_by_dest.has(destination_id):
		return 0
	var count := 0
	var token_ids: Array = reservations_by_dest[destination_id].duplicate()
	for token_id in token_ids:
		if cancel_reservation(token_id):
			count += 1
	return count

# --- Indexing ---

func _index_token(token: ReservationToken) -> void:
	_index_token_stack(token)
	_add_reserved(token.stack_id, token.quantity)
	if not reservations_by_requester.has(token.requester_id):
		reservations_by_requester[token.requester_id] = []
	reservations_by_requester[token.requester_id].append(token.reservation_id)
	if token.destination_id > 0:
		if not reservations_by_dest.has(token.destination_id):
			reservations_by_dest[token.destination_id] = []
		reservations_by_dest[token.destination_id].append(token.reservation_id)

func _unindex_token(token: ReservationToken) -> void:
	_unindex_token_stack(token)
	if reservations_by_requester.has(token.requester_id):
		reservations_by_requester[token.requester_id].erase(token.reservation_id)
	if token.destination_id > 0 and reservations_by_dest.has(token.destination_id):
		reservations_by_dest[token.destination_id].erase(token.reservation_id)
		if reservations_by_dest[token.destination_id].is_empty():
			reservations_by_dest.erase(token.destination_id)

func _index_token_stack(token: ReservationToken) -> void:
	if not reservations_by_stack.has(token.stack_id):
		reservations_by_stack[token.stack_id] = []
	reservations_by_stack[token.stack_id].append(token.reservation_id)

func _unindex_token_stack(token: ReservationToken) -> void:
	if reservations_by_stack.has(token.stack_id):
		reservations_by_stack[token.stack_id].erase(token.reservation_id)
		if reservations_by_stack[token.stack_id].is_empty():
			reservations_by_stack.erase(token.stack_id)

func _add_reserved(stack_id: int, quantity: int) -> void:
	reserved_quantity_by_stack[stack_id] = int(reserved_quantity_by_stack.get(stack_id, 0)) + quantity

func _subtract_reserved(stack_id: int, quantity: int) -> void:
	var remaining := maxi(0, int(reserved_quantity_by_stack.get(stack_id, 0)) - quantity)
	if remaining == 0:
		reserved_quantity_by_stack.erase(stack_id)
	else:
		reserved_quantity_by_stack[stack_id] = remaining

func validate_conservation(inventory: RefCounted) -> bool:
	for stack_id in reservations_by_stack:
		if not inventory.commodity_stacks.has(stack_id):
			return false
		var stack = inventory.commodity_stacks[stack_id]
		var reserved := get_stack_reserved_quantity(stack_id)
		var recomputed := 0
		for token_id in reservations_by_stack[stack_id]:
			if active_reservations.has(token_id):
				recomputed += int(active_reservations[token_id].quantity)
		if reserved != recomputed or reserved > stack.quantity:
			return false
	return true

# --- Serialization (Schema 4) ---

func export_state() -> Dictionary:
	var tokens_data: Array[Dictionary] = []
	for token_id in active_reservations:
		tokens_data.append(active_reservations[token_id].to_dict())
	return {
		"next_reservation_id": next_reservation_id,
		"active_reservations": tokens_data
	}

func import_state(data: Dictionary) -> void:
	clear()
	next_reservation_id = int(data.get("next_reservation_id", 1))
	for token_dict in data.get("active_reservations", []):
		var token := ReservationToken.from_dict(token_dict)
		if token.state == &"active" and token.reservation_id > 0 and token.stack_id > 0 and token.quantity > 0 and token.requester_id > 0:
			active_reservations[token.reservation_id] = token
			_index_token(token)
			next_reservation_id = maxi(next_reservation_id, token.reservation_id + 1)
