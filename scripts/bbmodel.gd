class_name BBModel
extends RefCounted
## Le projetos do Blockbench (.bbmodel, formato "Modelo padrao") e monta os nos do jogo:
## cada grupo vira um Node3D (osso) na articulacao (origin), cada cubo uma malha com a textura do projeto.
## Os nomes dos grupos ("legA__3", "head__12"...) definem os grupos de animacao do VoxelRig
## (o trecho antes de "__"). Funciona com arquivos salvos pelo Blockbench 4.x e 5.x.

const T := 1.0 / 16.0
const DIR := "res://assets/blockbench/"

static var _cache: Dictionary = {}
static var _meta: Dictionary = {}
static var _meta_loaded := false
static var _shader: Shader
static var _lock := Mutex.new()


## Dados extras de uma criatura (animacao, escala, ponto da sela) gerados com os modelos.
static func meta(name: String) -> Dictionary:
	_lock.lock()
	if not _meta_loaded:
		_meta_loaded = true
		var p := DIR + "creatures.json"
		if FileAccess.file_exists(p):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
			if d is Dictionary:
				_meta = d
	var out: Dictionary = _meta.get(name, {})
	_lock.unlock()
	return out


static func exists(name: String) -> bool:
	return FileAccess.file_exists(DIR + name + ".bbmodel")


## Projeto lido e ja convertido em malhas (cache por arquivo).
static func load_model(name: String) -> Dictionary:
	_lock.lock()
	var hit: Variant = _cache.get(name)
	_lock.unlock()
	if hit != null:
		return hit
	var path := DIR + name + ".bbmodel"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return {}
	var res := _convert(data)
	_lock.lock()
	_cache[name] = res
	_lock.unlock()
	return res


static func _material(texture: Texture2D, translucent: bool) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://shaders/voxel_tex.gdshader")
	var m := ShaderMaterial.new()
	if translucent:
		var sh := Shader.new()
		sh.code = _shader.code.replace("//ALPHA", "ALPHA = alpha * t.a;")
		m.shader = sh
		m.set_shader_parameter("alpha", 0.6)
	else:
		m.shader = _shader
	m.set_shader_parameter("tex", texture)
	return m


static func _convert(data: Dictionary) -> Dictionary:
	var res: Dictionary = data.get("resolution", {"width": 16, "height": 16})
	var texs: Array = data.get("textures", [])
	var images: Array[Texture2D] = []
	var sizes: Array[Vector2] = []
	for t: Dictionary in texs:
		var img := Image.new()
		var src: String = t.get("source", "")
		if src.begins_with("data:image/png;base64,"):
			img.load_png_from_buffer(Marshalls.base64_to_raw(src.substr(22)))
		elif t.get("path", "") != "" and FileAccess.file_exists(t["path"]):
			img.load(t["path"])
		if img.is_empty():
			img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(Color.MAGENTA)
		images.append(ImageTexture.create_from_image(img))
		sizes.append(Vector2(float(t.get("uv_width", res.get("width", 16))), float(t.get("uv_height", res.get("height", 16)))))
	var elements := {}
	for e: Dictionary in data.get("elements", []):
		elements[e["uuid"]] = e
	var groups := {}
	for g: Dictionary in data.get("groups", []):
		groups[g["uuid"]] = g
	# Arvore: [{name, origin, rotation, cubes: [elementos], children: [...]}]
	var tree: Array = []
	for o: Variant in data.get("outliner", []):
		var n: Variant = _node(o, elements, groups)
		if n != null:
			tree.append(n)
	return {"tree": tree, "textures": images, "uv_sizes": sizes}


static func _node(o: Variant, elements: Dictionary, groups: Dictionary) -> Variant:
	if o is String:
		if elements.has(o):
			return {"name": "solto", "origin": [0, 0, 0], "rotation": [0, 0, 0], "cubes": [elements[o]], "children": []}
		return null
	var od: Dictionary = o
	var g: Dictionary = od
	if not od.has("name") and groups.has(od.get("uuid", "")):
		g = groups[od["uuid"]]
	var out := {"name": g.get("name", "grupo"), "origin": g.get("origin", [0, 0, 0]), "rotation": g.get("rotation", [0, 0, 0]),
		"visible": g.get("visibility", true), "cubes": [], "children": []}
	for c: Variant in od.get("children", []):
		if c is String:
			if elements.has(c):
				out["cubes"].append(elements[c])
		else:
			var n: Variant = _node(c, elements, groups)
			if n != null:
				out["children"].append(n)
	return out


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _rot_basis(r: Array) -> Basis:
	var e := Vector3(deg_to_rad(float(r[0])), deg_to_rad(float(r[1])), deg_to_rad(float(r[2])))
	return Basis.from_euler(e, EULER_ORDER_ZYX)


## Monta os nos dentro de root. Devolve {"groups": {nome: [Node3D]}, "meshes": [MeshInstance3D]}.
static func build_into(root: Node3D, name: String, translucent: bool = false) -> Dictionary:
	var m := load_model(name)
	var out := {"groups": {}, "meshes": []}
	if m.is_empty():
		return out
	var mats: Array = []
	for t: Texture2D in m["textures"]:
		mats.append(_material(t, translucent))
	for n: Dictionary in m["tree"]:
		_build_node(root, n, Vector3.ZERO, m, mats, out)
	return out


static func _build_node(parent: Node3D, n: Dictionary, parent_origin: Vector3, m: Dictionary, mats: Array, out: Dictionary) -> void:
	if not n.get("visible", true):
		return
	var origin := _v(n["origin"])
	var node := Node3D.new()
	node.name = str(n["name"]).validate_node_name()
	node.position = (origin - parent_origin) * T
	node.basis = _rot_basis(n["rotation"])
	parent.add_child(node)
	var gname: String = str(n["name"]).split("__")[0]
	if not out["groups"].has(gname):
		out["groups"][gname] = []
	out["groups"][gname].append(node)
	if not n["cubes"].is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = _cubes_mesh(n["cubes"], origin, m, mats)
		node.add_child(mi)
		out["meshes"].append(mi)
	for c: Dictionary in n["children"]:
		_build_node(node, c, origin, m, mats, out)


## Ordem dos cantos de cada face (vistos de fora): [esq-cima, dir-cima, dir-baixo, esq-baixo] no espaco do cubo 0..1.
const _FACES := {
	"north": [Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	"south": [Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1)],
	"east": [Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(1, 0, 0)],
	"west": [Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1), Vector3(0, 0, 0), Vector3(-1, 0, 0)],
	"up": [Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 1, 0)],
	"down": [Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, -1, 0)],
}


static func _cubes_mesh(cubes: Array, group_origin: Vector3, m: Dictionary, mats: Array) -> ArrayMesh:
	# Uma superficie por textura.
	var surf := {}
	for e: Dictionary in cubes:
		if not e.get("visibility", true):
			continue
		var infl: float = float(e.get("inflate", 0.0))
		var a := _v(e["from"]) - Vector3.ONE * infl
		var b := _v(e["to"]) + Vector3.ONE * infl
		var co := _v(e.get("origin", [0, 0, 0]))
		var rb := _rot_basis(e.get("rotation", [0, 0, 0]))
		var faces: Dictionary = e.get("faces", {})
		for fname: String in _FACES:
			if not faces.has(fname):
				continue
			var fd: Dictionary = faces[fname]
			var ti: Variant = fd.get("texture", 0)
			if ti == null:
				continue
			var tidx := int(ti) if (ti is int or ti is float) else 0
			if tidx >= mats.size():
				tidx = 0
			if not surf.has(tidx):
				surf[tidx] = [PackedVector3Array(), PackedVector3Array(), PackedVector2Array(), PackedInt32Array()]
			var s: Array = surf[tidx]
			var spec: Array = _FACES[fname]
			var uvs: Vector2 = m["uv_sizes"][tidx] if tidx < m["uv_sizes"].size() else Vector2(16, 16)
			var uv: Array = fd.get("uv", [0, 0, 16, 16])
			var u1 := float(uv[0]) / uvs.x
			var v1 := float(uv[1]) / uvs.y
			var u2 := float(uv[2]) / uvs.x
			var v2 := float(uv[3]) / uvs.y
			var tc: Array = [Vector2(u1, v1), Vector2(u2, v1), Vector2(u2, v2), Vector2(u1, v2)]
			var rot := int(fd.get("rotation", 0)) / 90
			for k in rot % 4:
				tc = [tc[3], tc[0], tc[1], tc[2]]
			var nrm: Vector3 = rb * (spec[4] as Vector3)
			# Arrays compactados dentro de Array sao copias: edita localmente e devolve.
			var pv: PackedVector3Array = s[0]
			var pn: PackedVector3Array = s[1]
			var pt: PackedVector2Array = s[2]
			var idx: PackedInt32Array = s[3]
			var base := pv.size()
			for k in 4:
				var c: Vector3 = spec[k]
				var p := Vector3(lerpf(a.x, b.x, c.x), lerpf(a.y, b.y, c.y), lerpf(a.z, b.z, c.z))
				p = co + rb * (p - co)
				pv.append((p - group_origin) * T)
				pn.append(nrm)
				pt.append(tc[k])
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
			s[0] = pv
			s[1] = pn
			s[2] = pt
			s[3] = idx
	var mesh := ArrayMesh.new()
	for tidx: int in surf:
		var s: Array = surf[tidx]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s[0]
		arr[Mesh.ARRAY_NORMAL] = s[1]
		arr[Mesh.ARRAY_TEX_UV] = s[2]
		arr[Mesh.ARRAY_INDEX] = s[3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[tidx])
	return mesh
