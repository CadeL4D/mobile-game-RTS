extends Node

signal setting_changed(key: StringName, value: Variant)

const PATH := "user://settings.json"

var values := {
	"ui_scale": 1.0,
	"text_scale": 1.0,
	"left_handed": false,
	"pause_on_panel": true,
	"reduce_motion": false,
	"haptics": true,
}

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key in parsed:
			if values.has(key):
				values[key] = parsed[key]
	values.ui_scale = clampf(float(values.ui_scale), 0.8, 1.5)
	values.text_scale = clampf(float(values.text_scale), 0.8, 1.5)

func set_value(key: StringName, value: Variant) -> bool:
	var string_key := String(key)
	if not values.has(string_key):
		return false
	if key in [&"ui_scale", &"text_scale"]:
		value = clampf(float(value), 0.8, 1.5)
	values[string_key] = value
	save_settings()
	setting_changed.emit(key, value)
	return true

func save_settings() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(values, "\t"))
