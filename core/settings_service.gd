extends Node

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

func save_settings() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(values, "\t"))

