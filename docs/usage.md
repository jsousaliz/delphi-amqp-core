# Guia de Uso

## Instalacao manual

Adicione a pasta `src` ao search path do projeto Delphi ou inclua as units
necessarias diretamente no projeto.

## Conexao

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
`CreateChannel` abre um canal AMQP e as operacoes de fila/publicacao/consumo ja
enviam comandos AMQP reais.

## Publicacao

```pascal
Channel := Connection.CreateChannel;
Channel.QueueDeclare('minha.fila', True, False, False);
Channel.Publish('', 'minha.fila', TAMQPMessage.FromText('Mensagem'));
```

## Administracao de fila

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
Com `AAutoAck=True`, a mensagem ja e considerada confirmada pelo broker durante
a entrega; nesse modo `Nack` e `Reject` nao devem ser usados.

## Observabilidade

Implemente `IAMQPLogger` para receber eventos estruturados da biblioteca. O
logger e passado na criacao da factory; se nenhum logger for informado, a
biblioteca usa um logger nulo interno e nao gera erro por referencia `nil`.

Cada evento recebido em `Log` contem:

- `Timestamp`: data/hora local do evento.
- `Level`: nivel do evento (`llTrace`, `llDebug`, `llInfo`, `llWarning`,
  `llError`).
- `Kind`: categoria do evento, como conexao, fila, publish, consume, ack,
  heartbeat ou erro.
- `Operation`: nome tecnico da operacao AMQP, por exemplo `queue.declare` ou
  `basic.publish`.
- `ConnectionId`: identificador local da conexao.
- `ChannelId`: canal AMQP associado ao evento, quando existir.
- `ErrorClass`: classe da excecao, quando for um evento de erro.
- `DurationMS`: duracao em milissegundos, reservado para operacoes medidas.

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

Exemplo simples de implementacao:

```pascal
procedure TMeuLogger.Log(const AEvent: TAMQPLogEvent);
begin
  Writeln(Format(
    '[%s] canal=%d operacao=%s mensagem=%s',
    [GetEnumName(TypeInfo(TAMQPLogLevel), Ord(AEvent.Level)),
     AEvent.ChannelId,
     AEvent.Operation,
     AEvent.Message]));
end;
```

Para testes, a unit `DelphiAMQP.Logging` tambem oferece
`TAMQPInMemoryLogger`, que armazena eventos em memoria e permite validar se uma
operacao foi emitida:

```pascal
Logger := TAMQPInMemoryLogger.Create;
TAMQPLogger.Emit(Logger, llInfo, lekQueue, 'fila declarada', '', 1, '', 'queue.declare');
Assert(Logger.ContainsOperation('queue.declare'));
```
