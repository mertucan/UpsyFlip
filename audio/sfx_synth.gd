class_name SfxSynth
extends RefCounted
## Synthesizes every sound effect from code (no audio assets).
## All sounds are 16-bit mono at MIX_RATE.

enum Wave { SINE, TRIANGLE, SQUARE }

const MIX_RATE: int = 22050
const NOISE_SEED: int = 7
const SFX_NAMES: Array[StringName] = [
	&"launch", &"stick", &"perfect", &"bounce", &"coin", &"target",
	&"fever", &"clutch", &"death", &"theme", &"button", &"shot", &"return",
]


static func build_all() -> Dictionary[StringName, AudioStreamWAV]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = NOISE_SEED
	var thunk: PackedFloat32Array = _layer(
			_tone(0.16, 170.0, 60.0, 28.0, 0.9), _noise(rng, 0.05, 60.0, 0.5, 0.25), 0.0)

	var sounds: Dictionary[StringName, AudioStreamWAV] = {}
	sounds[&"launch"] = _to_stream(_noise(rng, 0.12, 20.0, 0.3, 0.12))
	sounds[&"stick"] = _to_stream(thunk)

	var perfect: PackedFloat32Array = _layer(thunk, _tone(0.22, 880.0, 880.0, 14.0, 0.45), 0.0)
	perfect = _layer(perfect, _tone(0.32, 1320.0, 1320.0, 10.0, 0.45), 0.07)
	sounds[&"perfect"] = _to_stream(perfect)

	sounds[&"bounce"] = _to_stream(_layer(
			_noise(rng, 0.09, 40.0, 0.55, 0.5), _tone(0.08, 300.0, 190.0, 35.0, 0.4, Wave.TRIANGLE), 0.0))

	sounds[&"coin"] = _to_stream(_layer(
			_tone(0.07, 1250.0, 1250.0, 30.0, 0.4), _tone(0.18, 1870.0, 1870.0, 16.0, 0.4), 0.06))

	sounds[&"target"] = _to_stream(_layer(
			thunk, _tone(0.3, 660.0, 990.0, 9.0, 0.45, Wave.TRIANGLE), 0.02))

	var fever: PackedFloat32Array = PackedFloat32Array()
	var fever_notes: PackedFloat32Array = [523.25, 659.25, 783.99, 1046.5]
	for index: int in fever_notes.size():
		fever = _layer(fever, _tone(0.35, fever_notes[index], fever_notes[index], 9.0, 0.35, Wave.TRIANGLE), index * 0.07)
	sounds[&"fever"] = _to_stream(fever)

	var clutch: PackedFloat32Array = _tone(0.25, 110.0, 50.0, 14.0, 0.8)
	for frequency: float in [392.0, 523.25, 783.99]:
		clutch = _layer(clutch, _tone(0.6, frequency, frequency, 6.0, 0.25, Wave.TRIANGLE), 0.03)
	sounds[&"clutch"] = _to_stream(clutch)

	sounds[&"death"] = _to_stream(_tone(0.45, 420.0, 90.0, 5.0, 0.5, Wave.TRIANGLE))
	sounds[&"theme"] = _to_stream(_layer(
			_tone(0.3, 659.25, 659.25, 8.0, 0.4), _tone(0.5, 987.77, 987.77, 6.0, 0.4), 0.12))
	sounds[&"button"] = _to_stream(_tone(0.04, 700.0, 700.0, 60.0, 0.4))
	# Toy pop rather than a realistic gunshot.
	sounds[&"shot"] = _to_stream(_layer(
			_noise(rng, 0.1, 30.0, 0.7, 0.7), _tone(0.12, 520.0, 140.0, 26.0, 0.6, Wave.SQUARE), 0.0))
	sounds[&"return"] = _to_stream(_layer(
			_noise(rng, 0.35, 7.0, 0.25, 0.08), _tone(0.35, 300.0, 620.0, 6.0, 0.3, Wave.TRIANGLE), 0.0))
	return sounds


## Pitched tone sweeping from `frequency_start` to `frequency_end` with an
## exponential decay envelope.
static func _tone(
		duration: float, frequency_start: float, frequency_end: float,
		decay: float, volume: float, wave: Wave = Wave.SINE) -> PackedFloat32Array:
	var count: int = int(duration * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var phase: float = 0.0
	var ratio: float = frequency_end / frequency_start
	for index: int in count:
		var progress: float = float(index) / float(count)
		phase += frequency_start * pow(ratio, progress) / MIX_RATE
		var cycle: float = fposmod(phase, 1.0)
		var value: float = 0.0
		match wave:
			Wave.SINE:
				value = sin(cycle * TAU)
			Wave.TRIANGLE:
				value = 1.0 - 4.0 * absf(cycle - 0.5)
			Wave.SQUARE:
				value = 0.6 if cycle < 0.5 else -0.6
		samples[index] = value * volume * _envelope(index, count, decay)
	return samples


## Low-passed white noise burst; `smoothing` near 0 is dull, near 1 is bright.
static func _noise(
		rng: RandomNumberGenerator, duration: float, decay: float,
		volume: float, smoothing: float) -> PackedFloat32Array:
	var count: int = int(duration * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var filtered: float = 0.0
	for index: int in count:
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), smoothing)
		samples[index] = filtered * volume * _envelope(index, count, decay)
	return samples


## Short attack, exponential decay, and a fade at the very end to avoid clicks.
static func _envelope(index: int, count: int, decay: float) -> float:
	var time: float = float(index) / MIX_RATE
	var attack: float = minf(time / 0.002, 1.0)
	var tail: float = minf(float(count - index) / (0.005 * MIX_RATE), 1.0)
	return attack * tail * exp(-decay * time)


## Returns `base` with `addition` mixed in, starting `offset` seconds in.
static func _layer(
		base: PackedFloat32Array, addition: PackedFloat32Array, offset: float) -> PackedFloat32Array:
	var start: int = int(offset * MIX_RATE)
	var result: PackedFloat32Array = base.duplicate()
	if result.size() < start + addition.size():
		result.resize(start + addition.size())
	for index: int in addition.size():
		result[start + index] += addition[index]
	return result


static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index: int in samples.size():
		bytes.encode_s16(index * 2, int(clampf(samples[index], -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
