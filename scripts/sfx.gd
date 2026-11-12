class_name Sfx
extends Node
## Audio 100% sintetizado: vento, chuva, trovao, passos e blocos.

const RATE := 22050

var wind_player: AudioStreamPlayer
var rain_player: AudioStreamPlayer
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 12345
	wind_player = _loop_player(_make(_wind(3.0), true))
	rain_player = _loop_player(_make(_rain(2.0), true))
	_streams["thud"] = _make(_thud(0.16, 90.0, 0.5), false)
	_streams["place"] = _make(_thud(0.10, 160.0, 0.25), false)
	_streams["step"] = _make(_thud(0.07, 70.0, 0.8), false)
	_streams["splash"] = _make(_burst(0.45, 0.25, 9.0), false)
	_streams["thunder"] = _make(_burst(3.2, 0.02, 1.3), false)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func _loop_player(s: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch * _rng.randf_range(0.92, 1.08)
	p.play()


func set_ambience(wind: float, rain: float) -> void:
	wind_player.volume_db = linear_to_db(clampf(wind * 0.55, 0.0005, 1.0))
	wind_player.pitch_scale = 0.8 + wind * 0.35
	rain_player.volume_db = linear_to_db(clampf(rain * 0.6, 0.0001, 1.0))


func _make(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _seamless(src: PackedFloat32Array, n: int, fade: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = src[i]
	for i in fade:
		var t := float(i) / fade
		out[i] = src[i] * t + src[n + i] * (1.0 - t)
	return out


func _wind(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var fade := RATE / 3
	var src := PackedFloat32Array()
	src.resize(n + fade)
	var lp := 0.0
	var lp2 := 0.0
	for i in n + fade:
		var w := _rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.035
		lp2 += (lp - lp2) * 0.2
		src[i] = lp2 * 5.0 * (0.75 + 0.25 * sin(TAU * i / float(n) * 2.0))
	return _seamless(src, n, fade)


func _rain(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var fade := RATE / 4
	var src := PackedFloat32Array()
	src.resize(n + fade)
	var lp := 0.0
	var hp := 0.0
	for i in n + fade:
		var w := _rng.randf_range(-1.0, 1.0)
		lp += (w - lp) * 0.45
		hp += (lp - hp) * 0.04
		var s := (lp - hp) * 0.55
		if _rng.randf() < 0.004:
			s += _rng.randf_range(-0.5, 0.5)
		src[i] = s
	return _seamless(src, n, fade)


func _thud(seconds: float, freq: float, noise: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * 0.25
		out[i] = (sin(TAU * freq * t * (1.0 - t * 2.0)) * exp(-t * 28.0) * 0.8 + lp * noise * exp(-t * 45.0)) * 0.9
	return out


func _burst(seconds: float, cutoff: float, decay: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * cutoff
		var env := exp(-t * decay) * minf(t * 60.0, 1.0)
		out[i] = clampf(lp * env * (2.0 if cutoff > 0.1 else 9.0) * (0.7 + 0.3 * sin(t * 23.0)), -1.0, 1.0)
	return out
