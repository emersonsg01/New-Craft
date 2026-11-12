# Arquitetura do New Craft

Visão técnica de como o jogo funciona por dentro. Todos os caminhos são relativos à raiz do projeto.

## Visão geral

```
main.gd ──► World (chunks, edição, física, salvamento)
   │          ├── GpuWorldGen  (thread) ──► compute shaders (wg_shaders.gd)
   │          │                  └── WorldGen.finish (WorkerThreadPool): árvores, estruturas, micro-detalhes
   │          └── ChunkMesher  (WorkerThreadPool) ──► ArrayMesh por chunk (5 superfícies)
   ├── FarTerrain  (LOD em quadtree até 32 km, altura calculada no vertex shader)
   ├── Weather     (dia/noite, clima, estações, dimensões, parâmetros globais de shader)
   ├── Player      (física AABB, mineração, construção, micro-blocos, sobrevivência, atributos)
   ├── Mobs        (criaturas, NPCs, barcos, flechas/feitiços, itens no chão)
   ├── Hud         (hotbar, barras, inventário, criação, baús, fornalha, painel de atributos)
   └── Menus       (opções gráficas, desempenho, upscaling, ray tracing, jogo, personagem)
GameSettings (autoload, settings.gd): opções, perfil automático por hardware, resolução dinâmica
```

## Dados do mundo

- **Chunk:** 16 × 128 × 16 blocos em `PackedByteArray`, com índice `y * 256 + z * 16 + x`.
- **Formas** (`Chunk.shapes`): dicionário `idx -> int`. Os bits 0–3 são o tipo (`SH_*`) e os bits 4–5 a rotação.
- **Micro-células** (`Chunk.micro`): dicionário `idx -> PackedByteArray(512)`. O bloco recebe o id `Blocks.MICRO` e a forma `SH_MICRO` (15). Cada byte da grade 8×8×8 é o id do material daquele voxel (0 = vazio). Veja `scripts/micro.gd`.
- **Edições:**
  - `World.all_mods[dim][chunk][idx] = id | forma << 8`;
  - `World.all_micro[dim][chunk][idx] = grade`.
  - As edições são reaplicadas quando o chunk é gerado de novo.
- **Outros estados por dimensão** (chaves `Vector4i(x, y, z, dim)`): baús (`containers`), saque ainda não aberto (`loot_pos`), blocos que crescem (`ticks`) e fornalhas (`furnaces`).
- **Salvamento:** `user://world_v4.save`, via `FileAccess.store_var`. Guarda a semente, as edições, as micro-células, os contêineres, o jogador (posição, inventário, armadura, fome e atributos) e a hora e o dia.

## Geração

1. **GPU** (`gpu_world_gen.gd`, `wg_shaders.gd`): um `RenderingDevice` local, numa thread própria, roda o compute shader do chunk. Ele calcula relevo, biomas, cavernas, rochas, minérios, flores e água. A dimensão é escolhida por push constant (superfície, ígnea ou etérea).
2. **CPU** (`world_gen.gd: finish`): tarefas no `WorkerThreadPool` adicionam árvores por espécie e bioma, arbustos e abóboras, e micro-detalhes (pedrinhas, galhos, raízes). Em seguida aplicam as estruturas (`structures.gd: stamp`), os peitoris e as edições salvas.
3. **Estruturas** (`structures.gd`): grade de células de 256 blocos. Cada célula pode ter uma vila, um acampamento, uma ruína ou uma pirâmide, com paletas por bioma (planície, floresta, cerejeira, deserto, neve, bandidos, ruína). Os templates são rotacionados e carimbados nos chunks que tocam.
4. **Terreno distante** (`far_terrain.gd`): tiles em quadtree (raiz de 8192 e mínimo de 128). A altura é recalculada no vertex shader com o mesmo ruído da GPU, e a transição para os voxels usa pontilhado em `lod_near`.

## Malha (`chunk_mesher.gd`)

- Um array acolchoado de 18 × 130 × 18 traz a borda dos 8 vizinhos. O bit `0x100` marca blocos com forma, que não ocluem os vizinhos.
- A luz do céu é calculada por coluna e cai ao atravessar folhas e rocha.
- Cor do vértice: `r` = oclusão de ambiente, `g` = camada da textura, `b` = luz do céu, `a` = emissão ou peso do vento.
- Superfícies: opaca (0), folhagem (1), água (2), vidro (3) e lava (4).
- Tipos de bloco tratados:
  - cubos com AO por vértice;
  - folhas com planos internos;
  - plantas em cruz;
  - líquidos com altura por nível;
  - vidro;
  - modelos (móveis);
  - formas;
  - micro-células, geradas por `Micro.mesh_cell`, com fusão gulosa por fatia e oclusão contra blocos e micro-células vizinhas.
- O UV dos opacos é projetado pela posição no mundo. Por isso a textura continua sem emenda entre blocos e entre micro-voxels.

## Micro-blocos (`micro.gd`)

| Função | Uso |
|---|---|
| `filled`, `empty`, `count`, `uniform`, `dominant` | Criar e inspecionar grades |
| `fill_cube(g, x, y, z, s, id, removed)` | Preencher ou esvaziar um cubo de lado `s` (8, 4, 2 ou 1) |
| `boxes(g)` | Caixas de colisão agrupadas de forma gulosa (cache em `Chunk.micro_boxes`) |
| `raycast(g, origem_local, dir)` | DDA dentro da célula; devolve a distância, o voxel e a normal |
| `mesh_cell(...)` | Faces visíveis com fusão de retângulos do mesmo material |
| `can_micro(id)` | Cubos e vidros (exceto portais e rocha-mãe) |

No mundo, `World.set_micro(p, grade)` normaliza a célula: vazia vira ar e cheia de um único material vira bloco normal. `get_boxes` e `raycast` tratam `SH_MICRO`.

No jogador, `micro_scale` (tecla T) escolhe a escala. `micro_target(outside)` calcula a célula e o voxel alinhado à escala. `_carve` esculpe e `_place_micro` constrói. `micro_credit` guarda as sobras em voxels (512 = 1 bloco).

## Texturas (`texture_gen.gd`, `tex_shader.gd`)

- Cada camada é um `LayerDef` com cores c0, c1 e c2, parâmetros e padrão, e roda num compute shader com 37 padrões. Entre eles:
  - terra, pedra, tijolos e madeira;
  - folhas (normais, agulhas, flores, frutas);
  - capim, flores (radial, tulipa, lavanda, girassol) e roseira;
  - portas, vitrais e janelas.
- Passo 1 pinta o albedo e a altura. Passo 2 calcula a normal e o ORM (oclusão, rugosidade, metal, emissão).
- O resultado são três `Texture2DArray` (albedo, normal+altura, ORM) compartilhados pelos materiais.

## Shaders

| Arquivo | Uso |
|---|---|
| `terrain.gdshader` | Opacos: parallax occlusion, normal, umidade da chuva com poças, neve sazonal, emissão |
| `foliage.gdshader` | Folhas e plantas: vento, outono e galhos nus, neve, translucidez |
| `water.gdshader` | Ondas, reflexo, profundidade |
| `glass.gdshader` | Vidros, vitrais e portais (redemoinho quando é emissivo) |
| `lava.gdshader` | Lava animada e emissiva |
| `sky.gdshader` | Céu, sol, lua, estrelas, nuvens |
| `voxel.gdshader` | Criaturas, itens e personagem (flash de dano) |

Parâmetros globais (`project.godot`): `wind_*`, `rain_*`, `parallax_depth`, `player_pos`, `lod_near`, `season`, `snow_cover`.

## Arte por código

- `voxel_art.gd`: um `Canvas` 16×16 desenha os itens em pixel-art, extrudados para 3D, e `part_mesh` monta as caixas com detalhes por face `[face, x, y, w, h, cor]`. Faces: 0 = +X, 1 = −X, 2 = topo, 3 = base, 4 = +Z (trás), 5 = −Z (frente). As linhas contam de cima para baixo.
- `rigs.gd`: cada personagem e criatura é um conjunto de partes.
  - Humanoide com penteados, barbas, roupas, chapéus e armaduras por material.
  - Quadrúpede genérico com olhos (esclera, pupila, pálpebra), cascos e extras presos à cabeça.
  - Aves, aranha, gosma, espectro e barco.
- `voxel_rig.gd`: animações procedurais (bípede, quadrúpede com pastar e rabo, ave, aranha, salto, flutuar).

## Jogador (`player.gd`) e atributos (`stats.gd`)

- Física AABB própria, com subida automática de degraus, nado, escalada na borda da água e voo no criativo.
- Mira por raycast voxel. A mineração tem tempo por dureza, ferramenta e Força, mostra rachaduras e faz a árvore inteira cair (`falling_tree.gd`).
- Recursos: vida, fome, estamina (correr, pular, golpear), mana (feitiços G e H) e fôlego (afogamento).
- `Stats`: nível, XP, pontos e 7 atributos (força, inteligência, percepção, velocidade, fôlego, estamina, mana). Os valores derivados são calculados em métodos como `melee_mult()`, `max_breath()` e `mana_regen()`.

## Criaturas (`mobs.gd`)

- `DEFS` define vida, velocidade, comportamento (hostil, neutro, assustadiço, voador, saltador), dano, saque e se a criatura queima ao sol.
- IA simples: vagar, fugir, perseguir, atacar e atirar. Os aldeões ficam presos à vila e fazem trocas (`TRADES`).
- `Arrow` cobre flechas, projéteis de criaturas e o feitiço arcano (sem gravidade e com luz). Abates do jogador dão XP, e a Percepção aumenta o saque.

## Desempenho

- `hardware.gd` detecta a GPU, a VRAM (pelo registro do Windows), os núcleos e a RAM, e define um nível de hardware.
- `world.gd` mede a RAM e a VRAM marginais por chunk e limita o raio ao orçamento. A varredura incremental agenda até 3000 deslocamentos por quadro, e acima de 20 chunks a malha é "leve" (sem plantas nem planos internos das folhas).
- `settings.gd` aplica o perfil automático e a resolução dinâmica para o FPS-alvo, e define as threads de trabalho.

## Testes

Os testes são scripts `SceneTree` executados com `godot --path . --script teste.gd`. Eles carregam `scenes/main.tscn`, montam a cena por código, imprimem medições e salvam capturas com `root.get_texture().get_image().save_png(...)`.

Como os scripts de teste não enxergam o autoload `GameSettings` em tempo de compilação, use acesso dinâmico (`root.get_node("GameSettings")`, `m.world.load_save()`) em vez de referências tipadas a classes que dependem dele.
