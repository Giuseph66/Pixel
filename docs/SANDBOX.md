# PIXEL — Modo Sandbox

Terceiro modo, ao lado de HISTÓRIA e INFINITO: um editor de salas dentro do
jogo, com estante de salas salvas, exportação em arquivo, código de
compartilhamento e um caminho de mão única para transformar uma sala criada em
sala oficial da campanha.

Escrito em 2026-08-25.

---

## 1. A ideia que faz tudo caber

Uma sala da campanha é isto e nada mais:

```gdscript
{"id": ..., "name": ..., "hint": ..., "par": 30.0, "rows": PackedStringArray}
```

`rows` são 32 linhas de 60 caracteres. `Level.setup()` recebe esse dicionário e
constrói a sala inteira — terreno, colisão, entidades, jogador. **Ele não tem
como saber de onde o dicionário veio.**

Então o modo sandbox não precisou de nenhum código novo de gameplay. Ele é um
gerador de `rows` com uma tela na frente. Tudo que o jogo já sabe fazer — gelo,
esteira, espinho retrátil, maré, plataforma circular — funciona numa sala criada
no primeiro dia, sem uma linha a mais.

---

## 2. Arquivos novos

| Arquivo | O que faz |
| --- | --- |
| `scripts/tile_palette.gd` | O alfabeto de tiles do ponto de vista do editor: nome, grupo, ícone, quais são únicos. Adicionar uma mecânica = uma entrada aqui. |
| `scripts/sandbox.gd` | Modelo da sala, store em `user://sandbox.json`, validação, JSON de exportação, código de compartilhamento, varredura de `res://rooms/`. |
| `scripts/room_preview.gd` | Desenha uma sala em miniatura, um bloco colorido por tile. |
| `scripts/text_field.gd` | Uma linha de texto digitável. O jogo não tem nenhum nó `Control`, então isso é uma máquina de estados alimentada por eventos de tecla. |
| `scripts/editor_screen.gd` | O editor. |
| `scripts/sandbox_screen.gd` | A estante de salas: criar, editar, jogar, copiar, apagar, exportar, importar. |
| `tools/check_sandbox.gd` / `.tscn` | Teste de fumaça headless do modo inteiro. |
| `rooms/` | Pasta das salas extras que entram na campanha. |

## 3. Arquivos alterados

| Arquivo | Alteração |
| --- | --- |
| `scripts/main.gd` | Fluxo do sandbox: estante → editor → teste → resultado, e de volta. |
| `scripts/play_select_screen.gd` | Três painéis em vez de dois. |
| `scripts/pause_menu.gd` | Numa sala custom, o menu oferece EDITAR e MINHAS SALAS. |
| `scripts/save_manager.gd` | `Save.tracking`, desligado enquanto uma sala custom roda. |
| `scripts/level.gd` | `art_seed`: a semente do céu e das lâminas retráteis passa a ser um campo da sala em vez do índice dela. Na campanha o valor é o mesmo de antes. |
| `scripts/levels.gd` | `all()` concatena `Sandbox.pack_rooms()`. |
| `scripts/i18n.gd` | ~120 chaves novas nos três idiomas. |

---

## 4. O editor

A sala é desenhada 1:1 sob a mesma faixa de 14 px que o HUD usa em jogo. O que
está na tela do editor é exatamente a tela que sai no play — sem zoom, sem
scroll, sem minimapa, porque uma sala é uma tela por definição.

### Teclas

| Tecla | O que faz |
| --- | --- |
| Setas | Move o cursor (com repetição ao segurar) |
| Espaço | Pinta o tile atual |
| Mouse | Esquerdo pinta, direito apaga, meio copia o tile, roda troca o pincel |
| `TAB` / `C` | Abre a paleta |
| `X` | Apaga |
| `Q` | Copia o tile sob o cursor para o pincel |
| `R` | Alterna pincel / retângulo (dois cliques marcam os cantos) |
| `F` | Preenche a área contígua |
| `CTRL+Z` / `CTRL+Y` | Desfazer / refazer (60 passos) |
| `O` | Painel da sala: nome, autor, tempo alvo, velocidade, dash, queda, semente |
| `P` | Testar a sala agora |
| `CTRL+S` | Salvar |
| `H` | Ajuda |
| `ESC` | Sair (salvar, descartar ou ficar) |

### A bandeja de tiles

Cinco gavetas — CHÃO, PERIGO, VIVOS, COLETÁVEIS, MARCADORES — com os nomes
alinhados à direita contra a coluna de células, para a bandeja ler como uma
coluna de tiles com uma espinha de nomes ao lado.

Cada célula tem 20 px e desenha o tile **em dobro**, pintado pelas mesmas
rotinas que a sala assa (`paint_tile`, `paint_ice`, `paint_platform`) em vez de
um retângulo colorido. O que está na bandeja é o que sai na sala.

Três plataformas móveis (`m`, `n`, `r`) usam o mesmo sprite de laje e só diferem
no caminho que percorrem, então o caminho é o que o marcador desenha: seta dupla
horizontal, seta dupla vertical, anel. As esteiras ganham seta simples na
direção em que empurram. Na sala, esse marcador aparece só na **cabeça da fila**
— carimbar nos seis tiles de uma laje enterraria a laje.

O rodapé mostra nome, **caractere do tile entre colchetes** e a nota de uma
linha. O caractere vale a pena estar ali: é o que acaba no arquivo salvo e em
toda tabela da documentação.

### Como o terreno é desenhado

O editor assa o terreno numa `Image` do mesmo jeito que `level.gd` assa, mas de
forma incremental: uma edição repinta o tile e os quatro vizinhos, porque o
chanfro de um tile depende de quem encosta nele e de mais nada. Assar a grade
inteira a cada pincelada custaria ~20 ms por tile pintado; assim custa cinco
células.

Tudo que não é terreno é desenhado como sprite por cima, todo frame — são
algumas dezenas de sprites, não custa nada.

### O que é configurável e o que é derivado

O painel `O` tem sete campos: **nome**, **autor**, **tempo alvo**,
**velocidade** (`intensity`, 0.5×–2.5×, acelera toda entidade da sala),
**dash** e **queda esmagadora** (ligar/desligar por sala — é assim que se faz
uma sala que é só sobre pulo de parede) e **semente do céu**.

O resto é derivado da grade, de propósito:

- um mob anda no chão que existe embaixo dele e vira na borda;
- uma plataforma móvel mede o ar livre ao lado (ou acima) e usa isso como
  trilho;
- um espinho retrátil cresce até o ar livre acima dele, limitado a 3 tiles;
- uma esteira ou plataforma é **uma fila de tiles iguais** = um objeto só, do
  tamanho da fila.

Ou seja: **a grade é a configuração**. Não existe um segundo lugar onde uma
sala guarda "esse slime anda de x=10 até x=20" que possa discordar do desenho.

### Validação

Duas coisas quebram a sala de verdade e são erro: nenhum ponto de partida
(o jogador nasce na origem) e nenhuma porta (a sala nunca acaba). Mais de um
`P`, mais de um `X` ou mais de uma maré também são apontados, e a porta na
primeira linha não tem onde desenhar a metade de cima.

Crueldade não é erro. Uma sala impossível de terminar por dificuldade continua
válida.

---

## 5. De onde uma sala nova vem

O card **NOVA SALA** abre um seletor de origem em vez de já cair no editor:

| Origem | O que faz |
| --- | --- |
| Sala vazia | Caixa selada, um chão, um ponto de partida e uma porta |
| Copiar da história | Lista as salas da campanha e copia a escolhida |
| Copiar uma minha | Mesma lista, com as salas do sandbox |

Copiar não é atalho, é como a maioria das salas de fato nasce: pega uma que já
funciona, arranca o miolo, e as partes que nunca foram o ponto — borda selada,
chão, ponto de partida que não está dentro de uma parede — já estão certas.

O seletor de cópia é **lista de nomes à esquerda, preview grande à direita**
(4 px por tile, 240×128). Grade de cards não segura 47 salas da campanha sem
virar oito páginas de rolagem, e nome de sala de campanha é evocativo de
propósito — "GANÂNCIA" não diz nada sobre o que você está copiando. Setas
andam de sala, esquerda/direita pula uma página, espaço copia.

A cópia de uma sala da campanha resolve o nome pela tabela de tradução (a
campanha guarda `level.the_climb.name`, não texto), descarta a dica (ela
pertence à lição da sala original, não à cópia) e **mantém a semente do céu** —
uma sala de campanha não tem semente própria, o `Level` usa o índice dela, então
é o índice que vai junto. A cópia abre parecida com o original em vez de igual
nas paredes e diferente no céu.

Nada disso é escrito no `user://sandbox.json` até o editor salvar. Sair de uma
cópia que você não quis não deixa casca na estante.

## 6. A estante

Cards com preview real, três por linha, o primeiro sempre "NOVA SALA".

| Tecla | O que faz |
| --- | --- |
| Espaço | Joga a sala |
| `E` | Edita |
| `C` | Duplica |
| `R` / `DEL` | Apaga (com confirmação) |
| `X` | Exporta essa sala |
| `SHIFT+X` | Exporta todas num pacote |
| `I` | Importa |
| `ESC` | Volta |

Limite de 64 salas por usuário, em `user://sandbox.json`.

---

## 7. Compartilhamento

Exportar faz as duas coisas de uma vez, porque são os dois jeitos que as pessoas
realmente passam uma sala adiante:

**Arquivo.** Vai para a **pasta Downloads da máquina** — `~/Downloads` no
Linux, o equivalente em cada sistema — porque é onde um arquivo que alguém te
mandou já está, e a única pasta que uma pessoa acha sem precisar de instrução.
Onde o sistema não tem pasta de downloads (build web), cai em `user://export/`.

JSON legível e indentado, com `rows` como uma linha de texto por linha da sala.
O caminho absoluto aparece na tela, quebrado em várias linhas se for longo. Dá
para mandar por e-mail, commitar no repositório ou colar aqui no chat.

**Código.** O mesmo JSON, deflatado e em base64, atrás do prefixo `PIXEL1.`,
copiado direto para a área de transferência. Serve para colar numa conversa. O
prefixo é parte do payload de propósito: um código copiado pela metade falha
alto em vez de decodificar em lixo.

Importar (`I`) aceita os dois: "colar da área de transferência" ou qualquer
arquivo encontrado em Downloads, `user://rooms/`, `user://` e `user://export/`.
Cada entrada é marcada com a pasta em que está (`DOWNLOADS/SALA.PIXELROOM`),
porque a mesma sala costuma existir em duas delas ao mesmo tempo.

Só `user://rooms/` aceita `.json` solto; nas outras a varredura exige
`.pixelroom`. Downloads é pasta de todo mundo — chave de service account,
calendário exportado, whiteboard — e varrer `.json` ali enchia a lista de
importação com dezesseis arquivos que não eram salas e um que era.

Cada sala importada ganha um `id` novo, então importar o mesmo arquivo duas
vezes dá duas salas em vez de sobrescrever a primeira.

### Para o jogo do seu amigo

Ele põe o arquivo em `user://rooms/` (ou copia o código) e importa pelo `I`. A
sala vira uma sala dele, jogável e editável.

### Para o mapa oficial

Ele — ou você — copia o arquivo para a pasta `rooms/` do projeto. No próximo
boot, `Levels.all()` já devolve a sala no fim da campanha, sem alterar uma linha
de código. Detalhes em [`rooms/README.md`](../rooms/README.md).

### Para mandar para mim

Cole o conteúdo do `.pixelroom`, ou o código `PIXEL1.…`, aqui no chat. É JSON,
eu leio direto e transformo numa `_level_nn()` pintada à mão em `levels.gd` se
a sala merecer virar parte da campanha escrita.

---

## 8. Por que o save é blindado

`save_manager.gd` guarda os recordes por **índice na campanha** traduzido para
o `id` da sala naquele índice. Uma sala do sandbox roda com índice 0. Sem
proteção, o primeiro gem pego numa sala custom seria arquivado como recorde de
FIRST STEPS.

Daí `Save.tracking`, desligado por `main._build_room()` enquanto `_sandbox` está
ligado. Ele barra `record_clear`, `record_endless`, `add_gem`, `add_death`,
`take_secret` e `discover`. O último é escolha de design tanto quanto de
segurança: varrer a grade de uma sala que você mesmo escreveu abriria o códex
inteiro de graça.

---

## 9. Teste

```
godot --headless res://tools/check_sandbox.tscn
```

Carrega todos os scripts, checa o formato da sala em branco, o validador, o
round trip de JSON e de código, a coerência entre a paleta e `Codex.BY_TILE`,
a unicidade dos ids da campanha, e então **constrói o editor e a estante de
verdade e roda alguns frames em cada modo** — o renderizador headless joga o
desenho fora, mas todo `_draw()` executa, que é a única forma de pegar um índice
ruim em código que só roda quando alguém está olhando. Por último monta um
`Level` a partir de uma sala do sandbox e confirma que nada dela chegou ao save.

---

## 10. O que ficou de fora

- **Colar código pela interface do jogo.** Depende de `DisplayServer.clipboard_get()`,
  que não existe em todo lugar; no navegador o import por arquivo é o caminho.
- **Salas maiores que uma tela.** O jogo inteiro é construído em cima de "uma
  sala é uma tela". Rolagem seria outro jogo.
- **Ajuste fino por entidade** (esse slime é mais rápido que aquele). A grade é
  a configuração; velocidade é por sala.
- **Navegação da paleta por controle no modo de pintura.** As setas movem o
  cursor; a paleta abre no `TAB` e aí sim anda no direcional.
