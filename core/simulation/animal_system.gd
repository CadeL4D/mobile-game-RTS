class_name AnimalSystem
extends RefCounted

## Coordinates animal breeding, pen capacities, Cook slaughter tasks at 75% capacity,
## Coop egg-laying cycles, and physical Doggo hauling/key interactions.

func process_animals(
	animals: Array,
	buildings: Array,
	task_system: RefCounted,
	inventory: RefCounted,
	current_tick: int
) -> void:
	var animals_by_pen: Dictionary = {}

	# Group captive animals by pen/building
	for animal in animals:
		if not bool(animal.get("captured", false)):
			continue
		var pen_id := int(animal.get("pen_id", 0))
		if pen_id <= 0:
			continue
		if not animals_by_pen.has(pen_id):
			animals_by_pen[pen_id] = []
		animals_by_pen[pen_id].append(animal)

	# Process pens
	for building in buildings:
		if building is not Dictionary or not bool(building.get("completed", true)) or bool(building.get("destroyed", false)):
			continue
		var def_id := String(building.get("definition_id", ""))
		var building_id := int(building.get("id", 0))

		if def_id == "animal_pen":
			var cap := int(building.get("animal_capacity", 6))
			var pen_animals: Array = animals_by_pen.get(building_id, [])
			var target_occupancy := int(floor(float(cap) * 0.75))

			# When occupancy is above 75%, Cooks may reduce it to that target.
			if cap > 0 and float(pen_animals.size()) / float(cap) > 0.75:
				var excess := pen_animals.size() - target_occupancy
				var count := 0
				for animal in pen_animals:
					if count >= excess:
						break
					var species := String(animal.get("species", animal.get("definition_id", "beefalo")))
					if String(animal.get("age_stage", "adult")) == "adult" and species not in ["doggo", "doofy_doggo"]:
						var aid := int(animal.get("id", 0))
						var apos := Vector2i(int(animal.get("x", 0)), int(animal.get("y", 0)))
						task_system.post_task(&"slaughter", apos, aid, 10, {
							"animal_id": aid,
							"species": species,
							"dedupe_key": "slaughter:%d" % aid
						})
						count += 1

		elif def_id == "clucker_coop":
			var coop_animals: Array = []
			for animal in animals_by_pen.get(building_id, []):
				if String(animal.get("species", animal.get("definition_id", ""))) == "clucker" and not bool(animal.get("dead", false)):
					coop_animals.append(animal)
			# Living Cluckers lay eggs over time in Coops
			if not coop_animals.is_empty() and current_tick % 120 == 0:
				var egg_count := maxi(1, coop_animals.size() / 2)
				var bpos := Vector2i(int(building.get("x", 0)), int(building.get("y", 0)))
				inventory.create_commodity_stack(
					&"eggs",
					egg_count,
					1, # CONTAINER
					bpos,
					building_id
				)

func get_slaughter_yields(species: StringName) -> Dictionary:
	match species:
		&"beefalo": return {"raw_meat": 4, "leather": 2}
		&"entler": return {"raw_meat": 3, "wood": 2}
		&"rous": return {"raw_meat": 2}
		&"clucker": return {"raw_meat": 1, "feathers": 2} # Note: eggs are NOT slaughter yields
		_: return {"raw_meat": 1}

func process_doggos(
	doggos: Array,
	inventory: RefCounted,
	reservation_service: RefCounted,
	logistics: RefCounted,
	buildings: Array,
	current_tick: int
) -> void:
	for doggo in doggos:
		if bool(doggo.get("dead", false)):
			continue
		var doggo_id := int(doggo.get("id", 0))
		var dpos := Vector2i(int(doggo.get("x", 0)), int(doggo.get("y", 0)))

		# Check if Doggo can seek keys or loot boxes
		var held_key := false
		var held_key_id := 0
		if inventory.items_by_carrier.has(doggo_id):
			for item_id in inventory.items_by_carrier[doggo_id]:
				if inventory.unique_items.has(item_id):
					if inventory.unique_items[item_id].item_id == &"suspicious_key":
						held_key = true
						held_key_id = int(item_id)
						break

		# If holding a key, seek nearest lootbox
		if held_key:
			# Look for loot box on ground
			for stack_id in inventory.commodity_stacks:
				var stack = inventory.commodity_stacks[stack_id]
				if stack.resource_id == &"lootbox" and int(stack.location_state) == 0: # GROUND
					if Vector2(dpos).distance_to(Vector2(stack.grid_cell)) < 1.5:
						# Open loot box!
						inventory.remove_commodity_stack(stack_id)
						# Consume key
						if held_key_id > 0:
							inventory.remove_unique_item(held_key_id)
						# Spawn loot rewards
						inventory.create_commodity_stack(&"gold_coins", 50, 0, dpos)
						inventory.create_commodity_stack(&"crystal", 10, 0, dpos)
						break
