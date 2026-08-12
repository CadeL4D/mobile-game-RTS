class_name SimEvent
extends RefCounted

var tick: int
var type: StringName
var data: Dictionary

func _init(p_tick: int, p_type: StringName, p_data: Dictionary = {}) -> void:
	tick = p_tick
	type = p_type
	data = p_data.duplicate(true)

func to_dictionary() -> Dictionary:
	return {"tick": tick, "type": String(type), "data": data.duplicate(true)}

