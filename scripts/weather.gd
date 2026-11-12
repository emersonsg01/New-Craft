class_name Weather
extends Node3D
## Ciclo dia/noite, ceu, vento com rajadas, chuva, neve, tempestade com raios e neblina.
## Publica o estado nos uniforms globais usados pelos shaders de folhagem, agua e terreno.

enum State { CLEAR, CLOUDY, RAIN, STORM }
const STATE_NAMES: Array[String] = ["Céu limpo", "Nublado", "Chuva", "Tempestade"]
const TARGETS := {
	State.CLEAR: [0.28, 0.0, 0.30],
	State.CLOUDY: [0.62, 0.0, 0.55],
	State.RAIN: [0.88, 0.6, 0.85],
	State.STORM: [1.0, 1.0, 1.45],
}

var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var flash_light: DirectionalLight3D
var sky_mat: ShaderMaterial
var world: World
var sfx: Sfx
var camera: Camera3D

var time_of_day := 0.32
var day_length := 720.0
var time_scale := 1.0
var state: State = State.CLEAR
var auto_weather := true
var cloud := 0.3
var rain := 0.0
var wind := 0.3
var wind_eff := 0.3
var wind_angle := 0.6
var wind_time := 0.0
var wetness := 0.0
var lightning := 0.0
var underwater := false
## Calendario: dias passados e duracao de cada estacao (em dias de jogo).
var day := 0
var season_days := 3.0
## 0 primavera, 1 verao, 2 outono, 3 inverno (com fracao).
var season := 0.0
var snow_cover := 0.0
## Dimensao atual: 0 superficie, 1 profundezas igneas, 2 ilhas etereas.
var dim := 0
const SEASON_NAMES: Array[String] = ["Primavera", "Verão", "Outono", "Inverno"]
var cold := false
var sun_dir := Vector3.UP
## Alcance da visao (m): a neblina fecha exatamente no fim do terreno distante.
var view_far := 2000.0

var _state_timer := 90.0
var _bolt_timer := 8.0
var _thunder_delay := -1.0
var _cloud_offset := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _rain_p: GPUParticles3D
var _splash_p: GPUParticles3D
var _snow_p: GPUParticles3D
var _leaf_p: GPUParticles3D
var _rain_pm: ParticleProcessMaterial
var _snow_pm: ParticleProcessMaterial
var _leaf_pm: ParticleProcessMaterial
var _rain_mat: StandardMaterial3D
var _hf: GPUParticlesCollisionHeightField3D
var _t := 0.0


func _ready() -> void:
	_rng.randomize()
	_build_environment()
	_build_lights()
	_build_particles()
	_apply(0.0)


func _build_environment() -> void:
	var cn := FastNoiseLite.new()
	cn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cn.frequency = 0.006
	cn.fractal_octaves = 5
	var ct := NoiseTexture2D.new()
	ct.width = 512
	ct.height = 512
	ct.seamless = true
	ct.generate_mipmaps = true
	ct.noise = cn

	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("cloud_tex", ct)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_aerial_perspective = 1.0
	env.fog_sky_affect = 0.0
	env.fog_sun_scatter = 0.15
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_length = 96.0
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_sky_affect = 0.0
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_lights() -> void:
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.6
	sun.light_angular_distance = 0.4
	sun.light_volumetric_fog_energy = 1.6
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 120.0
	moon.shadow_normal_bias = 1.6
	moon.light_volumetric_fog_energy = 0.5
	add_child(moon)
	flash_light = DirectionalLight3D.new()
	flash_light.light_color = Color(0.8, 0.86, 1.0)
	flash_light.shadow_enabled = false
	flash_light.light_energy = 0.0
	flash_light.rotation_degrees = Vector3(-70, 30, 0)
	add_child(flash_light)


func _quad_mesh(size: Vector2, color: Color, billboard: bool, shaded: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if shaded else BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
	q.material = m
	return q


func _build_particles() -> void:
	_hf = GPUParticlesCollisionHeightField3D.new()
	_hf.size = Vector3(56, 64, 56)
	_hf.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	_hf.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	add_child(_hf)

	# Respingos emitidos onde as gotas batem.
	_splash_p = GPUParticles3D.new()
	_splash_p.amount = 1200
	_splash_p.lifetime = 0.3
	_splash_p.local_coords = false
	_splash_p.emitting = false
	_splash_p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var spm := ParticleProcessMaterial.new()
	spm.direction = Vector3(0, 1, 0)
	spm.spread = 55.0
	spm.initial_velocity_min = 1.2
	spm.initial_velocity_max = 2.6
	spm.gravity = Vector3(0, -12, 0)
	_splash_p.process_material = spm
	_splash_p.draw_pass_1 = _quad_mesh(Vector2(0.035, 0.035), Color(0.8, 0.86, 0.95, 0.5), true, false)
	add_child(_splash_p)

	_rain_p = GPUParticles3D.new()
	_rain_p.amount = 7000
	_rain_p.lifetime = 1.3
	_rain_p.local_coords = false
	_rain_p.collision_base_size = 0.05
	_rain_p.visibility_aabb = AABB(Vector3(-40, -50, -40), Vector3(80, 70, 80))
	_rain_p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	_rain_pm = ParticleProcessMaterial.new()
	_rain_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_pm.emission_box_extents = Vector3(24, 0.5, 24)
	_rain_pm.direction = Vector3(0, -1, 0)
	_rain_pm.spread = 2.0
	_rain_pm.initial_velocity_min = 24.0
	_rain_pm.initial_velocity_max = 30.0
	_rain_pm.gravity = Vector3(0, -8, 0)
	_rain_pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	_rain_pm.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	_rain_pm.sub_emitter_amount_at_collision = 2
	_rain_p.process_material = _rain_pm
	var rq := _quad_mesh(Vector2(0.022, 0.75), Color(0.75, 0.82, 0.95, 0.30), false, false)
	_rain_mat = rq.material
	_rain_p.draw_pass_1 = rq
	_rain_p.amount_ratio = 0.0
	add_child(_rain_p)
	_rain_p.sub_emitter = _rain_p.get_path_to(_splash_p)

	_snow_p = GPUParticles3D.new()
	_snow_p.amount = 3500
	_snow_p.lifetime = 7.0
	_snow_p.local_coords = false
	_snow_p.collision_base_size = 0.04
	_snow_p.visibility_aabb = AABB(Vector3(-40, -50, -40), Vector3(80, 70, 80))
	_snow_pm = ParticleProcessMaterial.new()
	_snow_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_snow_pm.emission_box_extents = Vector3(24, 6, 24)
	_snow_pm.direction = Vector3(0, -1, 0)
	_snow_pm.spread = 15.0
	_snow_pm.initial_velocity_min = 1.5
	_snow_pm.initial_velocity_max = 3.0
	_snow_pm.gravity = Vector3(0, -0.6, 0)
	_snow_pm.turbulence_enabled = true
	_snow_pm.turbulence_noise_strength = 0.6
	_snow_pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	_snow_p.process_material = _snow_pm
	_snow_p.draw_pass_1 = _quad_mesh(Vector2(0.055, 0.055), Color(0.95, 0.97, 1.0, 0.85), true, false)
	_snow_p.amount_ratio = 0.0
	add_child(_snow_p)

	# Folhas soltas levadas pelo vento.
	_leaf_p = GPUParticles3D.new()
	_leaf_p.amount = 90
	_leaf_p.lifetime = 7.0
	_leaf_p.local_coords = false
	_leaf_p.collision_base_size = 0.05
	_leaf_p.visibility_aabb = AABB(Vector3(-50, -40, -50), Vector3(100, 80, 100))
	_leaf_pm = ParticleProcessMaterial.new()
	_leaf_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_leaf_pm.emission_box_extents = Vector3(22, 5, 22)
	_leaf_pm.spread = 25.0
	_leaf_pm.initial_velocity_min = 2.0
	_leaf_pm.initial_velocity_max = 5.0
	_leaf_pm.gravity = Vector3(0, -0.8, 0)
	_leaf_pm.angular_velocity_min = -220.0
	_leaf_pm.angular_velocity_max = 220.0
	_leaf_pm.turbulence_enabled = true
	_leaf_pm.turbulence_noise_strength = 1.4
	_leaf_pm.hue_variation_min = -0.08
	_leaf_pm.hue_variation_max = 0.04
	_leaf_pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	_leaf_p.process_material = _leaf_pm
	_leaf_p.draw_pass_1 = _quad_mesh(Vector2(0.11, 0.07), Color(0.42, 0.52, 0.16, 1.0), false, true)
	_leaf_p.amount_ratio = 0.0
	add_child(_leaf_p)


func next_weather() -> void:
	state = ((state + 1) % 4) as State
	_state_timer = 150.0


func set_state(s: int) -> void:
	state = s as State
	_state_timer = 150.0


func season_name() -> String:
	return SEASON_NAMES[int(season) % 4]


## Multiplicador de crescimento das plantas pela estacao.
func growth() -> float:
	if dim == 1:
		return 0.6
	match int(season) % 4:
		0: return 1.3
		1: return 1.0
		2: return 0.6
	return 0.0


func hour_text() -> String:
	var h := fposmod(time_of_day * 24.0, 24.0)
	return "%02d:%02d" % [int(h), int((h - int(h)) * 60.0)]


func _process(delta: float) -> void:
	_apply(delta)


func _apply(delta: float) -> void:
	_t += delta
	var prev_t := time_of_day
	time_of_day = fposmod(time_of_day + delta * time_scale / day_length, 1.0)
	if time_of_day < prev_t:
		day += 1
	season = fposmod((day + time_of_day) / maxf(season_days, 0.1), 4.0)
	# Neve acumula ao longo do inverno e derrete no comeco da primavera.
	var target_snow := 0.0
	if season >= 3.0:
		target_snow = smoothstep(3.0, 3.25, season) * (1.0 - smoothstep(3.85, 4.0, season))
	snow_cover = lerpf(snow_cover, target_snow if dim == 0 else 0.0, 1.0 - exp(-delta * 0.5))
	RenderingServer.global_shader_parameter_set("season", season if dim == 0 else 1.0)
	RenderingServer.global_shader_parameter_set("snow_cover", snow_cover)
	if dim != 0:
		_apply_dim(delta)
		return

	# Maquina de estados do clima.
	if auto_weather:
		_state_timer -= delta * time_scale
		if _state_timer <= 0.0:
			var r := _rng.randf()
			if state == State.CLEAR:
				state = State.CLOUDY if r < 0.7 else State.CLEAR
			elif state == State.CLOUDY:
				state = State.RAIN if r < 0.45 else State.CLEAR
			elif state == State.RAIN:
				state = State.STORM if r < 0.35 else State.CLOUDY
			else:
				state = State.RAIN
			_state_timer = _rng.randf_range(70.0, 160.0)
	var tg: Array = TARGETS[state]
	var k := 1.0 - exp(-delta * 0.35)
	cloud = lerpf(cloud, tg[0], k)
	rain = lerpf(rain, tg[1], k)
	wind = lerpf(wind, tg[2], k)

	# Vento: direcao que gira devagar + rajadas.
	wind_angle += delta * 0.02 * sin(_t * 0.05)
	var gust := 0.72 + 0.28 * sin(_t * 0.31) * sin(_t * 0.17 + 1.3) + 0.12 * sin(_t * 1.1)
	wind_eff = maxf(0.05, wind * gust)
	wind_time += delta * (0.55 + wind_eff * 0.9)
	var wd := Vector2(cos(wind_angle), sin(wind_angle))
	if rain > 0.05:
		wetness = minf(1.0, wetness + delta * rain * 0.12)
	else:
		wetness = maxf(0.0, wetness - delta * 0.012)
	RenderingServer.global_shader_parameter_set("wind_dir", wd)
	RenderingServer.global_shader_parameter_set("wind_strength", wind_eff)
	RenderingServer.global_shader_parameter_set("wind_time", wind_time)
	RenderingServer.global_shader_parameter_set("rain_wetness", 0.0 if cold else wetness)
	RenderingServer.global_shader_parameter_set("rain_intensity", 0.0 if cold else rain)

	# Sol e lua.
	var ang := (time_of_day - 0.25) * TAU
	sun_dir = Vector3(cos(ang), sin(ang), 0.32).normalized()
	var overcast := clampf((cloud - 0.5) * 2.0, 0.0, 1.0)
	var sun_up := smoothstep(-0.06, 0.14, sun_dir.y)
	_aim(sun, sun_dir)
	_aim(moon, -sun_dir)
	var warm := smoothstep(0.45, 0.05, sun_dir.y)
	sun.light_color = Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.55, 0.28), warm)
	sun.light_energy = sun_up * lerpf(1.35, 0.32, overcast)
	sun.visible = sun.light_energy > 0.004
	var moon_up := smoothstep(-0.06, 0.14, -sun_dir.y)
	moon.light_energy = moon_up * lerpf(0.16, 0.03, overcast)
	moon.visible = moon.light_energy > 0.004

	# Raios.
	if state == State.STORM and rain > 0.6:
		_bolt_timer -= delta
		if _bolt_timer <= 0.0:
			_bolt_timer = _rng.randf_range(5.0, 16.0)
			lightning = 1.0
			_thunder_delay = _rng.randf_range(0.3, 2.2)
			flash_light.rotation_degrees = Vector3(_rng.randf_range(-80, -40), _rng.randf_range(0, 360), 0)
	lightning = maxf(0.0, lightning - delta * 3.5)
	var flick := lightning * (0.6 + 0.4 * sin(_t * 70.0))
	flash_light.light_energy = flick * 2.5
	flash_light.visible = flick > 0.01
	if _thunder_delay > 0.0:
		_thunder_delay -= delta
		if _thunder_delay <= 0.0 and sfx != null:
			sfx.play("thunder", -2.0, _rng.randf_range(0.7, 1.1))

	# Ceu.
	_cloud_offset += wd * delta * (0.0018 + wind_eff * 0.0045)
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("moon_dir", -sun_dir)
	sky_mat.set_shader_parameter("cloud_offset", _cloud_offset)
	sky_mat.set_shader_parameter("coverage", cloud)
	sky_mat.set_shader_parameter("overcast", overcast)
	sky_mat.set_shader_parameter("lightning", flick)

	# Neblina.
	if underwater:
		env.fog_aerial_perspective = 0.0
		env.fog_light_color = Color(0.04, 0.22, 0.30) * (0.15 + 0.85 * sun_up)
		env.fog_depth_begin = 0.0
		env.fog_depth_end = 26.0
		env.fog_depth_curve = 0.7
		env.fog_sky_affect = 1.0
		env.volumetric_fog_density = 0.06
	else:
		env.fog_aerial_perspective = 1.0
		env.fog_sky_affect = 0.0
		env.fog_depth_begin = lerpf(30.0, 4.0, rain)
		env.fog_depth_end = lerpf(view_far, minf(view_far, 320.0), sqrt(rain)) * (1.0 - overcast * 0.25)
		env.fog_depth_curve = lerpf(1.7, 0.8, rain)
		env.volumetric_fog_density = lerpf(0.006, 0.035, rain)

	if camera != null:
		_update_particles(wd, sun_up)
	if sfx != null:
		sfx.set_ambience(clampf((wind_eff - 0.15) * 0.7, 0.0, 1.0), 0.0 if (cold or underwater) else rain)


func _aim(l: DirectionalLight3D, toward: Vector3) -> void:
	# A luz aponta ao longo de -Z; o astro fica na direcao "toward".
	var up := Vector3.UP if absf(toward.y) < 0.99 else Vector3.RIGHT
	l.basis = Basis.looking_at(-toward, up)


## Ambiente fixo das outras dimensoes: sem sol, chuva ou estacoes.
func _apply_dim(delta: float) -> void:
	wind_time += delta * 0.5
	RenderingServer.global_shader_parameter_set("wind_strength", 0.15)
	RenderingServer.global_shader_parameter_set("wind_time", wind_time)
	RenderingServer.global_shader_parameter_set("rain_wetness", 0.0)
	RenderingServer.global_shader_parameter_set("rain_intensity", 0.0)
	sun.visible = false
	moon.visible = dim == 2
	flash_light.visible = false
	_rain_p.amount_ratio = 0.0
	_snow_p.amount_ratio = 0.0
	_leaf_p.amount_ratio = 0.0
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	if dim == 1:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.16, 0.03, 0.02)
		env.ambient_light_color = Color(0.85, 0.36, 0.20)
		env.ambient_light_energy = 0.75
		env.fog_light_color = Color(0.40, 0.08, 0.03)
		env.fog_depth_begin = 6.0
		env.fog_depth_end = 110.0
		env.fog_depth_curve = 1.2
		env.volumetric_fog_density = 0.03
		env.volumetric_fog_albedo = Color(1.0, 0.5, 0.3)
	else:
		env.background_mode = Environment.BG_SKY
		sky_mat.set_shader_parameter("sun_dir", Vector3(0.2, -0.9, 0.3).normalized())
		sky_mat.set_shader_parameter("moon_dir", Vector3(0.3, 0.8, -0.4).normalized())
		sky_mat.set_shader_parameter("coverage", 0.15)
		sky_mat.set_shader_parameter("overcast", 0.0)
		sky_mat.set_shader_parameter("lightning", 0.0)
		env.ambient_light_color = Color(0.45, 0.42, 0.70)
		env.ambient_light_energy = 0.9
		env.fog_light_color = Color(0.10, 0.06, 0.20)
		env.fog_depth_begin = 30.0
		env.fog_depth_end = 360.0
		env.fog_depth_curve = 1.5
		env.volumetric_fog_density = 0.006
		_aim(moon, Vector3(0.3, 0.8, -0.4).normalized())
		moon.light_energy = 0.55
		moon.light_color = Color(0.7, 0.75, 1.0)
	if sfx != null:
		sfx.set_ambience(0.05, 0.0)


func set_dim(d: int) -> void:
	dim = d
	if d == 0:
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 1.0
		env.volumetric_fog_albedo = Color(1, 1, 1)
		moon.light_color = Color(0.55, 0.65, 0.95)


func _update_particles(wd: Vector2, sun_up: float) -> void:
	var cp := camera.global_position
	if world != null:
		cold = world.gen.temperature(cp.x, cp.z) < -0.32 or cp.y > WorldGen.SEA + 52 or snow_cover > 0.5
	var drift := Vector3(wd.x, 0, wd.y) * wind_eff
	_hf.global_position = Vector3(snappedf(cp.x, 2.0), snappedf(cp.y, 2.0), snappedf(cp.z, 2.0))
	_rain_p.global_position = cp + Vector3(0, 15, 0) - drift * 3.0
	_rain_p.amount_ratio = 0.0 if cold else rain
	_rain_pm.direction = Vector3(drift.x * 0.28, -1.0, drift.z * 0.28).normalized()
	var lum := 0.18 + 0.82 * sun_up + lightning
	_rain_mat.albedo_color = Color(0.75 * lum, 0.82 * lum, 0.95 * lum, 0.30)
	_snow_p.global_position = cp + Vector3(0, 9, 0) - drift * 4.0
	_snow_p.amount_ratio = clampf(rain * 1.2 + (0.12 if cloud > 0.5 else 0.0), 0.0, 1.0) if cold else 0.0
	_snow_pm.gravity = Vector3(drift.x * 2.5, -0.6, drift.z * 2.5)
	_leaf_p.global_position = cp + Vector3(0, 4, 0) - drift * 9.0
	_leaf_p.amount_ratio = 0.0 if cold else clampf((wind_eff - 0.25) * 1.1, 0.0, 1.0)
	_leaf_pm.direction = Vector3(drift.x, 0.1, drift.z).normalized() if drift.length() > 0.01 else Vector3(1, 0, 0)
	_leaf_pm.gravity = Vector3(drift.x * 3.0, -0.8, drift.z * 3.0)
