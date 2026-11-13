class_name VoxelRig
extends Node3D
## Boneco articulado feito de caixas voxel (VoxelArt.part_mesh). Cada parte tem um pivo e um
## grupo de animacao; animate() balanca os grupos conforme o tipo de locomocao.

var groups: Dictionary = {}
var meshes: Array[MeshInstance3D] = []
var anim := "biped"
var pose := ""
var phase := 0.0
var amp := 0.0
var attack_t := 0.0
var _root: Node3D
var _t := 0.0
var _seed := 0.0
## Giro da cabeca para os lados (olhar), definido pela IA.
var look_yaw := 0.0
var _look := 0.0
## Altura base do corpo (para o balanco ao andar).
var _base_y := 0.0


func build(d: Dictionary) -> void:
	for ch in get_children():
		ch.queue_free()
	groups.clear()
	meshes.clear()
	anim = d.get("anim", "biped")
	_seed = randf() * TAU
	_t = randf() * 20.0
	_base_y = 0.0
	pose = d.get("pose", "")
	_root = Node3D.new()
	var sc: float = d.get("scale", 1.0)
	_root.scale = Vector3.ONE * sc
	add_child(_root)
	var translucent: bool = d.get("alpha", false)
	# Modelo do Blockbench: ossos e malhas vem do .bbmodel; partes extras (sela) somam por cima.
	if d.has("bbmodel"):
		var bb := BBModel.build_into(_root, d["bbmodel"], translucent)
		for gk: String in bb["groups"]:
			if not groups.has(gk):
				groups[gk] = []
			groups[gk].append_array(bb["groups"][gk])
		for mi: MeshInstance3D in bb["meshes"]:
			meshes.append(mi)
	var seed_v := 1
	var nodes: Array[Node3D] = []
	var pivots: Array[Vector3] = []
	for p: Dictionary in d["parts"]:
		seed_v += 7
		var size: Vector3i = p["size"]
		var pos: Vector3 = p["pos"]
		var pivot: Vector3 = p.get("pivot", pos + Vector3(size) * 0.5)
		var node := Node3D.new()
		# Articulacao: a parte pode pender de outra (joelho na coxa, antebraco no braco...).
		var pi: int = p.get("parent_i", -1)
		if pi >= 0 and pi < nodes.size():
			node.position = (pivot - pivots[pi]) * VoxelArt.T
			nodes[pi].add_child(node)
		else:
			node.position = pivot * VoxelArt.T
			_root.add_child(node)
		nodes.append(node)
		pivots.append(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = VoxelArt.part_mesh(size, p["col"], p.get("spk", 0.12), p.get("feats", []), seed_v, translucent)
		var infl: float = p.get("infl", 0.0)
		var local := (pos - pivot) * VoxelArt.T
		if infl > 0.0:
			var half := Vector3(size) * VoxelArt.T * 0.5
			mi.scale = Vector3.ONE * (1.0 + infl)
			mi.position = local + half - half * (1.0 + infl)
		else:
			mi.position = local
		node.add_child(mi)
		meshes.append(mi)
		var g: String = p.get("g", "")
		if g != "":
			if not groups.has(g):
				groups[g] = []
			groups[g].append(node)


func _set_x(group: String, angle: float) -> void:
	for n: Node3D in groups.get(group, []):
		n.rotation.x = angle


func _set_z(group: String, angle: float) -> void:
	for n: Node3D in groups.get(group, []):
		n.rotation.z = angle


var _z0: Dictionary = {}

func _head_z0(n: Node3D) -> float:
	if not _z0.has(n):
		_z0[n] = n.position.z
	return _z0[n]


func _set_y(group: String, angle: float) -> void:
	for n: Node3D in groups.get(group, []):
		n.rotation.y = angle


## speed: velocidade horizontal em m/s; grounded: no chao.
func animate(dt: float, speed: float, grounded: bool = true) -> void:
	_t += dt
	attack_t = maxf(0.0, attack_t - dt * 3.5)
	var target := clampf(speed / 3.0, 0.0, 1.0) if grounded else 0.3
	amp = lerpf(amp, target, 1.0 - exp(-dt * 8.0))
	# Passada: mais rapida e mais longa com a velocidade.
	phase += dt * (3.0 + speed * 2.0)
	var sw := sin(phase) * amp
	var cw := cos(phase)
	var hit := sin(attack_t * PI)
	_look = lerp_angle(_look, look_yaw, 1.0 - exp(-dt * 4.0))
	match anim:
		"biped":
			if pose == "ride":
				# Montado: pernas abertas para a frente, joelhos dobrados, maos nas redeas.
				_set_x("legA", 1.15)
				_set_x("legB", 1.15)
				_set_z("legA", 0.28)
				_set_z("legB", -0.28)
				_set_x("legA2", -1.25)
				_set_x("legB2", -1.25)
				_set_x("armA", 0.55 + hit * 1.4)
				_set_x("armB", 0.55)
				_set_x("armA2", 0.7)
				_set_x("armB2", 0.7)
				_root.position.y = _base_y
				_root.rotation.x = 0.0
			else:
				_set_z("legA", 0.0)
				_set_z("legB", 0.0)
				_set_x("legA", sw * 0.85)
				_set_x("legB", -sw * 0.85)
				# Joelho dobra quando a perna passa para a frente.
				_set_x("legA2", -maxf(0.0, cw) * 1.15 * amp - 0.04)
				_set_x("legB2", -maxf(0.0, -cw) * 1.15 * amp - 0.04)
				if pose == "reach":
					_set_x("armA", 1.45 + sw * 0.15 + hit * 0.5)
					_set_x("armB", 1.45 - sw * 0.15 + hit * 0.5)
					_set_x("armA2", 0.1)
					_set_x("armB2", 0.1)
				else:
					_set_x("armA", -sw * 0.75 + hit * 1.6)
					_set_x("armB", sw * 0.75)
					# Cotovelo sempre um pouco dobrado, mais no balanco para a frente e no golpe.
					_set_x("armA2", 0.18 + maxf(0.0, -sw) * 0.55 + hit * 0.6)
					_set_x("armB2", 0.18 + maxf(0.0, sw) * 0.55)
					# Segurando algo: braco um pouco a frente, balanco menor, antebraco erguido.
					match hold_kind[0]:
						"tool", "item", "bow":
							_set_x("armA", 0.2 - sw * 0.4 + hit * 1.6)
							_set_x("armA2", 0.45 + maxf(0.0, -sw) * 0.25 + hit * 0.5)
						"lantern", "torch", "block":
							_set_x("armA", 0.15 - sw * 0.3 + hit * 1.6)
							_set_x("armA2", 0.75 + hit * 0.5)
						"shield":
							_set_x("armA", 0.25 + sw * 0.12 + hit * 1.2)
							_set_x("armA2", 1.05)
					match hold_kind[1]:
						"shield":
							# Escudo carregado a frente do corpo, antebraco dobrado.
							_set_x("armB", 0.25 + sw * 0.12)
							_set_x("armB2", 1.05)
						"tool", "item", "bow":
							_set_x("armB", 0.2 + sw * 0.4)
							_set_x("armB2", 0.45 + maxf(0.0, sw) * 0.25)
						"lantern", "torch", "block":
							_set_x("armB", 0.15 + sw * 0.3)
							_set_x("armB2", 0.75)
				# Corpo sobe e desce a cada passo e inclina para a frente ao correr; respira parado.
				_root.position.y = _base_y + (absf(cw) - 0.6) * 0.05 * amp + sin(_t * 2.2) * 0.004 * (1.0 - amp)
				_root.rotation.x = -0.09 * amp * clampf(speed / 5.0, 0.3, 1.0)
			_level_held()
			_set_x("head", sin(_t * 0.7) * 0.05 + (0.06 * amp if pose != "ride" else 0.0))
			_set_y("head", _look + sin(_t * 0.37 + _seed) * 0.12 * (1.0 - amp))
		"quad":
			_set_x("legA", sw * 0.65)
			_set_x("legB", -sw * 0.65)
			_set_x("legA2", -maxf(0.0, cw) * 0.8 * amp)
			_set_x("legB2", -maxf(0.0, -cw) * 0.8 * amp)
			# Parado, de vez em quando abaixa a cabeca para pastar.
			var graze := 0.0
			if amp < 0.2:
				graze = smoothstep(0.55, 0.85, sin(_t * 0.31 + _seed * 2.1)) * (1.0 - amp * 5.0)
			var nod := sin(phase * 2.0) * 0.06 * amp
			_set_x("head", sin(_t * 0.9) * 0.08 - hit * 0.5 - graze * 0.75 + sin(_t * 9.0) * 0.03 * graze + nod)
			_set_y("head", _look * (1.0 - graze) + sin(_t * 0.29 + _seed) * 0.15 * (1.0 - amp) * (1.0 - graze))
			_set_y("tail", sin(_t * 5.0) * 0.4)
			# Rabo pendente espanta moscas; orelhas se mexem.
			_set_z("tailz", sin(_t * 2.3 + _seed) * 0.28 + sin(_t * 7.0) * 0.06)
			_set_z("tailz2", sin(_t * 2.3 + _seed - 0.8) * 0.35)
			_set_x("tailz", -0.5 * amp)
			var tw := pow(maxf(0.0, sin(_t * 1.7 + _seed * 3.0)), 12.0)
			_set_z("earA", -tw * 0.35)
			_set_z("earB", tw * 0.35)
			_root.position.y = _base_y + (absf(cw) - 0.6) * 0.035 * amp + sin(_t * 1.8) * 0.006
			_root.rotation.z = sw * 0.02
		"bird":
			_set_x("legA", sw * 1.0)
			_set_x("legB", -sw * 1.0)
			# Asas abrem e batem quando corre, cai ou leva dano; parado, so um leve tremor.
			var flap := 0.06 + amp * 0.35 + (0.0 if grounded else 0.9) + hit * 0.8
			var wa := (0.5 + 0.5 * sin(_t * 22.0)) * flap
			_set_z("wingA", wa)
			_set_z("wingB", -wa)
			# Cabeca vai e volta ao andar, como uma galinha.
			for n: Node3D in groups.get("head", []):
				n.position.z = _head_z0(n) - (0.5 + 0.5 * sin(phase * 2.0)) * amp * 0.06
			_set_x("tail", sin(_t * 3.0) * 0.12)
			_set_y("head", _look + sin(_t * 1.3 + _seed) * 0.35 * (1.0 - amp))
			_root.rotation.z = sw * 0.08
		"spider":
			_set_y("legA", sw * 0.45)
			_set_y("legB", -sw * 0.45)
			_set_x("head", -hit * 0.4)
		"hop":
			var bs := _base_scale()
			var sq := 1.0 + sin(_t * 6.0) * 0.1 * (0.3 + amp)
			_root.scale = Vector3(bs / sq, bs * sq, bs / sq)
		"float":
			_root.position.y = sin(_t * 2.0) * 0.12 + 0.2
			_set_x("armA", 1.2 + sin(_t * 1.7) * 0.2 + hit * 0.6)
			_set_x("armB", 1.2 - sin(_t * 1.3) * 0.2 + hit * 0.6)


var _bscale := -1.0

func _base_scale() -> float:
	if _bscale < 0.0:
		_bscale = _root.scale.y
	return _bscale


func attack() -> void:
	attack_t = 1.0


## Itens nas maos: [no de pegada, tipo] por mao (0 = direita, 1 = esquerda).
var _held: Array = [null, null]
var hold_kind: Array = ["", ""]


## Tipo de pegada para um item ou bloco.
static func grip_kind(id: int) -> String:
	if id <= 0:
		return ""
	if Items.is_item(id):
		var k: String = Items.def(id).get("kind", "")
		if k == "shield":
			return "shield"
		if k == "bow":
			return "bow"
		if k == "tool" or k == "weapon" or k == "shears" or k == "igniter":
			return "tool"
		return "item"
	if id == Blocks.LANTERN:
		return "lantern"
	if id == Blocks.TORCH:
		return "torch"
	return "block"


## Coloca (ou tira, mesh null) um item na mao. A pegada fica no punho:
## ferramentas pelo cabo, apontando para a frente; arco em pe pelo meio; escudo no antebraco virado
## para a frente; lanterna pendurada; tocha em pe; bloco na palma. Devolve a malha (ou null).
func set_held(slot: int, mesh: Mesh, kind: String) -> MeshInstance3D:
	if _held[slot] != null and is_instance_valid(_held[slot]):
		(_held[slot] as Node).queue_free()
	_held[slot] = null
	hold_kind[slot] = ""
	var g := "armA2" if slot == 0 else "armB2"
	var arms: Array = groups.get(g, groups.get("armA" if slot == 0 else "armB", []))
	if arms.is_empty() or mesh == null or kind == "":
		return null
	var arm: Node3D = arms[0]
	var anchor := Node3D.new()
	if groups.has(g):
		anchor.position = Vector3(0, -arm.position.y, 0)
	arm.add_child(anchor)
	# Punho: ponta de baixo do braco (no referencial do ombro).
	var grip := Node3D.new()
	grip.position = Vector3(0, -0.56, -0.01)
	anchor.add_child(grip)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	grip.add_child(mi)
	var side := 1.0 if slot == 0 else -1.0
	match kind:
		"tool", "item", "bow":
			# Desenho 16x16 com o cabo no canto de baixo a esquerda e a ponta em cima a direita.
			var up := 0.32 if kind == "tool" else (1.35 if kind == "bow" else 0.7)
			var sc := 0.62 if kind == "tool" else (0.7 if kind == "bow" else 0.38)
			var handle := Vector3(-0.34, -0.29, 0.0) if kind == "tool" else Vector3.ZERO
			var dir := Vector3(0, sin(up), -cos(up))
			var perp := Vector3(0, cos(up), sin(up))
			var ex := (dir - perp).normalized()
			var ey := (dir + perp).normalized()
			var bs := Basis(ex, ey, ex.cross(ey)).scaled(Vector3.ONE * sc)
			mi.basis = bs
			mi.position = -(bs * handle) + Vector3(side * 0.01, 0, 0)
		"shield":
			mi.scale = Vector3.ONE * 0.72
			mi.position = Vector3(side * 0.07, 0.16, -0.06)
		"lantern":
			mi.scale = Vector3.ONE * 0.34
			mi.position = -Vector3(8.5, 2.0, 8.5) * 0.34
		"torch":
			mi.scale = Vector3.ONE * 0.46
			mi.position = -Vector3(8.5, 1.3, 8.5) * 0.46 + Vector3(0, 0, -0.02)
		_:
			mi.scale = Vector3.ONE * 0.2
			mi.position = -Vector3(8.5, 1.5, 8.5) * 0.2 + Vector3(0, 0.03, -0.06)
	_held[slot] = grip
	hold_kind[slot] = kind
	return mi


## Compatibilidade: segura um item (true) ou bloco (false).
func hold(slot: int, mesh: Mesh, is_item: bool) -> MeshInstance3D:
	return set_held(slot, mesh, "tool" if is_item else "block")


## Escudo, lanterna, tocha e blocos ficam alinhados ao corpo (o escudo de frente, a lanterna pendurada).
func _level_held() -> void:
	for k in 2:
		var gn: Variant = _held[k]
		if gn == null or not is_instance_valid(gn):
			continue
		var kd: String = hold_kind[k]
		if kd == "shield" or kd == "lantern" or kd == "torch" or kd == "block":
			(gn as Node3D).global_basis = global_basis.orthonormalized()


func set_flash(f: float) -> void:
	for mi in meshes:
		mi.set_instance_shader_parameter("flash", f)
