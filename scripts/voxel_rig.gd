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


func build(d: Dictionary) -> void:
	for ch in get_children():
		ch.queue_free()
	groups.clear()
	meshes.clear()
	anim = d.get("anim", "biped")
	_seed = randf() * TAU
	_t = randf() * 20.0
	pose = d.get("pose", "")
	_root = Node3D.new()
	var sc: float = d.get("scale", 1.0)
	_root.scale = Vector3.ONE * sc
	add_child(_root)
	var translucent: bool = d.get("alpha", false)
	var seed_v := 1
	for p: Dictionary in d["parts"]:
		seed_v += 7
		var size: Vector3i = p["size"]
		var pos: Vector3 = p["pos"]
		var pivot: Vector3 = p.get("pivot", pos + Vector3(size) * 0.5)
		var node := Node3D.new()
		node.position = pivot * VoxelArt.T
		_root.add_child(node)
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
	amp = lerpf(amp, target, 1.0 - exp(-dt * 10.0))
	phase += dt * (3.0 + speed * 2.2)
	var sw := sin(phase) * amp
	var hit := sin(attack_t * PI)
	match anim:
		"biped":
			_set_x("legA", sw * 0.9)
			_set_x("legB", -sw * 0.9)
			if pose == "reach":
				_set_x("armA", 1.45 + sw * 0.15 + hit * 0.5)
				_set_x("armB", 1.45 - sw * 0.15 + hit * 0.5)
			else:
				_set_x("armA", -sw * 0.8 + hit * 1.6)
				_set_x("armB", sw * 0.8)
			_set_x("head", sin(_t * 0.7) * 0.05)
		"quad":
			_set_x("legA", sw * 0.7)
			_set_x("legB", -sw * 0.7)
			# Parado, de vez em quando abaixa a cabeca para pastar.
			var graze := 0.0
			if amp < 0.2:
				graze = smoothstep(0.55, 0.85, sin(_t * 0.31 + _seed * 2.1)) * (1.0 - amp * 5.0)
			_set_x("head", sin(_t * 0.9) * 0.08 - hit * 0.5 - graze * 0.75 + sin(_t * 9.0) * 0.03 * graze)
			_set_y("tail", sin(_t * 5.0) * 0.4)
			# Rabo pendente espanta moscas; orelhas se mexem.
			_set_z("tailz", sin(_t * 2.3 + _seed) * 0.28 + sin(_t * 7.0) * 0.06)
			var tw := pow(maxf(0.0, sin(_t * 1.7 + _seed * 3.0)), 12.0)
			_set_z("earA", -tw * 0.35)
			_set_z("earB", tw * 0.35)
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


func set_flash(f: float) -> void:
	for mi in meshes:
		mi.set_instance_shader_parameter("flash", f)
