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
	"planicie": {"door_v": 0, "win_v": 0, "floor": Blocks.PLANKS, "wall": Blocks.PLANKS, "wall2": Blocks.COBBLE, "pillar": Blocks.LOG, "roof": Blocks.ROOF_TILES, "found": Blocks.COBBLE,
		"path": Blocks.PATH, "fence": Blocks.FENCE, "trim": Blocks.STONE_BRICKS, "chest": Blocks.CHEST, "wool": Blocks.WOOL_0 + 3},
	"floresta": {"door_v": 8, "win_v": 6, "floor": Blocks.MAHOG_PLANKS, "wall": Blocks.BIRCH_PLANKS, "wall2": Blocks.MOSSY_COBBLE, "pillar": Blocks.BIRCH_LOG, "roof": Blocks.ROOF_GREEN,
		"found": Blocks.MOSSY_COBBLE, "path": Blocks.PATH, "fence": Blocks.FENCE, "trim": Blocks.LIMESTONE_BRICKS, "chest": Blocks.CHEST_BIRCH, "wool": Blocks.WOOL_0 + 6},
	"cerejeira": {"door_v": 23, "win_v": 15, "floor": Blocks.PLANKS, "wall": Blocks.CHERRY_PLANKS, "wall2": Blocks.STONE_BRICKS, "pillar": Blocks.CHERRY_LOG, "roof": Blocks.ROOF_TILES,
		"found": Blocks.STONE_BRICKS, "path": Blocks.PATH, "fence": Blocks.FENCE, "trim": Blocks.MARBLE_BRICKS, "chest": Blocks.CHEST_CHERRY, "wool": Blocks.WOOL_0 + 10},
	"deserto": {"door_v": 18, "win_v": 14, "window": Blocks.WINDOW_IRON, "floor": Blocks.SANDSTONE, "wall": Blocks.SANDSTONE_BRICKS, "wall2": Blocks.MUD_BRICKS, "pillar": Blocks.SANDSTONE, "roof": Blocks.TERRACOTTA,
		"found": Blocks.SANDSTONE, "path": Blocks.PATH, "fence": Blocks.FENCE, "trim": Blocks.MUD_BRICKS, "chest": Blocks.CHEST_PALM, "wool": Blocks.WOOL_0 + 4},
	"neve": {"door_v": 5, "win_v": 4, "floor": Blocks.PINE_PLANKS, "wall": Blocks.PINE_PLANKS, "wall2": Blocks.STONE_BRICKS, "pillar": Blocks.PINE_LOG, "roof": Blocks.ROOF_SLATE,
		"found": Blocks.STONE_BRICKS, "path": Blocks.GRAVEL, "fence": Blocks.FENCE, "trim": Blocks.STONE_BRICKS, "chest": Blocks.CHEST_PINE, "wool": Blocks.WOOL_0 + 8},
	"bandidos": {"door_v": 13, "win_v": 10, "window": Blocks.WINDOW_IRON, "floor": Blocks.MAHOG_PLANKS, "wall": Blocks.MAHOG_PLANKS, "wall2": Blocks.BASALT_BRICKS, "pillar": Blocks.MAHOG_LOG, "roof": Blocks.WOOL_0 + 2,
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
		# Construcoes da vila (cada uma com seus moradores), em anel ao redor do poco.
		var types := ["centro_comercial", "torre_guarda", "ferreiro", "fazenda", "curral", "cabana_lenhador", "cabana_caca",
			"mina", "cabana_construtor", "lote", "casa_artesao", "casa_alfaiate", "casa_tecelao",
			"casa", "casa_grande", "fazenda", "casa", "templo", "casa", "curral"]
		var n := rng.randi_range(16, types.size())
		for i in n:
			var t: String = types[i]
			var sz := _size(t)
			var b: Dictionary = {}
			var dir := Vector2.ZERO
			var rad := 0.0
			for tries in 4:
				var ang := TAU * i / n + rng.randf_range(-0.2, 0.2) + tries * 0.31
				rad = 14.0 + maxf(sz.x, sz.y) * 0.6 + rng.randf_range(0.0, 6.0) + tries * 5.0
				dir = Vector2(cos(ang), sin(ang))
				var rot := _rot_towards(dir)
				var rs := sz if rot % 2 == 0 else Vector2i(sz.y, sz.x)
				var bx := cx + int(dir.x * rad) - rs.x / 2
				var bz := cz + int(dir.y * rad) - rs.y / 2
				var by := gen.height_biome(bx + rs.x / 2, bz + rs.y / 2) & 0xFF
				if absi(by - hc) > 7 or by <= WorldGen.SEA:
					continue
				var cand := _place(t, bx, bz, by, rot, sz.x, sz.y)
				if not _overlaps(cand, builds):
					b = cand
					break
			if b.is_empty():
				continue
			b["var"] = rng.randi()
			builds.append(b)
			_residents(b, rng, npcs, Vector3(cx, hc, cz))
			if t != "fazenda" and t != "curral":
				var pth := _path(Vector2i(cx, cz), _door_cell(b))
				paths.append_array(pth)
				# Postes de iluminacao ao lado do caminho, a cada 6 blocos.
				var dv := Vector2(_door_cell(b) - Vector2i(cx, cz)).normalized()
				var side := Vector2i(roundi(-dv.y * 2.0), roundi(dv.x * 2.0))
				for k in range(7, pth.size() - 2, 7):
					var pc: Vector3i = pth[k]
					var lp2 := Vector2i(pc.x, pc.z) + side
					var lb2 := _place("lampiao", lp2.x, lp2.y, gen.height_biome(lp2.x, lp2.y) & 0xFF, 0, 1, 1)
					if not _hits(lb2, builds) and not _lamp_near(lp2, builds, 6):
						builds.append(lb2)
			if rng.randf() < 0.4:
				var lp := Vector2i(cx, cz) + Vector2i(int(dir.x * rad * 0.5) + 2, int(dir.y * rad * 0.5) + 2)
				var lb := _place("lampiao", lp.x, lp.y, gen.height_biome(lp.x, lp.y) & 0xFF, 0, 1, 1)
				if not _overlaps(lb, builds):
					builds.append(lb)
		# Postes em volta da praca do poco.
		for o: Vector2i in [Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4)]:
			var lb3 := _place("lampiao", cx + o.x, cz + o.y, gen.height_biome(cx + o.x, cz + o.y) & 0xFF, 0, 1, 1)
			if not _hits(lb3, builds):
				builds.append(lb3)
		# Mais um guarda e um comerciante na praca.
		var cv := Vector3(cx, hc, cz)
		npcs.append([Vector3(cx + 3.5, hc + 2.0, cz + 0.5), "aldeao", _prof_seed(rng, "guarda"), {"center": cv}])
		npcs.append([Vector3(cx - 2.5, hc + 2.0, cz + 2.5), "aldeao", _prof_seed(rng, "comerciante"), {"center": cv}])
		# O construtor recebe o lote onde vai erguer uma casa nova.
		var lote: Dictionary = {}
		for bb: Dictionary in builds:
			if bb["t"] == "lote":
				lote = bb
		if not lote.is_empty():
			for np: Array in npcs:
				if np.size() > 3 and np[1] == "aldeao" and Rigs.npc_options("aldeao", int(np[2]))["profession"] == "construtor":
					np[3]["plot"] = lote
	elif kind == "bandidos":
		builds.append(_place("fogueira", cx, cz, hc, 0, 1, 1))
		for o: Vector2i in [Vector2i(-5, 0), Vector2i(5, 0), Vector2i(0, -5), Vector2i(0, 5)]:
			builds.append(_place("poste_tocha", cx + o.x, cz + o.y, gen.height_biome(cx + o.x, cz + o.y) & 0xFF, 0, 1, 1))
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


## Semente de aldeao com a profissao dada (Rigs.npc_options escolhe a profissao pela semente).
static func _prof_seed(rng: RandomNumberGenerator, prof: String) -> int:
	return (rng.randi() % 100000) * Rigs.PROFS.size() + maxi(0, Rigs.PROFS.find(prof))


## Moradores de cada construcao, na porta; animais dentro do curral.
func _residents(b: Dictionary, rng: RandomNumberGenerator, npcs: Array, center: Vector3 = Vector3.ZERO) -> void:
	var door := _door_cell(b)
	var dp := Vector3(door.x + 0.5, int(b["y"]) + 2.0, door.y + 0.5)
	var bc := Vector3(int(b["x"]) + int(b["w"]) * 0.5, int(b["y"]) + 1.0, int(b["z"]) + int(b["d"]) * 0.5)
	var profs: Array = []
	match b["t"]:
		"mina":
			profs = ["minerador", "minerador"]
			# Mineradores trabalham na camara no fundo da mina.
			dp = _local_world(b, 3, -11, 17) + Vector3(0.5, 0, 0.5)
			bc = _local_world(b, 3, -11, 19) + Vector3(0.5, 0, 0.5)
		"cabana_construtor": profs = ["construtor"]
		"casa_artesao": profs = ["artesão"]
		"casa_alfaiate": profs = ["alfaiate"]
		"casa_tecelao": profs = ["tecelão"]
		"casa": profs = [["fazendeiro", "caçador", "criador", "lenhador"][rng.randi() % 4]]
		"casa_grande": profs = ["minerador", "comerciante"]
		"fazenda": profs = ["fazendeiro"]
		"ferreiro": profs = ["ferreiro", "armeiro", "ferramenteiro"]
		"curral": profs = ["criador"]
		"cabana_caca": profs = ["caçador"]
		"cabana_lenhador": profs = ["lenhador", "lenhador"]
		"torre_guarda": profs = ["guarda", "guarda"]
		"centro_comercial": profs = ["comerciante", "comerciante", "comerciante"]
	for k in profs.size():
		npcs.append([dp + Vector3(k * 0.8, 0, 0), "aldeao", _prof_seed(rng, profs[k]), {"center": center, "face": bc, "home": dp}])
	if b["t"] == "curral":
		var kinds := ["vaca", "ovelha", "porco", "galinha"]
		var main: String = kinds[rng.randi() % kinds.size()]
		var c := Vector3(int(b["x"]) + int(b["w"]) * 0.5, int(b["y"]) + 2.0, int(b["z"]) + int(b["d"]) * 0.5)
		for k in rng.randi_range(4, 6):
			var kind: String = main if k < 3 else kinds[rng.randi() % kinds.size()]
			npcs.append([c + Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(-1.5, 1.5)), kind, rng.randi() % 12])


## Cama de 2 blocos: cabeceira em (x, z) e pes no bloco anterior, conforme a rotacao r.
static func _bed(bl: Array, x: int, y: int, z: int, r: int) -> void:
	var hd := Blocks.bed_head_dir(r)
	bl.append([x, y, z, Blocks.BED, r << 4])
	bl.append([x - hd.x, y, z - hd.y, Blocks.BED_FOOT, r << 4])


## Posicao no mundo de uma coordenada local da construcao.
static func _local_world(b: Dictionary, lx: int, ly: int, lz: int) -> Vector3:
	var rl := rot_local(lx, lz, b["w0"], b["d0"], b["rot"])
	return Vector3(int(b["x"]) + rl.x, int(b["y"]) + ly, int(b["z"]) + rl.y)


## Blocos (no mundo) da casa que o construtor vai erguer no lote, de baixo para cima.
func plan_blocks(b: Dictionary, pal: String) -> Array:
	var tpl := template("casa", pal, b["var"])
	var rot: int = b["rot"]
	var out: Array = []
	for e: Array in tpl["blocks"]:
		var id: int = e[3]
		if id == 0:
			continue
		var rl := rot_local(e[0], e[2], b["w0"], b["d0"], rot)
		var sh: int = e[4]
		if Blocks.KIND[id] == Blocks.K_MODEL or (sh & 15) == Blocks.SH_STAIRS or (sh & 15) == Blocks.SH_WEDGE or (sh & 15) == Blocks.SH_WALL:
			sh = (sh & ~0x30) | ((((sh >> 4) & 3) + rot) % 4) << 4
		out.append([Vector3i(int(b["x"]) + rl.x, int(b["y"]) + int(e[1]), int(b["z"]) + rl.y), id, sh])
	out.sort_custom(func(a: Array, c: Array) -> bool: return a[0].y < c[0].y)
	return out


static func _size(t: String) -> Vector2i:
	match t:
		"mina": return Vector2i(7, 20)
		"cabana_construtor": return Vector2i(10, 7)
		"lote": return Vector2i(7, 7)
		"casa_artesao": return Vector2i(7, 7)
		"casa_alfaiate": return Vector2i(7, 7)
		"casa_tecelao": return Vector2i(10, 7)
		"curral": return Vector2i(11, 9)
		"cabana_caca": return Vector2i(8, 7)
		"cabana_lenhador": return Vector2i(10, 7)
		"torre_guarda": return Vector2i(5, 5)
		"centro_comercial": return Vector2i(11, 9)
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


## Ja existe um poste a menos de r blocos?
static func _lamp_near(p: Vector2i, list: Array, r: int) -> bool:
	for o: Dictionary in list:
		if o["t"] == "lampiao" and absi(int(o["x"]) - p.x) + absi(int(o["z"]) - p.y) < r:
			return true
	return false


## Sobreposicao exata (sem margem): para postes pequenos.
static func _hits(b: Dictionary, list: Array) -> bool:
	var r := Rect2i(int(b["x"]) - 1, int(b["z"]) - 1, int(b["w"]) + 2, int(b["d"]) + 2)
	for o: Dictionary in list:
		if r.intersects(Rect2i(o["x"], o["z"], o["w"], o["d"])):
			return true
	return false


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
				bl.append([c.x, 3, c.y, Blocks.LANTERN if c.x == c.y else p["fence"], 0])
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
			# Cerca em volta (entrada no meio da frente) e espantalho no canto.
			for x in 9:
				for z in 7:
					if (x == 0 or x == 8 or z == 0 or z == 6) and not (z == 0 and x == 4):
						bl.append([x, 1, z, p["fence"], 0])
			bl.append([8, 1, 6, p["fence"], 0])
			bl.append([8, 2, 6, Blocks.HAY, 0])
			bl.append([8, 3, 6, Blocks.PUMPKIN, 0])
			bl.append([0, 2, 6, Blocks.HAY, 0])
			bl.append([0, 2, 0, Blocks.LANTERN, 0])
			h = 4
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
			bl.append([0, 4, 3, Blocks.LANTERN, 0])
			# Chamine de pedra sobre as fornalhas e cocho de agua para temperar.
			for y in range(4, 8):
				bl.append([1, y, 6, Blocks.COBBLE, 0])
				bl.append([2, y, 6, Blocks.COBBLE, 0])
			bl.append([1, 8, 6, Blocks.CAMPFIRE, 0])
			bl.append([5, 1, 3, p["trim"], Blocks.SH_SLAB])
			bl.append([5, 1, 4, Blocks.WATER, 0])
			bl.append([3, 1, 1, Blocks.BARREL, 0])
			h = 9
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
			bl.append([2, 2, 2, Blocks.LANTERN, 0])
			h = 4
		"curral":
			h = _pen(bl, p, r)
		"mina":
			h = _mine(bl, loot, p, r)
		"cabana_construtor":
			h = _builder_hut(bl, loot, p, r)
		"lote":
			# Terreno marcado para a casa que o construtor vai erguer: piso, estacas e um monte de material.
			for x in 7:
				for z in 7:
					bl.append([x, 0, z, p["found"], 0])
			for c: Vector2i in [Vector2i(0, 0), Vector2i(6, 0), Vector2i(0, 6), Vector2i(6, 6)]:
				bl.append([c.x, 1, c.y, p["fence"], 0])
			h = 3
		"casa_artesao":
			h = _craft_house(bl, loot, p, r, "artesao")
		"casa_alfaiate":
			h = _craft_house(bl, loot, p, r, "alfaiate")
		"casa_tecelao":
			h = _craft_house(bl, loot, p, r, "tecelao")
		"cabana_caca":
			h = _hunter(bl, loot, p, r)
		"cabana_lenhador":
			h = _lumber(bl, loot, p, r)
		"torre_guarda":
			h = _guard_tower(bl, loot, p, r)
		"centro_comercial":
			h = _market(bl, loot, p, r)
		"lampiao":
			# Poste: base de pedra, haste de madeira e lanterna no topo.
			bl.append([0, 1, 0, p["trim"], Blocks.SH_PILLAR])
			bl.append([0, 2, 0, p["fence"], 0])
			bl.append([0, 3, 0, p["fence"], 0])
			bl.append([0, 4, 0, Blocks.LANTERN, 0])
			h = 5
		"poste_tocha":
			bl.append([0, 1, 0, p["fence"], 0])
			bl.append([0, 2, 0, Blocks.TORCH, 0])
			h = 3
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
			_bed(bl, 1, 1, 3, 0)
			bl.append([3, 1, 3, p["chest"], 2 << 4])
			loot.append([3, 1, 3, 2])
			bl.append([2, 1, 2, Blocks.TORCH, 0])
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


## Mina: entrada coberta, rampa de escada descendo 12 blocos com escoras de madeira e lanternas,
## veios de minerio nas paredes e uma camara no fundo com bau.
func _mine(bl: Array, loot: Array, p: Dictionary, r: RandomNumberGenerator) -> int:
	for x in 7:
		for z in 4:
			bl.append([x, 0, z, p["found"], 0])
			bl.append([x, 5, z, p["roof"], Blocks.SH_SLAB])
	for c: Vector2i in [Vector2i(1, 0), Vector2i(5, 0), Vector2i(1, 3), Vector2i(5, 3)]:
		for y in range(1, 5):
			bl.append([c.x, y, c.y, p["pillar"], 0])
	for x in range(1, 6):
		bl.append([x, 4, 0, p["floor"], 0])
		bl.append([x, 4, 3, p["floor"], 0])
	bl.append([3, 3, 1, Blocks.LANTERN, 0])
	bl.append([0, 1, 1, Blocks.BARREL, 0])
	bl.append([6, 1, 1, Blocks.CRATE, 0])
	bl.append([6, 1, 2, Blocks.COAL_BLOCK, 0])
	var ores := [Blocks.COAL_ORE, Blocks.COAL_ORE, Blocks.IRON_ORE, Blocks.COPPER_ORE, Blocks.STONE, Blocks.STONE]
	for z in range(4, 16):
		var f := -(z - 3)
		for x in range(2, 5):
			bl.append([x, f, z, Blocks.COBBLE, Blocks.SH_STAIRS | (2 << 4)])
			for y in range(f + 1, f + 4):
				bl.append([x, y, z, 0, 0])
		bl.append([1, f, z, Blocks.STONE, 0])
		bl.append([5, f, z, Blocks.STONE, 0])
		if z % 3 == 0:
			for y in range(f + 1, f + 4):
				bl.append([1, y, z, p["pillar"], 0])
				bl.append([5, y, z, p["pillar"], 0])
			for x in range(1, 6):
				bl.append([x, f + 4, z, p["floor"], 0])
		else:
			bl.append([1, f + 2, z, ores[r.randi() % ores.size()], 0])
			bl.append([5, f + 2, z, ores[r.randi() % ores.size()], 0])
		if z % 6 == 1:
			bl.append([2, f + 3, z, Blocks.LANTERN, 0])
	# Camara no fundo.
	for x in 7:
		for z in range(16, 20):
			bl.append([x, -12, z, Blocks.STONE, 0])
			for y in range(-11, -7):
				bl.append([x, y, z, 0, 0])
	for z in range(16, 20):
		bl.append([0, -10, z, ores[r.randi() % 4], 0])
	for x in 7:
		bl.append([x, -10, 20, ores[r.randi() % 4], 0])
		bl.append([x, -7, 17, p["floor"], 0])
	for c: Vector2i in [Vector2i(0, 17), Vector2i(6, 17)]:
		for y in range(-11, -7):
			bl.append([c.x, y, c.y, p["pillar"], 0])
	bl.append([3, -8, 18, Blocks.LANTERN, 0])
	bl.append([1, -11, 19, Blocks.LANTERN, 0])
	bl.append([5, -11, 19, p["chest"], 2 << 4])
	loot.append([5, -11, 19, 2])
	bl.append([6, -11, 16, Blocks.IRON_ORE, 0])
	return 6


## Cabana do construtor: oficina com pilhas de tabuas, tijolos e pedra, e um andaime ao lado.
func _builder_hut(bl: Array, loot: Array, p: Dictionary, r: RandomNumberGenerator) -> int:
	var h := _house(bl, loot, p, 7, 7, 3, r, false)
	var piles := [p["floor"], Blocks.BRICKS, Blocks.COBBLE, Blocks.STONE_BRICKS, p["floor"]]
	for z in range(1, 6):
		for y in range(1, 2 + (z % 2)):
			bl.append([7, y, z, piles[z - 1], 0])
	for z: int in [0, 6]:
		for y in range(1, 5):
			bl.append([9, y, z, p["fence"], 0])
	for z in range(0, 7):
		bl.append([9, 4, z, p["floor"], Blocks.SH_SLAB_TOP])
	bl.append([8, 1, 3, Blocks.WORKBENCH, 0])
	bl.append([8, 1, 1, Blocks.BARREL, 0])
	return maxi(h, 6)


## Casas de oficio: interior e quintal conforme o oficio.
func _craft_house(bl: Array, loot: Array, p: Dictionary, r: RandomNumberGenerator, kind: String) -> int:
	var h := _house(bl, loot, p, 7, 7, 3, r, false)
	match kind:
		"artesao":
			# Moveis feitos pelo artesao e cortinas de la nas janelas.
			_bed(bl, 2, 1, 5, 0)
			bl.append([4, 1, 3, Blocks.TABLE, 0])
			bl.append([3, 1, 3, Blocks.CHAIR, 1 << 4])
			bl.append([5, 1, 3, Blocks.CHAIR, 3 << 4])
			bl.append([5, 1, 5, Blocks.WORKBENCH, 0])
			bl.append([1, 1, 1, Blocks.BOOKSHELF, 0])
			for c: Vector3i in [Vector3i(1, 2, 1), Vector3i(5, 2, 1)]:
				bl.append([c.x, c.y, c.z, Blocks.WOOL_0 + 3, Blocks.SH_PANE])
		"alfaiate":
			# Manequim, rolos de tecido coloridos e mesa de corte.
			bl.append([3, 1, 4, p["fence"], 0])
			bl.append([3, 2, 4, Blocks.WOOL_0 + 8, 0])
			bl.append([3, 3, 4, Blocks.WOOL_0, Blocks.SH_SLAB])
			for x in range(1, 6, 2):
				bl.append([x, 1, 1, Blocks.TABLE, 0])
				bl.append([x, 2, 1, Blocks.WOOL_0 + [3, 6, 10][(x / 2) % 3], Blocks.SH_SLAB])
			bl.append([5, 1, 4, Blocks.WOOL_0 + 4, 0])
			bl.append([5, 2, 4, Blocks.WOOL_0 + 5, Blocks.SH_SLAB])
		"tecelao":
			# Tear (molduras com fios de la), fardos de la e tanques de curtir couro com varal de peles.
			for x: int in [2, 4]:
				bl.append([x, 1, 3, p["fence"], 0])
				bl.append([x, 2, 3, p["fence"], 0])
			bl.append([3, 1, 3, Blocks.WOOL_0, Blocks.SH_PANE | (0 << 4)])
			bl.append([3, 2, 3, Blocks.WOOL_0 + 8, Blocks.SH_PANE])
			for x in range(2, 5):
				bl.append([x, 3, 3, p["floor"], Blocks.SH_SLAB])
			bl.append([1, 1, 5, Blocks.WOOL_0, 0])
			bl.append([1, 2, 5, Blocks.WOOL_0 + 1, 0])
			bl.append([5, 1, 5, Blocks.HAY, 0])
			for z in range(1, 6, 2):
				bl.append([7, 1, z, Blocks.BARREL, 0])
				bl.append([8, 0, z, Blocks.WATER, 0])
			for z in range(0, 7):
				bl.append([9, 1, z, p["fence"], 0])
			for z in range(1, 6, 2):
				bl.append([9, 2, z, Blocks.WOOL_0 + 11, Blocks.SH_PANE | (1 << 4)])
	return h


## Curral 11x9: cerca fechada, abrigo coberto no fundo, feno, cocho de agua e lanternas.
func _pen(bl: Array, p: Dictionary, r: RandomNumberGenerator) -> int:
	var w := 11
	var d := 9
	for x in w:
		for z in d:
			bl.append([x, 0, z, Blocks.DIRT if (x + z) % 3 else Blocks.GRASS, 0])
			if x == 0 or x == w - 1 or z == 0 or z == d - 1:
				bl.append([x, 1, z, p["fence"], 0])
	for c: Vector2i in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, d - 1), Vector2i(w - 1, d - 1)]:
		bl.append([c.x, 2, c.y, Blocks.LANTERN, 0])
	# Abrigo: postes e telhado de laje no fundo.
	for x: int in [1, 5, 9]:
		for y in range(1, 4):
			bl.append([x, y, d - 2, p["pillar"], 0])
	for x in range(1, w - 1):
		for z in range(d - 3, d - 1):
			bl.append([x, 4, z, p["roof"], Blocks.SH_SLAB])
	bl.append([2, 1, d - 2, Blocks.HAY, 0])
	bl.append([3, 1, d - 2, Blocks.HAY, 0])
	bl.append([2, 2, d - 2, Blocks.HAY, 0])
	# Cocho: agua com borda de pedra.
	for x in range(7, 9):
		bl.append([x, 0, 2, Blocks.WATER, 0])
	return 6


## Cabana de madeira (base comum das cabanas): paredes de tronco, telhado de duas aguas.
func _cabin(bl: Array, loot: Array, p: Dictionary, r: RandomNumberGenerator, w: int, d: int) -> int:
	var pc := p.duplicate()
	pc["wall"] = p["pillar"]
	pc["wall2"] = p["pillar"]
	pc["wool"] = Blocks.WOOL_0 + 11
	return _house(bl, loot, pc, w, d, 3, r, false)


## Cabana de caca: peles secando no varal, galhada sobre a porta, fogueira com tocos.
func _hunter(bl: Array, loot: Array, p: Dictionary, r: RandomNumberGenerator) -> int:
	var h := _cabin(bl, loot, p, r, 7, 7)
	var hide := Blocks.WOOL_0 + 11
	for z in range(1, 6):
		bl.append([7, 1, z, p["fence"], 0])
	for z in range(1, 6, 2):
		bl.append([7, 2, z, hide, Blocks.SH_PANE | (1 << 4)])
	bl.append([3, 4, -1, p["fence"], 0])
	bl.append([2, 5, -1, p["fence"], 0])
	bl.append([4, 5, -1, p["fence"], 0])
	bl.append([5, 1, 4, Blocks.BARREL, 0])
	return h


## Cabana do lenhador: pilha de toras ao lado, toco com machado e serragem.
func _lumber(bl: Array, loot: Array, p: Dictionary, r: RandomNumberGenerator) -> int:
	var h := _cabin(bl, loot, p, r, 7, 7)
	for z in range(1, 6):
		for y in range(1, 3 if z % 2 else 4):
			bl.append([7, y, z, p["pillar"], 0])
			bl.append([8, y, z, p["pillar"], 0])
	for z: int in [0, 6]:
		bl.append([9, 1, z, p["fence"], 0])
		bl.append([9, 2, z, p["fence"], 0])
	for z in range(0, 7):
		bl.append([9, 3, z, p["roof"], Blocks.SH_SLAB])
		bl.append([8, 4, z, p["roof"], Blocks.SH_SLAB])
		bl.append([7, 4, z, p["roof"], Blocks.SH_SLAB])
	bl.append([8, 1, 0, p["pillar"], Blocks.SH_SLAB])
	bl.append([5, 1, 4, Blocks.WORKBENCH, 0])
	return maxi(h, 5)


## Torre da guarnicao: pedra, ameias, estandarte na frente e lanternas no alto.
func _guard_tower(bl: Array, loot: Array, p: Dictionary, r: RandomNumberGenerator) -> int:
	var pc := p.duplicate()
	pc["wall"] = Blocks.STONE_BRICKS
	pc["wall2"] = Blocks.COBBLE
	pc["found"] = Blocks.STONE_BRICKS
	var h := _tower(bl, loot, pc, r, false)
	var flag: int = p.get("wool", Blocks.WOOL_0 + 3)
	bl.append([2, 6, -1, flag, Blocks.SH_PANE])
	bl.append([2, 7, -1, flag, Blocks.SH_PANE])
	bl.append([2, 8, -1, flag, Blocks.SH_PANE])
	for c: Vector2i in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 4), Vector2i(4, 4)]:
		bl.append([c.x, 11, c.y, Blocks.LANTERN, 0])
	_bed(bl, 3, 1, 1, 2)
	return h + 1


## Centro comercial 11x9: pavilhao coberto com bancas, toldos coloridos, mercadorias e lanternas.
func _market(bl: Array, loot: Array, p: Dictionary, r: RandomNumberGenerator) -> int:
	var w := 11
	var d := 9
	for x in w:
		for z in d:
			bl.append([x, 0, z, p["trim"] if (x + z) % 2 else p["found"], 0])
			bl.append([x, 5, z, p["roof"], Blocks.SH_SLAB])
	for x: int in [0, 5, 10]:
		for z: int in [0, 4, 8]:
			for y in range(1, 5):
				bl.append([x, y, z, p["pillar"], 0])
	for x in w:
		bl.append([x, 4, 0, p["pillar"], 0])
		bl.append([x, 4, d - 1, p["pillar"], 0])
	# Bancas: balcao, toldo de la e mercadorias diferentes.
	var goods := [[Blocks.CRATE, Blocks.HAY], [Blocks.BARREL, Blocks.PUMPKIN], [Blocks.CRATE, Blocks.BARREL], [Blocks.HAY, Blocks.CRATE]]
	var awn := [3, 4, 6, 8]
	var spots := [Vector2i(1, 2), Vector2i(6, 2), Vector2i(1, 6), Vector2i(6, 6)]
	for k in 4:
		var sp: Vector2i = spots[k]
		var wool: int = Blocks.WOOL_0 + int(awn[k])
		for x in range(sp.x, sp.x + 4):
			bl.append([x, 1, sp.y, Blocks.TABLE, 0])
			bl.append([x, 3, sp.y - 1 if sp.y < 4 else sp.y + 1, wool, Blocks.SH_SLAB_TOP])
		bl.append([sp.x, 2, sp.y, (goods[k] as Array)[0], 0])
		bl.append([sp.x + 3, 2, sp.y, (goods[k] as Array)[1], 0])
		bl.append([sp.x + 1, 2, sp.y, Blocks.LANTERN, 0])
	bl.append([5, 1, 4, p["chest"], 0])
	loot.append([5, 1, 4, 1])
	for c: Vector2i in [Vector2i(2, 4), Vector2i(8, 4)]:
		bl.append([c.x, 4, c.y, Blocks.LANTERN, 0])
	return 7


## Porta da vila: variante da paleta, centralizada na parede da frente; dupla com folha espelhada.
func _door(bl: Array, p: Dictionary, x: int, z: int, width: int) -> void:
	if not p.has("door_v"):
		bl.append([x, 1, z, Blocks.DOOR, 0])
		bl.append([x, 2, z, Blocks.DOOR, 0])
		return
	var base := Blocks.SH_CENTER | (int(p["door_v"]) << 8)
	for i in width:
		var sh := base | (Blocks.SH_MIRROR if width == 2 and i == 1 else 0)
		bl.append([x + i, 1, z, Blocks.DOORV, sh])
		bl.append([x + i, 2, z, Blocks.DOORV, sh])


func _window(bl: Array, p: Dictionary, x: int, y: int, z: int) -> void:
	if p.has("win_v"):
		bl.append([x, y, z, Blocks.WINDOWV, int(p["win_v"]) << 8])
	else:
		bl.append([x, y, z, p.get("window", Blocks.WINDOW_WOOD), 0])


## Tapete de micro-voxels (1/8 de altura) com barra de outra cor nas bordas externas.
func _rug(bl: Array, x0: int, z0: int, wc: int, dc: int, y: int, col: int, border: int) -> void:
	for cx in wc:
		for cz in dc:
			var g := Micro.empty()
			for vz in 8:
				for vx in 8:
					var edge := (cx == 0 and vx == 0) or (cx == wc - 1 and vx == 7) or (cz == 0 and vz == 0) or (cz == dc - 1 and vz == 7)
					var pat := (vx + vz + cx * 8 + cz * 8) % 6 == 0
					g[Micro.i3(vx, 0, vz)] = border if edge or pat else col
			bl.append([x0 + cx, y, z0 + cz, Blocks.MICRO, Blocks.SH_MICRO, g])


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
	# Porta (dupla na casa grande) e janelas com a madeira da vila.
	_door(bl, p, mid, 0, 2 if tall else 1)
	var win_rows := [2, 6] if tall else [2]
	for wy: int in win_rows:
		for wx: int in [1, w - 2]:
			if wx != mid and not (tall and wx == mid + 1):
				_window(bl, p, wx, wy, 0)
				_window(bl, p, wx, wy, d - 1)
		_window(bl, p, 0, wy, d / 2)
		_window(bl, p, w - 1, wy, d / 2)
	# Vigas de madeira no alto das paredes.
	for x in range(1, w - 1):
		for z: int in [0, d - 1]:
			bl.append([x, wall_h, z, p["pillar"], 0])
	# Lanternas sobre postes dos dois lados da porta.
	for sx: int in [mid - 1, mid + (2 if tall else 1)]:
		bl.append([sx, 1, -1, p["fence"], 0])
		bl.append([sx, 2, -1, Blocks.LANTERN, 0])
	# Tapete de 1/8 de altura no meio do comodo.
	_rug(bl, mid - 1, 3, 3, 2, 1, p["wool"], Blocks.WOOL_0)
	if tall:
		# Piso do segundo andar e escada.
		for x in range(1, w - 1):
			for z in range(1, d - 1):
				if not (x == 1 and z >= 3 and z <= 5):
					bl.append([x, 4, z, p["floor"], 0])
		bl.append([1, 1, 3, p["floor"], Blocks.SH_STAIRS])
		bl.append([1, 2, 4, p["floor"], Blocks.SH_STAIRS])
		bl.append([1, 3, 5, p["floor"], Blocks.SH_STAIRS])
		_bed(bl, w - 2, 5, d - 2, 0)
		_bed(bl, w - 3, 5, d - 2, 0)
		bl.append([w - 2, 5, 1, Blocks.BOOKSHELF, 0])
		bl.append([w - 3, 5, 1, Blocks.BOOKSHELF, 0])
		bl.append([mid, 5, d / 2, Blocks.LAMP, 0])
		bl.append([1, 5, 1, Blocks.LANTERN, 0])
	# Telhado de duas aguas, com oitoes.
	var top := wall_h + 1
	# Camadas ate a cumeeira: largura par fecha com duas cunhas encostadas; impar fecha com meia-laje.
	var layers := (d + 3) / 2
	for i in layers:
		var y := top + i
		for x in range(-1, w + 1):
			var zf := i - 1
			var zb := d - i
			if zf > zb:
				continue
			if zf == zb:
				bl.append([x, y, zf, p["roof"], Blocks.SH_SLAB])
			else:
				bl.append([x, y, zf, p["roof"], Blocks.SH_WEDGE])
				bl.append([x, y, zb, p["roof"], Blocks.SH_WEDGE | (2 << 4)])
				if x >= 0 and x < w:
					for z in range(zf + 1, zb):
						var gable := x == 0 or x == w - 1
						bl.append([x, y, z, p["wall"] if gable else 0, 0])
	# Mobilia.
	var choice := r.randi() % 3
	if tall:
		bl.append([w - 2, 1, d - 2, Blocks.FURNACE, 2 << 4])
	else:
		_bed(bl, 1, 1, d - 2, 0)
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
	_door(bl, p, 3, 0, 2)
	for sx: int in [1, 5]:
		bl.append([sx, 1, -2, p["trim"], 0])
		bl.append([sx, 2, -2, p["fence"], 0])
		bl.append([sx, 3, -2, Blocks.LANTERN, 0])
	for z: int in [3, 6]:
		bl.append([1, 1, z, Blocks.TORCH, 0])
		bl.append([5, 1, z, Blocks.TORCH, 0])
	_rug(bl, 2, 1, 3, 8, 1, Blocks.WOOL_0 + 3, Blocks.WOOL_0 + 4)
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
	var layers := (w + 3) / 2
	for i in layers:
		var y := top + i
		for z in range(-1, d + 1):
			var xf := i - 1
			var xb := w - i
			if xf > xb:
				continue
			if xf == xb:
				bl.append([xf, y, z, p["roof"], Blocks.SH_SLAB])
			else:
				bl.append([xf, y, z, p["roof"], Blocks.SH_WEDGE | (3 << 4)])
				bl.append([xb, y, z, p["roof"], Blocks.SH_WEDGE | (1 << 4)])
				if z >= 0 and z < d:
					for x in range(xf + 1, xb):
						var gable := z == 0 or z == d - 1
						bl.append([x, y, z, p["trim"] if gable else 0, 0])
	return top + layers + 1


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
		bl.append([3, 1, 1, Blocks.TORCH, 0])
	else:
		bl.append([2, 1, 3, Blocks.TORCH, 0])
	return hh + 2


# ---------------------------------------------------------------- carimbo no chunk

## Escreve no chunk (blocks/shapes) tudo o que estiver dentro dele. Devolve ticks, saques e NPCs.
func stamp(blocks: PackedByteArray, shapes: Dictionary, cx: int, cz: int) -> Dictionary:
	var ox := cx * 16
	var oz := cz * 16
	var res := {"ticks": [], "loot": [], "npcs": [], "top": 0, "lights": [], "micro_s": {}}
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
		for pc0: Vector3i in l["paths"]:
			# Caminho com 2 a 3 blocos de largura.
			for off: Vector3i in [Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
				var pc := pc0 + off
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
				res["npcs"].append([np[0], np[1], np[2], l["id"], np[3] if np.size() > 3 else {}, pal])
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
			# Gira so os bits de rotacao, preservando centralizacao, espelho e variante.
			sh = (sh & ~0x30) | ((((sh >> 4) & 3) + rot) % 4) << 4
		if id == Blocks.MICRO and e.size() > 5:
			res["micro_s"][idx] = Micro.rotate_y(e[5], rot)
		elif id != 0 and Blocks.EMIT[id] == 1:
			res["lights"].append(idx)
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
