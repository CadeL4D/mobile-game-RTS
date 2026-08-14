class_name PopulationSystem
extends RefCounted

## Coordinates villager lifecycle progression, natural aging, death,
## corpse decay, ghost spawning, and equipment instance slot management.

func process_lifecycle(
	villagers: Array,
	ghosts: Array,
	inventory: RefCounted,
	current_tick: int,
	rng_source: RandomNumberGenerator
) -> Array[Dictionary]:
	var death_events: Array[Dictionary] = []

	# Aging check (every day = 2400 ticks at 10 Hz)
	if current_tick % 2400 == 0:
		for villager in villagers:
			if bool(villager.get("dead", false)):
				continue
			var age := int(villager.get("age", 20)) + 1
			villager.age = age

			# Natural death chance for elders (> 65)
			if age > 65 and rng_source.randf() < 0.1:
				villager.dead = true
				death_events.append({"id": int(villager.get("id", 0)), "cause": "old_age"})

	for event in death_events:
		var vid := int(event.id)
		var deceased: Dictionary = {}
		for villager in villagers:
			if int(villager.get("id", 0)) == vid:
				deceased = villager
				break
		# Spawn ghost
		ghosts.append({
			"id": vid,
			"kind": "ghost",
			"x": float(deceased.get("x", 0.0)),
			"y": float(deceased.get("y", 0.0)),
			"soul_type": "villager",
			"ticks_remaining": 1200
		})

	return death_events
