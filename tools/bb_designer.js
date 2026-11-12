// Biblioteca de design do New Craft para o Blockbench (rodar via MCP risky_eval ou console).
// Monta um modelo a partir de uma lista de pecas (cubos girados em ossos), pinta a textura em alta
// resolucao direto no Blockbench e salva o .bbmodel que o jogo carrega.
// Convencao: frente da criatura em -Z (norte), 16 unidades = 1 bloco, ossos nomeados "<grupo>__<n>".
(function () {
	const fs = require('fs');
	const PPV = 8; // pixels por unidade

	function hash(a, b, c) {
		let h = (a * 374761393 + b * 668265263 + c * 2147483647) | 0;
		h = (h ^ (h >>> 13)) * 1274126177;
		return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
	}

	function rgb(c) {
		return [c[0] * 255, c[1] * 255, c[2] * 255];
	}

	// Dimensoes (em unidades) de cada face: [largura, altura] vistas de fora.
	function faceDims(s) {
		return { north: [s[0], s[1]], south: [s[0], s[1]], east: [s[2], s[1]], west: [s[2], s[1]], up: [s[0], s[2]], down: [s[0], s[2]] };
	}

	// Pinta uma face: cor base com ruido fino (pelagem/material), luz de cima, oclusao nas arestas,
	// listras opcionais (pelo) e decalques [x0, y0, x1, y1, cor] em coordenadas 0..1 da face.
	function paintFace(ctx, x, y, w, h, face, part, seed) {
		const base = part.color;
		for (let py = 0; py < h; py++) {
			for (let px = 0; px < w; px++) {
				const u = (px + 0.5) / w;
				const v = (py + 0.5) / h;
				let col = base;
				for (const d of (part.decals || [])) {
					if ((d.face === face || d.face === '*' || (d.face === 'side' && face !== 'up' && face !== 'down')) && u >= d.r[0] && u < d.r[2] && v >= d.r[1] && v < d.r[3]) col = d.color;
				}
				if (col[3] === 0) continue;
				const n = (hash(px + seed, py, seed * 7) - 0.5) * (part.noise ?? 0.10);
				const streak = part.fur ? (hash(px + seed * 3, Math.floor(py / 3), seed) - 0.5) * 0.08 : 0;
				let shade = 1.0;
				if (face !== 'up' && face !== 'down') shade *= 1.05 - v * 0.12;
				if (face === 'down') shade *= 0.82;
				if (face === 'up') shade *= 1.06;
				const ex = Math.min(px, w - 1 - px) / Math.max(1, PPV * 0.6);
				const ey = Math.min(py, h - 1 - py) / Math.max(1, PPV * 0.6);
				shade *= 0.9 + 0.1 * Math.min(1, Math.min(ex, ey));
				const f = shade + n + streak;
				const c = rgb(col);
				ctx.fillStyle = `rgba(${Math.max(0, Math.min(255, c[0] * f)) | 0},${Math.max(0, Math.min(255, c[1] * f)) | 0},${Math.max(0, Math.min(255, c[2] * f)) | 0},${col[3] ?? 1})`;
				ctx.fillRect(x + px, y + py, 1, 1);
			}
		}
	}

	// design: { name, parts: [{ name, group, parent, pivot, from, to, rotation, color, decals, noise, fur, inflate }] }
	// group = nome do osso (animacao); parent = nome do osso pai. Pecas do mesmo osso ficam juntas.
	function build(design, outPath) {
		newProject(Formats.free);
		Project.name = design.name;
		Project.box_uv = false;
		// 1) Retangulos de textura de todas as faces.
		const rects = [];
		design.parts.forEach((p, i) => {
			const s = [p.to[0] - p.from[0], p.to[1] - p.from[1], p.to[2] - p.from[2]];
			const fd = faceDims(s);
			for (const f in fd) rects.push({ i, f, w: Math.max(1, Math.ceil(fd[f][0] * PPV)), h: Math.max(1, Math.ceil(fd[f][1] * PPV)) });
		});
		rects.sort((a, b) => b.h - a.h);
		let area = 0;
		rects.forEach(r => area += r.w * r.h);
		let tw = 64;
		while (tw * tw < area * 1.35 && tw < 1024) tw *= 2;
		let x = 0, y = 0, shelf = 0;
		rects.forEach(r => {
			if (x + r.w > tw) { x = 0; y += shelf; shelf = 0; }
			r.x = x; r.y = y; x += r.w; shelf = Math.max(shelf, r.h);
		});
		let th = 16;
		while (th < y + shelf) th *= 2;
		// 2) Pinta o atlas.
		const canvas = document.createElement('canvas');
		canvas.width = tw; canvas.height = th;
		const ctx = canvas.getContext('2d');
		rects.forEach(r => paintFace(ctx, r.x, r.y, r.w, r.h, r.f, design.parts[r.i], r.i * 31 + 7));
		const tex = new Texture({ name: design.name + '.png' }).fromDataURL(canvas.toDataURL()).add(false);
		tex.uv_width = tw; tex.uv_height = th;
		Project.texture_width = tw; Project.texture_height = th;
		// 3) Ossos e cubos.
		const bones = {};
		let n = 0;
		// bone = chave unica do osso; group = grupo de animacao (varias pernas dividem "legA").
		const boneOf = (key, anim, pivot, rotation, parent) => {
			if (bones[key]) return bones[key];
			const g = new Group({ name: anim + '__' + (n++), origin: pivot, rotation: rotation || [0, 0, 0] });
			if (parent && bones[parent]) g.addTo(bones[parent]); else g.addTo();
			g.init();
			bones[key] = g;
			return g;
		};
		design.parts.forEach((p, i) => {
			const anim = p.group || 'corpo';
			const g = boneOf(p.bone || anim, anim, p.bonePivot || p.pivot || p.from, p.boneRotation, p.parent);
			const faces = {};
			rects.filter(r => r.i === i).forEach(r => faces[r.f] = { uv: [r.x, r.y, r.x + r.w, r.y + r.h], texture: tex.uuid });
			new Cube({ name: p.name || 'cubo', from: p.from, to: p.to, origin: p.pivot || p.from, rotation: p.rotation || [0, 0, 0], inflate: p.inflate || 0, faces }).addTo(g).init();
		});
		Canvas.updateAll();
		if (outPath) fs.writeFileSync(outPath, Codecs.project.compile());
		return { name: design.name, cubes: design.parts.length, texture: [tw, th] };
	}

	window.NC_DESIGN = { build, PPV };
	return true;
})();
