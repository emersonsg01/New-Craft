class_name TitleMenu
extends Control
## Tela inicial: Jogar sozinho (mundos salvos, gerar novo mundo) e Multijogador
## (servidores favoritos, entrar em novo servidor). Emite "chosen" com o que o jogador escolheu:
##   {"mode": "solo", "world": meta}   ou   {"mode": "join", "address": "ip:porta"}

signal chosen(choice: Dictionary)

var _page: Control
var _status: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font_size = 18
	theme = th
	# Fundo: ceu de fim de tarde em degrade com uma faixa de "terreno" em blocos.
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.10, 0.16, 0.30))
	grad.set_color(1, Color(0.85, 0.55, 0.38))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var hills := _Hills.new()
	hills.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hills)
	_status = Label.new()
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_top = -40
	_status.offset_bottom = -14
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(1, 0.92, 0.75))
	add_child(_status)
	if Saves.title_message != "":
		_status.text = Saves.title_message
		Saves.title_message = ""
	_show_main()


func set_status(text: String) -> void:
	_status.text = text


# ---------------------------------------------------------------- paginas

func _clear() -> VBoxContainer:
	if _page != null:
		_page.queue_free()
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	move_child(cc, get_child_count() - 2)
	_page = cc
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.10, 0.88)
	sb.border_color = Color(1, 1, 1, 0.14)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(26)
	p.add_theme_stylebox_override("panel", sb)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	return v


func _title(v: Control, text: String, size: int = 30) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	v.add_child(l)


func _button(text: String, cb: Callable, w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 44)
	b.pressed.connect(cb)
	return b


func _show_main() -> void:
	var v := _clear()
	v.custom_minimum_size = Vector2(380, 0)
	var t := Label.new()
	t.text = "NEW CRAFT"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override("shadow_offset_x", 3)
	t.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(t)
	var sub := Label.new()
	sub.text = "mundo aberto em voxels"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	v.add_child(sub)
	v.add_child(HSeparator.new())
	v.add_child(_button("Jogar sozinho", _show_solo))
	v.add_child(_button("Multijogador", _show_multi))
	v.add_child(_button("Sair do jogo", func() -> void: get_tree().quit()))


# ---------------------------------------------------------------- solo

func _show_solo() -> void:
	var v := _clear()
	v.custom_minimum_size = Vector2(720, 0)
	_title(v, "Jogar sozinho")
	var worlds := Saves.list_worlds(Saves.DIR_SOLO)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 320)
	list.add_theme_font_size_override("font_size", 17)
	for w: Dictionary in worlds:
		var i := list.add_item("%s   —   %s" % [w["name"], Saves.describe(w)])
		list.set_item_metadata(i, w)
	if worlds.is_empty():
		var note := Label.new()
		note.text = "Nenhum mundo salvo ainda. Gere um mundo novo para começar."
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(note)
	else:
		list.select(0)
	v.add_child(list)
	var play := func() -> void:
		var sel := list.get_selected_items()
		if not sel.is_empty():
			chosen.emit({"mode": "solo", "world": list.get_item_metadata(sel[0])})
	list.item_activated.connect(func(_i: int) -> void: play.call())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var bp := _button("Jogar mundo selecionado", play)
	bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp.disabled = worlds.is_empty()
	h.add_child(bp)
	var bn := _button("Gerar novo mundo", _show_new_world)
	bn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(bn)
	var bd := _button("Excluir", func() -> void:
		var sel := list.get_selected_items()
		if sel.is_empty():
			return
		var w: Dictionary = list.get_item_metadata(sel[0])
		_confirm("Excluir o mundo \"%s\"?\nIsso apaga o mundo para sempre e não pode ser desfeito." % w["name"], func() -> void:
			Saves.delete_world(w["id"], Saves.DIR_SOLO)
			_show_solo()), 120)
	bd.disabled = worlds.is_empty()
	h.add_child(bd)
	v.add_child(_button("Voltar", _show_main))


func _show_new_world() -> void:
	var v := _clear()
	v.custom_minimum_size = Vector2(520, 0)
	_title(v, "Gerar novo mundo")
	var n := Saves.list_worlds(Saves.DIR_SOLO).size() + 1
	var name_e := _field(v, "Nome do mundo", "Novo mundo %d" % n)
	var seed_e := _field(v, "Semente (vazio = aleatória)", "")
	seed_e.placeholder_text = "ex.: 12345 ou uma palavra"
	var note := Label.new()
	note.text = "O mundo começa no modo sobrevivência. Para o criativo, aperte T e digite /modo-criativo."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
	note.add_theme_font_size_override("font_size", 15)
	v.add_child(note)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var create := func() -> void:
		var w := Saves.new_world(name_e.text, seed_e.text, Saves.DIR_SOLO)
		chosen.emit({"mode": "solo", "world": w})
	name_e.text_submitted.connect(func(_t: String) -> void: create.call())
	var bc := _button("Criar e jogar", create)
	bc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(bc)
	var bb := _button("Cancelar", _show_solo)
	bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(bb)
	name_e.grab_focus()
	name_e.select_all()


# ---------------------------------------------------------------- multijogador

func _show_multi() -> void:
	var v := _clear()
	v.custom_minimum_size = Vector2(720, 0)
	_title(v, "Multijogador")
	var nick := _field(v, "Seu nome", str(GameSettings.get_v("net_name")))
	nick.text_changed.connect(func(t: String) -> void: GameSettings.set_v("net_name", t.strip_edges() if t.strip_edges() != "" else "Jogador"))

	var lf := Label.new()
	lf.text = "Servidores favoritos"
	lf.add_theme_font_size_override("font_size", 20)
	v.add_child(lf)
	var favs := Saves.favorites()
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 200)
	for s: Dictionary in favs:
		var i := list.add_item("%s   —   %s" % [s.get("name", ""), s.get("address", "")])
		list.set_item_metadata(i, s)
	if not favs.is_empty():
		list.select(0)
	v.add_child(list)
	var join_fav := func() -> void:
		var sel := list.get_selected_items()
		if not sel.is_empty():
			chosen.emit({"mode": "join", "address": str((list.get_item_metadata(sel[0]) as Dictionary)["address"])})
	list.item_activated.connect(func(_i: int) -> void: join_fav.call())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var bj := _button("Entrar no servidor", join_fav)
	bj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bj.disabled = favs.is_empty()
	h.add_child(bj)
	var br := _button("Remover dos favoritos", func() -> void:
		var sel := list.get_selected_items()
		if not sel.is_empty():
			Saves.remove_favorite(str((list.get_item_metadata(sel[0]) as Dictionary)["address"]))
			_show_multi())
	br.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.disabled = favs.is_empty()
	h.add_child(br)
	if favs.is_empty():
		var note := Label.new()
		note.text = "Nenhum favorito ainda: entre num servidor novo abaixo e marque \"Salvar nos favoritos\"."
		note.add_theme_color_override("font_color", Color(0.72, 0.78, 0.86))
		note.add_theme_font_size_override("font_size", 15)
		v.add_child(note)

	v.add_child(HSeparator.new())
	var ln := Label.new()
	ln.text = "Entrar em novo servidor"
	ln.add_theme_font_size_override("font_size", 20)
	v.add_child(ln)
	var sname := _field(v, "Nome (para os favoritos)", "")
	sname.placeholder_text = "ex.: Servidor dos amigos"
	var addr := _field(v, "Endereço (IP:porta)", "%s:%d" % [str(GameSettings.get_v("net_ip")), int(GameSettings.get_v("net_port"))])
	var keep := CheckBox.new()
	keep.text = "Salvar nos favoritos"
	keep.button_pressed = true
	v.add_child(keep)
	var join_new := func() -> void:
		var a := addr.text.strip_edges()
		if a == "":
			set_status("Digite o endereço do servidor.")
			return
		var pa := Saves.parse_address(a)
		GameSettings.set_v("net_ip", pa[0])
		GameSettings.set_v("net_port", pa[1])
		var full := "%s:%d" % [pa[0], pa[1]]
		if keep.button_pressed:
			Saves.add_favorite(sname.text.strip_edges(), full)
		chosen.emit({"mode": "join", "address": full})
	addr.text_submitted.connect(func(_t: String) -> void: join_new.call())
	v.add_child(_button("Entrar", join_new))
	v.add_child(_button("Voltar", _show_main))


# ---------------------------------------------------------------- utilitarios

func _field(v: Control, label: String, value: String) -> LineEdit:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(250, 0)
	h.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(e)
	v.add_child(h)
	return e


func _confirm(text: String, cb: Callable) -> void:
	var d := ConfirmationDialog.new()
	d.title = "Confirmar"
	d.dialog_text = text
	d.ok_button_text = "Excluir"
	d.cancel_button_text = "Cancelar"
	d.confirmed.connect(cb)
	d.visibility_changed.connect(func() -> void:
		if not d.visible:
			d.queue_free())
	add_child(d)
	d.popup_centered()


## Silhueta de morros em blocos na parte de baixo da tela inicial.
class _Hills extends Control:
	func _draw() -> void:
		var s := size
		var cell := maxf(12.0, s.x / 96.0)
		var cols := int(s.x / cell) + 2
		for layer in 3:
			var col: Color = [Color(0.22, 0.26, 0.38), Color(0.16, 0.24, 0.20), Color(0.10, 0.16, 0.12)][layer]
			var base := s.y * (0.62 + layer * 0.1)
			for i in cols:
				var x := i * cell
				var hgt := (sin(i * 0.11 + layer * 2.0) * 0.5 + sin(i * 0.037 + layer) * 0.8 + 1.4) * cell * (5.0 - layer)
				var top := floorf((base - hgt) / cell) * cell
				draw_rect(Rect2(x, top, cell, s.y - top), col)
				if layer == 2:
					draw_rect(Rect2(x, top, cell, cell * 0.35), Color(0.20, 0.42, 0.18))
