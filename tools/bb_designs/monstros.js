// Monstros redesenhados. Humanoides: corpo, cabeca (head), bracos e pernas em dois segmentos
// (armA/armA2, armB/armB2, legA/legA2, legB/legB2). Aranha: 8 pernas (legA/legB + segmento de baixo).
// Gosma: anim "hop"; espectro, chama e vigia: anim "float" (armA/armB).
(function () {
	const BLACK = [0.04, 0.03, 0.03, 1];
	const HOLE = [0, 0, 0, 0];
	const A = (c, a) => [c[0], c[1], c[2], a === undefined ? 1 : a];
	const mul = (c, f) => [c[0] * f, c[1] * f, c[2] * f, c[3] === undefined ? 1 : c[3]];

	function rnd(seed) {
		let s = seed;
		return () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
	}

	function spots(seed, n, color, smin, smax, face) {
		const R = rnd(seed);
		const out = [];
		for (let k = 0; k < n; k++) {
			const s = smin + R() * (smax - smin);
			const x = R() * (1 - s), y = R() * (1 - s);
			out.push({ face: face || '*', r: [x, y, x + s, y + s * (0.6 + R() * 0.8)], color });
		}
		return out;
	}

	function P(parts, name, bone, group, pivot, from, to, color, extra) {
		parts.push(Object.assign({ name, bone, group, bonePivot: pivot, pivot, from, to, color }, extra || {}));
	}

	// Humanoide base. o: {tw, aw, lw, head:[w,h,d], skin, shirt, pants, shoes, armSkin, legSkin, faceDec, shirtDec, pantsDec, armDec, legDec}
	function humanoid(parts, o) {
		const tw = o.tw || 8, aw = o.aw || 3, lw = o.lw || 4, hw = o.head ? o.head[0] : 8, hh = o.head ? o.head[1] : 8, hd = o.head ? o.head[2] : 8;
		const hipX = o.hipX || 2;
		// Pernas: coxa (legA) e canela (legA2), com o pe na canela.
		[[hipX, 'legA', 'pE'], [-hipX, 'legB', 'pD']].forEach(([x, g, b]) => {
			P(parts, 'coxa', b, g, [x, 11, 0], [x - lw / 2, 5.5, -lw / 2], [x + lw / 2, 11.2, lw / 2], o.pants, { decals: o.pantsDec || [], noise: o.noise });
			P(parts, 'canela', b + '2', g + '2', [x, 5.5, 0], [x - lw / 2 + 0.05, 0, -lw / 2 + 0.05], [x + lw / 2 - 0.05, 5.7, lw / 2 - 0.05], o.legSkin || o.pants,
				{ parent: b, decals: (o.legDec || []).concat(o.shoes ? [{ face: '*', r: [0, 0.65, 1, 1], color: o.shoes }] : []), noise: o.noise });
		});
		P(parts, 'tronco', 'corpo', 'corpo', [0, 11, 0], [-tw / 2, 11, -2.5], [tw / 2, 21, 2.5], o.shirt, { decals: o.shirtDec || [], noise: o.noise, fur: o.fur });
		const ax = tw / 2 + aw / 2;
		[[ax, 'armA', 'bE'], [-ax, 'armB', 'bD']].forEach(([x, g, b]) => {
			P(parts, 'braco', b, g, [x, 20, 0], [x - aw / 2, 15.3, -aw / 2], [x + aw / 2, 21, aw / 2], o.sleeve || o.shirt, { decals: o.sleeveDec || [], noise: o.noise });
			P(parts, 'antebraco', b + '2', g + '2', [x, 15.5, 0], [x - aw / 2 + 0.05, 10, -aw / 2 + 0.05], [x + aw / 2 - 0.05, 15.6, aw / 2 - 0.05], o.armSkin || o.skin,
				{ parent: b, decals: o.armDec || [], noise: o.noise });
		});
		P(parts, 'cabeca', 'cabeca', 'head', [0, 21, 0], [-hw / 2, 21, -hd / 2], [hw / 2, 21 + hh, hd / 2], o.skin, { decals: o.faceDec || [], noise: o.noise });
	}

	// Rosto frontal: olhos, boca. y em fracao da altura (0 = topo).
	function face(eye, mouth, o) {
		o = o || {};
		const ey = o.ey ?? 0.42, eh = o.eh ?? 0.14, ew = o.ew ?? 0.2;
		const out = [
			{ face: 'north', r: [0.5 - 0.1 - ew, ey, 0.4, ey + eh], color: o.sclera || eye },
			{ face: 'north', r: [0.6, ey, 0.6 + ew, ey + eh], color: o.sclera || eye },
		];
		if (o.sclera) out.push({ face: 'north', r: [0.4 - ew * 0.5, ey, 0.4, ey + eh], color: eye }, { face: 'north', r: [0.6, ey, 0.6 + ew * 0.5, ey + eh], color: eye });
		if (mouth) out.push({ face: 'north', r: [o.mx0 ?? 0.3, o.my ?? 0.74, o.mx1 ?? 0.7, (o.my ?? 0.74) + (o.mh ?? 0.08)], color: mouth });
		return out;
	}

	// ---------------------------------------------------------------- andarilho (morto-vivo)
	function andarilho(v) {
		const skin = A([[0.38, 0.52, 0.36], [0.30, 0.55, 0.62], [0.62, 0.52, 0.34]][v]);
		const shirt = A([[0.24, 0.34, 0.40], [0.20, 0.28, 0.30], [0.46, 0.38, 0.26]][v]);
		const pants = A([[0.22, 0.20, 0.30], [0.16, 0.20, 0.24], [0.34, 0.28, 0.20]][v]);
		const rot = mul(skin, 0.7), bone = A([0.85, 0.80, 0.62]), blood = A([0.30, 0.10, 0.08]);
		const parts = [];
		const torn = [{ face: 'north', r: [0.05, 0.85, 0.25, 1], color: HOLE }, { face: 'north', r: [0.55, 0.9, 0.7, 1], color: HOLE }, { face: 'south', r: [0.3, 0.88, 0.5, 1], color: HOLE },
			{ face: 'north', r: [0.25, 0.45, 0.55, 0.55], color: bone }, { face: 'north', r: [0.25, 0.6, 0.55, 0.68], color: bone }, { face: 'north', r: [0.22, 0.4, 0.58, 0.72], color: rot },
			{ face: 'east', r: [0.2, 0.3, 0.6, 0.6], color: mul(shirt, 0.6) }].concat(spots(201 + v, 6, mul(shirt, 0.7), 0.08, 0.2));
		torn.splice(5, 0); // ordem: pele exposta primeiro, costelas por cima
		const shirtDec = [torn[5], torn[3], torn[4], torn[0], torn[1], torn[2], torn[6]].concat(torn.slice(7));
		humanoid(parts, { skin, shirt, pants, shoes: A([0.18, 0.14, 0.12]), shirtDec, noise: 0.14,
			sleeve: shirt, sleeveDec: [{ face: '*', r: [0, 0.75, 1, 1], color: HOLE }, { face: 'north', r: [0, 0.6, 0.5, 0.75], color: HOLE }],
			armDec: spots(211 + v, 4, rot, 0.15, 0.3),
			pantsDec: [{ face: 'north', r: [0.1, 0.7, 0.6, 1], color: mul(pants, 0.7) }], legDec: [{ face: 'north', r: [0.2, 0.1, 0.8, 0.4], color: rot }],
			faceDec: face(A([0.70, 0.08, 0.06]), A([0.12, 0.08, 0.06]), { sclera: A([0.92, 0.85, 0.50]), ey: 0.40, my: 0.72, mh: 0.12, mx0: 0.28, mx1: 0.66 })
				.concat([{ face: 'north', r: [0.70, 0.62, 0.95, 0.85], color: rot }, { face: 'north', r: [0.36, 0.84, 0.44, 0.94], color: bone }, { face: 'north', r: [0.52, 0.84, 0.6, 0.94], color: bone },
					{ face: 'east', r: [0.3, 0.2, 0.7, 0.5], color: rot }, { face: 'up', r: [0.1, 0.1, 0.5, 0.4], color: blood }].concat(spots(221 + v, 8, mul(skin, 0.82), 0.06, 0.14))) });
		P(parts, 'cabelo', 'cabeca', 'head', [0, 21, 0], [-4.2, 27.5, -4.2], [4.2, 29.3, 4.2], A([0.16, 0.20, 0.14]), { noise: 0.25, decals: [{ face: '*', r: [0.3, 0, 0.6, 1], color: HOLE }, { face: 'north', r: [0, 0.6, 1, 1], color: HOLE }] });
		if (v === 1) P(parts, 'alga', 'cabeca', 'head', [0, 21, 0], [3, 23, -1], [4.4, 29.5, 1], A([0.15, 0.40, 0.18]), { noise: 0.3 });
		return { name: 'andarilho_' + v, parts };
	}

	// ---------------------------------------------------------------- esqueleto
	function esqueleto(v) {
		const b = v === 0 ? A([0.88, 0.86, 0.78]) : A([0.24, 0.22, 0.22]);
		const dk = v === 0 ? A([0.12, 0.11, 0.10]) : A([0.70, 0.25, 0.08]);
		const parts = [];
		// Pernas e bracos finos (ossos), pelve, coluna, costelas e cranio.
		[[2, 'legA', 'pE'], [-2, 'legB', 'pD']].forEach(([x, g, bn]) => {
			P(parts, 'femur', bn, g, [x, 11, 0], [x - 0.9, 5.5, -0.9], [x + 0.9, 11.2, 0.9], b);
			P(parts, 'joelho', bn, g, [x, 11, 0], [x - 1.2, 5.2, -1.2], [x + 1.2, 6.4, 1.2], mul(b, 0.92));
			P(parts, 'tibia', bn + '2', g + '2', [x, 5.5, 0], [x - 0.8, 1, -0.8], [x + 0.8, 5.6, 0.8], b, { parent: bn });
			P(parts, 'pe', bn + '2', g + '2', [x, 5.5, 0], [x - 1.2, 0, -2], [x + 1.2, 1.1, 1], b, { parent: bn });
		});
		P(parts, 'pelve', 'corpo', 'corpo', [0, 11, 0], [-3.5, 10.5, -1.5], [3.5, 12.6, 1.5], b);
		P(parts, 'coluna', 'corpo', 'corpo', [0, 11, 0], [-0.8, 12.5, 0.2], [0.8, 21, 1.8], b);
		for (let k = 0; k < 4; k++) {
			const y = 14 + k * 1.8;
			P(parts, 'costela', 'corpo', 'corpo', [0, 11, 0], [-3.4 + k * 0.15, y, -2.2], [3.4 - k * 0.15, y + 0.9, 1.6], b, { decals: [{ face: 'north', r: [0.42, 0, 0.58, 1], color: mul(b, 0.85) }] });
		}
		P(parts, 'ombros', 'corpo', 'corpo', [0, 11, 0], [-4, 20, -1.4], [4, 21, 1.4], b);
		[[5, 'armA', 'bE'], [-5, 'armB', 'bD']].forEach(([x, g, bn]) => {
			P(parts, 'umero', bn, g, [x, 20, 0], [x - 0.9, 15.3, -0.9], [x + 0.9, 21, 0.9], b);
			P(parts, 'radio', bn + '2', g + '2', [x, 15.5, 0], [x - 0.8, 10.5, -0.8], [x + 0.8, 15.6, 0.8], b, { parent: bn });
			P(parts, 'mao', bn + '2', g + '2', [x, 15.5, 0], [x - 1, 9.4, -1], [x + 1, 10.6, 1], mul(b, 0.92), { parent: bn });
		});
		P(parts, 'cranio', 'cabeca', 'head', [0, 21, 0], [-3.8, 22.5, -3.8], [3.8, 29.5, 3.8], b,
			{ decals: [{ face: 'north', r: [0.12, 0.35, 0.42, 0.62], color: dk }, { face: 'north', r: [0.58, 0.35, 0.88, 0.62], color: dk }, { face: 'north', r: [0.44, 0.62, 0.56, 0.74], color: dk }].concat(
				[0.18, 0.32, 0.46, 0.6, 0.74].map(x => ({ face: 'north', r: [x, 0.84, x + 0.08, 1], color: dk })), spots(231 + v, 5, mul(b, 0.88), 0.06, 0.15)) });
		P(parts, 'mandibula', 'cabeca', 'head', [0, 21, 0], [-3, 21, -3.6], [3, 22.6, 2], b, { decals: [0.2, 0.36, 0.52, 0.68].map(x => ({ face: 'north', r: [x, 0, x + 0.08, 0.5], color: dk })) });
		P(parts, 'aljava', 'corpo', 'corpo', [0, 11, 0], [-1.5, 13.5, 2], [1.5, 21.5, 4], A([0.36, 0.22, 0.12]), { rotation: [0, 0, 18], decals: [{ face: '*', r: [0, 0.15, 1, 0.22], color: A([0.6, 0.6, 0.62]) }] });
		P(parts, 'flechas', 'corpo', 'corpo', [0, 11, 0], [-1, 21.5, 2.4], [1, 24, 3.6], A([0.90, 0.90, 0.88]), { rotation: [0, 0, 18] });
		return { name: 'esqueleto_' + v, parts };
	}

	// ---------------------------------------------------------------- mumia
	function mumia(v) {
		const band = A(v === 0 ? [0.80, 0.74, 0.56] : [0.86, 0.80, 0.60]);
		const dark = mul(band, 0.68), gold = A([0.95, 0.75, 0.20]), lapis = A([0.18, 0.32, 0.85]);
		const eye = v === 0 ? A([0.40, 1.0, 0.60]) : A([1.0, 0.80, 0.20]);
		const stripes = (seed) => {
			const R = rnd(seed);
			const out = [];
			for (let k = 0; k < 9; k++) {
				const y = k / 9 + (R() - 0.5) * 0.04;
				out.push({ face: '*', r: [0, y, 1, y + 0.025 + R() * 0.02], color: dark });
			}
			return out;
		};
		const parts = [];
		humanoid(parts, { skin: band, shirt: band, pants: band, noise: 0.12, shirtDec: stripes(241), pantsDec: stripes(242), legDec: stripes(243), sleeveDec: stripes(244), armDec: stripes(245),
			faceDec: stripes(246).concat([{ face: 'north', r: [0.15, 0.36, 0.85, 0.56], color: A([0.10, 0.08, 0.06]) }, { face: 'north', r: [0.22, 0.4, 0.4, 0.52], color: eye }, { face: 'north', r: [0.6, 0.4, 0.78, 0.52], color: eye }]) });
		// Faixas soltas pendendo dos bracos e do quadril.
		P(parts, 'faixa', 'bE2', 'armA2', [5.5, 15.5, 0], [5.6, 8.5, -0.4], [6.2, 12, 0.4], band, { parent: 'bE', rotation: [0, 0, 10] });
		P(parts, 'faixa2', 'corpo', 'corpo', [0, 11, 0], [-3.5, 8, -2.7], [-2.6, 11.5, -2.4], band, { rotation: [0, 0, -8] });
		if (v === 1) {
			P(parts, 'nemes', 'cabeca', 'head', [0, 21, 0], [-4.4, 25, -4.3], [4.4, 29.6, 4.4], gold, { decals: [0.1, 0.3, 0.5, 0.7, 0.9].map(y => ({ face: '*', r: [0, y, 1, y + 0.1], color: lapis })) });
			P(parts, 'lapelas', 'cabeca', 'head', [0, 21, 0], [-4.6, 20, -2], [-3.9, 26, 1], gold, { decals: [0.15, 0.45, 0.75].map(y => ({ face: '*', r: [0, y, 1, y + 0.15], color: lapis })) });
			P(parts, 'lapelas2', 'cabeca', 'head', [0, 21, 0], [3.9, 20, -2], [4.6, 26, 1], gold, { decals: [0.15, 0.45, 0.75].map(y => ({ face: '*', r: [0, y, 1, y + 0.15], color: lapis })) });
			P(parts, 'colar', 'corpo', 'corpo', [0, 11, 0], [-4.2, 18.5, -2.8], [4.2, 21.2, 2.8], gold, { decals: [{ face: 'north', r: [0, 0.3, 1, 0.6], color: lapis }, { face: 'north', r: [0.4, 0.6, 0.6, 1], color: A([0.85, 0.15, 0.2]) }] });
		}
		return { name: 'mumia_' + v, parts };
	}

	// ---------------------------------------------------------------- goblin
	function goblin(v) {
		const skin = A([[0.36, 0.55, 0.20], [0.40, 0.46, 0.52], [0.70, 0.24, 0.16]][v]);
		const cloth = A([0.36, 0.26, 0.16]), tooth = A([0.95, 0.93, 0.82]);
		const parts = [];
		humanoid(parts, { skin, shirt: cloth, pants: mul(cloth, 0.75), tw: 7, aw: 2.4, lw: 2.8, hipX: 1.6, head: [9, 8, 8], noise: 0.14,
			sleeve: skin, legSkin: skin, shoes: null,
			shirtDec: [{ face: '*', r: [0, 0, 1, 0.25], color: skin }, { face: 'north', r: [0.3, 0.5, 0.45, 0.7], color: mul(cloth, 0.6) }, { face: '*', r: [0, 0.82, 0.2, 1], color: HOLE }, { face: '*', r: [0.6, 0.86, 0.75, 1], color: HOLE }],
			pantsDec: [{ face: '*', r: [0, 0.45, 1, 1], color: skin }],
			faceDec: face(A([1.0, 0.85, 0.10]), A([0.10, 0.04, 0.03]), { ey: 0.36, eh: 0.14, ew: 0.22, my: 0.70, mh: 0.12, mx0: 0.22, mx1: 0.78 })
				.concat([{ face: 'north', r: [0.3, 0.7, 0.38, 0.82], color: tooth }, { face: 'north', r: [0.62, 0.7, 0.7, 0.82], color: tooth }, { face: 'north', r: [0.2, 0.3, 0.42, 0.36], color: mul(skin, 0.6) }, { face: 'north', r: [0.58, 0.3, 0.8, 0.36], color: mul(skin, 0.6) }]) });
		P(parts, 'nariz', 'cabeca', 'head', [0, 21, 0], [-1, 24.5, -6], [1, 27, -4], mul(skin, 0.9), { rotation: [-10, 0, 0] });
		for (const s of [-1, 1]) {
			P(parts, 'orelha', 'cabeca', 'head', [s * 4.5, 26, 0], s < 0 ? [-9, 25.5, -0.5] : [4.5, 25.5, -0.5], s < 0 ? [-4.5, 27.5, 0.5] : [9, 27.5, 0.5], skin, { rotation: [0, s * 20, s * 15],
				decals: [{ face: 'north', r: [0.2, 0.2, 0.8, 0.8], color: mul(skin, 0.7) }] });
		}
		P(parts, 'tanga', 'corpo', 'corpo', [0, 11, 0], [-2.5, 7.5, -2.7], [2.5, 11.5, -2.4], mul(cloth, 0.8), { decals: [{ face: 'north', r: [0, 0.85, 1, 1], color: HOLE }] });
		P(parts, 'faca', 'bE2', 'armA2', [4.7, 15.5, 0], [4.3, 8.5, -3.5], [5.1, 10.2, 0], A([0.62, 0.62, 0.66]), { parent: 'bE', decals: [{ face: '*', r: [0, 0, 0.3, 1], color: A([0.36, 0.22, 0.12]) }] });
		return { name: 'goblin_' + v, parts };
	}

	// ---------------------------------------------------------------- ogro
	function ogro(v) {
		const skin = A([[0.58, 0.48, 0.30], [0.52, 0.52, 0.50], [0.40, 0.50, 0.28]][v]);
		const hide = A([0.40, 0.28, 0.16]), tusk = A([0.95, 0.93, 0.85]);
		const parts = [];
		humanoid(parts, { skin, shirt: skin, pants: hide, tw: 12, aw: 4.5, lw: 4.6, hipX: 2.8, head: [7, 7, 7], noise: 0.14, sleeve: skin, legSkin: skin,
			shirtDec: [{ face: 'north', r: [0.3, 0.15, 0.7, 0.4], color: mul(skin, 0.85) }, { face: '*', r: [0, 0.75, 1, 1], color: hide }, { face: 'north', r: [0.45, 0.75, 0.55, 0.85], color: A([0.6, 0.6, 0.62]) }].concat(spots(261 + v, 8, mul(skin, 0.88), 0.06, 0.14)),
			pantsDec: [{ face: '*', r: [0, 0.6, 1, 1], color: skin }, { face: '*', r: [0, 0.55, 1, 0.62], color: mul(hide, 0.7) }],
			faceDec: face(A([0.90, 0.20, 0.10]), A([0.12, 0.06, 0.04]), { ey: 0.32, eh: 0.12, ew: 0.2, my: 0.66, mh: 0.12, mx0: 0.2, mx1: 0.8 })
				.concat([{ face: 'north', r: [0.15, 0.24, 0.85, 0.32], color: mul(skin, 0.6) }]) });
		P(parts, 'barriga', 'corpo', 'corpo', [0, 11, 0], [-5, 12, -3.8], [5, 18.5, -2.4], mul(skin, 1.05), { decals: [{ face: 'north', r: [0.45, 0.4, 0.55, 0.5], color: mul(skin, 0.7) }] });
		P(parts, 'mandibula', 'cabeca', 'head', [0, 21, 0], [-3, 21, -4.4], [3, 23.4, -2.6], skin);
		for (const s of [-1, 1]) P(parts, 'presa', 'cabeca', 'head', [s * 2, 23, -4], [s * 2 - 0.5, 23, -4.6], [s * 2 + 0.5, 25.2, -3.8], tusk);
		P(parts, 'tacape', 'bE2', 'armA2', [8.25, 15.5, 0], [7.4, 9.5, -9], [9.1, 11.2, 0], A([0.40, 0.26, 0.14]), { parent: 'bE' });
		P(parts, 'tacape2', 'bE2', 'armA2', [8.25, 15.5, 0], [7, 8.8, -13.5], [9.5, 11.9, -9], A([0.34, 0.22, 0.12]), { parent: 'bE', noise: 0.2,
			decals: [{ face: '*', r: [0.2, 0.2, 0.3, 0.3], color: A([0.7, 0.7, 0.72]) }, { face: '*', r: [0.6, 0.6, 0.7, 0.7], color: A([0.7, 0.7, 0.72]) }] });
		return { name: 'ogro_' + v, parts };
	}

	// ---------------------------------------------------------------- golem
	function golem(v) {
		const st = A([[0.46, 0.46, 0.48], [0.42, 0.46, 0.40], [0.16, 0.16, 0.18]][v]);
		const moss = A(v === 2 ? [0.6, 0.25, 0.08] : [0.24, 0.42, 0.16]);
		const core = A(v === 2 ? [1.0, 0.35, 0.05] : [1.0, 0.55, 0.10]);
		const cracks = (seed) => spots(seed, 10, mul(st, 0.55), 0.02, 0.06).concat(spots(seed + 1, 6, mul(st, 1.18), 0.1, 0.25));
		const mossy = (seed) => spots(seed, v === 1 ? 10 : 4, moss, 0.1, 0.3, 'up').concat(spots(seed + 3, v === 1 ? 8 : 3, moss, 0.08, 0.2, 'side'));
		const parts = [];
		humanoid(parts, { skin: st, shirt: st, pants: mul(st, 0.9), tw: 10, aw: 4.5, lw: 4.4, hipX: 2.6, head: [7, 7, 7], noise: 0.18,
			shirtDec: cracks(271).concat(mossy(272), [{ face: 'north', r: [0.3, 0.3, 0.7, 0.62], color: mul(st, 0.45) }, { face: 'north', r: [0.38, 0.36, 0.62, 0.56], color: core }, { face: 'north', r: [0.45, 0.42, 0.55, 0.5], color: A([1, 0.95, 0.6]) }]),
			sleeveDec: cracks(273).concat(mossy(274)), armDec: cracks(275), pantsDec: cracks(276), legDec: cracks(277),
			faceDec: cracks(278).concat(mossy(279), [{ face: 'north', r: [0.12, 0.38, 0.88, 0.56], color: mul(st, 0.4) }, { face: 'north', r: [0.18, 0.42, 0.42, 0.52], color: core }, { face: 'north', r: [0.58, 0.42, 0.82, 0.52], color: core }]) });
		P(parts, 'ombreiraE', 'bE', 'armA', [7.25, 20, 0], [4.8, 19.5, -2.8], [9.7, 22.5, 2.8], mul(st, 1.05), { decals: cracks(281).concat(mossy(282)) });
		P(parts, 'ombreiraD', 'bD', 'armB', [-7.25, 20, 0], [-9.7, 19.5, -2.8], [-4.8, 22.5, 2.8], mul(st, 1.05), { decals: cracks(283).concat(mossy(284)) });
		P(parts, 'punhoE', 'bE2', 'armA2', [7.25, 15.5, 0], [4.6, 8.4, -2.8], [9.9, 11.5, 2.8], mul(st, 0.95), { parent: 'bE', decals: cracks(285) });
		P(parts, 'punhoD', 'bD2', 'armB2', [-7.25, 15.5, 0], [-9.9, 8.4, -2.8], [-4.6, 11.5, 2.8], mul(st, 0.95), { parent: 'bD', decals: cracks(286) });
		return { name: 'golem_' + v, parts };
	}

	// ---------------------------------------------------------------- espectro
	function espectro(v) {
		const gh = A(v === 0 ? [0.72, 0.86, 0.95] : [0.66, 0.52, 0.92], 0.75);
		const dk = mul(gh, 0.7); dk[3] = 0.75;
		const eye = v === 0 ? A([0.70, 1.0, 1.0]) : A([1.0, 0.70, 1.0]);
		const parts = [];
		const wisp = (s) => spots(s, 6, A([gh[0] * 1.15, gh[1] * 1.15, gh[2] * 1.15], 0.75), 0.05, 0.15).concat([{ face: '*', r: [0, 0.88, 0.3, 1], color: HOLE }, { face: '*', r: [0.5, 0.92, 0.75, 1], color: HOLE }]);
		P(parts, 'manto', 'corpo', 'corpo', [0, 11, 0], [-4, 11, -2.5], [4, 21, 2.5], gh, { decals: wisp(291) });
		P(parts, 'saia', 'corpo', 'corpo', [0, 11, 0], [-3.4, 5, -2], [3.4, 11.2, 2], dk, { decals: wisp(292) });
		P(parts, 'cauda', 'corpo', 'corpo', [0, 11, 0], [-2.2, 0.5, -1.2], [2.2, 5.2, 1.6], dk, { rotation: [12, 0, 0], decals: wisp(293) });
		P(parts, 'capuz', 'cabeca', 'head', [0, 21, 0], [-4.4, 21, -4.2], [4.4, 30, 4.4], gh,
			{ decals: [{ face: 'north', r: [0.15, 0.18, 0.85, 0.95], color: A([0.04, 0.05, 0.08]) }, { face: 'north', r: [0.25, 0.4, 0.42, 0.5], color: eye }, { face: 'north', r: [0.58, 0.4, 0.75, 0.5], color: eye }].concat(wisp(294).slice(0, 4)) });
		P(parts, 'ponta', 'cabeca', 'head', [0, 21, 0], [-1.5, 29, 1], [1.5, 31, 5], gh, { rotation: [-20, 0, 0] });
		for (const [x, g, b] of [[5.5, 'armA', 'bE'], [-5.5, 'armB', 'bD']]) {
			P(parts, 'manga', b, g, [x, 20, 0], [x - 1.5, 13, -1.5], [x + 1.5, 21, 1.5], gh, { decals: wisp(295) });
			P(parts, 'garra', b, g, [x, 20, 0], [x - 0.9, 10.5, -0.9], [x + 0.9, 13.2, 0.9], A([0.04, 0.05, 0.08], 0.9));
		}
		return { name: 'espectro_' + v, parts };
	}

	// ---------------------------------------------------------------- aranha
	function aranha(v) {
		const body = A([[0.16, 0.13, 0.12], [0.14, 0.26, 0.10], [0.26, 0.14, 0.34]][v]);
		const mark = A([[0.75, 0.10, 0.08], [0.85, 0.80, 0.20], [0.95, 0.55, 0.15]][v]);
		const hair = mul(body, 1.5), band = A([0.42, 0.30, 0.20]), eyeC = A([0.95, 0.10, 0.10]);
		const parts = [];
		P(parts, 'abdomen', 'corpo', 'corpo', [0, 7, 3], [-5.5, 4, 0.5], [5.5, 12, 12], body, { noise: 0.22, rotation: [-12, 0, 0],
			decals: [{ face: 'up', r: [0.4, 0.15, 0.6, 0.8], color: mark }, { face: 'up', r: [0.25, 0.3, 0.75, 0.38], color: mark }, { face: 'up', r: [0.3, 0.55, 0.7, 0.62], color: mark },
				{ face: 'south', r: [0.3, 0.3, 0.7, 0.6], color: mark }].concat(spots(301 + v, 30, hair, 0.02, 0.05)) });
		P(parts, 'cintura', 'corpo', 'corpo', [0, 7, 0], [-2, 5.5, -1], [2, 8.5, 1.5], body);
		const eyes = [[0.3, 0.3], [0.62, 0.3], [0.18, 0.18], [0.74, 0.18], [0.06, 0.32], [0.86, 0.32], [0.38, 0.12], [0.54, 0.12]].map(([x, y]) => ({ face: 'north', r: [x, y, x + 0.1, y + 0.12], color: eyeC }));
		P(parts, 'cefalotorax', 'cabeca', 'head', [0, 7, -1], [-3.8, 4.5, -7.5], [3.8, 9.8, -0.5], mul(body, 1.1), { noise: 0.18, decals: eyes.concat(spots(311 + v, 14, hair, 0.03, 0.06, 'up')) });
		for (const s of [-1, 1]) P(parts, 'quelicera', 'cabeca', 'head', [0, 7, -1], [s * 1.4 - 0.8, 3, -8.2], [s * 1.4 + 0.8, 6, -6.8], body, { decals: [{ face: '*', r: [0, 0.65, 1, 1], color: A([0.78, 0.74, 0.62]) }] });
		for (let i = 0; i < 4; i++) {
			const z = -5.5 + i * 2.2;
			const ga = i % 2 === 0 ? 'legA' : 'legB', gb = i % 2 === 0 ? 'legB' : 'legA';
			for (const [s, g] of [[1, ga], [-1, gb]]) {
				const bn = 'l' + i + (s > 0 ? 'E' : 'D');
				const x0 = s * 3.2;
				const ang = (i - 1.5) * 18;
				P(parts, 'femur', bn, g, [x0, 7, z], s > 0 ? [x0, 6.2, z - 0.7] : [x0 - 7.5, 6.2, z - 0.7], s > 0 ? [x0 + 7.5, 7.6, z + 0.7] : [x0, 7.6, z + 0.7], body,
					{ boneRotation: [0, 0, s * 25], noise: 0.25, decals: [{ face: '*', r: [0.45, 0, 0.55, 1], color: band }].concat(spots(321 + i, 6, hair, 0.04, 0.08)) });
				const kx = x0 + s * 7.5;
				P(parts, 'tibia', bn + 'b', 'perna2', [kx, 7, z], s > 0 ? [kx - 0.6, -0.5, z - 0.6] : [kx - 0.6, -0.5, z - 0.6], [kx + 0.6, 7.2, z + 0.6], body,
					{ parent: bn, boneRotation: [0, 0, s * -40], noise: 0.25, decals: [{ face: '*', r: [0, 0.4, 1, 0.48], color: band }, { face: '*', r: [0, 0.88, 1, 1], color: BLACK }] });
			}
		}
		return { name: 'aranha_' + v, parts };
	}

	// ---------------------------------------------------------------- gosma
	function gosma(v) {
		const c = [[0.36, 0.78, 0.30], [0.28, 0.50, 0.96], [0.96, 0.36, 0.08]][v];
		const parts = [];
		const outer = A(c, 0.7), core = A(c.map(x => x * 0.5));
		const dark = A([0.05, 0.10, 0.05]);
		P(parts, 'nucleo', 'corpo', 'corpo', [0, 0, 0], [-3, 2, -3], [3, 8, 3], core, { noise: 0.2 });
		P(parts, 'bolha', 'corpo', 'corpo', [0, 0, 0], [1.5, 6.5, 0], [3.2, 8.2, 1.7], A(c.map(x => Math.min(1, x * 1.4))), { noise: 0.05 });
		P(parts, 'bolha2', 'corpo', 'corpo', [0, 0, 0], [-3.8, 3, 1], [-2.6, 4.2, 2.2], A(c.map(x => Math.min(1, x * 1.4))), { noise: 0.05 });
		P(parts, 'olhoE', 'corpo', 'corpo', [0, 0, 0], [-4, 6, -6.1], [-1.6, 9, -5.3], dark, { decals: [{ face: 'north', r: [0.1, 0.1, 0.45, 0.4], color: A([0.9, 0.95, 0.9]) }] });
		P(parts, 'olhoD', 'corpo', 'corpo', [0, 0, 0], [1.6, 6, -6.1], [4, 9, -5.3], dark, { decals: [{ face: 'north', r: [0.1, 0.1, 0.45, 0.4], color: A([0.9, 0.95, 0.9]) }] });
		P(parts, 'boca', 'corpo', 'corpo', [0, 0, 0], [-1.8, 3.4, -6.1], [1.8, 4.4, -5.3], dark);
		P(parts, 'corpo', 'corpo', 'corpo', [0, 0, 0], [-6, 0, -6], [6, 11, 6], outer,
			{ noise: 0.08, decals: [{ face: 'up', r: [0.15, 0.15, 0.45, 0.4], color: A(c.map(x => Math.min(1, x * 1.5)), 0.85) }, { face: 'north', r: [0.1, 0.05, 0.3, 0.2], color: A(c.map(x => Math.min(1, x * 1.6)), 0.85) }] });
		return { name: 'gosma_' + v, parts };
	}

	// ---------------------------------------------------------------- salamandra (quadrupede de fogo)
	function salamandra() {
		const red = A([0.80, 0.24, 0.06]), belly = A([1.0, 0.62, 0.18]), spot = A([1.0, 0.85, 0.20]);
		const parts = [];
		P(parts, 'tronco', 'corpo', 'corpo', [0, 0, 0], [-3, 2.5, -8], [3, 6.5, 8], red, { noise: 0.15, decals: [{ face: 'down', r: [0, 0, 1, 1], color: belly }].concat(spots(331, 12, spot, 0.06, 0.14, 'up'), spots(332, 8, spot, 0.06, 0.12, 'side')) });
		P(parts, 'cabeca', 'cabeca', 'head', [0, 5, -8], [-3, 3, -14], [3, 7, -7.5], mul(red, 1.08),
			{ decals: [{ face: 'north', r: [0.1, 0.25, 0.32, 0.45], color: spot }, { face: 'north', r: [0.68, 0.25, 0.9, 0.45], color: spot }, { face: 'north', r: [0.1, 0.72, 0.9, 0.8], color: A([0.3, 0.05, 0.02]) }, { face: 'down', r: [0, 0, 1, 1], color: belly }] });
		for (const s of [-1, 1]) P(parts, 'crista', 'cabeca', 'head', [0, 5, -8], [s * 1.2 - 0.3, 7, -13], [s * 1.2 + 0.3, 8.2, -8], spot);
		P(parts, 'cauda1', 'cauda', 'tail', [0, 4.5, 8], [-2.2, 3, 7.5], [2.2, 6, 13], red, { decals: spots(333, 5, spot, 0.08, 0.15, 'up') });
		P(parts, 'cauda2', 'cauda2', 'tail', [0, 4.2, 13], [-1.4, 3.2, 12.5], [1.4, 5.2, 19], red, { parent: 'cauda', boneRotation: [0, 12, 0], decals: [{ face: '*', r: [0, 0.8, 1, 1], color: spot }] });
		[[3, -5.5, 'legA'], [-3, -5.5, 'legB'], [3, 5.5, 'legB'], [-3, 5.5, 'legA']].forEach(([x, z, g], i) => {
			const s = Math.sign(x);
			P(parts, 'coxa', 'p' + i, g, [x, 4.5, z], s > 0 ? [x, 3.4, z - 1] : [x - 3.5, 3.4, z - 1], s > 0 ? [x + 3.5, 5.4, z + 1] : [x, 5.4, z + 1], red);
			P(parts, 'pata', 'p' + i + 'b', g + '2', [x + s * 3, 4.5, z], [x + s * 3 - 1, 0, z - 1.6], [x + s * 3 + 1, 4.6, z + 1], mul(red, 0.85), { parent: 'p' + i, decals: [{ face: '*', r: [0, 0.8, 1, 1], color: belly }] });
		});
		return { name: 'salamandra_0', parts };
	}

	// ---------------------------------------------------------------- chama (espirito de fogo)
	function chama() {
		const core = A([1.0, 0.62, 0.12]), hot = A([1.0, 0.90, 0.40]), deep = A([0.90, 0.25, 0.04]);
		const parts = [];
		P(parts, 'nucleo', 'corpo', 'corpo', [0, 13, 0], [-3, 10, -3], [3, 16, 3], core, { noise: 0.2,
			decals: [{ face: 'north', r: [0.15, 0.35, 0.38, 0.55], color: A([0.25, 0.05, 0.0]) }, { face: 'north', r: [0.62, 0.35, 0.85, 0.55], color: A([0.25, 0.05, 0.0]) }, { face: 'north', r: [0.3, 0.7, 0.7, 0.8], color: A([0.25, 0.05, 0.0]) }] });
		P(parts, 'aura', 'corpo', 'corpo', [0, 13, 0], [-2.2, 5, -2.2], [2.2, 10.5, 2.2], deep, { noise: 0.25 });
		P(parts, 'ponta', 'corpo', 'corpo', [0, 13, 0], [-1.2, 1.5, -1.2], [1.2, 5.5, 1.2], mul(deep, 0.8), { rotation: [0, 45, 0] });
		const R = rnd(341);
		for (let k = 0; k < 6; k++) {
			const a = k * 60, h = 3 + R() * 4;
			P(parts, 'lingua', 'cabeca', 'head', [0, 16, 0], [-0.9, 15.5, -0.9], [0.9, 15.5 + h, 0.9], k % 2 ? hot : core, { rotation: [20, a, 0], noise: 0.25 });
		}
		for (const [x, g] of [[5, 'armA'], [-5, 'armB']]) {
			P(parts, 'brasa', g, g, [x, 14, 0], [x - 1, 8, -1], [x + 1, 14, 1], deep, { noise: 0.25 });
			P(parts, 'brasa2', g, g, [x, 14, 0], [x - 0.6, 6, -0.6], [x + 0.6, 8.2, 0.6], hot);
		}
		return { name: 'chama_0', parts };
	}

	// ---------------------------------------------------------------- vigia (olho de cristal flutuante)
	function vigia() {
		const shell = A([0.24, 0.16, 0.36]), crystal = A([0.55, 0.92, 1.0]), white = A([0.95, 0.95, 0.92]);
		const parts = [];
		P(parts, 'casco', 'corpo', 'corpo', [0, 13, 0], [-5, 8, -5], [5, 18, 5], shell, { noise: 0.15, decals: spots(351, 12, mul(shell, 1.4), 0.05, 0.12) });
		P(parts, 'olho', 'cabeca', 'head', [0, 13, 0], [-3.5, 9.5, -5.6], [3.5, 16.5, -4.8], white,
			{ decals: [{ face: 'north', r: [0.25, 0.25, 0.75, 0.75], color: A([0.15, 0.75, 0.95]) }, { face: 'north', r: [0.38, 0.38, 0.62, 0.62], color: BLACK }, { face: 'north', r: [0.3, 0.3, 0.4, 0.4], color: white }] });
		P(parts, 'palpebra', 'cabeca', 'head', [0, 13, 0], [-4, 16, -5.8], [4, 17.5, -4.6], mul(shell, 1.2));
		const R = rnd(361);
		for (let k = 0; k < 5; k++) {
			const x = -3 + R() * 6, z = -2 + R() * 5, h = 3 + R() * 4;
			P(parts, 'cristal', 'corpo', 'corpo', [x, 18, z], [x - 0.8, 17.5, z - 0.8], [x + 0.8, 17.5 + h, z + 0.8], crystal, { rotation: [R() * 30 - 15, 45, R() * 30 - 15], noise: 0.1,
				decals: [{ face: '*', r: [0, 0, 0.3, 1], color: A([0.85, 0.98, 1.0]) }] });
		}
		for (const [x, g] of [[6.5, 'armA'], [-6.5, 'armB']]) {
			P(parts, 'tentaculo', g, g, [x, 15, 0], [x - 1.2, 8, -1], [x + 1.2, 15, 1], mul(shell, 0.8), { noise: 0.15 });
			P(parts, 'ponta', g, g, [x, 15, 0], [x - 0.7, 6, -0.7], [x + 0.7, 8.2, 0.7], crystal);
		}
		return { name: 'vigia_0', parts };
	}

	window.NC_MONSTERS = {
		andarilho: [andarilho, 3], esqueleto: [esqueleto, 2], mumia: [mumia, 2], goblin: [goblin, 3], ogro: [ogro, 3], golem: [golem, 3],
		espectro: [espectro, 2], aranha: [aranha, 3], gosma: [gosma, 3], salamandra: [salamandra, 1], chama: [chama, 1], vigia: [vigia, 1],
	};
	return true;
})();
