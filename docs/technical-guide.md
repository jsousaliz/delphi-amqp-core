# Guia Técnico do Delphi AMQP Core

Este documento explica como o componente funciona internamente. A ideia é
manter a implementação transparente para usuários avançados e contribuidores.

Status: documento vivo. Ele deve ser atualizado conforme novas etapas do
componente forem implementadas.

## Índice

- [1. Visao Geral do `Connect`](#1-visao-geral-do-connect)
- [2. Transporte TCP](#2-transporte-tcp)
- [3. Frames AMQP](#3-frames-amqp)
- [4. Métodos AMQP](#4-métodos-amqp)
- [5. Orquestracao em `TAMQPConnection`](#5-orquestracao-em-tamqpconnection)
- [6. Sessao Interna de Frames](#6-sessao-interna-de-frames)
- [7. Filas e Publicação](#7-filas-e-publicação)
- [8. Operacoes no `TAMQPChannel`](#8-operacoes-no-tamqpchannel)
- [9. Consumo Assincrono](#9-consumo-assincrono)
- [10. Observabilidade](#10-observabilidade)
- [11. Exemplo Validado](#11-exemplo-validado)
- [Resumo Atual](#resumo-atual)

## 1. Visao Geral do `Connect`

Quando o usuário chama:

```pascal
Connection.Connect;
```

a biblioteca faz duas coisas diferentes:

- abre uma conexão TCP com o broker;
- conversa AMQP 0-9-1 por cima dessa conexão TCP.

TCP é apenas o transporte de bytes. AMQP é o protocolo que dá significado a
esses bytes.

Fluxo conceitual:

```text
Delphi AMQP Core
  -> abre socket TCP
  -> envia/recebe frames AMQP
  -> RabbitMQ
```

No código, a abertura TCP acontece em:

```pascal
FTransport.Connect(FOptions.Host, FOptions.Port, FOptions.ConnectionTimeoutMS);
```

Depois a conversa AMQP comeca com:

```pascal
FTransport.SendBytes(TAMQPFrameCodec.ProtocolHeader);
```

O header inicial AMQP é:

```text
A M Q P 0 0 9 1
```

Ele informa ao broker que o cliente quer falar AMQP 0-9-1.

Depois disso, ocorre o handshake:

```text
Cliente  -> Protocol Header
Servidor -> connection.start
Cliente  -> connection.start-ok
Servidor -> connection.tune
Cliente  -> connection.tune-ok
Cliente  -> connection.open
Servidor -> connection.open-ok
```

Resumo das camadas:

```text
IAMQPConnection.Connect
        |
        v
TAMQPConnection
        |
        v
TAMQPMethodCodec / TAMQPFrameCodec
        |
        v
TAMQPTcpTransport
        |
        v
RabbitMQ
```

## 2. Transporte TCP

Arquivo principal: `src/DelphiAMQP.Transport.Tcp.pas`.

`TAMQPTcpTransport` é a camada mais baixa da biblioteca. Ela não conhece AMQP,
RabbitMQ, fila, exchange ou mensagem. Ela sabe apenas:

```pascal
procedure Connect(const AHost: string; const APort: UInt16; const ATimeoutMS: Cardinal);
procedure Disconnect;
procedure SendBytes(const ABytes: TBytes);
function ReceiveBytes(const ACount: Integer): TBytes;
function Connected: Boolean;
```

No Windows, sockets TCP usam WinSock. Antes de usar sockets, a biblioteca chama:

```pascal
WSAStartup(WINSOCK_VERSION_2_2, LData)
```

`WINSOCK_VERSION_2_2` representa WinSock 2.2. A constante evita que o valor
hexadecimal `$0202` fique sem contexto no fluxo principal.

Depois o socket é criado com:

```pascal
FSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
```

Significado:

- `AF_INET`: IPv4.
- `SOCK_STREAM`: conexão orientada a fluxo.
- `IPPROTO_TCP`: protocolo TCP.

O endereço é montado com `TSockAddrIn`:

```pascal
LAddr.sin_family := AF_INET;
LAddr.sin_port := htons(APort);
```

`htons` converte a porta para network byte order, que é a ordem de bytes usada
em protocolos de rede.

O host pode ser um IP ou um nome:

```pascal
LAddress := inet_addr(PAnsiChar(AnsiString(AHost)));
```

Se não for IP, ele é resolvido com:

```pascal
LHostEnt := gethostbyname(PAnsiChar(AnsiString(AHost)));
```

Timeouts de envio e recebimento são configurados com:

```pascal
setsockopt(FSocket, SOL_SOCKET, SO_RCVTIMEO, PAnsiChar(@LTimeout), SizeOf(LTimeout));
setsockopt(FSocket, SOL_SOCKET, SO_SNDTIMEO, PAnsiChar(@LTimeout), SizeOf(LTimeout));
```

A conexão real acontece com:

```pascal
Winapi.WinSock.connect(FSocket, LAddr, SizeOf(LAddr));
```

Envio de bytes usa `send`. Como `send` pode enviar menos bytes do que foi
solicitado, a implementacao usa um loop ate enviar tudo:

```pascal
while LTotal < Length(ABytes) do
begin
  LSent := send(FSocket, ABytes[LTotal], Length(ABytes) - LTotal, 0);
  Inc(LTotal, LSent);
end;
```

Recebimento usa `recv`. Como `recv` também pode retornar menos bytes do que o
necessário, a implementação recebe em loop até completar a quantidade esperada:

```pascal
while LTotal < ACount do
begin
  WaitReadable;
  LReceived := recv(FSocket, Result[LTotal], ACount - LTotal, 0);
  Inc(LTotal, LReceived);
end;
```

`WaitReadable` usa `select` para evitar bloqueio indefinido:

```pascal
select(0, @LReadSet, nil, nil, @LTimeout);
```

Se nenhum dado chegar dentro do timeout, a biblioteca levanta
`EAMQPConnectionError`.

## 3. Frames AMQP

Arquivo principal: `src/DelphiAMQP.Protocol.Frame.pas`.

Depois que o TCP está conectado, AMQP organiza os bytes em frames. Um frame é a
unidade basica de comunicacao do protocolo.

Formato de um frame AMQP:

```text
+-------------+----------+--------------+-----------+
| tipo        | canal    | tamanho      | payload   |
+-------------+----------+--------------+-----------+
| 1 byte      | 2 bytes  | 4 bytes      | N bytes   |
+-------------+----------+--------------+-----------+
| frame-end = $CE                                |
+------------------------------------------------+
```

No código:

```pascal
TAMQPFrame = record
  FrameType: Byte;
  Channel: UInt16;
  Payload: TBytes;
end;
```

Tipos principais:

```pascal
AMQP_FRAME_METHOD = 1;
AMQP_FRAME_HEADER = 2;
AMQP_FRAME_BODY = 3;
AMQP_FRAME_HEARTBEAT = 8;
AMQP_FRAME_END = $CE;
AMQP_FRAME_HEADER_SIZE = 7;
AMQP_FRAME_END_SIZE = 1;
```

Nesta etapa, o handshake usa principalmente frames do tipo `METHOD`.

Todo frame trafega em formato binario. Numeros AMQP usam network byte order
big-endian. Por isso existem `TAMQPBinaryWriter` e `TAMQPBinaryReader`.

Exemplo de escrita de `UInt16`:

```pascal
procedure TAMQPBinaryWriter.WriteUInt16(const AValue: UInt16);
begin
  AppendByte(Byte((AValue shr 8) and $FF));
  AppendByte(Byte(AValue and $FF));
end;
```

O número `10` vira:

```text
00 0A
```

`EncodeFrame` transforma um `TAMQPFrame` em bytes para envio TCP:

```pascal
LWriter.WriteUInt8(AFrame.FrameType);
LWriter.WriteUInt16(AFrame.Channel);
LWriter.WriteUInt32(Length(AFrame.Payload));
LWriter.WriteBytes(AFrame.Payload);
LWriter.WriteUInt8(AMQP_FRAME_END);
```

`DecodeFrame` faz o inverso: recebe bytes, valida o marcador final `$CE` e
retorna um `TAMQPFrame`.

Importante: o protocol header `A M Q P 0 0 9 1` não é um frame. Ele é enviado
uma única vez no início da conexão. Depois disso, a comunicação usa frames.

## 4. Métodos AMQP

Arquivo principal: `src/DelphiAMQP.Protocol.Methods.pas`.

Um frame do tipo `METHOD` carrega um método AMQP. Métodos são comandos do
protocolo, como:

- `connection.start`
- `connection.start-ok`
- `connection.tune`
- `connection.tune-ok`
- `connection.open`
- `channel.open`
- `queue.declare`
- `basic.publish`

Todo payload de método começa com:

```text
2 bytes -> class id
2 bytes -> method id
```

Exemplo:

```text
00 0A 00 0B
```

Isso significa:

```text
class id  = 10
method id = 11
```

No AMQP 0-9-1:

```text
10.11 = connection.start-ok
```

Constantes principais:

```pascal
AMQP_CLASS_CONNECTION = 10;
AMQP_CLASS_CHANNEL = 20;
```

Métodos de conexão:

```pascal
AMQP_CONNECTION_START = 10;
AMQP_CONNECTION_START_OK = 11;
AMQP_CONNECTION_TUNE = 30;
AMQP_CONNECTION_TUNE_OK = 31;
AMQP_CONNECTION_OPEN = 40;
AMQP_CONNECTION_OPEN_OK = 41;
```

Métodos de canal:

```pascal
AMQP_CHANNEL_OPEN = 10;
AMQP_CHANNEL_OPEN_OK = 11;
```

`ReadMethodId` le os dois primeiros campos do payload:

```pascal
Result.ClassId := LReader.ReadUInt16;
Result.MethodId := LReader.ReadUInt16;
```

`BuildConnectionStartOk` responde ao `connection.start`, usando autenticação
`PLAIN`:

```pascal
LResponse := TEncoding.UTF8.GetBytes(#0 + AUserName + #0 + APassword);
```

Para `guest` / `guest`, isso representa:

```text
#0 guest #0 guest
```

`TAMQPConnectionTune` representa os parâmetros negociados com o servidor:

```pascal
TAMQPConnectionTune = record
  ChannelMax: UInt16;
  FrameMax: UInt32;
  Heartbeat: UInt16;
end;
```

Significado:

- `ChannelMax`: máximo de canais permitidos na conexão.
- `FrameMax`: tamanho máximo de frame.
- `Heartbeat`: intervalo de heartbeat em segundos.

Antes do servidor enviar `connection.tune`, a biblioteca usa valores iniciais
seguros:

```pascal
AMQP_NO_CHANNEL_MAX = 0;
AMQP_DEFAULT_FRAME_MAX = 131072;
```

No AMQP, `channel_max = 0` representa ausência de limite explícito negociado
pelo cliente. O valor `131072` bytes é o frame máximo padrão usado pelo AMQP
0-9-1/RabbitMQ quando não há outra negociação aplicada.

`BuildConnectionOpen` abre o virtual host configurado, geralmente `/`.

`BuildChannelOpen` abre um canal AMQP real. Diferente dos métodos de conexão,
ele usa canal `1`, `2`, `3` etc. O canal `0` é reservado para a própria conexão.
No código:

```pascal
AMQP_CONNECTION_CHANNEL = 0;
AMQP_FIRST_APPLICATION_CHANNEL = 1;
```

## 5. Orquestracao em `TAMQPConnection`

Arquivo principal: `src/DelphiAMQP.Connection.pas`.

`TAMQPConnection` implementa `IAMQPConnection` e coordena as camadas:

```text
TAMQPConnection
  -> TAMQPTcpTransport
  -> TAMQPFrameCodec
  -> TAMQPMethodCodec
  -> IAMQPLogger
```

Campos importantes:

```pascal
FOptions: IAMQPConnectionOptions;
FLogger: IAMQPLogger;
FState: TAMQPConnectionState;
FNextChannelId: UInt16;
FConnectionId: string;
FTransport: TAMQPTcpTransport;
FTune: TAMQPConnectionTune;
```

`FNextChannelId` controla o proximo canal AMQP livre. Ele inicia em `1`:

```pascal
FNextChannelId := AMQP_FIRST_APPLICATION_CHANNEL;
```

Canal `0` é reservado para métodos de conexão:

```pascal
AMQP_CONNECTION_CHANNEL = 0;
```

Canais de trabalho comecam em `1`.

Os valores iniciais de tune também usam constantes nomeadas:

```pascal
FTune.ChannelMax := AMQP_NO_CHANNEL_MAX;
FTune.FrameMax := AMQP_DEFAULT_FRAME_MAX;
FTune.Heartbeat := FOptions.HeartbeatSeconds;
```

Isso evita que números como `0`, `1` e `131072` apareçam sem contexto no fluxo
principal da conexão.

Fluxo de `Connect`:

```text
1. Se já conectado, sai
2. Estado = connecting
3. Abre TCP
4. Envia protocol header
5. Espera connection.start
6. Envia connection.start-ok
7. Espera connection.tune
8. Envia connection.tune-ok
9. Envia connection.open
10. Espera connection.open-ok
11. Estado = connected
```

O método `ReceiveFrame` lê um frame inteiro do TCP:

```pascal
LHeader := FTransport.ReceiveBytes(AMQP_FRAME_HEADER_SIZE);
```

Sete bytes representam o tamanho fixo do header de frame AMQP:

```text
1 byte  -> frame type
2 bytes -> channel
4 bytes -> payload size
```

Depois ele le `payload size + AMQP_FRAME_END_SIZE`, porque alem do payload vem
o byte final `$CE`.

`ReceiveExpectedMethod` garante que a sequência do protocolo está correta. Ele
lê frames até encontrar o método esperado, ignora heartbeats e trata
`connection.close` enviado pelo servidor.

`CreateChannel` so pode ser chamado depois de `Connect`:

```pascal
if FState <> csConnected then
  raise EAMQPConnectionError.Create('Connection must be connected before creating a channel.');
```

Ele abre um canal no broker:

```pascal
SendFrame(TAMQPMethodCodec.BuildChannelOpen(LChannelId));
ReceiveExpectedMethod(AMQP_CLASS_CHANNEL, AMQP_CHANNEL_OPEN_OK);
```

Depois cria o objeto local:

```pascal
Result := TAMQPChannel.Create(LChannelId, FLogger);
Inc(FNextChannelId);
```

`Disconnect` tenta fechar a conexão educadamente com:

```text
Cliente -> connection.close
Servidor -> connection.close-ok
```

Depois fecha o socket TCP.

## 6. Sessao Interna de Frames

Arquivo principal: `src/DelphiAMQP.Internal.Session.pas`.

A Etapa 5 introduziu `IAMQPFrameSession` para separar responsabilidades entre
conexão e canal.

Antes disso, `TAMQPConnection` era a única classe capaz de enviar e receber
frames. Com operações como `QueueDeclare` e `Publish`, o canal também precisa
solicitar envio de frames. Em vez de passar o socket TCP para o canal, foi
criada uma interface interna:

```pascal
IAMQPFrameSession = interface
  procedure SendFrame(const AFrame: TAMQPFrame);
  function ReceiveFrame: TAMQPFrame;
  function ReceiveExpectedMethod(const AClassId, AMethodId: UInt16): TAMQPFrame;
  function GetFrameMax: UInt32;
  function GetConnectionId: string;
  function GetConsumerDispatchMode: TAMQPConsumerDispatchMode;
end;
```

Ela permite ao canal:

- enviar um frame AMQP;
- receber o próximo frame AMQP disponível;
- esperar um método AMQP específico;
- consultar o `frame_max` negociado;
- obter o identificador local da conexão para diagnóstico;
- consultar se callbacks de consumo devem rodar na worker thread ou na main
  thread.

Quem implementa essa interface é `TAMQPConnection`:

```pascal
TAMQPConnection = class(TInterfacedObject, IAMQPConnection, IAMQPFrameSession)
```

Quando a conexão cria um canal, ela passa a si mesma como sessão interna:

```pascal
Result := TAMQPChannel.Create(LChannelId, FLogger, Self as IAMQPFrameSession);
```

Assim, a arquitetura fica:

```text
TAMQPChannel
  -> fala em operações AMQP de canal

IAMQPFrameSession
  -> fronteira interna para envio/recebimento de frames

TAMQPConnection
  -> controla handshake, leitura de frames e estado da conexão

TAMQPTcpTransport
  -> envia e recebe bytes TCP
```

O canal não conhece `TAMQPTcpTransport`, não chama `send`/`recv` e não codifica
bytes diretamente. Ele trabalha no nível correto: frames e métodos AMQP.

## 7. Filas e Publicação

Arquivo principal: `src/DelphiAMQP.Protocol.Methods.pas`.

A Etapa 5 adiciona os métodos AMQP de `queue` e `basic.publish`.

Classes AMQP usadas:

```pascal
AMQP_CLASS_QUEUE = 50;
AMQP_CLASS_BASIC = 60;
```

### Operações de Fila

Métodos de fila:

```pascal
AMQP_QUEUE_DECLARE = 10;
AMQP_QUEUE_DECLARE_OK = 11;
AMQP_QUEUE_PURGE = 30;
AMQP_QUEUE_PURGE_OK = 31;
AMQP_QUEUE_DELETE = 40;
AMQP_QUEUE_DELETE_OK = 41;
```

`QueueDeclare` envia `queue.declare` e aguarda `queue.declare-ok`. O retorno do
broker é convertido para:

```pascal
TAMQPQueueDeclareResult = record
  QueueName: string;
  MessageCount: UInt32;
  ConsumerCount: UInt32;
end;
```

`queue.declare` contém flags booleanas compactadas em um byte:

```text
bit 0 -> passive
bit 1 -> durable
bit 2 -> exclusive
bit 3 -> auto-delete
bit 4 -> no-wait
```

O helper `PackBits` transforma um array de booleanos nesses bits:

```pascal
LWriter.WriteUInt8(PackBits([False, ADurable, AExclusive, AAutoDelete, False]));
```

`QueuePurge` envia `queue.purge` e aguarda `queue.purge-ok`. O parser lê a
quantidade de mensagens removidas, embora a API pública atual seja `procedure`.

`QueueDelete` envia `queue.delete` e aguarda `queue.delete-ok`. As flags usadas
são:

```text
bit 0 -> if-unused
bit 1 -> if-empty
bit 2 -> no-wait
```

### Publicação

Publicação usa três partes no AMQP:

```text
basic.publish method frame
content header frame
content body frame(s)
```

O method frame informa exchange, routing key e flags:

```pascal
TAMQPMethodCodec.BuildBasicPublish(...)
```

No RabbitMQ, exchange vazia (`''`) significa default exchange. Nesse caso, a
routing key normalmente deve ser o nome da fila:

```pascal
Channel.Publish('', 'delphiamqp.demo', TAMQPMessage.FromText('Mensagem'));
```

O content header informa classe `basic`, peso `0`, tamanho total do corpo e
propriedades:

```pascal
TAMQPMethodCodec.BuildContentHeader(...)
```

As propriedades de mensagem usam flags AMQP. Por exemplo:

```pascal
AMQP_BASIC_PROP_CONTENT_TYPE = $8000;
AMQP_BASIC_PROP_DELIVERY_MODE = $1000;
```

Se `ContentType` e `DeliveryMode` estiverem preenchidos, o header envia as flags
e depois os valores na ordem definida pelo protocolo.

O corpo da mensagem é dividido em um ou mais frames quando necessário:

```pascal
TAMQPMethodCodec.BuildContentBodyFrames(...)
```

O limite vem do `frame_max` negociado no handshake:

```pascal
Result := FSession.GetFrameMax;
```

Publisher confirms ainda não foram implementados. Na etapa atual, `Publish`
envia os frames AMQP em ordem e não aguarda confirmação individual do broker.

Se `mandatory=True`, o broker pode devolver uma mensagem não roteável via
`basic.return`; esse evento assíncrono depende do loop de leitura/roteamento que
será implementado junto do consumo.

## 8. Operacoes no `TAMQPChannel`

Arquivo principal: `src/DelphiAMQP.Channel.pas`.

`TAMQPChannel` executa as operações públicas de canal usando `FSession`.

Campos principais:

```pascal
FChannelId: UInt16;
FLogger: IAMQPLogger;
FSession: IAMQPFrameSession;
```

`QueueDeclare`:

```text
valida nome da fila
monta queue.declare
envia frame
espera queue.declare-ok
retorna QueueName, MessageCount e ConsumerCount
```

`QueuePurge`:

```text
valida nome da fila
monta queue.purge
envia frame
espera queue.purge-ok
```

`QueueDelete`:

```text
valida nome da fila
monta queue.delete
envia frame
espera queue.delete-ok
```

`Publish`:

```text
valida mensagem e roteamento
envia basic.publish
envia content header
envia content body frame(s)
```

## 9. Consumo Assincrono

Arquivos principais:

- `src/DelphiAMQP.Channel.pas`
- `src/DelphiAMQP.Consumer.pas`
- `src/DelphiAMQP.Protocol.Methods.pas`

A Etapa 6 adiciona:

```pascal
AMQP_BASIC_CONSUME = 20;
AMQP_BASIC_CONSUME_OK = 21;
AMQP_BASIC_CANCEL = 30;
AMQP_BASIC_CANCEL_OK = 31;
AMQP_BASIC_DELIVER = 60;
AMQP_BASIC_ACK = 80;
AMQP_BASIC_REJECT = 90;
AMQP_BASIC_NACK = 120;
```

`BasicConsume` envia `basic.consume`, aguarda `basic.consume-ok` e cria um
`TAMQPConsumer` com a consumer tag retornada pelo broker.

O parâmetro do callback na API pública é chamado `AMessageHandler`, para deixar
claro que ele é a rotina responsável por tratar cada mensagem recebida.

Quando `Consumer.Start` é chamado, uma worker thread passa a ler frames da
sessão interna:

```text
basic.deliver
content header
content body frame(s)
```

`basic.deliver` contém consumer tag, delivery tag, exchange, routing key e flag
de redelivery. O content header contém tamanho total do corpo e propriedades da
mensagem. O corpo pode chegar em um ou mais frames, conforme `frame_max`.

O consumer guarda `FChannel: IAMQPChannel` e deriva o id do canal pela
propriedade `FChannel.ChannelId`. Isso evita duplicar estado interno entre canal
e consumer.

Depois da montagem, o callback recebe:

```pascal
const AMessage: IAMQPMessage;
const AContext: IAMQPConsumerContext;
```

Com `AAutoAck=False`, o usuário deve chamar:

```pascal
AContext.Ack;
AContext.Nack(True);
AContext.Reject(False);
```

Com `AAutoAck=True`, `Ack` vira no-op local e `Nack`/`Reject` levantam erro,
porque o broker já considerou a mensagem confirmada.

`Consumer.Stop` envia `basic.cancel` e aguarda a thread encerrar após receber
`basic.cancel-ok` ou cancelamento remoto.

Não há mais evento local de parada no consumer. A parada normal é governada pelo
protocolo:

```text
Consumer.Stop
  -> envia basic.cancel
  -> worker recebe basic.cancel-ok
  -> worker encerra
```

Isso evita que `basic.cancel-ok` fique pendurado no socket e seja lido pela
próxima operação sincronizada, como `queue.purge`.

## 10. Observabilidade

Arquivos principais:

- `src/DelphiAMQP.Types.pas`
- `src/DelphiAMQP.Logging.pas`
- `src/DelphiAMQP.Factory.pas`

A observabilidade do componente é baseada em uma interface pública:

```pascal
IAMQPLogger = interface
  procedure Log(const AEvent: TAMQPLogEvent);
end;
```

Quem usa a biblioteca pode adaptar esse evento para console, arquivo, banco,
OpenTelemetry, Log4D, logger proprio ou qualquer outro destino. A biblioteca
não depende de framework externo de log.

O evento é estruturado:

```pascal
TAMQPLogEvent = record
  Timestamp: TDateTime;
  Level: TAMQPLogLevel;
  Kind: TAMQPLogEventKind;
  Message: string;
  Operation: string;
  ConnectionId: string;
  ChannelId: UInt16;
  ErrorClass: string;
  DurationMS: UInt64;
end;
```

`Kind` classifica a area do evento:

```pascal
lekConnection,
lekChannel,
lekQueue,
lekPublish,
lekConsume,
lekAck,
lekNack,
lekHeartbeat,
lekError
```

`Operation` guarda o nome técnico da operação AMQP, como:

```text
tcp.connect
connection.open
channel.open
queue.declare
queue.purge
queue.delete
basic.publish
basic.consume
basic.ack
basic.nack
basic.reject
basic.cancel
heartbeat
```

Isso permite filtrar logs por operação sem depender do texto livre de
`Message`.

O logger é definido na factory:

```pascal
Factory := TAMQPConnectionFactory.Create(TConsoleLogger.Create);
```

Se o usuário não informar um logger, a factory usa:

```pascal
TAMQPLogger.Null
```

Esse logger implementa `IAMQPLogger`, mas não faz nada. Assim os fluxos
internos podem emitir eventos sem testar `nil` em todos os pontos de uso.

`TAMQPLogger.Emit` centraliza a montagem do evento, mas o código de produção usa
helpers semânticos para deixar a leitura mais clara:

```pascal
TAMQPLogger.Info(
  FLogger,
  lekQueue,
  FSession.GetConnectionId,
  FChannelId,
  Format('queue.declare requested for %s', [AQueueName]),
  AMQP_LOG_QUEUE_DECLARE);
```

As operações de log também ficam em constantes, como
`AMQP_LOG_QUEUE_DECLARE`, `AMQP_LOG_BASIC_PUBLISH` e
`AMQP_LOG_CONNECTION_OPEN`, evitando strings soltas espalhadas pelo código.

Para testes existe `TAMQPInMemoryLogger`. Ele guarda os eventos em memória com
proteção por `TMonitor`, permitindo validar emissão de eventos sem escrever em
arquivo externo:

```pascal
Logger := TAMQPInMemoryLogger.Create;
Assert(Logger.ContainsOperation('queue.declare'));
```

## 11. Exemplo Validado

Arquivo principal: `examples/ConsoleStepByStep/DelphiAMQP.Example.ConsoleStepByStep.dpr`.

O exemplo atual executa o fluxo em rotinas separadas:

```text
PrintConfiguration
criar factory com logger
configurar host/porta/vhost/usuário/senha
Connect
OpenChannel
DeclareQueue
StartConsumer
PublishMessage
WaitForMessage
StopConsumer
CleanupQueue
Disconnect
```

Fluxo equivalente:

```pascal
Factory := TAMQPConnectionFactory.Create(TConsoleLogger.Create);
Options := BuildOptions;

Connection := Connect(Factory, Options);
Channel := OpenChannel(Connection);
DeclareQueue(Channel);
Consumer := StartConsumer(Channel, MessageReceived);
PublishMessage(Channel);
WaitForMessage(MessageReceived);
StopConsumer(Consumer);
CleanupQueue(Channel);
Disconnect(Connection);
```

`MessageReceived` é um `TEvent` usado apenas pelo exemplo para a thread
principal aguardar até o callback do consumer sinalizar que a mensagem chegou.
O exemplo imprime o id da thread principal e o id da worker thread do callback,
deixando visível que o consumo não bloqueia a thread principal.

Esse fluxo foi compilado e executado contra RabbitMQ local.

## Resumo Atual

Nesta etapa, a biblioteca já consegue:

- abrir socket TCP;
- falar o header inicial AMQP 0-9-1;
- autenticar com `PLAIN`;
- negociar `connection.tune`;
- abrir o virtual host;
- abrir canais AMQP reais;
- declarar, limpar e deletar filas;
- publicar mensagens usando `basic.publish`, content header e content body;
- consumir mensagens com `basic.consume`;
- confirmar ou rejeitar mensagens com `ack`, `nack` e `reject`;
- registrar eventos estruturados de conexão, canal, fila, publish, consumo,
  ack/nack/reject, heartbeat e erro.

As próximas etapas devem expandir esta base com `basic.return` para mensagens
publicadas com `mandatory=True`, heartbeat ativo e reconexão futura.
