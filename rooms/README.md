# rooms/

Salas extras que entram na campanha.

Qualquer arquivo `.pixelroom` (ou `.json` no mesmo formato) colocado aqui é
carregado no boot e vai para o **fim** da lista de salas oficiais, em ordem
alfabética de nome de arquivo. Não há nada para editar no código: o
`Sandbox.pack_rooms()` varre esta pasta e o `Levels.all()` concatena o
resultado.

## Como colocar uma sala aqui

1. Crie a sala no modo **SANDBOX** do jogo.
2. Na estante de salas, com ela selecionada, aperte **X**. O jogo escreve
   `<Downloads>/<nome>.pixelroom` e mostra o caminho completo na tela.
3. Copie esse arquivo para esta pasta.
4. Reabra o jogo. A sala aparece no fim de LEVELS.

Há um exemplo pronto em [`docs/exemplo_sala.pixelroom`](../docs/exemplo_sala.pixelroom) —
copie para cá para ver o mecanismo funcionando.

## O que é validado

Uma sala sem ponto de partida (`P`) ou sem porta (`X`) é ignorada com um aviso
no console em vez de quebrar o boot. O `id` do arquivo ganha o prefixo `pack_`
antes de virar chave do save, então uma sala da comunidade nunca pode
sobrescrever o recorde de uma sala escrita à mão em `levels.gd`.

## Formato

```json
{
  "format": "pixel.room",
  "version": 1,
  "room": {
    "id": "example_tour",
    "name": "EXEMPLO",
    "hint": "UMA DICA DE UMA LINHA",
    "par": 30.0,
    "intensity": 1.0,
    "dash": true,
    "pound": true,
    "seed": 4242,
    "author": "SEU NOME",
    "rows": ["############...", "..."]
  }
}
```

`rows` são 32 linhas de exatamente 60 caracteres. A tabela de caracteres está
no topo de [`scripts/levels.gd`](../scripts/levels.gd) e, em forma de paleta com
nome e descrição, em [`scripts/tile_palette.gd`](../scripts/tile_palette.gd).

Um arquivo `pixel.pack` com uma lista `rooms` também funciona: todas as salas
dele entram.
