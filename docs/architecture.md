# Arquitetura

Delphi AMQP Core sera organizado em camadas pequenas e testaveis.

## Camadas

- API publica: interfaces e tipos estaveis usados pelo consumidor da biblioteca.
- Implementacao: classes concretas para conexao, canal, mensagens e consumers.
- Protocolo: codec AMQP 0-9-1, frames e metodos binarios.
- Transporte: socket TCP baseado em WinSock/RTL, com timeouts de envio/recebimento.
- Observabilidade: logger por interface, com implementacao nula por padrao.

## Handshake implementado

`IAMQPConnection.Connect` executa a sequencia inicial:

- Abre socket TCP.
- Envia protocol header AMQP 0-9-1.
- Responde `connection.start` com `connection.start-ok` usando autenticacao PLAIN.
- Negocia `connection.tune` com `connection.tune-ok`.
- Envia `connection.open` para o virtual host configurado.

`IAMQPConnection.CreateChannel` abre um canal AMQP real com `channel.open`.

## Documentacao tecnica detalhada

O guia `technical-guide.md` explica em mais detalhes o transporte TCP, a
estrutura dos frames AMQP, os metodos de handshake e a orquestracao da conexao.
Constantes de protocolo como canal de conexao, tamanho do header de frame e
`frame_max` padrao ficam nomeadas nas units de protocolo para evitar numeros
sem contexto no fluxo principal.

## Memoria

A API publica expõe interfaces (`IInterface`) para que o ciclo de vida dos
objetos seja controlado por reference counting. Objetos internos podem usar
classes, records e buffers, mas nao devem vazar ownership manual para o usuario.

## Threading

O consumo de mensagens deve usar worker thread propria. Callbacks podem rodar
em background ou ser sincronizados com a thread principal por configuracao.

## Compatibilidade inicial

- Delphi 10.4+
- Win64
- AMQP 0-9-1
- RabbitMQ como broker de validacao
