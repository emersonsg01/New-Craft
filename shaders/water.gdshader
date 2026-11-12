shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// Agua: ondas guiadas pelo vento, refracao, absorcao por profundidade, espuma na margem
// e aneis de gotas quando chove.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D wave_normal : filter_linear_mipmap, repeat_enable;
uniform vec3 shallow_color : source_color = vec3(0.10, 0.42, 0.48);
uniform vec3 deep_color : source_color = vec3(0.015, 0.09, 0.17);

global uniform vec2 wind_dir;
global uniform float wind_strength;
global uniform float wind_time;
global uniform float rain_intensity;
global uniform float lod_near;
global uniform vec3 player_pos;
// Plano de agua distante: desenha so alem do raio dos voxels.
uniform bool far_plane = false;

varying vec3 v_wpos;
varying float v_top;

vec2 hash22(vec2 p) {
	vec3 a = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	a += dot(a, a.yzx + 33.33);
	return fract((a.xx + a.yz) * a.zy);
}

vec2 ripples(vec2 p, float t) {
	vec2 acc = vec2(0.0);
	vec2 cell = floor(p);
	vec2 f = fract(p);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 o = vec2(float(i), float(j));
			vec2 h = hash22(cell + o);
			float ph = fract(t * 0.85 + h.x * 7.0 + h.y * 3.0);
			vec2 dv = o + h - f;
			float d = length(dv);
			float r = d - ph * 0.9;
			float ring = sin(r * 30.0) * (1.0 - smoothstep(0.0, 0.11, abs(r))) * (1.0 - ph);
			acc += normalize(dv + vec2(0.00001)) * ring;
		}
	}
	return acc;
}

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_top = step(0.5, NORMAL.y);
	float wave = sin(v_wpos.x * 0.9 + wind_time * 1.3) + sin(v_wpos.z * 0.75 - wind_time * 1.1) + sin((v_wpos.x + v_wpos.z) * 0.35 + wind_time * 0.7);
	VERTEX.y += wave * 0.022 * (0.4 + wind_strength) * COLOR.r;
}

void fragment() {
	// Transicao pontilhada para o terreno distante (LOD).
	float lod_d = length(v_wpos.xz - player_pos.xz);
	float lod_n = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if ((lod_d > lod_near + (lod_n - 0.5) * 8.0) != far_plane) {
		discard;
	}
	vec2 flow = wind_dir * wind_time * 0.035;
	vec2 p = v_wpos.xz;
	vec3 n1 = texture(wave_normal, p * 0.11 + flow).rgb * 2.0 - 1.0;
	vec3 n2 = texture(wave_normal, p * 0.27 - flow * 1.7 + vec2(0.31, 0.57)).rgb * 2.0 - 1.0;
	vec2 nxy = (n1.xy + n2.xy * 0.6) * (0.18 + wind_strength * 0.28);
	if (rain_intensity > 0.01) {
		nxy += ripples(p * 2.2, wind_time * 0.6 + TIME) * rain_intensity * 0.55;
	}
	vec3 nw = normalize(vec3(nxy.x, 1.0, nxy.y));
	vec3 view_n = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	if (!FRONT_FACING) {
		view_n = -view_n;
	}
	vec3 base_n = normalize(NORMAL);
	NORMAL = mix(base_n, view_n, v_top);

	// Profundidade da agua atras do pixel.
	float d_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d_raw, 1.0);
	float scene_z = vp.z / vp.w;
	float wdepth = max(0.0, VERTEX.z - scene_z);

	vec2 ruv = SCREEN_UV + nxy * 0.045 * clamp(wdepth, 0.0, 1.0) * v_top;
	float d2 = texture(depth_tex, ruv).r;
	vec4 vp2 = INV_PROJECTION_MATRIX * vec4(ruv * 2.0 - 1.0, d2, 1.0);
	float z2 = vp2.z / vp2.w;
	if (z2 > VERTEX.z) {
		ruv = SCREEN_UV;
	} else {
		wdepth = max(0.0, VERTEX.z - z2);
	}
	vec3 behind = textureLod(screen_tex, ruv, 0.0).rgb;

	float absorb = 1.0 - exp(-wdepth * 0.42);
	vec3 tint = mix(shallow_color, deep_color, clamp(wdepth * 0.16, 0.0, 1.0));
	float foam = (1.0 - smoothstep(0.0, 0.32, wdepth)) * v_top * (0.55 + 0.45 * n2.x);
	float through = (1.0 - absorb) * (1.0 - foam);

	ALBEDO = mix(tint * absorb, vec3(0.9), foam);
	EMISSION = behind * through * mix(vec3(1.0), shallow_color * 2.2, clamp(wdepth * 0.5, 0.0, 0.75));
	ROUGHNESS = 0.035 + rain_intensity * 0.08 + foam * 0.5;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	AO = mix(0.15, 1.0, COLOR.b);
	ALPHA = 1.0;
}
