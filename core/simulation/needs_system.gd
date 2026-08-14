class_name NeedsSystem
extends RefCounted

## Coordinates villager physiological needs (hunger, thirst, sleep, temperature, medical triage).

const NEED_CRITICAL_THRESHOLD: int = 700 # Scale 0 - 1000 where 1000 is fully satisfied

func update_villager_needs(
	villager: Dictionary,
	inventory: RefCounted,
	reservation_service: RefCounted,
	task_system: RefCounted,
	buildings: Array,
	current_tick: int
) -> void:
	if bool(villager.get("dead", false)):
		return

	var hunger: int = int(villager.get("hunger", 1000))
	var thirst: int = int(villager.get("thirst", 1000))
	var energy: int = int(villager.get("energy", 1000))
	var health: int = int(villager.get("health", 100))

	# Rate of decay (every 30 ticks = 3 seconds at 10 Hz)
	if current_tick % 30 == 0:
		hunger = maxi(0, hunger - 4)
		thirst = maxi(0, thirst - 6)
		energy = maxi(0, energy - 2)

	villager.hunger = hunger
	villager.thirst = thirst
	villager.energy = energy

	var vid := int(villager.get("id", 0))
	var vpos := Vector2i(int(villager.get("x", 0)), int(villager.get("y", 0)))

	# Medical triage preemption if injured
	if health < 80:
		villager.triage_urgency = (100 - health) * 3
		task_system.post_task(&"triage", vpos, vid, 200 + (100 - health), {
			"patient_id": vid,
			"health": health
		})
