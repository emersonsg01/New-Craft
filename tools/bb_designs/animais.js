// Animais redesenhados (exceto o cavalo, em cavalo.js). Cada especie: function(v) -> design.
// Ossos: corpo, cabeca (head) com orelhas (earA/earB) penduradas, pernas em dois segmentos
// (legA/legA2, legB/legB2), cauda (tail gira no eixo Y; tailz/tailz2 pendem). Aves: wingA/wingB.
(function () {
	const BLACK = [0.04, 0.03, 0.03, 1];
	const WHITE = [0.94, 0.93, 0.90, 1];
	const PINK = [0.90, 0.62, 0.62, 1];
	const A = (c, a) => [c[0], c[1], c[2], a === undefined ? 1 : a];
	const mul = (c, f) => [c[0] * f, c[1] * f, c[2] * f, c[3] === undefined ? 1 : c[3]];

	function rnd(seed) {
		let s = seed;
		return () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
	}

	// Manchas aleatorias em todas as faces.
	function spots(seed, n, color, smin, smax) {
		const R = rnd(seed);
		const out = [];
		for (let k = 0; k < n; k++) {
			const s = smin + R() * (smax - smin);
			const x = R() * (1 - s), y = R() * (1 - s);
			out.push({ face: '*', r: [x, y, x + s, y + s * (0.8 + R() * 0.5)], color });
		}
		return out;
	}

	// Olhos: laterais (presas) ou frontais (predadores). Esclera, pupila e brilho.
	function eyes(lateral, sclera, pupil, y0, y1, d) {
		const sc = sclera || WHITE, pu = pupil || BLACK;
		y0 = y0 ?? 0.30; y1 = y1 ?? 0.50; d = d ?? 0.0;
		if (lateral) {
			return [
				{ face: 'east', r: [0.62 - d, y0, 0.84 - d, y1], color: sc }, { face: 'east', r: [0.70 - d, y0 + 0.02, 0.82 - d, y1 - 0.02], color: pu },
				{ face: 'west', r: [0.16 + d, y0, 0.38 + d, y1], color: sc }, { face: 'west', r: [0.18 + d, y0 + 0.02, 0.30 + d, y1 - 0.02], color: pu },
			];
		}
		return [
			{ face: 'north', r: [0.14, y0, 0.36, y1], color: sc }, { face: 'north', r: [0.22, y0 + 0.02, 0.34, y1 - 0.02], color: pu },
			{ face: 'north', r: [0.64, y0, 0.86, y1], color: sc }, { face: 'north', r: [0.66, y0 + 0.02, 0.78, y1 - 0.02], color: pu },
		];
	}

	function body(parts, name, from, to, color, extra) {
		parts.push(Object.assign({ name, bone: 'corpo', group: 'corpo', pivot: [0, 0, 0], from, to, color, fur: true }, extra || {}));
	}

	function head(parts, name, pivot, from, to, color, extra) {
		parts.push(Object.assign({ name, bone: 'cabeca', group: 'head', bonePivot: parts.__hp, pivot: pivot || parts.__hp, from, to, color, fur: true }, extra || {}));
	}

	function ear(parts, side, pivot, from, to, color, rot, extra) {
		parts.push(Object.assign({ name: 'orelha', bone: side < 0 ? 'orelhaE' : 'orelhaD', group: side < 0 ? 'earA' : 'earB', parent: 'cabeca',
			bonePivot: pivot, pivot, from, to, color, rotation: rot || [0, 0, 0] }, extra || {}));
	}

	// Quatro pernas em dois segmentos. o: {x, zf, zb, top, knee, t, ts, color, low, hoof, hh, hindT, decals}
	function legs(parts, o) {
		const L = [[o.x, o.zf, 'legA', false], [-o.x, o.zf, 'legB', false], [o.x, o.zb, 'legB', true], [-o.x, o.zb, 'legA', true]];
		L.forEach((l, i) => {
			const [x, z, g, hind] = l;
			const t = hind && o.hindT ? o.hindT : o.t;
			const up = 'perna' + i, lo = 'canela' + i;
			parts.push({ name: 'coxa', bone: up, group: g, bonePivot: [x, o.top, z], pivot: [x, o.top, z], from: [x - t, o.knee, z - t], to: [x + t, o.top + 0.5, z + t],
				color: o.color, fur: true, decals: o.decals || [] });
			const ts = o.ts;
			parts.push({ name: 'canela', bone: lo, group: g + '2', parent: up, bonePivot: [x, o.knee, z], pivot: [x, o.knee, z],
				from: [x - ts, o.hh || 0, z - ts], to: [x + ts, o.knee + 0.4, z + ts], color: o.low || o.color, fur: true });
			if (o.hoof) {
				parts.push({ name: 'casco', bone: lo, group: g + '2', parent: up, pivot: [x, o.knee, z],
					from: [x - ts - 0.2, 0, z - ts - 0.35], to: [x + ts + 0.2, (o.hh || 1.2) + 0.05, z + ts + 0.15], color: o.hoof, noise: 0.05,
					decals: [{ face: 'north', r: [0.44, 0, 0.56, 1], color: mul(o.hoof, 0.6) }] });
			}
		});
	}

	// ---------------------------------------------------------------- vaca
	function vaca(v) {
		const base = [[0.94, 0.93, 0.90], [0.50, 0.32, 0.18], [0.14, 0.12, 0.11], [0.86, 0.64, 0.38]][v];
		const c = A(base), spot = A([0.10, 0.09, 0.08]);
		const sp = v === 0 ? spots(41, 16, spot, 0.10, 0.28) : (v === 3 ? spots(42, 6, A([0.96, 0.94, 0.90]), 0.10, 0.22) : []);
		const parts = []; parts.__hp = [0, 19, -9];
		body(parts, 'tronco', [-6, 11, -9], [6, 21, 9], c, { decals: sp });
		body(parts, 'lombo', [-5.5, 20.5, -8], [5.5, 21.8, 7], c, { decals: sp });
		body(parts, 'ubere', [-2.5, 9.2, 3], [2.5, 11.2, 7], A(PINK), { decals: [{ face: 'down', r: [0.1, 0.1, 0.3, 0.3], color: mul(PINK, 0.8) }, { face: 'down', r: [0.7, 0.1, 0.9, 0.3], color: mul(PINK, 0.8) },
			{ face: 'down', r: [0.1, 0.7, 0.3, 0.9], color: mul(PINK, 0.8) }, { face: 'down', r: [0.7, 0.7, 0.9, 0.9], color: mul(PINK, 0.8) }] });
		head(parts, 'pescoco', [0, 19, -9], [-3.5, 14.5, -11], [3.5, 21, -7.5], c, { decals: sp.slice(0, 3) });
		const face = v === 0 ? [{ face: '*', r: [0, 0, 0.45, 0.5], color: spot }] : [{ face: 'north', r: [0.35, 0, 0.65, 0.7], color: WHITE }];
		head(parts, 'cranio', null, [-4, 15.5, -16], [4, 22.5, -10.5], c, { decals: face.concat(eyes(true, WHITE, BLACK, 0.30, 0.48)) });
		head(parts, 'focinho', null, [-3.2, 15, -17.6], [3.2, 18.8, -15.5], A(PINK), { noise: 0.06, decals: [{ face: 'north', r: [0.12, 0.35, 0.30, 0.65], color: A([0.30, 0.16, 0.16]) }, { face: 'north', r: [0.70, 0.35, 0.88, 0.65], color: A([0.30, 0.16, 0.16]) }] });
		const horn = A([0.86, 0.82, 0.70]);
		head(parts, 'chifreE', [-4, 21.5, -13], [-6.5, 21, -13.6], [-3.6, 22.4, -12.4], horn, { rotation: [0, 0, -18], decals: [{ face: '*', r: [0, 0, 0.25, 1], color: A([0.40, 0.36, 0.30]) }] });
		head(parts, 'chifreD', [4, 21.5, -13], [3.6, 21, -13.6], [6.5, 22.4, -12.4], horn, { rotation: [0, 0, 18], decals: [{ face: '*', r: [0.75, 0, 1, 1], color: A([0.40, 0.36, 0.30]) }] });
		ear(parts, -1, [-4, 20, -12], [-7, 19.2, -12.6], [-4, 21, -11.6], c, [0, 0, 18], { decals: [{ face: 'north', r: [0.1, 0.2, 0.8, 0.8], color: A(PINK) }] });
		ear(parts, 1, [4, 20, -12], [4, 19.2, -12.6], [7, 21, -11.6], c, [0, 0, -18], { decals: [{ face: 'north', r: [0.2, 0.2, 0.9, 0.8], color: A(PINK) }] });
		parts.push({ name: 'rabo', bone: 'cauda', group: 'tailz', bonePivot: [0, 20.5, 9], pivot: [0, 20.5, 9], from: [-0.5, 11, 8.6], to: [0.5, 20.5, 9.6], color: c });
		parts.push({ name: 'tufo', bone: 'cauda', group: 'tailz', pivot: [0, 20.5, 9], from: [-1, 9, 8.1], to: [1, 12, 10.1], color: v === 2 ? A([0.30, 0.28, 0.26]) : spot, fur: true, noise: 0.25 });
		legs(parts, { x: 4, zf: -6.5, zb: 6.5, top: 12, knee: 6, t: 2, ts: 1.6, color: c, hoof: A([0.22, 0.18, 0.16]), hh: 1.4, decals: sp.slice(0, 2) });
		return { name: 'vaca_' + v, parts };
	}

	// ---------------------------------------------------------------- porco
	function porco(v) {
		const base = [[0.93, 0.62, 0.62], [0.62, 0.44, 0.36], [0.22, 0.18, 0.18]][v];
		const c = A(base), d = mul(c, 0.85);
		const parts = []; parts.__hp = [0, 11, -7];
		body(parts, 'tronco', [-5, 6, -7.5], [5, 14.5, 7.5], c, { noise: 0.08, decals: v === 1 ? spots(51, 7, mul(c, 0.7), 0.1, 0.25) : [] });
		body(parts, 'papada', [-4, 6.5, -8.5], [4, 12, -7], d);
		head(parts, 'cranio', null, [-4, 7, -14], [4, 15, -7.5], c, { decals: eyes(true, A([0.95, 0.88, 0.86]), BLACK, 0.32, 0.46) });
		head(parts, 'focinho', null, [-2.2, 8, -15.8], [2.2, 11.2, -13.8], mul(c, 1.05), { noise: 0.05, decals: [{ face: 'north', r: [0.15, 0.3, 0.38, 0.7], color: A([0.35, 0.18, 0.18]) }, { face: 'north', r: [0.62, 0.3, 0.85, 0.7], color: A([0.35, 0.18, 0.18]) }] });
		ear(parts, -1, [-3, 14.5, -9], [-4.2, 13.2, -12.5], [-1.4, 14.8, -9], d, [-35, 0, 0]);
		ear(parts, 1, [3, 14.5, -9], [1.4, 13.2, -12.5], [4.2, 14.8, -9], d, [-35, 0, 0]);
		parts.push({ name: 'rabo1', bone: 'cauda', group: 'tail', bonePivot: [0, 12, 7.5], pivot: [0, 12, 7.5], from: [-0.5, 11.5, 7.5], to: [0.5, 12.5, 9.2], color: d });
		parts.push({ name: 'rabo2', bone: 'cauda', group: 'tail', pivot: [0, 12, 7.5], from: [0.5, 11.5, 8.5], to: [1.5, 13.8, 9.5], color: d });
		parts.push({ name: 'rabo3', bone: 'cauda', group: 'tail', pivot: [0, 12, 7.5], from: [-0.5, 13, 8.5], to: [0.5, 14, 9.5], color: d });
		legs(parts, { x: 3.2, zf: -5, zb: 5, top: 7, knee: 3.5, t: 1.8, ts: 1.5, color: c, hoof: A([0.40, 0.26, 0.24]), hh: 1.0 });
		return { name: 'porco_' + v, parts };
	}

	// ---------------------------------------------------------------- ovelha
	function ovelha(v) {
		const wool = A([[0.94, 0.93, 0.90], [0.55, 0.55, 0.58], [0.16, 0.14, 0.13], [0.48, 0.33, 0.20]][v]);
		const face = A([0.30, 0.25, 0.22]);
		const parts = []; parts.__hp = [0, 15, -8];
		const tufts = spots(61, 30, mul(wool, 0.9), 0.06, 0.14).concat(spots(62, 20, mul(wool, 1.08), 0.05, 0.10));
		// Pele por baixo da la (aparece quando a ovelha e tosquiada); la em osso proprio ("la").
		body(parts, 'pele', [-4.2, 10, -7.2], [4.2, 17, 7.2], A([0.86, 0.78, 0.70]), { noise: 0.08 });
		body(parts, 'la', [-5.5, 9, -8.5], [5.5, 18.5, 8.5], wool, { noise: 0.22, decals: tufts, bone: 'la', group: 'la' });
		body(parts, 'la_topo', [-4.5, 18, -7.5], [4.5, 19.5, 7], wool, { noise: 0.22, decals: tufts, bone: 'la', group: 'la' });
		head(parts, 'cara', null, [-2.4, 11.5, -13.5], [2.4, 17, -8], face, { noise: 0.06,
			decals: eyes(true, A([0.82, 0.70, 0.40]), BLACK, 0.28, 0.42).concat([{ face: 'north', r: [0.35, 0.72, 0.65, 0.84], color: A([0.12, 0.10, 0.09]) }]) });
		head(parts, 'topete', null, [-3, 15.8, -12.5], [3, 18, -8], wool, { noise: 0.25, bone: 'la_cab', group: 'la', parent: 'cabeca' });
		ear(parts, -1, [-2.4, 15.5, -10], [-4.8, 14.6, -11], [-2.4, 15.6, -9], face, [0, 0, 15]);
		ear(parts, 1, [2.4, 15.5, -10], [2.4, 14.6, -11], [4.8, 15.6, -9], face, [0, 0, -15]);
		parts.push({ name: 'rabo', bone: 'cauda', group: 'tailz', bonePivot: [0, 17, 8.5], pivot: [0, 17, 8.5], from: [-1.2, 13.5, 8], to: [1.2, 17.2, 10], color: wool, noise: 0.25 });
		legs(parts, { x: 3.2, zf: -5.5, zb: 5.5, top: 11, knee: 5.5, t: 1.6, ts: 0.9, color: wool, low: face, hoof: A([0.10, 0.09, 0.08]), hh: 1.0 });
		return { name: 'ovelha_' + v, parts };
	}

	// ---------------------------------------------------------------- cabra
	function cabra(v) {
		const c = A([[0.92, 0.90, 0.86], [0.16, 0.14, 0.13], [0.90, 0.86, 0.80], [0.52, 0.44, 0.34]][v]);
		const horn = A([0.58, 0.52, 0.42]);
		const parts = []; parts.__hp = [0, 13, -6];
		const sp = v === 2 ? spots(71, 9, A([0.40, 0.26, 0.14]), 0.12, 0.3) : [];
		body(parts, 'tronco', [-3.5, 8, -6.5], [3.5, 14.5, 6.5], c, { noise: 0.16, decals: sp.concat(v === 3 ? [{ face: 'up', r: [0.35, 0, 0.65, 1], color: mul(c, 0.6) }] : []) });
		head(parts, 'pescoco', [0, 13, -6], [-1.8, 10.5, -8], [1.8, 15.5, -5.5], c, { rotation: [-20, 0, 0] });
		head(parts, 'cranio', [0, 15, -9], [-2.3, 13, -11.5], [2.3, 17.2, -7], c, { rotation: [18, 0, 0], decals: eyes(true, A([0.85, 0.70, 0.30]), BLACK, 0.25, 0.40) });
		head(parts, 'focinho', [0, 15, -9], [-1.6, 12.8, -13.2], [1.6, 15.2, -11.2], mul(c, 0.92), { rotation: [18, 0, 0], decals: [{ face: 'north', r: [0.2, 0.4, 0.4, 0.6], color: BLACK }, { face: 'north', r: [0.6, 0.4, 0.8, 0.6], color: BLACK }] });
		head(parts, 'barba', [0, 12, -11], [-0.7, 9.5, -12], [0.7, 12.5, -10.8], mul(c, 0.8), { noise: 0.25 });
		for (const s of [-1, 1]) {
			head(parts, 'chifre', [s * 1.2, 17, -8.5], [s * 1.2 - 0.6, 16.6, -9], [s * 1.2 + 0.6, 19.6, -7.8], horn, { rotation: [-35, 0, s * -10] });
			head(parts, 'ponta', [s * 1.2, 19.4, -6.8], [s * 1.2 - 0.5, 18.6, -7.2], [s * 1.2 + 0.5, 19.8, -4.6], horn, { rotation: [-15, 0, 0] });
			ear(parts, s, [s * 2.3, 16, -8], s < 0 ? [-4.6, 15.4, -8.6] : [2.3, 15.4, -8.6], s < 0 ? [-2.3, 16.4, -7.6] : [4.6, 16.4, -7.6], c, [0, 0, s * -20]);
		}
		parts.push({ name: 'rabo', bone: 'cauda', group: 'tail', bonePivot: [0, 13.5, 6.5], pivot: [0, 13.5, 6.5], rotation: [30, 0, 0], from: [-0.8, 13, 6], to: [0.8, 16, 7.4], color: c });
		legs(parts, { x: 2.2, zf: -4.8, zb: 4.8, top: 9, knee: 4.5, t: 1.2, ts: 0.75, color: c, hoof: A([0.14, 0.12, 0.10]), hh: 0.9 });
		return { name: 'cabra_' + v, parts };
	}

	// ---------------------------------------------------------------- cervo
	function cervo(v) {
		const c = A([[0.60, 0.40, 0.22], [0.70, 0.30, 0.16], [0.28, 0.20, 0.14]][v]);
		const cream = A([0.92, 0.86, 0.74]);
		const horn = A([0.86, 0.80, 0.66]);
		const parts = []; parts.__hp = [0, 20, -7.5];
		body(parts, 'tronco', [-4, 13, -8], [4, 21, 8], c, { decals: [{ face: 'down', r: [0, 0, 1, 1], color: cream }].concat(spots(81, 8, mul(c, 1.18), 0.05, 0.1)) });
		body(parts, 'garupa', [-4.2, 13.5, 6], [4.2, 20, 8.6], c, { decals: [{ face: 'south', r: [0.2, 0.1, 0.8, 0.9], color: WHITE }] });
		head(parts, 'pescoco', [0, 20, -8], [-2, 17.5, -10], [2, 28, -6], c, { rotation: [-25, 0, 0], decals: [{ face: 'north', r: [0.25, 0, 0.75, 1], color: cream }] });
		head(parts, 'cranio', null, [-2.6, 25.5, -14], [2.6, 30.5, -9], c, { decals: eyes(true, A([0.20, 0.12, 0.06]), BLACK, 0.25, 0.45) });
		head(parts, 'focinho', [0, 27, -14], [-1.8, 25.6, -17.5], [1.8, 28.6, -13.8], mul(c, 0.9), { rotation: [-8, 0, 0], decals: [{ face: 'north', r: [0.25, 0, 0.75, 0.4], color: BLACK }, { face: 'down', r: [0, 0, 1, 1], color: cream }] });
		for (const s of [-1, 1]) {
			const bx = s * 1.6;
			head(parts, 'galho', [bx, 30.5, -10.5], [bx - 0.5, 30.2, -11], [bx + 0.5, 35.5, -10], horn, { rotation: [-15, 0, s * -20] });
			head(parts, 'galho2', [bx + s * 1.8, 34, -10], [bx + s * 1.8 - 0.4, 33.8, -10.4], [bx + s * 1.8 + 0.4, 37.5, -10], horn, { rotation: [-10, 0, s * -35] });
			head(parts, 'galho3', [bx, 33, -10.5], [bx - 0.4, 32.8, -13.6], [bx + 0.4, 33.6, -10.5], horn, { rotation: [25, 0, 0] });
			head(parts, 'galho4', [bx + s * 1, 35, -10.5], [bx + s * 1 - 0.4, 34.8, -10.8], [bx + s * 1 + 0.4, 38.4, -10.2], horn, { rotation: [-5, 0, s * 8] });
			ear(parts, s, [s * 2.6, 29.5, -10], s < 0 ? [-5.4, 28.8, -10.6] : [2.6, 28.8, -10.6], s < 0 ? [-2.6, 30.6, -9.6] : [5.4, 30.6, -9.6], c, [0, 0, s * -25],
				{ decals: [{ face: 'north', r: [0.15, 0.2, 0.85, 0.8], color: cream }] });
		}
		parts.push({ name: 'rabo', bone: 'cauda', group: 'tailz', bonePivot: [0, 20, 8.5], pivot: [0, 20, 8.5], from: [-1.2, 17, 8.2], to: [1.2, 20.5, 9.6], color: c, decals: [{ face: 'south', r: [0, 0, 1, 1], color: WHITE }, { face: 'down', r: [0, 0, 1, 1], color: WHITE }] });
		legs(parts, { x: 2.5, zf: -6, zb: 6, top: 14, knee: 7, t: 1.4, ts: 0.85, color: c, hoof: A([0.16, 0.12, 0.10]), hh: 1.2, hindT: 1.7 });
		return { name: 'cervo_' + v, parts };
	}

	// ---------------------------------------------------------------- burro
	function burro(v) {
		const c = A([[0.52, 0.50, 0.48], [0.48, 0.36, 0.24], [0.24, 0.20, 0.18]][v]);
		const light = mul(c, 1.55), dark = mul(c, 0.55);
		const parts = []; parts.__hp = [0, 17, -7];
		body(parts, 'tronco', [-3.8, 11, -8], [3.8, 19, 8], c, { decals: [{ face: 'down', r: [0, 0, 1, 1], color: light }, { face: 'up', r: [0.42, 0, 0.58, 1], color: dark }] });
		head(parts, 'pescoco', [0, 17, -7.5], [-2, 15, -9.5], [2, 25.5, -5.5], c, { rotation: [-28, 0, 0] });
		head(parts, 'crina', [0, 17, -7.5], [-0.5, 16, -6], [0.5, 26.5, -4.8], dark, { rotation: [-28, 0, 0], noise: 0.2 });
		head(parts, 'cranio', null, [-2.5, 22.5, -13], [2.5, 27.5, -8], c, { decals: eyes(true, WHITE, BLACK, 0.25, 0.45) });
		head(parts, 'focinho', [0, 24, -13], [-2, 22, -16.4], [2, 25.6, -12.8], light, { rotation: [-10, 0, 0], decals: [{ face: 'north', r: [0.15, 0.4, 0.35, 0.65], color: BLACK }, { face: 'north', r: [0.65, 0.4, 0.85, 0.65], color: BLACK }] });
		for (const s of [-1, 1]) {
			ear(parts, s, [s * 1.4, 27, -9.5], [s * 1.4 - 0.7, 26.8, -10], [s * 1.4 + 0.7, 33, -9], c, [-10, 0, s * -14], { decals: [{ face: 'north', r: [0.2, 0.1, 0.8, 0.85], color: light }, { face: 'up', r: [0, 0, 1, 1], color: dark }] });
		}
		parts.push({ name: 'rabo', bone: 'cauda', group: 'tailz', bonePivot: [0, 18, 8], pivot: [0, 18, 8], from: [-0.5, 10, 7.8], to: [0.5, 18, 8.8], color: c });
		parts.push({ name: 'tufo', bone: 'cauda', group: 'tailz', pivot: [0, 18, 8], from: [-1, 8.4, 7.3], to: [1, 11, 9.3], color: dark, noise: 0.25 });
		legs(parts, { x: 2.5, zf: -6, zb: 6, top: 12, knee: 6, t: 1.4, ts: 1.0, color: c, hoof: A([0.16, 0.14, 0.12]), hh: 1.2 });
		return { name: 'burro_' + v, parts };
	}

	// ---------------------------------------------------------------- camelo
	function camelo(v) {
		const c = v === 0 ? A([0.78, 0.62, 0.40]) : A([0.52, 0.38, 0.24]);
		const d = mul(c, 0.8);
		const parts = []; parts.__hp = [0, 25, -8];
		body(parts, 'tronco', [-4.5, 18, -9], [4.5, 27, 9], c, { noise: 0.12 });
		if (v === 0) body(parts, 'corcova', [-3.5, 26.5, -4], [3.5, 32, 4], c, { noise: 0.14 });
		else {
			body(parts, 'corcova1', [-3.2, 26.5, -7], [3.2, 31.5, -1.5], c, { noise: 0.2, decals: [{ face: 'up', r: [0, 0, 1, 1], color: d }] });
			body(parts, 'corcova2', [-3.2, 26.5, 1.5], [3.2, 31.5, 7], c, { noise: 0.2, decals: [{ face: 'up', r: [0, 0, 1, 1], color: d }] });
		}
		head(parts, 'pescoco', [0, 25, -8.5], [-2, 21, -10.5], [2, 33, -6.5], c, { rotation: [-38, 0, 0], decals: v === 1 ? [{ face: 'north', r: [0, 0.3, 1, 1], color: d }] : [] });
		head(parts, 'pescoco2', [0, 32, -15], [-1.8, 30.5, -16.6], [1.8, 37, -13.2], c, { rotation: [10, 0, 0] });
		head(parts, 'cranio', null, [-2.4, 35.5, -20], [2.4, 39.5, -14.5], c, { decals: eyes(true, A([0.25, 0.15, 0.08]), BLACK, 0.2, 0.45).concat([{ face: 'east', r: [0.6, 0.12, 0.86, 0.22], color: d }, { face: 'west', r: [0.14, 0.12, 0.4, 0.22], color: d }]) });
		head(parts, 'focinho', null, [-1.9, 35.5, -22.5], [1.9, 38.4, -19.8], mul(c, 0.9), { decals: [{ face: 'north', r: [0.15, 0.3, 0.35, 0.5], color: BLACK }, { face: 'north', r: [0.65, 0.3, 0.85, 0.5], color: BLACK }, { face: 'north', r: [0.1, 0.75, 0.9, 0.85], color: d }] });
		for (const s of [-1, 1]) ear(parts, s, [s * 2, 39, -15.5], s < 0 ? [-3.2, 38.6, -16] : [2, 38.6, -16], s < 0 ? [-2, 40.4, -15] : [3.2, 40.4, -15], c, [0, 0, s * -30]);
		parts.push({ name: 'rabo', bone: 'cauda', group: 'tailz', bonePivot: [0, 25, 9], pivot: [0, 25, 9], from: [-0.5, 18, 8.8], to: [0.5, 25, 9.8], color: d });
		legs(parts, { x: 2.8, zf: -6.5, zb: 6.5, top: 19, knee: 9.5, t: 1.6, ts: 1.0, color: c, hoof: mul(c, 0.55), hh: 1.0, hindT: 1.9 });
		return { name: 'camelo_' + v, parts };
	}

	// ---------------------------------------------------------------- lobo e raposa
	function canideo(name, v, o) {
		const c = A(o.colors[v]), light = A(o.light[v]), dark = A(o.dark[v]);
		const parts = []; parts.__hp = [0, o.hy, o.hz];
		const s = o.s;
		body(parts, 'tronco', [-3.5 * s, 8 * s, -7.5 * s], [3.5 * s, 14.5 * s, 7.5 * s], c, { noise: 0.16,
			decals: [{ face: 'down', r: [0, 0, 1, 1], color: light }, { face: 'up', r: [0.3, 0, 0.7, 1], color: dark }].concat(spots(91 + v, 10, mul(c, 0.88), 0.06, 0.14)) });
		if (o.ruff) body(parts, 'juba', [-4.5 * s, 8.5 * s, -8.6 * s], [4.5 * s, 15.8 * s, -4.6 * s], light, { noise: 0.24 });
		head(parts, 'cranio', null, [-3.4 * s, (o.hy - 3) * 1, (o.hz - 5) * 1], [3.4 * s, (o.hy + 3.2), o.hz], c,
			{ decals: eyes(false, A(o.eye), BLACK, 0.30, 0.46).concat([{ face: 'north', r: [0, 0.6, 1, 1], color: light }, { face: 'up', r: [0.35, 0, 0.65, 1], color: dark }]) });
		head(parts, 'focinho', null, [-1.5 * s, o.hy - 3, o.hz - 8.2 * s], [1.5 * s, o.hy - 0.2, o.hz - 4.8], light,
			{ decals: [{ face: 'north', r: [0.25, 0, 0.75, 0.35], color: BLACK }, { face: 'down', r: [0, 0, 1, 1], color: mul(light, 0.9) }, { face: 'up', r: [0, 0, 1, 1], color: c }] });
		for (const sd of [-1, 1]) {
			const ex = sd * 2.2 * s;
			ear(parts, sd, [ex, o.hy + 3, o.hz - 1.5], [ex - o.ew, o.hy + 2.8, o.hz - 2], [ex + o.ew, o.hy + 3 + o.eh, o.hz - 1], c, [0, 0, sd * -8],
				{ decals: [{ face: 'north', r: [0.2, 0.3, 0.8, 1], color: A([0.35, 0.25, 0.25]) }, { face: '*', r: [0, 0, 1, 0.22], color: o.eartip ? dark : c }] });
		}
		const ty = 12.5 * s, tz = 7.5 * s;
		parts.push({ name: 'cauda', bone: 'cauda', group: 'tail', bonePivot: [0, ty, tz], pivot: [0, ty, tz], rotation: [o.tailRot, 0, 0],
			from: [-o.tw, ty - o.tw * 1.6, tz - 0.5], to: [o.tw, ty + o.tw * 0.4, tz + o.tl], color: c, noise: 0.26,
			decals: [{ face: 'south', r: [0, 0, 1, 1], color: o.tip ? light : dark }, { face: '*', r: [0, 0, 1, 1], color: c }, { face: 'east', r: [0, 0, 0.22, 1], color: o.tip ? light : dark }, { face: 'west', r: [0.78, 0, 1, 1], color: o.tip ? light : dark }, { face: 'up', r: [0, 0.78, 1, 1], color: o.tip ? light : dark }] });
		legs(parts, { x: 2 * s, zf: -5.5 * s, zb: 5.5 * s, top: 9 * s, knee: 4.5 * s, t: 1.3 * s, ts: 0.9 * s, color: c, low: A(o.sock[v]), hh: 0 });
		return { name: name + '_' + v, parts };
	}

	function lobo(v) {
		return canideo('lobo', v, { s: 1, hy: 13, hz: -7.5, ruff: true, ew: 1, eh: 2.6, tw: 1.4, tl: 7.5, tailRot: 35, tip: false, eartip: false, eye: [0.92, 0.70, 0.12],
			colors: [[0.56, 0.57, 0.60], [0.92, 0.92, 0.92], [0.13, 0.13, 0.14]], light: [[0.82, 0.82, 0.84], [0.98, 0.98, 0.98], [0.30, 0.30, 0.32]],
			dark: [[0.36, 0.37, 0.40], [0.80, 0.80, 0.82], [0.06, 0.06, 0.07]], sock: [[0.56, 0.57, 0.60], [0.92, 0.92, 0.92], [0.13, 0.13, 0.14]] });
	}

	function raposa(v) {
		return canideo('raposa', v, { s: 0.72, hy: 9, hz: -5.4, ruff: false, ew: 0.9, eh: 2.6, tw: 1.5, tl: 8, tailRot: 15, tip: true, eartip: true, eye: [0.95, 0.75, 0.20],
			colors: [[0.86, 0.42, 0.12], [0.94, 0.94, 0.92], [0.34, 0.34, 0.36]], light: [[0.96, 0.95, 0.92], [0.99, 0.99, 0.99], [0.92, 0.92, 0.92]],
			dark: [[0.15, 0.10, 0.08], [0.78, 0.80, 0.84], [0.10, 0.10, 0.11]], sock: [[0.12, 0.10, 0.09], [0.82, 0.82, 0.86], [0.08, 0.08, 0.09]] });
	}

	// ---------------------------------------------------------------- urso
	function urso(v) {
		const c = A([[0.38, 0.24, 0.14], [0.10, 0.09, 0.09], [0.94, 0.93, 0.88]][v]);
		const snout = v === 2 ? mul(c, 0.95) : mul(c, 1.35);
		const parts = []; parts.__hp = [0, 15, -9];
		body(parts, 'tronco', [-6, 8, -9], [6, 19, 9], c, { noise: 0.2, decals: spots(101 + v, 18, mul(c, 0.88), 0.06, 0.16) });
		body(parts, 'corcova', [-5.5, 18, -8], [5.5, 21, -1], c, { noise: 0.22 });
		head(parts, 'cranio', null, [-4.5, 10.5, -15], [4.5, 18, -8.5], c, { noise: 0.18, decals: eyes(false, A([0.25, 0.15, 0.08]), BLACK, 0.34, 0.46) });
		head(parts, 'focinho', null, [-2.4, 10.5, -17.6], [2.4, 14.4, -14.5], snout, { decals: [{ face: 'north', r: [0.25, 0.5, 0.75, 1], color: BLACK }, { face: 'up', r: [0.3, 0.6, 0.7, 1], color: BLACK }] });
		for (const s of [-1, 1]) ear(parts, s, [s * 3.5, 17.5, -11], [s * 3.5 - 1.3, 17.2, -11.6], [s * 3.5 + 1.3, 19.6, -10.4], c, [0, 0, 0],
			{ decals: [{ face: 'north', r: [0.25, 0.25, 0.75, 0.8], color: mul(c, 0.6) }] });
		parts.push({ name: 'rabo', bone: 'cauda', group: 'tail', bonePivot: [0, 16, 9], pivot: [0, 16, 9], from: [-1.4, 14.5, 8.6], to: [1.4, 17, 10.4], color: c, noise: 0.25 });
		const claws = [{ face: 'north', r: [0.05, 0.75, 0.25, 1], color: A([0.86, 0.84, 0.76]) }, { face: 'north', r: [0.40, 0.75, 0.60, 1], color: A([0.86, 0.84, 0.76]) }, { face: 'north', r: [0.75, 0.75, 0.95, 1], color: A([0.86, 0.84, 0.76]) }];
		legs(parts, { x: 3.6, zf: -6, zb: 6, top: 9, knee: 4.5, t: 2.4, ts: 2.1, color: c, hh: 0 });
		parts.filter(p => p.name === 'canela').forEach(p => { p.decals = claws; });
		return { name: 'urso_' + v, parts };
	}

	// ---------------------------------------------------------------- coelho
	function coelho(v) {
		const c = A([[0.72, 0.60, 0.46], [0.95, 0.95, 0.93], [0.50, 0.50, 0.52], [0.15, 0.14, 0.14]][v]);
		const light = v === 1 ? A([0.99, 0.99, 0.98]) : mul(c, 1.3);
		const parts = []; parts.__hp = [0, 7, -3.5];
		body(parts, 'tronco', [-2.6, 2, -4], [2.6, 7.2, 4], c, { noise: 0.16, decals: [{ face: 'down', r: [0, 0, 1, 1], color: light }, { face: 'north', r: [0.2, 0.3, 0.8, 1], color: light }] });
		body(parts, 'ancas', [-3, 1.6, 1], [3, 6.6, 4.6], c, { noise: 0.16 });
		head(parts, 'cabeca', null, [-2.3, 5, -7.2], [2.3, 9.6, -3.2], c, { decals: eyes(true, A([0.25, 0.14, 0.08]), BLACK, 0.25, 0.48).concat([{ face: 'north', r: [0.2, 0.55, 0.8, 1], color: light }, { face: 'north', r: [0.42, 0.55, 0.58, 0.68], color: PINK }]) });
		for (const s of [-1, 1]) ear(parts, s, [s * 1.1, 9.3, -4.5], [s * 1.1 - 0.75, 9, -5], [s * 1.1 + 0.75, 14.5, -4.3], c, [-14, 0, s * -10],
			{ decals: [{ face: 'north', r: [0.2, 0.08, 0.8, 0.9], color: PINK }] });
		parts.push({ name: 'pompom', bone: 'cauda', group: 'tail', bonePivot: [0, 5, 4.5], pivot: [0, 5, 4.5], from: [-1.3, 3.8, 4.3], to: [1.3, 6.4, 6], color: v === 3 ? A([0.30, 0.28, 0.28]) : WHITE, noise: 0.25 });
		// Patas: dianteiras finas, traseiras grandes (pe comprido).
		[[1.3, -3, 'legA'], [-1.3, -3, 'legB']].forEach((l, i) => {
			parts.push({ name: 'pata', bone: 'pd' + i, group: l[2], bonePivot: [l[0], 3, l[1]], pivot: [l[0], 3, l[1]], from: [l[0] - 0.6, 0, l[1] - 0.7], to: [l[0] + 0.6, 3.3, l[1] + 0.6], color: light });
		});
		[[2.2, 3, 'legB'], [-2.2, 3, 'legA']].forEach((l, i) => {
			parts.push({ name: 'coxa', bone: 'pt' + i, group: l[2], bonePivot: [l[0], 4, l[1]], pivot: [l[0], 4, l[1]], from: [l[0] - 0.9, 1, l[1] - 1.5], to: [l[0] + 0.9, 4.5, l[1] + 1.5], color: c });
			parts.push({ name: 'pe', bone: 'pt' + i, group: l[2], pivot: [l[0], 4, l[1]], from: [l[0] - 0.8, 0, l[1] - 2.2], to: [l[0] + 0.8, 1.1, l[1] + 1.5], color: light });
		});
		return { name: 'coelho_' + v, parts };
	}

	// ---------------------------------------------------------------- aves
	function ave(name, v, o) {
		const c = A(o.body[v]), breast = A(o.breast[v]), headc = A(o.head[v]);
		const leg = A(o.leg), bill = A(o.bill);
		const parts = []; parts.__hp = [0, o.hy, o.hz];
		body(parts, 'corpo', o.bFrom, o.bTo, c, { noise: 0.12, decals: [{ face: 'north', r: [0.1, 0.15, 0.9, 1], color: breast }, { face: 'down', r: [0, 0, 1, 0.5], color: breast }].concat(o.speck ? spots(111 + v, 22, mul(c, 0.6), 0.05, 0.11) : []) });
		head(parts, 'cabeca', null, o.hFrom, o.hTo, headc, { decals: eyes(true, A([0.95, 0.70, 0.20]), BLACK, 0.28, 0.46).concat(o.ring ? [{ face: '*', r: [0, 0.82, 1, 1], color: WHITE }] : []) });
		head(parts, 'bico', null, o.biFrom, o.biTo, bill, { noise: 0.04 });
		for (const e of (o.extras || [])) head(parts, e[0], null, e[1], e[2], A(e[3]));
		for (const s of [-1, 1]) {
			const x = s > 0 ? o.bTo[0] : o.bFrom[0];
			parts.push({ name: 'asa', bone: s > 0 ? 'asaD' : 'asaE', group: s > 0 ? 'wingA' : 'wingB', bonePivot: [x, o.wy, 0], pivot: [x, o.wy, 0],
				from: [s > 0 ? x : x - 1, o.wy - o.wh, o.bFrom[2] + 1], to: [s > 0 ? x + 1 : x, o.wy, o.bTo[2] - 0.5], color: mul(c, 0.88),
				decals: [{ face: '*', r: [0, 0.65, 1, 1], color: A(o.wingTip[v]) }, { face: '*', r: [0, 0.45, 1, 0.55], color: A(o.speculum || o.wingTip[v]) }] });
		}
		parts.push({ name: 'cauda', bone: 'cauda', group: 'tail', bonePivot: [0, o.ty, o.bTo[2]], pivot: [0, o.ty, o.bTo[2]], rotation: [o.tr, 0, 0],
			from: [-o.tw, o.ty - 1, o.bTo[2] - 1], to: [o.tw, o.ty + o.th, o.bTo[2] + 1.5], color: A(o.tail[v]) });
		for (const s of [-1, 1]) {
			const x = s * o.lx;
			parts.push({ name: 'perna', bone: 'p' + s, group: s > 0 ? 'legA' : 'legB', bonePivot: [x, o.lt, 0], pivot: [x, o.lt, 0], from: [x - 0.5, 0, -0.5], to: [x + 0.5, o.lt + 0.3, 0.5], color: leg });
			parts.push({ name: 'pe', bone: 'p' + s, group: s > 0 ? 'legA' : 'legB', pivot: [x, o.lt, 0], from: [x - 1.4, 0, -2.2], to: [x + 1.4, 0.7, 0.6], color: leg });
		}
		return { name: name + '_' + v, parts };
	}

	function galinha(v) {
		return ave('galinha', v, { bFrom: [-3, 5, -4], bTo: [3, 11, 4], hy: 11, hz: -3, hFrom: [-2, 10.5, -6.5], hTo: [2, 15.5, -2.5], biFrom: [-1, 12, -8], biTo: [1, 13.2, -6.3],
			extras: [['crista', [-0.5, 15.2, -6], [0.5, 17.4, -3.2], [0.80, 0.12, 0.10]], ['crista2', [-0.5, 16.8, -5.4], [0.5, 18, -4.6], [0.80, 0.12, 0.10]], ['barbela', [-0.6, 10.2, -7], [0.6, 12, -6.3], [0.80, 0.12, 0.10]]],
			body: [[0.62, 0.34, 0.16], [0.95, 0.94, 0.90], [0.30, 0.28, 0.26]], breast: [[0.86, 0.66, 0.42], [0.98, 0.97, 0.94], [0.55, 0.52, 0.48]],
			head: [[0.70, 0.40, 0.20], [0.97, 0.96, 0.93], [0.36, 0.34, 0.32]], wingTip: [[0.16, 0.12, 0.10], [0.85, 0.85, 0.82], [0.12, 0.11, 0.10]],
			tail: [[0.10, 0.08, 0.06], [0.90, 0.90, 0.88], [0.08, 0.08, 0.08]], speck: v !== 1, leg: [0.90, 0.62, 0.16], bill: [0.92, 0.66, 0.18],
			wy: 10, wh: 4, ty: 9, tr: -35, tw: 1.6, th: 5, lx: 1.5, lt: 5 });
	}

	function pato(v) {
		return ave('pato', v, { bFrom: [-2.6, 3, -4.5], bTo: [2.6, 7.5, 4], hy: 7, hz: -3.5, hFrom: [-1.6, 6.5, -6.2], hTo: [1.6, 11, -3], biFrom: [-1.2, 7.4, -8.4], biTo: [1.2, 8.4, -6],
			body: [[0.62, 0.58, 0.52], [0.96, 0.96, 0.94], [0.52, 0.38, 0.24]], breast: [[0.48, 0.26, 0.18], [0.94, 0.94, 0.92], [0.62, 0.48, 0.32]],
			head: [[0.06, 0.40, 0.20], [0.96, 0.96, 0.94], [0.48, 0.34, 0.20]], wingTip: [[0.30, 0.28, 0.26], [0.88, 0.88, 0.86], [0.36, 0.26, 0.16]],
			speculum: [0.20, 0.30, 0.80], tail: [[0.10, 0.10, 0.10], [0.92, 0.92, 0.90], [0.30, 0.22, 0.14]], ring: v === 0, speck: v === 2,
			leg: [0.95, 0.55, 0.12], bill: v === 0 ? [0.85, 0.75, 0.25] : [0.95, 0.68, 0.16], wy: 7, wh: 3, ty: 6, tr: -20, tw: 1.2, th: 2.5, lx: 1.2, lt: 3 });
	}

	window.NC_ANIMALS = {
		vaca: [vaca, 4], porco: [porco, 3], ovelha: [ovelha, 4], cabra: [cabra, 4], cervo: [cervo, 3], burro: [burro, 3], camelo: [camelo, 2],
		lobo: [lobo, 3], raposa: [raposa, 3], urso: [urso, 3], coelho: [coelho, 4], galinha: [galinha, 3], pato: [pato, 3],
	};
	return true;
})();
