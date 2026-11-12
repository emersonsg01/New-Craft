class_name Crafting
extends RefCounted
## Receitas. Ingredientes podem ser um id, um nome de item ou um grupo ("#tabuas", "#troncos",
## "#combustivel", "#la"). Estacao: "" (maos), "bancada", "fornalha" ou "bigorna" (perto do jogador).

static var RECIPES: Array[Dictionary] = []
static var GROUPS: Dictionary = {}


static func _id(x: Variant) -> int:
	if x is int:
		return x
	var n: String = x
	if n.begins_with("#"):
		return 0
	var id := Items.find(n)
	if id == 0:
		push_warning("Receita: item desconhecido " + n)
	return id


static func _r(out: Variant, n: int, ins: Array, station: String = "", cat: String = "") -> void:
	var oid := _id(out)
	if oid <= 0:
		return
	var parsed := []
	for i in range(0, ins.size(), 2):
		var key: Variant = ins[i]
		if key is String and (key as String).begins_with("#"):
			parsed.append([key, ins[i + 1]])
		else:
			var iid := _id(key)
			if iid <= 0:
				return
			parsed.append([iid, ins[i + 1]])
	if cat == "":
		cat = "Itens" if Items.is_item(oid) else "Blocos"
	RECIPES.append({"out": oid, "n": n, "in": parsed, "station": station, "cat": cat})


static func _static_init() -> void:
	GROUPS["#tabuas"] = [Blocks.PLANKS, Blocks.PINE_PLANKS, Blocks.BIRCH_PLANKS, Blocks.MAHOG_PLANKS, Blocks.PALM_PLANKS, Blocks.CHERRY_PLANKS]
	GROUPS["#troncos"] = [Blocks.LOG, Blocks.PINE_LOG, Blocks.BIRCH_LOG, Blocks.MAHOG_LOG, Blocks.PALM_LOG, Blocks.CHERRY_LOG]
	GROUPS["#la"] = range(Blocks.WOOL_0, Blocks.WOOL_0 + 12)
	GROUPS["#combustivel"] = [Items.find("Carvão"), Blocks.COAL_BLOCK, Items.find("Pó de brasa")] + GROUPS["#tabuas"] + GROUPS["#troncos"]
	GROUPS["#pedras"] = [Blocks.COBBLE, Blocks.STONE, Blocks.GRANITE, Blocks.BASALT, Blocks.LIMESTONE, Blocks.SLATE]
	GROUPS["#obsidiana"] = [Blocks.OBSIDIAN]

	# ---------- basico ----------
	var logs := [Blocks.LOG, Blocks.PINE_LOG, Blocks.BIRCH_LOG, Blocks.MAHOG_LOG, Blocks.PALM_LOG, Blocks.CHERRY_LOG]
	var planks := [Blocks.PLANKS, Blocks.PINE_PLANKS, Blocks.BIRCH_PLANKS, Blocks.MAHOG_PLANKS, Blocks.PALM_PLANKS, Blocks.CHERRY_PLANKS]
	for i in 6:
		_r(planks[i], 4, [logs[i], 1], "", "Básico")
	_r("Graveto", 4, ["#tabuas", 2], "", "Básico")
	_r(Blocks.WORKBENCH, 1, ["#tabuas", 4], "", "Básico")
	_r(Blocks.TORCH, 4, ["Graveto", 1, "Carvão", 1], "", "Básico")
	_r(Blocks.TORCH, 4, ["Graveto", 1, "Pó de brasa", 1], "", "Básico")
	_r(Blocks.FURNACE, 1, [Blocks.COBBLE, 8], "bancada", "Básico")
	_r(Blocks.CAMPFIRE, 1, ["Graveto", 3, "#troncos", 3, "Carvão", 1], "bancada", "Básico")
	_r("Isqueiro de pederneira", 1, ["Lingote de ferro", 1, "Pederneira", 1], "", "Básico")
	_r("Farinha de osso", 3, ["Osso", 1], "", "Básico")
	_r("Balde", 1, ["Lingote de ferro", 3], "", "Básico")
	_r(Blocks.ANVIL, 1, [Blocks.IRON_BLOCK, 3, "Lingote de ferro", 4], "bancada", "Básico")

	# ---------- fornalha ----------
	_r("Lingote de cobre", 1, [Blocks.COPPER_ORE, 1, "#combustivel", 1], "fornalha", "Fundição")
	_r("Lingote de ferro", 1, [Blocks.IRON_ORE, 1, "#combustivel", 1], "fornalha", "Fundição")
	_r("Lingote de ouro", 1, [Blocks.GOLD_ORE, 1, "#combustivel", 1], "fornalha", "Fundição")
	_r(Blocks.GLASS, 1, [Blocks.SAND, 1, "#combustivel", 1], "fornalha", "Fundição")
	_r(Blocks.STONE, 1, [Blocks.COBBLE, 1, "#combustivel", 1], "fornalha", "Fundição")
	_r(Blocks.BRICKS, 1, [Blocks.CLAY, 1, "#combustivel", 1], "fornalha", "Fundição")
	_r(Blocks.TERRACOTTA, 1, [Blocks.CLAY, 1, "#combustivel", 1], "fornalha", "Fundição")
	_r("Carvão", 1, ["#troncos", 1, "#combustivel", 1], "fornalha", "Fundição")
	_r("Carne assada", 1, ["Carne crua", 1, "#combustivel", 1], "fornalha", "Comida")
	_r("Batata assada", 1, ["Batata", 1, "#combustivel", 1], "fornalha", "Comida")
	_r(Blocks.OBSIDIAN, 1, [Blocks.BASALT, 4, "Pó de brasa", 2], "bancada", "Fundição")

	# ---------- comida e agricultura ----------
	_r("Pão", 1, ["Trigo", 3], "", "Comida")
	_r("Torta de abóbora", 1, [Blocks.PUMPKIN, 1, "Trigo", 2], "bancada", "Comida")
	_r("Torta de abóbora", 2, [Blocks.PUMPKIN, 1, "Trigo", 2, "Ovo", 1], "bancada", "Comida")
	_r("Tesoura", 1, ["Lingote de ferro", 2], "", "Ferramentas")
	_r("Tecido", 1, ["#la", 2], "", "Itens")
	_r("Couro curtido", 2, ["Couro", 2, "Carvão", 1], "bancada", "Itens")
	_r("Chapéu de palha", 1, ["Trigo", 5], "bancada", "Roupas")
	_r("Capuz", 1, ["Tecido", 3], "bancada", "Roupas")
	_r("Gorro", 1, ["Tecido", 2], "bancada", "Roupas")
	_r("Bandana", 1, ["Tecido", 1], "bancada", "Roupas")
	_r("Túnica", 1, ["Tecido", 4], "bancada", "Roupas")
	_r("Avental", 1, ["Couro curtido", 3], "bancada", "Roupas")
	_r("Manto", 1, ["Tecido", 6], "bancada", "Roupas")
	_r("Colete", 1, ["Couro curtido", 2, "Tecido", 2], "bancada", "Roupas")
	_r("Escudo de madeira", 1, ["#tabuas", 5, "Couro", 1], "bancada", "Armas")
	_r("Escudo de ferro", 1, ["Lingote de ferro", 5, "#tabuas", 1], "bigorna", "Armas")
	_r("Capacete de minerador", 1, ["Lingote de ferro", 4, Blocks.LANTERN, 1], "bancada", "Armaduras")
	_r("Sementes de abóbora", 4, [Blocks.PUMPKIN, 1], "", "Comida")
	_r(Blocks.HAY, 1, ["Trigo", 9], "", "Comida")
	_r("Trigo", 9, [Blocks.HAY, 1], "", "Comida")

	# ---------- ferramentas e armas ----------
	var mats := [["madeira", "#tabuas"], ["pedra", "#pedras"], ["cobre", "Lingote de cobre"], ["ferro", "Lingote de ferro"],
		["ouro", "Lingote de ouro"], ["cristal", "Cristal"]]
	for m: Array in mats:
		var mt: String = m[0]
		var it: Variant = m[1]
		_r("Picareta de " + mt, 1, [it, 3, "Graveto", 2], "bancada", "Ferramentas")
		_r("Machado de " + mt, 1, [it, 3, "Graveto", 1], "bancada", "Ferramentas")
		_r("Pá de " + mt, 1, [it, 1, "Graveto", 2], "bancada", "Ferramentas")
		_r("Enxada de " + mt, 1, [it, 2, "Graveto", 2], "bancada", "Ferramentas")
		var st := "bigorna" if mt in ["ferro", "ouro", "cristal"] else "bancada"
		_r("Espada de " + mt, 1, [it, 2, "Graveto", 1], st, "Armas")
		_r("Adaga de " + mt, 1, [it, 1, "Graveto", 1], st, "Armas")
		_r("Lança de " + mt, 1, [it, 1, "Graveto", 3], st, "Armas")
		_r("Machado de guerra de " + mt, 1, [it, 4, "Graveto", 2], st, "Armas")
		_r("Maça de " + mt, 1, [it, 4, "Graveto", 1], st, "Armas")
	# Materiais mistos: ingredientes e equipamentos.
	_r("Lingote de aço", 2, ["Lingote de ferro", 2, "Carvão", 1], "bigorna", "Itens")
	_r("Lingote de bronze", 4, ["Lingote de cobre", 3, "Lingote de ferro", 1], "bancada", "Itens")
	_r("Lingote de ferro dourado", 2, ["Lingote de ferro", 1, "Lingote de ouro", 1], "bigorna", "Itens")
	_r("Cristal rubi", 1, ["Cristal", 1, "Rubi", 1], "bigorna", "Itens")
	_r("Couro tachado", 2, ["Couro", 2, "Lingote de ferro", 1], "bancada", "Itens")
	var all_mats := mats.duplicate()
	for m: Array in Items.MIXED:
		all_mats.append([m[0], m[7]])
		var mt: String = m[0]
		var it: Variant = m[7]
		_r("Picareta de " + mt, 1, [it, 3, "Graveto", 2], "bancada", "Ferramentas")
		_r("Machado de " + mt, 1, [it, 3, "Graveto", 1], "bancada", "Ferramentas")
		_r("Pá de " + mt, 1, [it, 1, "Graveto", 2], "bancada", "Ferramentas")
		_r("Enxada de " + mt, 1, [it, 2, "Graveto", 2], "bancada", "Ferramentas")
		_r("Espada de " + mt, 1, [it, 2, "Graveto", 1], "bigorna", "Armas")
		_r("Adaga de " + mt, 1, [it, 1, "Graveto", 1], "bigorna", "Armas")
		_r("Lança de " + mt, 1, [it, 1, "Graveto", 3], "bigorna", "Armas")
		_r("Machado de guerra de " + mt, 1, [it, 4, "Graveto", 2], "bigorna", "Armas")
		_r("Maça de " + mt, 1, [it, 4, "Graveto", 1], "bigorna", "Armas")
	for m: Array in all_mats:
		var mt: String = m[0]
		var it: Variant = m[1]
		var st := "bancada" if mt in ["madeira", "pedra", "osso"] else "bigorna"
		_r("Martelo de guerra de " + mt, 1, [it, 5, "Graveto", 2], st, "Armas")
		_r("Alabarda de " + mt, 1, [it, 2, "Graveto", 3], st, "Armas")
		_r("Sabre de " + mt, 1, [it, 3, "Graveto", 3], st, "Armas")
		_r("Foice de guerra de " + mt, 1, [it, 4, "Graveto", 3], st, "Armas")
	_r("Besta", 1, ["#tabuas", 3, "Lingote de ferro", 2, "Corrente", 1], "bancada", "Armas")
	for m: Array in Items.ARMOR_MATS2:
		var an: String = m[0]
		_r("Capacete de " + an, 1, [m[4], 5], "bigorna", "Armaduras")
		_r("Peitoral de " + an, 1, [m[4], 8], "bigorna", "Armaduras")
		_r("Calças de " + an, 1, [m[4], 7], "bigorna", "Armaduras")
		_r("Botas de " + an, 1, [m[4], 4], "bigorna", "Armaduras")
	# Selas.
	_r("Sela de couro", 1, ["Couro", 5, "Lingote de ferro", 1], "bancada", "Montaria")
	_r("Sela de couro com ferro", 1, ["Couro", 4, "Lingote de ferro", 3], "bancada", "Montaria")
	_r("Sela de couro com cobre", 1, ["Couro", 4, "Lingote de cobre", 3], "bancada", "Montaria")
	_r("Sela cerimonial de ouro", 1, ["Couro", 4, "Lingote de ouro", 3, "#la", 1], "bancada", "Montaria")
	_r("Sela de viagem", 1, ["Couro", 6, "#la", 2, "Lingote de ferro", 1], "bancada", "Montaria")
	_r("Sela de guerra de aço", 1, ["Couro", 3, "Lingote de aço", 4, "#la", 1], "bigorna", "Montaria")
	_r("Arco", 1, ["Graveto", 3, "Couro", 1], "bancada", "Armas")
	_r("Flecha", 4, ["Pederneira", 1, "Graveto", 1, "Pena", 1], "", "Armas")
	var amats := [["couro", "Couro"], ["cobre", "Lingote de cobre"], ["ferro", "Lingote de ferro"], ["ouro", "Lingote de ouro"], ["cristal", "Cristal"]]
	for m: Array in amats:
		var st := "bancada" if m[0] == "couro" else "bigorna"
		_r("Capacete de " + str(m[0]), 1, [m[1], 5], st, "Armaduras")
		_r("Peitoral de " + str(m[0]), 1, [m[1], 8], st, "Armaduras")
		_r("Calças de " + str(m[0]), 1, [m[1], 7], st, "Armaduras")
		_r("Botas de " + str(m[0]), 1, [m[1], 4], st, "Armaduras")
	for i in Items.BOAT_WOODS.size():
		var bw: Array = Items.BOAT_WOODS[i]
		_r("Barco de " + str(bw[0]), 1, [bw[3], 5], "bancada", "Ferramentas")

	# ---------- construcao ----------
	_r(Blocks.STONE_BRICKS, 4, [Blocks.STONE, 4], "", "Construção")
	_r(Blocks.SANDSTONE_BRICKS, 4, [Blocks.SANDSTONE, 4], "", "Construção")
	_r(Blocks.MARBLE_BRICKS, 4, [Blocks.MARBLE, 4], "", "Construção")
	_r(Blocks.BASALT_BRICKS, 4, [Blocks.BASALT, 4], "", "Construção")
	_r(Blocks.LIMESTONE_BRICKS, 4, [Blocks.LIMESTONE, 4], "", "Construção")
	_r(Blocks.GRANITE_POLISHED, 4, [Blocks.GRANITE, 4], "", "Construção")
	_r(Blocks.MUD_BRICKS, 4, [Blocks.MUD, 4], "", "Construção")
	_r(Blocks.MOSSY_COBBLE, 1, [Blocks.COBBLE, 1, Blocks.MOSS_BLOCK, 1], "", "Construção")
	_r(Blocks.SANDSTONE, 1, [Blocks.SAND, 4], "", "Construção")
	_r(Blocks.ROOF_TILES, 4, [Blocks.TERRACOTTA, 4], "", "Construção")
	_r(Blocks.ROOF_SLATE, 4, [Blocks.SLATE, 4], "", "Construção")
	_r(Blocks.ROOF_GREEN, 4, [Blocks.TERRACOTTA, 4, "Cristal", 1], "", "Construção")
	_r(Blocks.PATH, 4, [Blocks.DIRT, 3, Blocks.GRAVEL, 1], "", "Construção")
	_r(Blocks.CONCRETE_0 + 1, 8, [Blocks.SAND, 4, Blocks.GRAVEL, 4], "bancada", "Construção")
	var metal := [[Blocks.IRON_BLOCK, "Lingote de ferro"], [Blocks.GOLD_BLOCK, "Lingote de ouro"], [Blocks.COPPER_BLOCK, "Lingote de cobre"],
		[Blocks.CRYSTAL_BLOCK, "Cristal"], [Blocks.RUBY_BLOCK, "Rubi"], [Blocks.COAL_BLOCK, "Carvão"]]
	for mb: Array in metal:
		_r(mb[0], 1, [mb[1], 9], "", "Construção")
		_r(mb[1], 9, [mb[0], 1], "", "Construção")
	_r(Blocks.WOOL_0 + 3, 1, [Blocks.WOOL_0, 1, Blocks.FLOWER_RED, 1], "", "Construção")
	_r(Blocks.WOOL_0 + 9, 1, [Blocks.WOOL_0, 1, Blocks.LAVENDER, 1], "", "Construção")
	_r(Blocks.WOOL_0 + 10, 1, [Blocks.WOOL_0, 1, Blocks.TULIP, 1], "", "Construção")
	_r(Blocks.GLASS_TINT_0, 2, [Blocks.GLASS, 2, Blocks.FLOWER_RED, 1], "", "Construção")
	_r(Blocks.GLASS_TINT_0 + 1, 2, [Blocks.GLASS, 2, Blocks.FLOWER_BLUE, 1], "", "Construção")
	_r(Blocks.GLASS_TINT_0 + 2, 2, [Blocks.GLASS, 2, Blocks.FERN, 1], "", "Construção")
	_r(Blocks.GLASS_TINT_0 + 3, 2, [Blocks.GLASS, 2, Blocks.SUNFLOWER, 1], "", "Construção")
	_r(Blocks.WOOL_0 + 5, 1, [Blocks.WOOL_0, 1, Blocks.FLOWER_YELLOW, 1], "", "Construção")
	_r(Blocks.WOOL_0 + 8, 1, [Blocks.WOOL_0, 1, Blocks.FLOWER_BLUE, 1], "", "Construção")
	_r(Blocks.WOOL_0 + 2, 1, [Blocks.WOOL_0, 1, "Carvão", 1], "", "Construção")

	# ---------- moveis ----------
	var chest_ids := [Blocks.CHEST, Blocks.CHEST_PINE, Blocks.CHEST_BIRCH, Blocks.CHEST_MAHOG, Blocks.CHEST_PALM, Blocks.CHEST_CHERRY]
	for i in 6:
		_r(chest_ids[i], 1, [planks[i], 8], "bancada", "Móveis")
	_r(Blocks.CHEST_IRON, 1, ["Lingote de ferro", 6, "#tabuas", 2], "bancada", "Móveis")
	_r(Blocks.DOOR_IRON, 2, ["Lingote de ferro", 6], "bancada", "Móveis")
	# ---------- portas, janelas, vidracas, correntes e ponte levadica ----------
	_r("Corrente", 2, ["Lingote de ferro", 2], "bancada", "Portas")
	_r("Ponte levadiça", 1, ["#troncos", 3, "Lingote de ferro", 3, "Corrente", 3], "bancada", "Portas")
	for w: Array in Blocks.WOODS:
		var pl: int = w[3]
		var wn: String = w[0]
		_r("Porta de " + wn, 3, [pl, 6], "bancada", "Portas")
		_r("Porta de %s com ferro" % wn, 2, [pl, 4, "Lingote de ferro", 2], "bancada", "Portas")
		_r("Porta de %s com cobre" % wn, 2, [pl, 4, "Lingote de cobre", 2], "bancada", "Portas")
		_r("Porta de vidro com " + wn, 2, [pl, 4, Blocks.GLASS, 2], "bancada", "Portas")
		_r("Janela de " + wn, 2, [pl, 2, Blocks.GLASS, 2], "bancada", "Janelas")
		_r("Janela de %s com ferro" % wn, 2, [pl, 2, "Lingote de ferro", 1, Blocks.GLASS, 2], "bancada", "Janelas")
		_r("Janela de %s com cobre" % wn, 2, [pl, 2, "Lingote de cobre", 1, Blocks.GLASS, 2], "bancada", "Janelas")
	_r("Porta de vidro com ferro", 2, ["Lingote de ferro", 4, Blocks.GLASS, 2], "bancada", "Portas")
	_r("Porta de vidro com cobre", 2, ["Lingote de cobre", 4, Blocks.GLASS, 2], "bancada", "Portas")
	for dv: Dictionary in Blocks.DOOR_VARS:
		var nm: String = dv["name"]
		_r("Porta dupla " + nm, 1, ["Porta " + nm, 2], "bancada", "Portas")
		_r("Portão grande " + nm, 1, ["Porta dupla " + nm, 2], "bancada", "Portas")
	for wv: Dictionary in Blocks.WIN_VARS:
		_r("Vidraça " + str(wv["name"]), 36, ["Janela " + str(wv["name"]), 6], "bancada", "Janelas")
	# Laminas de vidraca: 6 blocos (duas fileiras de 3) rendem 36 laminas.
	for i in Blocks.PANE_COUNT:
		_r(Blocks.PANE_0 + i, 36, [Blocks.PANE_SRC[i], 6], "bancada", "Construção")
	_r(Blocks.WINDOW_IRON, 2, [Blocks.GLASS, 2, "Lingote de ferro", 1], "bancada", "Móveis")
	_r(Blocks.STAINED_0, 4, [Blocks.GLASS_TINT_0, 1, Blocks.GLASS_TINT_0 + 1, 1, Blocks.GLASS_TINT_0 + 2, 1, Blocks.GLASS_TINT_0 + 3, 1], "bancada", "Móveis")
	_r(Blocks.STAINED_0 + 1, 4, [Blocks.GLASS_TINT_0, 2, Blocks.GLASS_TINT_0 + 3, 2], "bancada", "Móveis")
	_r(Blocks.STAINED_0 + 2, 4, [Blocks.GLASS_TINT_0 + 1, 2, Blocks.GLASS_TINT_0 + 2, 2], "bancada", "Móveis")
	_r(Blocks.STAINED_0 + 3, 4, [Blocks.GLASS_TINT_0 + 3, 2, Blocks.GLASS_TINT_0 + 2, 2], "bancada", "Móveis")
	_r(Blocks.CHAIR, 1, ["#tabuas", 3, "Graveto", 2], "bancada", "Móveis")
	_r(Blocks.STOOL, 1, ["#tabuas", 2, "Graveto", 2], "bancada", "Móveis")
	_r(Blocks.TABLE, 1, ["#tabuas", 3, "Graveto", 4], "bancada", "Móveis")
	_r(Blocks.BENCH, 1, ["#tabuas", 4, "Graveto", 2], "bancada", "Móveis")
	_r(Blocks.BED, 1, ["#la", 3, "#tabuas", 3], "bancada", "Móveis")
	_r(Blocks.FENCE, 3, ["#tabuas", 2, "Graveto", 4], "bancada", "Móveis")
	_r(Blocks.SHELF, 2, ["#tabuas", 3], "bancada", "Móveis")
	_r(Blocks.BOOKSHELF, 1, ["#tabuas", 6, "Couro", 3], "bancada", "Móveis")
	_r(Blocks.BARREL, 1, ["#tabuas", 6, "Lingote de ferro", 1], "bancada", "Móveis")
	_r(Blocks.CRATE, 1, ["#tabuas", 6], "bancada", "Móveis")
	_r(Blocks.LANTERN, 1, ["Lingote de ferro", 2, Blocks.TORCH, 1], "bancada", "Móveis")
	_r(Blocks.LAMP, 1, ["Lingote de ferro", 2, "#la", 1, Blocks.TORCH, 1], "bancada", "Móveis")
	_r(Blocks.FLOWER_POT, 1, [Blocks.TERRACOTTA, 3], "", "Móveis")


static func matches(key: Variant, id: int) -> bool:
	if key is String:
		return GROUPS.get(key, []).has(id)
	return key == id


static func have(inv: Inventory, key: Variant) -> int:
	if key is String:
		var n := 0
		for gid: int in GROUPS.get(key, []):
			n += inv.count(gid)
		return n
	return inv.count(key)


## Quantas vezes a receita pode ser feita com o inventario (ignorando a estacao).
static func times(inv: Inventory, r: Dictionary) -> int:
	var best := 999
	for ing: Array in r["in"]:
		best = mini(best, have(inv, ing[0]) / int(ing[1]))
	return best


## Quantas unidades (espacos) a receita ocupa numa grade de criacao.
static func units(r: Dictionary) -> int:
	var n := 0
	for ing: Array in r["in"]:
		n += int(ing[1])
	return n


## Receita que corresponde aos itens da grade (um item por espaco, em qualquer posicao).
## cells: quantos espacos a grade tem (4 ou 9); stations: estacoes disponiveis.
static func match_grid(grid: Inventory, cells: int, stations: Dictionary) -> Dictionary:
	var ids: Array[int] = []
	for i in cells:
		if grid.slots[i][0] > 0:
			ids.append(grid.slots[i][0])
	if ids.is_empty():
		return {}
	for r: Dictionary in RECIPES:
		var st: String = r["station"]
		if st == "fornalha" or (st != "" and not stations.has(st)):
			continue
		if units(r) != ids.size():
			continue
		var left := ids.duplicate()
		var ok := true
		# Ingredientes especificos primeiro, grupos depois.
		var ings: Array = r["in"].duplicate()
		ings.sort_custom(func(a: Array, b: Array) -> bool: return not (a[0] is String) and (b[0] is String))
		for ing: Array in ings:
			var need: int = ing[1]
			var k := 0
			while need > 0 and k < left.size():
				if matches(ing[0], left[k]):
					left.remove_at(k)
					need -= 1
				else:
					k += 1
			if need > 0:
				ok = false
				break
		if ok and left.is_empty():
			return r
	return {}


## Tira um item de cada espaco ocupado da grade.
static func consume_grid(grid: Inventory, cells: int) -> void:
	for i in cells:
		if grid.slots[i][0] > 0:
			grid.take_one(i)


## Fornalha: item de entrada -> [saida, quantidade].
static func smelt_table() -> Dictionary:
	var out := {}
	for r: Dictionary in RECIPES:
		if r["station"] != "fornalha":
			continue
		for ing: Array in r["in"]:
			if ing[0] is String:
				if ing[0] == "#combustivel":
					continue
				for gid: int in GROUPS.get(ing[0], []):
					if not out.has(gid):
						out[gid] = [r["out"], r["n"]]
			else:
				out[ing[0]] = [r["out"], r["n"]]
	return out


## Segundos de queima de um combustivel (0 = nao queima).
static func fuel_time(id: int) -> float:
	if id == Items.find("Carvão"):
		return 16.0
	if id == Blocks.COAL_BLOCK:
		return 144.0
	if id == Items.find("Pó de brasa"):
		return 12.0
	if GROUPS["#troncos"].has(id):
		return 8.0
	if GROUPS["#tabuas"].has(id):
		return 6.0
	if id == Items.find("Graveto"):
		return 2.0
	return 0.0


static func consume(inv: Inventory, r: Dictionary) -> void:
	for ing: Array in r["in"]:
		var need: int = ing[1]
		var key: Variant = ing[0]
		if key is String:
			for gid: int in GROUPS.get(key, []):
				var take := mini(need, inv.count(gid))
				if take > 0:
					inv.remove(gid, take)
					need -= take
				if need == 0:
					break
		else:
			inv.remove(key, need)


static func ing_name(key: Variant) -> String:
	if key is String:
		match key:
			"#tabuas": return "tábuas"
			"#troncos": return "troncos"
			"#combustivel": return "combustível"
			"#la": return "lã"
			"#pedras": return "pedras"
		return key
	return Items.name_of(key)


## Icone representativo de um ingrediente (para grupos, o primeiro membro).
static func ing_icon(key: Variant) -> int:
	if key is String:
		var g: Array = GROUPS.get(key, [])
		return g[0] if not g.is_empty() else 0
	return key
