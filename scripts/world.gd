class_name World
extends Node3D
## Gerencia os chunks: geracao e malha em threads, edicao de blocos, colisao e raycast voxel.

const H := ChunkMesher.H
const SAVE_PATH := "user://world_v4.save"
const DIM_NAMES: Array[String] = ["Superfície", "Profundezas Ígneas", "Ilhas Etéreas"]

class Chunk:
	var key: Vector2i
	var blocks: PackedByteArray
	var shapes: Dictionary = {}
	var top := 0
	var has_data := false
	var meshing := false
	var dirty := true
	var meshed := false
	var version := 0
	var mi: MeshInstance3D
	var lights: Dictionary = {}
	var lite := false
	## Celulas micro: idx -> PackedByteArray(512); caixas de colisao em cache.
	var micro: Dictionary = {}
	var micro_boxes: Dictionary = {}

var gen: WorldGen
var gpu: GpuWorldGen
## Raio (m) ate onde os voxels estao completos; alem dele o terreno distante assume.
var near_radius := 0.0
var far_enabled := true
var mats: Array = []
var chunks: Dictionary = {}
var mods: Dictionary = {}
## Edicoes por dimensao; mods aponta para a dimensao atual.
var all_mods: Dictionary = {0: {}, 1: {}, 2: {}}
## Celulas micro editadas: dim -> {chunk -> {idx -> PackedByteArray}}.
var all_micro: Dictionary = {0: {}, 1: {}, 2: {}}
var micro_mods: Dictionary = {}
## Multijogador: rede (ou null), se este peer simula liquidos/plantacoes, e trava para nao reenviar edicoes recebidas.
var net: Variant = null
var simulate := true
var _net_mute := false
var dim := 0
## Conteudo dos baus: Vector4i(x, y, z, dim) -> Inventory.
var containers: Dictionary = {}
## Baus gerados por estruturas que ainda nao foram abertos: Vector4i -> nivel do saque.
var loot_pos: Dictionary = {}
## Blocos que crescem com o tempo (plantacoes, mudas, arbustos): Vector4i -> true.
var ticks: Dictionary = {}
## NPCs gerados pelas vilas, aguardando o gerenciador de criaturas.
var pending_npcs: Array = []
## Blocos de construcoes de vila quebrados pelo jogador: [pos, id, forma]; o construtor conserta.
var village_damage: Array = []
## Multiplicador de crescimento definido pela estacao do ano.
var season_growth := 1.0
## Fornalhas: Vector4i -> {"inv": Inventory(3) [entrada, combustivel, saida], "burn", "burn_max", "cook"}.
var furnaces: Dictionary = {}
const COOK_TIME := 2.5
static var _smelt: Dictionary = {}
var _tick_t := 0.0
## Celulas de liquido para reavaliar (Vector3i -> true). Agua anda a cada 0,2 s; lava a cada 0,9 s.
var _fluid_q: Dictionary = {}
var _water_t := 0.0
var _lava_t := 0.0
const DIRS4: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
var _rng := RandomNumberGenerator.new()
var render_distance := 7
## Raio pedido nas opcoes (ate 256) e raio efetivo limitado pelo orcamento de RAM/VRAM.
var requested_distance := 7
var max_chunks := 1000000
var ram_per_chunk := 120000.0
var vram_per_chunk := 120000.0
var meshed_count := 0
var _base_ram := 0.0
var _base_vram := 0.0
var _budget_t := 0.0
var _ram_sample: Array = []
var _vram_sample: Array = []
var _scan_i := 0
var _pass_missing := INF
var _pass_center := Vector2i(999999, 999999)
## Alem deste raio (em chunks) a malha e "leve": sem plantas nem planos internos das folhas.
const LITE_DIST := 20
const SHADOW_DIST := 10
var center := Vector2i(999999, 999999)
var focus := Vector3.ZERO

var _mutex := Mutex.new()
var _mesh_results: Array = []
var _tasks: Array[int] = []
var _gen_inflight := 0
var _mesh_inflight := 0
var _urgent: Array[Vector2i] = []
var _offsets: Array[Vector2i] = []
var _max_jobs := 4
var _frame := 0
var _stopping := false
var _last_key := Vector2i(999999, 999999)
var _last_chunk: Chunk = null


func setup(seed_v: int, materials: Array, saved: Dictionary) -> void:
	gen = WorldGen.new(seed_v)
	gpu = GpuWorldGen.new()
	gpu.start(gen)
	mats = materials
	_rng.randomize()
	var am: Dictionary = saved.get("all_mods", {})
	for d in 3:
		all_mods[d] = am.get(d, {})
	dim = int(saved.get("dim", 0))
	mods = all_mods[dim]
	var amc: Dictionary = saved.get("all_micro", {})
	for d in 3:
		all_micro[d] = amc.get(d, {})
	micro_mods = all_micro[dim]
	for k: Vector4i in saved.get("containers", {}):
		var inv := Inventory.new(27)
		inv.from_array(saved["containers"][k])
		containers[k] = inv
	loot_pos = saved.get("loot_pos", {})
	ticks = saved.get("ticks", {})
	for k: Vector4i in saved.get("furnaces", {}):
		var fd: Dictionary = saved["furnaces"][k]
		var inv := Inventory.new(3)
		inv.from_array(fd["inv"])
		furnaces[k] = {"inv": inv, "burn": float(fd.get("burn", 0.0)), "burn_max": float(fd.get("burn_max", 1.0)), "cook": float(fd.get("cook", 0.0))}
	_max_jobs = GameSettings.worker_threads()
	requested_distance = render_distance
	_base_ram = Performance.get_monitor(Performance.MEMORY_STATIC)
	_base_vram = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)
	set_render_distance(render_distance)


func request_distance(r: int) -> void:
	requested_distance = clampi(r, 3, 256)
	_update_budget(true)


## Orcamento: quantos chunks cabem na fatia de RAM e VRAM escolhida, medindo o custo real por chunk.
func _update_budget(force: bool = false) -> void:
	_max_jobs = GameSettings.worker_threads()
	var n := chunks.size()
	var mc := 0
	for c: Chunk in chunks.values():
		if c.meshed:
			mc += 1
	meshed_count = mc
	var ram := Performance.get_monitor(Performance.MEMORY_STATIC)
	var vram := float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED))
	# Custo marginal: diferenca entre duas amostras com pelo menos 200 chunks de distancia
	# (assim texturas e outros recursos carregados depois nao inflam a conta).
	if _ram_sample.is_empty():
		_ram_sample = [n, ram]
		_vram_sample = [mc, vram]
	if absi(n - int(_ram_sample[0])) >= 200:
		var est := (ram - float(_ram_sample[1])) / float(n - int(_ram_sample[0]))
		if est > 0.0:
			ram_per_chunk = clampf(lerpf(ram_per_chunk, est, 0.5), 30000.0, 4000000.0)
		_ram_sample = [n, ram]
	if absi(mc - int(_vram_sample[0])) >= 200:
		var est := (vram - float(_vram_sample[1])) / float(mc - int(_vram_sample[0]))
		if est > 0.0:
			vram_per_chunk = clampf(lerpf(vram_per_chunk, est, 0.5), 20000.0, 4000000.0)
		_vram_sample = [mc, vram]
	_base_ram = ram - ram_per_chunk * n
	_base_vram = vram - vram_per_chunk * mc
	var ram_budget := Hardware.ram_total * float(GameSettings.get_v("ram_budget")) / 100.0
	var vram_budget := Hardware.vram_total * float(GameSettings.get_v("vram_budget")) / 100.0
	var cap_ram := (ram_budget - _base_ram) / ram_per_chunk
	var cap_vram := (vram_budget - _base_vram) / vram_per_chunk
	# Folga: se o sistema estiver com pouca memoria livre, encolhe.
	var avail := float(OS.get_memory_info().get("available", 4.0 * Hardware.GB))
	if avail > 0.0 and avail < 1.0 * Hardware.GB:
		cap_ram = minf(cap_ram, n * 0.85)
	max_chunks = maxi(150, int(minf(cap_ram, cap_vram)))
	# Chunks carregados ~ quadrado de lado 2r + 5.
	var r_cap := int((sqrt(float(max_chunks)) - 5.0) * 0.5)
	var eff := clampi(mini(requested_distance, r_cap), 3, 256)
	if force or eff < render_distance or eff >= render_distance + 2:
		if eff != render_distance:
			set_render_distance(eff)


func set_render_distance(r: int) -> void:
	render_distance = clampi(r, 3, 256)
	_scan_i = 0
	_pass_missing = INF
	_build_offsets()
	_offsets = _OFF


## Todas as posicoes de chunk ate o raio 258, do centro para fora (montada uma vez, ordenacao nativa).
static var _OFF: Array[Vector2i] = []

static func _build_offsets() -> void:
	if not _OFF.is_empty():
		return
	var R := 258
	var w := 2 * R + 1
	var keys := PackedInt64Array()
	keys.resize(w * w)
	var i := 0
	for z in range(-R, R + 1):
		for x in range(-R, R + 1):
			keys[i] = ((x * x + z * z) << 20) | ((z + R) * w + (x + R))
			i += 1
	keys.sort()
	_OFF.resize(w * w)
	for j in keys.size():
		var idx := keys[j] & 0xFFFFF
		_OFF[j] = Vector2i(idx % w - R, idx / w - R)


func _process(_dt: float) -> void:
	if _stopping:
		return
	_frame += 1
	# Tarefas concluidas precisam ser "esperadas" para liberar o id.
	var k := _tasks.size() - 1
	while k >= 0:
		if WorkerThreadPool.is_task_completed(_tasks[k]):
			WorkerThreadPool.wait_for_task_completion(_tasks[k])
			_tasks.remove_at(k)
		k -= 1
	_drain()
	center = Vector2i(floori(focus.x / 16.0), floori(focus.z / 16.0))
	_schedule()
	_budget_t += _dt
	if _budget_t >= 2.0:
		_budget_t = 0.0
		_update_budget()
	_tick_furnaces(_dt)
	# Plantacoes e liquidos: so quem simula o mundo (no multijogador, o host ou o simulador).
	if simulate:
		_tick_t += _dt
		if _tick_t >= 1.0:
			_tick_t = 0.0
			_random_ticks()
		_water_t += _dt
		_lava_t += _dt
		if _water_t >= 0.2:
			_water_t = 0.0
			_step_fluids(1)
		if _lava_t >= 0.9:
			_lava_t = 0.0
			_step_fluids(2)
	if _frame % 60 == 0:
		_unload_far()


func _drain() -> void:
	var gr := gpu.take_results()
	_mutex.lock()
	var mr := _mesh_results
	_mesh_results = []
	_mutex.unlock()
	for r: Array in gr:
		_gen_inflight -= 1
		if int(r[2]) != dim:
			continue
		var c: Chunk = chunks.get(r[0])
		if c == null:
			continue
		var d: Dictionary = r[1]
		var ox: int = c.key.x * 16
		var oz: int = c.key.y * 16
		for idx: int in d.get("ticks", []):
			var tk := Vector4i(ox + (idx & 15), idx >> 8, oz + ((idx >> 4) & 15), dim)
			if not mods.get(c.key, {}).has(idx):
				ticks[tk] = true
		for lt: Array in d.get("loot", []):
			var lk := Vector4i(ox + (int(lt[0]) & 15), int(lt[0]) >> 8, oz + ((int(lt[0]) >> 4) & 15), dim)
			if not containers.has(lk):
				loot_pos[lk] = lt[1]
		for np: Array in d.get("npcs", []):
			pending_npcs.append(np)
		c.blocks = d["blocks"]
		c.shapes = d["shapes"]
		c.top = d["top"]
		# Micro-celulas geradas (pedrinhas, galhos, raizes, peitoris) e as editadas pelo jogador.
		var cm: Dictionary = mods.get(c.key, {})
		var gm: Dictionary = d.get("micro", {})
		for idx: int in gm:
			if not cm.has(idx):
				c.micro[idx] = gm[idx]
		var em: Dictionary = micro_mods.get(c.key, {})
		for idx: int in em:
			c.micro[idx] = (em[idx] as PackedByteArray).duplicate()
		c.has_data = true
		_last_chunk = null
		_last_key = Vector2i(999999, 999999)
		_spawn_lights(c)
		# Lanternas, tochas e abajures das construcoes acendem de verdade.
		for idx: int in d.get("lights", []):
			if not c.lights.has(idx) and Blocks.EMIT[c.blocks[idx]] == 1:
				_add_light(c, idx)
	for r: Array in mr:
		_mesh_inflight -= 1
		var c: Chunk = chunks.get(r[0])
		if c == null:
			continue
		c.meshing = false
		if c.version != r[1]:
			continue
		var d: Dictionary = r[2]
		var mesh: ArrayMesh = d["mesh"]
		var kinds: PackedInt32Array = d["kinds"]
		if c.mi == null:
			c.mi = MeshInstance3D.new()
			c.mi.position = Vector3(c.key.x * 16, 0, c.key.y * 16)
			var cd := maxi(absi(c.key.x - center.x), absi(c.key.y - center.y))
			c.mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cd <= SHADOW_DIST else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(c.mi)
		for s in kinds.size():
			mesh.surface_set_material(s, mats[kinds[s]])
		c.mi.mesh = mesh if kinds.size() > 0 else null
		c.meshed = true


func _neighbors_ready(key: Vector2i) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var n: Chunk = chunks.get(key + Vector2i(dx, dz))
			if n == null or not n.has_data:
				return false
	return true


func _schedule() -> void:
	# Remalhas urgentes (edicao do jogador) passam na frente.
	while not _urgent.is_empty():
		var key: Vector2i = _urgent.pop_back()
		var c: Chunk = chunks.get(key)
		if c != null and c.has_data and c.dirty and not c.meshing and _neighbors_ready(key):
			_start_mesh(c)
	if center != _pass_center:
		_pass_center = center
		_scan_i = 0
		_pass_missing = INF
	var gen_r2 := (render_distance + 1) * (render_distance + 1) + 2
	var mesh_r2 := render_distance * render_distance + 1
	var lite2 := LITE_DIST * LITE_DIST
	var gen_cap := maxi(48, _max_jobs * 12)
	# Varredura incremental: no maximo 3000 posicoes por quadro, do centro para fora.
	var budget := 3000
	while budget > 0:
		if _scan_i >= _offsets.size() or _offsets[_scan_i].length_squared() > gen_r2:
			var fm := _pass_missing if _pass_missing < INF else sqrt(float(mesh_r2)) + 0.2
			_publish_near(fm)
			_scan_i = 0
			_pass_missing = INF
			break
		var off: Vector2i = _offsets[_scan_i]
		_scan_i += 1
		budget -= 1
		var d2 := off.length_squared()
		var key := center + off
		var c: Chunk = chunks.get(key)
		if c == null:
			if _gen_inflight < gen_cap:
				c = Chunk.new()
				c.key = key
				chunks[key] = c
				_gen_inflight += 1
				var m: Dictionary = mods.get(key, {})
				gpu.request(key, m.duplicate(), dim)
			if d2 <= mesh_r2:
				_pass_missing = minf(_pass_missing, sqrt(float(d2)))
			continue
		if d2 <= mesh_r2 and not c.meshed:
			_pass_missing = minf(_pass_missing, sqrt(float(d2)))
		# Chunk leve que ficou perto: refaz a malha completa.
		if c.meshed and c.lite and d2 < (LITE_DIST - 2) * (LITE_DIST - 2):
			c.dirty = true
		if d2 <= mesh_r2 and c.has_data and c.dirty and not c.meshing and _mesh_inflight < _max_jobs:
			if _neighbors_ready(key):
				_start_mesh(c, d2 > lite2)


func _publish_near(first_missing: float) -> void:
	var target := maxf(0.0, first_missing * 16.0 - 24.0)
	if target < near_radius:
		near_radius = target
	else:
		near_radius = minf(target, near_radius + 60.0)
	RenderingServer.global_shader_parameter_set("lod_near", near_radius if far_enabled else 1000000.0)


func _start_mesh(c: Chunk, lite: bool = false) -> void:
	c.meshing = true
	c.dirty = false
	c.lite = lite
	c.version += 1
	var nb := []
	var nsh := []
	var nmi := []
	var top := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var n: Chunk = chunks[c.key + Vector2i(dx, dz)]
			nb.append(n.blocks)
			nsh.append(n.shapes.duplicate())
			nmi.append(n.micro.duplicate() if not n.micro.is_empty() else {})
			top = maxi(top, n.top)
	_mesh_inflight += 1
	_tasks.append(WorkerThreadPool.add_task(_mesh_task.bind(c.key, c.version, nb, nsh, top, lite, nmi)))


func _mesh_task(key: Vector2i, version: int, nb: Array, nsh: Array, top: int, lite: bool, nmi: Array = []) -> void:
	var d := ChunkMesher.build(nb, nsh, top, key.x, key.y, lite, nmi)
	_mutex.lock()
	_mesh_results.append([key, version, d])
	_mutex.unlock()


func _unload_far() -> void:
	var lim := render_distance + 2
	for key: Vector2i in chunks.keys():
		var cd := maxi(absi(key.x - center.x), absi(key.y - center.y))
		if cd <= lim:
			var cc: Chunk = chunks[key]
			if cc.mi != null:
				cc.mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cd <= SHADOW_DIST else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		var c: Chunk = chunks[key]
		if not c.has_data or c.meshing:
			continue
		if c.mi != null:
			c.mi.queue_free()
		for l: Node in c.lights.values():
			l.queue_free()
		chunks.erase(key)
	_last_chunk = null
	_last_key = Vector2i(999999, 999999)


func wait_all() -> void:
	_stopping = true
	set_process(false)
	for t in _tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_tasks.clear()
	if gpu != null:
		gpu.stop()


func _exit_tree() -> void:
	wait_all()


func meshed_near(pos: Vector3, radius: int) -> float:
	var ck := Vector2i(floori(pos.x / 16.0), floori(pos.z / 16.0))
	var total := 0
	var done := 0
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			total += 1
			var c: Chunk = chunks.get(ck + Vector2i(dx, dz))
			if c != null and c.meshed:
				done += 1
	return float(done) / total


# ---------------------------------------------------------------- acesso a blocos

func _chunk_at(x: int, z: int) -> Chunk:
	var key := Vector2i(x >> 4, z >> 4)
	if key == _last_key and _last_chunk != null:
		return _last_chunk
	var c: Chunk = chunks.get(key)
	if c != null and c.has_data:
		_last_key = key
		_last_chunk = c
		return c
	return null


func is_loaded(x: int, z: int) -> bool:
	return _chunk_at(x, z) != null


func get_block(x: int, y: int, z: int) -> int:
	if y < 0 or y >= H:
		return 0
	var c := _chunk_at(x, z)
	if c == null:
		return 0
	return c.blocks[y * 256 + (z & 15) * 16 + (x & 15)]


func get_shape(x: int, y: int, z: int) -> int:
	if y < 0 or y >= H:
		return 0
	var c := _chunk_at(x, z)
	if c == null or c.shapes.is_empty():
		return 0
	return c.shapes.get(y * 256 + (z & 15) * 16 + (x & 15), 0)


func surface_y(x: int, z: int) -> int:
	for y in range(H - 1, 0, -1):
		var id := get_block(x, y, z)
		if Blocks.SOLID[id] == 1 or Blocks.FLUID[id] != 0:
			return y
	return 0


func set_block(p: Vector3i, id: int, shape: int = 0) -> bool:
	if p.y < 1 or p.y >= H:
		return false
	var c := _chunk_at(p.x, p.z)
	if c == null:
		return false
	var lx := p.x & 15
	var lz := p.z & 15
	var idx := p.y * 256 + lz * 16 + lx
	if c.blocks[idx] == Blocks.BEDROCK:
		return false
	if (shape & 15) == 0 and id < 256 and Blocks.PANE[id] == 1:
		shape |= Blocks.SH_PANE
	var old := c.blocks[idx]
	c.blocks[idx] = id
	if c.micro.has(idx) and id != Blocks.MICRO:
		c.micro.erase(idx)
		c.micro_boxes.erase(idx)
		if micro_mods.has(c.key):
			micro_mods[c.key].erase(idx)
	if shape != 0 and id != 0:
		c.shapes[idx] = shape
	else:
		c.shapes.erase(idx)
		shape = 0
	if id != 0:
		c.top = maxi(c.top, p.y + 1)
	if not mods.has(c.key):
		mods[c.key] = {}
	mods[c.key][idx] = id | (shape << 8)
	if c.lights.has(idx):
		c.lights[idx].queue_free()
		c.lights.erase(idx)
	_touch_fluids(p)
	var wk := Vector4i(p.x, p.y, p.z, dim)
	if is_tickable(id):
		ticks[wk] = true
	else:
		ticks.erase(wk)
	if id != 0 and Blocks.EMIT[id] == 1:
		_add_light(c, idx)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if (dx == -1 and lx != 0) or (dx == 1 and lx != 15) or (dz == -1 and lz != 0) or (dz == 1 and lz != 15):
				continue
			var n: Chunk = chunks.get(c.key + Vector2i(dx, dz))
			if n != null and n.has_data:
				n.dirty = true
				_urgent.append(n.key)
	if net != null and not _net_mute and id != Blocks.MICRO:
		net.send_edit(dim, p, id, shape, PackedByteArray())
	return true


## Lados em que a cerca em (x, y, z) se conecta (1 +X, 2 -X, 4 +Z, 8 -Z).
func fence_mask(x: int, y: int, z: int) -> int:
	var m := 0
	for k in 4:
		var d: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][k]
		var nid := get_block(x + d.x, y, z + d.y)
		if nid > 0 and get_shape(x + d.x, y, z + d.y) != 0:
			nid |= 0x100
		if Blocks.fence_links(nid):
			m |= 1 << k
	return m


func get_micro(x: int, y: int, z: int) -> Variant:
	if y < 0 or y >= H:
		return null
	var c := _chunk_at(x, z)
	if c == null or c.micro.is_empty():
		return null
	return c.micro.get(y * 256 + (z & 15) * 16 + (x & 15))


## Grava uma celula micro. Vazia vira ar; cheia de um material so vira bloco normal.
func set_micro(p: Vector3i, g: PackedByteArray) -> bool:
	var u := Micro.uniform(g)
	if u == 0:
		return set_block(p, Blocks.AIR)
	if u > 0:
		return set_block(p, u)
	var was := _net_mute
	_net_mute = true
	var ok := set_block(p, Blocks.MICRO, Blocks.SH_MICRO)
	_net_mute = was
	if not ok:
		return false
	var c := _chunk_at(p.x, p.z)
	var idx := p.y * 256 + (p.z & 15) * 16 + (p.x & 15)
	c.micro[idx] = g
	c.micro_boxes.erase(idx)
	if not micro_mods.has(c.key):
		micro_mods[c.key] = {}
	micro_mods[c.key][idx] = g.duplicate()
	if net != null and not _net_mute:
		net.send_edit(dim, p, Blocks.MICRO, Blocks.SH_MICRO, g)
	return true


## Edicao vinda de outro jogador: aplica sem reenviar; fora dos chunks carregados, guarda para quando gerarem.
func apply_remote(d: int, p: Vector3i, id: int, sh: int, g: PackedByteArray) -> void:
	if d == dim and _chunk_at(p.x, p.z) != null:
		_net_mute = true
		if g.size() == Micro.SIZE:
			set_micro(p, g)
		else:
			set_block(p, id, sh)
		_net_mute = false
		return
	var key := Vector2i(p.x >> 4, p.z >> 4)
	var idx := p.y * 256 + (p.z & 15) * 16 + (p.x & 15)
	var am: Dictionary = all_mods[d]
	if not am.has(key):
		am[key] = {}
	am[key][idx] = id | (sh << 8)
	var mm: Dictionary = all_micro[d]
	if g.size() == Micro.SIZE:
		if not mm.has(key):
			mm[key] = {}
		mm[key][idx] = g.duplicate()
	elif mm.has(key):
		mm[key].erase(idx)


func _micro_boxes(c: Chunk, idx: int) -> Array:
	if not c.micro_boxes.has(idx):
		var g: Variant = c.micro.get(idx)
		c.micro_boxes[idx] = Micro.boxes(g) if g != null else []
	return c.micro_boxes[idx]


func _add_light(c: Chunk, idx: int) -> void:
	if c.lights.has(idx):
		return
	var l := OmniLight3D.new()
	var bid := c.blocks[idx]
	l.light_energy = 2.6
	l.omni_range = 13.0
	match bid:
		Blocks.PORTAL_FIRE:
			l.light_color = Color(1.0, 0.45, 0.15)
		Blocks.PORTAL_ASTRAL:
			l.light_color = Color(0.45, 0.70, 1.0)
		Blocks.TORCH, Blocks.CAMPFIRE:
			l.light_color = Color(1.0, 0.58, 0.24)
			l.light_energy = 2.2
			l.omni_range = 10.0
		Blocks.LAMP:
			l.light_color = Color(1.0, 0.86, 0.62)
			l.omni_range = 11.0
		Blocks.FURNACE:
			l.light_color = Color(1.0, 0.50, 0.20)
			l.light_energy = 1.4
			l.omni_range = 7.0
		_:
			l.light_color = Color(1.0, 0.74, 0.40)
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	# Luzes distantes somem aos poucos (economiza GPU com muitas vilas carregadas).
	l.distance_fade_enabled = true
	l.distance_fade_begin = 48.0
	l.distance_fade_length = 16.0
	l.position = Vector3(c.key.x * 16 + (idx & 15) + 0.5, (idx >> 8) + 0.45, c.key.y * 16 + ((idx >> 4) & 15) + 0.5)
	add_child(l)
	c.lights[idx] = l


## Marca a celula e as vizinhas para o liquido ser reavaliado (alguma pode escorrer).
func _touch_fluids(p: Vector3i) -> void:
	_fluid_q[p] = true
	_fluid_q[p + Vector3i(0, 1, 0)] = true
	_fluid_q[p + Vector3i(0, -1, 0)] = true
	for d in DIRS4:
		_fluid_q[p + d] = true


func _step_fluids(kind: int) -> void:
	if _fluid_q.is_empty():
		return
	var batch: Array[Vector3i] = []
	var keep := {}
	for p: Vector3i in _fluid_q:
		var id := get_block(p.x, p.y, p.z)
		var t := Blocks.FLUID[id]
		if t == 0 or not is_loaded(p.x, p.z):
			continue
		if t != kind or batch.size() >= 600:
			keep[p] = true
			continue
		batch.append(p)
	_fluid_q = keep
	for p in batch:
		_update_fluid(p)


## O liquido pode ocupar esta celula com o nivel lv?
func _can_flow(nid: int, kind: int, lv: int) -> bool:
	if nid == 0 or Blocks.KIND[nid] == Blocks.K_PLANT:
		return true
	if Blocks.FLUID[nid] == kind and not Blocks.is_source(nid):
		return Blocks.fluid_level(nid) < lv
	return false


## Agua encontrando lava (ou o contrario) solidifica. Devolve true se reagiu.
func _react(q: Vector3i, kind: int) -> bool:
	var nid := get_block(q.x, q.y, q.z)
	var other := Blocks.FLUID[nid]
	if other == 0 or other == kind:
		return false
	if kind == 1:
		set_block(q, Blocks.OBSIDIAN if Blocks.is_source(nid) else Blocks.COBBLE)
	else:
		set_block(q, Blocks.STONE)
	return true


func _update_fluid(p: Vector3i) -> void:
	var id := get_block(p.x, p.y, p.z)
	var kind := Blocks.FLUID[id]
	var mx := 8 if kind == 1 else 4
	var lv := Blocks.fluid_level(id)
	var src := Blocks.is_source(id)
	var up := get_block(p.x, p.y + 1, p.z)
	if not src:
		# Recuo: o nivel vem do vizinho mais alto (menos um) ou de liquido caindo de cima.
		var supply := 0
		var sources := 0
		if Blocks.FLUID[up] == kind:
			supply = mx - 1
		for d in DIRS4:
			var nid := get_block(p.x + d.x, p.y, p.z + d.z)
			if Blocks.FLUID[nid] == kind:
				supply = maxi(supply, Blocks.fluid_level(nid) - 1)
				if Blocks.is_source(nid):
					sources += 1
		var below_id := get_block(p.x, p.y - 1, p.z)
		if kind == 1 and sources >= 2 and (Blocks.SOLID[below_id] == 1 or below_id == Blocks.WATER):
			set_block(p, Blocks.WATER)
			return
		if supply <= 0:
			set_block(p, Blocks.AIR)
			return
		if supply != lv:
			lv = mini(supply, mx - 1)
			set_block(p, Blocks.fluid_block(kind, lv))
	# Lava ao lado ou em cima de agua vira pedra; agua sobre lava idem.
	var below := p + Vector3i(0, -1, 0)
	if _react(below, kind):
		return
	var bid := get_block(below.x, below.y, below.z)
	if below.y >= 1 and _can_flow(bid, kind, mx - 1):
		set_block(below, Blocks.fluid_block(kind, mx - 1))
		if not src:
			return
	elif Blocks.FLUID[bid] == kind and not src:
		return
	var nl := lv - 1
	if nl < 1:
		return
	for d in DIRS4:
		var q := p + d
		if _react(q, kind):
			continue
		var nid := get_block(q.x, q.y, q.z)
		if _can_flow(nid, kind, nl):
			set_block(q, Blocks.fluid_block(kind, nl))


## Primeira celula de fonte de liquido no caminho do raio (para o balde).
func raycast_fluid(origin: Vector3, dir: Vector3, max_dist: float) -> Variant:
	var t := 0.0
	while t <= max_dist:
		var q := origin + dir * t
		var p := Vector3i(floori(q.x), floori(q.y), floori(q.z))
		var id := get_block(p.x, p.y, p.z)
		if Blocks.is_source(id):
			return p
		if Blocks.SOLID[id] == 1:
			return null
		t += 0.1
	return null


static func is_tickable(id: int) -> bool:
	return Blocks.is_crop(id) or (id >= Blocks.SAPLING_0 and id < Blocks.SAPLING_0 + 6) or id == Blocks.BERRY_BUSH_EMPTY


## Crescimento: a cada segundo cada planta tem uma chance de avancar (estacao e agua influem).
func _random_ticks() -> void:
	if ticks.is_empty() or season_growth <= 0.0:
		return
	var done: Array[Vector4i] = []
	for k: Vector4i in ticks:
		if k.w != dim or not is_loaded(k.x, k.z):
			continue
		var id := get_block(k.x, k.y, k.z)
		if not is_tickable(id):
			done.append(k)
			continue
		var p := Vector3i(k.x, k.y, k.z)
		if Blocks.is_crop(id):
			var water := _near_water(p)
			if _rng.randf() < 0.035 * season_growth * (2.0 if water else 1.0):
				advance_crop(p)
		elif id == Blocks.BERRY_BUSH_EMPTY:
			if _rng.randf() < 0.012 * season_growth:
				set_block(p, Blocks.BERRY_BUSH)
		elif _rng.randf() < 0.008 * season_growth:
			grow_tree(p, id - Blocks.SAPLING_0)
	for k in done:
		ticks.erase(k)


func _near_water(p: Vector3i) -> bool:
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			if Blocks.FLUID[get_block(p.x + dx, p.y - 1, p.z + dz)] == 1:
				return true
	return false


## Avanca um estagio; devolve true se mudou.
func advance_crop(p: Vector3i, steps: int = 1) -> bool:
	var id := get_block(p.x, p.y, p.z)
	var base := Blocks.crop_base(id)
	if base == 0:
		return false
	var last: int = base + int(Blocks.CROP_STAGES[base]) - 1
	if id >= last:
		return false
	set_block(p, mini(id + steps, last))
	return true


func _put_if_free(p: Vector3i, id: int) -> void:
	var cur := get_block(p.x, p.y, p.z)
	if cur == 0 or Blocks.KIND[cur] == Blocks.K_PLANT or Blocks.KIND[cur] == Blocks.K_LEAVES:
		set_block(p, id)


## Faz uma muda virar arvore. species: 0 carvalho, 1 pinheiro, 2 betula, 3 mogno, 4 palmeira, 5 cerejeira.
func grow_tree(p: Vector3i, species: int) -> void:
	var logs := [Blocks.LOG, Blocks.PINE_LOG, Blocks.BIRCH_LOG, Blocks.MAHOG_LOG, Blocks.PALM_LOG, Blocks.CHERRY_LOG]
	var leaves := [Blocks.LEAVES, Blocks.PINE_LEAVES, Blocks.BIRCH_LEAVES, Blocks.MAHOG_LEAVES, Blocks.PALM_LEAVES, Blocks.CHERRY_LEAVES]
	var lg: int = logs[species]
	var lf: int = leaves[species]
	var th := 4 + _rng.randi() % 3
	if species == 1:
		th = 6 + _rng.randi() % 3
	elif species == 3:
		th = 7 + _rng.randi() % 3
	for y in th + 1:
		if y > 0 and get_block(p.x, p.y + y, p.z) != 0:
			th = y - 1
			break
	if th < 3:
		return
	for y in th:
		set_block(p + Vector3i(0, y, 0), lg)
	var top := p + Vector3i(0, th, 0)
	if species == 1:
		_put_if_free(top, lf)
		for ly in range(2, th):
			var rad := 1 + ((th - ly) % 2)
			for dz in range(-rad, rad + 1):
				for dx in range(-rad, rad + 1):
					if absi(dx) + absi(dz) <= rad + (1 if rad == 2 else 0) and (dx != 0 or dz != 0):
						_put_if_free(p + Vector3i(dx, ly, dz), lf)
	elif species == 4:
		_put_if_free(top, lf)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			_put_if_free(top + Vector3i(d.x, 0, d.y), lf)
			_put_if_free(top + Vector3i(d.x * 2, -1, d.y * 2), lf)
	else:
		for dy in range(-2, 2):
			var rad := 2 if dy <= -1 else 1
			for dz in range(-rad, rad + 1):
				for dx in range(-rad, rad + 1):
					if absi(dx) == rad and absi(dz) == rad and _rng.randf() < 0.5:
						continue
					_put_if_free(top + Vector3i(dx, dy, dz), lf)


# ---------------------------------------------------------------- baus

func container_at(p: Vector3i) -> Inventory:
	var k := Vector4i(p.x, p.y, p.z, dim)
	if not containers.has(k):
		var inv := Inventory.new(27)
		if loot_pos.has(k):
			_fill_loot(inv, int(loot_pos[k]), k)
			loot_pos.erase(k)
		containers[k] = inv
	return containers[k]


func furnace_at(p: Vector3i) -> Dictionary:
	var k := Vector4i(p.x, p.y, p.z, dim)
	if not furnaces.has(k):
		furnaces[k] = {"inv": Inventory.new(3), "burn": 0.0, "burn_max": 1.0, "cook": 0.0}
	return furnaces[k]


func remove_furnace(p: Vector3i) -> Inventory:
	var k := Vector4i(p.x, p.y, p.z, dim)
	if not furnaces.has(k):
		return null
	var inv: Inventory = furnaces[k]["inv"]
	furnaces.erase(k)
	return inv


func _tick_furnaces(dt: float) -> void:
	if furnaces.is_empty():
		return
	if _smelt.is_empty():
		_smelt = Crafting.smelt_table()
	for k: Vector4i in furnaces:
		if k.w != dim or not is_loaded(k.x, k.z):
			continue
		var f: Dictionary = furnaces[k]
		var inv: Inventory = f["inv"]
		var src: Array = inv.slots[0]
		var res: Variant = _smelt.get(src[0], null) if src[0] > 0 else null
		var can_out := false
		if res != null:
			var outs: Array = inv.slots[2]
			can_out = outs[0] == 0 or (outs[0] == res[0] and outs[1] + int(res[1]) <= Items.max_stack(res[0]))
		if f["burn"] > 0.0:
			f["burn"] = maxf(0.0, f["burn"] - dt)
		elif can_out:
			var ft := Crafting.fuel_time(inv.slots[1][0])
			if ft > 0.0:
				inv.take_one(1)
				f["burn"] = ft
				f["burn_max"] = ft
		if f["burn"] > 0.0 and can_out:
			f["cook"] += dt
			if f["cook"] >= COOK_TIME:
				f["cook"] = 0.0
				inv.take_one(0)
				var outs: Array = inv.slots[2]
				if outs[0] == 0:
					inv.slots[2] = [res[0], int(res[1]), 0]
				else:
					outs[1] += int(res[1])
		else:
			f["cook"] = maxf(0.0, f["cook"] - dt * 2.0)


func remove_container(p: Vector3i) -> Inventory:
	var k := Vector4i(p.x, p.y, p.z, dim)
	var inv: Inventory = container_at(p)
	containers.erase(k)
	return inv


func _fill_loot(inv: Inventory, tier: int, k: Vector4i) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash(k)
	var common := ["Pão", "Maçã", "Carvão", "Graveto", "Trigo", "Sementes de trigo", "Batata", "Cenoura", "Couro", "Osso", "Flecha"]
	var rare := ["Lingote de ferro", "Lingote de cobre", "Lingote de ouro", "Cristal", "Rubi", "Pederneira"]
	var gear := ["Espada de ferro", "Picareta de ferro", "Arco", "Capacete de ferro", "Peitoral de couro", "Botas de cobre", "Machado de pedra",
		"Isqueiro de pederneira", "Espada de cristal", "Lança de cobre"]
	for i in r.randi_range(3, 6):
		inv.slots[r.randi() % 27] = [Items.find(common[r.randi() % common.size()]), r.randi_range(1, 6), 0]
	for i in r.randi_range(0, 1 + tier):
		inv.slots[r.randi() % 27] = [Items.find(rare[r.randi() % rare.size()]), r.randi_range(1, 3), 0]
	if r.randf() < 0.3 + tier * 0.2:
		inv.slots[r.randi() % 27] = [Items.find(gear[r.randi() % gear.size()]), 1, 0]


# ---------------------------------------------------------------- portais

static func portal_for_frame(frame_id: int) -> int:
	if frame_id == Blocks.OBSIDIAN:
		return Blocks.PORTAL_FIRE
	if frame_id == Blocks.CRYSTAL_BLOCK:
		return Blocks.PORTAL_ASTRAL
	return 0


## Tenta acender um portal a partir de um bloco da moldura (p) e da face clicada (n).
## Preenche o vao fechado (ate 21x21) no plano X ou Z com o bloco de portal.
func try_ignite(p: Vector3i, n: Vector3i) -> bool:
	var frame := get_block(p.x, p.y, p.z)
	var portal := portal_for_frame(frame)
	if portal == 0:
		return false
	var start := p + n
	if get_block(start.x, start.y, start.z) != 0:
		return false
	for axis: Vector3i in [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
		var cells := _flood_plane(start, axis, frame)
		if cells.size() >= 2:
			for c: Vector3i in cells:
				set_block(c, portal)
			return true
	return false


func _flood_plane(start: Vector3i, axis: Vector3i, frame: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var seen := {start: true}
	var stack: Array[Vector3i] = [start]
	var dirs: Array[Vector3i] = [axis, -axis, Vector3i(0, 1, 0), Vector3i(0, -1, 0)]
	while not stack.is_empty():
		var c: Vector3i = stack.pop_back()
		out.append(c)
		if out.size() > 441:
			return []
		for d in dirs:
			var nb := c + d
			if seen.has(nb):
				continue
			var id := get_block(nb.x, nb.y, nb.z)
			if id == frame:
				continue
			if id != 0:
				return []
			if absi(nb.x - start.x) + absi(nb.y - start.y) + absi(nb.z - start.z) > 30:
				return []
			seen[nb] = true
			stack.append(nb)
	return out


func find_block_near(c: Vector3i, id: int, radius: int, vrad: int) -> Variant:
	for dy in range(-vrad, vrad + 1):
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if get_block(c.x + dx, c.y + dy, c.z + dz) == id:
					return c + Vector3i(dx, dy, dz)
	return null


## Moldura 4x5 (vao 2x3) no plano X com o portal aceso. Devolve a posicao para o jogador ficar.
func build_portal(base: Vector3i, frame: int, portal: int) -> Vector3:
	for x in range(-1, 4):
		for y in range(-1, 5):
			for z in range(-2, 3):
				if z == 0:
					continue
				if y >= 0:
					set_block(base + Vector3i(x, y, z), 0)
	for x in range(-1, 3):
		for y in range(-1, 4):
			var edge := x == -1 or x == 2 or y == -1 or y == 3
			set_block(base + Vector3i(x, y, 0), frame if edge else portal)
	# Chao firme na frente e atras.
	for x in range(-1, 3):
		for z in [-1, 1]:
			if Blocks.SOLID[get_block(base.x + x, base.y - 1, base.z + z)] == 0:
				set_block(base + Vector3i(x, -1, z), frame if dim != 0 else Blocks.COBBLE)
	return Vector3(base.x + 1.0, base.y, base.z - 1.5)


## Procura chao com 2 blocos livres acima entre y0 e y1 (para dimensoes com teto).
func find_floor(x: int, z: int, y0: int, y1: int) -> int:
	for y in range(y0, y1):
		var below := get_block(x, y - 1, z)
		if Blocks.SOLID[below] == 1 and get_block(x, y, z) == 0 and get_block(x, y + 1, z) == 0:
			return y
	return -1


## Troca a dimensao ativa: descarta os chunks e passa a gerar a nova.
func change_dim(new_dim: int) -> void:
	for key: Vector2i in chunks.keys():
		var c: Chunk = chunks[key]
		if c.mi != null:
			c.mi.queue_free()
		for l: Node in c.lights.values():
			l.queue_free()
	chunks.clear()
	_urgent.clear()
	_last_chunk = null
	_last_key = Vector2i(999999, 999999)
	dim = new_dim
	mods = all_mods[dim]
	micro_mods = all_micro[dim]
	near_radius = 0.0
	center = Vector2i(999999, 999999)


func _spawn_lights(c: Chunk) -> void:
	var m: Dictionary = mods.get(c.key, {})
	for idx: int in m:
		if Blocks.EMIT[int(m[idx]) & 0xFF] == 1:
			_add_light(c, idx)


## Caixas solidas que tocam a regiao (para a fisica do jogador).
func get_boxes(a: AABB) -> Array[AABB]:
	var out: Array[AABB] = []
	var x0 := floori(a.position.x)
	var y0 := maxi(floori(a.position.y), 0)
	var z0 := floori(a.position.z)
	var x1 := floori(a.end.x)
	var y1 := mini(floori(a.end.y), H - 1)
	var z1 := floori(a.end.z)
	for y in range(y0, y1 + 1):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				var c := _chunk_at(x, z)
				if c == null:
					out.append(AABB(Vector3(x, y, z), Vector3.ONE))
					continue
				var idx := y * 256 + (z & 15) * 16 + (x & 15)
				var id := c.blocks[idx]
				if id == 0 or Blocks.SOLID[id] == 0:
					continue
				var sh: int = c.shapes.get(idx, 0) if not c.shapes.is_empty() else 0
				if sh == 0 and Blocks.KIND[id] != Blocks.K_MODEL:
					out.append(AABB(Vector3(x, y, z), Vector3.ONE))
				elif (sh & 15) == Blocks.SH_MICRO:
					for b: AABB in _micro_boxes(c, idx):
						out.append(AABB(b.position + Vector3(x, y, z), b.size))
				else:
					for b: AABB in (Blocks.fence_boxes(fence_mask(x, y, z)) if id == Blocks.FENCE else Blocks.boxes(id, sh)):
						out.append(AABB(b.position + Vector3(x, y, z), b.size))
	return out


static func _ray_box(o: Vector3, d: Vector3, b: AABB) -> Vector4:
	# Retorna (t, nx, ny, nz); t < 0 se nao acertar.
	var tmin := -INF
	var tmax := INF
	var n := Vector3.ZERO
	for a in 3:
		if absf(d[a]) < 1e-9:
			if o[a] < b.position[a] or o[a] > b.end[a]:
				return Vector4(-1, 0, 0, 0)
			continue
		var t1 := (b.position[a] - o[a]) / d[a]
		var t2 := (b.end[a] - o[a]) / d[a]
		var sgn := -1.0
		if t1 > t2:
			var tt := t1
			t1 = t2
			t2 = tt
			sgn = 1.0
		if t1 > tmin:
			tmin = t1
			n = Vector3.ZERO
			n[a] = sgn
		tmax = minf(tmax, t2)
		if tmin > tmax:
			return Vector4(-1, 0, 0, 0)
	if tmin < 0.0:
		return Vector4(-1, 0, 0, 0)
	return Vector4(tmin, n.x, n.y, n.z)


## Raycast voxel (DDA). Retorna {} ou {pos, normal, point, id, shape}.
func raycast(origin: Vector3, dir: Vector3, max_dist: float) -> Dictionary:
	var p := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var step := Vector3i(1 if dir.x > 0 else -1, 1 if dir.y > 0 else -1, 1 if dir.z > 0 else -1)
	var tmax := Vector3(INF, INF, INF)
	var tdelta := Vector3(INF, INF, INF)
	for a in 3:
		if absf(dir[a]) > 1e-9:
			var edge := float(p[a] + (1 if dir[a] > 0 else 0))
			tmax[a] = (edge - origin[a]) / dir[a]
			tdelta[a] = absf(1.0 / dir[a])
	var normal := Vector3i.ZERO
	var t := 0.0
	while t <= max_dist:
		var id := get_block(p.x, p.y, p.z)
		if id != Blocks.AIR and Blocks.FLUID[id] == 0:
			var sh := get_shape(p.x, p.y, p.z)
			var kind := Blocks.KIND[id]
			if (sh & 15) == Blocks.SH_MICRO:
				var g: Variant = get_micro(p.x, p.y, p.z)
				if g != null:
					var r: Array = Micro.raycast(g, origin - Vector3(p), dir)
					if not r.is_empty() and float(r[0]) <= max_dist:
						var mv: Vector3i = r[1]
						var gg: PackedByteArray = g
						return {"pos": p, "normal": r[2], "point": origin + dir * float(r[0]), "id": int(gg[Micro.i3(mv.x, mv.y, mv.z)]),
							"shape": sh, "micro": mv}
			elif sh == 0 and kind != Blocks.K_PLANT and kind != Blocks.K_MODEL:
				return {"pos": p, "normal": normal, "point": origin + dir * t, "id": id, "shape": 0}
			else:
				var best := Vector4(-1, 0, 0, 0)
				for b: AABB in (Blocks.fence_boxes(fence_mask(p.x, p.y, p.z)) if id == Blocks.FENCE else Blocks.boxes(id, sh)):
					var r := _ray_box(origin, dir, AABB(b.position + Vector3(p), b.size))
					if r.x >= 0.0 and r.x <= max_dist and (best.x < 0.0 or r.x < best.x):
						best = r
				if best.x >= 0.0:
					return {"pos": p, "normal": Vector3i(int(best.y), int(best.z), int(best.w)), "point": origin + dir * best.x, "id": id, "shape": sh}
		if tmax.x < tmax.y and tmax.x < tmax.z:
			p.x += step.x
			t = tmax.x
			tmax.x += tdelta.x
			normal = Vector3i(-step.x, 0, 0)
		elif tmax.y < tmax.z:
			p.y += step.y
			t = tmax.y
			tmax.y += tdelta.y
			normal = Vector3i(0, -step.y, 0)
		else:
			p.z += step.z
			t = tmax.z
			tmax.z += tdelta.z
			normal = Vector3i(0, 0, -step.z)
	return {}


# ---------------------------------------------------------------- salvar / carregar

static func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = f.get_var()
	if v is Dictionary:
		return v
	return {}


func save(extra: Dictionary) -> void:
	var d := extra.duplicate()
	d["seed"] = gen.seed_v
	d["all_mods"] = all_mods
	d["all_micro"] = all_micro
	d["dim"] = dim
	var cont := {}
	for k: Vector4i in containers:
		cont[k] = (containers[k] as Inventory).to_array()
	d["containers"] = cont
	d["loot_pos"] = loot_pos
	d["ticks"] = ticks
	var fur := {}
	for k: Vector4i in furnaces:
		var f: Dictionary = furnaces[k]
		fur[k] = {"inv": (f["inv"] as Inventory).to_array(), "burn": f["burn"], "burn_max": f["burn_max"], "cook": f["cook"]}
	d["furnaces"] = fur
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_var(d)
