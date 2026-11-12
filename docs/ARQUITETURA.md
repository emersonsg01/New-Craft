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
- **Formas finas:**
  - `SH_PANE` (7): lâmina centralizada;
  - `SH_PANE_EDGE` (8): lâmina encostada num lado (rotação 0 = −Z, 1 = +X, 2 = +Z, 3 = −X);
  - bit `SH_CENTER` (64) nos modelos: porta centralizada, com caixas pré-calculadas por `Blocks._center_models` e lidas por `Blocks.model(id, forma)`.
  - As lâminas são os blocos `PANE_0 … PANE_0 + 10` (`Blocks.PANE`, `Blocks.PANE_SRC`), e `Player.thin_placement` escolhe o lado ou o centro pelo ponto clicado.
- **Blocos com variante:** `DOORV`/`DOORV_OPEN` (portas), `WINDOWV` (janela), `PANEV` (vidraça), `DRAWBRIDGE`/`DRAWBRIDGE_DOWN` (ponte levadiça).
  - Bits 8–15 da forma: a variante (`Blocks.DOOR_VARS`, `Blocks.WIN_VARS`). As camadas de textura ficam em `Blocks.VAR_LAYERS`.
  - Bit `SH_MIRROR` (128): a folha da direita de portas duplas e portões.
  - Bits 16–20 na ponte: a parte da estrutura (coluna e altura).
  - No inventário, cada variante é um item (`kind` `door`, `window`, `drawbridge`). `Items.for_variant` faz o caminho inverso, do bloco para o item.
  - Abrir uma porta afeta todas as células ligadas (`Player.door_cells`). A ponte gira numa animação (`Player.toggle_drawbridge`) e depois os blocos são trocados.
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
   - Os templates podem incluir micro-células `[x, y, z, Blocks.MICRO, SH_MICRO, grade]`. A grade é girada com `Micro.rotate_y` e vai para `res["micro_s"]`.
   - Blocos luminosos carimbados entram em `res["lights"]`. `World._drain` cria uma `OmniLight3D` para cada um, com cor por tipo e `distance_fade`.
   - A rotação das formas preserva os bits de centralização, espelho e variante. Por isso as portas e janelas das vilas mantêm a madeira da paleta (`door_v`, `win_v`).
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
- Articulações: uma parte pode ter `parent_i` e pender de outra. `Rigs._split_limbs` divide braços e pernas em segmentos (grupos `armA`/`armA2`, `legA`/`legA2`). `VoxelRig` monta a hierarquia e anima joelhos, cotovelos, o balanço do corpo, a inclinação, o olhar (`look_yaw`) e a pose montada (`pose = "ride"`).
- Raças com pelagem desenhada por variante: `Rigs._breed` e `Rigs._monster`. As selas são desenhadas por `Rigs._add_saddle` sobre o ponto `back` que o `quad()` devolve.
- `voxel_rig.gd`: animações procedurais (bípede, quadrúpede com pastar e rabo, ave, aranha, salto, flutuar).

## Jogador (`player.gd`) e atributos (`stats.gd`)

- Física AABB própria, com subida automática de degraus, nado, escalada na borda da água e voo no criativo.
- Mira por raycast voxel. A mineração tem tempo por dureza, ferramenta e Força, mostra rachaduras e faz a árvore inteira cair (`falling_tree.gd`).
- Recursos: vida, fome, estamina (correr, pular, golpear), mana (feitiços G e H) e fôlego (afogamento).
- `Stats`: nível, XP, pontos e 7 atributos (força, inteligência, percepção, velocidade, fôlego, estamina, mana). Os valores derivados são calculados em métodos como `melee_mult()`, `max_breath()` e `mana_regen()`.

## Criaturas (`mobs.gd`)

- `DEFS` define vida, velocidade, comportamento (hostil, neutro, assustadiço, voador, saltador), dano, saque e se a criatura queima ao sol.
- IA simples: vagar, fugir, perseguir, atacar e atirar. Os aldeões ficam presos à vila e fazem trocas (`TRADES`).
- Aldeões: a vila (`structures.gd`) anexa a cada morador um dicionário extra (`center` da praça, `home` = posto de trabalho, `face` = ponto que ele encara, `plot` = lote do construtor) e a paleta; `pending_npcs` leva `[pos, espécie, semente, vila, extra, paleta]`. Moradores cujo chunk ainda não carregou (mineradores na câmara da mina) esperam na fila.
- `Mob._npc_job` decide antes do passeio: conversa (pares frente a frente com balão `Label3D`, um fala por vez), ronda do guarda (`_patrol`, 8 pontos num círculo de raio 21 em volta da praça), obra do construtor (`_build`: primeiro `world.village_damage`, gravado em `player._break_block` para blocos de construção quebrados, depois `Structures.plan_blocks` da casa no lote, de baixo para cima) e o ciclo trabalhar/folgar. `_steer` desvia de obstáculos; o construtor que não progride por ~9 s reaparece perto da obra.
- Vozes (`voices.gd`): sintetizador estático — fonte vocal (serra/pulso/seno com vibrato, tremor, jitter, aspereza e sopro) por 3 formantes em filtro de estado variável, ruído filtrado, sino FM, sequência, mistura e eco. `_design(especie)` monta os sons por evento (`idle`, `hurt`, `death`, `attack`, `talk`, `night`); cada espécie é gerada numa tarefa do `WorkerThreadPool` na primeira vez que aparece (`get_sound` devolve null até ficar pronto). `Mob.voice()` toca num `AudioStreamPlayer3D` próprio; `Mobs.VOICE` define intervalo dos sons a toa e volume por espécie.
- `NPC_HANDS` diz o que cada profissão segura; `VoxelRig.hold` prende o item no antebraço com o mesmo encaixe do personagem do jogador. O minerador leva também uma luz. `TRADES` tem várias ofertas por profissão; `trade_id` converte nomes em itens ou blocos (`TRADE_BLOCKS`).
- `Arrow` cobre flechas, projéteis de criaturas e o feitiço arcano (sem gravidade e com luz). Abates do jogador dão XP, e a Percepção aumenta o saque.

## Modelos do Blockbench

- As criaturas (animais e monstros, todas as variantes) ficam em `assets/blockbench/<especie>_<variante>.bbmodel`, no formato "Modelo padrão" do Blockbench. Os grupos são os ossos, com a articulação no `origin`. O nome antes de `__` define o grupo de animação (`legA`, `legA2`, `head`, `tailz`...).
- `scripts/bbmodel.gd` lê o `.bbmodel` direto, inclusive arquivos salvos pelo Blockbench 4.x e 5.x, e monta os nós e as malhas com a textura embutida. O shader é `voxel_tex.gdshader`, com filtro nítido, recorte de transparência e clarão de dano. `Rigs.mob` usa o `.bbmodel` quando ele existe; a sela continua sendo desenhada por cima.
- `assets/blockbench/creatures.json` guarda, para cada modelo, a animação, a escala, a pose e o ponto da sela.
- `tools/bb_export_specs.gd` gera os `.bbmodel` a partir dos desenhos de `Rigs`, com 8 px por voxel e atlas de até 1024 px. Sem `--force`, preserva os arquivos que já existem, para não apagar edições feitas no Blockbench.
  - `godot --headless --path . --script res://tools/bb_export_specs.gd -- --force`
- **Redesenho no Blockbench:** `tools/bb_designer.js` é uma biblioteca que roda dentro do Blockbench, pelo MCP (`risky_eval`) ou pelo console. Ela monta um modelo a partir de peças (cubos girados em ossos), pinta a textura em alta resolução (8 px por unidade, atlas até 1024) e salva o `.bbmodel`. Os designs de cada espécie ficam em `tools/bb_designs/<especie>.js`; prontos: `cavalo.js` (7 pelagens) e `animais.js` (vaca, porco, ovelha, cabra, cervo, burro, camelo, lobo, raposa, urso, coelho, galinha e pato, com todas as raças).
  - Os modelos redesenhados não devem ser regenerados com `bb_export_specs.gd -- --force`, que os substituiria pelos desenhos antigos. As versões geradas anteriores do cavalo ficam em `assets/blockbench/_gerado/`.
- Para editar: abra o `.bbmodel` no Blockbench, mude cubos, ossos ou textura e salve. O jogo usa a versão nova na próxima vez que carregar.

## Montaria e materiais mistos

- `Mobs.DEFS[*]["ride"/"seat"/"jump"]` marcam as montarias. `Mob.set_saddle(item)` redesenha o animal com a sela. Com `Mob.rider` definido, `Mob._ride` lê o teclado e move o animal, e o `Player` fica em `vehicle` com a altura `seat_h`.
- `Items.MIXED`, `Items.ARMOR_MATS2` e `Items.SADDLES` são adicionados no fim de `Items._static_init`, para não mudar os ids dos itens antigos.
- As variantes de portas e janelas também são geradas em `Items`, na mesma ordem de `Blocks.DOOR_VARS`/`WIN_VARS`, para não depender da ordem de inicialização das classes.

## Desempenho

- `hardware.gd` detecta a GPU, a VRAM (pelo registro do Windows), os núcleos e a RAM, e define um nível de hardware.
- `world.gd` mede a RAM e a VRAM marginais por chunk e limita o raio ao orçamento. A varredura incremental agenda até 3000 deslocamentos por quadro, e acima de 20 chunks a malha é "leve" (sem plantas nem planos internos das folhas).
- `settings.gd` aplica o perfil automático e a resolução dinâmica para o FPS-alvo, e define as threads de trabalho.

## Testes

Os testes são scripts `SceneTree` executados com `godot --path . --script teste.gd`. Eles carregam `scenes/main.tscn`, montam a cena por código, imprimem medições e salvam capturas com `root.get_texture().get_image().save_png(...)`.

Como os scripts de teste não enxergam o autoload `GameSettings` em tempo de compilação, use acesso dinâmico (`root.get_node("GameSettings")`, `m.world.load_save()`) em vez de referências tipadas a classes que dependem dele.
