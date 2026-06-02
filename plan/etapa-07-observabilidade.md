# Etapa 7: Observabilidade

Status: implementada.

## Entregas

- [x] Revisar os eventos já existentes e padronizar campos de `ConnectionId`,
  `ChannelId`, erro e operação.
- [x] Eventos estruturados principais para handshake, publish, queue
  operations, consume, ack/nack/reject, heartbeat e fechamento.
- [x] Logger nulo default.
- [x] Exemplo com logger simples.
- [x] Test logger em memória para testes unitários.
- [x] Incluir campo `DurationMS` no evento para medição futura de operações
  bloqueantes.

## Definicao de pronto

- [x] Fluxos principais emitem eventos.
- [x] Testes validam eventos sem depender de arquivo externo.
- [x] Documentação mostra como integrar `IAMQPLogger` com logger próprio do
  usuário.

## Observacoes

- A biblioteca continua sem depender de framework externo de log.
- `TAMQPConnectionFactory.Create` aceita `IAMQPLogger` opcional.
- Quando nenhum logger e informado, `TAMQPLogger.Null` e usado como default.
- `TAMQPInMemoryLogger` existe para testes e validacoes locais.
