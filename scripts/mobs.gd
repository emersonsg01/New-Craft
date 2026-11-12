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
	# Montarias: "ride" = velocidade montado, "seat" = altura da sela, "jump" = impulso do pulo.
	"cavalo": {"hp": 22, "speed": 1.6, "hostile": false, "w": 0.5, "h": 1.6, "ride": 8.5, "seat": 1.30, "jump": 9.2, "drops": [["Couro", 0, 2]]},
	"burro": {"hp": 18, "speed": 1.4, "hostile": false, "w": 0.45, "h": 1.35, "ride": 6.0, "seat": 1.05, "jump": 8.2, "drops": [["Couro", 0, 2]]},
	"camelo": {"hp": 26, "speed": 1.2, "hostile": false, "w": 0.55, "h": 2.2, "ride": 7.0, "seat": 1.90, "jump": 7.8, "drops": [["Couro", 0, 2]]},
	"cabra": {"hp": 8, "speed": 1.8, "hostile": false, "w": 0.32, "h": 0.95, "drops": [["Carne crua", 1, 2], ["Couro", 0, 1]], "climber": true},
	"raposa": {"hp": 8, "speed": 3.2, "hostile": false, "w": 0.3, "h": 0.65, "drops": [["Couro", 0, 1]], "skittish": true},
	"urso": {"hp": 32, "speed": 2.6, "hostile": false, "neutral": true, "w": 0.6, "h": 1.3, "dmg": 6.0, "reach": 1.9, "drops": [["Carne crua", 2, 4], ["Couro", 1, 3]]},
	"pato": {"hp": 4, "speed": 1.4, "hostile": false, "w": 0.25, "h": 0.6, "drops": [["Pena", 1, 3], ["Carne crua", 0, 1]]},
	"mumia": {"hp": 24, "speed": 1.6, "hostile": true, "undead": true, "w": 0.32, "h": 1.8, "dmg": 3.5, "reach": 1.5, "drops": [["Osso", 0, 2], ["Lingote de ouro", 0, 1]]},
	"goblin": {"hp": 12, "speed": 3.4, "hostile": true, "w": 0.25, "h": 1.25, "dmg": 2.5, "reach": 1.3, "drops": [["Lingote de cobre", 0, 2], ["Pão", 0, 1]]},
	"ogro": {"hp": 55, "speed": 1.3, "hostile": true, "w": 0.6, "h": 2.9, "dmg": 8.0, "reach": 2.4, "drops": [["Couro", 1, 3], ["Lingote de ferro", 0, 2]]},
}
## Trocas por profissao: [o que o jogador da, quantidade, o que recebe, quantidade].
## Clique direito mostra a proxima oferta; Shift + clique direito fecha a oferta mostrada.
const TRADES := {
	"fazendeiro": [["Trigo", 6, "Pão", 3], ["Lingote de ferro", 1, "Enxada de ferro", 1]],
	"minerador": [["Pão", 4, "Carvão", 8], ["Pão", 2, "tocha", 8], ["Lingote de ferro", 2, "lanterna", 2], ["Lingote de ouro", 4, "Capacete de minerador", 1]],
	"caçador": [["Carne crua", 3, "Flecha", 8], ["Pena", 6, "Arco", 1]],
	"criador": [["Trigo", 4, "lã", 2], ["Trigo", 6, "Couro", 2], ["Trigo", 3, "Ovo", 2]],
	"ferreiro": [["Carvão", 8, "Lingote de ferro", 1], ["Lingote de ferro", 4, "Escudo de ferro", 1]],
	"armeiro": [["Lingote de ferro", 6, "Peitoral de ferro", 1]],
	"ferramenteiro": [["Lingote de ferro", 3, "Picareta de ferro", 1], ["Lingote de ferro", 2, "Machado de ferro", 1]],
	"lenhador": [["Pão", 3, "tronco", 16], ["Pão", 2, "tábuas", 24]],
	"comerciante": [["Lingote de ouro", 3, "Sela de couro", 1], ["Rubi", 1, "Lingote de ouro", 3]],
	"construtor": [["Pão", 3, "tábuas", 16], ["Lingote de ferro", 1, "tijolos", 16], ["Carvão", 4, "pedra lapidada", 16]],
	"artesão": [["Tecido", 3, "cama", 1], ["Pão", 2, "cadeira", 2], ["Pão", 3, "mesa", 1], ["Tecido", 2, "cortina", 6], ["Pão", 3, "estante", 1]],
	"alfaiate": [["Tecido", 3, "Túnica", 1], ["Trigo", 5, "Chapéu de palha", 1], ["Tecido", 4, "Manto", 1], ["Couro curtido", 3, "Colete", 1],
		["Tecido", 2, "Bandana", 1], ["Tecido", 2, "Avental", 1], ["Couro curtido", 2, "Capuz", 1]],
	"tecelão": [["lã", 2, "Tecido", 1], ["Couro", 2, "Couro curtido", 2], ["Trigo", 8, "Tecido", 1]],
}
## Nomes de troca que sao blocos.
const TRADE_BLOCKS := {"lã": "WOOL_0", "estante": "BOOKSHELF", "tronco": "LOG", "tábuas": "PLANKS", "tijolos": "BRICKS", "cama": "BED",
	"cadeira": "CHAIR", "mesa": "TABLE", "tocha": "TORCH", "lanterna": "LANTERN", "pedra lapidada": "STONE_BRICKS"}
## O que cada profissao leva nas maos: [direita, esquerda].
const NPC_HANDS := {
	"fazendeiro": ["Enxada de ferro", ""], "minerador": ["Picareta de ferro", "lanterna"], "caçador": ["Arco", ""],
	"guarda": ["Espada de ferro", "Escudo de ferro"], "ferreiro": ["Martelo de guerra de ferro", ""], "ferramenteiro": ["Machado de ferro", ""],
	"lenhador": ["Machado de ferro", ""], "construtor": ["Martelo de guerra de ferro", ""], "alfaiate": ["Tesoura", ""],
	"tecelão": ["Tesoura", ""], "artesão": ["Machado de pedra", ""], "armeiro": ["Martelo de guerra de ferro", ""],
}
const CHAT_LINES: Array[String] = ["Viu o tempo hoje?", "Dizem que tem minério novo na mina.", "Preciso de mais lã para o tear.",
	"O construtor está erguendo uma casa nova!", "Os guardas viram lobos ontem.", "A feira está movimentada.", "Que tal um pão quentinho?",
	"Meu machado precisa de fio.", "A colheita vai ser boa.", "Ouvi falar de uma aurora no céu.", "Hoje o mercado abriu cedo.",
	"Cuidado com a mina à noite.", "Essa túnica ficou ótima!", "As vacas deram muito leite.", "Ha, essa é boa!", "Concordo plenamente."]
const GREETINGS: Array[String] = ["Bom dia, viajante!", "Que ventos te trazem?", "Cuidado com as criaturas à noite.", "A colheita está boa este ano.",
	"Já viu as ilhas que flutuam? Dizem que um portal de cristal leva até lá.", "Moldura de vidro vulcânico... e uma faísca. Ouvi falar disso."]
## Vozes: [intervalo minimo e maximo entre sons a toa (s), volume em dB].
const VOICE := {
	"vaca": [9.0, 22.0, 0.0], "porco": [7.0, 16.0, -2.0], "ovelha": [8.0, 18.0, -2.0], "cabra": [8.0, 20.0, -1.0], "galinha": [5.0, 12.0, -5.0],
	"pato": [5.0, 12.0, -4.0], "coelho": [14.0, 30.0, -10.0], "cervo": [14.0, 30.0, -3.0], "raposa": [12.0, 26.0, -3.0], "lobo": [10.0, 24.0, 0.0],
	"urso": [10.0, 22.0, 1.0], "cavalo": [10.0, 24.0, -1.0], "burro": [12.0, 26.0, 0.0], "camelo": [12.0, 26.0, -1.0],
	"andarilho": [5.0, 12.0, -1.0], "mumia": [6.0, 13.0, -2.0], "esqueleto": [5.0, 11.0, -4.0], "aranha": [5.0, 11.0, -4.0], "gosma": [4.0, 9.0, -4.0],
	"espectro": [6.0, 14.0, -1.0], "golem": [10.0, 20.0, 2.0], "salamandra": [6.0, 13.0, -4.0], "chama": [4.0, 9.0, -4.0], "vigia": [7.0, 15.0, -3.0],
	"goblin": [5.0, 12.0, -3.0], "ogro": [8.0, 16.0, 2.0], "bandido": [10.0, 22.0, -2.0], "aldeao": [18.0, 40.0, -6.0],
}
const PASSIVE_CAP := 14
const HOSTILE_CAP := 12

var world: World
var player: Player
## Multijogador: rede, modo boneco (criaturas vem do simulador) e bonecos por id do simulador.
var net: Variant = null
var puppet_mode := false
var _puppets: Dictionary = {}
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
	## Montaria: item da sela colocada e jogador montado.
	var saddle := 0
	var rider: Player = null
	var seat_h := 0.25
	## Movimento natural: ponto de destino ao passear, pausa e fator de velocidade da raca.
	var goal := Vector3.INF
	var idle_t := 0.0
	var breed_speed := 1.0
	## Produtos: espera para ordenhar de novo, proximo ovo, ovelha tosquiada e tempo da la crescer.
	## Boneco de rede (id da criatura no simulador; 0 = criatura local) e alvo interpolado.
	var puppet_id := 0
	## Id curto desta criatura na rede (sequencial, cabe num float).
	var net_id := 0
	var net_pos := Vector3.ZERO
	var net_yaw := 0.0
	var net_speed := 0.0
	var milk_t := 0.0
	var egg_t := 0.0
	var sheared := false
	var wool_t := 0.0
	## Guarda: alvo atual.
	var foe: Variant = null
	## Aldeoes: dados da vila (centro, local de trabalho, lote), paleta, trocas, trabalho, conversa e ronda.
	var npc_extra: Dictionary = {}
	var pal := "planicie"
	var trade_i := 0
	var trade_shown := 0
	var job_t := 0.0
	var working := false
	var swing_t := 0.0
	var chat_t := 0.0
	var chat_with: Variant = null
	var _say_t := 0.0
	var _bubble: Label3D
	var patrol_i := -1
	var _last_p := Vector3.ZERO
	var _stuck_t := 0.0
	var _plan: Array = []
	var _plan_i := 0
	var _place_t := 0.0
	var _best_d := INF
	## Voz: tocador 3D (criado no primeiro som), chave da voz, proximo som a toa e tom individual.
	var _voice: AudioStreamPlayer3D
	var voice_key := ""
	var voice_t := 0.0
	var voice_pitch := 1.0
	var _best_t := 0.0

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
		seat_h = float(d.get("seat", 0.25))
		# Cada raca/individuo anda um pouco diferente.
		breed_speed = 0.88 + float((v * 37 + 11) % 29) / 29.0 * 0.3
		egg_t = randf_range(30.0, 180.0)
		if d.get("npc", false):
			profession = Rigs.npc_options(k, v).get("profession", "")
		facing = randf() * TAU
		voice_key = k
		if k == "aldeao" and bool(Rigs.npc_options(k, v).get("female", false)):
			voice_key = "aldeao_f"
		voice_pitch = 0.92 + float((v * 53 + 7) % 17) / 17.0 * 0.18
		voice_t = randf_range(1.0, 10.0)
		if Mobs.VOICE.has(k):
			Voices.get_sound(voice_key, "idle")

	## Toca um som da especie (idle, hurt, death, attack, talk, night) saindo da propria criatura.
	func voice(ev: String, vol: float = 0.0) -> void:
		if not Mobs.VOICE.has(kind):
			return
		var st := Voices.get_sound(voice_key, ev)
		if st == null:
			return
		if _voice == null:
			_voice = AudioStreamPlayer3D.new()
			_voice.unit_size = 6.0
			_voice.max_distance = 48.0
			_voice.attenuation_filter_cutoff_hz = 9000.0
			_voice.position = Vector3(0, float(d["h"]) * 0.8, 0)
			add_child(_voice)
		_voice.stream = st
		_voice.volume_db = float(Mobs.VOICE[kind][2]) + vol
		_voice.pitch_scale = voice_pitch * randf_range(0.95, 1.05)
		_voice.play()

	## Sons a toa de tempos em tempos (so perto de algum jogador).
	func _voice_tick(dt: float) -> void:
		voice_t -= dt
		if voice_t > 0.0 or dead_t >= 0.0 or not Mobs.VOICE.has(kind):
			return
		var iv: Array = Mobs.VOICE[kind]
		voice_t = randf_range(iv[0], iv[1])
		if mgr.player == null or position.distance_to(mgr.player.position) > 32.0 or chat_t > 0.0:
			return
		var night: bool = mgr.weather != null and mgr.weather.sun_dir.y < -0.05
		if kind == "lobo" and night and randf() < 0.6:
			voice("night", 3.0)
		else:
			voice("idle")

	func hurt(amount: float, from: Vector3, knock: bool = true) -> void:
		if dead_t >= 0.0:
			return
		if puppet_id != 0:
			# Boneco: o dano vai para quem simula esta criatura.
			flash = 1.0
			rig.set_flash(flash)
			if mgr.net != null:
				mgr.net.hit_mob(puppet_id, amount, from)
			voice("hurt")
			return
		hp -= amount
		flash = 1.0
		voice("death" if hp <= 0.0 else "hurt", 2.0)
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

	## Coloca (ou tira, id 0) a sela e redesenha a criatura.
	func set_saddle(id: int) -> void:
		saddle = id
		var sd: Dictionary = {}
		if id > 0:
			var df := Items.def(id)
			sd = {"seat": df["c0"], "trim": df["c1"], "blanket": df.get("blanket", Color(0.6, 0.12, 0.1)), "style": df.get("style", "")}
		rig.build(Rigs.mob(kind, variant, sd))

	## Ha chao firme e seco a frente? (evita penhascos e agua ao passear)
	func _safe_ahead(dir: Vector2) -> bool:
		var w := mgr.world
		var a := position + Vector3(dir.x, 0, dir.y) * (float(d["w"]) + 0.7)
		var ax := floori(a.x)
		var az := floori(a.z)
		var y := floori(position.y + 0.1)
		for dy in range(0, 4):
			var b := w.get_block(ax, y - 1 - dy, az)
			if Blocks.FLUID[b] != 0:
				return d.get("flyer", false)
			if Blocks.SOLID[b] == 1:
				return true
		return d.get("flyer", false)

	## Controle pelo jogador montado.
	func _ride(dt: float) -> void:
		var pl := rider
		var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		var ix := 0.0
		var iz := 0.0
		if captured:
			ix = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
			iz = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		var dir := Basis(Vector3.UP, pl.yaw) * Vector3(ix, 0, iz)
		if dir.length() > 1.0:
			dir = dir.normalized()
		var bonus := 1.0
		if saddle > 0:
			bonus = float(Items.def(saddle).get("speed", 1.0))
		# Ctrl: galope.
		var gallop := 1.45 if captured and Input.is_physical_key_pressed(KEY_CTRL) else 1.0
		var top := float(d.get("ride", 6.0)) * breed_speed * bonus * gallop
		var accel := 3.5 if dir.length() > 0.1 else 5.0
		vel.x = lerpf(vel.x, dir.x * top, 1.0 - exp(-dt * accel))
		vel.z = lerpf(vel.z, dir.z * top, 1.0 - exp(-dt * accel))
		vel.y = maxf(vel.y - 25.0 * dt, -40.0)
		if captured and Input.is_physical_key_pressed(KEY_SPACE) and on_ground:
			vel.y = float(d.get("jump", 8.0))
		var hs := Vector2(vel.x, vel.z)
		if hs.length() > 0.4:
			facing = lerp_angle(facing, atan2(-hs.x, -hs.y), 1.0 - exp(-dt * 6.0))
		var w := mgr.world
		if not w.is_loaded(floori(position.x), floori(position.z)):
			return
		var r := Mobs.move_box(w, position, vel * dt, d["w"], d["h"])
		position = r[0]
		on_ground = r[1]
		if on_ground and vel.y < 0.0:
			vel.y = 0.0
		# Sobe degraus de um bloco sozinho.
		if r[2] and on_ground and hs.length() > 0.5:
			vel.y = 7.0
		var feet := w.get_block(floori(position.x), floori(position.y + 0.3), floori(position.z))
		if Blocks.FLUID[feet] != 0:
			vel.y = minf(vel.y + 30.0 * dt, 2.5)
		rig.rotation.y = facing
		rig.look_yaw = 0.0
		rig.animate(dt, hs.length(), on_ground)

	## Ovelha tosquiada: esconde a la (grupo "la" do modelo) ate crescer de novo.
	# ------------------------------------------------------------ aldeoes
	## Itens nas maos conforme a profissao (e luz da lanterna do minerador).
	func equip_npc() -> void:
		var hands: Array = Mobs.NPC_HANDS.get(profession, [])
		for k in hands.size():
			var id := Mobs.trade_id(str(hands[k]))
			if id > 0 and mgr.player != null:
				rig.set_held(k, mgr.player.item_mesh(id), VoxelRig.grip_kind(id))
		if profession == "minerador":
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.78, 0.46)
			l.light_energy = 1.6
			l.omni_range = 7.0
			l.position = Vector3(0, 1.9, -0.3)
			add_child(l)

	func _say(text: String) -> void:
		if _bubble == null:
			_bubble = Label3D.new()
			_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_bubble.pixel_size = 0.004
			_bubble.font_size = 40
			_bubble.outline_size = 10
			_bubble.modulate = Color(1, 1, 0.92)
			_bubble.position = Vector3(0, float(d["h"]) + 0.45, 0)
			add_child(_bubble)
		_bubble.text = text
		_bubble.visible = text != ""
		_say_t = 3.0
		if text != "":
			voice("talk")
		# Na conversa, um fala de cada vez.
		if text != "" and chat_with != null and is_instance_valid(chat_with) and chat_with._bubble != null:
			chat_with._bubble.visible = false

	func _face_to(v: Vector3, dt: float) -> void:
		if Vector2(v.x, v.z).length() > 0.05:
			facing = lerp_angle(facing, atan2(-v.x, -v.z), 1.0 - exp(-dt * 5.0))

	## Comportamento de aldeao. Devolve a direcao desejada ou null para passear normalmente.
	func _npc_job(dt: float) -> Variant:
		if _say_t > 0.0:
			_say_t -= dt
			if _say_t <= 0.0 and _bubble != null:
				_bubble.visible = false
		var night: bool = mgr.weather != null and mgr.weather.sun_dir.y < -0.05
		# Conversa entre aldeoes: ficam frente a frente, gesticulam e trocam falas.
		if chat_t > 0.0:
			chat_t -= dt
			if chat_with == null or not is_instance_valid(chat_with) or chat_with.dead_t >= 0.0:
				chat_t = 0.0
				return null
			var tc: Vector3 = chat_with.position - position
			if tc.length() > 2.4:
				return Vector2(tc.x, tc.z).normalized() * 0.5
			_face_to(tc, dt)
			swing_t -= dt
			if swing_t <= 0.0:
				swing_t = randf_range(1.6, 3.2)
				if randf() < 0.5:
					rig.attack()
				_say(Mobs.CHAT_LINES[randi() % Mobs.CHAT_LINES.size()])
			if chat_t <= 0.0:
				_say("")
				job_t = randf_range(4.0, 8.0)
			return Vector2.ZERO
		if profession == "guarda":
			return _patrol(dt)
		if profession == "construtor" and not night:
			var bw: Variant = _build(dt)
			if bw != null:
				return bw
		job_t -= dt
		if job_t <= 0.0:
			working = not working and not night
			job_t = randf_range(12.0, 22.0) if working else randf_range(8.0, 14.0)
			# Fora do trabalho, as vezes puxa conversa com um vizinho.
			if not working and randf() < 0.6:
				var o: Variant = mgr.nearest_villager(self, 7.0)
				if o != null and o.chat_t <= 0.0 and not o.working:
					chat_t = randf_range(5.0, 9.0)
					chat_with = o
					o.chat_t = chat_t
					o.chat_with = self
					swing_t = 0.2
					o.swing_t = 1.4
					return Vector2.ZERO
		if not working or not npc_extra.has("face"):
			return null
		# Vai ao posto de trabalho, encara a bancada/parede e trabalha com a ferramenta.
		var spot: Vector3 = npc_extra.get("home", home)
		var to_s := Vector2(spot.x - position.x, spot.z - position.z)
		if to_s.length() > 2.5:
			return _steer(to_s.normalized() * 0.55, dt)
		_face_to(npc_extra["face"] - position, dt)
		swing_t -= dt
		if swing_t <= 0.0:
			swing_t = randf_range(0.9, 1.8)
			rig.attack()
		return Vector2.ZERO

	## Guarda: ronda pelo perimetro da vila (8 pontos num circulo em volta da praca).
	func _patrol(dt: float) -> Variant:
		var c: Vector3 = npc_extra.get("center", Vector3.ZERO)
		if c == Vector3.ZERO:
			return null
		var dirn := 1 if variant % 2 == 0 else -1
		if patrol_i < 0:
			patrol_i = int(posmod(roundi((atan2(position.z - c.z, position.x - c.x)) / (TAU / 8.0)), 8))
		var ang := TAU * patrol_i / 8.0
		var wp := c + Vector3(cos(ang), 0, sin(ang)) * 21.0
		var to_w := Vector2(wp.x - position.x, wp.z - position.z)
		if job_t > 0.0:
			# Pausa para vigiar.
			job_t -= dt
			rig.look_yaw = sin(job_t * 1.5) * 0.7
			_last_p = position
			_stuck_t = 0.0
			return Vector2.ZERO
		if to_w.length() < 1.6 or _stuck_t > 6.0:
			patrol_i = posmod(patrol_i + dirn, 8)
			_stuck_t = 0.0
			job_t = randf_range(1.5, 3.5)
			return Vector2.ZERO
		return _steer(to_w.normalized() * 0.6, dt)

	## Desvia de obstaculos: sem progresso por 1 s, contorna para um lado por um tempo; _stuck_t acumula o tempo preso.
	var _detour_t := 0.0
	var _detour_s := 1.0
	var _prog_t := 0.0
	func _steer(dir: Vector2, dt: float) -> Vector2:
		_prog_t += dt
		if _prog_t > 1.0:
			if position.distance_to(_last_p) < 0.35:
				_stuck_t += _prog_t
				_detour_t = randf_range(1.0, 2.0)
				_detour_s = -_detour_s if randf() < 0.5 else _detour_s
			else:
				_stuck_t = maxf(0.0, _stuck_t - 0.5)
			_prog_t = 0.0
			_last_p = position
		if _detour_t > 0.0:
			_detour_t -= dt
			return dir.rotated(_detour_s * 1.4)
		return dir

	## Construtor: primeiro conserta blocos quebrados da vila, depois ergue a casa do lote, bloco a bloco.
	func _build(dt: float) -> Variant:
		var w := mgr.world
		var tgt: Array = []
		var from_damage := false
		for k in range(w.village_damage.size() - 1, -1, -1):
			var e: Array = w.village_damage[k]
			var pp: Vector3i = e[0]
			if Vector2(pp.x - home.x, pp.z - home.z).length() > 48.0:
				continue
			var cur := w.get_block(pp.x, pp.y, pp.z)
			if cur != 0 and Blocks.FLUID[cur] == 0:
				w.village_damage.remove_at(k)
				continue
			tgt = e
			from_damage = true
			break
		if tgt.is_empty() and npc_extra.has("plot"):
			if _plan.is_empty():
				_plan = w.gen.structs.plan_blocks(npc_extra["plot"], pal)
			while _plan_i < _plan.size():
				var e2: Array = _plan[_plan_i]
				var p2: Vector3i = e2[0]
				if not w.is_loaded(p2.x, p2.z):
					return null
				if w.get_block(p2.x, p2.y, p2.z) == int(e2[1]):
					_plan_i += 1
					continue
				tgt = e2
				break
		if tgt.is_empty():
			return null
		var p: Vector3i = tgt[0]
		var c := Vector3(p) + Vector3(0.5, 0, 0.5)
		var to_c := Vector2(c.x - position.x, c.z - position.z)
		if to_c.length() > 3.2:
			# Muito tempo sem conseguir chegar: da a volta por fora (reaparece perto da obra).
			if to_c.length() < _best_d - 0.5:
				_best_d = to_c.length()
				_best_t = 0.0
			_best_t += dt
			if _stuck_t > 10.0 or _best_t > 9.0:
				_stuck_t = 0.0
				_best_t = 0.0
				_best_d = INF
				var fy := w.find_floor(p.x + 2, p.z - 2, p.y - 4, p.y + 8)
				if fy > 0:
					position = Vector3(p.x + 2.5, fy, p.z - 1.5)
			return _steer(to_c.normalized() * 0.6, dt)
		_stuck_t = 0.0
		_best_d = INF
		_best_t = 0.0
		# Nao se empareda: sai da celula antes de colocar um bloco solido nela.
		if Blocks.SOLID[int(tgt[1])] == 1 and Vector2(c.x - position.x, c.z - position.z).length() < 0.9 				and p.y >= floori(position.y) - 1 and p.y <= floori(position.y) + 1:
			return Vector2(position.x - c.x, position.z - c.z).normalized().rotated(0.3) * 0.6
		_face_to(c - position, dt)
		_place_t -= dt
		if _place_t <= 0.0:
			_place_t = 0.55
			rig.attack()
			# Nao constroi dentro de quem estiver no caminho.
			var pl = mgr.nearest_player(c)
			var blocked: bool = Blocks.SOLID[int(tgt[1])] == 1 and pl.position.distance_to(c + Vector3(0, 0.5, 0)) < 1.1
			if not blocked and w.set_block(p, int(tgt[1]), int(tgt[2])):
				if from_damage:
					w.village_damage.erase(tgt)
				else:
					_plan_i += 1
		return Vector2.ZERO

	func set_sheared(on: bool) -> void:
		sheared = on
		wool_t = 300.0 if on else 0.0
		for n: Node3D in rig.groups.get("la", []):
			n.visible = not on

	func _produce(dt: float) -> void:
		milk_t = maxf(0.0, milk_t - dt)
		if kind == "galinha":
			egg_t -= dt
			if egg_t <= 0.0:
				if egg_t > -1000.0 and mgr.player != null and position.distance_to(mgr.player.position) < 48.0:
					mgr.drop(Items.find("Ovo"), position + Vector3(0, 0.3, 0))
				egg_t = randf_range(90.0, 180.0)
		if sheared:
			wool_t -= dt
			if wool_t <= 0.0:
				set_sheared(false)

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
		_produce(dt)
		_voice_tick(dt)
		if rider != null:
			if not is_instance_valid(rider) or rider.vehicle != self:
				rider = null
			else:
				_ride(dt)
				return
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
		var pl = mgr.nearest_player(position)
		var to_p: Vector3 = pl.position - position
		var dist := to_p.length()
		var speed: float = d["speed"]
		var want := Vector2.ZERO
		var hostile: bool = d["hostile"] or angry
		var guarding := false
		if profession == "guarda":
			if think_t <= 0.0 or (foe != null and (not is_instance_valid(foe) or foe.dead_t >= 0.0)):
				foe = mgr.nearest_hostile(position, 16.0)
			if foe != null and is_instance_valid(foe) and foe.dead_t < 0.0:
				guarding = true
				var tf: Vector3 = foe.position - position
				var dir3 := Vector2(tf.x, tf.z).normalized()
				want = dir3
				speed = 3.2
				if tf.length() < 2.0 and attack_cd <= 0.0:
					attack_cd = 0.8
					rig.attack()
					if randf() < 0.3:
						voice("talk")
					foe.hurt(6.0, position)
		if guarding:
			pass
		elif hostile and dist < 24.0 and pl.alive:
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
					if randf() < 0.6:
						voice("attack")
					mgr.shoot(position + Vector3(0, 1.4, 0), pl.position + Vector3(0, 1.2, 0), false, d["dmg"], 26.0, kind)
			else:
				want = dir2
				if dist < d["reach"] and attack_cd <= 0.0 and absf(to_p.y) < 2.0:
					attack_cd = 1.0
					rig.attack()
					if randf() < 0.6:
						voice("attack", 1.0)
					pl.damage(d["dmg"], position)
		elif flee_t > 0.0 or (d.get("skittish", false) and dist < 6.0):
			want = -Vector2(to_p.x, to_p.z).normalized()
			speed *= 1.8
		else:
			# Aldeoes: trabalho, conversa, ronda e obra tem prioridade sobre o passeio.
			var job: Variant = _npc_job(dt) if d.get("npc", false) and village != "" else null
			if job != null:
				think_t = maxf(think_t, 0.3)
				goal = Vector3.INF
			if think_t <= 0.0:
				think_t = randf_range(3.0, 8.0)
				if randf() < 0.65:
					# Escolhe um ponto proximo; animais tendem a ficar perto do rebanho.
					var tgt := position + Vector3(randf_range(-8.0, 8.0), 0, randf_range(-8.0, 8.0))
					var mate: Variant = mgr.nearest_kind(self, 14.0)
					if mate != null and not d.get("npc", false) and randf() < 0.6:
						tgt = mate.position + Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
					# NPCs ficam perto de casa; animais do curral ficam dentro da cerca.
					var penned: bool = village != "" and not d.get("npc", false)
					if penned:
						tgt = home + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.0, 2.0))
					elif d.get("npc", false) and Vector2(position.x - home.x, position.z - home.z).length() > 16.0:
						tgt = home
					goal = tgt
				else:
					goal = Vector3.INF
					idle_t = randf_range(1.5, 4.0)
			if goal != Vector3.INF:
				var to_g := Vector2(goal.x - position.x, goal.z - position.z)
				if to_g.length() < 0.8:
					goal = Vector3.INF
				else:
					# Desacelera ao chegar.
					wander_dir = to_g.normalized() * clampf(to_g.length() / 2.0, 0.35, 1.0)
			else:
				wander_dir = wander_dir.lerp(Vector2.ZERO, 1.0 - exp(-dt * 3.0))
			if wander_dir.length() > 0.05 and not _safe_ahead(wander_dir.normalized()):
				goal = Vector3.INF
				wander_dir = -wander_dir * 0.5
				think_t = randf_range(0.5, 1.5)
			want = wander_dir * 0.55 * breed_speed
			if job != null:
				want = job
			# Olha para o jogador quando ele esta perto.
			if dist < 7.0 and pl.alive:
				var rel := wrapf(atan2(-to_p.x, -to_p.z) - facing, -PI, PI)
				rig.look_yaw = clampf(rel, -0.9, 0.9)
			else:
				rig.look_yaw = 0.0
			if d.get("npc", false) and dist < 3.0 and pl.alive:
				want = Vector2.ZERO
				var dir2 := Vector2(to_p.x, to_p.z).normalized()
				facing = lerp_angle(facing, atan2(-dir2.x, -dir2.y), 1.0 - exp(-dt * 6.0))
		if d.get("flyer", false):
			var target_y: float = pl.position.y + 1.0 if hostile else position.y
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
			var acc := 7.0 if hostile or flee_t > 0.0 else 3.0
			vel.x = lerpf(vel.x, want.x * speed, 1.0 - exp(-dt * acc))
			vel.z = lerpf(vel.z, want.y * speed, 1.0 - exp(-dt * acc))
		if want.length() > 0.05 and not ranged:
			# Vira com inercia: devagar passeando, rapido fugindo ou atacando.
			var turn := 7.0 if hostile or flee_t > 0.0 else 2.6
			facing = lerp_angle(facing, atan2(-want.x, -want.y), 1.0 - exp(-dt * turn))
		var cx := floori(position.x)
		var cz := floori(position.z)
		if not w.is_loaded(cx, cz):
			return
		var r := Mobs.move_box(w, position, vel * dt, d["w"], d["h"])
		position = r[0]
		on_ground = r[1]
		if on_ground and vel.y < 0.0:
			vel.y = 0.0
		if r[2] and on_ground and want.length() > 0.1 and not d.get("hopper", false) and not (village != "" and not d.get("npc", false)):
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
	if puppet_mode:
		_update_puppets(dt)
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
	var later: Array = []
	while not world.pending_npcs.is_empty():
		var np: Array = world.pending_npcs.pop_front()
		var vid: String = np[3]
		var pos: Vector3 = np[0]
		# Cada morador/animal da vila nasce uma vez por sessao (os chunks podem recarregar).
		var key := "%s|%s|%d|%d|%d" % [vid, np[1], floori(pos.x), floori(pos.z), int(np[2])]
		if _villages.has(key):
			continue
		if not world.is_loaded(floori(pos.x), floori(pos.z)):
			if pos.distance_to(player.position) < 90.0:
				later.append(np)
			continue
		# Chao livre perto da altura planejada (evita nascer em cima de telhados).
		var fy := world.find_floor(floori(pos.x), floori(pos.z), floori(pos.y) - 3, floori(pos.y) + 3)
		if fy < 0:
			fy = world.surface_y(floori(pos.x), floori(pos.z)) + 1
		var m := spawn(np[1], Vector3(pos.x, fy, pos.z), int(np[2]))
		m.home = m.position
		m.village = vid
		if np.size() > 4:
			m.npc_extra = np[4]
			m.pal = str(np[5]) if np.size() > 5 else "planicie"
		if m.d.get("npc", false):
			m.equip_npc()
		_villages[key] = 1
	world.pending_npcs.append_array(later)
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
					var kinds := ["andarilho", "esqueleto", "aranha", "gosma", "andarilho", "aranha", "goblin"]
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
			var kinds := ["andarilho", "andarilho", "esqueleto", "aranha", "gosma", "espectro", "goblin", "goblin"]
			if bio == WorldGen.B_MOUNTAIN or bio == WorldGen.B_PEAK:
				kinds.append("golem")
				kinds.append("ogro")
			if bio == WorldGen.B_FOREST:
				kinds.append("ogro")
			if bio == WorldGen.B_DESERT:
				kinds = ["mumia", "mumia", "mumia", "esqueleto", "aranha"]
			spawn(kinds[_rng.randi() % kinds.size()], pos)
		return
	if _count(false) >= PASSIVE_CAP:
		return
	var choices: Array = []
	match bio:
		WorldGen.B_PLAINS: choices = ["vaca", "porco", "ovelha", "galinha", "coelho", "cavalo", "cavalo", "burro", "pato"]
		WorldGen.B_FOREST: choices = ["vaca", "porco", "galinha", "cervo", "coelho", "lobo", "raposa", "urso", "cavalo"]
		WorldGen.B_SNOW: choices = ["coelho", "cervo", "lobo", "ovelha", "raposa", "urso"]
		WorldGen.B_DESERT: choices = ["coelho", "camelo", "camelo"]
		WorldGen.B_MOUNTAIN: choices = ["ovelha", "cervo", "golem", "cabra", "cabra"]
	if choices.is_empty():
		return
	var kind: String = choices[_rng.randi() % choices.size()]
	# Rebanhos: animais de fazenda aparecem em grupos, da mesma raca regional.
	var herd := 1 if kind in ["lobo", "golem", "cervo", "urso", "raposa"] else _rng.randi_range(2, 4)
	var breed := -1
	match kind:
		"raposa": breed = 1 if bio == WorldGen.B_SNOW else (_rng.randi() % 2) * 2
		"urso": breed = 2 if bio == WorldGen.B_SNOW else _rng.randi() % 2
		"cabra": breed = 3 if _rng.randf() < 0.5 else _rng.randi() % 3
	for i in herd:
		var off := Vector3(_rng.randf_range(-2.5, 2.5), 0, _rng.randf_range(-2.5, 2.5))
		var hx := floori(pos.x + off.x)
		var hz := floori(pos.z + off.z)
		spawn(kind, Vector3(hx + 0.5, world.surface_y(hx, hz) + 1.0, hz + 0.5), breed)


func spawn(kind: String, pos: Vector3, variant: int = -1) -> Mob:
	var m := Mob.new()
	if variant < 0:
		variant = _rng.randi() % 12
	m.setup(kind, self, variant)
	_next_nid += 1
	m.net_id = _next_nid
	m.position = pos
	add_child(m)
	mobs.append(m)
	return m


## Jogador vivo mais perto (local ou outro jogador conectado).
func nearest_player(pos: Vector3) -> Variant:
	var best: Variant = player
	var bd: float = player.position.distance_to(pos) if player.alive else INF
	if net != null:
		for r in net.remotes.values():
			if is_instance_valid(r) and r.alive:
				var dd: float = r.position.distance_to(pos)
				if dd < bd:
					bd = dd
					best = r
	return best


## Multijogador: liga/desliga o modo boneco (este peer nao simula criaturas).
func set_puppet_mode(on: bool) -> void:
	if on == puppet_mode:
		return
	puppet_mode = on
	clear_all()
	_puppets.clear()
	_villages.clear()


## Estado compacto das criaturas simuladas aqui, 10 floats cada (cabe num pacote):
## [id, especie, variante, x, y, z, direcao, velocidade, bits (1 tosquiada, 2 morta), sela].
const SNAP := 10
var _next_nid := 0
static var KINDS: Array = []


func snapshot() -> PackedFloat32Array:
	if KINDS.is_empty():
		KINDS = DEFS.keys()
	var out := PackedFloat32Array()
	for m in mobs:
		if not is_instance_valid(m) or m.is_queued_for_deletion() or m.puppet_id != 0:
			continue
		var bits := (1 if m.sheared else 0) | (2 if m.dead_t >= 0.0 else 0)
		out.append_array([m.net_id, KINDS.find(m.kind), m.variant, m.position.x, m.position.y, m.position.z, m.facing,
			Vector2(m.vel.x, m.vel.z).length(), bits, m.saddle])
	return out


## Atualiza os bonecos a partir do estado recebido do simulador.
func apply_snapshot(snap: PackedFloat32Array) -> void:
	if KINDS.is_empty():
		KINDS = DEFS.keys()
	var seen := {}
	for k in range(0, snap.size() - SNAP + 1, SNAP):
		var iid := int(snap[k])
		var ki := int(snap[k + 1])
		if ki < 0 or ki >= KINDS.size():
			continue
		seen[iid] = true
		var pos := Vector3(snap[k + 3], snap[k + 4], snap[k + 5])
		var bits := int(snap[k + 8])
		var m: Variant = _puppets.get(iid)
		if m == null or not is_instance_valid(m):
			m = spawn(KINDS[ki], pos, int(snap[k + 2]))
			m.set_physics_process(false)
			m.puppet_id = iid
			m.facing = snap[k + 6]
			_puppets[iid] = m
		m.net_pos = pos
		m.net_yaw = snap[k + 6]
		m.net_speed = snap[k + 7]
		if bool(bits & 1) != m.sheared:
			m.set_sheared(bool(bits & 1))
		if int(snap[k + 9]) != m.saddle:
			m.set_saddle(int(snap[k + 9]))
		if (bits & 2) != 0 and m.dead_t < 0.0:
			m.dead_t = 0.0
	for iid: int in _puppets.keys():
		if not seen.has(iid):
			var m2: Variant = _puppets[iid]
			if is_instance_valid(m2):
				m2.queue_free()
			_puppets.erase(iid)


func _update_puppets(dt: float) -> void:
	var k := mobs.size() - 1
	while k >= 0:
		var m = mobs[k]
		if not is_instance_valid(m) or m.is_queued_for_deletion():
			mobs.remove_at(k)
			k -= 1
			continue
		if m.dead_t >= 0.0:
			m.dead_t += dt
			m.rig.rotation.z = minf(m.dead_t * 6.0, PI * 0.5)
		else:
			m.position = m.position.lerp(m.net_pos, 1.0 - exp(-dt * 10.0))
			m.facing = lerp_angle(m.facing, m.net_yaw, 1.0 - exp(-dt * 10.0))
			m.rig.rotation.y = m.facing
			m.flash = maxf(0.0, m.flash - dt * 4.0)
			m.rig.set_flash(m.flash)
			m.rig.animate(dt, m.net_speed, true)
			m._voice_tick(dt)
		k -= 1


## Golpe recebido pela rede numa criatura simulada aqui.
func hit_by_id(iid: int, amount: float, from: Vector3) -> void:
	for m in mobs:
		if is_instance_valid(m) and m.net_id == iid:
			var was: bool = m.hp > 0.0
			m.hurt(amount, from)
			return


func nearest_hostile(pos: Vector3, radius: float) -> Variant:
	var best: Variant = null
	var bd := radius
	for o in mobs:
		if not is_instance_valid(o) or o.dead_t >= 0.0 or not bool(o.d["hostile"]) or o.d.get("npc", false):
			continue
		var dd: float = o.position.distance_to(pos)
		if dd < bd:
			bd = dd
			best = o
	return best


## Criatura da mesma especie mais proxima (para andar em rebanho).
## Outro aldeao perto (para conversar).
func nearest_villager(m: Mob, radius: float) -> Variant:
	var best: Variant = null
	var bd := radius
	for o in mobs:
		if o == m or not is_instance_valid(o) or o.kind != "aldeao" or o.dead_t >= 0.0 or o.profession == "guarda":
			continue
		var dd: float = o.position.distance_to(m.position)
		if dd < bd:
			bd = dd
			best = o
	return best


## Id do item ou bloco pelo nome usado nas trocas.
static func trade_id(n: String) -> int:
	if n == "":
		return 0
	if n == "cortina":
		return Blocks.WOOL_0 + 3
	if TRADE_BLOCKS.has(n):
		return _block_const(TRADE_BLOCKS[n])
	return Items.find(n)


static func _block_const(c: String) -> int:
	match c:
		"WOOL_0": return Blocks.WOOL_0
		"BOOKSHELF": return Blocks.BOOKSHELF
		"LOG": return Blocks.LOG
		"PLANKS": return Blocks.PLANKS
		"BRICKS": return Blocks.BRICKS
		"BED": return Blocks.BED
		"CHAIR": return Blocks.CHAIR
		"TABLE": return Blocks.TABLE
		"TORCH": return Blocks.TORCH
		"LANTERN": return Blocks.LANTERN
		"STONE_BRICKS": return Blocks.STONE_BRICKS
	return 0


func nearest_kind(m: Mob, radius: float) -> Variant:
	var best: Variant = null
	var bd := radius
	for o in mobs:
		if o == m or not is_instance_valid(o) or o.kind != m.kind:
			continue
		var dd: float = o.position.distance_to(m.position)
		if dd < bd and dd > 2.5:
			bd = dd
			best = o
	return best


## La da cor da ovelha.
func wool_of(m: Mob) -> int:
	match Rigs.variant_name(m.kind, m.variant):
		"cinza": return Blocks.WOOL_0 + 1
		"preta": return Blocks.WOOL_0 + 2
		"marrom": return Blocks.WOOL_0 + 11
	return Blocks.WOOL_0


func on_death(m: Mob) -> void:
	_forget(m)
	if m.rider != null and is_instance_valid(m.rider):
		m.rider.vehicle = null
		m.rider = null
	if m.saddle > 0:
		drop(m.saddle, m.position + Vector3(0, 1.0, 0))
	var luck: float = player.stats.loot_chance() if player != null else 0.0
	for dr: Array in m.d.get("drops", []):
		var n := _rng.randi_range(dr[1], dr[2])
		if _rng.randf() < luck:
			n += 1
		var id := Items.find(dr[0])
		for i in n:
			drop(id, m.position + Vector3(0, 0.5, 0))
	if m.d.has("block_drop") and not m.sheared:
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
	var offers: Array = TRADES.get(m.profession, [])
	if m.profession == "guarda":
		return "Guarda: a vila está segura enquanto eu estiver de vigia."
	if offers.is_empty():
		return title + ": " + GREETINGS[m.variant % GREETINGS.size()]
	if not trade:
		m.trade_shown = m.trade_i % offers.size()
		m.trade_i += 1
	var t: Array = offers[m.trade_shown % offers.size()]
	var give := trade_id(t[0])
	var get_id := trade_id(t[2])
	var offer := "%s: troco %d %s por %d %s." % [title, t[1], Items.name_of(give), t[3], Items.name_of(get_id)]
	if not trade:
		var more := "  (oferta %d/%d - clique de novo para ver outra)" % [m.trade_shown + 1, offers.size()] if offers.size() > 1 else ""
		return offer + more + "  (Shift + clique direito para trocar)"
	if inv.count(give) < int(t[1]):
		return "%s: você precisa de %d %s." % [title, t[1], t[0]]
	inv.remove(give, t[1])
	var left := inv.add(get_id, t[3])
	if left > 0:
		drop(get_id, player.position + Vector3(0, 1, 0), left)
	return "%s: negócio fechado! (+%d %s)" % [title, t[3], Items.name_of(get_id)]
