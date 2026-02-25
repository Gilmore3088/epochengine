extends Node

## Centralized audio manager with procedural sound generation.
## No external audio files needed — all sounds generated from sine waves and noise.

const SAMPLE_RATE := 44100
const MIX_RATE := 44100.0

# Volume categories (0.0 - 1.0)
var volume_master: float = 0.7
var volume_music: float = 0.4
var volume_sfx: float = 0.8
var volume_ui: float = 0.6

# Audio players
var _sfx_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer

# Precomputed buffers
var _click_buffer: AudioStreamWAV
var _hover_buffer: AudioStreamWAV
var _war_buffer: AudioStreamWAV
var _peace_buffer: AudioStreamWAV
var _golden_age_buffer: AudioStreamWAV
var _tech_buffer: AudioStreamWAV
var _battle_buffer: AudioStreamWAV
var _victory_buffer: AudioStreamWAV
var _defeat_buffer: AudioStreamWAV

# Ambient music state
var _music_generator: AudioStreamGenerator
var _music_playback: AudioStreamGeneratorPlayback
var _music_phase: float = 0.0
var _music_mod_phase: float = 0.0


func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = "Master"
	add_child(_sfx_player)

	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "Master"
	add_child(_ui_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)

	_precompute_buffers()
	_connect_events()
	start_ambient_music()


# ==================== PROCEDURAL GENERATORS ====================

static func gen_tone(freq: float, duration: float, amplitude: float = 0.5, fade_out: bool = false) -> PackedFloat32Array:
	## Generate a sine wave tone.
	var sample_count: int = int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for i in sample_count:
		var t: float = float(i) / MIX_RATE
		var value: float = sin(t * freq * TAU) * amplitude
		if fade_out:
			var env: float = 1.0 - (float(i) / float(sample_count))
			value *= env
		samples[i] = value
	return samples


static func gen_noise(duration: float, amplitude: float = 0.3) -> PackedFloat32Array:
	## Generate filtered noise burst.
	var sample_count: int = int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var prev: float = 0.0
	for i in sample_count:
		var raw: float = randf_range(-1.0, 1.0) * amplitude
		# Simple low-pass filter
		prev = prev * 0.7 + raw * 0.3
		# Envelope: sharp attack, quick decay
		var env: float = 1.0 - (float(i) / float(sample_count))
		samples[i] = prev * env
	return samples


static func gen_chord(freqs: Array[float], duration: float, amplitude: float = 0.3) -> PackedFloat32Array:
	## Generate multi-frequency chord.
	var sample_count: int = int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var per_amp: float = amplitude / float(freqs.size())
	for i in sample_count:
		var t: float = float(i) / MIX_RATE
		var value: float = 0.0
		for freq in freqs:
			value += sin(t * freq * TAU) * per_amp
		# Fade out
		var env: float = 1.0 - (float(i) / float(sample_count))
		samples[i] = value * env
	return samples


func _precompute_buffers() -> void:
	_click_buffer = _samples_to_wav(gen_tone(800.0, 0.05, 0.4))
	_hover_buffer = _samples_to_wav(gen_tone(600.0, 0.03, 0.2))
	_war_buffer = _samples_to_wav(gen_noise(0.15, 0.5))
	_peace_buffer = _samples_to_wav(gen_tone(440.0, 0.3, 0.35, true))
	_golden_age_buffer = _samples_to_wav(gen_chord([523.25, 659.25, 783.99] as Array[float], 0.5, 0.35))
	_tech_buffer = _samples_to_wav(gen_tone(1046.0, 0.12, 0.3, true))
	_battle_buffer = _samples_to_wav(gen_tone(200.0, 0.1, 0.4))
	_victory_buffer = _samples_to_wav(gen_chord([523.25, 659.25, 783.99, 1046.5] as Array[float], 0.8, 0.3))
	_defeat_buffer = _samples_to_wav(gen_tone(150.0, 0.6, 0.35, true))


static func _samples_to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	## Convert float samples to 16-bit WAV AudioStream.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false

	var byte_data := PackedByteArray()
	byte_data.resize(samples.size() * 2)
	for i in samples.size():
		var clamped: float = clampf(samples[i], -1.0, 1.0)
		var val: int = int(clamped * 32767.0)
		byte_data[i * 2] = val & 0xFF
		byte_data[i * 2 + 1] = (val >> 8) & 0xFF
	wav.data = byte_data
	return wav


# ==================== PLAYBACK API ====================

func play_ui_click() -> void:
	_play(_ui_player, _click_buffer, volume_master * volume_ui)


func play_ui_hover() -> void:
	_play(_ui_player, _hover_buffer, volume_master * volume_ui * 0.5)


func play_war() -> void:
	_play(_sfx_player, _war_buffer, volume_master * volume_sfx)


func play_peace() -> void:
	_play(_sfx_player, _peace_buffer, volume_master * volume_sfx)


func play_golden_age() -> void:
	_play(_sfx_player, _golden_age_buffer, volume_master * volume_sfx)


func play_tech() -> void:
	_play(_sfx_player, _tech_buffer, volume_master * volume_sfx)


func play_battle() -> void:
	_play(_sfx_player, _battle_buffer, volume_master * volume_sfx * 0.6)


func play_victory() -> void:
	_play(_sfx_player, _victory_buffer, volume_master * volume_sfx)


func play_defeat() -> void:
	_play(_sfx_player, _defeat_buffer, volume_master * volume_sfx)


func _play(player: AudioStreamPlayer, buffer: AudioStreamWAV, vol: float) -> void:
	player.stream = buffer
	player.volume_db = linear_to_db(vol)
	player.play()


# ==================== EVENT HOOKS ====================

func _connect_events() -> void:
	EventBus.war_declared.connect(_on_war)
	EventBus.peace_declared.connect(_on_peace)
	EventBus.golden_age_started.connect(_on_golden_age)
	EventBus.technology_emerged.connect(_on_tech)
	EventBus.battle_resolved.connect(_on_battle)
	EventBus.game_won.connect(_on_win)
	EventBus.game_lost.connect(_on_lose)


func _on_war(_a: int, _b: int) -> void:
	play_war()

func _on_peace(_a: int, _b: int) -> void:
	play_peace()

func _on_golden_age(_civ_id: int) -> void:
	play_golden_age()

func _on_tech(_civ_id: int, _tech: String) -> void:
	play_tech()

func _on_battle(_region: int, _atk: int, _def: int, _winner: int) -> void:
	play_battle()

func _on_win(_type: String, _details: Dictionary) -> void:
	play_victory()

func _on_lose(_reason: String, _details: Dictionary) -> void:
	play_defeat()


# ==================== AMBIENT MUSIC ====================

func start_ambient_music() -> void:
	## Start a barely-audible ambient drone (low C2 + fifth).
	_music_generator = AudioStreamGenerator.new()
	_music_generator.mix_rate = MIX_RATE
	_music_generator.buffer_length = 0.1
	_music_player.stream = _music_generator
	_music_player.volume_db = linear_to_db(volume_master * volume_music * 0.3)
	_music_player.play()
	_music_playback = _music_player.get_stream_playback()


func _process(_delta: float) -> void:
	if not _music_playback:
		return

	var frames_available: int = _music_playback.get_frames_available()
	if frames_available <= 0:
		return

	var base_freq: float = 65.41  # C2
	var fifth_freq: float = 98.0  # G2
	var mod_freq: float = 0.15  # Slow modulation

	for i in frames_available:
		_music_phase += 1.0 / MIX_RATE
		_music_mod_phase += mod_freq / MIX_RATE

		var modulation: float = 0.5 + 0.5 * sin(_music_mod_phase * TAU)
		var sample: float = sin(_music_phase * base_freq * TAU) * 0.3
		sample += sin(_music_phase * fifth_freq * TAU) * 0.15
		sample *= modulation * 0.4

		_music_playback.push_frame(Vector2(sample, sample))
