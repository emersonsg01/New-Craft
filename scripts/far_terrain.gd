class_name FarTerrain
extends Node3D
## Terreno distante com LOD em quadtree, 100% na GPU: o vertex shader avalia o mesmo ruido
## do gerador de chunks, entao nao ha malha nem textura de altura calculada na CPU.
## Cada folha do quadtree e a mesma grade 64x64 esticada; perto do jogador as folhas tem 128 m
## (um vertice a cada 2 m) e dobram de tamanho com a distancia ate 1024 m.

const GRID := 64
const MIN_TILE := 128.0
const ROOT_TILE := 8192.0

const SHADER_HEAD := """
shader_type spatial;
render_mode cull_back;

instance uniform vec3 tile = vec3(0.0, 0.0, 128.0);
uniform int world_seed = 0;
uniform float grid = 64.0;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 c_grass : source_color = vec3(0.2, 0.4, 0.1);
uniform vec3 c_dirt : source_color = vec3(0.35, 0.25, 0.15);
uniform vec3 c_stone : source_color = vec3(0.45, 0.45, 0.45);
uniform vec3 c_sand : source_color = vec3(0.85, 0.77, 0.55);
uniform vec3 c_snow : source_color = vec3(0.93, 0.95, 0.98);
uniform vec3 c_leaves : source_color = vec3(0.15, 0.33, 0.08);
uniform vec3 c_pine : source_color = vec3(0.08, 0.22, 0.12);
global uniform vec3 player_pos;
global uniform float lod_near;
global uniform float rain_wetness;
global uniform float season;
global uniform float snow_cover;
varying float v_snowable;
varying float v_green;

// Tinta sazonal da vegetacao: s em 0..4 (primavera, verao, outono, inverno).
vec3 season_tint(float s) {
	vec3 spring = vec3(0.92, 1.10, 0.86);
	vec3 summer = vec3(1.04, 1.00, 0.84);
	vec3 autumn = vec3(1.22, 0.92, 0.55);
	vec3 winter = vec3(0.86, 0.84, 0.74);
	float f = fract(s);
	int i = int(floor(s)) % 4;
	vec3 a = i == 0 ? spring : (i == 1 ? summer : (i == 2 ? autumn : winter));
	vec3 b = i == 0 ? summer : (i == 1 ? autumn : (i == 2 ? winter : spring));
	return mix(a, b, smoothstep(0.6, 1.0, f));
}

varying vec3 v_wpos;
varying vec3 v_n;
varying vec3 v_top;
varying vec3 v_side;
"""

const SHADER_BODY := """
// Altura da superficie (topo do bloco) com um "dossel" falso onde ha floresta.
vec4 far_surface(vec2 p, uint sd) {
	vec3 c = wg_column(p, sd);
	float h = c.x + 1.0;
	// Copa continua e arredondada: densidade da floresta modulada por ruido suave.
	float dens = c.y == 3.0 ? 0.8 : (c.y == 5.0 ? 0.5 : (c.y == 2.0 ? 0.1 : 0.0));
	float tree = 0.0;
	if (dens > 0.0 && c.x > 45.0) {
		float n = wg_noise(p * 0.09, sd + 77u) * 0.6 + wg_noise(p * 0.21, sd + 78u) * 0.3 + 0.5;
		tree = smoothstep(1.0 - dens, 1.0 - dens + 0.3, n);
		h += tree * 5.0;
	}
	return vec4(h, c.y, tree, c.x);
}

void vertex() {
	uint sd = uint(world_seed);
	vec2 xz = tile.xy + VERTEX.xz * tile.z;
	float st = tile.z / grid;
	vec4 s0 = far_surface(xz, sd);
	float hx = far_surface(xz + vec2(st, 0.0), sd).x;
	float hz = far_surface(xz + vec2(0.0, st), sd).x;
	vec3 n = normalize(vec3(s0.x - hx, st, s0.x - hz));
	float bio = s0.y;
	vec3 top = c_grass;
	vec3 side = c_dirt;
	if (bio < 1.5 || bio == 4.0) {
		top = c_sand;
		side = c_sand * 0.9;
	} else if (bio == 5.0) {
		top = c_snow;
	} else if (bio == 6.0) {
		top = c_stone;
		side = c_stone * 0.9;
	} else if (bio == 7.0) {
		top = c_snow;
		side = c_snow * 0.85;
	}
	if (s0.w < 44.0) {
		top = c_sand;
		side = c_sand * 0.9;
	}
	v_snowable = (bio < 1.5 || bio == 4.0 || s0.w < 44.0) ? 0.0 : 1.0;
	v_green = (bio == 2.0 || bio == 3.0) ? 1.0 : 0.0;
	vec3 canopy = bio == 5.0 ? c_pine : c_leaves;
	float cw = smoothstep(0.15, 0.55, s0.z);
	top = mix(top, canopy, cw);
	side = mix(side, canopy * 0.8, cw);
	v_top = top;
	v_side = side;
	v_n = n;
	NORMAL = n;
	// VERTEX.y = 1 marca a saia que esconde frestas entre niveis de LOD.
	v_wpos = vec3(xz.x, s0.x - VERTEX.y * tile.z * 0.07, xz.y);
	VERTEX = v_wpos;
}

void fragment() {
	float dist = length(v_wpos.xz - player_pos.xz);
	float dth = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (dist < lod_near + (dth - 0.5) * 8.0) {
		discard;
	}
	vec3 n = normalize(v_n);
	float steep = 1.0 - smoothstep(0.5, 0.78, n.y);
	vec3 col = mix(v_top, v_side, steep);
	float macro = texture(macro_noise, v_wpos.xz * 0.011 + v_wpos.y * 0.003).r;
	float macro2 = texture(macro_noise, v_wpos.xz * 0.043 + vec2(0.37, 0.11)).r;
	col *= mix(0.80, 1.14, macro) * mix(0.94, 1.06, macro2);
	// Variacao por bloco: mantem a leitura de voxels enquanto ainda da para distinguir.
	vec3 cell = floor(v_wpos + n * 0.01);
	float hv = float(wg_hash(uint(int(cell.x)), uint(int(cell.z)), uint(int(cell.y))) & 255u) / 255.0;
	col *= mix(1.0, 0.88 + 0.24 * hv, 1.0 - smoothstep(140.0, 420.0, dist));
	// Linhas de degrau nas encostas: o relevo liso continua lendo como blocos empilhados.
	float fy = fract(v_wpos.y);
	float fw = max(fwidth(v_wpos.y) * 1.5, 0.03);
	float ledge = 1.0 - smoothstep(0.0, fw, min(fy, 1.0 - fy));
	float slope = smoothstep(0.04, 0.3, 1.0 - n.y);
	col *= 1.0 - ledge * slope * 0.35 * (1.0 - smoothstep(160.0, 700.0, dist));
	col *= mix(1.0, 0.72, rain_wetness);
	col *= mix(vec3(1.0), season_tint(season), v_green);
	float snow = smoothstep(0.55, 0.8, n.y) * snow_cover * v_snowable;
	col = mix(col, vec3(0.88, 0.91, 0.97), snow);
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.45, rain_wetness);
	SPECULAR = 0.3;
}
"""

var view_distance := 2000.0
var material: ShaderMaterial
var water_material: ShaderMaterial
var focus := Vector3.ZERO
var near_radius := 0.0
var tile_count := 0

var _mesh: ArrayMesh
var _pool: Array[MeshInstance3D] = []
var _used := 0
var _water: MeshInstance3D
var _timer := 0.0
var _last_focus := Vector3(1e9, 0, 1e9)


func setup(seed_v: int, macro: Texture2D, colors: Dictionary, water_base: ShaderMaterial) -> void:
	var sh := Shader.new()
	sh.code = SHADER_HEAD + WGShaders.NOISE + SHADER_BODY
	material = ShaderMaterial.new()
	material.shader = sh
	material.set_shader_parameter("world_seed", seed_v)
	material.set_shader_parameter("grid", float(GRID))
	material.set_shader_parameter("macro_noise", macro)
	for k: String in colors:
		material.set_shader_parameter(k, colors[k])
	_mesh = _build_grid()
	water_material = water_base.duplicate()
	water_material.set_shader_parameter("far_plane", true)
	_water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	pm.material = water_material
	_water.mesh = pm
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_water)


func _build_grid() -> ArrayMesh:
	# Grade (GRID+1)^2 mais um anel externo de "saia" (y = 1) nas mesmas posicoes da borda.
	var n := GRID + 3
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	for z in n:
		for x in n:
			var skirt := x == 0 or z == 0 or x == n - 1 or z == n - 1
			var fx := clampf(float(x - 1) / GRID, 0.0, 1.0)
			var fz := clampf(float(z - 1) / GRID, 0.0, 1.0)
			v.append(Vector3(fx, 1.0 if skirt else 0.0, fz))
	for z in n - 1:
		for x in n - 1:
			var a := z * n + x
			idx.append(a); idx.append(a + 1); idx.append(a + n)
			idx.append(a + 1); idx.append(a + n + 1); idx.append(a + n)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, material)
	return m


func set_view_distance(d: float) -> void:
	view_distance = d
	visible = d > 0.0
	_last_focus = Vector3(1e9, 0, 1e9)


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer > 0.0 and focus.distance_to(_last_focus) < 12.0:
		return
	_timer = 0.3
	_last_focus = focus
	_used = 0
	var r0 := int(floor((focus.x - view_distance) / ROOT_TILE))
	var r1 := int(floor((focus.x + view_distance) / ROOT_TILE))
	var q0 := int(floor((focus.z - view_distance) / ROOT_TILE))
	var q1 := int(floor((focus.z + view_distance) / ROOT_TILE))
	for rz in range(q0, q1 + 1):
		for rx in range(r0, r1 + 1):
			_visit(rx * ROOT_TILE, rz * ROOT_TILE, ROOT_TILE)
	for i in range(_used, _pool.size()):
		_pool[i].visible = false
	tile_count = _used
	var ws := view_distance * 2.2
	_water.scale = Vector3(ws, 1.0, ws)
	_water.position = Vector3(snappedf(focus.x, 16.0), WorldGen.SEA + 0.875, snappedf(focus.z, 16.0))


func _visit(x: float, z: float, size: float) -> void:
	var dx := maxf(maxf(x - focus.x, focus.x - (x + size)), 0.0)
	var dz := maxf(maxf(z - focus.z, focus.z - (z + size)), 0.0)
	var d := sqrt(dx * dx + dz * dz)
	if d > view_distance:
		return
	if size > MIN_TILE and d < size * 1.1:
		var h := size * 0.5
		_visit(x, z, h)
		_visit(x + h, z, h)
		_visit(x, z + h, h)
		_visit(x + h, z + h, h)
		return
	# Folha totalmente coberta pelos voxels: nada a desenhar.
	var fx := maxf(absf(x - focus.x), absf(x + size - focus.x))
	var fz := maxf(absf(z - focus.z), absf(z + size - focus.z))
	if sqrt(fx * fx + fz * fz) < near_radius - 8.0:
		return
	var mi: MeshInstance3D
	if _used < _pool.size():
		mi = _pool[_used]
	else:
		mi = MeshInstance3D.new()
		mi.mesh = _mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(mi)
		_pool.append(mi)
	_used += 1
	mi.visible = true
	mi.set_instance_shader_parameter("tile", Vector3(x, z, size))
	mi.custom_aabb = AABB(Vector3(x, -80.0, z), Vector3(size, 230.0, size))
