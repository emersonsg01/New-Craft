shader_type spatial;
render_mode cull_disabled;
// Lava: crosta escura que racha e deixa ver o magma brilhante; a superficie pulsa devagar.

uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;
global uniform float lod_near;
global uniform vec3 player_pos;

varying vec3 v_wpos;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(v_wpos.x * 0.7 + TIME * 0.8) * sin(v_wpos.z * 0.6 - TIME * 0.6) * 0.04 * COLOR.r;
}

void fragment() {
	vec2 p = v_wpos.xz + v_wpos.y * 0.3;
	float n1 = texture(macro_noise, p * 0.09 + vec2(TIME * 0.012, TIME * 0.007)).r;
	float n2 = texture(macro_noise, p * 0.23 - vec2(TIME * 0.02, -TIME * 0.015)).r;
	float heat = smoothstep(0.42, 0.7, n1 * 0.6 + n2 * 0.4);
	vec3 crust = mix(vec3(0.10, 0.03, 0.02), vec3(0.28, 0.08, 0.03), n2);
	vec3 magma = mix(vec3(1.0, 0.30, 0.04), vec3(1.0, 0.85, 0.30), n2);
	ALBEDO = mix(crust, magma * 0.4, heat);
	EMISSION = magma * mix(0.6, 5.5, heat) * (0.9 + 0.1 * sin(TIME * 2.0 + n1 * 6.0));
	ROUGHNESS = mix(0.95, 0.4, heat);
	METALLIC = 0.0;
}
