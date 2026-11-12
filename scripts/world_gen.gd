class_name WorldGen
extends RefCounted
## Parte de CPU da geracao do mundo. O ruido e os voxels vem da GPU (GpuWorldGen); aqui ficam
## so as arvores, as edicoes do jogador e um espelho em GDScript do ruido para consultas pontuais
## (ponto de nascimento, nome do bioma, temperatura do clima).

const H := 128
const SEA := 44
const M32 := 0xFFFFFFFF

const B_OCEAN := 0
const B_BEACH := 1
const B_PLAINS := 2
const B_FOREST := 3
const B_DESERT := 4
const B_SNOW := 5
const B_MOUNTAIN := 6
const B_PEAK := 7
const BIOME_NAMES: Array[String] = ["Oceano", "Praia", "Planície", "Floresta", "Deserto", "Taiga nevada", "Montanha", "Pico nevado"]

var seed_v: int


var structs: Structures


func _init(s: int) -> void:
	seed_v = s
	structs = Structures.new(self)


# ---------------------------------------------------------------- espelho do ruido GLSL

static func _mul(a: int, b: int) -> int:
	return ((a & 0xFFFF) * b + ((((a >> 16) * b) & 0xFFFF) << 16)) & M32


static func _hash32(x: int, y: int, s: int) -> int:
	var h := (_mul(x & M32, 2654435761) + _mul(y & M32, 2246822519) + _mul(s & M32, 3266489917)) & M32
	h ^= h >> 15
	h = _mul(h, 739982445)
	h ^= h >> 12
	h = _mul(h, 695872825)
	h ^= h >> 15
	return h


static func _grad(ix: int, iy: int, fx: float, fy: float, s: int) -> float:
	var h := _hash32(ix, iy, s) & 7
	var sx := 1.0 if (h & 1) == 0 else -1.0
	var sy := 1.0 if (h & 2) == 0 else -1.0
	if h < 4:
		return sx * fx + sy * fy
	if h < 6:
		return sx * fx * 1.4142
	return sx * fy * 1.4142


static func _noise(px: float, py: float, s: int) -> float:
	var flx := floorf(px)
	var fly := floorf(py)
	var ix := int(flx)
	var iy := int(fly)
	var fx := px - flx
	var fy := py - fly
	var ux := fx * fx * fx * (fx * (fx * 6.0 - 15.0) + 10.0)
	var uy := fy * fy * fy * (fy * (fy * 6.0 - 15.0) + 10.0)
	var a := _grad(ix, iy, fx, fy, s)
	var b := _grad(ix + 1, iy, fx - 1.0, fy, s)
	var c := _grad(ix, iy + 1, fx, fy - 1.0, s)
	var d := _grad(ix + 1, iy + 1, fx - 1.0, fy - 1.0, s)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy)


static func _fbm(px: float, py: float, s: int, oct: int) -> float:
	var amp := 1.0
	var sum := 0.0
	var norm := 0.0
	for k in oct:
		sum += amp * _noise(px, py, s + k * 131)
		norm += amp
		px *= 2.0
		py *= 2.0
		amp *= 0.5
	return sum / norm * 1.6


func temperature(wx: float, wz: float) -> float:
	return _fbm(wx * 0.0013, wz * 0.0013, seed_v + 6, 2) * 1.6


## Retorna altura | bioma << 8 (mesma conta do wg_column em GLSL).
func height_biome(wx: float, wz: float) -> int:
	var sd := seed_v
	var c := _fbm(wx * 0.0016, wz * 0.0016, sd + 1, 4)
	var land := smoothstep(-0.16, 0.06, c)
	var e := _fbm(wx * 0.004, wz * 0.004, sd + 2, 3) * 0.5 + 0.5
	var m := smoothstep(0.12, 0.5, _fbm(wx * 0.0022, wz * 0.0022, sd + 3, 2)) * land
	var r := 1.0 - absf(_fbm(wx * 0.007, wz * 0.007, sd + 4, 4))
	var d := _fbm(wx * 0.035, wz * 0.035, sd + 5, 3)
	var h := 29.0 + land * 18.5 + e * 9.0 * land + m * (r * r * 54.0 + 8.0) + d * (1.5 + m * 3.5)
	var rv := absf(_fbm(wx * 0.0028, wz * 0.0028, sd + 8, 2))
	var rcut := (1.0 - smoothstep(0.0, 0.055, rv)) * land * (1.0 - m)
	h = lerpf(h, 40.5, rcut)
	var hi := clampi(int(floorf(h)), 3, 114)
	var temp := _fbm(wx * 0.0013, wz * 0.0013, sd + 6, 2) * 1.6 - maxf(0.0, h - 72.0) * 0.012 + d * 0.04
	var humid := _fbm(wx * 0.0019, wz * 0.0019, sd + 7, 2) * 1.6 + d * 0.04
	var bio := B_PLAINS
	if hi < 43:
		bio = B_OCEAN
	elif hi <= 45:
		bio = B_BEACH
	elif hi > 98:
		bio = B_PEAK
	elif hi > 80 and m > 0.45:
		bio = B_MOUNTAIN
	elif temp > 0.32 and humid < 0.15:
		bio = B_DESERT
	elif temp < -0.32:
		bio = B_SNOW
	elif humid > 0.08:
		bio = B_FOREST
	return hi | (bio << 8)


# ---------------------------------------------------------------- acabamento do chunk na CPU

func _hash(x: int, z: int, salt: int) -> int:
	return _hash32(x, z, salt + seed_v) & 0x7FFFFFFF


func _put(blocks: PackedByteArray, x: int, y: int, z: int, id: int, force: bool) -> void:
	if x < 0 or x > 15 or z < 0 or z > 15 or y < 1 or y >= H:
		return
	var i := y * 256 + z * 16 + x
	if force or blocks[i] == 0:
		blocks[i] = id


## blocks: voxels vindos da GPU; cols: mapa 20x20 (altura | bioma << 8 | cavado << 12) com margem 2.
func finish(blocks: PackedByteArray, cols: PackedInt32Array, cx: int, cz: int, mods: Dictionary, dim: int = 0) -> Dictionary:
	if dim == 1:
		return _apply_mods(blocks, {}, 126, mods, {})
	if dim == 2:
		return _finish_astral(blocks, cols, cx, cz, mods)
	var M := 2
	var CW := 16 + M * 2
	var ox := cx * 16
	var oz := cz * 16
	var top := SEA + 1
	for z in 16:
		for x in 16:
			top = maxi(top, (cols[(z + M) * CW + x + M] & 0xFF) + 1)
	var micro := {}

	# Arvores e cactos (incluindo os que nascem na borda dos chunks vizinhos).
	for tz in range(-M, 16 + M):
		for tx in range(-M, 16 + M):
			var cv := cols[(tz + M) * CW + tx + M]
			var h := cv & 0xFF
			var bio := (cv >> 8) & 15
			if h <= SEA or (cv >> 12) != 0:
				continue
			var chance := 0
			match bio:
				B_FOREST: chance = 30
				B_PLAINS: chance = 3
				B_SNOW: chance = 10
				B_DESERT: chance = 6
				B_BEACH: chance = 9
			if chance == 0:
				continue
			var wx := ox + tx
			var wz := oz + tz
			if _hash(wx, wz, 23) % 1000 >= chance:
				continue
			if structs.in_structure(wx, wz):
				continue
			var hv := _hash(wx, wz, 31)
			if bio == B_DESERT:
				for y in range(h + 1, h + 3 + hv % 2):
					_put(blocks, tx, y, tz, Blocks.CACTUS, true)
				top = maxi(top, h + 4)
			elif bio == B_BEACH:
				var th := 5 + hv % 2
				for y in range(h + 1, h + th + 1):
					_put(blocks, tx, y, tz, Blocks.PALM_LOG, true)
				var py := h + th
				_put(blocks, tx, py + 1, tz, Blocks.PALM_LEAVES, false)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					_put(blocks, tx + d.x, py + 1, tz + d.y, Blocks.PALM_LEAVES, false)
					_put(blocks, tx + d.x * 2, py, tz + d.y * 2, Blocks.PALM_LEAVES, false)
					_put(blocks, tx + d.x, py, tz + d.y, Blocks.PALM_LEAVES, false)
				top = maxi(top, py + 2)
			elif bio == B_SNOW:
				var th := 6 + hv % 3
				for y in range(h + 1, h + th + 1):
					_put(blocks, tx, y, tz, Blocks.PINE_LOG, true)
				_roots(blocks, micro, tx, h + 1, tz, Blocks.PINE_LOG, hv)
				_put(blocks, tx, h + th + 1, tz, Blocks.PINE_LEAVES, false)
				for ly in range(h + 3, h + th + 1):
					var kk := (h + th) - ly
					var rad := 1 + (kk % 2)
					for dz in range(-rad, rad + 1):
						for dx in range(-rad, rad + 1):
							if absi(dx) + absi(dz) > rad + (1 if rad == 2 else 0):
								continue
							_put(blocks, tx + dx, ly, tz + dz, Blocks.PINE_LEAVES, false)
				top = maxi(top, h + th + 1)
			else:
				# Especie por regiao: carvalho, betula ou mogno (mais alto).
				var sp := _hash(wx >> 5, wz >> 5, 77) % 10
				var log_id := Blocks.LOG
				var leaf_id := Blocks.LEAVES
				var th := 4 + hv % 3
				if sp <= 1:
					leaf_id = Blocks.APPLE_LEAVES
				elif sp == 4:
					leaf_id = Blocks.ORANGE_LEAVES
					th = 4
				if sp == 5:
					log_id = Blocks.CHERRY_LOG
					leaf_id = Blocks.CHERRY_LEAVES
					th = 4 + hv % 2
				elif sp >= 9:
					log_id = Blocks.MAHOG_LOG
					leaf_id = Blocks.MAHOG_LEAVES
					th = 7 + hv % 3
				elif sp >= 6:
					log_id = Blocks.BIRCH_LOG
					leaf_id = Blocks.BIRCH_LEAVES
					th = 5 + hv % 2
				for y in range(h + 1, h + th + 1):
					_put(blocks, tx, y, tz, log_id, true)
				_roots(blocks, micro, tx, h + 1, tz, log_id, hv)
				var ty := h + th
				for dy in range(-2, 2):
					var rad := 2 if dy <= -1 else 1
					for dz in range(-rad, rad + 1):
						for dx in range(-rad, rad + 1):
							if absi(dx) == rad and absi(dz) == rad:
								if rad == 1 and dy == 1:
									continue
								if (_hash(wx + dx, wz + dz, 40 + dy) & 1) == 0:
									continue
							_put(blocks, tx + dx, ty + dy, tz + dz, leaf_id, false)
				top = maxi(top, ty + 1)

	# Arbustos de frutas e aboboras silvestres.
	for z in 16:
		for x in 16:
			var cv := cols[(z + M) * CW + x + M]
			var h := cv & 0xFF
			var bio := (cv >> 8) & 15
			if h <= SEA or h + 1 >= H or (cv >> 12) != 0:
				continue
			var i := h * 256 + z * 16 + x
			if blocks[i] != Blocks.GRASS or blocks[i + 256] != 0:
				continue
			var r := _hash(ox + x, oz + z, 57) % 1000
			if (bio == B_FOREST and r < 7) or (bio == B_PLAINS and r < 3):
				blocks[i + 256] = Blocks.BERRY_BUSH
			elif bio == B_PLAINS and r >= 990:
				blocks[i + 256] = Blocks.PUMPKIN
	# Pedrinhas soltas e galhos caidos (micro-voxels de 1/8 de bloco).
	for z in 16:
		for x in 16:
			var cv := cols[(z + M) * CW + x + M]
			var h := cv & 0xFF
			var bio := (cv >> 8) & 15
			if h <= SEA or h + 1 >= H or (cv >> 12) != 0:
				continue
			var i := h * 256 + z * 16 + x
			if blocks[i + 256] != 0:
				continue
			var ground := blocks[i]
			if ground != Blocks.GRASS and ground != Blocks.SNOW_GRASS and ground != Blocks.SAND and ground != Blocks.DIRT:
				continue
			var wx := ox + x
			var wz := oz + z
			var r := _hash(wx, wz, 91) % 1000
			var pc := 9
			match bio:
				B_FOREST: pc = 14
				B_DESERT: pc = 7
				B_BEACH: pc = 10
				B_SNOW: pc = 6
			if r < pc:
				micro[i + 256] = _pebbles(_hash(wx, wz, 92), bio)
				blocks[i + 256] = Blocks.MICRO
			elif bio == B_FOREST and r < pc + 8:
				micro[i + 256] = _twig(_hash(wx, wz, 93))
				blocks[i + 256] = Blocks.MICRO
	var shapes := {}
	var st := structs.stamp(blocks, shapes, cx, cz)
	top = maxi(top, int(st["top"]))
	if int(st["top"]) > 0:
		_sills(blocks, micro, top)
	var ms: Dictionary = st.get("micro_s", {})
	for k: int in ms:
		micro[k] = ms[k]
	# Estruturas podem ter sobrescrito celulas micro.
	for idx: int in micro.keys():
		if blocks[idx] != Blocks.MICRO:
			micro.erase(idx)
		else:
			shapes[idx] = Blocks.SH_MICRO
	st["micro"] = micro
	return _apply_mods(blocks, shapes, top, mods, st)


static func _mrng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r


## Algumas pedrinhas de tamanhos variados sobre o chao.
static func _pebbles(seed_v: int, bio: int) -> PackedByteArray:
	var r := _mrng(seed_v)
	var g := Micro.empty()
	var mats: Array = [Blocks.STONE, Blocks.COBBLE, Blocks.GRANITE, Blocks.GRAVEL]
	if bio == B_DESERT or bio == B_BEACH:
		mats = [Blocks.SANDSTONE, Blocks.GRANITE, Blocks.LIMESTONE]
	var n := r.randi_range(1, 4)
	var rm := {}
	for k in n:
		var sx := r.randi_range(1, 3)
		var sz := r.randi_range(1, 3)
		var sy := r.randi_range(1, 2) if sx > 1 or sz > 1 else 1
		var x0 := r.randi_range(0, 8 - sx)
		var z0 := r.randi_range(0, 8 - sz)
		var m: int = mats[r.randi() % mats.size()]
		for y in sy:
			for z in range(z0, z0 + sz):
				for x in range(x0, x0 + sx):
					# Cantos de cima arredondados.
					if y == sy - 1 and sy > 1 and (x == x0 or x == x0 + sx - 1) and (z == z0 or z == z0 + sz - 1):
						continue
					g[Micro.i3(x, y, z)] = m
	return g


## Galho caido com uma bifurcacao.
static func _twig(seed_v: int) -> PackedByteArray:
	var r := _mrng(seed_v)
	var g := Micro.empty()
	var along_x := r.randi() % 2 == 0
	var a0 := r.randi_range(0, 2)
	var len := r.randi_range(4, 7)
	var b := r.randi_range(2, 5)
	var wood: int = [Blocks.LOG, Blocks.BIRCH_LOG, Blocks.PINE_LOG][r.randi() % 3]
	for k in range(a0, mini(a0 + len, 8)):
		var x := k if along_x else b
		var z := b if along_x else k
		g[Micro.i3(x, 0, z)] = wood
	var fk := a0 + len / 2
	for k in 3:
		var x := fk + k if along_x else b + k + 1
		var z := b + k + 1 if along_x else fk + k
		if x < 8 and z < 8:
			g[Micro.i3(x, 0, z)] = wood
	# Folhinhas secas em volta.
	for k in 3:
		var lx := r.randi_range(0, 7)
		var lz := r.randi_range(0, 7)
		if g[Micro.i3(lx, 0, lz)] == 0:
			g[Micro.i3(lx, 0, lz)] = Blocks.DIRT
	return g


## Raizes que se abrem na base do tronco, nas quatro direcoes.
func _roots(blocks: PackedByteArray, micro: Dictionary, tx: int, y: int, tz: int, wood: int, hv: int) -> void:
	if y < 1 or y >= H:
		return
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for k in 4:
		if ((hv >> k) & 1) == 0 and k > 1:
			continue
		var d: Vector2i = dirs[k]
		var x := tx + d.x
		var z := tz + d.y
		if x < 0 or x > 15 or z < 0 or z > 15:
			continue
		var i := y * 256 + z * 16 + x
		if blocks[i] != 0 and Blocks.KIND[blocks[i]] != Blocks.K_PLANT:
			continue
		if Blocks.SOLID[blocks[i - 256]] == 0:
			continue
		var g := Micro.empty()
		# Rampa: alta junto ao tronco e baixa na ponta, com 2 a 3 voxels de largura.
		var w0 := 2 + ((hv >> (k + 4)) & 1)
		var c0 := 4 - w0 / 2 + ((hv >> (k + 8)) % 2)
		var reach := 3 + ((hv >> (k + 12)) & 3)
		for s in reach:
			var hgt := maxi(1, 4 - s)
			var wid := maxi(1, w0 - s / 2)
			for yy in hgt:
				for ww in wid:
					var across := clampi(c0 + ww - wid / 2, 0, 7)
					var along := s if (d.x < 0 or d.y < 0) == false else 7 - s
					var vx := along if d.x != 0 else across
					var vz := across if d.x != 0 else along
					g[Micro.i3(vx, yy, vz)] = wood
		blocks[i] = Blocks.MICRO
		micro[i] = g


## Peitoris de 1/8 de espessura sob as janelas das construcoes.
func _sills(blocks: PackedByteArray, micro: Dictionary, top: int) -> void:
	for y in range(SEA, mini(top, H - 1)):
		for z in 16:
			for x in 16:
				var i := y * 256 + z * 16 + x
				var id := blocks[i]
				if id != Blocks.WINDOW_WOOD and id != Blocks.WINDOW_IRON:
					continue
				var below := blocks[i - 256]
				if below == Blocks.WINDOW_WOOD or below == Blocks.WINDOW_IRON or below == 0:
					continue
				var mat := Blocks.PLANKS if id == Blocks.WINDOW_WOOD else Blocks.STONE_BRICKS
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := x + d.x
					var nz := z + d.y
					if nx < 0 or nx > 15 or nz < 0 or nz > 15:
						continue
					var ni := y * 256 + nz * 16 + nx
					if blocks[ni] != 0:
						continue
					var g := Micro.empty()
					for a in 8:
						for t in 2:
							# t = distancia da parede (0 encostado).
							var vx := (t if d.x > 0 else 7 - t) if d.x != 0 else a
							var vz := (t if d.y > 0 else 7 - t) if d.y != 0 else a
							g[Micro.i3(vx, 0, vz)] = mat
							if t == 0:
								g[Micro.i3(vx, 1, vz)] = mat
					blocks[ni] = Blocks.MICRO
					micro[ni] = g


func _apply_mods(blocks: PackedByteArray, shapes: Dictionary, top: int, mods: Dictionary, extra: Dictionary) -> Dictionary:
	for idx: int in mods:
		var mv: int = mods[idx]
		blocks[idx] = mv & 0xFF
		if (mv >> 8) != 0:
			shapes[idx] = mv >> 8
		top = maxi(top, idx >> 8)
	return {"blocks": blocks, "shapes": shapes, "top": mini(top + 1, H), "ticks": extra.get("ticks", []),
		"loot": extra.get("loot", []), "npcs": extra.get("npcs", []), "micro": extra.get("micro", {}), "lights": extra.get("lights", [])}


## Ilhas etereas: arvores de cristal sobre o musgo lunar.
func _finish_astral(blocks: PackedByteArray, cols: PackedInt32Array, cx: int, cz: int, mods: Dictionary) -> Dictionary:
	var M := 2
	var CW := 20
	var ox := cx * 16
	var oz := cz * 16
	var top := 0
	for z in 16:
		for x in 16:
			top = maxi(top, (cols[(z + M) * CW + x + M] & 0xFF) + 1)
	for tz in range(-M, 16 + M):
		for tx in range(-M, 16 + M):
			var h := cols[(tz + M) * CW + tx + M] & 0xFF
			if h < 12:
				continue
			var wx := ox + tx
			var wz := oz + tz
			if _hash(wx, wz, 88) % 1000 >= 14:
				continue
			var th := 5 + _hash(wx, wz, 89) % 4
			for y in range(h + 1, h + th + 1):
				_put(blocks, tx, y, tz, Blocks.ETHER_LOG, true)
			var ty := h + th
			for dy in range(-2, 2):
				var rad := 2 if dy < 0 else 1
				for dz in range(-rad, rad + 1):
					for dx in range(-rad, rad + 1):
						if absi(dx) + absi(dz) <= rad + 1:
							_put(blocks, tx + dx, ty + dy, tz + dz, Blocks.ETHER_LEAVES, false)
			_put(blocks, tx, ty + 2, tz, Blocks.CRYSTAL_BLOCK, false)
			top = maxi(top, ty + 3)
	return _apply_mods(blocks, {}, top, mods, {})
