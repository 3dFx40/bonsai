class_name BonsaiSound
extends Node

var enabled := false
var player: AudioStreamPlayer
var clips: Dictionary = {}

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -19
	add_child(player)
	# Original synthesized placeholders; no external assets or mandatory music.
	clips["water"] = _make_clip(0.65, 410, true)
	clips["prune"] = _make_clip(0.10, 1500, true)
	clips["fertilize"] = _make_clip(0.22, 720, false)

func play_cue(cue: String) -> void:
	if not enabled or not clips.has(cue): return
	player.stream = clips[cue]
	player.play()

func _make_clip(seconds: float, hz: float, noise: bool) -> AudioStreamWAV:
	var rate := 22050
	var count := int(seconds * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var filtered := 0.0
	for i in count:
		var t := float(i) / rate
		var envelope := minf(1, t * 40) * pow(1 - float(i) / count, 1.8)
		filtered = lerpf(filtered, rng.randf_range(-1, 1), 0.2)
		var wave := filtered if noise else sin(t * TAU * hz) * exp(-t * 15)
		bytes.encode_s16(i * 2, int(clampf(wave * envelope, -1, 1) * 28000))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	return wav
