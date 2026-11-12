class_name HUD
extends Control
## Mira, vida, fome, armadura, barra de itens, inventario (criativo e sobrevivencia), criacao de
## itens, baus, avisos e painel de depuracao.

var player: Player
var world: World
var weather: Weather
var far: FarTerrain
var mobs: Mobs
var icons: Array[ImageTexture] = []
var show_debug := true
var palette_open := false
var _font: Font
var _rects: Array = []
var _hint_t := 14.0
var _tab := 0
var _tabs: Array[String] = []
var _toasts: Array = []
## Bau aberto (ou null) e pilha presa ao cursor.
var chest: Inventory = null
var cursor: Array = [0, 0, 0]
var _rtab := 0
var _rscroll := 0
var _only_craftable := false
var _stations: Dictionary = {}
var _station_t := 0.0
## Grade de criacao (2x2 no inventario, 3x3 na bancada/bigorna), fornalha aberta e previa do personagem.
var grid := Inventory.new(9)
var attrs_open := false
var grid_n := 2
var furnace: Dictionary = {}
var menus: Menus
var _preview: SubViewport
var _prev_rig: VoxelRig
var _prev_key := ""
var _prev_yaw := PI + 0.5
var _prev_drag := 0.0
var _prev_rect := Rect2()
const RTABS: Array[String] = ["Todas", "Básico", "Ferramentas", "Armas", "Armaduras", "Comida", "Fundição", "Construção", "Móveis"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	for k: String in Blocks.CATS:
		_tabs.append(k)
	for k: String in Items.CATS:
		_tabs.append(k)
	_build_preview()


func _build_preview() -> void:
	_preview = SubViewport.new()
	_preview.size = Vector2i(320, 500)
	_preview.own_world_3d = true
	_preview.transparent_bg = true
	_preview.msaa_3d = Viewport.MSAA_4X
	_preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_preview)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.0, 3.4)
	cam.fov = 38.0
	_preview.add_child(cam)
	cam.look_at(Vector3(0, 0.88, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	_preview.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 200, 0)
	fill.light_energy = 0.35
	_preview.add_child(fill)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.66)
	_preview.add_child(env)
	_prev_rig = VoxelRig.new()
	_preview.add_child(_prev_rig)


func _update_preview(delta: float) -> void:
	if _prev_rig == null or player == null:
		return
	var o := Player.character_options(player.armor)
	var key := str(o)
	if key != _prev_key:
		_prev_key = key
		_prev_rig.build(Rigs.humanoid(o))
	_prev_drag -= delta
	if _prev_drag <= 0.0:
		_prev_yaw += delta * 0.5
	_prev_rig.rotation.y = _prev_yaw
	_prev_rig.animate(delta, 0.0, true)


func add_toast(text: String) -> void:
	_toasts.append([text, 3.5])
	if _toasts.size() > 5:
		_toasts.pop_front()


func _process(delta: float) -> void:
	_hint_t -= delta
	for t: Array in _toasts:
		t[1] -= delta
	while not _toasts.is_empty() and _toasts[0][1] <= 0.0:
		_toasts.pop_front()
	if palette_open:
		_update_preview(delta)
		_station_t -= delta
		if _station_t <= 0.0:
			_station_t = 0.5
			_scan_stations()
	queue_redraw()


func _scan_stations() -> void:
	_stations.clear()
	if world == null or player == null:
		return
	var c := Vector3i(floori(player.position.x), floori(player.position.y), floori(player.position.z))
	for st: String in Blocks.STATIONS:
		for bid: int in Blocks.STATIONS[st]:
			if world.find_block_near(c, bid, 4, 3) != null:
				_stations[st] = true


func toggle_palette() -> void:
	palette_open = not palette_open
	if palette_open:
		_scan_stations()
		_prev_yaw = PI + 0.5
	else:
		chest = null
		furnace = {}
		attrs_open = false
		_return_grid()
		_return_cursor()
		grid_n = 2
	mouse_filter = Control.MOUSE_FILTER_STOP if palette_open else Control.MOUSE_FILTER_IGNORE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if palette_open else Input.MOUSE_MODE_CAPTURED
	if _preview != null:
		_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS if palette_open else SubViewport.UPDATE_DISABLED


## Painel de nivel e atributos (tecla K).
func toggle_attrs() -> void:
	if palette_open and attrs_open:
		toggle_palette()
		return
	if not palette_open:
		toggle_palette()
	chest = null
	furnace = {}
	attrs_open = true


func open_chest(inv: Inventory) -> void:
	if not palette_open:
		toggle_palette()
	chest = inv
	furnace = {}


func open_crafting(station: String) -> void:
	if not palette_open:
		toggle_palette()
	chest = null
	furnace = {}
	grid_n = 3
	_stations[station] = true
	if station == "bigorna":
		_stations["bancada"] = true


func open_furnace(f: Dictionary) -> void:
	if not palette_open:
		toggle_palette()
	chest = null
	furnace = f


func _return_cursor() -> void:
	if cursor[0] > 0 and player != null:
		var left := player.inv.add(cursor[0], cursor[1], cursor[2])
		if left > 0 and mobs != null:
			mobs.drop(cursor[0], player.position + Vector3(0, 1, 0), left, cursor[2])
	cursor = [0, 0, 0]


func _return_grid() -> void:
	if player == null:
		return
	for i in 9:
		var st: Array = grid.slots[i]
		if st[0] > 0:
			var left := player.inv.add(st[0], st[1], st[2])
			if left > 0 and mobs != null:
				mobs.drop(st[0], player.position + Vector3(0, 1, 0), left, st[2])
			grid.set_slot(i, 0, 0)


func _grid_stations() -> Dictionary:
	var st := {}
	if grid_n == 3:
		st["bancada"] = true
		if _stations.has("bigorna"):
			st["bigorna"] = true
	return st


func _grid_result() -> Dictionary:
	return Crafting.match_grid(grid, grid_n * grid_n, _grid_stations())


# ---------------------------------------------------------------- entrada

func _gui_input(ev: InputEvent) -> void:
	if not palette_open:
		return
	if ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and _prev_rect.has_point(mm.position):
			_prev_yaw += mm.relative.x * 0.012
			_prev_drag = 1.5
		return
	if not (ev is InputEventMouseButton and ev.pressed):
		return
	var mb := ev as InputEventMouseButton
	var creative := player.creative()
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var dir := 1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
		if creative and chest == null and furnace.is_empty():
			_tab = posmod(_tab + dir, _tabs.size())
		else:
			_rscroll = maxi(0, _rscroll + dir * 2)
		accept_event()
		return
	var right := mb.button_index == MOUSE_BUTTON_RIGHT
	if mb.button_index != MOUSE_BUTTON_LEFT and not right:
		return
	for e: Array in _rects:
		var r: Rect2 = e[0]
		if not r.has_point(mb.position):
			continue
		match e[1]:
			"tab":
				_tab = e[2]
			"item":
				var id: int = e[2]
				if Items.is_item(id) and Items.def(id)["kind"] == "armor" and mb.shift_pressed:
					player.equip(id)
				else:
					player.set_hotbar(player.slot, id)
			"armor":
				_click_armor(e[2])
			"slot":
				_click_slot(e[2], e[3], right, mb.shift_pressed)
			"result":
				_take_result(mb.shift_pressed)
			"rtab":
				_rtab = e[2]
				_rscroll = 0
			"filter":
				_only_craftable = not _only_craftable
				_rscroll = 0
			"recipe":
				if creative:
					_craft(e[2], mb.shift_pressed)
				else:
					_fill_grid(e[2])
			"custom":
				toggle_palette()
				if menus != null:
					menus.open_character()
			"attrs":
				attrs_open = true
			"attr_back":
				attrs_open = false
			"attr":
				var n := 5 if mb.shift_pressed else 1
				for k in n:
					if not player.stats.spend(e[2]):
						break
		accept_event()
		return


func _click_armor(s: int) -> void:
	if cursor[0] > 0 and Items.is_item(cursor[0]) and Items.def(cursor[0])["kind"] == "armor" and int(Items.def(cursor[0])["slot"]) == s:
		var old := player.armor[s]
		player.armor[s] = cursor[0]
		cursor = [old, 1, 0] if old > 0 else [0, 0, 0]
		player.rebuild_rig()
	elif cursor[0] == 0 and player.armor[s] > 0:
		cursor = [player.armor[s], 1, 0]
		player.armor[s] = 0
		player.rebuild_rig()


func _furnace_inv() -> Inventory:
	return furnace["inv"] if not furnace.is_empty() else null


## Clique num espaco de um inventario (jogador, bau, grade ou fornalha).
func _click_slot(inv: Inventory, i: int, right: bool, shift: bool) -> void:
	var st: Array = inv.slots[i]
	var finv := _furnace_inv()
	# Saida da fornalha: so retirar.
	if finv != null and inv == finv and i == 2:
		if st[0] == 0:
			return
		if cursor[0] == 0:
			cursor = st.duplicate()
			inv.set_slot(i, 0, 0)
		elif cursor[0] == st[0] and cursor[1] + st[1] <= Items.max_stack(st[0]):
			cursor[1] += st[1]
			inv.set_slot(i, 0, 0)
		return
	if shift and st[0] > 0:
		var dest: Inventory = null
		var dest_slot := -1
		if chest != null:
			dest = player.inv if inv == chest else chest
		elif inv == grid or (finv != null and inv == finv):
			dest = player.inv
		elif finv != null:
			# Da mochila para a fornalha: combustivel embaixo, o resto em cima.
			dest = finv
			dest_slot = 1 if Crafting.fuel_time(st[0]) > 0.0 and not World._smelt.has(st[0]) else 0
		if dest != null and dest_slot >= 0:
			var ds: Array = dest.slots[dest_slot]
			if ds[0] == 0:
				dest.slots[dest_slot] = st.duplicate()
				inv.set_slot(i, 0, 0)
			elif ds[0] == st[0]:
				var put := mini(Items.max_stack(st[0]) - ds[1], st[1])
				ds[1] += put
				st[1] -= put
				if st[1] <= 0:
					inv.set_slot(i, 0, 0)
		elif dest != null:
			var left := dest.add(st[0], st[1], st[2])
			if left == 0:
				inv.set_slot(i, 0, 0)
			else:
				st[1] = left
		else:
			var rng := range(9, 36) if i < 9 else range(0, 9)
			for j: int in rng:
				if inv.slots[j][0] == 0:
					inv.slots[j] = st.duplicate()
					inv.set_slot(i, 0, 0)
					break
		return
	if cursor[0] == 0:
		if st[0] == 0:
			return
		if right and st[1] > 1:
			var half := int(ceil(st[1] / 2.0))
			cursor = [st[0], half, st[2]]
			st[1] -= half
		else:
			cursor = st.duplicate()
			inv.set_slot(i, 0, 0)
		return
	var mx := Items.max_stack(cursor[0])
	if right:
		if st[0] == 0:
			inv.set_slot(i, cursor[0], 1, cursor[2])
			cursor[1] -= 1
		elif st[0] == cursor[0] and st[1] < mx:
			st[1] += 1
			cursor[1] -= 1
		if cursor[1] <= 0:
			cursor = [0, 0, 0]
		return
	if st[0] == 0:
		inv.slots[i] = cursor.duplicate()
		cursor = [0, 0, 0]
	elif st[0] == cursor[0] and mx > 1:
		var put := mini(mx - st[1], cursor[1])
		st[1] += put
		cursor[1] -= put
		if cursor[1] <= 0:
			cursor = [0, 0, 0]
	else:
		var tmp: Array = st.duplicate()
		inv.slots[i] = cursor.duplicate()
		cursor = tmp


## Retira o item criado da grade. Shift: cria o maximo e manda direto para a mochila.
func _take_result(shift: bool) -> void:
	var r := _grid_result()
	if r.is_empty():
		return
	var cells := grid_n * grid_n
	if shift:
		var n := 0
		while not r.is_empty() and n < 64:
			var left := player.inv.add(r["out"], r["n"])
			if left > 0 and mobs != null:
				mobs.drop(r["out"], player.position + Vector3(0, 1, 0), left)
			Crafting.consume_grid(grid, cells)
			n += 1
			r = _grid_result()
	else:
		var out: int = r["out"]
		var cnt: int = r["n"]
		if cursor[0] == 0:
			cursor = [out, cnt, 0]
		elif cursor[0] == out and cursor[1] + cnt <= Items.max_stack(out):
			cursor[1] += cnt
		else:
			return
		Crafting.consume_grid(grid, cells)
	if player.sfx != null:
		player.sfx.play("place", -6.0, 1.3)


## Livro de receitas: coloca na grade os ingredientes tirados da mochila.
func _fill_grid(r: Dictionary) -> void:
	var st: String = r["station"]
	if st == "fornalha":
		add_toast("Use uma fornalha: o item vai em cima e o combustível embaixo.")
		return
	var cells := grid_n * grid_n
	if Crafting.units(r) > cells:
		add_toast("Precisa de uma grade 3x3: use uma bancada de trabalho.")
		return
	if st != "" and not _grid_stations().has(st):
		add_toast("Precisa de: " + st)
		return
	_return_grid()
	var ings: Array = r["in"].duplicate()
	ings.sort_custom(func(a: Array, b: Array) -> bool: return not (a[0] is String) and (b[0] is String))
	var cell := 0
	for ing: Array in ings:
		for k in int(ing[1]):
			var found := -1
			for j in player.inv.size():
				var s: Array = player.inv.slots[j]
				if s[0] > 0 and Crafting.matches(ing[0], s[0]):
					found = j
					break
			if found < 0:
				_return_grid()
				add_toast("Faltam ingredientes: " + Crafting.ing_name(ing[0]))
				return
			grid.set_slot(cell, player.inv.slots[found][0], 1)
			player.inv.take_one(found)
			cell += 1


func _recipes() -> Array:
	var out := []
	for r: Dictionary in Crafting.RECIPES:
		if _rtab != 0 and r["cat"] != RTABS[_rtab]:
			continue
		if _only_craftable and not _can(r):
			continue
		out.append(r)
	return out


func _station_ok(r: Dictionary) -> bool:
	var st: String = r["station"]
	if player.creative() or st == "":
		return true
	if st == "fornalha":
		return not furnace.is_empty()
	return _grid_stations().has(st)


func _can(r: Dictionary) -> bool:
	if player.creative():
		return true
	if not _station_ok(r):
		return false
	if r["station"] != "fornalha" and Crafting.units(r) > grid_n * grid_n:
		return false
	return Crafting.times(player.inv, r) > 0


func _craft(r: Dictionary, many: bool) -> void:
	var n := 64 if many else 1
	for k in n:
		var left := player.inv.add(r["out"], r["n"])
		if left > 0:
			break
	if player.sfx != null:
		player.sfx.play("place", -6.0, 1.3)


# ---------------------------------------------------------------- desenho

func _text(pos: Vector2, text: String, size: int = 16, color: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(_font, pos + Vector2(1, 1), text, align, width, size, Color(0, 0, 0, 0.75))
	draw_string(_font, pos, text, align, width, size, color)


func draw_icon(id: int, c: Vector2, s: float) -> void:
	if id <= 0:
		return
	if Items.is_item(id):
		draw_texture_rect(Items.icon(id), Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), false)
		return
	if icons.is_empty():
		return
	var fl := Blocks.FACE_LAYER
	var kind := Blocks.KIND[id]
	if kind == Blocks.K_PLANT or kind == Blocks.K_WATER:
		draw_texture_rect(icons[fl[id * 6]], Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), false)
		return
	if kind == Blocks.K_MODEL:
		s *= 0.85
	var w := s * 0.87
	var t := c + Vector2(0, -s)
	var l := c + Vector2(-w, -s * 0.5)
	var r := c + Vector2(w, -s * 0.5)
	var m := c
	var b := c + Vector2(0, s)
	var l2 := c + Vector2(-w, s * 0.5)
	var r2 := c + Vector2(w, s * 0.5)
	var uv_top := PackedVector2Array([Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)])
	var uv_side := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var c1 := Color.WHITE
	var c2 := Color(0.72, 0.72, 0.72)
	var c3 := Color(0.5, 0.5, 0.5)
	var top_l := fl[id * 6 + 2]
	var front_l := fl[id * 6 + 5]
	var side_l := fl[id * 6 + 4]
	if kind == Blocks.K_MODEL:
		var mb: Array = Blocks.MODELS[id * 4 + 2][0]
		var ls: PackedInt32Array = mb[1]
		top_l = ls[2]
		front_l = ls[4]
		side_l = ls[1]
	draw_polygon(PackedVector2Array([l, t, r, m]), PackedColorArray([c1, c1, c1, c1]), uv_top, icons[top_l])
	draw_polygon(PackedVector2Array([l, m, b, l2]), PackedColorArray([c2, c2, c2, c2]), uv_side, icons[front_l])
	draw_polygon(PackedVector2Array([m, r, r2, b]), PackedColorArray([c3, c3, c3, c3]), uv_side, icons[side_l])


## Icone + quantidade + barra de desgaste.
func draw_stack(st: Array, c: Vector2, s: float) -> void:
	if st[0] <= 0:
		return
	draw_icon(st[0], c, s)
	if st[1] > 1:
		_text(c + Vector2(s * 0.1, s + 2), str(st[1]), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, s * 0.9)
	var dur := Items.durability(st[0])
	if dur > 0 and st[2] > 0:
		var f := 1.0 - float(st[2]) / dur
		draw_rect(Rect2(c + Vector2(-s, s - 2), Vector2(s * 2.0, 3)), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(c + Vector2(-s, s - 2), Vector2(s * 2.0 * f, 3)), Color(1.0 - f, f, 0.1))


func _heart(c: Vector2, s: float, fill: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var t := i / 24.0 * TAU
		pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * s / 17.0)
	draw_colored_polygon(pts, Color(0.08, 0.02, 0.02, 0.9))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(c + (p - c) * 0.72)
	draw_colored_polygon(inner, Color(0.25, 0.05, 0.05))
	if fill > 0.0:
		var clip := PackedVector2Array()
		for p in inner:
			clip.append(Vector2(minf(p.x, c.x - s + 2.0 * s * fill), p.y))
		draw_colored_polygon(clip, Color(0.86, 0.10, 0.12))


func _drumstick(c: Vector2, s: float, fill: float) -> void:
	draw_circle(c + Vector2(-s * 0.15, -s * 0.15), s * 0.62, Color(0.08, 0.05, 0.03, 0.9))
	draw_line(c + Vector2(s * 0.2, s * 0.2), c + Vector2(s * 0.85, s * 0.85), Color(0.08, 0.05, 0.03, 0.9), s * 0.45)
	if fill > 0.0:
		var col := Color(0.70, 0.40, 0.16) if fill >= 1.0 else Color(0.70, 0.40, 0.16, 0.5)
		draw_circle(c + Vector2(-s * 0.15, -s * 0.15), s * 0.45, col)
		draw_line(c + Vector2(s * 0.2, s * 0.2), c + Vector2(s * 0.75, s * 0.75), Color(0.93, 0.90, 0.82), s * 0.22)


func _shield(c: Vector2, s: float, fill: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(s, s * 0.2), c + Vector2(0, s * 1.1), c + Vector2(-s, s * 0.2)])
	draw_colored_polygon(pts, Color(0.1, 0.1, 0.12, 0.9))
	if fill > 0.0:
		var inner := PackedVector2Array()
		for p in pts:
			var q := c + (p - c) * 0.7
			inner.append(Vector2(minf(q.x, c.x - s + 2.0 * s * fill), q.y))
		draw_colored_polygon(inner, Color(0.78, 0.80, 0.86))


func _draw() -> void:
	if player == null:
		return
	var sz := size
	var cx := sz.x * 0.5
	var cy := sz.y * 0.5
	if not palette_open and player.view_mode != 2:
		draw_rect(Rect2(cx - 10, cy - 1, 20, 2), Color(1, 1, 1, 0.85))
		draw_rect(Rect2(cx - 1, cy - 10, 2, 20), Color(1, 1, 1, 0.85))
		if player.mine_progress > 0.0:
			draw_arc(Vector2(cx, cy), 18.0, -PI * 0.5, -PI * 0.5 + TAU * player.mine_progress, 32, Color(1, 1, 1, 0.9), 3.0)
	if player.head_in_water:
		var lava := world != null and Blocks.FLUID[world.get_block(floori(player.cam.global_position.x), floori(player.cam.global_position.y), floori(player.cam.global_position.z))] == 2
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.9, 0.3, 0.0, 0.5) if lava else Color(0.0, 0.25, 0.4, 0.22))
	if player.hurt_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.8, 0.0, 0.0, player.hurt_flash * 0.25))
	if not player.alive:
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.4, 0.0, 0.0, 0.45))
		_text(Vector2(0, cy), "Você morreu", 42, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, sz.x)

	var slot_w := 62.0
	var x0 := cx - slot_w * 4.5
	var y0 := sz.y - slot_w - 14.0
	for i in 9:
		var r := Rect2(x0 + i * slot_w, y0, slot_w - 4, slot_w - 4)
		draw_rect(r, Color(0.05, 0.06, 0.08, 0.62))
		var sel := i == player.slot
		draw_rect(r, Color(1, 1, 1, 0.95) if sel else Color(1, 1, 1, 0.22), false, 3.0 if sel else 1.0)
		draw_stack(player.inv.slots[i], r.get_center() + Vector2(0, 2), 19.0)
		_text(r.position + Vector2(5, 15), str(i + 1), 12, Color(1, 1, 1, 0.7))
	var creative := player.creative()
	if not creative:
		for i in 10:
			_heart(Vector2(x0 + 12 + i * 22, y0 - 20), 9.0, clampf(player.hp / 2.0 - i, 0.0, 1.0))
			_drumstick(Vector2(x0 + slot_w * 9 - 16 - i * 22, y0 - 20), 9.0, clampf(player.food / 2.0 - i, 0.0, 1.0))
		var ap := player.armor_points()
		if ap > 0.0:
			for i in 10:
				_shield(Vector2(x0 + 12 + i * 22, y0 - 44), 8.0, clampf(ap / 2.0 - i, 0.0, 1.0))
		var st := player.stats
		# Estamina e mana acima da fome.
		var bw := 216.0
		var bx := x0 + slot_w * 9 - 4 - bw
		_bar(Rect2(bx, y0 - 42, bw, 7), st.stamina / st.max_stamina(), Color(0.95, 0.80, 0.20) if not player._exhausted else Color(0.75, 0.35, 0.15))
		_bar(Rect2(bx, y0 - 54, bw, 7), st.mana / st.max_mana(), Color(0.35, 0.55, 1.0))
		# Icones: raio da estamina e gota da mana.
		var sc := Color(0.95, 0.80, 0.20)
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 8, y0 - 46), Vector2(bx - 13, y0 - 38), Vector2(bx - 9, y0 - 38), Vector2(bx - 12, y0 - 31), Vector2(bx - 5, y0 - 40), Vector2(bx - 9, y0 - 40)]), sc)
		draw_circle(Vector2(bx - 9, y0 - 49), 3.5, Color(0.35, 0.55, 1.0))
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 9, y0 - 57), Vector2(bx - 12.4, y0 - 50), Vector2(bx - 5.6, y0 - 50)]), Color(0.35, 0.55, 1.0))
		# Bolhas de ar embaixo d'agua.
		if st.breath < st.max_breath() - 0.01:
			var by := y0 - (66.0 if ap > 0.0 else 44.0)
			var nb := 10
			var f := st.breath / st.max_breath() * nb
			for i in nb:
				var c := Vector2(x0 + 12 + i * 22, by)
				var a := clampf(f - i, 0.0, 1.0)
				draw_circle(c, 7.5, Color(0.1, 0.2, 0.3, 0.5))
				if a > 0.0:
					draw_circle(c, 7.0 * (0.5 + 0.5 * a), Color(0.55, 0.85, 1.0, 0.95))
					draw_circle(c + Vector2(-2.5, -2.5), 2.0, Color(1, 1, 1, 0.9))
	if not creative:
		# Experiencia e nivel.
		var st2 := player.stats
		var xr := Rect2(x0, y0 - 7, slot_w * 9 - 4, 5)
		_bar(xr, st2.xp / st2.xp_needed(), Color(0.45, 0.95, 0.35))
		_text(Vector2(x0, y0 - 14), str(st2.level), 18, Color(0.6, 1.0, 0.45), HORIZONTAL_ALIGNMENT_CENTER, slot_w * 9 - 4)
		if st2.points > 0:
			_text(Vector2(x0, y0 - 32), "+%d (K)" % st2.points, 13, Color(1.0, 0.95, 0.5), HORIZONTAL_ALIGNMENT_CENTER, slot_w * 9 - 4)
	var id := player.held_id()
	var label := Items.name_of(id) if id > 0 else ""
	if Micro.can_micro(id) and player.micro_scale > 0:
		label += "  -  Escala: %s (T)" % Micro.SCALE_NAMES[player.micro_scale]
		var cr := int(player.micro_credit.get(id, 0))
		if cr > 0 and not creative:
			label += "  -  Sobra %d/512" % cr
	elif Blocks.can_shape(id):
		label += "  -  Forma: %s (R)" % Blocks.SHAPE_NAMES[player.current_shape()]
	if player.micro_scale > 0 and id == 0:
		label = "Escala: %s (T) - esculpe e constrói em pedaços" % Micro.SCALE_NAMES[player.micro_scale]
	elif Items.is_item(id):
		var d := Items.def(id)
		match d["kind"]:
			"weapon", "tool": label += "  -  Dano %.1f" % d["dmg"]
			"bow": label += "  -  Clique direito atira"
			"armor": label += "  -  Clique direito veste (+%.1f)" % d["armor"]
			"food": label += "  -  Clique direito come (+%d)" % int(d["heal"])
			"seed": label += "  -  Plante em terra arada"
			"igniter": label += "  -  Acende portais e fogueiras"
			"boat": label += "  -  Coloque na água"
	_text(Vector2(0, y0 - (86 if not creative else 40)), label, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, sz.x)

	for i in _toasts.size():
		var t: Array = _toasts[i]
		_text(Vector2(0, cy + 90 + i * 22), t[0], 17, Color(1, 1, 0.85, clampf(t[1], 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, sz.x)

	if _hint_t > 0.0 and not palette_open:
		var a := clampf(_hint_t, 0.0, 1.0)
		_text(Vector2(0, 40), "WASD mover - Espaço pular - Shift correr/agachar - Segure clique esq. para minerar/atacar - dir. usa/constrói", 16, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, sz.x)
		_text(Vector2(0, 62), "E inventário - K atributos - T escala (1, 1/2, 1/4, 1/8) - G feitiço - H cura - Q soltar - R forma 3D - V câmera - Esc opções", 16, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, sz.x)

	if show_debug and world != null and weather != null:
		var p := player.position
		var place := World.DIM_NAMES[world.dim]
		if world.dim == 0:
			place = WorldGen.BIOME_NAMES[world.gen.height_biome(p.x, p.z) >> 8]
		var lines: Array[String] = [
			"%d FPS" % Engine.get_frames_per_second(),
			"XYZ %.1f / %.1f / %.1f" % [p.x, p.y, p.z],
			"Local: %s" % place,
			"%s  -  Dia %d, %s  -  %s" % [weather.hour_text(), weather.day + 1, weather.season_name(), Weather.STATE_NAMES[weather.state]],
			"Modo: %s" % ("Criativo" if creative else "Sobrevivência"),
			"Chunks %d  -  Upscaling: %s" % [world.chunks.size(), GameSettings.active_upscaler.to_upper()],
		]
		if far != null and far.visible:
			lines.append("LOD: %d blocos na GPU  -  voxels até %.0f m" % [far.tile_count, world.near_radius])
		lines.append("Voxels: raio %d/%d chunks  -  %d carregados (máx. %d)  -  %d núcleos" % [world.render_distance, world.requested_distance,
			world.chunks.size(), world.max_chunks, GameSettings.worker_threads()])
		lines.append("RAM %.2f GB  -  VRAM %.2f GB  -  resolução %d%%" % [Performance.get_monitor(Performance.MEMORY_STATIC) / Hardware.GB,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / Hardware.GB, int(get_viewport().scaling_3d_scale * 100.0)])
		if mobs != null:
			lines.append("Criaturas: %d" % mobs.mobs.size())
		if player.flying:
			lines.append("Voando")
		for i in lines.size():
			_text(Vector2(12, 24 + i * 20), lines[i], 15)

	if palette_open:
		_rects.clear()
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.5))
		if attrs_open:
			_draw_attrs(sz, cx, cy)
		elif creative and chest == null and furnace.is_empty():
			_draw_creative(sz, cx, cy)
		else:
			_draw_survival(sz, cx, cy)
		if cursor[0] > 0:
			draw_stack(cursor, get_local_mouse_position() + Vector2(4, 4), 20.0)


func _bar(r: Rect2, f: float, col: Color) -> void:
	draw_rect(r.grow(1.0), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f, 0.0, 1.0), r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f, 0.0, 1.0), r.size.y * 0.4)), Color(1, 1, 1, 0.22))


const ATTR_COLORS := {
	"forca": Color(0.90, 0.35, 0.25), "inteligencia": Color(0.60, 0.45, 0.95), "percepcao": Color(0.30, 0.80, 0.75),
	"velocidade": Color(0.95, 0.75, 0.25), "folego": Color(0.45, 0.75, 1.0), "estamina": Color(0.85, 0.85, 0.30), "mana": Color(0.35, 0.50, 1.0),
}


func _draw_attrs(sz: Vector2, cx: float, cy: float) -> void:
	var st := player.stats
	var w := 900.0
	var h := 580.0
	var px := cx - w * 0.5
	var py := cy - h * 0.5
	_panel(Rect2(px, py, w, h))
	var mp := get_local_mouse_position()
	_text(Vector2(px + 24, py + 40), "Nível %d" % st.level, 30, Color(0.6, 1.0, 0.45))
	_bar(Rect2(px + 170, py + 24, 400, 12), st.xp / st.xp_needed(), Color(0.45, 0.95, 0.35))
	_text(Vector2(px + 170, py + 54), "Experiência %d / %d" % [int(st.xp), int(st.xp_needed())], 13, Color(1, 1, 1, 0.75))
	var pc := Color(1.0, 0.95, 0.5) if st.points > 0 else Color(1, 1, 1, 0.6)
	_text(Vector2(px + 600, py + 40), "Pontos: %d" % st.points, 22, pc)
	var back := Rect2(px + w - 130, py + 16, 110, 30)
	draw_rect(back, Color(0.3, 0.3, 0.36, 0.9) if back.has_point(mp) else Color(0.2, 0.2, 0.25, 0.9))
	_text(back.position + Vector2(0, 20), "Inventário", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, back.size.x)
	_rects.append([back, "attr_back"])
	var y := py + 84.0
	for k: String in Stats.KEYS:
		var v := st.get_attr(k)
		var col: Color = ATTR_COLORS[k]
		var row := Rect2(px + 20, y, 540, 58)
		draw_rect(row, Color(1, 1, 1, 0.05) if not row.has_point(mp) else Color(1, 1, 1, 0.09))
		draw_rect(Rect2(row.position, Vector2(4, row.size.y)), col)
		_text(Vector2(row.position.x + 14, y + 22), Stats.NAMES[k], 17, Color.WHITE)
		_text(Vector2(row.position.x + 14, y + 44), Stats.DESCS[k], 11, Color(1, 1, 1, 0.55))
		_text(Vector2(row.position.x + 330, y + 24), str(v), 20, col, HORIZONTAL_ALIGNMENT_RIGHT, 40)
		_bar(Rect2(row.position.x + 380, y + 14, 100, 8), float(v) / Stats.MAX_ATTR, col)
		var pb := Rect2(row.end.x - 44, y + 10, 34, 34)
		var can := st.points > 0 and v < Stats.MAX_ATTR
		draw_rect(pb, (col if pb.has_point(mp) else col.darkened(0.35)) if can else Color(0.25, 0.25, 0.28, 0.8))
		_text(pb.position + Vector2(0, 26), "+", 26, Color.WHITE if can else Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_CENTER, pb.size.x)
		if can:
			_rects.append([pb, "attr", k])
		y += 64.0
	# Resumo dos efeitos.
	var sx := px + 590.0
	var sy := py + 100.0
	_text(Vector2(sx, sy), "Efeitos", 18, Color(1, 1, 1, 0.9))
	var lines: Array = [
		["Dano corpo a corpo", "x%.2f" % st.melee_mult()],
		["Velocidade de mineração", "x%.2f" % st.mine_mult()],
		["Poder dos feitiços", "x%.2f" % st.spell_mult()],
		["Chance de crítico", "%d%%" % int(st.crit_chance() * 100.0)],
		["Dano à distância", "x%.2f" % st.ranged_mult()],
		["Saque extra", "%d%%" % int(st.loot_chance() * 100.0)],
		["Movimento", "%d%%" % int(st.move_mult() * 100.0)],
		["Intervalo de ataque", "%d%%" % int(st.attack_cd_mult() * 100.0)],
		["Ar embaixo d'água", "%.0f s" % st.max_breath()],
		["Estamina", "%d / %d" % [int(st.stamina), int(st.max_stamina())]],
		["Recuperação de estamina", "%.1f/s" % st.stamina_regen()],
		["Mana", "%d / %d" % [int(st.mana), int(st.max_mana())]],
		["Regeneração de mana", "%.1f/s" % st.mana_regen()],
		["Bônus de experiência", "+%d%%" % (3 * st.get_attr("inteligencia"))],
	]
	for i in lines.size():
		var ly := sy + 28 + i * 25
		_text(Vector2(sx, ly), lines[i][0], 13, Color(1, 1, 1, 0.7))
		_text(Vector2(sx, ly), lines[i][1], 14, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 280)
	_text(Vector2(px + 20, py + h - 30), "Ganhe experiência caçando monstros, minerando minérios, cortando árvores e colhendo. Shift+clique no + gasta 5 pontos.", 12, Color(1, 1, 1, 0.6))
	_text(Vector2(px + 20, py + h - 12), "G lança o feitiço arcano (12 de mana)  -  H cura (30 de mana)", 12, Color(0.75, 0.65, 1.0, 0.85))


func _panel(r: Rect2) -> void:
	draw_rect(r, Color(0.07, 0.08, 0.10, 0.95))
	draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)


func _slot_grid(inv: Inventory, from: int, to: int, cols: int, pos: Vector2, cell: float, mp: Vector2) -> int:
	var hover := -1
	for i in range(from, to):
		var k := i - from
		var r := Rect2(pos + Vector2((k % cols) * cell, (k / cols) * cell), Vector2(cell - 4, cell - 4))
		var hov := r.has_point(mp)
		draw_rect(r, Color(1, 1, 1, 0.14) if hov else Color(1, 1, 1, 0.05))
		if inv == player.inv and i == player.slot:
			draw_rect(r, Color(1, 1, 1, 0.6), false, 2.0)
		draw_stack(inv.slots[i], r.get_center(), cell * 0.32)
		_rects.append([r, "slot", inv, i])
		if hov and inv.slots[i][0] > 0:
			hover = inv.slots[i][0]
	return hover


func _draw_survival(sz: Vector2, cx: float, cy: float) -> void:
	var cell := 52.0
	var left_w := 250.0
	var mid_w := 9 * cell + 24.0
	var book_w := 430.0
	var total := left_w + mid_w + book_w
	var ph := 3 * cell + 4 * cell + 130.0
	var px := cx - total * 0.5
	var py := cy - ph * 0.5 - 20.0
	_panel(Rect2(px, py, total, ph))
	var mp := get_local_mouse_position()
	var hover := 0

	# ---------- personagem ----------
	_prev_rect = Rect2(px + 14, py + 14, 160, 250)
	draw_rect(_prev_rect, Color(0.12, 0.14, 0.18, 0.9))
	if _preview != null:
		draw_texture_rect(_preview.get_texture(), _prev_rect, false)
	draw_rect(_prev_rect, Color(1, 1, 1, 0.15), false, 1.0)
	_text(_prev_rect.position + Vector2(6, 16), "Arraste para girar", 11, Color(1, 1, 1, 0.45))
	var cb := Rect2(px + 14, _prev_rect.end.y + 8, 160, 30)
	draw_rect(cb, Color(0.30, 0.42, 0.62, 0.9) if cb.has_point(mp) else Color(0.22, 0.30, 0.46, 0.9))
	_text(cb.position + Vector2(0, 20), "Personalizar", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, cb.size.x)
	_rects.append([cb, "custom"])
	for s in 4:
		var r := Rect2(px + 182, py + 14 + s * (cell + 6), cell - 4, cell - 4)
		draw_rect(r, Color(1, 1, 1, 0.07))
		draw_rect(r, Color(1, 1, 1, 0.2), false, 1.0)
		if player.armor[s] > 0:
			draw_icon(player.armor[s], r.get_center(), cell * 0.32)
		else:
			_text(r.position + Vector2(3, cell * 0.55), Items.SLOT_NAMES[s].substr(0, 5), 10, Color(1, 1, 1, 0.35))
		_rects.append([r, "armor", s])
	var ab := Rect2(px + 14, cb.end.y + 6, 160, 30)
	var has_pts := player.stats.points > 0
	draw_rect(ab, Color(0.42, 0.52, 0.26, 0.95) if ab.has_point(mp) else (Color(0.50, 0.44, 0.16, 0.95) if has_pts else Color(0.26, 0.34, 0.20, 0.9)))
	_text(ab.position + Vector2(0, 20), "Atributos (Nv %d)%s" % [player.stats.level, " +" + str(player.stats.points) if has_pts else ""], 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, ab.size.x)
	_rects.append([ab, "attrs"])
	_text(Vector2(px + 14, ab.end.y + 20), "Proteção %d%%" % int(clampf(player.armor_points() * 4.0, 0.0, 80.0)), 13)
	_text(Vector2(px + 14, ab.end.y + 38), "Vida %d  -  Fome %d" % [int(player.hp), int(player.food)], 13)

	# ---------- area de cima: grade, bau ou fornalha ----------
	var mx := px + left_w
	var top := py + 14.0
	if chest != null:
		_text(Vector2(mx + 12, top + 12), "Baú", 16)
		var hv := _slot_grid(chest, 0, 27, 9, Vector2(mx + 12, top + 20), cell, mp)
		if hv > 0:
			hover = hv
	elif not furnace.is_empty():
		_draw_furnace(Vector2(mx + 12, top), cell, mp)
	else:
		var title := "Criação (2x2)" if grid_n == 2 else ("Bigorna (3x3)" if _stations.has("bigorna") else "Bancada de trabalho (3x3)")
		_text(Vector2(mx + 12, top + 12), title, 16)
		var gx := mx + 12 + (3 - grid_n) * cell * 0.5 + 40
		var gy := top + 20 + (3 - grid_n) * cell * 0.5
		for i in grid_n * grid_n:
			var r := Rect2(gx + (i % grid_n) * cell, gy + (i / grid_n) * cell, cell - 4, cell - 4)
			draw_rect(r, Color(1, 1, 1, 0.14) if r.has_point(mp) else Color(1, 1, 1, 0.05))
			draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
			draw_stack(grid.slots[i], r.get_center(), cell * 0.32)
			_rects.append([r, "slot", grid, i])
			if r.has_point(mp) and grid.slots[i][0] > 0:
				hover = grid.slots[i][0]
		var res := _grid_result()
		var ax := mx + 12 + 3 * cell + 70
		var ay := top + 20 + 1.5 * cell
		draw_colored_polygon(PackedVector2Array([Vector2(ax, ay - 8), Vector2(ax + 34, ay - 8), Vector2(ax + 34, ay - 16), Vector2(ax + 52, ay),
			Vector2(ax + 34, ay + 16), Vector2(ax + 34, ay + 8), Vector2(ax, ay + 8)]), Color(1, 1, 1, 0.5 if not res.is_empty() else 0.15))
		var rr := Rect2(ax + 66, ay - cell * 0.6, cell * 1.2, cell * 1.2)
		draw_rect(rr, Color(0.3, 0.5, 0.3, 0.35) if not res.is_empty() else Color(1, 1, 1, 0.05))
		draw_rect(rr, Color(1, 1, 1, 0.3), false, 2.0)
		if not res.is_empty():
			draw_stack([res["out"], res["n"], 0], rr.get_center(), cell * 0.4)
			if rr.has_point(mp):
				hover = res["out"]
		_rects.append([rr, "result"])
	# ---------- mochila ----------
	var iy := top + 3 * cell + 46
	_text(Vector2(mx + 12, iy - 8), "Mochila", 15)
	var hv2 := _slot_grid(player.inv, 9, 36, 9, Vector2(mx + 12, iy), cell, mp)
	if hv2 > 0:
		hover = hv2
	var hv3 := _slot_grid(player.inv, 0, 9, 9, Vector2(mx + 12, iy + 3 * cell + 10), cell, mp)
	if hv3 > 0:
		hover = hv3
	var info := "Clique pega/solta - Direito divide/solta 1 - Shift+clique move - Shift no resultado cria o máximo"
	if hover > 0:
		info = Items.name_of(hover)
	_text(Vector2(mx + 12, py + ph - 14), info, 13, Color(0.9, 0.9, 0.95))
	_draw_crafting(Rect2(mx + mid_w + 4, py + 10, book_w - 16, ph - 30), mp)


func _draw_furnace(o: Vector2, cell: float, mp: Vector2) -> void:
	var inv: Inventory = furnace["inv"]
	_text(o + Vector2(0, 12), "Fornalha", 16)
	var x0 := o.x + 90
	var r_in := Rect2(x0, o.y + 22, cell - 4, cell - 4)
	var r_fuel := Rect2(x0, o.y + 22 + cell * 1.9, cell - 4, cell - 4)
	var r_out := Rect2(x0 + 190, o.y + 22 + cell * 0.95 - 6, cell * 1.2, cell * 1.2)
	var labels := ["Item", "Combustível", "Resultado"]
	var rects := [r_in, r_fuel, r_out]
	for k in 3:
		var r: Rect2 = rects[k]
		draw_rect(r, Color(1, 1, 1, 0.14) if r.has_point(mp) else Color(1, 1, 1, 0.05))
		draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)
		draw_stack(inv.slots[k], r.get_center(), cell * (0.4 if k == 2 else 0.32))
		if k < 2:
			_text(Vector2(r.position.x - 86, r.get_center().y + 5), labels[k], 12, Color(0.8, 0.82, 0.86))
		else:
			_text(r.position + Vector2(0, r.size.y + 16), labels[k], 12, Color(0.8, 0.82, 0.86))
		_rects.append([r, "slot", inv, k])
	# Chama: quanto combustivel resta.
	var flame := clampf(float(furnace["burn"]) / maxf(float(furnace["burn_max"]), 0.01), 0.0, 1.0)
	var fc := Vector2(r_in.get_center().x, r_in.end.y + cell * 0.45)
	draw_rect(Rect2(fc - Vector2(10, 14), Vector2(20, 28)), Color(0.2, 0.2, 0.22))
	if flame > 0.0:
		draw_rect(Rect2(fc + Vector2(-10, 14 - 28 * flame), Vector2(20, 28 * flame)), Color(1.0, 0.55, 0.1))
	# Seta: progresso do cozimento.
	var cook := clampf(float(furnace["cook"]) / World.COOK_TIME, 0.0, 1.0)
	var ax := x0 + cell + 20
	var ay := r_out.get_center().y
	draw_rect(Rect2(ax, ay - 7, 110, 14), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(ax, ay - 7, 110 * cook, 14), Color(1.0, 0.85, 0.4))
	draw_colored_polygon(PackedVector2Array([Vector2(ax + 110, ay - 14), Vector2(ax + 128, ay), Vector2(ax + 110, ay + 14)]), Color(1, 1, 1, 0.3 + 0.5 * cook))


func _draw_crafting(area: Rect2, mp: Vector2) -> void:
	_text(area.position + Vector2(0, 14), "Livro de receitas", 16)
	_text(area.position + Vector2(160, 14), "clique para preencher a grade", 11, Color(0.7, 0.8, 0.9))
	var tx := area.position.x
	var ty := area.position.y + 24
	for i in RTABS.size():
		var tw := _font.get_string_size(RTABS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
		if tx + tw > area.end.x:
			tx = area.position.x
			ty += 22
		var r := Rect2(tx, ty, tw, 20)
		draw_rect(r, Color(1, 1, 1, 0.2) if i == _rtab else Color(1, 1, 1, 0.05))
		_text(r.position + Vector2(6, 15), RTABS[i], 12)
		_rects.append([r, "rtab", i])
		tx += tw + 3
	ty += 24
	var fr := Rect2(area.position.x, ty, 200, 20)
	draw_rect(fr, Color(0.3, 0.6, 0.3, 0.4) if _only_craftable else Color(1, 1, 1, 0.05))
	_text(fr.position + Vector2(6, 15), ("[x] " if _only_craftable else "[ ] ") + "Só o que dá para fazer", 12)
	_rects.append([fr, "filter"])
	ty += 26
	var list := _recipes()
	var row_h := 40.0
	var rows := int((area.end.y - ty) / row_h)
	_rscroll = clampi(_rscroll, 0, maxi(0, list.size() - rows))
	for k in rows:
		var idx := _rscroll + k
		if idx >= list.size():
			break
		var r: Dictionary = list[idx]
		var rr := Rect2(area.position.x, ty + k * row_h, area.size.x, row_h - 3)
		var can := _can(r)
		var hov := rr.has_point(mp)
		draw_rect(rr, Color(0.25, 0.45, 0.25, 0.35 if hov else 0.22) if can else Color(1, 1, 1, 0.08 if hov else 0.03))
		draw_icon(r["out"], rr.position + Vector2(20, row_h * 0.5 - 1), 14.0)
		var nm := Items.name_of(r["out"])
		if int(r["n"]) > 1:
			nm += " x%d" % r["n"]
		_text(rr.position + Vector2(42, 16), nm, 13, Color.WHITE if can else Color(0.6, 0.6, 0.65))
		var ix := rr.position.x + 42
		for ing: Array in r["in"]:
			var have := Crafting.have(player.inv, ing[0])
			var ok := have >= int(ing[1]) or player.creative()
			draw_icon(Crafting.ing_icon(ing[0]), Vector2(ix + 8, rr.position.y + 28), 7.0)
			_text(Vector2(ix + 18, rr.position.y + 33), "%d" % ing[1], 11, Color(0.6, 1.0, 0.6) if ok else Color(1.0, 0.5, 0.5))
			ix += 40
		var tag: String = r["station"]
		if tag == "" and Crafting.units(r) > 4:
			tag = "grade 3x3"
		if tag != "":
			_text(Vector2(rr.end.x - 90, rr.position.y + 16), tag, 11, Color(0.6, 1.0, 0.6) if _station_ok(r) else Color(1.0, 0.6, 0.4))
		_rects.append([rr, "recipe", r])
		if hov:
			var parts: Array[String] = []
			for ing: Array in r["in"]:
				parts.append("%d %s" % [ing[1], Crafting.ing_name(ing[0])])
			_text(Vector2(area.position.x, area.end.y + 14), "Precisa de: " + ", ".join(parts), 12, Color(0.9, 0.9, 0.7))
	if list.size() > rows:
		_text(Vector2(area.end.x - 120, area.end.y + 14), "Roda: rolar (%d/%d)" % [mini(_rscroll + rows, list.size()), list.size()], 11, Color(0.7, 0.7, 0.75))


func _draw_creative(sz: Vector2, cx: float, cy: float) -> void:
	var cols := 12
	var cell := 62.0
	var pw := cols * cell + 220.0
	var ph := 560.0
	var px := cx - pw * 0.5
	var py := cy - ph * 0.5 - 30.0
	_panel(Rect2(px, py, pw, ph))
	var mp := get_local_mouse_position()
	var tx := px + 12.0
	var ty := py + 10.0
	for i in _tabs.size():
		var tw := _font.get_string_size(_tabs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 22.0
		if tx + tw > px + pw - 10:
			tx = px + 12.0
			ty += 34
		var r := Rect2(tx, ty, tw, 30)
		var sel := i == _tab
		draw_rect(r, Color(1, 1, 1, 0.18) if sel else (Color(1, 1, 1, 0.08) if r.has_point(mp) else Color(1, 1, 1, 0.03)))
		_text(r.position + Vector2(11, 20), _tabs[i], 15, Color.WHITE if sel else Color(0.8, 0.82, 0.86))
		_rects.append([r, "tab", i])
		tx += tw + 4.0
	var tab_name := _tabs[_tab]
	var ids: Array = Blocks.CATS.get(tab_name, Items.CATS.get(tab_name, []))
	var gx := px + 12.0
	var gy := ty + 44.0
	var hover := 0
	for i in ids.size():
		var r := Rect2(gx + (i % cols) * cell, gy + (i / cols) * cell, cell - 6, cell - 6)
		var hov := r.has_point(mp)
		draw_rect(r, Color(1, 1, 1, 0.16) if hov else Color(1, 1, 1, 0.05))
		draw_icon(ids[i], r.get_center() + Vector2(0, 1), 20.0)
		_rects.append([r, "item", ids[i]])
		if hov:
			hover = ids[i]
	var ax := px + pw - 196.0
	_text(Vector2(ax, py + 72), "Armadura", 16)
	for s in 4:
		var r := Rect2(ax, py + 84 + s * 64, 58, 58)
		draw_rect(r, Color(1, 1, 1, 0.07))
		draw_rect(r, Color(1, 1, 1, 0.2), false, 1.0)
		if player.armor[s] > 0:
			draw_icon(player.armor[s], r.get_center(), 21.0)
		_text(r.position + Vector2(66, 34), Items.SLOT_NAMES[s], 14, Color(0.8, 0.82, 0.86))
		_rects.append([r, "armor", s])
	var hy := py + ph - 82.0
	_slot_grid(player.inv, 0, 9, 9, Vector2(gx, hy), cell, mp)
	var info := "Clique em um item para pôr no espaço %d. Shift+clique veste armadura. Roda troca de aba." % (player.slot + 1)
	if hover > 0:
		info = Items.name_of(hover)
	_text(Vector2(gx, hy - 12), info, 15, Color(0.92, 0.92, 0.95))
