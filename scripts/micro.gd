class_name Micro
extends RefCounted
## Micro-celulas: um bloco subdividido em 8 x 8 x 8 voxels (1/8 de bloco cada).
## Cada voxel guarda o id do material (0 = vazio), entao uma unica celula pode misturar materiais.
## Escalas de construcao: 1 bloco, 1/2 (4 voxels), 1/4 (2 voxels) e 1/8 (1 voxel).

const N := 8
const SIZE := 512
const INV := 1.0 / 8.0
const SCALES: Array[int] = [8, 4, 2, 1]
const SCALE_NAMES: Array[String] = ["Bloco inteiro", "1/2 bloco", "1/4 bloco", "1/8 bloco"]


static func i3(x: int, y: int, z: int) -> int:
	return (y * N + z) * N + x


static func filled(id: int) -> PackedByteArray:
	var g := PackedByteArray()
	g.resize(SIZE)
	g.fill(id)
	return g


static func empty() -> PackedByteArray:
	return filled(0)


static func count(g: PackedByteArray) -> int:
	var n := 0
	for v in g:
		if v != 0:
			n += 1
	return n


## Material unico que preenche a celula toda (-1 se misturada ou incompleta; 0 se vazia).
static func uniform(g: PackedByteArray) -> int:
	var first := g[0]
	for v in g:
		if v != first:
			return -1
	return first


## Material mais comum (para som, dureza e particulas).
static func dominant(g: PackedByteArray) -> int:
	var cnt := {}
	var best := 0
	var bn := 0
	for v in g:
		if v == 0:
			continue
		var n: int = cnt.get(v, 0) + 1
		cnt[v] = n
		if n > bn:
			bn = n
			best = v
	return best


## Preenche (ou esvazia, id = 0) um cubo de lado s a partir do voxel (x, y, z). Devolve quantos mudaram
## e soma os materiais removidos em "removed".
static func fill_cube(g: PackedByteArray, x0: int, y0: int, z0: int, s: int, id: int, removed: Dictionary) -> int:
	var changed := 0
	for y in range(y0, mini(y0 + s, N)):
		for z in range(z0, mini(z0 + s, N)):
			for x in range(x0, mini(x0 + s, N)):
				var k := i3(x, y, z)
				var old := g[k]
				if id == 0:
					if old != 0:
						removed[old] = int(removed.get(old, 0)) + 1
						g[k] = 0
						changed += 1
				elif old == 0:
					g[k] = id
					changed += 1
	return changed


## Caixas de colisao: voxels agrupados em blocos retangulares (guloso em X, Z e Y).
static func boxes(g: PackedByteArray) -> Array[AABB]:
	var used := PackedByteArray()
	used.resize(SIZE)
	used.fill(0)
	var out: Array[AABB] = []
	for y in N:
		for z in N:
			for x in N:
				var k := i3(x, y, z)
				if g[k] == 0 or used[k] != 0:
					continue
				var w := 1
				while x + w < N and g[i3(x + w, y, z)] != 0 and used[i3(x + w, y, z)] == 0:
					w += 1
				var d := 1
				var ok := true
				while z + d < N and ok:
					for xx in range(x, x + w):
						var kk := i3(xx, y, z + d)
						if g[kk] == 0 or used[kk] != 0:
							ok = false
							break
					if ok:
						d += 1
				var h := 1
				ok = true
				while y + h < N and ok:
					for zz in range(z, z + d):
						for xx in range(x, x + w):
							var kk := i3(xx, y + h, zz)
							if g[kk] == 0 or used[kk] != 0:
								ok = false
								break
						if not ok:
							break
					if ok:
						h += 1
				for yy in range(y, y + h):
					for zz in range(z, z + d):
						for xx in range(x, x + w):
							used[i3(xx, yy, zz)] = 1
				out.append(AABB(Vector3(x, y, z) * INV, Vector3(w, h, d) * INV))
	return out


## DDA dentro da celula. o: origem em coordenadas locais da celula (0..1), dir normalizado.
## Devolve [t, voxel Vector3i, normal Vector3i] ou [] se nao acertar.
static func raycast(g: PackedByteArray, o: Vector3, dir: Vector3) -> Array:
	# Avanca ate entrar no cubo 0..1.
	var t0 := 0.0
	var inside := o.x >= 0.0 and o.x <= 1.0 and o.y >= 0.0 and o.y <= 1.0 and o.z >= 0.0 and o.z <= 1.0
	var n0 := Vector3i.ZERO
	if not inside:
		var tmin := -INF
		var tmax := INF
		for a in 3:
			if absf(dir[a]) < 1e-9:
				if o[a] < 0.0 or o[a] > 1.0:
					return []
				continue
			var ta := (0.0 - o[a]) / dir[a]
			var tb := (1.0 - o[a]) / dir[a]
			var sg := -1
			if ta > tb:
				var tt := ta
				ta = tb
				tb = tt
				sg = 1
			if ta > tmin:
				tmin = ta
				n0 = Vector3i.ZERO
				n0[a] = sg
			tmax = minf(tmax, tb)
		if tmin > tmax or tmax < 0.0:
			return []
		t0 = maxf(tmin, 0.0)
	var p := (o + dir * (t0 + 1e-5)) * N
	var v := Vector3i(clampi(floori(p.x), 0, N - 1), clampi(floori(p.y), 0, N - 1), clampi(floori(p.z), 0, N - 1))
	var step := Vector3i(1 if dir.x > 0 else -1, 1 if dir.y > 0 else -1, 1 if dir.z > 0 else -1)
	var tm := Vector3(INF, INF, INF)
	var td := Vector3(INF, INF, INF)
	for a in 3:
		if absf(dir[a]) > 1e-9:
			var edge := float(v[a] + (1 if dir[a] > 0 else 0))
			tm[a] = t0 + (edge - p[a]) * INV / dir[a] + 1e-5 * 0.0
			td[a] = absf(INV / dir[a])
	var nrm := n0
	var t := t0
	for _i in 32:
		if g[i3(v.x, v.y, v.z)] != 0:
			return [t, v, nrm]
		if tm.x < tm.y and tm.x < tm.z:
			v.x += step.x
			t = tm.x
			tm.x += td.x
			nrm = Vector3i(-step.x, 0, 0)
		elif tm.y < tm.z:
			v.y += step.y
			t = tm.y
			tm.y += td.y
			nrm = Vector3i(0, -step.y, 0)
		else:
			v.z += step.z
			t = tm.z
			tm.z += td.z
			nrm = Vector3i(0, 0, -step.z)
		if v.x < 0 or v.y < 0 or v.z < 0 or v.x >= N or v.y >= N or v.z >= N:
			return []
	return []


# ---------------------------------------------------------------- malha

const _AX: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## Voxel vizinho fora da celula: 1 = ocupado/opaco (esconde a face), 0 = livre.
static func _outside(f: int, a: int, b: int, nbid: int, nbg: Variant) -> int:
	if nbg != null:
		var ng: PackedByteArray = nbg
		# Voxel espelhado na celula vizinha.
		var x := 0
		var y := 0
		var z := 0
		match f:
			0: x = 0; y = a; z = b
			1: x = N - 1; y = a; z = b
			2: x = a; y = 0; z = b
			3: x = a; y = N - 1; z = b
			4: x = a; y = b; z = 0
			5: x = a; y = b; z = N - 1
		var nv := ng[i3(x, y, z)]
		return 1 if nv != 0 and Blocks.KIND[nv] != Blocks.K_GLASS else 0
	return 1 if Blocks.OPQ[nbid] == 1 else 0


## Gera as faces visiveis da celula com fusao gulosa por fatia.
## o: canto da celula no chunk; nbids[f]: id acolchoado do vizinho na face f; nbgs[f]: grade vizinha ou null.
## opaque/glass: [v, n, c, i] de cada superficie. light: luz do ceu (0..1).
static func mesh_cell(g: PackedByteArray, o: Vector3, nbids: Array, nbgs: Array, light: float,
		ov: PackedVector3Array, on: PackedVector3Array, oc: PackedColorArray, oi: PackedInt32Array,
		gv: PackedVector3Array, gn: PackedVector3Array, gc: PackedColorArray, gi: PackedInt32Array) -> void:
	var fl := Blocks.FACE_LAYER
	var mask := PackedInt32Array()
	mask.resize(64)
	for f in 6:
		var ax := _AX[f]
		# Eixos: d = normal, u e v = plano da fatia.
		var d := 0 if ax.x != 0 else (1 if ax.y != 0 else 2)
		var u := 1 if d == 0 else 0
		var w := 2 if d != 2 else 1
		var sgn := ax[d]
		for layer in N:
			mask.fill(0)
			var any := false
			for b in N:
				for a in N:
					var p := Vector3i.ZERO
					p[d] = layer
					p[u] = a
					p[w] = b
					var m := g[i3(p.x, p.y, p.z)]
					if m == 0:
						continue
					var q := p
					q[d] += sgn
					var hidden := 0
					if q[d] < 0 or q[d] >= N:
						# a/b no sistema do vizinho: (y, z) para X, (x, z) para Y, (x, y) para Z.
						var aa := p.y if d == 0 else p.x
						var bb := p.z if d != 2 else p.y
						hidden = _outside(f, aa, bb, nbids[f], nbgs[f])
					else:
						var nv := g[i3(q.x, q.y, q.z)]
						if nv != 0:
							var mg := Blocks.KIND[m] == Blocks.K_GLASS
							var ng := Blocks.KIND[nv] == Blocks.K_GLASS
							hidden = 1 if (not ng or (mg and nv == m)) else 0
					if hidden == 0:
						mask[b * N + a] = m
						any = true
			if not any:
				continue
			# Fusao gulosa de retangulos do mesmo material.
			for b in N:
				var a := 0
				while a < N:
					var m := mask[b * N + a]
					if m == 0:
						a += 1
						continue
					var wa := 1
					while a + wa < N and mask[b * N + a + wa] == m:
						wa += 1
					var hb := 1
					var ok := true
					while b + hb < N and ok:
						for k in wa:
							if mask[(b + hb) * N + a + k] != m:
								ok = false
								break
						if ok:
							hb += 1
					for bb in range(b, b + hb):
						for k in wa:
							mask[bb * N + a + k] = 0
					# Quad: plano em d = layer (+1 se face positiva).
					var plane := float(layer + (1 if sgn > 0 else 0)) * INV
					var c0 := Vector3.ZERO
					c0[d] = plane
					c0[u] = a * INV
					c0[w] = b * INV
					var du := Vector3.ZERO
					du[u] = wa * INV
					var dw := Vector3.ZERO
					dw[w] = hb * INV
					var p0 := o + c0
					var nrm := Vector3(ax)
					var is_glass := Blocks.KIND[m] == Blocks.K_GLASS
					# Faces de baixo e laterais internas um pouco mais escuras para dar profundidade.
					var shade := 0.96 if f != 3 else 0.85
					var col := Color(shade, fl[m * 6 + f] / 255.0, light, 1.0 if is_glass else 0.0)
					if is_glass:
						ChunkMesher._quad(gv, gn, gc, gi, p0, p0 + du, p0 + du + dw, p0 + dw, nrm, col)
					else:
						ChunkMesher._quad(ov, on, oc, oi, p0, p0 + du, p0 + du + dw, p0 + dw, nrm, col)
					a += wa


## Gira a grade em passos de 90 graus no eixo Y (mesmo sentido de Structures.rot_local).
static func rotate_y(g: PackedByteArray, rot: int) -> PackedByteArray:
	var out := g
	for k in rot % 4:
		var n := empty()
		for y in N:
			for z in N:
				for x in N:
					n[i3(N - 1 - z, y, x)] = out[i3(x, y, z)]
		out = n
	return out


## Converte qualquer bloco cubico em celula micro do mesmo material.
static func can_micro(id: int) -> bool:
	if id <= 0 or id >= 256:
		return false
	var k := Blocks.KIND[id]
	return (k == Blocks.K_CUBE or k == Blocks.K_GLASS) and Blocks.PANE[id] == 0 and not Blocks.VAR_LAYERS.has(id) and id != Blocks.PORTAL_FIRE and id != Blocks.PORTAL_ASTRAL and id != Blocks.BEDROCK
