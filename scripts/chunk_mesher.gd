class_name ChunkMesher
extends RefCounted
## Converte os voxels de um chunk em malha. Roda em threads de trabalho.
## Cor do vertice: r = oclusao, g = camada da textura, b = luz do ceu, a = emissao / peso do vento.

const CS := 16
const H := 128
const PS := 18
const PL := PS * PS
const PH := H + 2

const S_OPAQUE := 0
const S_FOLIAGE := 1
const S_WATER := 2
const S_GLASS := 3
const S_LAVA := 4

static var NRM: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
static var CPOS: Array[Vector3] = []
static var ND := PackedInt32Array()
static var AOD := PackedInt32Array()
static var AOV := PackedFloat32Array([0.45, 0.64, 0.83, 1.0])
static var QUV: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
static var _empty := PackedByteArray()


static func _static_init() -> void:
	var us: Array[Vector3i] = [Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0)]
	var vs: Array[Vector3i] = [Vector3i(0, 0, 1), Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 1, 0), Vector3i(1, 0, 0)]
	var ns: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	var sg: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
	for f in 6:
		ND.append(_d(ns[f]))
		for c in 4:
			var su := sg[c].x
			var sv := sg[c].y
			var p := Vector3(ns[f] + us[f] * su + vs[f] * sv) * 0.5 + Vector3(0.5, 0.5, 0.5)
			CPOS.append(p)
			AOD.append(_d(us[f] * su))
			AOD.append(_d(vs[f] * sv))
			AOD.append(_d(us[f] * su + vs[f] * sv))
	_empty.resize(256 * H)
	_empty.fill(0)


static func _d(v: Vector3i) -> int:
	return v.x + v.z * PS + v.y * PL


static func _quad(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array,
		p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, nrm: Vector3, col: Color) -> void:
	var b := v.size()
	v.append(p0)
	v.append(p1)
	v.append(p2)
	v.append(p3)
	for k in 4:
		n.append(nrm)
		c.append(col)
	if (p1 - p0).cross(p2 - p0).dot(nrm) > 0.0:
		idx.append(b); idx.append(b + 2); idx.append(b + 1)
		idx.append(b); idx.append(b + 3); idx.append(b + 2)
	else:
		idx.append(b); idx.append(b + 1); idx.append(b + 2)
		idx.append(b); idx.append(b + 2); idx.append(b + 3)


static func _tri(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array,
		p0: Vector3, p1: Vector3, p2: Vector3, nrm: Vector3, col: Color) -> void:
	var b := v.size()
	v.append(p0)
	v.append(p1)
	v.append(p2)
	for k in 3:
		n.append(nrm)
		c.append(col)
	if (p1 - p0).cross(p2 - p0).dot(nrm) > 0.0:
		idx.append(b); idx.append(b + 2); idx.append(b + 1)
	else:
		idx.append(b); idx.append(b + 1); idx.append(b + 2)


static func _face_of(n: Vector3) -> int:
	if n.x > 0.5: return 0
	if n.x < -0.5: return 1
	if n.y > 0.5: return 2
	if n.y < -0.5: return 3
	if n.z > 0.5: return 4
	return 5


static func _box(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array,
		o: Vector3, bx: AABB, id: int, light: float, emit: float, pb: PackedInt32Array, i: int, lay: int = -1) -> void:
	var mn := bx.position
	var sz := bx.size
	var mx := bx.end
	var fl := Blocks.FACE_LAYER
	for f in 6:
		var onb := false
		match f:
			0: onb = mx.x > 0.999
			1: onb = mn.x < 0.001
			2: onb = mx.y > 0.999
			3: onb = mn.y < 0.001
			4: onb = mx.z > 0.999
			5: onb = mn.z < 0.001
		if onb and Blocks.OPQ[pb[i + ND[f]]] == 1:
			continue
		var b := f * 4
		var col := Color(0.96, (fl[id * 6 + f] if lay < 0 else lay) / 255.0, light, emit)
		_quad(v, n, c, idx, o + mn + CPOS[b] * sz, o + mn + CPOS[b + 1] * sz, o + mn + CPOS[b + 2] * sz, o + mn + CPOS[b + 3] * sz, NRM[f], col)


## Caixa de um modelo (movel): cada face tem a propria camada de textura.
static func _mbox(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array,
		o: Vector3, bx: AABB, layers: PackedInt32Array, light: float, pb: PackedInt32Array, i: int) -> void:
	var mn := bx.position
	var sz := bx.size
	var mx := bx.end
	for f in 6:
		var onb := false
		match f:
			0: onb = mx.x > 0.999
			1: onb = mn.x < 0.001
			2: onb = mx.y > 0.999
			3: onb = mn.y < 0.001
			4: onb = mx.z > 0.999
			5: onb = mn.z < 0.001
		if onb and Blocks.OPQ[pb[i + ND[f]]] == 1:
			continue
		var b := f * 4
		var col := Color(0.96, layers[f] / 255.0, light, 1.0)
		_quad(v, n, c, idx, o + mn + CPOS[b] * sz, o + mn + CPOS[b + 1] * sz, o + mn + CPOS[b + 2] * sz, o + mn + CPOS[b + 3] * sz, NRM[f], col)


static func _rp(p: Vector3, r: int) -> Vector3:
	for k in r:
		p = Vector3(1.0 - p.z, p.y, p.x)
	return p


static func _rn(p: Vector3, r: int) -> Vector3:
	for k in r:
		p = Vector3(-p.z, p.y, p.x)
	return p


static func _wedge(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array,
		o: Vector3, rot: int, id: int, light: float, pb: PackedInt32Array, i: int) -> void:
	var fl := Blocks.FACE_LAYER
	var a := o + _rp(Vector3(0, 0, 0), rot)
	var b := o + _rp(Vector3(1, 0, 0), rot)
	var cc := o + _rp(Vector3(1, 0, 1), rot)
	var d := o + _rp(Vector3(0, 0, 1), rot)
	var e := o + _rp(Vector3(0, 1, 1), rot)
	var f := o + _rp(Vector3(1, 1, 1), rot)
	var side := fl[id * 6] / 255.0
	if Blocks.OPQ[pb[i - PL]] == 0:
		_quad(v, n, c, idx, a, b, cc, d, Vector3(0, -1, 0), Color(0.96, fl[id * 6 + 3] / 255.0, light, 0))
	var nb := _rn(Vector3(0, 0, 1), rot)
	if Blocks.OPQ[pb[i + ND[_face_of(nb)]]] == 0:
		_quad(v, n, c, idx, d, cc, f, e, nb, Color(0.96, side, light, 0))
	_quad(v, n, c, idx, a, b, f, e, _rn(Vector3(0, 0.70710678, -0.70710678), rot), Color(1.0, fl[id * 6 + 2] / 255.0, light, 0))
	var nl := _rn(Vector3(-1, 0, 0), rot)
	if Blocks.OPQ[pb[i + ND[_face_of(nl)]]] == 0:
		_tri(v, n, c, idx, a, d, e, nl, Color(0.96, side, light, 0))
	var nr := _rn(Vector3(1, 0, 0), rot)
	if Blocks.OPQ[pb[i + ND[_face_of(nr)]]] == 0:
		_tri(v, n, c, idx, b, cc, f, nr, Color(0.96, side, light, 0))


## Lados em que a cerca se conecta (1 +X, 2 -X, 4 +Z, 8 -Z), olhando o array acolchoado.
static func _fence_mask(pb: PackedInt32Array, i: int) -> int:
	var m := 0
	if Blocks.fence_links(pb[i + 1]): m |= 1
	if Blocks.fence_links(pb[i - 1]): m |= 2
	if Blocks.fence_links(pb[i + PS]): m |= 4
	if Blocks.fence_links(pb[i - PS]): m |= 8
	return m


## nb: 9 arrays de blocos (dz+1)*3+(dx+1); nsh: 9 dicionarios de formas; top: altura maxima ocupada.
## Grade micro em coordenadas locais do chunk central (x/z podem sair de 0..15 para os vizinhos).
static func _micro_at(nmi: Array, x: int, y: int, z: int) -> Variant:
	if nmi.is_empty() or y < 0 or y >= H:
		return null
	var xi := 1
	var zi := 1
	if x < 0:
		xi = 0
		x += 16
	elif x > 15:
		xi = 2
		x -= 16
	if z < 0:
		zi = 0
		z += 16
	elif z > 15:
		zi = 2
		z -= 16
	var d: Dictionary = nmi[zi * 3 + xi]
	if d.is_empty():
		return null
	return d.get(y * 256 + z * 16 + x)


static func build(nb: Array, nsh: Array, top: int, cx: int, cz: int, lite: bool = false, nmi: Array = []) -> Dictionary:
	var KIND := Blocks.KIND
	var OPQ := Blocks.OPQ
	var COVER := Blocks.COVER
	var FL := Blocks.FACE_LAYER
	var cpos := CPOS
	var nrm := NRM
	var nd := ND
	var aod := AOD
	var aov := AOV
	top = clampi(top, 1, H)

	# 1) Array acolchoado 18 x (H+2) x 18 com a borda dos 8 vizinhos.
	var pb := PackedInt32Array()
	pb.resize(PL * PH)
	pb.fill(0)
	for y in top:
		var prow := (y + 1) * PL
		var crow := y * 256
		for pz in PS:
			var zi := 1
			var sz := pz - 1
			if sz < 0:
				zi = 0
				sz = 15
			elif sz > 15:
				zi = 2
				sz = 0
			var base := prow + pz * PS
			var src := crow + sz * 16
			var left: PackedByteArray = nb[zi * 3]
			var mid: PackedByteArray = nb[zi * 3 + 1]
			var right: PackedByteArray = nb[zi * 3 + 2]
			pb[base] = left[src + 15]
			for x in 16:
				pb[base + 1 + x] = mid[src + x]
			pb[base + 17] = right[src]
	# Blocos com forma recebem o bit 0x100: nao ocluem os vizinhos.
	for k in 9:
		var sd: Dictionary = nsh[k]
		if sd.is_empty():
			continue
		var offx := (k % 3 - 1) * 16 + 1
		var offz := (k / 3 - 1) * 16 + 1
		for idx: int in sd:
			var px := (idx & 15) + offx
			var pz := ((idx >> 4) & 15) + offz
			var py := (idx >> 8) + 1
			if px < 0 or px >= PS or pz < 0 or pz >= PS or py > top:
				continue
			pb[(py * PS + pz) * PS + px] |= 0x100

	# 2) Luz do ceu por coluna: cai ao passar por folhas e some debaixo de rocha.
	var sl := PackedByteArray()
	sl.resize(PL * PH)
	sl.fill(0)
	for col in PL:
		var lv := 255
		var under := false
		var i := (top + 1) * PL + col
		for yy in range(top + 1, 0, -1):
			sl[i] = lv
			if under:
				lv -= 40
			else:
				var cvr := COVER[pb[i]]
				if cvr == 2:
					under = true
					lv -= 40
				elif cvr == 1:
					lv = maxi(lv - 22, 70)
			if lv <= 0:
				break
			i -= PL

	var ov := PackedVector3Array()
	var on := PackedVector3Array()
	var oc := PackedColorArray()
	var oi := PackedInt32Array()
	var fv := PackedVector3Array()
	var fn := PackedVector3Array()
	var fc := PackedColorArray()
	var fu := PackedVector2Array()
	var fi := PackedInt32Array()
	var lav_v := PackedVector3Array()
	var lav_n := PackedVector3Array()
	var lav_c := PackedColorArray()
	var lav_i := PackedInt32Array()
	var wv := PackedVector3Array()
	var wn := PackedVector3Array()
	var wc := PackedColorArray()
	var wi := PackedInt32Array()
	var gv := PackedVector3Array()
	var gn := PackedVector3Array()
	var gc := PackedColorArray()
	var gi := PackedInt32Array()
	var shapes: Dictionary = nsh[4]
	var inv255 := 1.0 / 255.0
	var a0 := 0
	var a1 := 0
	var a2 := 0
	var a3 := 0
	var up := Vector3(0, 1, 0)

	for y in top:
		for z in 16:
			var i := ((y + 1) * PS + z + 1) * PS + 1
			for x in 16:
				var id := pb[i]
				if id == 0:
					i += 1
					continue
				var o := Vector3(x, y, z)
				if id >= 256:
					id &= 255
					var sb: int = shapes.get(y * 256 + z * 16 + x, 0)
					var light := sl[i] * inv255
					if (sb & 15) == Blocks.SH_MICRO:
						var g: Variant = _micro_at(nmi, x, y, z)
						if g != null:
							var nbids := []
							var nbgs := []
							for f in 6:
								var ni := i + nd[f]
								nbids.append(pb[ni])
								var nv := Vector3i(x, y, z) + Vector3i(NRM[f])
								nbgs.append(_micro_at(nmi, nv.x, nv.y, nv.z) if pb[ni] >= 256 else null)
							Micro.mesh_cell(g, o, nbids, nbgs, light, ov, on, oc, oi, gv, gn, gc, gi)
					elif id == Blocks.FENCE:
						for mb: Array in Blocks.fence_model(_fence_mask(pb, i)):
							_mbox(ov, on, oc, oi, o, mb[0], mb[1], light, pb, i)
					elif KIND[id] == 6:
						if Blocks.model_is_glass(id, sb):
							for mb: Array in Blocks.model(id, sb):
								_mbox(gv, gn, gc, gi, o, mb[0], mb[1], light, pb, i)
						else:
							for mb: Array in Blocks.model(id, sb):
								_mbox(ov, on, oc, oi, o, mb[0], mb[1], light, pb, i)
					elif KIND[id] == 5:
						var vl := Blocks.var_layer(id, sb)
						for bx: AABB in Blocks.SHAPE_BOXES[sb & 63]:
							_box(gv, gn, gc, gi, o, bx, id, light, 1.0, pb, i, vl)
					elif (sb & 15) == Blocks.SH_WEDGE:
						_wedge(ov, on, oc, oi, o, (sb >> 4) & 3, id, light, pb, i)
					else:
						for bx: AABB in Blocks.SHAPE_BOXES[sb & 63]:
							_box(ov, on, oc, oi, o, bx, id, light, 0.0, pb, i)
					i += 1
					continue
				var kind := KIND[id]
				if kind == 1:
					for f in 6:
						var ni := i + nd[f]
						if OPQ[pb[ni]] == 1:
							continue
						var b4 := f * 4
						var lg := FL[id * 6 + f] * inv255
						var vb := ov.size()
						for c in 4:
							var k3 := (b4 + c) * 3
							var i1 := ni + aod[k3]
							var i2 := ni + aod[k3 + 1]
							var i3 := ni + aod[k3 + 2]
							var s1 := OPQ[pb[i1]]
							var s2 := OPQ[pb[i2]]
							var s3 := OPQ[pb[i3]]
							var ao := 0 if (s1 + s2) == 2 else 3 - s1 - s2 - s3
							var ls: int = sl[ni]
							var cnt := 1
							if s1 == 0:
								ls += sl[i1]
								cnt += 1
							if s2 == 0:
								ls += sl[i2]
								cnt += 1
							if s3 == 0 and (s1 + s2) < 2:
								ls += sl[i3]
								cnt += 1
							ov.append(o + cpos[b4 + c])
							on.append(nrm[f])
							oc.append(Color(aov[ao], lg, ls * inv255 / cnt, 0.0))
							if c == 0: a0 = ao
							elif c == 1: a1 = ao
							elif c == 2: a2 = ao
							else: a3 = ao
						if a0 + a2 < a1 + a3:
							oi.append(vb + 1); oi.append(vb + 3); oi.append(vb + 2)
							oi.append(vb + 1); oi.append(vb); oi.append(vb + 3)
						else:
							oi.append(vb); oi.append(vb + 2); oi.append(vb + 1)
							oi.append(vb); oi.append(vb + 3); oi.append(vb + 2)
				elif kind == 2:
					# Folhas: faces recortadas + dois planos diagonais internos para dar volume.
					var lg := FL[id * 6] * inv255
					var exposed := false
					for f in 6:
						var ni := i + nd[f]
						var nid := pb[ni]
						if nid == id or OPQ[nid] == 1:
							continue
						exposed = true
						var b4 := f * 4
						var vb := fv.size()
						var col := Color(0.92, lg, sl[ni] * inv255, 0.22)
						for c in 4:
							fv.append(o + cpos[b4 + c])
							fn.append(nrm[f])
							fc.append(col)
							fu.append(QUV[c])
						fi.append(vb); fi.append(vb + 2); fi.append(vb + 1)
						fi.append(vb); fi.append(vb + 3); fi.append(vb + 2)
					if exposed and not lite:
						var col := Color(0.8, lg, sl[i] * inv255, 0.22)
						for q in 2:
							var vb := fv.size()
							var x0 := -0.12
							var x1 := 1.12
							var z0 := -0.12 if q == 0 else 1.12
							var z1 := 1.12 if q == 0 else -0.12
							fv.append(o + Vector3(x0, -0.1, z0))
							fv.append(o + Vector3(x1, -0.1, z1))
							fv.append(o + Vector3(x1, 1.1, z1))
							fv.append(o + Vector3(x0, 1.1, z0))
							var dn := Vector3(z1 - z0, 0.6, x0 - x1).normalized()
							for c in 4:
								fn.append(dn)
								fc.append(col)
								fu.append(QUV[c])
							fi.append(vb); fi.append(vb + 1); fi.append(vb + 2)
							fi.append(vb); fi.append(vb + 2); fi.append(vb + 3)
				elif kind == 3 and lite:
					pass
				elif kind == 3:
					# Plantas em cruz com variacao de posicao e altura por bloco.
					var hsh := ((cx * 16 + x) * 73856093) ^ ((cz * 16 + z) * 19349663) ^ (y * 83492791)
					var jx := ((hsh & 15) / 15.0 - 0.5) * 0.3
					var jz := (((hsh >> 4) & 15) / 15.0 - 0.5) * 0.3
					var ph := 0.72 + ((hsh >> 8) & 15) / 15.0 * 0.4
					var lg := FL[id * 6] * inv255
					var light := sl[i] * inv255
					var cb := Color(1.0, lg, light, 0.0)
					var ct := Color(1.0, lg, light, 1.0)
					for q in 2:
						var vb := fv.size()
						var z0 := 0.1 if q == 0 else 0.9
						var z1 := 0.9 if q == 0 else 0.1
						fv.append(o + Vector3(0.1 + jx, 0.0, z0 + jz))
						fv.append(o + Vector3(0.9 + jx, 0.0, z1 + jz))
						fv.append(o + Vector3(0.9 + jx, ph, z1 + jz))
						fv.append(o + Vector3(0.1 + jx, ph, z0 + jz))
						fn.append(up); fn.append(up); fn.append(up); fn.append(up)
						fc.append(cb); fc.append(cb); fc.append(ct); fc.append(ct)
						fu.append(QUV[0]); fu.append(QUV[1]); fu.append(QUV[2]); fu.append(QUV[3])
						fi.append(vb); fi.append(vb + 1); fi.append(vb + 2)
						fi.append(vb); fi.append(vb + 2); fi.append(vb + 3)
				elif kind == 4:
					var ft := Blocks.FLUID[id]
					var is_lava := ft == 2
					var above_same := Blocks.FLUID[pb[i + PL] & 255] == ft
					var h := 1.0 if above_same else Blocks.fluid_height(id)
					for f in 6:
						var ni := i + nd[f]
						var nid := pb[ni] & 255
						if OPQ[pb[ni]] == 1:
							continue
						var y0 := 0.0
						var y1 := h
						if Blocks.FLUID[nid] == ft:
							if f == 2 or f == 3:
								continue
							# Lado entre niveis diferentes: so o trecho acima do vizinho.
							var nh := 1.0 if Blocks.FLUID[pb[ni + PL] & 255] == ft else Blocks.fluid_height(nid)
							if nh >= h - 0.01:
								continue
							y0 = nh
						var b4 := f * 4
						var light := 1.0 if is_lava else sl[ni] * inv255
						var is_top := f == 2 and not above_same
						if is_lava:
							var vb := lav_v.size()
							for c in 4:
								var cp := cpos[b4 + c]
								var yy := h if f == 2 else (0.0 if f == 3 else lerpf(y0, y1, cp.y))
								lav_v.append(o + Vector3(cp.x, yy, cp.z))
								lav_n.append(nrm[f])
								lav_c.append(Color(1.0 if is_top else 0.0, 0.0, light, 1.0))
							lav_i.append(vb); lav_i.append(vb + 2); lav_i.append(vb + 1)
							lav_i.append(vb); lav_i.append(vb + 3); lav_i.append(vb + 2)
						else:
							var vb := wv.size()
							for c in 4:
								var cp := cpos[b4 + c]
								var yy := h if f == 2 else (0.0 if f == 3 else lerpf(y0, y1, cp.y))
								wv.append(o + Vector3(cp.x, yy, cp.z))
								wn.append(nrm[f])
								wc.append(Color(1.0 if is_top else 0.0, 0.0, light, 1.0))
							wi.append(vb); wi.append(vb + 2); wi.append(vb + 1)
							wi.append(vb); wi.append(vb + 3); wi.append(vb + 2)
				elif kind == 5 and Blocks.PANE[id] == 1:
					# Lamina sem forma (ex.: item na mao): desenha centralizada.
					for bx: AABB in Blocks.SHAPE_BOXES[Blocks.SH_PANE]:
						_box(gv, gn, gc, gi, o, bx, id, sl[i] * inv255, 1.0, pb, i)
				elif kind == 5:
					for f in 6:
						var ni := i + nd[f]
						var nid := pb[ni]
						if nid == id or OPQ[nid] == 1:
							continue
						var b4 := f * 4
						_quad(gv, gn, gc, gi, o + cpos[b4], o + cpos[b4 + 1], o + cpos[b4 + 2], o + cpos[b4 + 3], nrm[f],
							Color(1.0, FL[id * 6 + f] * inv255, sl[ni] * inv255, 1.0))
				elif kind == 6:
					var mlight := sl[i] * inv255
					var mparts: Array = Blocks.fence_model(_fence_mask(pb, i)) if id == Blocks.FENCE else Blocks.model(id, 0)
					for mb: Array in mparts:
						_mbox(ov, on, oc, oi, o, mb[0], mb[1], mlight, pb, i)
				i += 1

	var mesh := ArrayMesh.new()
	var kinds := PackedInt32Array()
	if ov.size() > 0:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = ov
		arr[Mesh.ARRAY_NORMAL] = on
		arr[Mesh.ARRAY_COLOR] = oc
		arr[Mesh.ARRAY_INDEX] = oi
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		kinds.append(S_OPAQUE)
	if fv.size() > 0:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = fv
		arr[Mesh.ARRAY_NORMAL] = fn
		arr[Mesh.ARRAY_COLOR] = fc
		arr[Mesh.ARRAY_TEX_UV] = fu
		arr[Mesh.ARRAY_INDEX] = fi
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		kinds.append(S_FOLIAGE)
	if wv.size() > 0:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = wv
		arr[Mesh.ARRAY_NORMAL] = wn
		arr[Mesh.ARRAY_COLOR] = wc
		arr[Mesh.ARRAY_INDEX] = wi
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		kinds.append(S_WATER)
	if gv.size() > 0:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = gv
		arr[Mesh.ARRAY_NORMAL] = gn
		arr[Mesh.ARRAY_COLOR] = gc
		arr[Mesh.ARRAY_INDEX] = gi
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		kinds.append(S_GLASS)
	if lav_v.size() > 0:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = lav_v
		arr[Mesh.ARRAY_NORMAL] = lav_n
		arr[Mesh.ARRAY_COLOR] = lav_c
		arr[Mesh.ARRAY_INDEX] = lav_i
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		kinds.append(S_LAVA)
	return {"mesh": mesh, "kinds": kinds}


## Malha de um unico bloco (para o item na mao). O bloco fica em (8, 1, 8).
static func build_item(id: int, shape: int) -> Dictionary:
	var center := _empty.duplicate()
	var idx := 1 * 256 + 8 * 16 + 8
	center[idx] = id
	var nb := []
	var nsh := []
	for k in 9:
		nb.append(center if k == 4 else _empty)
		nsh.append({})
	if shape != 0:
		nsh[4] = {idx: shape}
	return build(nb, nsh, 3, 0, 0)
