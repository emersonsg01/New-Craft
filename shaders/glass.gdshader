shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// Vidro e portais. Camadas com emissao (portais) giram e brilham com o tempo.

uniform sampler2DArray tex_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray tex_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool local_space = false;
global uniform float lod_near;
global uniform vec3 player_pos;

varying vec3 v_wpos;
varying vec2 v_uv;
varying flat float v_layer;

void vertex() {
	vec3 n = NORMAL;
	vec3 t = abs(n.y) > 0.99 ? vec3(1.0, 0.0, 0.0) : normalize(cross(vec3(0.0, 1.0, 0.0), n));
	vec3 b = cross(n, t);
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 p = local_space ? VERTEX : v_wpos;
	v_uv = vec2(dot(p, t), -dot(p, b));
	v_layer = floor(COLOR.g * 255.0 + 0.5);
}

void fragment() {
	if (!local_space && length(v_wpos.xz - player_pos.xz) > lod_near) {
		discard;
	}
	vec4 orm = texture(tex_orm, vec3(v_uv, v_layer));
	if (orm.a > 0.5) {
		vec2 c = fract(v_uv) - 0.5;
		float a = TIME * 0.9 + length(c) * 3.0;
		c = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * c;
		vec4 alb = texture(tex_albedo, vec3(c + 0.5, v_layer));
		ALBEDO = alb.rgb * 0.3;
		EMISSION = alb.rgb * (2.2 + 0.6 * sin(TIME * 3.0 + v_wpos.y));
		ALPHA = 0.82;
		ROUGHNESS = 0.2;
	} else {
		vec4 alb = texture(tex_albedo, vec3(v_uv, v_layer));
		ALBEDO = alb.rgb;
		ALPHA = alb.a;
		ROUGHNESS = 0.04;
		SPECULAR = 0.85;
	}
	METALLIC = 0.0;
	AO = mix(0.2, 1.0, COLOR.b);
}
