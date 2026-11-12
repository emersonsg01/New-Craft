extends Node3D
## Monta o jogo inteiro por codigo: texturas, materiais, mundo, clima, jogador e interface.

var world: World
var weather: Weather
var far: FarTerrain
var mobs: Mobs
var player: Player
var sfx: Sfx
var hud: HUD
var menus: Menus
var _ui: CanvasLayer
var _loading: Control
var _load_label: Label
var _load_bar: ProgressBar
var _ready_to_play := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	_ui = CanvasLayer.new()
	add_child(_ui)
	_build_loading()
	await get_tree().process_frame

	# 1) Texturas PBR procedurais, geradas em paralelo.
	var tg := TextureGen.new()
	tg.start()
	while not tg.is_done():
		_set_loading("Gerando texturas PBR...", tg.progress() * 0.4)
		await get_tree().process_frame
	tg.finish()

	# 2) Materiais.
	var macro_n := FastNoiseLite.new()
	macro_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro_n.frequency = 0.012
	macro_n.fractal_octaves = 4
	var macro := NoiseTexture2D.new()
	macro.width = 256
	macro.height = 256
	macro.seamless = true
	macro.generate_mipmaps = true
	macro.noise = macro_n
	var wave_n := FastNoiseLite.new()
	wave_n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	wave_n.frequency = 0.02
	wave_n.fractal_octaves = 3
	var wave := NoiseTexture2D.new()
	wave.width = 256
	wave.height = 256
	wave.seamless = true
	wave.as_normal_map = true
	wave.bump_strength = 6.0
	wave.generate_mipmaps = true
	wave.noise = wave_n

	var terrain := ShaderMaterial.new()
	terrain.shader = load("res://shaders/terrain.gdshader")
	terrain.set_shader_parameter("tex_albedo", tg.albedo)
	terrain.set_shader_parameter("tex_normal", tg.normal)
	terrain.set_shader_parameter("tex_orm", tg.orm)
	terrain.set_shader_parameter("macro_noise", macro)
	terrain.set_shader_parameter("natural_layers", float(Blocks.NATURAL_LAYERS))
	terrain.set_shader_parameter("grass_layer", float(Blocks.L_GRASS_TOP))
	terrain.set_shader_parameter("sand_layer", float(Blocks.L_SAND))
	terrain.set_shader_parameter("sand_layer2", float(Blocks.FACE_LAYER[Blocks.RED_SAND * 6]))
	var foliage := ShaderMaterial.new()
	foliage.shader = load("res://shaders/foliage.gdshader")
	foliage.set_shader_parameter("tex_albedo", tg.albedo)
	foliage.set_shader_parameter("macro_noise", macro)
	foliage.set_shader_parameter("evergreen_a", float(Blocks.L_PINE_LEAVES))
	foliage.set_shader_parameter("evergreen_b", float(Blocks.FACE_LAYER[Blocks.ETHER_LEAVES * 6]))
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	water.set_shader_parameter("wave_normal", wave)
	var glass := ShaderMaterial.new()
	glass.shader = load("res://shaders/glass.gdshader")
	glass.set_shader_parameter("tex_albedo", tg.albedo)
	glass.set_shader_parameter("tex_orm", tg.orm)
	var lava := ShaderMaterial.new()
	lava.shader = load("res://shaders/lava.gdshader")
	lava.set_shader_parameter("macro_noise", macro)
	var mats: Array = [terrain, foliage, water, glass, lava]
	# Variantes para o bloco na mao (UV em espaco local, sem vento).
	var terrain_i: ShaderMaterial = terrain.duplicate()
	terrain_i.set_shader_parameter("local_space", true)
	var foliage_i: ShaderMaterial = foliage.duplicate()
	foliage_i.set_shader_parameter("sway_scale", 0.0)
	var glass_i: ShaderMaterial = glass.duplicate()
	glass_i.set_shader_parameter("local_space", true)
	var mats_item: Array = [terrain_i, foliage_i, water, glass_i, lava]

	# 3) Mundo.
	var save := World.load_save()
	var seed_v: int = save.get("seed", randi() & 0x3FFFFFFF)
	for a in args:
		if a.begins_with("--seed="):
			seed_v = int(a.trim_prefix("--seed="))
	sfx = Sfx.new()
	add_child(sfx)
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.render_distance = int(GameSettings.get_v("render_distance"))
	world.setup(seed_v, mats, save)
	add_child(world)

	far = FarTerrain.new()
	far.process_mode = Node.PROCESS_MODE_PAUSABLE
	var ac := tg.avg_colors
	far.setup(seed_v, macro, {
		"c_grass": ac[Blocks.L_GRASS_TOP], "c_dirt": ac[Blocks.L_DIRT], "c_stone": ac[Blocks.L_STONE], "c_sand": ac[Blocks.L_SAND],
		"c_snow": ac[Blocks.L_SNOW], "c_leaves": ac[Blocks.L_LEAVES], "c_pine": ac[Blocks.L_PINE_LEAVES],
	}, water)
	add_child(far)

	weather = Weather.new()
	weather.process_mode = Node.PROCESS_MODE_PAUSABLE
	weather.world = world
	weather.sfx = sfx
	weather.time_of_day = save.get("time", 0.34)
	weather.day = int(save.get("day", 0))
	add_child(weather)
	GameSettings.bind(weather.env, weather.sun, weather.moon)

	# 4) Jogador.
	var spawn := _find_spawn()
	if save.has("player"):
		spawn = save["player"]
	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.world = world
	player.weather = weather
	player.sfx = sfx
	player.mats_item = mats_item
	player.avg_colors = tg.avg_colors
	player.position = spawn
	player.yaw = save.get("yaw", 0.0)
	if save.has("armor"):
		var ar: Array = save["armor"]
		for i in mini(ar.size(), 4):
			player.armor[i] = int(ar[i])
	if save.has("stats"):
		player.stats.from_dict(save["stats"])
	if save.has("inv"):
		player.inv.from_array(save["inv"])
		player.food = float(save.get("food", 20.0))
	elif GameSettings.get_v("mode") == "creative":
		var start := [Blocks.PLANKS, Blocks.BRICKS, Blocks.STONE_BRICKS, Blocks.COBBLE, Blocks.ROOF_TILES, Blocks.GLASS, Blocks.LANTERN,
			Items.find("Espada de ferro"), Items.find("Picareta de ferro")]
		for i in 9:
			player.set_hotbar(i, start[i])
	add_child(player)
	weather.camera = player.cam
	player.spawn_point = spawn
	player.rebuild_rig()

	mobs = Mobs.new()
	mobs.process_mode = Node.PROCESS_MODE_PAUSABLE
	mobs.world = world
	mobs.player = player
	mobs.weather = weather
	mobs.sfx = sfx
	add_child(mobs)
	player.mobs = mobs
	world.focus = spawn

	# 5) Interface.
	hud = HUD.new()
	hud.player = player
	hud.world = world
	hud.weather = weather
	hud.far = far
	hud.mobs = mobs
	hud.icons = tg.icons
	hud.visible = false
	_ui.add_child(hud)
	menus = Menus.new()
	menus.world = world
	menus.weather = weather
	menus.player = player
	player.toast.connect(hud.add_toast)
	player.open_container.connect(func(pos: Vector3i) -> void: hud.open_chest(world.container_at(pos)))
	player.open_crafting.connect(hud.open_crafting)
	player.open_furnace.connect(func(pos: Vector3i) -> void: hud.open_furnace(world.furnace_at(pos)))
	hud.menus = menus
	player.slept.connect(func() -> void:
		weather.time_of_day = 0.26
		weather.day += 1)
	player.portal_entered.connect(_travel)
	if world.dim != 0:
		weather.set_dim(world.dim)
	menus.quit_requested.connect(_quit)
	_ui.add_child(menus)
	_ui.move_child(_loading, -1)
	GameSettings.changed.connect(_apply_view)
	_apply_view()

	# 6) Espera o terreno em volta do jogador.
	while true:
		var f := world.meshed_near(spawn, 3)
		_set_loading("Gerando o mundo (semente %d)..." % seed_v, 0.4 + f * 0.6)
		if f >= 0.999:
			break
		await get_tree().process_frame
	if not save.has("player"):
		player.position.y = world.surface_y(floori(spawn.x), floori(spawn.z)) + 1.05
	player.spawn_point = save.get("spawn", player.position) if world.dim == 0 else _find_spawn()
	_loading.queue_free()
	hud.visible = true
	player.active = true
	_ready_to_play = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _find_spawn() -> Vector3:
	var g := world.gen
	for i in 400:
		var ang := i * 0.7
		var rad := i * 6.0
		var x := cos(ang) * rad
		var z := sin(ang) * rad
		var hb := g.height_biome(x, z)
		var bio := hb >> 8
		var h := hb & 0xFF
		if (bio == WorldGen.B_PLAINS or bio == WorldGen.B_FOREST) and h < WorldGen.SEA + 16:
			return Vector3(floorf(x) + 0.5, h + 2.0, floorf(z) + 0.5)
	return Vector3(0.5, 90, 0.5)


func _build_loading() -> void:
	_loading = ColorRect.new()
	(_loading as ColorRect).color = Color(0.05, 0.07, 0.10)
	_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_loading)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	cc.add_child(v)
	var title := Label.new()
	title.text = "NEW CRAFT"
	title.add_theme_font_size_override("font_size", 54)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_load_label = Label.new()
	_load_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_load_label)
	_load_bar = ProgressBar.new()
	_load_bar.custom_minimum_size = Vector2(420, 18)
	_load_bar.max_value = 1.0
	_load_bar.show_percentage = false
	v.add_child(_load_bar)


func _set_loading(text: String, f: float) -> void:
	_load_label.text = text
	_load_bar.value = f


func _unhandled_input(ev: InputEvent) -> void:
	if not _ready_to_play:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var key := (ev as InputEventKey).physical_keycode
		if key == KEY_ESCAPE:
			if hud.palette_open:
				hud.toggle_palette()
			elif menus.visible:
				menus.close()
			else:
				menus.open()
		elif get_tree().paused:
			return
		elif key == KEY_E:
			hud.toggle_palette()
		elif key == KEY_P:
			menus.open_character()
		elif key == KEY_K:
			hud.toggle_attrs()
		elif key == KEY_C:
			weather.next_weather()
		elif key == KEY_F3:
			hud.show_debug = not hud.show_debug
		elif key == KEY_F2:
			_screenshot("user://screenshot_%d.png" % Time.get_unix_time_from_system())
	elif ev is InputEventMouseButton and ev.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused and not hud.palette_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_view() -> void:
	mobs.enabled = GameSettings.get_v("mobs")
	var d := float(GameSettings.get_v("lod_distance"))
	if world.dim != 0:
		d = 0.0
	far.set_view_distance(d)
	world.far_enabled = d > 0.0
	world.request_distance(int(GameSettings.get_v("render_distance")))
	if player != null and player.cam != null:
		player.cam.far = maxf(12000.0, d * 1.25 + 2000.0)
	weather.view_far = d * 0.97 if d > 0.0 else world.render_distance * 16.0 - 28.0
	weather.season_days = float(GameSettings.get_v("season_days"))


## Atravessa um portal: troca de dimensao, espera o terreno e garante um portal de volta.
func _travel(portal_id: int) -> void:
	var from := world.dim
	var target := 0
	if from == 0:
		target = 1 if portal_id == Blocks.PORTAL_FIRE else 2
	var frame := Blocks.OBSIDIAN if portal_id == Blocks.PORTAL_FIRE else Blocks.CRYSTAL_BLOCK
	var p := player.position
	var dest := Vector3(p.x, p.y, p.z)
	if from == 0 and target == 1:
		dest = Vector3(p.x / 8.0, 64, p.z / 8.0)
	elif from == 1:
		dest = Vector3(p.x * 8.0, 80, p.z * 8.0)
	hud.add_toast("Atravessando para: " + World.DIM_NAMES[target])
	player.active = false
	if player.vehicle != null:
		player.vehicle.rider = null
		player.vehicle = null
	mobs.clear_all()
	world.change_dim(target)
	weather.set_dim(target)
	_apply_view()
	player.position = Vector3(dest.x, 120, dest.z)
	player.vel = Vector3.ZERO
	world.focus = player.position
	var t0 := Time.get_ticks_msec()
	while world.meshed_near(player.position, 2) < 0.999 and Time.get_ticks_msec() - t0 < 15000:
		player.position = Vector3(dest.x, 120, dest.z)
		await get_tree().process_frame
	var bx := floori(dest.x)
	var bz := floori(dest.z)
	var stand := Vector3.ZERO
	var found: Variant = world.find_block_near(Vector3i(bx, int(dest.y), bz), portal_id, 12, 40)
	if found != null:
		var fp: Vector3i = found
		stand = Vector3(fp.x + 0.5, fp.y, fp.z - 1.5)
		var fy := world.find_floor(fp.x, fp.z - 1, fp.y - 3, fp.y + 4)
		if fy > 0:
			stand.y = fy
	else:
		var by := 0
		if target == 1:
			by = world.find_floor(bx, bz, 34, 110)
			if by < 0:
				by = 64
				for x in range(-2, 4):
					for z in range(-3, 4):
						world.set_block(Vector3i(bx + x, by - 1, bz + z), Blocks.SCORIA)
						for y in 5:
							world.set_block(Vector3i(bx + x, by + y, bz + z), 0)
		elif target == 2:
			by = world.surface_y(bx, bz) + 1
			if by < 12:
				by = 64
				for x in range(-3, 5):
					for z in range(-4, 5):
						world.set_block(Vector3i(bx + x, by - 1, bz + z), Blocks.ASTRAL_STONE)
		else:
			by = world.surface_y(bx, bz) + 1
		stand = world.build_portal(Vector3i(bx, by, bz), frame, portal_id)
	player.position = stand + Vector3(0, 0.05, 0)
	player.vel = Vector3.ZERO
	player.active = true
	if target == 0:
		player.spawn_point = player.position


func _process(_dt: float) -> void:
	if far != null and player != null:
		far.focus = player.position
		far.near_radius = world.near_radius
	if _ready_to_play and not get_tree().paused:
		weather.time_scale = 40.0 if Input.is_physical_key_pressed(KEY_T) else 1.0
		world.season_growth = weather.growth()


func _screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _save() -> void:
	if world == null or player == null or not _ready_to_play:
		return
	world.save({"player": player.position, "yaw": player.yaw, "time": weather.time_of_day, "day": weather.day, "inv": player.inv.to_array(),
		"food": player.food, "armor": player.armor, "spawn": player.spawn_point, "stats": player.stats.to_dict()})


func _quit() -> void:
	_save()
	get_tree().paused = false
	if world != null:
		world.wait_all()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		if world != null:
			world.wait_all()
