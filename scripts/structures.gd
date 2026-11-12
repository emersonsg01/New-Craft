class_name Structures
extends RefCounted
## Vilas, acampamentos de bandidos e ruinas. O mapa e dividido em celulas de 256 blocos; cada
## celula pode ter uma estrutura, decidida de forma deterministica pela semente. O layout e
## calculado uma vez (cache) e cada chunk "carimba" so a parte que cai dentro dele.

const CELL := 256

## Modelos e blocos com forma giram junto com a construcao.
const ROT_SHAPED := true

var gen: WorldGen
var _cache: Dictionary = {}
var _tpl_cache: Dictionary = {}
var _lock := Mutex.new()

static var PALETTES := {
	"planicie": {"floor": Blocks.PLANKS, "wall": Blocks.PLANKS, "wall2": Blocks.COBBLE, "pillar": Blocks.LOG, "roof": Blocks.ROOF_TILES, "found": Blocks.COBBLE,
		"path": Blocks.PATH, "fence": Blocks.FENCE, "trim": Blocks.STONE_BRICKS, "chest": Blocks.CHEST, "wool": Blocks.WOOL_0 + 3},
	"floresta": {"floor": Blocks.MAHOG_PLANKS, "wall": Blocks.BIRCH_PLANKS, "wall2": Blocks.MOSSY_COBBLE, "pillar": Blocks.BIRCH_LOG, "roof": Blocks.ROOF_GREEN,
		"found": Blocks.MOSSY_COBBLE, "path": Blocks.PATH, "fence": Blocks.FENCE, "trim": Blocks.LIMESTONE_BRICKS, "chest": Blocks.CHEST_BIRCH, "wool": Blocks.WOOL_0 + 6},
	"cerejeira": {"floor": Blocks.PLANKS, "wall": Blocks.CHERRY_PLANKS, "wall2": Blocks.STONE_BRICKS, "pillar": Blocks.CHERRY_LOG, "roof": Blocks.ROOF_TILES,
		"found": Blocks.STONE_BRICKS, "path": Blocks.PATH, "fence": Blocks.FENCE, "trim": Blocks.MARBLE_BRICKS, "chest": Blocks.CHEST_CHERRY, "wool": Blocks.WOOL_0 + 10},
	"deserto": {"window": Blocks.WINDOW_IRON, "floor": Blocks.SANDSTONE, "wall": Blocks.SANDSTONE_BRICKS, "wall2": Blocks.MUD_BRICKS, "pillar": Blocks.SANDSTONE, "roof": Blocks.TERRACOTTA,
		"found": Blocks.SANDSTONE, "path": Blocks.PATH, "fence": Blocks.FENCE, "trim": Blocks.MUD_BRICKS, "chest": Blocks.CHEST_PALM, "wool": Blocks.WOOL_0 + 4},
	"neve": {"floor": Blocks.PINE_PLANKS, "wall": Blocks.PINE_PLANKS, "wall2": Blocks.STONE_BRICKS, "pillar": Blocks.PINE_LOG, "roof": Blocks.ROOF_SLATE,
		"found": Blocks.STONE_BRICKS, "path": Blocks.GRAVEL, "fence": Blocks.FENCE, "trim": Blocks.STONE_BRICKS, "chest": Blocks.CHEST_PINE, "wool": Blocks.WOOL_0 + 8},
	"bandidos": {"window": Blocks.WINDOW_IRON, "floor": Blocks.MAHOG_PLANKS, "wall": Blocks.MAHOG_PLANKS, "wall2": Blocks.BASALT_BRICKS, "pillar": Blocks.MAHOG_LOG, "roof": Blocks.WOOL_0 + 2,
		"found": Blocks.BASALT_BRICKS, "path": Blocks.GRAVEL, "fence": Blocks.FENCE, "trim": Blocks.BASALT_BRICKS, "chest": Blocks.CHEST_IRON, "wool": Blocks.WOOL_0 + 3},
	"ruina": {"floor": Blocks.STONE_BRICKS, "wall": Blocks.STONE_BRICKS, "wall2": Blocks.MOSSY_COBBLE, "pillar": Blocks.MOSSY_COBBLE, "roof": Blocks.STONE_BRICKS,
		"found": Blocks.COBBLE, "path": Blocks.GRAVEL, "fence": Blocks.FENCE, "trim": Blocks.MOSSY_COBBLE, "chest": Blocks.CHEST, "wool": Blocks.WOOL_0},
}


func _init(g: WorldGen) -> void:
	gen = g


# ---------------------------------------------------------------- layout

func layout(cell: Vector2i) -> Dictionary:
	_lock.lock()
	var hit: Variant = _cache.get(cell, null)
	_lock.unlock()
	if hit != null:
		return hit
	var out := _layout(cell)
	_lock.lock()
	if _cache.has(cell):
		out = _cache[cell]
	else:
		_cache[cell] = out
	_lock.unlock()
	return out


func _layout(cell: Vector2i) -> Dictionary:
	var out := {}
	var h := gen._hash(cell.x, cell.y, 901)
	var cx := cell.x * CELL + 64 + h % 128
	var cz := cell.y * CELL + 64 + (h >> 8) % 128
	var roll := (h >> 16) % 100
	var hb := gen.height_biome(cx, cz)
	var hc := hb & 0xFF
	var bio := hb >> 8
	if hc <= WorldGen.SEA + 1:
		return out
	var flat := true
	for o: Vector2i in [Vector2i(14, 0), Vector2i(-14, 0), Vector2i(0, 14), Vector2i(0, -14)]:
		if absi((gen.height_biome(cx + o.x, cz + o.y) & 0xFF) - hc) > 6:
			flat = false
	var rng := RandomNumberGenerator.new()
	rng.seed = h
	var kind := ""
	var pal := ""
	if roll < 45 and flat and bio in [WorldGen.B_PLAINS, WorldGen.B_FOREST, WorldGen.B_DESERT, WorldGen.B_SNOW]:
		kind = "vila"
		match bio:
			WorldGen.B_PLAINS: pal = "planicie"
			WorldGen.B_FOREST: pal = "cerejeira" if rng.randf() < 0.35 else "floresta"
			WorldGen.B_DESERT: pal = "deserto"
			WorldGen.B_SNOW: pal = "neve"
	elif roll < 62 and flat and bio in [WorldGen.B_PLAINS, WorldGen.B_FOREST, WorldGen.B_SNOW]:
		kind = "bandidos"
		pal = "bandidos"
	elif roll < 80:
		kind = "piramide" if bio == WorldGen.B_DESERT else "ruina"
		pal = "deserto" if bio == WorldGen.B_DESERT else "ruina"
	else:
		return out
	out["kind"] = kind
	out["pal"] = pal
	out["center"] = Vector3i(cx, hc, cz)
	out["id"] = "%d,%d" % [cell.x, cell.y]
	var builds: Array = []
	var paths: Array = []
	var npcs: Array = []
	if kind == "vila":
		builds.append(_place("poco", cx - 1, cz - 1, hc, 0, 3, 3))
		var types := ["casa", "casa", "casa", "casa_grande", "fazenda", "fazenda", "ferreiro", "mercado", "templo", "torre", "casa"]
		var n := rng.randi_range(6, 10)
		var used_templo := false
		for i in n:
			var t: String = types[rng.randi() % types.size()]
			if t == "templo" or t == "torre":
				if used_templo:
					t = "casa"
				used_templo = true
			var sz := _size(t)
			var ang := TAU * i / n + rng.randf_range(-0.25, 0.25)
			var rad := 13.0 + maxf(sz.x, sz.y) * 0.6 + rng.randf_range(0.0, 8.0)
			var dir := Vector2(cos(ang), sin(ang))
			var rot := _rot_towards(dir)
			var rs := sz if rot % 2 == 0 else Vector2i(sz.y, sz.x)
			var bx := cx + int(dir.x * rad) - rs.x / 2
			var bz := cz + int(dir.y * rad) - rs.y / 2
			var by := gen.height_biome(bx + rs.x / 2, bz + rs.y / 2) & 0xFF
			if absi(by - hc) > 7 or by <= WorldGen.SEA:
				continue
			var b := _place(t, bx, bz, by, rot, sz.x, sz.y)
			if _overlaps(b, builds):
				continue
			b["var"] = rng.randi()
			builds.append(b)
			if t != "fazenda" and t != "mercado":
				paths.append_array(_path(Vector2i(cx, cz), _door_cell(b)))
			if rng.randf() < 0.4:
				var lp := Vector2i(cx, cz) + Vector2i(int(dir.x * rad * 0.5) + 2, int(dir.y * rad * 0.5) + 2)
				var lb := _place("lampiao", lp.x, lp.y, gen.height_biome(lp.x, lp.y) & 0xFF, 0, 1, 1)
				if not _overlaps(lb, builds):
					builds.append(lb)
		for i in clampi(builds.size() / 2, 3, 7):
			npcs.append([Vector3(cx + rng.randf_range(-8, 8), hc + 2.0, cz + rng.randf_range(-8, 8)), "aldeao", rng.randi()])
	elif kind == "bandidos":
		builds.append(_place("fogueira", cx, cz, hc, 0, 1, 1))
		var n := rng.randi_range(3, 5)
		for i in n:
			var t := "tenda" if i > 0 else "torre"
			var sz := _size(t)
			var ang := TAU * i / n + rng.randf_range(-0.3, 0.3)
			var dir := Vector2(cos(ang), sin(ang))
			var rad := 8.0 + rng.randf_range(0.0, 4.0)
			var rot := _rot_towards(dir)
			var rs := sz if rot % 2 == 0 else Vector2i(sz.y, sz.x)
			var bx := cx + int(dir.x * rad) - rs.x / 2
			var bz := cz + int(dir.y * rad) - rs.y / 2
			var by := gen.height_biome(bx + rs.x / 2, bz + rs.y / 2) & 0xFF
			var b := _place(t, bx, bz, by, rot, sz.x, sz.y)
			if _overlaps(b, builds):
				continue
			b["var"] = rng.randi()
			builds.append(b)
		for i in rng.randi_range(3, 6):
			npcs.append([Vector3(cx + rng.randf_range(-6, 6), hc + 2.0, cz + rng.randf_range(-6, 6)), "bandido", rng.randi()])
	elif kind == "ruina":
		var b := _place("torre_ruina", cx - 2, cz - 2, hc, rng.randi() % 4, 5, 5)
		b["var"] = rng.randi()
		builds.append(b)
	else:
		var b := _place("piramide", cx - 5, cz - 5, hc, rng.randi() % 4, 11, 11)
		b["var"] = rng.randi()
		builds.append(b)
	out["builds"] = builds
	out["paths"] = paths
	out["npcs"] = npcs
	var lo := Vector2i(cx, cz)
	var hi := Vector2i(cx, cz)
	for b: Dictionary in builds:
		lo = Vector2i(mini(lo.x, b["x"]), mini(lo.y, b["z"]))
		hi = Vector2i(maxi(hi.x, int(b["x"]) + int(b["w"])), maxi(hi.y, int(b["z"]) + int(b["d"])))
	out["lo"] = lo - Vector2i(3, 3)
	out["hi"] = hi + Vector2i(3, 3)
	return out


static func _size(t: String) -> Vector2i:
	match t:
		"casa": return Vector2i(7, 7)
		"casa_grande": return Vector2i(9, 9)
		"fazenda": return Vector2i(9, 7)
		"ferreiro": return Vector2i(7, 7)
		"mercado": return Vector2i(5, 3)
		"templo": return Vector2i(7, 11)
		"torre": return Vector2i(5, 5)
		"tenda": return Vector2i(5, 5)
	return Vector2i(1, 1)


## Rotacao que faz a frente (porta) olhar para o centro, dado o vetor centro -> construcao.
static func _rot_towards(dir: Vector2) -> int:
	if absf(dir.x) > absf(dir.y):
		return 3 if dir.x > 0.0 else 1
	return 0 if dir.y > 0.0 else 2


func _place(t: String, x: int, z: int, y: int, rot: int, w0: int, d0: int) -> Dictionary:
	var w := w0 if rot % 2 == 0 else d0
	var d := d0 if rot % 2 == 0 else w0
	return {"t": t, "x": x, "z": z, "y": y, "rot": rot, "w0": w0, "d0": d0, "w": w, "d": d, "var": 0}


static func _overlaps(b: Dictionary, list: Array) -> bool:
	var r := Rect2i(int(b["x"]) - 2, int(b["z"]) - 2, int(b["w"]) + 4, int(b["d"]) + 4)
	for o: Dictionary in list:
		if r.intersects(Rect2i(o["x"], o["z"], o["w"], o["d"])):
			return true
	return false


## Celula do lado de fora da porta (local x = meio, z = -1), ja girada para o mundo.
static func _door_cell(b: Dictionary) -> Vector2i:
	var l := rot_local(int(b["w0"]) / 2, -1, b["w0"], b["d0"], b["rot"])
	return Vector2i(int(b["x"]) + l.x, int(b["z"]) + l.y)


static func rot_local(lx: int, lz: int, w0: int, d0: int, rot: int) -> Vector2i:
	var x := lx
	var z := lz
	var w := w0
	var d := d0
	for i in rot:
		var nx := d - 1 - z
		var nz := x
		x = nx
		z = nz
		var t := w
		w = d
		d = t
	return Vector2i(x, z)


func _path(a: Vector2i, b: Vector2i) -> Array:
	var out := []
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(3, n + 1):
		var t := float(i) / maxf(n, 1)
		var x := roundi(lerpf(a.x, b.x, t))
		var z := roundi(lerpf(a.y, b.y, t))
		out.append(Vector3i(x, gen.height_biome(x, z) & 0xFF, z))
	return out


func in_structure(wx: int, wz: int) -> bool:
	var cell := Vector2i(floori(float(wx) / CELL), floori(float(wz) / CELL))
	var l := layout(cell)
	if l.is_empty():
		return false
	var lo: Vector2i = l["lo"]
	var hi: Vector2i = l["hi"]
	return wx >= lo.x and wx <= hi.x and wz >= lo.y and wz <= hi.y


# ---------------------------------------------------------------- modelos de construcao
## Cada modelo devolve {"blocks": [[x, y, z, id, forma], ...], "h": altura, "loot": [[x,y,z,nivel]], "crops": [[x,y,z]]}
## em coordenadas locais (frente/porta em z = 0, olhando para -Z).

func template(t: String, pal_name: String, variant: int) -> Dictionary:
	var key := "%s|%s|%d" % [t, pal_name, variant % 4]
	_lock.lock()
	var hit: Variant = _tpl_cache.get(key, null)
	_lock.unlock()
	if hit != null:
		return hit
	var p: Dictionary = PALETTES[pal_name]
	var r := RandomNumberGenerator.new()
	r.seed = variant
	var bl: Array = []
	var loot: Array = []
	var crops: Array = []
	var h := 4
	match t:
		"casa":
			h = _house(bl, loot, p, 7, 7, 3, r, false)
		"casa_grande":
			h = _house(bl, loot, p, 9, 9, 7, r, true)
		"templo":
			h = _temple(bl, loot, p, r)
		"torre":
			h = _tower(bl, loot, p, r, false)
		"torre_ruina":
			h = _tower(bl, loot, p, r, true)
		"poco":
			for x in 3:
				for z in 3:
					if x == 1 and z == 1:
						bl.append([x, 0, z, Blocks.WATER, 0])
						bl.append([x, -1, z, Blocks.WATER, 0])
					else:
						bl.append([x, 0, z, p["found"], 0])
						bl.append([x, 1, z, p["found"], 0] if (x + z) % 2 == 1 else [x, 1, z, 0, 0])
			for c: Vector2i in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]:
				bl.append([c.x, 2, c.y, p["fence"], 0])
				bl.append([c.x, 3, c.y, p["fence"], 0])
			for x in 3:
				for z in 3:
					bl.append([x, 4, z, p["roof"], Blocks.SH_SLAB])
			h = 5
		"fazenda":
			var crop_ids := [Blocks.CROP_WHEAT, Blocks.CROP_CARROT, Blocks.CROP_POTATO, Blocks.CROP_WHEAT]
			var cid: int = crop_ids[r.randi() % crop_ids.size()]
			var n: int = Blocks.CROP_STAGES[cid]
			for x in 9:
				for z in 7:
					var edge := x == 0 or x == 8 or z == 0 or z == 6
					if edge:
						bl.append([x, 0, z, p["pillar"], 0])
					elif z == 3:
						bl.append([x, 0, z, Blocks.WATER, 0])
					else:
						bl.append([x, 0, z, Blocks.FARMLAND, 0])
						bl.append([x, 1, z, cid + r.randi_range(0, n - 1), 0])
						crops.append([x, 1, z])
			h = 2
		"ferreiro":
			for x in 7:
				for z in 7:
					bl.append([x, 0, z, Blocks.COBBLE, 0])
					bl.append([x, 4, z, p["roof"], Blocks.SH_SLAB])
			for c: Vector2i in [Vector2i(0, 0), Vector2i(6, 0), Vector2i(0, 6), Vector2i(6, 6)]:
				for y in range(1, 4):
					bl.append([c.x, y, c.y, p["pillar"], 0])
			for x in range(1, 6):
				for y in range(1, 4):
					bl.append([x, y, 6, p["trim"], 0])
			bl.append([1, 1, 5, Blocks.FURNACE, 2 << 4])
			bl.append([2, 1, 5, Blocks.FURNACE, 2 << 4])
			bl.append([3, 1, 3, Blocks.ANVIL, 0])
			bl.append([5, 1, 5, p["chest"], 2 << 4])
			loot.append([5, 1, 5, 1])
			bl.append([5, 1, 1, Blocks.BARREL, 0])
			bl.append([1, 1, 1, Blocks.LANTERN, 0])
			h = 5
		"mercado":
			var wool: int = Blocks.WOOL_0 + [3, 4, 5, 6, 8, 10][r.randi() % 6]
			for c: Vector2i in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 2), Vector2i(4, 2)]:
				bl.append([c.x, 1, c.y, p["fence"], 0])
				bl.append([c.x, 2, c.y, p["fence"], 0])
			for x in 5:
				for z in 3:
					bl.append([x, 3, z, wool, Blocks.SH_SLAB])
			bl.append([1, 1, 1, [Blocks.CRATE, Blocks.HAY, Blocks.BARREL][r.randi() % 3], 0])
			bl.append([3, 1, 1, [Blocks.CRATE, Blocks.PUMPKIN, Blocks.BARREL][r.randi() % 3], 0])
			bl.append([2, 1, 2, Blocks.TABLE, 0])
			h = 4
		"lampiao":
			bl.append([0, 1, 0, p["fence"], 0])
			bl.append([0, 2, 0, p["fence"], 0])
			bl.append([0, 3, 0, Blocks.LANTERN, 0])
			h = 4
		"fogueira":
			bl.append([0, 1, 0, Blocks.CAMPFIRE, 0])
			h = 2
		"tenda":
			var wool: int = [Blocks.WOOL_0 + 2, Blocks.WOOL_0 + 3, Blocks.WOOL_0 + 11][r.randi() % 3]
			for x in 5:
				for i in 3:
					bl.append([x, 1 + i, i, wool, Blocks.SH_WEDGE])
					bl.append([x, 1 + i, 4 - i, wool, Blocks.SH_WEDGE | (2 << 4)])
				bl.append([x, 3, 2, wool, 0])
			bl.append([1, 1, 3, Blocks.BED, 0])
			bl.append([3, 1, 3, p["chest"], 2 << 4])
			loot.append([3, 1, 3, 2])
			h = 4
		"piramide":
			for lyr in 6:
				for x in range(lyr, 11 - lyr):
					for z in range(lyr, 11 - lyr):
						bl.append([x, lyr, z, Blocks.SANDSTONE if lyr % 2 == 0 else Blocks.SANDSTONE_BRICKS, 0])
			for x in range(4, 7):
				for z in range(4, 7):
					bl.append([x, 1, z, 0, 0])
					bl.append([x, 2, z, 0, 0])
			for z in range(0, 5):
				bl.append([5, 1, z, 0, 0])
				bl.append([5, 2, z, 0, 0])
			bl.append([5, 1, 6, Blocks.CHEST_PALM, 2 << 4])
			loot.append([5, 1, 6, 3])
			bl.append([4, 1, 6, Blocks.TORCH, 0])
			bl.append([6, 1, 6, Blocks.TORCH, 0])
			h = 7
	var res := {"blocks": bl, "h": h, "loot": loot, "crops": crops}
	_lock.lock()
	_tpl_cache[key] = res
	_lock.unlock()
	return res


## Casa com telhado de duas aguas. tall: segundo andar com escada.
func _house(bl: Array, loot: Array, p: Dictionary, w: int, d: int, wall_h: int, r: RandomNumberGenerator, tall: bool) -> int:
	var mid := w / 2
	for x in w:
		for z in d:
			bl.append([x, 0, z, p["floor"], 0])
			var edge := x == 0 or x == w - 1 or z == 0 or z == d - 1
			var corner := (x == 0 or x == w - 1) and (z == 0 or z == d - 1)
			for y in range(1, wall_h + 1):
				if not edge:
					bl.append([x, y, z, 0, 0])
					continue
				var id: int = p["pillar"] if corner else (p["wall2"] if y == 1 else p["wall"])
				if tall and y == 4 and not corner:
					id = p["pillar"]
				bl.append([x, y, z, id, 0])
	# Porta e janelas.
	bl.append([mid, 1, 0, Blocks.DOOR, 0])
	bl.append([mid, 2, 0, Blocks.DOOR, 0])
	var win: int = p.get("window", Blocks.WINDOW_WOOD)
	var win_rows := [2, 6] if tall else [2]
	for wy: int in win_rows:
		for wx: int in [1, w - 2]:
			if wx != mid:
				bl.append([wx, wy, 0, win, 0])
				bl.append([wx, wy, d - 1, win, 0])
		bl.append([0, wy, d / 2, win, 0])
		bl.append([w - 1, wy, d / 2, win, 0])
	if tall:
		# Piso do segundo andar e escada.
		for x in range(1, w - 1):
			for z in range(1, d - 1):
				if not (x == 1 and z >= 3 and z <= 5):
					bl.append([x, 4, z, p["floor"], 0])
		bl.append([1, 1, 3, p["floor"], Blocks.SH_STAIRS])
		bl.append([1, 2, 4, p["floor"], Blocks.SH_STAIRS])
		bl.append([1, 3, 5, p["floor"], Blocks.SH_STAIRS])
		bl.append([w - 2, 5, d - 2, Blocks.BED, 2 << 4])
		bl.append([w - 3, 5, d - 2, Blocks.BED, 2 << 4])
		bl.append([w - 2, 5, 1, Blocks.BOOKSHELF, 0])
		bl.append([w - 3, 5, 1, Blocks.BOOKSHELF, 0])
		bl.append([mid, 5, d / 2, Blocks.LAMP, 0])
	# Telhado de duas aguas, com oitoes.
	var top := wall_h + 1
	var layers := (d + 1) / 2
	for i in layers:
		var y := top + i
		for x in range(-1, w + 1):
			var zf := i - 1
			var zb := d - i
			if zf >= zb:
				bl.append([x, y, zf, p["roof"], 0])
			else:
				bl.append([x, y, zf, p["roof"], Blocks.SH_WEDGE])
				bl.append([x, y, zb, p["roof"], Blocks.SH_WEDGE | (2 << 4)])
				if x >= 0 and x < w:
					for z in range(zf + 1, zb):
						var gable := x == 0 or x == w - 1
						bl.append([x, y, z, p["wall"] if gable else 0, 0])
	# Mobilia.
	var choice := r.randi() % 3
	bl.append([1, 1, d - 2, Blocks.BED, 2 << 4] if not tall else [w - 2, 1, d - 2, Blocks.FURNACE, 2 << 4])
	bl.append([w - 2, 1, d - 2, p["chest"], 2 << 4])
	loot.append([w - 2, 1, d - 2, 1])
	if choice == 0:
		bl.append([w - 2, 1, 2, Blocks.TABLE, 0])
		bl.append([w - 3, 1, 2, Blocks.CHAIR, 1 << 4])
		bl.append([w - 2, 2, 2, Blocks.LANTERN, 0])
	elif choice == 1:
		bl.append([w - 2, 1, 2, Blocks.WORKBENCH, 0])
		bl.append([w - 2, 1, 3, Blocks.BARREL, 0])
		bl.append([1, 1, 1, Blocks.TORCH, 0])
	else:
		bl.append([w - 2, 1, 2, Blocks.BOOKSHELF, 0])
		bl.append([w - 2, 2, 2, Blocks.FLOWER_POT, 0])
		bl.append([1, 1, 1, Blocks.LAMP, 0])
	return top + layers + 1


func _temple(bl: Array, loot: Array, p: Dictionary, r: RandomNumberGenerator) -> int:
	var w := 7
	var d := 11
	var wall_h := 6
	for x in w:
		for z in d:
			bl.append([x, 0, z, p["trim"], 0])
			var edge := x == 0 or x == w - 1 or z == 0 or z == d - 1
			var pillar := edge and (z % 3 == 0) and (x == 0 or x == w - 1)
			for y in range(1, wall_h + 1):
				if not edge:
					bl.append([x, y, z, 0, 0])
				else:
					bl.append([x, y, z, p["pillar"] if pillar else p["trim"], 0])
	bl.append([3, 1, 0, Blocks.DOOR, 0])
	bl.append([3, 2, 0, Blocks.DOOR, 0])
	for z in [2, 5, 8]:
		bl.append([0, 3, z, Blocks.STAINED_0 + (z % 4), 0])
		bl.append([0, 4, z, Blocks.STAINED_0 + (z % 4), 0])
		bl.append([w - 1, 3, z, Blocks.STAINED_0 + ((z + 1) % 4), 0])
		bl.append([w - 1, 4, z, Blocks.STAINED_0 + ((z + 1) % 4), 0])
	for z in range(2, 9, 2):
		bl.append([1, 1, z, Blocks.BENCH, 1 << 4])
		bl.append([5, 1, z, Blocks.BENCH, 3 << 4])
	bl.append([3, 1, 9, Blocks.CRYSTAL_BLOCK if r.randf() < 0.5 else Blocks.GOLD_BLOCK, 0])
	bl.append([2, 1, 9, Blocks.LAMP, 0])
	bl.append([4, 1, 9, Blocks.LAMP, 0])
	bl.append([1, 1, 9, p["chest"], 2 << 4])
	loot.append([1, 1, 9, 2])
	var top := wall_h + 1
	for i in 4:
		var y := top + i
		for z in range(-1, d + 1):
			var xf := i - 1
			var xb := w - i
			if xf >= xb:
				bl.append([xf, y, z, p["roof"], 0])
			else:
				bl.append([xf, y, z, p["roof"], Blocks.SH_WEDGE | (1 << 4)])
				bl.append([xb, y, z, p["roof"], Blocks.SH_WEDGE | (3 << 4)])
				if z >= 0 and z < d:
					for x in range(xf + 1, xb):
						var gable := z == 0 or z == d - 1
						bl.append([x, y, z, p["trim"] if gable else 0, 0])
	return top + 5


func _tower(bl: Array, loot: Array, p: Dictionary, r: RandomNumberGenerator, ruined: bool) -> int:
	var hh := 10
	for x in 5:
		for z in 5:
			bl.append([x, 0, z, p["found"], 0])
			var edge := x == 0 or x == 4 or z == 0 or z == 4
			for y in range(1, hh):
				var id := 0
				if edge:
					id = p["wall2"] if r.randf() < 0.3 else p["wall"]
					if ruined and y > 3 and r.randf() < float(y) / hh * 0.9:
						id = 0
				if y == 5 and not edge:
					id = p["floor"]
				bl.append([x, y, z, id, 0])
			if edge and (x + z) % 2 == 0 and not ruined:
				bl.append([x, hh, z, p["wall"], 0])
	bl.append([2, 1, 0, 0, 0])
	bl.append([2, 2, 0, 0, 0])
	for y in [3, 7]:
		bl.append([0, y, 2, Blocks.WINDOW_IRON if not ruined else 0, 0])
		bl.append([4, y, 2, Blocks.WINDOW_IRON if not ruined else 0, 0])
	bl.append([1, 1, 1, p["floor"], Blocks.SH_STAIRS])
	bl.append([1, 2, 2, p["floor"], Blocks.SH_STAIRS])
	bl.append([1, 3, 3, p["floor"], Blocks.SH_STAIRS])
	bl.append([1, 4, 3, 0, 0])
	bl.append([1, 5, 3, 0, 0])
	bl.append([1, 5, 2, 0, 0])
	bl.append([3, 1, 3, p["chest"], 2 << 4])
	loot.append([3, 1, 3, 2 if ruined else 1])
	if not ruined:
		bl.append([2, 6, 2, Blocks.LANTERN, 0])
	return hh + 2


# ---------------------------------------------------------------- carimbo no chunk

## Escreve no chunk (blocks/shapes) tudo o que estiver dentro dele. Devolve ticks, saques e NPCs.
func stamp(blocks: PackedByteArray, shapes: Dictionary, cx: int, cz: int) -> Dictionary:
	var ox := cx * 16
	var oz := cz * 16
	var res := {"ticks": [], "loot": [], "npcs": [], "top": 0}
	var seen := {}
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(15, 0), Vector2i(0, 15), Vector2i(15, 15)]:
		for off: Vector2i in [Vector2i(0, 0), Vector2i(-70, 0), Vector2i(70, 0), Vector2i(0, -70), Vector2i(0, 70)]:
			var wx := ox + corner.x + off.x
			var wz := oz + corner.y + off.y
			seen[Vector2i(floori(float(wx) / CELL), floori(float(wz) / CELL))] = true
	for cell: Vector2i in seen:
		var l := layout(cell)
		if l.is_empty():
			continue
		var lo: Vector2i = l["lo"]
		var hi: Vector2i = l["hi"]
		if hi.x < ox or lo.x > ox + 15 or hi.y < oz or lo.y > oz + 15:
			continue
		var pal: String = l["pal"]
		var p: Dictionary = PALETTES[pal]
		for pc: Vector3i in l["paths"]:
			if pc.x >= ox and pc.x < ox + 16 and pc.z >= oz and pc.z < oz + 16 and pc.y > 1:
				var idx := pc.y * 256 + (pc.z - oz) * 16 + (pc.x - ox)
				var cur := blocks[idx]
				if cur != Blocks.WATER and Blocks.KIND[cur] == Blocks.K_CUBE:
					blocks[idx] = p["path"]
					var above := idx + 256
					if above < blocks.size() and Blocks.KIND[blocks[above]] == Blocks.K_PLANT:
						blocks[above] = 0
		for b: Dictionary in l["builds"]:
			_stamp_build(blocks, shapes, ox, oz, b, pal, res)
		var c: Vector3i = l["center"]
		if c.x >= ox and c.x < ox + 16 and c.z >= oz and c.z < oz + 16:
			for np: Array in l["npcs"]:
				res["npcs"].append([np[0], np[1], np[2], l["id"]])
	return res


func _stamp_build(blocks: PackedByteArray, shapes: Dictionary, ox: int, oz: int, b: Dictionary, pal: String, res: Dictionary) -> void:
	var bx: int = b["x"]
	var bz: int = b["z"]
	if bx + int(b["w"]) < ox or bx > ox + 15 or bz + int(b["d"]) < oz or bz > oz + 15:
		return
	var tpl := template(b["t"], pal, b["var"])
	var rot: int = b["rot"]
	var w0: int = b["w0"]
	var d0: int = b["d0"]
	var by: int = b["y"]
	var p: Dictionary = PALETTES[pal]
	var hgt: int = tpl["h"]
	# Fundacao e limpeza da area.
	for lz in d0:
		for lx in w0:
			var rl := rot_local(lx, lz, w0, d0, rot)
			var wx := bx + rl.x - ox
			var wz := bz + rl.y - oz
			if wx < 0 or wx > 15 or wz < 0 or wz > 15:
				continue
			var col := wz * 16 + wx
			for y in range(by + 1, mini(by + hgt + 2, WorldGen.H)):
				blocks[y * 256 + col] = 0
				shapes.erase(y * 256 + col)
			for y in range(by - 1, maxi(by - 9, 1), -1):
				var id := blocks[y * 256 + col]
				if id != 0 and id != Blocks.WATER and Blocks.KIND[id] != Blocks.K_PLANT and Blocks.KIND[id] != Blocks.K_LEAVES:
					break
				blocks[y * 256 + col] = p["found"]
	for e: Array in tpl["blocks"]:
		var rl := rot_local(e[0], e[2], w0, d0, rot)
		var wx := bx + rl.x - ox
		var wz := bz + rl.y - oz
		var y: int = by + int(e[1])
		if wx < 0 or wx > 15 or wz < 0 or wz > 15 or y < 1 or y >= WorldGen.H:
			continue
		var idx := y * 256 + wz * 16 + wx
		var id: int = e[3]
		blocks[idx] = id
		var sh: int = e[4]
		if id != 0 and (Blocks.KIND[id] == Blocks.K_MODEL or (sh & 15) == Blocks.SH_STAIRS or (sh & 15) == Blocks.SH_WEDGE or (sh & 15) == Blocks.SH_WALL):
			sh = (sh & 15) | ((((sh >> 4) & 3) + rot) % 4) << 4
		if sh != 0 and id != 0:
			shapes[idx] = sh
		else:
			shapes.erase(idx)
		res["top"] = maxi(res["top"], y + 1)
	for lt: Array in tpl["loot"]:
		var rl := rot_local(lt[0], lt[2], w0, d0, rot)
		var wx := bx + rl.x - ox
		var wz := bz + rl.y - oz
		if wx >= 0 and wx <= 15 and wz >= 0 and wz <= 15:
			res["loot"].append([(by + int(lt[1])) * 256 + wz * 16 + wx, lt[3]])
	for cr: Array in tpl["crops"]:
		var rl := rot_local(cr[0], cr[2], w0, d0, rot)
		var wx := bx + rl.x - ox
		var wz := bz + rl.y - oz
		if wx >= 0 and wx <= 15 and wz >= 0 and wz <= 15:
			res["ticks"].append((by + int(cr[1])) * 256 + wz * 16 + wx)
