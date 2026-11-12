class_name Items
extends RefCounted
## Itens que nao sao blocos: ferramentas, armas, armaduras, comida e materiais.
## Ids comecam em 256 (abaixo disso sao blocos). Cada item e desenhado em pixel-art 16x16
## pela VoxelArt e extrudado para virar o modelo 3D na mao.

const BASE := 256
const SLOT_NAMES: Array[String] = ["Capacete", "Peitoral", "Calças", "Botas"]

static var DEFS: Array[Dictionary] = []
static var CATS: Dictionary = {}
static var _icons: Dictionary = {}
static var _meshes: Dictionary = {}
static var _canvas: Dictionary = {}

static var WOOD_D := Color(0.36, 0.24, 0.12)
static var WOOD_L := Color(0.58, 0.40, 0.21)
## [nome, cor escura, cor clara, bonus de dano]
static var MATS: Array = [
	["madeira", Color(0.40, 0.27, 0.13), Color(0.62, 0.44, 0.24), 0.0, 1, 2.0, 60],
	["pedra", Color(0.36, 0.36, 0.38), Color(0.60, 0.60, 0.62), 1.0, 2, 4.0, 130],
	["cobre", Color(0.62, 0.32, 0.17), Color(0.90, 0.56, 0.34), 1.5, 3, 5.0, 200],
	["ferro", Color(0.58, 0.60, 0.64), Color(0.90, 0.91, 0.93), 2.5, 4, 6.0, 250],
	["ouro", Color(0.80, 0.56, 0.08), Color(1.0, 0.86, 0.32), 2.0, 2, 12.0, 40],
	["cristal", Color(0.14, 0.58, 0.74), Color(0.62, 0.96, 1.0), 4.0, 5, 8.0, 1500],
]
## [nome, cor escura, cor clara, pontos de armadura]
static var ARMOR_MATS: Array = [
	["couro", Color(0.36, 0.22, 0.11), Color(0.56, 0.36, 0.19), 1.0],
	["cobre", Color(0.62, 0.32, 0.17), Color(0.90, 0.56, 0.34), 1.5],
	["ferro", Color(0.58, 0.60, 0.64), Color(0.90, 0.91, 0.93), 2.0],
	["ouro", Color(0.80, 0.56, 0.08), Color(1.0, 0.86, 0.32), 1.5],
	["cristal", Color(0.14, 0.58, 0.74), Color(0.62, 0.96, 1.0), 3.0],
]


static func _add(d: Dictionary) -> int:
	DEFS.append(d)
	var cat: String = d["cat"]
	if not CATS.has(cat):
		CATS[cat] = []
	var id := BASE + DEFS.size() - 1
	CATS[cat].append(id)
	return id


static func _static_init() -> void:
	var tools := [["pick", "Picareta", 2.0, Blocks.TOOL_PICK], ["axe", "Machado", 3.0, Blocks.TOOL_AXE],
		["shovel", "Pá", 1.5, Blocks.TOOL_SHOVEL], ["hoe", "Enxada", 1.0, Blocks.TOOL_NONE]]
	for t: Array in tools:
		for m: Array in MATS:
			_add({"name": "%s de %s" % [t[1], m[0]], "cat": "Ferramentas", "kind": "tool", "draw": t[0], "c0": m[1], "c1": m[2],
				"dmg": t[2] + m[3] * 0.5, "cd": 0.4, "reach": 3.6, "tool": t[3], "mat": m[0], "tier": m[4], "speed": m[5], "dur": m[6]})
	# [desenho, nome, dano base, intervalo, alcance]
	var weapons := [["sword", "Espada", 4.0, 0.38, 3.6], ["dagger", "Adaga", 2.5, 0.2, 3.0], ["spear", "Lança", 3.5, 0.45, 4.8],
		["battleaxe", "Machado de guerra", 5.5, 0.6, 3.6], ["mace", "Maça", 4.5, 0.5, 3.4]]
	for w: Array in weapons:
		for m: Array in MATS:
			_add({"name": "%s de %s" % [w[1], m[0]], "cat": "Armas", "kind": "weapon", "draw": w[0], "c0": m[1], "c1": m[2],
				"dmg": w[2] + m[3], "cd": w[3], "reach": w[4], "tool": 0, "mat": m[0], "dur": m[6]})
	_add({"name": "Arco", "cat": "Armas", "kind": "bow", "draw": "bow", "c0": WOOD_D, "c1": WOOD_L, "dmg": 5.0, "cd": 0.9, "reach": 42.0, "tool": 0, "dur": 300})
	var factor := [1.0, 1.6, 1.3, 0.8]
	var shapes := ["helmet", "chest", "legs", "boots"]
	for s in 4:
		for m: Array in ARMOR_MATS:
			_add({"name": "%s de %s" % [SLOT_NAMES[s], m[0]], "cat": "Armaduras", "kind": "armor", "draw": shapes[s], "c0": m[1], "c1": m[2],
				"slot": s, "armor": m[3] * factor[s]})
	var misc := [
		["Maçã", "apple", Color(0.78, 0.10, 0.08), Color(0.95, 0.45, 0.35), 4.0],
		["Pão", "bread", Color(0.66, 0.42, 0.16), Color(0.86, 0.66, 0.34), 5.0],
		["Carne crua", "meat", Color(0.78, 0.28, 0.30), Color(0.95, 0.60, 0.58), 3.0],
		["Carne assada", "meat", Color(0.45, 0.24, 0.10), Color(0.70, 0.44, 0.22), 8.0],
		["Graveto", "stick", WOOD_D, WOOD_L, 0.0],
		["Carvão", "lump", Color(0.06, 0.06, 0.07), Color(0.22, 0.22, 0.25), 0.0],
		["Lingote de cobre", "ingot", MATS[2][1], MATS[2][2], 0.0],
		["Lingote de ferro", "ingot", MATS[3][1], MATS[3][2], 0.0],
		["Lingote de ouro", "ingot", MATS[4][1], MATS[4][2], 0.0],
		["Cristal", "gem", MATS[5][1], MATS[5][2], 0.0],
		["Rubi", "gem", Color(0.58, 0.04, 0.10), Color(1.0, 0.36, 0.44), 0.0],
		["Couro", "leather", ARMOR_MATS[0][1], ARMOR_MATS[0][2], 0.0],
		["Pena", "feather", Color(0.75, 0.75, 0.78), Color(0.97, 0.97, 0.98), 0.0],
		["Osso", "bone", Color(0.72, 0.70, 0.62), Color(0.94, 0.92, 0.86), 0.0],
		["Flecha", "arrow", Color(0.5, 0.5, 0.54), Color(0.9, 0.9, 0.92), 0.0],
	]
	misc.append_array([
		["Batata assada", "potato", Color(0.62, 0.42, 0.18), Color(0.86, 0.66, 0.34), 6.0],
		["Frutas silvestres", "berries", Color(0.55, 0.04, 0.18), Color(0.86, 0.20, 0.36), 2.0],
		["Cereja", "cherry", Color(0.62, 0.04, 0.10), Color(0.95, 0.25, 0.30), 2.0],
		["Coco", "coconut", Color(0.36, 0.24, 0.13), Color(0.56, 0.40, 0.24), 3.0],
		["Laranja", "orange", Color(0.90, 0.45, 0.05), Color(1.0, 0.70, 0.25), 4.0],
		["Torta de abóbora", "pie", Color(0.78, 0.46, 0.14), Color(0.94, 0.72, 0.38), 8.0],
		["Trigo", "wheat", Color(0.70, 0.56, 0.16), Color(0.96, 0.84, 0.40), 0.0],
		["Pederneira", "flint", Color(0.16, 0.16, 0.18), Color(0.40, 0.40, 0.44), 0.0],
		["Pó de brasa", "dust", Color(0.86, 0.36, 0.06), Color(1.0, 0.78, 0.30), 0.0],
		["Farinha de osso", "dust", Color(0.80, 0.78, 0.72), Color(0.98, 0.97, 0.94), 0.0],
	])
	for it: Array in misc:
		var d := {"name": it[0], "cat": "Diversos", "kind": "food" if it[4] > 0.0 else "misc", "draw": it[1], "c0": it[2], "c1": it[3], "heal": it[4]}
		_add(d)
	# Plantaveis (Cenoura e Batata tambem sao comida).
	_add({"name": "Sementes de trigo", "cat": "Agricultura", "kind": "seed", "draw": "seeds", "c0": Color(0.45, 0.40, 0.14), "c1": Color(0.72, 0.66, 0.30), "crop": Blocks.CROP_WHEAT})
	_add({"name": "Sementes de abóbora", "cat": "Agricultura", "kind": "seed", "draw": "seeds", "c0": Color(0.78, 0.72, 0.52), "c1": Color(0.96, 0.92, 0.74), "crop": Blocks.CROP_PUMPKIN})
	_add({"name": "Cenoura", "cat": "Agricultura", "kind": "food", "draw": "carrot", "c0": Color(0.86, 0.38, 0.06), "c1": Color(1.0, 0.62, 0.20), "heal": 3.0, "crop": Blocks.CROP_CARROT})
	_add({"name": "Batata", "cat": "Agricultura", "kind": "food", "draw": "potato", "c0": Color(0.58, 0.44, 0.24), "c1": Color(0.80, 0.66, 0.42), "heal": 1.0, "crop": Blocks.CROP_POTATO})
	_add({"name": "Balde", "cat": "Ferramentas", "kind": "bucket", "draw": "bucket", "c0": Color(0.50, 0.52, 0.56), "c1": Color(0.82, 0.84, 0.88), "fluid": 0})
	_add({"name": "Balde de água", "cat": "Ferramentas", "kind": "bucket", "draw": "bucket_w", "c0": Color(0.50, 0.52, 0.56), "c1": Color(0.82, 0.84, 0.88), "fluid": 1})
	_add({"name": "Balde de lava", "cat": "Ferramentas", "kind": "bucket", "draw": "bucket_l", "c0": Color(0.50, 0.52, 0.56), "c1": Color(0.82, 0.84, 0.88), "fluid": 2})
	_add({"name": "Isqueiro de pederneira", "cat": "Ferramentas", "kind": "igniter", "draw": "igniter", "c0": Color(0.30, 0.30, 0.34), "c1": Color(0.80, 0.82, 0.86), "dur": 64})
	for i in BOAT_WOODS.size():
		var bw: Array = BOAT_WOODS[i]
		_add({"name": "Barco de " + str(bw[0]), "cat": "Ferramentas", "kind": "boat", "draw": "boat", "c0": bw[1], "c1": bw[2], "wood": i})


## [nome, escura, clara, tabuas]
static var BOAT_WOODS: Array = [
	["carvalho", Color(0.50, 0.34, 0.18), Color(0.74, 0.55, 0.31), Blocks.PLANKS],
	["pinheiro", Color(0.40, 0.25, 0.13), Color(0.60, 0.42, 0.24), Blocks.PINE_PLANKS],
	["bétula", Color(0.72, 0.62, 0.42), Color(0.90, 0.82, 0.60), Blocks.BIRCH_PLANKS],
	["mogno", Color(0.38, 0.14, 0.09), Color(0.60, 0.26, 0.15), Blocks.MAHOG_PLANKS],
	["palmeira", Color(0.60, 0.46, 0.26), Color(0.80, 0.66, 0.42), Blocks.PALM_PLANKS],
	["cerejeira", Color(0.66, 0.40, 0.37), Color(0.88, 0.64, 0.60), Blocks.CHERRY_PLANKS],
]


## Quantos cabem numa pilha.
static func max_stack(id: int) -> int:
	if id <= 0:
		return 0
	if id >= BASE:
		var k: String = DEFS[id - BASE]["kind"]
		if k in ["tool", "weapon", "bow", "armor", "igniter", "boat", "bucket"]:
			return 1
		return 64
	return 64


static func durability(id: int) -> int:
	if id < BASE:
		return 0
	return int(DEFS[id - BASE].get("dur", 0))


static func is_item(id: int) -> bool:
	return id >= BASE


static func def(id: int) -> Dictionary:
	return DEFS[id - BASE]


static func name_of(id: int) -> String:
	return DEFS[id - BASE]["name"] if id >= BASE else Blocks.NAMES[id]


static func find(item_name: String) -> int:
	for i in DEFS.size():
		if DEFS[i]["name"] == item_name:
			return BASE + i
	return 0


static func canvas(id: int) -> VoxelArt.Canvas:
	if not _canvas.has(id):
		var d := def(id)
		_canvas[id] = _draw(d["draw"], d["c0"], d["c1"], d.get("mat", ""))
	return _canvas[id]


static func icon(id: int) -> Texture2D:
	if not _icons.has(id):
		_icons[id] = canvas(id).texture()
	return _icons[id]


static func mesh(id: int) -> ArrayMesh:
	if not _meshes.has(id):
		_meshes[id] = VoxelArt.extrude(canvas(id))
	return _meshes[id]


static func _handle(cv: VoxelArt.Canvas, x1: float = 10.0, y1: float = 5.0) -> void:
	cv.line(2, 13, x1, y1, WOOD_L, 1.4)


## Cor da guarda e da gema do pomo conforme o material.
static func _accent(mat: String) -> Array:
	match mat:
		"madeira": return [WOOD_D, WOOD_L]
		"pedra": return [Color(0.30, 0.30, 0.32), Color(0.55, 0.55, 0.58)]
		"cobre": return [Color(0.55, 0.40, 0.16), Color(0.30, 0.70, 0.60)]
		"ferro": return [Color(0.72, 0.56, 0.20), Color(0.85, 0.12, 0.16)]
		"ouro": return [Color(0.95, 0.80, 0.30), Color(0.20, 0.50, 0.95)]
		"cristal": return [Color(0.80, 0.82, 0.88), Color(0.70, 1.0, 1.0)]
	return [Color(0.3, 0.3, 0.34), Color(0.8, 0.2, 0.2)]


## Cabo de couro enrolado.
static func _grip(cv: VoxelArt.Canvas, x0: float, y0: float, x1: float, y1: float) -> void:
	cv.line(x0, y0, x1, y1, Color(0.30, 0.18, 0.10), 1.4)
	var n := int(Vector2(x1 - x0, y1 - y0).length())
	for k in range(0, n + 1, 2):
		var t := float(k) / maxf(1.0, n)
		cv.setp(int(lerpf(x0, x1, t)), int(lerpf(y0, y1, t)), Color(0.52, 0.34, 0.18))


static func _draw(shape: String, c0: Color, c1: Color, mat: String = "") -> VoxelArt.Canvas:
	var cv := VoxelArt.Canvas.new()
	var clear := VoxelArt.CLEAR
	var acc := _accent(mat)
	var shine := c1.lightened(0.45)
	match shape:
		"pick":
			_handle(cv)
			cv.bezier(Vector2(4.5, 1.5), Vector2(13.5, 1.5), Vector2(13.5, 10.5), c0, 2.3)
			cv.bezier(Vector2(5.0, 1.2), Vector2(13.0, 1.2), Vector2(13.2, 10.0), c1, 1.2)
			cv.setp(4, 1, shine)
			cv.setp(14, 10, shine)
			# Amarração de couro na junção.
			cv.rect(9, 4, 10, 5, Color(0.42, 0.26, 0.12))
			cv.setp(9, 4, Color(0.60, 0.40, 0.20))
		"axe":
			_handle(cv)
			for y in 16:
				for x in 16:
					var d := Vector2(x - 9.0, y - 4.5).length()
					if d < 3.9 and x + y < 14 and x + y > 7:
						cv.setp(x, y, shine if d > 3.2 else (c1 if d > 1.8 else c0))
			cv.rect(8, 6, 9, 7, Color(0.42, 0.26, 0.12))
		"shovel":
			_handle(cv, 9.0, 6.0)
			cv.disc(11.4, 4.6, 2.8, c0)
			cv.disc(11.6, 4.4, 2.1, c1)
			cv.disc(12.4, 3.6, 1.6, c1)
			cv.setp(13, 2, shine)
			cv.line(9.5, 6.5, 11.5, 4.5, c0, 0.5)
		"hoe":
			_handle(cv)
			cv.line(10, 5, 5.5, 2.5, c0, 2.0)
			cv.line(10, 4.6, 5.8, 2.2, c1, 1.0)
			cv.setp(5, 2, shine)
		"sword":
			# Lâmina com fio claro e sulco central, guarda e pomo com gema.
			cv.line(5, 10, 13.6, 1.4, c0, 2.4)
			cv.line(5.4, 10.0, 13.4, 1.6, c1, 1.4)
			cv.line(6.5, 8.5, 12.0, 3.0, c0.lerp(c1, 0.35), 0.5)
			cv.setp(14, 1, shine)
			cv.setp(13, 2, shine)
			cv.line(2.0, 8.0, 7.0, 13.0, acc[0], 1.6)
			cv.setp(2, 8, acc[0].lightened(0.3))
			cv.setp(7, 13, acc[0].lightened(0.3))
			cv.setp(4, 11, acc[1])
			_grip(cv, 2.6, 12.4, 4.0, 11.0)
			cv.disc(1.6, 13.6, 1.1, acc[0])
			cv.setp(1, 14, acc[1])
		"dagger":
			cv.line(6, 9, 11.5, 3.5, c0, 1.9)
			cv.line(6.3, 8.9, 11.3, 3.7, c1, 1.0)
			cv.setp(12, 3, shine)
			cv.line(4, 8, 7, 11, acc[0], 1.3)
			_grip(cv, 3.0, 12.0, 4.5, 10.5)
			cv.setp(2, 13, acc[1])
		"spear":
			cv.line(1, 14, 10, 5, WOOD_L, 1.2)
			cv.line(1, 14, 10, 5, WOOD_D, 0.4)
			cv.rect(9, 5, 10, 6, Color(0.42, 0.26, 0.12))
			cv.disc(11.5, 4.5, 1.8, c0)
			cv.disc(11.7, 4.3, 1.2, c1)
			cv.disc(13.0, 3.0, 1.2, c1)
			cv.disc(14.2, 1.8, 0.7, shine)
			# Fita colorida.
			cv.setp(8, 8, acc[1])
			cv.setp(7, 9, acc[1].darkened(0.3))
		"battleaxe":
			_handle(cv, 11.0, 4.0)
			for y in 16:
				for x in 16:
					var d := Vector2(x - 9.0, y - 5.5).length()
					if d < 4.4 and absi(x + y - 14) > 1 and x - y > 0:
						cv.setp(x, y, shine if d > 3.7 else (c1 if d > 2.0 else c0))
			cv.rect(8, 6, 9, 7, acc[0])
			cv.setp(11, 4, acc[1])
		"mace":
			_handle(cv, 9.0, 6.0)
			cv.disc(11.5, 4.5, 2.8, c0)
			cv.disc(11.0, 4.0, 1.8, c1)
			cv.setp(10, 3, shine)
			for p: Vector2i in [Vector2i(11, 0), Vector2i(15, 4), Vector2i(7, 4), Vector2i(11, 8), Vector2i(14, 1), Vector2i(8, 1), Vector2i(14, 7)]:
				cv.setp(p.x, p.y, shine)
			cv.rect(7, 7, 8, 8, acc[0])
		"bow":
			cv.bezier(Vector2(3, 2), Vector2(14, 2), Vector2(13, 13), c0, 1.7)
			cv.bezier(Vector2(3.3, 1.7), Vector2(13.6, 2.2), Vector2(12.7, 12.7), c1, 0.8)
			cv.line(3, 2, 13, 13, Color(0.88, 0.88, 0.82), 0.6)
			cv.rect(10, 4, 11, 5, Color(0.30, 0.18, 0.10))
			cv.setp(2, 2, Color(0.90, 0.90, 0.85))
			cv.setp(13, 14, Color(0.90, 0.90, 0.85))
		"helmet":
			cv.rect(3, 3, 12, 10, c1)
			cv.rect(4, 2, 11, 2, c1)
			cv.rect(3, 6, 12, 6, c0)
			cv.rect(5, 7, 10, 10, clear)
			cv.rect(7, 7, 8, 9, c0)
			cv.rect(7, 1, 8, 5, c0)
			cv.setp(4, 3, shine)
			for p: Vector2i in [Vector2i(4, 9), Vector2i(11, 9), Vector2i(4, 5), Vector2i(11, 5)]:
				cv.setp(p.x, p.y, c0.darkened(0.2))
		"chest":
			cv.rect(4, 4, 11, 13, c1)
			cv.rect(1, 2, 5, 5, c1)
			cv.rect(10, 2, 14, 5, c1)
			cv.rect(1, 5, 4, 5, c0)
			cv.rect(11, 5, 14, 5, c0)
			cv.rect(6, 2, 9, 3, clear)
			cv.rect(7, 5, 8, 10, c0)
			cv.rect(4, 11, 11, 11, Color(0.34, 0.22, 0.12))
			cv.rect(7, 11, 8, 11, acc[0])
			cv.setp(5, 5, shine)
			cv.setp(2, 3, shine)
		"legs":
			cv.rect(3, 2, 12, 5, c1)
			cv.rect(3, 6, 6, 14, c1)
			cv.rect(9, 6, 12, 14, c1)
			cv.rect(3, 2, 12, 2, Color(0.34, 0.22, 0.12))
			cv.rect(7, 2, 8, 2, acc[0])
			cv.rect(7, 3, 8, 5, c0)
			cv.rect(3, 9, 6, 10, c0)
			cv.rect(9, 9, 12, 10, c0)
			cv.setp(4, 9, shine)
			cv.setp(10, 9, shine)
		"boots":
			cv.rect(2, 4, 5, 12, c1)
			cv.rect(2, 10, 7, 12, c1)
			cv.rect(9, 4, 12, 12, c1)
			cv.rect(9, 10, 14, 12, c1)
			cv.rect(2, 4, 5, 5, c0)
			cv.rect(9, 4, 12, 5, c0)
			cv.rect(2, 12, 7, 12, c0.darkened(0.3))
			cv.rect(9, 12, 14, 12, c0.darkened(0.3))
			cv.setp(3, 7, shine)
			cv.setp(10, 7, shine)
		"apple":
			cv.disc(8, 9.5, 4.6, c0)
			cv.disc(6.5, 8.0, 1.3, c1)
			cv.line(8, 4, 9, 2, WOOD_D, 1.0)
			cv.rect(10, 3, 11, 3, Color(0.25, 0.55, 0.15))
		"bread":
			for y in 16:
				for x in 16:
					var e := Vector2((x - 7.5) / 6.2, (y - 8.5) / 3.6).length()
					if e < 1.0:
						cv.setp(x, y, c1 if e < 0.7 else c0)
			for k in 3:
				cv.line(4.0 + k * 3.0, 9.5, 5.5 + k * 3.0, 7.0, c0, 0.8)
		"meat":
			cv.disc(7, 8, 4.4, c0)
			cv.disc(6.5, 7.5, 2.3, c1)
			cv.line(10, 11, 13, 14, Color(0.93, 0.91, 0.85), 1.4)
			cv.disc(13.8, 14.2, 1.1, Color(0.93, 0.91, 0.85))
		"stick":
			cv.line(3, 13, 12, 4, WOOD_L, 1.4)
		"lump":
			cv.disc(8, 9, 3.8, c0)
			cv.disc(6.5, 7.5, 1.6, c1)
			cv.disc(10.2, 10.2, 1.2, c1)
		"ingot":
			cv.rect(3, 8, 12, 11, c0)
			cv.rect(4, 6, 13, 7, c1)
			cv.rect(13, 8, 13, 10, c0)
		"gem":
			for y in 16:
				for x in 16:
					if absf(x - 7.5) + absf(y - 8.0) < 5.6:
						cv.setp(x, y, c1 if x + y < 15 else c0)
		"leather":
			cv.rect(3, 4, 12, 12, c0)
			cv.rect(2, 5, 13, 6, c0)
			cv.rect(2, 10, 13, 11, c0)
			cv.rect(5, 6, 10, 10, c1)
		"feather":
			cv.line(4, 13, 12, 3, c1, 1.0)
			for k in 5:
				cv.disc(6.0 + k * 1.4, 10.6 - k * 1.7, 1.5, c1)
			cv.line(3, 14, 6, 11, c0, 0.8)
		"bone":
			cv.line(4.5, 11.5, 11.5, 4.5, c1, 1.5)
			for p: Vector2 in [Vector2(3.5, 11.5), Vector2(4.8, 12.8), Vector2(11.5, 3.2), Vector2(12.8, 4.5)]:
				cv.disc(p.x + 0.5, p.y + 0.5, 1.2, c1)
		"arrow":
			cv.line(3, 13, 12, 4, WOOD_L, 1.0)
			cv.disc(13.0, 3.0, 1.5, c1)
			cv.rect(2, 12, 3, 12, c1)
			cv.rect(3, 14, 4, 14, c1)
		"seeds":
			for p: Vector2i in [Vector2i(5, 6), Vector2i(9, 5), Vector2i(7, 9), Vector2i(11, 9), Vector2i(4, 11), Vector2i(9, 12)]:
				cv.disc(p.x + 0.5, p.y + 0.5, 1.2, c1)
				cv.setp(p.x, p.y + 1, c0)
		"wheat":
			for k in 3:
				var x := 5.0 + k * 3.0
				cv.line(x, 14, x + 1.0, 6, Color(0.55, 0.50, 0.18), 0.8)
				for j in 3:
					cv.disc(x + 1.0 + (j % 2) * 0.8, 6.0 - j * 1.6, 1.0, c1 if j % 2 == 0 else c0)
		"carrot":
			cv.line(5, 12, 10, 6, c0, 2.4)
			cv.line(6, 11, 10, 7, c1, 1.0)
			cv.line(10, 6, 13, 2, Color(0.2, 0.55, 0.15), 0.9)
			cv.line(10, 6, 14, 5, Color(0.2, 0.55, 0.15), 0.9)
		"potato":
			for y in 16:
				for x in 16:
					if Vector2((x - 7.5) / 5.2, (y - 8.5) / 4.0).length() < 1.0:
						cv.setp(x, y, c1)
			for p: Vector2i in [Vector2i(5, 8), Vector2i(9, 7), Vector2i(8, 10)]:
				cv.setp(p.x, p.y, c0)
		"berries":
			for p: Vector2 in [Vector2(6, 9), Vector2(10, 9), Vector2(8, 6), Vector2(8, 12)]:
				cv.disc(p.x, p.y, 2.2, c0)
				cv.setp(int(p.x) - 1, int(p.y) - 1, c1)
			cv.line(8, 3, 9, 1, Color(0.2, 0.5, 0.15), 1.0)
		"cherry":
			cv.disc(5.5, 11.5, 2.6, c0)
			cv.disc(10.5, 11.5, 2.6, c0)
			cv.bezier(Vector2(5, 9), Vector2(7, 2), Vector2(10, 9), Color(0.25, 0.45, 0.12), 0.8)
			cv.setp(4, 10, c1)
			cv.setp(9, 10, c1)
		"orange":
			cv.disc(8, 9, 4.8, c0)
			cv.disc(6.5, 7.5, 1.8, c1)
			for p: Vector2i in [Vector2i(10, 11), Vector2i(5, 11), Vector2i(11, 7)]:
				cv.setp(p.x, p.y, c0.darkened(0.15))
			cv.rect(8, 3, 8, 4, Color(0.3, 0.2, 0.1))
			cv.rect(9, 3, 10, 3, Color(0.2, 0.55, 0.15))
		"coconut":
			cv.disc(8, 8.5, 5.0, c0)
			cv.disc(6.5, 7, 1.6, c1)
			for p: Vector2i in [Vector2i(7, 6), Vector2i(9, 6), Vector2i(8, 8)]:
				cv.setp(p.x, p.y, Color(0.12, 0.08, 0.05))
		"pie":
			for y in 16:
				for x in 16:
					var e := Vector2((x - 7.5) / 6.5, (y - 9.0) / 4.0).length()
					if e < 1.0:
						cv.setp(x, y, c0 if e > 0.75 else c1)
			cv.line(4, 9, 11, 9, c0, 0.7)
		"flint":
			for y in 16:
				for x in 16:
					if absf(x - 8.0) * 0.8 + absf(y - 8.5) * 1.1 < 5.0:
						cv.setp(x, y, c1 if x < y else c0)
		"dust":
			cv.disc(8, 10, 4.2, c0)
			cv.disc(7, 9, 2.2, c1)
			for p: Vector2i in [Vector2i(3, 6), Vector2i(13, 7), Vector2i(11, 4)]:
				cv.setp(p.x, p.y, c1)
		"igniter":
			cv.rect(3, 7, 8, 12, c1)
			cv.rect(4, 8, 7, 11, c0)
			cv.disc(11.5, 6.5, 2.6, Color(0.18, 0.18, 0.2))
			cv.setp(12, 3, Color(1.0, 0.8, 0.3))
			cv.setp(14, 4, Color(1.0, 0.6, 0.2))
		"bucket", "bucket_w", "bucket_l":
			for y in range(5, 14):
				var w := 5.0 - (y - 5) * 0.28
				cv.line(8.0 - w, y, 8.0 + w, y, c1 if y > 5 else c0, 1.0)
			cv.bezier(Vector2(3, 5), Vector2(8, -1), Vector2(13, 5), c0, 0.8)
			if shape != "bucket":
				var lc := Color(0.20, 0.45, 0.90) if shape == "bucket_w" else Color(1.0, 0.45, 0.08)
				cv.line(4, 6, 12, 6, lc, 1.2)
		"boat":
			cv.rect(1, 8, 14, 10, c0)
			cv.rect(2, 11, 13, 11, c0)
			cv.rect(3, 12, 12, 12, c0)
			cv.rect(2, 7, 13, 7, c1)
			cv.line(7, 2, 7, 7, WOOD_D, 0.8)
			cv.rect(8, 3, 11, 6, Color(0.92, 0.9, 0.84))
	cv.finish()
	return cv
