class_name ProductionSystem
extends RefCounted

## Coordinates recipe execution, physical input/output buffers,
## worker physical attendance requirements, and tool throughput scaling.

func is_worker_attending_building(worker: Dictionary, building: Dictionary) -> bool:
	var wx := float(worker.get("x", 0))
	var wy := float(worker.get("y", 0))
	var bx := float(building.get("x", 0))
	var by := float(building.get("y", 0))
	var bw := float(building.get("width", 1))
	var bh := float(building.get("height", 1))

	var rect := Rect2(bx, by, bw, bh).grow(1.5)
	if rect.has_point(Vector2(wx, wy)):
		return true

	var state := String(worker.get("state", ""))
	return state.begins_with("operating_") or state == "working"

func count_attending_workers(building: Dictionary, villagers: Array) -> int:
	var count := 0
	var building_id := int(building.get("id", 0))
	for villager in villagers:
		if int(villager.get("workplace_id", 0)) == building_id:
			if is_worker_attending_building(villager, building):
				count += 1
	return count

func can_execute_recipe(
	recipe: Dictionary,
	building_id: int,
	inventory: RefCounted,
	policy: Dictionary = {} # Make / Maintain rule
) -> bool:
	var outputs: Dictionary = recipe.get("outputs", {})
	if outputs.is_empty():
		return false
	var output_id := StringName(policy.get("resource_id", outputs.keys()[0]))
	var mode := String(policy.get("mode", "always")) # always, make, maintain
	var target_amount := int(policy.get("amount", 0))

	if mode == "maintain":
		var current_stock: int = inventory.get_total(output_id)
		if current_stock >= target_amount:
			return false
	elif mode == "make":
		var made := int(policy.get("made_so_far", 0))
		if made >= target_amount:
			return false

	# Check required inputs
	var inputs: Dictionary = recipe.get("inputs", {})
	for res_id_str in inputs:
		var res_id := StringName(res_id_str)
		var needed := int(inputs[res_id_str])
		var available := 0

		# Check building input buffer stacks
		if inventory.stacks_by_container.has(building_id):
			for stack_id in inventory.stacks_by_container[building_id]:
				if inventory.commodity_stacks.has(stack_id):
					var stack = inventory.commodity_stacks[stack_id]
					if stack.resource_id == res_id:
						available += stack.quantity

		if available < needed:
			return false

	return true

func consume_recipe_inputs(
	recipe: Dictionary,
	building_id: int,
	inventory: RefCounted
) -> bool:
	if not can_execute_recipe(recipe, building_id, inventory):
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for res_id_str in inputs:
		var res_id := StringName(res_id_str)
		var needed := int(inputs[res_id_str])
		var remaining := needed

		if inventory.stacks_by_container.has(building_id):
			var stack_ids: Array = inventory.stacks_by_container[building_id].duplicate()
			for stack_id in stack_ids:
				if remaining <= 0:
					break
				if not inventory.commodity_stacks.has(stack_id):
					continue
				var stack = inventory.commodity_stacks[stack_id]
				if stack.resource_id == res_id:
					if stack.quantity <= remaining:
						remaining -= stack.quantity
						inventory.remove_commodity_stack(stack_id)
					else:
						stack.quantity -= remaining
						inventory._subtract_cached_totals(res_id, remaining, stack.location_state)
						remaining = 0

		if remaining > 0:
			return false
	return true

func produce_recipe_outputs(
	recipe: Dictionary,
	building: Dictionary,
	inventory: RefCounted
) -> void:
	var building_id := int(building.get("id", 0))
	var grid_pos := Vector2i(int(building.get("x", 0)), int(building.get("y", 0)))
	var outputs: Dictionary = recipe.get("outputs", {})
	for output_id_value in outputs:
		var output_id := StringName(output_id_value)
		var output_qty := int(outputs[output_id_value])
		if output_qty <= 0:
			continue
		var resource_definition := ContentRegistry.get_by_id(&"resources", output_id)
		if _is_unique_item(resource_definition, output_id):
			for _index in output_qty:
				inventory.create_unique_item(
					output_id,
					StringName(resource_definition.get("group", "item")),
					int(resource_definition.get("durability", 100)),
					int(resource_definition.get("durability", 100)),
					StringName(resource_definition.get("slot", "hand")),
					resource_definition,
					1, # CONTAINER
					grid_pos,
					building_id
				)
		else:
			inventory.create_commodity_stack(
				output_id,
				output_qty,
				1, # CONTAINER
				grid_pos,
				building_id
			)

func _is_unique_item(resource_definition: Dictionary, resource_id: StringName) -> bool:
	var group := String(resource_definition.get("group", ""))
	return group in ["tool", "weapon", "armor"] or resource_id in [&"suspicious_key", &"empty_eerie_vessel", &"filled_eerie_vessel"]
