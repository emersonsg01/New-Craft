class_name Net
extends Node
## Multijogador (ENet). Papeis:
##  - "host": jogo normal que tambem e servidor (peer 1); simula mundo e criaturas.
##  - "client": recebe a semente e as edicoes do servidor e gera o mesmo mundo localmente.
##  - "dedicated": servidor sem tela (scripts/dedicated_server.gd); guarda o mundo e repassa tudo.
##    Num servidor dedicado, o primeiro jogador conectado vira o "simulador" (criaturas, liquidos,
##    plantacoes) e o servidor repassa o que ele simula para os outros.
## O no fica em /root/Main/Net em todos os peers, para os RPCs se encontrarem.

signal welcomed(ok: bool)
signal status_changed(text: String)

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 16
const STATE_RATE := 1.0 / 15.0
const MOB_RATE := 0.1
const TIME_RATE := 3.0
const DED_DAY := 720.0

var role := "off"
var sim_auth := 0
var my_name := "Jogador"
var main: Node = null
var world: Variant = null
var player: Variant = null
var mobs: Variant = null
var weather: Variant = null
## peer -> {"name", "app"}
var players: Dictionary = {}
## peer -> RemotePlayer
var remotes: Dictionary = {}
## Dados recebidos ao entrar num servidor.
var welcome: Dictionary = {}
## Mundo guardado pelo servidor dedicado.
var store: Dictionary = {}
var store_path := ""
var _state_t := 0.0
var _mob_t := 0.0
var _time_t := 0.0
var _save_t := 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_lost)


func active() -> bool:
	return role != "off"


func my_id() -> int:
	return multiplayer.get_unique_id() if active() else 1


## Este peer simula mundo e criaturas?
func is_sim() -> bool:
	return not active() or sim_auth == my_id()


func is_server() -> bool:
	return role == "host" or role == "dedicated"


# ---------------------------------------------------------------- iniciar

func host(port: int) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		return "Não foi possível abrir a porta %d (erro %d)." % [port, err]
	multiplayer.multiplayer_peer = peer
	role = "host"
	sim_auth = 1
	_apply_sim()
	status_changed.emit("Servidor aberto na porta %d." % port)
	return ""


## Conecta e espera as boas-vindas (semente e edicoes do mundo). Devolve true se entrou.
func join(ip: String, port: int, app: Dictionary) -> bool:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, port) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	role = "client"
	var t0 := Time.get_ticks_msec()
	while peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		leave()
		return false
	rpc_id(1, "c_hello", my_name, app)
	t0 = Time.get_ticks_msec()
	while welcome.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	if welcome.is_empty():
		leave()
		return false
	return true


func start_dedicated(port: int, path: String, seed_v: int) -> String:
	store_path = path
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var v: Variant = f.get_var()
		if v is Dictionary:
			store = v
	if not store.has("seed"):
		store = {"seed": seed_v if seed_v >= 0 else (randi() & 0x3FFFFFFF), "all_mods": {0: {}, 1: {}, 2: {}}, "all_micro": {0: {}, 1: {}, 2: {}}, "time": 0.30, "day": 0}
	var err := host(port)
	if err != "":
		return err
	role = "dedicated"
	sim_auth = 0
	return ""


func leave() -> void:
	for r in remotes.values():
		if is_instance_valid(r):
			r.queue_free()
	remotes.clear()
	players.clear()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	role = "off"
	sim_auth = 0
	_apply_sim()


## Liga o jogo local (mundo, jogador, criaturas, clima) ao multijogador.
func attach(w: Variant, p: Variant, m: Variant, we: Variant) -> void:
	world = w
	player = p
	mobs = m
	weather = we
	if world != null:
		world.net = self
	if mobs != null:
		mobs.net = self
	_apply_sim()


func _apply_sim() -> void:
	if world != null:
		world.simulate = is_sim()
	if mobs != null:
		mobs.set_puppet_mode(not is_sim())


# ---------------------------------------------------------------- conexoes

func _on_peer_connected(_id: int) -> void:
	pass


func _on_peer_disconnected(id: int) -> void:
	if not is_server():
		return
	var nm: String = players.get(id, {}).get("name", "?")
	players.erase(id)
	_drop_remote(id)
	rpc("s_player_leave", id)
	_toast("%s saiu." % nm)
	if role == "dedicated" and sim_auth == id:
		sim_auth = players.keys()[0] if not players.is_empty() else 0
		rpc("s_sim_auth", sim_auth)


func _on_server_lost() -> void:
	_toast("Conexão com o servidor perdida.")
	leave()


func _drop_remote(id: int) -> void:
	if remotes.has(id):
		if is_instance_valid(remotes[id]):
			remotes[id].queue_free()
		remotes.erase(id)


func _toast(text: String) -> void:
	status_changed.emit(text)
	if main != null and main.hud != null:
		main.hud.add_toast(text)
	elif role == "dedicated":
		print("[servidor] ", text)


func _ensure_remote(id: int) -> Variant:
	if id == my_id() or main == null:
		return null
	if not remotes.has(id) or not is_instance_valid(remotes[id]):
		var info: Dictionary = players.get(id, {"name": "Jogador", "app": {}})
		var r := RemotePlayer.new()
		r.setup(self, id, info["name"], info["app"])
		main.add_child(r)
		remotes[id] = r
	return remotes[id]


# ---------------------------------------------------------------- RPCs: entrada

@rpc("any_peer", "reliable")
func c_hello(nm: String, app: Dictionary) -> void:
	if not is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	players[id] = {"name": nm, "app": app}
	if role == "dedicated" and sim_auth == 0:
		sim_auth = id
	var info := {}
	for pid: int in players:
		if pid != id:
			info[pid] = players[pid]
	var w := {}
	if role == "host":
		info[1] = {"name": my_name, "app": player.character_options(player.armor) if player != null else {}}
		w = {"seed": world.gen.seed_v, "all_mods": world.all_mods, "all_micro": world.all_micro,
			"time": weather.time_of_day, "day": weather.day}
	else:
		w = {"seed": store["seed"], "all_mods": store["all_mods"], "all_micro": store["all_micro"], "time": store["time"], "day": store["day"]}
	rpc_id(id, "s_welcome", w, info, sim_auth)
	for pid: int in players:
		if pid != id:
			rpc_id(pid, "s_player_join", id, nm, app)
	if role == "host":
		_ensure_remote(id)
	_toast("%s entrou." % nm)


@rpc("authority", "reliable")
func s_welcome(w: Dictionary, info: Dictionary, auth: int) -> void:
	for pid: int in info:
		players[pid] = info[pid]
	sim_auth = auth
	welcome = w
	welcomed.emit(true)


@rpc("authority", "reliable")
func s_player_join(id: int, nm: String, app: Dictionary) -> void:
	players[id] = {"name": nm, "app": app}
	_ensure_remote(id)
	_toast("%s entrou." % nm)


@rpc("authority", "reliable")
func s_player_leave(id: int) -> void:
	var nm: String = players.get(id, {}).get("name", "?")
	players.erase(id)
	_drop_remote(id)
	_toast("%s saiu." % nm)


@rpc("authority", "reliable")
func s_sim_auth(id: int) -> void:
	sim_auth = id
	_apply_sim()
	if is_sim():
		_toast("Você agora simula as criaturas e o mundo deste servidor.")


# ---------------------------------------------------------------- RPCs: jogadores

@rpc("any_peer", "unreliable_ordered")
func c_state(st: Array) -> void:
	if not is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if role == "host":
		var r: Variant = _ensure_remote(id)
		if r != null:
			r.apply_state(st)
	for pid: int in players:
		if pid != id:
			rpc_id(pid, "s_state", id, st)


@rpc("authority", "unreliable_ordered")
func s_state(id: int, st: Array) -> void:
	var r: Variant = _ensure_remote(id)
	if r != null:
		r.apply_state(st)


## Dano que uma criatura simulada aqui causa em outro jogador.
func hurt_remote(peer: int, amount: float, from: Vector3) -> void:
	if peer == my_id():
		if player != null:
			player.damage(amount, from)
	elif role == "host":
		rpc_id(peer, "s_hurt", amount, from)
	else:
		rpc_id(1, "c_hurt", peer, amount, from)


@rpc("any_peer", "reliable")
func c_hurt(peer: int, amount: float, from: Vector3) -> void:
	if not is_server():
		return
	if peer == 1 and role == "host":
		player.damage(amount, from)
	elif players.has(peer):
		rpc_id(peer, "s_hurt", amount, from)


@rpc("authority", "reliable")
func s_hurt(amount: float, from: Vector3) -> void:
	if player != null:
		player.damage(amount, from)


# ---------------------------------------------------------------- RPCs: blocos

func send_edit(dim: int, p: Vector3i, id: int, sh: int, g: PackedByteArray) -> void:
	if not active():
		return
	if is_server():
		rpc("s_edit", dim, p, id, sh, g)
	else:
		rpc_id(1, "c_edit", dim, p, id, sh, g)


@rpc("any_peer", "reliable")
func c_edit(dim: int, p: Vector3i, id: int, sh: int, g: PackedByteArray) -> void:
	if not is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if role == "host":
		world.apply_remote(dim, p, id, sh, g)
	else:
		_store_edit(dim, p, id, sh, g)
	for pid: int in players:
		if pid != sender:
			rpc_id(pid, "s_edit", dim, p, id, sh, g)


@rpc("authority", "reliable")
func s_edit(dim: int, p: Vector3i, id: int, sh: int, g: PackedByteArray) -> void:
	if world != null:
		world.apply_remote(dim, p, id, sh, g)


func _store_edit(dim: int, p: Vector3i, id: int, sh: int, g: PackedByteArray) -> void:
	var key := Vector2i(p.x >> 4, p.z >> 4)
	var idx := p.y * 256 + (p.z & 15) * 16 + (p.x & 15)
	var am: Dictionary = store["all_mods"]
	if not am.has(dim):
		am[dim] = {}
	if not am[dim].has(key):
		am[dim][key] = {}
	am[dim][key][idx] = id | (sh << 8)
	var mc: Dictionary = store["all_micro"]
	if not mc.has(dim):
		mc[dim] = {}
	if g.size() == Micro.SIZE:
		if not mc[dim].has(key):
			mc[dim][key] = {}
		mc[dim][key][idx] = g
	elif mc[dim].has(key):
		mc[dim][key].erase(idx)


# ---------------------------------------------------------------- RPCs: criaturas

@rpc("any_peer", "unreliable")
func c_mobs(snap: PackedFloat32Array) -> void:
	if not is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != sim_auth:
		return
	for pid: int in players:
		if pid != sender:
			rpc_id(pid, "s_mobs", snap)


@rpc("authority", "unreliable")
func s_mobs(snap: PackedFloat32Array) -> void:
	if mobs != null and not is_sim():
		mobs.apply_snapshot(snap)


## Golpe de um jogador numa criatura que outro peer simula.
func hit_mob(iid: int, amount: float, from: Vector3) -> void:
	if role == "host" or is_sim():
		if mobs != null:
			mobs.hit_by_id(iid, amount, from)
	else:
		rpc_id(1, "c_hit_mob", iid, amount, from)


@rpc("any_peer", "reliable")
func c_hit_mob(iid: int, amount: float, from: Vector3) -> void:
	if not is_server():
		return
	if role == "host":
		mobs.hit_by_id(iid, amount, from)
	elif sim_auth != 0:
		rpc_id(sim_auth, "s_hit_mob", iid, amount, from)


@rpc("authority", "reliable")
func s_hit_mob(iid: int, amount: float, from: Vector3) -> void:
	if mobs != null:
		mobs.hit_by_id(iid, amount, from)


# ---------------------------------------------------------------- RPCs: hora do dia

@rpc("authority", "unreliable_ordered")
func s_time(t: float, d: int) -> void:
	if weather != null:
		weather.time_of_day = t
		weather.day = d


# ---------------------------------------------------------------- laco

func _process(dt: float) -> void:
	if not active():
		return
	if role == "dedicated":
		store["time"] = fposmod(float(store["time"]) + dt / DED_DAY, 1.0)
		if float(store["time"]) < dt / DED_DAY:
			store["day"] = int(store["day"]) + 1
		_time_t += dt
		if _time_t >= TIME_RATE:
			_time_t = 0.0
			rpc("s_time", float(store["time"]), int(store["day"]))
		_save_t += dt
		if _save_t >= 60.0:
			_save_t = 0.0
			save_store()
		return
	# Estado do jogador local.
	_state_t += dt
	if _state_t >= STATE_RATE and player != null:
		_state_t = 0.0
		var st: Array = [player.position, player.yaw, player.pitch, Vector2(player.vel.x, player.vel.z).length(), player.on_ground or player.in_water,
			player.vehicle != null, world.dim if world != null else 0]
		if role == "host":
			rpc("s_state", 1, st)
		else:
			rpc_id(1, "c_state", st)
	# Criaturas simuladas aqui.
	if is_sim() and mobs != null:
		_mob_t += dt
		if _mob_t >= MOB_RATE:
			_mob_t = 0.0
			var snap: PackedFloat32Array = mobs.snapshot()
			if role == "host":
				rpc("s_mobs", snap)
			else:
				rpc_id(1, "c_mobs", snap)
	if role == "host":
		_time_t += dt
		if _time_t >= TIME_RATE and weather != null:
			_time_t = 0.0
			rpc("s_time", weather.time_of_day, weather.day)


func save_store() -> void:
	if role != "dedicated" or store_path == "":
		return
	var f := FileAccess.open(store_path, FileAccess.WRITE)
	if f != null:
		f.store_var(store)
