extends Node3D
## Cena principal do executavel do servidor (NewCraftServer.exe).
## Com janela: lista de mundos do servidor, criar mundo, ligar e desligar o mundo, jogadores e registro.
## Sem janela (--headless) ou com argumentos, liga direto, como antes:
##   NewCraftServer.console.exe --headless --port=7777 [--mundo=id | --seed=123 | --save=user://arquivo.save]
## Este no se chama "Main" e o Net fica em /root/Main/Net, igual ao jogo, para os RPCs se encontrarem.

var net: Net
var running: Dictionary = {}
var _ui: Control
var _list: ItemList
var _port: SpinBox
var _btn_on: Button
var _btn_off: Button
var _btn_new: Button
var _status: Label
var _players: ItemList
var _log: RichTextLabel
var _name_e: LineEdit
var _seed_e: LineEdit
var _t := 0.0


func _ready() -> void:
	net = Net.new()
	net.name = "Net"
	add_child(net)
	net.status_changed.connect(_append)
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var auto := DisplayServer.get_name() == "headless"
	var port := Net.DEFAULT_PORT
	var seed_v := -1
	var path := ""
	var world_id := ""
	for a in args:
		if a.begins_with("--port="):
			port = int(a.trim_prefix("--port="))
			auto = true
		elif a.begins_with("--seed="):
			seed_v = int(a.trim_prefix("--seed="))
			auto = true
		elif a.begins_with("--save="):
			path = a.trim_prefix("--save=")
			auto = true
		elif a.begins_with("--mundo="):
			world_id = a.trim_prefix("--mundo=")
			auto = true
	await get_tree().process_frame
	if auto:
		var meta: Dictionary = {}
		if path == "":
			var ws := Saves.list_worlds(Saves.DIR_SERVER)
			for w: Dictionary in ws:
				if world_id == "" or w["id"] == world_id:
					meta = w
					break
			if meta.is_empty():
				meta = Saves.new_world(world_id if world_id != "" else "Mundo do servidor", str(seed_v) if seed_v >= 0 else "", Saves.DIR_SERVER)
		else:
			meta = {"id": "", "name": path.get_file(), "path": path, "seed": seed_v}
		var err := start_world(meta, port)
		if err != "":
			print("[servidor] ", err)
			get_tree().quit(1)
		else:
			print("[servidor] Ctrl+C para encerrar (o mundo é salvo a cada minuto).")
		return
	_build_ui()


## Liga o mundo (carrega o arquivo dele e abre a porta).
func start_world(meta: Dictionary, port: int) -> String:
	if net.active():
		return "Já há um mundo ligado."
	var seed_v := int(meta.get("seed", -1))
	net.store = {}
	var err := net.start_dedicated(port, str(meta["path"]), seed_v)
	if err != "":
		return err
	running = meta.duplicate()
	running["port"] = port
	net.save_store()
	_log_line("Mundo \"%s\" ligado na porta %d (semente %d)." % [meta.get("name", ""), port, int(net.store["seed"])])
	return ""


## Desliga o mundo: salva, desconecta todos e fecha a porta.
func stop_world() -> void:
	if running.is_empty():
		return
	net.save_store()
	if str(running.get("id", "")) != "":
		Saves.touch(Saves.DIR_SERVER, str(running["id"]), {"day": int(net.store.get("day", 0)), "seed": int(net.store.get("seed", 0))})
	net.leave()
	_log_line("Mundo \"%s\" desligado e salvo." % running.get("name", ""))
	running = {}
	net.store = {}


func _exit_tree() -> void:
	if not running.is_empty():
		net.save_store()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop_world()


func _log_line(t: String) -> void:
	print("[servidor] ", t)
	_append(t)


## So no registro da janela (o Net ja escreve no console).
func _append(t: String) -> void:
	if _log != null:
		var tm := Time.get_time_string_from_system().substr(0, 5)
		_log.append_text("[color=#8fa3bf]%s[/color]  %s\n" % [tm, t])


# ---------------------------------------------------------------- janela

func _build_ui() -> void:
	get_window().title = "New Craft - Servidor"
	get_window().min_size = Vector2i(980, 620)
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font_size = 18
	_ui.theme = th
	layer.add_child(_ui)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 22)
	_ui.add_child(m)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	m.add_child(root)
	var title := Label.new()
	title.text = "NEW CRAFT  ·  Servidor"
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# Coluna dos mundos.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	left.add_child(_header("Mundos do servidor"))
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_font_size_override("font_size", 16)
	left.add_child(_list)
	left.add_child(_header("Criar mundo"))
	var hn := HBoxContainer.new()
	hn.add_theme_constant_override("separation", 8)
	left.add_child(hn)
	_name_e = LineEdit.new()
	_name_e.placeholder_text = "Nome do mundo"
	_name_e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hn.add_child(_name_e)
	_seed_e = LineEdit.new()
	_seed_e.placeholder_text = "Semente (opcional)"
	_seed_e.custom_minimum_size = Vector2(190, 0)
	hn.add_child(_seed_e)
	_btn_new = Button.new()
	_btn_new.text = "Criar mundo"
	_btn_new.pressed.connect(_on_create)
	hn.add_child(_btn_new)

	# Coluna de controle.
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(400, 0)
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)
	right.add_child(_header("Controle"))
	var hp := HBoxContainer.new()
	var lp := Label.new()
	lp.text = "Porta"
	lp.custom_minimum_size = Vector2(80, 0)
	hp.add_child(lp)
	_port = SpinBox.new()
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = Net.DEFAULT_PORT
	_port.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.add_child(_port)
	right.add_child(hp)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	right.add_child(hb)
	_btn_on = Button.new()
	_btn_on.text = "Ligar mundo"
	_btn_on.custom_minimum_size = Vector2(0, 46)
	_btn_on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_on.pressed.connect(_on_start)
	hb.add_child(_btn_on)
	_btn_off = Button.new()
	_btn_off.text = "Desligar mundo"
	_btn_off.custom_minimum_size = Vector2(0, 46)
	_btn_off.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_off.pressed.connect(func() -> void:
		stop_world()
		_refresh())
	hb.add_child(_btn_off)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status)
	right.add_child(_header("Jogadores conectados"))
	_players = ItemList.new()
	_players.custom_minimum_size = Vector2(0, 110)
	right.add_child(_players)
	right.add_child(_header("Registro"))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 15)
	right.add_child(_log)
	_refresh_worlds()
	_refresh()
	_log_line("Escolha um mundo e clique em \"Ligar mundo\".")


func _header(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(1, 0.86, 0.6))
	return l


func _refresh_worlds() -> void:
	_list.clear()
	var ws := Saves.list_worlds(Saves.DIR_SERVER)
	for w: Dictionary in ws:
		var on: bool = not running.is_empty() and str(running.get("id", "")) == str(w["id"])
		var i := _list.add_item("%s%s   —   %s" % [w["name"], "  (LIGADO)" if on else "", Saves.describe(w)])
		_list.set_item_metadata(i, w)
	if _list.item_count > 0:
		_list.select(0)


func _refresh() -> void:
	var on := not running.is_empty()
	_btn_on.disabled = on or _list.item_count == 0
	_btn_off.disabled = not on
	_port.editable = not on
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
	if on:
		var ips: Array = []
		for ip in IP.get_local_addresses():
			if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
				ips.append("%s:%d" % [ip, int(running["port"])])
		_status.text = "LIGADO: \"%s\" na porta %d.\nNa mesma rede, os jogadores entram por: %s\nPela internet: abra a porta %d (UDP) no roteador e passe seu IP público." % [
			running.get("name", ""), int(running["port"]), ", ".join(ips) if not ips.is_empty() else "este computador", int(running["port"])]
		_status.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6))
	else:
		_status.text = "DESLIGADO. Escolha um mundo na lista e clique em \"Ligar mundo\"." if _list.item_count > 0 else "Nenhum mundo ainda: crie um mundo ao lado."
		_status.add_theme_color_override("font_color", Color(0.95, 0.75, 0.55))
	_refresh_worlds()


func _on_create() -> void:
	var w := Saves.new_world(_name_e.text if _name_e.text.strip_edges() != "" else "Mundo %d" % (_list.item_count + 1), _seed_e.text, Saves.DIR_SERVER)
	_name_e.text = ""
	_seed_e.text = ""
	_log_line("Mundo \"%s\" criado (semente %d)." % [w["name"], int(w["seed"])])
	_refresh()


func _on_start() -> void:
	var sel := _list.get_selected_items()
	if sel.is_empty():
		return
	var err := start_world(_list.get_item_metadata(sel[0]), int(_port.value))
	if err != "":
		_log_line("Não foi possível ligar: " + err)
	_refresh()


func _process(dt: float) -> void:
	_t += dt
	if _t < 1.0 or _players == null:
		return
	_t = 0.0
	_players.clear()
	for pid: int in net.players:
		_players.add_item(str(net.players[pid].get("name", "Jogador")))
	if not running.is_empty() and net.players.is_empty():
		_players.add_item("(ninguém conectado)")
