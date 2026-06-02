# Etapa 6: Consumo Assincrono

Status: implementada inicialmente. Manter este arquivo para revisao final de
concorrencia, `basic.return` e cenarios de cancelamento remoto.

## Entregas

- Definir loop de leitura de frames da conexao para rotear entregas por canal e
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
- Politica explicita de callback: executar em worker thread por padrao e usar
  sincronizacao com a main thread apenas quando configurado.
- Tratamento de cancelamento remoto pelo broker (`basic.cancel`) e fechamento
  de canal/conexao durante consumo.

## Definicao de pronto

- Consumo nao bloqueia thread principal.
- Ack manual e auto-ack testados.
- Cancelamento nao gera deadlock.
- Teste de integracao valida recebimento de payload maior que um frame quando
  possivel.
- Documentacao tecnica explica lifecycle do consumer e responsabilidades de
  ack/nack/reject.
