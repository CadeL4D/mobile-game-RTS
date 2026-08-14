class_name LogisticsSystem
extends RefCounted

## Manages container capacities, resource filters, input/output workplace buffers,
## carrier limits, trash routing, and clean/dirty water networks.

const TRASH_BUILDING_TYPES: Array[String] = ["trash_can", "landfill", "processor", "burner", "cube_e_golem_combobulator"]

func can_container_accept(
	building: Dictionary,
	resource_id: StringName,
	quantity: int,
	inventory: RefCounted
) -> bool:
	if quantity <= 0 or building.is_empty() or not bool(building.get("completed", true)) or bool(building.get("destroyed", false)):
		return false

	var building_id := int(building.get("id", 0))
	var def_id := StringName(building.get("definition_id", ""))
	var definition := ContentRegistry.get_by_id(&"buildings", def_id)
	var profile: Dictionary = definition.get("storage_profile", {})

	# Check filter rules
	if not profile.is_empty():
		var accepted_resources: Array = profile.get("resources", [])
		var accepted_groups: Array = profile.get("accepted_groups", [])
		var excluded_resources: Array = profile.get("excluded_resources", [])

		if excluded_resources.has(String(resource_id)):
			return false

		var res_def := ContentRegistry.get_by_id(&"resources", resource_id)
		var res_group := String(res_def.get("group", ""))

		if not accepted_resources.is_empty() and not accepted_resources.has(String(resource_id)):
			return false
		if not accepted_groups.is_empty() and not accepted_groups.has(res_group):
			return false

	# Calculate capacity
	var max_cap := get_container_capacity(building, definition)
	var current_used := get_container_current_volume(building_id, inventory)
	return (current_used + quantity) <= max_cap

func get_container_capacity(building: Dictionary, definition: Dictionary = {}) -> int:
	if definition.is_empty():
		definition = ContentRegistry.get_by_id(&"buildings", StringName(building.get("definition_id", "")))
	var tier := int(building.get("tier", 1))
	var profile: Dictionary = definition.get("storage_profile", {})
	if profile.has("capacity_by_tier"):
		var caps: Array = profile.capacity_by_tier
		if caps.is_empty():
			return 0
		var idx := clampi(tier - 1, 0, caps.size() - 1)
		return int(caps[idx])
	return int(definition.get("storage_capacity", 64))

func get_container_current_volume(container_id: int, inventory: RefCounted) -> int:
	var total := 0
	if inventory.stacks_by_container.has(container_id):
		for stack_id in inventory.stacks_by_container[container_id]:
			if inventory.commodity_stacks.has(stack_id):
				total += inventory.commodity_stacks[stack_id].quantity
	if inventory.items_by_container.has(container_id):
		total += inventory.items_by_container[container_id].size()
	return total

func find_best_storage_for_resource(
	resource_id: StringName,
	quantity: int,
	inventory: RefCounted,
	buildings: Array,
	from_pos: Vector2i
) -> int:
	var best_building_id := 0
	var best_dist := 999999.0
	var res_def := ContentRegistry.get_by_id(&"resources", resource_id)
	var is_trash := String(res_def.get("group", "")) == "trash"

	for building in buildings:
		if building is not Dictionary or not bool(building.get("completed", true)) or bool(building.get("destroyed", false)):
			continue
		var def_id := String(building.get("definition_id", ""))

		# Trash routing
		if is_trash and def_id not in TRASH_BUILDING_TYPES:
			continue
		if not is_trash and def_id in TRASH_BUILDING_TYPES:
			continue

		if can_container_accept(building, resource_id, quantity, inventory):
			var bpos := Vector2i(int(building.get("x", 0)), int(building.get("y", 0)))
			var dist := Vector2(from_pos).distance_to(Vector2(bpos))
			if dist < best_dist:
				best_dist = dist
				best_building_id = int(building.get("id", 0))

	return best_building_id

func find_available_resource_stack(
	resource_id: StringName,
	needed_qty: int,
	inventory: RefCounted,
	reservation_service: RefCounted,
	from_pos: Vector2i
):
	var best_stack = null
	var best_dist := 999999.0

	for stack_id in inventory.commodity_stacks:
		var stack = inventory.commodity_stacks[stack_id]
		if stack.resource_id != resource_id:
			continue
		if int(stack.location_state) not in [0, 1]: # GROUND = 0, CONTAINER = 1
			continue

		var avail: int = reservation_service.get_stack_available_quantity(stack_id, inventory)
		if avail <= 0:
			continue

		var dist := Vector2(from_pos).distance_to(Vector2(stack.grid_cell))
		if dist < best_dist:
			best_dist = dist
			best_stack = stack

	return best_stack

func get_carrier_capacity(carrier_kind: StringName) -> int:
	match carrier_kind:
		&"villager": return 20
		&"doggo": return 5
		&"courier": return 50
		&"golem": return 40
		_: return 10
