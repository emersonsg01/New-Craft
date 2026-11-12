class_name Stats
extends RefCounted
## Nivel do personagem, experiencia e atributos.
## Cada nivel da 3 pontos para distribuir. Os atributos alteram dano, mineracao, velocidade,
## folego (tempo embaixo d'agua), estamina (correr/pular) e mana (feiticos).

const KEYS: Array[String] = ["forca", "inteligencia", "percepcao", "velocidade", "folego", "estamina", "mana"]
const NAMES := {
	"forca": "Força", "inteligencia": "Inteligência", "percepcao": "Percepção", "velocidade": "Velocidade",
	"folego": "Fôlego", "estamina": "Estamina", "mana": "Mana",
}
const DESCS := {
	"forca": "+6% dano corpo a corpo e +4% velocidade de mineração por ponto",
	"inteligencia": "+8% poder dos feitiços, +3% experiência e regeneração de mana",
	"percepcao": "+3% chance de crítico, +4% dano à distância e chance de saque extra",
	"velocidade": "+2,5% velocidade de movimento e ataques mais rápidos",
	"folego": "+2 s de ar embaixo d'água e nado mais rápido",
	"estamina": "+10 de estamina máxima e recuperação mais rápida",
	"mana": "+10 de mana máxima e regeneração de mana",
}
const MAX_ATTR := 50
const POINTS_PER_LEVEL := 3

var level := 1
var xp := 0.0
var points := 0
var attrs := {}

# Recursos atuais.
var stamina := 100.0
var mana := 50.0
var breath := 10.0


func _init() -> void:
	for k in KEYS:
		attrs[k] = 0
	stamina = max_stamina()
	mana = max_mana()
	breath = max_breath()


func xp_needed() -> float:
	return 30.0 + (level - 1) * 22.0 + pow(level - 1, 1.6) * 4.0


func get_attr(k: String) -> int:
	return int(attrs.get(k, 0))


## Soma experiencia (ja multiplicada pela inteligencia). Devolve quantos niveis subiu.
func add_xp(amount: float) -> int:
	xp += amount * (1.0 + 0.03 * get_attr("inteligencia"))
	var ups := 0
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		points += POINTS_PER_LEVEL
		ups += 1
	if ups > 0:
		stamina = max_stamina()
		mana = max_mana()
	return ups


func spend(k: String) -> bool:
	if points <= 0 or get_attr(k) >= MAX_ATTR:
		return false
	attrs[k] = get_attr(k) + 1
	points -= 1
	return true


# ---------- valores derivados ----------

func melee_mult() -> float:
	return 1.0 + 0.06 * get_attr("forca")


func mine_mult() -> float:
	return 1.0 + 0.04 * get_attr("forca")


func spell_mult() -> float:
	return 1.0 + 0.08 * get_attr("inteligencia")


func crit_chance() -> float:
	return minf(0.6, 0.03 * get_attr("percepcao"))


func ranged_mult() -> float:
	return 1.0 + 0.04 * get_attr("percepcao")


func loot_chance() -> float:
	return minf(0.5, 0.02 * get_attr("percepcao"))


func move_mult() -> float:
	return 1.0 + 0.025 * get_attr("velocidade")


func attack_cd_mult() -> float:
	return 1.0 / (1.0 + 0.03 * get_attr("velocidade"))


func swim_mult() -> float:
	return 1.0 + 0.03 * get_attr("folego")


func max_breath() -> float:
	return 10.0 + 2.0 * get_attr("folego")


func max_stamina() -> float:
	return 100.0 + 10.0 * get_attr("estamina")


func stamina_regen() -> float:
	return 16.0 + 1.5 * get_attr("estamina")


func max_mana() -> float:
	return 50.0 + 10.0 * get_attr("mana")


func mana_regen() -> float:
	return 1.5 + 0.25 * get_attr("inteligencia") + 0.2 * get_attr("mana")


# ---------- salvar/carregar ----------

func to_dict() -> Dictionary:
	return {"level": level, "xp": xp, "points": points, "attrs": attrs.duplicate(), "stamina": stamina, "mana": mana}


func from_dict(d: Dictionary) -> void:
	level = int(d.get("level", 1))
	xp = float(d.get("xp", 0.0))
	points = int(d.get("points", 0))
	var a: Dictionary = d.get("attrs", {})
	for k in KEYS:
		attrs[k] = int(a.get(k, 0))
	stamina = minf(float(d.get("stamina", max_stamina())), max_stamina())
	mana = minf(float(d.get("mana", max_mana())), max_mana())
	breath = max_breath()
