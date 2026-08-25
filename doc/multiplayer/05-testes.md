# Testes e critérios de entrega

## Estratégia

Testar em camadas:

1. Single player.
2. Duas instâncias na mesma máquina.
3. Duas máquinas na LAN.
4. Duas redes diferentes.
5. Vários jogadores e rede degradada.

Cada falha deve registrar estado da sessão, peer, tick e motivo sem incluir senha
ou token.

## Ferramentas de desenvolvimento previstas

Adicionar argumentos de debug durante a Etapa 1:

```text
--net-role=offline|host|client
--net-address=127.0.0.1
--net-port=27816
--net-capacity=4
--net-name=Player
--net-mode=story|endless|sandbox
```

Após esses argumentos existirem, teste local manual:

Terminal 1:

```bash
godot --path . -- --net-role=host --net-port=27816 --net-capacity=4 --net-name=Host
```

Terminal 2:

```bash
godot --path . -- --net-role=client --net-address=127.0.0.1 --net-port=27816 --net-name=Guest
```

Esses comandos são meta do plano; ainda não funcionam no código atual.

## Regressão single player

Executar após cada etapa:

- Abrir menu e escolher JOGAR.
- Iniciar História.
- Correr, pular, dash, parede e pound.
- Coletar gema.
- Morrer e respawnar.
- Reiniciar sala.
- Concluir e salvar resultado.
- Iniciar Infinito e avançar uma sala.
- Abrir Sandbox e testar sala.
- Confirmar que nenhum socket foi criado em offline.

## Matriz funcional

| Caso | Resultado esperado |
|---|---|
| Host cria sala | Lobby abre e host aparece |
| Cliente entra | Todos recebem participante |
| Código inválido | Erro sem travar UI |
| Senha errada | Entrada rejeitada |
| Sala cheia | Entrada rejeitada antes do loading |
| Versão diferente | Motivo de incompatibilidade |
| Cliente sai no lobby | Slot liberado |
| Cliente sai jogando | Jogador removido; regra recalculada |
| Host sai | Sessão termina de forma limpa |
| Host inicia | Todos carregam mesma sala |
| Cliente demora | Timeout controlado |
| Gema simultânea | Uma única coleta |
| Morte simultânea | Um evento por jogador |
| Porta simultânea | Uma conclusão |
| Retry | Todos reiniciam juntos |
| Próxima sala | Mesmo ID/seed para todos |

## Matriz de jogadores

Testar:

- 2 jogadores.
- 4 jogadores.
- 8 jogadores.
- 16 jogadores.
- Capacidade cheia.
- Tentativa de exceder capacidade.

Medir no host:

- FPS/física.
- Uso de CPU.
- Memória.
- Bytes enviados/recebidos por segundo.
- Fila de pacotes.
- Tempo médio do tick.

Medir no cliente:

- Ping.
- Jitter.
- Correções de posição por segundo.
- Tamanho médio da correção.
- Snapshots descartados.

## Condições de rede

Perfis:

| Perfil | Latência | Jitter | Perda |
|---|---:|---:|---:|
| LAN | 1–10 ms | mínimo | 0% |
| Boa internet | 30–60 ms | 5 ms | 0–1% |
| Média | 100–150 ms | 20 ms | 2% |
| Ruim | 200–300 ms | 50 ms | 5–10% |

Validar:

- Input local continua responsivo.
- Remotos não teleportam continuamente.
- Eventos confiáveis chegam uma vez logicamente.
- Snapshot antigo não sobrescreve novo.
- Timeout não ocorre cedo demais.

## Testes por modo

### História

- Todos entram na porta.
- Um jogador morto respawna sem reiniciar os demais.
- Desconectado não bloqueia saída.
- Resultado grava somente após confirmação.
- Host e cliente podem ter saves diferentes.

### Infinito

- Seed e sala são iguais.
- Retry mantém sala esperada.
- Party wipe encerra run.
- Profundidade não duplica.
- Cliente reconectado recebe estado completo, quando reconexão existir.

### Sandbox

- Sala sem arquivo local carrega no cliente.
- Payload inválido é rejeitado.
- Sala grande demais é rejeitada.
- Resultado não altera campanha.

## Falhas e abuso

- Input com `peer_id` falso.
- Tick muito antigo ou futuro.
- Payload acima do limite.
- Spam de conexão.
- Spam de pronto/início.
- RPC fora do estado correto.
- Nome enorme ou caracteres inválidos.
- Repetição de `event_id`.
- Senha ausente ou prova reutilizada.

Host deve rejeitar sem crash e registrar motivo seguro.

## Observabilidade

Formato sugerido:

```text
[NET][role=host][peer=3][state=PLAYING][tick=18420] event
```

Contadores úteis:

- Peers conectados.
- Inputs recebidos/descartados.
- Snapshots enviados.
- Eventos reenviados.
- RTT por peer.
- Timeouts.
- Erros de autenticação.
- Bytes por canal.

Logs nunca incluem:

- Senha.
- Prova completa.
- Token de sessão.
- SDP completo em build de produção.
- IP em telemetria pública.

## Critérios do primeiro protótipo

- Single player sem regressão conhecida.
- Host e cliente LAN entram no mesmo lobby.
- Dois personagens distintos aparecem.
- Cada máquina controla somente o próprio personagem.
- Movimento tolerável até 100 ms.
- Gema, morte e porta sincronizam.
- Host encerra sessão sem deixar estado preso.

## Critérios do MVP internet

- Entrada por código em redes diferentes.
- Senha opcional.
- P2P direto quando possível.
- Relay quando necessário e disponível.
- História e Infinito completos.
- Sandbox enviado pelo host.
- 8 jogadores aprovados na matriz de desempenho.
- Erros traduzidos e recuperáveis.
- Saves locais protegidos.

