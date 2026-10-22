extends Node

## Audio Manager
## Handles sound effects, combat audio, and procedural audio synthesis fallback.

var _sfx_players: Array[AudioStreamPlayer] = []
const POOL_SIZE = 12
var _current_player_idx = 0

var _bgm_player: AudioStreamPlayer
var _procedural_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_nodes()
	_connect_event_bus()

func _setup_audio_nodes() -> void:
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_sfx_players.append(player)

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = &"Music"
	add_child(_bgm_player)

func _connect_event_bus() -> void:
	if has_node("/root/EventBus"):
		var eb = get_node("/root/EventBus")
		eb.play_sfx_requested.connect(play_sfx)
		eb.duel_clash_occurred.connect(func(dmg, crit, pos):
			if crit:
				play_sfx("crit", "Combat")
			else:
				play_sfx("clash", "Combat")
		)
		eb.move_executed.connect(func(from, to, attack):
			if not attack:
				play_sfx("move", "SFX")
		)
		eb.duel_triggered.connect(func(atk, df, pos):
			play_sfx("duel_start", "Combat")
		)
		eb.match_ended.connect(func(winner, reason):
			play_sfx("victory", "UI")
		)

func play_sfx(sound_name: String, bus_name: String = "SFX") -> void:
	var stream: AudioStream = null

	# Check if asset exists on disk, otherwise synthesize
	var asset_path = "res://assets/audio/sfx/" + sound_name + ".wav"
	if ResourceLoader.exists(asset_path):
		stream = load(asset_path)
	else:
		stream = _get_or_synthesize_sound(sound_name)

	if stream:
		var player = _sfx_players[_current_player_idx]
		_current_player_idx = (_current_player_idx + 1) % POOL_SIZE
		player.bus = StringName(bus_name)
		player.stream = stream
		player.pitch_scale = randf_range(0.95, 1.05)
		player.play()

## Synthesize distinct 8-bit / punchy game sounds procedurally so audio works without external assets
func _get_or_synthesize_sound(sound_name: String) -> AudioStreamWAV:
	if _procedural_cache.has(sound_name):
		return _procedural_cache[sound_name]

	var sample_rate = 22050
	var duration = 0.2
	var samples: PackedByteArray = PackedByteArray()

	match sound_name:
		"click":
			duration = 0.05
			var num_samples = int(duration * sample_rate)
			samples.resize(num_samples)
			for i in range(num_samples):
				var t = float(i) / sample_rate
				var env = 1.0 - (float(i) / num_samples)
				var val = sin(2.0 * PI * 880.0 * t) * env * 0.4
				samples[i] = int(clamp((val + 1.0) * 127.5, 0, 255))

		"move":
			duration = 0.12
			var num_samples = int(duration * sample_rate)
			samples.resize(num_samples)
			for i in range(num_samples):
				var env = 1.0 - (float(i) / num_samples)
				var freq = lerpf(300.0, 150.0, float(i) / num_samples)
				var t = float(i) / sample_rate
				var val = sin(2.0 * PI * freq * t) * env * 0.5
				samples[i] = int(clamp((val + 1.0) * 127.5, 0, 255))

		"clash":
			duration = 0.25
			var num_samples = int(duration * sample_rate)
			samples.resize(num_samples)
			for i in range(num_samples):
				var env = exp(-8.0 * (float(i) / num_samples))
				var noise = randf_range(-1.0, 1.0) * 0.6
				var metallic = sin(2.0 * PI * 1200.0 * (float(i) / sample_rate)) * 0.4
				var val = (noise + metallic) * env
				samples[i] = int(clamp((val + 1.0) * 127.5, 0, 255))

		"crit":
			duration = 0.35
			var num_samples = int(duration * sample_rate)
			samples.resize(num_samples)
			for i in range(num_samples):
				var env = exp(-5.0 * (float(i) / num_samples))
				var freq = lerpf(800.0, 300.0, float(i) / num_samples)
				var noise = randf_range(-0.5, 0.5)
				var tone = sin(2.0 * PI * freq * (float(i) / sample_rate))
				var val = (tone * 0.7 + noise * 0.3) * env
				samples[i] = int(clamp((val + 1.0) * 127.5, 0, 255))

		"duel_start":
			duration = 0.45
			var num_samples = int(duration * sample_rate)
			samples.resize(num_samples)
			for i in range(num_samples):
				var env = 1.0 - (float(i) / num_samples)
				var freq = lerpf(120.0, 480.0, float(i) / num_samples)
				var val = sin(2.0 * PI * freq * (float(i) / sample_rate)) * env * 0.6
				samples[i] = int(clamp((val + 1.0) * 127.5, 0, 255))

		"victory":
			duration = 0.6
			var num_samples = int(duration * sample_rate)
			samples.resize(num_samples)
			for i in range(num_samples):
				var t = float(i) / sample_rate
				var env = 1.0 - (float(i) / num_samples)
				var note = 440.0 if t < 0.2 else (554.37 if t < 0.4 else 659.25)
				var val = sin(2.0 * PI * note * t) * env * 0.5
				samples[i] = int(clamp((val + 1.0) * 127.5, 0, 255))

		_:
			duration = 0.1
			var num_samples = int(duration * sample_rate)
			samples.resize(num_samples)
			for i in range(num_samples):
				var val = randf_range(-0.3, 0.3)
				samples[i] = int(clamp((val + 1.0) * 127.5, 0, 255))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = samples
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_procedural_cache[sound_name] = wav
	return wav
