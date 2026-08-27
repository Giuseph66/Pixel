# BOMBADO — testes

## Automatico

`tools/check_sandbox.gd::_check_buff()`, rodando junto com o resto:

```
godot --headless res://tools/check_sandbox.tscn
```

O que ele cobre:

1. **Arte** — as 13 grades existem, todas 26x30, e todo caractere usado esta
   em `Palette.CHARS`. Uma letra errada vira pixel transparente silencioso sem
   isso.
2. **Gate** — `buff_unlocked = false` + `footless` + F: nao transforma. E o
   teste que garante que historia e infinito continuam limpos.
3. **Janela** — `buff_unlocked = true` mas **sem** `footless`: nao transforma.
4. **Entrada** — liberado, achatado, no chao, com espaco: entra em `BUFF_RISE`
   e depois em `BUFF_ON`, e a caixa de colisao passa a medir 14x24.
5. **Espaco** — com o teto colado, a transformacao e negada e o jogador
   continua do tamanho normal.
6. **Saida** — `_leave_buff(true)` devolve a caixa para 6x10.
7. **Poses** — o sorteio nunca devolve a mesma pose duas vezes seguidas.

## Manual

1. Menu > JOGAR > SANDBOX, abrir ou criar uma sala, TESTAR.
2. Achar um ponto com pelo menos 2 tiles de largura e 3 de altura livres — ele
   e grande, e sem esse espaco a transformacao e recusada de proposito.
3. Pular, segurar BAIXO no ar, pousar o pisao (o boneco fica achatado).
4. Apertar **F** dentro dos 2 segundos.
5. Conferir: terra saltando, corpo subindo de dentro do chao, tela
   escurecendo, brasas subindo, chao tremendo de leve.
6. Ficar parado meio segundo: as poses comecam a sair sozinhas.
7. Andar: mais lento e mais pesado; pular: mais baixo; pisao: crater maior.
8. Apertar **F** de novo: afunda e volta ao normal.
9. Morrer com espinho: volta ao normal na hora, sem aura sobrando na tela.
10. Voltar ao menu, entrar em HISTORIA e em INFINITO, repetir os passos 3 e 4:
    **nada** pode acontecer.
