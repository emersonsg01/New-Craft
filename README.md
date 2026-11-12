# New Craft

Jogo de mundo aberto procedural em voxels, feito em **Godot 4.7 (Forward+, GDScript)**. Ele é inspirado no gênero sandbox de blocos, mas tem design próprio: texturas realistas geradas na GPU, terreno distante até 32 km, movimento reativo ao vento e à chuva, estações do ano, dimensões, vilas, criaturas, progressão de personagem e construção em micro-blocos (1, 1/2, 1/4 e 1/8 de bloco).

Não há arquivos de arte externos. Texturas, modelos, itens, criaturas e sons são gerados por código.

---

## Como executar

1. Instale a **Godot 4.7.x** (versão padrão ou mono).
2. Abra a pasta do projeto no editor e pressione **F5**, ou use o `Jogar.bat` no Windows.
   - O `Jogar.bat` aponta para o executável da Godot numa pasta fixa. Ajuste a variável `GODOT` para o caminho da sua instalação.
   - Ele também define `VK_LOADER_LAYERS_DISABLE=~implicit~`, que desliga camadas Vulkan injetadas por outros programas (ReShade, overlays do GOG/OBS). Essas camadas podem travar a Godot antes de a janela abrir.
3. O mundo é salvo em `user://world_v4.save` ao sair. Para recomeçar, apague esse arquivo.

Requisitos: GPU com Vulkan. A geração de terreno e de texturas roda em compute shaders.

---

## Controles

| Tecla | Ação |
|---|---|
| WASD | Mover |
| Espaço | Pular / nadar para cima (duplo toque voa no criativo) |
| Shift | Correr (gasta estamina) / descer do barco |
| Ctrl | Descer (voando ou nadando) |
| Clique esquerdo (segurar) | Minerar, esculpir, atacar |
| Clique direito | Usar item, interagir, construir |
| Roda / 1–9 | Trocar o item da hotbar |
| E | Inventário e criação |
| K | Painel de nível e atributos |
| T | Escala de construção: bloco, 1/2, 1/4, 1/8 |
| R | Forma 3D do bloco (laje, escada, cunha, pilar, meia parede, painel) |
| G | Feitiço arcano (12 de mana) |
| H | Cura (30 de mana) |
| Q / Ctrl+Q | Soltar um item / a pilha inteira |
| V ou F5 | Câmera: 1ª pessoa, 3ª pessoa por trás, 3ª pessoa de frente |
| P | Personalizar o personagem |
| L | Lanterna |
| C | Trocar o clima |
| F | Voar (criativo) |
| F2 | Captura de tela |
| F3 | Informações de depuração |
| Esc | Opções |

---

## Recursos

### Mundo
- **Geração na GPU:** relevo, biomas, cavernas, minérios e vegetação rodam em compute shaders numa thread própria, e o acabamento (árvores, estruturas) usa vários núcleos da CPU.
- **Distância:** até 256 chunks de voxels completos e terreno distante (LOD em quadtree) até 32 km, com transição pontilhada.
- **Biomas:** planícies, floresta, neve, deserto e praia, com carvalho, bétula, mogno, cerejeira, pinheiro, palmeira, macieira e laranjeira.
- **Dimensões:** as Profundezas Ígneas e as Ilhas Etéreas, com portais próprios.
- **Estruturas:** vilas pacíficas por bioma, acampamentos de bandidos, ruínas e pirâmides com baús de saque.
- **Líquidos com física:** água e lava escorrem por níveis, e lava em contato com água vira pedra.
- **Clima e estações:** chuva, tempestade e neve, com vento global que move plantas, folhas e água, e estações no estilo Vintage Story (cor das folhas, neve, crescimento).

### Blocos e construção
- Cerca de 200 blocos com texturas procedurais (relevo por parallax, normal, rugosidade e emissão), além de vidros, vitrais, janelas, portas, móveis e plantações.
- **Formas 3D:** laje, escada, cunha, pilar, meia parede e painel.
- **Micro-blocos:** qualquer bloco cúbico ou de vidro pode ser esculpido ou construído em pedaços de 1/2, 1/4 e 1/8 (grade 8×8×8 por bloco, com material por voxel). As sobras acumulam até formar um bloco inteiro.
- **Detalhes naturais em micro-voxels:** pedrinhas, galhos caídos, raízes na base das árvores e peitoris nas janelas das vilas.

### Sobrevivência
- Vida, fome, armadura, dano de queda, afogamento e lava.
- Mineração com tempo por ferramenta e material, rachaduras no bloco e queda da árvore inteira ao cortar o tronco.
- Inventário com grade de criação 2×2 / 3×3, cerca de 165 receitas, livro de receitas, fornalha e baús.
- Agricultura: arado, sementes, estágios de crescimento e farinha de osso.
- Barcos, balde de água e de lava, arco e flechas, isqueiro para portais.

### Personagem e progressão
- Personagem masculino ou feminino com pele, cabelo, penteado, barba, roupa e chapéu personalizáveis.
- Armaduras de couro, cobre, ferro, ouro e cristal, cada uma com acabamento próprio.
- **Nível e XP** (caçar, minerar, cortar árvores, colher), com 3 pontos por nível.
- **Atributos:**
  - Força: dano e mineração;
  - Inteligência: feitiços, XP e mana;
  - Percepção: crítico, dano à distância e saque;
  - Velocidade: movimento e ataque;
  - Fôlego: ar embaixo d'água;
  - Estamina: corrida e pulo;
  - Mana: reserva de mana.
- Barras de estamina, mana e fôlego no HUD, e dois feitiços (projétil arcano e cura).

### Criaturas
- Animais (vaca, porco, ovelha, galinha, coelho, cervo, lobo) com variantes de cor e animação de pastar.
- Monstros (andarilho, esqueleto, aranha, gosma, espectro, golem) que queimam e morrem ao sol.
- Criaturas das dimensões e aldeões/bandidos com profissões, roupas, cabelos e barbas variados. Os aldeões fazem trocas.

### Gráficos e desempenho
- Upscaling: FSR 1 e FSR 2. DLSS e XeSS aparecem automaticamente se a build da Godot expuser esses modos; a build oficial não traz, e nesse caso o jogo usa FSR 2.
- Iluminação global e reflexos (SDFGI, SSR, SSIL, SSAO), névoa volumétrica, sombras e perfis de qualidade (baixo, médio, alto, ultra).
- Detecção de hardware (GPU, VRAM, CPU, RAM) com perfil automático, orçamento de memória por chunk, resolução dinâmica para manter o FPS-alvo e número de threads configurável.

---

## Estrutura do projeto

```
project.godot        Configuração, autoload GameSettings e parâmetros globais de shader
Jogar.bat            Lançador para Windows
scenes/main.tscn     Cena principal
scripts/             Toda a lógica do jogo (GDScript)
shaders/             Terreno, folhagem, água, vidro, lava, céu e voxels
docs/ARQUITETURA.md  Visão técnica detalhada
```

Veja [docs/ARQUITETURA.md](docs/ARQUITETURA.md) para o funcionamento interno: geração, malha, micro-blocos, salvamento e os principais scripts.

---

## Licença

Projeto pessoal. Todos os recursos visuais são gerados proceduralmente pelo próprio código.
