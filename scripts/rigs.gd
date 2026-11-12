class_name Rigs
extends RefCounted
## Definicoes dos bonecos (em texels de 1/16 m; frente = -Z, pes em y = 0).
## Uma definicao e {scale, anim, parts: [{size, pos, pivot, col, spk, feats, g, infl}]}.

const CLEAR := Color(0, 0, 0, 0)
static var SKINS: Array[Color] = [Color(0.96, 0.80, 0.68), Color(0.86, 0.66, 0.50), Color(0.66, 0.46, 0.32), Color(0.42, 0.28, 0.19)]
static var HAIRS: Array[Color] = [Color(0.16, 0.11, 0.07), Color(0.42, 0.26, 0.12), Color(0.86, 0.70, 0.36), Color(0.70, 0.22, 0.10), Color(0.09, 0.09, 0.10), Color(0.78, 0.78, 0.80)]
const SKIN_NAMES: Array[String] = ["Clara", "Morena clara", "Morena", "Escura"]
const HAIR_NAMES: Array[String] = ["Castanho escuro", "Castanho", "Loiro", "Ruivo", "Preto", "Grisalho"]
const HAIR_STYLES: Array[String] = ["Curto", "Longo", "Careca", "Rabo de cavalo", "Moicano", "Coque"]
const BEARDS: Array[String] = ["Nenhuma", "Bigode", "Cavanhaque", "Curta", "Longa"]
const OUTFITS: Array[String] = ["Camiseta", "Túnica", "Avental", "Manto", "Colete"]
const HATS: Array[String] = ["Nenhum", "Chapéu de palha", "Capuz", "Gorro", "Bandana"]


static func _sides(x: int, y: int, w: int, h: int, c: Color, d: int = -1) -> Array:
	# Retangulo repetido nas 4 faces laterais (d = largura nas faces +-X, se diferente).
	var dd := w if d < 0 else d
	return [[0, x, y, dd, h, c], [1, x, y, dd, h, c], [4, x, y, w, h, c], [5, x, y, w, h, c]]


## Humanoide com proporcoes proprias do New Craft: cabeca grande (10x9x9), tronco curto e
## largo, bracos finos com maos, pernas com botas e cabelo com volume.
## o: {female, skin, hair, shirt, pants, shoes, eyes, armor: [cores ou null x4], arm_w, leg_w, torso_w, plain}
static func humanoid(o: Dictionary) -> Dictionary:
	var female: bool = o.get("female", false)
	var skin: Color = o.get("skin", SKINS[0])
	var hair: Color = o.get("hair", HAIRS[0])
	var shirt: Color = o.get("shirt", Color(0.16, 0.42, 0.62))
	var pants: Color = o.get("pants", Color(0.20, 0.22, 0.42))
	var shoes: Color = o.get("shoes", Color(0.22, 0.16, 0.12))
	var eyes: Color = o.get("eyes", Color(0.20, 0.32, 0.55))
	var plain: bool = o.get("plain", false)
	var aw: int = o.get("arm_w", 3)
	var ad := mini(aw, 3)
	var lw: int = o.get("leg_w", 4)
	var ld := mini(lw, 4)
	var tw: int = o.get("torso_w", 8 if female else 9)
	var white := Color(0.97, 0.97, 0.97)
	var trim := shirt.lightened(0.35)
	var parts: Array = []

	# ---------- cabeca ----------
	var hf: Array = []
	var style: int = o.get("hair_style", 3 if female else 0)
	var beard: int = o.get("beard", 0)
	if not plain:
		match style:
			0, 5:
				hf.append([2, 0, 0, 10, 9, hair])
				hf.append([4, 0, 0, 10, 6, hair])
				hf.append([0, 0, 0, 9, 3, hair])
				hf.append([1, 0, 0, 9, 3, hair])
				hf.append([5, 0, 0, 10, 2, hair])
				hf.append([5, 5, 2, 4, 1, hair])
				hf.append([5, 8, 3, 1, 1, hair])
			1, 3:
				hf.append([2, 0, 0, 10, 9, hair])
				hf.append([4, 0, 0, 10, 9, hair])
				hf.append([0, 0, 0, 9, 7, hair])
				hf.append([1, 0, 0, 9, 7, hair])
				hf.append([5, 0, 0, 10, 2, hair])
				hf.append([5, 0, 2, 1, 6, hair])
				hf.append([5, 9, 2, 1, 6, hair])
				hf.append([5, 1, 2, 2, 1, hair])
			2:
				hf.append([0, 3, 2, 6, 2, hair.darkened(0.1)])
				hf.append([1, 3, 2, 6, 2, hair.darkened(0.1)])
				hf.append([4, 0, 3, 10, 2, hair.darkened(0.1)])
			4:
				hf.append([2, 4, 0, 2, 9, hair])
				hf.append([4, 4, 0, 2, 5, hair])
				hf.append([0, 0, 2, 9, 2, hair.darkened(0.25)])
				hf.append([1, 0, 2, 9, 2, hair.darkened(0.25)])
		hf.append([0, 4, 4, 1, 1, skin.darkened(0.2)])
		hf.append([1, 4, 4, 1, 1, skin.darkened(0.2)])
	hf.append([5, 2, 4, 2, 2, white])
	hf.append([5, 6, 4, 2, 2, white])
	hf.append([5, 3, 4, 1, 2, eyes])
	hf.append([5, 6, 4, 1, 2, eyes])
	if not plain:
		hf.append([5, 2, 3, 2, 1, hair.darkened(0.35)])
		hf.append([5, 6, 3, 2, 1, hair.darkened(0.35)])
	var mouth: Color = o.get("mouth", Color(0.80, 0.34, 0.36) if female else skin.darkened(0.35))
	hf.append([5, 4, 7, 2, 1, mouth])
	if female and not plain:
		hf.append([5, 1, 6, 1, 1, skin.lerp(Color(0.95, 0.45, 0.45), 0.4)])
		hf.append([5, 8, 6, 1, 1, skin.lerp(Color(0.95, 0.45, 0.45), 0.4)])
	if not plain and beard > 0:
		var bc := hair.darkened(0.1)
		hf.append([5, 3, 6, 4, 1, bc])
		if beard == 2:
			hf.append([5, 4, 8, 2, 1, bc])
		elif beard >= 3:
			hf.append([5, 1, 6, 2, 3, bc])
			hf.append([5, 7, 6, 2, 3, bc])
			hf.append([5, 3, 8, 4, 1, bc])
			hf.append([0, 0, 5, 3, 4, bc])
			hf.append([1, 0, 5, 3, 4, bc])
			hf.append([3, 1, 0, 8, 4, bc])
	hf.append_array(o.get("head_feats", []))
	var head_pos := Vector3(-5, 21, -4.5)
	var head_piv := Vector3(0, 21, 0)
	parts.append({"size": Vector3i(10, 9, 9), "pos": head_pos, "pivot": head_piv, "col": skin, "feats": hf, "g": "head"})
	if not plain:
		match style:
			0:
				# Topete levantado.
				parts.append({"size": Vector3i(4, 2, 4), "pos": Vector3(-1, 30, -3.5), "pivot": head_piv, "col": hair, "g": "head"})
			1:
				# Cabelo solto caindo nas costas.
				parts.append({"size": Vector3i(10, 7, 2), "pos": Vector3(-5, 16, 4.5), "pivot": head_piv, "col": hair, "g": "head"})
			3:
				# Rabo de cavalo preso no alto, com prendedor.
				parts.append({"size": Vector3i(4, 2, 2), "pos": Vector3(-2, 26, 4.5), "pivot": head_piv, "col": o.get("tie", Color(0.86, 0.72, 0.18)), "g": "head"})
				parts.append({"size": Vector3i(4, 8, 3), "pos": Vector3(-2, 18.5, 5.5), "pivot": head_piv, "col": hair, "g": "head"})
			4:
				parts.append({"size": Vector3i(2, 3, 8), "pos": Vector3(-1, 30, -3.5), "pivot": head_piv, "col": hair, "g": "head"})
			5:
				parts.append({"size": Vector3i(4, 3, 4), "pos": Vector3(-2, 29, 1), "pivot": head_piv, "col": hair, "g": "head"})
		if beard == 4:
			parts.append({"size": Vector3i(6, 4, 2), "pos": Vector3(-3, 18, -5), "pivot": head_piv, "col": hair.darkened(0.1), "g": "head"})

	# ---------- tronco ----------
	var tf: Array = []
	var cx := (tw - 2) / 2
	if not plain:
		if female:
			tf.append([5, cx - 1, 0, 4, 2, skin])
			tf.append([5, cx - 2, 0, 1, 2, trim])
			tf.append([5, cx + 3, 0, 1, 2, trim])
		else:
			tf.append([5, cx, 0, 2, 2, skin])
			tf.append([5, cx - 1, 0, 1, 1, trim])
			tf.append([5, cx + 2, 0, 1, 1, trim])
			tf.append([5, cx + 1, 3, 1, 1, trim])
			tf.append([5, cx + 1, 5, 1, 1, trim])
		tf.append_array(_sides(0, 8, tw, 1, Color(0.24, 0.16, 0.10), 5))
		tf.append([5, cx, 8, 2, 1, Color(0.92, 0.76, 0.28)])
		tf.append_array(_sides(0, 9, tw, 1, pants, 5))
	var outfit: int = o.get("outfit", 0)
	var cloth2: Color = o.get("cloth2", Color(0.62, 0.48, 0.30))
	if not plain:
		match outfit:
			2:
				tf.append([5, 1, 2, tw - 2, 8, cloth2])
				tf.append([5, cx, 0, 2, 2, cloth2.darkened(0.2)])
			3:
				tf.append_array(_sides(0, 8, tw, 2, shirt.darkened(0.15), 5))
				tf.append([5, cx, 2, 2, 8, trim])
			4:
				tf.append([5, 0, 0, 2, 9, cloth2])
				tf.append([5, tw - 2, 0, 2, 9, cloth2])
				tf.append_array([[0, 0, 0, 5, 9, cloth2], [1, 0, 0, 5, 9, cloth2], [4, 0, 0, tw, 9, cloth2]])
	tf.append_array(o.get("torso_feats", []))
	var torso_pos := Vector3(-tw * 0.5, 11, -2.5)
	parts.append({"size": Vector3i(tw, 10, 5), "pos": torso_pos, "pivot": Vector3(0, 11, 0), "col": shirt, "feats": tf})

	# ---------- bracos (com maos) ----------
	var af: Array = []
	if not plain:
		var sleeve := 3 if female else 4
		af.append_array(_sides(0, 0, aw, sleeve, shirt, ad))
		af.append_array(_sides(0, sleeve, aw, 1, trim, ad))
		af.append([2, 0, 0, aw, ad, shirt])
	af.append_array(o.get("limb_feats", []))
	var axr := tw * 0.5
	parts.append({"size": Vector3i(aw, 10, ad), "pos": Vector3(axr, 11, -ad * 0.5), "pivot": Vector3(axr + aw * 0.5, 20, 0), "col": skin, "feats": af, "g": "armA"})
	parts.append({"size": Vector3i(aw, 10, ad), "pos": Vector3(-axr - aw, 11, -ad * 0.5), "pivot": Vector3(-axr - aw * 0.5, 20, 0), "col": skin, "feats": af, "g": "armB"})

	# ---------- pernas (com botas) ----------
	var lf: Array = []
	if not plain:
		lf.append_array(_sides(0, 8, lw, 3, shoes, ld))
		lf.append_array(_sides(0, 8, lw, 1, shoes.lightened(0.25), ld))
		lf.append([3, 0, 0, lw, ld, shoes])
	if not plain:
		match outfit:
			1:
				lf.append_array(_sides(0, 0, lw, 4, shirt, ld))
			2:
				lf.append([5, 0, 0, lw, 6, cloth2])
			3:
				lf.append_array(_sides(0, 0, lw, 8, shirt.darkened(0.15), ld))
	lf.append_array(o.get("limb_feats", []))
	var lxa := 2.0 - lw * 0.5
	var lxb := -2.0 - lw * 0.5
	parts.append({"size": Vector3i(lw, 11, ld), "pos": Vector3(lxa, 0, -ld * 0.5), "pivot": Vector3(2, 11, 0), "col": pants, "feats": lf, "g": "legA"})
	parts.append({"size": Vector3i(lw, 11, ld), "pos": Vector3(lxb, 0, -ld * 0.5), "pivot": Vector3(-2, 11, 0), "col": pants, "feats": lf, "g": "legB"})

	# ---------- chapeus ----------
	var hat: int = o.get("hat", 0)
	var armor: Array = o.get("armor", [null, null, null, null])
	if not plain and armor[0] == null:
		var hc: Color = o.get("hat_col", Color(0.86, 0.74, 0.40))
		match hat:
			1:
				parts.append({"size": Vector3i(14, 1, 13), "pos": Vector3(-7, 29.5, -6.5), "pivot": head_piv, "col": hc, "spk": 0.2, "g": "head"})
				parts.append({"size": Vector3i(8, 3, 8), "pos": Vector3(-4, 30.5, -4), "pivot": head_piv, "col": hc, "spk": 0.2, "g": "head",
					"feats": [[0, 0, 2, 8, 1, Color(0.6, 0.2, 0.15)], [1, 0, 2, 8, 1, Color(0.6, 0.2, 0.15)], [4, 0, 2, 8, 1, Color(0.6, 0.2, 0.15)], [5, 0, 2, 8, 1, Color(0.6, 0.2, 0.15)]]})
			2:
				parts.append({"size": Vector3i(10, 9, 9), "pos": head_pos, "pivot": head_piv, "col": hc, "infl": 0.1, "g": "head",
					"feats": [[5, 1, 2, 8, 7, CLEAR], [3, 0, 0, 10, 9, CLEAR]]})
				parts.append({"size": Vector3i(6, 4, 2), "pos": Vector3(-3, 25, 4.5), "pivot": head_piv, "col": hc.darkened(0.1), "g": "head"})
			3:
				parts.append({"size": Vector3i(10, 3, 9), "pos": Vector3(-5, 28, -4.5), "pivot": head_piv, "col": hc, "infl": 0.08, "g": "head",
					"feats": [[0, 0, 2, 9, 1, hc.darkened(0.3)], [1, 0, 2, 9, 1, hc.darkened(0.3)], [5, 0, 2, 10, 1, hc.darkened(0.3)], [4, 0, 2, 10, 1, hc.darkened(0.3)]]})
				parts.append({"size": Vector3i(2, 2, 2), "pos": Vector3(-1, 31, -1), "pivot": head_piv, "col": Color(0.95, 0.95, 0.95), "g": "head"})
			4:
				parts.append({"size": Vector3i(10, 3, 9), "pos": Vector3(-5, 27, -4.5), "pivot": head_piv, "col": hc, "infl": 0.06, "g": "head",
					"feats": [[3, 0, 0, 10, 9, CLEAR]]})
				parts.append({"size": Vector3i(2, 3, 1), "pos": Vector3(-1, 25, 4.8), "pivot": head_piv, "col": hc, "g": "head"})

	# ---------- armadura: cascas levemente infladas por cima, com furos ----------
	# Acabamento por material: couro costurado, cobre com patina, ferro rebitado, ouro gravado, cristal com gemas.
	if armor[0] != null:
		var c: Color = armor[0]
		var am := _armor_mat(c)
		var tr := _armor_trim(am, c)
		var hfe: Array = [[5, 1, 3, 8, 6, CLEAR], [3, 0, 0, 10, 9, CLEAR], [2, 4, 0, 2, 9, c.darkened(0.3)], [5, 4, 0, 2, 3, c.darkened(0.3)]]
		for f in [0, 1, 4]:
			hfe.append([f, 0, 3, 10 if f == 4 else 9, 1, tr])
		if am == 2 or am == 3:
			hfe.append([5, 4, 3, 2, 3, c])  # protetor nasal
		if am == 2:
			for f in [0, 1]:
				hfe.append([f, 1, 5, 1, 1, tr])
				hfe.append([f, 7, 5, 1, 1, tr])
		elif am == 0:
			for f in [0, 1]:
				for k in range(1, 8, 2):
					hfe.append([f, k, 6, 1, 1, tr])
		elif am == 1:
			hfe.append_array(_spots(4, Color(0.30, 0.62, 0.52), 10, 9, 9, 71))
		elif am == 4:
			hfe.append([5, 4, 1, 2, 2, Color(0.8, 1.0, 1.0)])
		parts.append({"size": Vector3i(10, 9, 9), "pos": head_pos, "pivot": head_piv, "col": c, "infl": 0.12, "g": "head", "feats": hfe})
		if o.get("lamp", false):
			# Capacete de minerador: lanterna na testa.
			parts.append({"size": Vector3i(4, 3, 2), "pos": head_pos + Vector3(3, 6, -1.6), "pivot": head_piv, "col": Color(0.25, 0.25, 0.27), "g": "head",
				"feats": [[5, 1, 0, 2, 2, Color(1.0, 0.96, 0.70)]]})
		if am >= 3:
			# Crista no elmo.
			parts.append({"size": Vector3i(2, 3, 9), "pos": head_pos + Vector3(4, 9.6, 0), "pivot": head_piv, "col": tr, "g": "head", "spk": 0.2,
				"feats": [[0, 0, 0, 9, 1, tr.lightened(0.3)], [1, 0, 0, 9, 1, tr.lightened(0.3)]]})
	if armor[1] != null:
		var c: Color = armor[1]
		var am := _armor_mat(c)
		var tr := _armor_trim(am, c)
		var cfe: Array = [[5, cx, 1, 2, 7, c.darkened(0.3)], [3, 0, 0, tw, 5, CLEAR], [2, 1, 1, tw - 2, 3, CLEAR]]
		# Cinto com fivela.
		cfe.append([5, 0, 8, tw, 1, Color(0.30, 0.20, 0.11)])
		cfe.append([4, 0, 8, tw, 1, Color(0.30, 0.20, 0.11)])
		cfe.append([5, cx, 8, 2, 1, tr])
		match am:
			0:
				for k in range(0, 7, 2):
					cfe.append([5, 1, k, 1, 1, tr])
					cfe.append([5, tw - 2, k, 1, 1, tr])
			1:
				cfe.append_array(_spots(5, Color(0.30, 0.62, 0.52), tw, 10, 5, 73))
			2:
				for x in [1, tw - 2]:
					for y in [1, 4, 7]:
						cfe.append([5, x, y, 1, 1, tr])
				cfe.append([5, 0, 4, tw, 1, c.darkened(0.15)])
			3:
				cfe.append([5, 1, 2, tw - 2, 1, tr])
				cfe.append([5, 2, 5, tw - 4, 1, tr])
				cfe.append([5, cx, 3, 2, 2, Color(0.85, 0.10, 0.15)])
			4:
				cfe.append([5, cx, 3, 2, 2, Color(0.80, 1.0, 1.0)])
				cfe.append([5, 1, 1, 1, 1, Color(0.80, 1.0, 1.0)])
				cfe.append([5, tw - 2, 1, 1, 1, Color(0.80, 1.0, 1.0)])
		if am == 5 or am == 8:
			# Cota de malha: aneis alternados; couro tachado: tachas espalhadas.
			for y in range(0, 8, 2):
				for x in range(0 if am == 5 else 1, tw, 2 if am == 5 else 3):
					cfe.append([5, x + (y / 2) % 2, y, 1, 1, tr])
					cfe.append([4, x + (y / 2) % 2, y, 1, 1, tr])
		elif am == 9:
			cfe.append([5, 1, 2, 1, 6, tr])
			cfe.append([5, tw - 2, 2, 1, 6, tr])
		elif am == 10:
			cfe.append([5, cx, 3, 2, 2, Color(1.0, 0.35, 0.55)])
		parts.append({"size": Vector3i(tw, 10, 5), "pos": torso_pos, "pivot": Vector3(0, 11, 0), "col": c, "infl": 0.12, "feats": cfe})
		# Ombreiras.
		for sd in [1, -1]:
			var ox: float = axr - 0.5 if sd > 0 else -axr - aw - 0.5
			parts.append({"size": Vector3i(aw + 1, 2, ad + 2), "pos": Vector3(ox, 19.5, -ad * 0.5 - 1.0), "pivot": Vector3(sd * (axr + aw * 0.5), 20, 0),
				"col": c.lightened(0.06), "spk": 0.1, "g": "armA" if sd > 0 else "armB",
				"feats": [[0, 0, 1, ad + 2, 1, tr], [1, 0, 1, ad + 2, 1, tr], [5, 0, 1, aw + 1, 1, tr], [4, 0, 1, aw + 1, 1, tr]]})
		var sf: Array = _sides(0, 0, aw, 5, c, ad)
		sf.append([2, 0, 0, aw, ad, c])
		sf.append_array(_sides(0, 4, aw, 1, tr, ad))
		parts.append({"size": Vector3i(aw, 10, ad), "pos": Vector3(axr, 11, -ad * 0.5), "pivot": Vector3(axr + aw * 0.5, 20, 0), "col": CLEAR, "infl": 0.22, "feats": sf, "g": "armA"})
		parts.append({"size": Vector3i(aw, 10, ad), "pos": Vector3(-axr - aw, 11, -ad * 0.5), "pivot": Vector3(-axr - aw * 0.5, 20, 0), "col": CLEAR, "infl": 0.22, "feats": sf, "g": "armB"})
	for slot in [2, 3]:
		if armor[slot] == null:
			continue
		var c: Color = armor[slot]
		var tr := _armor_trim(_armor_mat(c), c)
		var ff: Array = _sides(0, 0, lw, 8, c, ld) if slot == 2 else _sides(0, 7, lw, 4, c, ld)
		if slot == 3:
			ff.append([3, 0, 0, lw, ld, c.darkened(0.3)])
			ff.append_array(_sides(0, 7, lw, 1, tr, ld))
		else:
			# Joelheira e faixa lateral.
			ff.append([5, 0, 5, lw, 2, c.lightened(0.12)])
			ff.append([5, lw / 2, 5, 1, 1, tr])
			ff.append([0, 0, 0, ld, 8, c.darkened(0.12)])
		var inf := 0.10 if slot == 2 else 0.17
		parts.append({"size": Vector3i(lw, 11, ld), "pos": Vector3(lxa, 0, -ld * 0.5), "pivot": Vector3(2, 11, 0), "col": CLEAR, "infl": inf, "feats": ff, "g": "legA"})
		parts.append({"size": Vector3i(lw, 11, ld), "pos": Vector3(lxb, 0, -ld * 0.5), "pivot": Vector3(-2, 11, 0), "col": CLEAR, "infl": inf, "feats": ff, "g": "legB"})
	parts = _split_limbs(parts, ["armA", "armB"], 0.5)
	parts = _split_limbs(parts, ["legA", "legB"], 0.55)
	return {"scale": o.get("scale", 0.95), "anim": o.get("anim", "biped"), "pose": o.get("pose", ""), "alpha": o.get("alpha", false), "parts": parts}


## Indice do material da armadura pela cor clara (0 couro, 1 cobre, 2 ferro, 3 ouro, 4 cristal).
static func _armor_mat(c: Color) -> int:
	var best := 0
	var bd := 99.0
	var all: Array = Items.ARMOR_MATS + Items.ARMOR_MATS2
	for i in all.size():
		var m: Color = all[i][2]
		var dd := absf(m.r - c.r) + absf(m.g - c.g) + absf(m.b - c.b)
		if dd < bd:
			bd = dd
			best = i
	return best


static func _armor_trim(am: int, c: Color) -> Color:
	match am:
		0: return Color(0.86, 0.78, 0.60)  # costura
		1: return Color(0.98, 0.72, 0.48)
		2: return Color(0.32, 0.33, 0.36)  # rebites
		3: return Color(1.0, 0.95, 0.70)  # gravura
		4: return Color(0.90, 0.92, 0.98)  # prata
		5: return Color(0.28, 0.29, 0.32)  # aneis da malha
		6: return Color(0.96, 0.30, 0.20)  # aco com friso vermelho
		7: return Color(0.30, 0.62, 0.52)  # bronze com patina
		8: return Color(0.80, 0.80, 0.84)  # tachas
		9: return Color(0.70, 0.45, 1.0)  # obsidiana com brilho violeta
		10: return Color(0.98, 0.82, 0.30)  # ouro no cristal rubi
	return c.lightened(0.3)


## Divide as partes dos grupos dados em segmento de cima (grupo original) e de baixo (grupo + "2"),
## pendurado no de cima pela articulacao. frac = fracao da altura que fica no segmento de cima.
static func _split_limbs(parts: Array, groups: Array, frac: float) -> Array:
	var out: Array = []
	var remap: Array[int] = []
	for p0: Dictionary in parts:
		var p := p0
		if p.has("parent_i"):
			p = p0.duplicate()
			p["parent_i"] = remap[int(p0["parent_i"])]
		remap.append(out.size())
		var g: String = p.get("g", "")
		var size: Vector3i = p["size"]
		if not groups.has(g) or size.y < 6 or p.has("parent_i"):
			out.append(p)
			continue
		var h := size.y
		var u := clampi(int(round(h * frac)), 2, h - 2)
		var pos: Vector3 = p["pos"]
		var pivot: Vector3 = p.get("pivot", pos + Vector3(size) * 0.5)
		var top_f: Array = []
		var low_f: Array = []
		for f: Array in p.get("feats", []):
			var face: int = f[0]
			if face == 2:
				top_f.append(f)
				continue
			if face == 3:
				low_f.append(f)
				continue
			var y0: int = f[2]
			var y1: int = y0 + int(f[4])
			if y0 < u:
				var nf := f.duplicate()
				nf[4] = mini(y1, u) - y0
				top_f.append(nf)
			if y1 > u:
				var nf2 := f.duplicate()
				nf2[2] = maxi(y0, u) - u
				nf2[4] = y1 - maxi(y0, u)
				low_f.append(nf2)
		var up := p.duplicate()
		up["size"] = Vector3i(size.x, u, size.z)
		up["pos"] = Vector3(pos.x, pos.y + h - u, pos.z)
		up["pivot"] = pivot
		up["feats"] = top_f
		out.append(up)
		var lo := p.duplicate()
		lo["size"] = Vector3i(size.x, h - u, size.z)
		lo["pos"] = pos
		lo["pivot"] = Vector3(pivot.x, pos.y + h - u, pivot.z)
		lo["feats"] = low_f
		lo["g"] = g + "2"
		lo["parent_i"] = out.size() - 1
		out.append(lo)
	return out


static func _spots(count: int, col: Color, w: int, h: int, l: int, seed_v: int) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in count:
		var face: int = [0, 1, 2][rng.randi() % 3]
		var fw := l if face < 2 else w
		var fh := h if face < 2 else l
		var sw := rng.randi_range(2, 5)
		var sh := rng.randi_range(2, 4)
		out.append([face, rng.randi_range(0, maxi(0, fw - sw)), rng.randi_range(0, maxi(0, fh - sh)), sw, sh, col])
	return out


## Quadrupede generico. o: bw,bh,bl (corpo), lw,lh (pernas), head (Vector3i), head_up, col, col2,
## body_feats, head_feats, extra (partes adicionais), scale.
static func quad(o: Dictionary) -> Dictionary:
	var bw: int = o["bw"]
	var bh: int = o["bh"]
	var bl: int = o["bl"]
	var lw: int = o["lw"]
	var lh: int = o["lh"]
	var hs: Vector3i = o["head"]
	var col: Color = o["col"]
	var col2: Color = o.get("col2", col)
	var legc: Color = o.get("leg_col", col.darkened(0.15))
	var parts: Array = []
	parts.append({"size": Vector3i(bw, bh, bl), "pos": Vector3(-bw * 0.5, lh, -bl * 0.5), "col": col, "spk": o.get("spk", 0.12), "feats": o.get("body_feats", [])})
	var leg_f: Array = []
	if o.has("hoof"):
		var hoof: Color = o["hoof"]
		for f in [0, 1, 4, 5]:
			leg_f.append([f, 0, lh - 2, lw, 2, hoof])
		leg_f.append([3, 0, 0, lw, lw, hoof.darkened(0.3)])
		# Fenda do casco na frente.
		leg_f.append([5, lw / 2, lh - 2, 1, 2, hoof.darkened(0.5)])
	leg_f.append_array(o.get("leg_feats", []))
	var fx := bw * 0.5 - lw
	var legs := [[fx, -bl * 0.5, "legA"], [-bw * 0.5, -bl * 0.5, "legB"], [fx, bl * 0.5 - lw, "legB"], [-bw * 0.5, bl * 0.5 - lw, "legA"]]
	for lg: Array in legs:
		parts.append({"size": Vector3i(lw, lh, lw), "pos": Vector3(lg[0], 0, lg[1]), "pivot": Vector3(lg[0] + lw * 0.5, lh, lg[1] + lw * 0.5), "col": legc,
			"feats": leg_f, "g": lg[2]})
	var hy: float = lh + bh - hs.y * 0.55 + o.get("head_up", 0.0)
	var hz := -bl * 0.5 - hs.z + 1.0
	var hpiv := Vector3(0, hy + hs.y * 0.5, -bl * 0.5 + 1.0)
	# Olhos: esclera, pupila voltada para o centro, palpebra e brilho.
	var sclera: Color = o.get("sclera", Color(0.93, 0.91, 0.86))
	var pupil: Color = o.get("eye", Color(0.04, 0.03, 0.03))
	var ey: int = o.get("eye_y", 2)
	var eo := 1 if hs.x >= 7 else 0
	var hf: Array = []
	for i in 2:
		var x0 := eo if i == 0 else hs.x - 2 - eo
		hf.append([5, x0, ey, 2, 1, sclera])
		hf.append([5, x0 + (1 if i == 0 else 0), ey, 1, 1, pupil])
		hf.append([5, x0, ey - 1, 2, 1, col2.darkened(0.3)])
	hf.append_array(o.get("head_feats", []))
	parts.append({"size": hs, "pos": Vector3(-hs.x * 0.5, hy, hz), "pivot": hpiv, "col": col2, "feats": hf, "g": "head"})
	for ex: Dictionary in o.get("extra", []):
		var e := ex.duplicate()
		# Partes "head:" acompanham a cabeca; posicoes relativas ao canto frontal-inferior dela.
		if e.get("on_head", false):
			e["pos"] = Vector3(-hs.x * 0.5, hy, hz) + (e["pos"] as Vector3)
			e["pivot"] = hpiv
			e["g"] = "head"
		parts.append(e)
	parts = _split_limbs(parts, ["legA", "legB"], 0.5)
	return {"scale": o.get("scale", 1.0), "anim": o.get("anim", "quad"), "parts": parts,
		"back": Vector3(0, lh + bh, 0), "bw": bw, "bl": bl, "lh": lh}


## Variantes de cor por especie: [nome, cor alvo] (a primeira e a cor natural).
static var VARIANTS := {
	"vaca": [["malhada", null], ["marrom", Color(0.50, 0.32, 0.18)], ["preta", Color(0.14, 0.12, 0.11)], ["caramelo", Color(0.86, 0.64, 0.38)]],
	"porco": [["rosado", null], ["moreno", Color(0.62, 0.44, 0.36)], ["preto", Color(0.22, 0.18, 0.18)]],
	"ovelha": [["branca", null], ["cinza", Color(0.55, 0.55, 0.58)], ["preta", Color(0.16, 0.14, 0.13)], ["marrom", Color(0.48, 0.33, 0.20)]],
	"galinha": [["caipira", null], ["branca", Color(0.95, 0.94, 0.90)], ["carijó", Color(0.30, 0.28, 0.26)]],
	"coelho": [["pardo", null], ["branco", Color(0.95, 0.95, 0.93)], ["cinza", Color(0.50, 0.50, 0.52)], ["preto", Color(0.15, 0.14, 0.14)]],
	"cervo": [["comum", null], ["avermelhado", Color(0.70, 0.30, 0.16)], ["escuro", Color(0.28, 0.20, 0.14)]],
	"lobo": [["cinzento", null], ["branco", Color(0.95, 0.95, 0.95)], ["negro", Color(0.12, 0.12, 0.13)]],
	"aranha": [["comum", null], ["venenosa", Color(0.18, 0.40, 0.12)], ["roxa", Color(0.32, 0.16, 0.42)]],
	"gosma": [["verde", null], ["azul", Color(0.28, 0.50, 0.96)], ["magma", Color(0.96, 0.36, 0.08)]],
	"esqueleto": [["comum", null], ["calcinado", Color(0.22, 0.20, 0.20)]],
	"andarilho": [["comum", null], ["afogado", Color(0.30, 0.55, 0.62)], ["ressecado", Color(0.62, 0.52, 0.34)]],
	"golem": [["de pedra", null], ["de musgo", Color(0.30, 0.46, 0.22)], ["de basalto", Color(0.16, 0.16, 0.18)]],
	"espectro": [["pálido", null], ["violeta", Color(0.66, 0.52, 0.92)]],
	"cavalo": [["castanho", null], ["preto", null], ["branco", null], ["tordilho", null], ["malhado", null], ["palomino", null], ["baio", null]],
	"burro": [["cinza", null], ["pardo", null], ["escuro", null]],
	"camelo": [["dromedário", null], ["bactriano", null]],
	"cabra": [["branca", null], ["preta", null], ["malhada", null], ["montanhesa", null]],
	"raposa": [["vermelha", null], ["ártica", null], ["prateada", null]],
	"urso": [["pardo", null], ["negro", null], ["polar", null]],
	"pato": [["selvagem", null], ["branco", null], ["pardo", null]],
	"mumia": [["comum", null], ["real", null]],
	"goblin": [["verde", null], ["das cavernas", null], ["vermelho", null]],
	"ogro": [["pardo", null], ["cinza", null], ["musgo", null]],
}
## Especies com pelagem/raca desenhada por variante (sem tintura).
const PATTERNED: Array[String] = ["cavalo", "burro", "camelo", "cabra", "raposa", "urso", "pato", "mumia", "goblin", "ogro"]


static func _tint(c: Variant, target: Color) -> Variant:
	if not (c is Color):
		return c
	var col: Color = c
	if col.a < 0.01:
		return col
	var lum := col.r * 0.3 + col.g * 0.5 + col.b * 0.2
	if lum < 0.12:
		return col
	var t := col.lerp(target, 0.62)
	return Color(t.r, t.g, t.b, col.a)


## Usa os modelos do Blockbench (assets/blockbench/<especie>_<variante>.bbmodel) quando existem.
static var use_bbmodel := true


## saddle: {} sem sela, ou {"seat", "trim", "blanket", "style"} (cores e modelo).
static func mob(kind: String, variant: int = 0, saddle: Dictionary = {}) -> Dictionary:
	var vars: Array = VARIANTS.get(kind, [])
	var vname := "%s_%d" % [kind, variant % maxi(1, vars.size())]
	if use_bbmodel and kind != "aldeao" and kind != "bandido" and BBModel.exists(vname):
		var mt := BBModel.meta(vname)
		var bd := {"bbmodel": vname, "scale": float(mt.get("scale", 1.0)), "anim": str(mt.get("anim", "quad")),
			"pose": str(mt.get("pose", "")), "alpha": bool(mt.get("alpha", false)), "parts": []}
		if not saddle.is_empty() and int(mt.get("bw", 0)) > 0:
			var bk: Array = mt.get("back", [0, 0, 0])
			bd["back"] = Vector3(float(bk[0]), float(bk[1]), float(bk[2]))
			bd["bw"] = int(mt["bw"])
			bd["bl"] = int(mt.get("bl", 16))
			_add_saddle(bd, saddle)
		return bd
	var dd := _mob_variant(kind, variant)
	if not saddle.is_empty() and dd.has("back"):
		_add_saddle(dd, saddle)
	return dd


static func _mob_variant(kind: String, variant: int) -> Dictionary:
	match kind:
		"aldeao", "bandido":
			return humanoid(npc_options(kind, variant))
		"salamandra":
			var red := Color(0.80, 0.24, 0.06)
			return quad({"bw": 6, "bh": 4, "bl": 16, "lw": 2, "lh": 3, "head": Vector3i(6, 4, 6), "col": red, "col2": red.lightened(0.1), "spk": 0.15,
				"body_feats": _spots(8, Color(1.0, 0.75, 0.2), 6, 4, 16, 3), "leg_col": red.darkened(0.3),
				"head_feats": [[5, 1, 1, 1, 1, Color(1.0, 0.9, 0.2)], [5, 4, 1, 1, 1, Color(1.0, 0.9, 0.2)]],
				"extra": [{"size": Vector3i(2, 2, 10), "pos": Vector3(-1, 4, 8), "col": red, "g": "tail", "pivot": Vector3(0, 5, 8)}]})
		"chama":
			var core := Color(1.0, 0.62, 0.12)
			return {"scale": 1.0, "anim": "float", "parts": [
				{"size": Vector3i(6, 6, 6), "pos": Vector3(-3, 10, -3), "col": core, "feats": [[5, 1, 2, 1, 1, Color(0.2, 0.05, 0.0)], [5, 4, 2, 1, 1, Color(0.2, 0.05, 0.0)]]},
				{"size": Vector3i(3, 5, 3), "pos": Vector3(-1.5, 16, -1.5), "col": Color(1.0, 0.86, 0.36)},
				{"size": Vector3i(2, 6, 2), "pos": Vector3(4, 8, -1), "col": Color(0.95, 0.36, 0.06), "g": "armA", "pivot": Vector3(5, 14, 0)},
				{"size": Vector3i(2, 6, 2), "pos": Vector3(-6, 8, -1), "col": Color(0.95, 0.36, 0.06), "g": "armB", "pivot": Vector3(-5, 14, 0)},
				{"size": Vector3i(4, 4, 4), "pos": Vector3(-2, 5, -2), "col": Color(0.85, 0.25, 0.04)}]}
		"vigia":
			var shell := Color(0.24, 0.16, 0.36)
			return {"scale": 1.0, "anim": "float", "parts": [
				{"size": Vector3i(10, 10, 10), "pos": Vector3(-5, 8, -5), "col": shell, "spk": 0.1,
					"feats": [[5, 2, 2, 6, 6, Color(0.95, 0.95, 0.92)], [5, 4, 4, 2, 2, Color(0.2, 0.85, 1.0)], [5, 3, 3, 4, 1, Color(0.85, 0.85, 0.82)]]},
				{"size": Vector3i(2, 5, 2), "pos": Vector3(-1, 18, -1), "col": Color(0.55, 0.92, 1.0)},
				{"size": Vector3i(2, 4, 2), "pos": Vector3(3, 17, 2), "col": Color(0.55, 0.92, 1.0)},
				{"size": Vector3i(2, 3, 2), "pos": Vector3(-4, 17, 1), "col": Color(0.55, 0.92, 1.0)},
				{"size": Vector3i(3, 6, 2), "pos": Vector3(5, 9, -1), "col": shell.darkened(0.2), "g": "armA", "pivot": Vector3(6, 15, 0)},
				{"size": Vector3i(3, 6, 2), "pos": Vector3(-8, 9, -1), "col": shell.darkened(0.2), "g": "armB", "pivot": Vector3(-6, 15, 0)}]}
	var vars: Array = VARIANTS.get(kind, [])
	if PATTERNED.has(kind):
		return _breed(kind, variant % maxi(1, vars.size()))
	var d := _mob_base(kind)
	if vars.size() > 1 and variant % vars.size() != 0:
		var target: Color = vars[variant % vars.size()][1]
		for part: Dictionary in d["parts"]:
			part["col"] = _tint(part["col"], target)
			var feats: Array = []
			for f: Array in part.get("feats", []):
				var nf := f.duplicate()
				nf[5] = _tint(f[5], target)
				feats.append(nf)
			part["feats"] = feats
	return d


static func variant_name(kind: String, variant: int) -> String:
	var vars: Array = VARIANTS.get(kind, [])
	if vars.is_empty():
		return ""
	return vars[variant % vars.size()][0]


## Aparencia sorteada para NPCs. Aldeoes tem profissao; bandidos usam roupas escuras e bandana/capuz.
const PROFS: Array[String] = ["fazendeiro", "minerador", "caçador", "criador", "guarda", "ferreiro", "armeiro", "ferramenteiro", "lenhador", "comerciante",
	"construtor", "artesão", "alfaiate", "tecelão"]


static func npc_options(kind: String, seed_v: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var female := r.randf() < 0.5
	var o := {
		"female": female,
		"skin": SKINS[r.randi() % SKINS.size()],
		"hair": HAIRS[r.randi() % HAIRS.size()],
		"hair_style": [1, 3, 5, 0][r.randi() % 4] if female else [0, 2, 4, 5, 0][r.randi() % 5],
		"beard": 0 if female else [0, 0, 1, 2, 3, 4][r.randi() % 6],
		"eyes": [Color(0.2, 0.32, 0.55), Color(0.30, 0.20, 0.12), Color(0.2, 0.45, 0.25)][r.randi() % 3],
	}
	if kind == "bandido":
		var darks := [Color(0.16, 0.14, 0.14), Color(0.30, 0.18, 0.12), Color(0.36, 0.08, 0.08), Color(0.20, 0.22, 0.18)]
		o["shirt"] = darks[r.randi() % darks.size()]
		o["pants"] = darks[r.randi() % darks.size()].darkened(0.2)
		o["outfit"] = [0, 4][r.randi() % 2]
		o["cloth2"] = Color(0.32, 0.22, 0.14)
		o["hat"] = [4, 2][r.randi() % 2]
		o["hat_col"] = [Color(0.62, 0.10, 0.08), Color(0.12, 0.12, 0.12)][r.randi() % 2]
		o["profession"] = "bandido"
		return o
	# A profissao vem da semente (as vilas escolhem a semente conforme a construcao).
	var prof: String = PROFS[posmod(seed_v, PROFS.size())]
	o["profession"] = prof
	var dye := Blocks.DYES
	o["shirt"] = dye[r.randi() % 12].lerp(Color(0.6, 0.55, 0.45), 0.35)
	o["pants"] = [Color(0.30, 0.24, 0.18), Color(0.22, 0.24, 0.36), Color(0.36, 0.34, 0.30)][r.randi() % 3]
	var iron := Color(0.90, 0.91, 0.93)
	match prof:
		"fazendeiro":
			o["outfit"] = 1
			o["hat"] = 1 if r.randf() < 0.7 else 0
		"minerador":
			o["outfit"] = 2
			o["cloth2"] = Color(0.36, 0.34, 0.32)
			o["shirt"] = Color(0.42, 0.36, 0.26)
			o["hat"] = 3
			o["hat_col"] = Color(0.85, 0.66, 0.18)
			o["lamp"] = true
		"construtor":
			o["outfit"] = 2
			o["cloth2"] = Color(0.50, 0.34, 0.16)
			o["shirt"] = Color(0.70, 0.42, 0.14)
			o["hat"] = 3
			o["hat_col"] = Color(0.95, 0.78, 0.10)
		"artesão":
			o["outfit"] = 2
			o["cloth2"] = Color(0.22, 0.42, 0.20)
		"alfaiate":
			o["outfit"] = 3
			o["shirt"] = Color(0.42, 0.18, 0.52)
			o["cloth2"] = Color(0.80, 0.70, 0.30)
		"tecelão":
			o["outfit"] = 1
			o["hat"] = 4
			o["hat_col"] = [Color(0.20, 0.45, 0.65), Color(0.70, 0.20, 0.35)][r.randi() % 2]
		"criador":
			o["outfit"] = 4
			o["cloth2"] = Color(0.92, 0.90, 0.84)
			o["hat"] = 1 if r.randf() < 0.6 else 0
		"guarda":
			o["shirt"] = Color(0.16, 0.24, 0.52)
			o["pants"] = Color(0.18, 0.18, 0.22)
			o["armor"] = [iron, iron, null, iron]
		"armeiro":
			o["outfit"] = 3
			o["shirt"] = Color(0.46, 0.12, 0.10)
			o["armor"] = [null, Color(0.66, 0.68, 0.72), null, null]
		"ferramenteiro":
			o["outfit"] = 2
			o["cloth2"] = Color(0.44, 0.28, 0.14)
			o["hat"] = 4
			o["hat_col"] = Color(0.20, 0.30, 0.55)
		"lenhador":
			o["outfit"] = 4
			o["shirt"] = [Color(0.62, 0.12, 0.10), Color(0.20, 0.36, 0.20)][r.randi() % 2]
			o["cloth2"] = Color(0.36, 0.24, 0.12)
			o["hat"] = 3
			o["hat_col"] = Color(0.55, 0.10, 0.08)
		"comerciante":
			o["outfit"] = 3
			o["shirt"] = [Color(0.40, 0.18, 0.46), Color(0.10, 0.30, 0.40), Color(0.55, 0.40, 0.08)][r.randi() % 3]
			o["hat"] = 1
			o["hat_col"] = Color(0.40, 0.10, 0.30)
		"ferreiro":
			o["outfit"] = 2
			o["cloth2"] = Color(0.22, 0.18, 0.15)
		"pastor":
			o["outfit"] = 4
			o["cloth2"] = Color(0.92, 0.90, 0.84)
			o["hat"] = 3 if r.randf() < 0.4 else 0
			o["hat_col"] = Color(0.5, 0.3, 0.2)
		"bibliotecário":
			o["outfit"] = 3
			o["shirt"] = [Color(0.25, 0.18, 0.40), Color(0.15, 0.28, 0.22), Color(0.40, 0.12, 0.12)][r.randi() % 3]
		"caçador":
			o["outfit"] = 4
			o["cloth2"] = Color(0.40, 0.28, 0.16)
			o["hat"] = 2 if r.randf() < 0.5 else 0
			o["hat_col"] = Color(0.26, 0.34, 0.20)
		"joalheiro":
			o["outfit"] = 0
			o["shirt"] = Color(0.85, 0.80, 0.70)
			o["hat"] = 3 if r.randf() < 0.3 else 0
			o["hat_col"] = Color(0.55, 0.15, 0.40)
	return o


## Barco: casco de tabuas com bancos.
static func boat(c0: Color, c1: Color) -> Dictionary:
	var parts: Array = [
		{"size": Vector3i(14, 2, 22), "pos": Vector3(-7, 0, -11), "col": c0, "spk": 0.15},
		{"size": Vector3i(2, 5, 22), "pos": Vector3(-8, 1, -11), "col": c1, "spk": 0.15},
		{"size": Vector3i(2, 5, 22), "pos": Vector3(6, 1, -11), "col": c1, "spk": 0.15},
		{"size": Vector3i(12, 5, 2), "pos": Vector3(-6, 1, -12), "col": c1, "spk": 0.15},
		{"size": Vector3i(12, 5, 2), "pos": Vector3(-6, 1, 10), "col": c1, "spk": 0.15},
		{"size": Vector3i(12, 1, 3), "pos": Vector3(-6, 3, 2), "col": c0.darkened(0.15)},
		{"size": Vector3i(1, 1, 14), "pos": Vector3(-9, 5, -7), "col": c0.darkened(0.3), "g": "armB", "pivot": Vector3(-8, 5, 0)},
		{"size": Vector3i(1, 1, 14), "pos": Vector3(8, 5, -7), "col": c0.darkened(0.3), "g": "armA", "pivot": Vector3(8, 5, 0)},
	]
	return {"scale": 1.0, "anim": "none", "parts": parts}


# ---------------------------------------------------------------- racas novas

static func _breed(kind: String, v: int) -> Dictionary:
	var black := Color(0.06, 0.06, 0.07)
	var white := Color(0.94, 0.94, 0.92)
	match kind:
		"cavalo":
			var bases := [Color(0.45, 0.27, 0.14), Color(0.13, 0.11, 0.10), Color(0.90, 0.88, 0.84), Color(0.62, 0.62, 0.64),
				Color(0.92, 0.90, 0.86), Color(0.86, 0.66, 0.36), Color(0.64, 0.46, 0.25)]
			var manes := [Color(0.16, 0.10, 0.07), Color(0.06, 0.05, 0.05), Color(0.70, 0.70, 0.72), Color(0.25, 0.25, 0.27),
				Color(0.30, 0.20, 0.12), Color(0.96, 0.92, 0.80), Color(0.08, 0.07, 0.06)]
			var c: Color = bases[v]
			var mane: Color = manes[v]
			var bf: Array = []
			if v == 3:
				bf = _spots(16, c.darkened(0.35), 8, 9, 20, 61)
			elif v == 4:
				bf = _spots(7, Color(0.42, 0.26, 0.14), 8, 9, 20, 62)
				for f: Array in bf:
					f[3] = f[3] + 2
					f[4] = f[4] + 2
			var socks := mane if v == 6 else c.darkened(0.1)
			var hf: Array = [[5, 1, 5, 3, 1, c.darkened(0.3)], [5, 0, 4, 5, 2, c.darkened(0.15)]]
			if v == 0 or v == 4:
				hf.append([5, 2, 0, 1, 4, white])
			var ex: Array = [
				# Pescoco inclinado entre o peito e a cabeca, com crina.
				{"size": Vector3i(5, 10, 5), "pos": Vector3(-2.5, 20, -13), "col": c, "g": "head", "pivot": Vector3(0, 31.7, -9)},
				{"size": Vector3i(1, 11, 3), "pos": Vector3(-0.5, 22, -9.5), "col": mane, "g": "head", "pivot": Vector3(0, 31.7, -9), "spk": 0.25},
				{"on_head": true, "size": Vector3i(1, 2, 2), "pos": Vector3(2, 6, 6), "col": mane},
				{"on_head": true, "size": Vector3i(1, 3, 1), "pos": Vector3(0, 6, 7), "col": c.darkened(0.1), "g": "earA"},
				{"on_head": true, "size": Vector3i(1, 3, 1), "pos": Vector3(4, 6, 7), "col": c.darkened(0.1), "g": "earB"},
				# Rabo em dois segmentos.
				{"size": Vector3i(2, 3, 2), "pos": Vector3(-1, 19, 9.5), "col": mane, "g": "tailz", "pivot": Vector3(0, 22, 10), "spk": 0.25},
				{"size": Vector3i(3, 9, 2), "pos": Vector3(-1.5, 10, 10), "col": mane, "g": "tailz2", "pivot": Vector3(0, 19, 10.5), "spk": 0.3, "parent_tail": true},
			]
			return _with_tail(quad({"bw": 8, "bh": 9, "bl": 20, "lw": 3, "lh": 14, "head": Vector3i(5, 6, 9), "col": c, "col2": c, "head_up": 9.0,
				"hoof": Color(0.20, 0.17, 0.14), "eye_y": 2, "spk": 0.08, "body_feats": bf, "head_feats": hf,
				"leg_feats": [[0, 0, 9, 3, 3, socks], [1, 0, 9, 3, 3, socks], [4, 0, 9, 3, 3, socks], [5, 0, 9, 3, 3, socks]], "extra": ex}))
		"burro":
			var cs := [Color(0.52, 0.50, 0.48), Color(0.48, 0.36, 0.24), Color(0.24, 0.20, 0.18)]
			var c: Color = cs[v]
			var light := c.lightened(0.45)
			var ex: Array = [
				{"size": Vector3i(4, 8, 4), "pos": Vector3(-2, 16, -10.5), "col": c, "g": "head", "pivot": Vector3(0, 24.7, -7)},
				{"size": Vector3i(1, 8, 2), "pos": Vector3(-0.5, 17, -7.5), "col": c.darkened(0.4), "g": "head", "pivot": Vector3(0, 24.7, -7)},
				{"on_head": true, "size": Vector3i(1, 6, 1), "pos": Vector3(0, 6, 6), "col": c, "feats": [[5, 0, 1, 1, 4, light]], "g": "earA"},
				{"on_head": true, "size": Vector3i(1, 6, 1), "pos": Vector3(4, 6, 6), "col": c, "feats": [[5, 0, 1, 1, 4, light]], "g": "earB"},
				{"size": Vector3i(1, 7, 1), "pos": Vector3(-0.5, 9, 8.5), "col": c, "g": "tailz", "pivot": Vector3(0, 16, 8.5)},
				{"size": Vector3i(2, 2, 2), "pos": Vector3(-1, 8, 8), "col": c.darkened(0.4), "g": "tailz", "pivot": Vector3(0, 16, 8.5)},
			]
			return quad({"bw": 7, "bh": 8, "bl": 16, "lw": 3, "lh": 11, "head": Vector3i(5, 6, 8), "col": c, "col2": c, "head_up": 6.0,
				"hoof": Color(0.16, 0.14, 0.12), "eye_y": 2, "body_feats": [[3, 0, 0, 7, 16, light]], "head_feats": [[5, 0, 3, 5, 3, light], [5, 1, 4, 1, 1, black], [5, 3, 4, 1, 1, black]], "extra": ex})
		"camelo":
			var c := Color(0.78, 0.62, 0.40) if v == 0 else Color(0.52, 0.38, 0.24)
			var ex: Array = [
				{"size": Vector3i(4, 13, 4), "pos": Vector3(-2, 22, -12), "col": c, "g": "head", "pivot": Vector3(0, 36.7, -8)},
				{"size": Vector3i(6, 5, 6), "pos": Vector3(-3, 27, -3 if v == 0 else -6), "col": c, "spk": 0.15},
				{"size": Vector3i(1, 6, 1), "pos": Vector3(-0.5, 18, 8.5), "col": c.darkened(0.2), "g": "tailz", "pivot": Vector3(0, 24, 8.5)},
			]
			if v == 1:
				ex.append({"size": Vector3i(6, 5, 6), "pos": Vector3(-3, 27, 2), "col": c, "spk": 0.15})
				ex.append({"size": Vector3i(5, 4, 5), "pos": Vector3(-2.5, 24, -13), "col": c.darkened(0.15), "g": "head", "pivot": Vector3(0, 36.7, -8), "spk": 0.3})
			var dd := quad({"bw": 9, "bh": 9, "bl": 18, "lw": 3, "lh": 18, "head": Vector3i(5, 5, 8), "col": c, "col2": c, "head_up": 12.0,
				"hoof": c.darkened(0.4), "eye_y": 1, "head_feats": [[5, 1, 3, 3, 1, c.darkened(0.4)]], "extra": ex, "scale": 0.95})
			dd["back"] = Vector3(0, 32, 0)
			return dd
		"cabra":
			var cs := [Color(0.92, 0.90, 0.86), Color(0.16, 0.14, 0.13), Color(0.90, 0.86, 0.80), Color(0.52, 0.44, 0.34)]
			var c: Color = cs[v]
			var horn := Color(0.62, 0.56, 0.46)
			var bf: Array = _spots(8, Color(0.40, 0.26, 0.14), 6, 6, 11, 71) if v == 2 else []
			return quad({"bw": 6, "bh": 6, "bl": 11, "lw": 2, "lh": 8, "head": Vector3i(5, 5, 6), "col": c, "head_up": 3.0, "hoof": Color(0.14, 0.12, 0.10),
				"sclera": Color(0.85, 0.70, 0.30), "eye": black, "eye_y": 2, "body_feats": bf, "spk": 0.18,
				"extra": [{"on_head": true, "size": Vector3i(1, 3, 2), "pos": Vector3(0.5, 5, 3), "col": horn},
					{"on_head": true, "size": Vector3i(1, 2, 2), "pos": Vector3(0.5, 7, 5), "col": horn},
					{"on_head": true, "size": Vector3i(1, 3, 2), "pos": Vector3(3.5, 5, 3), "col": horn},
					{"on_head": true, "size": Vector3i(1, 2, 2), "pos": Vector3(3.5, 7, 5), "col": horn},
					{"on_head": true, "size": Vector3i(1, 3, 1), "pos": Vector3(2, -3, 0.5), "col": c.darkened(0.2)},
					{"on_head": true, "size": Vector3i(2, 1, 1), "pos": Vector3(-2, 3, 4), "col": c, "g": "earA"},
					{"on_head": true, "size": Vector3i(2, 1, 1), "pos": Vector3(5, 3, 4), "col": c, "g": "earB"},
					{"size": Vector3i(2, 2, 1), "pos": Vector3(-1, 13, 5.5), "col": c, "g": "tail", "pivot": Vector3(0, 13, 5.5)}]})
		"raposa":
			var cs := [Color(0.86, 0.42, 0.12), Color(0.94, 0.94, 0.92), Color(0.32, 0.32, 0.34)]
			var c: Color = cs[v]
			var chest := white if v != 1 else Color(0.85, 0.88, 0.92)
			var sock := Color(0.12, 0.10, 0.09) if v != 1 else Color(0.80, 0.80, 0.82)
			return quad({"bw": 5, "bh": 5, "bl": 12, "lw": 2, "lh": 5, "head": Vector3i(6, 5, 5), "col": c, "head_up": 1.5, "spk": 0.16,
				"sclera": Color(0.95, 0.75, 0.20), "eye": black, "eye_y": 2,
				"body_feats": [[3, 0, 0, 5, 12, chest], [5, 1, 1, 3, 4, chest]], "leg_feats": [[0, 0, 2, 2, 3, sock], [1, 0, 2, 2, 3, sock], [4, 0, 2, 2, 3, sock], [5, 0, 2, 2, 3, sock]],
				"head_feats": [[5, 0, 3, 6, 2, chest]],
				"extra": [{"on_head": true, "size": Vector3i(2, 2, 3), "pos": Vector3(2, 0, -2.5), "col": chest, "feats": [[5, 0, 0, 2, 1, black]]},
					{"on_head": true, "size": Vector3i(2, 3, 1), "pos": Vector3(0, 5, 3), "col": c, "feats": [[5, 0, 0, 2, 1, black]], "g": "earA"},
					{"on_head": true, "size": Vector3i(2, 3, 1), "pos": Vector3(4, 5, 3), "col": c, "feats": [[5, 0, 0, 2, 1, black]], "g": "earB"},
					{"size": Vector3i(3, 3, 9), "pos": Vector3(-1.5, 7, 6), "col": c, "spk": 0.25, "g": "tail", "pivot": Vector3(0, 9, 6),
						"feats": [[4, 0, 0, 3, 3, chest], [2, 0, 6, 3, 3, chest], [3, 0, 6, 3, 3, chest], [0, 6, 0, 3, 3, chest], [1, 0, 0, 3, 3, chest]]}]})
		"urso":
			var cs := [Color(0.38, 0.24, 0.14), Color(0.10, 0.09, 0.09), Color(0.94, 0.93, 0.88)]
			var c: Color = cs[v]
			var snout := c.lightened(0.25) if v != 2 else c.darkened(0.06)
			return quad({"bw": 12, "bh": 11, "bl": 18, "lw": 5, "lh": 8, "head": Vector3i(9, 8, 8), "col": c, "head_up": 0.0, "spk": 0.22,
				"sclera": Color(0.25, 0.15, 0.08), "eye": black, "eye_y": 3, "leg_feats": [[3, 0, 0, 5, 5, c.darkened(0.3)]],
				"body_feats": _spots(10, c.darkened(0.12), 12, 11, 18, 81),
				"extra": [{"on_head": true, "size": Vector3i(5, 4, 3), "pos": Vector3(2, 0, -2.5), "col": snout, "feats": [[5, 1, 0, 3, 2, black], [5, 2, 3, 1, 1, c.darkened(0.3)]]},
					{"on_head": true, "size": Vector3i(3, 3, 2), "pos": Vector3(-1, 7, 4), "col": c, "feats": [[5, 1, 1, 1, 1, c.darkened(0.4)]]},
					{"on_head": true, "size": Vector3i(3, 3, 2), "pos": Vector3(7, 7, 4), "col": c, "feats": [[5, 1, 1, 1, 1, c.darkened(0.4)]]},
					{"size": Vector3i(12, 5, 6), "pos": Vector3(-6, 15, -9), "col": c, "spk": 0.3},
					{"size": Vector3i(3, 3, 2), "pos": Vector3(-1.5, 15, 9), "col": c, "g": "tail"}]})
		"pato":
			var head_c: Color = [Color(0.06, 0.40, 0.20), Color(0.96, 0.96, 0.94), Color(0.48, 0.34, 0.20)][v]
			var body_c: Color = [Color(0.62, 0.58, 0.52), Color(0.96, 0.96, 0.94), Color(0.52, 0.38, 0.24)][v]
			var breast: Color = [Color(0.48, 0.26, 0.18), Color(0.94, 0.94, 0.92), Color(0.62, 0.48, 0.32)][v]
			var bill := Color(0.95, 0.68, 0.16) if v != 0 else Color(0.85, 0.75, 0.25)
			var leg := Color(0.95, 0.55, 0.12)
			var hp := Vector3(0, 8, -3)
			var parts: Array = [
				{"size": Vector3i(5, 4, 8), "pos": Vector3(-2.5, 3, -4), "col": body_c, "spk": 0.1, "feats": [[5, 0, 0, 5, 3, breast], [2, 1, 5, 3, 3, body_c.darkened(0.2)]]},
				{"size": Vector3i(1, 3, 2), "pos": Vector3(-0.5, 5, 3.5), "col": body_c.darkened(0.3), "g": "tail", "pivot": Vector3(0, 6, 4)},
				{"size": Vector3i(1, 3, 1), "pos": Vector3(1, 0, -0.5), "pivot": Vector3(1.5, 3, 0), "col": leg, "g": "legA"},
				{"size": Vector3i(3, 1, 3), "pos": Vector3(0, 0, -2.5), "pivot": Vector3(1.5, 3, 0), "col": leg, "g": "legA"},
				{"size": Vector3i(1, 3, 1), "pos": Vector3(-2, 0, -0.5), "pivot": Vector3(-1.5, 3, 0), "col": leg, "g": "legB"},
				{"size": Vector3i(3, 1, 3), "pos": Vector3(-3, 0, -2.5), "pivot": Vector3(-1.5, 3, 0), "col": leg, "g": "legB"},
				{"size": Vector3i(1, 3, 6), "pos": Vector3(2.5, 4, -2), "pivot": Vector3(2.5, 7, 0), "col": body_c.darkened(0.1), "feats": [[0, 0, 1, 2, 1, Color(0.2, 0.3, 0.8)]], "g": "wingA"},
				{"size": Vector3i(1, 3, 6), "pos": Vector3(-3.5, 4, -2), "pivot": Vector3(-2.5, 7, 0), "col": body_c.darkened(0.1), "feats": [[1, 0, 1, 2, 1, Color(0.2, 0.3, 0.8)]], "g": "wingB"},
				{"size": Vector3i(3, 5, 3), "pos": Vector3(-1.5, 6, -5.5), "pivot": hp, "col": head_c, "g": "head",
					"feats": [[5, 0, 1, 1, 1, black], [5, 2, 1, 1, 1, black], [0, 1, 1, 1, 1, black], [1, 1, 1, 1, 1, black], [5, 0, 4, 3, 1, white if v == 0 else head_c]]},
				{"size": Vector3i(3, 1, 3), "pos": Vector3(-1.5, 8, -8), "pivot": hp, "col": bill, "g": "head"},
			]
			return {"scale": 0.85, "anim": "bird", "parts": parts}
		"mumia", "goblin", "ogro":
			return _monster(kind, v)
	return _mob_base(kind)


## Rabo de dois segmentos: o segundo pende do primeiro.
static func _with_tail(dd: Dictionary) -> Dictionary:
	var parts: Array = dd["parts"]
	var t1 := -1
	for i in parts.size():
		var p: Dictionary = parts[i]
		if p.get("g", "") == "tailz" and t1 < 0:
			t1 = i
		if p.get("parent_tail", false) and t1 >= 0:
			p["parent_i"] = t1
			p.erase("parent_tail")
	return dd


static func _monster(kind: String, v: int) -> Dictionary:
	var black := Color(0.06, 0.06, 0.07)
	match kind:
		"mumia":
			var band := Color(0.80, 0.74, 0.56) if v == 0 else Color(0.84, 0.78, 0.58)
			var dark := band.darkened(0.3)
			var lines: Array = []
			for k in 5:
				lines.append([5, 0, 1 + k * 2, 10, 1, dark])
			var tl: Array = []
			for k in 5:
				tl.append([5, 0, k * 2 + (k % 2), 9, 1, dark])
				tl.append([4, 0, k * 2, 9, 1, dark])
			var ll: Array = [[5, 0, 2, 4, 1, dark], [5, 0, 5, 4, 1, dark], [5, 0, 8, 4, 1, dark], [0, 0, 3, 4, 1, dark], [1, 0, 6, 4, 1, dark]]
			var eye := Color(0.4, 1.0, 0.6) if v == 0 else Color(1.0, 0.8, 0.2)
			var d := humanoid({"plain": true, "skin": band, "shirt": band, "pants": band, "eyes": eye, "mouth": dark, "pose": "reach", "arm_w": 3,
				"head_feats": lines + [[5, 2, 4, 2, 1, eye], [5, 6, 4, 2, 1, eye], [5, 2, 3, 6, 1, black]], "torso_feats": tl, "limb_feats": ll})
			if v == 1:
				var gold := Color(0.95, 0.75, 0.20)
				var parts: Array = d["parts"]
				parts.append({"size": Vector3i(10, 3, 1), "pos": Vector3(-5, 20, -3.2), "col": gold, "feats": [[5, 2, 1, 6, 1, Color(0.2, 0.4, 0.9)]]})
				parts.append({"size": Vector3i(10, 4, 2), "pos": Vector3(-5, 22, -5.2), "pivot": Vector3(0, 21, 0), "col": gold, "g": "head",
					"feats": [[5, 2, 1, 2, 1, black], [5, 6, 1, 2, 1, black], [5, 4, 3, 2, 1, Color(0.2, 0.4, 0.9)]]})
			return d
		"goblin":
			var skins := [Color(0.36, 0.55, 0.20), Color(0.40, 0.46, 0.52), Color(0.70, 0.24, 0.16)]
			var sk: Color = skins[v]
			var cloth := Color(0.36, 0.26, 0.16)
			var d := humanoid({"plain": true, "skin": sk, "shirt": cloth, "pants": cloth.darkened(0.3), "eyes": Color(1.0, 0.85, 0.1), "mouth": black,
				"arm_w": 3, "leg_w": 3, "torso_w": 8, "scale": 0.68,
				"head_feats": [[5, 2, 3, 2, 1, Color(1.0, 0.85, 0.1)], [5, 6, 3, 2, 1, Color(1.0, 0.85, 0.1)], [5, 3, 6, 4, 1, black], [5, 3, 7, 1, 1, Color(0.95, 0.95, 0.85)], [5, 6, 7, 1, 1, Color(0.95, 0.95, 0.85)]],
				"torso_feats": [[5, 0, 9, 3, 1, Color(0, 0, 0, 0)], [5, 5, 9, 2, 1, Color(0, 0, 0, 0)], [5, 1, 3, 2, 2, cloth.darkened(0.3)]]})
			var parts: Array = d["parts"]
			var hp := Vector3(0, 21, 0)
			parts.append({"size": Vector3i(4, 3, 1), "pos": Vector3(5, 25, -1), "pivot": hp, "col": sk, "g": "head"})
			parts.append({"size": Vector3i(4, 3, 1), "pos": Vector3(-9, 25, -1), "pivot": hp, "col": sk, "g": "head"})
			parts.append({"size": Vector3i(2, 3, 2), "pos": Vector3(-1, 23, -6.5), "pivot": hp, "col": sk.darkened(0.1), "g": "head"})
			return d
		"ogro":
			var skins := [Color(0.58, 0.48, 0.30), Color(0.52, 0.52, 0.50), Color(0.40, 0.50, 0.28)]
			var sk: Color = skins[v]
			var hide := Color(0.40, 0.28, 0.16)
			var d := humanoid({"plain": true, "skin": sk, "shirt": sk, "pants": hide, "eyes": Color(0.9, 0.2, 0.1), "mouth": black,
				"arm_w": 5, "leg_w": 5, "torso_w": 12, "scale": 1.6,
				"head_feats": [[5, 2, 3, 2, 1, Color(0.9, 0.2, 0.1)], [5, 6, 3, 2, 1, Color(0.9, 0.2, 0.1)], [5, 2, 2, 6, 1, sk.darkened(0.35)], [5, 2, 6, 6, 1, black]],
				"torso_feats": [[5, 0, 7, 12, 3, hide], [4, 0, 7, 12, 3, hide], [5, 4, 2, 4, 3, sk.darkened(0.15)], [0, 0, 0, 5, 9, Color(0, 0, 0, 0)]]})
			var parts: Array = d["parts"]
			var hp := Vector3(0, 21, 0)
			parts.append({"size": Vector3i(1, 2, 1), "pos": Vector3(-3, 21, -5.2), "pivot": hp, "col": Color(0.95, 0.93, 0.85), "g": "head"})
			parts.append({"size": Vector3i(1, 2, 1), "pos": Vector3(2, 21, -5.2), "pivot": hp, "col": Color(0.95, 0.93, 0.85), "g": "head"})
			return d
	return _mob_base(kind)


## Sela sobre o lombo: manta, assento, arcos, estribos e acessorios do modelo.
static func _add_saddle(dd: Dictionary, sd: Dictionary) -> void:
	var parts: Array = dd["parts"]
	var back: Vector3 = dd["back"]
	var bw: int = dd["bw"]
	var seat: Color = sd.get("seat", Color(0.36, 0.20, 0.10))
	var trim: Color = sd.get("trim", Color(0.24, 0.16, 0.10))
	var blanket: Color = sd.get("blanket", Color(0.60, 0.12, 0.10))
	var style: String = sd.get("style", "")
	var y := back.y
	var bwh := bw * 0.5
	parts.append({"size": Vector3i(bw + 2, 1, 9), "pos": Vector3(-bwh - 1, y - 0.6, -4.5), "col": blanket, "infl": 0.02,
		"feats": [[0, 0, 0, 9, 1, trim], [1, 0, 0, 9, 1, trim], [4, 0, 0, bw + 2, 1, trim], [5, 0, 0, bw + 2, 1, trim]]})
	parts.append({"size": Vector3i(1, 4, 7), "pos": Vector3(-bwh - 1, y - 4, -3.5), "col": blanket, "feats": [[1, 0, 3, 7, 1, trim]]})
	parts.append({"size": Vector3i(1, 4, 7), "pos": Vector3(bwh, y - 4, -3.5), "col": blanket, "feats": [[0, 0, 3, 7, 1, trim]]})
	parts.append({"size": Vector3i(bw - 2, 1, 6), "pos": Vector3(-bwh + 1, y + 0.4, -3), "col": seat, "spk": 0.08,
		"feats": [[2, 1, 1, bw - 4, 4, seat.lightened(0.12)]]})
	parts.append({"size": Vector3i(bw - 2, 2, 1), "pos": Vector3(-bwh + 1, y + 0.4, 2.2), "col": seat.darkened(0.1), "feats": [[2, 0, 0, bw - 2, 1, trim]]})
	parts.append({"size": Vector3i(2, 3, 1), "pos": Vector3(-1, y + 0.4, -3.6), "col": seat.darkened(0.1), "feats": [[2, 0, 0, 2, 1, trim]]})
	for sx in [-1, 1]:
		var x: float = sx * (bwh + 1.2) - 0.5
		parts.append({"size": Vector3i(1, 7, 1), "pos": Vector3(x, y - 7, -0.5), "col": seat.darkened(0.3)})
		parts.append({"size": Vector3i(1, 1, 3), "pos": Vector3(x, y - 8, -1.5), "col": trim, "feats": [[2, 0, 1, 1, 1, Color(0, 0, 0, 0)]]})
	match style:
		"viagem":
			for sx in [-1, 1]:
				var x: float = sx * (bwh + 1.5) - (1.5 if sx > 0 else 1.5)
				parts.append({"size": Vector3i(3, 4, 4), "pos": Vector3(x if sx > 0 else x - 0.5, y - 4, 3), "col": seat.lightened(0.05),
					"feats": [[0, 0, 0, 4, 1, trim], [1, 0, 0, 4, 1, trim], [5, 1, 1, 1, 1, trim]]})
			parts.append({"size": Vector3i(bw, 2, 2), "pos": Vector3(-bwh, y + 0.5, 3.4), "col": Color(0.62, 0.56, 0.42), "spk": 0.25})
		"guerra":
			parts.append({"size": Vector3i(bw + 1, 5, 1), "pos": Vector3(-bwh - 0.5, y - 9, -dd["bl"] * 0.5 - 1.2), "col": trim,
				"feats": [[5, 1, 1, bw - 1, 1, trim.lightened(0.3)], [5, int(bwh) - 1, 2, 2, 2, blanket]]})
			for sx in [-1, 1]:
				parts.append({"size": Vector3i(1, 6, 12), "pos": Vector3(sx * (bwh + 1.4) - 0.5, y - 6, -6), "col": blanket,
					"feats": [[0 if sx > 0 else 1, 0, 5, 12, 1, trim], [0 if sx > 0 else 1, 5, 1, 2, 3, trim.lightened(0.2)]]})
		"cerimonial":
			for k in 4:
				parts.append({"size": Vector3i(1, 2, 1), "pos": Vector3(-bwh - 1.2 + (bw + 1.4) * (k % 2), y - 6.5, -3 + 5 * (k / 2)), "col": trim})


static func _mob_base(kind: String) -> Dictionary:
	var black := Color(0.06, 0.06, 0.07)
	var white := Color(0.94, 0.94, 0.92)
	match kind:
		"vaca":
			var pinkc := Color(0.90, 0.64, 0.64)
			var spot := Color(0.12, 0.10, 0.09)
			return quad({"bw": 12, "bh": 10, "bl": 18, "lw": 4, "lh": 11, "head": Vector3i(8, 8, 6), "col": white, "col2": white, "spk": 0.06,
				"body_feats": _spots(9, spot, 12, 10, 18, 5), "leg_col": Color(0.85, 0.85, 0.83), "hoof": Color(0.22, 0.18, 0.16), "eye_y": 3,
				"head_feats": [[5, 0, 0, 3, 3, spot], [2, 0, 0, 8, 2, spot], [2, 3, 2, 2, 2, Color(0.88, 0.86, 0.82)]],
				"extra": [{"on_head": true, "size": Vector3i(1, 3, 1), "pos": Vector3(-1, 7, 3), "col": Color(0.85, 0.82, 0.70), "feats": [[2, 0, 0, 1, 1, Color(0.4, 0.36, 0.3)]]},
					{"on_head": true, "size": Vector3i(1, 3, 1), "pos": Vector3(8, 7, 3), "col": Color(0.85, 0.82, 0.70), "feats": [[2, 0, 0, 1, 1, Color(0.4, 0.36, 0.3)]]},
					# Orelhas para os lados, com o interior rosado.
					{"on_head": true, "size": Vector3i(3, 2, 1), "pos": Vector3(-3, 5, 3), "col": white, "feats": [[5, 0, 0, 2, 2, pinkc]], "g": "earA"},
					{"on_head": true, "size": Vector3i(3, 2, 1), "pos": Vector3(8, 5, 3), "col": white, "feats": [[5, 1, 0, 2, 2, pinkc]], "g": "earB"},
					# Focinho saliente com narinas.
					{"on_head": true, "size": Vector3i(6, 4, 2), "pos": Vector3(1, 0, -1.5), "col": pinkc, "spk": 0.05,
						"feats": [[5, 1, 1, 1, 1, Color(0.30, 0.16, 0.16)], [5, 4, 1, 1, 1, Color(0.30, 0.16, 0.16)], [5, 1, 3, 4, 1, pinkc.darkened(0.15)]]},
					# Ubere com tetas.
					{"size": Vector3i(5, 2, 4), "pos": Vector3(-2.5, 9, 3), "col": pinkc, "feats": [[3, 0, 0, 1, 1, pinkc.darkened(0.2)], [3, 4, 0, 1, 1, pinkc.darkened(0.2)], [3, 0, 3, 1, 1, pinkc.darkened(0.2)], [3, 4, 3, 1, 1, pinkc.darkened(0.2)]]},
					{"size": Vector3i(1, 1, 1), "pos": Vector3(-2, 8, 3.5), "col": pinkc.darkened(0.1)},
					{"size": Vector3i(1, 1, 1), "pos": Vector3(1, 8, 3.5), "col": pinkc.darkened(0.1)},
					{"size": Vector3i(1, 1, 1), "pos": Vector3(-2, 8, 5.5), "col": pinkc.darkened(0.1)},
					{"size": Vector3i(1, 1, 1), "pos": Vector3(1, 8, 5.5), "col": pinkc.darkened(0.1)},
					# Rabo pendente com tufo.
					{"size": Vector3i(1, 9, 1), "pos": Vector3(-0.5, 11, 8.6), "pivot": Vector3(0, 20, 9), "col": white, "g": "tailz"},
					{"size": Vector3i(2, 3, 2), "pos": Vector3(-1, 9, 8.1), "pivot": Vector3(0, 20, 9), "col": spot, "spk": 0.25, "g": "tailz"}]})
		"porco":
			var pink := Color(0.93, 0.62, 0.62)
			var dpink := Color(0.80, 0.46, 0.48)
			return quad({"bw": 10, "bh": 8, "bl": 15, "lw": 4, "lh": 6, "head": Vector3i(8, 8, 8), "col": pink, "head_up": 1.0, "hoof": Color(0.46, 0.30, 0.28),
				"body_feats": [[2, 2, 2, 6, 10, pink.lightened(0.06)], [0, 4, 6, 3, 1, dpink], [1, 6, 6, 3, 1, dpink]], "eye_y": 3, "sclera": Color(0.95, 0.88, 0.86),
				"head_feats": [[5, 1, 6, 6, 1, dpink]],
				"extra": [{"on_head": true, "size": Vector3i(4, 3, 1), "pos": Vector3(2, 1, -1), "col": Color(0.86, 0.52, 0.54),
						"feats": [[5, 0, 1, 1, 1, Color(0.4, 0.2, 0.2)], [5, 3, 1, 1, 1, Color(0.4, 0.2, 0.2)], [5, 1, 0, 2, 1, Color(0.95, 0.66, 0.66)]]},
					# Orelhas caidas sobre os olhos.
					{"on_head": true, "size": Vector3i(3, 1, 3), "pos": Vector3(0, 7, 0), "col": dpink, "g": "earA"},
					{"on_head": true, "size": Vector3i(3, 1, 3), "pos": Vector3(5, 7, 0), "col": dpink, "g": "earB"},
					{"on_head": true, "size": Vector3i(2, 2, 1), "pos": Vector3(0.5, 5.5, -0.5), "col": dpink},
					{"on_head": true, "size": Vector3i(2, 2, 1), "pos": Vector3(5.5, 5.5, -0.5), "col": dpink},
					# Rabinho enrolado.
					{"size": Vector3i(1, 1, 2), "pos": Vector3(-0.5, 11, 7.5), "col": dpink, "g": "tail", "pivot": Vector3(0, 11.5, 7.5)},
					{"size": Vector3i(1, 2, 1), "pos": Vector3(0.5, 11, 9), "col": dpink, "g": "tail", "pivot": Vector3(0, 11.5, 7.5)},
					{"size": Vector3i(1, 1, 1), "pos": Vector3(-0.5, 12.5, 9), "col": dpink, "g": "tail", "pivot": Vector3(0, 11.5, 7.5)}]})
		"ovelha":
			var face := Color(0.30, 0.25, 0.22)
			var wool_f: Array = _spots(14, white.darkened(0.07), 8, 7, 14, 9)
			wool_f.append_array(_spots(8, white.lightened(0.5), 8, 7, 14, 21))
			return quad({"bw": 8, "bh": 7, "bl": 14, "lw": 3, "lh": 10, "head": Vector3i(6, 6, 7), "col": face, "col2": face, "head_up": 1.0,
				"hoof": Color(0.10, 0.09, 0.08), "eye_y": 2, "sclera": Color(0.80, 0.70, 0.40),
				"head_feats": [[5, 2, 4, 2, 1, Color(0.12, 0.10, 0.09)], [5, 1, 5, 4, 1, face.lightened(0.1)]],
				"extra": [{"size": Vector3i(8, 7, 14), "pos": Vector3(-4, 10, -7), "col": white, "spk": 0.2, "infl": 0.32, "feats": wool_f},
					# Touca de la na cabeca e "calcas" de la nas coxas.
					{"on_head": true, "size": Vector3i(6, 2, 5), "pos": Vector3(0, 5, 2), "col": white, "spk": 0.22, "infl": 0.12},
					{"on_head": true, "size": Vector3i(2, 1, 3), "pos": Vector3(-2, 3, 3), "col": face.darkened(0.1), "g": "earA"},
					{"on_head": true, "size": Vector3i(2, 1, 3), "pos": Vector3(6, 3, 3), "col": face.darkened(0.1), "g": "earB"},
					{"size": Vector3i(3, 3, 3), "pos": Vector3(1, 7.5, -7), "col": white, "spk": 0.2, "infl": 0.15},
					{"size": Vector3i(3, 3, 3), "pos": Vector3(-4, 7.5, -7), "col": white, "spk": 0.2, "infl": 0.15},
					{"size": Vector3i(3, 3, 3), "pos": Vector3(1, 7.5, 4), "col": white, "spk": 0.2, "infl": 0.15},
					{"size": Vector3i(3, 3, 3), "pos": Vector3(-4, 7.5, 4), "col": white, "spk": 0.2, "infl": 0.15},
					{"size": Vector3i(2, 3, 2), "pos": Vector3(-1, 13, 7.5), "col": white, "spk": 0.2, "g": "tailz", "pivot": Vector3(0, 16, 7.5)}]})
		"galinha":
			# Ave bipede: 2 pernas com pes, 2 asas articuladas, cabeca com bico, crista e barbela.
			# Galinha caipira: plumagem castanha pintada, peito claro, cauda escura em leque.
			var yel := Color(0.90, 0.62, 0.16)
			var red := Color(0.80, 0.12, 0.10)
			var plum := Color(0.62, 0.34, 0.16)
			var breast := Color(0.86, 0.66, 0.42)
			var dark := Color(0.16, 0.12, 0.10)
			var wing := plum.darkened(0.15)
			var hp := Vector3(0, 10, -3)
			var body_f: Array = [[5, 1, 1, 4, 5, breast], [3, 1, 0, 4, 4, breast]]
			body_f.append_array(_spots(10, plum.darkened(0.35), 6, 6, 8, 11))
			var parts: Array = [
				{"size": Vector3i(6, 6, 8), "pos": Vector3(-3, 5, -4), "col": plum, "spk": 0.1, "feats": body_f},
				# Cauda em leque: tres penas escuras levantadas.
				{"size": Vector3i(2, 6, 2), "pos": Vector3(-1, 9, 3), "col": dark, "g": "tail", "pivot": Vector3(0, 9, 4)},
				{"size": Vector3i(1, 5, 2), "pos": Vector3(-2.5, 8.5, 3.5), "col": dark.lightened(0.1), "g": "tail", "pivot": Vector3(0, 9, 4)},
				{"size": Vector3i(1, 5, 2), "pos": Vector3(1.5, 8.5, 3.5), "col": dark.lightened(0.1), "g": "tail", "pivot": Vector3(0, 9, 4)},
				# Pernas (canela fina) e pes abertos para a frente.
				{"size": Vector3i(1, 5, 1), "pos": Vector3(1, 0, -0.5), "pivot": Vector3(1.5, 5, 0), "col": yel, "g": "legA"},
				{"size": Vector3i(3, 1, 3), "pos": Vector3(0, 0, -2.5), "pivot": Vector3(1.5, 5, 0), "col": yel, "g": "legA"},
				{"size": Vector3i(1, 5, 1), "pos": Vector3(-2, 0, -0.5), "pivot": Vector3(-1.5, 5, 0), "col": yel, "g": "legB"},
				{"size": Vector3i(3, 1, 3), "pos": Vector3(-3, 0, -2.5), "pivot": Vector3(-1.5, 5, 0), "col": yel, "g": "legB"},
				# Asas presas na lateral do corpo, articuladas pela borda de cima.
				{"size": Vector3i(1, 4, 6), "pos": Vector3(3, 6, -3), "pivot": Vector3(3, 10, 0), "col": wing,
					"feats": [[0, 0, 2, 6, 2, dark], [0, 0, 0, 6, 1, plum]], "g": "wingA"},
				{"size": Vector3i(1, 4, 6), "pos": Vector3(-4, 6, -3), "pivot": Vector3(-3, 10, 0), "col": wing,
					"feats": [[1, 0, 2, 6, 2, dark], [1, 0, 0, 6, 1, plum]], "g": "wingB"},
				# Cabeca menor e mais alta, bico curto, barbela pequena e crista serrilhada.
				{"size": Vector3i(4, 5, 4), "pos": Vector3(-2, 10, -6.5), "pivot": hp, "col": plum.lightened(0.1), "g": "head",
					"feats": [[5, 0, 1, 1, 1, black], [5, 3, 1, 1, 1, black], [0, 1, 1, 1, 1, black], [1, 2, 1, 1, 1, black],
						[5, 0, 3, 4, 2, breast]]},
				{"size": Vector3i(2, 1, 2), "pos": Vector3(-1, 12, -8), "pivot": hp, "col": yel, "g": "head"},
				{"size": Vector3i(1, 2, 1), "pos": Vector3(-0.5, 10, -7), "pivot": hp, "col": red, "g": "head"},
				{"size": Vector3i(1, 2, 1), "pos": Vector3(-0.5, 15, -6), "pivot": hp, "col": red, "g": "head"},
				{"size": Vector3i(1, 3, 1), "pos": Vector3(-0.5, 15, -5), "pivot": hp, "col": red, "g": "head"},
				{"size": Vector3i(1, 2, 1), "pos": Vector3(-0.5, 15, -4), "pivot": hp, "col": red, "g": "head"},
			]
			return {"scale": 0.8, "anim": "bird", "parts": parts}
		"coelho":
			var fur := Color(0.72, 0.60, 0.46)
			var pk := Color(0.92, 0.62, 0.64)
			return quad({"bw": 5, "bh": 5, "bl": 8, "lw": 2, "lh": 3, "head": Vector3i(5, 5, 5), "col": fur, "head_up": 2.0, "scale": 0.8, "eye_y": 2,
				"sclera": Color(0.25, 0.14, 0.08), "eye": Color(0.03, 0.02, 0.02),
				"body_feats": [[3, 0, 0, 5, 8, fur.lightened(0.3)], [5, 1, 2, 3, 3, fur.lightened(0.25)]],
				"head_feats": [[5, 1, 3, 3, 2, fur.lightened(0.35)], [5, 2, 3, 1, 1, pk]],
				"extra": [{"on_head": true, "size": Vector3i(2, 6, 1), "pos": Vector3(-0.5, 5, 3), "col": fur, "feats": [[5, 0, 1, 1, 4, pk]], "g": "earA", "pivot": Vector3(0, 5, 3.5)},
					{"on_head": true, "size": Vector3i(2, 6, 1), "pos": Vector3(3.5, 5, 3), "col": fur, "feats": [[5, 1, 1, 1, 4, pk]], "g": "earB", "pivot": Vector3(5, 5, 3.5)},
					# Patas traseiras grandes.
					{"size": Vector3i(2, 2, 4), "pos": Vector3(1.5, 0, 1), "col": fur.darkened(0.1), "feats": [[3, 0, 0, 2, 4, fur.lightened(0.3)]]},
					{"size": Vector3i(2, 2, 4), "pos": Vector3(-3.5, 0, 1), "col": fur.darkened(0.1), "feats": [[3, 0, 0, 2, 4, fur.lightened(0.3)]]},
					{"size": Vector3i(3, 3, 2), "pos": Vector3(-1.5, 5, 4), "col": white, "spk": 0.2, "g": "tail"}]})
		"cervo":
			var tan := Color(0.60, 0.40, 0.22)
			var horn := Color(0.86, 0.80, 0.66)
			var cream := Color(0.92, 0.86, 0.74)
			var ant: Array = []
			for sd in [-1, 1]:
				var bx := 0 if sd < 0 else 5
				ant.append({"on_head": true, "size": Vector3i(1, 5, 1), "pos": Vector3(bx, 7, 5), "col": horn})
				ant.append({"on_head": true, "size": Vector3i(3, 1, 1), "pos": Vector3(bx + (-2 if sd < 0 else 0), 10, 5), "col": horn})
				ant.append({"on_head": true, "size": Vector3i(1, 4, 1), "pos": Vector3(bx + 2 * sd, 11, 5), "col": horn})
				ant.append({"on_head": true, "size": Vector3i(1, 3, 1), "pos": Vector3(bx, 12, 4), "col": horn})
				ant.append({"on_head": true, "size": Vector3i(1, 1, 3), "pos": Vector3(bx + 2 * sd, 13, 3), "col": horn.lightened(0.15)})
				ant.append({"on_head": true, "size": Vector3i(2, 3, 1), "pos": Vector3(bx + (-2 if sd < 0 else 1), 5, 6), "col": tan, "feats": [[5, 0, 0, 2, 2, cream]], "g": "earA" if sd < 0 else "earB"})
			ant.append({"size": Vector3i(4, 8, 4), "pos": Vector3(-2, 20, -9), "col": tan, "g": "head", "pivot": Vector3(0, 21, -7), "feats": [[5, 1, 0, 2, 8, cream]]})
			ant.append({"size": Vector3i(3, 4, 2), "pos": Vector3(-1.5, 18, 7.5), "col": white, "g": "tailz", "pivot": Vector3(0, 22, 8)})
			ant.append({"on_head": true, "size": Vector3i(4, 3, 2), "pos": Vector3(1, 0, -1.5), "col": tan.darkened(0.1), "feats": [[5, 1, 0, 2, 1, black], [3, 0, 0, 4, 2, cream]]})
			return quad({"bw": 8, "bh": 8, "bl": 16, "lw": 3, "lh": 13, "head": Vector3i(6, 7, 8), "col": tan, "head_up": 7.0, "hoof": Color(0.16, 0.12, 0.10), "eye_y": 3,
				"body_feats": [[3, 0, 0, 8, 16, cream], [4, 1, 0, 6, 5, white]] + _spots(6, tan.lightened(0.18), 8, 8, 16, 41), "head_feats": [[5, 1, 5, 4, 2, cream]],
				"extra": ant})
		"lobo":
			var grey := Color(0.56, 0.57, 0.60)
			var light := Color(0.82, 0.82, 0.84)
			return quad({"bw": 7, "bh": 7, "bl": 15, "lw": 3, "lh": 8, "head": Vector3i(7, 6, 6), "col": grey, "head_up": 2.0,
				"sclera": Color(0.92, 0.70, 0.12), "eye": Color(0.05, 0.04, 0.02), "eye_y": 2, "spk": 0.2,
				"body_feats": [[3, 0, 0, 7, 15, light], [2, 2, 0, 3, 15, grey.darkened(0.3)]] + _spots(10, grey.darkened(0.15), 7, 7, 15, 17),
				"leg_feats": [[5, 0, 6, 3, 2, light]],
				"head_feats": [[5, 0, 4, 7, 2, light], [2, 2, 0, 3, 6, grey.darkened(0.3)]],
				"extra": [{"on_head": true, "size": Vector3i(3, 3, 4), "pos": Vector3(2, 0, -3), "col": light,
						"feats": [[5, 1, 0, 1, 1, black], [3, 0, 0, 3, 4, light.lightened(0.1)], [5, 0, 2, 3, 1, Color(0.3, 0.3, 0.32)]]},
					{"on_head": true, "size": Vector3i(2, 3, 1), "pos": Vector3(0, 6, 4), "col": grey, "feats": [[5, 0, 1, 1, 2, Color(0.4, 0.3, 0.3)]], "g": "earA"},
					{"on_head": true, "size": Vector3i(2, 3, 1), "pos": Vector3(5, 6, 4), "col": grey, "feats": [[5, 1, 1, 1, 2, Color(0.4, 0.3, 0.3)]], "g": "earB"},
					# Juba no pescoco.
					{"size": Vector3i(9, 7, 3), "pos": Vector3(-4.5, 8.5, -8.5), "col": light.darkened(0.05), "spk": 0.25},
					{"size": Vector3i(3, 3, 8), "pos": Vector3(-1.5, 11, 7), "col": grey, "g": "tail", "pivot": Vector3(0, 13, 7), "spk": 0.25,
						"feats": [[4, 0, 0, 3, 3, light], [2, 0, 6, 3, 2, light], [3, 0, 6, 3, 2, light]]}]})
		"andarilho":
			var rot := Color(0.38, 0.52, 0.36)
			return humanoid({"skin": rot, "hair": Color(0.16, 0.2, 0.14), "shirt": Color(0.24, 0.34, 0.40), "pants": Color(0.22, 0.20, 0.30), "eyes": black,
				"mouth": Color(0.15, 0.2, 0.14), "pose": "reach", "arm_w": 4,
				"head_feats": [[5, 6, 5, 2, 2, rot.darkened(0.3)], [5, 1, 1, 2, 1, Color(0.28, 0.12, 0.10)], [5, 4, 7, 3, 1, Color(0.85, 0.80, 0.62)]],
				"torso_feats": [[5, 1, 4, 3, 3, rot.darkened(0.25)], [5, 5, 8, 2, 2, rot.darkened(0.25)], [4, 2, 5, 4, 2, rot.darkened(0.25)],
					[5, 0, 11, 2, 1, CLEAR], [5, 4, 10, 1, 2, CLEAR], [5, 7, 11, 2, 1, CLEAR], [4, 2, 11, 3, 1, CLEAR],
					[5, 2, 6, 3, 1, Color(0.80, 0.76, 0.60)], [5, 2, 7, 3, 1, rot.darkened(0.35)], [5, 2, 8, 3, 1, Color(0.80, 0.76, 0.60)]]})
		"esqueleto":
			var bone := Color(0.88, 0.86, 0.78)
			var dk := Color(0.10, 0.10, 0.11)
			return humanoid({"plain": true, "skin": bone, "shirt": bone, "pants": bone, "eyes": dk, "mouth": dk, "arm_w": 2, "leg_w": 2,
				"torso_w": 8, "head_feats": [[5, 2, 3, 2, 3, dk], [5, 6, 3, 2, 3, dk], [5, 4, 6, 1, 1, dk], [5, 3, 7, 4, 1, dk]],
				"torso_feats": [[5, 1, 1, 6, 1, dk], [5, 1, 3, 6, 1, dk], [5, 1, 5, 6, 1, dk], [5, 0, 7, 3, 3, CLEAR], [5, 5, 7, 3, 3, CLEAR],
					[4, 0, 7, 3, 3, CLEAR], [4, 5, 7, 3, 3, CLEAR], [4, 1, 1, 6, 1, dk], [4, 1, 3, 6, 1, dk], [4, 1, 5, 6, 1, dk]]})
		"golem":
			var st := Color(0.46, 0.46, 0.48)
			var moss := Color(0.24, 0.40, 0.16)
			return humanoid({"plain": true, "skin": st, "shirt": st.darkened(0.12), "pants": st.darkened(0.2), "eyes": Color(1.0, 0.55, 0.1),
				"mouth": st.darkened(0.5), "arm_w": 5, "scale": 1.35,
				"torso_w": 10, "leg_w": 5, "head_feats": [[2, 0, 0, 10, 9, moss], [5, 0, 0, 10, 1, moss], [5, 2, 4, 2, 2, Color(1.0, 0.55, 0.1)], [5, 6, 4, 2, 2, Color(1.0, 0.55, 0.1)]],
				"torso_feats": [[5, 0, 0, 8, 2, moss], [4, 0, 0, 8, 3, moss], [5, 2, 4, 6, 5, st.darkened(0.4)], [5, 3, 5, 4, 3, Color(1.0, 0.45, 0.05)],
					[5, 4, 6, 2, 1, Color(1.0, 0.85, 0.4)], [5, 1, 9, 1, 3, st.darkened(0.5)], [5, 8, 2, 1, 4, st.darkened(0.5)], [5, 7, 1, 1, 1, st.darkened(0.5)],
					[4, 3, 6, 1, 5, st.darkened(0.5)], [4, 2, 5, 1, 1, st.darkened(0.5)]],
				"limb_feats": [[2, 0, 0, 5, 4, moss], [5, 0, 5, 2, 3, st.darkened(0.3)], [5, 3, 8, 1, 3, st.darkened(0.5)], [0, 1, 3, 1, 4, st.darkened(0.5)]]})
		"espectro":
			var gh := Color(0.72, 0.86, 0.95)
			var d := humanoid({"plain": true, "skin": gh, "shirt": gh.darkened(0.1), "pants": gh.darkened(0.2), "eyes": black, "mouth": black,
				"anim": "float", "alpha": true, "head_feats": [[5, 2, 3, 2, 3, black], [5, 6, 3, 2, 3, black], [5, 4, 6, 2, 2, black]]})
			# Sem pernas: um manto que afina.
			var parts: Array = d["parts"]
			parts.resize(4)
			parts.append({"size": Vector3i(6, 7, 3), "pos": Vector3(-3, 4, -1.5), "col": gh.darkened(0.2)})
			parts.append({"size": Vector3i(4, 4, 2), "pos": Vector3(-2, 0, -1), "col": gh.darkened(0.3)})
			return d
		"aranha":
			var body := Color(0.16, 0.13, 0.12)
			var red := Color(0.9, 0.1, 0.1)
			var hair := body.lightened(0.18)
			var band := Color(0.42, 0.30, 0.20)
			var parts: Array = []
			var ab_f: Array = [[2, 4, 2, 2, 7, Color(0.62, 0.10, 0.08)], [2, 3, 3, 4, 1, Color(0.62, 0.10, 0.08)], [2, 3, 6, 4, 1, Color(0.62, 0.10, 0.08)], [4, 3, 2, 4, 3, Color(0.5, 0.1, 0.08)]]
			ab_f.append_array(_spots(16, hair, 10, 7, 11, 13))
			parts.append({"size": Vector3i(10, 7, 11), "pos": Vector3(-5, 5, 0), "col": body, "spk": 0.28, "feats": ab_f})
			parts.append({"size": Vector3i(7, 5, 6), "pos": Vector3(-3.5, 5, -6), "col": body.lightened(0.08), "g": "head", "pivot": Vector3(0, 7, 0), "spk": 0.2,
				"feats": [[5, 2, 1, 1, 1, red], [5, 4, 1, 1, 1, red], [5, 1, 0, 1, 1, red.darkened(0.2)], [5, 5, 0, 1, 1, red.darkened(0.2)],
					[5, 0, 1, 1, 1, red.darkened(0.35)], [5, 6, 1, 1, 1, red.darkened(0.35)], [5, 1, 2, 1, 1, red.darkened(0.3)], [5, 5, 2, 1, 1, red.darkened(0.3)],
					[2, 2, 3, 3, 3, hair]]})
			# Quelíceras com presas.
			parts.append({"size": Vector3i(2, 3, 2), "pos": Vector3(-2.5, 4, -7.5), "col": body.lightened(0.05), "g": "head", "pivot": Vector3(0, 7, 0), "feats": [[3, 0, 0, 2, 2, Color(0.75, 0.72, 0.6)]]})
			parts.append({"size": Vector3i(2, 3, 2), "pos": Vector3(0.5, 4, -7.5), "col": body.lightened(0.05), "g": "head", "pivot": Vector3(0, 7, 0), "feats": [[3, 0, 0, 2, 2, Color(0.75, 0.72, 0.6)]]})
			var up_f := [[2, 3, 0, 1, 2, band], [2, 7, 0, 1, 2, band], [5, 3, 0, 1, 2, band], [5, 7, 0, 1, 2, band]]
			var lo_f := [[5, 0, 1, 2, 1, band], [0, 0, 1, 2, 1, band], [1, 0, 1, 2, 1, band], [4, 0, 1, 2, 1, band], [3, 0, 0, 2, 2, Color(0.05, 0.04, 0.04)]]
			for i in 4:
				var z := -4.0 + i * 2.6
				var ga := "legA" if i % 2 == 0 else "legB"
				var gb := "legB" if i % 2 == 0 else "legA"
				parts.append({"size": Vector3i(9, 2, 2), "pos": Vector3(3, 4, z), "pivot": Vector3(3, 5, z + 1), "col": body.lightened(0.05), "spk": 0.3, "feats": up_f, "g": ga})
				parts.append({"size": Vector3i(9, 2, 2), "pos": Vector3(-12, 4, z), "pivot": Vector3(-3, 5, z + 1), "col": body.lightened(0.05), "spk": 0.3, "feats": up_f, "g": gb})
				parts.append({"size": Vector3i(2, 5, 2), "pos": Vector3(11, 0, z), "pivot": Vector3(3, 5, z + 1), "col": body, "spk": 0.3, "feats": lo_f, "g": ga})
				parts.append({"size": Vector3i(2, 5, 2), "pos": Vector3(-13, 0, z), "pivot": Vector3(-3, 5, z + 1), "col": body, "spk": 0.3, "feats": lo_f, "g": gb})
			return {"scale": 1.0, "anim": "spider", "parts": parts}
		"gosma":
			var gr := Color(0.36, 0.78, 0.30)
			return {"scale": 1.0, "anim": "hop", "alpha": true, "parts": [
				{"size": Vector3i(12, 11, 12), "pos": Vector3(-6, 0, -6), "col": gr, "spk": 0.08,
					"feats": [[5, 2, 3, 2, 3, Color(0.05, 0.12, 0.05)], [5, 8, 3, 2, 3, Color(0.05, 0.12, 0.05)], [5, 4, 8, 4, 1, Color(0.05, 0.12, 0.05)]]},
				{"size": Vector3i(6, 6, 6), "pos": Vector3(-3, 2, -3), "col": gr.darkened(0.45)},
				{"size": Vector3i(2, 2, 2), "pos": Vector3(2, 7, 1), "col": gr.lightened(0.4)},
				{"size": Vector3i(1, 1, 1), "pos": Vector3(-4, 4, 2), "col": gr.lightened(0.5)},
				{"size": Vector3i(3, 1, 3), "pos": Vector3(-4.5, 10.2, -4.5), "col": gr.lightened(0.55)}]}
	return {"scale": 1.0, "anim": "hop", "parts": [{"size": Vector3i(8, 8, 8), "pos": Vector3(-4, 0, -4), "col": Color.MAGENTA}]}
