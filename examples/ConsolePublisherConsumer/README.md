# ConsolePublisherConsumer

Exemplo console didatico de uso da API publica do DelphiAMQP.

Ele demonstra a forma esperada de:

- Criar opcoes de conexao.
- Injetar logger.
- Conectar.
- Criar canal.
- Declarar fila.
- Publicar mensagem.
- Consumir de forma assincrona.
- Confirmar mensagem com ack.
- Limpar e excluir fila.

## Estado atual

Neste momento o exemplo valida conexao TCP, handshake AMQP 0-9-1, abertura de
canal, criacao de fila, publicacao, consumo assincrono, ack manual, purge e
delete com RabbitMQ.

## Broker local planejado

```powershell
docker run --rm -it -p 5672:5672 -p 15672:15672 rabbitmq:3-management
```
