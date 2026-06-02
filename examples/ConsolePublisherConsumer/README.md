# ConsolePublisherConsumer

Exemplo console didático de uso da API pública do Delphi AMQP Core.

Ele demonstra a forma esperada de:

- Criar opções de conexão.
- Injetar logger.
- Conectar.
- Criar canal.
- Declarar fila.
- Publicar mensagem.
- Consumir de forma assíncrona.
- Confirmar mensagem com ack.
- Limpar e excluir fila.

## Estado atual

Neste momento o exemplo valida conexão TCP, handshake AMQP 0-9-1, abertura de
canal, criação de fila, publicação, consumo assíncrono, ack manual, purge e
delete com RabbitMQ.

## Broker local planejado

```powershell
docker run --rm -it -p 5672:5672 -p 15672:15672 rabbitmq:3-management
```
