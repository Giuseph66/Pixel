# UI e regras dos modos

## Fluxo principal

```text
TÍTULO
  +-- JOGAR ----------------> fluxo single player atual
  +-- MULTIPLAYER
        +-- CRIAR SALA -----> configuração -> lobby
        +-- ENTRAR ---------> código/senha -> lobby
        +-- LAN ------------> IP/porta, ferramenta de teste
```

JOGAR não muda de significado. Multiplayer é caminho separado.

## Criar sala

Campos:

- Nome do jogador.
- Nome da sala.
- Capacidade.
- Senha opcional.
- Privada ou pública.
- Permitir entrada após início.
- Modo inicial.

Controles:

- Cima/baixo seleciona campo.
- Esquerda/direita altera valor.
- Confirmar cria.
- Cancelar volta.

Validação antes de criar:

- Nome não vazio e dentro do limite.
- Capacidade dentro do teto técnico.
- Senha dentro do limite.
- Serviço de sinalização acessível, salvo modo LAN.

## Entrar na sala

Campos:

- Código.
- Senha, se solicitada.
- Nome do jogador.

UX:

- Código normalizado para maiúsculas.
- Hífen opcional durante digitação.
- Colar código quando plataforma permitir.
- Não revelar se senha está correta até handshake.
- Timeout mostra ação para tentar novamente.

## Lobby

Exibe:

- Código da sala.
- Nome da sala.
- Modo selecionado.
- Capacidade atual/máxima.
- Jogadores, ping e estado pronto.
- Indicação clara do host.

Host pode:

- Alterar modo.
- Alterar fase/seed/opções.
- Alterar capacidade sem expulsar quem já entrou.
- Expulsar jogador.
- Fechar/reabrir novas conexões.
- Iniciar.
- Encerrar sala.

Cliente pode:

- Alternar pronto.
- Alterar cor/nome permitido.
- Sair.

## Estados e mensagens

Mensagens necessárias no `i18n.gd`:

```text
Criando sala
Conectando
Autenticando
Negociando conexão
Carregando sala
Esperando jogadores
Sala cheia
Senha incorreta
Código inválido
Versão incompatível
Conteúdo incompatível
Host desconectou
Conexão perdida
Tempo esgotado
Relay indisponível
```

Nunca deixar tela parada sem etapa atual ou timeout.

## Identificação dos jogadores

- Cor/contorno escolhido de uma paleta.
- Nome curto acima do personagem.
- Marcador para jogador local.
- Estado sem dash continua visível.
- Jogadores fora da tela futura recebem indicador de direção.
- Efeitos não podem esconder hazards.

## Regras comuns

- Sem colisão entre jogadores.
- Cada jogador controla somente seu personagem.
- Mundo e coleta são compartilhados por padrão.
- Host valida regras.
- Participante desconectado deixa de bloquear porta.
- Late join desativado no primeiro MVP durante gameplay.

## História cooperativa

Configuração recomendada:

- Host escolhe uma sala liberada no save dele.
- Todos começam no mesmo spawn com pequeno deslocamento visual.
- Gemas são globais.
- Inimigos escolhem alvos entre jogadores vivos.
- Morte causa respawn individual.
- Todos os jogadores ativos entram na porta para concluir.
- Pode existir contagem regressiva quando primeiro jogador entra.
- Resultado confirmado é enviado a todos.
- Cada máquina registra sua própria conclusão.

Questão para playtest: exigir todos na porta pode gerar troll/grief. Alternativa:
primeiro jogador ativa contagem de 10 segundos; depois todos são puxados.

## Infinito cooperativo

- Seed e profundidade pertencem ao host.
- Todos recebem a mesma sala gerada.
- Gemas e tempo são compartilhados.
- Mortes são contadas por jogador e pelo grupo.
- Run termina em party wipe.
- Entre salas, jogadores mortos retornam.
- Host escolhe continuar ou encerrar; votação pode entrar depois.

Questão para playtest: respawn imediato pode remover pressão. Alternativa: morto
vira espectador até outro jogador concluir a sala.

## Sandbox

- Host escolhe sala local.
- Definição da sala é enviada no loading.
- Clientes validam tile count, caracteres e tamanho.
- Sala recebida existe somente na sessão.
- Resultado não altera campanha.
- Editor colaborativo não faz parte do MVP.

## Competitivo futuro

Possíveis presets:

- Corrida: primeiro na porta vence.
- Pontos: gemas, inimigos e tempo.
- Sobrevivência: último vivo.
- Ghost race: jogadores não afetam o mesmo mundo.

Para suportar isso sem refatorar rede, `SessionConfig` já inclui `mode_id` e as
regras ficam em classes de modo, não dentro do transporte ou do `Player`.

## Capacidade

Host escolhe capacidade na UI. Regras:

- Não pode reduzir abaixo da quantidade conectada.
- Aumentar atualiza registro da sala.
- Sala cheia rejeita antes de carregar gameplay.
- Teto publicado depende dos testes de desempenho.
- UI não promete "ilimitado".

## Sala maior no futuro

UI atual continua válida. Gameplay muda para:

- Câmera local seguindo o próprio jogador.
- Indicadores de grupo.
- Possível minimapa.
- Relevância de rede por região.
- Spawn/checkpoint independente.

Por isso, mensagens usam coordenadas do mundo desde o início.

