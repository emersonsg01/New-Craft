class_name Saves
extends RefCounted
## Mundos salvos (jogo solo e servidor) e servidores favoritos.
## Cada mundo tem um arquivo de dados (<id>.save) e um arquivo pequeno de informacoes (<id>.json)
## com nome, semente, dia e ultima vez jogado, para a lista abrir rapido.

const DIR_SOLO := "user://mundos/"
const DIR_SERVER := "user://servidor_mundos/"
const FAVORITES := "user://servidores.json"
const LEGACY_SOLO := "user://world_v4.save"
const LEGACY_SERVER := "user://servidor.save"

## Mundo escolhido na tela inicial: {"id", "path", "name", "seed"} (sobrevive ao recarregar a cena).
static var current: Dictionary = {}
## Aviso para mostrar na tela inicial (ex.: falha ao conectar).
static var title_message := ""


# ---------------------------------------------------------------- mundos

## Lista os mundos de uma pasta, do jogado mais recentemente para o mais antigo.
static func list_worlds(dir: String = DIR_SOLO) -> Array:
	_migrate(dir)
	var out: Array = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for fn in da.get_files():
		if not fn.ends_with(".json"):
			continue
		var id := fn.trim_suffix(".json")
		var meta := read_meta(dir, id)
		if meta.is_empty():
			continue
		meta["id"] = id
		meta["path"] = dir + id + ".save"
		meta["exists"] = FileAccess.file_exists(dir + id + ".save")
		out.append(meta)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("played", 0)) > float(b.get("played", 0)))
	return out


static func read_meta(dir: String, id: String) -> Dictionary:
	var f := FileAccess.open(dir + id + ".json", FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Dictionary else {}


static func write_meta(dir: String, id: String, meta: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var m := meta.duplicate()
	m.erase("id")
	m.erase("path")
	m.erase("exists")
	var f := FileAccess.open(dir + id + ".json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(m, "\t"))


## Cria um mundo novo (o arquivo de dados nasce no primeiro salvamento). Semente vazia = aleatoria;
## texto que nao e numero vira semente pelo hash, como em outros jogos de blocos.
static func new_world(name: String, seed_text: String, dir: String = DIR_SOLO) -> Dictionary:
	name = name.strip_edges()
	if name == "":
		name = "Novo mundo"
	var seed_v := randi() & 0x3FFFFFFF
	seed_text = seed_text.strip_edges()
	if seed_text != "":
		seed_v = int(seed_text) if seed_text.is_valid_int() else (hash(seed_text) & 0x3FFFFFFF)
	var id := _slug(name)
	var base := id
	var n := 2
	while FileAccess.file_exists(dir + id + ".json"):
		id = "%s_%d" % [base, n]
		n += 1
	var meta := {"name": name, "seed": seed_v, "created": Time.get_unix_time_from_system(), "played": Time.get_unix_time_from_system(), "day": 0}
	write_meta(dir, id, meta)
	meta["id"] = id
	meta["path"] = dir + id + ".save"
	meta["exists"] = false
	return meta


static func delete_world(id: String, dir: String = DIR_SOLO) -> void:
	for ext in [".save", ".json"]:
		if FileAccess.file_exists(dir + id + ext):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + id + ext))


## Atualiza as informacoes depois de salvar o mundo.
static func touch(dir: String, id: String, extra: Dictionary) -> void:
	var meta := read_meta(dir, id)
	meta.merge(extra, true)
	meta["played"] = Time.get_unix_time_from_system()
	write_meta(dir, id, meta)


static func _slug(s: String) -> String:
	var t := s.to_lower()
	var from := "áàâãäéèêëíìîïóòôõöúùûüçñ"
	var to := "aaaaaeeeeiiiiooooouuuucn"
	var out := ""
	for ch in t:
		var k := from.find(ch)
		if k >= 0:
			ch = to[k]
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif not out.ends_with("_"):
			out += "_"
	out = out.strip_edges().trim_prefix("_").trim_suffix("_")
	return out if out != "" else "mundo"


## Traz o mundo antigo (um so arquivo) para a lista, uma vez.
static func _migrate(dir: String) -> void:
	var legacy := LEGACY_SOLO if dir == DIR_SOLO else LEGACY_SERVER
	var flag := dir + ".importado"
	if FileAccess.file_exists(flag) or not FileAccess.file_exists(legacy):
		DirAccess.make_dir_recursive_absolute(dir)
		return
	DirAccess.make_dir_recursive_absolute(dir)
	var id := "meu_mundo" if dir == DIR_SOLO else "mundo_do_servidor"
	DirAccess.copy_absolute(ProjectSettings.globalize_path(legacy), ProjectSettings.globalize_path(dir + id + ".save"))
	var seed_v := 0
	var day := 0
	var f := FileAccess.open(legacy, FileAccess.READ)
	if f != null:
		var v: Variant = f.get_var()
		if v is Dictionary:
			seed_v = int((v as Dictionary).get("seed", 0))
			day = int((v as Dictionary).get("day", 0))
	var mt := FileAccess.get_modified_time(legacy)
	write_meta(dir, id, {"name": "Meu mundo" if dir == DIR_SOLO else "Mundo do servidor", "seed": seed_v, "day": day, "created": mt, "played": mt})
	var fl := FileAccess.open(flag, FileAccess.WRITE)
	if fl != null:
		fl.store_string("ok")


static func describe(meta: Dictionary) -> String:
	var when := Time.get_datetime_string_from_unix_time(int(meta.get("played", 0)) - _tz(), true)
	var d := when.split(" ")
	var date := d[0].split("-")
	var dstr := "%s/%s/%s %s" % [date[2], date[1], date[0], d[1].substr(0, 5)] if date.size() == 3 and d.size() == 2 else when
	var mode := "  ·  criativo" if str(meta.get("mode", "survival")) == "creative" else ""
	return "Semente %d  ·  dia %d%s  ·  jogado em %s" % [int(meta.get("seed", 0)), int(meta.get("day", 0)) + 1, mode, dstr]


static func _tz() -> int:
	return -int(Time.get_time_zone_from_system().get("bias", 0)) * 60


# ---------------------------------------------------------------- servidores favoritos

static func favorites() -> Array:
	var f := FileAccess.open(FAVORITES, FileAccess.READ)
	if f == null:
		return []
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if v is Array else []


static func save_favorites(list: Array) -> void:
	var f := FileAccess.open(FAVORITES, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(list, "\t"))


static func add_favorite(name: String, address: String) -> void:
	var list := favorites()
	for s: Dictionary in list:
		if str(s.get("address", "")) == address:
			s["name"] = name
			save_favorites(list)
			return
	list.append({"name": name if name.strip_edges() != "" else address, "address": address})
	save_favorites(list)


static func remove_favorite(address: String) -> void:
	var list := favorites().filter(func(s: Dictionary) -> bool: return str(s.get("address", "")) != address)
	save_favorites(list)


## "ip:porta" -> [ip, porta].
static func parse_address(address: String) -> Array:
	var a := address.strip_edges()
	var port := Net.DEFAULT_PORT
	var k := a.rfind(":")
	if k > 0 and a.substr(k + 1).is_valid_int():
		port = int(a.substr(k + 1))
		a = a.substr(0, k)
	return [a if a != "" else "127.0.0.1", port]
