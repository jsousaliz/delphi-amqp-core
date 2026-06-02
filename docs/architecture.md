# Arquitetura

Delphi AMQP Core será organizado em camadas pequenas e testáveis.

## Índice

- [Camadas](#camadas)
- [Handshake implementado](#handshake-implementado)
- [Documentação técnica detalhada](#documentação-técnica-detalhada)
- [Memória](#memória)
- [Threading](#threading)
- [Compatibilidade inicial](#compatibilidade-inicial)

## Camadas

- API pública: interfaces e tipos estáveis usados pelo consumidor da biblioteca.
- Implementação: classes concretas para conexão, canal, mensagens e consumers.
- Protocolo: codec AMQP 0-9-1, frames e métodos binários.
- Transporte: socket TCP baseado em WinSock/RTL, com timeouts de envio/recebimento.
- Observabilidade: logger por interface, com implementação nula por padrão.

## Handshake implementado

`IAMQPConnection.Connect` executa a sequência inicial:

- Abre socket TCP.
- Envia protocol header AMQP 0-9-1.
- Responde `connection.start` com `connection.start-ok` usando autenticação PLAIN.
- Negocia `connection.tune` com `connection.tune-ok`.
- Envia `connection.open` para o virtual host configurado.

`IAMQPConnection.CreateChannel` abre um canal AMQP real com `channel.open`.

## Documentação técnica detalhada

O guia [`technical-guide.md`](technical-guide.md) explica em mais detalhes o transporte TCP, a
estrutura dos frames AMQP, os métodos de handshake e a orquestração da conexão.
Constantes de protocolo como canal de conexão, tamanho do header de frame e
`frame_max` padrão ficam nomeadas nas units de protocolo para evitar números
sem contexto no fluxo principal.

## Memória

A API pública expõe interfaces (`IInterface`) para que o ciclo de vida dos
objetos seja controlado por reference counting. Objetos internos podem usar
classes, records e buffers, mas não devem vazar ownership manual para o usuário.

## Threading

O consumo de mensagens deve usar worker thread própria. Callbacks podem rodar
em background ou ser sincronizados com a thread principal por configuração.

## Compatibilidade inicial

- Delphi 10.4+
- Win64
- AMQP 0-9-1
- RabbitMQ como broker de validação
