shader_type sky;
// Ceu procedural: gradiente atmosferico, sol, lua, estrelas e nuvens que andam com o vento.

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 cloud_offset = vec2(0.0);
uniform float coverage = 0.4;
uniform float overcast = 0.0;
uniform float lightning = 0.0;
// Eventos noturnos: aurora boreal e chuva de estrelas cadentes (0..1, ja multiplicados pela noite).
uniform float aurora = 0.0;
uniform float meteors = 0.0;
uniform float event_seed = 0.0;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float cloud_density(vec2 uv) {
	return texture(cloud_tex, uv).r * 0.60
		+ texture(cloud_tex, uv * 2.9 + cloud_offset * 1.7).r * 0.28
		+ texture(cloud_tex, uv * 7.3 + cloud_offset * 3.1).r * 0.12;
}

float hash1(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

// Aurora: cortinas verdes ondulando, com raios verticais e topo magenta.
vec3 aurora_col(vec3 d) {
	if (d.y <= 0.02) {
		return vec3(0.0);
	}
	vec3 acc = vec3(0.0);
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		// Altura da cortina sobe com a camada; projeta numa "abobada" alta.
		float h = 0.55 + fk * 0.18;
		vec2 p = d.xz / (d.y + 0.08) * h;
		float wave = sin(p.x * 1.3 + TIME * 0.07 + fk * 1.7) * 0.9 + sin(p.x * 3.1 - TIME * 0.11 + fk) * 0.35;
		float band = p.y * 0.9 + wave * 0.5 + (event_seed - 0.5) * 0.6 + fk * 0.35 - 0.15;
		float curtain = exp(-band * band * 2.2);
		float rays = 0.55 + 0.45 * texture(cloud_tex, vec2(p.x * 0.35 + TIME * 0.004 + fk * 0.21, 0.37 + fk * 0.11)).r;
		rays *= 0.6 + 0.4 * sin(p.x * 22.0 + TIME * 0.6 + fk * 4.0);
		float fade = smoothstep(0.05, 0.30, d.y) * (1.0 - smoothstep(0.85, 0.99, d.y));
		vec3 green = vec3(0.12, 1.0, 0.45);
		vec3 top = mix(vec3(0.55, 0.20, 0.95), vec3(0.15, 0.70, 1.0), hash1(fk + event_seed));
		acc += mix(green, top, smoothstep(0.0, 0.8, band + 0.4)) * curtain * rays * fade * (0.85 - fk * 0.18);
	}
	return acc * 0.95;
}

// Estrelas cadentes: rastros finos que cruzam o ceu e somem.
float meteor_streaks(vec3 d) {
	if (d.y <= 0.05) {
		return 0.0;
	}
	vec2 p = d.xz / (d.y + 0.35);
	float sum = 0.0;
	for (int k = 0; k < 5; k++) {
		float fk = float(k);
		float period = 2.6 + hash1(fk * 7.3 + event_seed) * 3.5;
		float t = TIME + hash1(fk * 3.1) * period;
		float cyc = floor(t / period);
		float ph = fract(t / period) * period;
		float life = 0.7 + hash1(cyc * 1.3 + fk) * 0.5;
		if (ph > life) {
			continue;
		}
		float u = ph / life;
		float s = cyc * 13.7 + fk * 5.1 + event_seed * 9.0;
		vec2 a = vec2(hash1(s) - 0.5, hash1(s + 1.0) - 0.5) * 2.2;
		vec2 dir = normalize(vec2(hash1(s + 2.0) - 0.5, -0.4 - hash1(s + 3.0) * 0.6));
		float len = 0.35 + hash1(s + 4.0) * 0.35;
		vec2 head = a + dir * len * u * 2.0;
		vec2 tail = head - dir * len * 0.5;
		vec2 pa = p - tail;
		vec2 ba = head - tail;
		float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
		float dist = length(pa - ba * h);
		float line = exp(-dist * dist * 60000.0) * h * h + exp(-dist * dist * 6000.0) * h * h * h * 0.25;
		float flash = sin(u * 3.14159);
		sum += line * flash;
	}
	return sum;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float sh = sun_dir.y;
	float day = smoothstep(-0.14, 0.2, sh);
	float dusk = (1.0 - smoothstep(0.0, 0.38, abs(sh))) * smoothstep(-0.22, -0.02, sh);

	vec3 zen = mix(vec3(0.003, 0.005, 0.016), vec3(0.09, 0.24, 0.60), day);
	vec3 hor = mix(vec3(0.010, 0.014, 0.032), vec3(0.50, 0.68, 0.90), day);
	vec3 sunset = vec3(1.0, 0.40, 0.12);
	vec2 dh = normalize(d.xz + vec2(0.00001));
	vec2 shz = normalize(sun_dir.xz + vec2(0.00001));
	float toward = max(dot(dh, shz), 0.0);
	hor = mix(hor, sunset, dusk * (0.2 + 0.8 * toward * toward) * 0.85);
	zen = mix(zen, vec3(0.22, 0.16, 0.30), dusk * 0.35);

	float t = pow(1.0 - max(d.y, 0.0), 3.0);
	vec3 col = mix(zen, hor, t);
	col = mix(col, hor * 0.55, (1.0 - smoothstep(-0.25, 0.0, d.y)));

	float lum = dot(col, vec3(0.3, 0.5, 0.2));
	col = mix(col, vec3(lum) * vec3(0.80, 0.85, 0.92), overcast * 0.9);

	float clear = 1.0 - overcast * 0.95;
	float sd = dot(d, sun_dir);
	col += vec3(1.0, 0.62, 0.3) * pow(max(sd, 0.0), 14.0) * 0.28 * clear * smoothstep(-0.2, 0.1, sh);
	col += vec3(1.0, 0.85, 0.6) * pow(max(sd, 0.0), 400.0) * 2.5 * clear;
	if (sd > 0.99955) {
		col += vec3(14.0, 11.5, 8.0) * clear * smoothstep(-0.06, 0.03, sh);
	}

	float night = (1.0 - smoothstep(-0.16, 0.04, sh));
	float md = dot(d, moon_dir);
	col += vec3(0.5, 0.6, 0.8) * pow(max(md, 0.0), 180.0) * 0.25 * night * clear;
	if (md > 0.9994) {
		col += vec3(1.3, 1.4, 1.6) * night * clear;
	}
	if (d.y > 0.0 && night > 0.01) {
		vec3 q = floor(d * 190.0);
		float s = hash3(q);
		float tw = 0.6 + 0.4 * sin(TIME * 2.0 + s * 90.0);
		col += vec3(step(0.9972, s)) * tw * night * clear * smoothstep(0.0, 0.25, d.y) * 1.6;
	}

	if (aurora > 0.001) {
		col += aurora_col(d) * aurora * clear;
	}
	if (meteors > 0.001 && night > 0.01) {
		col += vec3(1.0, 0.95, 0.85) * meteor_streaks(d) * meteors * clear * 2.5;
	}

	if (d.y > 0.0) {
		vec2 uv = d.xz / (d.y + 0.12) * 0.085 + cloud_offset;
		float n = cloud_density(uv);
		float thr = mix(0.74, 0.26, coverage);
		float c = smoothstep(thr, thr + 0.2, n);
		vec3 ldir = sh > -0.05 ? sun_dir : moon_dir;
		float n2 = cloud_density(uv + normalize(ldir.xz + vec2(0.0001)) * 0.014);
		float shade = clamp(0.55 + (n - n2) * 3.2, 0.0, 1.0);
		vec3 lit = mix(vec3(0.035, 0.045, 0.07), vec3(1.0, 0.98, 0.95), day);
		lit = mix(lit, sunset * 1.15, dusk * 0.65 * (0.4 + 0.6 * toward));
		vec3 dark = lit * mix(0.5, 0.2, overcast);
		vec3 ccol = mix(dark, lit, shade * (1.0 - overcast * 0.65));
		ccol += lightning * vec3(0.9, 0.95, 1.2) * 1.5;
		c *= smoothstep(0.0, 0.13, d.y);
		col = mix(col, ccol, c * 0.96);
	}
	col += lightning * vec3(0.12, 0.13, 0.18);
	COLOR = col;
}
