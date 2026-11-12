shader_type spatial;
render_mode cull_disabled;
// Folhas e plantas: recorte por alpha, balanco com o vento (rajadas viajando pelo mapa)
// e plantas que se curvam quando o jogador passa.

uniform sampler2DArray tex_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;
uniform float sway_scale = 1.0;

global uniform vec2 wind_dir;
global uniform float wind_strength;
global uniform float wind_time;
global uniform vec3 player_pos;
global uniform float rain_wetness;
global uniform float lod_near;
global uniform float season;
global uniform float snow_cover;
uniform float evergreen_a = -1.0;
uniform float evergreen_b = -1.0;

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

float cell_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

varying flat float v_layer;
varying float v_sway;
varying vec3 v_wpos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = COLOR.a * sway_scale;
	v_layer = floor(COLOR.g * 255.0 + 0.5);
	v_sway = COLOR.a;
	float gust = sin(dot(wp.xz, wind_dir) * 0.32 - wind_time * 1.7) * 0.5 + 0.5;
	gust *= sin(dot(wp.xz, wind_dir.yx * vec2(-1.0, 1.0)) * 0.11 + wind_time * 0.4) * 0.35 + 0.65;
	float flutter = sin(wind_time * 5.3 + wp.x * 2.1 + wp.z * 1.7 + wp.y * 1.3);
	vec2 push = wind_dir * (0.05 + gust * 0.24) * wind_strength;
	push += wind_dir.yx * vec2(-1.0, 1.0) * flutter * 0.035 * wind_strength;
	VERTEX.xz += push * w;
	VERTEX.y -= length(push) * w * 0.35;

	// Empurrao do jogador (so plantas: peso alto).
	vec3 d = wp - player_pos;
	float pd = length(d.xz);
	float inf = (1.0 - smoothstep(0.25, 1.25, pd)) * (1.0 - smoothstep(0.8, 1.8, abs(d.y - 0.5))) * w * w;
	VERTEX.xz += normalize(d.xz + vec2(0.0001)) * inf * 0.5;
	VERTEX.y -= inf * 0.3;
	v_wpos = wp;
}

void fragment() {
	// Transicao pontilhada para o terreno distante (LOD).
	float lod_d = length(v_wpos.xz - player_pos.xz);
	float lod_n = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (sway_scale > 0.0 && lod_d > lod_near + (lod_n - 0.5) * 8.0) {
		discard;
	}
	vec4 alb = texture(tex_albedo, vec3(UV, v_layer));
	bool evergreen = abs(v_layer - evergreen_a) < 0.5 || abs(v_layer - evergreen_b) < 0.5;
	bool leaf = v_sway > 0.15 && v_sway < 0.3;
	float autumn = smoothstep(2.0, 2.5, season) * (1.0 - smoothstep(3.0, 3.3, season));
	float bare = smoothstep(3.0, 3.35, season) * (1.0 - smoothstep(3.85, 4.0, season));
	vec3 cellp = floor(v_wpos + vec3(0.001));
	float hc = cell_hash(cellp);
	if (leaf && !evergreen && bare > 0.0 && cell_hash(floor(v_wpos * 4.0)) < bare * 0.75) {
		discard;
	}
	if (alb.a < 0.4) {
		discard;
	}
	float macro = texture(macro_noise, v_wpos.xz * 0.011).r;
	alb.rgb *= mix(0.78, 1.18, macro);
	alb.rgb *= mix(1.0, 0.8, rain_wetness * COLOR.b);
	if (!evergreen) {
		alb.rgb *= season_tint(season);
		if (leaf && autumn > 0.0) {
			vec3 fall = hc < 0.33 ? vec3(0.85, 0.30, 0.08) : (hc < 0.66 ? vec3(0.92, 0.62, 0.12) : vec3(0.70, 0.16, 0.08));
			float lum = dot(alb.rgb, vec3(0.3, 0.5, 0.2));
			alb.rgb = mix(alb.rgb, fall * (0.6 + lum * 1.2), autumn * 0.85);
		}
		if (bare > 0.0) {
			alb.rgb = mix(alb.rgb, vec3(0.36, 0.28, 0.20) * (0.7 + dot(alb.rgb, vec3(0.33))), bare * 0.6);
		}
	}
	// Neve sobre as folhas no inverno.
	alb.rgb = mix(alb.rgb, vec3(0.9, 0.93, 0.98), snow_cover * COLOR.b * (leaf ? 0.45 : 0.3));
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = alb.rgb;
	ROUGHNESS = mix(0.75, 0.3, rain_wetness * COLOR.b);
	SPECULAR = 0.35;
	BACKLIGHT = alb.rgb * 0.45;
	AO = COLOR.r * mix(0.08, 1.0, COLOR.b);
	AO_LIGHT_AFFECT = 0.25;
}
