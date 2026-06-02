# Guia de Uso

## Instalação manual

Adicione a pasta `src` ao search path do projeto Delphi ou inclua as units
necessárias diretamente no projeto.

## Conexão

```pascal
Factory := TAMQPConnectionFactory.Create;
Options := TAMQPConnectionOptions.CreateDefault
  .SetHost('localhost')
  .SetPort(5672)
  .SetVirtualHost('/')
  .SetUserName('guest')
  .SetPassword('guest');

Connection := Factory.CreateConnection(Options);
Connection.Connect;
```

Na etapa atual, `Connect` executa handshake real com RabbitMQ,
`CreateChannel` abre um canal AMQP e as operações de fila/publicação/consumo já
enviam comandos AMQP reais.

## Publicação

```pascal
Channel := Connection.CreateChannel;
Channel.QueueDeclare('minha.fila', True, False, False);
Channel.Publish('', 'minha.fila', TAMQPMessage.FromText('Mensagem'));
```

## Administração de fila

```pascal
Channel.QueueDeclare('minha.fila', True, False, False);
Channel.QueuePurge('minha.fila');
Channel.QueueDelete('minha.fila');
```

## Consumo

```pascal
Consumer := Channel.BasicConsume(
  'minha.fila',
  procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
  begin
    Processar(AMessage.AsText);
    AContext.Ack;
  end);

Consumer.Start;
```

Use `AAutoAck=False` quando quiser confirmar manualmente com `AContext.Ack`.
Com `AAutoAck=True`, a mensagem já é considerada confirmada pelo broker durante
a entrega; nesse modo `Nack` e `Reject` não devem ser usados.

## Observabilidade

Implemente `IAMQPLogger` para receber eventos estruturados da biblioteca. O
logger é passado na criação da factory; se nenhum logger for informado, a
biblioteca usa um logger nulo interno e não gera erro por referência `nil`.

Cada evento recebido em `Log` contém:

- `Timestamp`: data/hora local do evento.
- `Level`: nível do evento (`llTrace`, `llDebug`, `llInfo`, `llWarning`,
  `llError`).
- `Kind`: categoria do evento, como conexão, fila, publish, consume, ack,
  heartbeat ou erro.
- `Operation`: nome técnico da operação AMQP, por exemplo `queue.declare` ou
  `basic.publish`.
- `ConnectionId`: identificador local da conexão.
- `ChannelId`: canal AMQP associado ao evento, quando existir.
- `ErrorClass`: classe da exceção, quando for um evento de erro.
- `DurationMS`: duração em milissegundos, reservado para operações medidas.

```pascal
type
  TMeuLogger = class(TInterfacedObject, IAMQPLogger)
  public
    procedure Log(const AEvent: TAMQPLogEvent);
  end;
```

Passe o logger para a factory:

```pascal
Factory := TAMQPConnectionFactory.Create(TMeuLogger.Create);
```

Exemplo simples de implementação:

```pascal
procedure TMeuLogger.Log(const AEvent: TAMQPLogEvent);
begin
  Writeln(Format(
    '[%s] canal=%d operação=%s mensagem=%s',
    [GetEnumName(TypeInfo(TAMQPLogLevel), Ord(AEvent.Level)),
     AEvent.ChannelId,
     AEvent.Operation,
     AEvent.Message]));
end;
```

Para testes, a unit `DelphiAMQP.Logging` também oferece
`TAMQPInMemoryLogger`, que armazena eventos em memória e permite validar se uma
operação foi emitida:

```pascal
Logger := TAMQPInMemoryLogger.Create;
TAMQPLogger.Info(
  Logger,
  lekQueue,
  'connection-id',
  1,
  'fila declarada',
  AMQP_LOG_QUEUE_DECLARE);
Assert(Logger.ContainsOperation(AMQP_LOG_QUEUE_DECLARE));
```

## Projetos de exemplo

O projeto `examples/ConsoleQuickStart/DelphiAMQP.Example.ConsoleQuickStart.dproj`
mostra o fluxo completo em sequência, sem rotinas auxiliares.

O projeto `examples/ConsoleStepByStep/DelphiAMQP.Example.ConsoleStepByStep.dproj`
mostra o fluxo completo com RabbitMQ local separado em etapas:

- conectar;
- abrir canal;
- declarar fila;
- iniciar consumer assíncrono em worker thread;
- publicar mensagem;
- confirmar com ack;
- parar consumer;
- executar purge/delete;
- desconectar.

O projeto `examples/VclQueueManager/DelphiAMQP.Example.VclQueueManager.dproj`
mostra uma tela VCL com conexão compartilhada, operações de fila, publish,
consume e logs filtráveis por `Level` e `Kind`.

As instruções de execução ficam em:

- `examples/ConsoleQuickStart/README.md`
- `examples/ConsoleStepByStep/README.md`
- `examples/VclQueueManager/README.md`
