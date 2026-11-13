class_name Menus
extends Control
## Menu de pausa e tela de opcoes (Graficos, Upscaling, Tracado de raios, Jogo).

signal resumed
signal quit_requested
## Multijogador (definido pelo main).
var net: Variant = null

var world: World
var weather: Weather
var player: Player
var _pause_box: Control
var _options: Control
var _tab := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var th := Theme.new()
	th.default_font_size = 17
	theme = th
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_build_pause()


func _panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.96)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = min_size
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	cc.add_child(p)
	p.set_meta("holder", cc)
	return p


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(cb)
	return b


func _build_pause() -> void:
	var p := _panel(Vector2(360, 0))
	_pause_box = p.get_meta("holder")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var title := Label.new()
	title.text = "NEW CRAFT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	v.add_child(title)
	v.add_child(_button("Continuar", func() -> void: close()))
	v.add_child(_button("Opções", func() -> void: _show_options()))
	v.add_child(_button("Salvar e voltar ao menu", func() -> void: quit_requested.emit()))


func open() -> void:
	visible = true
	_pause_box.visible = true
	if _options != null:
		_options.queue_free()
		_options = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()


func _show_options() -> void:
	_pause_box.visible = false
	if _options != null:
		_options.queue_free()
	var p := _panel(Vector2(820, 600))
	_options = p.get_meta("holder")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)

	var tabs := HBoxContainer.new()
	v.add_child(tabs)
	var names: Array[String] = ["Gráficos", "Desempenho", "Upscaling", "Traçado de raios", "Jogo", "Personagem", "Multijogador"]
	for i in names.size():
		var b := _button(names[i], func() -> void:
			_tab = i
			_show_options())
		b.toggle_mode = true
		b.button_pressed = i == _tab
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 430)
	v.add_child(sc)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	sc.add_child(body)
	match _tab:
		0: _tab_graphics(body)
		1: _tab_performance(body)
		2: _tab_upscaling(body)
		3: _tab_rt(body)
		4: _tab_game(body)
		5: _tab_character(body)
		6: _tab_multiplayer(body)
	v.add_child(_button("Voltar", func() -> void:
		_options.queue_free()
		_options = null
		_pause_box.visible = true))


func _row(parent: Control, text: String, tip: String = "", label_w: float = 300.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(label_w, 0)
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(l)
	parent.add_child(h)
	return h


func _note(parent: Control, text: String, color: Color = Color(0.72, 0.78, 0.86)) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)


## items: [[valor, texto, desabilitado?]]
func _choice(parent: Control, text: String, key: String, items: Array, tip: String = "") -> void:
	var h := _row(parent, text, tip)
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cur: Variant = GameSettings.get_v(key)
	for i in items.size():
		var it: Array = items[i]
		ob.add_item(it[1], i)
		if it.size() > 2 and it[2]:
			ob.set_item_disabled(i, true)
		if it[0] == cur:
			ob.select(i)
	ob.item_selected.connect(func(idx: int) -> void:
		GameSettings.set_v(key, items[idx][0])
		_after_change(key))
	h.add_child(ob)


func _toggle(parent: Control, text: String, key: String, tip: String = "") -> void:
	var h := _row(parent, text, tip)
	var cb := CheckButton.new()
	cb.button_pressed = GameSettings.get_v(key)
	cb.toggled.connect(func(on: bool) -> void:
		GameSettings.set_v(key, on)
		_after_change(key))
	h.add_child(cb)


func _slider(parent: Control, text: String, key: String, lo: float, hi: float, step: float, fmt: String, is_int: bool = false) -> void:
	var h := _row(parent, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(GameSettings.get_v(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(260, 24)
	var val := Label.new()
	val.custom_minimum_size = Vector2(70, 0)
	val.text = fmt % s.value
	s.value_changed.connect(func(x: float) -> void:
		val.text = fmt % x
		if is_int:
			GameSettings.set_v(key, int(x))
		else:
			GameSettings.set_v(key, x)
		_after_change(key))
	h.add_child(s)
	h.add_child(val)


func _after_change(key: String) -> void:
	if key in ["render_distance", "ram_budget", "vram_budget", "cpu_threads"] and world != null:
		world.request_distance(int(GameSettings.get_v("render_distance")))
	if key in ["render_distance", "lod_distance", "cpu_threads", "ram_budget", "vram_budget", "dyn_res", "target_fps"] and GameSettings.get_v("perf_auto"):
		GameSettings.set_v("perf_auto", false)


func _tab_graphics(b: Control) -> void:
	var h := _row(b, "Predefinição")
	for pr: Array in [["low", "Baixo"], ["medium", "Médio"], ["high", "Alto"], ["ultra", "Ultra"]]:
		var bt := _button(pr[1], func() -> void:
			GameSettings.apply_preset(pr[0])
			_after_change("render_distance")
			_show_options())
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(bt)
	_toggle(b, "Tela cheia", "fullscreen")
	_toggle(b, "VSync", "vsync")
	_choice(b, "Limite de FPS", "max_fps", [[0, "Sem limite"], [30, "30"], [60, "60"], [120, "120"], [144, "144"], [240, "240"]])
	_choice(b, "Anti-aliasing", "aa", [["off", "Desligado"], ["fxaa", "FXAA"], ["smaa", "SMAA"], ["taa", "TAA (temporal)"],
		["msaa2", "MSAA 2x"], ["msaa4", "MSAA 4x"], ["msaa8", "MSAA 8x"]], "Com FSR 2, o TAA próprio do upscaler é usado.")
	_choice(b, "Sombras", "shadows", [["off", "Desligadas"], ["low", "Baixas"], ["medium", "Médias"], ["high", "Altas"], ["ultra", "Ultra"]])
	_toggle(b, "Oclusão de ambiente (SSAO)", "ssao")
	_toggle(b, "Neblina volumétrica (raios de luz)", "volumetric_fog")
	_toggle(b, "Brilho (bloom)", "glow")
	_toggle(b, "Relevo 3D nos blocos (parallax)", "parallax", "Dá profundidade real a tijolos, pedras e tábuas.")
	_note(b, "Distância de visão, núcleos de CPU e memória ficam na aba Desempenho.")


func _tab_performance(b: Control) -> void:
	var h := _row(b, "Ajuste automático ao hardware")
	var auto := CheckButton.new()
	auto.button_pressed = GameSettings.get_v("perf_auto")
	auto.toggled.connect(func(on: bool) -> void:
		if on:
			GameSettings.apply_auto()
		else:
			GameSettings.set_v("perf_auto", false)
		_after_change("render_distance")
		_show_options())
	h.add_child(auto)
	_note(b, Hardware.summary())
	var rec := Hardware.recommended()
	_note(b, "Sugestão para este hardware: predefinição %s, %d chunks de voxels, %d km de terreno distante." % [
		str(rec["preset"]).capitalize(), rec["render_distance"], int(rec["lod_distance"]) / 1000])
	_slider(b, "Voxels detalhados (chunks)", "render_distance", 3, 256, 1, "%d", true)
	if world != null:
		_note(b, "Em uso agora: raio de %d chunks (%d carregados; cabem %d no orçamento de memória). Raios muito grandes são limitados automaticamente pela RAM e VRAM." % [
			world.render_distance, world.chunks.size(), world.max_chunks])
	_choice(b, "Terreno distante (LOD na GPU)", "lod_distance", [[0, "Desligado"], [1000, "1 km"], [2000, "2 km"], [4000, "4 km"], [8000, "8 km"],
		[16000, "16 km"], [32000, "32 km"]], "Além dos voxels detalhados, o relevo é desenhado direto pela placa de vídeo com níveis de detalhe.")
	var th: Array = [[0, "Automático (%d)" % maxi(2, Hardware.cores - 1)]]
	for n in [1, 2, 4, 6, 8, 12, 16, 24, 32, 64]:
		if n <= Hardware.cores:
			th.append([n, str(n)])
	_choice(b, "Núcleos de CPU para gerar o mundo", "cpu_threads", th, "Geração de chunks, árvores, vilas e malhas rodam em paralelo nesses núcleos.")
	_slider(b, "Limite de RAM para o mundo (%)", "ram_budget", 20, 85, 5, "%d%%", true)
	_slider(b, "Limite de VRAM para o mundo (%)", "vram_budget", 30, 90, 5, "%d%%", true)
	_toggle(b, "Resolução dinâmica", "dyn_res", "Baixa a resolução interna quando o FPS cai abaixo da meta e sobe quando sobra desempenho.")
	_choice(b, "Meta de FPS", "target_fps", [[30, "30"], [45, "45"], [60, "60"], [90, "90"], [120, "120"], [144, "144"]])


func _tab_upscaling(b: Control) -> void:
	var has_dlss: bool = GameSettings.ext_modes.has("dlss")
	var has_xess: bool = GameSettings.ext_modes.has("xess")
	_choice(b, "Tecnologia", "upscaler", [
		["native", "Nativo (sem upscaling)"],
		["bilinear", "Bilinear"],
		["fsr1", "AMD FSR 1.0 (espacial)"],
		["fsr2", "AMD FSR 2.2 (temporal)"],
		["dlss", "NVIDIA DLSS" + ("" if has_dlss else "  - indisponível nesta build"), not has_dlss],
		["xess", "Intel XeSS" + ("" if has_xess else "  - indisponível nesta build"), not has_xess],
	])
	_choice(b, "Qualidade", "upscale_quality", [["native", "Nativa 100% (só anti-aliasing)"], ["ultra", "Ultra qualidade 77%"],
		["quality", "Qualidade 67%"], ["balanced", "Equilibrado 59%"], ["performance", "Desempenho 50%"]])
	_slider(b, "Nitidez", "sharpness", 0.0, 1.0, 0.05, "%.2f")
	_note(b, "Placa de vídeo: %s" % GameSettings.gpu_name)
	_note(b, "FSR 1.0 e FSR 2.2 fazem parte da Godot e funcionam em placas AMD, NVIDIA e Intel.")
	if not has_dlss or not has_xess:
		_note(b, "DLSS e XeSS não existem na Godot %s: as bibliotecas da NVIDIA e da Intel não são distribuídas com a engine. As opções acima são detectadas em tempo de execução e se habilitam sozinhas se o jogo rodar em uma build da engine que exponha esses modos. Até lá, o FSR 2.2 é o equivalente temporal que roda em qualquer placa." % Engine.get_version_info()["string"], Color(0.95, 0.80, 0.50))


func _tab_rt(b: Control) -> void:
	_choice(b, "Iluminação global por raios (SDFGI)", "rt_gi", [["off", "Desligada"], ["low", "Baixa"], ["medium", "Média"], ["high", "Alta"]],
		"Raios traçados contra um campo de distâncias da cena: luz rebatida e céu iluminando o ambiente.")
	_toggle(b, "Reflexos traçados em espaço de tela (SSR)", "rt_reflections", "Reflexos em poças de chuva, mármore e metal.")
	_toggle(b, "Luz indireta em espaço de tela (SSIL)", "ssil")
	_note(b, "Suporte a ray tracing por hardware nesta placa: %s" % ("sim" if GameSettings.hardware_rt else "não detectado"))
	_note(b, "A Godot %s não tem um renderizador de ray tracing por hardware (RTX/DXR) pronto. O traçado de raios aqui é feito em software: o SDFGI marcha raios por um campo de distâncias da cena e os reflexos são traçados no buffer de profundidade. Funciona em qualquer placa compatível com Vulkan." % Engine.get_version_info()["string"], Color(0.95, 0.80, 0.50))


## Abre direto na aba do personagem (tecla P).
func open_character() -> void:
	open()
	_tab = 5
	_show_options()


func _swatches(parent: Control, text: String, key: String, colors: Array, names: Array) -> void:
	var h := _row(parent, text, "", 90.0)
	h.add_theme_constant_override("separation", 5)
	var cur := int(GameSettings.get_v(key))
	for i in colors.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(27, 27)
		b.tooltip_text = names[i]
		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[i]
		sb.set_corner_radius_all(5)
		sb.set_border_width_all(3 if i == cur else 1)
		sb.border_color = Color.WHITE if i == cur else Color(0, 0, 0, 0.5)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.pressed.connect(func() -> void:
			GameSettings.set_v(key, i)
			_show_options())
		h.add_child(b)


func _char_choice(parent: Control, text: String, key: String, items: Array) -> void:
	var h := _row(parent, text, "", 90.0)
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cur: Variant = GameSettings.get_v(key)
	for i in items.size():
		ob.add_item(items[i][1], i)
		if items[i][0] == cur:
			ob.select(i)
	ob.item_selected.connect(func(idx: int) -> void:
		GameSettings.set_v(key, items[idx][0])
		_show_options())
	h.add_child(ob)


func _tab_character(b: Control) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	b.add_child(top)
	# Previa 3D girando, num mundo proprio.
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(200, 330)
	svc.stretch = true
	top.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.3)
	cam.fov = 40.0
	sv.add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	sv.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	sv.add_child(env)
	var rig := VoxelRig.new()
	rig.process_mode = Node.PROCESS_MODE_ALWAYS
	sv.add_child(rig)
	var armor: Array[int] = [0, 0, 0, 0]
	if player != null:
		armor = player.armor
	rig.build(Rigs.humanoid(Player.character_options(armor)))
	rig.rotation.y = PI + 0.5
	var spin := Timer.new()
	spin.wait_time = 1.0 / 60.0
	spin.process_mode = Node.PROCESS_MODE_ALWAYS
	spin.autostart = true
	spin.timeout.connect(func() -> void:
		rig.rotation.y += 0.012
		rig.animate(1.0 / 60.0, 1.6, true))
	sv.add_child(spin)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	top.add_child(col)
	var h := _row(col, "Corpo", "", 90.0)
	for e: Array in [[false, "Masculino"], [true, "Feminino"]]:
		var bt := _button(e[1], func() -> void:
			GameSettings.set_v("char_female", e[0])
			_show_options())
		bt.toggle_mode = true
		bt.button_pressed = GameSettings.get_v("char_female") == e[0]
		bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(bt)
	_swatches(col, "Pele", "char_skin", Rigs.SKINS, Rigs.SKIN_NAMES)
	_swatches(col, "Cabelo", "char_hair", Rigs.HAIRS, Rigs.HAIR_NAMES)
	_swatches(col, "Camisa", "char_shirt", Blocks.DYES, Blocks.COLOR_NAMES_F)
	_swatches(col, "Calça", "char_pants", Blocks.DYES.map(func(c: Color) -> Color: return c.darkened(0.25)), Blocks.COLOR_NAMES_F)
	var styles := [[-1, "Padrão do corpo"]]
	for i in Rigs.HAIR_STYLES.size():
		styles.append([i, Rigs.HAIR_STYLES[i]])
	_char_choice(col, "Cabelo", "char_style", styles)
	var beards := []
	for i in Rigs.BEARDS.size():
		beards.append([i, Rigs.BEARDS[i]])
	_char_choice(col, "Barba", "char_beard", beards)
	var outfits := []
	for i in Rigs.OUTFITS.size():
		outfits.append([i, Rigs.OUTFITS[i]])
	_char_choice(col, "Roupa", "char_outfit", outfits)
	var hats := []
	for i in Rigs.HATS.size():
		hats.append([i, Rigs.HATS[i]])
	_char_choice(col, "Chapéu", "char_hat", hats)
	_note(col, "A armadura equipada aparece por cima da roupa. Use F5 no jogo para ver o personagem em terceira pessoa.")


func _line(parent: Control, text: String, key: String, w: float = 260.0) -> LineEdit:
	var h := _row(parent, text)
	var e := LineEdit.new()
	e.text = str(GameSettings.get_v(key))
	e.custom_minimum_size = Vector2(w, 0)
	e.text_changed.connect(func(t: String) -> void: GameSettings.set_v(key, int(t) if key == "net_port" else t))
	h.add_child(e)
	return e


func _tab_multiplayer(b: Control) -> void:
	_line(b, "Seu nome", "net_name")
	_line(b, "Endereço do servidor (IP)", "net_ip")
	_line(b, "Porta", "net_port", 120.0)
	var st := Label.new()
	st.autowrap_mode = TextServer.AUTOWRAP_WORD
	b.add_child(st)
	var refresh := func() -> void:
		if net == null or not net.active():
			st.text = "Desconectado. Hospede este mundo para outros entrarem, ou entre no servidor de outra pessoa."
			return
		var names: Array = [str(GameSettings.get_v("net_name")) + " (você)"]
		for pid: int in net.players:
			names.append(str(net.players[pid]["name"]))
		var r: String = {"host": "Hospedando este mundo", "client": "Conectado a um servidor"}.get(net.role, net.role)
		st.text = "%s - %d jogador(es): %s" % [r, names.size(), ", ".join(names)]
	refresh.call()
	var h := _row(b, "")
	var bh := _button("Hospedar este mundo", func() -> void:
		if net != null and not net.active():
			net.my_name = str(GameSettings.get_v("net_name"))
			var err: String = net.host(int(GameSettings.get_v("net_port")))
			st.text = err if err != "" else "Servidor aberto na porta %d. Os outros jogadores entram pelo seu IP." % int(GameSettings.get_v("net_port")))
	bh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(bh)
	var bj := _button("Entrar no servidor", func() -> void:
		GameSettings.set_v("net_join", "%s:%d" % [str(GameSettings.get_v("net_ip")), int(GameSettings.get_v("net_port"))])
		quit_requested.emit())
	bj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(bj)
	var bd := _button("Desconectar", func() -> void:
		if net != null:
			net.leave()
		refresh.call())
	bd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(bd)
	var tip := Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip.modulate = Color(1, 1, 1, 0.6)
	tip.text = "Entrar no servidor salva o mundo atual e recarrega o jogo conectado. Servidor dedicado: rode Servidor.bat (porta 7777 por padrão). Libere a porta no roteador/firewall para jogar pela internet."
	b.add_child(tip)


func _tab_game(b: Control) -> void:
	_slider(b, "Campo de visão", "fov", 55.0, 110.0, 1.0, "%.0f")
	_slider(b, "Sensibilidade do mouse", "sensitivity", 0.05, 1.0, 0.05, "%.2f")
	_slider(b, "Volume", "volume", 0.0, 1.0, 0.05, "%.2f")
	_toggle(b, "Balanço da câmera ao andar", "bob")
	_toggle(b, "Criaturas", "mobs")
	_choice(b, "Câmera (V ou F5 alterna)", "camera", [[0, "Primeira pessoa"], [1, "Terceira pessoa (por cima do ombro)"], [2, "Terceira pessoa (de frente)"]])
	_toggle(b, "Cortar um tronco derruba a árvore inteira", "tree_felling", "Segure Shift ao quebrar para tirar só um bloco.")
	_choice(b, "Duração de cada estação", "season_days", [[1, "1 dia"], [3, "3 dias"], [6, "6 dias"], [12, "12 dias"]],
		"Primavera, verão, outono e inverno mudam a vegetação, a neve e o crescimento das plantações.")
	if weather != null:
		var h := _row(b, "Clima")
		for i in Weather.STATE_NAMES.size():
			var bt := _button(Weather.STATE_NAMES[i], func() -> void: weather.set_state(i))
			bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(bt)
		var h2 := _row(b, "Hora do dia")
		for e: Array in [["Amanhecer", 0.26], ["Meio-dia", 0.5], ["Pôr do sol", 0.74], ["Noite", 0.0]]:
			var bt := _button(e[0], func() -> void: weather.time_of_day = e[1])
			bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h2.add_child(bt)
