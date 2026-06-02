# Etapa 7: Observabilidade

Status: implementada.

## Entregas

- Revisar os eventos já existentes e padronizar campos de `ConnectionId`,
  `ChannelId`, erro e operação.
- Eventos estruturados principais para handshake, publish, queue
  operations, consume, ack/nack/reject, heartbeat e fechamento.
- Logger nulo default.
- Exemplo com logger simples.
- Test logger em memória para testes unitários.
- Incluir campo `DurationMS` no evento para medição futura de operações
  bloqueantes.

## Definicao de pronto

- Fluxos principais emitem eventos.
- Testes validam eventos sem depender de arquivo externo.
- Documentação mostra como integrar `IAMQPLogger` com logger próprio do
  usuário.

## Observacoes

- A biblioteca continua sem depender de framework externo de log.
- `TAMQPConnectionFactory.Create` aceita `IAMQPLogger` opcional.
- Quando nenhum logger e informado, `TAMQPLogger.Null` e usado como default.
- `TAMQPInMemoryLogger` existe para testes e validacoes locais.
