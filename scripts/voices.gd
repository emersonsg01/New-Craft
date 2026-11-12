class_name Voices
extends RefCounted
## Vozes das criaturas, 100% sintetizadas (sem arquivos de audio).
## Cada especie e montada com: fonte vocal (serra/pulso com vibrato, tremor e aspereza) passando por
## filtros de formantes (as "vogais"), ruidos filtrados (chiados, bufadas, estalos), sinos FM e eco.
## As vozes de uma especie sao geradas numa thread na primeira vez que ela aparece perto do jogador.

const RATE := 22050

## [especie] -> {evento: [AudioStreamWAV, ...]}
static var _cache: Dictionary = {}
static var _busy: Dictionary = {}
static var _lock := Mutex.new()


## Som pronto para tocar (variante sorteada) ou null se ainda nao foi gerado (pede a geracao).
static func get_sound(key: String, ev: String) -> AudioStreamWAV:
	_lock.lock()
	var set_v: Variant = _cache.get(key)
	var busy: bool = _busy.has(key)
	if set_v == null and not busy:
		_busy[key] = true
	_lock.unlock()
	if set_v == null:
		if not busy:
			WorkerThreadPool.add_task(_build_task.bind(key), false, "vozes " + key)
		return null
	var list: Array = (set_v as Dictionary).get(ev, [])
	if list.is_empty():
		return null
	return list[randi() % list.size()]


## Gera tudo de uma vez (testes e ferramentas).
static func build_now(key: String) -> Dictionary:
	var d := _build(key)
	_lock.lock()
	_cache[key] = d
	_lock.unlock()
	return d


static func _build_task(key: String) -> void:
	var d := _build(key)
	_lock.lock()
	_cache[key] = d
	_busy.erase(key)
	_lock.unlock()


static func _build(key: String) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash(key)
	var raw: Dictionary = _design(key, r)
	var out := {}
	for ev: String in raw:
		var arr: Array = []
		for buf: PackedFloat32Array in raw[ev]:
			arr.append(_wav(_finish(buf)))
		out[ev] = arr
	return out


# ===================================================================== projetos das especies

static func _design(key: String, r: RandomNumberGenerator) -> Dictionary:
	match key:
		"vaca":
			return {
				"idle": [_moo(r, 1.5, 1.0), _moo(r, 1.1, 1.08), _moo(r, 1.8, 0.94)],
				"hurt": [_moo(r, 0.45, 1.35)],
				"death": [_moo(r, 1.6, 0.8, true)]}
		"porco":
			return {"idle": [_oink(r, 2), _oink(r, 3), _snort(r)], "hurt": [_squeal(r, 0.5)], "death": [_squeal(r, 1.1)]}
		"ovelha":
			return {"idle": [_bleat(r, 300.0, 1.0, 8.5), _bleat(r, 330.0, 0.8, 9.5)], "hurt": [_bleat(r, 420.0, 0.4, 12.0)],
				"death": [_bleat(r, 260.0, 1.2, 6.0, true)]}
		"cabra":
			# Berro quase humano, nasal e rachado.
			return {"idle": [_bleat(r, 380.0, 0.9, 11.0, false, 0.5), _bleat(r, 420.0, 1.3, 13.0, false, 0.6)],
				"hurt": [_bleat(r, 520.0, 0.5, 15.0, false, 0.6)], "death": [_bleat(r, 340.0, 1.4, 9.0, true, 0.5)]}
		"galinha":
			return {"idle": [_cluck(r, 4), _cluck(r, 6), _bawk(r)], "hurt": [_bawk(r, 1.3)], "death": [_bawk(r, 0.8)]}
		"pato":
			return {"idle": [_quack(r, 2), _quack(r, 3), _quack(r, 1)], "hurt": [_quack(r, 1, 1.3)], "death": [_quack(r, 2, 0.8)]}
		"coelho":
			return {"idle": [_sniff(r)], "hurt": [_squeak(r, 1400.0, 0.18)], "death": [_squeak(r, 1100.0, 0.35)]}
		"cervo":
			return {"idle": [_deer_call(r), _sniff(r)], "hurt": [_squeak(r, 900.0, 0.3)], "death": [_deer_call(r, 0.7)]}
		"raposa":
			# Raposas soltam gritos agudos e latidinhos.
			return {"idle": [_yip(r, 3), _fox_scream(r)], "hurt": [_yip(r, 1, 1.25)], "death": [_fox_scream(r, 0.8)]}
		"lobo":
			return {"idle": [_howl(r, 2.6), _howl(r, 2.0), _growl(r, 0.9, 95.0)], "night": [_howl(r, 3.2), _howl(r, 2.8)],
				"attack": [_growl(r, 0.5, 120.0), _bark(r)], "hurt": [_yelp(r)], "death": [_yelp(r, 1.6)]}
		"urso":
			return {"idle": [_growl(r, 1.2, 70.0), _huff(r)], "attack": [_roar(r, 1.3, 85.0)], "hurt": [_roar(r, 0.6, 120.0)],
				"death": [_roar(r, 1.8, 65.0, true)]}
		"cavalo":
			return {"idle": [_neigh(r), _snort(r, 0.7), _neigh(r, 0.85)], "hurt": [_neigh(r, 1.2, 0.6)], "death": [_neigh(r, 0.7, 1.4)]}
		"burro":
			return {"idle": [_heehaw(r, 3), _heehaw(r, 4)], "hurt": [_heehaw(r, 1)], "death": [_heehaw(r, 2, 0.8)]}
		"camelo":
			return {"idle": [_gurgle(r, 1.6), _gurgle(r, 1.1)], "hurt": [_gurgle(r, 0.5, 1.4)], "death": [_gurgle(r, 1.8, 0.75)]}
		"andarilho":
			return {"idle": [_groan(r, 1.4, 85.0), _groan(r, 1.0, 95.0)], "attack": [_groan(r, 0.5, 120.0, 0.9)],
				"hurt": [_groan(r, 0.4, 140.0)], "death": [_groan(r, 1.8, 70.0, 0.6, true)]}
		"mumia":
			# Respiracao arenosa e um gemido seco.
			return {"idle": [_mummy(r, 1.6), _mummy(r, 1.2)], "attack": [_mummy(r, 0.6, 1.3)], "hurt": [_mummy(r, 0.5, 1.5)],
				"death": [_mummy(r, 2.0, 0.7)]}
		"esqueleto":
			return {"idle": [_rattle(r, 10), _rattle(r, 6)], "attack": [_rattle(r, 4, 1.4)], "hurt": [_rattle(r, 8, 1.2)],
				"death": [_collapse(r)]}
		"aranha":
			return {"idle": [_chitter(r, 0.6), _hiss(r, 0.7, 4200.0)], "attack": [_hiss(r, 0.4, 3000.0)], "hurt": [_chitter(r, 0.3, 1.4)],
				"death": [_chitter(r, 0.9, 0.7)]}
		"gosma":
			return {"idle": [_squelch(r, 3), _squelch(r, 2)], "attack": [_squelch(r, 1, 0.8)], "hurt": [_squelch(r, 2, 1.4)],
				"death": [_squelch(r, 5, 0.7)]}
		"espectro":
			return {"idle": [_wail(r, 2.2), _whisper(r)], "attack": [_wail(r, 0.8, 1.4)], "hurt": [_wail(r, 0.5, 1.7)],
				"death": [_wail(r, 2.6, 0.7)]}
		"golem":
			return {"idle": [_rumble(r, 1.6), _grind(r)], "attack": [_rumble(r, 0.7, 1.3), _grind(r)], "hurt": [_clank(r)],
				"death": [_collapse(r, 0.5), _rumble(r, 2.2, 0.7)]}
		"salamandra":
			return {"idle": [_hiss(r, 0.8, 2600.0, true), _crackle(r, 0.8)], "attack": [_hiss(r, 0.5, 2000.0, true)],
				"hurt": [_squeak(r, 700.0, 0.25)], "death": [_crackle(r, 1.4)]}
		"chama":
			return {"idle": [_flame(r, 1.4), _flame(r, 1.0)], "attack": [_whoosh(r)], "hurt": [_crackle(r, 0.4)], "death": [_whoosh(r, 1.6)]}
		"vigia":
			# Cristal vivo: zumbido e acordes de sino inarmonicos.
			return {"idle": [_crystal(r, 2.0), _crystal(r, 1.4)], "attack": [_zap(r)], "hurt": [_chime(r, 0.6)], "death": [_shatter(r)]}
		"goblin":
			return {"idle": [_cackle(r, 5, 420.0), _gibber(r, 3, 380.0, 0.6)], "attack": [_cackle(r, 3, 520.0)], "hurt": [_ouch(r, 520.0)],
				"death": [_ouch(r, 400.0, 1.8)]}
		"ogro":
			return {"idle": [_roar(r, 1.0, 60.0), _ogre_grunt(r)], "attack": [_roar(r, 1.2, 70.0)], "hurt": [_ogre_grunt(r, 1.3)],
				"death": [_roar(r, 2.2, 50.0, true)]}
		"bandido":
			return {"idle": [_laugh(r, 110.0), _gibber(r, 4, 115.0, 1.0)], "attack": [_shout(r, 125.0)], "hurt": [_ouch(r, 140.0)],
				"death": [_ouch(r, 110.0, 2.0)], "talk": [_gibber(r, 5, 112.0, 1.0)]}
		"aldeao", "aldeao_f":
			var f0 := 210.0 if key == "aldeao_f" else 118.0
			var fs := 1.18 if key == "aldeao_f" else 1.0
			var talk: Array = []
			for i in 6:
				talk.append(_gibber(r, r.randi_range(3, 6), f0 * r.randf_range(0.92, 1.08), fs))
			return {"idle": [_hmm(r, f0, fs), _hmm(r, f0 * 1.05, fs, true)], "talk": talk, "hurt": [_ouch(r, f0 * 1.15, 1.0, fs)],
				"death": [_ouch(r, f0, 2.0, fs)]}
	return {}


# ---------------------------------------------------------------- animais da fazenda

static func _moo(r: RandomNumberGenerator, dur: float, p: float, dying: bool = false) -> PackedFloat32Array:
	# "Mmmuuuuoo": comeca de boca fechada (nasal), abre em "u" -> "o" e cai no fim.
	var f := 105.0 * p
	return voice(dur, {
		"f0": [[0.0, f * 0.92], [0.15, f * 1.08], [0.7, f], [1.0, f * (0.7 if dying else 0.86)]],
		"form": [[0.0, 260, 700, 2100], [0.2, 330, 760, 2200], [0.75, 520, 880, 2300], [1.0, 420, 820, 2200]],
		"amp": [[0.0, 0.0], [0.08, 0.6], [0.25, 1.0], [0.85, 0.85], [1.0, 0.0]],
		"vib": [4.5, 0.012], "jitter": 0.012, "breath": 0.06, "rough": 0.15 if dying else 0.05, "bw": 0.9}, r)


static func _oink(r: RandomNumberGenerator, n: int) -> PackedFloat32Array:
	var parts: Array = []
	for i in n:
		var d := r.randf_range(0.12, 0.2)
		var g := voice(d, {
			"f0": [[0.0, 210.0], [0.5, 260.0], [1.0, 170.0]], "shape": "pulse",
			"form": [[0.0, 650, 1500, 2600], [1.0, 800, 1900, 2900]],
			"amp": [[0.0, 0.0], [0.15, 1.0], [0.7, 0.6], [1.0, 0.0]],
			"rough": 0.55, "breath": 0.25, "jitter": 0.03, "bw": 1.4}, r)
		parts.append([g, r.randf_range(0.05, 0.12)])
	return seq(parts)


static func _snort(r: RandomNumberGenerator, p: float = 1.0) -> PackedFloat32Array:
	# Bufada: ar pelo focinho, com "batida" das narinas.
	return noise(0.45 / p, {"fc": [[0.0, 900.0 * p], [0.5, 1400.0 * p], [1.0, 600.0 * p]], "q": 3.0,
		"amp": [[0.0, 0.0], [0.05, 1.0], [0.35, 0.5], [1.0, 0.0]], "flutter": [38.0, 0.7]}, r)


static func _squeal(r: RandomNumberGenerator, dur: float) -> PackedFloat32Array:
	return voice(dur, {
		"f0": [[0.0, 700.0], [0.3, 1100.0], [1.0, 800.0]], "shape": "pulse",
		"form": [[0.0, 900, 2200, 3200], [1.0, 1000, 2400, 3300]],
		"amp": [[0.0, 0.0], [0.08, 1.0], [0.8, 0.8], [1.0, 0.0]],
		"vib": [11.0, 0.04], "rough": 0.4, "jitter": 0.03, "bw": 1.2}, r)


static func _bleat(r: RandomNumberGenerator, f: float, dur: float, trem: float, dying: bool = false, crack: float = 0.2) -> PackedFloat32Array:
	# "Méééé": o tremor rapido de amplitude e pitch e o que faz o balido.
	return voice(dur, {
		"f0": [[0.0, f * 0.9], [0.1, f * 1.05], [0.8, f], [1.0, f * (0.7 if dying else 0.92)]],
		"form": [[0.0, 450, 1600, 2500], [0.3, 560, 1850, 2600], [1.0, 520, 1700, 2500]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [0.8, 0.8], [1.0, 0.0]],
		"trem": [trem, 0.55], "vib": [trem, 0.035], "jitter": 0.02 + crack * 0.03, "rough": crack, "bw": 1.1, "nasal": 0.35}, r)


static func _cluck(r: RandomNumberGenerator, n: int) -> PackedFloat32Array:
	var parts: Array = []
	for i in n:
		var f := r.randf_range(520.0, 760.0)
		var g := voice(r.randf_range(0.05, 0.09), {
			"f0": [[0.0, f * 1.3], [1.0, f * 0.8]], "shape": "pulse",
			"form": [[0.0, 900, 1900, 3000], [1.0, 700, 1500, 2800]],
			"amp": [[0.0, 0.0], [0.1, 1.0], [1.0, 0.0]], "rough": 0.3, "bw": 1.6}, r)
		parts.append([g, r.randf_range(0.06, 0.18)])
	return seq(parts)


static func _bawk(r: RandomNumberGenerator, p: float = 1.0) -> PackedFloat32Array:
	# "Pó-pó-póóóó!": dois cacarejos curtos e um longo que sobe.
	var a := _cluck(r, 2)
	var b := voice(0.45, {
		"f0": [[0.0, 600.0 * p], [0.4, 980.0 * p], [1.0, 760.0 * p]], "shape": "pulse",
		"form": [[0.0, 800, 1800, 3000], [1.0, 950, 2100, 3100]],
		"amp": [[0.0, 0.0], [0.1, 1.0], [0.8, 0.7], [1.0, 0.0]], "rough": 0.35, "vib": [9.0, 0.03], "bw": 1.3}, r)
	return seq([[a, 0.04], [b, 0.0]])


static func _quack(r: RandomNumberGenerator, n: int, p: float = 1.0) -> PackedFloat32Array:
	var parts: Array = []
	for i in n:
		var g := voice(r.randf_range(0.14, 0.22), {
			"f0": [[0.0, 300.0 * p], [0.3, 330.0 * p], [1.0, 230.0 * p]], "shape": "pulse",
			"form": [[0.0, 900, 1600, 2600], [0.4, 1100, 2000, 3000], [1.0, 800, 1500, 2600]],
			"amp": [[0.0, 0.0], [0.1, 1.0], [0.6, 0.8], [1.0, 0.0]], "rough": 0.5, "nasal": 0.7, "bw": 0.8}, r)
		parts.append([g, r.randf_range(0.07, 0.15)])
	return seq(parts)


static func _sniff(r: RandomNumberGenerator) -> PackedFloat32Array:
	var parts: Array = []
	for i in 3:
		parts.append([noise(0.07, {"fc": [[0.0, 3000.0], [1.0, 4200.0]], "q": 2.0, "amp": [[0.0, 0.0], [0.3, 0.7], [1.0, 0.0]]}, r), 0.06])
	return seq(parts)


static func _squeak(r: RandomNumberGenerator, f: float, dur: float) -> PackedFloat32Array:
	return voice(dur, {"f0": [[0.0, f], [0.3, f * 1.4], [1.0, f * 0.9]], "shape": "sine",
		"amp": [[0.0, 0.0], [0.1, 1.0], [1.0, 0.0]], "vib": [16.0, 0.05]}, r)


static func _deer_call(r: RandomNumberGenerator, p: float = 1.0) -> PackedFloat32Array:
	# Assobio agudo dos cervos (ronco curto + apito que sobe).
	var grunt := voice(0.25, {"f0": [[0.0, 140.0], [1.0, 120.0]], "form": [[0.0, 400, 900, 2300]],
		"amp": [[0.0, 0.0], [0.2, 0.7], [1.0, 0.0]], "rough": 0.4}, r)
	var whistle := voice(1.1, {"f0": [[0.0, 700.0 * p], [0.3, 1250.0 * p], [0.8, 1150.0 * p], [1.0, 800.0 * p]], "shape": "sine",
		"amp": [[0.0, 0.0], [0.15, 1.0], [0.8, 0.7], [1.0, 0.0]], "vib": [6.0, 0.02], "breath": 0.25}, r)
	return seq([[grunt, 0.05], [whistle, 0.0]])


# ---------------------------------------------------------------- feras

static func _howl(r: RandomNumberGenerator, dur: float) -> PackedFloat32Array:
	# Uivo: sobe devagar, segura com vibrato e cai; com eco de vale.
	var b := r.randf_range(0.9, 1.1)
	var h := voice(dur, {
		"f0": [[0.0, 360.0 * b], [0.25, 620.0 * b], [0.6, 660.0 * b], [0.85, 600.0 * b], [1.0, 380.0 * b]],
		"form": [[0.0, 350, 800, 2400], [0.3, 480, 900, 2500], [1.0, 330, 760, 2300]],
		"amp": [[0.0, 0.0], [0.15, 0.8], [0.4, 1.0], [0.85, 0.8], [1.0, 0.0]],
		"vib": [5.5, 0.015], "jitter": 0.006, "breath": 0.1, "bw": 0.7}, r)
	return echo(h, 0.31, 0.32, 3)


static func _growl(r: RandomNumberGenerator, dur: float, f: float) -> PackedFloat32Array:
	return voice(dur, {"f0": [[0.0, f * 0.9], [0.5, f * 1.1], [1.0, f * 0.85]], "form": [[0.0, 380, 950, 2300], [1.0, 450, 1100, 2400]],
		"amp": [[0.0, 0.0], [0.15, 1.0], [0.85, 0.9], [1.0, 0.0]], "rough": 0.9, "trem": [24.0, 0.45], "jitter": 0.05, "breath": 0.3}, r)


static func _bark(r: RandomNumberGenerator) -> PackedFloat32Array:
	var parts: Array = []
	for i in 2:
		parts.append([voice(0.13, {"f0": [[0.0, 420.0], [0.3, 520.0], [1.0, 300.0]], "form": [[0.0, 650, 1300, 2600]],
			"amp": [[0.0, 0.0], [0.08, 1.0], [1.0, 0.0]], "rough": 0.6, "breath": 0.3}, r), 0.12])
	return seq(parts)


static func _yelp(r: RandomNumberGenerator, dur: float = 0.35) -> PackedFloat32Array:
	return voice(dur, {"f0": [[0.0, 1000.0], [0.2, 1150.0], [1.0, 520.0]], "form": [[0.0, 800, 1700, 3000]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [1.0, 0.0]], "vib": [12.0, 0.03], "rough": 0.2}, r)


static func _yip(r: RandomNumberGenerator, n: int, p: float = 1.0) -> PackedFloat32Array:
	var parts: Array = []
	for i in n:
		parts.append([voice(0.1, {"f0": [[0.0, 900.0 * p], [0.4, 1250.0 * p], [1.0, 800.0 * p]], "form": [[0.0, 1000, 2000, 3200]],
			"amp": [[0.0, 0.0], [0.1, 1.0], [1.0, 0.0]], "rough": 0.3}, r), r.randf_range(0.1, 0.2)])
	return seq(parts)


static func _fox_scream(r: RandomNumberGenerator, p: float = 1.0) -> PackedFloat32Array:
	return voice(0.8, {"f0": [[0.0, 700.0 * p], [0.2, 1300.0 * p], [1.0, 600.0 * p]], "form": [[0.0, 900, 2100, 3300], [1.0, 700, 1600, 3000]],
		"amp": [[0.0, 0.0], [0.08, 1.0], [0.6, 0.8], [1.0, 0.0]], "rough": 0.7, "jitter": 0.04, "breath": 0.3}, r)


static func _roar(r: RandomNumberGenerator, dur: float, f: float, dying: bool = false) -> PackedFloat32Array:
	var v := voice(dur, {"f0": [[0.0, f * 0.8], [0.25, f * 1.3], [0.7, f * 1.1], [1.0, f * (0.6 if dying else 0.9)]],
		"form": [[0.0, 400, 900, 2200], [0.3, 650, 1100, 2400], [1.0, 450, 900, 2200]],
		"amp": [[0.0, 0.0], [0.12, 1.0], [0.75, 0.9], [1.0, 0.0]], "rough": 1.0, "trem": [18.0, 0.35], "jitter": 0.06, "breath": 0.45, "bw": 1.3}, r)
	return v


static func _huff(r: RandomNumberGenerator) -> PackedFloat32Array:
	var parts: Array = []
	for i in 2:
		parts.append([noise(0.3, {"fc": [[0.0, 500.0], [1.0, 350.0]], "q": 2.0, "amp": [[0.0, 0.0], [0.1, 1.0], [1.0, 0.0]], "flutter": [30.0, 0.5]}, r), 0.2])
	return seq(parts)


# ---------------------------------------------------------------- montarias

static func _neigh(r: RandomNumberGenerator, p: float = 1.0, dur_k: float = 1.0) -> PackedFloat32Array:
	# Relincho: ataque agudo, trinado rapido que desce, e uma bufada no fim.
	var main := voice(1.3 * dur_k, {
		"f0": [[0.0, 520.0 * p], [0.1, 760.0 * p], [0.35, 640.0 * p], [0.7, 420.0 * p], [1.0, 260.0 * p]],
		"form": [[0.0, 700, 1600, 2800], [0.5, 600, 1300, 2600], [1.0, 450, 1000, 2400]],
		"amp": [[0.0, 0.0], [0.05, 1.0], [0.6, 0.85], [1.0, 0.0]],
		"vib": [17.0, 0.09], "trem": [17.0, 0.5], "rough": 0.35, "jitter": 0.02, "breath": 0.2}, r)
	return seq([[main, -0.1], [_snort(r, 0.8), 0.0]])


static func _heehaw(r: RandomNumberGenerator, n: int, p: float = 1.0) -> PackedFloat32Array:
	# "Hii-ó": inspiracao aguda e aspera, expiracao grave e cheia.
	var parts: Array = []
	for i in n:
		parts.append([voice(0.32, {"f0": [[0.0, 650.0 * p], [1.0, 720.0 * p]], "form": [[0.0, 600, 2100, 3000]],
			"amp": [[0.0, 0.0], [0.2, 0.8], [1.0, 0.1]], "rough": 0.6, "breath": 0.6, "shape": "pulse"}, r), 0.0])
		parts.append([voice(0.42, {"f0": [[0.0, 260.0 * p], [0.3, 230.0 * p], [1.0, 170.0 * p]], "form": [[0.0, 700, 1100, 2500]],
			"amp": [[0.0, 0.0], [0.1, 1.0], [1.0, 0.0]], "rough": 0.5, "breath": 0.2}, r), 0.05])
	return seq(parts)


static func _gurgle(r: RandomNumberGenerator, dur: float, p: float = 1.0) -> PackedFloat32Array:
	# Camelo: ronco grave borbulhante.
	return voice(dur, {"f0": [[0.0, 90.0 * p], [0.5, 120.0 * p], [1.0, 80.0 * p]], "form": [[0.0, 300, 700, 2000], [0.5, 500, 900, 2200], [1.0, 350, 750, 2000]],
		"amp": [[0.0, 0.0], [0.1, 1.0], [0.9, 0.8], [1.0, 0.0]], "rough": 1.0, "trem": [9.0, 0.7], "jitter": 0.08, "breath": 0.3, "bubble": 0.6}, r)


# ---------------------------------------------------------------- mortos-vivos e monstros

static func _groan(r: RandomNumberGenerator, dur: float, f: float, open: float = 0.5, dying: bool = false) -> PackedFloat32Array:
	return voice(dur, {"f0": [[0.0, f], [0.4, f * 1.15], [1.0, f * (0.6 if dying else 0.85)]],
		"form": [[0.0, 350, 900, 2300], [0.4, 450 + open * 300, 1000 + open * 200, 2400], [1.0, 380, 850, 2300]],
		"amp": [[0.0, 0.0], [0.2, 1.0], [0.8, 0.8], [1.0, 0.0]], "rough": 0.8, "jitter": 0.1, "breath": 0.5, "trem": [6.0, 0.3]}, r)


static func _mummy(r: RandomNumberGenerator, dur: float, p: float = 1.0) -> PackedFloat32Array:
	var breath := noise(dur, {"fc": [[0.0, 1800.0 * p], [0.5, 2600.0 * p], [1.0, 1500.0 * p]], "q": 1.5,
		"amp": [[0.0, 0.0], [0.3, 0.8], [1.0, 0.0]], "crackle": 0.4}, r)
	var moan := voice(dur, {"f0": [[0.0, 75.0 * p], [0.5, 90.0 * p], [1.0, 65.0 * p]], "form": [[0.0, 300, 800, 2200]],
		"amp": [[0.0, 0.0], [0.4, 0.6], [1.0, 0.0]], "rough": 1.0, "jitter": 0.15, "breath": 0.7}, r)
	return mix(breath, moan, 0.0, 0.8)


static func _rattle(r: RandomNumberGenerator, n: int, p: float = 1.0) -> PackedFloat32Array:
	# Ossos batendo: estalos curtos ressonantes, em rajadas irregulares.
	var out := PackedFloat32Array()
	out.resize(int(RATE * (0.1 + n * 0.06)))
	var t := 0.02
	for i in n:
		var c := noise(0.035, {"fc": [[0.0, r.randf_range(1800.0, 3200.0) * p]], "q": 12.0, "amp": [[0.0, 1.0], [1.0, 0.0]]}, r)
		out = mix(out, c, t, r.randf_range(0.6, 1.0))
		t += r.randf_range(0.025, 0.09)
	return out


static func _collapse(r: RandomNumberGenerator, p: float = 1.0) -> PackedFloat32Array:
	var out := _rattle(r, 16, 0.8 * p)
	return mix(out, noise(0.4, {"fc": [[0.0, 300.0 * p]], "q": 1.0, "amp": [[0.0, 0.0], [0.05, 1.0], [1.0, 0.0]]}, r), 0.35, 0.8)


static func _chitter(r: RandomNumberGenerator, dur: float, p: float = 1.0) -> PackedFloat32Array:
	var out := _hiss(r, dur, 3800.0 * p)
	var t := 0.0
	while t < dur:
		var c := noise(0.012, {"fc": [[0.0, 5000.0 * p]], "q": 8.0, "amp": [[0.0, 1.0], [1.0, 0.0]]}, r)
		out = mix(out, c, t, 0.9)
		t += r.randf_range(0.02, 0.05)
	return out


static func _hiss(r: RandomNumberGenerator, dur: float, fc: float, fiery: bool = false) -> PackedFloat32Array:
	var h := noise(dur, {"fc": [[0.0, fc], [0.5, fc * 1.2], [1.0, fc * 0.9]], "q": 1.2,
		"amp": [[0.0, 0.0], [0.15, 1.0], [0.8, 0.8], [1.0, 0.0]], "crackle": 0.5 if fiery else 0.0}, r)
	return h


static func _squelch(r: RandomNumberGenerator, n: int, p: float = 1.0) -> PackedFloat32Array:
	# Gosma: bolhas (senos que sobem rapido) num fundo molhado.
	var out := noise(0.15 + n * 0.12, {"fc": [[0.0, 500.0 * p]], "q": 2.0, "amp": [[0.0, 0.0], [0.2, 0.35], [1.0, 0.0]]}, r)
	var t := 0.0
	for i in n:
		var f := r.randf_range(140.0, 260.0) * p
		var b := voice(r.randf_range(0.06, 0.12), {"f0": [[0.0, f], [1.0, f * 2.6]], "shape": "sine", "amp": [[0.0, 0.0], [0.2, 1.0], [1.0, 0.0]]}, r)
		out = mix(out, b, t, 1.0)
		t += r.randf_range(0.07, 0.14)
	return out


static func _wail(r: RandomNumberGenerator, dur: float, p: float = 1.0) -> PackedFloat32Array:
	# Lamento fantasmagorico: tres vozes desafinadas em coro + sopro, com eco longo.
	var out := PackedFloat32Array()
	for k in 3:
		var det := 1.0 + (k - 1) * 0.012
		var v := voice(dur, {"f0": [[0.0, 420.0 * p * det], [0.4, 760.0 * p * det], [0.7, 640.0 * p * det], [1.0, 380.0 * p * det]],
			"form": [[0.0, 320, 820, 2300], [0.5, 380, 900, 2400], [1.0, 300, 780, 2200]],
			"amp": [[0.0, 0.0], [0.3, 1.0], [0.8, 0.7], [1.0, 0.0]], "vib": [4.0 + k, 0.025], "breath": 0.5, "bw": 0.6}, r)
		out = v if k == 0 else mix(out, v, 0.0, 0.8)
	return echo(out, 0.23, 0.45, 4)


static func _whisper(r: RandomNumberGenerator) -> PackedFloat32Array:
	# Sussurro sem voz: so o ar passando pelas "vogais".
	var parts: Array = []
	for i in 5:
		parts.append([voice(r.randf_range(0.12, 0.22), {"f0": [[0.0, 200.0]], "breath": 1.0, "voiced": 0.0,
			"form": [[0.0, r.randf_range(300, 750), r.randf_range(900, 2200), 2600]], "amp": [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]]}, r), 0.03])
	return echo(seq(parts), 0.19, 0.4, 3)


static func _rumble(r: RandomNumberGenerator, dur: float, p: float = 1.0) -> PackedFloat32Array:
	# Golem: ronco de pedra muito grave com atrito.
	var v := voice(dur, {"f0": [[0.0, 42.0 * p], [0.5, 55.0 * p], [1.0, 38.0 * p]], "form": [[0.0, 250, 600, 1800]],
		"amp": [[0.0, 0.0], [0.2, 1.0], [0.8, 0.9], [1.0, 0.0]], "rough": 1.0, "jitter": 0.1, "trem": [7.0, 0.5]}, r)
	return mix(v, noise(dur, {"fc": [[0.0, 220.0 * p]], "q": 1.5, "amp": [[0.0, 0.0], [0.3, 0.6], [1.0, 0.0]], "crackle": 0.7}, r), 0.0, 0.7)


static func _grind(r: RandomNumberGenerator) -> PackedFloat32Array:
	return noise(0.7, {"fc": [[0.0, 700.0], [0.5, 1100.0], [1.0, 500.0]], "q": 4.0, "amp": [[0.0, 0.0], [0.2, 0.8], [1.0, 0.0]],
		"crackle": 0.9, "flutter": [13.0, 0.6]}, r)


static func _clank(r: RandomNumberGenerator) -> PackedFloat32Array:
	return mix(_bell(r, 0.6, 180.0, 1.41, 3.0, 4.0), noise(0.1, {"fc": [[0.0, 1500.0]], "q": 2.0, "amp": [[0.0, 1.0], [1.0, 0.0]]}, r), 0.0, 0.6)


static func _crackle(r: RandomNumberGenerator, dur: float) -> PackedFloat32Array:
	var out := noise(dur, {"fc": [[0.0, 900.0]], "q": 1.0, "amp": [[0.0, 0.0], [0.2, 0.25], [1.0, 0.0]]}, r)
	var t := 0.0
	while t < dur:
		out = mix(out, noise(0.008, {"fc": [[0.0, r.randf_range(2000.0, 6000.0)]], "q": 3.0, "amp": [[0.0, 1.0], [1.0, 0.0]]}, r), t, r.randf_range(0.4, 1.0))
		t += r.randf_range(0.01, 0.08)
	return out


static func _flame(r: RandomNumberGenerator, dur: float) -> PackedFloat32Array:
	var roar := noise(dur, {"fc": [[0.0, 350.0], [0.5, 600.0], [1.0, 300.0]], "q": 0.8, "amp": [[0.0, 0.0], [0.2, 1.0], [0.8, 0.9], [1.0, 0.0]],
		"flutter": [11.0, 0.5]}, r)
	return mix(roar, _crackle(r, dur), 0.0, 0.6)


static func _whoosh(r: RandomNumberGenerator, dur: float = 0.6) -> PackedFloat32Array:
	return noise(dur, {"fc": [[0.0, 300.0], [0.4, 2200.0], [1.0, 500.0]], "q": 2.5, "amp": [[0.0, 0.0], [0.35, 1.0], [1.0, 0.0]]}, r)


static func _crystal(r: RandomNumberGenerator, dur: float) -> PackedFloat32Array:
	# Zumbido harmonico + sinos de cristal em intervalos estranhos.
	var hum := voice(dur, {"f0": [[0.0, 220.0], [1.0, 233.0]], "shape": "sine", "amp": [[0.0, 0.0], [0.3, 0.35], [0.7, 0.35], [1.0, 0.0]],
		"vib": [3.0, 0.01]}, r)
	var out := hum
	var notes := [880.0, 1244.5, 1661.2, 987.8, 1396.9]
	for i in 3:
		out = mix(out, _bell(r, 1.2, notes[r.randi() % notes.size()], 2.76, 2.0, 2.5), r.randf_range(0.0, dur * 0.6), 0.5)
	return echo(out, 0.17, 0.35, 3)


static func _chime(r: RandomNumberGenerator, dur: float) -> PackedFloat32Array:
	return _bell(r, dur, 1500.0, 3.17, 3.0, 6.0)


static func _zap(r: RandomNumberGenerator) -> PackedFloat32Array:
	var z := voice(0.35, {"f0": [[0.0, 1800.0], [1.0, 300.0]], "shape": "pulse", "amp": [[0.0, 1.0], [1.0, 0.0]]}, r)
	return echo(z, 0.07, 0.4, 3)


static func _shatter(r: RandomNumberGenerator) -> PackedFloat32Array:
	var out := noise(0.5, {"fc": [[0.0, 5000.0], [1.0, 3000.0]], "q": 1.0, "amp": [[0.0, 1.0], [1.0, 0.0]]}, r)
	for i in 6:
		out = mix(out, _bell(r, 0.9, r.randf_range(1500.0, 4200.0), 2.3, 1.5, 5.0), r.randf_range(0.0, 0.25), 0.4)
	return out


# ---------------------------------------------------------------- humanoides

static func _gibber(r: RandomNumberGenerator, n: int, f0: float, fs: float) -> PackedFloat32Array:
	# Fala inventada: silabas consoante + vogal, com entoacao de frase (ou pergunta).
	var vowels := [[730, 1090, 2440], [530, 1840, 2480], [270, 2290, 3010], [570, 840, 2410], [300, 870, 2240], [660, 1700, 2400]]
	var question := r.randf() < 0.35
	var parts: Array = []
	for i in n:
		var t := float(i) / maxf(n - 1, 1)
		var pitch := f0 * (1.0 + 0.12 * sin(t * PI) + (0.35 * t * t if question else -0.15 * t))
		var v: Array = vowels[r.randi() % vowels.size()]
		var v2: Array = vowels[r.randi() % vowels.size()]
		var cons := r.randi() % 4
		if cons == 1:
			parts.append([noise(0.05, {"fc": [[0.0, 4500.0 * fs]], "q": 2.0, "amp": [[0.0, 0.0], [0.3, 0.5], [1.0, 0.0]]}, r), 0.0])
		elif cons == 2:
			parts.append([noise(0.015, {"fc": [[0.0, 1500.0 * fs]], "q": 1.0, "amp": [[0.0, 1.0], [1.0, 0.0]]}, r), 0.01])
		var dur := r.randf_range(0.09, 0.17) * (1.5 if i == n - 1 else 1.0)
		parts.append([voice(dur, {"f0": [[0.0, pitch * 1.03], [1.0, pitch * 0.97]],
			"form": [[0.0, v[0] * fs, v[1] * fs, v[2] * fs], [1.0, v2[0] * fs, v2[1] * fs, v2[2] * fs]],
			"amp": [[0.0, 0.0], [0.15, 1.0], [0.75, 0.8], [1.0, 0.0]], "jitter": 0.01, "breath": 0.08,
			"nasal": 0.4 if cons == 3 else 0.0}, r), r.randf_range(0.01, 0.06)])
	return seq(parts)


static func _hmm(r: RandomNumberGenerator, f0: float, fs: float, thinking: bool = false) -> PackedFloat32Array:
	# "Hmm" (boca fechada) ou "Hm-hm!" curto e animado.
	if thinking:
		return voice(0.7, {"f0": [[0.0, f0 * 1.05], [0.5, f0 * 0.95], [1.0, f0 * 1.1]], "form": [[0.0, 250 * fs, 1000 * fs, 2300 * fs]],
			"amp": [[0.0, 0.0], [0.2, 0.9], [0.8, 0.7], [1.0, 0.0]], "nasal": 1.0, "vib": [5.0, 0.01]}, r)
	var a := voice(0.18, {"f0": [[0.0, f0 * 1.1], [1.0, f0 * 1.25]], "form": [[0.0, 260 * fs, 1100 * fs, 2300 * fs]],
		"amp": [[0.0, 0.0], [0.2, 1.0], [1.0, 0.0]], "nasal": 1.0}, r)
	var b := voice(0.25, {"f0": [[0.0, f0 * 1.2], [1.0, f0 * 0.95]], "form": [[0.0, 260 * fs, 1100 * fs, 2300 * fs]],
		"amp": [[0.0, 0.0], [0.2, 1.0], [1.0, 0.0]], "nasal": 1.0}, r)
	return seq([[a, 0.06], [b, 0.0]])


static func _ouch(r: RandomNumberGenerator, f0: float, dur_k: float = 1.0, fs: float = 1.0) -> PackedFloat32Array:
	# "Ai!" (ou um "aaah..." longo ao cair).
	return voice(0.3 * dur_k, {"f0": [[0.0, f0 * 1.5], [0.2, f0 * 1.7], [1.0, f0 * (0.7 if dur_k > 1.5 else 1.1)]],
		"form": [[0.0, 750 * fs, 1200 * fs, 2500 * fs], [1.0, 400 * fs, 2000 * fs, 2700 * fs]],
		"amp": [[0.0, 0.0], [0.08, 1.0], [0.7, 0.7], [1.0, 0.0]], "rough": 0.25, "breath": 0.15}, r)


static func _laugh(r: RandomNumberGenerator, f0: float) -> PackedFloat32Array:
	# "Ha-ha-ha!" grave do bandido.
	var parts: Array = []
	for i in 4:
		var p := f0 * (1.3 - i * 0.08)
		parts.append([noise(0.04, {"fc": [[0.0, 1400.0]], "q": 1.0, "amp": [[0.0, 0.0], [0.5, 0.6], [1.0, 0.0]]}, r), 0.0])
		parts.append([voice(0.13, {"f0": [[0.0, p], [1.0, p * 0.9]], "form": [[0.0, 750, 1200, 2500]],
			"amp": [[0.0, 0.0], [0.15, 1.0], [1.0, 0.0]], "rough": 0.4, "breath": 0.3}, r), 0.06])
	return seq(parts)


static func _cackle(r: RandomNumberGenerator, n: int, f0: float) -> PackedFloat32Array:
	# "Hi-hi-hi-hi" esganicado do goblin.
	var parts: Array = []
	for i in n:
		var p := f0 * (1.0 + i * 0.07)
		parts.append([voice(0.08, {"f0": [[0.0, p * 1.1], [1.0, p]], "form": [[0.0, 350, 2400, 3100]], "shape": "pulse",
			"amp": [[0.0, 0.0], [0.2, 1.0], [1.0, 0.0]], "rough": 0.5, "breath": 0.25}, r), 0.05])
	return seq(parts)


static func _shout(r: RandomNumberGenerator, f0: float) -> PackedFloat32Array:
	return voice(0.5, {"f0": [[0.0, f0 * 1.3], [0.3, f0 * 1.7], [1.0, f0 * 1.2]], "form": [[0.0, 700, 1150, 2500], [1.0, 600, 1000, 2400]],
		"amp": [[0.0, 0.0], [0.1, 1.0], [0.8, 0.8], [1.0, 0.0]], "rough": 0.6, "breath": 0.2}, r)


static func _ogre_grunt(r: RandomNumberGenerator, p: float = 1.0) -> PackedFloat32Array:
	var parts: Array = []
	for i in 2:
		parts.append([voice(0.3, {"f0": [[0.0, 70.0 * p], [1.0, 55.0 * p]], "form": [[0.0, 500, 900, 2000]],
			"amp": [[0.0, 0.0], [0.15, 1.0], [1.0, 0.0]], "rough": 0.9, "breath": 0.4}, r), 0.15])
	return seq(parts)


# ===================================================================== sintese

## Voz: fonte (serra, pulso ou seno) com vibrato/tremor/aspereza/sopro, filtrada por 3 formantes.
## Curvas ("f0", "form", "amp") sao listas de [t de 0 a 1, valores...].
static func voice(dur: float, o: Dictionary, r: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var f0c: Array = o.get("f0", [[0.0, 200.0]])
	var formc: Array = o.get("form", [])
	var ampc: Array = o.get("amp", [[0.0, 1.0]])
	var shape: String = o.get("shape", "saw")
	var vib: Array = o.get("vib", [0.0, 0.0])
	var trem: Array = o.get("trem", [0.0, 0.0])
	var jitter: float = o.get("jitter", 0.0)
	var breath: float = o.get("breath", 0.0)
	var rough: float = o.get("rough", 0.0)
	var nasal: float = o.get("nasal", 0.0)
	var bubble: float = o.get("bubble", 0.0)
	var voiced: float = o.get("voiced", 1.0)
	var bw: float = o.get("bw", 1.0)
	var phase := 0.0
	var jit := 0.0
	var rgh := 0.0
	var b1 := 0.0
	var l1 := 0.0
	var b2 := 0.0
	var l2 := 0.0
	var b3 := 0.0
	var l3 := 0.0
	var bn := 0.0
	var ln := 0.0
	var lpf := 0.0
	var fi := 0
	var ai := 0
	var pi_ := 0
	var vp := r.randf() * TAU
	var tp := r.randf() * TAU
	var bub := 0.0
	for i in n:
		var t := float(i) / n
		var ts := float(i) / RATE
		# Curvas (avanca o indice; sao poucas pontas).
		while pi_ < f0c.size() - 2 and t > f0c[pi_ + 1][0]:
			pi_ += 1
		var f0 := _seg(f0c, pi_, t, 1)
		if i % 64 == 0:
			jit = r.randf_range(-1.0, 1.0) * jitter
		f0 *= 1.0 + jit + vib[1] * sin(TAU * vib[0] * ts + vp)
		phase += f0 / RATE
		if phase >= 1.0:
			phase -= 1.0
			rgh = r.randf_range(-1.0, 1.0) * rough
			if bubble > 0.0 and r.randf() < 0.12:
				bub = 1.0
		var src := 0.0
		match shape:
			"sine":
				src = sin(TAU * phase)
			"pulse":
				src = 1.0 if phase < 0.3 else -0.43
			_:
				src = 1.0 - 2.0 * phase
		src *= (1.0 + rgh) * voiced
		bub *= 0.996
		src *= 1.0 - bubble * 0.6 * bub
		src += r.randf_range(-1.0, 1.0) * breath
		var s := src
		if not formc.is_empty():
			while fi < formc.size() - 2 and t > formc[fi + 1][0]:
				fi += 1
			var f1 := _seg(formc, fi, t, 1)
			var f2 := _seg(formc, fi, t, 2)
			var f3 := _seg(formc, fi, t, 3)
			var q1 := 0.16 * bw
			var c1 := 2.0 * sin(PI * minf(f1, 4800.0) / RATE)
			var h1 := src - l1 - q1 * b1
			b1 += c1 * h1
			l1 += c1 * b1
			var c2 := 2.0 * sin(PI * minf(f2, 4800.0) / RATE)
			var h2 := src - l2 - q1 * 0.8 * b2
			b2 += c2 * h2
			l2 += c2 * b2
			var c3 := 2.0 * sin(PI * minf(f3, 4800.0) / RATE)
			var h3 := src - l3 - q1 * 0.7 * b3
			b3 += c3 * h3
			l3 += c3 * b3
			s = b1 + b2 * 0.55 + b3 * 0.28
			if nasal > 0.0:
				# Ressonancia nasal grave (~250 Hz) e anti-ressonancia: o "mmm"/"nhé".
				var cn := 2.0 * sin(PI * 250.0 / RATE)
				var hn := src - ln - 0.2 * bn
				bn += cn * hn
				ln += cn * bn
				s = s * (1.0 - nasal * 0.7) + bn * nasal * 1.6
		elif shape != "sine":
			lpf += (s - lpf) * 0.3
			s = lpf
		while ai < ampc.size() - 2 and t > ampc[ai + 1][0]:
			ai += 1
		var a := _seg(ampc, ai, t, 1)
		a *= 1.0 - trem[1] * (0.5 + 0.5 * sin(TAU * trem[0] * ts + tp))
		out[i] = s * a
	return out


## Ruido filtrado (passa-banda variavel) com envelope, tremulacao ("flutter") e estalos ("crackle").
static func noise(dur: float, o: Dictionary, r: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var fcc: Array = o.get("fc", [[0.0, 1000.0]])
	var ampc: Array = o.get("amp", [[0.0, 1.0]])
	var q: float = o.get("q", 2.0)
	var fl: Array = o.get("flutter", [0.0, 0.0])
	var crackle: float = o.get("crackle", 0.0)
	var damp := 1.0 / q
	var b := 0.0
	var l := 0.0
	var fi := 0
	var ai := 0
	for i in n:
		var t := float(i) / n
		while fi < fcc.size() - 2 and t > fcc[fi + 1][0]:
			fi += 1
		var fc := minf(_seg(fcc, fi, t, 1), 6000.0)
		var c := 2.0 * sin(PI * fc / RATE)
		var w := r.randf_range(-1.0, 1.0)
		if crackle > 0.0 and r.randf() < 0.002 * crackle:
			w *= 9.0
		var h := w - l - damp * b
		b += c * h
		l += c * b
		while ai < ampc.size() - 2 and t > ampc[ai + 1][0]:
			ai += 1
		var a := _seg(ampc, ai, t, 1)
		a *= 1.0 - fl[1] * (0.5 + 0.5 * sin(TAU * fl[0] * float(i) / RATE))
		out[i] = b * a
	return out


## Sino FM (modulador em razao inarmonica): cristais, metal.
static func _bell(r: RandomNumberGenerator, dur: float, f: float, ratio: float, index: float, decay: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * decay)
		out[i] = sin(TAU * f * t + index * env * sin(TAU * f * ratio * t)) * env * minf(t * 400.0, 1.0)
	return out


## Junta pedacos em sequencia: [[buffer, pausa_depois_em_s], ...] (pausa negativa sobrepoe).
static func seq(parts: Array) -> PackedFloat32Array:
	var total := 0.0
	for p: Array in parts:
		total += (p[0] as PackedFloat32Array).size() / float(RATE) + maxf(float(p[1]), -0.5)
	var out := PackedFloat32Array()
	out.resize(int((total + 0.05) * RATE) + 16)
	var t := 0.0
	for p: Array in parts:
		out = mix(out, p[0], t, 1.0)
		t += (p[0] as PackedFloat32Array).size() / float(RATE) + float(p[1])
	return out


## Soma b em a a partir de t segundos (aumenta a se preciso).
static func mix(a: PackedFloat32Array, b: PackedFloat32Array, t: float, gain: float) -> PackedFloat32Array:
	var off := int(maxf(t, 0.0) * RATE)
	if off + b.size() > a.size():
		a.resize(off + b.size())
	for i in b.size():
		a[off + i] += b[i] * gain
	return a


## Eco com repeticoes que somem (vale, caverna, alem-tumulo).
static func echo(a: PackedFloat32Array, delay: float, fb: float, taps: int) -> PackedFloat32Array:
	var d := int(delay * RATE)
	var src := a.duplicate()
	var out := a
	var g := 1.0
	for k in range(1, taps + 1):
		g *= fb
		out = mix(out, _soften(src), float(d * k) / RATE, g)
	return out


static func _soften(a: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	var lp := 0.0
	for i in out.size():
		lp += (out[i] - lp) * 0.35
		out[i] = lp
	return out


## Valor da coluna col da curva no tempo t, entre as pontas k e k+1.
static func _seg(c: Array, k: int, t: float, col: int) -> float:
	if c.size() == 1:
		return float(c[0][col])
	var a: Array = c[k]
	var b: Array = c[mini(k + 1, c.size() - 1)]
	var span := float(b[0]) - float(a[0])
	var u := 0.0 if span <= 0.0 else clampf((t - float(a[0])) / span, 0.0, 1.0)
	return lerpf(float(a[col]), float(b[col]), u)


## Normaliza, tira o DC e suaviza as bordas.
static func _finish(a: PackedFloat32Array) -> PackedFloat32Array:
	var peak := 0.0001
	var dc := 0.0
	var prev := 0.0
	for i in a.size():
		# Passa-alta bem suave (remove DC dos pulsos).
		var x := a[i]
		dc = 0.995 * (dc + x - prev)
		prev = x
		a[i] = dc
		peak = maxf(peak, absf(dc))
	var g := 0.85 / peak
	var fade := mini(200, a.size() / 4)
	for i in a.size():
		var e := 1.0
		if i < fade:
			e = float(i) / fade
		elif i > a.size() - fade:
			e = float(a.size() - i) / fade
		a[i] = clampf(a[i] * g * e, -1.0, 1.0)
	return a


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(samples[i] * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
