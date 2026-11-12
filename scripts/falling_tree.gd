class_name FallingTree
extends Node3D
## Arvore derrubada: os blocos viram um corpo rigido que tomba a partir da base, acelerando
## como um pendulo, e ao bater no chao emite "landed" com a posicao final de cada bloco.

signal landed(blocks: Array)

var _parts: Array = []
var _axis := Vector3.RIGHT
var _angle := 0.0
var _vel := 0.0
var _t := 0.0
var _done := false
var _body: Node3D
var _max_angle := PI * 0.5


## blocks: [[Vector3i, id], ...]; pivot: ponto da base em torno do qual tomba; dir: direcao da queda.
func setup(blocks: Array, pivot: Vector3, dir: Vector3, mesh_fn: Callable, max_angle: float = PI * 0.5) -> void:
	position = pivot
	_max_angle = max_angle
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3(1, 0, 0)
	_axis = Vector3.UP.cross(dir.normalized()).normalized()
	_body = Node3D.new()
	add_child(_body)
	for b: Array in blocks:
		var p: Vector3 = Vector3(b[0]) - pivot
		var mi := MeshInstance3D.new()
		mi.mesh = mesh_fn.call(b[1])
		mi.position = p - Vector3(8, 1, 8)
		_body.add_child(mi)
		_parts.append([p, b[1]])


func _process(dt: float) -> void:
	if _done:
		return
	_t += dt
	# Comeca devagar (a arvore "range") e acelera conforme inclina.
	_vel += (0.35 + sin(_angle) * 7.5) * dt
	_angle = minf(_angle + _vel * dt, _max_angle)
	_body.basis = Basis(_axis, _angle)
	# Pequena vibracao no comeco, como madeira estalando.
	if _t < 0.35:
		_body.position = Vector3(sin(_t * 80.0), 0, cos(_t * 70.0)) * 0.02
	else:
		_body.position = Vector3.ZERO
	if _angle >= _max_angle - 0.0001 or _t > 5.0:
		_done = true
		var out := []
		for pr: Array in _parts:
			var c: Vector3 = pr[0] + Vector3(0.5, 0.5, 0.5)
			out.append([global_transform * (_body.transform * c), pr[1]])
		landed.emit(out)
		queue_free()
