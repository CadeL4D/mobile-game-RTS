extends Node

signal cue_requested(cue_id: StringName, world_position: Vector2)

const SAMPLE_RATE := 22050
const BUS_NAMES := ["Music", "Ambience", "UI", "Creatures", "Buildings", "Combat"]

var music_intensity := 0.0
var corruption_intensity := 0.0
var cue_cache: Dictionary = {}
var music_players: Dictionary = {}
var last_cue_msec: Dictionary = {}

func _ready() -> void:
	_ensure_buses()
	if not _silent_runtime():
		_build_adaptive_music()

func _ensure_buses() -> void:
	for bus_name in BUS_NAMES:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")

func play_cue(cue_id: StringName, world_position := Vector2.ZERO) -> void:
	cue_requested.emit(cue_id, world_position)
	if _silent_runtime():
		return
	var key := String(cue_id)
	var now := Time.get_ticks_msec()
	if now - int(last_cue_msec.get(key, -10000)) < 90:
		return
	last_cue_msec[key] = now
	if not cue_cache.has(key):
		cue_cache[key] = _create_cue(key)
	var player := AudioStreamPlayer.new()
	player.stream = cue_cache[key]
	player.bus = _bus_for_cue(key)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func set_music_intensity(value: float) -> void:
	music_intensity = clampf(value, 0.0, 1.0)
	_apply_music_mix()

func set_corruption_intensity(value: float) -> void:
	corruption_intensity = clampf(value, 0.0, 1.0)
	_apply_music_mix()

func _build_adaptive_music() -> void:
	var layers := {
		"calm": {"notes": [48, 55, 60, 64, 60, 55, 52, 57], "wave": "triangle"},
		"danger": {"notes": [38, 38, 41, 36, 38, 43, 41, 36], "wave": "square"},
		"corruption": {"notes": [31, 32, 31, 27, 31, 34, 32, 27], "wave": "sine"},
	}
	for layer_id in layers:
		var player := AudioStreamPlayer.new()
		player.stream = _create_music_loop(layers[layer_id].notes, String(layers[layer_id].wave))
		player.bus = "Music"
		player.volume_db = -80.0
		add_child(player)
		player.play()
		music_players[layer_id] = player
	_apply_music_mix()

func _apply_music_mix() -> void:
	if music_players.is_empty():
		return
	var danger := music_intensity * (1.0 - corruption_intensity)
	var corruption := corruption_intensity
	var calm := clampf(1.0 - maxf(danger, corruption), 0.0, 1.0)
	music_players.calm.volume_db = linear_to_db(maxf(0.0001, calm * 0.58))
	music_players.danger.volume_db = linear_to_db(maxf(0.0001, danger * 0.50))
	music_players.corruption.volume_db = linear_to_db(maxf(0.0001, corruption * 0.48))

func _create_cue(cue_id: String) -> AudioStreamWAV:
	var definition: Array = {
		"ui_tap": [[520.0, 720.0], 0.09, "triangle"],
		"invalid_action": [[180.0, 120.0], 0.18, "square"],
		"building_placed": [[190.0, 260.0], 0.22, "triangle"],
		"building_completed": [[330.0, 440.0, 660.0], 0.42, "triangle"],
		"goal_completed": [[392.0, 523.25, 659.25, 783.99], 0.78, "triangle"],
		"achievement_completed": [[523.25, 659.25, 783.99, 1046.5], 0.95, "sine"],
		"harvest": [[150.0, 105.0], 0.12, "noise"],
		"warning": [[220.0, 220.0, 164.8], 0.64, "square"],
	}.get(cue_id, [[330.0], 0.16, "sine"])
	return _synthesize(definition[0], float(definition[1]), String(definition[2]), false)

func _create_music_loop(notes: Array, wave: String) -> AudioStreamWAV:
	var frequencies: Array[float] = []
	for midi_note in notes:
		frequencies.append(440.0 * pow(2.0, (float(midi_note) - 69.0) / 12.0))
	var stream := _synthesize(frequencies, 16.0, wave, true)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(16.0 * SAMPLE_RATE)
	return stream

func _synthesize(frequencies: Array, duration: float, wave: String, music_loop: bool) -> AudioStreamWAV:
	var sample_count := maxi(1, int(duration * SAMPLE_RATE))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var segment_length := maxf(1.0, float(sample_count) / float(maxi(1, frequencies.size())))
	for sample_index in sample_count:
		var time := float(sample_index) / float(SAMPLE_RATE)
		var segment := mini(frequencies.size() - 1, int(float(sample_index) / segment_length))
		var frequency := float(frequencies[segment])
		var phase := TAU * frequency * time
		var raw := _wave_sample(phase, wave, sample_index)
		if music_loop:
			raw = raw * 0.34 + sin(phase * 0.5) * 0.16 + sin(TAU * (frequency * 1.5) * time) * 0.08
		var attack := minf(1.0, float(sample_index) / maxf(1.0, SAMPLE_RATE * (0.16 if music_loop else 0.012)))
		var release_samples := SAMPLE_RATE * (0.20 if music_loop else minf(0.12, duration * 0.35))
		var release := minf(1.0, float(sample_count - sample_index) / maxf(1.0, release_samples))
		var envelope := minf(attack, release)
		var amplitude := 0.20 if music_loop else 0.34
		bytes.encode_s16(sample_index * 2, clampi(roundi(raw * envelope * amplitude * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream

func _wave_sample(phase: float, wave: String, sample_index: int) -> float:
	match wave:
		"triangle":
			return asin(sin(phase)) * (2.0 / PI)
		"square":
			return 1.0 if sin(phase) >= 0.0 else -1.0
		"noise":
			return sin(float(sample_index * 1103515245 + 12345))
		_:
			return sin(phase)

func _bus_for_cue(cue_id: String) -> String:
	if cue_id in ["ui_tap", "invalid_action", "goal_completed", "achievement_completed", "warning"]:
		return "UI"
	if cue_id.begins_with("building") or cue_id == "harvest":
		return "Buildings"
	return "Combat"

func _silent_runtime() -> bool:
	return "--run-tests" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless"
