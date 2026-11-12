class_name Mobs
extends Node3D
## Criaturas: nascimento por bioma e hora, IA (passear, fugir, perseguir, atacar, atirar),
## fisica voxel simples, combate, flechas e itens que caem ao morrer.

## hp, velocidade, hostil, meia-largura, altura, dano, alcance, especial, drops [[nome, min, max]]
const DEFS := {
	"vaca": {"hp": 10, "speed": 1.3, "hostile": false, "w": 0.45, "h": 1.35, "drops": [["Carne crua", 1, 3], ["Couro", 0, 2]]},
	"porco": {"hp": 10, "speed": 1.4, "hostile": false, "w": 0.4, "h": 0.9, "drops": [["Carne crua", 1, 3]]},
	"ovelha": {"hp": 8, "speed": 1.3, "hostile": false, "w": 0.4, "h": 1.25, "drops": [["Carne crua", 1, 2]], "block_drop": Blocks.WOOL_0},
	"galinha": {"hp": 4, "speed": 1.6, "hostile": false, "w": 0.25, "h": 0.7, "drops": [["Pena", 0, 2], ["Carne crua", 1, 1]]},
	"coelho": {"hp": 3, "speed": 3.4, "hostile": false, "w": 0.22, "h": 0.5, "drops": [["Carne crua", 0, 1]], "skittish": true},
	"cervo": {"hp": 10, "speed": 3.0, "hostile": false, "w": 0.4, "h": 1.6, "drops": [["Carne crua", 1, 3], ["Couro", 0, 1]], "skittish": true},
	"lobo": {"hp": 12, "speed": 3.2, "hostile": false, "neutral": true, "w": 0.35, "h": 0.95, "dmg": 3.0, "reach": 1.4, "drops": [["Osso", 0, 1]]},
	"andarilho": {"hp": 20, "burns": true, "speed": 2.0, "hostile": true, "undead": true, "w": 0.32, "h": 1.8, "dmg": 3.0, "reach": 1.5, "drops": [["Carne crua", 0, 1]]},
	"esqueleto": {"hp": 16, "burns": true, "speed": 2.1, "hostile": true, "undead": true, "w": 0.3, "h": 1.8, "dmg": 3.0, "reach": 14.0, "ranged": true,
		"drops": [["Osso", 1, 2], ["Flecha", 0, 2]]},
	"aranha": {"hp": 14, "burns": true, "speed": 3.0, "hostile": true, "w": 0.6, "h": 0.8, "dmg": 2.0, "reach": 1.6, "drops": [["Couro", 0, 1]]},
	"gosma": {"hp": 12, "burns": true, "speed": 1.8, "hostile": true, "w": 0.4, "h": 0.75, "dmg": 2.0, "reach": 1.3, "hopper": true, "drops": [["Cristal", 0, 1]]},
	"espectro": {"hp": 14, "burns": true, "speed": 2.6, "hostile": true, "undead": true, "flyer": true, "w": 0.3, "h": 1.7, "dmg": 3.0, "reach": 1.5, "drops": [["Pena", 1, 2]]},
	"golem": {"hp": 40, "speed": 1.2, "hostile": true, "w": 0.5, "h": 2.6, "dmg": 7.0, "reach": 2.0, "drops": [["Lingote de ferro", 1, 3], ["Rubi", 0, 1]]},
	"aldeao": {"hp": 20, "speed": 1.3, "hostile": false, "npc": true, "w": 0.3, "h": 1.8, "drops": []},
	"bandido": {"hp": 20, "speed": 2.6, "hostile": true, "npc": true, "w": 0.3, "h": 1.8, "dmg": 4.0, "reach": 1.6,
		"drops": [["Pão", 0, 2], ["Flecha", 0, 3], ["Lingote de ferro", 0, 1]]},
	"salamandra": {"hp": 16, "speed": 2.6, "hostile": true, "fire": true, "w": 0.35, "h": 0.6, "dmg": 3.0, "reach": 1.4, "drops": [["Pó de brasa", 1, 2], ["Couro", 0, 1]]},
	"chama": {"hp": 12, "speed": 2.4, "hostile": true, "fire": true, "flyer": true, "w": 0.3, "h": 1.2, "dmg": 3.0, "reach": 16.0, "ranged": true,
		"drops": [["Pó de brasa", 1, 3]]},
	"vigia": {"hp": 24, "speed": 2.0, "hostile": true, "flyer": true, "w": 0.4, "h": 1.4, "dmg": 4.0, "reach": 18.0, "ranged": true,
		"drops": [["Cristal", 1, 2]]},
}
## Trocas por profissao: [o que o jogador da, quantidade, o que recebe, quantidade].
const TRADES := {
	"fazendeiro": ["Trigo", 6, "Pão", 3],
	"ferreiro": ["Carvão", 8, "Lingote de ferro", 1],
	"pastor": ["Trigo", 4, "lã", 2],
	"bibliotecário": ["Couro", 3, "estante", 1],
	"caçador": ["Carne crua", 3, "Flecha", 8],
	"joalheiro": ["Lingote de ouro", 2, "Cristal", 1],
}
const GREETINGS: Array[String] = ["Bom dia, viajante!", "Que ventos te trazem?", "Cuidado com as criaturas à noite.", "A colheita está boa este ano.",
	"Já viu as ilhas que flutuam? Dizem que um portal de cristal leva até lá.", "Moldura de vidro vulcânico... e uma faísca. Ouvi falar disso."]
const PASSIVE_CAP := 14
const HOSTILE_CAP := 12

var world: World
var player: Player
var weather: Weather
var sfx: Sfx
var enabled := true
var mobs: Array = []
var _rng := RandomNumberGenerator.new()
var _spawn_t := 1.0


static func move_box(w: World, pos: Vector3, motion: Vector3, hw: float, h: float) -> Array:
	# Retorna [posicao, no_chao, bateu_na_parede]. Resolve um eixo de cada vez.
	var ground := false
	var wall := false
	for axis: int in [1, 0, 2]:
		var amt: float = motion[axis]
		if amt == 0.0:
			continue
		pos[axis] += amt
		var bb := AABB(Vector3(pos.x - hw, pos.y, pos.z - hw), Vector3(hw * 2.0, h, hw * 2.0))
		for b in w.get_boxes(bb):
			if not bb.intersects(b):
				continue
			if axis == 1:
				if amt < 0.0:
					pos.y = b.end.y + 0.001
					ground = true
				else:
					pos.y = b.position.y - h - 0.001
			elif amt > 0.0:
				pos[axis] = b.position[axis] - hw - 0.001
				wall = true
			else:
				pos[axis] = b.end[axis] + hw + 0.001
				wall = true
			bb = AABB(Vector3(pos.x - hw, pos.y, pos.z - hw), Vector3(hw * 2.0, h, hw * 2.0))
	return [pos, ground, wall]


class Mob extends Node3D:
	var kind := ""
	var d: Dictionary
	var mgr: Mobs
	var rig: VoxelRig
	var hp := 10.0
	var vel := Vector3.ZERO
	var on_ground := false
	var facing := 0.0
	var wander_dir := Vector2.ZERO
	var think_t := 0.0
	var attack_cd := 0.0
	var flee_t := 0.0
	var angry := false
	var flash := 0.0
	var dead_t := -1.0
	var hop_t := 0.0
	var variant := 0
	var ranged := false
	var home := Vector3.ZERO
	var village := ""
	var profession := ""
	## Fogo: segundos restantes queimando, temporizadores e efeito visual.
	var burn_t := 0.0
	var _burn_dmg_t := 0.0
	var _sun_t := 0.0
	var _fire: CPUParticles3D
	var _fire_light: OmniLight3D

	func setup(k: String, m: Mobs, v: int = 0) -> void:
		kind = k
		mgr = m
		variant = v
		d = Mobs.DEFS[k]
		hp = d["hp"]
		ranged = d.get("ranged", false) or (k == "bandido" and v % 3 == 0)
		rig = VoxelRig.new()
		add_child(rig)
		rig.build(Rigs.mob(k, v))
		if d.get("npc", false):
			profession = Rigs.npc_options(k, v).get("profession", "")
		facing = randf() * TAU

	func hurt(amount: float, from: Vector3, knock: bool = true) -> void:
		if dead_t >= 0.0:
			return
		hp -= amount
		flash = 1.0
		if not knock:
			flee_t = 2.0
			if mgr.sfx != null:
				mgr.sfx.play("thud", -8.0, 1.8)
			if hp <= 0.0:
				dead_t = 0.0
				_set_fire(false)
				mgr.on_death(self)
			return
		var push := (global_position - from)
		push.y = 0.0
		push = push.normalized() * 6.0 if push.length() > 0.01 else Vector3.ZERO
		vel.x = push.x
		vel.z = push.z
		vel.y = 4.5
		flee_t = 4.0
		if d.get("neutral", false):
			angry = true
		if mgr.sfx != null:
			mgr.sfx.play("thud", -2.0, 1.4)
		if hp <= 0.0:
			dead_t = 0.0
			mgr.on_death(self)

	func _set_fire(on: bool) -> void:
		if on and _fire == null:
			var hw: float = d["w"]
			var hh: float = d["h"]
			_fire = CPUParticles3D.new()
			_fire.amount = 46
			_fire.lifetime = 0.55
			_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			_fire.emission_box_extents = Vector3(hw, hh * 0.45, hw)
			_fire.position = Vector3(0, hh * 0.5, 0)
			_fire.direction = Vector3.UP
			_fire.spread = 18.0
			_fire.initial_velocity_min = 0.6
			_fire.initial_velocity_max = 1.6
			_fire.gravity = Vector3(0, 2.5, 0)
			_fire.scale_amount_min = 0.6
			_fire.scale_amount_max = 1.3
			var curve := Curve.new()
			curve.add_point(Vector2(0, 0.6))
			curve.add_point(Vector2(0.3, 1.0))
			curve.add_point(Vector2(1, 0.0))
			_fire.scale_amount_curve = curve
			var grad := Gradient.new()
			grad.set_color(0, Color(1.0, 0.95, 0.55, 1.0))
			grad.set_color(1, Color(0.9, 0.15, 0.02, 0.0))
			grad.add_point(0.4, Color(1.0, 0.45, 0.05, 1.0))
			_fire.color_ramp = grad
			var q := QuadMesh.new()
			q.size = Vector2(0.36, 0.36)
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			m.vertex_color_use_as_albedo = true
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			q.material = m
			_fire.mesh = q
			add_child(_fire)
			_fire_light = OmniLight3D.new()
			_fire_light.light_color = Color(1.0, 0.55, 0.2)
			_fire_light.light_energy = 1.6
			_fire_light.omni_range = 4.0
			_fire_light.position = Vector3(0, hh * 0.6, 0)
			add_child(_fire_light)
		if _fire != null:
			_fire.emitting = on
			_fire_light.visible = on

	func _physics_process(dt: float) -> void:
		dt = minf(dt, 0.05)
		if dead_t >= 0.0:
			dead_t += dt
			rig.rotation.z = minf(dead_t * 6.0, PI * 0.5)
			if dead_t > 0.7:
				queue_free()
			return
		flash = maxf(0.0, flash - dt * 4.0)
		rig.set_flash(flash)
		# Luz do sol direta incendeia os monstros; sombra ou agua apagam.
		_sun_t -= dt
		if _sun_t <= 0.0:
			_sun_t = 0.5
			if d.get("burns", false) and mgr.in_sunlight(position + Vector3(0, d["h"], 0)):
				burn_t = maxf(burn_t, 1.5)
		if burn_t > 0.0:
			var fb := mgr.world.get_block(floori(position.x), floori(position.y + 0.3), floori(position.z))
			if Blocks.FLUID[fb] == 1:
				burn_t = 0.0
			else:
				burn_t -= dt
				_burn_dmg_t -= dt
				if _burn_dmg_t <= 0.0:
					_burn_dmg_t = 0.5
					hurt(1.0, position, false)
		_set_fire(burn_t > 0.0 and dead_t < 0.0)
		attack_cd -= dt
		flee_t -= dt
		think_t -= dt
		var w := mgr.world
		var pl := mgr.player
		var to_p := pl.position - position
		var dist := to_p.length()
		var speed: float = d["speed"]
		var want := Vector2.ZERO
		var hostile: bool = d["hostile"] or angry
		if hostile and dist < 24.0 and pl.alive:
			var dir2 := Vector2(to_p.x, to_p.z).normalized()
			if ranged:
				if dist < 7.0:
					want = -dir2
				elif dist > 12.0:
					want = dir2
				facing = atan2(-dir2.x, -dir2.y)
				if attack_cd <= 0.0 and dist < d["reach"]:
					attack_cd = 2.2
					rig.attack()
					mgr.shoot(position + Vector3(0, 1.4, 0), pl.position + Vector3(0, 1.2, 0), false, d["dmg"], 26.0, kind)
			else:
				want = dir2
				if dist < d["reach"] and attack_cd <= 0.0 and absf(to_p.y) < 2.0:
					attack_cd = 1.0
					rig.attack()
					pl.damage(d["dmg"], position)
		elif flee_t > 0.0 or (d.get("skittish", false) and dist < 6.0):
			want = -Vector2(to_p.x, to_p.z).normalized()
			speed *= 1.8
		else:
			if think_t <= 0.0:
				think_t = randf_range(2.0, 6.0)
				wander_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.6 else Vector2.ZERO
				# NPCs ficam perto de casa.
				if d.get("npc", false) and Vector2(position.x - home.x, position.z - home.z).length() > 16.0:
					wander_dir = Vector2(home.x - position.x, home.z - position.z).normalized()
			want = wander_dir * 0.5
			if d.get("npc", false) and dist < 3.0 and pl.alive:
				want = Vector2.ZERO
				var dir2 := Vector2(to_p.x, to_p.z).normalized()
				facing = lerp_angle(facing, atan2(-dir2.x, -dir2.y), 1.0 - exp(-dt * 6.0))
		if d.get("flyer", false):
			var target_y := pl.position.y + 1.0 if hostile else position.y
			vel.y = lerpf(vel.y, clampf(target_y - position.y, -2.0, 2.0), 1.0 - exp(-dt * 3.0))
		else:
			vel.y = maxf(vel.y - 25.0 * dt, -40.0)
		if d.get("hopper", false):
			hop_t -= dt
			if on_ground:
				vel.x *= 0.6
				vel.z *= 0.6
				if hop_t <= 0.0 and want.length() > 0.1:
					hop_t = 1.1
					vel.y = 7.0
					vel.x = want.x * speed * 2.0
					vel.z = want.y * speed * 2.0
		else:
			vel.x = lerpf(vel.x, want.x * speed, 1.0 - exp(-dt * 8.0))
			vel.z = lerpf(vel.z, want.y * speed, 1.0 - exp(-dt * 8.0))
		if want.length() > 0.05 and not ranged:
			facing = lerp_angle(facing, atan2(-want.x, -want.y), 1.0 - exp(-dt * 8.0))
		var cx := floori(position.x)
		var cz := floori(position.z)
		if not w.is_loaded(cx, cz):
			return
		var r := Mobs.move_box(w, position, vel * dt, d["w"], d["h"])
		position = r[0]
		on_ground = r[1]
		if on_ground and vel.y < 0.0:
			vel.y = 0.0
		if r[2] and on_ground and want.length() > 0.1 and not d.get("hopper", false):
			vel.y = 7.6
		var feet := w.get_block(cx, floori(position.y + 0.3), cz)
		if Blocks.FLUID[feet] != 0:
			vel.y = minf(vel.y + 30.0 * dt, 2.5)
			if Blocks.FLUID[feet] == 2 and not d.get("fire", false):
				burn_t = maxf(burn_t, 4.0)
				hurt(4.0 * dt, position)
		rig.rotation.y = facing
		rig.animate(dt, Vector2(vel.x, vel.z).length(), on_ground or d.get("flyer", false))


class Arrow extends Node3D:
	var vel := Vector3.ZERO
	var from_player := true
	var dmg := 4.0
	var mgr: Mobs
	var life := 6.0
	var stuck := false
	var grav := 14.0
	var magic := false

	func _physics_process(dt: float) -> void:
		life -= dt
		if life <= 0.0:
			queue_free()
			return
		if stuck:
			return
		vel.y -= grav * dt
		var step := vel * dt
		var hit := mgr.world.raycast(position, step.normalized(), step.length() + 0.05)
		if not hit.is_empty():
			position = hit["point"]
			if magic:
				queue_free()
				return
			stuck = true
			life = minf(life, 3.0)
			return
		position += step
		if vel.length() > 0.1 and absf(vel.normalized().y) < 0.99:
			look_at(position + vel, Vector3.UP)
		if from_player:
			for m in mgr.mobs:
				if is_instance_valid(m) and m.dead_t < 0.0:
					var c: Vector3 = m.position + Vector3(0, m.d["h"] * 0.5, 0)
					if c.distance_to(position) < maxf(m.d["w"], m.d["h"] * 0.5) + 0.2:
						var was_alive: bool = m.hp > 0.0
						m.hurt(dmg, position - vel)
						if was_alive and m.hp <= 0.0 and mgr.player != null:
							mgr.player.gain_xp(mgr.player.kill_xp(m))
						queue_free()
						return
		else:
			var pc := mgr.player.position + Vector3(0, 0.9, 0)
			if pc.distance_to(position) < 0.8:
				mgr.player.damage(dmg, position - vel)
				queue_free()


class Drop extends Node3D:
	var id := 0
	var n := 1
	var wear := 0
	var mgr: Mobs
	var vel := Vector3.ZERO
	var t := 0.0

	func _physics_process(dt: float) -> void:
		t += dt
		if t > 120.0:
			queue_free()
			return
		vel.y = maxf(vel.y - 18.0 * dt, -20.0)
		var r := Mobs.move_box(mgr.world, position, vel * dt, 0.12, 0.25)
		position = r[0]
		if r[1]:
			vel = Vector3(vel.x * 0.5, 0.0, vel.z * 0.5)
		get_child(0).rotation.y = t * 2.0
		get_child(0).position.y = 0.2 + sin(t * 3.0) * 0.06
		if t > 0.6 and mgr.player.alive and (mgr.player.position + Vector3(0, 0.5, 0)).distance_to(position) < 1.6:
			var left := mgr.player.pickup(id, n, wear)
			if left == 0:
				queue_free()
			else:
				n = left


class Boat extends Node3D:
	var wood := 0
	var mgr: Mobs
	var rig: VoxelRig
	var vel := Vector3.ZERO
	var yaw := 0.0
	var rider: Player = null
	var hp := 3.0
	var _oar := 0.0

	func setup(w: int, m: Mobs) -> void:
		wood = w
		mgr = m
		var bw: Array = Items.BOAT_WOODS[w]
		rig = VoxelRig.new()
		add_child(rig)
		rig.build(Rigs.boat(bw[1], bw[2]))

	func _physics_process(dt: float) -> void:
		dt = minf(dt, 0.05)
		var w := mgr.world
		var bx := floori(position.x)
		var bz := floori(position.z)
		if not w.is_loaded(bx, bz):
			return
		var water_here := Blocks.FLUID[w.get_block(bx, floori(position.y + 0.15), bz)] == 1
		var water_below := Blocks.FLUID[w.get_block(bx, floori(position.y - 0.2), bz)] == 1
		var thrust := 0.0
		var turn := 0.0
		if rider != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			thrust = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)) * 0.5
			turn = float(Input.is_physical_key_pressed(KEY_A)) - float(Input.is_physical_key_pressed(KEY_D))
		yaw += turn * dt * 1.8
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var on_water := water_here or water_below
		var accel := 9.0 if on_water else 2.0
		vel += fwd * thrust * accel * dt
		var damp := 1.6 if on_water else 6.0
		vel.x *= exp(-damp * dt)
		vel.z *= exp(-damp * dt)
		if water_here:
			vel.y = minf(vel.y + 18.0 * dt, 1.5)
		elif water_below:
			vel.y *= 0.5
		else:
			vel.y = maxf(vel.y - 20.0 * dt, -20.0)
		var r := Mobs.move_box(w, position, vel * dt, 0.55, 0.4)
		position = r[0]
		if r[1]:
			vel.y = 0.0
		rotation.y = yaw
		_oar += dt * (absf(thrust) * 6.0)
		for n: Node3D in rig.groups.get("armA", []):
			n.rotation.x = sin(_oar) * 0.6
		for n: Node3D in rig.groups.get("armB", []):
			n.rotation.x = sin(_oar) * 0.6


var boats: Array = []
## Vilas com NPCs vivos (para nao duplicar ao recarregar chunks): id -> quantidade.
var _villages: Dictionary = {}


func _ready() -> void:
	_rng.randomize()


func _physics_process(dt: float) -> void:
	if world == null or player == null:
		return
	var k := mobs.size() - 1
	while k >= 0:
		var m = mobs[k]
		if not is_instance_valid(m) or m.is_queued_for_deletion():
			mobs.remove_at(k)
			k -= 1
			continue
		else:
			var far: float = m.position.distance_to(player.position)
			var day := weather.sun_dir.y > 0.08
			if far > 96.0:
				_forget(m)
				m.queue_free()
				mobs.remove_at(k)
		k -= 1
	# NPCs vindos das vilas carregadas.
	while not world.pending_npcs.is_empty():
		var np: Array = world.pending_npcs.pop_front()
		var vid: String = np[3]
		if _villages.get(vid, 0) > 0:
			continue
		var pos: Vector3 = np[0]
		var fy := world.surface_y(floori(pos.x), floori(pos.z))
		var m := spawn(np[1], Vector3(pos.x, fy + 1.0, pos.z), int(np[2]))
		m.home = m.position
		m.village = vid
		_villages[vid] = _villages.get(vid, 0) + 1
	if not enabled:
		return
	_spawn_t -= dt
	if _spawn_t <= 0.0:
		_spawn_t = 0.7
		_try_spawn()


func _count(hostile: bool) -> int:
	var n := 0
	for m in mobs:
		if is_instance_valid(m) and bool(m.d["hostile"]) == hostile:
			n += 1
	return n


## Ha sol batendo direto neste ponto? (dia, superficie, sem chuva forte, nada solido ou folhagem acima)
func in_sunlight(p: Vector3) -> bool:
	if world.dim != 0 or weather == null:
		return false
	if weather.sun_dir.y < 0.08 or weather.rain > 0.35:
		return false
	var x := floori(p.x)
	var z := floori(p.z)
	for y in range(floori(p.y) + 1, World.H):
		var id := world.get_block(x, y, z)
		if id != 0 and (Blocks.SOLID[id] == 1 or Blocks.KIND[id] == Blocks.K_LEAVES or Blocks.FLUID[id] != 0):
			return false
	return true


func _forget(m: Variant) -> void:
	var vid: String = m.village
	if vid != "":
		_villages[vid] = maxi(0, int(_villages.get(vid, 1)) - 1)


func clear_all() -> void:
	for m in mobs:
		if is_instance_valid(m):
			m.queue_free()
	mobs.clear()
	for b in boats:
		if is_instance_valid(b):
			b.queue_free()
	boats.clear()
	_villages.clear()
	for ch in get_children():
		if ch is Drop or ch is Arrow:
			ch.queue_free()


func _try_spawn_dim() -> void:
	var pp := player.position
	var ang := _rng.randf() * TAU
	var rad := _rng.randf_range(18.0, 44.0)
	var x := floori(pp.x + cos(ang) * rad)
	var z := floori(pp.z + sin(ang) * rad)
	if not world.is_loaded(x, z) or _count(true) >= HOSTILE_CAP:
		return
	if world.dim == 1:
		var y := world.find_floor(x, z, maxi(33, floori(pp.y) - 12), mini(120, floori(pp.y) + 12))
		if y < 0:
			return
		var kinds := ["salamandra", "salamandra", "chama", "gosma", "esqueleto"]
		var k: String = kinds[_rng.randi() % kinds.size()]
		var v := 2 if k == "gosma" else (1 if k == "esqueleto" else 0)
		spawn(k, Vector3(x + 0.5, y, z + 0.5), v)
	else:
		var y := world.surface_y(x, z)
		if y < 10:
			return
		var k: String = ["vigia", "espectro"][_rng.randi() % 2]
		spawn(k, Vector3(x + 0.5, y + 1.0, z + 0.5), 1 if k == "espectro" else 0)


func _try_spawn() -> void:
	if world.dim != 0:
		_try_spawn_dim()
		return
	var pp := player.position
	var ang := _rng.randf() * TAU
	var rad := _rng.randf_range(22.0, 54.0)
	var x := floori(pp.x + cos(ang) * rad)
	var z := floori(pp.z + sin(ang) * rad)
	if not world.is_loaded(x, z):
		return
	var night := weather.sun_dir.y < -0.05
	var surf := world.surface_y(x, z)
	var underground := pp.y < world.surface_y(floori(pp.x), floori(pp.z)) - 6
	var top := world.get_block(x, surf, z)
	var bio := world.gen.height_biome(x, z) >> 8
	if underground:
		# Cavernas: procura um vao de 2 blocos perto da altura do jogador.
		for tries in 12:
			var cy := floori(pp.y) + _rng.randi_range(-8, 8)
			if Blocks.SOLID[world.get_block(x, cy - 1, z)] == 1 and world.get_block(x, cy, z) == 0 and world.get_block(x, cy + 1, z) == 0:
				if _count(true) < HOSTILE_CAP:
					var kinds := ["andarilho", "esqueleto", "aranha", "gosma", "andarilho", "aranha"]
					if bio == WorldGen.B_MOUNTAIN or _rng.randf() < 0.05:
						kinds.append("golem")
					spawn(kinds[_rng.randi() % kinds.size()], Vector3(x + 0.5, cy, z + 0.5))
				return
		return
	if Blocks.FLUID[top] != 0 or surf <= WorldGen.SEA:
		return
	var pos := Vector3(x + 0.5, surf + 1.0, z + 0.5)
	if night:
		if _count(true) < HOSTILE_CAP:
			var kinds := ["andarilho", "andarilho", "esqueleto", "aranha", "gosma", "espectro"]
			if bio == WorldGen.B_MOUNTAIN or bio == WorldGen.B_PEAK:
				kinds.append("golem")
			spawn(kinds[_rng.randi() % kinds.size()], pos)
		return
	if _count(false) >= PASSIVE_CAP:
		return
	var choices: Array = []
	match bio:
		WorldGen.B_PLAINS: choices = ["vaca", "porco", "ovelha", "galinha", "coelho"]
		WorldGen.B_FOREST: choices = ["vaca", "porco", "galinha", "cervo", "coelho", "lobo"]
		WorldGen.B_SNOW: choices = ["coelho", "cervo", "lobo", "ovelha"]
		WorldGen.B_DESERT: choices = ["coelho"]
		WorldGen.B_MOUNTAIN: choices = ["ovelha", "cervo", "golem"]
	if choices.is_empty():
		return
	var kind: String = choices[_rng.randi() % choices.size()]
	# Rebanhos: animais de fazenda aparecem em grupos.
	var herd := 1 if kind in ["lobo", "golem", "cervo"] else _rng.randi_range(2, 4)
	for i in herd:
		var off := Vector3(_rng.randf_range(-2.5, 2.5), 0, _rng.randf_range(-2.5, 2.5))
		var hx := floori(pos.x + off.x)
		var hz := floori(pos.z + off.z)
		spawn(kind, Vector3(hx + 0.5, world.surface_y(hx, hz) + 1.0, hz + 0.5))


func spawn(kind: String, pos: Vector3, variant: int = -1) -> Mob:
	var m := Mob.new()
	if variant < 0:
		variant = _rng.randi() % 12
	m.setup(kind, self, variant)
	m.position = pos
	add_child(m)
	mobs.append(m)
	return m


func on_death(m: Mob) -> void:
	_forget(m)
	var luck: float = player.stats.loot_chance() if player != null else 0.0
	for dr: Array in m.d.get("drops", []):
		var n := _rng.randi_range(dr[1], dr[2])
		if _rng.randf() < luck:
			n += 1
		var id := Items.find(dr[0])
		for i in n:
			drop(id, m.position + Vector3(0, 0.5, 0))
	if m.d.has("block_drop"):
		var wool: int = m.d["block_drop"]
		# A la acompanha a cor da ovelha.
		match Rigs.variant_name(m.kind, m.variant):
			"cinza": wool = Blocks.WOOL_0 + 1
			"preta": wool = Blocks.WOOL_0 + 2
			"marrom": wool = Blocks.WOOL_0 + 11
		drop(wool, m.position + Vector3(0, 0.5, 0))


func drop(id: int, pos: Vector3, n: int = 1, wear: int = 0) -> void:
	if id <= 0 or n <= 0:
		return
	var dr := Drop.new()
	dr.id = id
	dr.n = n
	dr.wear = wear
	dr.mgr = self
	dr.position = pos
	dr.vel = Vector3(_rng.randf_range(-2, 2), 4.0, _rng.randf_range(-2, 2))
	var mi := MeshInstance3D.new()
	if Items.is_item(id):
		mi.mesh = Items.mesh(id)
		mi.scale = Vector3.ONE * 0.5
	else:
		mi.mesh = player.item_mesh(id)
		mi.scale = Vector3.ONE * 0.25
		mi.position = -Vector3(8.5, 1.5, 8.5) * 0.25
	var holder := Node3D.new()
	holder.add_child(mi)
	dr.add_child(holder)
	add_child(dr)


func shoot(from: Vector3, to: Vector3, by_player: bool, dmg: float, speed: float = 26.0, shooter: String = "") -> void:
	var a := Arrow.new()
	a.mgr = self
	a.from_player = by_player
	a.dmg = dmg
	a.position = from
	var dir := (to - from)
	var flat := Vector2(dir.x, dir.z).length()
	dir = dir.normalized()
	if not by_player:
		dir.y += flat * 0.012
		dir = dir.normalized()
	a.vel = dir * speed
	if shooter == "magia":
		a.grav = 0.0
		a.magic = true
		a.life = 3.0
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		var om := StandardMaterial3D.new()
		om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		om.albedo_color = Color(0.75, 0.55, 1.0)
		om.emission_enabled = true
		om.emission = Color(0.6, 0.35, 1.0)
		om.emission_energy_multiplier = 4.0
		sm.material = om
		orb.mesh = sm
		a.add_child(orb)
		var ol := OmniLight3D.new()
		ol.light_color = Color(0.65, 0.45, 1.0)
		ol.light_energy = 2.5
		ol.omni_range = 5.0
		a.add_child(ol)
		var tr := CPUParticles3D.new()
		tr.amount = 30
		tr.lifetime = 0.4
		tr.local_coords = false
		tr.gravity = Vector3.ZERO
		tr.initial_velocity_max = 0.3
		tr.scale_amount_min = 0.04
		tr.scale_amount_max = 0.09
		var qm := QuadMesh.new()
		var pm := StandardMaterial3D.new()
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		pm.albedo_color = Color(0.85, 0.7, 1.0)
		qm.material = pm
		tr.mesh = qm
		a.add_child(tr)
		add_child(a)
		return
	var mi := MeshInstance3D.new()
	var proj := "Flecha"
	if shooter == "chama":
		proj = "Pó de brasa"
	elif shooter == "vigia":
		proj = "Cristal"
	mi.mesh = Items.mesh(Items.find(proj))
	mi.scale = Vector3.ONE * 0.7
	mi.rotation = Vector3(0, PI * 0.5, PI * 0.25)
	a.add_child(mi)
	add_child(a)
	if sfx != null:
		sfx.play("place", -8.0, 1.8)


## Mob mais proximo atingido por um raio (para o ataque corpo a corpo).
func ray_mob(origin: Vector3, dir: Vector3, max_dist: float) -> Array:
	var best: Mob = null
	var best_t := max_dist
	for m in mobs:
		if not is_instance_valid(m) or m.dead_t >= 0.0:
			continue
		var w: float = m.d["w"] * maxf(m.rig._root.scale.x, 1.0) + 0.1
		var b := AABB(m.position - Vector3(w, 0, w), Vector3(w * 2.0, m.d["h"], w * 2.0))
		var r := World._ray_box(origin, dir, b)
		if r.x >= 0.0 and r.x < best_t:
			best_t = r.x
			best = m
	return [best, best_t]


func ray_boat(origin: Vector3, dir: Vector3, max_dist: float) -> Array:
	var best: Boat = null
	var best_t := max_dist
	for b in boats:
		if not is_instance_valid(b):
			continue
		var r := World._ray_box(origin, dir, AABB(b.position - Vector3(0.6, 0, 0.6), Vector3(1.2, 0.6, 1.2)))
		if r.x >= 0.0 and r.x < best_t:
			best_t = r.x
			best = b
	return [best, best_t]


func place_boat(wood: int, pos: Vector3, yaw: float) -> Boat:
	var b := Boat.new()
	b.setup(wood, self)
	b.position = pos
	b.yaw = yaw
	add_child(b)
	boats.append(b)
	return b


func break_boat(b: Boat) -> void:
	drop(Items.find("Barco de " + str(Items.BOAT_WOODS[b.wood][0])), b.position + Vector3(0, 0.5, 0))
	boats.erase(b)
	b.queue_free()


## Conversa ou troca com um NPC. Devolve o texto para mostrar.
func interact(m: Mob, trade: bool, inv: Inventory) -> String:
	if m.kind != "aldeao":
		return ""
	var title := m.profession.capitalize()
	var t: Array = TRADES.get(m.profession, [])
	if t.is_empty():
		return title + ": " + GREETINGS[m.variant % GREETINGS.size()]
	var give := Items.find(t[0])
	var get_id := Items.find(t[2])
	if t[2] == "lã":
		get_id = Blocks.WOOL_0
	elif t[2] == "estante":
		get_id = Blocks.BOOKSHELF
	var offer := "%s: troco %d %s por %d %s." % [title, t[1], t[0], t[3], Items.name_of(get_id)]
	if not trade:
		return GREETINGS[m.variant % GREETINGS.size()] + "  " + offer + "  (Shift + clique direito para trocar)"
	if inv.count(give) < int(t[1]):
		return "%s: você precisa de %d %s." % [title, t[1], t[0]]
	inv.remove(give, t[1])
	var left := inv.add(get_id, t[3])
	if left > 0:
		drop(get_id, player.position + Vector3(0, 1, 0), left)
	return "%s: negócio fechado! (+%d %s)" % [title, t[3], Items.name_of(get_id)]
