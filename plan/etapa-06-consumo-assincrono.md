# Etapa 6: Consumo Assincrono

Status: implementada inicialmente. Manter este arquivo para revisão final de
concorrencia, `basic.return` e cenarios de cancelamento remoto.

## Entregas

- Definir loop de leitura de frames da conexão para rotear entregas por canal e
  consumer tag sem bloquear a thread principal.
- `basic.consume`.
- `basic.cancel`.
- `basic.ack`, `basic.nack`, `basic.reject`.
- Worker thread.
- Parada limpa.
- Suporte a montagem de mensagem recebida a partir de `basic.deliver`,
  content header e um ou mais content body frames.
- Roteamento de eventos assincronos recebidos pelo broker, incluindo
  `basic.return` para publicacoes com `mandatory=True`.
- Política explícita de callback: executar em worker thread por padrão e usar
  sincronizacao com a main thread apenas quando configurado.
- Tratamento de cancelamento remoto pelo broker (`basic.cancel`) e fechamento
  de canal/conexão durante consumo.

## Definicao de pronto

- Consumo não bloqueia thread principal.
- Ack manual e auto-ack testados.
- Cancelamento não gera deadlock.
- Teste de integração valida recebimento de payload maior que um frame quando
  possivel.
- Documentação técnica explica lifecycle do consumer e responsabilidades de
  ack/nack/reject.
