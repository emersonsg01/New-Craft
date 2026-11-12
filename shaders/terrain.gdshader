shader_type spatial;
// Blocos opacos: UV projetado no mundo, normal map, parallax occlusion (relevo 3D),
// umidade de chuva com pocas e luz de ceu por vertice.

uniform sampler2DArray tex_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray tex_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray tex_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;
uniform bool local_space = false;
uniform float natural_layers = 8.0;

global uniform float rain_wetness;
global uniform float parallax_depth;
global uniform float season;
global uniform float snow_cover;
uniform float grass_layer = 0.0;
uniform float sand_layer = 3.0;
uniform float sand_layer2 = -1.0;

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
global uniform float lod_near;
global uniform vec3 player_pos;

varying vec3 v_wpos;
varying vec3 v_n;
varying vec3 v_t;
varying vec3 v_b;
varying vec2 v_uv;
varying flat float v_layer;

void vertex() {
	vec3 n = NORMAL;
	vec3 t = abs(n.y) > 0.99 ? vec3(1.0, 0.0, 0.0) : normalize(cross(vec3(0.0, 1.0, 0.0), n));
	vec3 b = cross(n, t);
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 p = local_space ? VERTEX : v_wpos;
	mat3 m = mat3(MODEL_MATRIX);
	v_n = normalize(m * n);
	v_t = normalize(m * t);
	v_b = normalize(m * b);
	v_uv = vec2(dot(p, t), -dot(p, b));
	v_layer = floor(COLOR.g * 255.0 + 0.5);
}

void fragment() {
	// Transicao pontilhada para o terreno distante (LOD).
	float lod_d = length(v_wpos.xz - player_pos.xz);
	float lod_n = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	if (!local_space && lod_d > lod_near + (lod_n - 0.5) * 8.0) {
		discard;
	}
	float layer = v_layer;
	float sc = layer < natural_layers ? 0.5 : 1.0;
	vec2 uv = v_uv * sc;
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	vec3 N = normalize(v_n);
	vec3 T = normalize(v_t);
	vec3 B = normalize(v_b);
	vec3 to_cam = CAMERA_POSITION_WORLD - v_wpos;
	float dist = length(to_cam);
	vec3 view_w = to_cam / max(dist, 0.0001);

	if (parallax_depth > 0.0 && dist < 22.0) {
		vec3 vt = vec3(dot(view_w, T), -dot(view_w, B), dot(view_w, N));
		float fade = 1.0 - smoothstep(12.0, 22.0, dist);
		float nsteps = mix(18.0, 6.0, clamp(vt.z, 0.0, 1.0));
		vec2 delta = vt.xy / max(vt.z, 0.3) * parallax_depth * fade * sc / nsteps;
		float lstep = 1.0 / nsteps;
		float cur = 0.0;
		float dpt = 1.0 - textureGrad(tex_normal, vec3(uv, layer), dx, dy).a;
		float prev = dpt;
		for (int k = 0; k < 18; k++) {
			if (cur >= dpt) {
				break;
			}
			uv -= delta;
			cur += lstep;
			prev = dpt;
			dpt = 1.0 - textureGrad(tex_normal, vec3(uv, layer), dx, dy).a;
		}
		float after = dpt - cur;
		float before = prev - (cur - lstep);
		uv += delta * clamp(after / (after - before - 0.00001), 0.0, 1.0);
	}

	vec4 alb = textureGrad(tex_albedo, vec3(uv, layer), dx, dy);
	vec4 nh = textureGrad(tex_normal, vec3(uv, layer), dx, dy);
	vec4 orm = textureGrad(tex_orm, vec3(uv, layer), dx, dy);
	vec3 nt = nh.rgb * 2.0 - 1.0;
	float rough = orm.g;
	float sky = COLOR.b;

	float macro = 0.5;
	float macro2 = 0.0;
	if (!local_space) {
		macro = texture(macro_noise, v_wpos.xz * 0.011 + v_wpos.y * 0.003).r;
		macro2 = texture(macro_noise, v_wpos.xz * 0.043 + vec2(0.37, 0.11)).r;
		alb.rgb *= mix(0.80, 1.14, macro) * mix(0.94, 1.06, macro2);
	}

	// Chuva: superficie molhada escurece, fica lisa e forma pocas nas partes baixas do relevo.
	float up = clamp(N.y, 0.0, 1.0);
	float wet = rain_wetness * sky * mix(0.35, 1.0, up);
	float puddle = smoothstep(0.52, 0.66, macro2) * (1.0 - smoothstep(0.35, 0.75, nh.a)) * up * rain_wetness * sky;
	alb.rgb *= mix(1.0, 0.68, max(wet * 0.8, puddle));
	if (abs(layer - grass_layer) < 0.5) {
		alb.rgb *= season_tint(season);
	}
	// Neve do inverno sobre superficies voltadas para cima e expostas ao ceu.
	if (snow_cover > 0.01 && !local_space && abs(layer - sand_layer) > 0.5 && abs(layer - sand_layer2) > 0.5) {
		float snow = smoothstep(0.5, 0.8, N.y) * smoothstep(0.45, 0.75, sky) * snow_cover;
		snow *= smoothstep(0.25, 0.6, nh.a + (macro2 - 0.5) * 0.6 + snow_cover * 0.5);
		alb.rgb = mix(alb.rgb, vec3(0.90, 0.93, 0.98), snow);
		rough = mix(rough, 0.55, snow);
		nt = normalize(mix(nt, vec3(0.0, 0.0, 1.0), snow * 0.7));
	}
	rough = mix(rough, 0.22, wet * 0.75);
	rough = mix(rough, 0.03, puddle);
	nt = normalize(mix(nt, vec3(0.0, 0.0, 1.0), puddle * 0.95));

	vec3 nw = normalize(T * nt.x + B * nt.y + N * nt.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ALBEDO = alb.rgb;
	ROUGHNESS = rough;
	METALLIC = orm.b;
	SPECULAR = 0.5;
	AO = orm.r * COLOR.r * mix(0.05, 1.0, sky);
	AO_LIGHT_AFFECT = 0.2;
	EMISSION = alb.rgb * orm.a * 6.0;
}
