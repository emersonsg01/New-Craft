// Cavalo redesenhado: corpo com peito, garupa e barriga; pescoco inclinado com crina em camadas;
// cabeca com cranio, focinho, orelhas e topete; pernas em dois segmentos com jarrete, boleto e casco;
// cauda em dois segmentos. 7 pelagens.
(function () {
	const PEL = [
		{ c: [0.45, 0.27, 0.14], m: [0.16, 0.10, 0.07], blaze: true },
		{ c: [0.13, 0.11, 0.10], m: [0.06, 0.05, 0.05] },
		{ c: [0.90, 0.88, 0.84], m: [0.70, 0.70, 0.72] },
		{ c: [0.62, 0.62, 0.64], m: [0.25, 0.25, 0.27], spots: [0.40, 0.40, 0.42], nspots: 46 },
		{ c: [0.92, 0.90, 0.86], m: [0.30, 0.20, 0.12], spots: [0.42, 0.26, 0.14], nspots: 9, big: true, blaze: true },
		{ c: [0.86, 0.66, 0.36], m: [0.96, 0.92, 0.80] },
		{ c: [0.64, 0.46, 0.25], m: [0.08, 0.07, 0.06], socks: true },
	];
	const HOOF = [0.20, 0.17, 0.14, 1];
	const BLACK = [0.04, 0.03, 0.03, 1];
	const WHITE = [0.93, 0.92, 0.88, 1];

	function rnd(seed) {
		let s = seed;
		return () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
	}

	function horse(v) {
		const P = PEL[v];
		const c = [...P.c, 1];
		const m = [...P.m, 1];
		const dark = [P.c[0] * 0.7, P.c[1] * 0.7, P.c[2] * 0.7, 1];
		const R = rnd(91 + v * 17);
		const spots = [];
		if (P.spots) {
			for (let k = 0; k < P.nspots; k++) {
				const sz = P.big ? 0.18 + R() * 0.22 : 0.04 + R() * 0.05;
				const x = R() * (1 - sz), y = R() * (1 - sz);
				spots.push({ face: '*', r: [x, y, x + sz, y + sz * (P.big ? 1.2 : 1)], color: [...P.spots, 1] });
			}
		}
		const parts = [];
		const body = (name, from, to, extra) => parts.push(Object.assign({ name, bone: 'corpo', group: 'corpo', pivot: [0, 0, 0], from, to, color: c, fur: true, decals: spots }, extra || {}));
		body('tronco', [-4.5, 14, -9], [4.5, 23, 9]);
		body('peito', [-4, 12.5, -10.5], [4, 21.5, -6.5]);
		body('garupa', [-4.3, 20.5, 3.5], [4.3, 24, 10]);
		body('barriga', [-3.6, 13, -6], [3.6, 14.5, 6], { color: dark, decals: [] });
		// Pernas: [x, z, grupo, traseira]
		const legs = [[2.6, -7, 'legA', false], [-2.6, -7, 'legB', false], [2.6, 7, 'legB', true], [-2.6, 7, 'legA', true]];
		legs.forEach((L, i) => {
			const [x, z, g, hind] = L;
			const up = 'perna' + i;
			const lo = 'canela' + i;
			const t = hind ? 1.7 : 1.35;
			parts.push({ name: 'coxa', bone: up, group: g, pivot: [x, 15.5, z], from: [x - t, 7.5, z - t - (hind ? 0.6 : 0.2)], to: [x + t, 16, z + t], color: c, fur: true, decals: spots });
			const sock = P.socks ? m : c;
			parts.push({ name: 'canela', bone: lo, group: g + '2', parent: up, pivot: [x, 8, z], from: [x - 1.1, 2.2, z - 1.1], to: [x + 1.1, 8.3, z + 1.1], color: sock, fur: true });
			parts.push({ name: 'boleto', bone: lo, group: g + '2', parent: up, pivot: [x, 8, z], from: [x - 1.3, 1.5, z - 1.5], to: [x + 1.3, 2.6, z + 1.2], color: sock });
			parts.push({ name: 'casco', bone: lo, group: g + '2', parent: up, pivot: [x, 8, z], from: [x - 1.6, 0, z - 1.9], to: [x + 1.6, 1.7, z + 1.4], color: HOOF, noise: 0.05,
				decals: [{ face: 'north', r: [0.45, 0, 0.55, 1], color: [0.12, 0.10, 0.08, 1] }] });
		});
		// Pescoco inclinado para a frente, crina e cabeca (osso "head").
		const hp = [0, 21, -8];
		parts.push({ name: 'pescoco', bone: 'cabeca', group: 'head', bonePivot: hp, pivot: [0, 21, -8.5], rotation: [-32, 0, 0], from: [-2.4, 18.5, -11.2], to: [2.4, 31, -5.8], color: c, fur: true });
		parts.push({ name: 'crina', bone: 'cabeca', group: 'head', pivot: [0, 21, -8.5], rotation: [-32, 0, 0], from: [-0.9, 21, -6.4], to: [0.9, 33, -4.4], color: m, fur: true, noise: 0.18 });
		parts.push({ name: 'crina2', bone: 'cabeca', group: 'head', pivot: [0, 21, -8.5], rotation: [-32, 0, 0], from: [-0.6, 19, -5], to: [1.2, 28, -3.6], color: m, fur: true, noise: 0.2 });
		const skullDec = [
			{ face: 'east', r: [0.62, 0.28, 0.82, 0.50], color: WHITE }, { face: 'east', r: [0.68, 0.30, 0.80, 0.48], color: BLACK },
			{ face: 'west', r: [0.18, 0.28, 0.38, 0.50], color: WHITE }, { face: 'west', r: [0.20, 0.30, 0.32, 0.48], color: BLACK },
		];
		if (P.blaze) skullDec.push({ face: 'north', r: [0.40, 0, 0.60, 1], color: WHITE }, { face: 'up', r: [0.40, 0, 0.60, 0.4], color: WHITE });
		parts.push({ name: 'cranio', bone: 'cabeca', group: 'head', pivot: hp, from: [-2.6, 29, -15], to: [2.6, 34.5, -9], color: c, fur: true, decals: skullDec });
		const muz = [{ face: 'north', r: [0.15, 0.55, 0.38, 0.8], color: BLACK }, { face: 'north', r: [0.62, 0.55, 0.85, 0.8], color: BLACK }, { face: 'down', r: [0, 0, 1, 1], color: dark }];
		if (P.blaze) muz.push({ face: 'north', r: [0.40, 0, 0.60, 0.5], color: WHITE }, { face: 'up', r: [0.38, 0, 0.62, 1], color: WHITE });
		parts.push({ name: 'focinho', bone: 'cabeca', group: 'head', pivot: [0, 30, -14.5], rotation: [-14, 0, 0], from: [-2.05, 27.2, -19.8], to: [2.05, 31.4, -14.2], color: [P.c[0] * 0.85, P.c[1] * 0.85, P.c[2] * 0.85, 1], decals: muz });
		parts.push({ name: 'topete', bone: 'cabeca', group: 'head', pivot: hp, from: [-1, 33.5, -15.4], to: [1, 35.2, -12.5], color: m, fur: true, noise: 0.2 });
		parts.push({ name: 'orelhaE', bone: 'cabeca', group: 'head', pivot: [-1.6, 34.5, -10], rotation: [0, 0, 12], from: [-2.3, 34.2, -10.6], to: [-0.9, 37.4, -9.4], color: c, decals: [{ face: 'north', r: [0.25, 0.2, 0.75, 1], color: dark }] });
		parts.push({ name: 'orelhaD', bone: 'cabeca', group: 'head', pivot: [1.6, 34.5, -10], rotation: [0, 0, -12], from: [0.9, 34.2, -10.6], to: [2.3, 37.4, -9.4], color: c, decals: [{ face: 'north', r: [0.25, 0.2, 0.75, 1], color: dark }] });
		// Cauda: raiz levantada e rabo pendente (tailz2 pende de tailz).
		parts.push({ name: 'raiz', bone: 'cauda', group: 'tailz', bonePivot: [0, 23, 9.5], pivot: [0, 23, 9.5], rotation: [35, 0, 0], from: [-1.1, 20.5, 9], to: [1.1, 23.8, 12], color: m, fur: true });
		parts.push({ name: 'rabo', bone: 'cauda2', group: 'tailz2', parent: 'cauda', bonePivot: [0, 21.5, 11.5], pivot: [0, 21.5, 11.5], from: [-1.7, 9.5, 10.6], to: [1.7, 21.8, 12.8], color: m, fur: true, noise: 0.22 });
		return { name: 'cavalo_' + v, parts };
	}

	window.NC_HORSE = horse;
	return true;
})();
