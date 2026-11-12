class_name TexShader
extends RefCounted
## Compute shader que gera todas as camadas PBR (albedo, altura, rugosidade/metal/emissao, normal, AO).
## Cada camada e descrita por um padrao + cores (Blocks.LAYERS), lidos de um storage buffer.
## Passo 0: cor e altura por pixel. Passo 1: normal e oclusao de cavidade a partir da altura.
## Todo ruido e periodico (repete a cada 256 px), entao as texturas emendam sem costura.

const BODY := """
float ss(float a, float b, float x) {
	float t = clamp((x - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

uint hsh(uint x, uint y, uint s) {
	uint h = x * 2654435761u + y * 2246822519u + s * 3266489917u;
	h ^= h >> 15u;
	h *= 739982445u;
	h ^= h >> 12u;
	h *= 695872825u;
	h ^= h >> 15u;
	return h;
}

float h01(int a, int b, int s) {
	return float(hsh(uint(a), uint(b), uint(s)) & 0xFFFFFFu) / 16777215.0;
}

int wrapi(int a, int p) {
	return ((a % p) + p) % p;
}

float pgrad(ivec2 i, int per, vec2 f, uint s) {
	uint h = hsh(uint(wrapi(i.x, per)), uint(wrapi(i.y, per)), s) & 7u;
	float sx = (h & 1u) == 0u ? 1.0 : -1.0;
	float sy = (h & 2u) == 0u ? 1.0 : -1.0;
	if (h < 4u) {
		return sx * f.x + sy * f.y;
	}
	if (h < 6u) {
		return sx * f.x * 1.4142;
	}
	return sx * f.y * 1.4142;
}

float pnoise(vec2 p, int per, uint s) {
	vec2 fl = floor(p);
	ivec2 i = ivec2(fl);
	vec2 f = p - fl;
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = pgrad(i, per, f, s);
	float b = pgrad(i + ivec2(1, 0), per, f - vec2(1.0, 0.0), s);
	float c = pgrad(i + ivec2(0, 1), per, f - vec2(0.0, 1.0), s);
	float d = pgrad(i + ivec2(1, 1), per, f - vec2(1.0, 1.0), s);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float pfbm(vec2 uv, int cells, uint s, int oct) {
	float amp = 1.0;
	float sum = 0.0;
	float norm = 0.0;
	int per = cells;
	for (int k = 0; k < oct; k++) {
		sum += amp * pnoise(uv * float(per), per, s + uint(k) * 131u);
		norm += amp;
		per *= 2;
		amp *= 0.5;
	}
	return clamp(0.5 + sum / norm * 1.15, 0.0, 1.0);
}

vec2 pcell(vec2 uv, int cells, int s) {
	vec2 p = uv * float(cells);
	vec2 fl = floor(p);
	ivec2 i = ivec2(fl);
	vec2 f = p - fl;
	float d1 = 8.0;
	float d2 = 8.0;
	float cv = 0.0;
	for (int oy = -1; oy <= 1; oy++) {
		for (int ox = -1; ox <= 1; ox++) {
			ivec2 c = i + ivec2(ox, oy);
			int wx = wrapi(c.x, cells);
			int wy = wrapi(c.y, cells);
			vec2 r = vec2(h01(wx, wy, s), h01(wx, wy, s + 7));
			float d = length(vec2(float(ox), float(oy)) + r - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				cv = h01(wx, wy, s + 13);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec2(clamp((d2 - d1) * 1.1, 0.0, 1.0), cv);
}

vec3 tile(float u, float v, int rows, int cols, float off, int sd) {
	float ry = v * float(rows);
	float row = floor(ry);
	float fy = ry - row;
	int irow = int(row);
	float ux = u * float(cols) + ((irow & 1) == 1 ? off : 0.0);
	float col = floor(ux);
	float fx = ux - col;
	int icol = wrapi(int(col), cols);
	float dx = min(fx, 1.0 - fx) / float(cols);
	float dy = min(fy, 1.0 - fy) / float(rows);
	return vec3(min(dx, dy), h01(irow * 31 + sd, icol * 17 + 3, 0), fy);
}

vec3 C;
float A;
float Hh;
float R;
float MT;
float EM;

void dirt(vec3 c0, vec3 c1, vec3 c2, float pebbles, float b, float g, float e, float k) {
	C = mix(c0, c1, b * 0.6 + g * 0.4);
	float peb = ss(0.5, 0.8, e) * (k > 0.6 ? 1.0 : 0.0) * pebbles;
	C = mix(C, c2, peb * 0.8);
	Hh = 0.25 + 0.3 * b + 0.2 * g + peb * 0.3;
	R = 0.95;
}

void stone(vec3 c0, vec3 c1, float cracks, float a, float b, float g, float e) {
	C = mix(c0, c1, a * 0.45 + b * 0.55);
	float crack = (1.0 - ss(0.0, 0.07, e)) * ss(0.35, 0.6, b) * cracks;
	C *= (0.88 + 0.24 * g) * (1.0 - 0.5 * crack);
	Hh = 0.45 + 0.3 * b + 0.2 * g - crack * 0.45;
	R = 0.8;
}

void grass(vec3 c0, vec3 c1, vec3 c2, float a, float b, float g) {
	C = mix(c0, c1, b * 0.55 + g * 0.45);
	C = mix(C, c2, ss(0.6, 0.92, a) * 0.5);
	C *= 0.82 + 0.36 * g;
	Hh = 0.35 + 0.55 * g + 0.1 * b;
	R = 0.9;
}

void planks(vec3 c0, vec3 c1, float u, float v, float a, float b, float g) {
	vec3 tl = tile(u, v, 4, 1, 0.37, 5);
	float grain = sin(TAU * (v * 20.0 + b * 2.5 + a * 4.0)) * 0.5 + 0.5;
	C = mix(c0, c1, grain * 0.55 + tl.y * 0.45);
	C *= 0.9 + 0.15 * g;
	float bev = ss(0.004, 0.022, tl.x);
	Hh = 0.15 + bev * (0.6 + 0.12 * grain);
	R = 0.62;
	if (bev < 0.5) {
		C *= vec3(0.45, 0.42, 0.4);
	}
}

void cobble(vec3 c0, vec3 c1, vec3 c2, float moss, float b, float g, float e, float k) {
	float dome = ss(0.03, 0.34, e);
	if (e < 0.05) {
		C = c2;
		Hh = 0.05 + g * 0.08;
		R = 0.96;
	} else {
		C = mix(c0, c1, k);
		C *= (0.85 + 0.3 * g) * (0.75 + 0.25 * dome);
		Hh = 0.2 + dome * 0.75;
		R = 0.82;
	}
	C = mix(C, vec3(0.18, 0.36, 0.11) * (0.75 + 0.5 * g), ss(0.42, 0.66, b) * moss);
}

// x,y = vetor do pixel ao centro da celula mais proxima; z = id aleatorio; w = distancia.
vec4 nearest(vec2 uv, int cells, int s) {
	vec2 p = uv * float(cells);
	vec2 fl = floor(p);
	ivec2 i = ivec2(fl);
	vec2 f = p - fl;
	float best = 8.0;
	vec2 bv = vec2(0.0);
	float bid = 0.0;
	for (int oy = -1; oy <= 1; oy++) {
		for (int ox = -1; ox <= 1; ox++) {
			ivec2 c = i + ivec2(ox, oy);
			int wx = wrapi(c.x, cells);
			int wy = wrapi(c.y, cells);
			vec2 r = vec2(h01(wx, wy, s), h01(wx, wy, s + 7));
			vec2 dv = f - (vec2(float(ox), float(oy)) + r);
			float d = length(dv);
			if (d < best) {
				best = d;
				bv = dv;
				bid = h01(wx, wy, s + 13);
			}
		}
	}
	return vec4(bv, bid, best);
}

// Uma folha em formato de lanca: devolve (dentro?, sombreamento 0..1, nervura).
vec3 leaf_shape(vec4 nc, float len, float wid) {
	float ang = nc.z * TAU;
	vec2 q = vec2(cos(ang) * nc.x + sin(ang) * nc.y, -sin(ang) * nc.x + cos(ang) * nc.y);
	float t = q.x / len;
	if (abs(t) > 1.0) {
		return vec3(0.0);
	}
	float w = wid * pow(max(1.0 - t * t, 0.0), 0.75) * (t < 0.0 ? 1.0 : 0.85);
	if (abs(q.y) > w) {
		return vec3(0.0);
	}
	float across = abs(q.y) / max(w, 0.001);
	float vein = (abs(q.y) < 0.025 ? 1.0 : 0.0) + (abs(fract((q.x + abs(q.y) * 1.3) * 7.0) - 0.5) < 0.06 && across < 0.85 ? 0.5 : 0.0);
	return vec3(1.0, 1.0 - across, vein);
}

// Laminas de capim curvas: x = altura relativa (0 = sem lamina), y = posicao transversal (-1..1), z = id.
vec3 blades3(float u, float v, int count, int sd, float wid) {
	float t = 1.0 - v;
	vec3 best = vec3(0.0);
	for (int k = 0; k < count; k++) {
		float hh = 0.45 + h01(k, sd + 5, 1) * 0.5;
		if (t > hh) {
			continue;
		}
		float bx = (float(k) + 0.5) / float(count) + (h01(k, sd, 1) - 0.5) * 0.08;
		float lean = (h01(k, sd + 9, 1) - 0.5) * 0.45;
		float q = t / hh;
		float cx = bx + lean * q * q * q;
		float w = (0.024 * pow(1.0 - q, 0.8) + 0.003) * wid;
		float dx = u - cx;
		if (abs(dx) < w && 0.3 + 0.7 * q > best.x) {
			best = vec3(0.3 + 0.7 * q, dx / w, h01(k, sd + 3, 1));
		}
	}
	return best;
}

float blades(float u, float v, int count, int sd, float wid) {
	float t = 1.0 - v;
	float best = 0.0;
	for (int k = 0; k < count; k++) {
		float hh = 0.45 + h01(k, sd + 5, 1) * 0.5;
		if (t > hh) {
			continue;
		}
		float bx = (float(k) + 0.5) / float(count) + (h01(k, sd, 1) - 0.5) * 0.08;
		float lean = (h01(k, sd + 9, 1) - 0.5) * 0.35;
		float q = t / hh;
		float cx = bx + lean * q * q;
		float w = (0.038 * (1.0 - q) + 0.006) * wid;
		if (abs(u - cx) < w) {
			best = max(best, 0.35 + 0.65 * q);
		}
	}
	return best;
}

void shade(int layer, ivec2 px) {
	LayerDef D = defs.d[layer];
	vec3 c0 = D.c0.rgb;
	vec3 c1 = D.c1.rgb;
	vec3 c2 = D.c2.rgb;
	vec4 P = D.p;
	int pat = D.i.x;
	uint sd = uint(D.i.z);
	int isd = D.i.z;
	float u = (float(px.x) + 0.5) / 256.0;
	float v = (float(px.y) + 0.5) / 256.0;
	vec2 uv = vec2(u, v);
	float a = pfbm(uv, 2, sd, 3);
	float b = pfbm(uv, 8, sd + 1u, 4);
	float g = pfbm(uv, 56, sd + 2u, 2);
	vec2 cl = pcell(uv, D.i.y, isd + 3);
	float e = cl.x;
	float k = cl.y;
	float edge = min(min(u, 1.0 - u), min(v, 1.0 - v));
	C = c0;
	A = 1.0;
	Hh = 0.5;
	R = 0.85;
	MT = 0.0;
	EM = 0.0;

	if (pat == 0) {
		grass(c0, c1, c2, a, b, g);
	} else if (pat == 1) {
		dirt(c0, c1, c2, P.x, b, g, e, k);
		R = P.y;
	} else if (pat == 2) {
		stone(c0, c1, P.x, a, b, g, e);
		float sp = h01(px.x / 2, px.y / 2, isd + 21);
		C = mix(C, c2, (sp > 0.80 ? 1.0 : 0.0) * P.y * 0.8);
		C = mix(C, c1 * 1.15, (sp < 0.10 ? 1.0 : 0.0) * P.y * 0.6);
		R = P.z;
	} else if (pat == 3) {
		C = mix(c0, c1, b);
		float rip = sin(TAU * (v * 9.0 + a * 1.6)) * 0.5 + 0.5;
		C *= (0.92 + 0.16 * g) * (0.94 + 0.08 * rip);
		Hh = 0.4 + 0.25 * rip + 0.2 * g;
		R = 0.92;
	} else if (pat == 4) {
		C = mix(c0, c1, b * 0.7 + g * 0.3);
		Hh = 0.4 + 0.35 * b + 0.2 * a + 0.05 * g;
		R = P.x > 0.0 ? P.x + 0.1 * g : 0.5 + 0.2 * g;
		if (P.x > 0.0) {
			float crack = (1.0 - ss(0.0, 0.035, e)) * ss(0.4, 0.6, b);
			C = mix(C, vec3(0.95, 0.98, 1.0), crack * 0.7);
		}
	} else if (pat == 5) {
		C = mix(c0, c1, k);
		float dome = ss(0.0, 0.3, e);
		C *= (0.85 + 0.3 * g) * (0.55 + 0.45 * dome);
		Hh = dome * 0.85 + g * 0.1;
		R = 0.88;
	} else if (pat == 6) {
		float vein = abs(sin(TAU * (u * 2.0 + a * 2.6 + b * 0.5)));
		float vv = 1.0 - ss(0.0, 0.09, vein);
		float vein2 = 1.0 - ss(0.0, 0.05, abs(sin(TAU * (v * 3.0 + b * 2.0 + a))));
		C = mix(c0, c1, max(vv * 0.85, vein2 * 0.4));
		C = mix(C, c0 * 0.92, b * 0.35);
		Hh = 0.7 - vv * 0.06;
		R = P.x + 0.1 * g;
	} else if (pat == 7) {
		dirt(vec3(0.24, 0.16, 0.10), vec3(0.43, 0.30, 0.19), vec3(0.50, 0.47, 0.43), 1.0, b, g, e, k);
		float fr = pfbm(vec2(u, 0.5 / 256.0), 56, sd + 2u, 2);
		float fr2 = pfbm(vec2(u, 37.5 / 256.0), 8, sd + 1u, 4);
		float thr = 0.14 + 0.16 * fr + 0.10 * fr2;
		if (v < thr) {
			float hh = Hh;
			if (P.x < 0.5) {
				grass(c0, c1, c2, a, b, g);
			} else {
				C = mix(c0, c1, b * 0.7 + g * 0.3);
				R = 0.5 + 0.2 * g;
			}
			float ed = 1.0 - ss(thr - 0.06, thr, v);
			Hh = mix(hh, 0.95, ed);
			C *= 0.8 + 0.2 * ed;
		}
	} else if (pat == 8) {
		float r = sin(TAU * (u * 9.0 + b * 1.3 + a * 2.2)) * 0.5 + 0.5;
		float r2 = sin(TAU * (u * 23.0 + b * 2.0)) * 0.5 + 0.5;
		float bk = r * 0.75 + r2 * 0.25;
		if (P.x < 0.5) {
			C = mix(c0, c1, bk * 0.75 + g * 0.25);
			Hh = bk * 0.8 + g * 0.2;
		} else {
			// Casca clara com marcas horizontais escuras (estilo betula).
			C = mix(c0, c1, b * 0.5 + g * 0.5);
			Hh = 0.6 + g * 0.2;
			int row = int(floor(v * 16.0));
			float ro = h01(row, 1, isd);
			float fx = fract(u * 4.0 + ro);
			int seg = wrapi(int(floor(u * 4.0 + ro)), 4);
			float fy = fract(v * 16.0);
			if (h01(row, seg, isd + 2) > 0.68 && fx > 0.12 && fx < 0.88 && fy > 0.25 && fy < 0.8) {
				C = c2 * (0.8 + 0.6 * g);
				Hh = 0.3;
			}
		}
		R = 0.92;
	} else if (pat == 9) {
		float dx = u - 0.5;
		float dy = v - 0.5;
		float d = sqrt(dx * dx + dy * dy) * (1.0 + (a - 0.5) * 0.25);
		float ring = sin(d * TAU * 11.0) * 0.5 + 0.5;
		C = mix(c0, c1, ring * 0.7 + g * 0.3);
		Hh = 0.6 + ring * 0.12;
		R = 0.75;
		if (max(abs(dx), abs(dy)) > 0.44) {
			C = c2 * (0.7 + 0.6 * g);
			Hh = 0.85;
			R = 0.92;
		}
	} else if (pat == 10) {
		planks(c0, c1, u, v, a, b, g);
	} else if (pat == 11) {
		int rows = int(P.x);
		vec3 tl = tile(u, v, rows, int(P.y), 0.5, 9);
		float sc = 4.0 / float(rows);
		float bev = ss(0.012 * sc, 0.034 * sc, tl.x);
		if (tl.x < 0.0125 * sc) {
			C = c2 * (0.85 + 0.25 * g);
			Hh = 0.22 + g * 0.1;
			R = 0.96;
		} else {
			C = mix(c0, c1, tl.y * 0.7 + b * 0.3);
			C = mix(C, c0 * 0.6, ss(0.55, 0.9, b) * P.z);
			C *= 0.85 + 0.3 * g;
			Hh = 0.35 + bev * (0.5 + 0.15 * b);
			R = 0.8;
		}
	} else if (pat == 12) {
		cobble(c0, c1, c2, P.x, b, g, e, k);
	} else if (pat == 13) {
		float s = fract((u + v) * 1.5);
		if (edge < 0.05) {
			C = mix(c0, vec3(0.95), 0.55);
			A = 0.92;
			Hh = 0.9;
		} else if ((s > 0.30 && s < 0.36) || (s > 0.42 && s < 0.44)) {
			C = mix(c0, vec3(1.0), 0.8);
			A = 0.32 + P.x * 0.2;
		} else {
			C = c0;
			A = 0.10 + P.x * 0.32;
		}
		R = 0.05;
	} else if (pat == 14) {
		int mode = int(P.z + 0.5);
		A = 0.0;
		R = 0.65;
		int cells = D.i.y;
		for (int layer2 = 0; layer2 < 2; layer2++) {
			int cn = layer2 == 0 ? cells : int(float(cells) * 1.6);
			vec4 nc = nearest(uv, cn, isd + 20 + layer2 * 31);
			vec3 lf = vec3(0.0);
			if (mode == 1) {
				// Agulhas: tracos finos em leque.
				float ang = nc.z * TAU;
				vec2 qd = vec2(cos(ang) * nc.x + sin(ang) * nc.y, -sin(ang) * nc.x + cos(ang) * nc.y);
				if (abs(qd.y) < 0.10 && abs(qd.x) < 0.95) {
					lf = vec3(1.0, 1.0 - abs(qd.y) / 0.10, 0.0);
				}
			} else if (mode == 2) {
				// Flor de cinco petalas.
				float r = length(nc.xy);
				float th = atan(nc.y, nc.x) + nc.z * TAU;
				float pr = 0.46 * (0.6 + 0.4 * abs(cos(th * 2.5)));
				if (r < pr) {
					lf = vec3(1.0, 1.0 - r / pr, r < 0.09 ? 1.0 : 0.0);
				}
			} else {
				lf = leaf_shape(nc, 0.62, 0.30);
			}
			if (lf.x > 0.0) {
				vec3 lc = mix(c0, c1, nc.z * 0.6 + g * 0.4);
				lc *= 0.62 + 0.45 * lf.y;
				lc = mix(lc, c1 * 1.25, lf.z * (mode == 2 ? 0.0 : 0.22));
				if (mode == 2 && lf.z > 0.5) {
					lc = vec3(0.95, 0.85, 0.45);
				}
				// Folhas de baixo ficam mais escuras (sombra da camada de cima).
				C = layer2 == 0 && A > 0.5 ? C : lc * (layer2 == 0 ? 0.82 : 1.0);
				A = 1.0;
				Hh = 0.35 + 0.6 * lf.y + float(layer2) * 0.1;
			}
		}
		// Pinheiro: ramos escuros preenchem o fundo entre as agulhas.
		if (mode == 1 && A < 0.5 && g > 0.42) {
			C = mix(c0, c1, 0.25) * (0.55 + 0.35 * g);
			A = 1.0;
			Hh = 0.2;
		}
		// Frutas: bolinhas com brilho, cabinho e sombra.
		if (P.y > 0.0) {
			vec4 fc = nearest(uv, 9, isd + 77);
			if (fc.z < P.y * 2.5) {
				float r = length(fc.xy);
				if (r < 0.24) {
					float sh = 1.0 - r / 0.24;
					C = c2 * (0.55 + 0.6 * sh);
					if (length(fc.xy - vec2(-0.07, -0.08)) < 0.06) {
						C = mix(C, vec3(1.0), 0.6);
					}
					A = 1.0;
					Hh = 0.6 + 0.4 * sh;
					R = 0.35;
				} else if (r < 0.32 && fc.y < -0.2 && abs(fc.x) < 0.03) {
					C = vec3(0.30, 0.22, 0.10);
					A = 1.0;
				}
			}
		}
	} else if (pat == 15) {
		// P.w encolhe as hastes (estagios de plantacao); P.z = 3 desenha a raiz/tuberculo na base.
		float vs = P.w > 0.0 ? 1.0 - (1.0 - v) / P.w : v;
		vec3 b3 = vs < 0.0 ? vec3(0.0) : blades3(u, vs, int(P.x), isd, P.y);
		float bl = b3.x;
		C = mix(c0, c1, 0.25 + 0.75 * bl);
		C *= 0.86 + 0.28 * b3.z;
		C *= 0.78 + 0.32 * (1.0 - abs(b3.y));
		C = mix(C, c1 * 1.3, (abs(b3.y) < 0.2 ? 0.25 : 0.0) * bl);
		C = mix(C, vec3(0.92, 0.88, 0.55), ss(0.85, 1.0, bl) * 0.35);
		A = bl > 0.0 ? 1.0 : 0.0;
		if (P.z > 0.5 && P.z < 1.5 && bl > 0.82) {
			C = c2;
		}
		if (P.z > 2.5 && v > 0.84 && fract(u * 4.0 + 0.25) < 0.5) {
			C = c2 * (0.8 + 0.4 * g);
			A = 1.0;
		}
		if (P.z > 1.5 && P.z < 2.5) {
			// Preenchido (feno): hastes sobre fundo opaco, com cintas.
			C = bl > 0.0 ? mix(c0, c1, bl) : c0 * (0.6 + 0.3 * g);
			A = 1.0;
			Hh = 0.3 + bl * 0.6;
			if (abs(v - 0.25) < 0.03 || abs(v - 0.75) < 0.03) {
				C = vec3(0.45, 0.30, 0.14);
				Hh = 0.95;
			}
		}
		R = 0.75;
	} else if (pat == 16) {
		int style = int(P.z + 0.5);
		A = 0.0;
		R = 0.7;
		vec3 stem_c = vec3(0.16, 0.38, 0.10);
		float top_v = style == 3 ? 0.30 : (style == 2 ? 0.10 : 0.28);
		float stem_x = 0.5 + 0.03 * sin(v * 6.0);
		if (v > top_v && abs(u - stem_x) < (style == 3 ? 0.03 : 0.018)) {
			C = stem_c * (0.85 + 0.3 * (1.0 - abs(u - stem_x) / 0.03));
			A = 1.0;
		}
		// Folhas do caule com nervura.
		for (int lk = 0; lk < 2; lk++) {
			float side = lk == 0 ? -1.0 : 1.0;
			vec2 lc = vec2(0.5 + side * 0.13, lk == 0 ? 0.74 : 0.62);
			vec2 lq = vec2(u, v) - lc;
			vec2 rq = vec2(lq.x * side * 0.9 + lq.y * 0.45, lq.y * 0.9 - lq.x * side * 0.45);
			float lw = 0.05 * (1.0 - pow(rq.x / 0.14, 2.0));
			if (abs(rq.x) < 0.14 && abs(rq.y) < lw) {
				C = vec3(0.18, 0.44, 0.12) * (0.75 + 0.35 * (1.0 - abs(rq.y) / max(lw, 0.001)));
				if (abs(rq.y) < 0.006) {
					C *= 1.25;
				}
				A = 1.0;
			}
		}
		vec2 fc = vec2(u - 0.5, v - 0.26);
		float d = length(fc);
		float th = atan(fc.y, fc.x);
		if (style == 0) {
			// Duas coroas de petalas defasadas, com veios e miolo granulado.
			float pr2 = 0.16 + 0.07 * cos(th * P.x + 0.6 + PI / P.x);
			float pr = 0.12 + 0.06 * cos(th * P.x + 0.6);
			if (d < pr2) {
				C = c0 * (0.55 + 0.25 * (d / pr2));
				A = 1.0;
				Hh = 0.7;
			}
			if (d < pr) {
				C = c0 * (0.75 + 0.35 * (d / pr));
				if (abs(fract(th * P.x / TAU + 0.5) - 0.5) < 0.03) {
					C *= 0.8;
				}
				A = 1.0;
				Hh = 0.85;
			}
			if (d < 0.05) {
				C = c1 * (0.7 + 0.5 * h01(px.x, px.y, isd));
				A = 1.0;
				Hh = 1.0;
			}
		} else if (style == 1) {
			// Tulipa: taca de petalas com borda em pontas.
			vec2 q = vec2(u - 0.5, v - 0.2);
			float halfw = 0.11 * (1.0 - pow(max(q.y - 0.02, 0.0) / 0.12, 2.0));
			float tip = q.y < -0.06 ? 0.03 * abs(sin(q.x * 40.0)) : 0.0;
			if (q.y > -0.12 + tip && q.y < 0.12 && abs(q.x) < halfw) {
				C = c0 * (0.6 + 0.5 * (1.0 - abs(q.x) / max(halfw, 0.001)));
				if (abs(abs(q.x) - halfw * 0.35) < 0.008) {
					C *= 0.75;
				}
				A = 1.0;
				Hh = 0.85;
			}
		} else if (style == 2) {
			// Lavanda: espiga de florzinhas ao longo do caule.
			for (int fk = 0; fk < 9; fk++) {
				float fy = 0.12 + float(fk) * 0.04;
				float fx = 0.5 + (fk % 2 == 0 ? -0.025 : 0.025);
				if (length(vec2(u - fx, (v - fy) * 1.3)) < 0.03) {
					C = mix(c0, c1, h01(fk, 3, isd)) * (0.75 + 0.35 * h01(px.x, px.y, isd + 5));
					A = 1.0;
					Hh = 0.9;
				}
			}
		} else {
			// Girassol: muitas petalas finas e miolo escuro com sementes em espiral.
			fc = vec2(u - 0.5, v - 0.3);
			d = length(fc);
			th = atan(fc.y, fc.x);
			float pr = 0.22 + 0.05 * cos(th * 16.0);
			if (d < pr) {
				C = c0 * (0.75 + 0.35 * (d / pr));
				A = 1.0;
				Hh = 0.8;
			}
			if (d < 0.12) {
				float sp = fract(d * 60.0 + th * 2.0);
				C = c1 * (0.6 + 0.6 * step(0.5, sp));
				A = 1.0;
				Hh = 1.0;
			}
		}
	} else if (pat == 17) {
		A = 0.0;
		R = 0.6;
		if (abs(u - 0.5) < 0.065 + 0.02 * (v - 0.5) && v > 0.45 && v < 0.98) {
			C = c1 * (0.85 + 0.2 * g);
			A = 1.0;
		}
		vec2 cp = vec2((u - 0.5) / 0.32, (v - 0.47) / 0.24);
		if (length(cp) < 1.0 && v < 0.5) {
			C = c0 * (0.75 + 0.35 * (1.0 - length(cp)));
			A = 1.0;
			Hh = 0.9;
			vec2 sc = pcell(uv, 9, isd + 40);
			if (sc.x > 0.55 && sc.y > 0.4) {
				C = c2;
			}
		}
	} else if (pat == 18) {
		if (P.x > 1.5) {
			// Cupula de tecido iluminada por dentro.
			float weave = sin(u * TAU * 24.0) * sin(v * TAU * 24.0);
			C = mix(c0, c1, 0.5 + 0.5 * weave) * (0.9 + 0.2 * b);
			EM = 0.75;
			R = 0.9;
			if (v < 0.06 || v > 0.94) {
				C *= 0.55;
				EM = 0.2;
			}
		} else if (P.x > 0.5) {
			// Chama.
			C = mix(c0, c1, ss(0.2, 0.8, 1.0 - v + (b - 0.5) * 0.6));
			EM = 1.0;
			R = 0.3;
		} else if (edge < 0.11 || abs(u - 0.5) < 0.035 || abs(v - 0.5) < 0.03) {
			C = c0 * (0.8 + 0.4 * g);
			MT = 0.9;
			R = 0.42;
			Hh = 1.0;
		} else {
			C = mix(c1, vec3(1.0, 0.92, 0.65), b);
			EM = 1.0;
			R = 0.2;
			Hh = 0.45;
		}
	} else if (pat == 19) {
		stone(vec3(0.33, 0.33, 0.34), vec3(0.57, 0.56, 0.54), 0.0, a, b, g, 1.0);
		if (k > 0.52 && e > 0.2) {
			float t = ss(0.2, 0.4, e);
			C = mix(C, mix(c0, c1, g), t);
			R = mix(R, 0.4, t);
			MT = P.x * t;
			EM = P.y * t;
			Hh += 0.18 * t;
		}
	} else if (pat == 20) {
		vec3 tl = tile(u, v, 4, 4, 0.5, 21);
		float row = floor(v * 4.0);
		float fx = fract(u * 4.0 + (mod(row, 2.0) > 0.5 ? 0.5 : 0.0));
		float barrel = sin(fx * PI);
		C = mix(c0, c1, tl.y);
		C *= (0.62 + 0.38 * tl.z) * (0.8 + 0.2 * barrel) * (0.9 + 0.2 * g);
		Hh = (0.15 + 0.7 * tl.z) * (0.6 + 0.4 * barrel);
		R = 0.7;
	} else if (pat == 21) {
		float bands = sin(TAU * (v * 5.0 + a * 1.2)) * 0.5 + 0.5;
		C = mix(c0, c1, bands * 0.7 + g * 0.3);
		Hh = 0.45 + 0.22 * bands + 0.15 * g;
		R = 0.86;
		if (P.x > 0.5) {
			vec3 tl = tile(u, v, 2, 1, 0.5, 4);
			if (tl.x < 0.008) {
				C *= 0.55;
				Hh = 0.15;
			}
		}
	} else if (pat == 22) {
		float weave = sin(u * TAU * 16.0) * sin(v * TAU * 16.0);
		float fluff = pfbm(uv, 24, sd + 9u, 2);
		C = c0 * (0.80 + 0.14 * weave + 0.22 * (fluff - 0.5) + 0.1 * b);
		Hh = 0.35 + 0.3 * (weave * 0.5 + 0.5) + 0.3 * fluff;
		R = 0.96;
	} else if (pat == 23) {
		C = c0 * (1.0 - P.y * 0.5 + P.y * (b * 0.6 + g * 0.4));
		Hh = 0.5 + 0.12 * g + 0.1 * b;
		R = P.x;
	} else if (pat == 24) {
		vec3 tl = tile(u, v, 2, 2, 0.0, 3);
		C = mix(c0, c1, b * 0.55 + tl.y * 0.3 + 0.15 * sin(TAU * (v * 40.0 + a * 3.0)));
		Hh = 0.65;
		MT = 0.95;
		R = P.x + 0.15 * g;
		if (tl.x < 0.012) {
			C *= 0.45;
			Hh = 0.2;
		}
		vec2 rv = abs(fract(uv * 2.0) - 0.5);
		if (length(rv - vec2(0.38)) < 0.035) {
			C = c1 * 1.1;
			Hh = 1.0;
		}
	} else if (pat == 25) {
		C = mix(c0, c1, k * 0.8 + g * 0.2);
		Hh = 0.4 + k * 0.4;
		if (e < 0.06) {
			C = mix(C, c1 * 1.2, 0.7);
			Hh = 0.9;
		}
		R = 0.12 + 0.1 * g;
		EM = P.x * k;
	} else if (pat == 26) {
		planks(c0, c1, u, v, a, b, g);
		if (edge > 0.07 && abs(v - 0.5) > 0.035) {
			float rowi = v < 0.5 ? 0.0 : 1.0;
			float bu = u * 9.0 + rowi * 3.3;
			int bi = int(floor(bu));
			float bf = fract(bu);
			float hue = h01(bi, int(rowi), isd);
			vec3 bc = hue < 0.2 ? vec3(0.55, 0.12, 0.10) : (hue < 0.4 ? vec3(0.12, 0.25, 0.50) : (hue < 0.6 ? vec3(0.15, 0.40, 0.18)
				: (hue < 0.8 ? vec3(0.50, 0.38, 0.14) : vec3(0.32, 0.16, 0.38))));
			float top = 0.08 + h01(bi, 5, isd) * 0.05;
			float lv = fract(v * 2.0);
			if (lv > top) {
				C = bc * (0.8 + 0.3 * g) * (bf < 0.1 || bf > 0.9 ? 0.6 : 1.0);
				Hh = 0.55 + 0.25 * sin(bf * PI);
				if (abs(lv - 0.3) < 0.02 || abs(lv - 0.75) < 0.02) {
					C = vec3(0.85, 0.72, 0.3);
				}
			} else {
				C = c2 * 0.5;
				Hh = 0.1;
			}
			R = 0.7;
		} else {
			C = c2 * (0.9 + 0.3 * g);
			Hh = 0.95;
		}
	} else if (pat == 27) {
		planks(c0, c1, u, v, a, b, g);
		int var = int(P.x);
		bool fr = edge < 0.085;
		if (var == 1 && (abs(u - v) < 0.05 || abs(u + v - 1.0) < 0.05)) {
			fr = true;
		}
		if (var == 4 && (abs(fract(u * 3.0) - 0.5) > 0.47 || abs(fract(v * 3.0) - 0.5) > 0.47)) {
			fr = true;
		}
		if (var == 5 && ((abs(u - 0.3) < 0.14 && abs(v - 0.55) < 0.2) || (abs(u - 0.7) < 0.14 && abs(v - 0.55) < 0.2))) {
			C *= 0.6;
			Hh = 0.3;
		}
		if (fr) {
			C = c2 * (0.85 + 0.35 * g);
			Hh = 0.92;
		}
		if (var == 2) {
			if (abs(v - 0.34) < 0.045) {
				C = c2 * 0.7;
				Hh = 0.95;
			}
			if (abs(u - 0.5) < 0.07 && abs(v - 0.36) < 0.1) {
				C = vec3(0.72, 0.72, 0.75) * (0.8 + 0.3 * g);
				MT = 1.0;
				R = 0.35;
				Hh = 1.0;
			}
		}
		if (var == 6) {
			// Porta: tabuas verticais, moldura, almofada com chanfro e macaneta de latao.
			vec3 tlv = tile(v, u, 4, 1, 0.0, 9);
			C = mix(c0, c1, tlv.y * 0.6 + b * 0.4) * (0.9 + 0.15 * g);
			Hh = 0.5;
			vec2 pc = abs(uv - vec2(0.5, 0.5));
			float inset = max(pc.x / 0.32, pc.y / 0.36);
			if (edge < 0.07) {
				C = c2 * (0.85 + 0.3 * g);
				Hh = 0.95;
			} else if (inset < 1.0) {
				float bevel = ss(0.82, 1.0, inset);
				C *= 0.95 + 0.15 * (1.0 - bevel) - 0.25 * bevel * step(uv.x + uv.y, 1.0);
				Hh = 0.7 - 0.25 * bevel;
			}
			if (length(uv - vec2(0.86, 0.5)) < 0.045) {
				C = vec3(0.86, 0.66, 0.24) * (0.8 + 0.4 * g);
				MT = 1.0;
				R = 0.3;
				Hh = 1.0;
			}
		}
		if (var == 8) {
			// Porta de tabuas com cintas de metal (c2), rebites, dobradicas e argola.
			vec3 tlv = tile(v, u, 5, 1, 0.0, 11);
			C = mix(c0, c1, tlv.y * 0.55 + b * 0.45) * (0.88 + 0.16 * g);
			Hh = 0.5 + 0.25 * sin(fract(u * 5.0) * PI);
			if (tlv.x < 0.012) {
				C *= 0.45;
				Hh = 0.2;
			}
			bool strap = abs(v - 0.2) < 0.055 || abs(v - 0.8) < 0.055;
			bool diag = abs((1.0 - v) - u * 0.6 - 0.2) < 0.04 && v > 0.25 && v < 0.75;
			if (strap || diag || edge < 0.04) {
				C = c2 * (0.75 + 0.35 * g + 0.15 * b);
				MT = 0.95;
				R = 0.42;
				Hh = 0.95;
			}
			vec2 rv = fract(uv * vec2(5.0, 1.0)) - 0.5;
			if (strap && abs(rv.x) < 0.09 && (abs(v - 0.2) < 0.022 || abs(v - 0.8) < 0.022)) {
				C = c2 * 1.35;
				Hh = 1.0;
			}
			float ring = abs(length(uv - vec2(0.82, 0.52)) - 0.06);
			if (ring < 0.014) {
				C = c2 * 1.2;
				MT = 1.0;
				R = 0.3;
				Hh = 1.0;
			}
		}
		if (var == 7) {
			// Porta de ferro: chapas, faixas e rebites.
			C = mix(c0, c1, b * 0.5 + g * 0.3 + 0.2 * sin(TAU * (v * 30.0 + a * 2.0)));
			MT = 0.95;
			R = 0.38 + 0.15 * g;
			Hh = 0.6;
			if (abs(v - 0.25) < 0.04 || abs(v - 0.75) < 0.04 || edge < 0.06) {
				C = c2 * (0.8 + 0.3 * g);
				Hh = 0.9;
			}
			vec2 rv = fract(uv * vec2(4.0, 4.0)) - 0.5;
			if ((abs(v - 0.25) < 0.04 || abs(v - 0.75) < 0.04) && length(rv * vec2(1.0, 4.0)) < 0.16) {
				C = c1 * 1.15;
				Hh = 1.0;
			}
		}
		if (var == 3) {
			vec3 tl = tile(v, u, 6, 1, 0.0, 3);
			Hh = 0.5 + 0.3 * sin(fract(u * 6.0) * PI);
			if (tl.x < 0.006) {
				C *= 0.5;
			}
			if (abs(v - 0.2) < 0.05 || abs(v - 0.8) < 0.05) {
				C = c2 * (0.85 + 0.3 * g);
				MT = 1.0;
				R = 0.4;
				Hh = 1.0;
			}
		}
	} else if (pat == 28) {
		cobble(c0, c1, c2, 0.0, b, g, e, k);
		if (P.x > 0.5) {
			if (abs(u - 0.5) < 0.3 && v > 0.52 && v < 0.88) {
				C = vec3(0.04, 0.035, 0.03);
				Hh = 0.0;
				R = 0.9;
				float fire = ss(0.60, 0.86, v + (b - 0.5) * 0.25);
				if (P.y > 0.5 && fire > 0.05) {
					C = mix(vec3(0.9, 0.25, 0.05), vec3(1.0, 0.85, 0.35), fire);
					EM = fire;
				}
			} else if (abs(u - 0.5) < 0.3 && v > 0.16 && v < 0.34) {
				C = vec3(0.05);
				Hh = 0.05;
			} else if (abs(u - 0.5) < 0.34 && v > 0.12 && v < 0.92) {
				C = vec3(0.16, 0.16, 0.17) * (0.8 + 0.4 * g);
				Hh = 1.0;
				MT = 0.6;
			}
		}
	} else if (pat == 30) {
		dirt(c0, c1, c2, 0.3, b, g, e, k);
		float fur = sin(v * TAU * 4.0) * 0.5 + 0.5;
		C *= 0.72 + 0.28 * fur;
		Hh = 0.25 + 0.45 * fur + 0.1 * g;
		R = 0.95;
	} else if (pat == 31) {
		if (P.x < 0.5) {
			float r = abs(sin(u * PI * 5.0));
			C = mix(c0, c1, r * 0.8 + g * 0.2);
			Hh = 0.3 + 0.6 * r;
			if (r < 0.12) {
				C *= 0.7;
			}
		} else {
			vec2 dc = uv - 0.5;
			float ang = atan(dc.y, dc.x);
			float r = abs(sin(ang * 5.0));
			C = mix(c0, c1, r * 0.6 + g * 0.4);
			Hh = 0.4 + 0.3 * r;
			if (length(dc) < 0.09) {
				C = c2 * (0.8 + 0.4 * g);
				Hh = 1.0;
			}
		}
		R = 0.6;
	} else if (pat == 32) {
		float m = b * 0.45 + ss(0.0, 0.35, e) * 0.55;
		vec2 dc = (uv - vec2(0.5, 0.56)) * vec2(1.0, 1.15);
		bool inside = length(dc) < 0.46 + (b - 0.5) * 0.25;
		C = mix(c0, c1, k * 0.55 + g * 0.45) * (0.65 + 0.5 * ss(0.05, 0.4, e));
		A = (m > 0.30 && inside) ? 1.0 : 0.0;
		if (P.x > 1.5 && inside) {
			vec4 rc = nearest(uv, 6, isd + 60);
			float r = length(rc.xy);
			if (rc.z < 0.55 && r < 0.3) {
				float spiral = fract(r * 14.0 + atan(rc.y, rc.x) / TAU * 2.0);
				C = c2 * (0.55 + 0.45 * (1.0 - r / 0.3)) * (0.75 + 0.35 * step(0.4, spiral));
				A = 1.0;
				Hh = 0.9 - r;
			}
		} else if (P.x > 0.5 && inside) {
			vec2 br = pcell(uv, 11, isd + 50);
			if (br.x > 0.62 && br.y > 0.5) {
				C = c2 * (0.8 + 0.5 * g);
				A = 1.0;
				Hh = 1.0;
			}
		}
		R = 0.7;
	} else if (pat == 33) {
		A = 0.0;
		R = 0.8;
		int sp = int(P.x + 0.5);
		if (abs(u - 0.5) < 0.035 && v > 0.42) {
			C = c0;
			A = 1.0;
		}
		float leaf = pfbm(uv, 16, sd + 7u, 2);
		if (sp == 1) {
			float w = (v - 0.12) * 0.55;
			if (v > 0.12 && v < 0.8 && abs(u - 0.5) < w && leaf > 0.3) {
				C = c1 * (0.75 + 0.4 * leaf);
				A = 1.0;
			}
		} else if (sp == 4) {
			for (int f = 0; f < 5; f++) {
				float a = -2.6 + float(f) * 0.55;
				vec2 dir = vec2(cos(a), sin(a));
				vec2 rel = uv - vec2(0.5, 0.42);
				float along = dot(rel, dir);
				float side = abs(dot(rel, vec2(-dir.y, dir.x)) + along * along * 0.6);
				if (along > 0.0 && along < 0.34 && side < 0.045) {
					C = c1 * (0.8 + 0.3 * leaf);
					A = 1.0;
				}
			}
		} else if (length((uv - vec2(0.5, 0.36)) * vec2(1.0, 1.1)) < 0.27 && leaf > 0.32) {
			C = c1 * (0.75 + 0.4 * leaf);
			A = 1.0;
		}
	} else if (pat == 34) {
		vec2 dc = uv - 0.5;
		float d = length(dc);
		float sw = sin(atan(dc.y, dc.x) * 3.0 + d * 16.0 + b * 6.0) * 0.5 + 0.5;
		C = mix(c0, c1, sw * 0.8 + g * 0.2);
		A = 0.78;
		EM = 1.0;
		R = 0.1;
	} else if (pat == 35) {
		int st = int(P.x + 0.5);
		vec3 pal[6] = vec3[](vec3(0.78, 0.10, 0.12), vec3(0.12, 0.25, 0.80), vec3(0.15, 0.58, 0.22), vec3(0.95, 0.72, 0.15),
			vec3(0.50, 0.18, 0.66), vec3(0.10, 0.62, 0.65));
		float lead = 0.0;
		float cid = 0.0;
		if (st == 0) {
			vec4 nc = nearest(uv, 6, isd + 90);
			vec2 cl = pcell(uv, 6, isd + 90);
			lead = cl.x < 0.07 ? 1.0 : 0.0;
			cid = nc.z;
		} else if (st == 1) {
			vec2 dc = uv - 0.5;
			float r = length(dc);
			float th = atan(dc.y, dc.x) / TAU + 0.5;
			float ring = r * 6.0;
			lead = (abs(fract(ring) - 0.5) > 0.44 || abs(fract(th * 12.0) - 0.5) > 0.45) ? 1.0 : 0.0;
			cid = h01(int(floor(ring)), int(floor(th * 12.0)) % 2, isd);
			if (r > 0.49) {
				cid = 0.55;
			}
		} else if (st == 2) {
			vec2 dq = vec2(u + v, u - v) * 2.0;
			vec2 fq = fract(dq);
			lead = (min(min(fq.x, 1.0 - fq.x), min(fq.y, 1.0 - fq.y)) < 0.05) ? 1.0 : 0.0;
			cid = h01(int(floor(dq.x)), int(floor(dq.y)), isd);
		} else {
			vec2 dc = uv - 0.5;
			float r = length(dc);
			float th = atan(dc.y, dc.x);
			float petal = 0.30 + 0.12 * cos(th * 6.0);
			lead = (abs(r - petal) < 0.02 || abs(r - 0.1) < 0.02 || abs(fract(th / TAU * 6.0 + 0.5) - 0.5) < 0.012 && r < petal) ? 1.0 : 0.0;
			cid = r < 0.1 ? 0.5 : (r < petal ? 0.05 : 0.3 + 0.5 * h01(int(floor((th / TAU + 0.5) * 12.0)), 1, isd));
		}
		if (edge < 0.04) {
			lead = 1.0;
		}
		if (lead > 0.5) {
			C = vec3(0.16, 0.16, 0.18) * (0.8 + 0.4 * g);
			A = 1.0;
			Hh = 1.0;
			MT = 0.7;
		} else {
			int ci = int(cid * 5.99);
			C = pal[ci] * (0.8 + 0.35 * b) * (0.9 + 0.2 * g);
			A = 0.62;
			Hh = 0.5 + 0.2 * g;
		}
		R = 0.08;
	} else if (pat == 36) {
		int st = int(P.x + 0.5);
		bool frame_px = false;
		bool grid_px = false;
		if (st == 0) {
			frame_px = edge < 0.09 || abs(u - 0.5) < 0.035 || abs(v - 0.5) < 0.035;
		} else if (st == 2) {
			// Moldura de madeira com grade fina de metal (c2).
			frame_px = edge < 0.09;
			grid_px = !frame_px && (abs(fract(u * 3.0) - 0.5) > 0.475 || abs(fract(v * 4.0) - 0.5) > 0.47);
		} else {
			frame_px = edge < 0.06 || abs(fract(u * 3.0) - 0.5) > 0.47 || abs(fract(v * 3.0) - 0.5) > 0.47;
		}
		if (grid_px) {
			C = c2 * (0.8 + 0.3 * g);
			MT = 0.9;
			R = 0.38;
			A = 1.0;
			Hh = 0.9;
		} else if (frame_px) {
			if (st == 0 || st == 2) {
				planks(c0, c1, v, u, a, b, g);
				C *= 0.9;
			} else {
				C = mix(c0, c1, g * 0.6 + b * 0.4);
				MT = 0.9;
				R = 0.4;
			}
			A = 1.0;
			Hh = 1.0;
		} else {
			// Vidro levemente esverdeado com reflexo diagonal.
			float streak = fract((u + v) * 1.4 + 0.15);
			C = vec3(0.70, 0.86, 0.90);
			A = 0.16;
			if (streak > 0.30 && streak < 0.38) {
				C = vec3(0.96, 0.99, 1.0);
				A = 0.42;
			}
			R = 0.04;
			Hh = 0.4;
		}
	} else if (pat == 29) {
		if (P.x < 0.5) {
			float r = sin(u * TAU * 6.0) * 0.5 + 0.5;
			C = mix(c0, c1, r * 0.7 + g * 0.3);
			Hh = 0.3 + 0.6 * r;
			vec2 sp = fract(vec2(u * 6.0, v * 8.0)) - 0.5;
			if (r > 0.8 && length(sp * vec2(1.0, 0.5)) < 0.09) {
				C = vec3(0.92, 0.9, 0.72);
				Hh = 1.0;
			}
		} else {
			float d = length(uv - 0.5);
			float ring = sin(d * TAU * 5.0) * 0.5 + 0.5;
			C = mix(c0, c1, ring * 0.6 + g * 0.4);
			Hh = 0.5 + 0.2 * ring;
			if (edge < 0.07) {
				C = c0 * 0.8;
			}
		}
		R = 0.7;
	}
}

void main() {
	ivec3 id = ivec3(gl_GlobalInvocationID);
	ivec2 px = id.xy;
	int layer = id.z;
	if (pc.pass_id == 0) {
		shade(layer, px);
		imageStore(img_albedo, id, vec4(clamp(C, 0.0, 1.0), A));
		imageStore(img_orm, id, vec4(0.0, clamp(R, 0.0, 1.0), clamp(MT, 0.0, 1.0), clamp(EM, 0.0, 1.0)));
		imageStore(img_height, id, vec4(clamp(Hh, 0.0, 1.0)));
		return;
	}
	float hl = imageLoad(img_height, ivec3(wrapi(px.x - 1, 256), px.y, layer)).r;
	float hr = imageLoad(img_height, ivec3(wrapi(px.x + 1, 256), px.y, layer)).r;
	float hu = imageLoad(img_height, ivec3(px.x, wrapi(px.y - 1, 256), layer)).r;
	float hd = imageLoad(img_height, ivec3(px.x, wrapi(px.y + 1, 256), layer)).r;
	float hc = imageLoad(img_height, id).r;
	float st = defs.d[layer].p.w;
	vec3 n = normalize(vec3((hl - hr) * st, (hd - hu) * st, 1.0));
	imageStore(img_normal, id, vec4(n * 0.5 + 0.5, hc));
	float cav = clamp((hc - (hl + hr + hu + hd) * 0.25) * 6.0 + 0.5, 0.0, 1.0);
	vec4 o = imageLoad(img_orm, id);
	o.r = 0.5 + 0.5 * ss(0.0, 0.55, hc) * (0.6 + 0.4 * cav);
	imageStore(img_orm, id, o);
}
"""


static func source() -> String:
	var s := "#version 450\n"
	s += "layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;\n"
	s += "layout(rgba8, set = 0, binding = 0) uniform restrict image2DArray img_albedo;\n"
	s += "layout(rgba8, set = 0, binding = 1) uniform restrict image2DArray img_orm;\n"
	s += "layout(r32f, set = 0, binding = 2) uniform restrict image2DArray img_height;\n"
	s += "layout(rgba8, set = 0, binding = 3) uniform restrict image2DArray img_normal;\n"
	s += "struct LayerDef { vec4 c0; vec4 c1; vec4 c2; vec4 p; ivec4 i; };\n"
	s += "layout(set = 0, binding = 4, std430) restrict readonly buffer Defs { LayerDef d[]; } defs;\n"
	s += "layout(push_constant, std430) uniform Params { int pass_id; int p0; int p1; int p2; } pc;\n"
	s += "const float TAU = 6.28318530718;\nconst float PI = 3.14159265359;\n"
	return s + BODY
