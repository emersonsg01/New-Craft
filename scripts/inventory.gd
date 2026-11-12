class_name Inventory
extends RefCounted
## Inventario em pilhas. Cada espaco e um Array [id, quantidade, desgaste] ou vazio ([0, 0, 0]).

var slots: Array = []


func _init(size: int) -> void:
	slots.resize(size)
	for i in size:
		slots[i] = [0, 0, 0]


func size() -> int:
	return slots.size()


func id_at(i: int) -> int:
	return slots[i][0]


func count_at(i: int) -> int:
	return slots[i][1]


func set_slot(i: int, id: int, n: int, wear: int = 0) -> void:
	if id <= 0 or n <= 0:
		slots[i] = [0, 0, 0]
	else:
		slots[i] = [id, n, wear]


func count(id: int) -> int:
	var n := 0
	for s: Array in slots:
		if s[0] == id:
			n += s[1]
	return n


## Adiciona e devolve quanto nao coube.
func add(id: int, n: int, wear: int = 0) -> int:
	if id <= 0 or n <= 0:
		return 0
	var mx := Items.max_stack(id)
	if mx > 1:
		for s: Array in slots:
			if s[0] == id and s[1] < mx:
				var put := mini(mx - s[1], n)
				s[1] += put
				n -= put
				if n == 0:
					return 0
	for i in slots.size():
		if slots[i][0] == 0:
			var put := mini(mx, n)
			slots[i] = [id, put, wear]
			n -= put
			if n == 0:
				return 0
	return n


## Remove n unidades (das ultimas pilhas primeiro). Devolve true se havia o suficiente.
func remove(id: int, n: int) -> bool:
	if count(id) < n:
		return false
	for i in range(slots.size() - 1, -1, -1):
		var s: Array = slots[i]
		if s[0] != id:
			continue
		var take := mini(s[1], n)
		s[1] -= take
		n -= take
		if s[1] <= 0:
			slots[i] = [0, 0, 0]
		if n == 0:
			break
	return true


func take_one(i: int) -> void:
	var s: Array = slots[i]
	s[1] -= 1
	if s[1] <= 0:
		slots[i] = [0, 0, 0]


## Gasta durabilidade; devolve true se a ferramenta quebrou.
func wear(i: int, amount: int = 1) -> bool:
	var s: Array = slots[i]
	var dur := Items.durability(s[0])
	if dur <= 0:
		return false
	s[2] += amount
	if s[2] >= dur:
		slots[i] = [0, 0, 0]
		return true
	return false


func is_empty() -> bool:
	for s: Array in slots:
		if s[0] != 0:
			return false
	return true


func to_array() -> Array:
	var out := []
	for s: Array in slots:
		out.append(s.duplicate())
	return out


func from_array(a: Array) -> void:
	for i in mini(a.size(), slots.size()):
		var s: Array = a[i]
		if s.size() >= 3:
			slots[i] = [int(s[0]), int(s[1]), int(s[2])]
