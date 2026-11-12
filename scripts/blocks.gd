class_name Blocks
extends RefCounted
## Registro de blocos. Cada textura e uma "camada" descrita por um padrao procedural + cores,
## entao variacoes (madeiras, pedras, las, concretos...) custam uma linha cada.

const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const WATER := 5
const LOG := 6
const LEAVES := 7
const PLANKS := 8
const BRICKS := 9
const STONE_BRICKS := 10
const COBBLE := 11
const GLASS := 12
const SNOW_GRASS := 13
const GRAVEL := 14
const TALL_GRASS := 15
const FLOWER_RED := 16
const FLOWER_YELLOW := 17
const LANTERN := 18
const COAL_ORE := 19
const IRON_ORE := 20
const BEDROCK := 21
const ROOF_TILES := 22
const SANDSTONE := 23
const PINE_LEAVES := 24
const MARBLE := 25
const PINE_LOG := 26
const SNOW_BLOCK := 27
const GRANITE := 28
const BASALT := 29
const LIMESTONE := 30
const SLATE := 31
const OBSIDIAN := 32
const CLAY := 33
const MUD := 34
const ICE := 35
const RED_SAND := 36
const MOSSY_COBBLE := 37
const MOSS_BLOCK := 38
const COPPER_ORE := 39
const GOLD_ORE := 40
const CRYSTAL_ORE := 41
const RUBY_ORE := 42
const BIRCH_LOG := 43
const BIRCH_LEAVES := 44
const BIRCH_PLANKS := 45
const PINE_PLANKS := 46
const MAHOG_LOG := 47
const MAHOG_LEAVES := 48
const MAHOG_PLANKS := 49
const PALM_LOG := 50
const PALM_LEAVES := 51
const PALM_PLANKS := 52
const SANDSTONE_BRICKS := 53
const MARBLE_BRICKS := 54
const BASALT_BRICKS := 55
const MUD_BRICKS := 56
const GRANITE_POLISHED := 57
const LIMESTONE_BRICKS := 58
const ROOF_SLATE := 59
const ROOF_GREEN := 60
const IRON_BLOCK := 61
const GOLD_BLOCK := 62
const COPPER_BLOCK := 63
const CRYSTAL_BLOCK := 64
const RUBY_BLOCK := 65
const COAL_BLOCK := 66
const WOOL_0 := 67
const CONCRETE_0 := 79
const GLASS_TINT_0 := 91
const FERN := 95
const FLOWER_BLUE := 96
const FLOWER_WHITE := 97
const MUSHROOM_RED := 98
const MUSHROOM_BROWN := 99
const DEAD_BUSH := 100
const WHEAT := 101
const CACTUS := 102
const WORKBENCH := 103
const FURNACE := 104
const CHEST := 105
const BOOKSHELF := 106
const BARREL := 107
const CRATE := 108
const TORCH := 109
const LAMP := 110
const CHAIR := 111
const TABLE := 112
const BED := 113
const STOOL := 114
const BENCH := 115
const FENCE := 116
const SHELF := 117
const FLOWER_POT := 118
const TERRACOTTA := 119
const HAY := 120
const FARMLAND := 121
const CROP_WHEAT := 122
const CROP_CARROT := 126
const CROP_POTATO := 130
const CROP_PUMPKIN := 134
const PUMPKIN := 137
const BERRY_BUSH := 138
const BERRY_BUSH_EMPTY := 139
const CHERRY_LOG := 140
const CHERRY_LEAVES := 141
const CHERRY_PLANKS := 142
const SAPLING_0 := 143
const LAVA := 150
const SCORIA := 151
const ASH := 152
const EMBERSTONE := 153
const RED_FUNGUS := 154
const ASTRAL_STONE := 155
const MOON_MOSS := 156
const MOON_FLOWER := 157
const ETHER_LEAVES := 158
const ETHER_LOG := 159
const PORTAL_FIRE := 160
const PORTAL_ASTRAL := 161
const CHEST_PINE := 162
const CHEST_BIRCH := 163
const CHEST_MAHOG := 164
const CHEST_PALM := 165
const CHEST_CHERRY := 166
const CHEST_IRON := 167
const PATH := 168
const ANVIL := 169
const CAMPFIRE := 170
const DOOR := 171
const DOOR_OPEN := 172
## Agua corrente niveis 1..7 e lava corrente niveis 1..3 (a fonte e WATER / LAVA).
const WATER_FLOW := 173
const LAVA_FLOW := 180
const APPLE_LEAVES := 183
const ORANGE_LEAVES := 184
const TULIP := 185
const LAVENDER := 186
const SUNFLOWER := 187
const ROSE_BUSH := 188
const WINDOW_WOOD := 189
const WINDOW_IRON := 190
const STAINED_0 := 191
const DOOR_IRON := 195
const DOOR_IRON_OPEN := 196
const MICRO := 197
const COUNT := 198
## Estagios: trigo/cenoura/batata 0..3, abobora 0..2. Mudas: carvalho, pinheiro, betula, mogno, palmeira, cerejeira.
const CROP_STAGES := {CROP_WHEAT: 4, CROP_CARROT: 4, CROP_POTATO: 4, CROP_PUMPKIN: 3}

# Padroes do compute shader de texturas.
const P_GRASS := 0
const P_DIRT := 1
const P_STONE := 2
const P_SAND := 3
const P_SNOW := 4
const P_GRAVEL := 5
const P_MARBLE := 6
const P_FRINGE := 7
const P_BARK := 8
const P_LOG_TOP := 9
const P_PLANKS := 10
const P_BRICKS := 11
const P_COBBLE := 12
const P_GLASS := 13
const P_LEAVES := 14
const P_BLADES := 15
const P_FLOWER := 16
const P_MUSHROOM := 17
const P_LANTERN := 18
const P_ORE := 19
const P_ROOF := 20
const P_STRATA := 21
const P_WOOL := 22
const P_SMOOTH := 23
const P_METAL := 24
const P_GEM := 25
const P_BOOKS := 26
const P_FRAMED := 27
const P_FURNACE := 28
const P_CACTUS := 29
const P_FARMLAND := 30
const P_RIBBED := 31
const P_BUSH := 32
const P_SAPLING := 33
const P_PORTAL := 34
const P_STAINED := 35
const P_WINDOW := 36

const K_AIR := 0
const K_CUBE := 1
const K_LEAVES := 2
const K_PLANT := 3
const K_WATER := 4
const K_GLASS := 5
const K_MODEL := 6

const SH_CUBE := 0
const SH_SLAB := 1
const SH_SLAB_TOP := 2
const SH_STAIRS := 3
const SH_WEDGE := 4
const SH_PILLAR := 5
const SH_WALL := 6
const SH_PANE := 7
## Celula micro (8x8x8 voxels); a grade fica em World.Chunk.micro.
const SH_MICRO := 15
const PLAYER_SHAPES: Array[int] = [SH_CUBE, SH_SLAB, SH_STAIRS, SH_WEDGE, SH_PILLAR, SH_WALL, SH_PANE]
const SHAPE_NAMES := {0: "Cubo", 1: "Laje", 2: "Laje", 3: "Escada", 4: "Rampa", 5: "Pilar", 6: "Meia parede", 7: "Painel"}

const TOOL_NONE := 0
const TOOL_PICK := 1
const TOOL_AXE := 2
const TOOL_SHOVEL := 3

const COLOR_NAMES: Array[String] = ["branco", "cinza", "preto", "vermelho", "laranja", "amarelo", "verde", "ciano", "azul", "roxo", "rosa", "marrom"]
const COLOR_NAMES_F: Array[String] = ["branca", "cinza", "preta", "vermelha", "laranja", "amarela", "verde", "ciano", "azul", "roxa", "rosa", "marrom"]
static var DYES: Array[Color] = [Color(0.92, 0.92, 0.92), Color(0.5, 0.5, 0.52), Color(0.1, 0.1, 0.11), Color(0.72, 0.13, 0.12),
	Color(0.9, 0.48, 0.1), Color(0.95, 0.8, 0.2), Color(0.3, 0.55, 0.15), Color(0.1, 0.55, 0.6), Color(0.15, 0.25, 0.7),
	Color(0.5, 0.2, 0.7), Color(0.92, 0.5, 0.65), Color(0.42, 0.27, 0.15)]

static var KIND := PackedByteArray()
static var OPQ := PackedByteArray()
static var COVER := PackedByteArray()
static var SOLID := PackedByteArray()
static var EMIT := PackedByteArray()
static var TOOL := PackedByteArray()
## Mineracao: dureza (s) e nivel minimo de picareta para dropar algo (0 = qualquer).
static var HARD := PackedFloat32Array()
## 0 = nao e liquido, 1 = agua, 2 = lava.
static var FLUID := PackedByteArray()
static var REQ := PackedByteArray()
## Bloco que funciona como mesa de criacao, por estacao.
static var STATIONS := {"bancada": [WORKBENCH], "fornalha": [FURNACE], "bigorna": [ANVIL]}
static var CHESTS: Array[int] = [CHEST, CHEST_PINE, CHEST_BIRCH, CHEST_MAHOG, CHEST_PALM, CHEST_CHERRY, CHEST_IRON]
static var SAPLING_WOOD: Array[int] = []
static var FACE_LAYER := PackedByteArray()
static var NAMES: Array[String] = []
static var SHAPE_BOXES: Array = []
## Camadas de textura: {pat, c0, c1, c2, p, cells, nstr}.
static var LAYERS: Array[Dictionary] = []
static var NATURAL_LAYERS := 0
## Modelos (moveis etc.): MODELS[id * 4 + rotacao] = Array de [AABB, PackedInt32Array(6 camadas por face)].
static var MODELS: Dictionary = {}
## Abas do inventario: nome -> lista de ids.
static var CATS: Dictionary = {}
static var PLANT_BOX := AABB(Vector3(0.2, 0.0, 0.2), Vector3(0.6, 0.8, 0.6))
static var UNIT_BOX := AABB(Vector3.ZERO, Vector3.ONE)

static var L_GRASS_TOP := 0
static var L_DIRT := 0
static var L_STONE := 0
static var L_SAND := 0
static var L_SNOW := 0
static var L_LEAVES := 0
static var L_PINE_LEAVES := 0


static func L_STONE_FALLBACK() -> int:
	return FACE_LAYER[STONE * 6]


static func _L(pat: int, c0: Color, c1: Color = Color.BLACK, c2: Color = Color.BLACK, p: Vector4 = Vector4.ZERO, cells: int = 10, nstr: float = 3.5) -> int:
	LAYERS.append({"pat": pat, "c0": c0, "c1": c1, "c2": c2, "p": p, "cells": cells, "nstr": nstr})
	return LAYERS.size() - 1


static func _reg(id: int, name: String, cat: String, kind: int) -> void:
	NAMES[id] = name
	KIND[id] = kind
	OPQ[id] = 1 if kind == K_CUBE else 0
	COVER[id] = 2 if kind == K_CUBE else (1 if kind == K_LEAVES else 0)
	SOLID[id] = 1 if (kind == K_CUBE or kind == K_LEAVES or kind == K_GLASS or kind == K_MODEL) else 0
	if cat != "":
		if not CATS.has(cat):
			CATS[cat] = []
		CATS[cat].append(id)


static func _cube(id: int, name: String, cat: String, top: int, side: int = -1, bottom: int = -1, kind: int = K_CUBE) -> void:
	_reg(id, name, cat, kind)
	if side < 0:
		side = top
	if bottom < 0:
		bottom = top
	var b := id * 6
	FACE_LAYER[b] = side
	FACE_LAYER[b + 1] = side
	FACE_LAYER[b + 2] = top
	FACE_LAYER[b + 3] = bottom
	FACE_LAYER[b + 4] = side
	FACE_LAYER[b + 5] = side


static func _rot_box(b: AABB, r: int) -> AABB:
	for i in r:
		var mn := b.position
		var mx := b.end
		var nmin := Vector3(1.0 - mx.z, mn.y, mn.x)
		var nmax := Vector3(1.0 - mn.z, mx.y, mx.x)
		b = AABB(nmin, nmax - nmin)
	return b


## boxes: [[x0, y0, z0, x1, y1, z1 (em 1/16), camada ou [6 camadas]], ...]. Frente do modelo = -Z.
static func _model(id: int, name: String, cat: String, boxes: Array, emit: bool = false) -> void:
	_reg(id, name, cat, K_MODEL)
	EMIT[id] = 1 if emit else 0
	var first: Variant = boxes[0][6]
	var fl: int = first[0] if first is Array else first
	for f in 6:
		FACE_LAYER[id * 6 + f] = fl
	# Faces +X,-X,+Y,-Y,+Z,-Z; cada giro de 90 graus leva +Z -> -X -> -Z -> +X.
	var cyc := [4, 1, 5, 0]
	for r in 4:
		var out := []
		for bx: Array in boxes:
			var ab := AABB(Vector3(bx[0], bx[1], bx[2]) / 16.0, Vector3(bx[3] - bx[0], bx[4] - bx[1], bx[5] - bx[2]) / 16.0)
			var src := PackedInt32Array()
			if bx[6] is Array:
				src = PackedInt32Array(bx[6])
			else:
				src.resize(6)
				src.fill(bx[6])
			var dst := src.duplicate()
			for k in 4:
				dst[cyc[(k + r) % 4]] = src[cyc[k]]
			out.append([_rot_box(ab, r), dst])
		MODELS[id * 4 + r] = out


static func _static_init() -> void:
	KIND.resize(512)
	KIND.fill(0)
	OPQ.resize(512)
	OPQ.fill(0)
	COVER.resize(512)
	COVER.fill(0)
	SOLID.resize(512)
	SOLID.fill(0)
	EMIT.resize(512)
	EMIT.fill(0)
	TOOL.resize(512)
	TOOL.fill(0)
	FACE_LAYER.resize(256 * 6)
	FACE_LAYER.fill(0)
	NAMES.resize(COUNT)
	NAMES.fill("")
	NAMES[AIR] = "Ar"
	var N := "Natureza"
	var B := "Construção"
	var W := "Madeira"
	var C := "Cores"
	var D := "Decoração"
	var V4 := Vector4.ZERO
	for cat_name: String in [N, B, W, C, D]:
		CATS[cat_name] = []

	# ---------- camadas naturais (escala 0.5: uma textura cobre 2 blocos) ----------
	var grass_c0 := Color(0.12, 0.26, 0.07)
	var grass_c1 := Color(0.33, 0.50, 0.15)
	var grass_c2 := Color(0.44, 0.45, 0.17)
	var dirt_c0 := Color(0.24, 0.16, 0.10)
	var dirt_c1 := Color(0.43, 0.30, 0.19)
	var peb := Color(0.50, 0.47, 0.43)
	L_GRASS_TOP = _L(P_GRASS, grass_c0, grass_c1, grass_c2)
	L_DIRT = _L(P_DIRT, dirt_c0, dirt_c1, peb, Vector4(1, 0.95, 0, 0), 15)
	L_STONE = _L(P_STONE, Color(0.33, 0.33, 0.34), Color(0.57, 0.56, 0.54), Color.BLACK, Vector4(1, 0, 0.8, 0), 5)
	L_SAND = _L(P_SAND, Color(0.78, 0.69, 0.47), Color(0.91, 0.84, 0.63), Color.BLACK, V4, 10, 2.2)
	L_SNOW = _L(P_SNOW, Color(0.86, 0.90, 0.96), Color(0.98, 0.99, 1.0), Color.BLACK, V4, 10, 1.6)
	var l_gravel := _L(P_GRAVEL, Color(0.33, 0.32, 0.31), Color(0.64, 0.62, 0.58), Color.BLACK, V4, 22, 5.0)
	var l_bedrock := _L(P_STONE, Color(0.09, 0.09, 0.10), Color(0.26, 0.26, 0.29), Color.BLACK, Vector4(1, 0, 0.7, 0), 5, 5.0)
	var l_marble := _L(P_MARBLE, Color(0.93, 0.92, 0.90), Color(0.50, 0.51, 0.56), Color.BLACK, Vector4(0.16, 0, 0, 0), 10, 0.8)
	var l_granite := _L(P_STONE, Color(0.52, 0.36, 0.32), Color(0.72, 0.56, 0.50), Color(0.2, 0.17, 0.17), Vector4(0.3, 0.9, 0.7, 0), 5)
	var l_basalt := _L(P_STONE, Color(0.13, 0.13, 0.15), Color(0.28, 0.28, 0.31), Color.BLACK, Vector4(0.8, 0, 0.6, 0), 9)
	var l_limestone := _L(P_STONE, Color(0.66, 0.63, 0.54), Color(0.86, 0.83, 0.74), Color(0.55, 0.5, 0.42), Vector4(0.4, 0.3, 0.85, 0), 5)
	var l_slate := _L(P_STRATA, Color(0.22, 0.26, 0.32), Color(0.38, 0.43, 0.50), Color.BLACK, V4, 10)
	var l_obsidian := _L(P_STONE, Color(0.03, 0.02, 0.06), Color(0.14, 0.09, 0.2), Color.BLACK, Vector4(0, 0, 0.12, 0), 5, 1.5)
	var l_clay := _L(P_SMOOTH, Color(0.58, 0.62, 0.68), Color.BLACK, Color.BLACK, Vector4(0.75, 0.25, 0, 0))
	var l_mud := _L(P_DIRT, Color(0.13, 0.10, 0.08), Color(0.25, 0.19, 0.14), peb, Vector4(0, 0.4, 0, 0), 15)
	var l_ice := _L(P_SNOW, Color(0.55, 0.74, 0.92), Color(0.78, 0.90, 1.0), Color.BLACK, Vector4(0.08, 0, 0, 0), 10, 0.8)
	var l_red_sand := _L(P_SAND, Color(0.66, 0.34, 0.16), Color(0.82, 0.48, 0.24), Color.BLACK, V4, 10, 2.2)
	var l_moss := _L(P_GRASS, Color(0.14, 0.30, 0.10), Color(0.30, 0.46, 0.16), Color(0.25, 0.42, 0.12))
	NATURAL_LAYERS = LAYERS.size()

	# ---------- demais camadas ----------
	var l_grass_side := _L(P_FRINGE, grass_c0, grass_c1, grass_c2, V4, 15)
	var l_snow_side := _L(P_FRINGE, Color(0.86, 0.90, 0.96), Color(0.98, 0.99, 1.0), Color.BLACK, Vector4(1, 0, 0, 0), 15)
	# Madeiras: [casca escura, casca clara, madeira escura, madeira clara, folha escura, folha clara]
	var woods := [
		[Color(0.17, 0.12, 0.08), Color(0.43, 0.32, 0.21), Color(0.50, 0.34, 0.18), Color(0.74, 0.55, 0.31), Color(0.08, 0.24, 0.05), Color(0.27, 0.48, 0.12)],
		[Color(0.15, 0.08, 0.06), Color(0.40, 0.24, 0.16), Color(0.40, 0.25, 0.13), Color(0.60, 0.42, 0.24), Color(0.04, 0.16, 0.08), Color(0.13, 0.33, 0.17)],
		[Color(0.75, 0.74, 0.70), Color(0.93, 0.92, 0.88), Color(0.72, 0.62, 0.42), Color(0.90, 0.82, 0.60), Color(0.20, 0.38, 0.08), Color(0.48, 0.62, 0.18)],
		[Color(0.20, 0.09, 0.06), Color(0.42, 0.20, 0.13), Color(0.38, 0.14, 0.09), Color(0.60, 0.26, 0.15), Color(0.05, 0.20, 0.06), Color(0.16, 0.40, 0.14)],
		[Color(0.36, 0.28, 0.18), Color(0.58, 0.48, 0.33), Color(0.60, 0.46, 0.26), Color(0.80, 0.66, 0.42), Color(0.16, 0.36, 0.06), Color(0.42, 0.60, 0.14)],
	]
	var wood_names := ["carvalho", "pinheiro", "bétula", "mogno", "palmeira"]
	var log_ids := [LOG, PINE_LOG, BIRCH_LOG, MAHOG_LOG, PALM_LOG]
	var leaf_ids := [LEAVES, PINE_LEAVES, BIRCH_LEAVES, MAHOG_LEAVES, PALM_LEAVES]
	var plank_ids := [PLANKS, PINE_PLANKS, BIRCH_PLANKS, MAHOG_PLANKS, PALM_PLANKS]
	var l_planks: Array[int] = []
	var l_bark: Array[int] = []
	for i in 5:
		var wd: Array = woods[i]
		var bark := _L(P_BARK, wd[0], wd[1], Color(0.1, 0.1, 0.1), Vector4(1.0 if i == 2 else 0.0, 0, 0, 0), 10, 5.0)
		var top := _L(P_LOG_TOP, wd[2], wd[3], wd[0].lerp(wd[1], 0.4))
		var pl := _L(P_PLANKS, wd[2], wd[3])
		var lf := _L(P_LEAVES, wd[4], wd[5], Color(0.8, 0.15, 0.1), Vector4(0.38 if i == 1 else 0.36, 0, 1 if i == 1 else 0, 0), 12 if i == 1 else 7)
		l_bark.append(bark)
		l_planks.append(pl)
		_cube(log_ids[i], "Tronco de " + wood_names[i], W, top, bark, top)
		_cube(plank_ids[i], "Tábuas de " + wood_names[i], W, pl)
		_cube(leaf_ids[i], "Folhas de " + wood_names[i], W, lf, lf, lf, K_LEAVES)
		TOOL[log_ids[i]] = TOOL_AXE
		TOOL[plank_ids[i]] = TOOL_AXE
		if i == 0:
			L_LEAVES = lf
		elif i == 1:
			L_PINE_LEAVES = lf

	# ---------- natureza ----------
	_cube(GRASS, "Grama", N, L_GRASS_TOP, l_grass_side, L_DIRT)
	_cube(DIRT, "Terra", N, L_DIRT)
	_cube(STONE, "Pedra", N, L_STONE)
	_cube(SAND, "Areia", N, L_SAND)
	_reg(WATER, "Água", "", K_WATER)
	_cube(SNOW_GRASS, "Grama nevada", N, L_SNOW, l_snow_side, L_DIRT)
	_cube(SNOW_BLOCK, "Neve", N, L_SNOW)
	_cube(GRAVEL, "Cascalho", N, l_gravel)
	_cube(BEDROCK, "Rocha-mãe", "", l_bedrock)
	_cube(GRANITE, "Granito", N, l_granite)
	_cube(BASALT, "Basalto", N, l_basalt)
	_cube(LIMESTONE, "Calcário", N, l_limestone)
	_cube(SLATE, "Ardósia", N, l_slate)
	_cube(MARBLE, "Mármore", N, l_marble)
	_cube(OBSIDIAN, "Vidro vulcânico", N, l_obsidian)
	_cube(CLAY, "Argila", N, l_clay)
	_cube(MUD, "Lama", N, l_mud)
	_cube(ICE, "Gelo", N, l_ice)
	_cube(RED_SAND, "Areia vermelha", N, l_red_sand)
	_cube(MOSS_BLOCK, "Musgo", N, l_moss)
	_cube(SANDSTONE, "Arenito", N, _L(P_STRATA, Color(0.72, 0.62, 0.41), Color(0.89, 0.80, 0.57), Color.BLACK, Vector4(1, 0, 0, 0)))
	var ores := [
		[COAL_ORE, "Minério de carvão", Color(0.05, 0.05, 0.06), Color(0.16, 0.16, 0.18), 0.0, 0.0],
		[IRON_ORE, "Minério de ferro", Color(0.62, 0.40, 0.27), Color(0.84, 0.62, 0.45), 0.55, 0.0],
		[COPPER_ORE, "Minério de cobre", Color(0.70, 0.36, 0.18), Color(0.30, 0.70, 0.52), 0.5, 0.0],
		[GOLD_ORE, "Minério de ouro", Color(0.85, 0.62, 0.10), Color(1.0, 0.88, 0.35), 0.9, 0.0],
		[CRYSTAL_ORE, "Minério de cristal", Color(0.20, 0.70, 0.85), Color(0.70, 0.98, 1.0), 0.0, 0.35],
		[RUBY_ORE, "Minério de rubi", Color(0.62, 0.05, 0.12), Color(1.0, 0.30, 0.38), 0.0, 0.25],
	]
	for o: Array in ores:
		_cube(o[0], o[1], N, _L(P_ORE, o[2], o[3], Color.BLACK, Vector4(o[4], o[5], 0, 0), 10))
	_cube(CACTUS, "Cacto", N, _L(P_CACTUS, Color(0.20, 0.42, 0.14), Color(0.36, 0.60, 0.22), Color.BLACK, Vector4(1, 0, 0, 0)),
		_L(P_CACTUS, Color(0.14, 0.34, 0.10), Color(0.34, 0.58, 0.20)))
	_cube(HAY, "Fardo de feno", N, _L(P_BLADES, Color(0.62, 0.48, 0.12), Color(0.92, 0.78, 0.28), Color.BLACK, Vector4(40, 3.0, 2, 0)))
	var plants := [
		[TALL_GRASS, "Capim", _L(P_BLADES, Color(0.10, 0.24, 0.06), Color(0.42, 0.60, 0.20), Color.BLACK, Vector4(11, 1, 0, 0))],
		[FERN, "Samambaia", _L(P_BLADES, Color(0.06, 0.22, 0.08), Color(0.24, 0.50, 0.18), Color.BLACK, Vector4(7, 2.2, 0, 0))],
		[DEAD_BUSH, "Arbusto seco", _L(P_BLADES, Color(0.30, 0.20, 0.10), Color(0.56, 0.42, 0.24), Color.BLACK, Vector4(6, 0.6, 0, 0))],
		[WHEAT, "Trigo", _L(P_BLADES, Color(0.50, 0.42, 0.10), Color(0.86, 0.74, 0.26), Color(0.96, 0.86, 0.40), Vector4(9, 0.9, 1, 0))],
		[FLOWER_RED, "Papoula", _L(P_FLOWER, Color(0.86, 0.10, 0.08), Color(0.12, 0.09, 0.06), Color.BLACK, Vector4(5, 0, 0, 0))],
		[FLOWER_YELLOW, "Margarida amarela", _L(P_FLOWER, Color(0.98, 0.82, 0.12), Color(0.60, 0.36, 0.06), Color.BLACK, Vector4(5, 0, 0, 0))],
		[FLOWER_BLUE, "Centáurea azul", _L(P_FLOWER, Color(0.22, 0.38, 0.92), Color(0.95, 0.9, 0.5), Color.BLACK, Vector4(7, 0, 0, 0))],
		[FLOWER_WHITE, "Lírio branco", _L(P_FLOWER, Color(0.96, 0.96, 0.92), Color(0.95, 0.75, 0.15), Color.BLACK, Vector4(4, 0, 0, 0))],
		[MUSHROOM_RED, "Cogumelo vermelho", _L(P_MUSHROOM, Color(0.80, 0.10, 0.08), Color(0.90, 0.86, 0.76), Color(0.98, 0.96, 0.9))],
		[MUSHROOM_BROWN, "Cogumelo marrom", _L(P_MUSHROOM, Color(0.52, 0.34, 0.20), Color(0.88, 0.82, 0.70), Color(0.6, 0.42, 0.26))],
	]
	for pl: Array in plants:
		_cube(pl[0], pl[1], N, pl[2], pl[2], pl[2], K_PLANT)
	for id: int in [DIRT, GRASS, SAND, RED_SAND, GRAVEL, SNOW_GRASS, SNOW_BLOCK, CLAY, MUD, MOSS_BLOCK]:
		TOOL[id] = TOOL_SHOVEL
	for id: int in [STONE, GRANITE, BASALT, LIMESTONE, SLATE, MARBLE, OBSIDIAN, ICE, SANDSTONE, COAL_ORE, IRON_ORE, COPPER_ORE, GOLD_ORE, CRYSTAL_ORE, RUBY_ORE]:
		TOOL[id] = TOOL_PICK

	# ---------- construcao ----------
	var mortar := Color(0.60, 0.58, 0.54)
	var br := Vector4(4, 2, 0.6, 0)
	var big := Vector4(2, 2, 0.2, 0)
	_cube(BRICKS, "Tijolos", B, _L(P_BRICKS, Color(0.47, 0.17, 0.11), Color(0.72, 0.33, 0.21), mortar, br, 10, 4.5))
	_cube(STONE_BRICKS, "Tijolos de pedra", B, _L(P_BRICKS, Color(0.34, 0.34, 0.35), Color(0.56, 0.55, 0.54), Color(0.2, 0.2, 0.2), big, 10, 4.5))
	_cube(SANDSTONE_BRICKS, "Tijolos de arenito", B, _L(P_BRICKS, Color(0.72, 0.62, 0.41), Color(0.89, 0.80, 0.57), Color(0.55, 0.47, 0.3), big, 10, 4.0))
	_cube(MARBLE_BRICKS, "Tijolos de mármore", B, _L(P_BRICKS, Color(0.84, 0.83, 0.81), Color(0.95, 0.94, 0.92), Color(0.6, 0.6, 0.62), big, 10, 2.5))
	_cube(BASALT_BRICKS, "Tijolos de basalto", B, _L(P_BRICKS, Color(0.14, 0.14, 0.16), Color(0.28, 0.28, 0.31), Color(0.06, 0.06, 0.07), big, 10, 4.5))
	_cube(MUD_BRICKS, "Tijolos de barro", B, _L(P_BRICKS, Color(0.40, 0.30, 0.20), Color(0.58, 0.46, 0.32), Color(0.30, 0.22, 0.15), Vector4(4, 2, 0.3, 0), 10, 4.0))
	_cube(LIMESTONE_BRICKS, "Tijolos de calcário", B, _L(P_BRICKS, Color(0.68, 0.65, 0.56), Color(0.86, 0.83, 0.74), Color(0.5, 0.47, 0.4), Vector4(4, 2, 0.2, 0), 10, 4.0))
	_cube(GRANITE_POLISHED, "Granito polido", B, _L(P_STONE, Color(0.56, 0.38, 0.34), Color(0.74, 0.58, 0.52), Color(0.2, 0.17, 0.17), Vector4(0, 0.9, 0.18, 0), 5, 0.6))
	_cube(COBBLE, "Pedregulho", B, _L(P_COBBLE, Color(0.31, 0.31, 0.32), Color(0.62, 0.60, 0.56), Color(0.20, 0.19, 0.18), V4, 7, 5.0))
	_cube(MOSSY_COBBLE, "Pedregulho com musgo", B, _L(P_COBBLE, Color(0.31, 0.31, 0.32), Color(0.62, 0.60, 0.56), Color(0.20, 0.19, 0.18), Vector4(1, 0, 0, 0), 7, 5.0))
	_cube(ROOF_TILES, "Telhas de barro", B, _L(P_ROOF, Color(0.52, 0.20, 0.12), Color(0.76, 0.36, 0.22), Color.BLACK, V4, 10, 4.5))
	_cube(ROOF_SLATE, "Telhas de ardósia", B, _L(P_ROOF, Color(0.20, 0.25, 0.33), Color(0.36, 0.43, 0.52), Color.BLACK, V4, 10, 4.5))
	_cube(ROOF_GREEN, "Telhas esmaltadas", B, _L(P_ROOF, Color(0.10, 0.34, 0.26), Color(0.22, 0.56, 0.42), Color.BLACK, V4, 10, 4.5))
	_cube(TERRACOTTA, "Terracota", B, _L(P_SMOOTH, Color(0.62, 0.36, 0.24), Color.BLACK, Color.BLACK, Vector4(0.8, 0.3, 0, 0)))
	_cube(GLASS, "Vidro", B, _L(P_GLASS, Color(0.68, 0.88, 0.94)), -1, -1, K_GLASS)
	var l_iron := _L(P_METAL, Color(0.62, 0.64, 0.67), Color(0.86, 0.87, 0.89), Color.BLACK, Vector4(0.35, 0, 0, 0))
	_cube(IRON_BLOCK, "Bloco de ferro", B, l_iron)
	_cube(GOLD_BLOCK, "Bloco de ouro", B, _L(P_METAL, Color(0.86, 0.62, 0.10), Color(1.0, 0.86, 0.32), Color.BLACK, Vector4(0.25, 0, 0, 0)))
	_cube(COPPER_BLOCK, "Bloco de cobre", B, _L(P_METAL, Color(0.68, 0.36, 0.20), Color(0.90, 0.56, 0.36), Color.BLACK, Vector4(0.4, 0, 0, 0)))
	_cube(CRYSTAL_BLOCK, "Bloco de cristal", B, _L(P_GEM, Color(0.18, 0.62, 0.80), Color(0.72, 0.98, 1.0), Color.BLACK, Vector4(0.3, 0, 0, 0), 5))
	_cube(RUBY_BLOCK, "Bloco de rubi", B, _L(P_GEM, Color(0.55, 0.04, 0.10), Color(1.0, 0.32, 0.40), Color.BLACK, Vector4(0.2, 0, 0, 0), 5))
	_cube(COAL_BLOCK, "Bloco de carvão", B, _L(P_GEM, Color(0.04, 0.04, 0.05), Color(0.17, 0.17, 0.19), Color.BLACK, V4, 7))
	for id: int in [BRICKS, STONE_BRICKS, SANDSTONE_BRICKS, MARBLE_BRICKS, BASALT_BRICKS, MUD_BRICKS, LIMESTONE_BRICKS, GRANITE_POLISHED,
			COBBLE, MOSSY_COBBLE, ROOF_TILES, ROOF_SLATE, ROOF_GREEN, TERRACOTTA, IRON_BLOCK, GOLD_BLOCK, COPPER_BLOCK, CRYSTAL_BLOCK, RUBY_BLOCK, COAL_BLOCK]:
		TOOL[id] = TOOL_PICK

	# ---------- cores ----------
	var l_wool: Array[int] = []
	for i in 12:
		var lw := _L(P_WOOL, DYES[i])
		l_wool.append(lw)
		_cube(WOOL_0 + i, "Lã " + COLOR_NAMES_F[i], C, lw)
	for i in 12:
		_cube(CONCRETE_0 + i, "Concreto " + COLOR_NAMES[i], C, _L(P_SMOOTH, DYES[i].lerp(Color(0.5, 0.5, 0.5), 0.12), Color.BLACK, Color.BLACK, Vector4(0.7, 0.12, 0, 0)))
		TOOL[CONCRETE_0 + i] = TOOL_PICK
	var tints := [[3, "vermelho"], [8, "azul"], [6, "verde"], [5, "amarelo"]]
	for i in 4:
		var t: Array = tints[i]
		_cube(GLASS_TINT_0 + i, "Vidro " + t[1], C, _L(P_GLASS, DYES[t[0]], Color.BLACK, Color.BLACK, Vector4(1, 0, 0, 0)), -1, -1, K_GLASS)

	# ---------- decoracao e moveis ----------
	var oak := l_planks[0]
	var dark := l_planks[3]
	var frame := Color(0.26, 0.17, 0.09)
	var wc0: Color = woods[0][2]
	var wc1: Color = woods[0][3]
	var l_wb_top := _L(P_FRAMED, wc0, wc1, frame, Vector4(4, 0, 0, 0))
	var l_wb_side := _L(P_FRAMED, wc0, wc1, frame, Vector4(5, 0, 0, 0))
	_cube(WORKBENCH, "Bancada de trabalho", D, l_wb_top, l_wb_side, oak)
	var l_chest_front := _L(P_FRAMED, wc0, wc1, frame, Vector4(2, 0, 0, 0))
	var l_chest_side := _L(P_FRAMED, wc0, wc1, frame, Vector4(0, 0, 0, 0))
	var l_fur_front := _L(P_FURNACE, Color(0.31, 0.31, 0.32), Color(0.62, 0.60, 0.56), Color(0.20, 0.19, 0.18), Vector4(1, 1, 0, 0), 7, 5.0)
	var l_fur_side := _L(P_FURNACE, Color(0.31, 0.31, 0.32), Color(0.62, 0.60, 0.56), Color(0.20, 0.19, 0.18), V4, 7, 5.0)
	_model(CHEST, "Baú", D, [[1, 0, 1, 15, 14, 15, [l_chest_side, l_chest_side, l_chest_side, l_chest_side, l_chest_side, l_chest_front]]])
	_model(FURNACE, "Fornalha", D, [[0, 0, 0, 16, 16, 16, [l_fur_side, l_fur_side, l_fur_side, l_fur_side, l_fur_side, l_fur_front]]], true)
	_cube(BOOKSHELF, "Estante de livros", D, oak, _L(P_BOOKS, wc0, wc1, frame), oak)
	_cube(BARREL, "Barril", D, _L(P_FRAMED, wc0, wc1, frame, Vector4(0, 0, 0, 0)), _L(P_FRAMED, wc0, wc1, Color(0.4, 0.4, 0.42), Vector4(3, 0, 0, 0)))
	_cube(CRATE, "Caixote", D, _L(P_FRAMED, woods[1][2], woods[1][3], frame, Vector4(1, 0, 0, 0)))
	for id: int in [WORKBENCH, BOOKSHELF, BARREL, CRATE]:
		TOOL[id] = TOOL_AXE
	var l_lantern := _L(P_LANTERN, Color(0.13, 0.11, 0.09), Color(1.0, 0.78, 0.40))
	var l_flame := _L(P_LANTERN, Color(1.0, 0.55, 0.12), Color(1.0, 0.9, 0.5), Color.BLACK, Vector4(1, 0, 0, 0))
	var l_shade := _L(P_LANTERN, Color(0.95, 0.86, 0.66), Color(1.0, 0.92, 0.72), Color.BLACK, Vector4(2, 0, 0, 0))
	var l_terra := FACE_LAYER[TERRACOTTA * 6]
	var white := l_wool[0]
	var red := l_wool[3]
	_model(LANTERN, "Lanterna", D, [[5, 0, 5, 11, 9, 11, l_lantern], [6, 9, 6, 10, 10, 10, l_iron]], true)
	_model(TORCH, "Tocha", D, [[7, 0, 7, 9, 10, 9, dark], [6, 10, 6, 10, 14, 10, l_flame]], true)
	_model(LAMP, "Abajur de chão", D, [[5, 0, 5, 11, 1, 11, l_iron], [7, 1, 7, 9, 11, 9, l_iron], [4, 10, 4, 12, 16, 12, l_shade]], true)
	_model(CHAIR, "Cadeira", D, [[3, 6, 3, 13, 8, 13, oak], [3, 0, 3, 5, 6, 5, dark], [11, 0, 3, 13, 6, 5, dark], [3, 0, 11, 5, 6, 13, dark],
		[11, 0, 11, 13, 6, 13, dark], [3, 8, 11, 13, 16, 13, oak]])
	_model(STOOL, "Banqueta", D, [[4, 7, 4, 12, 9, 12, oak], [4, 0, 4, 6, 7, 6, dark], [10, 0, 4, 12, 7, 6, dark], [4, 0, 10, 6, 7, 12, dark], [10, 0, 10, 12, 7, 12, dark]])
	_model(TABLE, "Mesa", D, [[0, 13, 0, 16, 16, 16, oak], [1, 0, 1, 3, 13, 3, dark], [13, 0, 1, 15, 13, 3, dark], [1, 0, 13, 3, 13, 15, dark], [13, 0, 13, 15, 13, 15, dark]])
	_model(BENCH, "Banco", D, [[0, 6, 3, 16, 8, 13, oak], [0, 0, 4, 2, 6, 12, dark], [14, 0, 4, 16, 6, 12, dark], [0, 8, 11, 16, 14, 13, oak]])
	_model(BED, "Cama", D, [[0, 0, 0, 16, 5, 16, dark], [0, 5, 0, 16, 8, 16, white], [2, 8, 10, 14, 10, 15, white], [0, 8, 0, 16, 9, 9, red], [0, 5, 15, 16, 13, 16, oak]])
	_model(FENCE, "Cerca", D, [[6, 0, 6, 10, 16, 10, oak], [0, 11, 7, 16, 14, 9, oak], [0, 5, 7, 16, 8, 9, oak]])
	_model(SHELF, "Prateleira", D, [[0, 8, 8, 16, 10, 16, oak], [1, 3, 14, 3, 8, 16, dark], [13, 3, 14, 15, 8, 16, dark]])
	_model(FLOWER_POT, "Vaso de flor", D, [[5, 0, 5, 11, 6, 11, l_terra], [7, 6, 7, 9, 11, 9, L_LEAVES], [6, 10, 6, 10, 14, 10, red]])

	# ---------- cerejeira ----------
	var ch_bark := _L(P_BARK, Color(0.25, 0.12, 0.10), Color(0.45, 0.25, 0.22), Color(0.1, 0.1, 0.1), V4, 10, 5.0)
	var ch_top := _L(P_LOG_TOP, Color(0.62, 0.36, 0.32), Color(0.85, 0.58, 0.52), Color(0.32, 0.16, 0.13))
	var ch_pl := _L(P_PLANKS, Color(0.66, 0.40, 0.37), Color(0.88, 0.64, 0.60))
	var ch_lf := _L(P_LEAVES, Color(0.80, 0.40, 0.56), Color(0.98, 0.74, 0.84), Color.BLACK, Vector4(0.36, 0, 2, 0), 8)
	_cube(CHERRY_LOG, "Tronco de cerejeira", W, ch_top, ch_bark, ch_top)
	_cube(CHERRY_PLANKS, "Tábuas de cerejeira", W, ch_pl)
	_cube(CHERRY_LEAVES, "Folhas de cerejeira", W, ch_lf, ch_lf, ch_lf, K_LEAVES)
	TOOL[CHERRY_LOG] = TOOL_AXE
	TOOL[CHERRY_PLANKS] = TOOL_AXE
	l_planks.append(ch_pl)

	# ---------- agricultura ----------
	var l_farm := _L(P_FARMLAND, Color(0.15, 0.10, 0.06), Color(0.30, 0.21, 0.13), Color(0.4, 0.3, 0.2), V4, 15)
	_cube(FARMLAND, "Terra arada", N, l_farm, L_DIRT, L_DIRT)
	TOOL[FARMLAND] = TOOL_SHOVEL
	var green := Color(0.16, 0.42, 0.10)
	var crop_defs := [
		[CROP_WHEAT, "Trigo", 4, Color(0.50, 0.42, 0.10), Color(0.86, 0.74, 0.26), Color(0.96, 0.86, 0.40), 1.0],
		[CROP_CARROT, "Cenoura", 4, Color(0.10, 0.30, 0.06), Color(0.30, 0.58, 0.16), Color(0.95, 0.50, 0.10), 3.0],
		[CROP_POTATO, "Batata", 4, Color(0.10, 0.30, 0.08), Color(0.32, 0.56, 0.18), Color(0.78, 0.62, 0.36), 3.0],
		[CROP_PUMPKIN, "Abóbora", 3, Color(0.10, 0.32, 0.06), Color(0.30, 0.58, 0.14), Color(0.98, 0.82, 0.20), 1.0],
	]
	for cd: Array in crop_defs:
		var n: int = cd[2]
		for st in n:
			var t := float(st + 1) / n
			var c0: Color = green.lerp(cd[3], t * t) if cd[0] == CROP_WHEAT else cd[3]
			var c1: Color = green.lerp(cd[4], t) if cd[0] == CROP_WHEAT else cd[4]
			var mode: float = cd[6] if st == n - 1 else 0.0
			var lay := _L(P_BLADES, c0, c1, cd[5], Vector4(5 + st * 2, 0.7 + st * 0.2, mode, 0.35 + 0.65 * t))
			_cube(cd[0] + st, "%s (estágio %d)" % [cd[1], st + 1], "", lay, lay, lay, K_PLANT)
	var l_pump_side := _L(P_RIBBED, Color(0.80, 0.40, 0.06), Color(0.98, 0.62, 0.16), Color(0.3, 0.45, 0.1))
	var l_pump_top := _L(P_RIBBED, Color(0.80, 0.40, 0.06), Color(0.98, 0.62, 0.16), Color(0.3, 0.45, 0.1), Vector4(1, 0, 0, 0))
	_cube(PUMPKIN, "Abóbora", N, l_pump_top, l_pump_side, l_pump_top)
	TOOL[PUMPKIN] = TOOL_AXE
	var l_bush := _L(P_BUSH, Color(0.08, 0.26, 0.08), Color(0.22, 0.48, 0.14), Color(0.62, 0.06, 0.20), Vector4(1, 0, 0, 0), 14)
	var l_bush0 := _L(P_BUSH, Color(0.08, 0.26, 0.08), Color(0.22, 0.48, 0.14), Color(0.62, 0.06, 0.20), V4, 14)
	_cube(BERRY_BUSH, "Arbusto de frutas", N, l_bush, l_bush, l_bush, K_PLANT)
	_cube(BERRY_BUSH_EMPTY, "Arbusto de frutas (colhido)", "", l_bush0, l_bush0, l_bush0, K_PLANT)
	var sap_cols := [[woods[0][0], woods[0][5]], [woods[1][0], woods[1][5]], [woods[2][1], woods[2][5]], [woods[3][0], woods[3][5]],
		[woods[4][0], woods[4][5]], [Color(0.3, 0.15, 0.12), Color(0.95, 0.66, 0.78)]]
	var sap_names := ["carvalho", "pinheiro", "bétula", "mogno", "palmeira", "cerejeira"]
	SAPLING_WOOD.clear()
	for i in 6:
		var sc: Array = sap_cols[i]
		var ls := _L(P_SAPLING, sc[0], sc[1], Color.BLACK, Vector4(float(i), 0, 0, 0))
		_cube(SAPLING_0 + i, "Muda de " + sap_names[i], W, ls, ls, ls, K_PLANT)
		SAPLING_WOOD.append(i)
	_cube(PATH, "Caminho de terra", B, _L(P_DIRT, Color(0.42, 0.34, 0.22), Color(0.58, 0.49, 0.34), Color(0.55, 0.53, 0.5), Vector4(1, 0.95, 0, 0), 22), L_DIRT, L_DIRT)
	TOOL[PATH] = TOOL_SHOVEL

	# ---------- profundezas igneas ----------
	_reg(LAVA, "Lava", "", K_WATER)
	EMIT[LAVA] = 0
	_cube(SCORIA, "Escória", N, _L(P_STONE, Color(0.30, 0.09, 0.07), Color(0.52, 0.20, 0.14), Color(0.12, 0.04, 0.03), Vector4(1, 0.8, 0.85, 0), 9, 4.5))
	_cube(ASH, "Cinzas", N, _L(P_SAND, Color(0.30, 0.29, 0.29), Color(0.46, 0.44, 0.43), Color.BLACK, V4, 10, 1.5))
	_cube(EMBERSTONE, "Pedra-brasa", N, _L(P_GEM, Color(0.70, 0.22, 0.04), Color(1.0, 0.72, 0.24), Color.BLACK, Vector4(0.9, 0, 0, 0), 6))
	var l_fung := _L(P_MUSHROOM, Color(0.86, 0.26, 0.06), Color(0.55, 0.20, 0.14), Color(1.0, 0.80, 0.30))
	_cube(RED_FUNGUS, "Fungo rubro", N, l_fung, l_fung, l_fung, K_PLANT)
	for id: int in [SCORIA, EMBERSTONE]:
		TOOL[id] = TOOL_PICK
	TOOL[ASH] = TOOL_SHOVEL

	# ---------- ilhas etereas ----------
	var l_astral := _L(P_SMOOTH, Color(0.84, 0.82, 0.70), Color.BLACK, Color.BLACK, Vector4(0.6, 0.35, 0, 0))
	_cube(ASTRAL_STONE, "Pedra astral", N, l_astral)
	_cube(MOON_MOSS, "Musgo lunar", N, _L(P_GRASS, Color(0.20, 0.30, 0.42), Color(0.42, 0.62, 0.70), Color(0.62, 0.48, 0.80)), l_astral, l_astral)
	var l_mf := _L(P_FLOWER, Color(0.70, 0.92, 1.0), Color(1.0, 1.0, 0.9), Color.BLACK, Vector4(6, 0, 0, 0))
	_cube(MOON_FLOWER, "Flor lunar", N, l_mf, l_mf, l_mf, K_PLANT)
	var l_eb := _L(P_BARK, Color(0.48, 0.42, 0.62), Color(0.78, 0.72, 0.92), Color(0.1, 0.1, 0.1), V4, 10, 4.0)
	var l_et := _L(P_LOG_TOP, Color(0.62, 0.56, 0.80), Color(0.86, 0.82, 0.98), Color(0.4, 0.34, 0.56))
	_cube(ETHER_LOG, "Tronco etéreo", W, l_et, l_eb, l_et)
	var l_el := _L(P_LEAVES, Color(0.34, 0.20, 0.56), Color(0.66, 0.50, 0.92), Color.BLACK, Vector4(0.36, 0, 0, 0), 7)
	_cube(ETHER_LEAVES, "Folhas etéreas", W, l_el, l_el, l_el, K_LEAVES)
	TOOL[ASTRAL_STONE] = TOOL_PICK
	TOOL[MOON_MOSS] = TOOL_PICK
	TOOL[ETHER_LOG] = TOOL_AXE

	# ---------- portais ----------
	_cube(PORTAL_FIRE, "Portal ígneo", "", _L(P_PORTAL, Color(0.75, 0.16, 0.04), Color(1.0, 0.72, 0.20)), -1, -1, K_GLASS)
	_cube(PORTAL_ASTRAL, "Portal etéreo", "", _L(P_PORTAL, Color(0.20, 0.40, 0.90), Color(0.70, 0.95, 1.0)), -1, -1, K_GLASS)
	for id: int in [PORTAL_FIRE, PORTAL_ASTRAL]:
		SOLID[id] = 0
		EMIT[id] = 1

	# ---------- baus variados, portas e utilidades ----------
	var chest_woods := [[CHEST_PINE, "Baú de pinheiro", 1], [CHEST_BIRCH, "Baú de bétula", 2], [CHEST_MAHOG, "Baú de mogno", 3],
		[CHEST_PALM, "Baú de palmeira", 4]]
	for cw: Array in chest_woods:
		var wd: Array = woods[cw[2]]
		var fr: Color = wd[0].darkened(0.2)
		var lfr := _L(P_FRAMED, wd[2], wd[3], fr, Vector4(2, 0, 0, 0))
		var lsd := _L(P_FRAMED, wd[2], wd[3], fr, V4)
		_model(cw[0], cw[1], D, [[1, 0, 1, 15, 14, 15, [lsd, lsd, lsd, lsd, lsd, lfr]]])
	var lcf := _L(P_FRAMED, Color(0.66, 0.40, 0.37), Color(0.88, 0.64, 0.60), Color(0.32, 0.16, 0.13), Vector4(2, 0, 0, 0))
	var lcs := _L(P_FRAMED, Color(0.66, 0.40, 0.37), Color(0.88, 0.64, 0.60), Color(0.32, 0.16, 0.13), V4)
	_model(CHEST_CHERRY, "Baú de cerejeira", D, [[1, 0, 1, 15, 14, 15, [lcs, lcs, lcs, lcs, lcs, lcf]]])
	var lif := _L(P_FRAMED, Color(0.22, 0.20, 0.20), Color(0.34, 0.32, 0.31), Color(0.70, 0.72, 0.75), Vector4(2, 0, 0, 0))
	var lis := _L(P_FRAMED, Color(0.22, 0.20, 0.20), Color(0.34, 0.32, 0.31), Color(0.70, 0.72, 0.75), V4)
	_model(CHEST_IRON, "Baú reforçado", D, [[1, 0, 1, 15, 14, 15, [lis, lis, lis, lis, lis, lif]]])
	var l_door := _L(P_FRAMED, wc0, wc1, wc0.darkened(0.35), Vector4(6, 0, 0, 0))
	_model(DOOR, "Porta", D, [[0, 0, 0, 16, 16, 3, l_door]])
	_model(DOOR_OPEN, "Porta (aberta)", "", [[0, 0, 0, 3, 16, 16, l_door]])
	var l_anvil := _L(P_METAL, Color(0.22, 0.22, 0.25), Color(0.40, 0.40, 0.44), Color.BLACK, Vector4(0.45, 0, 0, 0))
	_model(ANVIL, "Bigorna", D, [[3, 0, 3, 13, 3, 13, l_anvil], [5, 3, 5, 11, 9, 11, l_anvil], [1, 9, 3, 15, 15, 13, l_anvil]])
	var l_log := FACE_LAYER[LOG * 6]
	_model(CAMPFIRE, "Fogueira", D, [[1, 0, 6, 15, 3, 10, l_log], [6, 0, 1, 10, 3, 15, l_log], [4, 2, 4, 12, 10, 12, l_flame]], true)
	for id: int in CHESTS:
		TOOL[id] = TOOL_AXE
	for id: int in [DOOR, DOOR_OPEN]:
		TOOL[id] = TOOL_AXE
	TOOL[ANVIL] = TOOL_PICK
	TOOL[CHEST_IRON] = TOOL_PICK
	for lv in 7:
		_reg(WATER_FLOW + lv, "Água corrente", "", K_WATER)
	for lv in 3:
		_reg(LAVA_FLOW + lv, "Lava corrente", "", K_WATER)
	FLUID.resize(512)
	FLUID.fill(0)
	FLUID[WATER] = 1
	FLUID[LAVA] = 2
	for lv in 7:
		FLUID[WATER_FLOW + lv] = 1
	for lv in 3:
		FLUID[LAVA_FLOW + lv] = 2
	# ---------- arvores frutiferas, flores, janelas, vitrais e porta de ferro ----------
	var oak_c0: Color = woods[0][4]
	var oak_c1: Color = woods[0][5]
	var l_apple := _L(P_LEAVES, oak_c0, oak_c1, Color(0.78, 0.08, 0.06), Vector4(0.36, 0.14, 0, 0), 7)
	_cube(APPLE_LEAVES, "Folhas de macieira", W, l_apple, l_apple, l_apple, K_LEAVES)
	var l_orange := _L(P_LEAVES, Color(0.05, 0.22, 0.06), Color(0.18, 0.42, 0.12), Color(0.98, 0.52, 0.06), Vector4(0.36, 0.16, 0, 0), 8)
	_cube(ORANGE_LEAVES, "Folhas de laranjeira", W, l_orange, l_orange, l_orange, K_LEAVES)
	var flowers := [
		[TULIP, "Tulipa", _L(P_FLOWER, Color(0.92, 0.22, 0.30), Color(0.3, 0.2, 0.1), Color.BLACK, Vector4(6, 0, 1, 0))],
		[LAVENDER, "Lavanda", _L(P_FLOWER, Color(0.56, 0.42, 0.86), Color(0.74, 0.60, 0.95), Color.BLACK, Vector4(6, 0, 2, 0))],
		[SUNFLOWER, "Girassol", _L(P_FLOWER, Color(1.0, 0.80, 0.10), Color(0.32, 0.18, 0.06), Color.BLACK, Vector4(6, 0, 3, 0))],
		[ROSE_BUSH, "Roseira", _L(P_BUSH, Color(0.06, 0.24, 0.08), Color(0.20, 0.44, 0.14), Color(0.86, 0.06, 0.14), Vector4(2, 0, 0, 0), 14)],
	]
	for fl: Array in flowers:
		_cube(fl[0], fl[1], N, fl[2], fl[2], fl[2], K_PLANT)
	_cube(WINDOW_WOOD, "Janela de madeira", D, _L(P_WINDOW, wc0, wc1, Color.BLACK, Vector4(0, 0, 0, 0)), -1, -1, K_GLASS)
	_cube(WINDOW_IRON, "Janela de ferro", D, _L(P_WINDOW, Color(0.20, 0.20, 0.22), Color(0.40, 0.40, 0.44), Color.BLACK, Vector4(1, 0, 0, 0)), -1, -1, K_GLASS)
	var stained := ["Vitral mosaico", "Vitral rosácea", "Vitral losangos", "Vitral floral"]
	for i in 4:
		_cube(STAINED_0 + i, stained[i], D, _L(P_STAINED, Color.WHITE, Color.WHITE, Color.BLACK, Vector4(i, 0, 0, 0), 6, 2.0), -1, -1, K_GLASS)
	var l_door_iron := _L(P_FRAMED, Color(0.50, 0.52, 0.56), Color(0.78, 0.80, 0.84), Color(0.28, 0.28, 0.30), Vector4(7, 0, 0, 0))
	_model(DOOR_IRON, "Porta de ferro", D, [[0, 0, 0, 16, 16, 3, l_door_iron]])
	_model(DOOR_IRON_OPEN, "Porta de ferro (aberta)", "", [[0, 0, 0, 3, 16, 16, l_door_iron]])
	for id: int in [WINDOW_IRON, DOOR_IRON, DOOR_IRON_OPEN]:
		TOOL[id] = TOOL_PICK
	TOOL[WINDOW_WOOD] = TOOL_AXE
	# Celula micro: material real fica em cada voxel; o id so marca a celula.
	_cube(MICRO, "Micro-bloco", "", L_STONE_FALLBACK(), -1, -1, K_CUBE)
	OPQ[MICRO] = 0
	COVER[MICRO] = 2
	_mining_table()
	_build_shapes()


static func _mining_table() -> void:
	HARD.resize(256)
	HARD.fill(1.0)
	REQ.resize(256)
	REQ.fill(0)
	for id in COUNT:
		match TOOL[id]:
			TOOL_SHOVEL: HARD[id] = 0.6
			TOOL_AXE: HARD[id] = 2.0
			TOOL_PICK:
				HARD[id] = 1.6
				REQ[id] = 1
		match KIND[id]:
			K_PLANT: HARD[id] = 0.0
			K_LEAVES: HARD[id] = 0.25
			K_GLASS: HARD[id] = 0.35
			K_MODEL:
				if TOOL[id] == TOOL_NONE:
					HARD[id] = 0.6
	for id: int in [SAND, RED_SAND, ASH, SNOW_BLOCK]:
		HARD[id] = 0.45
	for id: int in [BRICKS, STONE_BRICKS, SANDSTONE_BRICKS, MARBLE_BRICKS, BASALT_BRICKS, LIMESTONE_BRICKS, MUD_BRICKS]:
		HARD[id] = 2.0
	for id: int in [COAL_ORE, IRON_ORE, COPPER_ORE, GOLD_ORE, CRYSTAL_ORE, RUBY_ORE]:
		HARD[id] = 3.0
	for id: int in [IRON_BLOCK, GOLD_BLOCK, COPPER_BLOCK, CRYSTAL_BLOCK, RUBY_BLOCK, ANVIL, CHEST_IRON]:
		HARD[id] = 5.0
	for id: int in [IRON_ORE, COPPER_ORE, IRON_BLOCK, COPPER_BLOCK, ANVIL, CHEST_IRON]:
		REQ[id] = 2
	for id: int in [GOLD_ORE, CRYSTAL_ORE, RUBY_ORE, GOLD_BLOCK, CRYSTAL_BLOCK, RUBY_BLOCK]:
		REQ[id] = 4
	HARD[OBSIDIAN] = 40.0
	REQ[OBSIDIAN] = 5
	HARD[SCORIA] = 0.8
	HARD[ICE] = 0.5
	HARD[BEDROCK] = INF
	HARD[PORTAL_FIRE] = INF
	HARD[PORTAL_ASTRAL] = INF
	for id in COUNT:
		if FLUID[id] != 0:
			HARD[id] = INF


## Itens que um bloco dropa ao ser quebrado: [[id, quantidade], ...]. tool_ok: nivel de ferramenta suficiente.
static func drops(id: int, tool_ok: bool, rng: RandomNumberGenerator) -> Array:
	if not tool_ok:
		return []
	match id:
		STONE: return [[COBBLE, 1]]
		GRASS, SNOW_GRASS, FARMLAND, PATH: return [[DIRT, 1]]
		MOON_MOSS: return [[ASTRAL_STONE, 1]]
		COAL_ORE: return [[Items.find("Carvão"), 1]]
		CRYSTAL_ORE: return [[Items.find("Cristal"), rng.randi_range(1, 2)]]
		RUBY_ORE: return [[Items.find("Rubi"), 1]]
		EMBERSTONE: return [[Items.find("Pó de brasa"), rng.randi_range(2, 4)]]
		GRAVEL:
			return [[Items.find("Pederneira"), 1]] if rng.randf() < 0.15 else [[GRAVEL, 1]]
		GLASS, ICE, PORTAL_FIRE, PORTAL_ASTRAL, BEDROCK, WATER, LAVA:
			return []
		TALL_GRASS, FERN:
			return [[Items.find("Sementes de trigo"), 1]] if rng.randf() < 0.14 else []
		DEAD_BUSH:
			return [[Items.find("Graveto"), rng.randi_range(0, 2)]]
		BERRY_BUSH:
			return [[Items.find("Frutas silvestres"), rng.randi_range(2, 3)], [BERRY_BUSH_EMPTY, 1]]
		BERRY_BUSH_EMPTY:
			return [[BERRY_BUSH_EMPTY, 1]]
		DOOR_OPEN:
			return [[DOOR, 1]]
		DOOR_IRON_OPEN:
			return [[DOOR_IRON, 1]]
		ROSE_BUSH:
			return [[ROSE_BUSH, 1]]
	if id >= GLASS_TINT_0 and id < GLASS_TINT_0 + 4:
		return []
	if KIND[id] == K_LEAVES:
		var out := []
		var sap := _sapling_for_leaves(id)
		if sap > 0 and rng.randf() < 0.07:
			out.append([sap, 1])
		if rng.randf() < 0.05:
			out.append([Items.find("Graveto"), 1])
		var fruit := ""
		var chance := 0.0
		match id:
			LEAVES: fruit = "Maçã"; chance = 0.05
			APPLE_LEAVES: fruit = "Maçã"; chance = 0.3
			ORANGE_LEAVES: fruit = "Laranja"; chance = 0.3
			CHERRY_LEAVES: fruit = "Cereja"; chance = 0.10
			PALM_LEAVES: fruit = "Coco"; chance = 0.10
		if fruit != "" and rng.randf() < chance:
			out.append([Items.find(fruit), 1])
		return out
	for crop: int in CROP_STAGES:
		var n: int = CROP_STAGES[crop]
		if id >= crop and id < crop + n:
			var ripe := id == crop + n - 1
			match crop:
				CROP_WHEAT:
					return [[Items.find("Trigo"), 1], [Items.find("Sementes de trigo"), rng.randi_range(1, 3)]] if ripe else [[Items.find("Sementes de trigo"), 1]]
				CROP_CARROT:
					return [[Items.find("Cenoura"), rng.randi_range(2, 4) if ripe else 1]]
				CROP_POTATO:
					return [[Items.find("Batata"), rng.randi_range(2, 4) if ripe else 1]]
				CROP_PUMPKIN:
					return [[PUMPKIN, 1], [Items.find("Sementes de abóbora"), 1]] if ripe else [[Items.find("Sementes de abóbora"), 1]]
	return [[id, 1]]


static func _sapling_for_leaves(id: int) -> int:
	match id:
		LEAVES, APPLE_LEAVES, ORANGE_LEAVES: return SAPLING_0
		PINE_LEAVES: return SAPLING_0 + 1
		BIRCH_LEAVES: return SAPLING_0 + 2
		MAHOG_LEAVES: return SAPLING_0 + 3
		PALM_LEAVES: return SAPLING_0 + 4
		CHERRY_LEAVES: return SAPLING_0 + 5
	return 0


## Nivel do liquido: agua 1..8 (8 = fonte), lava 1..4 (4 = fonte); 0 se nao for liquido.
static func fluid_level(id: int) -> int:
	if id == WATER:
		return 8
	if id == LAVA:
		return 4
	if id >= WATER_FLOW and id < WATER_FLOW + 7:
		return id - WATER_FLOW + 1
	if id >= LAVA_FLOW and id < LAVA_FLOW + 3:
		return id - LAVA_FLOW + 1
	return 0


static func fluid_block(kind: int, level: int) -> int:
	if kind == 1:
		return WATER if level >= 8 else WATER_FLOW + clampi(level, 1, 7) - 1
	return LAVA if level >= 4 else LAVA_FLOW + clampi(level, 1, 3) - 1


static func is_source(id: int) -> bool:
	return id == WATER or id == LAVA


## Altura da superficie do liquido dentro do bloco (0..1).
static func fluid_height(id: int) -> float:
	var t := FLUID[id]
	if t == 0:
		return 0.0
	var mx := 8.0 if t == 1 else 4.0
	return 0.875 * float(fluid_level(id)) / mx


static func is_crop(id: int) -> bool:
	return (id >= CROP_WHEAT and id < CROP_PUMPKIN + 3)


static func crop_base(id: int) -> int:
	for crop: int in CROP_STAGES:
		if id >= crop and id < crop + int(CROP_STAGES[crop]):
			return crop
	return 0


static func _build_shapes() -> void:
	SHAPE_BOXES.resize(64)
	for sb in 64:
		var t := sb & 15
		var r := (sb >> 4) & 3
		var boxes: Array[AABB] = []
		match t:
			SH_SLAB:
				boxes.append(AABB(Vector3(0, 0, 0), Vector3(1, 0.5, 1)))
			SH_SLAB_TOP:
				boxes.append(AABB(Vector3(0, 0.5, 0), Vector3(1, 0.5, 1)))
			SH_STAIRS:
				boxes.append(AABB(Vector3(0, 0, 0), Vector3(1, 0.5, 1)))
				boxes.append(AABB(Vector3(0, 0.5, 0.5), Vector3(1, 0.5, 0.5)))
			SH_WEDGE:
				for k in 4:
					boxes.append(AABB(Vector3(0, k * 0.25, k * 0.25), Vector3(1, 0.25, 1.0 - k * 0.25)))
			SH_PILLAR:
				boxes.append(AABB(Vector3(0.25, 0, 0.25), Vector3(0.5, 1, 0.5)))
			SH_WALL:
				boxes.append(AABB(Vector3(0, 0, 0.5), Vector3(1, 1, 0.5)))
			SH_PANE:
				boxes.append(AABB(Vector3(0, 0, 7.0 / 16.0), Vector3(1, 1, 2.0 / 16.0)))
			_:
				boxes.append(UNIT_BOX)
		var out: Array[AABB] = []
		for b in boxes:
			out.append(_rot_box(b, r))
		SHAPE_BOXES[sb] = out
	# Blocos com forma ou modelo girado (id | 0x80) nao ocluem os vizinhos, mas cobrem a luz.
	for i in range(256, 512):
		COVER[i] = 2


## Caixas de colisao/selecao de um bloco (coordenadas locais 0..1).
static func boxes(id: int, shape: int) -> Array:
	var k := KIND[id]
	if k == K_MODEL:
		var out := []
		for mb: Array in MODELS[id * 4 + ((shape >> 4) & 3)]:
			out.append(mb[0])
		return out
	if k == K_PLANT:
		return [PLANT_BOX]
	if shape != 0:
		return SHAPE_BOXES[shape & 63]
	return [UNIT_BOX]


static func can_shape(id: int) -> bool:
	if id >= 256:
		return false
	if KIND[id] == K_GLASS:
		return id != PORTAL_FIRE and id != PORTAL_ASTRAL
	return KIND[id] == K_CUBE


## Porta aberta <-> fechada (0 se nao for porta).
static func door_toggle(id: int) -> int:
	match id:
		DOOR: return DOOR_OPEN
		DOOR_OPEN: return DOOR
		DOOR_IRON: return DOOR_IRON_OPEN
		DOOR_IRON_OPEN: return DOOR_IRON
	return 0


static func layer_bytes() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(LAYERS.size() * 80)
	for i in LAYERS.size():
		var d: Dictionary = LAYERS[i]
		var o := i * 80
		var cols: Array = [d["c0"], d["c1"], d["c2"]]
		for k in 3:
			var c: Color = cols[k]
			out.encode_float(o + k * 16, c.r)
			out.encode_float(o + k * 16 + 4, c.g)
			out.encode_float(o + k * 16 + 8, c.b)
			out.encode_float(o + k * 16 + 12, 1.0)
		var p: Vector4 = d["p"]
		out.encode_float(o + 48, p.x)
		out.encode_float(o + 52, p.y)
		out.encode_float(o + 56, p.z)
		out.encode_float(o + 60, d["nstr"])
		out.encode_s32(o + 64, d["pat"])
		out.encode_s32(o + 68, d["cells"])
		out.encode_s32(o + 72, 1000 + i * 17)
		out.encode_s32(o + 76, 0)
	return out
