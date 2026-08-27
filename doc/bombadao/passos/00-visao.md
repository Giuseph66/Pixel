# BOMBADO — visao geral

Um super poder do personagem, exclusivo do **modo sandbox**. O jogador da um
pisao (ground pound), fica achatado (estado `footless`), e nessa janela aperta
uma tecla: o personagem afunda e **renasce saindo de dentro da terra** como uma
versao gigante e musculosa de si mesmo. Enquanto estiver bombado o clima da
sala fica pesado (tela escurece, brasas sobem, o chao treme) e, parado, ele
fica soltando poses de fisiculturista de tempos em tempos.

## O que este poder NAO faz

- Nao existe no modo **historia**.
- Nao existe no modo **infinito**.
- Nao entra no codex (o codex e compartilhado com a historia; uma entrada la
  vazaria o poder para modos que nao o tem).
- Nao mexe em recorde, medalha, ghost ou save — sandbox ja roda com
  `Save.tracking = false`.

## Referencia visual

`doc/bombadao/referencias/ChatGPT Image 27 de ago. de 2026, 12_29_04.png`

A imagem e **referencia**, nao asset. O projeto inteiro gera sprite em runtime
a partir de grades de caracteres em `scripts/pixel_art.gd` (ver o cabecalho do
arquivo: "No PNGs, no importer"). O bombado segue a mesma regra: grades novas
em `PixelArt.GRIDS`, coloridas pelo mesmo caminho de
`Player._player_texture()`, entao a cor de cada jogador no multiplayer
continua valendo.

O que a referencia define:

- Cabeca pequena e redonda — **a cabeca do personagem original, sem mudar um
  pixel**, com os dois olhos brancos e as pupilas.
- Sem pescoco: a cabeca senta direto no trapezio.
- Ombros absurdamente largos (a silhueta e um V invertido).
- Peitoral em dois blocos, abdomen em grade, coxas grossas, panturrilhas.
- Oito poses: parado, dupla de biceps de frente, lateral de peito, lat spread,
  ajoelhado com um braco, dupla de biceps de costas, apontando, bracos
  cruzados.

## Documentos

- [Regras e maquina de estados](./01-estados.md)
- [Arte e poses](./02-arte.md)
- [Clima pesado](./03-clima.md)
- [Passo a passo de implementacao](./04-implementacao.md)
- [Testes](./05-testes.md)
