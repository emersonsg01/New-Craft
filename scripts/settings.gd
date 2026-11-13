extends Node
## Autoload "GameSettings": guarda, salva e aplica as opcoes graficas e de jogo.

signal changed

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"fullscreen": false,
	"vsync": true,
	"max_fps": 0,
	"upscaler": "native",
	"upscale_quality": "quality",
	"sharpness": 0.6,
	"aa": "taa",
	"rt_gi": "off",
	"rt_reflections": false,
	"ssil": false,
	"ssao": true,
	"shadows": "high",
	"volumetric_fog": true,
	"glow": true,
	"parallax": true,
	"render_distance": 7,
	"lod_distance": 2000,
	"fov": 75.0,
	"sensitivity": 0.5,
	"volume": 0.7,
	"bob": true,
	"mobs": true,
	"char_female": false,
	"char_skin": 1,
	"char_hair": 4,
	"char_shirt": 9,
	"char_pants": 1,
	"char_style": -1,
	"char_beard": 0,
	"char_outfit": 0,
	"char_hat": 0,
	"mode": "survival",
	"net_name": "Jogador",
	"net_ip": "127.0.0.1",
	"net_port": 7777,
	"net_join": "",
	"camera": 0,
	"tree_felling": true,
	"season_days": 3,
	"perf_auto": true,
	"cpu_threads": 0,
	"ram_budget": 50,
	"vram_budget": 70,
	"dyn_res": true,
	"target_fps": 60,
}
const SCALE := {"native": 1.0, "ultra": 0.77, "quality": 0.67, "balanced": 0.59, "performance": 0.5}
const PRESETS := {
	"low": {"upscaler": "fsr1", "upscale_quality": "balanced", "aa": "fxaa", "rt_gi": "off", "rt_reflections": false,
		"ssil": false, "ssao": false, "shadows": "low", "volumetric_fog": false, "glow": true, "parallax": false, "render_distance": 5, "lod_distance": 1000},
	"medium": {"upscaler": "fsr2", "upscale_quality": "quality", "aa": "off", "rt_gi": "off", "rt_reflections": false,
		"ssil": false, "ssao": true, "shadows": "medium", "volumetric_fog": false, "glow": true, "parallax": true, "render_distance": 7, "lod_distance": 2000},
	"high": {"upscaler": "native", "upscale_quality": "quality", "aa": "taa", "rt_gi": "low", "rt_reflections": true,
		"ssil": false, "ssao": true, "shadows": "high", "volumetric_fog": true, "glow": true, "parallax": true, "render_distance": 8, "lod_distance": 2000},
	"ultra": {"upscaler": "fsr2", "upscale_quality": "native", "aa": "off", "rt_gi": "high", "rt_reflections": true,
		"ssil": true, "ssao": true, "shadows": "ultra", "volumetric_fog": true, "glow": true, "parallax": true, "render_distance": 10, "lod_distance": 4000},
}

var data: Dictionary = {}
var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
## Modos de upscaling extras expostos pela build da engine (ex.: "dlss", "xess").
var ext_modes: Dictionary = {}
var hardware_rt := false
var gpu_name := ""
var active_upscaler := "native"
## Resolucao dinamica: escala atual e media de FPS.
var dyn_scale := 1.0
var _dyn_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k: String in DEFAULTS:
			var v: Variant = cf.get_value("settings", k, DEFAULTS[k])
			if typeof(v) == typeof(DEFAULTS[k]):
				data[k] = v
	_detect()
	Hardware.detect()
	if data["perf_auto"] and not cf.has_section_key("settings", "auto_applied"):
		_auto_values()
	apply()


func _detect() -> void:
	gpu_name = RenderingServer.get_video_adapter_name()
	# A Godot oficial nao traz DLSS/XeSS. Se a build tiver esses modos no enum, eles aparecem aqui.
	for cname: String in ClassDB.class_get_enum_constants("Viewport", "Scaling3DMode"):
		var up := cname.to_upper()
		if up.contains("DLSS"):
			ext_modes["dlss"] = ClassDB.class_get_integer_constant("Viewport", cname)
		elif up.contains("XESS"):
			ext_modes["xess"] = ClassDB.class_get_integer_constant("Viewport", cname)
	var rd := RenderingServer.get_rendering_device()
	if rd != null:
		hardware_rt = rd.has_feature(RenderingDevice.SUPPORTS_RAYTRACING_PIPELINE)


var _base_scale := 1.0
var _base_mode: int = Viewport.SCALING_3D_MODE_BILINEAR


## Aplica a escala da resolucao dinamica por cima da escolhida pelo usuario.
func _apply_scale() -> void:
	var vp := get_viewport()
	var sc := _base_scale
	if data.get("dyn_res", false):
		sc = minf(_base_scale, dyn_scale)
	vp.scaling_3d_scale = sc
	if sc < 0.999 and _base_mode == Viewport.SCALING_3D_MODE_BILINEAR:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	else:
		vp.scaling_3d_mode = _base_mode as Viewport.Scaling3DMode


## Escolhe a configuracao pelo hardware detectado (sem salvar).
func _auto_values() -> void:
	var rec := Hardware.recommended()
	var p: Dictionary = PRESETS[rec["preset"]]
	for k: String in p:
		data[k] = p[k]
	data["render_distance"] = rec["render_distance"]
	data["lod_distance"] = rec["lod_distance"]
	data["cpu_threads"] = 0
	data["dyn_res"] = true


func apply_auto() -> void:
	_auto_values()
	data["perf_auto"] = true
	apply()
	save()


## Quantas tarefas de CPU em paralelo o mundo pode usar.
func worker_threads() -> int:
	var t := int(data["cpu_threads"])
	if t <= 0:
		t = maxi(2, Hardware.cores - 1)
	return clampi(t, 1, maxi(1, Hardware.cores))


func _process(delta: float) -> void:
	if not data.get("dyn_res", false):
		if dyn_scale < 1.0:
			dyn_scale = 1.0
			apply()
		return
	_dyn_t += delta
	if _dyn_t < 1.0:
		return
	_dyn_t = 0.0
	var fps := Engine.get_frames_per_second()
	var target := float(data["target_fps"])
	var old := dyn_scale
	if fps < target * 0.92:
		dyn_scale = maxf(0.5, dyn_scale - 0.06)
	elif fps > target * 1.12 or (fps >= target - 1.0 and data["vsync"]):
		dyn_scale = minf(1.0, dyn_scale + 0.03)
	if absf(old - dyn_scale) > 0.001:
		_apply_scale()


func get_v(key: String) -> Variant:
	return data.get(key, DEFAULTS.get(key))


func set_v(key: String, value: Variant) -> void:
	data[key] = value
	apply()
	save()


func apply_preset(preset: String) -> void:
	var p: Dictionary = PRESETS[preset]
	for k: String in p:
		data[k] = p[k]
	apply()
	save()


func save() -> void:
	var cf := ConfigFile.new()
	for k: String in data:
		cf.set_value("settings", k, data[k])
	cf.set_value("settings", "auto_applied", true)
	cf.save(PATH)


func bind(e: Environment, s: DirectionalLight3D, m: DirectionalLight3D) -> void:
	env = e
	sun = s
	moon = m
	apply()


func apply() -> void:
	var win := get_window()
	if DisplayServer.get_name() != "headless":
		var want := Window.MODE_FULLSCREEN if data["fullscreen"] else Window.MODE_WINDOWED
		var is_fs := win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN
		if is_fs != bool(data["fullscreen"]):
			win.mode = want
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(data["max_fps"])
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(data["volume"]), 0.0001)))

	# ---------- Upscaling ----------
	var vp := get_viewport()
	var up: String = data["upscaler"]
	if (up == "dlss" or up == "xess") and not ext_modes.has(up):
		up = "fsr2"
	active_upscaler = up
	var scale: float = SCALE.get(data["upscale_quality"], 0.67)
	var temporal := up == "fsr2" or up == "dlss" or up == "xess"
	var aa: String = data["aa"]
	vp.use_taa = aa == "taa" and not temporal
	match up:
		"native":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			scale = 1.0
		"bilinear":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		"fsr1":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		"fsr2":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		_:
			vp.scaling_3d_mode = int(ext_modes[up]) as Viewport.Scaling3DMode
	vp.scaling_3d_scale = scale
	_base_scale = scale
	_base_mode = vp.scaling_3d_mode
	_apply_scale()
	vp.fsr_sharpness = lerpf(2.0, 0.0, float(data["sharpness"]))
	vp.texture_mipmap_bias = 0.0 if (temporal or scale >= 1.0) else log(scale) / log(2.0)

	# ---------- Anti-aliasing ----------
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	if aa == "fxaa":
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	elif aa == "smaa":
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
	vp.msaa_3d = Viewport.MSAA_DISABLED
	match aa:
		"msaa2": vp.msaa_3d = Viewport.MSAA_2X
		"msaa4": vp.msaa_3d = Viewport.MSAA_4X
		"msaa8": vp.msaa_3d = Viewport.MSAA_8X
	vp.use_debanding = true

	RenderingServer.global_shader_parameter_set("parallax_depth", 0.06 if data["parallax"] else 0.0)

	# ---------- Sombras ----------
	var sh: String = data["shadows"]
	var atlas := 4096
	var dist := 180.0
	var quality := RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
	match sh:
		"low":
			atlas = 2048
			dist = 90.0
			quality = RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW
		"medium":
			atlas = 4096
			dist = 140.0
			quality = RenderingServer.SHADOW_QUALITY_SOFT_LOW
		"ultra":
			atlas = 8192
			dist = 260.0
			quality = RenderingServer.SHADOW_QUALITY_SOFT_HIGH
	RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(quality)
	if sun != null:
		sun.shadow_enabled = sh != "off"
		sun.directional_shadow_max_distance = dist
		moon.shadow_enabled = sh == "high" or sh == "ultra"

	# ---------- Ambiente / tracado de raios ----------
	if env != null:
		env.ssao_enabled = data["ssao"]
		env.glow_enabled = data["glow"]
		env.volumetric_fog_enabled = data["volumetric_fog"]
		env.ssil_enabled = data["ssil"]
		env.ssr_enabled = data["rt_reflections"]
		env.ssr_max_steps = 96
		var gi: String = data["rt_gi"]
		env.sdfgi_enabled = gi != "off"
		match gi:
			"low":
				env.sdfgi_cascades = 4
				env.sdfgi_min_cell_size = 0.4
				RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_8)
				RenderingServer.environment_set_sdfgi_frames_to_converge(RenderingServer.ENV_SDFGI_CONVERGE_IN_15_FRAMES)
				RenderingServer.gi_set_use_half_resolution(true)
			"medium":
				env.sdfgi_cascades = 6
				env.sdfgi_min_cell_size = 0.25
				RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_16)
				RenderingServer.environment_set_sdfgi_frames_to_converge(RenderingServer.ENV_SDFGI_CONVERGE_IN_20_FRAMES)
				RenderingServer.gi_set_use_half_resolution(true)
			"high":
				env.sdfgi_cascades = 8
				env.sdfgi_min_cell_size = 0.2
				RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_32)
				RenderingServer.environment_set_sdfgi_frames_to_converge(RenderingServer.ENV_SDFGI_CONVERGE_IN_30_FRAMES)
				RenderingServer.gi_set_use_half_resolution(false)
	changed.emit()
