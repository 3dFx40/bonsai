class_name BonsaiSound
extends Node

var enabled := false
var player: AudioStreamPlayer
var clips: Dictionary = {}

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -19
	add_child(player)
	# Deterministic original foley: water bubbles, a double snip, falling pellets.
	clips["water"] = _make_clip(1.4, "water")
	clips["prune"] = _make_clip(0.24, "prune")
	clips["fertilize"] = _make_clip(0.55, "fertilize")

func play_cue(cue: String) -> void:
	if not enabled or not clips.has(cue): return
	player.stream = clips[cue]
	player.play()

func _make_clip(seconds: float, cue: String) -> AudioStreamWAV:
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
		var wave := 0.0
		match cue:
			"water":
				var bubbles := sin(t * TAU * (480 + sin(t * 71) * 160)) * 0.12 * pow(0.5 + 0.5 * sin(t * 47), 4)
				wave = filtered * 0.65 + bubbles
			"prune":
				var pulse := exp(-t * 90) + (exp(-(t - 0.075) * 110) if t > 0.075 else 0.0)
				wave = (filtered * 0.7 + sin(t * TAU * 2300) * 0.22) * pulse
			"fertilize":
				var pulse := pow(0.5 + 0.5 * sin(t * 95), 18) * exp(-t * 4)
				wave = (filtered * 0.6 + sin(t * TAU * 840) * 0.1) * pulse
		bytes.encode_s16(i * 2, int(clampf(wave * envelope, -1, 1) * 28000))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	return wav
