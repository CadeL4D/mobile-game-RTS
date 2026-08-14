class_name CombatSystem
extends RefCounted

## Coordinates defensive tower targeting, physical ammunition consumption from buffers,
## projectile resolution, monster behavioral AI, and elemental damage types.

func update_towers(
	buildings: Array,
	monsters: Array,
	inventory: RefCounted,
	current_tick: int,
	energy_source: RefCounted = null
) -> Array[Dictionary]:
	var projectile_events: Array[Dictionary] = []

	for building in buildings:
		if building is not Dictionary or not bool(building.get("completed", true)) or bool(building.get("destroyed", false)):
			continue

		var def_id := StringName(building.get("definition_id", ""))
		var definition := ContentRegistry.get_by_id(&"buildings", def_id)
		var tower_def: Dictionary = definition.get("tower", {})
		if tower_def.is_empty():
			continue

		if String(tower_def.get("role", "attack")) != "attack":
			continue
		var reload_ticks := maxi(1, int(tower_def.get("reload_ticks", 15)))
		if current_tick % reload_ticks != 0:
			continue

		var range_tiles := float(tower_def.get("range", 12.0))
		var damage := int(tower_def.get("damage", 25))
		var damage_type := StringName(tower_def.get("damage_type", "piercing"))
		var building_id := int(building.get("id", 0))
		var bpos := Vector2(float(building.get("x", 0)), float(building.get("y", 0)))

		# Resolve targets before consuming ammunition or energy. Idle towers must
		# never spend their buffers merely because a reload interval elapsed.
		var candidates: Array[Dictionary] = []
		for monster in monsters:
			if bool(monster.get("dead", false)):
				continue
			var mpos := Vector2(float(monster.get("x", 0)), float(monster.get("y", 0)))
			var dist := bpos.distance_to(mpos)
			if dist <= range_tiles:
				candidates.append({"monster": monster, "distance": dist})
		if candidates.is_empty():
			continue
		var priorities: Array = tower_def.get("priority", [])
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_kind := String(a.monster.get("definition_id", a.monster.get("kind", "")))
			var b_kind := String(b.monster.get("definition_id", b.monster.get("kind", "")))
			var a_priority := priorities.find(a_kind)
			var b_priority := priorities.find(b_kind)
			a_priority = a_priority if a_priority >= 0 else 9999
			b_priority = b_priority if b_priority >= 0 else 9999
			return a_priority < b_priority or (a_priority == b_priority and float(a.distance) < float(b.distance))
		)

		var ammo_type := StringName(tower_def.get("ammo", ""))
		var ammo_per_shot := maxi(1, int(tower_def.get("ammo_per_shot", 1)))
		if not ammo_type.is_empty() and inventory.get_container_quantity(building_id, ammo_type) < ammo_per_shot:
			continue
		var energy_per_shot := maxi(0, int(tower_def.get("energy_per_shot", 0)))
		if energy_per_shot > 0:
			if energy_source == null or int(energy_source.energy) < energy_per_shot:
				continue
		if not ammo_type.is_empty() and not inventory.consume_from_container(building_id, ammo_type, ammo_per_shot):
			continue
		if energy_per_shot > 0:
			energy_source.energy = int(energy_source.energy) - energy_per_shot

		var target_count := mini(maxi(1, int(tower_def.get("targets", 1))), candidates.size())
		for target_index in target_count:
			var target_monster: Dictionary = candidates[target_index].monster
			var mhp := int(target_monster.get("health", 100)) - damage
			target_monster.health = mhp
			if mhp <= 0:
				target_monster.dead = true
			projectile_events.append({
				"tower_id": building_id,
				"from_pos": bpos,
				"to_pos": Vector2(float(target_monster.x), float(target_monster.y)),
				"damage": damage,
				"damage_type": String(damage_type)
			})

	return projectile_events
