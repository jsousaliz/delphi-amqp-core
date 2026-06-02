# Exemplos

Esta pasta reúne exemplos práticos de uso do Delphi AMQP Core. Os exemplos usam
RabbitMQ local por padrão e foram separados por objetivo didático.

## ConsoleQuickStart

[`ConsoleQuickStart`](ConsoleQuickStart/README.md) é o exemplo console mínimo.
Ele deixa o fluxo completo em sequência no `begin/end`, sem rotinas auxiliares,
para mostrar o uso direto das interfaces principais.

## ConsoleStepByStep

[`ConsoleStepByStep`](ConsoleStepByStep/README.md) é o exemplo console didático
por etapas. Ele separa conexão, abertura de canal, declaração de fila,
publicação, consumo, purge, delete e desconexão em rotinas nomeadas.

## VclQueueManager

[`VclQueueManager`](VclQueueManager/README.md) é o exemplo visual VCL. Ele
demonstra configuração de conexão, criação/purge/delete de fila, publicação,
consumo assíncrono e logs filtráveis por `Level` e `Kind`.
