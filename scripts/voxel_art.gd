class_name VoxelArt
extends RefCounted
## Ferramenta de criacao voxel do projeto. Duas formas de modelar, ambas em grade de 1/16 m:
##  - Canvas: desenho 16x16 em pixel-art (linhas, discos, curvas) que vira icone 2D e,
##    extrudado, o item 3D na mao.
##  - part_mesh: caixa pintada texel a texel, a peca basica dos bonecos (personagem e mobs).

const T := 1.0 / 16.0
const CLEAR := Color(0, 0, 0, 0)

static var _mat: ShaderMaterial
static var _mat_alpha: ShaderMaterial
static var _part_cache: Dictionary = {}


static func material(translucent: bool = false) -> ShaderMaterial:
	if _mat == null:
		var base: Shader = load("res://shaders/voxel.gdshader")
		_mat = ShaderMaterial.new()
		_mat.shader = base
		var sh := Shader.new()
		sh.code = base.code.replace("//ALPHA", "ALPHA = alpha;")
		_mat_alpha = ShaderMaterial.new()
		_mat_alpha.shader = sh
		_mat_alpha.set_shader_parameter("alpha", 0.55)
	return _mat_alpha if translucent else _mat


class Canvas:
	var px: Array[Color] = []

	func _init() -> void:
		px.resize(256)
		px.fill(VoxelArt.CLEAR)

	func setp(x: int, y: int, c: Color) -> void:
		if x >= 0 and x < 16 and y >= 0 and y < 16:
			px[y * 16 + x] = c

	func getp(x: int, y: int) -> Color:
		if x < 0 or x > 15 or y < 0 or y > 15:
			return VoxelArt.CLEAR
		return px[y * 16 + x]

	func disc(cx: float, cy: float, r: float, c: Color) -> void:
		for y in range(int(floor(cy - r)), int(ceil(cy + r)) + 1):
			for x in range(int(floor(cx - r)), int(ceil(cx + r)) + 1):
				var dx := x + 0.5 - cx
				var dy := y + 0.5 - cy
				if dx * dx + dy * dy <= r * r:
					setp(x, y, c)

	func line(x0: float, y0: float, x1: float, y1: float, c: Color, th: float = 1.0) -> void:
		var n := int(maxf(absf(x1 - x0), absf(y1 - y0)) * 2.0) + 1
		for i in n + 1:
			var t := float(i) / n
			disc(lerpf(x0, x1, t) + 0.5, lerpf(y0, y1, t) + 0.5, th * 0.5 + 0.05, c)

	func rect(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				setp(x, y, c)

	func bezier(p0: Vector2, p1: Vector2, p2: Vector2, c: Color, th: float = 1.0) -> void:
		for i in 33:
			var t := i / 32.0
			var p := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
			disc(p.x + 0.5, p.y + 0.5, th * 0.5 + 0.05, c)

	## Contorno escuro e luz no canto superior esquerdo: o acabamento classico de pixel-art.
	func finish() -> void:
		var src := px.duplicate()
		for y in 16:
			for x in 16:
				var c: Color = src[y * 16 + x]
				if c.a < 0.5:
					continue
				var open := 0
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := x + d.x
					var ny := y + d.y
					if nx < 0 or nx > 15 or ny < 0 or ny > 15 or src[ny * 16 + nx].a < 0.5:
						open += 1
				var lit: bool = y > 0 and x > 0 and src[(y - 1) * 16 + x - 1].a < 0.5
				var f := 1.0
				if open > 0:
					f = 1.12 if lit else 0.62
				px[y * 16 + x] = Color(minf(c.r * f, 1.0), minf(c.g * f, 1.0), minf(c.b * f, 1.0), 1.0)

	func texture() -> ImageTexture:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				img.set_pixel(x, y, px[y * 16 + x])
		return ImageTexture.create_from_image(img)


static func _commit(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array, translucent: bool = false) -> ArrayMesh:
	var m := ArrayMesh.new()
	if v.is_empty():
		return m
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, material(translucent))
	return m


## Extruda um desenho 16x16 em uma placa de voxels com 1 texel de espessura, centrada na origem.
static func extrude(cv: Canvas) -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var h := T * 0.5
	for y in 16:
		for x in 16:
			var col := cv.getp(x, y)
			if col.a < 0.5:
				continue
			var x0 := (x - 8) * T
			var x1 := x0 + T
			var y1 := (8 - y) * T
			var y0 := y1 - T
			var side := Color(col.r * 0.78, col.g * 0.78, col.b * 0.78)
			ChunkMesher._quad(v, n, c, idx, Vector3(x0, y0, h), Vector3(x1, y0, h), Vector3(x1, y1, h), Vector3(x0, y1, h), Vector3(0, 0, 1), col)
			ChunkMesher._quad(v, n, c, idx, Vector3(x0, y0, -h), Vector3(x1, y0, -h), Vector3(x1, y1, -h), Vector3(x0, y1, -h), Vector3(0, 0, -1), col)
			if cv.getp(x - 1, y).a < 0.5:
				ChunkMesher._quad(v, n, c, idx, Vector3(x0, y0, -h), Vector3(x0, y0, h), Vector3(x0, y1, h), Vector3(x0, y1, -h), Vector3(-1, 0, 0), side)
			if cv.getp(x + 1, y).a < 0.5:
				ChunkMesher._quad(v, n, c, idx, Vector3(x1, y0, -h), Vector3(x1, y0, h), Vector3(x1, y1, h), Vector3(x1, y1, -h), Vector3(1, 0, 0), side)
			if cv.getp(x, y - 1).a < 0.5:
				ChunkMesher._quad(v, n, c, idx, Vector3(x0, y1, -h), Vector3(x1, y1, -h), Vector3(x1, y1, h), Vector3(x0, y1, h), Vector3(0, 1, 0), side)
			if cv.getp(x, y + 1).a < 0.5:
				ChunkMesher._quad(v, n, c, idx, Vector3(x0, y0, -h), Vector3(x1, y0, -h), Vector3(x1, y0, h), Vector3(x0, y0, h), Vector3(0, -1, 0), side)
	return _commit(v, n, c, idx)


static func _texel(face: int, u: int, w: int, base: Color, spk: float, feats: Array, seed_v: int) -> Color:
	var col := base
	for ft: Array in feats:
		if ft[0] == face and u >= ft[1] and u < ft[1] + ft[3] and w >= ft[2] and w < ft[2] + ft[4]:
			col = ft[5]
	if col.a < 0.01:
		return col
	var h := WorldGen._hash32(u + face * 37, w, seed_v) & 255
	var f := 1.0 + (h / 255.0 - 0.5) * spk
	return Color(col.r * f, col.g * f, col.b * f, col.a)


## Caixa de size texels (largura X, altura Y, profundidade Z) com o canto minimo na origem.
## feats: [[face, x, y, largura, altura, cor], ...] pinta retangulos por face (cor transparente = furo).
## Faces: 0 +X, 1 -X, 2 topo, 3 base, 4 +Z (costas), 5 -Z (frente). Nas faces laterais y conta do topo.
static func part_mesh(size: Vector3i, base: Color, spk: float, feats: Array, seed_v: int, translucent: bool = false) -> ArrayMesh:
	var key := str(size, base, spk, feats, seed_v, translucent)
	if _part_cache.has(key):
		return _part_cache[key]
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var sx := size.x
	var sy := size.y
	var sz := size.z
	for face in 6:
		var nu := sz if face < 2 else sx
		var nw := sz if (face == 2 or face == 3) else sy
		var shade := 1.0
		if face == 3:
			shade = 0.7
		elif face < 2:
			shade = 0.9
		for w in nw:
			for u in nu:
				var col := _texel(face, u, w, base, spk, feats, seed_v)
				if col.a < 0.01:
					continue
				col = Color(col.r * shade, col.g * shade, col.b * shade, 1.0)
				var y1 := (sy - w) * T
				var y0 := y1 - T
				match face:
					0:
						ChunkMesher._quad(v, n, c, idx, Vector3(sx * T, y0, u * T), Vector3(sx * T, y0, (u + 1) * T), Vector3(sx * T, y1, (u + 1) * T), Vector3(sx * T, y1, u * T), Vector3(1, 0, 0), col)
					1:
						ChunkMesher._quad(v, n, c, idx, Vector3(0, y0, u * T), Vector3(0, y0, (u + 1) * T), Vector3(0, y1, (u + 1) * T), Vector3(0, y1, u * T), Vector3(-1, 0, 0), col)
					2:
						ChunkMesher._quad(v, n, c, idx, Vector3(u * T, sy * T, w * T), Vector3((u + 1) * T, sy * T, w * T), Vector3((u + 1) * T, sy * T, (w + 1) * T), Vector3(u * T, sy * T, (w + 1) * T), Vector3(0, 1, 0), col)
					3:
						ChunkMesher._quad(v, n, c, idx, Vector3(u * T, 0, w * T), Vector3((u + 1) * T, 0, w * T), Vector3((u + 1) * T, 0, (w + 1) * T), Vector3(u * T, 0, (w + 1) * T), Vector3(0, -1, 0), col)
					4:
						ChunkMesher._quad(v, n, c, idx, Vector3(u * T, y0, sz * T), Vector3((u + 1) * T, y0, sz * T), Vector3((u + 1) * T, y1, sz * T), Vector3(u * T, y1, sz * T), Vector3(0, 0, 1), col)
					5:
						ChunkMesher._quad(v, n, c, idx, Vector3(u * T, y0, 0), Vector3((u + 1) * T, y0, 0), Vector3((u + 1) * T, y1, 0), Vector3(u * T, y1, 0), Vector3(0, 0, -1), col)
	var m := _commit(v, n, c, idx, translucent)
	_part_cache[key] = m
	return m
