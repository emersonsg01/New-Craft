extends SceneTree
## Gera um projeto do Blockbench (.bbmodel, formato "Modelo padrao") para cada criatura e variante,
## a partir dos desenhos de Rigs, com textura pintada em alta resolucao (ate 1024 px).
## O jogo le esses mesmos arquivos (BBModel.gd): edite no Blockbench, salve, e o jogo usa a versao nova.
##   godot --headless --path . --script res://tools/bb_export_specs.gd [--force]
## Sem --force, arquivos que ja existem (possivelmente editados a mao) sao preservados.

const OUT := "res://assets/blockbench/"
const FACE_NAMES := ["east", "west", "up", "down", "south", "north"]
## Pixels de textura por voxel (1/16 de bloco). Reduz automaticamente se o atlas passar de 1024.
const PPV := 8
const MAX_TEX := 1024

var _meta := {}


func _initialize() -> void:
	Rigs.use_bbmodel = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var force := OS.get_cmdline_user_args().has("--force") or OS.get_cmdline_args().has("--force")
	var meta_path := ProjectSettings.globalize_path(OUT + "creatures.json")
	if FileAccess.file_exists(meta_path):
		_meta = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	var n := 0
	var kept := 0
	for k: String in Mobs.DEFS:
		if k in ["aldeao", "bandido"]:
			continue
		var vars: Array = Rigs.VARIANTS.get(k, [])
		for v in maxi(1, vars.size()):
			var name := "%s_%d" % [k, v]
			var path := ProjectSettings.globalize_path(OUT + name + ".bbmodel")
			var d := Rigs.mob(k, v)
			_meta[name] = {"anim": d.get("anim", "biped"), "scale": d.get("scale", 1.0), "pose": d.get("pose", ""),
				"alpha": d.get("alpha", false), "back": _v3(d.get("back", Vector3.ZERO)), "bw": d.get("bw", 0), "bl": d.get("bl", 0)}
			if FileAccess.file_exists(path) and not force:
				kept += 1
				continue
			_export(name, d, path)
			n += 1
	var f := FileAccess.open(meta_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(_meta, "\t"))
	f.close()
	print("modelos gerados: ", n, "  preservados: ", kept)
	quit()


static func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _uuid(seed_s: String) -> String:
	var h := seed_s.sha256_text()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


## Pinta um texel de voxel em ppv x ppv pixels: ruido fino de pelagem/material, borda levemente
## escurecida, brilho no topo e sombra embaixo (oclusao).
static func _paint_voxel(img: Image, ox: int, oy: int, ppv: int, col: Color, face: int, u: int, w: int, fw: int, fh: int, seed_v: int) -> void:
	if col.a < 0.01:
		return
	for py in ppv:
		for px in ppv:
			var hsh := WorldGen._hash32(u * ppv + px + face * 997, w * ppv + py, seed_v * 13 + 7) & 1023
			var n := (hsh / 1023.0 - 0.5) * 0.10
			# Gradiente vertical sutil nas laterais (luz de cima) e oclusao perto das arestas.
			var gy := (float(w * ppv + py) / maxf(1.0, fh * ppv))
			var shade := 1.0
			if face != 2 and face != 3:
				shade *= 1.04 - gy * 0.10
			var ex := minf(float(u * ppv + px), float(fw * ppv - 1 - (u * ppv + px)))
			var ey := minf(float(w * ppv + py), float(fh * ppv - 1 - (w * ppv + py)))
			var edge := clampf(minf(ex, ey) / maxf(1.0, ppv * 0.75), 0.0, 1.0)
			shade *= 0.90 + 0.10 * edge
			var f := shade + n
			img.set_pixel(ox + px, oy + py, Color(col.r * f, col.g * f, col.b * f, col.a))


func _export(name: String, d: Dictionary, path: String) -> void:
	var parts: Array = d["parts"]
	var ppv := PPV
	var place := {}
	var rects: Array = []
	var tw := 0
	var th := 0
	# Empacota as faces; se nao couber em 1024, reduz os pixels por voxel.
	while true:
		rects.clear()
		for i in parts.size():
			var s: Vector3i = parts[i]["size"]
			for f in 6:
				var w := s.z if f < 2 else s.x
				var h := s.z if (f == 2 or f == 3) else s.y
				rects.append([i, f, maxi(w, 1), maxi(h, 1)])
		var order := range(rects.size())
		order.sort_custom(func(a: int, b: int) -> bool: return rects[a][3] > rects[b][3])
		var area := 0
		for r: Array in rects:
			area += int(r[2]) * int(r[3]) * ppv * ppv
		tw = clampi(nearest_po2(int(sqrt(area * 1.3))), 64, MAX_TEX)
		var x := 0
		var y := 0
		var shelf := 0
		place.clear()
		for oi: int in order:
			var r: Array = rects[oi]
			var rw := int(r[2]) * ppv
			if x + rw > tw:
				x = 0
				y += shelf
				shelf = 0
			place[oi] = Vector2i(x, y)
			x += rw
			shelf = maxi(shelf, int(r[3]) * ppv)
		th = nearest_po2(maxi(y + shelf, 16))
		if th <= MAX_TEX or ppv <= 1:
			break
		ppv = maxi(1, ppv / 2)
	var img := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var elements: Array = []
	var groups: Array = []
	var seed_v := 1
	for i in parts.size():
		seed_v += 7
		var p: Dictionary = parts[i]
		var s: Vector3i = p["size"]
		var faces := {}
		for f in 6:
			var ri := i * 6 + f
			var o: Vector2i = place[ri]
			var w: int = rects[ri][2]
			var h: int = rects[ri][3]
			for ww in h:
				for uu in w:
					var col := VoxelArt._texel(f, uu, ww, p["col"], p.get("spk", 0.12) * 0.6, p.get("feats", []), seed_v)
					# Orientacao do Blockbench: norte e leste espelhados na horizontal; base na vertical.
					var cx := uu
					var cy := ww
					if f == 5 or f == 0:
						cx = w - 1 - uu
					if f == 3:
						cy = h - 1 - ww
					_paint_voxel(img, o.x + cx * ppv, o.y + cy * ppv, ppv, col, f, uu, ww, w, h, seed_v)
			faces[FACE_NAMES[f]] = {"uv": [o.x, o.y, o.x + w * ppv, o.y + h * ppv], "texture": 0}
		var pos: Vector3 = p["pos"]
		var pivot: Vector3 = p.get("pivot", pos + Vector3(s) * 0.5)
		var cu := _uuid(name + ":c" + str(i))
		elements.append({"name": "cubo", "box_uv": false, "rescale": false, "locked": false, "render_order": "default",
			"from": _v3(pos), "to": _v3(pos + Vector3(s)), "autouv": 0, "color": i % 8, "origin": _v3(pivot),
			"inflate": (s.x + s.y + s.z) / 3.0 * float(p.get("infl", 0.0)) * 0.5, "faces": faces, "type": "cube", "uuid": cu})
		var g: String = p.get("g", "")
		groups.append({"name": ("%s__%d" % [g, i]) if g != "" else "parte__%d" % i, "origin": _v3(pivot), "color": 0,
			"uuid": _uuid(name + ":g" + str(i)), "export": true, "isOpen": false, "locked": false, "visibility": true,
			"autouv": 0, "children": [cu], "parent": int(p.get("parent_i", -1))})
	# Arvore de ossos: filhos aninhados dentro do pai.
	var roots: Array = []
	for i in range(groups.size() - 1, -1, -1):
		var gi: Dictionary = groups[i]
		var par: int = gi["parent"]
		gi.erase("parent")
		if par >= 0:
			(groups[par]["children"] as Array).append(gi)
		else:
			roots.push_front(gi)
	var png := img.save_png_to_buffer()
	var bb := {
		"meta": {"format_version": "4.10", "model_format": "free", "box_uv": false},
		"name": name, "model_identifier": "", "visible_box": [1, 1, 0],
		"variable_placeholders": "", "variable_placeholder_buttons": [], "timeline_setups": [], "unhandled_root_fields": {},
		"resolution": {"width": tw, "height": th},
		"elements": elements, "outliner": roots,
		"textures": [{"path": "", "name": name + ".png", "folder": "", "namespace": "", "id": "0", "width": tw, "height": th,
			"uv_width": tw, "uv_height": th, "particle": false, "use_as_default": false, "layers_enabled": false, "sync_to_project": "",
			"render_mode": "default", "render_sides": "auto", "frame_time": 1, "frame_order_type": "loop", "frame_order": "",
			"frame_interpolate": false, "visible": true, "internal": true, "saved": true, "uuid": _uuid(name + ":t"),
			"source": "data:image/png;base64," + Marshalls.raw_to_base64(png)}],
	}
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	f2.store_string(JSON.stringify(bb))
	f2.close()
