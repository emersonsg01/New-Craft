class_name Player
extends Node3D
## Jogador: fisica voxel propria (AABB), natacao, voo, camera reativa em primeira e terceira
## pessoa, boneco masculino/feminino, vida, armadura, combate, arco, comida e construcao.

signal toast(text: String)
signal portal_entered(portal_id: int)
signal open_container(pos: Vector3i)
signal open_crafting(station: String)
signal open_furnace(pos: Vector3i)
signal slept
signal leveled(level: int)

const HALF_W := 0.3
const HEIGHT := 1.8
const EYE := 1.62
const STEP := 0.6
const REACH := 6.5
const EPS := 0.001
const MAX_HP := 20.0

var world: World
var weather: Weather
var sfx: Sfx
var mobs: Mobs
var mats_item: Array = []
var avg_colors: Array[Color] = []

var cam: Camera3D
var hand: Node3D
var hand_mesh: MeshInstance3D
var flash: SpotLight3D
var outline: MeshInstance3D
var rig: VoxelRig
var _rig_item: MeshInstance3D

var vel := Vector3.ZERO
var on_ground := false
var flying := false
var in_water := false
var head_in_water := false
var yaw := 0.0
var pitch := 0.0
var active := false
var alive := true
var hp := MAX_HP
var armor: Array[int] = [0, 0, 0, 0]
var hurt_flash := 0.0
var spawn_point := Vector3.ZERO
## 0 = primeira pessoa, 1 = terceira (atras), 2 = terceira (de frente)
var view_mode := 0
## Inventario: espacos 0..8 sao a barra de itens.
var inv := Inventory.new(36)
var stats := Stats.new()
## Mao esquerda: [id, quantidade, desgaste]. X troca com o item da mao direita.
var offhand: Array = [0, 0, 0]
var hand_l: Node3D
var hand_l_mesh: MeshInstance3D
var _rig_item_l: MeshInstance3D
var _shown_l := -1
## Luz de tocha/lanterna segurada e do capacete de minerador.
var hand_light: OmniLight3D
var helmet_light: SpotLight3D
## Escala de construcao/escultura: indice em Micro.SCALES (0 = bloco inteiro ... 3 = 1/8).
var micro_scale := 0
## Sobras de material esculpido, em voxels (512 = 1 bloco).
var micro_credit: Dictionary = {}
var _stam_delay := 0.0
var _exhausted := false
var _drown_t := 0.0
var _spell_cd := 0.0
var food := 20.0
var vehicle: Variant = null
var mine_progress := 0.0
var _mine_pos := Vector3i(0, -999, 0)
var _exhaust := 0.0
var _portal_t := 0.0
var _starve_t := 0.0
var _lava_t := 0.0
var _brng := RandomNumberGenerator.new()
var slot := 0
var shape_i := 0
var target: Dictionary = {}

var _eye_y := 0.0
var _bob := 0.0
var _bob_amp := 0.0
var _dip := 0.0
var _dip_v := 0.0
var _roll := 0.0
var _hand_sway := Vector2.ZERO
var _swing := 0.0
var _act_cd := 0.0
var _step_acc := 0.0
var _item_cache: Dictionary = {}
var _shown_item := -1
var _space_t := 0.0
var _mouse_delta := Vector2.ZERO
var _regen_t := 0.0
var _fall_peak := 0.0
var _rig_key := ""
var _cam_dist := 0.0
## Braco em primeira pessoa, rachaduras do bloco e estado das animacoes de golpe.
var arm_pivot: Node3D
var arm_mi: MeshInstance3D
var crack: MeshInstance3D
var _crack_mats: Array[StandardMaterial3D] = []
var _mine_phase := 0.0
var _mining := false
var _chip_t := 0.0
var _use_t := 0.0
var _swing_kind := "punch"
const LOGS: Array[int] = [Blocks.LOG, Blocks.PINE_LOG, Blocks.BIRCH_LOG, Blocks.MAHOG_LOG, Blocks.PALM_LOG, Blocks.CHERRY_LOG, Blocks.ETHER_LOG]


func _ready() -> void:
	_brng.randomize()
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 12000.0
	cam.position = Vector3(0, EYE, 0)
	add_child(cam)
	cam.make_current()

	hand = Node3D.new()
	cam.add_child(hand)
	hand_mesh = MeshInstance3D.new()
	hand_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand.add_child(hand_mesh)
	# Braco: o punho fica na origem do "hand" e o antebraco desce para o canto da tela.
	arm_pivot = Node3D.new()
	hand.add_child(arm_pivot)
	arm_pivot.basis = Basis(Quaternion(Vector3.UP, Vector3(0.32, -0.62, 0.72).normalized()))
	arm_mi = MeshInstance3D.new()
	arm_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arm_mi.position = Vector3(-1.5, -1.0, -1.5) * VoxelArt.T
	arm_pivot.add_child(arm_mi)
	_build_crack()
	hand_l = Node3D.new()
	cam.add_child(hand_l)
	hand_l_mesh = MeshInstance3D.new()
	hand_l_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hand_l.add_child(hand_l_mesh)
	hand_light = OmniLight3D.new()
	hand_light.light_color = Color(1.0, 0.70, 0.36)
	hand_light.light_energy = 2.4
	hand_light.omni_range = 11.0
	hand_light.omni_attenuation = 1.3
	hand_light.visible = false
	hand_light.position = Vector3(0, -0.2, -0.5)
	cam.add_child(hand_light)
	helmet_light = SpotLight3D.new()
	helmet_light.light_color = Color(1.0, 0.94, 0.80)
	helmet_light.light_energy = 5.0
	helmet_light.spot_range = 26.0
	helmet_light.spot_angle = 34.0
	helmet_light.spot_angle_attenuation = 0.8
	helmet_light.shadow_enabled = false
	helmet_light.visible = false
	helmet_light.position = Vector3(0, 0.12, 0)
	cam.add_child(helmet_light)

	flash = SpotLight3D.new()
	flash.spot_range = 38.0
	flash.spot_angle = 30.0
	flash.spot_angle_attenuation = 0.7
	flash.light_energy = 6.0
	flash.light_color = Color(1.0, 0.95, 0.85)
	flash.shadow_enabled = true
	flash.visible = false
	flash.position = Vector3(0.25, -0.15, 0.0)
	cam.add_child(flash)

	outline = MeshInstance3D.new()
	outline.mesh = _outline_mesh()
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.top_level = true
	outline.visible = false
	add_child(outline)

	rig = VoxelRig.new()
	add_child(rig)
	rebuild_rig()
	GameSettings.changed.connect(rebuild_rig)
	_eye_y = position.y


func _outline_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var c: Array[Vector3] = []
	for i in 8:
		c.append(Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
	for e: Array in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		v.append(c[e[0]])
		v.append(c[e[1]])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.02, 0.02, 0.02, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.surface_set_material(0, mat)
	return m


## Opcoes do boneco a partir das configuracoes + armadura equipada.
static func character_options(armor_ids: Array[int]) -> Dictionary:
	var ac: Array = [null, null, null, null]
	for s in 4:
		if armor_ids[s] > 0:
			ac[s] = Items.def(armor_ids[s])["c1"]
	return {
		"female": GameSettings.get_v("char_female"),
		"skin": Rigs.SKINS[int(GameSettings.get_v("char_skin")) % Rigs.SKINS.size()],
		"hair": Rigs.HAIRS[int(GameSettings.get_v("char_hair")) % Rigs.HAIRS.size()],
		"shirt": Blocks.DYES[int(GameSettings.get_v("char_shirt")) % 12],
		"pants": Blocks.DYES[int(GameSettings.get_v("char_pants")) % 12].darkened(0.25),
		"hair_style": int(GameSettings.get_v("char_style")) if int(GameSettings.get_v("char_style")) >= 0 else (3 if GameSettings.get_v("char_female") else 0),
		"beard": int(GameSettings.get_v("char_beard")),
		"outfit": int(GameSettings.get_v("char_outfit")),
		"hat": int(GameSettings.get_v("char_hat")),
		"armor": ac,
		"lamp": armor_ids[0] > 0 and Items.def(armor_ids[0]).get("light", false),
	}


func rebuild_rig() -> void:
	var o := character_options(armor)
	var key := str(o)
	if key == _rig_key:
		return
	_rig_key = key
	rig.build(Rigs.humanoid(o))
	if arm_mi != null:
		var shirt: Color = o["shirt"]
		var skin: Color = o["skin"]
		# Linhas contadas a partir do topo (ombro): manga em cima, punho de pele embaixo.
		var cuff := shirt.lightened(0.35)
		var sl: Array = [[0, 0, 0, 3, 6, shirt], [1, 0, 0, 3, 6, shirt], [4, 0, 0, 3, 6, shirt], [5, 0, 0, 3, 6, shirt], [2, 0, 0, 3, 3, shirt],
			[0, 0, 6, 3, 1, cuff], [1, 0, 6, 3, 1, cuff], [4, 0, 6, 3, 1, cuff], [5, 0, 6, 3, 1, cuff]]
		if armor[1] > 0:
			var ac: Color = Items.def(armor[1])["c1"]
			sl.append_array([[0, 0, 0, 3, 5, ac], [1, 0, 0, 3, 5, ac], [4, 0, 0, 3, 5, ac], [5, 0, 0, 3, 5, ac], [2, 0, 0, 3, 3, ac]])
		arm_mi.mesh = VoxelArt.part_mesh(Vector3i(3, 10, 3), skin, 0.08, sl, 77)
	# Itens nas maos do corpo (3a pessoa e sombra): a pegada fica com o VoxelRig.set_held.
	_rig_item = null
	_rig_item_l = null
	_shown_l = -1
	_shown_item = -1


func current_shape() -> int:
	return Blocks.PLAYER_SHAPES[shape_i]


func held_id() -> int:
	return inv.id_at(slot)


func creative() -> bool:
	return GameSettings.get_v("mode") == "creative"


## Coloca um item na barra (usado pelo inventario criativo).
func set_hotbar(i: int, id: int) -> void:
	inv.set_slot(i, id, Items.max_stack(id) if id > 0 else 0)


func _held_def() -> Dictionary:
	var id := held_id()
	return Items.def(id) if Items.is_item(id) else {}


## Gasta uma unidade do item na mao (no modo sobrevivencia).
func _consume_held() -> void:
	if not creative():
		inv.take_one(slot)


func _wear_held(amount: int = 1) -> void:
	if creative():
		return
	var id := held_id()
	if inv.wear(slot, amount):
		toast.emit(Items.name_of(id) + " quebrou!")
		if sfx != null:
			sfx.play("thud", 0.0, 2.0)


func armor_points() -> float:
	var a := 0.0
	for id in armor:
		if id > 0:
			a += float(Items.def(id)["armor"])
	return a


## Experiencia por abater uma criatura.
func kill_xp(m: Variant) -> float:
	var mhp: float = float(m.d.get("hp", 10))
	if m.d.get("hostile", false):
		return 4.0 + mhp * 0.45
	if m.d.get("npc", false):
		return 1.0
	return 1.0 + mhp * 0.15


func gain_xp(amount: float) -> void:
	if creative() or amount <= 0.0:
		return
	var ups := stats.add_xp(amount)
	if ups > 0:
		toast.emit("Nível %d! +%d pontos de atributo (K)" % [stats.level, ups * Stats.POINTS_PER_LEVEL])
		if sfx != null:
			sfx.play("place", 0.0, 2.4)
		hp = MAX_HP
		leveled.emit(stats.level)


const ORE_XP := {
	Blocks.COAL_ORE: 1.5, Blocks.IRON_ORE: 3.0, Blocks.COPPER_ORE: 2.5, Blocks.GOLD_ORE: 5.0,
	Blocks.CRYSTAL_ORE: 8.0, Blocks.RUBY_ORE: 8.0, Blocks.EMBERSTONE: 2.0,
}


## Lanca um feitico: 0 = projetil arcano, 1 = cura.
func cast_spell(kind: int) -> void:
	if not alive or _spell_cd > 0.0:
		return
	var cost := 12.0 if kind == 0 else 30.0
	if not creative():
		if stats.mana < cost:
			toast.emit("Mana insuficiente.")
			return
		stats.mana -= cost
	_spell_cd = 0.45 * stats.attack_cd_mult()
	_swing = 1.0
	_swing_kind = "use"
	rig.attack()
	if kind == 0:
		var fwd := -cam.global_transform.basis.z
		var origin := cam.global_position
		if mobs != null:
			mobs.shoot(origin + fwd * 0.8, origin + fwd * 60.0, true, 5.0 * stats.spell_mult(), 30.0, "magia")
		if sfx != null:
			sfx.play("splash", -8.0, 2.2)
	else:
		var heal := 4.0 + 0.4 * stats.get_attr("inteligencia")
		hp = minf(MAX_HP, hp + heal)
		toast.emit("Cura +%.1f" % heal)
		if sfx != null:
			sfx.play("place", -4.0, 1.6)
		_heal_fx()


func _heal_fx() -> void:
	var pt := CPUParticles3D.new()
	pt.one_shot = true
	pt.amount = 40
	pt.lifetime = 1.0
	pt.explosiveness = 0.6
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pt.emission_sphere_radius = 0.6
	pt.direction = Vector3.UP
	pt.spread = 30.0
	pt.gravity = Vector3(0, 1.5, 0)
	pt.initial_velocity_min = 0.5
	pt.initial_velocity_max = 1.5
	pt.scale_amount_min = 0.05
	pt.scale_amount_max = 0.1
	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.5, 1.0, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 1.0, 0.5)
	qm.material = mat
	pt.mesh = qm
	get_parent().add_child(pt)
	pt.global_position = global_position + Vector3(0, 0.9, 0)
	pt.emitting = true
	get_tree().create_timer(1.6).timeout.connect(pt.queue_free)


func damage(amount: float, from: Vector3) -> void:
	if not alive or flying or creative():
		return
	var red := clampf(armor_points() * 0.04, 0.0, 0.8)
	if int(offhand[0]) >= Items.BASE and Items.def(int(offhand[0]))["kind"] == "shield":
		var to := (from - position)
		to.y = 0.0
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		if to.length() > 0.01 and fwd.dot(to.normalized()) > 0.2:
			red = 1.0 - (1.0 - red) * (1.0 - float(Items.def(int(offhand[0]))["block"]))
			if sfx != null:
				sfx.play("thud", -4.0, 2.0)
	hp -= amount * (1.0 - red)
	hurt_flash = 1.0
	var push := position - from
	push.y = 0.0
	if push.length() > 0.01:
		push = push.normalized() * 7.0
		vel.x = push.x
		vel.z = push.z
	vel.y = maxf(vel.y, 4.0)
	_dip_v = -1.2
	if sfx != null:
		sfx.play("thud", 0.0, 0.7)
	if hp <= 0.0:
		_die()


func _die() -> void:
	alive = false
	hp = 0.0
	toast.emit("Você morreu! Renascendo...")
	if vehicle != null:
		vehicle.rider = null
		vehicle = null
	if not creative() and mobs != null:
		for i in inv.size():
			var st: Array = inv.slots[i]
			if st[0] > 0:
				mobs.drop(st[0], position + Vector3(0, 1, 0), st[1], st[2])
			inv.set_slot(i, 0, 0)
	await get_tree().create_timer(2.5).timeout
	position = spawn_point
	position.y = world.surface_y(floori(spawn_point.x), floori(spawn_point.z)) + 1.05
	vel = Vector3.ZERO
	hp = MAX_HP
	food = 20.0
	stats.stamina = stats.max_stamina()
	stats.mana = stats.max_mana()
	stats.breath = stats.max_breath()
	alive = true


## Recolhe um item do chao. Devolve quanto sobrou (0 = recolheu tudo).
func pickup(id: int, n: int = 1, wear: int = 0) -> int:
	var left := inv.add(id, n, wear)
	if left < n:
		if sfx != null:
			sfx.play("place", -10.0, 2.0)
		toast.emit("+%d %s" % [n - left, Items.name_of(id)])
	return left


## Veste uma armadura do inventario (a peca antiga volta para o inventario).
func equip(id: int) -> void:
	var s: int = Items.def(id)["slot"]
	if armor[s] == id:
		unequip(s)
		return
	var old := armor[s]
	armor[s] = id
	if not creative():
		inv.remove(id, 1)
		if old > 0:
			inv.add(old, 1)
	rebuild_rig()
	toast.emit("Equipado: " + Items.name_of(id))


func unequip(s: int) -> void:
	var old := armor[s]
	if old <= 0:
		return
	armor[s] = 0
	if not creative() and inv.add(old, 1) > 0 and mobs != null:
		mobs.drop(old, position + Vector3(0, 1, 0))
	rebuild_rig()
	toast.emit("Removido: " + Items.name_of(old))


func _unhandled_input(ev: InputEvent) -> void:
	if not active:
		return
	if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := ev as InputEventMouseMotion
		var sens := 0.0008 + float(GameSettings.get_v("sensitivity")) * 0.004
		yaw -= mm.relative.x * sens
		pitch = clampf(pitch - mm.relative.y * sens, -1.55, 1.55)
		_mouse_delta += mm.relative
	elif ev is InputEventMouseButton and ev.pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			slot = posmod(slot - 1, 9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			slot = posmod(slot + 1, 9)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE and not target.is_empty() and creative():
			set_hotbar(slot, target["id"])
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var key := (ev as InputEventKey).physical_keycode
		if key >= KEY_1 and key <= KEY_9:
			slot = key - KEY_1
		elif key == KEY_R:
			shape_i = (shape_i + 1) % Blocks.PLAYER_SHAPES.size()
		elif key == KEY_F and creative():
			flying = not flying
			vel.y = 0.0
		elif key == KEY_Q:
			var st: Array = inv.slots[slot]
			if st[0] > 0 and mobs != null:
				var n: int = st[1] if Input.is_physical_key_pressed(KEY_CTRL) else 1
				var fwd := -cam.global_transform.basis.z
				mobs.drop(st[0], cam.global_position + fwd * 0.6, n, st[2])
				if not creative():
					if n >= st[1]:
						inv.set_slot(slot, 0, 0)
					else:
						st[1] -= n
		elif key == KEY_L:
			flash.visible = not flash.visible
		elif key == KEY_X:
			# Troca o item da mao direita com o da esquerda.
			var cur: Array = inv.slots[slot].duplicate()
			inv.set_slot(slot, int(offhand[0]), int(offhand[1]), int(offhand[2]))
			offhand = cur
			_shown_l = -1
			_shown_item = -1
		elif key == KEY_B:
			micro_scale = (micro_scale + 1) % Micro.SCALES.size()
			toast.emit("Escala: " + Micro.SCALE_NAMES[micro_scale])
		elif key == KEY_G:
			cast_spell(0)
		elif key == KEY_H:
			cast_spell(1)
		elif key == KEY_F5 or key == KEY_V:
			GameSettings.set_v("camera", (int(GameSettings.get_v("camera")) + 1) % 3)
		elif key == KEY_SPACE:
			if _space_t > 0.0 and creative():
				flying = not flying
				vel.y = 0.0
			_space_t = 0.28


func _touching_wall() -> bool:
	var y := floori(position.y + 0.5)
	for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var q := position + Vector3(d.x, 0, d.y) * (HALF_W + 0.25)
		if Blocks.SOLID[world.get_block(floori(q.x), y, floori(q.z))] == 1:
			return true
	return false


func _aabb(p: Vector3) -> AABB:
	return AABB(Vector3(p.x - HALF_W, p.y, p.z - HALF_W), Vector3(HALF_W * 2.0, HEIGHT, HALF_W * 2.0))


func _overlaps(p: Vector3) -> bool:
	var bb := _aabb(p)
	for b in world.get_boxes(bb):
		if bb.intersects(b):
			return true
	return false


func _resolve(p: Vector3, axis: int, amount: float) -> Vector3:
	var bb := _aabb(p)
	for b in world.get_boxes(bb):
		if not bb.intersects(b):
			continue
		if axis == 1:
			p.y = (b.position.y - HEIGHT - EPS) if amount > 0.0 else (b.end.y + EPS)
		elif amount > 0.0:
			p[axis] = b.position[axis] - HALF_W - EPS
		else:
			p[axis] = b.end[axis] + HALF_W + EPS
		bb = _aabb(p)
	return p


func _move(motion: Vector3) -> void:
	var was_ground := on_ground
	on_ground = false
	var steps := maxi(1, int(ceil(motion.length() / 0.35)))
	var m := motion / steps
	var p := position
	for s in steps:
		if m.y != 0.0:
			p.y += m.y
			if _overlaps(p):
				p = _resolve(p, 1, m.y)
				if m.y < 0.0:
					on_ground = true
				vel.y = 0.0
		for axis: int in [0, 2]:
			var amt: float = m[axis]
			if amt == 0.0:
				continue
			p[axis] += amt
			if not _overlaps(p):
				continue
			var stepped := false
			if (was_ground or on_ground) and not flying:
				var up := p + Vector3(0, STEP, 0)
				if not _overlaps(up):
					up.y -= STEP
					p = _resolve(up, 1, -1.0)
					stepped = true
					on_ground = true
			if not stepped:
				p = _resolve(p, axis, amt)
				vel[axis] = 0.0
	position = p


func _physics_process(delta: float) -> void:
	if not active or world == null:
		return
	delta = minf(delta, 0.05)
	_space_t -= delta
	if not alive:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var ix := 0.0
	var iz := 0.0
	if captured:
		ix = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		iz = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	var sprint := captured and Input.is_physical_key_pressed(KEY_SHIFT) and (creative() or not _exhausted)
	var jump := captured and Input.is_physical_key_pressed(KEY_SPACE)
	_spell_cd -= delta
	var down := captured and Input.is_physical_key_pressed(KEY_CTRL)
	var dir := (Basis(Vector3.UP, yaw) * Vector3(ix, 0, iz))
	if dir.length() > 1.0:
		dir = dir.normalized()

	if not creative():
		flying = false
	if vehicle != null:
		if not is_instance_valid(vehicle):
			vehicle = null
		else:
			var sh: float = vehicle.seat_h if "seat_h" in vehicle else 0.25
			position = vehicle.position + Vector3(0, sh, 0)
			vel = Vector3.ZERO
			on_ground = true
			if captured and Input.is_physical_key_pressed(KEY_SHIFT):
				vehicle.rider = null
				vehicle = null
				position.y += 1.0
			return
	var px := floori(position.x)
	var pz := floori(position.z)
	var body_block := world.get_block(px, floori(position.y + 0.6), pz)
	var in_lava := Blocks.FLUID[body_block] == 2 or Blocks.FLUID[world.get_block(px, floori(position.y + 0.1), pz)] == 2
	if in_lava and not creative():
		_lava_t += delta
		if _lava_t > 0.5:
			_lava_t = 0.0
			damage(2.0, position)
	# Portal: ficar dentro por 1,5 s atravessa.
	var pblock := world.get_block(px, floori(position.y + 0.9), pz)
	if pblock == Blocks.PORTAL_FIRE or pblock == Blocks.PORTAL_ASTRAL:
		_portal_t += delta
		if _portal_t > 1.5:
			_portal_t = -3.0
			portal_entered.emit(pblock)
	elif _portal_t > 0.0:
		_portal_t = 0.0
	elif _portal_t < 0.0:
		_portal_t = minf(0.0, _portal_t + delta)
	var was_water := in_water
	in_water = Blocks.FLUID[body_block] != 0 or Blocks.FLUID[world.get_block(px, floori(position.y + 0.1), pz)] != 0
	head_in_water = Blocks.FLUID[world.get_block(floori(cam.global_position.x), floori(cam.global_position.y + 0.1), floori(cam.global_position.z))] != 0
	if in_water and not was_water and vel.y < -4.0 and sfx != null:
		sfx.play("splash", -4.0)

	if flying:
		var sp := 28.0 if sprint else 12.0
		var want := dir * sp
		want.y = (float(jump) - float(down)) * sp * 0.7
		vel = vel.lerp(want, 1.0 - exp(-delta * 8.0))
	elif in_water:
		var want := dir * (4.2 if sprint else 3.0) * stats.swim_mult()
		vel.x = lerpf(vel.x, want.x, 1.0 - exp(-delta * 5.0))
		vel.z = lerpf(vel.z, want.z, 1.0 - exp(-delta * 5.0))
		vel.y -= 7.0 * delta
		vel.y *= exp(-delta * 2.5)
		if jump:
			var head_out := Blocks.FLUID[world.get_block(px, floori(position.y + 1.45), pz)] == 0
			if _touching_wall():
				# Encostado numa borda: vai escalando ate os pes sairem da agua e passarem da borda.
				vel.y = maxf(vel.y, 5.6)
			elif head_out and vel.y < 0.5:
				# Na superficie: pequeno pulo sobre a agua.
				vel.y = maxf(vel.y, 4.6)
			else:
				vel.y = lerpf(vel.y, 3.6, 1.0 - exp(-delta * 9.0))
		elif down:
			vel.y = lerpf(vel.y, -3.6, 1.0 - exp(-delta * 9.0))
	else:
		var sp := (6.6 if sprint else 4.4) * stats.move_mult()
		var want := dir * sp
		var accel := 14.0 if on_ground else 3.5
		vel.x = lerpf(vel.x, want.x, 1.0 - exp(-delta * accel))
		vel.z = lerpf(vel.z, want.z, 1.0 - exp(-delta * accel))
		vel.y = maxf(vel.y - 27.0 * delta, -55.0)
		if jump and on_ground:
			vel.y = 8.4
			on_ground = false
			if not creative():
				stats.stamina = maxf(0.0, stats.stamina - 6.0)
				_stam_delay = 0.8

	var fall_v := vel.y
	var was_ground := on_ground
	if world.is_loaded(px, pz):
		_move(vel * delta)
	if not on_ground and not flying and not in_water:
		_fall_peak = minf(_fall_peak, fall_v)
	if on_ground and not was_ground:
		if fall_v < -6.0:
			_dip_v = clampf(fall_v * 0.02, -0.5, 0.0) * 4.0
			if sfx != null:
				sfx.play("step", -3.0, 0.8)
		# Dano de queda acima de ~4 blocos.
		if _fall_peak < -15.5 and not flying:
			damage((-_fall_peak - 15.5) * 0.9, position)
		_fall_peak = 0.0
	if in_water or flying:
		_fall_peak = 0.0
	if position.y < -20.0:
		position.y = world.surface_y(px, pz) + 2.0
		vel = Vector3.ZERO

	_update_resources(delta, sprint and Vector2(vel.x, vel.z).length() > 1.0)

	# Fome: cansaco de andar, correr e pular gasta comida; comida cheia regenera vida.
	if not creative():
		var hsp := Vector2(vel.x, vel.z).length()
		_exhaust += delta * (0.02 + hsp * (0.012 if not sprint else 0.03))
		if jump and on_ground:
			_exhaust += 0.05
		if _exhaust > 1.0:
			_exhaust = 0.0
			food = maxf(0.0, food - 1.0)
		if food <= 0.0:
			_starve_t += delta
			if _starve_t > 4.0:
				_starve_t = 0.0
				if hp > 2.0:
					damage(1.0, position)
	_regen_t += delta
	if _regen_t > 4.0 and hp < MAX_HP and (food >= 16.0 or creative()):
		_regen_t = 0.0
		hp = minf(MAX_HP, hp + 1.0)
		if not creative():
			_exhaust += 0.3

	var hs := Vector2(vel.x, vel.z).length()
	if on_ground and not flying and hs > 1.0:
		_step_acc += hs * delta
		if _step_acc > 2.1:
			_step_acc = 0.0
			if sfx != null:
				sfx.play("step", -11.0, 1.0)


## Estamina (correr/pular), mana e folego embaixo d'agua.
func _update_resources(delta: float, running: bool) -> void:
	var st := stats
	if creative():
		st.stamina = st.max_stamina()
		st.breath = st.max_breath()
		st.mana = minf(st.max_mana(), st.mana + st.mana_regen() * 4.0 * delta)
		return
	if running:
		st.stamina = maxf(0.0, st.stamina - (14.0 if not in_water else 10.0) * delta)
		_stam_delay = 0.8
	else:
		_stam_delay -= delta
		if _stam_delay <= 0.0:
			var mult := 1.0 if food > 6.0 else 0.4
			st.stamina = minf(st.max_stamina(), st.stamina + st.stamina_regen() * mult * delta)
	if st.stamina <= 0.0:
		_exhausted = true
	elif _exhausted and st.stamina > st.max_stamina() * 0.3:
		_exhausted = false
	st.mana = minf(st.max_mana(), st.mana + st.mana_regen() * delta)
	if head_in_water:
		st.breath = maxf(0.0, st.breath - delta)
		if st.breath <= 0.0:
			_drown_t += delta
			if _drown_t > 1.0:
				_drown_t = 0.0
				damage(2.0, position)
	else:
		_drown_t = 0.0
		st.breath = minf(st.max_breath(), st.breath + delta * 5.0)


func _process(delta: float) -> void:
	if world == null:
		return
	world.focus = position
	RenderingServer.global_shader_parameter_set("player_pos", position)
	rotation.y = yaw
	hurt_flash = maxf(0.0, hurt_flash - delta * 2.0)

	var hs := Vector2(vel.x, vel.z).length()
	var bob_on: bool = GameSettings.get_v("bob")
	var moving := on_ground and not flying and hs > 0.5
	_bob_amp = lerpf(_bob_amp, (1.0 if moving else 0.0) * (1.0 if bob_on else 0.0), 1.0 - exp(-delta * 8.0))
	_bob += delta * hs * 1.75
	_dip_v += (-_dip * 90.0 - _dip_v * 13.0) * delta
	_dip += _dip_v * delta
	var dy := position.y - _eye_y
	if absf(dy) > 1.5:
		_eye_y = position.y
	else:
		_eye_y = lerpf(_eye_y, position.y, 1.0 - exp(-delta * 18.0))
	var local_v := Basis(Vector3.UP, -yaw) * vel
	_roll = lerpf(_roll, -local_v.x * 0.006, 1.0 - exp(-delta * 7.0))
	var storm_shake := 0.0
	if weather != null:
		storm_shake = maxf(0.0, weather.wind_eff - 0.9) * 0.004
	var eye := Vector3(0, EYE + (_eye_y - position.y), 0)
	if not alive:
		eye.y = 0.3

	# ---------- Camera: primeira ou terceira pessoa ----------
	view_mode = int(GameSettings.get_v("camera"))
	rig.visible = view_mode != 0
	hand.visible = view_mode == 0
	if view_mode == 0:
		_cam_dist = 0.0
		cam.position = eye + Vector3(cos(_bob) * 0.028 * _bob_amp, sin(_bob * 2.0) * 0.042 * _bob_amp + _dip, 0)
		cam.rotation = Vector3(pitch + sin(_bob * 2.0) * 0.004 * _bob_amp, 0, _roll + sin(Time.get_ticks_msec() * 0.003) * storm_shake)
	else:
		var front := view_mode == 2
		var back := Basis(Vector3.UP, PI if front else 0.0) * Basis(Vector3.RIGHT, -pitch if front else pitch) * Vector3(0, 0, 4.2)
		if not front:
			# Visao por cima do ombro direito: a mira nao fica escondida atras do personagem.
			back += Basis(Vector3.RIGHT, pitch) * Vector3(0.55, 0.15, 0)
		var origin := global_position + Vector3(0, eye.y, 0)
		var world_dir := global_transform.basis * back
		var hit := world.raycast(origin, world_dir.normalized(), 4.4)
		var want := 4.2
		if not hit.is_empty():
			want = maxf(0.6, origin.distance_to(hit["point"]) - 0.3)
		_cam_dist = lerpf(_cam_dist, want, 1.0 - exp(-delta * 12.0)) if _cam_dist < want else want
		cam.position = eye + back * (_cam_dist / back.length())
		cam.rotation = Vector3(-pitch if front else pitch, PI if front else 0.0, 0)
	var riding: bool = vehicle != null and is_instance_valid(vehicle) and "saddle" in vehicle
	rig.pose = "ride" if riding else ""
	rig.animate(delta, hs if not riding else 0.0, on_ground or in_water or riding)
	for n: Node3D in rig.groups.get("head", []):
		n.rotation.x = -pitch * 0.6
	rig.set_flash(hurt_flash)

	var base_fov: float = GameSettings.get_v("fov")
	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT) and hs > 5.0
	cam.fov = lerpf(cam.fov, base_fov + (9.0 if sprinting else 0.0) + (5.0 if flying and hs > 14.0 else 0.0), 1.0 - exp(-delta * 7.0))
	if weather != null:
		weather.underwater = head_in_water

	# ---------- Item na mao ----------
	_hand_sway = _hand_sway.lerp(Vector2(clampf(_mouse_delta.x, -60, 60), clampf(_mouse_delta.y, -60, 60)) * 0.0012, 1.0 - exp(-delta * 10.0))
	_mouse_delta = Vector2.ZERO
	_swing = maxf(0.0, _swing - delta * 4.2)
	_use_t = maxf(0.0, _use_t - delta * 6.0)
	_animate_hand(delta)
	_update_item()

	# ---------- Mira e acoes ----------
	_act_cd -= delta
	if active and alive:
		var fwd := -cam.global_transform.basis.z
		var origin := global_position + Vector3(0, EYE + (_eye_y - position.y), 0)
		if view_mode == 2:
			fwd = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * Vector3(0, 0, -1)
		target = world.raycast(origin, fwd, REACH)
		if target.is_empty():
			outline.visible = false
		else:
			var tp: Vector3i = target["pos"]
			var bb := AABB()
			var first := true
			var tbx: Array = Blocks.fence_boxes(world.fence_mask(tp.x, tp.y, tp.z)) if target["id"] == Blocks.FENCE else Blocks.boxes(target["id"], target["shape"])
			for b: AABB in tbx:
				bb = b if first else bb.merge(b)
				first = false
			outline.visible = true
			var ms := micro_target(false)
			if not ms.is_empty():
				var sz: float = float(ms[2]) * Micro.INV
				bb = AABB(Vector3(ms[1]) * Micro.INV, Vector3.ONE * sz)
				tp = ms[0]
			outline.global_transform = Transform3D(Basis.from_scale(bb.size + Vector3.ONE * 0.008), Vector3(tp) + bb.position - Vector3.ONE * 0.004)
			if mine_progress > 0.0 and tp == _mine_pos:
				var stage := clampi(int(mine_progress * 10.0), 0, 9)
				crack.visible = true
				crack.material_override = _crack_mats[stage]
				crack.global_transform = Transform3D(Basis.from_scale(bb.size + Vector3.ONE * 0.01), Vector3(tp) + bb.get_center())
			else:
				crack.visible = false
		if target.is_empty() or mine_progress <= 0.0:
			crack.visible = false
		var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		if captured and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if _act_cd <= 0.0:
				_primary(origin, fwd, delta)
		else:
			mine_progress = 0.0
			_mining = false
		if captured and _act_cd <= 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_secondary(origin, fwd)


## Poses do braco em primeira pessoa: parado (balanco), minerando (golpes em ciclo),
## soco (mao vazia), golpe de arma (corte diagonal) e uso/colocar (empurrao curto).
func _animate_hand(delta: float) -> void:
	var held := held_id()
	var d := _held_def()
	var base_pos := Vector3(0.46 - _hand_sway.x + cos(_bob) * 0.012 * _bob_amp, -0.34 + _hand_sway.y + sin(_bob * 2.0) * 0.014 * _bob_amp - _dip * 0.5, -0.62)
	var base_rot := Vector3(-0.12, 0.30 + _hand_sway.x * 2.0, 0.04)
	if held == 0:
		base_pos += Vector3(0.04, -0.04, 0.06)
	var pos := base_pos
	var rot := base_rot
	if _mining:
		_mine_phase += delta * 9.0
		var k := sin(_mine_phase)
		var down := maxf(0.0, k)
		var up := maxf(0.0, -k)
		pos += Vector3(-0.06 * down, 0.10 * up - 0.12 * down, -0.16 * down)
		rot += Vector3(0.55 * up - 1.05 * down, 0.15 * down, -0.25 * down)
	elif _swing > 0.0:
		var t := 1.0 - _swing
		if _swing_kind == "punch":
			var s := sin(clampf(t * 1.6, 0.0, 1.0) * PI)
			pos += Vector3(-0.14 * s, 0.06 * s, -0.38 * s)
			rot += Vector3(0.25 * s, -0.25 * s, 0.0)
		elif _swing_kind == "slash":
			var a := smoothstep(0.0, 1.0, t)
			var arc := sin(t * PI)
			pos += Vector3(0.10 - 0.40 * a, 0.22 - 0.36 * a, -0.22 * arc)
			rot += Vector3(0.6 - 1.7 * a, 0.7 - 1.1 * a, 0.9 - 1.6 * a)
		else:
			var s := sin(t * PI)
			pos += Vector3(-0.05 * s, -0.12 * s, -0.16 * s)
			rot += Vector3(-0.9 * s, 0.0, 0.0)
	if _use_t > 0.0:
		var s := sin(_use_t * PI)
		pos += Vector3(-0.04 * s, 0.03 * s, -0.20 * s)
		rot += Vector3(0.2 * s, 0.0, 0.0)
	hand.position = hand.position.lerp(pos, 1.0 - exp(-delta * 30.0))
	hand.rotation = hand.rotation.lerp(rot, 1.0 - exp(-delta * 30.0))
	var lp := Vector3(-base_pos.x, base_pos.y - 0.02, base_pos.z)
	hand_l.position = hand_l.position.lerp(lp, 1.0 - exp(-delta * 30.0))
	hand_l.rotation = Vector3(base_rot.x, -base_rot.y, -base_rot.z)
	hand_l.visible = view_mode == 0
	arm_mi.visible = true
	if d.get("kind", "") == "bow":
		arm_pivot.basis = Basis(Quaternion(Vector3.UP, Vector3(0.2, -0.7, 0.68).normalized()))
	else:
		arm_pivot.basis = Basis(Quaternion(Vector3.UP, Vector3(0.32, -0.62, 0.72).normalized()))


func _build_crack() -> void:
	# 10 estagios de rachadura desenhados por codigo (branco = sem efeito na mistura MUL).
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var lines: Array = []
	for i in 40:
		var start := Vector2(16, 16) if i < 6 else Vector2(rng.randf_range(2, 30), rng.randf_range(2, 30))
		var ang := rng.randf() * TAU
		var pts: Array[Vector2] = [start]
		for k in 6:
			ang += rng.randf_range(-0.9, 0.9)
			pts.append(pts[-1] + Vector2(cos(ang), sin(ang)) * rng.randf_range(2.0, 4.5))
		lines.append(pts)
	for stage in 10:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		var n := 3 + stage * 4
		for li in mini(n, lines.size()):
			var pts: Array = lines[li]
			var segs := mini(pts.size() - 1, 2 + stage)
			for k in segs:
				var a: Vector2 = pts[k]
				var b: Vector2 = pts[k + 1]
				for j in 9:
					var q := a.lerp(b, j / 8.0)
					var x := posmod(int(q.x), 32)
					var y := posmod(int(q.y), 32)
					img.set_pixel(x, y, Color(0.34, 0.31, 0.29, 1))
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE
		_crack_mats.append(m)
	crack = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	crack.mesh = bm
	crack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crack.top_level = true
	crack.visible = false
	add_child(crack)


func _chips(at: Vector3, id: int) -> void:
	var layer := Blocks.FACE_LAYER[id * 6]
	var col := avg_colors[layer] if layer < avg_colors.size() else Color.GRAY
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 5
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.4
	p.gravity = Vector3(0, -14, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	bm.material = mat
	p.mesh = bm
	p.position = at
	p.top_level = true
	add_child(p)
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)


func item_mesh(id: int) -> ArrayMesh:
	if Items.is_item(id):
		return Items.mesh(id)
	var sh := current_shape() if Blocks.can_shape(id) else 0
	if sh == Blocks.SH_STAIRS or sh == Blocks.SH_WEDGE:
		sh |= 2 << 4
	if Blocks.KIND[id] == Blocks.K_MODEL:
		sh = 2 << 4
	var key := id | (sh << 8)
	if not _item_cache.has(key):
		var d := ChunkMesher.build_item(id, sh)
		var mesh: ArrayMesh = d["mesh"]
		var kinds: PackedInt32Array = d["kinds"]
		for s in kinds.size():
			mesh.surface_set_material(s, mats_item[kinds[s]])
		_item_cache[key] = mesh
	return _item_cache[key]


## Itens que iluminam quando segurados.
static func emits_light(id: int) -> bool:
	return id == Blocks.TORCH or id == Blocks.LANTERN or id == Blocks.CAMPFIRE or id == Blocks.LAMP


func _update_lights() -> void:
	var lid := held_id() if emits_light(held_id()) else int(offhand[0])
	hand_light.visible = emits_light(lid)
	if hand_light.visible:
		hand_light.light_color = Color(1.0, 0.62, 0.28) if lid == Blocks.TORCH or lid == Blocks.CAMPFIRE else Color(1.0, 0.78, 0.46)
		hand_light.light_energy = 2.4 + sin(Time.get_ticks_msec() * 0.011) * 0.25 * (1.0 if lid == Blocks.TORCH else 0.3)
	helmet_light.visible = armor[0] > 0 and bool(Items.def(armor[0]).get("light", false))


func _update_offhand() -> void:
	var id := int(offhand[0])
	if id == _shown_l:
		return
	_shown_l = id
	if id <= 0:
		hand_l_mesh.mesh = null
		if rig != null:
			rig.set_held(1, null, "")
		_rig_item_l = null
		return
	hand_l_mesh.mesh = item_mesh(id)
	if Items.is_item(id):
		hand_l_mesh.scale = Vector3.ONE * 0.42
		hand_l_mesh.rotation = Vector3(0.0, -1.69, 0.62) if Items.def(id)["kind"] != "shield" else Vector3(0.0, -1.57, 0.0)
		hand_l_mesh.position = hand_l_mesh.basis * (Vector3(0.30, 0.30, 0.0) * 0.42)
	else:
		hand_l_mesh.scale = Vector3.ONE * 0.22
		hand_l_mesh.rotation = Vector3(0.0, -0.35, 0.0)
		hand_l_mesh.position = hand_l_mesh.basis * (-Vector3(8.5, 1.5, 8.5) * 0.22) + Vector3(0.0, 0.12, -0.04)
	if rig != null:
		_rig_item_l = rig.set_held(1, hand_l_mesh.mesh, VoxelRig.grip_kind(id))


func _update_item() -> void:
	_update_offhand()
	_update_lights()
	var id := held_id()
	var key := id * 64 + (current_shape() if Blocks.can_shape(id) else 0)
	if key == _shown_item:
		return
	_shown_item = key
	if id == 0:
		hand_mesh.mesh = null
		if rig != null:
			rig.set_held(0, null, "")
		_rig_item = null
		return
	hand_mesh.mesh = item_mesh(id)
	if Items.is_item(id):
		# Ferramenta presa pelo cabo: o canto inferior esquerdo do desenho fica no punho.
		hand_mesh.scale = Vector3.ONE * 0.42
		hand_mesh.rotation = Vector3(0.0, -1.45, 0.62)
		hand_mesh.position = hand_mesh.basis * (Vector3(0.30, 0.30, 0.0) * 0.42) + Vector3(0.0, 0.02, 0.0)
	else:
		hand_mesh.scale = Vector3.ONE * 0.22
		hand_mesh.rotation = Vector3(0.0, 0.35, 0.0)
		hand_mesh.position = hand_mesh.basis * (-Vector3(8.5, 1.5, 8.5) * 0.22) + Vector3(0.0, 0.12, -0.04)
	if rig != null:
		_rig_item = rig.set_held(0, hand_mesh.mesh, VoxelRig.grip_kind(id))


## Tempo (s) para quebrar um bloco com o item na mao.
func break_time(id: int) -> float:
	var hard := Blocks.HARD[id]
	if hard == INF:
		return INF
	var base := hard * 1.5
	var d := _held_def()
	var need := Blocks.TOOL[id]
	var mm := stats.mine_mult()
	if need != Blocks.TOOL_NONE and int(d.get("tool", -1)) == need:
		return base / float(d.get("speed", 1.0)) / mm
	if need == Blocks.TOOL_NONE:
		return base / mm
	return base * 3.3 / mm


## A ferramenta na mao tem nivel para o bloco dropar algo?
func tool_ok(id: int) -> bool:
	var req := Blocks.REQ[id]
	if req == 0:
		return true
	var d := _held_def()
	return int(d.get("tool", -1)) == Blocks.TOOL_PICK and int(d.get("tier", 0)) >= req


## Clique esquerdo: ataca uma criatura (ou barco) na mira; senao, vai minerando o bloco.
func _primary(origin: Vector3, fwd: Vector3, delta: float) -> void:
	var d := _held_def()
	var reach: float = d.get("reach", 3.4)
	if d.get("kind", "") == "bow":
		reach = 3.4
	var block_t := INF if target.is_empty() else origin.distance_to(target["point"])
	if mobs != null:
		var hit: Array = mobs.ray_mob(origin, fwd, reach)
		if hit[0] != null and hit[1] < block_t:
			var dmg: float = float(d.get("dmg", 1.0)) * stats.melee_mult()
			if not creative():
				if stats.stamina < 4.0:
					dmg *= 0.5
				stats.stamina = maxf(0.0, stats.stamina - 4.0)
				_stam_delay = 0.8
			if randf() < stats.crit_chance():
				dmg *= 1.8
				toast.emit("Golpe crítico!")
			var was_alive: bool = hit[0].hp > 0.0
			hit[0].hurt(dmg, position)
			if was_alive and hit[0].hp <= 0.0:
				gain_xp(kill_xp(hit[0]))
			_act_cd = float(d.get("cd", 0.35)) * stats.attack_cd_mult()
			_swing = 1.0
			_mining = false
			_swing_kind = "slash" if d.get("kind", "") in ["weapon", "tool"] else "punch"
			rig.attack()
			if d.get("kind", "") in ["weapon", "tool"]:
				_wear_held()
			mine_progress = 0.0
			return
		var bh: Array = mobs.ray_boat(origin, fwd, reach)
		if bh[0] != null and bh[1] < block_t:
			bh[0].hp -= 1.0
			_act_cd = 0.3
			_swing = 1.0
			if bh[0].hp <= 0.0 or creative():
				mobs.break_boat(bh[0])
			return
	if target.is_empty():
		mine_progress = 0.0
		# Golpe no ar.
		if not _mining and _swing <= 0.0:
			_swing = 1.0
			_swing_kind = "slash" if d.get("kind", "") in ["weapon", "tool"] else "punch"
			_act_cd = 0.3
			rig.attack()
		return
	var p: Vector3i = target["pos"]
	if p != _mine_pos:
		_mine_pos = p
		mine_progress = 0.0
	_mining = true
	var prev_phase := fmod(_mine_phase, TAU)
	if prev_phase > PI * 0.4 and prev_phase < PI * 0.4 + delta * 9.5:
		rig.attack()
	_chip_t -= delta
	if _chip_t <= 0.0 and not creative():
		_chip_t = 0.22
		_chips(target["point"] + Vector3(target["normal"]) * 0.05, target["id"])
	if creative():
		if not micro_target(false).is_empty():
			_carve()
			_act_cd = 0.12
		else:
			_break_block()
			_act_cd = 0.2
		_swing = 1.0
		_swing_kind = "mine"
		return
	var t := break_time(target["id"])
	if t == INF:
		return
	var carving := not micro_target(false).is_empty()
	if carving:
		# Pedaco menor quebra mais rapido (proporcional ao volume, com um minimo).
		var s := float(Micro.SCALES[micro_scale]) / 8.0
		t = maxf(t * s * s * 1.6, 0.07)
	_swing = minf(1.0, _swing + delta * 3.0) if _swing < 0.2 else _swing
	mine_progress += delta / maxf(t, 0.05)
	if mine_progress >= 1.0:
		mine_progress = 0.0
		if carving:
			_carve()
		else:
			_break_block()
		_act_cd = 0.12


## Clique direito: interagir com NPC/barco/bloco, usar o item na mao ou colocar bloco.
func _secondary(origin: Vector3, fwd: Vector3) -> void:
	var sneak := Input.is_physical_key_pressed(KEY_SHIFT)
	var block_t := INF if target.is_empty() else origin.distance_to(target["point"])
	if mobs != null:
		var hit: Array = mobs.ray_mob(origin, fwd, 4.0)
		if hit[0] != null and hit[1] < block_t and _animal_use(hit[0]):
			_act_cd = 0.4
			return
		if hit[0] != null and hit[1] < block_t and hit[0].d.has("ride") and vehicle == null:
			_interact_mount(hit[0], sneak)
			_act_cd = 0.4
			return
		if hit[0] != null and hit[1] < block_t and hit[0].kind == "aldeao":
			var txt := mobs.interact(hit[0], sneak, inv)
			if txt != "":
				toast.emit(txt)
			_act_cd = 0.5
			return
		var bh: Array = mobs.ray_boat(origin, fwd, 4.0)
		if bh[0] != null and bh[1] < block_t and vehicle == null:
			vehicle = bh[0]
			bh[0].rider = self
			toast.emit("Shift para sair do barco. WASD rema.")
			_act_cd = 0.5
			return
	var id := held_id()
	var d := _held_def()
	var tid: int = target.get("id", 0)
	var tp: Vector3i = target.get("pos", Vector3i.ZERO)
	# Blocos com uso proprio (Shift ignora e coloca bloco).
	if not target.is_empty() and not sneak:
		if Blocks.CHESTS.has(tid):
			open_container.emit(tp)
			_act_cd = 0.3
			return
		if Blocks.door_toggle(tid) != 0:
			_toggle_door(tp)
			_act_cd = 0.3
			return
		if tid == Blocks.DRAWBRIDGE or tid == Blocks.DRAWBRIDGE_DOWN:
			toggle_drawbridge(tp)
			_act_cd = 0.6
			return
		if tid == Blocks.FURNACE:
			open_furnace.emit(tp)
			_act_cd = 0.3
			return
		for st: String in Blocks.STATIONS:
			if Blocks.STATIONS[st].has(tid):
				open_crafting.emit(st)
				_act_cd = 0.3
				return
		if tid == Blocks.BED or tid == Blocks.BED_FOOT:
			if weather != null and weather.sun_dir.y < 0.05:
				slept.emit()
				spawn_point = position
				toast.emit("Você dormiu até o amanhecer.")
			else:
				toast.emit("Só é possível dormir à noite.")
			_act_cd = 0.6
			return
		if tid == Blocks.BERRY_BUSH:
			world.set_block(tp, Blocks.BERRY_BUSH_EMPTY)
			if mobs != null:
				mobs.drop(Items.find("Frutas silvestres"), Vector3(tp) + Vector3(0.5, 0.6, 0.5), _brng.randi_range(2, 3))
			_act_cd = 0.3
			return
	if not d.is_empty():
		var kind: String = d["kind"]
		var nm: String = d["name"]
		if d.has("crop") and _try_plant(int(d["crop"])):
			return
		match kind:
			"door":
				_place_door_item(d)
				return
			"window":
				_place_window_item(d)
				return
			"drawbridge":
				_place_drawbridge()
				return
			"food":
				if food < 20.0 or hp < MAX_HP:
					food = minf(20.0, food + float(d["heal"]))
					if creative():
						hp = minf(MAX_HP, hp + float(d["heal"]))
					toast.emit("Comeu: " + nm)
					_consume_held()
					if d.has("returns") and not creative():
						var back := Items.find(str(d["returns"]))
						if inv.add(back, 1) > 0 and mobs != null:
							mobs.drop(back, position + Vector3(0, 1, 0))
					if sfx != null:
						sfx.play("step", -2.0, 1.6)
				_act_cd = 0.5
				_swing = 1.0
				return
			"armor":
				equip(id)
				_act_cd = 0.4
				return
			"clothing":
				var k2: String = "char_hat" if d["slot_k"] == "hat" else "char_outfit"
				GameSettings.set_v(k2, int(d["value"]))
				rebuild_rig()
				toast.emit("Vestiu: " + nm)
				_act_cd = 0.4
				return
			"bow":
				var arrow := Items.find("Flecha")
				if creative() or inv.remove(arrow, 1):
					if mobs != null:
						mobs.shoot(origin + fwd * 0.6, origin + fwd * 50.0, true, float(d["dmg"]) * stats.ranged_mult(), 34.0)
					_wear_held()
				else:
					toast.emit("Sem flechas.")
				_act_cd = d["cd"]
				_swing = 1.0
				rig.attack()
				return
			"igniter":
				if not target.is_empty():
					if world.try_ignite(tp, target["normal"]):
						toast.emit("O portal se abriu!")
						_wear_held()
					else:
						var above := tp + Vector3i(target["normal"])
						if world.get_block(above.x, above.y, above.z) == 0 and Blocks.SOLID[tid] == 1:
							world.set_block(above, Blocks.CAMPFIRE)
							_wear_held()
				_act_cd = 0.4
				return
			"bucket":
				var fl: int = d["fluid"]
				if fl == 0:
					var fp: Variant = world.raycast_fluid(origin, fwd, REACH)
					if fp != null:
						var fpp: Vector3i = fp
						var fid := world.get_block(fpp.x, fpp.y, fpp.z)
						world.set_block(fpp, Blocks.AIR)
						if not creative():
							inv.set_slot(slot, Items.find("Balde de água" if Blocks.FLUID[fid] == 1 else "Balde de lava"), 1)
						if sfx != null:
							sfx.play("splash", -6.0, 1.2)
				elif not target.is_empty():
					var pp: Vector3i = tp + Vector3i(target["normal"])
					if Blocks.KIND[tid] == Blocks.K_PLANT:
						pp = tp
					var cur := world.get_block(pp.x, pp.y, pp.z)
					if cur == 0 or Blocks.KIND[cur] == Blocks.K_PLANT or (Blocks.FLUID[cur] != 0 and not Blocks.is_source(cur)):
						world.set_block(pp, Blocks.WATER if fl == 1 else Blocks.LAVA)
						if not creative():
							inv.set_slot(slot, Items.find("Balde"), 1)
						if sfx != null:
							sfx.play("splash", -6.0, 0.9)
				_act_cd = 0.3
				_use_t = 1.0
				return
			"boat":
				if not target.is_empty() and mobs != null:
					var bp := Vector3(tp) + Vector3(0.5, 1.0, 0.5)
					mobs.place_boat(int(d["wood"]), bp, yaw)
					_consume_held()
				_act_cd = 0.4
				return
			"tool":
				if nm.begins_with("Enxada") and (tid == Blocks.DIRT or tid == Blocks.GRASS or tid == Blocks.PATH):
					if world.get_block(tp.x, tp.y + 1, tp.z) == 0 or Blocks.KIND[world.get_block(tp.x, tp.y + 1, tp.z)] == Blocks.K_PLANT:
						world.set_block(tp + Vector3i(0, 1, 0), 0)
						world.set_block(tp, Blocks.FARMLAND)
						_wear_held()
						_swing = 1.0
						if sfx != null:
							sfx.play("step", -4.0, 0.8)
				_act_cd = 0.25
				return
			"misc":
				if nm == "Farinha de osso" and not target.is_empty():
					if _bonemeal(tp, tid):
						_consume_held()
					_act_cd = 0.3
					return
		return
	_place_block()


func _try_plant(crop: int) -> bool:
	if target.is_empty():
		return false
	var tp: Vector3i = target["pos"]
	if target["id"] != Blocks.FARMLAND or world.get_block(tp.x, tp.y + 1, tp.z) != 0:
		return false
	world.set_block(tp + Vector3i(0, 1, 0), crop)
	_consume_held()
	_act_cd = 0.2
	_swing = 1.0
	if sfx != null:
		sfx.play("place", -8.0, 1.4)
	return true


func _bonemeal(p: Vector3i, id: int) -> bool:
	if Blocks.is_crop(id):
		return world.advance_crop(p, 2)
	if id >= Blocks.SAPLING_0 and id < Blocks.SAPLING_0 + 6:
		world.grow_tree(p, id - Blocks.SAPLING_0)
		return true
	if id == Blocks.BERRY_BUSH_EMPTY:
		world.set_block(p, Blocks.BERRY_BUSH)
		return true
	if id == Blocks.GRASS:
		for i in 10:
			var q := p + Vector3i(_brng.randi_range(-3, 3), 1, _brng.randi_range(-3, 3))
			if world.get_block(q.x, q.y - 1, q.z) == Blocks.GRASS and world.get_block(q.x, q.y, q.z) == 0:
				world.set_block(q, [Blocks.TALL_GRASS, Blocks.TALL_GRASS, Blocks.FLOWER_RED, Blocks.FLOWER_YELLOW, Blocks.FLOWER_BLUE][_brng.randi() % 5])
		return true
	return false


func _toggle_door(p: Vector3i) -> void:
	var id := world.get_block(p.x, p.y, p.z)
	if id == Blocks.DOORV or id == Blocks.DOORV_OPEN:
		for q: Vector3i in door_cells(p):
			var qid := world.get_block(q.x, q.y, q.z)
			world.set_block(q, Blocks.door_toggle(qid), world.get_shape(q.x, q.y, q.z))
		if sfx != null:
			sfx.play("place", -6.0, 0.7)
		return
	var nid := Blocks.door_toggle(id)
	var sh := world.get_shape(p.x, p.y, p.z)
	for dy in [-1, 0, 1]:
		var q := p + Vector3i(0, dy, 0)
		if world.get_block(q.x, q.y, q.z) == id:
			world.set_block(q, nid, sh)
	if sfx != null:
		sfx.play("place", -6.0, 0.7)


func _break_block() -> void:
	if target.is_empty():
		return
	var p: Vector3i = target["pos"]
	var id: int = target["id"]
	var ok := tool_ok(id)
	if id == Blocks.BED or id == Blocks.BED_FOOT:
		# A cama sai inteira (cabeceira + pes) e devolve uma cama.
		var br := (world.get_shape(p.x, p.y, p.z) >> 4) & 3
		var hd := Blocks.bed_head_dir(br)
		var other := p + (Vector3i(hd.x, 0, hd.y) if id == Blocks.BED_FOOT else Vector3i(-hd.x, 0, -hd.y))
		var oid := world.get_block(other.x, other.y, other.z)
		if oid == Blocks.BED or oid == Blocks.BED_FOOT:
			world.set_block(other, Blocks.AIR)
		world.set_block(p, Blocks.AIR)
		if not creative() and mobs != null:
			mobs.drop(Blocks.BED, Vector3(p) + Vector3(0.5, 0.5, 0.5))
		_swing = 1.0
		rig.attack()
		_particles(Vector3(p) + Vector3(0.5, 0.5, 0.5), Blocks.BED)
		if sfx != null:
			sfx.play("thud", -5.0)
		return
	if id == Blocks.DOORV or id == Blocks.DOORV_OPEN or id == Blocks.WINDOWV or id == Blocks.PANEV \
			or id == Blocks.DRAWBRIDGE or id == Blocks.DRAWBRIDGE_DOWN:
		_break_variant(p, id)
		return
	if (int(target.get("shape", 0)) & 15) == Blocks.SH_MICRO:
		var g: Variant = world.get_micro(p.x, p.y, p.z)
		if world.set_block(p, Blocks.AIR) and g != null and not creative():
			var removed := {}
			for v in (g as PackedByteArray):
				if v != 0:
					removed[v] = int(removed.get(v, 0)) + 1
			_credit(removed)
		_swing = 1.0
		rig.attack()
		_particles(Vector3(p) + Vector3(0.5, 0.5, 0.5), id)
		if sfx != null:
			sfx.play("thud", -5.0)
		return
	# Bloco de construcao de vila: o construtor vai repor depois.
	var dck := Vector2i(p.x >> 4, p.z >> 4)
	var dix := p.y * 256 + (p.z & 15) * 16 + (p.x & 15)
	if id != 0 and Blocks.KIND[id] != Blocks.K_PLANT and Blocks.KIND[id] != Blocks.K_LEAVES and world.dim == 0 and not world.mods.get(dck, {}).has(dix) and world.village_damage.size() < 96 \
			and world.gen.structs.in_structure(p.x, p.z) and p.y >= world.surface_y(p.x, p.z) - 14:
		world.village_damage.append([p, id, int(target.get("shape", 0))])
	var cont: Inventory = null
	if Blocks.CHESTS.has(id):
		cont = world.remove_container(p)
	elif id == Blocks.FURNACE:
		cont = world.remove_furnace(p)
	if not world.set_block(p, Blocks.AIR):
		return
	var center := Vector3(p) + Vector3(0.5, 0.5, 0.5)
	if ok:
		gain_xp(float(ORE_XP.get(id, 0.0)))
	if LOGS.has(id):
		gain_xp(1.0)
	elif Blocks.is_crop(id) and Blocks.crop_base(id) > 0 and id - Blocks.crop_base(id) == int(Blocks.CROP_STAGES[Blocks.crop_base(id)]) - 1:
		gain_xp(1.5)
	if LOGS.has(id) and not Input.is_physical_key_pressed(KEY_SHIFT) and GameSettings.get_v("tree_felling"):
		if _fell_tree(p, id):
			_swing = 1.0
			_particles(center, id)
			return
	if not creative() and mobs != null:
		for dr: Array in Blocks.drops(id, ok, _brng):
			mobs.drop(dr[0], center, dr[1])
		if cont != null:
			for st: Array in cont.slots:
				if st[0] > 0:
					mobs.drop(st[0], center, st[1], st[2])
		if Blocks.TOOL[id] != Blocks.TOOL_NONE or Blocks.HARD[id] > 0.3:
			if _held_def().get("kind", "") == "tool":
				_wear_held()
	# Portas ocupam dois blocos; plantas caem junto com o bloco de baixo.
	if Blocks.door_toggle(id) != 0:
		for dy in [-1, 1]:
			var q := p + Vector3i(0, dy, 0)
			if world.get_block(q.x, q.y, q.z) == id:
				world.set_block(q, Blocks.AIR)
	var above := p + Vector3i(0, 1, 0)
	var ab := world.get_block(above.x, above.y, above.z)
	if Blocks.KIND[ab] == Blocks.K_PLANT:
		world.set_block(above, Blocks.AIR)
		if not creative() and mobs != null:
			for dr: Array in Blocks.drops(ab, true, _brng):
				mobs.drop(dr[0], Vector3(above) + Vector3(0.5, 0.3, 0.5), dr[1])
	_swing = 1.0
	rig.attack()
	_particles(center, id)
	if sfx != null:
		sfx.play("thud", -5.0)


## Corta a arvore inteira: os troncos ligados acima do corte e as folhas presas a eles tombam juntos.
func _fell_tree(p: Vector3i, log_id: int) -> bool:
	var logs: Array[Vector3i] = []
	var seen := {p: true}
	var queue: Array[Vector3i] = []
	for dy in [0, 1]:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var q := p + Vector3i(dx, dy, dz)
				if q != p and q.y >= p.y and world.get_block(q.x, q.y, q.z) == log_id:
					seen[q] = true
					queue.append(q)
	while not queue.is_empty() and logs.size() < 200:
		var c: Vector3i = queue.pop_front()
		logs.append(c)
		for dy in [0, 1]:
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var q := c + Vector3i(dx, dy, dz)
					if seen.has(q) or q.y < p.y:
						continue
					seen[q] = true
					if world.get_block(q.x, q.y, q.z) == log_id:
						queue.append(q)
	# Folhas a ate 4 blocos dos troncos, ligadas por folhas.
	var leaves: Array[Vector3i] = []
	var lq: Array = []
	var lseen := {}
	var trunk := logs.duplicate()
	trunk.append(p)
	for c: Vector3i in trunk:
		lq.append([c, 0])
	while not lq.is_empty() and leaves.size() < 500:
		var e: Array = lq.pop_front()
		var c: Vector3i = e[0]
		var dist: int = e[1]
		for dv: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var q := c + dv
			if lseen.has(q) or q.y < p.y:
				continue
			lseen[q] = true
			var bid := world.get_block(q.x, q.y, q.z)
			if Blocks.KIND[bid] == Blocks.K_LEAVES or (bid == Blocks.CRYSTAL_BLOCK and log_id == Blocks.ETHER_LOG):
				leaves.append(q)
				if dist < 4:
					lq.append([q, dist + 1])
	if logs.is_empty() or leaves.size() < 4:
		return false
	var blocks: Array = [[p, log_id]]
	for c in logs:
		blocks.append([c, log_id])
	for c in leaves:
		blocks.append([c, world.get_block(c.x, c.y, c.z)])
	for b: Array in blocks:
		if b[0] != p:
			world.set_block(b[0], Blocks.AIR)
	# Tomba para longe de quem cortou.
	var dir := Vector3(p) + Vector3(0.5, 0, 0.5) - position
	var tree := FallingTree.new()
	get_parent().add_child(tree)
	tree.setup(blocks, Vector3(p) + Vector3(0.5, 0.0, 0.5), dir, item_mesh_block)
	var was_creative := creative()
	tree.landed.connect(func(fallen: Array) -> void: _tree_landed(fallen, was_creative))
	if not was_creative:
		_wear_held(maxi(1, logs.size() / 3))
	if sfx != null:
		sfx.play("thud", 0.0, 0.5)
	return true


func _tree_landed(fallen: Array, was_creative: bool) -> void:
	if sfx != null:
		sfx.play("thud", 2.0, 0.4)
		sfx.play("splash", -10.0, 0.6)
	# Soma tudo o que a arvore solta e larga em pilhas espalhadas pela copa caida.
	var totals := {}
	var where := {}
	var n_leaves := 0
	var stick := Items.find("Graveto")
	for i in fallen.size():
		var e: Array = fallen[i]
		var pos: Vector3 = e[0]
		var id: int = e[1]
		if i % 3 == 0:
			_particles(pos, id)
		if was_creative or mobs == null:
			continue
		var got: Array = []
		if LOGS.has(id):
			got.append([id, 1])
		elif Blocks.KIND[id] == Blocks.K_LEAVES:
			n_leaves += 1
			# Uma folhagem a cada duas, gravetos e frutos (macieira, laranjeira, cerejeira...).
			if n_leaves % 2 == 0:
				got.append([id, 1])
			if _brng.randf() < 0.35:
				got.append([stick, 1])
			got.append_array(Blocks.drops(id, true, _brng))
		else:
			got.append_array(Blocks.drops(id, true, _brng))
		for g: Array in got:
			var gid: int = g[0]
			if gid <= 0:
				continue
			totals[gid] = int(totals.get(gid, 0)) + int(g[1])
			if not where.has(gid):
				where[gid] = []
			(where[gid] as Array).append(pos)
	if mobs == null or was_creative:
		return
	if n_leaves > 0:
		totals[stick] = maxi(int(totals.get(stick, 0)), 2)
		if not where.has(stick):
			where[stick] = [fallen[fallen.size() - 1][0]]
	for gid: int in totals:
		var n: int = totals[gid]
		var spots: Array = where[gid]
		var piles := clampi(ceili(n / 8.0), 1, 6)
		for k in piles:
			var cnt := n / piles + (1 if k < n % piles else 0)
			if cnt > 0:
				mobs.drop(gid, spots[(k * spots.size()) / piles] + Vector3(0, 0.3, 0), cnt)


## Malha de bloco inteiro (sem forma da barra), usada pela arvore que cai.
func item_mesh_block(id: int) -> ArrayMesh:
	var key := id | (0xFF << 8)
	if not _item_cache.has(key):
		var d := ChunkMesher.build_item(id, 0)
		var mesh: ArrayMesh = d["mesh"]
		var kinds: PackedInt32Array = d["kinds"]
		for s in kinds.size():
			mesh.surface_set_material(s, mats_item[kinds[s]])
		_item_cache[key] = mesh
	return _item_cache[key]


func _place_block() -> void:
	if target.is_empty():
		return
	var id := held_id()
	if id == 0 or Items.is_item(id):
		return
	if micro_scale > 0 and Micro.can_micro(id):
		_place_micro(id)
		return
	var n: Vector3i = target["normal"]
	if n == Vector3i.ZERO:
		return
	var tp: Vector3i = target["pos"]
	var p := tp + n
	if Blocks.KIND[target["id"]] == Blocks.K_PLANT:
		p = tp
	var cur := world.get_block(p.x, p.y, p.z)
	if cur != Blocks.AIR and Blocks.FLUID[cur] == 0 and Blocks.KIND[cur] != Blocks.K_PLANT:
		return
	if Blocks.KIND[id] == Blocks.K_PLANT:
		var below := world.get_block(p.x, p.y - 1, p.z)
		if Blocks.KIND[below] != Blocks.K_CUBE:
			return
	var sh := current_shape() if Blocks.can_shape(id) else 0
	var point: Vector3 = target["point"]
	var f := -cam.global_transform.basis.z
	var rot := 0
	if absf(f.x) > absf(f.z):
		rot = 3 if f.x > 0.0 else 1
	else:
		rot = 0 if f.z > 0.0 else 2
	var is_door := id == Blocks.DOOR or id == Blocks.DOOR_IRON
	if Blocks.PANE[id] == 1 or is_door:
		# Lamina/porta fina: encosta no lado mais proximo do ponto clicado, ou fica no centro.
		var pl := thin_placement(p)
		if Blocks.PANE[id] == 1:
			sh = (Blocks.SH_PANE if pl[0] else Blocks.SH_PANE_EDGE) | (int(pl[1]) << 4)
		else:
			sh = (int(pl[1]) << 4) | (Blocks.SH_CENTER if pl[0] else 0)
	elif Blocks.KIND[id] == Blocks.K_MODEL:
		sh = rot << 4
	elif sh == Blocks.SH_SLAB:
		var fy := point.y - floorf(point.y)
		if n.y < 0 or (n.y == 0 and fy > 0.5):
			sh = Blocks.SH_SLAB_TOP
	elif sh == Blocks.SH_STAIRS or sh == Blocks.SH_WEDGE or sh == Blocks.SH_WALL or sh == Blocks.SH_PANE:
		sh |= rot << 4
	if Blocks.SOLID[id] == 1:
		var pb := _aabb(position)
		for b: AABB in Blocks.boxes(id, sh):
			if pb.intersects(AABB(b.position + Vector3(p), b.size)):
				return
	# Cama: os pes ficam no bloco clicado e a cabeceira no seguinte, longe do jogador.
	if id == Blocks.BED:
		var hd := Blocks.bed_head_dir(rot)
		var hp3 := p + Vector3i(hd.x, 0, hd.y)
		if not _free_cell(world.get_block(hp3.x, hp3.y, hp3.z)):
			return
		if not world.set_block(hp3, Blocks.BED, sh):
			return
		world.set_block(p, Blocks.BED_FOOT, sh)
		_consume_held()
		_act_cd = 0.2
		_use_t = 1.0
		rig.attack()
		if sfx != null:
			sfx.play("place", -4.0)
		return
	# Porta: ocupa o bloco de cima tambem.
	if id == Blocks.DOOR or id == Blocks.DOOR_IRON:
		var up := p + Vector3i(0, 1, 0)
		if world.get_block(up.x, up.y, up.z) != 0:
			return
		world.set_block(up, id, sh)
	if not world.set_block(p, id, sh):
		return
	_consume_held()
	_act_cd = 0.2
	_use_t = 1.0
	rig.attack()
	if sfx != null:
		sfx.play("place", -4.0)


const SIDES: Array[Vector3i] = [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0)]


static func _free_cell(id: int) -> bool:
	return id == Blocks.AIR or Blocks.FLUID[id] != 0 or Blocks.KIND[id] == Blocks.K_PLANT


## Celulas de uma porta com variante (simples, dupla ou grande): vizinhas com a mesma variante e orientacao.
func door_cells(p: Vector3i) -> Array[Vector3i]:
	var sh := world.get_shape(p.x, p.y, p.z)
	var key := sh & ~Blocks.SH_MIRROR
	var out: Array[Vector3i] = []
	var seen := {p: true}
	var q: Array[Vector3i] = [p]
	while not q.is_empty() and out.size() < 8:
		var c: Vector3i = q.pop_back()
		out.append(c)
		for d: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var n := c + d
			if seen.has(n):
				continue
			seen[n] = true
			var nid := world.get_block(n.x, n.y, n.z)
			if (nid == Blocks.DOORV or nid == Blocks.DOORV_OPEN) and (world.get_shape(n.x, n.y, n.z) & ~Blocks.SH_MIRROR) == key:
				q.append(n)
	return out


## Coloca porta simples (1x2), dupla (2x2) ou portao grande (2x4) encostada no lado escolhido pelo clique.
func _place_door_item(d: Dictionary) -> void:
	if target.is_empty():
		return
	var n: Vector3i = target["normal"]
	var tp: Vector3i = target["pos"]
	var p := tp if Blocks.KIND[target["id"]] == Blocks.K_PLANT else tp + n
	if n.y < 0:
		p.y -= int(d["h"]) - 1
	var pl := thin_placement(p)
	var r: int = pl[1]
	var right := SIDES[(r + 1) % 4]
	var w: int = d["w"]
	var h: int = d["h"]
	var bb := _aabb(position)
	for i in w:
		for j in h:
			var c := p + right * i + Vector3i(0, j, 0)
			if not _free_cell(world.get_block(c.x, c.y, c.z)) or bb.intersects(AABB(Vector3(c), Vector3.ONE)):
				toast.emit("Sem espaço para a porta.")
				return
	var base := (r << 4) | (Blocks.SH_CENTER if pl[0] else 0) | (int(d["variant"]) << 8)
	for i in w:
		var sh := base | (Blocks.SH_MIRROR if w == 2 and i == 1 else 0)
		for j in h:
			world.set_block(p + right * i + Vector3i(0, j, 0), Blocks.DOORV, sh)
	_consume_held()
	_act_cd = 0.25
	_use_t = 1.0
	rig.attack()
	if sfx != null:
		sfx.play("place", -4.0)


## Janela (bloco inteiro) ou vidraca (lamina fina) com variante.
func _place_window_item(d: Dictionary) -> void:
	if target.is_empty():
		return
	var n: Vector3i = target["normal"]
	var tp: Vector3i = target["pos"]
	var p := tp if Blocks.KIND[target["id"]] == Blocks.K_PLANT else tp + n
	if not _free_cell(world.get_block(p.x, p.y, p.z)):
		return
	var block: int = d["block"]
	var sh := int(d["variant"]) << 8
	if block == Blocks.PANEV:
		var pl := thin_placement(p)
		sh |= (Blocks.SH_PANE if pl[0] else Blocks.SH_PANE_EDGE) | (int(pl[1]) << 4)
	else:
		if _aabb(position).intersects(AABB(Vector3(p), Vector3.ONE)):
			return
	if world.set_block(p, block, sh):
		_consume_held()
		_act_cd = 0.2
		_use_t = 1.0
		rig.attack()
		if sfx != null:
			sfx.play("place", -4.0)


## Quebra porta/janela/vidraca/ponte inteira e devolve o item.
func _break_variant(p: Vector3i, id: int) -> void:
	var sh := world.get_shape(p.x, p.y, p.z)
	var v := Blocks.variant(sh)
	var item := 0
	var cells: Array[Vector3i] = [p]
	if id == Blocks.DOORV or id == Blocks.DOORV_OPEN:
		cells = door_cells(p)
		var xs := {}
		var ys := {}
		for c: Vector3i in cells:
			xs[Vector2i(c.x, c.z)] = true
			ys[c.y] = true
		item = Items.for_variant("door", 0, v, xs.size(), ys.size())
	elif id == Blocks.WINDOWV or id == Blocks.PANEV:
		item = Items.for_variant("window", id, v)
	else:
		cells = drawbridge_cells(p)
		item = Items.find("Ponte levadiça")
	for c: Vector3i in cells:
		world.set_block(c, Blocks.AIR)
	if not creative() and mobs != null and item > 0:
		mobs.drop(item, Vector3(p) + Vector3(0.5, 0.5, 0.5))
	_swing = 1.0
	rig.attack()
	_particles(Vector3(p) + Vector3(0.5, 0.5, 0.5), id)
	if sfx != null:
		sfx.play("thud", -5.0)


# ---------------------------------------------------------------- ponte levadica (4 de largura x 8 de altura)

const BRIDGE_W := 4
const BRIDGE_H := 8


## Origem (base esquerda da coluna junto a dobradica) e rotacao a partir de uma celula da ponte.
func _bridge_origin(p: Vector3i) -> Array:
	var id := world.get_block(p.x, p.y, p.z)
	var sh := world.get_shape(p.x, p.y, p.z)
	var r := (sh >> 4) & 3
	var px := (sh >> 16) & 3
	var py := (sh >> 18) & 7
	var outv := SIDES[r]
	var right := SIDES[(r + 1) % 4]
	var o: Vector3i
	if id == Blocks.DRAWBRIDGE:
		o = p - right * px - Vector3i(0, py, 0)
	else:
		o = p - right * px - outv * (py + 1)
	return [o, r, id == Blocks.DRAWBRIDGE_DOWN]


func _bridge_cells_at(o: Vector3i, r: int, down: bool) -> Array[Vector3i]:
	var outv := SIDES[r]
	var right := SIDES[(r + 1) % 4]
	var out: Array[Vector3i] = []
	for px in BRIDGE_W:
		for py in BRIDGE_H:
			out.append(o + right * px + (outv * (py + 1) if down else Vector3i(0, py, 0)))
	return out


func drawbridge_cells(p: Vector3i) -> Array[Vector3i]:
	var info := _bridge_origin(p)
	var out: Array[Vector3i] = []
	for c: Vector3i in _bridge_cells_at(info[0], info[1], info[2]):
		var cid := world.get_block(c.x, c.y, c.z)
		if cid == Blocks.DRAWBRIDGE or cid == Blocks.DRAWBRIDGE_DOWN:
			out.append(c)
	return out


func _place_bridge_blocks(o: Vector3i, r: int, down: bool) -> void:
	var outv := SIDES[r]
	var right := SIDES[(r + 1) % 4]
	for px in BRIDGE_W:
		for py in BRIDGE_H:
			var c := o + right * px + (outv * (py + 1) if down else Vector3i(0, py, 0))
			world.set_block(c, Blocks.DRAWBRIDGE_DOWN if down else Blocks.DRAWBRIDGE, (r << 4) | (px << 16) | (py << 18))


## Coloca a ponte de pe; ela abaixa para o lado de onde o jogador olha.
func _place_drawbridge() -> void:
	if target.is_empty():
		return
	var n: Vector3i = target["normal"]
	var tp: Vector3i = target["pos"]
	var p := tp + n
	var f := -cam.global_transform.basis.z
	var toward := Vector3i(-signi(int(signf(f.x))), 0, 0) if absf(f.x) > absf(f.z) else Vector3i(0, 0, -int(signf(f.z)))
	var r := _side_rot(toward)
	# Centraliza a ponte no ponto clicado.
	var right := SIDES[(r + 1) % 4]
	var o := p - right * 1
	var bb := _aabb(position)
	for c: Vector3i in _bridge_cells_at(o, r, false):
		if not _free_cell(world.get_block(c.x, c.y, c.z)) or bb.intersects(AABB(Vector3(c), Vector3.ONE)):
			toast.emit("A ponte levadiça precisa de 4 x 8 blocos livres.")
			return
	_place_bridge_blocks(o, r, false)
	_consume_held()
	_act_cd = 0.4
	if sfx != null:
		sfx.play("place", -2.0, 0.6)


## Abaixa ou levanta a ponte com animacao de giro na dobradica.
func toggle_drawbridge(p: Vector3i) -> void:
	var info := _bridge_origin(p)
	var o: Vector3i = info[0]
	var r: int = info[1]
	var down: bool = info[2]
	for c: Vector3i in _bridge_cells_at(o, r, not down):
		var cid := world.get_block(c.x, c.y, c.z)
		if not _free_cell(cid) and cid != Blocks.DRAWBRIDGE and cid != Blocks.DRAWBRIDGE_DOWN:
			toast.emit("Algo bloqueia o caminho da ponte.")
			return
	for c: Vector3i in drawbridge_cells(p):
		world.set_block(c, Blocks.AIR)
	var outv := Vector3(SIDES[r])
	var right := Vector3(SIDES[(r + 1) % 4])
	var up := Vector3.UP
	# Dobradica: aresta de baixo da face externa da coluna de origem.
	var pivot := Node3D.new()
	pivot.position = Vector3(o) + Vector3(0.5, 0.0, 0.5) + outv * 0.5 - right * 0.5
	get_parent().add_child(pivot)
	var plate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(BRIDGE_W, BRIDGE_H, 0.25)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.40, 0.26, 0.14)
	mat.roughness = 0.85
	bm.material = mat
	plate.mesh = bm
	plate.transform = Transform3D(Basis(right, up, outv), right * BRIDGE_W * 0.5 + up * BRIDGE_H * 0.5 - outv * 0.125)
	pivot.add_child(plate)
	var im := StandardMaterial3D.new()
	im.albedo_color = Color(0.36, 0.37, 0.40)
	im.metallic = 0.9
	im.roughness = 0.4
	for k in 3:
		var band := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(BRIDGE_W + 0.02, 0.2, 0.28)
		b.material = im
		band.mesh = b
		band.transform = Transform3D(Basis(right, up, outv), right * BRIDGE_W * 0.5 + up * (1.2 + k * 2.8) - outv * 0.125)
		pivot.add_child(band)
	var axis := up.cross(outv).normalized()
	var a0 := 0.0 if not down else PI * 0.5
	var a1 := PI * 0.5 if not down else 0.0
	pivot.basis = Basis(axis, a0)
	var tw := pivot.create_tween()
	tw.tween_method(func(a: float) -> void: pivot.basis = Basis(axis, a), a0, a1, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if not down else Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_place_bridge_blocks(o, r, not down)
		pivot.queue_free()
		if sfx != null:
			sfx.play("thud", 0.0, 0.5))
	if sfx != null:
		sfx.play("place", -3.0, 0.5)


## Ordenhar vacas (balde vazio) e tosquiar ovelhas (tesoura). Devolve true se fez algo.
func _animal_use(m: Variant) -> bool:
	var d := _held_def()
	if d.is_empty():
		return false
	if m.kind == "vaca" and d.get("kind", "") == "bucket" and int(d.get("fluid", -1)) == 0:
		if m.milk_t > 0.0:
			toast.emit("Esta vaca já foi ordenhada. Volte mais tarde.")
			return true
		m.milk_t = 120.0
		var milk := Items.find("Balde de leite")
		if creative():
			pickup(milk, 1)
		else:
			inv.set_slot(slot, milk, 1)
		toast.emit("Você tirou leite da vaca.")
		if sfx != null:
			sfx.play("splash", -8.0, 1.5)
		return true
	if m.kind == "ovelha" and d.get("kind", "") == "shears":
		if m.sheared:
			toast.emit("A lã desta ovelha ainda não cresceu.")
			return true
		m.set_sheared(true)
		if mobs != null:
			for k in _brng.randi_range(1, 3):
				mobs.drop(mobs.wool_of(m), m.position + Vector3(0, 0.9, 0))
		_wear_held()
		if sfx != null:
			sfx.play("place", -6.0, 1.8)
		return true
	return false


## Montarias: sela na mao coloca a sela; Shift com a mao vazia tira; com sela, monta.
func _interact_mount(m: Variant, sneak: bool) -> void:
	var d := _held_def()
	if not d.is_empty() and d.get("kind", "") == "saddle":
		if m.saddle > 0:
			toast.emit("Esta montaria já tem sela.")
			return
		m.set_saddle(held_id())
		_consume_held()
		toast.emit("Sela colocada: " + Items.name_of(m.saddle))
		if sfx != null:
			sfx.play("place", -4.0, 0.8)
		return
	if sneak and m.saddle > 0 and held_id() == 0:
		var it: int = m.saddle
		m.set_saddle(0)
		if pickup(it) > 0 and mobs != null:
			mobs.drop(it, m.position + Vector3(0, 1, 0))
		return
	if m.saddle <= 0:
		toast.emit("Precisa de uma sela para montar (%s)." % Rigs.variant_name(m.kind, m.variant))
		return
	vehicle = m
	m.rider = self
	m.goal = Vector3.INF
	toast.emit("Montado: WASD cavalga, Ctrl galopa, Espaço pula, Shift desce.")
	if sfx != null:
		sfx.play("step", -2.0, 0.7)


## Lado -Z/+X/+Z/-X -> rotacao das formas finas (0..3).
static func _side_rot(d: Vector3i) -> int:
	if d.x > 0: return 1
	if d.z > 0: return 2
	if d.x < 0: return 3
	return 0


## Onde fica uma lamina/porta colocada na celula p: [centralizada, rotacao].
## No meio da face clicada fica no centro; perto de uma borda encosta naquele lado;
## numa parede, fora do centro e das bordas laterais, encosta no bloco clicado.
func thin_placement(p: Vector3i) -> Array:
	var n: Vector3i = target["normal"]
	var pt: Vector3 = target["point"]
	var lp := pt - Vector3(p)
	var f := -cam.global_transform.basis.z
	if n.y != 0:
		var a := lp.x
		var b := lp.z
		if absf(a - 0.5) < 0.2 and absf(b - 0.5) < 0.2:
			return [true, 1 if absf(f.x) > absf(f.z) else 0]
		var best := a
		var dir := Vector3i(-1, 0, 0)
		if 1.0 - a < best:
			best = 1.0 - a
			dir = Vector3i(1, 0, 0)
		if b < best:
			best = b
			dir = Vector3i(0, 0, -1)
		if 1.0 - b < best:
			dir = Vector3i(0, 0, 1)
		return [false, _side_rot(dir)]
	var along_x := n.z != 0
	var lu := lp.x if along_x else lp.z
	var lv := lp.y
	if absf(lu - 0.5) < 0.2 and absf(lv - 0.5) < 0.2:
		return [true, 0 if n.z != 0 else 1]
	if minf(lu, 1.0 - lu) < 0.25:
		var side := 1 if lu > 0.5 else -1
		return [false, _side_rot(Vector3i(side, 0, 0) if along_x else Vector3i(0, 0, side))]
	return [false, _side_rot(-n)]


## Selecao na escala atual: [celula, voxel alinhado, lado em voxels].
## outside = false: o pedaco dentro do bloco mirado (esculpir); true: o espaco encostado na face (construir).
func micro_target(outside: bool) -> Array:
	if micro_scale == 0 or target.is_empty():
		return []
	var n := Vector3(target["normal"])
	var pt: Vector3 = target["point"]
	pt += n * (0.004 if outside else -0.004)
	var cell := Vector3i(floori(pt.x), floori(pt.y), floori(pt.z))
	if not outside:
		var id: int = target["id"]
		var is_m := (int(target.get("shape", 0)) & 15) == Blocks.SH_MICRO
		if not is_m and (int(target.get("shape", 0)) != 0 or not Micro.can_micro(id)):
			return []
		if is_m:
			cell = target["pos"]
	var s: int = Micro.SCALES[micro_scale]
	var lp := (pt - Vector3(cell)) * 8.0
	var v := Vector3i(clampi(floori(lp.x), 0, 7), clampi(floori(lp.y), 0, 7), clampi(floori(lp.z), 0, 7))
	if not outside and target.has("micro"):
		v = target["micro"]
	v = Vector3i((v.x / s) * s, (v.y / s) * s, (v.z / s) * s)
	return [cell, v, s]


func _credit(removed: Dictionary) -> void:
	for m: int in removed:
		var dr: Array = Blocks.drops(m, tool_ok(m), _brng)
		if dr.is_empty():
			continue
		var out: int = dr[0][0]
		micro_credit[out] = int(micro_credit.get(out, 0)) + int(removed[m])
		while int(micro_credit[out]) >= Micro.SIZE:
			micro_credit[out] = int(micro_credit[out]) - Micro.SIZE
			if pickup(out, 1) > 0 and mobs != null:
				mobs.drop(out, position + Vector3(0, 1, 0))


## Remove um cubo de 1/2, 1/4 ou 1/8 do bloco mirado.
func _carve() -> void:
	var ms := micro_target(false)
	if ms.is_empty():
		return
	var p: Vector3i = ms[0]
	var v: Vector3i = ms[1]
	var sz: int = ms[2]
	var g: Variant = world.get_micro(p.x, p.y, p.z)
	var id := world.get_block(p.x, p.y, p.z)
	var grid: PackedByteArray
	if g != null:
		grid = (g as PackedByteArray).duplicate()
	elif Micro.can_micro(id):
		grid = Micro.filled(id)
	else:
		return
	var removed := {}
	if Micro.fill_cube(grid, v.x, v.y, v.z, sz, 0, removed) == 0:
		return
	world.set_micro(p, grid)
	if not creative():
		_credit(removed)
		if _held_def().get("kind", "") == "tool":
			_wear_held()
	_swing = 1.0
	rig.attack()
	var c := Vector3(p) + (Vector3(v) + Vector3.ONE * sz * 0.5) * Micro.INV
	_chips(c, int(removed.keys()[0]) if not removed.is_empty() else id)
	if sfx != null:
		sfx.play("thud", -9.0, 1.0 + (8 - sz) * 0.08)


## Coloca um cubo de 1/2, 1/4 ou 1/8 do bloco na mao, encostado na face mirada.
func _place_micro(id: int) -> void:
	var ms := micro_target(true)
	if ms.is_empty():
		return
	var p: Vector3i = ms[0]
	var v: Vector3i = ms[1]
	var sz: int = ms[2]
	var cur := world.get_block(p.x, p.y, p.z)
	var grid: PackedByteArray
	if cur == Blocks.MICRO:
		var g: Variant = world.get_micro(p.x, p.y, p.z)
		if g == null:
			return
		grid = (g as PackedByteArray).duplicate()
	elif cur == Blocks.AIR or Blocks.FLUID[cur] != 0 or Blocks.KIND[cur] == Blocks.K_PLANT:
		grid = Micro.empty()
	else:
		return
	var box := AABB(Vector3(p) + Vector3(v) * Micro.INV, Vector3.ONE * sz * Micro.INV)
	if Blocks.SOLID[id] == 1 and _aabb(position).intersects(box):
		return
	var need := 0
	for y in range(v.y, v.y + sz):
		for z in range(v.z, v.z + sz):
			for x in range(v.x, v.x + sz):
				if grid[Micro.i3(x, y, z)] == 0:
					need += 1
	if need == 0:
		return
	if not creative():
		while int(micro_credit.get(id, 0)) < need:
			if not inv.remove(id, 1):
				toast.emit("Sem material: " + Blocks.NAMES[id])
				return
			micro_credit[id] = int(micro_credit.get(id, 0)) + Micro.SIZE
		micro_credit[id] = int(micro_credit[id]) - need
	Micro.fill_cube(grid, v.x, v.y, v.z, sz, id, {})
	world.set_micro(p, grid)
	_act_cd = 0.12
	_use_t = 1.0
	rig.attack()
	if sfx != null:
		sfx.play("place", -6.0, 1.0 + (8 - sz) * 0.1)


func _particles(at: Vector3, id: int) -> void:
	var layer := Blocks.FACE_LAYER[id * 6]
	var col := avg_colors[layer] if layer < avg_colors.size() else Color.GRAY
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 18
	p.lifetime = 0.7
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.35, 0.35, 0.35)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	bm.material = mat
	p.mesh = bm
	p.position = at
	p.top_level = true
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
