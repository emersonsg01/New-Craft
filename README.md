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

### Multijogador

- **Hospedar:** Esc → Opções → Multijogador → "Hospedar este mundo" (porta padrão 7777). Os outros jogadores entram pelo seu IP.
- **Entrar:** na mesma aba, informe IP e porta e clique em "Entrar no servidor". O jogo salva o mundo local e recarrega conectado; a semente e as edições vêm do servidor, e o mundo local não é sobrescrito.
- **Servidor dedicado** (sem tela): `Servidor.bat [porta] [semente]`, ou
  `godot --headless --path . --script res://scripts/dedicated_server.gd -- --port=7777 --seed=123 --save=user://servidor.save`.
  O mundo do servidor é salvo a cada minuto. O primeiro jogador conectado simula criaturas, líquidos e plantações; se ele sair, outro assume.
- **Sincronizado:** blocos, formas e micro-blocos; posição, aparência e animação dos jogadores (com nome em cima); criaturas e aldeões (golpes vão para quem simula, e as criaturas atacam qualquer jogador); hora do dia.
- **Limitações:** baús, fornalhas e itens soltos no chão são locais de cada jogador; montar animais funciona só para quem simula as criaturas. Para jogar pela internet, libere a porta no roteador/firewall.

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
| B | Escala de construção: bloco, 1/2, 1/4, 1/8 |
| T | Chat e comandos: `/modo-criativo` liga o modo criativo, `/modo_survive` volta à sobrevivência |
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
  - Cada vila usa portas e janelas da sua madeira: carvalho na planície, bétula na floresta, vidro e cerejeira no cerejal, palmeira com cobre no deserto, pinheiro com ferro na neve e mogno com ferro nos bandidos.
  - As casas têm vigas no alto das paredes, tapete de micro-voxels, lanternas em postes dos dois lados da porta e porta dupla na casa grande. O templo tem porta dupla, tochas e tapete.
  - **Construções da vila:** centro comercial (pavilhão coberto com bancas e toldos), torre da guarnição (pedra, ameias, estandarte), ferraria (fornalhas, bigorna, chaminé e cocho), fazendas cercadas com espantalho, curral com abrigo, feno, cocho e animais, cabana de caça (peles no varal, galhada), cabana do lenhador (pilha de toras coberta), mina (entrada coberta, rampa de escada com escoras e lanternas, veios de minério e câmara com baú), cabana do construtor (pilhas de material e andaime), lote reservado para casa nova, casa do artesão (camas, mesas, cadeiras, estante, cortinas), casa do alfaiate (manequim e rolos de tecido), casa do tecelão (tear, fardos de lã, tanques de curtume e varal de couro), casas e templo.
  - **Profissões dos aldeões:** fazendeiro, minerador, caçador, criador, guarda, ferreiro, armeiro, ferramenteiro, lenhador, comerciante, construtor, artesão, alfaiate e tecelão. Cada um mora na sua construção, tem roupa própria e leva as ferramentas nas mãos (picareta e lanterna do minerador, espada e escudo do guarda, machado do lenhador, tesoura do alfaiate...).
  - **Trabalho e convivência:** de dia os aldeões alternam entre trabalhar no seu posto (encarando a bancada, a parede da mina etc. e golpeando com a ferramenta) e passear; nas folgas puxam conversa com um vizinho, ficam frente a frente, gesticulam e trocam falas em balões. Os guardas fazem ronda pelo perímetro da vila, param para vigiar e atacam monstros.
  - **Construtor:** conserta blocos das construções da vila quebrados pelo jogador e ergue, bloco a bloco, uma casa nova no lote da vila.
  - **Trocas:** clique direito mostra uma oferta (cada profissão tem várias; clique de novo para ver a próxima) e Shift + clique direito fecha a oferta mostrada. O tecelão faz tecido com lã e curte couro; o alfaiate vende roupas e acessórios; o artesão vende camas, cadeiras, mesas, cortinas e estantes; o construtor vende tábuas, tijolos e pedra lapidada.
  - **Iluminação real:** lanternas, tochas, abajures, fogueiras e fornalhas das construções acendem luzes de verdade dentro e fora, cada tipo com uma cor. Luzes distantes somem aos poucos para economizar GPU.
  - **Postes de iluminação:** em volta da praça do poço e a cada 7 blocos ao longo dos caminhos, que agora têm 2 a 3 blocos de largura. Os acampamentos de bandidos têm postes com tochas em volta da fogueira.
- **Líquidos com física:** água e lava escorrem por níveis, e lava em contato com água vira pedra.
- **Estações iguais em todo o mapa:** todos os biomas passam por primavera, verão, outono e inverno ao mesmo tempo. Fora do inverno a neve dos biomas gelados derrete e aparece a grama; no inverno neva em todos os biomas (inclusive deserto e praia). Chove nas outras estações e neva no inverno ou no alto das montanhas.
- **Luz na mão e mão esquerda:** tocha, lanterna ou fogueira na mão iluminam em volta. **X** troca o item da mão com a mão esquerda (escudo, tocha, lanterna, ferramentas); o escudo na mão esquerda reduz o dano vindo da frente. O **capacete de minerador** (4 lingotes de ferro + lanterna) tem uma lanterna que projeta um facho à frente.
- **Tecidos e roupas:** tecido (2 lã), couro curtido (couro + carvão), chapéu de palha, capuz, gorro, bandana, túnica, avental, manto e colete (vestir muda a aparência do personagem), escudos de madeira e de ferro.
- **Empunhadura:** personagem e NPCs seguram ferramentas e armas pelo cabo, com a lâmina para a frente; o arco em pé pelo meio; o escudo preso no antebraço, de frente, com o braço dobrado à frente do corpo; a lanterna pendurada na mão; a tocha em pé. O braço que segura algo fica um pouco à frente e balança menos ao andar.
- **Camas:** ocupam 2 blocos (cabeceira e pés), com pés de madeira, estrado, colchão e travesseiro brancos e cobertor de lã com a dobra do lençol. Ao colocar, os pés ficam no bloco clicado e a cabeceira para longe do jogador; quebrar qualquer metade tira a cama inteira.
- **Vozes das criaturas:** todos os animais, monstros e aldeões têm voz própria, sintetizada (sem arquivos de áudio) e posicionada em 3D: mugido da vaca, grunhidos e guinchos do porco, balido trêmulo da ovelha e berro da cabra, cacarejo da galinha, grasnado do pato, assobio do cervo, gritinhos da raposa, uivo do lobo com eco de vale (mais frequente à noite), rosnado e rugido do urso, relincho com bufada do cavalo, "hi-hó" do burro, gorgolejo do camelo, gemido do andarilho, respiração arenosa da múmia, ossos chacoalhando do esqueleto, chiado da aranha, bolhas da gosma, lamento em coro do espectro, ronco de pedra do golem, chiado e estalos da salamandra, rugido de fogo da chama, sinos de cristal do vigia, risadinha do goblin, urro do ogro e gargalhada do bandido. Cada indivíduo tem um tom de voz um pouco diferente; há sons a toa, de ferimento, de morte e de ataque. Os aldeões (vozes masculinas e femininas) "falam" numa língua inventada quando conversam entre si.
- **Céu noturno:** algumas noites sorteadas têm aurora boreal (cortinas verdes e violetas que ondulam) e outras uma chuva de estrelas cadentes. A noite é sorteada pela semente do mundo, então todos os jogadores do mesmo mundo veem o mesmo céu. Nuvens e chuva escondem os dois eventos.
- **Clima e estações:** chuva, tempestade e neve, com vento global que move plantas, folhas e água, e estações no estilo Vintage Story (cor das folhas, neve, crescimento).

### Blocos e construção
- Cerca de 200 blocos com texturas procedurais (relevo por parallax, normal, rugosidade e emissão), além de vidros, vitrais, janelas, portas, móveis e plantações.
- **Formas 3D:** laje, escada, cunha, pilar, meia parede e painel.
- **Portas:** para cada madeira (carvalho, pinheiro, bétula, mogno, palmeira, cerejeira) há porta lisa, com cintas de ferro, com cintas de cobre e de vidro com moldura de madeira, além das portas de vidro com ferro e com cobre. Cada uma existe em três tamanhos: simples (1×2), dupla (2×2) e portão grande (2×4). As duas folhas abrem juntas, para lados opostos.
  - Receitas na bancada: porta = 6 tábuas (rende 3); com metal = 4 tábuas + 2 lingotes; de vidro = 4 tábuas (ou 4 lingotes) + 2 vidros; dupla = 2 portas; portão grande = 2 portas duplas.
- **Janelas e vidraças:** janela de cada madeira com moldura simples, com grade de ferro ou com grade de cobre (2 tábuas + 2 vidros, mais 1 lingote nas de metal). 6 janelas rendem 36 vidraças finas.
- **Ponte levadiça:** 4 de largura × 8 de altura. É colocada de pé e abaixa na direção de quem a colocou. Clique direito abaixa ou levanta, com animação na dobradiça. Receita: 3 troncos + 3 lingotes de ferro + 3 correntes. Corrente: 2 lingotes de ferro rendem 2.
- **Lâminas de vidraça:** 6 blocos de vidro, vidro colorido, vitral ou janela (duas fileiras de 3 na bancada) rendem 36 lâminas finas (2/16 de bloco).
- **Posição das lâminas e portas:** a posição depende do ponto clicado. No meio da face, a peça fica centralizada. Perto de uma borda, encosta naquele lado. Numa parede, fora do centro e das bordas laterais, encosta no bloco clicado. As portas são finas (3/16) e seguem a mesma regra, inclusive centralizadas.
- **Micro-blocos:** qualquer bloco cúbico ou de vidro pode ser esculpido ou construído em pedaços de 1/2, 1/4 e 1/8 (grade 8×8×8 por bloco, com material por voxel). As sobras acumulam até formar um bloco inteiro.
- **Detalhes naturais em micro-voxels:** pedrinhas, galhos caídos, raízes na base das árvores e peitoris nas janelas das vilas.

### Sobrevivência
- Vida, fome, armadura, dano de queda, afogamento e lava.
- Mineração com tempo por ferramenta e material, rachaduras no bloco e queda da árvore inteira ao cortar o tronco.
- Inventário com grade de criação 2×2 / 3×3, cerca de 165 receitas, livro de receitas, fornalha e baús.
- Agricultura: arado, sementes, estágios de crescimento e farinha de osso.
- Animais: balde vazio na vaca tira leite (bebível, devolve o balde; a vaca leva 2 min para dar leite de novo); galinhas botam ovos a cada 1,5–3 min; tesoura (2 lingotes de ferro) tosquia ovelhas, que soltam 1 a 3 lãs da sua cor e ficam sem lã por 5 min.
- Derrubar uma árvore solta as toras, parte das folhagens, gravetos, mudas e frutos (maçã, laranja, cereja), agrupados em pilhas.
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

### Montaria
- Cavalos (7 pelagens: castanho, preto, branco, tordilho, malhado, palomino, baio), burros e camelos (dromédario e bactriano) podem ser montados.
- Clique direito com uma sela na mão sela o animal. Clique direito de novo monta. Shift com a mão vazia tira a sela.
- Montado: WASD cavalga, Ctrl galopa, Espaço pula, Shift desce. A velocidade varia por espécie e por indivíduo.
- 6 selas: de couro; de couro com ferro; de couro com cobre; cerimonial de ouro (+15% de velocidade); de viagem (com alforjes); de guerra de aço (com peitoral e manta lateral). Cada uma tem cores e acessórios próprios.

### Materiais mistos e armas novas
- Materiais: aço (2 ferro + 1 carvão), bronze (3 cobre + 1 ferro), obsidiana, osso, ferro dourado (ferro + ouro) e cristal rubi (cristal + rubi). Cada um faz todas as ferramentas e armas, com cabo e guarda próprios.
- Armas novas, em todos os materiais: martelo de guerra, alabarda (alcance longo), sabre e foice de guerra. Também a besta (dano alto, recarga lenta).
- Armaduras mistas: cota de malha (de correntes), aço, bronze, couro tachado, obsidiana e cristal rubi, cada uma com acabamento próprio no personagem.

### Criaturas
- Animais com raças: vaca, porco, ovelha, galinha, coelho, cervo, lobo, cavalo, burro, camelo, cabra (4 raças), raposa (vermelha, ártica, prateada), urso (pardo, negro, polar) e pato (3 raças).
- Monstros: andarilho, esqueleto, aranha, gosma, espectro e golem, que queimam ao sol; múmias no deserto (comum e real); goblins (3 tipos) e ogros (3 tipos).
- Movimento natural:
  - membros com dois segmentos (joelhos e cotovelos);
  - corpo que sobe e desce e se inclina ao correr;
  - giro com inércia e passeio até pontos de destino, com pausas;
  - rebanhos que andam juntos;
  - desvio de penhascos e água;
  - cabeça que acompanha o jogador;
  - rabo em dois segmentos e animação de pastar.
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

## Executáveis (.exe)

Os perfis de exportação ficam em `export_presets.cfg` (precisa dos modelos de exportação da Godot 4.7.2 instalados). Para gerar de novo:

```
godot --headless --path . --export-release "Jogo (Windows)" build/NewCraft.exe
godot --headless --path . --export-release "Servidor dedicado (Windows)" build/NewCraftServer.exe
```

Na pasta `build/`:

- `NewCraft.exe` — o jogo (arquivo único, com tudo embutido). `Jogar.bat` abre o jogo desligando camadas Vulkan de outros programas (ReShade, overlays) que podem travar a abertura.
- `NewCraftServer.exe` + `NewCraftServer.console.exe` — servidor dedicado, sem janela gráfica: abre direto na cena `scenes/server.tscn`. Use o `.console.exe` (ou `Servidor.bat [porta] [semente]`) para ver o registro e fechar com Ctrl+C. Opções: `--port=7777 --seed=123 --save=user://servidor.save`.
- Os dois arquivos do servidor precisam ficar juntos na mesma pasta.

### Instaladores

Os scripts do Inno Setup 6 ficam em `installer/` (`jogo.iss` e `servidor.iss`). Depois de exportar os .exe:

```
ISCC installer\jogo.iss
ISCC installer\servidor.iss
```

Saem em `build/Instalador do Jogo/NewCraft-Setup.exe` e `build/Instalador do Servidor/NewCraftServer-Setup.exe`. Os instaladores são em português, instalam sem pedir administrador (ou para todos, se escolhido), criam atalhos no menu Iniciar (e na área de trabalho, se marcado) e têm desinstalador. Os mundos salvos não são apagados ao desinstalar.
