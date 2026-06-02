# Guia Tecnico do DelphiAMQP

Este documento explica como o componente funciona internamente. A ideia e
manter a implementacao transparente para usuarios avancados e contribuidores.

Status: documento vivo. Ele deve ser atualizado conforme novas etapas do
componente forem implementadas.

## 1. Visao Geral do `Connect`

Quando o usuario chama:

```pascal
Connection.Connect;
```

a biblioteca faz duas coisas diferentes:

- abre uma conexao TCP com o broker;
- conversa AMQP 0-9-1 por cima dessa conexao TCP.

TCP e apenas o transporte de bytes. AMQP e o protocolo que da significado a
esses bytes.

Fluxo conceitual:

```text
DelphiAMQP
  -> abre socket TCP
  -> envia/recebe frames AMQP
  -> RabbitMQ
```

No codigo, a abertura TCP acontece em:

```pascal
FTransport.Connect(FOptions.Host, FOptions.Port, FOptions.ConnectionTimeoutMS);
```

Depois a conversa AMQP comeca com:

```pascal
FTransport.SendBytes(TAMQPFrameCodec.ProtocolHeader);
```

O header inicial AMQP e:

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

`TAMQPTcpTransport` e a camada mais baixa da biblioteca. Ela nao conhece AMQP,
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

Depois o socket e criado com:

```pascal
FSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
```

Significado:

- `AF_INET`: IPv4.
- `SOCK_STREAM`: conexao orientada a fluxo.
- `IPPROTO_TCP`: protocolo TCP.

O endereco e montado com `TSockAddrIn`:

```pascal
LAddr.sin_family := AF_INET;
LAddr.sin_port := htons(APort);
```

`htons` converte a porta para network byte order, que e a ordem de bytes usada
em protocolos de rede.

O host pode ser um IP ou um nome:

```pascal
LAddress := inet_addr(PAnsiChar(AnsiString(AHost)));
```

Se nao for IP, ele e resolvido com:

```pascal
LHostEnt := gethostbyname(PAnsiChar(AnsiString(AHost)));
```

Timeouts de envio e recebimento sao configurados com:

```pascal
setsockopt(FSocket, SOL_SOCKET, SO_RCVTIMEO, PAnsiChar(@LTimeout), SizeOf(LTimeout));
setsockopt(FSocket, SOL_SOCKET, SO_SNDTIMEO, PAnsiChar(@LTimeout), SizeOf(LTimeout));
```

A conexao real acontece com:

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

Recebimento usa `recv`. Como `recv` tambem pode retornar menos bytes do que o
necessario, a implementacao recebe em loop ate completar a quantidade esperada:

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

Depois que o TCP esta conectado, AMQP organiza os bytes em frames. Um frame e a
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

No codigo:

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

O numero `10` vira:

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

Importante: o protocol header `A M Q P 0 0 9 1` nao e um frame. Ele e enviado
uma unica vez no inicio da conexao. Depois disso, a comunicacao usa frames.

## 4. Metodos AMQP

Arquivo principal: `src/DelphiAMQP.Protocol.Methods.pas`.

Um frame do tipo `METHOD` carrega um metodo AMQP. Metodos sao comandos do
protocolo, como:

- `connection.start`
- `connection.start-ok`
- `connection.tune`
- `connection.tune-ok`
- `connection.open`
- `channel.open`
- `queue.declare`
- `basic.publish`

Todo payload de metodo comeca com:

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

Metodos de conexao:

```pascal
AMQP_CONNECTION_START = 10;
AMQP_CONNECTION_START_OK = 11;
AMQP_CONNECTION_TUNE = 30;
AMQP_CONNECTION_TUNE_OK = 31;
AMQP_CONNECTION_OPEN = 40;
AMQP_CONNECTION_OPEN_OK = 41;
```

Metodos de canal:

```pascal
AMQP_CHANNEL_OPEN = 10;
AMQP_CHANNEL_OPEN_OK = 11;
```

`ReadMethodId` le os dois primeiros campos do payload:

```pascal
Result.ClassId := LReader.ReadUInt16;
Result.MethodId := LReader.ReadUInt16;
```

`BuildConnectionStartOk` responde ao `connection.start`, usando autenticacao
`PLAIN`:

```pascal
LResponse := TEncoding.UTF8.GetBytes(#0 + AUserName + #0 + APassword);
```

Para `guest` / `guest`, isso representa:

```text
#0 guest #0 guest
```

`TAMQPConnectionTune` representa os parametros negociados com o servidor:

```pascal
TAMQPConnectionTune = record
  ChannelMax: UInt16;
  FrameMax: UInt32;
  Heartbeat: UInt16;
end;
```

Significado:

- `ChannelMax`: maximo de canais permitidos na conexao.
- `FrameMax`: tamanho maximo de frame.
- `Heartbeat`: intervalo de heartbeat em segundos.

Antes do servidor enviar `connection.tune`, a biblioteca usa valores iniciais
seguros:

```pascal
AMQP_NO_CHANNEL_MAX = 0;
AMQP_DEFAULT_FRAME_MAX = 131072;
```

No AMQP, `channel_max = 0` representa ausencia de limite explicito negociado
pelo cliente. O valor `131072` bytes e o frame maximo padrao usado pelo AMQP
0-9-1/RabbitMQ quando nao ha outra negociacao aplicada.

`BuildConnectionOpen` abre o virtual host configurado, geralmente `/`.

`BuildChannelOpen` abre um canal AMQP real. Diferente dos metodos de conexao,
ele usa canal `1`, `2`, `3` etc. O canal `0` e reservado para a propria conexao.
No codigo:

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

Canal `0` e reservado para metodos de conexao:

```pascal
AMQP_CONNECTION_CHANNEL = 0;
```

Canais de trabalho comecam em `1`.

Os valores iniciais de tune tambem usam constantes nomeadas:

```pascal
FTune.ChannelMax := AMQP_NO_CHANNEL_MAX;
FTune.FrameMax := AMQP_DEFAULT_FRAME_MAX;
FTune.Heartbeat := FOptions.HeartbeatSeconds;
```

Isso evita que numeros como `0`, `1` e `131072` aparecam sem contexto no fluxo
principal da conexao.

Fluxo de `Connect`:

```text
1. Se ja conectado, sai
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

O metodo `ReceiveFrame` le um frame inteiro do TCP:

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

`ReceiveExpectedMethod` garante que a sequencia do protocolo esta correta. Ele
le frames ate encontrar o metodo esperado, ignora heartbeats e trata
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

`Disconnect` tenta fechar a conexao educadamente com:

```text
Cliente -> connection.close
Servidor -> connection.close-ok
```

Depois fecha o socket TCP.

## 6. Sessao Interna de Frames

Arquivo principal: `src/DelphiAMQP.Internal.Session.pas`.

A Etapa 5 introduziu `IAMQPFrameSession` para separar responsabilidades entre
conexao e canal.

Antes disso, `TAMQPConnection` era a unica classe capaz de enviar e receber
frames. Com operacoes como `QueueDeclare` e `Publish`, o canal tambem precisa
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
- receber o proximo frame AMQP disponivel;
- esperar um metodo AMQP especifico;
- consultar o `frame_max` negociado;
- obter o identificador local da conexao para diagnostico;
- consultar se callbacks de consumo devem rodar na worker thread ou na main
  thread.

Quem implementa essa interface e `TAMQPConnection`:

```pascal
TAMQPConnection = class(TInterfacedObject, IAMQPConnection, IAMQPFrameSession)
```

Quando a conexao cria um canal, ela passa a si mesma como sessao interna:

```pascal
Result := TAMQPChannel.Create(LChannelId, FLogger, Self as IAMQPFrameSession);
```

Assim, a arquitetura fica:

```text
TAMQPChannel
  -> fala em operacoes AMQP de canal

IAMQPFrameSession
  -> fronteira interna para envio/recebimento de frames

TAMQPConnection
  -> controla handshake, leitura de frames e estado da conexao

TAMQPTcpTransport
  -> envia e recebe bytes TCP
```

O canal nao conhece `TAMQPTcpTransport`, nao chama `send`/`recv` e nao codifica
bytes diretamente. Ele trabalha no nivel correto: frames e metodos AMQP.

## 7. Filas e Publicacao

Arquivo principal: `src/DelphiAMQP.Protocol.Methods.pas`.

A Etapa 5 adiciona os metodos AMQP de `queue` e `basic.publish`.

Classes AMQP usadas:

```pascal
AMQP_CLASS_QUEUE = 50;
AMQP_CLASS_BASIC = 60;
```

### Operacoes de Fila

Metodos de fila:

```pascal
AMQP_QUEUE_DECLARE = 10;
AMQP_QUEUE_DECLARE_OK = 11;
AMQP_QUEUE_PURGE = 30;
AMQP_QUEUE_PURGE_OK = 31;
AMQP_QUEUE_DELETE = 40;
AMQP_QUEUE_DELETE_OK = 41;
```

`QueueDeclare` envia `queue.declare` e aguarda `queue.declare-ok`. O retorno do
broker e convertido para:

```pascal
TAMQPQueueDeclareResult = record
  QueueName: string;
  MessageCount: UInt32;
  ConsumerCount: UInt32;
end;
```

`queue.declare` contem flags booleanas compactadas em um byte:

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

`QueuePurge` envia `queue.purge` e aguarda `queue.purge-ok`. O parser le a
quantidade de mensagens removidas, embora a API publica atual seja `procedure`.

`QueueDelete` envia `queue.delete` e aguarda `queue.delete-ok`. As flags usadas
sao:

```text
bit 0 -> if-unused
bit 1 -> if-empty
bit 2 -> no-wait
```

### Publicacao

Publicacao usa tres partes no AMQP:

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

O corpo da mensagem e dividido em um ou mais frames quando necessario:

```pascal
TAMQPMethodCodec.BuildContentBodyFrames(...)
```

O limite vem do `frame_max` negociado no handshake:

```pascal
Result := FSession.GetFrameMax;
```

Publisher confirms ainda nao foram implementados. Na etapa atual, `Publish`
envia os frames AMQP em ordem e nao aguarda confirmacao individual do broker.

Se `mandatory=True`, o broker pode devolver uma mensagem nao roteavel via
`basic.return`; esse evento assincrono depende do loop de leitura/roteamento que
sera implementado junto do consumo.

## 8. Operacoes no `TAMQPChannel`

Arquivo principal: `src/DelphiAMQP.Channel.pas`.

`TAMQPChannel` executa as operacoes publicas de canal usando `FSession`.

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

O parametro do callback na API publica e chamado `AMessageHandler`, para deixar
claro que ele e a rotina responsavel por tratar cada mensagem recebida.

Quando `Consumer.Start` e chamado, uma worker thread passa a ler frames da
sessao interna:

```text
basic.deliver
content header
content body frame(s)
```

`basic.deliver` contem consumer tag, delivery tag, exchange, routing key e flag
de redelivery. O content header contem tamanho total do corpo e propriedades da
mensagem. O corpo pode chegar em um ou mais frames, conforme `frame_max`.

O consumer guarda `FChannel: IAMQPChannel` e deriva o id do canal pela
propriedade `FChannel.ChannelId`. Isso evita duplicar estado interno entre canal
e consumer.

Depois da montagem, o callback recebe:

```pascal
const AMessage: IAMQPMessage;
const AContext: IAMQPConsumerContext;
```

Com `AAutoAck=False`, o usuario deve chamar:

```pascal
AContext.Ack;
AContext.Nack(True);
AContext.Reject(False);
```

Com `AAutoAck=True`, `Ack` vira no-op local e `Nack`/`Reject` levantam erro,
porque o broker ja considerou a mensagem confirmada.

`Consumer.Stop` envia `basic.cancel` e aguarda a thread encerrar apos receber
`basic.cancel-ok` ou cancelamento remoto.

Nao ha mais evento local de parada no consumer. A parada normal e governada pelo
protocolo:

```text
Consumer.Stop
  -> envia basic.cancel
  -> worker recebe basic.cancel-ok
  -> worker encerra
```

Isso evita que `basic.cancel-ok` fique pendurado no socket e seja lido pela
proxima operacao sincronizada, como `queue.purge`.

## 10. Observabilidade

Arquivos principais:

- `src/DelphiAMQP.Types.pas`
- `src/DelphiAMQP.Logging.pas`
- `src/DelphiAMQP.Factory.pas`

A observabilidade do componente e baseada em uma interface publica:

```pascal
IAMQPLogger = interface
  procedure Log(const AEvent: TAMQPLogEvent);
end;
```

Quem usa a biblioteca pode adaptar esse evento para console, arquivo, banco,
OpenTelemetry, Log4D, logger proprio ou qualquer outro destino. A biblioteca
nao depende de framework externo de log.

O evento e estruturado:

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

`Operation` guarda o nome tecnico da operacao AMQP, como:

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

Isso permite filtrar logs por operacao sem depender do texto livre de
`Message`.

O logger e definido na factory:

```pascal
Factory := TAMQPConnectionFactory.Create(TConsoleLogger.Create);
```

Se o usuario nao informar um logger, a factory usa:

```pascal
TAMQPLogger.Null
```

Esse logger implementa `IAMQPLogger`, mas nao faz nada. Assim os fluxos
internos podem emitir eventos sem testar `nil` em todos os pontos de uso.

`TAMQPLogger.Emit` centraliza a montagem do evento:

```pascal
TAMQPLogger.Emit(
  FLogger,
  llInfo,
  lekQueue,
  'queue.declare requested for ' + AQueueName,
  FSession.GetConnectionId,
  FChannelId,
  '',
  'queue.declare');
```

Para testes existe `TAMQPInMemoryLogger`. Ele guarda os eventos em memoria com
proteção por `TMonitor`, permitindo validar emissao de eventos sem escrever em
arquivo externo:

```pascal
Logger := TAMQPInMemoryLogger.Create;
Assert(Logger.ContainsOperation('queue.declare'));
```

## 11. Exemplo Validado

Arquivo principal: `examples/ConsolePublisherConsumer/DelphiAMQP.Example.Console.dpr`.

O exemplo atual executa:

```text
criar factory com logger
configurar host/porta/vhost/usuario/senha
conectar
abrir canal
declarar fila
registrar consumer
iniciar consumer
publicar mensagem
aguardar callback de recebimento
confirmar mensagem com ack
parar consumer
limpar fila
deletar fila
desconectar
```

Fluxo equivalente:

```pascal
Factory := TAMQPConnectionFactory.Create(TConsoleLogger.Create);

Connection := Factory.CreateConnection(Options);
Connection.Connect;

Channel := Connection.CreateChannel;
Channel.QueueDeclare('delphiamqp.demo', True, False, False);

Consumer := Channel.BasicConsume(
  'delphiamqp.demo',
  procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
  begin
    Writeln('Mensagem recebida: ' + AMessage.AsText);
    AContext.Ack;
    MessageReceived.SetEvent;
  end,
  False);

Consumer.Start;
Channel.Publish('', 'delphiamqp.demo', TAMQPMessage.FromText('Ola do DelphiAMQP'));

if MessageReceived.WaitFor(5000) <> wrSignaled then
  raise Exception.Create('Timeout waiting for consumed message.');

Consumer.Stop;
Channel.QueuePurge('delphiamqp.demo');
Channel.QueueDelete('delphiamqp.demo');

Connection.Disconnect;
```

`MessageReceived` e um `TEvent` usado apenas pelo exemplo para a thread
principal aguardar ate o callback do consumer sinalizar que a mensagem chegou.

Esse fluxo foi compilado e executado contra RabbitMQ local.

## Resumo Atual

Nesta etapa, a biblioteca ja consegue:

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
- registrar eventos estruturados de conexao, canal, fila, publish, consumo,
  ack/nack/reject, heartbeat e erro.

As proximas etapas devem expandir esta base com `basic.return` para mensagens
publicadas com `mandatory=True`, heartbeat ativo e reconexao futura.
