class_name SpellSystem
extends RefCounted

## Coordinates the 5 verified spell categories (Hand, Aid, Defensive, Offensive, Utility),
## Occultist altar prayer, Faith -> Essence -> Energy conversion, and Cullis Gate instability.

const SPELL_GROUPS: Array[StringName] = [&"hand", &"aid", &"defensive", &"offensive", &"utility"]

var faith: int = 0
var essence: int = 0
var energy: int = 0
var max_energy: int = 1000

var cullis_instability: int = 0

func clear() -> void:
	faith = 0
	essence = 0
	energy = 0
	max_energy = 1000
	cullis_instability = 0

func add_prayer_faith(amount: int) -> void:
	faith += amount

func convert_faith_to_essence(collectors: Array) -> int:
	if collectors.is_empty() or faith < 10:
		return 0
	var converted := faith / 10
	faith = faith % 10
	essence += converted
	return converted

func convert_essence_to_energy() -> int:
	if essence <= 0:
		return 0
	var space := max_energy - energy
	if space <= 0:
		return 0
	var transfer := mini(essence * 3, space)
	var essence_used := maxi(1, transfer / 3)
	essence = maxi(0, essence - essence_used)
	energy = mini(max_energy, energy + transfer)
	return transfer

func can_cast_spell(spell_id: StringName, current_energy: int) -> bool:
	var def := ContentRegistry.get_by_id(&"spells", spell_id)
	if def.is_empty():
		return false
	var cost := int(def.get("cost", 0))
	return current_energy >= cost

func process_cullis_sacrifice(sacrifice_kind: StringName, current_tick: int) -> Dictionary:
	var essence_gain := 15
	var instability_gain := 20
	if sacrifice_kind == &"monster":
		essence_gain = 25
		instability_gain = 30
	elif sacrifice_kind == &"villager":
		essence_gain = 50
		instability_gain = 60

	essence += essence_gain
	cullis_instability += instability_gain

	var outcome := {
		"essence_gained": essence_gain,
		"instability": cullis_instability,
		"lightning_strike": false,
		"overload_quake": false
	}

	if cullis_instability > 480:
		outcome.overload_quake = true
		cullis_instability = 0
	elif cullis_instability > 240:
		outcome.lightning_strike = true
		cullis_instability -= 60

	return outcome

func export_state() -> Dictionary:
	return {
		"faith": faith,
		"essence": essence,
		"energy": energy,
		"max_energy": max_energy,
		"cullis_instability": cullis_instability
	}

func import_state(data: Dictionary) -> void:
	faith = int(data.get("faith", 0))
	essence = int(data.get("essence", 0))
	energy = int(data.get("energy", 0))
	max_energy = int(data.get("max_energy", 1000))
	cullis_instability = int(data.get("cullis_instability", 0))
