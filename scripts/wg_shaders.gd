class_name WGShaders
extends RefCounted
## Fontes GLSL do gerador de mundo. O mesmo bloco de ruido (NOISE) e colado no compute shader
## que gera os chunks e no shader do terreno distante, para os dois concordarem bloco a bloco.

## Ruido de gradiente com hash inteiro: valido tanto em GLSL 450 quanto na linguagem de shader da Godot.
const NOISE := """
uint wg_hash(uint x, uint y, uint s) {
	uint h = x * 2654435761u + y * 2246822519u + s * 3266489917u;
	h ^= h >> 15u;
	h *= 739982445u;
	h ^= h >> 12u;
	h *= 695872825u;
	h ^= h >> 15u;
	return h;
}

float wg_grad(ivec2 i, vec2 f, uint s) {
	uint h = wg_hash(uint(i.x), uint(i.y), s) & 7u;
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

float wg_noise(vec2 p, uint s) {
	vec2 fl = floor(p);
	ivec2 i = ivec2(fl);
	vec2 f = p - fl;
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = wg_grad(i, f, s);
	float b = wg_grad(i + ivec2(1, 0), f - vec2(1.0, 0.0), s);
	float c = wg_grad(i + ivec2(0, 1), f - vec2(0.0, 1.0), s);
	float d = wg_grad(i + ivec2(1, 1), f - vec2(1.0, 1.0), s);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float wg_fbm(vec2 p, uint s, int oct) {
	float amp = 1.0;
	float sum = 0.0;
	float norm = 0.0;
	for (int k = 0; k < oct; k++) {
		sum += amp * wg_noise(p, s + uint(k) * 131u);
		norm += amp;
		p *= 2.0;
		amp *= 0.5;
	}
	return sum / norm * 1.6;
}

// x = altura do bloco de superficie, y = bioma, z = temperatura.
vec3 wg_column(vec2 p, uint sd) {
	float c = wg_fbm(p * 0.0016, sd + 1u, 4);
	float land = smoothstep(-0.16, 0.06, c);
	float e = wg_fbm(p * 0.004, sd + 2u, 3) * 0.5 + 0.5;
	float m = smoothstep(0.12, 0.5, wg_fbm(p * 0.0022, sd + 3u, 2)) * land;
	float r = 1.0 - abs(wg_fbm(p * 0.007, sd + 4u, 4));
	float d = wg_fbm(p * 0.035, sd + 5u, 3);
	float h = 29.0 + land * 18.5 + e * 9.0 * land + m * (r * r * 54.0 + 8.0) + d * (1.5 + m * 3.5);
	float rv = abs(wg_fbm(p * 0.0028, sd + 8u, 2));
	float rcut = (1.0 - smoothstep(0.0, 0.055, rv)) * land * (1.0 - m);
	h = mix(h, 40.5, rcut);
	float hi = clamp(floor(h), 3.0, 114.0);
	float temp = wg_fbm(p * 0.0013, sd + 6u, 2) * 1.6 - max(0.0, h - 72.0) * 0.012 + d * 0.04;
	float humid = wg_fbm(p * 0.0019, sd + 7u, 2) * 1.6 + d * 0.04;
	float bio = 2.0;
	if (hi < 43.0) {
		bio = 0.0;
	} else if (hi <= 45.0) {
		bio = 1.0;
	} else if (hi > 98.0) {
		bio = 7.0;
	} else if (hi > 80.0 && m > 0.45) {
		bio = 6.0;
	} else if (temp > 0.32 && humid < 0.15) {
		bio = 4.0;
	} else if (temp < -0.32) {
		bio = 5.0;
	} else if (humid > 0.08) {
		bio = 3.0;
	}
	return vec3(hi, bio, temp);
}
"""

## Compute shader: gera os 16x16x128 blocos de um chunk (terreno, agua, cavernas, minerios, plantas)
## e o mapa de colunas 20x20 usado para plantar as arvores.
const CHUNK_MAIN := """
float wg_g3(ivec3 i, vec3 f, uint s) {
	uint h = wg_hash(uint(i.x), uint(i.y) + uint(i.z) * 1663821211u, s) & 15u;
	float u = h < 8u ? f.x : f.y;
	float v = h < 4u ? f.y : ((h == 12u || h == 14u) ? f.x : f.z);
	return ((h & 1u) == 0u ? u : -u) + ((h & 2u) == 0u ? v : -v);
}

float wg_noise3(vec3 p, uint s) {
	vec3 fl = floor(p);
	ivec3 i = ivec3(fl);
	vec3 f = p - fl;
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float n000 = wg_g3(i, f, s);
	float n100 = wg_g3(i + ivec3(1, 0, 0), f - vec3(1.0, 0.0, 0.0), s);
	float n010 = wg_g3(i + ivec3(0, 1, 0), f - vec3(0.0, 1.0, 0.0), s);
	float n110 = wg_g3(i + ivec3(1, 1, 0), f - vec3(1.0, 1.0, 0.0), s);
	float n001 = wg_g3(i + ivec3(0, 0, 1), f - vec3(0.0, 0.0, 1.0), s);
	float n101 = wg_g3(i + ivec3(1, 0, 1), f - vec3(1.0, 0.0, 1.0), s);
	float n011 = wg_g3(i + ivec3(0, 1, 1), f - vec3(0.0, 1.0, 1.0), s);
	float n111 = wg_g3(i + ivec3(1, 1, 1), f - vec3(1.0, 1.0, 1.0), s);
	return mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y), mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
}

bool wg_cave(int wx, int y, int wz, int h, uint sd) {
	if (y < 2) {
		return false;
	}
	if (h <= SEA + 1 && y >= h - 5) {
		return false;
	}
	vec3 p = vec3(float(wx), float(y) * 1.5, float(wz)) * 0.03;
	if (abs(wg_noise3(p, sd + 9u)) > 0.075) {
		return false;
	}
	return abs(wg_noise3(p + vec3(31.7, 11.3, 5.9), sd + 10u)) < 0.075;
}

// Variedade de rochas em manchas grandes.
uint wg_rock(int wx, int y, int wz, uint sd) {
	vec3 p = vec3(float(wx), float(y), float(wz)) * 0.022;
	float a = wg_noise3(p, sd + 40u);
	if (a > 0.40) {
		return B_GRANITE;
	}
	if (a < -0.40) {
		return B_BASALT;
	}
	float b = wg_noise3(p + vec3(17.3, 5.1, 9.7), sd + 41u);
	if (b > 0.42) {
		return B_LIMESTONE;
	}
	if (b < -0.42) {
		return B_SLATE;
	}
	return B_STONE;
}


// ---------------- Profundezas igneas: cavernas enormes entre piso e teto de rocha-mae, mar de lava.
float fire_density(vec3 p, uint sd) {
	float d = wg_noise3(p * vec3(0.022, 0.035, 0.022), sd + 60u) + wg_noise3(p * 0.06, sd + 61u) * 0.45;
	d += smoothstep(96.0, 122.0, p.y) * 1.4 + (1.0 - smoothstep(6.0, 34.0, p.y)) * 1.3;
	return d;
}

void gen_fire(ivec2 g, uint sd) {
	if (g.x < 20 && g.y < 20) {
		imageStore(out_cols, g, uvec4(9u << 8u, 0u, 0u, 0u));
	}
	int x = g.x & 15;
	int z = g.x >> 4;
	int y = g.y;
	int wx = pc.ox + x;
	int wz = pc.oz + z;
	uint id = 0u;
	if (y == 0 || y >= 126) {
		id = B_BEDROCK;
	} else {
		vec3 p = vec3(float(wx), float(y), float(wz));
		float d = fire_density(p, sd);
		if (d > 0.18) {
			bool air_above = y + 1 < 126 && fire_density(p + vec3(0.0, 1.0, 0.0), sd) <= 0.18;
			bool air_below = y - 1 > 0 && fire_density(p - vec3(0.0, 1.0, 0.0), sd) <= 0.18;
			id = wg_noise3(p * 0.05, sd + 62u) > 0.35 ? B_BASALT : B_SCORIA;
			if (air_above && y > 33 && wg_noise3(p * 0.09, sd + 63u) > 0.0) {
				id = B_ASH;
			}
			if (air_below && (wg_hash(uint(wx), uint(wz), sd + uint(y) * 7u) % 9u) == 0u) {
				id = B_EMBERSTONE;
			} else if ((wg_hash(uint(wx >> 1), uint(wz >> 1), sd + 200u + uint(y >> 1)) % 140u) == 0u) {
				id = B_EMBERSTONE;
			} else if (y < 48 && (wg_hash(uint(wx), uint(wz), sd + 300u + uint(y)) % 230u) == 0u) {
				id = B_GOLD_ORE;
			}
		} else if (y <= 31) {
			id = B_LAVA;
		} else if (fire_density(p - vec3(0.0, 1.0, 0.0), sd) > 0.18 && (wg_hash(uint(wx), uint(wz), sd + 71u + uint(y)) % 100u) < 4u) {
			id = B_RED_FUNGUS;
		}
	}
	imageStore(out_blocks, g, uvec4(id, 0u, 0u, 0u));
}

// ---------------- Ilhas etereas: ilhas flutuantes no vazio.
float astral_density(vec3 p, uint sd) {
	float mask = wg_fbm(p.xz * 0.006, sd + 80u, 3);
	float d = wg_noise3(p * vec3(0.02, 0.04, 0.02), sd + 81u) * 0.9 + wg_noise3(p * 0.07, sd + 82u) * 0.3;
	float dy = (p.y - 62.0 - mask * 14.0) / (12.0 + max(mask, 0.0) * 10.0);
	d += mask * 0.9 - dy * dy * 1.6 - 0.15;
	if (dy < 0.0) {
		d -= dy * dy * 1.2;
	}
	return d;
}

void gen_astral(ivec2 g, uint sd) {
	if (g.x < 20 && g.y < 20) {
		int cwx = pc.ox + g.x - 2;
		int cwz = pc.oz + g.y - 2;
		int top = 0;
		for (int yy = 110; yy > 10; yy--) {
			if (astral_density(vec3(float(cwx), float(yy), float(cwz)), sd) > 0.0) {
				top = yy;
				break;
			}
		}
		imageStore(out_cols, g, uvec4(uint(top) | (8u << 8u), 0u, 0u, 0u));
	}
	int x = g.x & 15;
	int z = g.x >> 4;
	int y = g.y;
	int wx = pc.ox + x;
	int wz = pc.oz + z;
	vec3 p = vec3(float(wx), float(y), float(wz));
	uint id = 0u;
	if (astral_density(p, sd) > 0.0) {
		bool air_above = astral_density(p + vec3(0.0, 1.0, 0.0), sd) <= 0.0;
		id = air_above ? B_MOON_MOSS : B_ASTRAL_STONE;
		if (!air_above && (wg_hash(uint(wx), uint(wz), sd + 90u + uint(y)) % 170u) == 0u) {
			id = B_CRYSTAL_ORE;
		}
	} else if (astral_density(p - vec3(0.0, 1.0, 0.0), sd) > 0.0 && (wg_hash(uint(wx), uint(wz), sd + 91u + uint(y)) % 100u) < 5u) {
		id = B_MOON_FLOWER;
	}
	imageStore(out_blocks, g, uvec4(id, 0u, 0u, 0u));
}

void main() {
	ivec2 g = ivec2(gl_GlobalInvocationID.xy);
	if (pc.dim == 1u) {
		gen_fire(g, pc.seed);
		return;
	}
	if (pc.dim == 2u) {
		gen_astral(g, pc.seed);
		return;
	}
	uint sd = pc.seed;

	if (g.x < 20 && g.y < 20) {
		int cwx = pc.ox + g.x - 2;
		int cwz = pc.oz + g.y - 2;
		vec3 cc = wg_column(vec2(float(cwx), float(cwz)), sd);
		int ch = int(cc.x);
		uint carved = wg_cave(cwx, ch, cwz, ch, sd) ? 1u : 0u;
		imageStore(out_cols, g, uvec4(uint(ch) | (uint(cc.y) << 8u) | (carved << 12u), 0u, 0u, 0u));
	}

	int x = g.x & 15;
	int z = g.x >> 4;
	int y = g.y;
	int wx = pc.ox + x;
	int wz = pc.oz + z;
	vec3 col = wg_column(vec2(float(wx), float(wz)), sd);
	int h = int(col.x);
	int bio = int(col.y);

	uint surf = B_GRASS;
	uint fill = B_DIRT;
	uint fill2 = B_STONE;
	if (bio == 0) {
		uint oc = wg_hash(uint(wx >> 2), uint(wz >> 2), sd + 3u) % 6u;
		surf = oc == 0u ? B_GRAVEL : (oc == 1u ? B_CLAY : B_SAND);
		fill = B_SAND;
	} else if (bio == 1) {
		surf = B_SAND;
		fill = B_SAND;
	} else if (bio == 4) {
		surf = B_SAND;
		fill = B_SAND;
		fill2 = B_SANDSTONE;
	} else if (bio == 5) {
		surf = B_SNOW_GRASS;
	} else if (bio == 6) {
		surf = (wg_hash(uint(wx >> 1), uint(wz >> 1), sd + 5u) % 7u) == 0u ? B_GRAVEL : wg_rock(wx, h, wz, sd);
		fill = surf == B_GRAVEL ? B_STONE : surf;
	} else if (bio == 7) {
		surf = B_SNOW_BLOCK;
		fill = B_SNOW_BLOCK;
	}
	if (h < SEA && bio != 0) {
		surf = B_SAND;
		fill = B_SAND;
	}

	uint id = 0u;
	if (y == 0) {
		id = B_BEDROCK;
	} else if (y <= h) {
		if (y == h) {
			id = surf;
		} else if (y >= h - 3) {
			id = fill;
		} else if (y >= h - 8) {
			id = fill2;
		} else {
			id = wg_rock(wx, y, wz, sd);
			uint oh = wg_hash(uint(wx >> 1), uint(wz >> 1), sd + 100u + uint(y >> 1));
			if ((oh % 89u) == 0u) {
				id = B_COAL_ORE;
			} else if (y < 56 && (oh % 173u) == 1u) {
				id = B_IRON_ORE;
			} else if (y < 64 && (oh % 151u) == 2u) {
				id = B_COPPER_ORE;
			} else if (y < 30 && (oh % 263u) == 3u) {
				id = B_GOLD_ORE;
			} else if (y < 18 && (oh % 331u) == 4u) {
				id = B_CRYSTAL_ORE;
			} else if (y < 14 && (oh % 397u) == 5u) {
				id = B_RUBY_ORE;
			}
		}
		if (wg_cave(wx, y, wz, h, sd)) {
			id = 0u;
		}
	} else if (h < SEA && y <= SEA) {
		id = (y == SEA && col.z < -0.5) ? B_ICE : B_WATER;
	} else if (y == h + 1 && h > SEA && !wg_cave(wx, h, wz, h, sd)) {
		uint pr = wg_hash(uint(wx), uint(wz), sd + 11u) % 100u;
		if (surf == B_GRASS && bio == 2) {
			uint pf = wg_hash(uint(wx >> 4), uint(wz >> 4), sd + 31u) % 4u;
			if (pr < 22u) {
				id = B_TALL_GRASS;
			} else if (pr < 30u && pf == 0u) {
				id = B_LAVENDER;
			} else if (pr < 27u && pf == 1u) {
				id = B_TULIP;
			} else if (pr < 25u && pf == 2u) {
				id = B_SUNFLOWER;
			} else if (pr < 24u) {
				id = B_FLOWER_RED;
			} else if (pr < 26u) {
				id = B_FLOWER_YELLOW;
			} else if (pr < 27u) {
				id = B_FLOWER_BLUE;
			} else if (pr < 28u) {
				id = B_FLOWER_WHITE;
			}
		} else if (surf == B_GRASS) {
			if (pr < 10u) {
				id = B_TALL_GRASS;
			} else if (pr < 18u) {
				id = B_FERN;
			} else if (pr < 19u) {
				id = B_MUSHROOM_RED;
			} else if (pr < 20u) {
				id = B_MUSHROOM_BROWN;
			} else if (pr < 21u) {
				id = B_FLOWER_WHITE;
			} else if (pr < 22u) {
				id = B_ROSE_BUSH;
			}
		} else if (bio == 4 && surf == B_SAND && pr < 2u) {
			id = B_DEAD_BUSH;
		}
	}
	imageStore(out_blocks, g, uvec4(id, 0u, 0u, 0u));
}
"""


static func chunk_compute_source() -> String:
	var s := "#version 450\n"
	s += "layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;\n"
	s += "layout(r8ui, set = 0, binding = 0) uniform restrict writeonly uimage2D out_blocks;\n"
	s += "layout(r16ui, set = 0, binding = 1) uniform restrict writeonly uimage2D out_cols;\n"
	s += "layout(push_constant, std430) uniform Params { int ox; int oz; uint seed; uint dim; } pc;\n"
	s += "const int SEA = %d;\n" % WorldGen.SEA
	var ids := {
		"GRASS": Blocks.GRASS, "DIRT": Blocks.DIRT, "STONE": Blocks.STONE, "SAND": Blocks.SAND, "WATER": Blocks.WATER,
		"GRAVEL": Blocks.GRAVEL, "SANDSTONE": Blocks.SANDSTONE, "SNOW_GRASS": Blocks.SNOW_GRASS, "SNOW_BLOCK": Blocks.SNOW_BLOCK,
		"BEDROCK": Blocks.BEDROCK, "COAL_ORE": Blocks.COAL_ORE, "IRON_ORE": Blocks.IRON_ORE, "TALL_GRASS": Blocks.TALL_GRASS,
		"FLOWER_RED": Blocks.FLOWER_RED, "FLOWER_YELLOW": Blocks.FLOWER_YELLOW, "FLOWER_BLUE": Blocks.FLOWER_BLUE,
		"FLOWER_WHITE": Blocks.FLOWER_WHITE, "FERN": Blocks.FERN, "MUSHROOM_RED": Blocks.MUSHROOM_RED, "MUSHROOM_BROWN": Blocks.MUSHROOM_BROWN,
		"DEAD_BUSH": Blocks.DEAD_BUSH, "TULIP": Blocks.TULIP, "LAVENDER": Blocks.LAVENDER, "SUNFLOWER": Blocks.SUNFLOWER, "ROSE_BUSH": Blocks.ROSE_BUSH, "GRANITE": Blocks.GRANITE, "BASALT": Blocks.BASALT, "LIMESTONE": Blocks.LIMESTONE, "SLATE": Blocks.SLATE,
		"CLAY": Blocks.CLAY, "ICE": Blocks.ICE, "COPPER_ORE": Blocks.COPPER_ORE, "GOLD_ORE": Blocks.GOLD_ORE,
		"CRYSTAL_ORE": Blocks.CRYSTAL_ORE, "RUBY_ORE": Blocks.RUBY_ORE, "LAVA": Blocks.LAVA, "SCORIA": Blocks.SCORIA,
		"ASH": Blocks.ASH, "EMBERSTONE": Blocks.EMBERSTONE, "RED_FUNGUS": Blocks.RED_FUNGUS, "ASTRAL_STONE": Blocks.ASTRAL_STONE,
		"MOON_MOSS": Blocks.MOON_MOSS, "MOON_FLOWER": Blocks.MOON_FLOWER,
	}
	for k: String in ids:
		s += "const uint B_%s = %du;\n" % [k, ids[k]]
	return s + NOISE + CHUNK_MAIN
