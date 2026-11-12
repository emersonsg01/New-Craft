class_name RemotePlayer
extends Node3D
## Outro jogador conectado: boneco com a aparencia dele, nome em cima e movimento interpolado.
## Tem "alive" e "damage" para as criaturas poderem atacar como fazem com o jogador local.

var net: Variant
var peer_id := 0
var alive := true
var rig: VoxelRig
var _label: Label3D
var _target := Vector3.ZERO
var _yaw := 0.0
var _speed := 0.0
var _grounded := true
var _riding := false
var _dim := 0
var _has := false


func setup(n: Variant, id: int, nm: String, app: Dictionary) -> void:
	net = n
	peer_id = id
	rig = VoxelRig.new()
	add_child(rig)
	rig.build(Rigs.humanoid(app))
	_label = Label3D.new()
	_label.text = nm
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 2.15, 0)
	_label.pixel_size = 0.006
	_label.outline_size = 8
	_label.modulate = Color(1, 1, 1)
	_label.no_depth_test = true
	add_child(_label)
	visible = false


## st = [posicao, yaw, pitch, velocidade, no_chao, montado, dimensao]
func apply_state(st: Array) -> void:
	_target = st[0]
	_yaw = st[1]
	_speed = st[3]
	_grounded = st[4]
	_riding = st[5]
	_dim = int(st[6]) if st.size() > 6 else 0
	if not _has:
		position = _target
		_has = true


func damage(amount: float, from: Vector3) -> void:
	if net != null:
		net.hurt_remote(peer_id, amount, from)


func _process(dt: float) -> void:
	if not _has:
		return
	var local_dim: int = net.world.dim if net != null and net.world != null else 0
	visible = _dim == local_dim
	alive = visible
	position = position.lerp(_target, 1.0 - exp(-dt * 12.0))
	rig.rotation.y = lerp_angle(rig.rotation.y, _yaw, 1.0 - exp(-dt * 12.0))
	rig.pose = "ride" if _riding else ""
	rig.animate(dt, _speed if not _riding else 0.0, _grounded or _riding)
