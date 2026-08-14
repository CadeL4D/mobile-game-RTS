class_name TradeSystem
extends RefCounted

## Coordinates physical Catjeet Provisioner arrival from map edges,
## Marketplace trade execution, auto-trade quotas, and departure.

var provisioners: Array[Dictionary] = []
var next_provisioner_id: int = 1

func clear() -> void:
	provisioners.clear()
	next_provisioner_id = 1

func spawn_caravan(map_width: int, map_height: int, marketplace: Dictionary) -> Dictionary:
	var pid := next_provisioner_id
	next_provisioner_id += 1

	# Start at map edge
	var start_x := 0.0
	var start_y := float(map_height / 2)
	var target_x := float(marketplace.get("x", map_width / 2))
	var target_y := float(marketplace.get("y", map_height / 2))

	var provisioner := {
		"id": pid,
		"kind": "catjeet_provisioner",
		"x": start_x,
		"y": start_y,
		"target_x": target_x,
		"target_y": target_y,
		"state": "traveling_to_market",
		"trade_ticks_remaining": 300,
		"gold": 500,
		"cargo": {}
	}
	provisioners.append(provisioner)
	return provisioner

func update_caravans(
	inventory: RefCounted,
	marketplace: Dictionary,
	delta_ticks: int
) -> void:
	var to_remove: Array[int] = []
	for idx in provisioners.size():
		var p: Dictionary = provisioners[idx]
		var state: String = p.get("state", "traveling_to_market")

		if state == "traveling_to_market":
			var cur := Vector2(float(p.x), float(p.y))
			var dest := Vector2(float(p.target_x), float(p.target_y))
			if cur.distance_to(dest) < 1.0:
				p.state = "trading"
			else:
				var move := cur.move_toward(dest, 0.4)
				p.x = move.x
				p.y = move.y
		elif state == "trading":
			p.trade_ticks_remaining = int(p.get("trade_ticks_remaining", 300)) - delta_ticks
			if int(p.trade_ticks_remaining) <= 0:
				p.state = "departing"
				p.target_x = 0.0
				p.target_y = float(p.y)
		elif state == "departing":
			var cur := Vector2(float(p.x), float(p.y))
			var dest := Vector2(float(p.target_x), float(p.target_y))
			if cur.distance_to(dest) < 1.0:
				to_remove.append(idx)
			else:
				var move := cur.move_toward(dest, 0.4)
				p.x = move.x
				p.y = move.y

	for i in range(to_remove.size() - 1, -1, -1):
		provisioners.remove_at(to_remove[i])

func export_state() -> Dictionary:
	return {
		"next_provisioner_id": next_provisioner_id,
		"provisioners": provisioners.duplicate(true)
	}

func import_state(data: Dictionary) -> void:
	clear()
	next_provisioner_id = int(data.get("next_provisioner_id", 1))
	for p in data.get("provisioners", []):
		provisioners.append(p.duplicate(true))
