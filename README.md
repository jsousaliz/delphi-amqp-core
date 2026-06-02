# DelphiAMQP

DelphiAMQP e uma biblioteca Delphi open source para comunicacao nativa com
brokers AMQP 0-9-1, com foco inicial em RabbitMQ. O objetivo e permitir
conectar, publicar, consumir, monitorar e administrar filas sem depender de
componentes Delphi externos.

Status atual: fundacao do projeto, contratos publicos, codec inicial, transporte
TCP, handshake AMQP 0-9-1, abertura de canal, operacoes de fila, publicacao,
consumo assincrono com ack/nack/reject e observabilidade estruturada.

## Objetivos

- AMQP 0-9-1 nativo, inicialmente validado com RabbitMQ.
- API baseada em interfaces para reduzir controle manual de memoria.
- Consumo assincrono para nao bloquear a thread principal.
- Observabilidade por interface de logger estruturado.
- Exemplos didaticos em projeto separado.
- Licenca MIT.

## Estrutura

- `src/`: units da biblioteca.
- `tests/`: testes unitarios e integracao planejados.
- `examples/`: projeto de exemplo.
- `docs/`: documentacao do usuario, arquitetura e guia tecnico interno.
- `plan/`: planejamento de desenvolvimento por etapas.
- `LICENSE` e `COPYRIGHT`: licenciamento do projeto.

## Planejamento de desenvolvimento

O planejamento incremental do componente fica em `plan/`. O arquivo principal
`plan/README.md` lista as etapas e cada arquivo detalha entregas, definicao de
pronto e pendencias conhecidas.

## Uso basico

```pascal
var
  Factory: IAMQPConnectionFactory;
  Options: IAMQPConnectionOptions;
  Connection: IAMQPConnection;
  Channel: IAMQPChannel;
begin
  Factory := TAMQPConnectionFactory.Create;
  Options := TAMQPConnectionOptions.CreateDefault;

  Options.SetHost('localhost')
    .SetPort(5672)
    .SetVirtualHost('/')
    .SetUserName('guest')
    .SetPassword('guest');

  Connection := Factory.CreateConnection(Options);
  Connection.Connect;

  Channel := Connection.CreateChannel;
  Channel.QueueDeclare('delphiamqp.demo', True, False, False);
  Channel.Publish('', 'delphiamqp.demo', TAMQPMessage.FromText('Ola AMQP'));

  Connection.Disconnect;
end;
```

## Consumo assincrono

```pascal
Consumer := Channel.BasicConsume(
  'delphiamqp.demo',
  procedure(const AMessage: IAMQPMessage; const AContext: IAMQPConsumerContext)
  begin
    try
      Writeln(AMessage.AsText);
      AContext.Ack;
    except
      AContext.Nack(True);
    end;
  end);

Consumer.Start;
```

O callback podera ser executado em worker thread ou sincronizado com a thread
principal, conforme configuracao.

## Exemplo

O projeto em `examples/ConsolePublisherConsumer` demonstra:

- Conexao com RabbitMQ local.
- Criacao de fila.
- Publicacao de mensagem.
- Purge e delete de fila.
- Consumo assincrono com ack manual.

Na etapa atual, conexao, abertura de canal, criacao de fila, publicacao,
consumo, ack, purge e delete ja sao executados contra RabbitMQ.

## Observabilidade

Passe um `IAMQPLogger` para `TAMQPConnectionFactory.Create` para receber eventos
estruturados de conexao, canal, fila, publish, consume, ack/nack/reject,
heartbeat e erro.

```pascal
Factory := TAMQPConnectionFactory.Create(TConsoleLogger.Create);
```

Os eventos incluem campos como `Operation`, `ConnectionId`, `ChannelId`,
`ErrorClass` e `DurationMS`. Sem logger explicito, a biblioteca usa um logger
nulo interno.

## RabbitMQ local

Uma forma simples de validar futuramente os testes de integracao:

```powershell
docker run --rm -it -p 5672:5672 -p 15672:15672 rabbitmq:3-management
```

Credenciais padrao:

- Usuario: `guest`
- Senha: `guest`
- Host: `localhost`
- Porta AMQP: `5672`

## Roadmap

1. Fundacao do repositorio e documentacao.
2. Contratos publicos e arquitetura.
3. Codec AMQP 0-9-1.
4. Conexao TCP, handshake e canais.
5. Operacoes de fila e publicacao.
6. Consumo assincrono.
7. Observabilidade.
8. Projeto de exemplo completo.
9. Documentacao final.
10. Preparacao open source.

## Documentacao tecnica

O funcionamento interno do transporte TCP, frames AMQP, metodos de handshake e
orquestracao da conexao esta documentado em `docs/technical-guide.md`. Este
arquivo deve ser mantido como documentacao viva conforme novas etapas forem
implementadas.

## Licenca

MIT. Veja `LICENSE`.
